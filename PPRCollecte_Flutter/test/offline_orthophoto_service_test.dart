import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:srm_collecte/data/local/database_helper.dart';
import 'package:srm_collecte/services/offline_orthophoto_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.resetForTest();
  });

  group('OfflineOrthophotoService', () {
    test('parses manifest and tile payloads', () {
      final state = OrthophotoLayerState.fromManifest({
        'ortho_id': 'loudaya',
        'version': 'v1',
        'format': 'tif',
        'min_zoom': 17,
        'max_zoom': 22,
        'tile_count': 12,
        'total_bytes': 3456,
        'tiles_url': 'http://server/api/orthophotos/agent/tiles/',
        'tile_url_template':
            'http://server/api/orthophotos/loudaya/tiles/{z}/{x}/{y}.tif',
      });
      final tile = OrthophotoTileSpec.fromMap(
        {
          'z': 17,
          'x': 64100,
          'y': 53200,
          'size_bytes': 2048,
          'sha256': 'ABCDEF',
          'format': 'tif',
          'url': 'http://server/tile.tif',
        },
        orthoId: state.orthoId,
        version: state.version,
      );

      expect(state.orthoId, 'loudaya');
      expect(state.maxZoom, 22);
      expect(tile.sha256, 'abcdef');
      expect(tile.key, 'loudaya/v1/17/64100/53200');
    });

    test('database tables persist layer state and tile cache', () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final helper = DatabaseHelper();

      await helper.upsertOrthophotoLayerState(
        orthoId: 'loudaya',
        version: 'v1',
        format: 'tif',
        minZoom: 17,
        maxZoom: 22,
        bounds4326: [-8.3, 31.6, -8.2, 31.7],
        tileCount: 1,
        totalBytes: 10,
      );
      await helper.upsertOrthophotoTileCache(
        orthoId: 'loudaya',
        version: 'v1',
        z: 17,
        x: 1,
        y: 2,
        sha256: '00',
        sizeBytes: 10,
        localPath: 'C:/tmp/tile.tif',
        status: 'downloaded',
      );

      final state = await helper.getActiveOrthophotoState();
      final tile = await helper.getOrthophotoTileCache(
        orthoId: 'loudaya',
        version: 'v1',
        z: 17,
        x: 1,
        y: 2,
      );

      expect(state?['ortho_id'], 'loudaya');
      expect(tile?['status'], 'downloaded');
      expect(await helper.getOrthophotoCacheBytes(), 10);
    });

    test('tile provider returns transparent image when tile is absent',
        () async {
      await DatabaseHelper.openInMemoryDatabaseForTest(
        includeSrmEntityTables: false,
      );
      final tempDir = await Directory.systemTemp.createTemp('ortho_test_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final service = OfflineOrthophotoService(
        databaseHelper: DatabaseHelper(),
        cacheRootOverride: tempDir,
      );
      await service.warmUp();
      final provider = OrthophotoTileProvider(service: service);

      final image = provider.getImage(
        const TileCoordinates(1, 2, 17),
        TileLayer(tileProvider: provider),
      );

      expect(image, isA<MemoryImage>());
    });
  });
}
