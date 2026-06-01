import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:srm_collecte/data/local/database_helper.dart';
import 'package:srm_collecte/models/merchich_point.dart';
import 'package:srm_collecte/services/affleurant_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.resetForTest();
  });

  test('affleurant package must be Merchich and snap returns X/Y Merchich',
      () async {
    await DatabaseHelper.openInMemoryDatabaseForTest(
      includeSrmEntityTables: false,
    );
    final service = AffleurantService();

    await service.importPackage({
      'srid': 26191,
      'version': 'test',
      'layers': [
        {
          'code': 'affleurants',
          'label': 'Affleurants',
          'geometry_type': 'Point',
          'visible_by_default': true,
          'snap_enabled': true,
          'priority': 100,
        },
        {
          'code': 'axes',
          'label': 'Axes',
          'geometry_type': 'LineString',
          'visible_by_default': true,
          'snap_enabled': true,
          'priority': 70,
        },
      ],
      'features': [
        {
          'id': 'aff-1',
          'layer_code': 'affleurants',
          'geometry': {
            'type': 'Point',
            'coordinates': [228580.0, 118670.0],
          },
        },
        {
          'id': 'axis-1',
          'layer_code': 'axes',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [228480.0, 118590.0],
              [228680.0, 118790.0],
            ],
          },
        },
      ],
    });

    final nearPoint = await service.snap(
      const MerchichPoint(x: 228580.18, y: 118670.11),
      toleranceMeters: 0.5,
    );
    expect(nearPoint.snapped, isTrue);
    expect(nearPoint.point.x, 228580.0);
    expect(nearPoint.point.y, 118670.0);

    final nearLine = await service.snap(
      const MerchichPoint(x: 228560.0, y: 118670.2),
      toleranceMeters: 0.5,
    );
    expect(nearLine.snapped, isTrue);
    expect(nearLine.snapType, 'line_projection');
    expect(nearLine.point.x, closeTo(228560.1, 0.2));
    expect(nearLine.point.y, closeTo(118670.1, 0.2));
  });

  test('non-Merchich affleurant package is refused', () async {
    await DatabaseHelper.openInMemoryDatabaseForTest(
      includeSrmEntityTables: false,
    );
    final service = AffleurantService();

    expect(
      () => service.importPackage({
        'srid': 3857,
        'version': 'bad',
        'layers': const [],
        'features': const [],
      }),
      throwsStateError,
    );
  });

  test('affleurant bbox fallback works without rtree table', () async {
    final db = await DatabaseHelper.openInMemoryDatabaseForTest(
      includeSrmEntityTables: false,
    );
    await db.execute('DROP TABLE IF EXISTS affleurant_feature_rtree');
    final service = AffleurantService();

    await service.importPackage({
      'srid': 26191,
      'version': 'no-rtree',
      'layers': [
        {
          'code': 'affleurants',
          'label': 'Affleurants',
          'geometry_type': 'Point',
          'visible_by_default': true,
          'snap_enabled': true,
          'priority': 100,
        },
      ],
      'features': [
        {
          'id': 'aff-1',
          'layer_code': 'affleurants',
          'geometry': {
            'type': 'Point',
            'coordinates': [228580.0, 118670.0],
          },
        },
      ],
    });

    expect(await service.countLocalFeatures(), 1);
    final nearPoint = await service.snap(
      const MerchichPoint(x: 228580.1, y: 118670.1),
      toleranceMeters: 0.5,
    );

    expect(nearPoint.snapped, isTrue);
    expect(nearPoint.point.x, 228580.0);
    expect(nearPoint.point.y, 118670.0);
  });

  test('same sha package is not re-imported over existing affleurants',
      () async {
    await DatabaseHelper.openInMemoryDatabaseForTest(
      includeSrmEntityTables: false,
    );
    final service = AffleurantService();

    final first = await service.importPackage({
      'srid': 26191,
      'version': 'v1',
      'sha256': 'abc123',
      'layers': [
        {
          'code': 'affleurants',
          'label': 'Affleurants',
          'geometry_type': 'Point',
          'visible_by_default': true,
          'snap_enabled': true,
          'priority': 100,
        },
      ],
      'features': [
        {
          'id': 'aff-1',
          'layer_code': 'affleurants',
          'geometry': {
            'type': 'Point',
            'coordinates': [228580.0, 118670.0],
          },
        },
      ],
    });

    final second = await service.importPackage({
      'srid': 26191,
      'version': 'v1',
      'sha256': 'abc123',
      'layers': [
        {
          'code': 'affleurants',
          'label': 'Affleurants',
          'geometry_type': 'Point',
          'visible_by_default': true,
          'snap_enabled': true,
          'priority': 100,
        },
      ],
      'features': const [],
    });

    expect(first.alreadyUpToDate, isFalse);
    expect(first.featureCount, 1);
    expect(second.alreadyUpToDate, isTrue);
    expect(second.featureCount, 1);
    expect(await service.countLocalFeatures(), 1);
  });
}
