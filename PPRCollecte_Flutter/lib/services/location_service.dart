// lib/services/location_service.dart
// ── SPRINT 3 : LocationService avec transformation temps réel WGS84 → Merchich Nord ──

import 'dart:async';
import 'package:location/location.dart';
import 'projection_service.dart';

/// Position GPS enrichie avec coordonnées Merchich Nord
class EnrichedLocation {
  final LocationData raw;
  final double merchichX;
  final double merchichY;

  EnrichedLocation({
    required this.raw,
    required this.merchichX,
    required this.merchichY,
  });

  double get latitude => raw.latitude ?? 0.0;
  double get longitude => raw.longitude ?? 0.0;
  double get accuracy => raw.accuracy ?? 0.0;
  double get altitude => raw.altitude ?? 0.0;
  double get speed => raw.speed ?? 0.0;
}

class LocationService {
  final Location _location = Location();
  final ProjectionService _projection = ProjectionService();

  Future<bool> requestPermissionAndService() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }

    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    if (permission == PermissionStatus.denied ||
        permission == PermissionStatus.deniedForever) {
      return false;
    }

    try {
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000,
        distanceFilter: 0,
      );
    } catch (e) {
      // Certaines versions ne supportent pas changeSettings
    }

    try {
      await _location.enableBackgroundMode(enable: true);
      print('✅ Background mode activé');
    } catch (e) {
      print('⚠️ Impossible d\'activer le background mode: $e');
    }

    return true;
  }

  Future<LocationData> getCurrent() => _location.getLocation();

  Future<EnrichedLocation> getCurrentEnriched() async {
    final loc = await _location.getLocation();
    return _enrichLocation(loc);
  }

  Stream<LocationData> onLocationChanged() => _location.onLocationChanged;

  /// Stream enrichi : chaque position GPS est transformée en Merchich Nord
  Stream<EnrichedLocation> onEnrichedLocationChanged() {
    return _location.onLocationChanged.map(_enrichLocation);
  }

  EnrichedLocation _enrichLocation(LocationData loc) {
    final lat = loc.latitude ?? 0.0;
    final lon = loc.longitude ?? 0.0;
    final m = _projection.wgs84ToMerchich(longitude: lon, latitude: lat);
    return EnrichedLocation(raw: loc, merchichX: m.x, merchichY: m.y);
  }

  ProjectionService get projection => _projection;
}
