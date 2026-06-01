import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:srm_collecte/services/regard_piece_geometry_service.dart';

void main() {
  test('regard piece accepted zone is mirror square plus buffer', () {
    const center = LatLng(118670.0, 228580.0);
    final halfSize = RegardPieceGeometryService.allowedHalfSizeMeters(
      mirrorSquareSizeMeters: 4.0,
      tapBufferMeters: 5.0,
    );

    expect(halfSize, 7.0);
    expect(
      RegardPieceGeometryService.containsTap(
        center: center,
        tapPoint: const LatLng(118677.0, 228580.0),
      ),
      isTrue,
    );
    expect(
      RegardPieceGeometryService.containsTap(
        center: center,
        tapPoint: const LatLng(118677.01, 228580.0),
      ),
      isFalse,
    );
  });

  test('regard piece allowed zone returns a closed square ring', () {
    const center = LatLng(100.0, 200.0);
    final ring = RegardPieceGeometryService.buildAllowedZone(
      center: center,
      mirrorSquareSizeMeters: 4.0,
      tapBufferMeters: 5.0,
    );

    expect(ring, hasLength(5));
    expect(ring.first, ring.last);
    expect(ring[0], const LatLng(93.0, 193.0));
    expect(ring[2], const LatLng(107.0, 207.0));
  });
}
