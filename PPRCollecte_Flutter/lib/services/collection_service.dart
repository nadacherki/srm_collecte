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

  void recordAltitudeForManualPoint(double? altitude) {
    _altitudesZ.add(altitude);
  }

  double? removeLastRecordedAltitude() {
    if (_altitudesZ.isEmpty) {
      return null;
    }
    return _altitudesZ.removeLast();
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

  double calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) {
      return 0.0;
    }

    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      final dx = points[i + 1].longitude - points[i].longitude;
      final dy = points[i + 1].latitude - points[i].latitude;
      totalDistance += sqrt((dx * dx) + (dy * dy));
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
