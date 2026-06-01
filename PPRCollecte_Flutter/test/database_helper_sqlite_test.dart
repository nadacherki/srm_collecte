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

    test(
        'C-1 : conduite queue rejects after 5 failures and re-enqueue '
        'resets retry counter', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();
      final jour = DateTime.utc(2026, 5, 27);

      final id = await helper.enqueueConduiteSyncItem(
        metier: 'ep',
        idAgent: 42,
        jour: jour,
        nodes: [
          {'uuid_regard': 'r-1'},
          {'uuid_regard': 'r-2'},
        ],
      );

      expect(await helper.getPendingConduiteSyncItems(), hasLength(1));
      expect(await helper.countFailedConduiteSyncItems(), 0);

      for (var i = 0; i < 5; i++) {
        await helper.markConduiteSyncItemFailed(id, 'API 500');
      }

      expect(await helper.getPendingConduiteSyncItems(), isEmpty);
      expect(await helper.countFailedConduiteSyncItems(), 1);

      final db = await helper.database;
      var row = (await db.query(
        'conduite_sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      ))
          .single;
      expect(row['retry_count'], 5);
      expect(row['synced'], -1);

      // Re-enqueue (agent re-saves conduite) doit remettre retry_count a 0
      // et la ligne doit redevenir eligible au retry.
      await helper.enqueueConduiteSyncItem(
        metier: 'ep',
        idAgent: 42,
        jour: jour,
        nodes: [
          {'uuid_regard': 'r-1'},
          {'uuid_regard': 'r-3'},
        ],
      );
      row = (await db.query(
        'conduite_sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      ))
          .single;
      expect(row['retry_count'], 0);
      expect(row['synced'], 0);
      expect(await helper.getPendingConduiteSyncItems(), hasLength(1));
    });

    test(
        'RP-2 : regard piece link queue rejects after 5 failures and re-enqueue '
        'resets retry counter', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();

      final id = await helper.enqueueRegardPieceLink(
        uuidRegard: 'regard-uuid-1',
        tableObjet: 'ep_vanne',
        uuidObjet: 'vanne-uuid-1',
      );

      expect(await helper.getPendingRegardPieceLinkItems(), hasLength(1));
      expect(await helper.countFailedRegardPieceLinkSyncItems(), 0);

      for (var i = 0; i < 5; i++) {
        await helper.markRegardPieceLinkFailed(id, 'API 404');
      }

      expect(await helper.getPendingRegardPieceLinkItems(), isEmpty);
      expect(await helper.countFailedRegardPieceLinkSyncItems(), 1);

      final db = await helper.database;
      var row = (await db.query(
        'regard_piece_link_sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      ))
          .single;
      expect(row['retry_count'], 5);
      expect(row['synced'], -1);

      await helper.enqueueRegardPieceLink(
        uuidRegard: 'regard-uuid-1',
        tableObjet: 'ep_vanne',
        uuidObjet: 'vanne-uuid-1',
      );
      row = (await db.query(
        'regard_piece_link_sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      ))
          .single;
      expect(row['retry_count'], 0);
      expect(row['synced'], 0);
      expect(await helper.getPendingRegardPieceLinkItems(), hasLength(1));
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
        await columnsOf('ventouse'),
        contains('geometry_geojson'),
      );
      expect(
        await columnsOf('vanne_de_vidange'),
        contains('geometry_geojson'),
      );
      expect(
        await columnsOf('conduite_terrain'),
        isNot(contains('ep_coor_z')),
      );
    });

    test('downloaded point rows with server GeoJSON appear on map', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();

      await helper.upsertDownloadedEntitySrm('ventouse', {
        'uuid': 'ventouse-geojson-1',
        'downloaded': 1,
        'synced': 1,
      });
      expect(
        await helper.countDownloadedRowsMissingMapPosition(
          tableName: 'ventouse',
          metierCode: 'ep',
        ),
        1,
      );

      await helper.upsertDownloadedEntitySrm('ventouse', {
        'uuid': 'ventouse-geojson-1',
        'ep_coor_x': 111111.11,
        'ep_coor_y': 222222.22,
        'geometry_geojson':
            '{"type":"Point","coordinates":[359779.21,368280.86]}',
        'downloaded': 1,
        'synced': 1,
      });
      expect(
        await helper.countDownloadedRowsMissingMapPosition(
          tableName: 'ventouse',
          metierCode: 'ep',
        ),
        0,
      );
      await helper.upsertDownloadedEntitySrm('vanne_de_vidange', {
        'uuid': 'vidange-geojson-1',
        'geometry_geojson':
            '{"type":"Point","coordinates":[359780.21,368281.86]}',
        'downloaded': 1,
        'synced': 1,
      });

      final markerRows = <Map<String, dynamic>>[];
      final markers = await DisplayedPointsService().getDisplayedPointsMarkers(
        onTapDetails: (_) {},
        onMarkerData: markerRows.add,
      );

      expect(markers, hasLength(greaterThanOrEqualTo(2)));
      expect(
        markerRows.map((row) => row['table_name']),
        containsAll({'ventouse', 'vanne_de_vidange'}),
      );

      final ventouse = markerRows.singleWhere(
        (row) => row['table_name'] == 'ventouse',
      );
      expect(ventouse['lat'], closeTo(368280.86, 0.001));
      expect(ventouse['lng'], closeTo(359779.21, 0.001));
    });

    test('new local ventouse and vidange stay visible on Merchich map',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      ApiService.userId = 19;
      final helper = DatabaseHelper();

      await helper.insertEntitySrm('ventouse', {
        'uuid': 'local-ventouse-merchich',
        'id_agent_crea': 19,
        'latitude_gps': 368280.86,
        'longitude_gps': 359779.21,
        'synced': 0,
      });
      await helper.insertEntitySrm('vanne_de_vidange', {
        'uuid': 'local-vidange-merchich',
        'id_agent_crea': 19,
        'latitude_gps': 368999.99,
        'longitude_gps': 359999.99,
        'ep_coor_x': 359780.21,
        'ep_coor_y': 368281.86,
        'geometry_geojson':
            '{"type":"Point","coordinates":[111111.11,222222.22]}',
        'synced': 0,
      });

      final markerRows = <Map<String, dynamic>>[];
      await DisplayedPointsService().getDisplayedPointsMarkers(
        onTapDetails: (_) {},
        onMarkerData: markerRows.add,
      );

      final ventouse = markerRows.singleWhere(
        (row) => row['table_name'] == 'ventouse',
      );
      final vidange = markerRows.singleWhere(
        (row) => row['table_name'] == 'vanne_de_vidange',
      );

      expect(ventouse['lat'], closeTo(368280.86, 0.001));
      expect(ventouse['lng'], closeTo(359779.21, 0.001));
      expect(vidange['lat'], closeTo(368281.86, 0.001));
      expect(vidange['lng'], closeTo(359780.21, 0.001));
    });

    test(
        'SU-5 : getUnsyncedSrm includes downloaded rows that were modified '
        'locally (re-upload path)', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();

      // 1) Simule une ligne livree par le serveur (downloaded = 1, synced = 1)
      //    et stockee localement comme telle.
      final downloadedId = await helper.insertEntitySrm('ep_regard_point', {
        'uuid': 'su5-downloaded-then-edited',
        'id_agent_crea': 19,
        'ep_coor_x': 359779.21,
        'ep_coor_y': 368280.86,
        'ep_coor_z': 145.90,
        'date_collecte': '2026-05-26T08:00:00.000Z',
        'downloaded': 1,
        'synced': 1,
      });

      // 2) Sanity check : avant edit, getUnsyncedSrm ne renvoie pas la ligne
      //    (elle est en sync avec le serveur).
      expect(
        await helper.getUnsyncedSrm('ep_regard_point'),
        isEmpty,
        reason: 'Une ligne synced = 1 ne doit pas etre renvoyee',
      );

      // 3) L'agent edite la ligne sur le terrain : le form widget set
      //    synced = 0 (cf. srm_point_form_widget.dart:1677). Downloaded
      //    reste a 1 puisque l'origine reste serveur.
      await helper.updateEntitySrm(
        'ep_regard_point',
        downloadedId,
        {
          'ep_coor_z': 146.42,
          'synced': 0,
        },
      );

      // 4) Le sync upload doit reprendre cette ligne pour la re-pousser
      //    au backend (qui supporte deja l'upsert by UUID via
      //    mobile_srm_table_view : INSERT si uuid inexistant, UPDATE sinon).
      //    Avant le fix SU-5, le filtre `AND downloaded = 0` masquait
      //    silencieusement les modifications de lignes telechargees.
      final pending = await helper.getUnsyncedSrm('ep_regard_point');
      expect(
        pending,
        hasLength(1),
        reason:
            'Une ligne downloaded = 1 modifiee (synced = 0) doit etre reprise '
            'par le sync upload, sinon les modifications terrain sur des objets '
            'serveur ne remontent jamais.',
      );
      expect(pending.single['uuid'], 'su5-downloaded-then-edited');
      expect(pending.single['ep_coor_z'], 146.42);
      expect(pending.single['downloaded'], 1);
    });

    test('countPendingSync includes edited downloaded rows and sync queues',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();

      await helper.insertEntitySrm('ep_regard_point', {
        'uuid': 'pending-downloaded-edit',
        'id_agent_crea': 19,
        'ep_coor_x': 359779.21,
        'ep_coor_y': 368280.86,
        'downloaded': 1,
        'synced': 0,
      });

      await helper.enqueuePhotoSyncItem(
        schemaName: 'ep',
        tableName: 'ep_regard_point',
        uuidObjet: 'pending-photo',
        photoSlot: 1,
        localPath: 'C:/tmp/pending_photo.jpg',
      );

      await helper.enqueueConduiteSyncItem(
        metier: 'ep',
        idAgent: 19,
        jour: DateTime.utc(2026, 5, 30),
        nodes: [
          {'uuid_regard': 'r-1'},
        ],
      );

      await helper.enqueueRegardPieceLink(
        uuidRegard: 'regard-pending',
        tableObjet: 'ep_regard_point',
        uuidObjet: 'piece-pending',
        idAgent: 19,
      );

      await helper.upsertDownloadedInterventionAnomalieTerrain({
        'id_intervention': 77,
        'id_objet': 1,
        'nom_table': 'ep.ep_regard_point',
        'uuid_objet': 'pending-intervention',
        'statut': 'en_cours',
      });
      final db = await helper.database;
      await db.update(
        'intervention_anomalie',
        {'synced': 0},
        where: 'id_intervention = ?',
        whereArgs: [77],
      );

      expect(await helper.countPendingSync(), 5);
    });

    test('download upsert can protect local unsynced edits from server pull',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest();
      final helper = DatabaseHelper();

      final localId = await helper.insertEntitySrm('ep_regard_point', {
        'uuid': 'protect-local-edit',
        'id_agent_crea': 19,
        'ep_coor_x': 359779.21,
        'ep_coor_y': 368280.86,
        'ep_coor_z': 145.90,
        'downloaded': 1,
        'synced': 0,
      });

      final result = await helper.upsertDownloadedEntitySrm(
        'ep_regard_point',
        {
          'uuid': 'protect-local-edit',
          'ep_coor_x': 359779.21,
          'ep_coor_y': 368280.86,
          'ep_coor_z': 999.0,
          'downloaded': 1,
          'synced': 1,
        },
        skipIfLocalUnsynced: true,
      );

      final db = await helper.database;
      final row = (await db.query(
        'ep_regard_point',
        where: 'id = ?',
        whereArgs: [localId],
      ))
          .single;

      expect(result.skippedLocalUnsynced, isTrue);
      expect(row['ep_coor_z'], 145.90);
      expect(row['synced'], 0);
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
