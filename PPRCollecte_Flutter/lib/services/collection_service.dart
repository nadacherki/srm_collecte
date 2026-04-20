import 'dart:async';
import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../models/collection_models.dart';

class CollectionService {
  StreamSubscription<LocationData>? _locationSubscription;
  LocationData? _currentLocation;
  final List<double?> _altitudesZ = [];

  double? get currentAltitude => _currentLocation?.altitude;

  void startCollection({
    required Stream<LocationData> locationStream,
    Function(int seconds)? onCountdownChanged,
  }) {
    stopCollection();
    _altitudesZ.clear();

    _locationSubscription = locationStream.listen(
      (locationData) {
        _currentLocation = locationData;
      },
      onError: (Object _, StackTrace __) {
        _currentLocation = null;
      },
    );

    onCountdownChanged?.call(0);
  }

  void recordCurrentAltitudeForManualPoint() {
    _altitudesZ.add(_currentLocation?.altitude);
  }

  void stopCollection() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _currentLocation = null;
  }

  double? getAverageAltitude() {
    final validAltitudes = _altitudesZ.whereType<double>().toList();
    if (validAltitudes.isEmpty) {
      return null;
    }
    return validAltitudes.reduce((a, b) => a + b) / validAltitudes.length;
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double degrees) {
    return degrees * (pi / 180.0);
  }

  double calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) {
      return 0.0;
    }

    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += _haversineDistance(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return totalDistance;
  }

  bool canFinishCollection(CollectionBase collection) {
    return collection.points.length >= 2;
  }

  void dispose() {
    stopCollection();
  }
}
