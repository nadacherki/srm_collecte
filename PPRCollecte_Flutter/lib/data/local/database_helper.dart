// lib/data/local/database_helper.dart
// ── SPRINT 3 : DatabaseHelper SRM ──
// Tables SQLite miroirs de PostgreSQL :
//   utilisateur_local → public.utilisateur (id_user, login, mot_de_passe en clair, nom_prenom, role)
//   projet_local      → public.projet      (id_projet, code_affaire, nom, srm, region, metier, statut)
//   mission_local     → public.mission     (id_mission, id_agent, id_projet, etat_mission)
// Version DB: 14

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import '../../core/config/srm_config.dart';
import '../remote/api_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static bool _isInitializing = false;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      try {
        await _database!.rawQuery('SELECT 1');
        return _database!;
      } catch (e) {
        print('❌ Connexion DB invalide, fermeture: $e');
        await _database!.close();
        _database = null;
      }
    }

    if (_isInitializing) {
      await Future.delayed(const Duration(milliseconds: 100));
      return database;
    }

    _isInitializing = true;
    try {
      _database = await _initDatabase();
      return _database!;
    } finally {
      _isInitializing = false;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'srm_collecte.db');
    print('📂 Chemin DB: $path');

    final dbExists = await databaseExists(path);
    print(dbExists ? '📁 DB existante' : '🆕 Nouvelle DB');

    final dbDir = Directory(dbPath);
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 14,
      onCreate: (db, version) async {
        print('🆕 Création tables v$version');
        await _createAllTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print('🔄 Migration $oldVersion → $newVersion');
        // Re-créer les tables SRM si elles n'existent pas
        await _createAllTables(db);
      },
      onOpen: (db) async {
        print('🔌 DB ouverte');
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // ██ CRÉATION DES TABLES
  // ══════════════════════════════════════════════════════

  Future<void> _createAllTables(Database db) async {
    // ── Session SRM ──
    await db.execute('''
      CREATE TABLE IF NOT EXISTS srm_session (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        current_login TEXT,
        last_login TEXT,
        is_logged_in INTEGER DEFAULT 0,
        remember_me INTEGER DEFAULT 0
      )
    ''');
    print('✅ Table srm_session');

    // ── utilisateur_local ──
    // Miroir de public.utilisateur
    // mot_de_passe stocké EN CLAIR (comme dans PostgreSQL)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS utilisateur_local (
        id_user INTEGER PRIMARY KEY,
        login TEXT NOT NULL UNIQUE,
        mot_de_passe TEXT NOT NULL,
        nom_prenom TEXT,
        role TEXT DEFAULT 'editeur_terrain',
        actif INTEGER DEFAULT 1,
        id_projet_actif INTEGER,
        nb_objets_collectes_total INTEGER DEFAULT 0,
        date_creation TEXT,
        dernier_login TEXT
      )
    ''');
    print('✅ Table utilisateur_local');

    // ── projet_local ──
    // Miroir de public.projet
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projet_local (
        id_projet INTEGER PRIMARY KEY,
        code_affaire TEXT,
        nom TEXT,
        srm TEXT,
        region TEXT,
        metier TEXT,
        statut TEXT DEFAULT 'EN_PREPARATION',
        date_debut TEXT,
        date_fin TEXT,
        date_sync TEXT
      )
    ''');
    print('✅ Table projet_local');

    // ── mission_local ──
    // Miroir de public.mission
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mission_local (
        id_mission INTEGER PRIMARY KEY,
        id_agent INTEGER,
        id_projet INTEGER NOT NULL,
        etat_mission TEXT DEFAULT 'EN_COURS',
        date_debut TEXT,
        date_fin TEXT,
        heure_debut TEXT,
        heure_fin TEXT,
        nb_objets_collectes INTEGER DEFAULT 0,
        nb_objets_incomplets INTEGER DEFAULT 0,
        nb_photos_prises INTEGER DEFAULT 0,
        date_sync TEXT,
        FOREIGN KEY (id_projet) REFERENCES projet_local(id_projet)
      )
    ''');
    print('✅ Table mission_local');

    // ── Métadonnées ──
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    print('✅ Table app_metadata');

    print('🎉 Toutes les tables SRM créées !');
  }

  // ══════════════════════════════════════════════════════
  // ██ UTILISATEUR SRM (login + mot_de_passe en clair)
  // ══════════════════════════════════════════════════════

  /// Insert ou update un utilisateur SRM
  Future<int> upsertUserSrm({
    required String login,
    required String motDePasse,
    String? nomPrenom,
    String? role,
    int? apiId,
    int? idProjetActif,
  }) async {
    final db = await database;
    try {
      return await db.insert(
        'utilisateur_local',
        {
          'id_user': apiId,
          'login': login,
          'mot_de_passe': motDePasse, // en clair
          'nom_prenom': nomPrenom,
          'role': role ?? 'editeur_terrain',
          'id_projet_actif': idProjetActif,
          'dernier_login': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Erreur upsertUserSrm: $e');
      return -1;
    }
  }

  /// Valide un login/mot_de_passe en local (mode offline)
  /// Comparaison en clair comme côté serveur :
  ///   if mot_de_passe != user.mot_de_passe
  Future<bool> validateUser(String login, String password) async {
    try {
      final db = await database;
      final result = await db.query(
        'utilisateur_local',
        where: 'login = ? AND mot_de_passe = ?',
        whereArgs: [login, password], // comparaison en clair
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      print('❌ Erreur validateUser: $e');
      return false;
    }
  }

  /// Récupère l'utilisateur SRM courant depuis SQLite
  Future<Map<String, dynamic>?> getCurrentUserSrm() async {
    try {
      final db = await database;
      final session = await db.query('srm_session', limit: 1);
      if (session.isEmpty) return null;

      final login = session.first['current_login'] as String?;
      if (login == null || login.isEmpty) return null;

      final user = await db.query(
        'utilisateur_local',
        where: 'login = ?',
        whereArgs: [login],
        limit: 1,
      );
      return user.isNotEmpty ? user.first : null;
    } catch (e) {
      print('❌ Erreur getCurrentUserSrm: $e');
      return null;
    }
  }

  /// Nom complet de l'agent
  Future<String?> getAgentFullName(String login) async {
    try {
      final db = await database;
      final result = await db.query(
        'utilisateur_local',
        columns: ['nom_prenom'],
        where: 'login = ?',
        whereArgs: [login],
        limit: 1,
      );
      if (result.isNotEmpty) {
        return result.first['nom_prenom'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Erreur getAgentFullName: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ SESSION SRM
  // ══════════════════════════════════════════════════════

  Future<void> setCurrentUserLogin(String login,
      {required bool remember}) async {
    try {
      final db = await database;
      final existing = await db.query('srm_session', limit: 1);
      final values = {
        'current_login': login,
        'last_login': DateTime.now().toIso8601String(),
        'is_logged_in': 1,
        'remember_me': remember ? 1 : 0,
      };

      if (existing.isEmpty) {
        await db.insert('srm_session', values);
      } else {
        await db.update('srm_session', values,
            where: 'id = ?', whereArgs: [existing.first['id']]);
      }
      print('✅ Session: $login | remember=$remember');
    } catch (e) {
      print('❌ Erreur setCurrentUserLogin: $e');
    }
  }

  /// Retourne le login remembered (pour pré-remplir le formulaire)
  Future<String?> getCurrentUserLogin() async {
    try {
      final db = await database;
      final result = await db.query('srm_session', limit: 1);
      if (result.isNotEmpty) {
        final row = result.first;
        final remember = _toInt(row['remember_me']);
        if (remember == 1) {
          return row['current_login'] as String?;
        }
      }
      return null;
    } catch (e) {
      print('❌ Erreur getCurrentUserLogin: $e');
      return null;
    }
  }

  /// Retourne le login de la session active (pas forcément remembered)
  Future<String?> getSessionLogin() async {
    try {
      final db = await database;
      final result = await db.query('srm_session', limit: 1);
      if (result.isNotEmpty) {
        final isLogged = _toInt(result.first['is_logged_in']);
        if (isLogged == 1) {
          return result.first['current_login'] as String?;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> clearSrmSession() async {
    try {
      final db = await database;
      final rows = await db.query('srm_session', limit: 1);
      if (rows.isEmpty) return;

      final row = rows.first;
      final remember = _toInt(row['remember_me']);

      if (remember == 1) {
        // Garder le login remembered, couper la session
        await db.update('srm_session', {'is_logged_in': 0},
            where: 'id = ?', whereArgs: [row['id']]);
      } else {
        await db.delete('srm_session');
      }
      print('✅ Session SRM effacée');
    } catch (e) {
      print('❌ Erreur clearSrmSession: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ PROJETS LOCAL
  // ══════════════════════════════════════════════════════

  /// Insert/update un projet (depuis l'API ou le login)
  Future<void> upsertProjetLocal({
    required int idProjet,
    String? nom,
    String? codeAffaire,
    String? srm,
    String? region,
    String? metier,
    String? statut,
  }) async {
    final db = await database;
    await db.insert(
      'projet_local',
      {
        'id_projet': idProjet,
        'code_affaire': codeAffaire,
        'nom': nom,
        'srm': srm,
        'region': region,
        'metier': metier,
        'statut': statut,
        'date_sync': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Sauvegarde une liste de projets (depuis GET /api/projets/)
  Future<void> saveProjetsLocal(
      List<Map<String, dynamic>> projets) async {
    final db = await database;
    final batch = db.batch();
    for (final p in projets) {
      batch.insert(
        'projet_local',
        {
          'id_projet': p['id_projet'],
          'code_affaire': p['code_affaire'],
          'nom': p['nom'],
          'srm': p['srm'],
          'region': p['region'],
          'metier': p['metier'],
          'statut': p['statut'],
          'date_debut': p['date_debut'],
          'date_fin': p['date_fin'],
          'date_sync': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    print('✅ ${projets.length} projets sauvegardés');
  }

  Future<List<Map<String, dynamic>>> getProjetsLocal() async {
    final db = await database;
    return await db.query('projet_local', orderBy: 'nom ASC');
  }

  Future<Map<String, dynamic>?> getProjetLocal(int idProjet) async {
    final db = await database;
    final result = await db.query(
      'projet_local',
      where: 'id_projet = ?',
      whereArgs: [idProjet],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ══════════════════════════════════════════════════════
  // ██ MISSIONS LOCAL
  // ══════════════════════════════════════════════════════

  /// Sauvegarde les missions (depuis GET /api/missions/)
  Future<void> saveMissionsLocal(
      List<Map<String, dynamic>> missions, int projetId) async {
    final db = await database;
    final batch = db.batch();
    for (final m in missions) {
      batch.insert(
        'mission_local',
        {
          'id_mission': m['id_mission'],
          'id_agent': m['id_agent'],
          'id_projet': projetId,
          'etat_mission': m['etat_mission'],
          'date_debut': m['date_debut'],
          'date_fin': m['date_fin'],
          'heure_debut': m['heure_debut'],
          'heure_fin': m['heure_fin'],
          'nb_objets_collectes': m['nb_objets_collectes'] ?? 0,
          'nb_objets_incomplets': m['nb_objets_incomplets'] ?? 0,
          'nb_photos_prises': m['nb_photos_prises'] ?? 0,
          'date_sync': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    print('✅ ${missions.length} missions sauvegardées (projet $projetId)');
  }

  Future<List<Map<String, dynamic>>> getMissionsLocal(
      int projetId) async {
    final db = await database;
    return await db.query(
      'mission_local',
      where: 'id_projet = ?',
      whereArgs: [projetId],
      orderBy: 'id_mission DESC',
    );
  }

  // ══════════════════════════════════════════════════════
  // ██ UTILITAIRES
  // ══════════════════════════════════════════════════════

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// Résout le login_id (= id_user) pour les FK dans les entités
  Future<int?> resolveLoginId() async {
    // Priorité 1 : ApiService (en mémoire)
    if (ApiService.userId != null && ApiService.userId! > 0) {
      return ApiService.userId;
    }
    // Priorité 2 : session SQLite
    try {
      final user = await getCurrentUserSrm();
      if (user != null) {
        final v = user['id_user'];
        if (v is int && v > 0) return v;
      }
    } catch (_) {}
    return null;
  }

  Future<int> insertEntity(
      String tableName, Map<String, dynamic> data) async {
    final db = await database;
    final enriched = {
      ...data,
      'id_agent_crea': await resolveLoginId(),
      'id_projet': ApiService.currentProjetId,
      'id_mission': ApiService.currentMissionId,
    };
    final id = await db.insert(tableName, enriched);
    print('✅ Entité insérée dans $tableName (ID: $id)');
    return id;
  }

  Future<List<Map<String, dynamic>>> getEntities(
      String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }

  // ══════════════════════════════════════════════════════
  // ██ ENTITÉS SRM (EP / ASS / ELEC) — SPRINT 5
  // ══════════════════════════════════════════════════════

  /// Crée la table SQLite pour une entité SRM si elle n'existe pas.
  /// Structure générique : id + tous les champs en TEXT ou REAL + FK SRM.
  Future<void> ensureEntityTable(String tableName, List<String> fields) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    // Vérifier si la table existe déjà
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName]);
    if (tables.isNotEmpty) return; // déjà créée

    // Colonnes fixes SRM communes à toutes les entités
    const fixedCols = '''
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT UNIQUE,
      id_projet INTEGER,
      id_mission INTEGER,
      id_agent_crea INTEGER,
      id_planche INTEGER,
      id_commune INTEGER,
      latitude_gps REAL,
      longitude_gps REAL,
      altitude_gps REAL,
      x_debut REAL,
      y_debut REAL,
      x_fin REAL,
      y_fin REAL,
      lat_debut REAL,
      lon_debut REAL,
      lat_fin REAL,
      lon_fin REAL,
      nb_points INTEGER DEFAULT 0,
      distance_m REAL DEFAULT 0,
      points_json TEXT,
      anomalie INTEGER DEFAULT 0,
      type_anomalie TEXT,
      photo_1 TEXT,
      photo_2 TEXT,
      photo_3 TEXT,
      photo_4 TEXT,
      mode_localisation TEXT DEFAULT 'GPS',
      synced INTEGER DEFAULT 0,
      date_collecte TEXT,
      date_sync TEXT
    ''';

    // Colonnes dynamiques depuis srm_config.dart (fields)
    final dynamicCols = fields
        .where(_isAllowedSrmColumn)
        .where((f) => !_isFixedCol(f))
        .map((f) => '  $f ${_sqliteTypeForField(f)}')
        .join(',\n');

    final sql = '''
      CREATE TABLE IF NOT EXISTS $tableName (
        $fixedCols
        ${dynamicCols.isNotEmpty ? ',$dynamicCols' : ''}
      )
    ''';

    await db.execute(sql);
    print('✅ Table SRM créée: $tableName (${fields.length} champs)');
  }

  bool _isFixedCol(String col) {
    const fixed = {
      'id', 'uuid', 'id_projet', 'id_mission', 'id_agent_crea',
      'id_planche', 'id_commune', 'latitude_gps', 'longitude_gps',
      'altitude_gps', 'x_debut', 'y_debut', 'x_fin', 'y_fin',
      'lat_debut', 'lon_debut', 'lat_fin', 'lon_fin',
      'nb_points', 'distance_m', 'points_json',
      'anomalie', 'type_anomalie',
      'photo_1', 'photo_2', 'photo_3', 'photo_4',
      'mode_localisation', 'synced', 'date_collecte', 'date_sync',
    };
    return fixed.contains(col);
  }

  /// Insert une entité SRM dans sa table (crée la table si besoin).
  Future<int> insertEntitySrm(
      String tableName, Map<String, dynamic> data) async {
    _assertAllowedSrmTable(tableName);
    // Récupérer les champs depuis la config (pour créer la table)
    final fields = data.keys.toList();
    await ensureEntityTable(tableName, fields);

    final db = await database;
    // Nettoyer les valeurs null pour éviter les erreurs SQLite
    final cleaned = _sanitizeSrmPayload(tableName, data);

    try {
      final id = await db.insert(
        tableName,
        cleaned,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ SRM insertEntitySrm → $tableName (ID: $id)');
      return id;
    } catch (e) {
      // Si la colonne n'existe pas encore, ajouter dynamiquement
      if (e.toString().contains('no such column')) {
        await _addMissingColumns(tableName, cleaned.keys.toList());
        final id = await db.insert(tableName, cleaned,
            conflictAlgorithm: ConflictAlgorithm.replace);
        return id;
      }
      rethrow;
    }
  }

  /// Ajoute les colonnes manquantes dans une table existante.
  Future<void> _addMissingColumns(
      String tableName, List<String> fields) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    final existing = await db.rawQuery('PRAGMA table_info($tableName)');
    final existingCols = existing.map((r) => r['name'] as String).toSet();

    for (final key in fields.where(_isAllowedSrmColumn)) {
      if (!existingCols.contains(key) && !_isFixedCol(key)) {
        try {
          await db.execute(
            'ALTER TABLE $tableName ADD COLUMN $key ${_sqliteTypeForField(key)}',
          );
          print('✅ Colonne ajoutée: $tableName.$key');
        } catch (_) {}
      }
    }
  }

  /// Met à jour une entité SRM.
  Future<void> updateEntitySrm(
      String tableName, int id, Map<String, dynamic> data) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    await _addMissingColumns(tableName, data.keys.toList());
    final cleaned = _sanitizeSrmPayload(tableName, data);
    await db.update(tableName, cleaned, where: 'id = ?', whereArgs: [id]);
    print('✅ SRM updateEntitySrm → $tableName id=$id');
  }

  /// Supprime une entité SRM.
  Future<void> deleteEntitySrm(String tableName, int id) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    print('✅ SRM deleteEntitySrm → $tableName id=$id');
  }

  /// Récupère toutes les entités d'une table SRM.
  Future<List<Map<String, dynamic>>> getEntitiesSrm(
      String tableName) async {
    try {
      _assertAllowedSrmTable(tableName);
      final db = await database;
      // Vérifier que la table existe
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName]);
      if (tables.isEmpty) return [];
      return await db.query(tableName, orderBy: 'id DESC');
    } catch (e) {
      print('❌ getEntitiesSrm $tableName: $e');
      return [];
    }
  }

  /// Récupère les entités non synchronisées d'une table SRM.
  Future<List<Map<String, dynamic>>> getUnsyncedSrm(
      String tableName) async {
    try {
      _assertAllowedSrmTable(tableName);
      final db = await database;
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName]);
      if (tables.isEmpty) return [];
      return await db.query(tableName,
          where: 'synced = ?', whereArgs: [0], orderBy: 'id ASC');
    } catch (e) {
      print('❌ getUnsyncedSrm $tableName: $e');
      return [];
    }
  }

  /// Marque une entité comme synchronisée.
  Future<void> markSyncedSrm(String tableName, int id) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    await db.update(tableName, {'synced': 1, 'date_sync': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Set<String> _allowedSrmTables() {
    final tables = <String>{};
    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        final tableName = SrmConfig.getTableName(metier, entity);
        if (tableName != null && tableName.isNotEmpty) {
          tables.add(tableName);
        }
      }
    }
    return tables;
  }

  Set<String> _allowedSrmColumns() {
    final columns = <String>{..._fixedSrmColumns};
    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        columns.addAll(SrmConfig.getFields(metier, entity));
      }
    }
    return columns;
  }

  static const Set<String> _fixedSrmColumns = {
    'id', 'uuid', 'id_projet', 'id_mission', 'id_agent_crea',
    'id_planche', 'id_commune', 'latitude_gps', 'longitude_gps',
    'altitude_gps', 'x_debut', 'y_debut', 'x_fin', 'y_fin',
    'lat_debut', 'lon_debut', 'lat_fin', 'lon_fin',
    'nb_points', 'distance_m', 'points_json', 'altitude_z_moy',
    'anomalie', 'type_anomalie',
    'photo_1', 'photo_2', 'photo_3', 'photo_4',
    'mode_localisation', 'synced', 'date_collecte', 'date_sync',
  };

  void _assertAllowedSrmTable(String tableName) {
    if (!_allowedSrmTables().contains(tableName)) {
      throw Exception('Table SRM non autorisée: $tableName');
    }
  }

  bool _isAllowedSrmColumn(String column) {
    return _allowedSrmColumns().contains(column);
  }

  String _sqliteTypeForField(String field) {
    if (_fixedSrmColumns.contains(field)) {
      switch (field) {
        case 'id':
        case 'id_projet':
        case 'id_mission':
        case 'id_agent_crea':
        case 'id_planche':
        case 'id_commune':
        case 'nb_points':
        case 'anomalie':
        case 'synced':
          return 'INTEGER';
        case 'latitude_gps':
        case 'longitude_gps':
        case 'altitude_gps':
        case 'altitude_z_moy':
        case 'x_debut':
        case 'y_debut':
        case 'x_fin':
        case 'y_fin':
        case 'lat_debut':
        case 'lon_debut':
        case 'lat_fin':
        case 'lon_fin':
        case 'distance_m':
          return 'REAL';
        default:
          return 'TEXT';
      }
    }

    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        final fields = SrmConfig.getFields(metier, entity);
        if (fields.contains(field)) {
          final rule = SrmConfig.getFieldRule(metier, entity, field);
          switch (rule.kind) {
            case SrmFieldKind.integer:
            case SrmFieldKind.booleanLike:
              return 'INTEGER';
            case SrmFieldKind.decimal:
              return 'REAL';
            case SrmFieldKind.date:
            case SrmFieldKind.uuid:
            case SrmFieldKind.enumValue:
            case SrmFieldKind.text:
              return 'TEXT';
          }
        }
      }
    }
    return 'TEXT';
  }

  Map<String, dynamic> _sanitizeSrmPayload(
    String tableName,
    Map<String, dynamic> data,
  ) {
    _assertAllowedSrmTable(tableName);
    final cleaned = <String, dynamic>{};
    for (final entry in data.entries) {
      if (!_isAllowedSrmColumn(entry.key)) {
        continue;
      }
      if (entry.value != null) {
        cleaned[entry.key] = entry.value;
      }
    }
    return cleaned;
  }

  Future<void> saveLastSyncTime(DateTime dt) async {
    final db = await database;
    await db.insert(
      'app_metadata',
      {'key': 'last_sync_time', 'value': dt.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> getLastSyncTime() async {
    final db = await database;
    final res = await db.query('app_metadata',
        where: 'key = ?', whereArgs: ['last_sync_time'], limit: 1);
    if (res.isEmpty) return null;
    final raw = res.first['value'] as String?;
    if (raw == null) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> resetDatabase() async {
    try {
      final db = await database;
      await db.close();
      _database = null;
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'srm_collecte.db');
      if (await databaseExists(path)) {
        await deleteDatabase(path);
      }
      print('✅ DB réinitialisée');
    } catch (e) {
      print('❌ Erreur resetDatabase: $e');
    }
  }
}
