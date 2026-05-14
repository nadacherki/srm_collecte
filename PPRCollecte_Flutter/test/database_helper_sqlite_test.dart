import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:srm_collecte/data/local/database_helper.dart';
import 'package:srm_collecte/data/remote/api_service.dart';
import 'package:srm_collecte/services/displayed_points_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    ApiService.userId = null;
    await DatabaseHelper.resetForTest();
  });

  group('DatabaseHelper SQLite local', () {
    test('regard mirror cache uses its dedicated table, not app_metadata',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();

      await helper.saveAppMetadataValue('ep_regard_polygon_cache', 'legacy');
      await helper.saveRegardMiroirCache([
        {'id': 1, 'uuid': 'regard-1', 'longueur': 1.2},
        {'id': 2, 'uuid': 'regard-2', 'largeur': 0.8},
      ]);

      final cache = await helper.getRegardMiroirCache();
      final legacyMetadata =
          await helper.getAppMetadataValue('ep_regard_polygon_cache');
      final db = await helper.database;
      final rows = await db.query('regard_miroir_cache_local');

      expect(cache, hasLength(2));
      expect(cache.map((row) => row['uuid']),
          containsAll(['regard-1', 'regard-2']));
      expect(legacyMetadata, isNull);
      expect(rows, hasLength(2));
    });

    test('photo queue keeps pending rows and stops retry after threshold',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();

      final id = await helper.enqueuePhotoSyncItem(
        schemaName: 'ep',
        tableName: 'ep_brc_pt',
        uuidObjet: 'uuid-photo-1',
        photoSlot: 1,
        localPath: 'C:/tmp/photo_1.jpg',
      );

      expect(await helper.getPendingPhotoSyncItems(), hasLength(1));
      expect(await helper.countFailedPhotoSyncItems(), 0);

      for (var i = 0; i < 5; i++) {
        await helper.markPhotoSyncItemFailed(id, 'upload failed');
      }

      expect(await helper.getPendingPhotoSyncItems(), isEmpty);
      expect(await helper.countFailedPhotoSyncItems(), 1);

      final db = await helper.database;
      final row = (await db.query(
        'photo_sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      ))
          .single;
      expect(row['retry_count'], 5);
      expect(row['synced'], -1);
    });

    test('synced photos cannot be deleted or replaced locally', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();

      final id = await helper.enqueuePhotoSyncItem(
        schemaName: 'ep',
        tableName: 'ep_brc_pt',
        uuidObjet: 'uuid-photo-2',
        photoSlot: 1,
        localPath: 'C:/tmp/photo_initial.jpg',
      );
      await helper.markPhotoSyncItemSynced(id, remotePath: 'remote/photo.jpg');

      await helper.cancelPhotoSyncItem(
        schemaName: 'ep',
        tableName: 'ep_brc_pt',
        uuidObjet: 'uuid-photo-2',
        photoSlot: 1,
      );
      final replacementId = await helper.enqueuePhotoSyncItem(
        schemaName: 'ep',
        tableName: 'ep_brc_pt',
        uuidObjet: 'uuid-photo-2',
        photoSlot: 1,
        localPath: 'C:/tmp/photo_replacement.jpg',
      );

      final db = await helper.database;
      final rows = await db.query(
        'photo_sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      );

      expect(replacementId, id);
      expect(rows, hasLength(1));
      expect(rows.single['synced'], 1);
      expect(rows.single['local_path'], 'C:/tmp/photo_initial.jpg');
      expect(rows.single['remote_path'], 'remote/photo.jpg');
    });

    test('photo queue allows separate workflow contexts for same slot',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();

      final initialId = await helper.enqueuePhotoSyncItem(
        schemaName: 'ep',
        tableName: 'ep_vanne',
        uuidObjet: 'uuid-photo-context',
        photoSlot: 1,
        localPath: 'C:/tmp/initial.jpg',
      );
      final anomalyId = await helper.enqueuePhotoSyncItem(
        schemaName: 'ep',
        tableName: 'ep_vanne',
        uuidObjet: 'uuid-photo-context',
        photoSlot: 1,
        photoContext: 'anomalie_avant',
        localPath: 'C:/tmp/anomaly.jpg',
      );

      final db = await helper.database;
      final rows = await db.query(
        'photo_sync_queue',
        where: 'uuid_objet = ?',
        whereArgs: ['uuid-photo-context'],
        orderBy: 'photo_context ASC',
      );

      expect(initialId, isNot(equals(anomalyId)));
      expect(rows, hasLength(2));
      expect(
          rows.map((row) => row['photo_context']),
          containsAll([
            'collecte_initiale',
            'anomalie_avant',
          ]));
    });

    test('photo workflow resolves and stores intervention anomaly id',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();
      final db = await helper.database;

      await helper.upsertDownloadedInterventionAnomalieTerrain({
        'id': 77,
        'id_intervention': 77,
        'id_objet': 12,
        'nom_classe': 'ep_vanne',
        'nom_table': 'ep.ep_vanne',
        'uuid_objet': 'uuid-photo-cycle',
        'statut': 'signale',
        'responsable_actuel': 'exploitant',
        'etat_exploitant': 'en_attente',
      });

      final resolvedId = await helper.resolveInterventionAnomalieIdForObject(
        schemaName: 'ep',
        tableName: 'ep_vanne',
        uuidObjet: 'uuid-photo-cycle',
      );
      expect(resolvedId, 77);

      final photoId = await helper.enqueuePhotoSyncItem(
        schemaName: 'ep',
        tableName: 'ep_vanne',
        uuidObjet: 'uuid-photo-cycle',
        photoSlot: 1,
        photoContext: 'anomalie_avant',
        localPath: 'C:/tmp/anomaly-cycle.jpg',
      );
      await helper.markPhotoSyncItemSynced(
        photoId,
        remotePath: 'remote/anomaly-cycle.jpg',
        idInterventionAnomalie: resolvedId,
      );

      final scopedRows = await helper.getPhotoSyncItemsForObject(
        schemaName: 'ep',
        tableName: 'ep_vanne',
        uuidObjet: 'uuid-photo-cycle',
        photoContext: 'anomalie_avant',
        idInterventionAnomalie: resolvedId,
      );
      final stored = (await db.query(
        'photo_sync_queue',
        where: 'id = ?',
        whereArgs: [photoId],
      ))
          .single;

      expect(scopedRows, hasLength(1));
      expect(stored['id_intervention_anomalie'], 77);
    });

    test('invalid photo queue items are rejected without retry loop', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();
      final id = await helper.enqueuePhotoSyncItem(
        schemaName: 'ep',
        tableName: 'ep_vanne',
        uuidObjet: 'uuid-photo-invalid',
        photoSlot: 1,
        localPath: 'C:/tmp/corrupt.jpg',
      );

      await helper.rejectPhotoSyncItem(id, 'Photo corrompue');

      expect(await helper.getPendingPhotoSyncItems(), isEmpty);
      expect(await helper.countFailedPhotoSyncItems(), 1);
    });

    test('critical SRM local tables include expected server columns', () async {
      final db = await DatabaseHelper.openInMemoryDatabaseForTest();

      Future<Set<String>> columnsOf(String table) async {
        final rows = await db.rawQuery('PRAGMA table_info($table)');
        return rows.map((row) => row['name'].toString()).toSet();
      }

      expect(
        await columnsOf('ep_regard_point'),
        containsAll({'conformite_plan', 'ref_rue'}),
      );
      expect(
        await columnsOf('compteur_abonne'),
        contains('observation'),
      );
      expect(
        await columnsOf('hydrant'),
        contains('conformite_plan'),
      );
      expect(
        await columnsOf('conduite_terrain'),
        containsAll({'altitude_z_moy', 'ep_diam', 'ep_mat'}),
      );
      expect(
        await columnsOf('conduite_terrain'),
        isNot(contains('ep_coor_z')),
      );
    });

    test('line tables accept average altitude without point Z columns',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();

      final id = await helper.insertEntitySrm('conduite_terrain', {
        'uuid': 'line-altitude-1',
        'ep_diam': '10',
        'ep_mat': '2',
        'points_json':
            '[{"lat":34.68,"lon":-1.91},{"lat":34.681,"lon":-1.912}]',
        'nb_points': 2,
        'distance_m': 12.3,
        'altitude_z_moy': 42.75,
      });

      final db = await helper.database;
      final row = (await db.query(
        'conduite_terrain',
        where: 'id = ?',
        whereArgs: [id],
      ))
          .single;

      expect(row['altitude_z_moy'], 42.75);
    });

    test('conduite mode can find today EP regard points', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      ApiService.userId = 19;
      final helper = DatabaseHelper();
      final now = DateTime.now();

      await helper.insertEntitySrm('ep_regard_point', {
        'uuid': 'regard-today-1',
        'id_agent_crea': 19,
        'ep_coor_x': 359779.21,
        'ep_coor_y': 368280.86,
        'ep_coor_z': 145.90,
        'date_collecte': now.toIso8601String(),
        'synced': 0,
      });

      final markers =
          await DisplayedPointsService().getDisplayedRegardMarkersForDay(
        day: now,
        onTapRegard: (_) {},
        metier: 'Eau Potable',
        entityType: 'Regard',
        tableName: 'ep_regard_point',
      );

      expect(markers, hasLength(1));
    });

    test('intervention anomaly summary separates exploitant and terrain states',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();

      await helper.upsertDownloadedInterventionAnomalieTerrain({
        'id': 1,
        'id_objet': 100,
        'nom_table': 'ep.ep_vanne',
        'statut': 'signale',
        'responsable_actuel': 'exploitant',
        'etat_exploitant': 'en_attente',
        'etat_terrain': 'en_attente',
      });
      await helper.upsertDownloadedInterventionAnomalieTerrain({
        'id': 2,
        'id_objet': 101,
        'nom_table': 'ep.ep_vanne',
        'retour_terrain': true,
        'statut': 'retour_terrain',
        'responsable_actuel': 'terrain',
        'etat_exploitant': 'traite',
        'etat_terrain': 'en_attente',
      });
      await helper.upsertDownloadedInterventionAnomalieTerrain({
        'id': 3,
        'id_objet': 102,
        'nom_table': 'ep.ep_vanne',
        'retour_terrain': true,
        'statut': 'terrain_traite',
        'responsable_actuel': 'terrain',
        'etat_exploitant': 'traite',
        'etat_terrain': 'traite',
      });

      final summary = await helper.getInterventionAnomalieTreatmentSummary();
      final waiting = await helper.getInterventionAnomalieTreatmentItems(
        filter: 'en_attente_exploitant',
      );
      final returns = await helper.getInterventionAnomalieTreatmentItems(
        filter: 'retour_terrain_a_faire',
      );

      expect(summary['en_attente_exploitant'], 1);
      expect(summary['retour_terrain_a_faire'], 1);
      expect(summary['retour_terrain_effectue'], 1);
      expect(waiting.single['id_intervention'], 1);
      expect(returns.single['id_intervention'], 2);
    });

    test('marking anomaly terrain return creates an unsynced local update',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();

      await helper.upsertDownloadedInterventionAnomalieTerrain({
        'id': 10,
        'id_objet': 500,
        'nom_table': 'ep.ep_brc_pt',
        'retour_terrain': true,
        'statut': 'retour_terrain',
        'responsable_actuel': 'terrain',
        'etat_exploitant': 'traite',
        'etat_terrain': 'en_attente',
      });

      final pending = await helper.getInterventionAnomalieTreatmentItems(
        filter: 'retour_terrain_a_faire',
      );
      await helper.updateInterventionAnomalieTerrainLocal(
        localId: pending.single['id'] as int,
        etatTerrain: 'traite',
      );

      final unsynced = await helper.getUnsyncedInterventionAnomalieTerrain();
      final summary = await helper.getInterventionAnomalieTreatmentSummary();

      expect(unsynced, hasLength(1));
      expect(unsynced.single['etat_terrain'], 'traite');
      expect(summary['retour_terrain_a_faire'], 0);
      expect(summary['retour_terrain_effectue'], 1);
    });
  });
}
