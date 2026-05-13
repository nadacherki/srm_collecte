// lib/data/remote/api_service.dart
// ── SPRINT 3 : API Service pour SRM Collecte ──
// POST /api/login/ → { login, mot_de_passe } → { success, user, projet_actif }
// Mot de passe en clair (comparaison directe côté serveur)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiPageResult {
  final List<dynamic> items;
  final int? nextPage;
  final int? count;

  const ApiPageResult({
    required this.items,
    this.nextPage,
    this.count,
  });
}

class ApiService {
  // ── URL de base du serveur Django SRM ──
  // Émulateur Android : 10.0.2.2 = localhost de la machine hôte
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  // ── Authentification ──
  static String? authToken;
  static int? userId; // = id_user (table public.utilisateur)
  static String? userLogin; // = login SRM (pas email)
  static String? userRole; // admin, project_manager, editeur_terrain…
  static String? userNom;
  static String? userPrenom;
  static String? nomPrenom; // nom complet affiche dans l'app

  static String _extractApiErrorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final nodesError = decoded['nodes'];
        if (nodesError is List && nodesError.isNotEmpty) {
          return nodesError.first.toString();
        }
        final message =
            decoded['error'] ?? decoded['detail'] ?? decoded['message'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
    } on FormatException {
      // Fallback texte brut plus bas.
    }

    final plainText = body
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plainText.isNotEmpty) {
      return plainText.length > 180
          ? '${plainText.substring(0, 180).trim()}...'
          : plainText;
    }

    return fallback;
  }

  // ══════════════════════════════════════════════════════
  // ██ LOGIN SRM
  // ══════════════════════════════════════════════════════
  /// POST /api/login/
  /// Body  : { "login": "nada", "mot_de_passe": "test123" }
  /// Retour:
  /// {
  ///   "success": true,
  ///   "user": {
  ///     "id_user": 2, "login": "nada", "prenom": "NADA", "nom": "CHERKI",
  ///     "role": "admin",
  ///     "nb_objets_collectes_total": 0
  ///   }
  /// }
  static Future<Map<String, dynamic>> login(
      String login, String motDePasse) async {
    final url = Uri.parse('$baseUrl/api/login/');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'login': login,
        'mot_de_passe': motDePasse, // en clair — pas de hash côté client
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      // ── Vérifier success ──
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Identifiants incorrects');
      }

      // ── Parser "user" ──
      final Map<String, dynamic> userMap =
          Map<String, dynamic>.from(data['user']);

      userId = userMap['id_user'];
      userLogin = userMap['login'];
      userNom = userMap['nom']?.toString();
      userPrenom = userMap['prenom']?.toString();
      nomPrenom = _buildFullName(userPrenom, userNom, userMap['nom_complet']);
      userRole = userMap['role'];

      // ── Token (si l'API en renvoie un à l'avenir) ──
      authToken = data['token'] ?? data['access'];

      debugPrint('SRM Login OK: user=$login (id_user=$userId) role=$userRole');

      // ── Résultat à plat pour LoginPage / DatabaseHelper ──
      return {
        'id_user': userId,
        'login': userLogin,
        'nom': userNom,
        'prenom': userPrenom,
        'nom_complet': nomPrenom,
        'role': userRole,
        'nb_objets_collectes_total': userMap['nb_objets_collectes_total'] ?? 0,
      };
    } else {
      try {
        final error = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(error['error'] ?? 'Erreur ${response.statusCode}');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Erreur serveur ${response.statusCode}');
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ PROJETS
  // ══════════════════════════════════════════════════════

  /// GET /api/basemaps/region/manifest/
  /// Retour: { success, name, attribution, format, version, sha256,
  ///           size_bytes, generated_at, download_url }
  static Future<Map<String, dynamic>> fetchRegionalBasemapManifest() async {
    final url = Uri.parse('$baseUrl/api/basemaps/region/manifest/');
    final response = await http
        .get(url, headers: _headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur GET basemap manifest: ${response.statusCode}',
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw Exception('Reponse manifest basemap invalide');
    }
    return data;
  }

  /// GET /api/orthophotos/agent/manifest/
  static Future<Map<String, dynamic>> fetchOrthophotoAgentManifest() async {
    final url = Uri.parse('$baseUrl/api/orthophotos/agent/manifest/');
    final response = await http
        .get(url, headers: _headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        _extractApiErrorMessage(
          utf8.decode(response.bodyBytes),
          'Erreur GET orthophoto manifest: ${response.statusCode}',
        ),
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw Exception('Reponse manifest orthophoto invalide');
    }
    return data;
  }

  /// GET /api/orthophotos/agent/tiles/
  static Future<Map<String, dynamic>> fetchOrthophotoAgentTiles({
    int page = 1,
    int pageSize = 500,
    int? z,
    int? x,
    int? y,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      if (z != null) 'z': z.toString(),
      if (x != null) 'x': x.toString(),
      if (y != null) 'y': y.toString(),
    };
    final url = Uri.parse('$baseUrl/api/orthophotos/agent/tiles/').replace(
      queryParameters: queryParameters,
    );
    final response = await http
        .get(url, headers: _headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        _extractApiErrorMessage(
          utf8.decode(response.bodyBytes),
          'Erreur GET orthophoto tiles: ${response.statusCode}',
        ),
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw Exception('Reponse tuiles orthophoto invalide');
    }
    return data;
  }

  static Future<List<Map<String, dynamic>>> fetchSrmFieldOptions({
    String? tableSchema,
    String? tableName,
    String? fieldName,
    bool activeOnly = true,
  }) async {
    final items = <Map<String, dynamic>>[];
    var page = 1;
    final visitedPages = <int>{};

    while (visitedPages.add(page)) {
      final queryParameters = <String, String>{
        'active_only': activeOnly ? 'true' : 'false',
        if (page > 1) 'page': page.toString(),
      };
      if (tableSchema != null && tableSchema.isNotEmpty) {
        queryParameters['table_schema'] = tableSchema;
      }
      if (tableName != null && tableName.isNotEmpty) {
        queryParameters['table_name'] = tableName;
      }
      if (fieldName != null && fieldName.isNotEmpty) {
        queryParameters['field_name'] = fieldName;
      }

      final url = Uri.parse('$baseUrl/api/srm-field-options/').replace(
        queryParameters: queryParameters,
      );
      final response = await http
          .get(url, headers: _headers())
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Erreur GET srm-field-options: ${response.statusCode}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final pageResult = _parsePagedDataResponse(data, currentPage: page);
      items.addAll(
        pageResult.items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item)),
      );

      final nextPage = pageResult.nextPage;
      if (nextPage == null || nextPage <= 0) {
        break;
      }
      page = nextPage;
    }

    return items;
  }

  static Future<List<Map<String, dynamic>>> fetchAttributConfigMobile({
    String? nomMetier,
    String? nomTable,
    String? nomChamp,
    bool visibleOnly = false,
  }) async {
    final queryParameters = <String, String>{
      if (visibleOnly) 'visible_only': 'true',
    };
    if (nomMetier != null && nomMetier.isNotEmpty) {
      queryParameters['nom_metier'] = nomMetier;
    }
    if (nomTable != null && nomTable.isNotEmpty) {
      queryParameters['nom_table'] = nomTable;
    }
    if (nomChamp != null && nomChamp.isNotEmpty) {
      queryParameters['nom_champ'] = nomChamp;
    }

    final url = Uri.parse('$baseUrl/api/attribut-config-mobile/').replace(
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );
    final response = await http
        .get(url, headers: _headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur GET attribut-config-mobile: ${response.statusCode}',
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final List items =
        data is List ? data : (data['results'] ?? data['features'] ?? const []);

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchFormulaireConfigMobile({
    String? nomMetier,
    String? nomTable,
    bool visibleOnly = false,
  }) async {
    final queryParameters = <String, String>{
      if (visibleOnly) 'visible_only': 'true',
    };
    if (nomMetier != null && nomMetier.isNotEmpty) {
      queryParameters['nom_metier'] = nomMetier;
    }
    if (nomTable != null && nomTable.isNotEmpty) {
      queryParameters['nom_table'] = nomTable;
    }

    final url = Uri.parse('$baseUrl/api/formulaire-config-mobile/').replace(
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );
    final response = await http
        .get(url, headers: _headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur GET formulaire-config-mobile: ${response.statusCode}',
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final List items =
        data is List ? data : (data['results'] ?? data['features'] ?? const []);

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchMobileExportManifest({
    String? nomMetier,
    String? nomTable,
  }) async {
    final queryParameters = <String, String>{};
    if (nomMetier != null && nomMetier.isNotEmpty) {
      queryParameters['nom_metier'] = nomMetier;
    }
    if (nomTable != null && nomTable.isNotEmpty) {
      queryParameters['nom_table'] = nomTable;
    }

    final url = Uri.parse('$baseUrl/api/mobile-export-manifest/').replace(
      queryParameters: queryParameters.isNotEmpty ? queryParameters : null,
    );
    final response = await http
        .get(url, headers: _headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur GET mobile-export-manifest: ${response.statusCode}',
      );
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final List items =
        data is List ? data : (data['results'] ?? data['features'] ?? const []);

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>?> fetchCompteurAbonneCustomerLink({
    String? numContrat,
    String? anciennePolice,
    double? x,
    double? y,
  }) async {
    final contract = numContrat?.trim() ?? '';
    final police = anciennePolice?.trim() ?? '';
    if (contract.isEmpty && police.isEmpty) return null;

    final params = <String, String>{
      if (contract.isNotEmpty) 'num_contrat': contract,
      if (police.isNotEmpty) 'ancienne_police': police,
      if (x != null) 'x': x.toStringAsFixed(3),
      if (y != null) 'y': y.toStringAsFixed(3),
    };
    final uri = Uri.parse('$baseUrl/api/ep/compteurs-abonne/customer-link/')
        .replace(queryParameters: params);

    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 12));
      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw Exception('Réponse liaison client invalide');
      }

      throw Exception(
        _extractApiErrorMessage(
          body,
          'Erreur liaison client ${response.statusCode}',
        ),
      );
    } on TimeoutException {
      throw Exception('Timeout liaison client');
    } on SocketException {
      throw Exception('Erreur réseau liaison client');
    } on FormatException {
      throw Exception('Réponse liaison client invalide');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchCommunesOriental() async {
    final url = Uri.parse('$baseUrl/api/communes-oriental/');
    final response = await http
        .get(url, headers: _headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Erreur GET communes-oriental: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    dynamic itemsRaw;
    if (data is List) {
      itemsRaw = data;
    } else if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) {
        itemsRaw = results;
      } else if (results is Map<String, dynamic> &&
          results['features'] is List) {
        itemsRaw = results['features'];
      } else if (data['features'] is List) {
        itemsRaw = data['features'];
      } else {
        itemsRaw = const [];
      }
    } else {
      itemsRaw = const [];
    }

    final List items = itemsRaw is List ? itemsRaw : const [];

    return items.whereType<Map>().map((item) {
      final feature = Map<String, dynamic>.from(item);
      final properties = feature['properties'] is Map
          ? Map<String, dynamic>.from(feature['properties'] as Map)
          : <String, dynamic>{};

      if (properties['id_commune'] == null && feature['id'] != null) {
        properties['id_commune'] = feature['id'];
      }
      if (feature['geometry'] != null) {
        properties['geometry_geojson'] = jsonEncode(feature['geometry']);
      }
      return properties;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchCommunes() {
    return fetchCommunesOriental();
  }

  static Future<List<Map<String, dynamic>>> fetchZones() async {
    final url = Uri.parse('$baseUrl/api/zones/');
    final response = await http
        .get(url, headers: _headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Erreur GET zones: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return _extractFeatureOrResultItems(data).map((item) {
      final feature = Map<String, dynamic>.from(item);
      final properties = feature['properties'] is Map
          ? Map<String, dynamic>.from(feature['properties'] as Map)
          : Map<String, dynamic>.from(feature);

      if (properties['id_zone'] == null && feature['id'] != null) {
        properties['id_zone'] = feature['id'];
      }
      if (feature['geometry'] != null) {
        properties['geometry_geojson'] = jsonEncode(feature['geometry']);
      } else if (properties['geometry_geojson'] is Map) {
        properties['geometry_geojson'] =
            jsonEncode(properties['geometry_geojson']);
      }
      return properties;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchZoneUtilisateurs({
    int? idUser,
    bool activeOnly = true,
  }) async {
    final queryParameters = <String, String>{
      'active_only': activeOnly ? 'true' : 'false',
    };
    final targetUserId = idUser ?? userId;
    if (targetUserId != null) {
      queryParameters['id_user'] = targetUserId.toString();
    }

    final url = Uri.parse('$baseUrl/api/zone-utilisateurs/').replace(
      queryParameters: queryParameters,
    );
    final response = await http
        .get(url, headers: _headers())
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Erreur GET zone-utilisateurs: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return _extractFeatureOrResultItems(data)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchTerrainInterventions({
    DateTime? updatedAfter,
  }) async {
    final items = await fetchData(
      'interventions-anomalies-terrain',
      updatedAfter: updatedAfter,
      queryParameters: const {
        'active_only': 'true',
        'terrain_only': 'false',
      },
    );

    return items.whereType<Map>().map((item) {
      final raw = Map<String, dynamic>.from(item);
      if (raw['properties'] is Map) {
        final properties = Map<String, dynamic>.from(raw['properties'] as Map);
        properties['id'] ??= raw['id'];
        return properties;
      }
      return raw;
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> fetchPlancheOverlay() async {
    final items = await fetchData('reference-overlays/planches');
    return items
        .whereType<Map>()
        .map((item) => _flattenReferenceOverlayItem(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchFondPlanOverlay() async {
    final items = await fetchData('reference-overlays/fond-plan');
    return items
        .whereType<Map>()
        .map((item) => _flattenReferenceOverlayItem(item))
        .toList();
  }

  static Map<String, dynamic> _flattenReferenceOverlayItem(Map rawItem) {
    final item = Map<String, dynamic>.from(rawItem);
    final properties = item['properties'] is Map
        ? Map<String, dynamic>.from(item['properties'] as Map)
        : Map<String, dynamic>.from(item);

    final geometry = item['geometry'] ?? properties['geometry_geojson'];
    if (geometry != null) {
      properties['geometry_geojson'] =
          geometry is String ? geometry : jsonEncode(geometry);
    }
    return properties;
  }

  static Future<Map<String, dynamic>> updateTerrainIntervention({
    required int idIntervention,
    required String etatTerrain,
    String? commentaireTerrain,
    int? idUserTerrain,
    String? syncSessionUuid,
    String? syncClientItemUuid,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/interventions-anomalies-terrain/$idIntervention/',
    );
    final payload = <String, dynamic>{
      'etat_terrain': etatTerrain,
      if (commentaireTerrain != null) 'commentaire_terrain': commentaireTerrain,
      'id_user_terrain': idUserTerrain ?? userId,
    };
    final cleanSyncUuid = syncSessionUuid?.trim() ?? '';
    if (cleanSyncUuid.isNotEmpty) {
      payload['_sync_session_uuid'] = cleanSyncUuid;
    }
    final cleanClientItemUuid = syncClientItemUuid?.trim() ?? '';
    if (cleanClientItemUuid.isNotEmpty) {
      payload['_sync_client_item_uuid'] = cleanClientItemUuid;
    }

    try {
      final response = await http
          .patch(uri, headers: _headers(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));
      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw Exception('Reponse intervention terrain invalide');
      }

      throw Exception(
        _extractApiErrorMessage(
          body,
          'Erreur intervention terrain ${response.statusCode}',
        ),
      );
    } on TimeoutException {
      throw Exception('Timeout intervention terrain');
    } on SocketException {
      throw Exception('Erreur réseau intervention terrain');
    } on FormatException {
      throw Exception('Reponse intervention terrain invalide');
    }
  }

  static List<Map<String, dynamic>> _extractFeatureOrResultItems(dynamic data) {
    dynamic itemsRaw;
    if (data is List) {
      itemsRaw = data;
    } else if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) {
        itemsRaw = results;
      } else if (results is Map<String, dynamic> &&
          results['features'] is List) {
        itemsRaw = results['features'];
      } else if (data['features'] is List) {
        itemsRaw = data['features'];
      } else {
        itemsRaw = const [];
      }
    } else {
      itemsRaw = const [];
    }

    final List items = itemsRaw is List ? itemsRaw : const [];
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // ══════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════
  // ██ POST GÉNÉRIQUE
  // ══════════════════════════════════════════════════════

  static Future<dynamic> postData(
    String endpoint,
    Map<String, dynamic> data, {
    bool throwOnError = false,
    String? syncSessionUuid,
    String? syncClientItemUuid,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/$endpoint/');
      final payload = Map<String, dynamic>.from(data);

      payload.remove('id_projet');
      payload.remove('id_mission');
      if (userId != null &&
          endpoint != 'objets-incomplets' &&
          !payload.containsKey('id_agent_crea')) {
        payload['id_agent_crea'] = userId;
      }
      final cleanSyncUuid = syncSessionUuid?.trim() ?? '';
      if (cleanSyncUuid.isNotEmpty) {
        payload['_sync_session_uuid'] = cleanSyncUuid;
      }
      final cleanClientItemUuid = syncClientItemUuid?.trim() ?? '';
      if (cleanClientItemUuid.isNotEmpty) {
        payload['_sync_client_item_uuid'] = cleanClientItemUuid;
      }

      final response = await http
          .post(url, headers: _headers(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          return true;
        }
      } else {
        debugPrint('❌ Erreur API POST ($endpoint): '
            '${response.statusCode} - ${response.body}');
        if (throwOnError) {
          var message = 'Erreur POST $endpoint: ${response.statusCode}';
          try {
            final decoded = jsonDecode(utf8.decode(response.bodyBytes));
            if (decoded is Map<String, dynamic>) {
              final serverMessage =
                  decoded['error'] ?? decoded['detail'] ?? decoded['message'];
              final serverText = serverMessage?.toString().trim() ?? '';
              if (serverText.isNotEmpty) {
                message = serverText;
              }
            }
          } catch (_) {
            // On garde le message par défaut.
          }
          throw Exception(message);
        }
        return null;
      }
    } on TimeoutException catch (e) {
      debugPrint('⏰ Timeout $endpoint: $e');
      if (throwOnError) {
        throw Exception('Timeout POST $endpoint');
      }
      return null;
    } on SocketException catch (e) {
      debugPrint('Erreur réseau $endpoint: $e');
      if (throwOnError) {
        throw Exception('Erreur réseau POST $endpoint');
      }
      return null;
    } catch (e) {
      debugPrint('❌ Exception $endpoint: $e');
      if (throwOnError) rethrow;
      return null;
    }
  }

  static Future<Map<String, dynamic>> createSyncManifest({
    required String syncUuid,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> attachments,
    Map<String, dynamic>? metadata,
  }) async {
    final uri = Uri.parse('$baseUrl/api/sync/manifest/');
    final payload = <String, dynamic>{
      'sync_uuid': syncUuid,
      'id_agent': userId,
      'items': items,
      'attachments': attachments,
      if (metadata != null) 'metadata': metadata,
    };

    try {
      final response = await http
          .post(uri, headers: _headers(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));
      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw Exception('Reponse manifeste sync invalide');
      }

      throw Exception(
        _extractApiErrorMessage(
          body,
          'Erreur manifeste sync ${response.statusCode}',
        ),
      );
    } on TimeoutException {
      throw Exception('Timeout manifeste sync');
    } on SocketException {
      throw Exception('Erreur réseau manifeste sync');
    } on FormatException {
      throw Exception('Reponse manifeste sync invalide');
    }
  }

  static Future<Map<String, dynamic>> fetchSyncSessionStatus(
    String syncUuid,
  ) async {
    final cleanSyncUuid = syncUuid.trim();
    if (cleanSyncUuid.isEmpty) {
      throw Exception('sync_uuid manquant');
    }

    final uri = Uri.parse('$baseUrl/api/sync/session/$cleanSyncUuid/');
    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 20));
      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw Exception('Reponse statut sync invalide');
      }

      throw Exception(
        _extractApiErrorMessage(
          body,
          'Erreur statut sync ${response.statusCode}',
        ),
      );
    } on TimeoutException {
      throw Exception('Timeout statut sync');
    } on SocketException {
      throw Exception('Erreur reseau statut sync');
    } on FormatException {
      throw Exception('Reponse statut sync invalide');
    }
  }

  static Future<Map<String, dynamic>> uploadPhoto({
    required String schemaName,
    required String tableName,
    required String uuidObjet,
    required int photoSlot,
    required String localPath,
    int? idAgentCrea,
    String? syncSessionUuid,
    String? endpoint,
  }) async {
    final uri = Uri.parse('$baseUrl/api/photos/upload/');
    final request = http.MultipartRequest('POST', uri);

    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    request.fields['schema_name'] = schemaName;
    request.fields['table_name'] = tableName;
    request.fields['uuid_objet'] = uuidObjet;
    request.fields['photo_slot'] = photoSlot.toString();
    final cleanEndpoint = endpoint?.trim() ?? '';
    if (cleanEndpoint.isNotEmpty) {
      request.fields['endpoint'] = cleanEndpoint;
    }
    final cleanSyncUuid = syncSessionUuid?.trim() ?? '';
    if (cleanSyncUuid.isNotEmpty) {
      request.fields['sync_session_uuid'] = cleanSyncUuid;
    }
    if (idAgentCrea != null) {
      request.fields['id_agent_crea'] = idAgentCrea.toString();
    }

    request.files.add(await http.MultipartFile.fromPath('file', localPath));

    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw Exception('Réponse upload photo invalide');
      }

      try {
        final decoded = jsonDecode(body);
        throw Exception(
            decoded['error'] ?? 'Erreur upload photo ${response.statusCode}');
      } catch (_) {
        throw Exception('Erreur upload photo ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Timeout upload photo');
    } on SocketException {
      throw Exception('Erreur réseau upload photo');
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ GET GÉNÉRIQUE (GeoJSON / liste)
  // ══════════════════════════════════════════════════════

  /// Ex : fetchData('ep/vannes') -> GET /api/ep/vannes/
  static Future<List<dynamic>> fetchData(
    String endpoint, {
    DateTime? updatedAfter,
    Map<String, String>? queryParameters,
  }) async {
    final items = <dynamic>[];
    var page = 1;
    final visitedPages = <int>{};

    while (visitedPages.add(page)) {
      final pageResult = await fetchDataPage(
        endpoint,
        updatedAfter: updatedAfter,
        queryParameters: queryParameters,
        page: page,
      );
      items.addAll(pageResult.items);
      final nextPage = pageResult.nextPage;
      if (nextPage == null || nextPage <= 0) {
        break;
      }
      page = nextPage;
    }

    return items;
  }

  static Future<ApiPageResult> fetchDataPage(
    String endpoint, {
    DateTime? updatedAfter,
    Map<String, String>? queryParameters,
    int page = 1,
  }) async {
    final params = <String, String>{...?queryParameters};
    if (updatedAfter != null) {
      params['updated_after'] = updatedAfter.toUtc().toIso8601String();
    }
    if (page > 1) {
      params['page'] = page.toString();
    }

    final uri = Uri.parse('$baseUrl/api/$endpoint/')
        .replace(queryParameters: params.isNotEmpty ? params : null);

    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return _parsePagedDataResponse(data, currentPage: page);
      } else {
        throw Exception('Erreur GET ($endpoint): ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      throw Exception('Timeout GET $endpoint');
    } on SocketException catch (_) {
      throw Exception('Erreur réseau GET $endpoint');
    } catch (e) {
      throw Exception('Erreur GET $endpoint: $e');
    }
  }

  static ApiPageResult _parsePagedDataResponse(
    dynamic data, {
    required int currentPage,
  }) {
    if (data is Map) {
      final count = _asInt(data['count']);
      final nextPage = _nextPageFromUrl(data['next']?.toString(), currentPage);
      if (data.containsKey('features')) {
        final features = data['features'];
        return ApiPageResult(
          items: features is List ? features : const [],
          nextPage: nextPage,
          count: count,
        );
      }
      if (data.containsKey('results')) {
        final results = data['results'];
        if (results is List) {
          return ApiPageResult(
            items: results,
            nextPage: nextPage,
            count: count,
          );
        }
        if (results is Map && results.containsKey('features')) {
          final features = results['features'];
          return ApiPageResult(
            items: features is List ? features : const [],
            nextPage: nextPage,
            count: count,
          );
        }
        return ApiPageResult(
          items: const [],
          nextPage: nextPage,
          count: count,
        );
      }
      return ApiPageResult(items: [data], count: count);
    }

    if (data is List) {
      return ApiPageResult(items: data);
    }

    return ApiPageResult(items: [data]);
  }

  static int? _nextPageFromUrl(String? nextUrl, int currentPage) {
    if (nextUrl == null || nextUrl.trim().isEmpty || nextUrl == 'null') {
      return null;
    }
    try {
      final uri = Uri.parse(nextUrl);
      final rawPage = uri.queryParameters['page'];
      if (rawPage == null || rawPage.trim().isEmpty) {
        return currentPage + 1;
      }
      final parsed = int.tryParse(rawPage);
      if (parsed == null || parsed <= currentPage) {
        return null;
      }
      return parsed;
    } catch (_) {
      return currentPage + 1;
    }
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static Future<List<Map<String, dynamic>>> fetchMetricsList(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final params = <String, String>{};
    (queryParameters ?? const {}).forEach((key, value) {
      if (value == null) return;
      final text = value.toString().trim();
      if (text.isEmpty) return;
      params[key] = text;
    });

    final uri = Uri.parse('$baseUrl/api/$endpoint/')
        .replace(queryParameters: params.isNotEmpty ? params : null);

    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Erreur GET $endpoint: ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final List items =
          decoded is List ? decoded : (decoded['results'] ?? const []);

      return items
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on TimeoutException {
      throw Exception('Timeout GET $endpoint');
    } on SocketException {
      throw Exception('Erreur réseau GET $endpoint');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erreur GET $endpoint: $e');
    }
  }

  static Future<Map<String, dynamic>?> fetchMetricsFirst(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final rows = await fetchMetricsList(
      endpoint,
      queryParameters: queryParameters,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<Map<String, dynamic>?> fetchAgentPublicResume({
    int? idAgent,
  }) {
    return fetchMetricsFirst(
      'metrics-agent-public-resume',
      queryParameters: {
        'id_agent': idAgent ?? userId,
      },
    );
  }

  static Future<Map<String, dynamic>?> fetchAgentPublicJour({
    int? idAgent,
    DateTime? jour,
  }) {
    return fetchMetricsFirst(
      'metrics-agent-public-jour',
      queryParameters: {
        'id_agent': idAgent ?? userId,
        if (jour != null) 'jour': _formatDateParam(jour),
      },
    );
  }

  static Future<Map<String, dynamic>?> fetchAgentPublicSemaine({
    int? idAgent,
    int? anneeIso,
    int? semaineIso,
  }) {
    return fetchMetricsFirst(
      'metrics-agent-public-semaine',
      queryParameters: {
        'id_agent': idAgent ?? userId,
        'annee_iso': anneeIso,
        'semaine_iso': semaineIso,
      },
    );
  }

  static Future<Map<String, dynamic>?> fetchAgentPublicMois({
    int? idAgent,
    int? annee,
    int? moisNumero,
  }) {
    return fetchMetricsFirst(
      'metrics-agent-public-mois',
      queryParameters: {
        'id_agent': idAgent ?? userId,
        'annee': annee,
        'mois_numero': moisNumero,
      },
    );
  }

  static Future<Map<String, dynamic>> fetchStatistiqueConduiteJour({
    int? idAgent,
    DateTime? jour,
    String metier = 'ep',
  }) async {
    final effectiveAgentId = idAgent ?? userId;
    if (effectiveAgentId == null) {
      throw Exception('Utilisateur non connecté pour lire la conduite du jour');
    }

    final effectiveDay = jour ?? DateTime.now();
    final uri = Uri.parse('$baseUrl/api/statistiques-conduite/jour/').replace(
      queryParameters: {
        'id_agent': effectiveAgentId.toString(),
        'jour': _formatDateParam(effectiveDay),
        'metier': metier,
      },
    );

    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 30));
      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw Exception('Réponse conduite du jour invalide');
      }

      throw Exception(
        _extractApiErrorMessage(
          body,
          'Erreur lecture conduite ${response.statusCode}',
        ),
      );
    } on TimeoutException {
      throw Exception('Timeout lecture conduite du jour');
    } on SocketException {
      throw Exception('Erreur réseau lecture conduite du jour');
    } on FormatException {
      throw Exception('Réponse conduite du jour invalide');
    }
  }

  static Future<Map<String, dynamic>> validateStatistiqueConduite({
    int? idAgent,
    required DateTime jour,
    required List<Map<String, dynamic>> nodes,
    String metier = 'ep',
    String? syncUuid,
    String? syncSessionUuid,
    String? syncClientItemUuid,
    bool acceptFrozenConflict = false,
  }) async {
    final effectiveAgentId = idAgent ?? userId;
    if (effectiveAgentId == null) {
      throw Exception('Utilisateur non connecté pour valider la conduite');
    }

    final uri = Uri.parse('$baseUrl/api/statistiques-conduite/valider/');
    final payload = <String, dynamic>{
      'metier': metier,
      'id_agent': effectiveAgentId,
      'jour': _formatDateParam(jour),
      'nodes': nodes,
    };
    final cleanSyncUuid = syncUuid?.trim() ?? '';
    if (cleanSyncUuid.isNotEmpty) {
      payload['sync_uuid'] = cleanSyncUuid;
    }
    final cleanSessionUuid = syncSessionUuid?.trim() ?? '';
    if (cleanSessionUuid.isNotEmpty) {
      payload['_sync_session_uuid'] = cleanSessionUuid;
    }
    final cleanClientItemUuid = syncClientItemUuid?.trim() ?? '';
    if (cleanClientItemUuid.isNotEmpty) {
      payload['_sync_client_item_uuid'] = cleanClientItemUuid;
    }

    try {
      final response = await http
          .post(uri, headers: _headers(), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));
      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          (acceptFrozenConflict && response.statusCode == 409)) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw Exception('Réponse validation conduite invalide');
      }

      throw Exception(
        _extractApiErrorMessage(
          body,
          'Erreur validation conduite ${response.statusCode}',
        ),
      );
    } on TimeoutException {
      throw Exception('Timeout validation conduite');
    } on SocketException {
      throw Exception('Erreur réseau validation conduite');
    } on FormatException {
      throw Exception('Réponse validation conduite invalide');
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ ENDPOINTS SPÉCIFIQUES (EP / ASS)
  // ══════════════════════════════════════════════════════

  // ── Eau Potable ──
  static Future<List<dynamic>> fetchVannes() => fetchData('ep/vannes');
  static Future<List<dynamic>> fetchVannesVidange() =>
      fetchData('ep/vannes-vidange');
  static Future<List<dynamic>> fetchVentouses() => fetchData('ep/ventouses');
  static Future<List<dynamic>> fetchHydrants() => fetchData('ep/hydrants');
  static Future<List<dynamic>> fetchBornesFontaine() =>
      fetchData('ep/bornes-fontaine');
  static Future<List<dynamic>> fetchBornesOnep() => fetchData('ep/bornes-onep');
  static Future<List<dynamic>> fetchBouchesCles() =>
      fetchData('ep/bouches-cles');
  static Future<List<dynamic>> fetchBouchesArrosage() =>
      fetchData('ep/bouches-arrosage');
  static Future<List<dynamic>> fetchCompteursReseau() =>
      fetchData('ep/compteurs-reseau');
  static Future<List<dynamic>> fetchCompteursAbonne() =>
      fetchData('ep/compteurs-abonne');
  static Future<List<dynamic>> fetchConesReduction() =>
      fetchData('ep/cones-reduction');
  static Future<List<dynamic>> fetchCentresTampon() =>
      fetchData('ep/centres-tampon');
  static Future<List<dynamic>> fetchObturateurs() =>
      fetchData('ep/obturateurs');
  static Future<List<dynamic>> fetchReducteursPression() =>
      fetchData('ep/reducteurs-pression');
  static Future<List<dynamic>> fetchNoeudsEP() => fetchData('ep/noeuds');
  static Future<List<dynamic>> fetchReservoirs() => fetchData('ep/reservoirs');
  static Future<List<dynamic>> fetchStationsPompage() =>
      fetchData('ep/stations-pompage');
  static Future<List<dynamic>> fetchForages() => fetchData('ep/forages');
  static Future<List<dynamic>> fetchPuits() => fetchData('ep/puits');
  static Future<List<dynamic>> fetchPompes() => fetchData('ep/pompes');
  static Future<List<dynamic>> fetchBaches() => fetchData('ep/baches');
  static Future<List<dynamic>> fetchRegardsEP() => fetchData('ep/regards');
  static Future<List<dynamic>> fetchRegardsMiroirEP() =>
      fetchData('ep/regards-miroir');
  static Future<List<dynamic>> fetchAnomaliesConduite() =>
      fetchData('ep/anomalies-conduite');
  static Future<List<dynamic>> fetchConduitesTerrain() =>
      fetchData('ep/conduites-terrain');
  static Future<List<dynamic>> fetchBranchementsEP() =>
      fetchData('ep/branchements');
  static Future<List<dynamic>> fetchTraverses() => fetchData('ep/traverses');
  static Future<List<dynamic>> fetchTnEP() => fetchData('ep/tn');
  static Future<List<dynamic>> fetchVoiesEP() => fetchData('ep/voies');

  // ── Assainissement ──
  static Future<List<dynamic>> fetchRegardsASS() => fetchData('ass/regards');
  static Future<List<dynamic>> fetchRegardsBranchement() =>
      fetchData('ass/regards-branchement');
  static Future<List<dynamic>> fetchCanalisationsASS() =>
      fetchData('ass/canalisations');
  static Future<List<dynamic>> fetchCanalisationsReutilisation() =>
      fetchData('ass/canalisations-reutilisation');
  static Future<List<dynamic>> fetchBranchementsASS() =>
      fetchData('ass/branchements');
  static Future<List<dynamic>> fetchBassins() => fetchData('ass/bassins');
  static Future<List<dynamic>> fetchOuvragesASS() => fetchData('ass/ouvrages');
  static Future<List<dynamic>> fetchEquipementsASS() =>
      fetchData('ass/equipements');
  static Future<List<dynamic>> fetchStationsASS() => fetchData('ass/stations');

  // ── Sync POST générique ──
  static Future<dynamic> syncEntity(
      String schema, String tableName, Map<String, dynamic> data) {
    return postData('$schema/$tableName', data);
  }

  // ══════════════════════════════════════════════════════
  // ██ UTILITAIRES
  // ══════════════════════════════════════════════════════

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
        // Identifie l'agent appelant pour le filtrage par zone d'affectation
        // cote serveur (zones, planches, donnees EP/ASS).
        if (userId != null) 'X-User-Id': userId!.toString(),
      };

  static String _formatDateParam(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Map<String, dynamic> extractFromGeoJson(Map<String, dynamic> geoJson) {
    return {
      'properties': geoJson['properties'],
      'geometry': geoJson['geometry'],
      'id': geoJson['id'],
    };
  }

  /// Reset complet (logout)
  static void resetSession() {
    authToken = null;
    userId = null;
    userRole = null;
    userLogin = null;
    userNom = null;
    userPrenom = null;
    nomPrenom = null;
  }

  static String? _buildFullName(Object? prenom, Object? nom, Object? fallback) {
    final fallbackText = fallback?.toString().trim() ?? '';
    if (fallbackText.isNotEmpty) return fallbackText;

    final parts = [
      prenom?.toString().trim() ?? '',
      nom?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' ');
  }
}
