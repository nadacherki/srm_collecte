import 'package:latlong2/latlong.dart';

class RegardPieceGeometryService {
  static const double defaultMirrorSquareSizeMeters = 4.0;
  static const double defaultTapBufferMeters = 5.0;

  const RegardPieceGeometryService();

  static double allowedHalfSizeMeters({
    double mirrorSquareSizeMeters = defaultMirrorSquareSizeMeters,
    double tapBufferMeters = defaultTapBufferMeters,
  }) {
    return (mirrorSquareSizeMeters / 2.0) + tapBufferMeters;
  }

  static List<LatLng> buildAllowedZone({
    required LatLng center,
    double mirrorSquareSizeMeters = defaultMirrorSquareSizeMeters,
    double tapBufferMeters = defaultTapBufferMeters,
  }) {
    final halfMeters = allowedHalfSizeMeters(
      mirrorSquareSizeMeters: mirrorSquareSizeMeters,
      tapBufferMeters: tapBufferMeters,
    );
    return [
      LatLng(center.latitude - halfMeters, center.longitude - halfMeters),
      LatLng(center.latitude - halfMeters, center.longitude + halfMeters),
      LatLng(center.latitude + halfMeters, center.longitude + halfMeters),
      LatLng(center.latitude + halfMeters, center.longitude - halfMeters),
      LatLng(center.latitude - halfMeters, center.longitude - halfMeters),
    ];
  }

  static bool containsTap({
    required LatLng center,
    required LatLng tapPoint,
    double mirrorSquareSizeMeters = defaultMirrorSquareSizeMeters,
    double tapBufferMeters = defaultTapBufferMeters,
  }) {
    final halfMeters = allowedHalfSizeMeters(
      mirrorSquareSizeMeters: mirrorSquareSizeMeters,
      tapBufferMeters: tapBufferMeters,
    );
    final dx = tapPoint.longitude - center.longitude;
    final dy = tapPoint.latitude - center.latitude;
    return dx.abs() <= halfMeters && dy.abs() <= halfMeters;
  }
}
