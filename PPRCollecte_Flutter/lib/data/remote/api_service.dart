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

  // ── Mission (choisi/créé après login) ──
  static int? currentMissionId; // id_mission

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
      String endpoint, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$baseUrl/api/$endpoint/');

      // Injecter automatiquement le contexte SRM dans chaque requête
      if (currentProjetId != null && !data.containsKey('id_projet')) {
        data['id_projet'] = currentProjetId;
      }
      if (currentMissionId != null && !data.containsKey('id_mission')) {
        data['id_mission'] = currentMissionId;
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
        return null;
      }
    } on TimeoutException catch (e) {
      print('⏰ Timeout $endpoint: $e');
      return null;
    } on SocketException catch (e) {
      print('📡 Erreur réseau $endpoint: $e');
      return null;
    } catch (e) {
      print('❌ Exception $endpoint: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ GET GÉNÉRIQUE (GeoJSON / liste)
  // ══════════════════════════════════════════════════════

  /// Ex : fetchData('ep/vannes') → GET /api/ep/vannes/?id_projet=1
  static Future<List<dynamic>> fetchData(String endpoint) async {
    final params = <String, String>{};
    if (currentProjetId != null) {
      params['id_projet'] = currentProjetId.toString();
    }
    if (currentMissionId != null) {
      params['id_mission'] = currentMissionId.toString();
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

  // ══════════════════════════════════════════════════════
  // ██ ENDPOINTS SPÉCIFIQUES (EP / ASS / ELEC)
  // ══════════════════════════════════════════════════════

  // ── Eau Potable ──
  static Future<List<dynamic>> fetchVannes() => fetchData('ep/vannes');
  static Future<List<dynamic>> fetchVannesVidange() => fetchData('ep/vannes_vidange');
  static Future<List<dynamic>> fetchVentouses() => fetchData('ep/ventouses');
  static Future<List<dynamic>> fetchHydrants() => fetchData('ep/hydrants');
  static Future<List<dynamic>> fetchBornesFontaine() => fetchData('ep/bornes_fontaine');
  static Future<List<dynamic>> fetchBornesOnep() => fetchData('ep/bornes_onep');
  static Future<List<dynamic>> fetchBouchesCles() => fetchData('ep/bouches_cles');
  static Future<List<dynamic>> fetchBouchesArrosage() => fetchData('ep/bouches_arrosage');
  static Future<List<dynamic>> fetchCompteursReseau() => fetchData('ep/compteurs_reseau');
  static Future<List<dynamic>> fetchCompteursAbonne() => fetchData('ep/compteurs_abonne');
  static Future<List<dynamic>> fetchConesReduction() => fetchData('ep/cones_reduction');
  static Future<List<dynamic>> fetchCentresTampon() => fetchData('ep/centres_tampon');
  static Future<List<dynamic>> fetchObturateurs() => fetchData('ep/obturateurs');
  static Future<List<dynamic>> fetchReducteursPression() => fetchData('ep/reducteurs_pression');
  static Future<List<dynamic>> fetchNoeudsEP() => fetchData('ep/noeuds');
  static Future<List<dynamic>> fetchReservoirs() => fetchData('ep/reservoirs');
  static Future<List<dynamic>> fetchStationsPompage() => fetchData('ep/stations_pompage');
  static Future<List<dynamic>> fetchForages() => fetchData('ep/forages');
  static Future<List<dynamic>> fetchPuits() => fetchData('ep/puits');
  static Future<List<dynamic>> fetchPompes() => fetchData('ep/pompes');
  static Future<List<dynamic>> fetchRegardsEP() => fetchData('ep/regards');
  static Future<List<dynamic>> fetchConduitesTerrain() => fetchData('ep/conduites_terrain');
  static Future<List<dynamic>> fetchBranchementsEP() => fetchData('ep/branchements');
  static Future<List<dynamic>> fetchTraverses() => fetchData('ep/traverses');

  // ── Assainissement ──
  static Future<List<dynamic>> fetchRegardsASS() => fetchData('ass/regards');
  static Future<List<dynamic>> fetchRegardsBranchement() => fetchData('ass/regards_branchement');
  static Future<List<dynamic>> fetchCanalisationsASS() => fetchData('ass/canalisations');
  static Future<List<dynamic>> fetchCanalisationsReutilisation() => fetchData('ass/canalisations_reutilisation');
  static Future<List<dynamic>> fetchBranchementsASS() => fetchData('ass/branchements');
  static Future<List<dynamic>> fetchBassins() => fetchData('ass/bassins');
  static Future<List<dynamic>> fetchOuvragesASS() => fetchData('ass/ouvrages');
  static Future<List<dynamic>> fetchEquipementsASS() => fetchData('ass/equipements');
  static Future<List<dynamic>> fetchStationsASS() => fetchData('ass/stations');

  // ── Électricité ──
  static Future<List<dynamic>> fetchSupports() => fetchData('elec/supports');
  static Future<List<dynamic>> fetchPostes() => fetchData('elec/postes');
  static Future<List<dynamic>> fetchCoffretsBT() => fetchData('elec/coffrets_bt');
  static Future<List<dynamic>> fetchNoeudsRaccord() => fetchData('elec/noeuds_raccord');
  static Future<List<dynamic>> fetchPointsDesserte() => fetchData('elec/points_desserte');
  static Future<List<dynamic>> fetchTronconsBT() => fetchData('elec/troncons_bt');
  static Future<List<dynamic>> fetchTronconsHTA() => fetchData('elec/troncons_hta');

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
      };

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
    currentMissionId = null;
    currentProjetNom = null;
    currentProjetCode = null;
    currentProjetStatut = null;
    currentProjetMetier = null;
    currentProjetRegion = null;
    currentProjetSrm = null;
  }
}
