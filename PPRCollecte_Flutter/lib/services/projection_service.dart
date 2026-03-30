// lib/services/projection_service.dart
// ── SPRINT 3 : Service de projection WGS84 ↔ Merchich Nord (EPSG:26191) ──
// Utilise le package proj4dart

import 'package:proj4dart/proj4dart.dart';
import '../core/constants/projection_constants.dart';

class ProjectionService {
  static ProjectionService? _instance;
  late final Projection _merchichNord;
  late final Projection _wgs84;

  factory ProjectionService() {
    _instance ??= ProjectionService._internal();
    return _instance!;
  }

  ProjectionService._internal() {
    Projection.add(
      'EPSG:${ProjectionConstants.sridMerchich}',
      ProjectionConstants.merchichNordProj4,
    );
    _merchichNord = Projection.get('EPSG:${ProjectionConstants.sridMerchich}')!;
    _wgs84 = Projection.get('EPSG:${ProjectionConstants.sridWgs84}')!;
  }

  /// WGS84 (lon, lat) → Merchich Nord (X, Y) en mètres
  ({double x, double y}) wgs84ToMerchich({
    required double longitude,
    required double latitude,
  }) {
    final point = Point(x: longitude, y: latitude);
    final result = _wgs84.transform(_merchichNord, point);
    return (x: result.x, y: result.y);
  }

  /// Merchich Nord (X, Y) → WGS84 (lon, lat)
  ({double longitude, double latitude}) merchichToWgs84({
    required double x,
    required double y,
  }) {
    final point = Point(x: x, y: y);
    final result = _merchichNord.transform(_wgs84, point);
    return (longitude: result.x, latitude: result.y);
  }

  String formatMerchich(double x, double y) {
    return 'X: ${x.toStringAsFixed(2)}  Y: ${y.toStringAsFixed(2)}';
  }

  List<List<double>> wgs84ListToMerchich(List<List<double>> coords) {
    return coords.map((c) {
      final m = wgs84ToMerchich(longitude: c[0], latitude: c[1]);
      return [m.x, m.y];
    }).toList();
  }

  List<List<double>> merchichListToWgs84(List<List<double>> coords) {
    return coords.map((c) {
      final w = merchichToWgs84(x: c[0], y: c[1]);
      return [w.longitude, w.latitude];
    }).toList();
  }
}
