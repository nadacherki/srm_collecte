import 'package:latlong2/latlong.dart';

/// Business coordinate used by SRM mobile: EPSG:26191 Merchich meters.
class MerchichPoint {
  static const double flutterLatLngCarrierScale = 1000000.0;

  final double x;
  final double y;
  final double? z;

  const MerchichPoint({
    required this.x,
    required this.y,
    this.z,
  });

  factory MerchichPoint.fromFlutterLatLng(LatLng point, {double? z}) {
    final decoded = decodeFlutterLatLng(point);
    return MerchichPoint(x: decoded.x, y: decoded.y, z: z);
  }

  LatLng toFlutterLatLng() => LatLng(y, x);

  static LatLng encodeFlutterLatLng({
    required double x,
    required double y,
  }) {
    return LatLng(
      y / flutterLatLngCarrierScale,
      x / flutterLatLngCarrierScale,
    );
  }

  static ({double x, double y}) decodeFlutterLatLng(LatLng point) {
    if (_looksLikeRawProjectedCarrier(point)) {
      return (x: point.longitude, y: point.latitude);
    }
    return (
      x: point.longitude * flutterLatLngCarrierScale,
      y: point.latitude * flutterLatLngCarrierScale,
    );
  }

  static bool _looksLikeRawProjectedCarrier(LatLng point) {
    return point.latitude.abs() > 90 || point.longitude.abs() > 180;
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        if (z != null) 'z': z,
      };

  static MerchichPoint? tryParse(dynamic x, dynamic y, {dynamic z}) {
    final parsedX = _asDouble(x);
    final parsedY = _asDouble(y);
    if (parsedX == null || parsedY == null) return null;
    return MerchichPoint(
      x: parsedX,
      y: parsedY,
      z: _asDouble(z),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }
}
