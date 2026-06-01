import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/core/map/merchich_crs.dart';
import 'package:srm_collecte/models/merchich_point.dart';
import 'package:srm_collecte/services/projection_service.dart';

void main() {
  group('Merchich-only map CRS', () {
    test('round-trips Merchich meters through FlutterMap technical LatLng', () {
      const point = MerchichPoint(x: 701234.567, y: 409876.543, z: 12.3);
      final carrier = ProjectionService().flutterLatLngFromMerchich(point);
      final back = ProjectionService().merchichFromFlutterLatLng(
        carrier,
        z: point.z,
      );

      expect(back.x, closeTo(point.x, 0.000001));
      expect(back.y, closeTo(point.y, 0.000001));
      expect(back.z, closeTo(point.z!, 0.000001));
    });

    test('round-trips projected map pixels without WGS coordinates', () {
      final crs = MerchichCrs();
      const point = MerchichPoint(x: 701234.567, y: 409876.543);
      final carrier = point.toFlutterLatLng();
      final pixel = crs.latLngToPoint(carrier, 13);
      final backCarrier = crs.pointToLatLng(pixel, 13);
      final back = MerchichPoint.fromFlutterLatLng(backCarrier);

      expect(back.x, closeTo(point.x, 0.000001));
      expect(back.y, closeTo(point.y, 0.000001));
    });

    test('returns safe LatLngBounds-compatible carriers from CRS unproject',
        () {
      final crs = MerchichCrs();
      const point = MerchichPoint(x: 228580.0, y: 118800.0);
      final carrier = MerchichPoint.encodeFlutterLatLng(
        x: point.x,
        y: point.y,
      );
      final pixel = crs.latLngToPoint(carrier, 13);
      final backCarrier = crs.pointToLatLng(pixel, 13);

      expect(backCarrier.latitude.abs(), lessThanOrEqualTo(90));
      expect(backCarrier.longitude.abs(), lessThanOrEqualTo(180));
      expect(
        () => LatLngBounds.fromPoints([carrier, backCarrier]),
        returnsNormally,
      );
    });

    test('keeps extreme projected carriers inside LatLngBounds limits', () {
      final carrier = MerchichPoint.encodeFlutterLatLng(
        x: 228580.0,
        y: 10250959.405495564,
      );

      expect(carrier.latitude.abs(), lessThanOrEqualTo(90));
      expect(carrier.longitude.abs(), lessThanOrEqualTo(180));
      expect(() => LatLngBounds.fromPoints([carrier]), returnsNormally);
    });

    test('uses ortho native resolution matrix from package manifest', () {
      final crs = MerchichCrs(
        originX: 228348.07243899943,
        originY: 118957.53621,
        resolutions: const [1.92, 0.96, 0.48, 0.24, 0.12, 0.06, 0.03],
      );
      const point = MerchichPoint(x: 228580.28743899943, y: 118671.78621);
      final carrier = point.toFlutterLatLng();
      final pixel = crs.latLngToPoint(carrier, 6);
      final backCarrier = crs.pointToLatLng(pixel, 6);
      final back = MerchichPoint.fromFlutterLatLng(backCarrier);

      expect(crs.scale(6), closeTo(1 / 0.03, 0.000001));
      expect(back.x, closeTo(point.x, 0.000001));
      expect(back.y, closeTo(point.y, 0.000001));
    });

    test('continues CRS scale above native max for ortho overzoom', () {
      final crs = MerchichCrs(
        resolutions: const [1.92, 0.96, 0.48, 0.24, 0.12, 0.06, 0.03],
      );

      expect(crs.scale(6), closeTo(1 / 0.03, 0.000001));
      expect(crs.scale(7), closeTo((1 / 0.03) * 2, 0.000001));
      expect(crs.scale(10), closeTo((1 / 0.03) * 16, 0.000001));
      expect(crs.zoom(crs.scale(10)), closeTo(10, 0.000001));
    });

    test('rejects non-Merchich basemap SRID contract in constants', () {
      expect(MerchichCrs().code, 'EPSG:26191');
      expect(const Epsg3857().code, isNot('EPSG:26191'));
    });
  });
}
