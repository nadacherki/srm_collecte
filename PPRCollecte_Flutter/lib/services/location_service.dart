import 'dart:async';

import 'package:flutter/services.dart';
import 'package:location/location.dart';

import 'projection_service.dart';

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
  final StreamController<LocationData> _locationStreamController =
      StreamController<LocationData>.broadcast();

  StreamSubscription<LocationData>? _deviceLocationSubscription;
  bool _mockLocationEnabled = false;
  LocationData? _lastMockLocation;

  LocationService() {
    _deviceLocationSubscription = _location.onLocationChanged.listen(
      (loc) {
        if (!_mockLocationEnabled && !_locationStreamController.isClosed) {
          _locationStreamController.add(loc);
        }
      },
      onError: (_) {
        // Ignore plugin-side stream errors caused by transient permission/service
        // state during app restarts or emulator changes.
      },
    );
  }

  Future<bool> requestPermissionAndService() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          return false;
        }
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
      } catch (_) {
        // Certaines versions du plugin ne supportent pas changeSettings.
      }

      try {
        await _location.enableBackgroundMode(enable: true);
      } catch (_) {
        // Le mode background n'est pas critique pour les tests.
      }

      return true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  bool get isMockLocationEnabled => _mockLocationEnabled;
  LocationData? get lastMockLocation => _lastMockLocation;

  Future<LocationData> getCurrent() async {
    if (_mockLocationEnabled && _lastMockLocation != null) {
      return _lastMockLocation!;
    }
    return getCurrentDevice();
  }

  Future<LocationData> getCurrentDevice() async {
    try {
      return await _location.getLocation();
    } on PlatformException {
      return LocationData.fromMap(const {});
    }
  }

  Future<EnrichedLocation> getCurrentEnriched() async {
    final loc = await getCurrent();
    return _enrichLocation(loc);
  }

  Future<EnrichedLocation> getCurrentDeviceEnriched() async {
    final loc = await getCurrentDevice();
    return _enrichLocation(loc);
  }

  Stream<LocationData> onLocationChanged() => _locationStreamController.stream;

  Stream<EnrichedLocation> onEnrichedLocationChanged() {
    return onLocationChanged().map(_enrichLocation);
  }

  void setMockLocation({
    required double latitude,
    required double longitude,
    double accuracy = 1.0,
    double altitude = 0.0,
    double speed = 0.0,
  }) {
    _mockLocationEnabled = true;
    _lastMockLocation = LocationData.fromMap({
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
    });
    if (!_locationStreamController.isClosed) {
      _locationStreamController.add(_lastMockLocation!);
    }
  }

  Future<void> clearMockLocation() async {
    _mockLocationEnabled = false;
    _lastMockLocation = null;
  }

  EnrichedLocation _enrichLocation(LocationData loc) {
    final lat = loc.latitude ?? 0.0;
    final lon = loc.longitude ?? 0.0;
    final merchich = _projection.wgs84ToMerchich(
      longitude: lon,
      latitude: lat,
    );

    return EnrichedLocation(
      raw: loc,
      merchichX: merchich.x,
      merchichY: merchich.y,
    );
  }

  ProjectionService get projection => _projection;

  Future<void> dispose() async {
    await _deviceLocationSubscription?.cancel();
    await _locationStreamController.close();
  }
}
