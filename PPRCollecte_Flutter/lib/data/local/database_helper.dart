// lib/data/local/database_helper.dart
// ── SPRINT 3 : DatabaseHelper SRM ──
// Tables SQLite miroirs de PostgreSQL :
//   utilisateur_local → public.utilisateur (id_user, login, mot_de_passe en clair, nom, prenom, role)
// Version DB: 23

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/srm_config.dart';
import '../../core/config/srm_server_columns.dart';
import '../remote/api_service.dart';
import '../../services/draft_service.dart';
import '../../services/password_hash_service.dart';
import '../../services/photo_storage_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static bool _isInitializing = false;
  static const Duration srmSessionDuration = Duration(days: 7);

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  @visibleForTesting
  static Future<Database> openInMemoryDatabaseForTest({
    bool includeSrmEntityTables = true,
  }) async {
    await resetForTest();
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 23,
      onCreate: (db, version) async {
        await _instance._createAllTables(
          db,
          includeSrmEntityTables: includeSrmEntityTables,
        );
      },
    );
    _database = db;
    return db;
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    final db = _database;
    _database = null;
    _isInitializing = false;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

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

  Future<void> _cleanupOldPendingPhotosIfNeeded(Database db) async {
    const key = 'photo_pending_cleanup_last_run';
    final rows = await db.query(
      'app_metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    final lastRun = rows.isEmpty
        ? null
        : DateTime.tryParse(rows.first['value']?.toString() ?? '');
    final now = DateTime.now().toUtc();
    if (lastRun != null && now.difference(lastRun.toUtc()).inHours < 24) {
      return;
    }

    try {
      final queuedRows = await db.query(
        'photo_sync_queue',
        columns: ['local_path'],
        where: "COALESCE(local_path, '') <> ''",
      );
      final protectedPaths = queuedRows
          .map((row) => row['local_path']?.toString().trim() ?? '')
          .where((path) => path.isNotEmpty)
          .toSet();
      final deleted = await PhotoStorageService.cleanupOldPendingPhotos(
        now: now,
        protectedPaths: protectedPaths,
      );
      await db.insert(
        'app_metadata',
        {'key': key, 'value': now.toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (deleted > 0) {
        debugPrint('[PHOTO] $deleted fichier(s) pending ancien(s) nettoye(s)');
      }
    } catch (e) {
      debugPrint('[PHOTO] Nettoyage pending ignore: $e');
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
      version: 23,
      onCreate: (db, version) async {
        debugPrint('🆕 Création tables v$version');
        await _createAllTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        debugPrint('🔄 Migration $oldVersion → $newVersion');
        await _createAllTables(db, includeSrmEntityTables: false);
      },
      onOpen: (db) async {
        debugPrint('🔌 DB ouverte');
        await _migrateExistingSrmTables(db);
        await _createConduiteSyncQueueTable(db);
        await _cleanupOldPendingPhotosIfNeeded(db);
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // ██ CRÉATION DES TABLES
  // ══════════════════════════════════════════════════════

  Future<void> _createAllTables(
    Database db, {
    bool includeSrmEntityTables = true,
  }) async {
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
    await _createRegionalBasemapStateTable(db);
    await _createSrmFieldOptionLocalTable(db);
    await _createAttributConfigMobileLocalTable(db);
    await _createFormulaireConfigMobileLocalTable(db);
    await _createOnepDbLocalTable(db);
    await _createRegardMiroirCacheTable(db);
    await _createCommuneLocalTable(db);
    await _createZoneLocalTables(db);
    await _createReferenceOverlayLocalTables(db);
    await _ensureInterventionAnomalieTerrainTable(db);
    if (includeSrmEntityTables) {
      await _createAllSrmEntityTables(db);
    }

    // ── SPRINT 7 : Table brouillons automatiques ──
    await DraftService.createTable(db);

    debugPrint('🎉 Toutes les tables SRM créées !');
  }

  Future<void> _migrateExistingSrmTables(Database db) async {
    await _ensureUtilisateurLocalColumns(db);
    await _ensureSrmFieldOptionLocalTable(db);
    await _createAttributConfigMobileLocalTable(db);
    await _createFormulaireConfigMobileLocalTable(db);
    await _createOnepDbLocalTable(db);
    await _createRegardMiroirCacheTable(db);
    await _ensureCommuneLocalTable(db);
    await _migrateZoneLocalTables(db);
    await _migrateReferenceOverlayLocalTables(db);
    await _ensureInterventionAnomalieTerrainTable(db);
    await _createPhotoSyncQueueTable(db);
    await _createLocalHistoryTable(db);
    await _createLocalEventHistoryTable(db);
    await _createRegionalBasemapStateTable(db);
    await _dropLegacyOfflineBasemapTables(db);
    // ── SPRINT 7 : S'assurer que la table brouillons existe ──
    await _migrateLocalHistoryTables(db);
    await DraftService.createTable(db);
    // ── Migration spécifique : table objet_incomplet ──
    await _ensureObjetIncompletTable(db);
    await _migratePhotoSyncQueueTable(db);
    await _createAllSrmEntityTables(db);
    await _assertAllSrmEntityTablesPresentAndAligned(db);
    await _markLocalHistoryForAlreadySyncedObjects(db);
  }

  /// Crée ou migre la table objet_incomplet avec les colonnes PostgreSQL exactes
  Future<void> _ensureObjetIncompletTable(Database db) async {
    // Créer la table si elle n'existe pas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS objet_incomplet (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_incomplet INTEGER,
        uuid TEXT,
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

    final requiredColumns = {
      'id_incomplet': 'INTEGER',
      'uuid': 'TEXT',
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

    await _ensureColumns(
      db,
      tableName: 'objet_incomplet',
      columns: requiredColumns,
    );
    await _assertColumnsPresent(
      db,
      tableName: 'objet_incomplet',
      columns: requiredColumns.keys,
    );

    final missingUuidRows = await db.query(
      'objet_incomplet',
      columns: ['id'],
      where: "uuid IS NULL OR trim(uuid) = ''",
    );
    for (final row in missingUuidRows) {
      final id = row['id'];
      if (id == null) continue;
      await db.update(
        'objet_incomplet',
        {'uuid': const Uuid().v4()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    // Migration legacy : ancienne colonne 'nom_classe' a copier vers 'nom_table'.
    // Verifier d'abord la presence de la colonne pour eviter un log SQLite
    // bruyant sur les installations neuves.
    final pragma = await db.rawQuery('PRAGMA table_info(objet_incomplet)');
    final hasNomClasse = pragma.any((row) => row['name'] == 'nom_classe');
    if (hasNomClasse) {
      await db.execute('''
        UPDATE objet_incomplet
        SET nom_table = nom_classe
        WHERE (nom_table IS NULL OR trim(nom_table) = '')
          AND nom_classe IS NOT NULL
          AND trim(nom_classe) <> ''
      ''');
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
        etat_exploitant TEXT DEFAULT 'en_attente',
        commentaire_exploitant TEXT,
        date_exploitant TEXT,
        etat_terrain TEXT DEFAULT 'en_attente',
        commentaire_terrain TEXT,
        date_terrain TEXT,
        id_user_terrain INTEGER,
        etat_bureau TEXT DEFAULT 'en_attente',
        commentaire_bureau TEXT,
        date_bureau TEXT,
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

    final requiredColumns = {
      'id_intervention': 'INTEGER',
      'id_objet': 'INTEGER',
      'nom_classe': 'TEXT',
      'nom_table': 'TEXT',
      'uuid_objet': 'TEXT',
      'retour_terrain': 'INTEGER DEFAULT 0',
      'statut': 'TEXT',
      'responsable_actuel': 'TEXT',
      'etat_exploitant': "TEXT DEFAULT 'en_attente'",
      'commentaire_exploitant': 'TEXT',
      'date_exploitant': 'TEXT',
      'etat_terrain': "TEXT DEFAULT 'en_attente'",
      'commentaire_terrain': 'TEXT',
      'date_terrain': 'TEXT',
      'id_user_terrain': 'INTEGER',
      'etat_bureau': "TEXT DEFAULT 'en_attente'",
      'commentaire_bureau': 'TEXT',
      'date_bureau': 'TEXT',
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

    await _ensureColumns(
      db,
      tableName: 'intervention_anomalie',
      columns: requiredColumns,
    );
    await _assertColumnsPresent(
      db,
      tableName: 'intervention_anomalie',
      columns: requiredColumns.keys,
    );

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

  Future<void> _createPhotoSyncQueueTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS photo_sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        schema_name TEXT NOT NULL,
        table_name TEXT NOT NULL,
        uuid_objet TEXT NOT NULL,
        photo_slot INTEGER NOT NULL,
        photo_context TEXT NOT NULL DEFAULT 'collecte_initiale',
        id_intervention_anomalie INTEGER DEFAULT 0,
        local_path TEXT NOT NULL,
        remote_path TEXT,
        date_prise_reelle TEXT,
        id_agent_crea INTEGER,
        synced INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_photo_sync_queue_context_slot
      ON photo_sync_queue (
        schema_name,
        table_name,
        uuid_objet,
        photo_context,
        id_intervention_anomalie,
        photo_slot
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

  Future<void> _createRegionalBasemapStateTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS regional_basemap_state (
        id TEXT PRIMARY KEY,
        sha256 TEXT NOT NULL,
        version TEXT,
        format TEXT NOT NULL DEFAULT 'pmtiles',
        size_bytes INTEGER,
        local_path TEXT,
        download_url TEXT,
        name TEXT,
        attribution TEXT,
        generated_at TEXT,
        downloaded_at TEXT,
        updated_at TEXT
      )
    ''');
  }

  Future<void> _dropLegacyOfflineBasemapTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS offline_basemap_package');
    await db.execute('DROP TABLE IF EXISTS offline_basemap_zone');
  }

  Future<void> _ensureColumns(
    Database db, {
    required String tableName,
    required Map<String, String> columns,
  }) async {
    final existing = await db.rawQuery(
      'PRAGMA table_info(${_quoteSqlIdentifier(tableName)})',
    );
    if (existing.isEmpty) return;

    final existingCols = existing
        .map((row) => row['name']?.toString().toLowerCase())
        .whereType<String>()
        .toSet();

    final missing = columns.entries
        .where((entry) => entry.key.trim().isNotEmpty)
        .where((entry) => !existingCols.contains(entry.key.toLowerCase()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in missing) {
      final column = entry.key.trim();
      final type = entry.value.trim().isEmpty ? 'TEXT' : entry.value.trim();
      await db.execute(
        'ALTER TABLE ${_quoteSqlIdentifier(tableName)} '
        'ADD COLUMN ${_quoteSqlIdentifier(column)} $type',
      );
      debugPrint('[SRM-SQLITE] Colonne ajoutee: $tableName.$column');
    }
  }

  String _quoteSqlIdentifier(String identifier) {
    return '"${identifier.replaceAll('"', '""')}"';
  }

  Future<void> _assertColumnsPresent(
    Database db, {
    required String tableName,
    required Iterable<String> columns,
    String sourceLabel = '',
  }) async {
    final existing = await db.rawQuery('PRAGMA table_info($tableName)');
    if (existing.isEmpty) return;

    final existingCols = existing.map((r) => r['name'] as String).toSet();
    final missing = columns
        .map((column) => column.trim())
        .where((column) => column.isNotEmpty && !existingCols.contains(column))
        .toList()
      ..sort();
    if (missing.isNotEmpty) {
      final source = sourceLabel.trim().isEmpty ? '' : ' ($sourceLabel)';
      throw StateError(
        'Structure SQLite locale incompatible pour $tableName. '
        'Colonnes manquantes$source: ${missing.join(', ')}. '
        'Réinitialisez les données locales puis relancez le téléchargement.',
      );
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

  Future<void> _createAttributConfigMobileLocalTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attribut_config_mobile_local (
        id INTEGER PRIMARY KEY,
        nom_metier TEXT NOT NULL,
        nom_table TEXT NOT NULL,
        nom_champ TEXT NOT NULL,
        type_champ TEXT,
        primary_key INTEGER DEFAULT 0,
        foreign_key INTEGER DEFAULT 0,
        ordre INTEGER DEFAULT 0,
        titre_app TEXT,
        visible INTEGER DEFAULT 0,
        contraintes TEXT,
        nullable INTEGER DEFAULT 1,
        valeur_par_defaut TEXT,
        valeur_min TEXT,
        valeur_max TEXT,
        reference_fk TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS attribut_config_mobile_local_lookup_idx
      ON attribut_config_mobile_local (nom_metier, nom_table, visible, ordre, id)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS attribut_config_mobile_local_field_idx
      ON attribut_config_mobile_local (nom_metier, nom_table, nom_champ)
    ''');
  }

  Future<void> _createFormulaireConfigMobileLocalTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS formulaire_config_mobile_local (
        id INTEGER PRIMARY KEY,
        nom_metier TEXT NOT NULL,
        nom_table TEXT NOT NULL,
        titre_app TEXT NOT NULL,
        ordre INTEGER DEFAULT 0,
        visible INTEGER DEFAULT 1,
        download_mobile INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    final columns = await db.rawQuery(
      'PRAGMA table_info(formulaire_config_mobile_local)',
    );
    final names = columns.map((row) => row['name']?.toString()).toSet();
    if (!names.contains('download_mobile')) {
      await db.execute(
        'ALTER TABLE formulaire_config_mobile_local '
        'ADD COLUMN download_mobile INTEGER DEFAULT 0',
      );
    }
    await db.execute('''
      CREATE INDEX IF NOT EXISTS formulaire_config_mobile_local_lookup_idx
      ON formulaire_config_mobile_local (nom_metier, visible, ordre, id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS formulaire_config_mobile_local_download_idx
      ON formulaire_config_mobile_local (nom_metier, download_mobile, ordre, id)
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS formulaire_config_mobile_local_table_idx
      ON formulaire_config_mobile_local (nom_metier, nom_table)
    ''');
  }

  Future<void> _createOnepDbLocalTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS onep_db (
        id INTEGER PRIMARY KEY,
        uuid TEXT UNIQUE,
        numero_contrat TEXT,
        ancienne_reference_sap TEXT,
        ancienne_police TEXT,
        nom_commune TEXT,
        nom_client TEXT,
        prenom_client TEXT,
        identifiant_geographique TEXT,
        etat_abonnement TEXT,
        adresse TEXT,
        downloaded INTEGER DEFAULT 1,
        synced INTEGER DEFAULT 1,
        date_sync TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS onep_db_num_contrat_idx
      ON onep_db (numero_contrat)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS onep_db_police_commune_idx
      ON onep_db (ancienne_police, nom_commune)
    ''');
  }

  Future<void> _createRegardMiroirCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS regard_miroir_cache_local (
        cache_key TEXT PRIMARY KEY,
        uuid TEXT,
        payload_json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS regard_miroir_cache_uuid_idx
      ON regard_miroir_cache_local (uuid)
    ''');

    await db.delete(
      'app_metadata',
      where: 'key = ?',
      whereArgs: [_regardMiroirCacheKey()],
    );
  }

  Future<void> _createCommuneLocalTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS commune_oriental_local (
        id_commune INTEGER PRIMARY KEY,
        id_province INTEGER,
        nom_commune TEXT,
        nom_province TEXT,
        nom_region TEXT,
        geometry_geojson TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS commune_oriental_local_name_idx
      ON commune_oriental_local (nom_commune, nom_province)
    ''');
  }

  Future<void> _ensureCommuneLocalTable(Database db) async {
    final existing =
        await db.rawQuery('PRAGMA table_info(commune_oriental_local)');
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
      await db.execute('DROP TABLE IF EXISTS commune_oriental_local');
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

  Future<void> _createReferenceOverlayLocalTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS planche_overlay_local (
        id INTEGER PRIMARY KEY,
        numero INTEGER,
        geometry_geojson TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS planche_overlay_local_numero_idx
      ON planche_overlay_local (numero)
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS fond_plan_overlay_local (
        fid INTEGER PRIMARY KEY,
        layer TEXT,
        color TEXT,
        linewidth REAL,
        geometry_geojson TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS fond_plan_overlay_local_layer_idx
      ON fond_plan_overlay_local (layer)
    ''');
  }

  Future<void> _migrateReferenceOverlayLocalTables(Database db) async {
    await _createReferenceOverlayLocalTables(db);
    await _ensureColumns(
      db,
      tableName: 'planche_overlay_local',
      columns: const {
        'id': 'INTEGER',
        'numero': 'INTEGER',
        'geometry_geojson': 'TEXT',
      },
    );
    await _ensureColumns(
      db,
      tableName: 'fond_plan_overlay_local',
      columns: const {
        'fid': 'INTEGER',
        'layer': 'TEXT',
        'color': 'TEXT',
        'linewidth': 'REAL',
        'geometry_geojson': 'TEXT',
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
      if (!existingCols.contains(entry.key)) {
        throw StateError(
          'Structure SQLite locale incompatible pour $tableName. '
          'Colonne manquante: ${entry.key}. '
          'Réinitialisez les données locales puis relancez le téléchargement.',
        );
      }
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
    if (!existingCols.contains('photo_context') ||
        !existingCols.contains('id_intervention_anomalie')) {
      await db.transaction((txn) async {
        await txn.execute(
          'ALTER TABLE photo_sync_queue RENAME TO photo_sync_queue_legacy',
        );
        await _createPhotoSyncQueueTable(txn);
        await txn.execute('''
          INSERT INTO photo_sync_queue (
            id,
            schema_name,
            table_name,
            uuid_objet,
            photo_slot,
            photo_context,
            id_intervention_anomalie,
            local_path,
            remote_path,
            date_prise_reelle,
            id_agent_crea,
            synced,
            retry_count,
            last_error,
            created_at,
            updated_at
          )
          SELECT
            id,
            schema_name,
            table_name,
            uuid_objet,
            photo_slot,
            'collecte_initiale',
            0,
            local_path,
            remote_path,
            date_prise_reelle,
            id_agent_crea,
            synced,
            retry_count,
            last_error,
            created_at,
            updated_at
          FROM photo_sync_queue_legacy
        ''');
        await txn.execute('DROP TABLE photo_sync_queue_legacy');
      });
      return _migratePhotoSyncQueueTable(db);
    }

    final requiredColumns = <String, String>{
      'schema_name': 'TEXT',
      'table_name': 'TEXT',
      'uuid_objet': 'TEXT',
      'photo_slot': 'INTEGER',
      'photo_context': 'TEXT',
      'id_intervention_anomalie': 'INTEGER',
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
      if (!existingCols.contains(entry.key)) {
        throw StateError(
          'Structure SQLite locale incompatible pour photo_sync_queue. '
          'Colonne manquante: ${entry.key}. '
          'Réinitialisez les données locales puis relancez le téléchargement.',
        );
      }
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
        await _assertSrmTableStructure(db, tableName);
      }
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ UTILISATEUR SRM (login + mot_de_passe en clair)
  // ══════════════════════════════════════════════════════

  Future<void> _assertAllSrmEntityTablesPresentAndAligned(Database db) async {
    for (final tableName in _allowedSrmTables()) {
      if (_supportTablesWithCustomSchema.contains(tableName)) {
        continue;
      }
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      if (tables.isEmpty) {
        throw StateError(
          'Table métier SQLite locale manquante: $tableName. '
          'Le mobile ne crée plus les tables métier à chaud. '
          'Réinitialisez les données locales pour recréer la structure depuis '
          'attribut_config_mobile / srm_server_columns.',
        );
      }
      await _assertSrmTableStructure(db, tableName);
    }
  }

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

  Future<Map<String, dynamic>?> getActiveSessionUser({
    Duration maxAge = srmSessionDuration,
  }) async {
    try {
      final db = await database;
      final session = await db.query('srm_session', limit: 1);
      if (session.isEmpty) return null;

      final row = session.first;
      if (_toInt(row['is_logged_in']) != 1) return null;

      if (!_isSessionFresh(row, maxAge: maxAge)) {
        await _expireSrmSessionRow(row);
        return null;
      }

      final login = row['current_login'] as String?;
      if (login == null || login.isEmpty) return null;

      final user = await db.query(
        'utilisateur_local',
        where: 'login = ?',
        whereArgs: [login],
        limit: 1,
      );
      return user.isNotEmpty ? user.first : null;
    } catch (e) {
      debugPrint('Erreur getActiveSessionUser: $e');
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
        final row = result.first;
        final isLogged = _toInt(row['is_logged_in']);
        if (isLogged == 1) {
          if (!_isSessionFresh(row, maxAge: srmSessionDuration)) {
            await _expireSrmSessionRow(row);
            return null;
          }
          return row['current_login'] as String?;
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

  DateTime? _parseSessionDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool _isSessionFresh(
    Map<String, dynamic> row, {
    required Duration maxAge,
  }) {
    final lastLogin = _parseSessionDate(row['last_login']);
    if (lastLogin == null) return false;
    final now = DateTime.now();
    if (lastLogin.isAfter(now.add(const Duration(minutes: 5)))) {
      return true;
    }
    return now.difference(lastLogin.toLocal()) <= maxAge;
  }

  Future<void> _expireSrmSessionRow(Map<String, dynamic> row) async {
    final db = await database;
    final remember = _toInt(row['remember_me']);
    if (remember == 1) {
      await db.update(
        'srm_session',
        {'is_logged_in': 0},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    } else {
      await db.delete(
        'srm_session',
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await recordLocalEvent(
      eventType: 'SESSION_EXPIRED',
      tableName: 'srm_session',
      cleLigne: row['current_login']?.toString(),
      payload: {
        'login': row['current_login'],
        'remember_me': remember,
        'max_age_days': srmSessionDuration.inDays,
      },
    );
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

  Future<({int id, bool wasInserted})> upsertDownloadedEntitySrm(
      String tableName, Map<String, dynamic> data,
      {bool recordHistory = false}) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    await _assertSrmTableExists(db, tableName);
    final cleaned = _sanitizeSrmPayload(tableName, data);
    // Le mobile ne modifie plus les tables metier a chaud. Toute colonne
    // acceptee ici doit deja exister dans la structure locale generee depuis
    // attribut_config_mobile / srm_server_columns.
    await _ensurePayloadColumnsMigrated(db, tableName, cleaned.keys);
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
        debugPrint(
            'SRM upsertDownloadedEntitySrm -> $tableName uuid=$uuid (UPDATE)');
        return (id: localId is int ? localId : 0, wasInserted: false);
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
    debugPrint('SRM upsertDownloadedEntitySrm -> $tableName (INSERT id=$id)');
    return (id: id, wasInserted: true);
  }

  Future<List<Map<String, dynamic>>> getEntities(String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }

  // ══════════════════════════════════════════════════════
  // ██ ENTITÉS SRM (EP / ASS) — SPRINT 5
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
      id_province INTEGER,
      latitude_gps REAL,
      longitude_gps REAL,
      altitude_gps REAL,
      altitude_z_moy REAL,
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
      date_sync TEXT,
      objet_incomplet INTEGER DEFAULT 0
    ''';

    final dynamicColLines = _srmDynamicColumnsForTable(tableName, fields)
        .entries
        .map((entry) => '  ${entry.key} ${entry.value}')
        .toList();

    final dynamicCols = dynamicColLines.join(',\n');
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
      'id_province',
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
      'objet_incomplet',
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
    await _ensurePayloadColumnsMigrated(db, tableName, cleaned.keys);

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
    await _ensurePayloadColumnsMigrated(db, tableName, cleaned.keys);
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

  Future<void> markLocalHistoryForObjectSynced({
    required String tableName,
    required Map<String, dynamic> row,
  }) async {
    _assertAllowedSrmTable(tableName);
    final db = await database;
    await _markLocalHistoryTableForObjectSynced(
      db,
      historyTableName: 'historique_local_attribut',
      tableName: tableName,
      row: row,
    );
    await _markLocalHistoryTableForObjectSynced(
      db,
      historyTableName: 'historique_local_evenement',
      tableName: tableName,
      row: row,
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

  Future<void> _markLocalHistoryTableForObjectSynced(
    Database db, {
    required String historyTableName,
    required String tableName,
    required Map<String, dynamic> row,
  }) async {
    if (!await _tableExistsInDb(db, historyTableName)) return;

    final uuidObjet = (row['uuid'] ?? row['uuid_objet'])?.toString().trim();
    final idObjet = _asInt(row['id']) ?? _asInt(row['id_objet']);
    final clauses = <String>[];
    final args = <Object?>[];

    if (uuidObjet != null && uuidObjet.isNotEmpty) {
      clauses.add('uuid_objet = ?');
      args.add(uuidObjet);
      clauses.add('cle_ligne = ?');
      args.add(uuidObjet);
    }
    if (idObjet != null) {
      clauses.add('id_objet = ?');
      args.add(idObjet);
      clauses.add('cle_ligne = ?');
      args.add(idObjet.toString());
    }
    if (clauses.isEmpty) return;

    await db.update(
      historyTableName,
      {
        'synced': 1,
        'date_sync': DateTime.now().toIso8601String(),
        'last_error': null,
      },
      where:
          '(synced IS NULL OR synced = 0) AND nom_table = ? AND (${clauses.join(' OR ')})',
      whereArgs: [tableName, ...args],
    );
  }

  Future<void> _markLocalHistoryForAlreadySyncedObjects(Database db) async {
    for (final historyTableName in const [
      'historique_local_attribut',
      'historique_local_evenement',
    ]) {
      if (!await _tableExistsInDb(db, historyTableName)) continue;

      for (final tableName in _allowedSrmTables()) {
        if (!await _tableExistsInDb(db, tableName)) continue;

        final columns = await _columnsForTableInDb(db, tableName);
        if (!columns.contains('id') || !columns.contains('synced')) continue;

        final tableSql = _quoteSqliteIdentifier(tableName);
        final uuidPredicates = columns.contains('uuid')
            ? '''
              OR (
                $historyTableName.uuid_objet IS NOT NULL
                AND $historyTableName.uuid_objet = synced_object.uuid
              )
              OR (
                $historyTableName.cle_ligne IS NOT NULL
                AND $historyTableName.cle_ligne = synced_object.uuid
              )
            '''
            : '';
        final updated = await db.rawUpdate(
          '''
          UPDATE $historyTableName
          SET synced = 1,
              date_sync = COALESCE(date_sync, ?),
              last_error = NULL
          WHERE (synced IS NULL OR synced = 0)
            AND nom_table = ?
            AND EXISTS (
              SELECT 1
              FROM $tableSql AS synced_object
              WHERE COALESCE(synced_object.synced, 0) = 1
                AND (
                  (
                    $historyTableName.id_objet IS NOT NULL
                    AND $historyTableName.id_objet = synced_object.id
                  )
                  OR (
                    $historyTableName.cle_ligne IS NOT NULL
                    AND $historyTableName.cle_ligne = CAST(synced_object.id AS TEXT)
                  )
                  $uuidPredicates
                )
            )
          ''',
          [DateTime.now().toIso8601String(), tableName],
        );
        if (updated > 0) {
          debugPrint(
            'Historique local clos: $updated ligne(s) pour $tableName',
          );
        }
      }
    }
  }

  Future<bool> _tableExistsInDb(Database db, String tableName) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return tables.isNotEmpty;
  }

  Future<Set<String>> _columnsForTableInDb(
    Database db,
    String tableName,
  ) async {
    final rows = await db
        .rawQuery('PRAGMA table_info(${_quoteSqliteIdentifier(tableName)})');
    return rows
        .map((row) => row['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  String _quoteSqliteIdentifier(String value) {
    return '"${value.replaceAll('"', '""')}"';
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
      'uuid': existing?['uuid'] ?? const Uuid().v4(),
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
      'etat_exploitant': row['etat_exploitant']?.toString(),
      'commentaire_exploitant': row['commentaire_exploitant']?.toString(),
      'date_exploitant': row['date_exploitant']?.toString(),
      'etat_terrain': row['etat_terrain']?.toString(),
      'commentaire_terrain': row['commentaire_terrain']?.toString(),
      'date_terrain': row['date_terrain']?.toString(),
      'id_user_terrain': _asInt(row['id_user_terrain']),
      'etat_bureau': row['etat_bureau']?.toString(),
      'commentaire_bureau': row['commentaire_bureau']?.toString(),
      'date_bureau': row['date_bureau']?.toString(),
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
        'etat_exploitant': remote['etat_exploitant']?.toString(),
        'commentaire_exploitant': remote['commentaire_exploitant']?.toString(),
        'date_exploitant': remote['date_exploitant']?.toString(),
        'etat_terrain': remote['etat_terrain']?.toString(),
        'commentaire_terrain': remote['commentaire_terrain']?.toString(),
        'date_terrain': remote['date_terrain']?.toString(),
        'id_user_terrain': _asInt(remote['id_user_terrain']),
        'etat_bureau': remote['etat_bureau']?.toString(),
        'commentaire_bureau': remote['commentaire_bureau']?.toString(),
        'date_bureau': remote['date_bureau']?.toString(),
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

  static const String _interventionActiveWhere =
      "(statut IS NULL OR lower(statut) NOT IN ('cloture', 'annule'))";
  static const String _interventionExploitantPendingWhere =
      "lower(COALESCE(responsable_actuel, '')) = 'exploitant' "
      "AND lower(COALESCE(etat_exploitant, 'en_attente')) NOT IN "
      "('traite', 'traité', 'resolu', 'résolu', 'cloture', 'clôture')";
  static const String _interventionTerrainReturnWhere =
      "(COALESCE(retour_terrain, 0) = 1 "
      "OR lower(COALESCE(responsable_actuel, '')) = 'terrain' "
      "OR lower(COALESCE(etat_exploitant, '')) IN ('traite', 'traité')) "
      "AND lower(COALESCE(etat_terrain, 'en_attente')) "
      "NOT IN ('traite', 'traité')";
  static const String _interventionTerrainDoneWhere =
      "lower(COALESCE(etat_terrain, '')) IN ('traite', 'traité')";

  Future<Map<String, int>> getInterventionAnomalieTreatmentSummary() async {
    final db = await database;
    await _ensureInterventionAnomalieTerrainTable(db);
    final rows = await db.rawQuery('''
      SELECT
        COUNT(*) AS total_active,
        SUM(CASE WHEN $_interventionExploitantPendingWhere
            THEN 1 ELSE 0 END) AS en_attente_exploitant,
        SUM(CASE WHEN $_interventionTerrainReturnWhere
            THEN 1 ELSE 0 END) AS retour_terrain_a_faire,
        SUM(CASE WHEN $_interventionTerrainDoneWhere
            THEN 1 ELSE 0 END) AS retour_terrain_effectue
      FROM intervention_anomalie
      WHERE $_interventionActiveWhere
    ''');
    final row = rows.isEmpty ? const <String, dynamic>{} : rows.first;
    return {
      'total_active': _asInt(row['total_active']) ?? 0,
      'en_attente_exploitant': _asInt(row['en_attente_exploitant']) ?? 0,
      'retour_terrain_a_faire': _asInt(row['retour_terrain_a_faire']) ?? 0,
      'retour_terrain_effectue': _asInt(row['retour_terrain_effectue']) ?? 0,
    };
  }

  Future<List<Map<String, dynamic>>> getInterventionAnomalieTreatmentItems({
    String filter = 'retour_terrain_a_faire',
    int limit = 500,
  }) async {
    final db = await database;
    await _ensureInterventionAnomalieTerrainTable(db);

    final where = switch (filter) {
      'en_attente_exploitant' =>
        '$_interventionActiveWhere AND ($_interventionExploitantPendingWhere)',
      'retour_terrain_effectue' =>
        '$_interventionActiveWhere AND ($_interventionTerrainDoneWhere)',
      'all' => _interventionActiveWhere,
      _ => '$_interventionActiveWhere AND ($_interventionTerrainReturnWhere)',
    };

    return await db.rawQuery('''
      SELECT *
      FROM intervention_anomalie
      WHERE $where
      ORDER BY
        COALESCE(updated_at, date_exploitant, date_bureau, date_creation,
                 date_collecte, '') DESC,
        id DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<Map<String, dynamic>?> getEntitySrmByIdOrUuid(
    String tableName, {
    int? idObjet,
    String? uuidObjet,
  }) async {
    try {
      _assertAllowedSrmTable(tableName);
      final db = await database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      if (tables.isEmpty) return null;

      final pragma = await db.rawQuery(
        'PRAGMA table_info(${_quoteSqlIdentifier(tableName)})',
      );
      final columns = pragma.map((row) => row['name'].toString()).toSet();
      final uuid = uuidObjet?.trim();
      if (uuid != null && uuid.isNotEmpty) {
        for (final column in ['uuid', 'uuid_objet']) {
          if (!columns.contains(column)) continue;
          final rows = await db.query(
            tableName,
            where: '$column = ?',
            whereArgs: [uuid],
            limit: 1,
          );
          if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
        }
      }

      if (idObjet != null) {
        final pkColumns = pragma
            .where((row) => (_asInt(row['pk']) ?? 0) > 0)
            .map((row) => row['name'].toString());
        final idColumns = <String>{
          ...pkColumns,
          'id',
          'fid',
          'gid',
          'id_objet',
        };
        for (final column in idColumns) {
          if (!columns.contains(column)) continue;
          final rows = await db.query(
            tableName,
            where: '$column = ?',
            whereArgs: [idObjet],
            limit: 1,
          );
          if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
        }
      }
    } catch (e) {
      debugPrint('❌ getEntitySrmByIdOrUuid $tableName: $e');
    }
    return null;
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

  /// Récupère la conduite locale pour ce métier/agent/jour, qu'elle soit
  /// synchronisée ou en attente. Le caller distingue via le champ `synced`
  /// (1 = déjà validée et envoyée au serveur, 0/null = en attente).
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
      where: 'metier = ? AND id_agent = ? AND jour = ?',
      whereArgs: [metier, idAgent, jourKey],
      orderBy: 'COALESCE(synced, 0) DESC, id DESC',
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
    String photoContext = 'collecte_initiale',
    int idInterventionAnomalie = 0,
    int? idAgentCrea,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toIso8601String();
    final cleanContext = _normalizePhotoContext(photoContext);
    final existing = await db.query(
      'photo_sync_queue',
      where: 'schema_name = ? AND table_name = ? AND uuid_objet = ? '
          'AND photo_context = ? AND COALESCE(id_intervention_anomalie, 0) = ? '
          'AND photo_slot = ?',
      whereArgs: [
        schemaName,
        tableName,
        uuidObjet,
        cleanContext,
        idInterventionAnomalie,
        photoSlot,
      ],
      limit: 1,
    );
    if (existing.isNotEmpty && _toInt(existing.first['synced']) == 1) {
      return _toInt(existing.first['id']);
    }

    final payload = <String, dynamic>{
      'schema_name': schemaName,
      'table_name': tableName,
      'uuid_objet': uuidObjet,
      'photo_slot': photoSlot,
      'photo_context': cleanContext,
      'id_intervention_anomalie': idInterventionAnomalie,
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
        cleLigne: '$tableName|$uuidObjet|$cleanContext|$photoSlot',
        uuidObjet: uuidObjet,
        payload: {
          'schema_name': schemaName,
          'table_name': tableName,
          'photo_slot': photoSlot,
          'photo_context': cleanContext,
          'id_intervention_anomalie': idInterventionAnomalie,
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
      cleLigne: '$tableName|$uuidObjet|$cleanContext|$photoSlot',
      uuidObjet: uuidObjet,
      payload: {
        'schema_name': schemaName,
        'table_name': tableName,
        'photo_slot': photoSlot,
        'photo_context': cleanContext,
        'id_intervention_anomalie': idInterventionAnomalie,
      },
    );
    return existingId;
  }

  String _normalizePhotoContext(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'anomalie_avant':
      case 'retour_terrain_apres':
      case 'incomplet_initial':
      case 'incomplet_complement':
      case 'collecte_initiale':
        return normalized;
      default:
        return 'collecte_initiale';
    }
  }

  Future<void> cancelPhotoSyncItem({
    required String schemaName,
    required String tableName,
    required String uuidObjet,
    required int photoSlot,
    String photoContext = 'collecte_initiale',
    int idInterventionAnomalie = 0,
  }) async {
    final db = await database;
    final cleanContext = _normalizePhotoContext(photoContext);
    await db.delete(
      'photo_sync_queue',
      where: 'schema_name = ? AND table_name = ? AND uuid_objet = ? '
          'AND photo_context = ? AND COALESCE(id_intervention_anomalie, 0) = ? '
          'AND photo_slot = ? '
          'AND COALESCE(synced, 0) != 1',
      whereArgs: [
        schemaName,
        tableName,
        uuidObjet,
        cleanContext,
        idInterventionAnomalie,
        photoSlot,
      ],
    );
  }

  Future<List<Map<String, dynamic>>> getPhotoSyncItemsForObject({
    required String schemaName,
    required String tableName,
    required String uuidObjet,
    String? photoContext,
    int? idInterventionAnomalie,
  }) async {
    final db = await database;
    final where = StringBuffer(
      'schema_name = ? AND table_name = ? AND uuid_objet = ?',
    );
    final args = <Object?>[schemaName, tableName, uuidObjet];
    if (photoContext != null && photoContext.trim().isNotEmpty) {
      where.write(' AND photo_context = ?');
      args.add(_normalizePhotoContext(photoContext));
    }
    if (idInterventionAnomalie != null) {
      where.write(' AND COALESCE(id_intervention_anomalie, 0) = ?');
      args.add(idInterventionAnomalie);
    }
    return db.query(
      'photo_sync_queue',
      where: where.toString(),
      whereArgs: args,
      orderBy:
          'photo_context ASC, id_intervention_anomalie ASC, photo_slot ASC',
    );
  }

  Future<int> resolveInterventionAnomalieIdForObject({
    required String schemaName,
    required String tableName,
    String? uuidObjet,
    int? idObjet,
  }) async {
    final cleanUuid = uuidObjet?.trim() ?? '';
    if (cleanUuid.isEmpty && idObjet == null) return 0;

    final db = await database;
    await _ensureInterventionAnomalieTerrainTable(db);
    final schema = schemaName.trim().toLowerCase();
    final table = tableName.trim().toLowerCase();
    final qualifiedTable = schema.isEmpty ? table : '$schema.$table';
    final tableSuffix = schema.isEmpty ? null : '$schema.%';

    final whereParts = <String>[
      _interventionActiveWhere,
      if (cleanUuid.isNotEmpty) 'uuid_objet = ?' else 'id_objet = ?',
      if (schema.isNotEmpty || table.isNotEmpty)
        '''
        (
          lower(COALESCE(nom_table, '')) = ?
          OR lower(COALESCE(nom_table, '')) = ?
          OR lower(COALESCE(nom_classe, '')) = ?
          ${tableSuffix == null ? '' : "OR lower(COALESCE(nom_table, '')) LIKE ?"}
        )
        ''',
    ];
    final args = <Object?>[
      if (cleanUuid.isNotEmpty) cleanUuid else idObjet,
      if (schema.isNotEmpty || table.isNotEmpty) ...[
        table,
        qualifiedTable,
        table,
        if (tableSuffix != null) tableSuffix,
      ],
    ];

    final rows = await db.rawQuery('''
      SELECT id_intervention
      FROM intervention_anomalie
      WHERE ${whereParts.join(' AND ')}
      ORDER BY
        CASE
          WHEN $_interventionTerrainReturnWhere THEN 0
          WHEN $_interventionExploitantPendingWhere THEN 1
          ELSE 2
        END,
        COALESCE(updated_at, date_exploitant, date_bureau, date_creation,
                 date_collecte, '') DESC,
        id DESC
      LIMIT 1
    ''', args);
    if (rows.isEmpty) return 0;
    return _asInt(rows.first['id_intervention']) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getPendingPhotoSyncItems({
    int limit = 200,
  }) async {
    final db = await database;
    return db.query(
      'photo_sync_queue',
      where: '(synced IS NULL OR synced = 0) AND COALESCE(retry_count, 0) < 5',
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  Future<int> countFailedPhotoSyncItems() async {
    final db = await database;
    return _countRowsIfTableExists(
      db,
      'photo_sync_queue',
      where: "COALESCE(last_error, '') <> '' OR COALESCE(synced, 0) = -1",
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
    int? idInterventionAnomalie,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{
      'synced': 1,
      'remote_path': remotePath,
      'date_prise_reelle': datePriseReelle,
      'last_error': null,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (idInterventionAnomalie != null && idInterventionAnomalie > 0) {
      updates['id_intervention_anomalie'] = idInterventionAnomalie;
    }
    await db.update(
      'photo_sync_queue',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
    await recordLocalEvent(
      eventType: 'PHOTO_SYNC_SUCCESS',
      tableName: 'photo_sync_queue',
      idObjet: id,
      payload: {
        'remote_path': remotePath,
        if (idInterventionAnomalie != null && idInterventionAnomalie > 0)
          'id_intervention_anomalie': idInterventionAnomalie,
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
      SET retry_count = COALESCE(retry_count, 0) + 1,
          synced = CASE
            WHEN COALESCE(retry_count, 0) + 1 >= 5 THEN -1
            ELSE 0
          END,
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

  Future<void> rejectPhotoSyncItem(int id, String errorMessage) async {
    final db = await database;
    await db.update(
      'photo_sync_queue',
      {
        'synced': -1,
        'retry_count': 5,
        'last_error': errorMessage,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await recordLocalEvent(
      eventType: 'PHOTO_SYNC_REJECTED',
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
    // Tables techniques hors srm_config.
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
    for (final tableColumns in srmServerColumnsByTable.values) {
      columns.addAll(tableColumns.keys);
    }
    columns.addAll(_mobileOutputAliasColumns.values);
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

  static const Map<String, String> _mobileOutputAliasColumns = {
    'ep_ref_rue': 'ref_rue',
    'ep_observation': 'observation',
    'ep_conf_plan': 'conformite_plan',
    'ASS_CONF_PLAN': 'conformite_plan',
    'ASS_OBSERV': 'observation',
    'ASS_DATE_INTERV': 'date_leve',
    'ASS_COOR_X': 'ass_coor_x',
    'ASS_COOR_Y': 'ass_coor_y',
    'ASS_COOR_Z': 'ass_coor_z',
    'ASS_TYPE_RESEAU': 'typereseau',
    'ASS_STATUT': 'etat',
    'ASS_DIAM': 'diametre',
    'ASS_MAT': 'nature',
    'ASS_LONG_R': 'longueur',
  };

  Map<String, String> _srmDynamicColumnsForTable(
    String tableName,
    List<String> fields,
  ) {
    final columns = <String, String>{};

    void addColumn(String column, String type) {
      final normalized = column.trim();
      if (normalized.isEmpty) return;
      if (!_isAllowedSrmColumn(normalized) || _isFixedCol(normalized)) return;
      if (_caseInsensitiveKey(columns.keys, normalized) != null) return;
      columns[normalized] = type.trim().isEmpty ? 'TEXT' : type.trim();
    }

    for (final field in fields) {
      addColumn(field, _sqliteTypeForField(field));
    }

    final serverColumns = srmServerColumnsByTable[tableName] ?? const {};
    for (final entry in serverColumns.entries) {
      addColumn(entry.key, entry.value);
    }

    // Backend mobile endpoints also return stable aliases. Keep these aliases
    // in SQLite whenever their source column is part of the downloaded table.
    for (final entry in _mobileOutputAliasColumns.entries) {
      final sourceKey = _caseInsensitiveKey(columns.keys, entry.key);
      if (sourceKey == null) continue;
      addColumn(
          entry.value, columns[sourceKey] ?? _sqliteTypeForField(sourceKey));
    }

    return columns;
  }

  String? _caseInsensitiveKey(Iterable<String> keys, String value) {
    final target = value.toLowerCase();
    for (final key in keys) {
      if (key.toLowerCase() == target) return key;
    }
    return null;
  }

  static const Set<String> _fixedSrmColumns = {
    'id', 'fid', 'uuid', 'id_agent_crea',
    'id_planche', 'id_commune', 'id_province', 'latitude_gps', 'longitude_gps',
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
    'id_province': 'INTEGER',
    'latitude_gps': 'REAL',
    'longitude_gps': 'REAL',
    'altitude_gps': 'REAL',
    'altitude_z_moy': 'REAL',
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
        case 'id_province':
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
    await _ensureColumns(
      db,
      tableName: tableName,
      columns: _migratableFixedSrmColumns,
    );
  }

  Future<void> _ensureSrmEntityColumns(
    Database db,
    String tableName,
    List<String> fields,
  ) async {
    final entityColumns = _srmDynamicColumnsForTable(tableName, fields);
    if (entityColumns.isEmpty) return;
    await _ensureColumns(
      db,
      tableName: tableName,
      columns: entityColumns,
    );
  }

  Future<void> _ensurePayloadColumnsMigrated(
    Database db,
    String tableName,
    Iterable<String> payloadColumns,
  ) async {
    final payloadColumnsToCheck = <String>{};
    for (final raw in payloadColumns) {
      final column = raw.trim();
      if (column.isEmpty) continue;
      if (column == 'id') continue;
      payloadColumnsToCheck.add(column);
    }
    if (payloadColumnsToCheck.isEmpty) return;
    await _assertColumnsPresent(
      db,
      tableName: tableName,
      columns: payloadColumnsToCheck,
      sourceLabel: 'payload serveur',
    );
  }

  Future<void> _assertSrmTableExists(Database db, String tableName) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    if (tables.isEmpty) {
      throw StateError(
        'Table métier SQLite locale manquante pour $tableName. '
        'Le mobile ne crée plus les tables métier à chaud. '
        'Réinitialisez les données locales puis relancez le téléchargement.',
      );
    }

    await _assertSrmTableStructure(db, tableName);
  }

  static const Set<String> _supportTablesWithCustomSchema = {
    'objet_incomplet',
    'raison_incomplet',
    'intervention_anomalie',
  };

  Future<void> _assertSrmTableStructure(Database db, String tableName) async {
    // Les tables de support (objet_incomplet, intervention_anomalie...) ont
    // leur propre schema strict gere par _ensureObjetIncompletTable /
    // _ensureInterventionAnomalieTerrainTable. Elles n'ont pas les colonnes
    // geometriques "fixes" des tables metier (latitude_gps, anomalie, etc.),
    // donc on ne doit pas leur appliquer _ensureSrmFixedColumns.
    if (_supportTablesWithCustomSchema.contains(tableName)) {
      return;
    }
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

  Future<void> replaceAttributConfigMobile({
    required List<Map<String, dynamic>> rows,
    String? nomMetier,
    String? nomTable,
  }) async {
    final db = await database;
    await _createAttributConfigMobileLocalTable(db);

    await db.transaction((txn) async {
      if ((nomMetier ?? '').trim().isNotEmpty &&
          (nomTable ?? '').trim().isNotEmpty) {
        await txn.delete(
          'attribut_config_mobile_local',
          where: 'nom_metier = ? AND nom_table = ?',
          whereArgs: [nomMetier!.trim(), nomTable!.trim()],
        );
      } else if ((nomMetier ?? '').trim().isNotEmpty) {
        await txn.delete(
          'attribut_config_mobile_local',
          where: 'nom_metier = ?',
          whereArgs: [nomMetier!.trim()],
        );
      } else {
        await txn.delete('attribut_config_mobile_local');
      }

      for (final row in rows) {
        final id = _asInt(row['id']);
        final metier = (row['nom_metier'] ?? '').toString().trim();
        final table = (row['nom_table'] ?? '').toString().trim();
        final champ = (row['nom_champ'] ?? '').toString().trim();
        if (id == null || metier.isEmpty || table.isEmpty || champ.isEmpty) {
          continue;
        }

        await txn.insert(
          'attribut_config_mobile_local',
          {
            'id': id,
            'nom_metier': metier,
            'nom_table': table,
            'nom_champ': champ,
            'type_champ': row['type_champ']?.toString(),
            'primary_key': _toSqlBool(row['primary_key']),
            'foreign_key': _toSqlBool(row['foreign_key']),
            'ordre': _asInt(row['ordre']) ?? 0,
            'titre_app': row['titre_app']?.toString(),
            'visible': _toSqlBool(row['visible']),
            'contraintes': row['contraintes']?.toString(),
            'nullable': _toSqlBool(row['nullable'], defaultValue: true),
            'valeur_par_defaut': row['valeur_par_defaut']?.toString(),
            'valeur_min': row['valeur_min']?.toString(),
            'valeur_max': row['valeur_max']?.toString(),
            'reference_fk': row['reference_fk']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAttributConfigMobile({
    required String nomMetier,
    required String nomTable,
    bool visibleOnly = false,
  }) async {
    final db = await database;
    await _createAttributConfigMobileLocalTable(db);

    final where = StringBuffer('nom_metier = ? AND nom_table = ?');
    final whereArgs = <Object?>[nomMetier, nomTable];
    if (visibleOnly) {
      where.write(' AND visible = 1');
    }

    return db.query(
      'attribut_config_mobile_local',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'ordre ASC, id ASC',
    );
  }

  Future<void> replaceFormulaireConfigMobile({
    required List<Map<String, dynamic>> rows,
    String? nomMetier,
    String? nomTable,
  }) async {
    final db = await database;
    await _createFormulaireConfigMobileLocalTable(db);

    await db.transaction((txn) async {
      if ((nomMetier ?? '').trim().isNotEmpty &&
          (nomTable ?? '').trim().isNotEmpty) {
        await txn.delete(
          'formulaire_config_mobile_local',
          where: 'nom_metier = ? AND nom_table = ?',
          whereArgs: [nomMetier!.trim(), nomTable!.trim()],
        );
      } else if ((nomMetier ?? '').trim().isNotEmpty) {
        await txn.delete(
          'formulaire_config_mobile_local',
          where: 'nom_metier = ?',
          whereArgs: [nomMetier!.trim()],
        );
      } else {
        await txn.delete('formulaire_config_mobile_local');
      }

      for (final row in rows) {
        final id = _asInt(row['id']);
        final metier = (row['nom_metier'] ?? '').toString().trim();
        final table = (row['nom_table'] ?? '').toString().trim();
        final titre = (row['titre_app'] ?? '').toString().trim();
        if (id == null || metier.isEmpty || table.isEmpty || titre.isEmpty) {
          continue;
        }

        await txn.insert(
          'formulaire_config_mobile_local',
          {
            'id': id,
            'nom_metier': metier,
            'nom_table': table,
            'titre_app': titre,
            'ordre': _asInt(row['ordre']) ?? 0,
            'visible': _toSqlBool(row['visible'], defaultValue: true),
            'download_mobile': _toSqlBool(
              row['download_mobile'],
              defaultValue: _toSqlBool(row['visible'], defaultValue: true) == 1,
            ),
            'created_at': row['created_at']?.toString(),
            'updated_at': row['updated_at']?.toString(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getFormulaireConfigMobile({
    String? nomMetier,
    String? nomTable,
    bool visibleOnly = false,
    bool downloadOnly = false,
  }) async {
    final db = await database;
    await _createFormulaireConfigMobileLocalTable(db);

    final whereParts = <String>[];
    final whereArgs = <Object?>[];
    if ((nomMetier ?? '').trim().isNotEmpty) {
      whereParts.add('nom_metier = ?');
      whereArgs.add(nomMetier!.trim());
    }
    if ((nomTable ?? '').trim().isNotEmpty) {
      whereParts.add('nom_table = ?');
      whereArgs.add(nomTable!.trim());
    }
    if (visibleOnly) {
      whereParts.add('visible = 1');
    }
    if (downloadOnly) {
      whereParts.add('download_mobile = 1');
    }

    return db.query(
      'formulaire_config_mobile_local',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'nom_metier ASC, ordre ASC, id ASC',
    );
  }

  Future<void> upsertDownloadedOnepDb(Map<String, dynamic> row) async {
    final id = _asInt(row['id']);
    final uuid = row['uuid']?.toString().trim() ?? '';
    if (id == null && uuid.isEmpty) return;

    final db = await database;
    await _createOnepDbLocalTable(db);
    await db.insert(
      'onep_db',
      {
        if (id != null) 'id': id,
        if (uuid.isNotEmpty) 'uuid': uuid,
        'numero_contrat': row['numero_contrat']?.toString().trim(),
        'ancienne_reference_sap':
            row['ancienne_reference_sap']?.toString().trim(),
        'ancienne_police': row['ancienne_police']?.toString().trim(),
        'nom_commune': row['nom_commune']?.toString().trim(),
        'nom_client': row['nom_client']?.toString().trim(),
        'prenom_client': row['prenom_client']?.toString().trim(),
        'identifiant_geographique':
            row['identifiant_geographique']?.toString().trim(),
        'etat_abonnement': row['etat_abonnement']?.toString().trim(),
        'adresse': row['adresse']?.toString().trim(),
        'downloaded': 1,
        'synced': 1,
        'date_sync': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> countOnepDbRows() async {
    final db = await database;
    await _createOnepDbLocalTable(db);
    final result = await db.rawQuery('SELECT COUNT(*) AS total FROM onep_db');
    return _asInt(result.first['total']) ?? 0;
  }

  Future<Map<String, dynamic>?> findOnepCustomerLocal({
    String? numContrat,
    String? anciennePolice,
    double? x,
    double? y,
  }) async {
    final contract = numContrat?.trim() ?? '';
    final police = anciennePolice?.trim() ?? '';
    if (contract.isEmpty && police.isEmpty) return null;

    final db = await database;
    await _createOnepDbLocalTable(db);

    Map<String, dynamic>? spatialCommune;
    String? spatialName;
    String? spatialKey;
    if (x != null && y != null) {
      spatialCommune = await findCommuneLocalByPoint(x: x, y: y);
      spatialName = spatialCommune?['nom_commune']?.toString().trim();
      spatialKey = _onepCommuneKey(spatialName);
    }

    var warnings = <String>[];
    var rows = <Map<String, dynamic>>[];
    String? matchType;

    if (contract.isNotEmpty) {
      rows = await db.query(
        'onep_db',
        where: "TRIM(COALESCE(numero_contrat, '')) = ?",
        whereArgs: [contract],
        limit: 2,
      );
      if (rows.length > 1) {
        return _onepLocalResponse(
          matched: false,
          statusText: 'ambiguous_contract',
          warnings: ['Numéro de contrat ambigu dans ONEP : $contract'],
          spatialName: spatialName,
          spatialKey: spatialKey,
        );
      }
      if (rows.length == 1) {
        matchType = 'num_contrat';
      }
    }

    if (rows.isEmpty && police.isNotEmpty) {
      if (spatialKey == null || spatialKey.isEmpty) {
        warnings = [
          'Commune spatiale introuvable: liaison par ancienne police impossible.',
        ];
      } else if (!_isValidOldPolice(police)) {
        warnings = [
          'Ancienne police vide ou non exploitable pour la liaison ONEP.',
        ];
      } else {
        final policeRows = await db.query(
          'onep_db',
          where: "TRIM(COALESCE(ancienne_police, '')) = ?",
          whereArgs: [police],
        );
        rows = policeRows
            .where((row) => _onepCommuneKey(row['nom_commune']) == spatialKey)
            .take(2)
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        if (rows.length > 1) {
          return _onepLocalResponse(
            matched: false,
            statusText: 'ambiguous_old_police',
            warnings: [
              'Ancienne police ambiguë dans ONEP pour la commune '
                  '$spatialKey : $police',
            ],
            spatialName: spatialName,
            spatialKey: spatialKey,
          );
        }
        if (rows.length == 1) {
          matchType = 'ancienne_police_commune';
        }
      }
    }

    if (rows.isEmpty) {
      return _onepLocalResponse(
        matched: false,
        statusText: 'not_found',
        warnings: warnings,
        spatialName: spatialName,
        spatialKey: spatialKey,
      );
    }

    final row = Map<String, dynamic>.from(rows.first);
    final onepName = row['nom_commune']?.toString().trim();
    final onepKey = _onepCommuneKey(onepName);
    String? observationNote;
    if (matchType == 'num_contrat' &&
        spatialKey != null &&
        onepKey != null &&
        spatialKey != onepKey) {
      observationNote = 'Incohérence découpage client : ONEP='
          '${onepName?.isNotEmpty == true ? onepName : '?'}, '
          'spatial=$spatialKey. Liaison conservée par numéro de contrat.';
      warnings.add(observationNote);
    }

    return _onepLocalResponse(
      matched: true,
      statusText: 'matched',
      matchType: matchType,
      warnings: warnings,
      data: _onepLocalPayload(row),
      observationNote: observationNote,
      spatialName: spatialName,
      spatialKey: spatialKey,
      onepName: onepName,
      onepKey: onepKey,
    );
  }

  Map<String, dynamic> _onepLocalResponse({
    required bool matched,
    required String statusText,
    List<String> warnings = const [],
    Map<String, dynamic> data = const {},
    String? matchType,
    String? observationNote,
    String? spatialName,
    String? spatialKey,
    String? onepName,
    String? onepKey,
  }) {
    return {
      'matched': matched,
      'status': statusText,
      'match_type': matchType,
      'warnings': warnings,
      'observation_note': observationNote,
      'data': data,
      'source': 'local_onep_db',
      'commune': {
        'spatial_name': spatialName,
        'spatial_key': spatialKey,
        'onep_name': onepName,
        'onep_key': onepKey,
      },
    };
  }

  Map<String, dynamic> _onepLocalPayload(Map<String, dynamic> row) {
    final oldSap = row['ancienne_reference_sap']?.toString().trim() ?? '';
    return {
      'num_contrat': row['numero_contrat']?.toString().trim(),
      'ref': oldSap.isEmpty ? null : oldSap,
      'ancien_ref_sap': oldSap.isEmpty ? null : oldSap,
      'id_geo': row['identifiant_geographique']?.toString().trim(),
      'ancienne_police': row['ancienne_police']?.toString().trim(),
      'abon': row['prenom_client']?.toString().trim(),
      'nom': row['nom_client']?.toString().trim(),
      'adresse': row['adresse']?.toString().trim(),
      'etat_abonnement': row['etat_abonnement']?.toString().trim(),
      'type_abonnement': null,
    };
  }

  bool _isValidOldPolice(String value) {
    final text = value.trim().toUpperCase();
    return text.isNotEmpty && !{'NEANT', 'N\u00C9ANT', 'NULL'}.contains(text);
  }

  String? _onepCommuneKey(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    var normalized = _stripDiacritics(text).toUpperCase();
    normalized = normalized.replaceAll(RegExp(r'[^A-Z0-9]+'), ' ').trim();
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    const aliases = {
      'LABSARA': 'BSARA',
    };
    return aliases[normalized] ?? normalized;
  }

  String _stripDiacritics(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.runes) {
      switch (codeUnit) {
        case 0x00C0:
        case 0x00C1:
        case 0x00C2:
        case 0x00C3:
        case 0x00C4:
        case 0x00C5:
          buffer.write('A');
          break;
        case 0x00E0:
        case 0x00E1:
        case 0x00E2:
        case 0x00E3:
        case 0x00E4:
        case 0x00E5:
          buffer.write('a');
          break;
        case 0x00C7:
          buffer.write('C');
          break;
        case 0x00E7:
          buffer.write('c');
          break;
        case 0x00C8:
        case 0x00C9:
        case 0x00CA:
        case 0x00CB:
          buffer.write('E');
          break;
        case 0x00E8:
        case 0x00E9:
        case 0x00EA:
        case 0x00EB:
          buffer.write('e');
          break;
        case 0x00CC:
        case 0x00CD:
        case 0x00CE:
        case 0x00CF:
          buffer.write('I');
          break;
        case 0x00EC:
        case 0x00ED:
        case 0x00EE:
        case 0x00EF:
          buffer.write('i');
          break;
        case 0x00D1:
          buffer.write('N');
          break;
        case 0x00F1:
          buffer.write('n');
          break;
        case 0x00D2:
        case 0x00D3:
        case 0x00D4:
        case 0x00D5:
        case 0x00D6:
          buffer.write('O');
          break;
        case 0x00F2:
        case 0x00F3:
        case 0x00F4:
        case 0x00F5:
        case 0x00F6:
          buffer.write('o');
          break;
        case 0x00D9:
        case 0x00DA:
        case 0x00DB:
        case 0x00DC:
          buffer.write('U');
          break;
        case 0x00F9:
        case 0x00FA:
        case 0x00FB:
        case 0x00FC:
          buffer.write('u');
          break;
        case 0x00DD:
        case 0x0178:
          buffer.write('Y');
          break;
        case 0x00FD:
        case 0x00FF:
          buffer.write('y');
          break;
        default:
          buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  int _toSqlBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue ? 1 : 0;
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value == 0 ? 0 : 1;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return defaultValue ? 1 : 0;
    return ['1', 'true', 't', 'yes', 'oui'].contains(text) ? 1 : 0;
  }

  Future<void> replaceCommunes({
    required List<Map<String, dynamic>> communes,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('commune_oriental_local');

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
          'commune_oriental_local',
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

  Future<void> replacePlancheOverlay({
    required List<Map<String, dynamic>> planches,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('planche_overlay_local');
      for (final planche in planches) {
        final id = _asInt(planche['id']);
        if (id == null) continue;
        await txn.insert(
          'planche_overlay_local',
          {
            'id': id,
            'numero': _asInt(planche['numero']),
            'geometry_geojson': _encodeGeoJson(planche['geometry_geojson']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> replaceFondPlanOverlay({
    required List<Map<String, dynamic>> features,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('fond_plan_overlay_local');
      for (final feature in features) {
        final fid = _asInt(feature['fid']);
        if (fid == null) continue;
        await txn.insert(
          'fond_plan_overlay_local',
          {
            'fid': fid,
            'layer': feature['layer']?.toString(),
            'color': feature['color']?.toString(),
            'linewidth': _asDouble(feature['linewidth']),
            'geometry_geojson': _encodeGeoJson(feature['geometry_geojson']),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getPlancheOverlayLocal() async {
    final db = await database;
    return db.query(
      'planche_overlay_local',
      orderBy: 'numero, id',
    );
  }

  Future<List<Map<String, dynamic>>> getFondPlanOverlayLocal() async {
    final db = await database;
    return db.query(
      'fond_plan_overlay_local',
      orderBy: 'layer, fid',
    );
  }

  static String? _encodeGeoJson(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return jsonEncode(value);
  }

  Future<List<Map<String, dynamic>>> getCommunesLocal() async {
    final db = await database;
    return db.query(
      'commune_oriental_local',
      orderBy: 'nom_commune ASC, nom_province ASC',
    );
  }

  Future<Map<String, dynamic>?> findCommuneLocalByPoint({
    required double x,
    required double y,
  }) async {
    final db = await database;
    final rows = await db.query(
      'commune_oriental_local',
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
        debugPrint('⚠️ commune_oriental_local geometry ignoree: $e');
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

  Future<Map<String, dynamic>?> getRegionalBasemapState() async {
    final db = await database;
    final rows = await db.query(
      'regional_basemap_state',
      where: 'id = ?',
      whereArgs: ['region'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> upsertRegionalBasemapState({
    required String sha256,
    required String version,
    required String format,
    int? sizeBytes,
    String? localPath,
    String? downloadUrl,
    String? name,
    String? attribution,
    String? generatedAt,
    String? downloadedAt,
  }) async {
    final db = await database;
    await db.insert(
      'regional_basemap_state',
      {
        'id': 'region',
        'sha256': sha256,
        'version': version,
        'format': format,
        'size_bytes': sizeBytes,
        'local_path': localPath,
        'download_url': downloadUrl,
        'name': name,
        'attribution': attribution,
        'generated_at': generatedAt,
        'downloaded_at': downloadedAt,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearRegionalBasemapState() async {
    final db = await database;
    await db.delete(
      'regional_basemap_state',
      where: 'id = ?',
      whereArgs: ['region'],
    );
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

  /// Sauve l'horodatage d'une synchro COMPLETE (failedCount==0). Distinct
  /// de `last_sync_time` qui marque la derniere sync au moins partielle :
  /// `last_sync_time`      -> label visuel "Sync: HH:mm"
  /// `last_full_sync_time` -> court-circuit "rien a synchro" + dialog
  Future<void> saveLastFullSyncTime(DateTime dt) async {
    final db = await database;
    await db.insert(
      'app_metadata',
      {'key': 'last_full_sync_time', 'value': dt.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> getLastFullSyncTime() async {
    final db = await database;
    final res = await db.query('app_metadata',
        where: 'key = ?', whereArgs: ['last_full_sync_time'], limit: 1);
    if (res.isEmpty) return null;
    final raw = res.first['value'] as String?;
    if (raw == null) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }

  /// Compte les rows locales en attente de synchronisation (synced=0 ET
  /// downloaded=0) sur toutes les tables SRM. Utilise par le court-circuit
  /// du bouton Synchroniser : si 0 -> message direct "Aucune donnee a
  /// synchroniser" sans interroger le serveur.
  ///
  /// Les rows qui ont echoue lors d'un sync precedent restent `synced=0`
  /// et sont donc toujours comptees ici, garantissant qu'elles seront
  /// re-tentees au prochain clic sans etre faussement marquees "fait".
  Future<int> countPendingSync() async {
    final db = await database;
    int total = 0;
    for (final tableName in _allowedSrmTables()) {
      try {
        final exists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName],
        );
        if (exists.isEmpty) continue;
        final res = await db.rawQuery(
          'SELECT COUNT(*) AS n FROM "$tableName" '
          'WHERE (synced IS NULL OR synced = 0) '
          'AND (downloaded IS NULL OR downloaded = 0)',
        );
        if (res.isNotEmpty) {
          total += _toInt(res.first['n']);
        }
      } catch (e) {
        debugPrint('countPendingSync $tableName: $e');
      }
    }
    // Photos en attente d'envoi
    try {
      final res = await db.rawQuery(
        "SELECT COUNT(*) AS n FROM photo_sync_queue "
        "WHERE status IS NULL OR status IN ('pending','failed')",
      );
      if (res.isNotEmpty) {
        total += _toInt(res.first['n']);
      }
    } catch (_) {
      // Table absente sur builds anciens : ignore.
    }
    return total;
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

  String _regardMiroirCacheKey() => 'ep_regard_polygon_cache';

  Future<void> saveRegardMiroirCache(List<Map<String, dynamic>> items) async {
    final db = await database;
    await _createRegardMiroirCacheTable(db);

    await db.transaction((txn) async {
      await txn.delete('regard_miroir_cache_local');
      await txn.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: [_regardMiroirCacheKey()],
      );

      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final uuid = item['uuid']?.toString().trim();
        final id = item['id']?.toString().trim();
        final cacheKey = (uuid != null && uuid.isNotEmpty)
            ? uuid
            : (id != null && id.isNotEmpty)
                ? 'id:$id'
                : 'row:$index';
        await txn.insert(
          'regard_miroir_cache_local',
          {
            'cache_key': cacheKey,
            'uuid': uuid == null || uuid.isEmpty ? null : uuid,
            'payload_json': jsonEncode(item),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getRegardMiroirCache() async {
    final db = await database;
    await _createRegardMiroirCacheTable(db);
    final rows = await db.query(
      'regard_miroir_cache_local',
      orderBy: 'cache_key ASC',
    );
    if (rows.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final items = <Map<String, dynamic>>[];
    for (final row in rows) {
      final raw = row['payload_json']?.toString();
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          items.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        continue;
      }
    }
    return items;
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

  /// Horodatage du dernier login (= debut de la session courante). Utilise
  /// par le court-circuit "Donnees deja telechargees" cote home_page pour
  /// eviter de retaper le serveur a chaque clic du bouton Telecharger
  /// pendant la meme session de login.
  Future<DateTime?> getLastLoginAt() async {
    try {
      final db = await database;
      final rows = await db.query(
        'srm_session',
        columns: ['last_login'],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final raw = rows.first['last_login']?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
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
