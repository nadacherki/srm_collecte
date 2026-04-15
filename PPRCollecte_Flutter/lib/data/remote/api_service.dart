// lib/data/remote/api_service.dart
// ── SPRINT 3 : API Service pour SRM Collecte ──
// POST /api/login/ → { login, mot_de_passe } → { success, user, projet_actif }
// Mot de passe en clair (comparaison directe côté serveur)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';

class ApiService {
  // ── URL de base du serveur Django SRM ──
  // Émulateur Android : 10.0.2.2 = localhost de la machine hôte
  static const String baseUrl = 'http://10.0.2.2:8000';

  // ── Authentification ──
  static String? authToken;
  static int? userId;       // = id_user (table public.utilisateur)
  static String? userLogin; // = login SRM (pas email)
  static String? userRole;  // admin, project_manager, editeur_terrain…
  static String? nomPrenom; // "NADA CHERKI"

  // ── Projet actif (renvoyé par /api/login/) ──
  static int? currentProjetId;       // id_projet
  static String? currentProjetNom;
  static String? currentProjetCode;  // code_affaire
  static String? currentProjetStatut;
  static String? currentProjetMetier; // EP, ASS, ELEC, ALL
  static String? currentProjetRegion;
  static String? currentProjetSrm;
  static int? currentMissionId;

  // ── Mission (choisi/créé après login) ──
  // SUPPRIMÉ : plus de gestion de mission — chaque objet porte sa date_collecte

  // ══════════════════════════════════════════════════════
  // ██ LOGIN SRM
  // ══════════════════════════════════════════════════════
  /// POST /api/login/
  /// Body  : { "login": "nada", "mot_de_passe": "test123" }
  /// Retour:
  /// {
  ///   "success": true,
  ///   "user": {
  ///     "id_user": 2, "login": "nada", "nom_prenom": "NADA CHERKI",
  ///     "role": "admin", "id_projet_actif": 1,
  ///     "nb_objets_collectes_total": 0
  ///   },
  ///   "projet_actif": {
  ///     "id_projet": 1, "code_affaire": "AO-10001842",
  ///     "nom": "SRM-Oriental — Reconnaissance Terrain Réseaux",
  ///     "srm": "SRM-Oriental", "region": "Oriental",
  ///     "metier": "ALL", "statut": "EN_COURS"
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

      userId    = userMap['id_user'];
      userLogin = userMap['login'];
      nomPrenom = userMap['nom_prenom'];
      userRole  = userMap['role'];

      // ── Parser "projet_actif" ──
      if (data['projet_actif'] != null) {
        final Map<String, dynamic> pj =
            Map<String, dynamic>.from(data['projet_actif']);
        currentProjetId     = pj['id_projet'];
        currentProjetCode   = pj['code_affaire'];
        currentProjetNom    = pj['nom'];
        currentProjetSrm    = pj['srm'];
        currentProjetRegion = pj['region'];
        currentProjetMetier = pj['metier'];
        currentProjetStatut = pj['statut'];
      }

      // ── Token (si l'API en renvoie un à l'avenir) ──
      authToken = data['token'] ?? data['access'];

      print('🔐 SRM Login OK: user=$login (id_user=$userId) '
          'role=$userRole projet=$currentProjetId');

      // ── Résultat à plat pour LoginPage / DatabaseHelper ──
      return {
        'id_user': userId,
        'login': userLogin,
        'nom_prenom': nomPrenom,
        'role': userRole,
        'id_projet_actif': currentProjetId,
        'nb_objets_collectes_total': userMap['nb_objets_collectes_total'] ?? 0,
        // Projet actif
        'projet_id': currentProjetId,
        'projet_code': currentProjetCode,
        'projet_nom': currentProjetNom,
        'projet_srm': currentProjetSrm,
        'projet_region': currentProjetRegion,
        'projet_metier': currentProjetMetier,
        'projet_statut': currentProjetStatut,
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

  /// GET /api/projets/
  static Future<List<Map<String, dynamic>>> fetchProjets() async {
    final url = Uri.parse('$baseUrl/api/projets/');
    final response =
        await http.get(url, headers: _headers())
            .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final List items =
          data is List ? data : (data['results'] ?? data['features'] ?? []);
      return items.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('Erreur GET projets: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> fetchBasemapCatalog({
    String? citySlug,
    String? style,
    bool activeOnly = true,
  }) async {
    final queryParameters = <String, String>{
      'active_only': activeOnly ? 'true' : 'false',
    };
    if (citySlug != null && citySlug.isNotEmpty) {
      queryParameters['city_slug'] = citySlug;
    }
    if (style != null && style.isNotEmpty) {
      queryParameters['style'] = style;
    }

    final url = Uri.parse('$baseUrl/api/basemaps/catalog/').replace(
      queryParameters: queryParameters,
    );
    final response =
        await http.get(url, headers: _headers())
            .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Erreur GET basemap catalog: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw Exception('Reponse basemap catalog invalide');
    }
    return data;
  }

  static Future<List<Map<String, dynamic>>> fetchSrmFieldOptions({
    String? tableSchema,
    String? tableName,
    String? fieldName,
    bool activeOnly = true,
  }) async {
    final queryParameters = <String, String>{
      'active_only': activeOnly ? 'true' : 'false',
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
    final response =
        await http.get(url, headers: _headers())
            .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Erreur GET srm-field-options: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final List items =
        data is List ? data : (data['results'] ?? data['features'] ?? const []);

    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchCommunes() async {
    final url = Uri.parse('$baseUrl/api/communes/');
    final response =
        await http.get(url, headers: _headers())
            .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Erreur GET communes: ${response.statusCode}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    dynamic itemsRaw;
    if (data is List) {
      itemsRaw = data;
    } else if (data is Map<String, dynamic>) {
      final results = data['results'];
      if (results is List) {
        itemsRaw = results;
      } else if (results is Map<String, dynamic> && results['features'] is List) {
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

  // ══════════════════════════════════════════════════════
  // ██ MISSIONS
  // ══════════════════════════════════════════════════════

  /// GET /api/missions/?id_projet=X
  static Future<List<Map<String, dynamic>>> fetchMissions(
      int projetId) async {
    final url =
        Uri.parse('$baseUrl/api/missions/?id_projet=$projetId');
    final response =
        await http.get(url, headers: _headers())
            .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final List items =
          data is List ? data : (data['results'] ?? data['features'] ?? []);
      return items.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      throw Exception('Erreur GET missions: ${response.statusCode}');
    }
  }

  /// POST /api/missions/ → créer une nouvelle mission
  static Future<Map<String, dynamic>?> createMission(int projetId) async {
    final result = await postData('missions', {
      'id_projet': projetId,
      'id_agent': userId,
      'etat_mission': 'EN_COURS',
      'date_debut': DateTime.now().toIso8601String().substring(0, 10),
    });
    if (result is Map<String, dynamic>) return result;
    return null;
  }

  // ══════════════════════════════════════════════════════
  // ██ POST GÉNÉRIQUE
  // ══════════════════════════════════════════════════════

  static Future<dynamic> postData(
    String endpoint,
    Map<String, dynamic> data, {
    bool throwOnError = false,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/$endpoint/');

      // Injecter automatiquement le contexte SRM dans chaque requête
      if (currentProjetId != null && !data.containsKey('id_projet')) {
        data['id_projet'] = currentProjetId;
      }
      if (userId != null && !data.containsKey('id_agent_crea')) {
        data['id_agent_crea'] = userId;
      }

      final response = await http
          .post(url, headers: _headers(), body: jsonEncode(data))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          return jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {
          return true;
        }
      } else {
        print('❌ Erreur API POST ($endpoint): '
            '${response.statusCode} - ${response.body}');
        if (throwOnError) {
          throw Exception('Erreur POST $endpoint: ${response.statusCode}');
        }
        return null;
      }
    } on TimeoutException catch (e) {
      print('⏰ Timeout $endpoint: $e');
      if (throwOnError) {
        throw Exception('Timeout POST $endpoint');
      }
      return null;
    } on SocketException catch (e) {
      print('📡 Erreur réseau $endpoint: $e');
      if (throwOnError) {
        throw Exception('Erreur reseau POST $endpoint');
      }
      return null;
    } catch (e) {
      print('❌ Exception $endpoint: $e');
      if (throwOnError) rethrow;
      return null;
    }
  }

  static Future<Map<String, dynamic>> uploadPhoto({
    required String schemaName,
    required String tableName,
    required String uuidObjet,
    required int photoSlot,
    required String localPath,
    int? idProjet,
    int? idMission,
    int? idAgentCrea,
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
    if (idProjet != null) {
      request.fields['id_projet'] = idProjet.toString();
    }
    if (idMission != null) {
      request.fields['id_mission'] = idMission.toString();
    }
    if (idAgentCrea != null) {
      request.fields['id_agent_crea'] = idAgentCrea.toString();
    }

    request.files.add(await http.MultipartFile.fromPath('file', localPath));

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      final body = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        throw Exception('Reponse upload photo invalide');
      }

      try {
        final decoded = jsonDecode(body);
        throw Exception(decoded['error'] ?? 'Erreur upload photo ${response.statusCode}');
      } catch (_) {
        throw Exception('Erreur upload photo ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Timeout upload photo');
    } on SocketException {
      throw Exception('Erreur reseau upload photo');
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ GET GÉNÉRIQUE (GeoJSON / liste)
  // ══════════════════════════════════════════════════════

  /// Ex : fetchData('ep/vannes') → GET /api/ep/vannes/?id_projet=1
  static Future<List<dynamic>> fetchData(
    String endpoint, {
    DateTime? updatedAfter,
  }) async {
    final params = <String, String>{};
    if (currentProjetId != null) {
      params['id_projet'] = currentProjetId.toString();
    }
    if (updatedAfter != null) {
      params['updated_after'] = updatedAfter.toUtc().toIso8601String();
    }

    final uri = Uri.parse('$baseUrl/api/$endpoint/')
        .replace(queryParameters: params.isNotEmpty ? params : null);

    try {
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map && data.containsKey('features')) {
          return data['features'];
        } else if (data is Map && data.containsKey('results')) {
          final results = data['results'];
          if (results is List) {
            return results;
          }
          if (results is Map && results.containsKey('features')) {
            final features = results['features'];
            if (features is List) {
              return features;
            }
          }
          return [];
        } else if (data is List) {
          return data;
        }
        return [data];
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
      throw Exception('Erreur reseau GET $endpoint');
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
    int? idProjet,
  }) {
    return fetchMetricsFirst(
      'metrics-agent-public-resume',
      queryParameters: {
        'id_agent': idAgent ?? userId,
        'id_projet': idProjet ?? currentProjetId,
      },
    );
  }

  static Future<Map<String, dynamic>?> fetchAgentPublicJour({
    int? idAgent,
    int? idProjet,
    DateTime? jour,
  }) {
    return fetchMetricsFirst(
      'metrics-agent-public-jour',
      queryParameters: {
        'id_agent': idAgent ?? userId,
        'id_projet': idProjet ?? currentProjetId,
        if (jour != null) 'jour': _formatDateParam(jour),
      },
    );
  }

  static Future<Map<String, dynamic>?> fetchAgentPublicSemaine({
    int? idAgent,
    int? idProjet,
    int? anneeIso,
    int? semaineIso,
  }) {
    return fetchMetricsFirst(
      'metrics-agent-public-semaine',
      queryParameters: {
        'id_agent': idAgent ?? userId,
        'id_projet': idProjet ?? currentProjetId,
        'annee_iso': anneeIso,
        'semaine_iso': semaineIso,
      },
    );
  }

  static Future<Map<String, dynamic>?> fetchAgentPublicMois({
    int? idAgent,
    int? idProjet,
    int? annee,
    int? moisNumero,
  }) {
    return fetchMetricsFirst(
      'metrics-agent-public-mois',
      queryParameters: {
        'id_agent': idAgent ?? userId,
        'id_projet': idProjet ?? currentProjetId,
        'annee': annee,
        'mois_numero': moisNumero,
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // ██ ENDPOINTS SPÉCIFIQUES (EP / ASS / ELEC)
  // ══════════════════════════════════════════════════════

  // ── Eau Potable ──
  static Future<List<dynamic>> fetchVannes() => fetchData('ep/vannes');
  static Future<List<dynamic>> fetchVannesVidange() => fetchData('ep/vannes-vidange');
  static Future<List<dynamic>> fetchVentouses() => fetchData('ep/ventouses');
  static Future<List<dynamic>> fetchHydrants() => fetchData('ep/hydrants');
  static Future<List<dynamic>> fetchBornesFontaine() => fetchData('ep/bornes-fontaine');
  static Future<List<dynamic>> fetchBornesOnep() => fetchData('ep/bornes-onep');
  static Future<List<dynamic>> fetchBouchesCles() => fetchData('ep/bouches-cles');
  static Future<List<dynamic>> fetchBouchesArrosage() => fetchData('ep/bouches-arrosage');
  static Future<List<dynamic>> fetchCompteursReseau() => fetchData('ep/compteurs-reseau');
  static Future<List<dynamic>> fetchCompteursAbonne() => fetchData('ep/compteurs-abonne');
  static Future<List<dynamic>> fetchConesReduction() => fetchData('ep/cones-reduction');
  static Future<List<dynamic>> fetchCentresTampon() => fetchData('ep/centres-tampon');
  static Future<List<dynamic>> fetchObturateurs() => fetchData('ep/obturateurs');
  static Future<List<dynamic>> fetchReducteursPression() => fetchData('ep/reducteurs-pression');
  static Future<List<dynamic>> fetchNoeudsEP() => fetchData('ep/noeuds');
  static Future<List<dynamic>> fetchReservoirs() => fetchData('ep/reservoirs');
  static Future<List<dynamic>> fetchStationsPompage() => fetchData('ep/stations-pompage');
  static Future<List<dynamic>> fetchForages() => fetchData('ep/forages');
  static Future<List<dynamic>> fetchPuits() => fetchData('ep/puits');
  static Future<List<dynamic>> fetchPompes() => fetchData('ep/pompes');
  static Future<List<dynamic>> fetchRegardsEP() => fetchData('ep/regards');
  static Future<List<dynamic>> fetchConduitesTerrain() => fetchData('ep/conduites-terrain');
  static Future<List<dynamic>> fetchBranchementsEP() => fetchData('ep/branchements');
  static Future<List<dynamic>> fetchTraverses() => fetchData('ep/traverses');

  // ── Assainissement ──
  static Future<List<dynamic>> fetchRegardsASS() => fetchData('ass/regards');
  static Future<List<dynamic>> fetchRegardsBranchement() => fetchData('ass/regards-branchement');
  static Future<List<dynamic>> fetchCanalisationsASS() => fetchData('ass/canalisations');
  static Future<List<dynamic>> fetchCanalisationsReutilisation() => fetchData('ass/canalisations-reutilisation');
  static Future<List<dynamic>> fetchBranchementsASS() => fetchData('ass/branchements');
  static Future<List<dynamic>> fetchBassins() => fetchData('ass/bassins');
  static Future<List<dynamic>> fetchOuvragesASS() => fetchData('ass/ouvrages');
  static Future<List<dynamic>> fetchEquipementsASS() => fetchData('ass/equipements');
  static Future<List<dynamic>> fetchStationsASS() => fetchData('ass/stations');

  // ── Électricité ──
  static Future<List<dynamic>> fetchSupports() => fetchData('elec/supports');
  static Future<List<dynamic>> fetchPostes() => fetchData('elec/postes');
  static Future<List<dynamic>> fetchCoffretsBT() => fetchData('elec/coffrets-bt');
  static Future<List<dynamic>> fetchNoeudsRaccord() => fetchData('elec/noeuds-raccord');
  static Future<List<dynamic>> fetchPointsDesserte() => fetchData('elec/points-desserte');
  static Future<List<dynamic>> fetchTronconsBT() => fetchData('elec/troncons-bt');
  static Future<List<dynamic>> fetchTronconsHTA() => fetchData('elec/troncons-hta');

  // ── Sync POST générique ──
  static Future<dynamic> syncEntity(
      String schema, String tableName, Map<String, dynamic> data) {
    return postData('$schema/$tableName', data);
  }

  // ══════════════════════════════════════════════════════
  // ██ UTILITAIRES
  // ══════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> uploadLocalHistory({
    List<Map<String, dynamic>> attributes = const [],
    List<Map<String, dynamic>> events = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/api/historique-mobile/upload/');
    final payload = <String, dynamic>{
      'attributes': attributes,
      'events': events,
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
        throw Exception('Reponse historique mobile invalide');
      }

      try {
        final decoded = jsonDecode(body);
        throw Exception(
          decoded['error'] ??
              decoded['detail'] ??
              'Erreur upload historique ${response.statusCode}',
        );
      } catch (_) {
        throw Exception('Erreur upload historique ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Timeout upload historique');
    } on SocketException {
      throw Exception('Erreur reseau upload historique');
    }
  }

  static Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  static String _formatDateParam(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Map<String, dynamic> extractFromGeoJson(
      Map<String, dynamic> geoJson) {
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
    nomPrenom = null;
    currentProjetId = null;
    currentProjetNom = null;
    currentProjetCode = null;
    currentProjetStatut = null;
    currentProjetMetier = null;
    currentProjetRegion = null;
    currentProjetSrm = null;
    currentMissionId = null;
  }
}
