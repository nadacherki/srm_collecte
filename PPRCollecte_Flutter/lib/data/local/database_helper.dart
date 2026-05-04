// lib/data/local/database_helper.dart
// ── SPRINT 3 : DatabaseHelper SRM ──
// Tables SQLite miroirs de PostgreSQL :
//   utilisateur_local → public.utilisateur (id_user, login, mot_de_passe en clair, nom, prenom, role)
// Version DB: 18

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/srm_config.dart';
import '../remote/api_service.dart';
import '../../services/draft_service.dart';
import '../../services/password_hash_service.dart';

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
        debugPrint('❌ Connexion DB invalide, fermeture: $e');
        await _database!.close();
        _database = null;
      }
    }

    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_database != null) return _database!;
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
    debugPrint('📂 Chemin DB: $path');

    final dbExists = await databaseExists(path);
    debugPrint(dbExists ? '📁 DB existante' : '🆕 Nouvelle DB');

    final dbDir = Directory(dbPath);
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    return await openDatabase(
      path,
      version: 18,
      onCreate: (db, version) async {
        debugPrint('🆕 Création tables v$version');
        await _createAllTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('🔄 Migration $oldVersion → $newVersion');
        await _createAllTables(db);
      },
      onOpen: (db) async {
        debugPrint('🔌 DB ouverte');
        await _migrateExistingSrmTables(db);
        await _createConduiteSyncQueueTable(db);
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
    debugPrint('✅ Table srm_session');

    // ── utilisateur_local ──
    // Miroir de public.utilisateur
    // mot_de_passe stocké EN CLAIR (comme dans PostgreSQL)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS utilisateur_local (
        id_user INTEGER PRIMARY KEY,
        login TEXT NOT NULL UNIQUE,
        mot_de_passe TEXT NOT NULL,
        nom TEXT,
        prenom TEXT,
        role TEXT DEFAULT 'editeur_terrain',
        actif INTEGER DEFAULT 1,
        nb_objets_collectes_total INTEGER DEFAULT 0,
        date_creation TEXT,
        dernier_login TEXT
      )
    ''');
    debugPrint('✅ Table utilisateur_local');

    // ── Métadonnées ──
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    debugPrint('✅ Table app_metadata');

    await _createPhotoSyncQueueTable(db);
    await _createConduiteSyncQueueTable(db);
    await _createLocalHistoryTable(db);
    await _createLocalEventHistoryTable(db);
    await _createOfflineBasemapZoneTable(db);
    await _createOfflineBasemapPackageTable(db);
    await _createSrmFieldOptionLocalTable(db);
    await _createCommuneLocalTable(db);
    await _createZoneLocalTables(db);
    await _ensureInterventionAnomalieTerrainTable(db);
    await _createAllSrmEntityTables(db);

    // ── SPRINT 7 : Table brouillons automatiques ──
    await DraftService.createTable(db);

    debugPrint('🎉 Toutes les tables SRM créées !');
  }

  Future<void> _migrateExistingSrmTables(Database db) async {
    await _ensureUtilisateurLocalColumns(db);
    await _ensureSrmFieldOptionLocalTable(db);
    await _ensureCommuneLocalTable(db);
    await _migrateZoneLocalTables(db);
    await _ensureInterventionAnomalieTerrainTable(db);
    await _createAllSrmEntityTables(db);
    await _createPhotoSyncQueueTable(db);
    await _createLocalHistoryTable(db);
    await _createLocalEventHistoryTable(db);
    await _createOfflineBasemapZoneTable(db);
    await _createOfflineBasemapPackageTable(db);
    // ── SPRINT 7 : S'assurer que la table brouillons existe ──
    await _migrateLocalHistoryTables(db);
    await _migrateOfflineBasemapTables(db);
    await DraftService.createTable(db);
    // ── Migration spécifique : table objet_incomplet ──
    await _ensureObjetIncompletTable(db);
    await _migratePhotoSyncQueueTable(db);
    for (final tableName in _allowedSrmTables()) {
      if (tableName == 'objet_incomplet' || tableName == 'raison_incomplet') {
        continue; // gérées séparément
      }
      try {
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName],
        );
        if (tables.isEmpty) continue;
        await _ensureSrmFixedColumns(db, tableName);
      } catch (e) {
        debugPrint('⚠️ Migration SRM ignorée pour $tableName: $e');
      }
    }
  }

  /// Crée ou migre la table objet_incomplet avec les colonnes PostgreSQL exactes
  Future<void> _ensureObjetIncompletTable(Database db) async {
    // Créer la table si elle n'existe pas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS objet_incomplet (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_incomplet INTEGER,
        nom_table TEXT,
        id_objet INTEGER,
        detail_raison TEXT,
        date_signalement TEXT,
        id_agent_incomplet INTEGER,
        statut TEXT DEFAULT 'A_COMPLETER',
        date_completion TEXT,
        id_agent_completement INTEGER,
        synced INTEGER DEFAULT 0,
        downloaded INTEGER DEFAULT 0,
        date_collecte TEXT,
        date_sync TEXT
      )
    ''');

    // Migrer les colonnes manquantes si la table existait déjà sans elles
    final colonnesMigration = {
      'id_incomplet': 'INTEGER',
      'nom_table': 'TEXT',
      'id_objet': 'INTEGER',
      'detail_raison': 'TEXT',
      'date_signalement': 'TEXT',
      'id_agent_incomplet': 'INTEGER',
      'statut': "TEXT DEFAULT 'A_COMPLETER'",
      'date_completion': 'TEXT',
      'id_agent_completement': 'INTEGER',
      'synced': 'INTEGER DEFAULT 0',
      'downloaded': 'INTEGER DEFAULT 0',
      'date_collecte': 'TEXT',
      'date_sync': 'TEXT',
    };

    final existing = await db.rawQuery('PRAGMA table_info(objet_incomplet)');
    final existingCols = existing.map((r) => r['name'] as String).toSet();

    for (final entry in colonnesMigration.entries) {
      if (existingCols.contains(entry.key)) continue;
      try {
        await db.execute(
          'ALTER TABLE objet_incomplet ADD COLUMN ${entry.key} ${entry.value}',
        );
        debugPrint('✅ Col ajoutée objet_incomplet.${entry.key}');
      } catch (e) {
        debugPrint('⚠️ objet_incomplet.${entry.key}: $e');
      }
    }

    try {
      await db.execute('''
        UPDATE objet_incomplet
        SET nom_table = nom_classe
        WHERE (nom_table IS NULL OR trim(nom_table) = '')
          AND nom_classe IS NOT NULL
          AND trim(nom_classe) <> ''
      ''');
    } catch (_) {
      // nom_classe n'existe pas sur les installations neuves.
    }
    await _normalizeLocalObjetIncompletNomTable(db);
  }

  Future<void> _normalizeLocalObjetIncompletNomTable(Database db) async {
    final rows = await db.query(
      'objet_incomplet',
      columns: ['id', 'nom_table'],
      where: "nom_table IS NOT NULL AND trim(nom_table) <> ''",
    );
    for (final row in rows) {
      final id = row['id'];
      final nomTable = row['nom_table']?.toString().trim() ?? '';
      if (nomTable.isEmpty || nomTable.contains('.')) continue;
      final normalized = _objetIncompletNomTable(nomTable);
      if (normalized == nomTable) continue;
      await db.update(
        'objet_incomplet',
        {'nom_table': normalized, 'synced': 0, 'date_sync': null},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _ensureInterventionAnomalieTerrainTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS intervention_anomalie (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_intervention INTEGER NOT NULL UNIQUE,
        id_objet INTEGER,
        nom_classe TEXT,
        nom_table TEXT,
        uuid_objet TEXT,
        retour_terrain INTEGER DEFAULT 0,
        statut TEXT,
        responsable_actuel TEXT,
        etat_terrain TEXT DEFAULT 'en_attente',
        commentaire_terrain TEXT,
        date_terrain TEXT,
        id_user_terrain INTEGER,
        date_creation TEXT,
        date_cloture TEXT,
        created_at TEXT,
        updated_at TEXT,
        synced INTEGER DEFAULT 1,
        downloaded INTEGER DEFAULT 1,
        date_collecte TEXT,
        date_sync TEXT,
        last_error TEXT
      )
    ''');

    final colonnesMigration = {
      'id_intervention': 'INTEGER',
      'id_objet': 'INTEGER',
      'nom_classe': 'TEXT',
      'nom_table': 'TEXT',
      'uuid_objet': 'TEXT',
      'retour_terrain': 'INTEGER DEFAULT 0',
      'statut': 'TEXT',
      'responsable_actuel': 'TEXT',
      'etat_terrain': "TEXT DEFAULT 'en_attente'",
      'commentaire_terrain': 'TEXT',
      'date_terrain': 'TEXT',
      'id_user_terrain': 'INTEGER',
      'date_creation': 'TEXT',
      'date_cloture': 'TEXT',
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
      'synced': 'INTEGER DEFAULT 1',
      'downloaded': 'INTEGER DEFAULT 1',
      'date_collecte': 'TEXT',
      'date_sync': 'TEXT',
      'last_error': 'TEXT',
    };

    final existing =
        await db.rawQuery('PRAGMA table_info(intervention_anomalie)');
    final existingCols = existing.map((r) => r['name'] as String).toSet();

    for (final entry in colonnesMigration.entries) {
      if (existingCols.contains(entry.key)) continue;
      try {
        await db.execute(
          'ALTER TABLE intervention_anomalie ADD COLUMN ${entry.key} ${entry.value}',
        );
        debugPrint('âœ… Col ajoutÃ©e intervention_anomalie.${entry.key}');
      } catch (e) {
        debugPrint('âš ï¸ intervention_anomalie.${entry.key}: $e');
      }
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_intervention_anomalie_statut
      ON intervention_anomalie(statut)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_intervention_anomalie_id_intervention
      ON intervention_anomalie(id_intervention)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_intervention_anomalie_objet
      ON intervention_anomalie(nom_table, id_objet)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_intervention_anomalie_uuid
      ON intervention_anomalie(uuid_objet)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_intervention_anomalie_sync
      ON intervention_anomalie(synced, updated_at)
    ''');
  }

  Future<void> _createPhotoSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS photo_sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schema_name TEXT NOT NULL,
        table_name TEXT NOT NULL,
        uuid_objet TEXT NOT NULL,
        photo_slot INTEGER NOT NULL,
        local_path TEXT NOT NULL,
        remote_path TEXT,
        date_prise_reelle TEXT,
        id_agent_crea INTEGER,
        synced INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT,
        updated_at TEXT,
        UNIQUE(schema_name, table_name, uuid_objet, photo_slot)
      )
    ''');
  }

  Future<void> _createConduiteSyncQueueTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conduite_sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_uuid TEXT NOT NULL UNIQUE,
        metier TEXT NOT NULL,
        id_agent INTEGER NOT NULL,
        jour TEXT NOT NULL,
        nodes_json TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT,
        updated_at TEXT,
        date_sync TEXT
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS conduite_sync_queue_day_idx
      ON conduite_sync_queue (metier, id_agent, jour)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS conduite_sync_queue_synced_idx
      ON conduite_sync_queue (synced, updated_at)
    ''');
  }

  Future<void> _createLocalHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS historique_local_attribut (
        id_historique_local INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_uuid TEXT,
        id_objet INTEGER,
        cle_ligne TEXT,
        uuid_objet TEXT,
        nom_schema TEXT,
        nom_table TEXT NOT NULL,
        nom_classe TEXT NOT NULL,
        nom_attribut TEXT NOT NULL,
        ancienne_valeur TEXT,
        nouvelle_valeur TEXT,
        date_action TEXT NOT NULL,
        id_agent INTEGER,
        type_action TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        date_sync TEXT,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS historique_local_date_action_idx
      ON historique_local_attribut (date_action DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS historique_local_schema_table_idx
      ON historique_local_attribut (nom_schema, nom_table)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS historique_local_uuid_objet_idx
      ON historique_local_attribut (uuid_objet)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS historique_local_cle_ligne_idx
      ON historique_local_attribut (cle_ligne)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS historique_local_synced_idx
      ON historique_local_attribut (synced, date_action DESC)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS historique_local_sync_uuid_idx
      ON historique_local_attribut (sync_uuid)
    ''');
  }

  Future<void> _createLocalEventHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS historique_local_evenement (
        id_evenement_local INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_uuid TEXT,
        type_evenement TEXT NOT NULL,
        nom_schema TEXT,
        nom_table TEXT,
        cle_ligne TEXT,
        uuid_objet TEXT,
        id_objet INTEGER,
        id_agent INTEGER,
        payload_json TEXT,
        date_action TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        date_sync TEXT,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS historique_local_evt_date_idx
      ON historique_local_evenement (date_action DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS historique_local_evt_type_idx
      ON historique_local_evenement (type_evenement)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS historique_local_evt_table_idx
      ON historique_local_evenement (nom_schema, nom_table)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS historique_local_evt_synced_idx
      ON historique_local_evenement (synced, date_action DESC)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS historique_local_evt_sync_uuid_idx
      ON historique_local_evenement (sync_uuid)
    ''');
  }

  Future<void> _createOfflineBasemapZoneTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_basemap_zone (
        zone_id TEXT PRIMARY KEY,
        city_slug TEXT NOT NULL,
        nom TEXT NOT NULL,
        geometry_geojson TEXT,
        bbox_west REAL NOT NULL,
        bbox_south REAL NOT NULL,
        bbox_east REAL NOT NULL,
        bbox_north REAL NOT NULL,
        center_latitude REAL NOT NULL,
        center_longitude REAL NOT NULL,
        min_zoom INTEGER DEFAULT 11,
        max_zoom INTEGER DEFAULT 19,
        actif INTEGER DEFAULT 1,
        metadata_json TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS offline_basemap_zone_city_idx
      ON offline_basemap_zone (city_slug, actif)
    ''');
  }

  Future<void> _createOfflineBasemapPackageTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_basemap_package (
        package_key TEXT PRIMARY KEY,
        zone_id TEXT NOT NULL,
        city_slug TEXT NOT NULL,
        style TEXT NOT NULL,
        format TEXT NOT NULL,
        version TEXT NOT NULL,
        file_name TEXT NOT NULL,
        relative_path TEXT,
        download_url TEXT,
        local_path TEXT,
        size_bytes INTEGER,
        sha256 TEXT,
        min_zoom INTEGER,
        max_zoom INTEGER,
        generated_at TEXT,
        source_name TEXT,
        attribution TEXT,
        tile_count INTEGER DEFAULT 0,
        metadata_json TEXT,
        actif INTEGER DEFAULT 1,
        requires_wifi INTEGER DEFAULT 1,
        status TEXT DEFAULT 'not_downloaded',
        downloaded_at TEXT,
        last_checked_at TEXT,
        last_error TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS offline_basemap_package_zone_style_idx
      ON offline_basemap_package (zone_id, style, actif)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS offline_basemap_package_status_idx
      ON offline_basemap_package (status, city_slug)
    ''');
  }

  Future<void> _migrateOfflineBasemapTables(Database db) async {
    await _ensureColumns(
      db,
      tableName: 'offline_basemap_zone',
      columns: const {
        'zone_id': 'TEXT',
        'city_slug': 'TEXT',
        'nom': 'TEXT',
        'geometry_geojson': 'TEXT',
        'bbox_west': 'REAL',
        'bbox_south': 'REAL',
        'bbox_east': 'REAL',
        'bbox_north': 'REAL',
        'center_latitude': 'REAL',
        'center_longitude': 'REAL',
        'min_zoom': 'INTEGER DEFAULT 11',
        'max_zoom': 'INTEGER DEFAULT 19',
        'actif': 'INTEGER DEFAULT 1',
        'metadata_json': 'TEXT',
        'updated_at': 'TEXT',
      },
    );

    await _ensureColumns(
      db,
      tableName: 'offline_basemap_package',
      columns: const {
        'package_key': 'TEXT',
        'zone_id': 'TEXT',
        'city_slug': 'TEXT',
        'style': 'TEXT',
        'format': 'TEXT',
        'version': 'TEXT',
        'file_name': 'TEXT',
        'relative_path': 'TEXT',
        'download_url': 'TEXT',
        'local_path': 'TEXT',
        'size_bytes': 'INTEGER',
        'sha256': 'TEXT',
        'min_zoom': 'INTEGER',
        'max_zoom': 'INTEGER',
        'generated_at': 'TEXT',
        'source_name': 'TEXT',
        'attribution': 'TEXT',
        'tile_count': 'INTEGER DEFAULT 0',
        'metadata_json': 'TEXT',
        'actif': 'INTEGER DEFAULT 1',
        'requires_wifi': 'INTEGER DEFAULT 1',
        'status': "TEXT DEFAULT 'not_downloaded'",
        'downloaded_at': 'TEXT',
        'last_checked_at': 'TEXT',
        'last_error': 'TEXT',
      },
    );
  }

  Future<void> _ensureColumns(
    Database db, {
    required String tableName,
    required Map<String, String> columns,
  }) async {
    final existing = await db.rawQuery('PRAGMA table_info($tableName)');
    if (existing.isEmpty) return;

    final existingCols = existing.map((r) => r['name'] as String).toSet();
    for (final entry in columns.entries) {
      if (existingCols.contains(entry.key)) continue;
      try {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}',
        );
      } catch (_) {}
    }
  }

  Future<void> _ensureUtilisateurLocalColumns(Database db) async {
    final existing = await db.rawQuery('PRAGMA table_info(utilisateur_local)');
    if (existing.isEmpty) return;

    final existingCols = existing.map((r) => r['name'] as String).toSet();
    await _ensureColumns(
      db,
      tableName: 'utilisateur_local',
      columns: {
        'nom': 'TEXT',
        'prenom': 'TEXT',
      },
    );

    if (!existingCols.contains('nom_prenom')) return;

    final rows = await db.query('utilisateur_local');
    for (final row in rows) {
      final fullName = row['nom_prenom']?.toString().trim();
      if (fullName == null || fullName.isEmpty) continue;

      final currentNom = row['nom']?.toString().trim() ?? '';
      final currentPrenom = row['prenom']?.toString().trim() ?? '';
      if (currentNom.isNotEmpty && currentPrenom.isNotEmpty) continue;

      final parts = fullName.split(RegExp(r'\s+'));
      final inferredPrenom = parts.isNotEmpty ? parts.first : null;
      final inferredNom = parts.length > 1 ? parts.skip(1).join(' ') : null;

      await db.update(
        'utilisateur_local',
        {
          if (currentPrenom.isEmpty) 'prenom': inferredPrenom,
          if (currentNom.isEmpty) 'nom': inferredNom,
        },
        where: 'id_user = ?',
        whereArgs: [row['id_user']],
      );
    }
  }

  static String? fullNameFromUserRow(Map<String, dynamic>? user) {
    if (user == null) return null;
    final prenom = user['prenom']?.toString().trim() ?? '';
    final nom = user['nom']?.toString().trim() ?? '';
    final fullName = [prenom, nom].where((part) => part.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) return fullName;

    final oldFullName = user['nom_prenom']?.toString().trim() ?? '';
    return oldFullName.isNotEmpty ? oldFullName : null;
  }

  Future<void> _createSrmFieldOptionLocalTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS srm_field_option_local (
        id_option INTEGER PRIMARY KEY,
        table_schema TEXT NOT NULL,
        table_name TEXT NOT NULL,
        field_name TEXT NOT NULL,
        code_value TEXT NOT NULL,
        label_value TEXT NOT NULL,
        display_order INTEGER DEFAULT 0,
        actif INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS srm_field_option_local_lookup_idx
      ON srm_field_option_local (table_schema, table_name, field_name, actif, display_order)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS srm_field_option_local_code_idx
      ON srm_field_option_local (table_schema, table_name, field_name, code_value)
    ''');
  }

  Future<void> _createCommuneLocalTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS commune_local (
        id_commune INTEGER PRIMARY KEY,
        id_province INTEGER,
        nom_commune TEXT,
        nom_province TEXT,
        nom_region TEXT,
        geometry_geojson TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS commune_local_name_idx
      ON commune_local (nom_commune, nom_province)
    ''');
  }

  Future<void> _ensureCommuneLocalTable(Database db) async {
    final existing = await db.rawQuery('PRAGMA table_info(commune_local)');
    if (existing.isEmpty) {
      await _createCommuneLocalTable(db);
      return;
    }

    final requiredColumns = <String>{
      'id_commune',
      'id_province',
      'nom_commune',
      'nom_province',
      'nom_region',
      'geometry_geojson',
    };
    final existingNames = existing
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();

    if (!requiredColumns.every(existingNames.contains)) {
      await db.execute('DROP TABLE IF EXISTS commune_local');
      await _createCommuneLocalTable(db);
      return;
    }

    await _createCommuneLocalTable(db);
  }

  Future<void> _createZoneLocalTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_local (
        id_zone INTEGER PRIMARY KEY,
        nom_zone TEXT NOT NULL,
        etat TEXT DEFAULT 'active',
        date_debut TEXT,
        date_cloture TEXT,
        id_user_creat INTEGER,
        id_user_cloture INTEGER,
        geometry_geojson TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS zone_local_name_idx
      ON zone_local (nom_zone, etat)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS zone_utilisateur_local (
        id INTEGER PRIMARY KEY,
        id_zone INTEGER NOT NULL,
        id_user INTEGER NOT NULL,
        date_affectation TEXT,
        actif INTEGER DEFAULT 1,
        UNIQUE(id_zone, id_user)
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS zone_utilisateur_local_user_idx
      ON zone_utilisateur_local (id_user, actif)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS zone_utilisateur_local_zone_idx
      ON zone_utilisateur_local (id_zone, actif)
    ''');
  }

  Future<void> _migrateZoneLocalTables(Database db) async {
    await _createZoneLocalTables(db);
    await _ensureColumns(
      db,
      tableName: 'zone_local',
      columns: const {
        'id_zone': 'INTEGER',
        'nom_zone': 'TEXT',
        'etat': "TEXT DEFAULT 'active'",
        'date_debut': 'TEXT',
        'date_cloture': 'TEXT',
        'id_user_creat': 'INTEGER',
        'id_user_cloture': 'INTEGER',
        'geometry_geojson': 'TEXT',
      },
    );
    await _ensureColumns(
      db,
      tableName: 'zone_utilisateur_local',
      columns: const {
        'id': 'INTEGER',
        'id_zone': 'INTEGER',
        'id_user': 'INTEGER',
        'date_affectation': 'TEXT',
        'actif': 'INTEGER DEFAULT 1',
      },
    );
  }

  Future<void> _ensureSrmFieldOptionLocalTable(Database db) async {
    final existing =
        await db.rawQuery('PRAGMA table_info(srm_field_option_local)');
    if (existing.isEmpty) {
      await _createSrmFieldOptionLocalTable(db);
      return;
    }

    final existingCols = existing.map((row) => row['name'] as String).toSet();
    const requiredCols = {
      'id_option',
      'table_schema',
      'table_name',
      'field_name',
      'code_value',
      'label_value',
      'display_order',
      'actif',
      'created_at',
    };

    if (!existingCols.containsAll(requiredCols)) {
      await db.execute('DROP TABLE IF EXISTS srm_field_option_local');
      await _createSrmFieldOptionLocalTable(db);
      return;
    }

    await _createSrmFieldOptionLocalTable(db);
  }

  Future<void> _migrateLocalHistoryTables(Database db) async {
    await _migrateLocalHistoryTable(
      db,
      tableName: 'historique_local_attribut',
      idColumn: 'id_historique_local',
    );
    await _migrateLocalHistoryTable(
      db,
      tableName: 'historique_local_evenement',
      idColumn: 'id_evenement_local',
    );
  }

  Future<void> _migrateLocalHistoryTable(
    Database db, {
    required String tableName,
    required String idColumn,
  }) async {
    final existing = await db.rawQuery('PRAGMA table_info($tableName)');
    if (existing.isEmpty) return;

    final existingCols = existing.map((r) => r['name'] as String).toSet();
    final requiredColumns = <String, String>{
      'sync_uuid': 'TEXT',
      'synced': 'INTEGER DEFAULT 0',
      'date_sync': 'TEXT',
      'last_error': 'TEXT',
    };

    for (final entry in requiredColumns.entries) {
      if (existingCols.contains(entry.key)) continue;
      try {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}',
        );
      } catch (_) {}
    }

    final missingSyncRows = await db.query(
      tableName,
      columns: [idColumn],
      where: 'sync_uuid IS NULL OR TRIM(sync_uuid) = ?',
      whereArgs: [''],
    );
    if (missingSyncRows.isNotEmpty) {
      final batch = db.batch();
      for (final row in missingSyncRows) {
        final localId = _asInt(row[idColumn]);
        if (localId == null) continue;
        batch.update(
          tableName,
          {
            'sync_uuid': _newHistorySyncUuid(),
            'synced': 0,
          },
          where: '$idColumn = ?',
          whereArgs: [localId],
        );
      }
      await batch.commit(noResult: true);
    }

    if (tableName == 'historique_local_attribut') {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS historique_local_synced_idx
        ON historique_local_attribut (synced, date_action DESC)
      ''');
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS historique_local_sync_uuid_idx
        ON historique_local_attribut (sync_uuid)
      ''');
    } else {
      await db.execute('''
        CREATE INDEX IF NOT EXISTS historique_local_evt_synced_idx
        ON historique_local_evenement (synced, date_action DESC)
      ''');
      await db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS historique_local_evt_sync_uuid_idx
        ON historique_local_evenement (sync_uuid)
      ''');
    }
  }

  Future<void> _migratePhotoSyncQueueTable(Database db) async {
    final existing = await db.rawQuery('PRAGMA table_info(photo_sync_queue)');
    if (existing.isEmpty) return;

    final existingCols = existing.map((r) => r['name'] as String).toSet();
    final requiredColumns = <String, String>{
      'schema_name': 'TEXT',
      'table_name': 'TEXT',
      'uuid_objet': 'TEXT',
      'photo_slot': 'INTEGER',
      'local_path': 'TEXT',
      'remote_path': 'TEXT',
      'date_prise_reelle': 'TEXT',
      'id_agent_crea': 'INTEGER',
      'synced': 'INTEGER DEFAULT 0',
      'retry_count': 'INTEGER DEFAULT 0',
      'last_error': 'TEXT',
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
    };

    for (final entry in requiredColumns.entries) {
      if (existingCols.contains(entry.key)) continue;
      try {
        await db.execute(
          'ALTER TABLE photo_sync_queue ADD COLUMN ${entry.key} ${entry.value}',
        );
      } catch (_) {}
    }
  }

  Future<void> _createAllSrmEntityTables(Database db) async {
    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        final tableName = SrmConfig.getTableName(metier, entity);
        if (tableName == null || tableName.isEmpty) continue;
        final fields = SrmConfig.getFields(metier, entity);

        final sql = _buildSrmCreateTableSql(
          tableName,
          fields,
        );
        await db.execute(sql);
        await _ensureSrmFixedColumns(db, tableName);
        await _ensureSrmEntityColumns(db, tableName, fields);
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ UTILISATEUR SRM (login + mot_de_passe en clair)
  // ══════════════════════════════════════════════════════

  /// Insert ou update un utilisateur SRM
  Future<int> upsertUserSrm({
    required String login,
    required String motDePasseHash,
    String? nom,
    String? prenom,
    String? role,
    int? apiId,
  }) async {
    final db = await database;
    try {
      return await db.insert(
        'utilisateur_local',
        {
          'id_user': apiId,
          'login': login,
          'mot_de_passe': motDePasseHash,
          'nom': nom,
          'prenom': prenom,
          'role': role ?? 'editeur_terrain',
          'dernier_login': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Erreur upsertUserSrm: $e');
      return -1;
    }
  }

  Future<bool> validateUser(String login, String password) async {
    try {
      final db = await database;
      final result = await db.query(
        'utilisateur_local',
        columns: ['mot_de_passe'],
        where: 'login = ?',
        whereArgs: [login],
        limit: 1,
      );
      if (result.isEmpty) return false;

      final storedValue =
          (result.first['mot_de_passe'] ?? '').toString().trim();
      if (storedValue.isEmpty) return false;

      if (PasswordHashService.looksLikePasswordHash(storedValue)) {
        return await PasswordHashService.verifyPassword(password, storedValue);
      }

      return storedValue == password;
    } catch (e) {
      debugPrint('❌ Erreur validateUser: $e');
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
      debugPrint('❌ Erreur getCurrentUserSrm: $e');
      return null;
    }
  }

  /// Nom complet de l'agent
  Future<String?> getAgentFullName(String login) async {
    try {
      final db = await database;
      final result = await db.query(
        'utilisateur_local',
        columns: ['nom', 'prenom'],
        where: 'login = ?',
        whereArgs: [login],
        limit: 1,
      );
      if (result.isNotEmpty) {
        return fullNameFromUserRow(result.first);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur getAgentFullName: $e');
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
      await recordLocalEvent(
        eventType: 'SESSION_LOGIN',
        tableName: 'srm_session',
        cleLigne: login,
        payload: {
          'login': login,
          'remember_me': remember ? 1 : 0,
        },
      );
      debugPrint('✅ Session: $login | remember=$remember');
    } catch (e) {
      debugPrint('❌ Erreur setCurrentUserLogin: $e');
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
      debugPrint('❌ Erreur getCurrentUserLogin: $e');
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
      await recordLocalEvent(
        eventType: 'SESSION_LOGOUT',
        tableName: 'srm_session',
        cleLigne: row['current_login']?.toString(),
        payload: {
          'login': row['current_login'],
          'remember_me': remember,
        },
      );
      debugPrint('✅ Session SRM effacée');
    } catch (e) {
      debugPrint('❌ Erreur clearSrmSession: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ PROJETS LOCAL
  // ══════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════
  // ██ MISSIONS LOCAL
  // ══════════════════════════════════════════════════════

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

  Future<int> insertEntity(String tableName, Map<String, dynamic> data) async {
    final db = await database;
    final enriched = {
      ...data,
      'id_agent_crea': await resolveLoginId(),
    };
    final id = await db.insert(tableName, enriched);
    debugPrint('✅ Entité insérée dans $tableName (ID: $id)');
    return id;
  }

  Future<int> insertEntityLocal(
    String tableName,
    Map<String, dynamic> data, {
    bool recordHistory = false,
  }) async {
    final db = await database;
    final id = await db.insert(tableName, data);
    if (recordHistory) {
      final insertedRow = Map<String, dynamic>.from(data)..['id'] = id;
      await _recordLocalInsertHistory(
        db,
        tableName: tableName,
        row: insertedRow,
      );
    }
    return id;
  }

  Future<void> updateEntityLocal(
    String tableName,
    int id,
    Map<String, dynamic> data, {
    bool recordHistory = false,
  }) async {
    final db = await database;
    Map<String, dynamic>? beforeRow;
    if (recordHistory) {
      final existing = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        beforeRow = Map<String, dynamic>.from(existing.first);
      }
    }

    await db.update(tableName, data, where: 'id = ?', whereArgs: [id]);

    if (recordHistory && beforeRow != null) {
      final afterRow = Map<String, dynamic>.from(beforeRow)..addAll(data);
      await _recordLocalUpdateHistory(
        db,
        tableName: tableName,
        beforeRow: beforeRow,
        afterRow: afterRow,
      );
    }
  }

  Future<void> deleteEntityLocal(
    String tableName,
    int id, {
    bool recordHistory = false,
  }) async {
    final db = await database;
    Map<String, dynamic>? existingRow;
    if (recordHistory) {
      final existing = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        existingRow = Map<String, dynamic>.from(existing.first);
      }
    }

    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);

    if (recordHistory && existingRow != null) {
      await _recordLocalDeleteHistory(
        db,
        tableName: tableName,
        row: existingRow,
      );
    }
  }

  Future<int> upsertDownloadedEntitySrm(
      String tableName, Map<String, dynamic> data,
      {bool recordHistory = false}) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    await _assertSrmTableExists(db, tableName);
    final cleaned = _sanitizeSrmPayload(tableName, data);
    await _ensureSrmEntityColumns(
      db,
      tableName,
      cleaned.keys.toList(),
    );
    final uuid = cleaned['uuid']?.toString().trim();

    if (uuid != null && uuid.isNotEmpty) {
      final existingRows = await db.query(
        tableName,
        where: 'uuid = ?',
        whereArgs: [uuid],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        final existing = Map<String, dynamic>.from(existingRows.first);
        final localId = existing['id'];
        final merged = Map<String, dynamic>.from(existing);
        cleaned.forEach((key, value) {
          merged[key] = value;
        });
        merged.remove('id');

        if (_toInt(existing['downloaded']) != 1) {
          merged['downloaded'] = 0;
        }

        final sanitizedMerged = _sanitizeSrmPayload(tableName, merged);
        await db.update(
          tableName,
          sanitizedMerged,
          where: 'id = ?',
          whereArgs: [localId],
        );
        if (recordHistory) {
          final afterRow = Map<String, dynamic>.from(existing)
            ..addAll(sanitizedMerged);
          await _recordLocalUpdateHistory(
            db,
            tableName: tableName,
            beforeRow: existing,
            afterRow: afterRow,
          );
        }
        debugPrint('SRM upsertDownloadedEntitySrm -> $tableName uuid=$uuid');
        return localId is int ? localId : 0;
      }
    }

    final id = await db.insert(
      tableName,
      cleaned,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (recordHistory) {
      final insertedRow = Map<String, dynamic>.from(cleaned)..['id'] = id;
      await _recordLocalInsertHistory(
        db,
        tableName: tableName,
        row: insertedRow,
      );
    }
    debugPrint('SRM upsertDownloadedEntitySrm -> $tableName (ID: $id)');
    return id;
  }

  Future<List<Map<String, dynamic>>> getEntities(String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }

  // ══════════════════════════════════════════════════════
  // ██ ENTITÉS SRM (EP / ASS / ELEC) — SPRINT 5
  // ══════════════════════════════════════════════════════

  String _buildSrmCreateTableSql(String tableName, List<String> fields) {
    _assertAllowedSrmTable(tableName);

    const fixedCols = '''
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      fid INTEGER,
      uuid TEXT UNIQUE,
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
      mode_localisation TEXT DEFAULT 'gnss',
      downloaded INTEGER DEFAULT 0,
      synced INTEGER DEFAULT 0,
      date_collecte TEXT,
      date_sync TEXT
    ''';

    final dynamicCols = fields
        .where(_isAllowedSrmColumn)
        .where((f) => !_isFixedCol(f))
        .map((f) => '  $f ${_sqliteTypeForField(f)}')
        .join(',\n');

    return '''
      CREATE TABLE IF NOT EXISTS $tableName (
        $fixedCols
        ${dynamicCols.isNotEmpty ? ',$dynamicCols' : ''}
      )
    ''';
  }

  bool _isFixedCol(String col) {
    const fixed = {
      'id',
      'fid',
      'uuid',
      'id_agent_crea',
      'id_planche',
      'id_commune',
      'latitude_gps',
      'longitude_gps',
      'altitude_gps',
      'x_debut',
      'y_debut',
      'x_fin',
      'y_fin',
      'lat_debut',
      'lon_debut',
      'lat_fin',
      'lon_fin',
      'nb_points',
      'distance_m',
      'points_json',
      'anomalie',
      'type_anomalie',
      'photo_1',
      'photo_2',
      'photo_3',
      'photo_4',
      'mode_localisation',
      'downloaded',
      'synced',
      'date_collecte',
      'date_sync',
    };
    return fixed.contains(col);
  }

  /// Insert une entité SRM dans sa table (crée la table si besoin).
  Future<int> insertEntitySrm(String tableName, Map<String, dynamic> data,
      {bool recordHistory = false}) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    await _assertSrmTableExists(db, tableName);
    // Nettoyer les valeurs null pour éviter les erreurs SQLite
    final cleaned = _sanitizeSrmPayload(tableName, data);

    final id = await db.insert(
      tableName,
      cleaned,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (recordHistory) {
      final insertedRow = Map<String, dynamic>.from(cleaned)..['id'] = id;
      await _recordLocalInsertHistory(
        db,
        tableName: tableName,
        row: insertedRow,
      );
    }
    debugPrint('✅ SRM insertEntitySrm → $tableName (ID: $id)');
    return id;
  }

  /// Met à jour une entité SRM.
  Future<void> updateEntitySrm(
      String tableName, int id, Map<String, dynamic> data,
      {bool recordHistory = false}) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    await _assertSrmTableExists(db, tableName);
    final cleaned = _sanitizeSrmPayload(tableName, data);
    Map<String, dynamic>? beforeRow;
    if (recordHistory) {
      final existing = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        beforeRow = Map<String, dynamic>.from(existing.first);
      }
    }
    await db.update(tableName, cleaned, where: 'id = ?', whereArgs: [id]);
    if (recordHistory && beforeRow != null) {
      final afterRow = Map<String, dynamic>.from(beforeRow)..addAll(cleaned);
      await _recordLocalUpdateHistory(
        db,
        tableName: tableName,
        beforeRow: beforeRow,
        afterRow: afterRow,
      );
    }
    debugPrint('✅ SRM updateEntitySrm → $tableName id=$id');
  }

  /// Supprime une entité SRM.
  Future<void> deleteEntitySrm(String tableName, int id,
      {bool recordHistory = false}) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    Map<String, dynamic>? existingRow;
    if (recordHistory) {
      final rows = await db.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        existingRow = Map<String, dynamic>.from(rows.first);
      }
    }
    await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    if (recordHistory && existingRow != null) {
      await _recordLocalDeleteHistory(
        db,
        tableName: tableName,
        row: existingRow,
      );
    }
    debugPrint('✅ SRM deleteEntitySrm → $tableName id=$id');
  }

  Future<void> _recordLocalInsertHistory(
    Database db, {
    required String tableName,
    required Map<String, dynamic> row,
  }) async {
    final historyMeta = _buildLocalHistoryMeta(tableName, row);
    final batch = db.batch();
    final rowWithId = Map<String, dynamic>.from(row);
    final keys = rowWithId.keys.toList()..sort();
    final nowIso = DateTime.now().toIso8601String();

    for (final key in keys) {
      final newValue = _stringifyHistoryValue(rowWithId[key]);
      if (newValue == null) continue;
      batch.insert('historique_local_attribut', {
        'sync_uuid': _newHistorySyncUuid(),
        ...historyMeta,
        'nom_attribut': key,
        'ancienne_valeur': null,
        'nouvelle_valeur': newValue,
        'date_action': nowIso,
        'type_action': 'INSERT',
        'synced': 0,
        'date_sync': null,
        'last_error': null,
      });
    }

    await batch.commit(noResult: true);
  }

  Future<void> _recordLocalUpdateHistory(
    Database db, {
    required String tableName,
    required Map<String, dynamic> beforeRow,
    required Map<String, dynamic> afterRow,
  }) async {
    final historyMeta = _buildLocalHistoryMeta(
        tableName, afterRow.isNotEmpty ? afterRow : beforeRow);
    final batch = db.batch();
    final keys = <String>{...beforeRow.keys, ...afterRow.keys}.toList()..sort();
    final nowIso = DateTime.now().toIso8601String();

    for (final key in keys) {
      final oldValue = _stringifyHistoryValue(beforeRow[key]);
      final newValue = _stringifyHistoryValue(afterRow[key]);
      if (oldValue == newValue) continue;
      batch.insert('historique_local_attribut', {
        'sync_uuid': _newHistorySyncUuid(),
        ...historyMeta,
        'nom_attribut': key,
        'ancienne_valeur': oldValue,
        'nouvelle_valeur': newValue,
        'date_action': nowIso,
        'type_action': 'UPDATE',
        'synced': 0,
        'date_sync': null,
        'last_error': null,
      });
    }

    await batch.commit(noResult: true);
  }

  Future<void> _recordLocalDeleteHistory(
    Database db, {
    required String tableName,
    required Map<String, dynamic> row,
  }) async {
    final historyMeta = _buildLocalHistoryMeta(tableName, row);
    final batch = db.batch();
    final keys = row.keys.toList()..sort();
    final nowIso = DateTime.now().toIso8601String();

    for (final key in keys) {
      final oldValue = _stringifyHistoryValue(row[key]);
      if (oldValue == null) continue;
      batch.insert('historique_local_attribut', {
        'sync_uuid': _newHistorySyncUuid(),
        ...historyMeta,
        'nom_attribut': key,
        'ancienne_valeur': oldValue,
        'nouvelle_valeur': null,
        'date_action': nowIso,
        'type_action': 'DELETE',
        'synced': 0,
        'date_sync': null,
        'last_error': null,
      });
    }

    await batch.commit(noResult: true);
  }

  Map<String, dynamic> _buildLocalHistoryMeta(
    String tableName,
    Map<String, dynamic> row,
  ) {
    final localId = _asInt(row['id']);
    final uuidObjet =
        row['uuid']?.toString().trim() ?? row['uuid_objet']?.toString().trim();
    final schemaName = _resolveSchemaNameForTable(tableName);
    final cleLigne = (uuidObjet != null && uuidObjet.isNotEmpty)
        ? uuidObjet
        : localId?.toString();

    return {
      'id_objet': localId,
      'cle_ligne': cleLigne,
      'uuid_objet': uuidObjet?.isEmpty ?? true ? null : uuidObjet,
      'nom_schema': schemaName,
      'nom_table': tableName,
      'nom_classe': schemaName != null ? '$schemaName.$tableName' : tableName,
      'id_agent': _resolveHistoryAgentId(row),
    };
  }

  String? _resolveSchemaNameForTable(String tableName) {
    if (tableName.contains('.')) {
      final schema = tableName.split('.').first.trim();
      return schema.isEmpty ? null : schema;
    }
    if (tableName == 'objet_incomplet') return 'public';
    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        final currentTable = SrmConfig.getTableName(metier, entity);
        if (currentTable != tableName) continue;
        final config = SrmConfig.getEntityConfig(metier, entity);
        final schema = config?['schema']?.toString().trim();
        if (schema != null && schema.isNotEmpty) {
          return schema;
        }
      }
    }
    return null;
  }

  String _objetIncompletNomTable(String tableName, {String? metierCode}) {
    final cleanTable = tableName.trim();
    if (cleanTable.contains('.')) return cleanTable;

    final resolvedSchema = _resolveSchemaNameForTable(cleanTable);
    final fallbackSchema = metierCode?.trim().toLowerCase();
    final schema = resolvedSchema ??
        (fallbackSchema == 'asst'
            ? 'ass'
            : (fallbackSchema == null || fallbackSchema.isEmpty
                ? null
                : fallbackSchema));
    return schema == null ? cleanTable : '$schema.$cleanTable';
  }

  int? _resolveHistoryAgentId(Map<String, dynamic> row) {
    return _asInt(row['id_agent_modif']) ??
        _asInt(row['id_agent']) ??
        _asInt(row['id_agent_crea']) ??
        _asInt(row['id_agent_incomplet']) ??
        _asInt(row['id_agent_completement']) ??
        _asInt(row['id_agent_signal']) ??
        _asInt(row['id_user']) ??
        ApiService.userId;
  }

  int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  int _truthyToInt(dynamic value) {
    if (value is bool) return value ? 1 : 0;
    if (value is int) return value == 1 ? 1 : 0;
    if (value is num) return value.toInt() == 1 ? 1 : 0;
    final normalized = value?.toString().trim().toLowerCase();
    return {'1', 'true', 't', 'yes', 'oui'}.contains(normalized) ? 1 : 0;
  }

  String? _stringifyHistoryValue(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is bool) return value ? '1' : '0';
    if (value is num) return value.toString();
    if (value is DateTime) return value.toIso8601String();
    if (value is Map || value is Iterable) return jsonEncode(value);
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String _newHistorySyncUuid() => const Uuid().v4();

  Future<void> recordLocalEvent({
    required String eventType,
    String? schemaName,
    String? tableName,
    String? cleLigne,
    String? uuidObjet,
    int? idObjet,
    int? idAgent,
    Map<String, dynamic>? payload,
  }) async {
    final db = await database;
    await db.insert(
      'historique_local_evenement',
      {
        'sync_uuid': _newHistorySyncUuid(),
        'type_evenement': eventType,
        'nom_schema': schemaName,
        'nom_table': tableName,
        'cle_ligne': cleLigne,
        'uuid_objet': uuidObjet,
        'id_objet': idObjet,
        'id_agent': idAgent ?? ApiService.userId,
        'payload_json': payload == null ? null : jsonEncode(payload),
        'date_action': DateTime.now().toIso8601String(),
        'synced': 0,
        'date_sync': null,
        'last_error': null,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingLocalAttributeHistory({
    int limit = 200,
  }) async {
    final db = await database;
    return db.query(
      'historique_local_attribut',
      where: 'synced IS NULL OR synced = 0',
      orderBy: 'date_action ASC, id_historique_local ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingLocalEventHistory({
    int limit = 200,
  }) async {
    final db = await database;
    return db.query(
      'historique_local_evenement',
      where: 'synced IS NULL OR synced = 0',
      orderBy: 'date_action ASC, id_evenement_local ASC',
      limit: limit,
    );
  }

  Future<void> markLocalAttributeHistorySynced(List<String> syncUuids) async {
    await _markLocalHistoryRowsSynced(
      tableName: 'historique_local_attribut',
      syncUuids: syncUuids,
    );
  }

  Future<void> markLocalEventHistorySynced(List<String> syncUuids) async {
    await _markLocalHistoryRowsSynced(
      tableName: 'historique_local_evenement',
      syncUuids: syncUuids,
    );
  }

  Future<void> markLocalAttributeHistoryFailed(
    List<String> syncUuids,
    String errorMessage,
  ) async {
    await _markLocalHistoryRowsFailed(
      tableName: 'historique_local_attribut',
      syncUuids: syncUuids,
      errorMessage: errorMessage,
    );
  }

  Future<void> markLocalEventHistoryFailed(
    List<String> syncUuids,
    String errorMessage,
  ) async {
    await _markLocalHistoryRowsFailed(
      tableName: 'historique_local_evenement',
      syncUuids: syncUuids,
      errorMessage: errorMessage,
    );
  }

  Future<void> _markLocalHistoryRowsSynced({
    required String tableName,
    required List<String> syncUuids,
  }) async {
    if (syncUuids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final nowIso = DateTime.now().toIso8601String();
    for (final syncUuid in syncUuids) {
      batch.update(
        tableName,
        {
          'synced': 1,
          'date_sync': nowIso,
          'last_error': null,
        },
        where: 'sync_uuid = ?',
        whereArgs: [syncUuid],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _markLocalHistoryRowsFailed({
    required String tableName,
    required List<String> syncUuids,
    required String errorMessage,
  }) async {
    if (syncUuids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    final nowIso = DateTime.now().toIso8601String();
    for (final syncUuid in syncUuids) {
      batch.update(
        tableName,
        {
          'synced': 0,
          'last_error': errorMessage,
          'date_sync': nowIso,
        },
        where: 'sync_uuid = ?',
        whereArgs: [syncUuid],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Récupère toutes les entités d'une table SRM.
  Future<List<Map<String, dynamic>>> getEntitiesSrm(String tableName) async {
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
      debugPrint('❌ getEntitiesSrm $tableName: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getOpenObjetIncompletForEntity({
    required String tableName,
    required int idObjet,
  }) async {
    try {
      _assertAllowedSrmTable(tableName);
      final db = await database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        ['objet_incomplet'],
      );
      if (tables.isEmpty) return null;

      final nomTable = _objetIncompletNomTable(tableName);
      final rows = await db.query(
        'objet_incomplet',
        where:
            '(nom_table = ? OR nom_table = ?) AND id_objet = ? AND (statut IS NULL OR statut = ?)',
        whereArgs: [nomTable, tableName, idObjet, 'A_COMPLETER'],
        orderBy: 'date_signalement DESC, id DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (e) {
      debugPrint('❌ getOpenObjetIncompletForEntity $tableName/$idObjet: $e');
      return null;
    }
  }

  Future<void> upsertObjetIncompletForEntity({
    required String tableName,
    required int idObjet,
    required String metierCode,
    required String? raison,
    String? detailRaison,
  }) async {
    final existing = await getOpenObjetIncompletForEntity(
      tableName: tableName,
      idObjet: idObjet,
    );
    final nowIso = DateTime.now().toIso8601String();
    final cleanReason = raison?.trim();
    final cleanDetail = detailRaison?.trim();
    final nomTable = _objetIncompletNomTable(
      tableName,
      metierCode: metierCode,
    );

    final payload = <String, dynamic>{
      'nom_table': nomTable,
      'id_objet': idObjet,
      'detail_raison': (cleanDetail == null || cleanDetail.isEmpty)
          ? cleanReason
          : cleanDetail,
      'date_signalement': existing?['date_signalement'] ?? nowIso,
      'id_agent_incomplet': ApiService.userId,
      'statut': 'A_COMPLETER',
      'date_completion': null,
      'id_agent_completement': null,
      'synced': 0,
      'downloaded': 0,
      'date_collecte': nowIso,
      'date_sync': null,
    };

    final existingId = _asInt(existing?['id']);
    if (existingId != null) {
      await updateEntitySrm(
        'objet_incomplet',
        existingId,
        payload,
        recordHistory: true,
      );
      return;
    }

    await insertEntitySrm(
      'objet_incomplet',
      payload,
      recordHistory: true,
    );
  }

  Future<void> resolveObjetIncompletForEntity({
    required String tableName,
    required int idObjet,
  }) async {
    try {
      _assertAllowedSrmTable(tableName);
      final db = await database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        ['objet_incomplet'],
      );
      if (tables.isEmpty) return;

      final nomTable = _objetIncompletNomTable(tableName);
      final rows = await db.query(
        'objet_incomplet',
        columns: ['id'],
        where:
            '(nom_table = ? OR nom_table = ?) AND id_objet = ? AND (statut IS NULL OR statut = ?)',
        whereArgs: [nomTable, tableName, idObjet, 'A_COMPLETER'],
      );
      if (rows.isEmpty) return;

      final nowIso = DateTime.now().toIso8601String();
      for (final row in rows) {
        final localId = _asInt(row['id']);
        if (localId == null) continue;
        await updateEntitySrm(
          'objet_incomplet',
          localId,
          {
            'statut': 'COMPLETE',
            'id_agent_completement': ApiService.userId,
            'date_completion': nowIso,
            'synced': 0,
            'date_collecte': nowIso,
            'date_sync': null,
          },
          recordHistory: true,
        );
      }
    } catch (e) {
      debugPrint('❌ resolveObjetIncompletForEntity $tableName/$idObjet: $e');
    }
  }

  /// Récupère les entités non synchronisées d'une table SRM.
  Future<void> upsertDownloadedInterventionAnomalieTerrain(
    Map<String, dynamic> row,
  ) async {
    final idIntervention = _asInt(row['id_intervention'] ?? row['id']);
    if (idIntervention == null) return;

    final db = await database;
    await _ensureInterventionAnomalieTerrainTable(db);
    final existing = await db.query(
      'intervention_anomalie',
      where: 'id_intervention = ?',
      whereArgs: [idIntervention],
      limit: 1,
    );

    if (existing.isNotEmpty && _asInt(existing.first['synced']) == 0) {
      return;
    }

    final nowIso = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'id_intervention': idIntervention,
      'id_objet': _asInt(row['id_objet']),
      'nom_classe': row['nom_classe']?.toString(),
      'nom_table': row['nom_table']?.toString(),
      'uuid_objet': row['uuid_objet']?.toString(),
      'retour_terrain': _truthyToInt(row['retour_terrain']),
      'statut': row['statut']?.toString(),
      'responsable_actuel': row['responsable_actuel']?.toString(),
      'etat_terrain': row['etat_terrain']?.toString(),
      'commentaire_terrain': row['commentaire_terrain']?.toString(),
      'date_terrain': row['date_terrain']?.toString(),
      'id_user_terrain': _asInt(row['id_user_terrain']),
      'date_creation': row['date_creation']?.toString(),
      'date_cloture': row['date_cloture']?.toString(),
      'created_at': row['created_at']?.toString(),
      'updated_at': row['updated_at']?.toString(),
      'synced': 1,
      'downloaded': 1,
      'date_sync': nowIso,
      'last_error': null,
    };

    if (existing.isNotEmpty) {
      await db.update(
        'intervention_anomalie',
        payload,
        where: 'id_intervention = ?',
        whereArgs: [idIntervention],
      );
      return;
    }

    await db.insert('intervention_anomalie', {
      ...payload,
      'date_collecte': nowIso,
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedInterventionAnomalieTerrain({
    int limit = 1000,
  }) async {
    final db = await database;
    await _ensureInterventionAnomalieTerrainTable(db);
    return await db.query(
      'intervention_anomalie',
      where: 'synced IS NULL OR synced = 0',
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<void> updateInterventionAnomalieTerrainLocal({
    required int localId,
    required String etatTerrain,
    String? commentaireTerrain,
  }) async {
    final db = await database;
    await _ensureInterventionAnomalieTerrainTable(db);
    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'intervention_anomalie',
      {
        'etat_terrain': etatTerrain.trim(),
        'commentaire_terrain': commentaireTerrain?.trim(),
        'id_user_terrain': ApiService.userId,
        'synced': 0,
        'downloaded': 1,
        'date_collecte': nowIso,
        'date_sync': null,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markInterventionAnomalieTerrainSynced(
    int localId,
    Map<String, dynamic> remote,
  ) async {
    final db = await database;
    await _ensureInterventionAnomalieTerrainTable(db);
    final nowIso = DateTime.now().toIso8601String();
    await db.update(
      'intervention_anomalie',
      {
        'statut': remote['statut']?.toString(),
        'responsable_actuel': remote['responsable_actuel']?.toString(),
        'etat_terrain': remote['etat_terrain']?.toString(),
        'commentaire_terrain': remote['commentaire_terrain']?.toString(),
        'date_terrain': remote['date_terrain']?.toString(),
        'id_user_terrain': _asInt(remote['id_user_terrain']),
        'updated_at': remote['updated_at']?.toString(),
        'synced': 1,
        'downloaded': 1,
        'date_sync': nowIso,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markInterventionAnomalieTerrainFailed(
    int localId,
    String error,
  ) async {
    final db = await database;
    await _ensureInterventionAnomalieTerrainTable(db);
    await db.update(
      'intervention_anomalie',
      {'last_error': error},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedSrm(String tableName) async {
    try {
      _assertAllowedSrmTable(tableName);
      final db = await database;
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName]);
      if (tables.isEmpty) return [];
      return await db.query(
        tableName,
        where:
            '(synced IS NULL OR synced = 0) AND (downloaded IS NULL OR downloaded = 0)',
        orderBy: 'id ASC',
      );
    } catch (e) {
      debugPrint('❌ getUnsyncedSrm $tableName: $e');
      return [];
    }
  }

  /// Marque une entité comme synchronisée.
  Future<void> markSyncedSrm(String tableName, int id) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    await db.update(
        tableName, {'synced': 1, 'date_sync': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> enqueueConduiteSyncItem({
    required String metier,
    required int idAgent,
    required DateTime jour,
    required List<Map<String, dynamic>> nodes,
  }) async {
    final db = await database;
    await _createConduiteSyncQueueTable(db);
    final nowIso = DateTime.now().toIso8601String();
    final jourKey = jour.toIso8601String().substring(0, 10);
    final existing = await db.query(
      'conduite_sync_queue',
      where: 'metier = ? AND id_agent = ? AND jour = ?',
      whereArgs: [metier, idAgent, jourKey],
      limit: 1,
    );
    final payload = <String, dynamic>{
      'metier': metier,
      'id_agent': idAgent,
      'jour': jourKey,
      'nodes_json': jsonEncode(nodes),
      'synced': 0,
      'last_error': null,
      'updated_at': nowIso,
      'date_sync': null,
    };

    if (existing.isEmpty) {
      payload['sync_uuid'] = const Uuid().v4();
      payload['retry_count'] = 0;
      payload['created_at'] = nowIso;
      return db.insert('conduite_sync_queue', payload);
    }

    final existingId = _toInt(existing.first['id']);
    await db.update(
      'conduite_sync_queue',
      payload,
      where: 'id = ?',
      whereArgs: [existingId],
    );
    return existingId;
  }

  Future<Map<String, dynamic>?> getConduiteSyncItemForDay({
    required String metier,
    required int idAgent,
    required DateTime jour,
  }) async {
    final db = await database;
    await _createConduiteSyncQueueTable(db);
    final jourKey = jour.toIso8601String().substring(0, 10);
    final rows = await db.query(
      'conduite_sync_queue',
      where:
          'metier = ? AND id_agent = ? AND jour = ? AND (synced IS NULL OR synced = 0)',
      whereArgs: [metier, idAgent, jourKey],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getPendingConduiteSyncItems({
    int limit = 100,
  }) async {
    final db = await database;
    await _createConduiteSyncQueueTable(db);
    return db.query(
      'conduite_sync_queue',
      where: 'synced IS NULL OR synced = 0',
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<void> markConduiteSyncItemSynced(int id) async {
    final db = await database;
    await db.update(
      'conduite_sync_queue',
      {
        'synced': 1,
        'last_error': null,
        'date_sync': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markConduiteSyncItemFailed(int id, String errorMessage) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE conduite_sync_queue
      SET synced = 0,
          retry_count = COALESCE(retry_count, 0) + 1,
          last_error = ?,
          updated_at = ?
      WHERE id = ?
      ''',
      [errorMessage, DateTime.now().toIso8601String(), id],
    );
  }

  Future<int> enqueuePhotoSyncItem({
    required String schemaName,
    required String tableName,
    required String uuidObjet,
    required int photoSlot,
    required String localPath,
    int? idAgentCrea,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    final existing = await db.query(
      'photo_sync_queue',
      where:
          'schema_name = ? AND table_name = ? AND uuid_objet = ? AND photo_slot = ?',
      whereArgs: [schemaName, tableName, uuidObjet, photoSlot],
      limit: 1,
    );

    final payload = <String, dynamic>{
      'schema_name': schemaName,
      'table_name': tableName,
      'uuid_objet': uuidObjet,
      'photo_slot': photoSlot,
      'local_path': localPath,
      'id_agent_crea': idAgentCrea,
      'synced': 0,
      'last_error': null,
      'updated_at': nowIso,
    };

    if (existing.isEmpty) {
      payload['retry_count'] = 0;
      payload['created_at'] = nowIso;
      final id = await db.insert('photo_sync_queue', payload);
      await recordLocalEvent(
        eventType: 'ENQUEUE_PHOTO_SYNC',
        tableName: 'photo_sync_queue',
        cleLigne: '$tableName|$uuidObjet|$photoSlot',
        uuidObjet: uuidObjet,
        payload: {
          'schema_name': schemaName,
          'table_name': tableName,
          'photo_slot': photoSlot,
        },
      );
      return id;
    }

    final existingId = _toInt(existing.first['id']);
    await db.update(
      'photo_sync_queue',
      payload,
      where: 'id = ?',
      whereArgs: [existingId],
    );
    await recordLocalEvent(
      eventType: 'ENQUEUE_PHOTO_SYNC',
      tableName: 'photo_sync_queue',
      cleLigne: '$tableName|$uuidObjet|$photoSlot',
      uuidObjet: uuidObjet,
      payload: {
        'schema_name': schemaName,
        'table_name': tableName,
        'photo_slot': photoSlot,
      },
    );
    return existingId;
  }

  Future<List<Map<String, dynamic>>> getPendingPhotoSyncItems({
    int limit = 200,
  }) async {
    final db = await database;
    return db.query(
      'photo_sync_queue',
      where: 'synced IS NULL OR synced = 0',
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<int> countPendingLocalHistoryItems() async {
    final db = await database;
    final attributes = await _countRowsIfTableExists(
      db,
      'historique_local_attribut',
      where: 'synced IS NULL OR synced = 0',
    );
    final events = await _countRowsIfTableExists(
      db,
      'historique_local_evenement',
      where: 'synced IS NULL OR synced = 0',
    );
    return attributes + events;
  }

  Future<int> _countRowsIfTableExists(
    Database db,
    String tableName, {
    String? where,
  }) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    if (tables.isEmpty) return 0;

    final result = await db.query(
      tableName,
      columns: ['COUNT(*) AS total'],
      where: where,
    );
    final value = result.isEmpty ? null : result.first['total'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> markPhotoSyncItemSynced(
    int id, {
    required String remotePath,
    String? datePriseReelle,
  }) async {
    final db = await database;
    await db.update(
      'photo_sync_queue',
      {
        'synced': 1,
        'remote_path': remotePath,
        'date_prise_reelle': datePriseReelle,
        'last_error': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await recordLocalEvent(
      eventType: 'PHOTO_SYNC_SUCCESS',
      tableName: 'photo_sync_queue',
      idObjet: id,
      payload: {
        'remote_path': remotePath,
        if (datePriseReelle != null && datePriseReelle.isNotEmpty)
          'date_prise_reelle': datePriseReelle,
      },
    );
  }

  Future<void> markPhotoSyncItemFailed(int id, String errorMessage) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE photo_sync_queue
      SET synced = 0,
          retry_count = COALESCE(retry_count, 0) + 1,
          last_error = ?,
          updated_at = ?
      WHERE id = ?
      ''',
      [errorMessage, DateTime.now().toIso8601String(), id],
    );
    await recordLocalEvent(
      eventType: 'PHOTO_SYNC_FAILED',
      tableName: 'photo_sync_queue',
      idObjet: id,
      payload: {'error': errorMessage},
    );
  }

  Future<void> updatePhotoReferenceByUuid(
      String tableName, String uuid, int photoSlot, String photoReference,
      {bool recordHistory = false}) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    final fieldName = 'photo_$photoSlot';
    Map<String, dynamic>? beforeRow;
    if (recordHistory) {
      final rows = await db.query(
        tableName,
        where: 'uuid = ?',
        whereArgs: [uuid],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        beforeRow = Map<String, dynamic>.from(rows.first);
      }
    }
    await db.update(
      tableName,
      {fieldName: photoReference},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    if (recordHistory && beforeRow != null) {
      final afterRow = Map<String, dynamic>.from(beforeRow)
        ..[fieldName] = photoReference;
      await _recordLocalUpdateHistory(
        db,
        tableName: tableName,
        beforeRow: beforeRow,
        afterRow: afterRow,
      );
    }
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
    // Tables spéciales hors srm_config
    tables.addAll({
      'objet_incomplet',
      'raison_incomplet',
    });
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

  List<String> _fieldsForTable(String tableName) {
    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        if (SrmConfig.getTableName(metier, entity) == tableName) {
          return SrmConfig.getFields(metier, entity);
        }
      }
    }
    return const [];
  }

  static const Set<String> _fixedSrmColumns = {
    'id', 'fid', 'uuid', 'id_agent_crea',
    'id_planche', 'id_commune', 'latitude_gps', 'longitude_gps',
    'altitude_gps', 'x_debut', 'y_debut', 'x_fin', 'y_fin',
    'lat_debut', 'lon_debut', 'lat_fin', 'lon_fin',
    'nb_points', 'distance_m', 'points_json', 'altitude_z_moy',
    'anomalie', 'type_anomalie',
    'photo_1', 'photo_2', 'photo_3', 'photo_4',
    'mode_localisation', 'downloaded', 'synced', 'date_collecte', 'date_sync',
    // Flag objet incomplet dans les tables métier
    'objet_incomplet',
    // Colonnes de la table objet_incomplet (correspond à PostgreSQL)
    'id_incomplet', 'nom_table', 'id_objet', 'detail_raison',
    'date_signalement', 'id_agent_incomplet', 'statut',
    'date_completion', 'id_agent_completement',
  };

  static const Map<String, String> _migratableFixedSrmColumns = {
    'fid': 'INTEGER',
    'uuid': 'TEXT',
    'id_agent_crea': 'INTEGER',
    'id_planche': 'INTEGER',
    'id_commune': 'INTEGER',
    'latitude_gps': 'REAL',
    'longitude_gps': 'REAL',
    'altitude_gps': 'REAL',
    'x_debut': 'REAL',
    'y_debut': 'REAL',
    'x_fin': 'REAL',
    'y_fin': 'REAL',
    'lat_debut': 'REAL',
    'lon_debut': 'REAL',
    'lat_fin': 'REAL',
    'lon_fin': 'REAL',
    'nb_points': 'INTEGER DEFAULT 0',
    'distance_m': 'REAL DEFAULT 0',
    'points_json': 'TEXT',
    'anomalie': 'INTEGER DEFAULT 0',
    'type_anomalie': 'TEXT',
    'photo_1': 'TEXT',
    'photo_2': 'TEXT',
    'photo_3': 'TEXT',
    'photo_4': 'TEXT',
    'mode_localisation': "TEXT DEFAULT 'gnss'",
    'downloaded': 'INTEGER DEFAULT 0',
    'synced': 'INTEGER DEFAULT 0',
    'date_collecte': 'TEXT',
    'date_sync': 'TEXT',
    // Flag dans les tables métier
    'objet_incomplet': 'INTEGER DEFAULT 0',
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
        case 'fid':
        case 'id_agent_crea':
        case 'id_planche':
        case 'id_commune':
        case 'nb_points':
        case 'anomalie':
        case 'downloaded':
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

  Future<void> _ensureSrmFixedColumns(Database db, String tableName) async {
    final existing = await db.rawQuery('PRAGMA table_info($tableName)');
    if (existing.isEmpty) return;

    final existingCols = existing.map((r) => r['name'] as String).toSet();
    for (final entry in _migratableFixedSrmColumns.entries) {
      if (existingCols.contains(entry.key)) continue;
      try {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN ${entry.key} ${entry.value}',
        );
        debugPrint('✅ Colonne fixe ajoutée: $tableName.${entry.key}');
      } catch (e) {
        debugPrint('⚠️ Impossible d’ajouter $tableName.${entry.key}: $e');
      }
    }
  }

  Future<void> _ensureSrmEntityColumns(
    Database db,
    String tableName,
    List<String> fields,
  ) async {
    final existing = await db.rawQuery('PRAGMA table_info($tableName)');
    if (existing.isEmpty) return;

    final existingCols = existing.map((r) => r['name'] as String).toSet();
    for (final field
        in fields.where(_isAllowedSrmColumn).where((f) => !_isFixedCol(f))) {
      if (existingCols.contains(field)) continue;
      try {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN $field ${_sqliteTypeForField(field)}',
        );
        debugPrint('✅ Colonne métier ajoutée: $tableName.$field');
      } catch (e) {
        debugPrint('⚠️ Impossible d’ajouter $tableName.$field: $e');
      }
    }
  }

  Future<void> _assertSrmTableExists(Database db, String tableName) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    if (tables.isEmpty) {
      // Créer la table automatiquement avec colonnes fixes
      final cols = <String>['id INTEGER PRIMARY KEY AUTOINCREMENT'];
      for (final entry in _migratableFixedSrmColumns.entries) {
        cols.add('${entry.key} ${entry.value}');
      }
      await db.execute(
        'CREATE TABLE IF NOT EXISTS $tableName (${cols.join(', ')})',
      );
      debugPrint('✅ Table SRM créée automatiquement: $tableName');
    } else {
      // Table existe → migrer les colonnes manquantes
      await _ensureSrmFixedColumns(db, tableName);
    }

    // Table existe → migrer uniquement les colonnes fixes connues
    await _ensureSrmFixedColumns(db, tableName);
    final fields = _fieldsForTable(tableName);
    if (fields.isNotEmpty) {
      await _ensureSrmEntityColumns(db, tableName, fields);
    }
  }

  Future<bool> tableHasColumn(String tableName, String columnName) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    final info = await db.rawQuery('PRAGMA table_info($tableName)');
    return info.any((row) => row['name'] == columnName);
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

  Future<void> replaceSrmFieldOptions({
    required List<Map<String, dynamic>> options,
    String? tableSchema,
    String? tableName,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      if ((tableSchema ?? '').trim().isNotEmpty &&
          (tableName ?? '').trim().isNotEmpty) {
        await txn.delete(
          'srm_field_option_local',
          where: 'table_schema = ? AND table_name = ?',
          whereArgs: [tableSchema!.trim(), tableName!.trim()],
        );
      } else {
        await txn.delete('srm_field_option_local');
      }

      for (final option in options) {
        final idOption = _asInt(option['id_option']);
        final schema = (option['table_schema'] ?? '').toString().trim();
        final name = (option['table_name'] ?? '').toString().trim();
        final fieldName = (option['field_name'] ?? '').toString().trim();
        final codeValue = (option['code_value'] ?? '').toString().trim();
        final labelValue = (option['label_value'] ?? '').toString().trim();

        if (idOption == null ||
            schema.isEmpty ||
            name.isEmpty ||
            fieldName.isEmpty ||
            codeValue.isEmpty ||
            labelValue.isEmpty) {
          continue;
        }

        await txn.insert(
          'srm_field_option_local',
          {
            'id_option': idOption,
            'table_schema': schema,
            'table_name': name,
            'field_name': fieldName,
            'code_value': codeValue,
            'label_value': labelValue,
            'display_order': _asInt(option['display_order']) ?? 0,
            'actif': option['actif'] == false ? 0 : 1,
            'created_at': option['created_at']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> replaceCommunes({
    required List<Map<String, dynamic>> communes,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('commune_local');

      for (final commune in communes) {
        final idCommune = _asInt(commune['id_commune'] ?? commune['fid']);
        if (idCommune == null) continue;

        final storedCommune = <String, dynamic>{
          'id_commune': idCommune,
          'id_province': _asInt(commune['id_province']),
          'nom_commune':
              (commune['nom_commune'] ?? commune['nom'])?.toString().trim(),
          'nom_province': commune['nom_province']?.toString().trim(),
          'nom_region': commune['nom_region']?.toString().trim(),
          'geometry_geojson': commune['geometry_geojson']?.toString(),
        };

        await txn.insert(
          'commune_local',
          storedCommune,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> replaceZones({
    required List<Map<String, dynamic>> zones,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('zone_local');

      for (final zone in zones) {
        final idZone = _asInt(zone['id_zone']);
        final nomZone = (zone['nom_zone'] ?? '').toString().trim();
        if (idZone == null || nomZone.isEmpty) continue;

        await txn.insert(
          'zone_local',
          {
            'id_zone': idZone,
            'nom_zone': nomZone,
            'etat': (zone['etat'] ?? 'active').toString(),
            'date_debut': zone['date_debut']?.toString(),
            'date_cloture': zone['date_cloture']?.toString(),
            'id_user_creat': _asInt(zone['id_user_creat']),
            'id_user_cloture': _asInt(zone['id_user_cloture']),
            'geometry_geojson': zone['geometry_geojson']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> replaceZoneUtilisateurs({
    required List<Map<String, dynamic>> affectations,
    int? idUser,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      if (idUser != null) {
        await txn.delete(
          'zone_utilisateur_local',
          where: 'id_user = ?',
          whereArgs: [idUser],
        );
      } else {
        await txn.delete('zone_utilisateur_local');
      }

      for (final affectation in affectations) {
        final id = _asInt(affectation['id']);
        final idZone = _asInt(affectation['id_zone']);
        final idUserValue = _asInt(affectation['id_user']);
        if (id == null || idZone == null || idUserValue == null) continue;

        await txn.insert(
          'zone_utilisateur_local',
          {
            'id': id,
            'id_zone': idZone,
            'id_user': idUserValue,
            'date_affectation': affectation['date_affectation']?.toString(),
            'actif': affectation['actif'] == false ? 0 : 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getZonesLocal({
    int? idUser,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (activeOnly) {
      whereParts.add("(etat IS NULL OR lower(etat) = 'active')");
    }
    if (idUser != null) {
      whereParts.add('''
        id_zone IN (
          SELECT id_zone FROM zone_utilisateur_local
          WHERE id_user = ? AND actif = 1
        )
      ''');
      whereArgs.add(idUser);
    }

    return db.query(
      'zone_local',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'nom_zone, id_zone',
    );
  }

  Future<List<Map<String, dynamic>>> getZoneUtilisateursLocal({
    int? idUser,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (idUser != null) {
      whereParts.add('id_user = ?');
      whereArgs.add(idUser);
    }
    if (activeOnly) {
      whereParts.add('actif = 1');
    }

    return db.query(
      'zone_utilisateur_local',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'id_user, id_zone',
    );
  }

  Future<List<Map<String, dynamic>>> getCommunesLocal() async {
    final db = await database;
    return db.query(
      'commune_local',
      orderBy: 'nom_commune ASC, nom_province ASC',
    );
  }

  Future<Map<String, dynamic>?> findCommuneLocalByPoint({
    required double x,
    required double y,
  }) async {
    final db = await database;
    final rows = await db.query(
      'commune_local',
      where: 'geometry_geojson IS NOT NULL AND TRIM(geometry_geojson) <> ?',
      whereArgs: [''],
    );

    for (final row in rows) {
      final geometryText = row['geometry_geojson']?.toString().trim();
      if (geometryText == null || geometryText.isEmpty) continue;

      try {
        final geometry = jsonDecode(geometryText);
        if (_geometryContainsPoint(geometry, x, y)) {
          return Map<String, dynamic>.from(row);
        }
      } catch (e) {
        debugPrint('⚠️ commune_local geometry ignoree: $e');
      }
    }
    return null;
  }

  bool _geometryContainsPoint(dynamic geometry, double x, double y) {
    if (geometry is! Map<String, dynamic>) return false;
    final type = geometry['type']?.toString();
    final coordinates = geometry['coordinates'];

    if (type == 'Polygon' && coordinates is List) {
      return _polygonContainsPoint(coordinates, x, y);
    }
    if (type == 'MultiPolygon' && coordinates is List) {
      for (final polygon in coordinates) {
        if (polygon is List && _polygonContainsPoint(polygon, x, y)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _polygonContainsPoint(List<dynamic> polygon, double x, double y) {
    if (polygon.isEmpty) return false;
    final outerRing = polygon.first;
    if (outerRing is! List || !_ringContainsPoint(outerRing, x, y)) {
      return false;
    }

    for (var i = 1; i < polygon.length; i++) {
      final hole = polygon[i];
      if (hole is List && _ringContainsPoint(hole, x, y)) {
        return false;
      }
    }
    return true;
  }

  bool _ringContainsPoint(List<dynamic> ring, double x, double y) {
    var inside = false;
    if (ring.length < 3) return false;

    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final pi = ring[i];
      final pj = ring[j];
      if (pi is! List || pj is! List || pi.length < 2 || pj.length < 2) {
        continue;
      }

      final xi = _asDouble(pi[0]);
      final yi = _asDouble(pi[1]);
      final xj = _asDouble(pj[0]);
      final yj = _asDouble(pj[1]);
      if (xi == null || yi == null || xj == null || yj == null) {
        continue;
      }

      final intersects = ((yi > y) != (yj > y)) &&
          (x <
              (xj - xi) * (y - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
      if (intersects) {
        inside = !inside;
      }
    }

    return inside;
  }

  Future<List<Map<String, dynamic>>> getSrmFieldOptions({
    required String tableSchema,
    required String tableName,
    String? fieldName,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final whereParts = <String>[
      'table_schema = ?',
      'table_name = ?',
    ];
    final whereArgs = <Object?>[tableSchema, tableName];

    if (fieldName != null && fieldName.trim().isNotEmpty) {
      whereParts.add('field_name = ?');
      whereArgs.add(fieldName.trim());
    }
    if (activeOnly) {
      whereParts.add('actif = 1');
    }

    return db.query(
      'srm_field_option_local',
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'field_name ASC, display_order ASC, label_value ASC',
    );
  }

  Future<void> replaceOfflineBasemapCatalog({
    required List<Map<String, dynamic>> zones,
    required List<Map<String, dynamic>> packages,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('offline_basemap_zone');
      final incomingPackageKeys = packages
          .map((package) =>
              '${package['zone_id']}:${package['style']}:${package['version']}')
          .toSet();

      final existingPackageRows = await txn.query(
        'offline_basemap_package',
        columns: ['package_key'],
      );
      for (final row in existingPackageRows) {
        final packageKey = (row['package_key'] ?? '').toString();
        if (packageKey.isEmpty || incomingPackageKeys.contains(packageKey)) {
          continue;
        }
        await txn.delete(
          'offline_basemap_package',
          where: 'package_key = ?',
          whereArgs: [packageKey],
        );
      }

      for (final zone in zones) {
        final bbox = (zone['bbox'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(zone['bbox'] as Map)
            : <String, dynamic>{};
        final center = (zone['center'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(zone['center'] as Map)
            : <String, dynamic>{};

        await txn.insert(
          'offline_basemap_zone',
          {
            'zone_id': zone['zone_id'],
            'city_slug': zone['city_slug'],
            'nom': zone['nom'],
            'geometry_geojson': _encodeJsonValue(zone['geometry']),
            'bbox_west': _asDouble(bbox['west']) ?? 0,
            'bbox_south': _asDouble(bbox['south']) ?? 0,
            'bbox_east': _asDouble(bbox['east']) ?? 0,
            'bbox_north': _asDouble(bbox['north']) ?? 0,
            'center_latitude': _asDouble(center['latitude']) ?? 0,
            'center_longitude': _asDouble(center['longitude']) ?? 0,
            'min_zoom': _asInt(zone['min_zoom']) ?? 11,
            'max_zoom': _asInt(zone['max_zoom']) ?? 19,
            'actif': zone['actif'] == false ? 0 : 1,
            'metadata_json': _encodeJsonValue(zone['metadata_json']),
            'updated_at': (zone['updated_at'] ?? '').toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final package in packages) {
        final packageKey =
            '${package['zone_id']}:${package['style']}:${package['version']}';
        final existingRows = await txn.query(
          'offline_basemap_package',
          columns: ['local_path', 'status', 'downloaded_at', 'last_error'],
          where: 'package_key = ?',
          whereArgs: [packageKey],
          limit: 1,
        );

        final existing = existingRows.isNotEmpty
            ? Map<String, dynamic>.from(existingRows.first)
            : const <String, dynamic>{};
        final incomingSha256 = (package['sha256'] ?? '').toString();
        final incomingSizeBytes = _asInt(package['size_bytes']);
        final existingLocalPath = (existing['local_path'] ?? '').toString();
        final existingStatus =
            (existing['status'] ?? 'not_downloaded').toString();
        final existingDownloadedAt = existing['downloaded_at'];
        final existingLastError = existing['last_error'];

        final existingPackageRows = await txn.query(
          'offline_basemap_package',
          columns: ['sha256', 'size_bytes'],
          where: 'package_key = ?',
          whereArgs: [packageKey],
          limit: 1,
        );
        final existingPackageMeta = existingPackageRows.isNotEmpty
            ? Map<String, dynamic>.from(existingPackageRows.first)
            : const <String, dynamic>{};
        final existingSha256 = (existingPackageMeta['sha256'] ?? '').toString();
        final existingSizeBytes = _asInt(existingPackageMeta['size_bytes']);

        final packageChanged = existingPackageMeta.isNotEmpty &&
            ((incomingSha256.isNotEmpty && incomingSha256 != existingSha256) ||
                (incomingSizeBytes != null &&
                    existingSizeBytes != null &&
                    incomingSizeBytes != existingSizeBytes));

        final preservedStatus = packageChanged
            ? (existingLocalPath.isNotEmpty
                ? 'update_available'
                : 'not_downloaded')
            : existingStatus;

        await txn.insert(
          'offline_basemap_package',
          {
            'package_key': packageKey,
            'zone_id': package['zone_id'],
            'city_slug': package['city_slug'],
            'style': package['style'],
            'format': package['format'],
            'version': package['version'],
            'file_name': package['file_name'],
            'relative_path': package['relative_path'],
            'download_url': package['download_url'],
            'local_path': existingLocalPath.isEmpty ? null : existingLocalPath,
            'size_bytes': incomingSizeBytes,
            'sha256': package['sha256'],
            'min_zoom': _asInt(package['min_zoom']),
            'max_zoom': _asInt(package['max_zoom']),
            'generated_at': (package['generated_at'] ?? '').toString(),
            'source_name': package['source_name'],
            'attribution': package['attribution'],
            'tile_count': _asInt(package['tile_count']) ?? 0,
            'metadata_json': _encodeJsonValue(package['metadata_json']),
            'actif': package['actif'] == false ? 0 : 1,
            'requires_wifi': package['requires_wifi'] == false ? 0 : 1,
            'status': preservedStatus,
            'downloaded_at': existingDownloadedAt,
            'last_checked_at': DateTime.now().toIso8601String(),
            'last_error': packageChanged ? null : existingLastError,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getOfflineBasemapZones({
    String? citySlug,
    String? zoneId,
    int? agentId,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (citySlug != null && citySlug.isNotEmpty) {
      whereParts.add('city_slug = ?');
      whereArgs.add(citySlug);
    }
    if (zoneId != null && zoneId.isNotEmpty) {
      whereParts.add('zone_id = ?');
      whereArgs.add(zoneId);
    }
    // Le catalogue téléchargé est déjà filtré côté serveur via zone_utilisateur.
    if (activeOnly) {
      whereParts.add('actif = 1');
    }

    return db.query(
      'offline_basemap_zone',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'city_slug, nom, zone_id',
    );
  }

  Future<Map<String, dynamic>?> getOfflineBasemapZoneById(String zoneId) async {
    final rows = await getOfflineBasemapZones(
      zoneId: zoneId,
      activeOnly: false,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getOfflineBasemapPackages({
    String? citySlug,
    String? zoneId,
    String? style,
    String? status,
    int? agentId,
    bool activeOnly = true,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (citySlug != null && citySlug.isNotEmpty) {
      whereParts.add('city_slug = ?');
      whereArgs.add(citySlug);
    }
    if (zoneId != null && zoneId.isNotEmpty) {
      whereParts.add('zone_id = ?');
      whereArgs.add(zoneId);
    }
    // Le catalogue téléchargé est déjà filtré côté serveur via zone_utilisateur.
    if (style != null && style.isNotEmpty) {
      whereParts.add('style = ?');
      whereArgs.add(style);
    }
    if (status != null && status.isNotEmpty) {
      whereParts.add('status = ?');
      whereArgs.add(status);
    }
    if (activeOnly) {
      whereParts.add('actif = 1');
    }

    return db.query(
      'offline_basemap_package',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'city_slug, zone_id, style, version',
    );
  }

  Future<Map<String, dynamic>?> getOfflineBasemapPackageByKey(
    String packageKey,
  ) async {
    final db = await database;
    final rows = await db.query(
      'offline_basemap_package',
      where: 'package_key = ?',
      whereArgs: [packageKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<List<Map<String, dynamic>>> getReadyOfflineBasemapPackages({
    String? citySlug,
    String? zoneId,
    String? style,
    int? agentId,
  }) {
    return getOfflineBasemapPackages(
      citySlug: citySlug,
      zoneId: zoneId,
      style: style,
      agentId: agentId,
      status: 'ready',
      activeOnly: true,
    );
  }

  String _activeOfflineBasemapPackageKeyMetadata(String style) {
    final normalizedStyle = style.trim().toLowerCase();
    return 'active_basemap_${normalizedStyle}_package_key';
  }

  Future<String?> getActiveOfflineBasemapPackageKey({
    required String style,
  }) {
    return getAppMetadataValue(_activeOfflineBasemapPackageKeyMetadata(style));
  }

  Future<void> setActiveOfflineBasemapPackageKey({
    required String style,
    String? packageKey,
    bool recordEvent = true,
  }) async {
    final metadataKey = _activeOfflineBasemapPackageKeyMetadata(style);

    if (packageKey == null || packageKey.trim().isEmpty) {
      await deleteAppMetadataValue(
        metadataKey,
        eventType: recordEvent ? 'CLEAR_ACTIVE_BASEMAP_PACKAGE' : null,
        payload: recordEvent ? {'style': style} : null,
      );
      return;
    }

    await saveAppMetadataValue(
      metadataKey,
      packageKey.trim(),
      eventType: recordEvent ? 'SET_ACTIVE_BASEMAP_PACKAGE' : null,
      payload: recordEvent
          ? {
              'style': style,
              'package_key': packageKey.trim(),
            }
          : null,
    );
  }

  Future<Map<String, dynamic>?> getActiveOfflineBasemapPackage({
    required String style,
  }) async {
    final packageKey = await getActiveOfflineBasemapPackageKey(style: style);
    if (packageKey == null || packageKey.trim().isEmpty) {
      return null;
    }

    final package = await getOfflineBasemapPackageByKey(packageKey.trim());
    if (package == null) {
      await setActiveOfflineBasemapPackageKey(
        style: style,
        packageKey: null,
        recordEvent: false,
      );
      return null;
    }

    final status = (package['status'] ?? '').toString().trim().toLowerCase();
    final localPath = (package['local_path'] ?? '').toString().trim();
    if (status != 'ready' || localPath.isEmpty) {
      await setActiveOfflineBasemapPackageKey(
        style: style,
        packageKey: null,
        recordEvent: false,
      );
      return null;
    }

    return package;
  }

  Future<void> updateOfflineBasemapPackageDownloadState({
    required String packageKey,
    required String status,
    String? localPath,
    String? downloadedAt,
    String? lastError,
  }) async {
    final db = await database;
    final payload = <String, Object?>{
      'status': status,
      'last_checked_at': DateTime.now().toIso8601String(),
      'last_error': lastError,
    };

    if (localPath != null) {
      payload['local_path'] = localPath;
    }
    if (downloadedAt != null) {
      payload['downloaded_at'] = downloadedAt;
    }

    await db.update(
      'offline_basemap_package',
      payload,
      where: 'package_key = ?',
      whereArgs: [packageKey],
    );
  }

  String? _encodeJsonValue(dynamic value) {
    if (value == null) return null;
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Future<void> saveLastSyncTime(DateTime dt) async {
    final db = await database;
    await db.insert(
      'app_metadata',
      {'key': 'last_sync_time', 'value': dt.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await recordLocalEvent(
      eventType: 'SAVE_LAST_SYNC_TIME',
      tableName: 'app_metadata',
      cleLigne: 'last_sync_time',
      payload: {'value': dt.toIso8601String()},
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

  Future<void> saveAppMetadataValue(
    String key,
    String value, {
    String? eventType,
    Map<String, dynamic>? payload,
  }) async {
    final db = await database;
    await db.insert(
      'app_metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (eventType != null) {
      await recordLocalEvent(
        eventType: eventType,
        tableName: 'app_metadata',
        cleLigne: key,
        payload: payload ?? {'value': value},
      );
    }
  }

  Future<String?> getAppMetadataValue(String key) async {
    final db = await database;
    final res = await db.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return res.first['value'] as String?;
  }

  String _regardMiroirCacheKey() => 'ep_regard_miroir_cache';

  Future<void> saveRegardMiroirCache(List<Map<String, dynamic>> items) async {
    await saveAppMetadataValue(
      _regardMiroirCacheKey(),
      jsonEncode(items),
    );
  }

  Future<List<Map<String, dynamic>>> getRegardMiroirCache() async {
    final raw = await getAppMetadataValue(
      _regardMiroirCacheKey(),
    );
    if (raw == null || raw.trim().isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> deleteAppMetadataValue(
    String key, {
    String? eventType,
    Map<String, dynamic>? payload,
  }) async {
    final db = await database;
    await db.delete(
      'app_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );

    if (eventType != null) {
      await recordLocalEvent(
        eventType: eventType,
        tableName: 'app_metadata',
        cleLigne: key,
        payload: payload ?? {'key': key},
      );
    }
  }

  Future<void> saveLastDownloadTime(DateTime dt) async {
    final db = await database;
    await db.insert(
      'app_metadata',
      {'key': 'last_download_time', 'value': dt.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await recordLocalEvent(
      eventType: 'SAVE_LAST_DOWNLOAD_TIME',
      tableName: 'app_metadata',
      cleLigne: 'last_download_time',
      payload: {'value': dt.toIso8601String()},
    );
  }

  String _lastDownloadTableTimeKey(String tableName) =>
      'last_download_time_table_${tableName.trim()}';

  String _downloadTableStatusKey(String tableName) =>
      'download_status_table_${tableName.trim()}';

  Future<void> saveLastDownloadTimeForTable(
    String tableName,
    DateTime dt,
  ) async {
    await saveAppMetadataValue(
      _lastDownloadTableTimeKey(tableName),
      dt.toIso8601String(),
      eventType: 'SAVE_LAST_DOWNLOAD_TABLE_TIME',
      payload: {
        'table_name': tableName,
        'value': dt.toIso8601String(),
      },
    );
  }

  Future<DateTime?> getLastDownloadTimeForTable(String tableName) async {
    final raw = await getAppMetadataValue(_lastDownloadTableTimeKey(tableName));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDownloadTableStatus(
    String tableName, {
    required String status,
    int? downloadedCount,
    int? nextPage,
    int? totalCount,
    String? updatedAfter,
    String? error,
  }) async {
    await saveAppMetadataValue(
      _downloadTableStatusKey(tableName),
      jsonEncode({
        'status': status,
        'table_name': tableName,
        if (downloadedCount != null) 'downloaded_count': downloadedCount,
        if (nextPage != null) 'next_page': nextPage,
        if (totalCount != null) 'total_count': totalCount,
        if (updatedAfter != null && updatedAfter.trim().isNotEmpty)
          'updated_after': updatedAfter.trim(),
        if (error != null && error.trim().isNotEmpty) 'error': error.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
      eventType: 'SAVE_DOWNLOAD_TABLE_STATUS',
      payload: {
        'table_name': tableName,
        'status': status,
        if (downloadedCount != null) 'downloaded_count': downloadedCount,
        if (nextPage != null) 'next_page': nextPage,
        if (totalCount != null) 'total_count': totalCount,
        if (updatedAfter != null && updatedAfter.trim().isNotEmpty)
          'updated_after': updatedAfter.trim(),
        if (error != null && error.trim().isNotEmpty) 'error': error.trim(),
      },
    );
  }

  Future<Map<String, dynamic>?> getDownloadTableStatus(String tableName) async {
    final raw = await getAppMetadataValue(_downloadTableStatusKey(tableName));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<DateTime?> getLastDownloadTime() async {
    final db = await database;
    final res = await db.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: ['last_download_time'],
      limit: 1,
    );
    if (res.isEmpty) return null;
    final raw = res.first['value'] as String?;
    if (raw == null) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<int> countDownloadedSrmRows() async {
    final db = await database;
    int total = 0;

    for (final tableName in _allowedSrmTables()) {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      if (tables.isEmpty) continue;

      final whereParts = <String>['downloaded = 1'];
      final whereArgs = <Object?>[];

      final result = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $tableName WHERE ${whereParts.join(' AND ')}',
        whereArgs,
      );
      final value = result.isNotEmpty ? result.first['c'] : 0;
      total += value is int ? value : int.tryParse(value.toString()) ?? 0;
    }

    return total;
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
      debugPrint('✅ DB réinitialisée');
    } catch (e) {
      debugPrint('❌ Erreur resetDatabase: $e');
    }
  }
}
