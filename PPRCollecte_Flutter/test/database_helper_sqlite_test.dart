import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:srm_collecte/data/local/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
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

      for (var i = 0; i < 5; i++) {
        await helper.markPhotoSyncItemFailed(id, 'upload failed');
      }

      expect(await helper.getPendingPhotoSyncItems(), isEmpty);

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
  });
}
