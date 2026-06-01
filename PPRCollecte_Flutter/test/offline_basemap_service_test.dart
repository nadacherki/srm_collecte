import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/services/offline_basemap_service.dart';

void main() {
  group('OfflineBasemapService', () {
    test('estimates ortho tile count from Merchich raster manifest', () {
      final tileCount = OfflineBasemapService.estimateTileCountFromManifest({
        'tileSize': 512,
        'nativeResolution': 0.03,
        'rasterSize': {
          'width': 15481,
          'height': 19050,
        },
        'resolutions': const [
          1.92,
          0.96,
          0.48,
          0.24,
          0.12,
          0.06,
          0.03,
        ],
      });

      expect(tileCount, 1591);
    });

    test('prefers explicit tile count when manifest provides it', () {
      expect(
        OfflineBasemapService.estimateTileCountFromManifest({
          'tile_count': 42,
        }),
        42,
      );
    });

    test('rejects ortho and satellite packages as offline basemap', () {
      expect(
        OfflineBasemapService.isAllowedBasemapPackageType('basemap'),
        isTrue,
      );
      expect(
        OfflineBasemapService.isAllowedBasemapPackageType('regional_basemap'),
        isTrue,
      );
      expect(
        OfflineBasemapService.isAllowedBasemapPackageType('ortho'),
        isFalse,
      );
      expect(
        OfflineBasemapService.isAllowedBasemapPackageType('satellite'),
        isFalse,
      );
    });
  });
}
