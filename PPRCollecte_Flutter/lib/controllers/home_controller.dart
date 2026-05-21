import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../data/remote/api_service.dart';
import '../services/location_service.dart';
import '../services/collection_manager.dart';
import '../models/collection_models.dart';

class HomeController extends ChangeNotifier {
  final LocationService _locationService;
  final CollectionManager _collectionManager = CollectionManager();

  // États exposés
  bool gpsEnabled = false;
  int? gpsAccuracy;
  String gpsSourceLabel = 'téléphone';
  String? gpsDetailsLine;
  String? lastSync;
  bool isOnline = true;
  LatLng userPosition = const LatLng(34.683100, -1.909800); // Oujda
  double? _currentAltitude;
  double? _currentProjectedX;
  double? _currentProjectedY;
  double? _currentProjectedZ;
  List<Marker> formMarkers = []; // Marqueurs des formulaires enregistrés
  final List<Polyline> collectedPolylines = <Polyline>[];

  // Anciens états ligne pour compatibilité
  bool lineActive = false;
  bool linePaused = false;
  List<LatLng> linePoints = [];
  double lineTotalDistance = 0.0;
  String? _activeLineCode;
  StreamSubscription<LocationData>? _locationSub;

  HomeController({LocationService? locationService})
      : _locationService = locationService ?? LocationService() {
    _collectionManager.addListener(_onCollectionChanged);
  }

  /// Seul l'admin peut utiliser le GPS du téléphone et le mock interne.
  /// Les autres rôles (editeur_terrain, etc.) doivent obligatoirement
  /// passer par un récepteur GNSS externe Bluetooth.
  bool get _canUseInternalGpsSources =>
      (ApiService.userRole ?? '').trim().toLowerCase() == 'admin';

  // Getters pour les nouvelles collectes
  LigneCollection? get ligneCollection => _collectionManager.ligneCollection;
  bool get hasActiveCollection => _collectionManager.hasActiveCollection;
  bool get hasPausedCollection => _collectionManager.hasPausedCollection;
  String? get activeCollectionType => _collectionManager.activeCollectionType;
  String? get activeLineCode => _activeLineCode;
  PolygonCollection? get polygonCollection =>
      _collectionManager.polygonCollection;
  int get collectionCountdown => _collectionManager.countdown;
  bool get isMockLocationEnabled => _locationService.isMockLocationEnabled;
  double? get currentAltitude =>
      _currentAltitude ?? _collectionManager.currentAltitude;
  double? get currentProjectedX => _currentProjectedX;
  double? get currentProjectedY => _currentProjectedY;
  double? get currentProjectedZ => _currentProjectedZ ?? _currentAltitude;

  LatLng? get mockPosition {
    final mock = _locationService.lastMockLocation;
    if (mock?.latitude == null || mock?.longitude == null) {
      return null;
    }
    return LatLng(mock!.latitude!, mock.longitude!);
  }

  double? get mockAltitude => _locationService.lastMockLocation?.altitude;

  // Expose le collection manager pour la simulation
  CollectionManager get collectionManager => _collectionManager;

  void setMockPosition({
    required double latitude,
    required double longitude,
    double accuracy = 1.0,
    double altitude = 0.0,
  }) {
    if (!_canUseInternalGpsSources) {
      throw StateError(
        'Mock interne reserve aux administrateurs. Utilisez le recepteur GNSS externe.',
      );
    }
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw Exception('Coordonnées mock invalides');
    }

    _locationService.setMockLocation(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      altitude: altitude,
    );

    userPosition = LatLng(latitude, longitude);
    _currentAltitude = altitude;
    _currentProjectedX = null;
    _currentProjectedY = null;
    _currentProjectedZ = altitude;
    gpsEnabled = true;
    gpsAccuracy = accuracy.round();
    gpsSourceLabel = 'mock interne';
    gpsDetailsLine = _buildPositionDetailsLine(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      accuracy: accuracy,
      source: 'mock interne',
    );
    lastSync = _formatTimeNow();
    notifyListeners();
  }

  Future<void> clearMockPosition() async {
    await _locationService.clearMockLocation();
    _currentAltitude = null;
    _currentProjectedX = null;
    _currentProjectedY = null;
    _currentProjectedZ = null;

    if (!_canUseInternalGpsSources) {
      // Non-admin : ne jamais retomber sur le GPS du telephone.
      // Le pipeline GNSS externe reprendra la main quand un fix arrivera.
      lastSync = _formatTimeNow();
      notifyListeners();
      return;
    }

    try {
      final loc = await _locationService.getCurrent();
      if (loc.latitude != null && loc.longitude != null) {
        userPosition = LatLng(loc.latitude!, loc.longitude!);
        final projected = _locationService.projection.wgs84ToMerchich(
          longitude: loc.longitude!,
          latitude: loc.latitude!,
        );
        _currentProjectedX = projected.x;
        _currentProjectedY = projected.y;
      }
      _currentAltitude = loc.altitude;
      _currentProjectedZ = loc.altitude;
      gpsAccuracy = loc.accuracy?.round() ?? gpsAccuracy;
      gpsSourceLabel = 'téléphone';
      if (loc.latitude != null && loc.longitude != null) {
        gpsDetailsLine = _buildPositionDetailsLine(
          latitude: loc.latitude!,
          longitude: loc.longitude!,
          altitude: loc.altitude,
          accuracy: loc.accuracy,
          speed: loc.speed,
          source: 'téléphone',
          timestampMs: loc.time?.round(),
        );
      }
    } catch (_) {
      // On conserve la dernière position connue si le GPS réel n'est pas encore disponible.
    }

    lastSync = _formatTimeNow();
    notifyListeners();
  }

  Future<EnrichedLocation?> refreshFromDeviceGps({
    bool disableInternalMock = true,
  }) async {
    if (!_canUseInternalGpsSources) {
      // Non-admin : pas d'usage du GPS interne du telephone.
      // Le pipeline NMEA externe est la seule source autorisee.
      return null;
    }
    if (disableInternalMock) {
      await _locationService.clearMockLocation();
    }

    final ok = await _locationService.requestPermissionAndService();
    if (!ok) {
      gpsEnabled = false;
      _currentAltitude = null;
      _currentProjectedX = null;
      _currentProjectedY = null;
      _currentProjectedZ = null;
      notifyListeners();
      return null;
    }

    final enriched = await _locationService.getCurrentDeviceEnriched();
    final lat = enriched.raw.latitude;
    final lon = enriched.raw.longitude;
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      gpsEnabled = false;
      _currentAltitude = null;
      _currentProjectedX = null;
      _currentProjectedY = null;
      _currentProjectedZ = null;
      notifyListeners();
      return null;
    }

    userPosition = LatLng(lat, lon);
    _currentAltitude = enriched.raw.altitude;
    _currentProjectedX = enriched.merchichX;
    _currentProjectedY = enriched.merchichY;
    _currentProjectedZ = enriched.raw.altitude;
    gpsEnabled = true;
    gpsAccuracy = enriched.raw.accuracy?.round() ?? gpsAccuracy;
    gpsSourceLabel = 'téléphone';
    gpsDetailsLine = _buildPositionDetailsLine(
      latitude: lat,
      longitude: lon,
      altitude: enriched.raw.altitude,
      accuracy: enriched.raw.accuracy,
      speed: enriched.raw.speed,
      source: 'téléphone',
      timestampMs: enriched.raw.time?.round(),
    );
    lastSync = _formatTimeNow();
    notifyListeners();
    return enriched;
  }

  void applyNmeaBridgeLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? projectedX,
    double? projectedY,
    double? projectedZ,
    double? speed,
    double? bearing,
    int? fixQuality,
    int? satellites,
    double? hdop,
    String? nmea,
    String? bluetoothName,
    String? bluetoothAddress,
    int? timestampMs,
    int? mockInjectedAtMs,
    bool hasDirectProjectedCoordinates = false,
  }) {
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw Exception('Coordonnées GNSS externe invalides');
    }

    userPosition = LatLng(latitude, longitude);
    _currentAltitude = projectedZ ?? altitude;
    _currentProjectedX = projectedX;
    _currentProjectedY = projectedY;
    _currentProjectedZ = projectedZ ?? altitude;
    gpsEnabled = true;
    gpsAccuracy = accuracy?.round() ?? gpsAccuracy;
    gpsSourceLabel = hasDirectProjectedCoordinates
        ? 'GNSS XYZ'
        : 'GNSS lat/lon converti';
    gpsDetailsLine = _buildPositionDetailsLine(
      latitude: latitude,
      longitude: longitude,
      altitude: projectedZ ?? altitude,
      projectedX: projectedX,
      projectedY: projectedY,
      accuracy: accuracy,
      speed: speed,
      bearing: bearing,
      fixQuality: fixQuality,
      satellites: satellites,
      hdop: hdop,
      source: gpsSourceLabel,
      nmea: nmea,
      bluetoothName: bluetoothName,
      bluetoothAddress: bluetoothAddress,
      timestampMs: timestampMs,
      mockInjectedAtMs: mockInjectedAtMs,
    );
    lastSync = _formatTimeNow();

    final device = (bluetoothName?.trim().isNotEmpty == true)
        ? bluetoothName!.trim()
        : (bluetoothAddress?.trim().isNotEmpty == true
            ? bluetoothAddress!.trim()
            : 'inconnu');
    final timestampLabel = timestampMs?.toString() ?? 'unknown';
    debugPrint(
      '[NMEA] fix source=${hasDirectProjectedCoordinates ? 'GNSS XYZ' : 'GNSS lat/lon converti'} '
      'device=$device '
      'lat=$latitude lon=$longitude x=$projectedX y=$projectedY z=${projectedZ ?? altitude} '
      'accuracy=$accuracy '
      'satellites=$satellites hdop=$hdop timestamp=$timestampLabel',
    );
    notifyListeners();
  }

  void markNmeaBridgePending({
    String? deviceLabel,
    String? bridgeStatus,
    String? lastNmea,
  }) {
    gpsEnabled = false;
    gpsSourceLabel = 'GNSS externe: attente fix';
    lastSync = _formatTimeNow();
    final device = deviceLabel?.trim().isNotEmpty == true
        ? deviceLabel!.trim()
        : 'unknown';
    final nmeaType = _extractNmeaType(lastNmea);
    final pendingParts = <String>[
      'GNSS externe en attente de fix',
      if (bridgeStatus?.trim().isNotEmpty == true)
        'État=${bridgeStatus!.trim()}',
      'BT=$device',
      if (nmeaType != null) 'NMEA=$nmeaType',
    ];
    gpsDetailsLine = pendingParts.join(' | ');
    debugPrint(
      '[NMEA] source=nmea_bridge pending device=$device',
    );
    notifyListeners();
  }

  void markNmeaBridgeDisconnected({
    String? deviceLabel,
    String? bridgeStatus,
  }) {
    _pauseActiveCollectionForGnssLoss();
    gpsEnabled = false;
    gpsSourceLabel = 'GNSS déconnecté';
    lastSync = _formatTimeNow();
    final device = deviceLabel?.trim().isNotEmpty == true
        ? deviceLabel!.trim()
        : 'unknown';
    final parts = <String>[
      'Pont GNSS déconnecté',
      if (bridgeStatus?.trim().isNotEmpty == true)
        'État=${bridgeStatus!.trim()}',
      'BT=$device',
    ];
    gpsDetailsLine = parts.join(' | ');
    notifyListeners();
  }

  void markNmeaBridgeStale({
    String? deviceLabel,
    String? bridgeStatus,
    int? lastFixTimestampMs,
  }) {
    _pauseActiveCollectionForGnssLoss();
    gpsEnabled = false;
    gpsSourceLabel = 'GNSS expiré';
    lastSync = _formatTimeNow();
    final device = deviceLabel?.trim().isNotEmpty == true
        ? deviceLabel!.trim()
        : 'unknown';
    final parts = <String>[
      'Aucun nouveau fix GNSS reçu',
      if (lastFixTimestampMs != null)
        'Dernier fix=${_formatTimestamp(lastFixTimestampMs)}',
      if (bridgeStatus?.trim().isNotEmpty == true)
        'État=${bridgeStatus!.trim()}',
      'BT=$device',
    ];
    gpsDetailsLine = parts.join(' | ');
    notifyListeners();
  }

  void _pauseActiveCollectionForGnssLoss() {
    final ligne = _collectionManager.ligneCollection;
    if (ligne?.isActive ?? false) {
      _collectionManager.pauseLigneCollection();
    }
    final polygon = _collectionManager.polygonCollection;
    if (polygon?.isActive ?? false) {
      _collectionManager.pausePolygonCollection();
    }
  }

  String _buildPositionDetailsLine({
    required double latitude,
    required double longitude,
    double? altitude,
    double? projectedX,
    double? projectedY,
    double? accuracy,
    double? speed,
    double? bearing,
    int? fixQuality,
    int? satellites,
    double? hdop,
    String? source,
    String? nmea,
    String? bluetoothName,
    String? bluetoothAddress,
    int? timestampMs,
    int? mockInjectedAtMs,
  }) {
    final projected = (projectedX != null && projectedY != null)
        ? null
        : _locationService.projection.wgs84ToMerchich(
            longitude: longitude,
            latitude: latitude,
          );
    final device = (bluetoothName?.trim().isNotEmpty == true)
        ? bluetoothName!.trim()
        : (bluetoothAddress?.trim().isNotEmpty == true
            ? bluetoothAddress!.trim()
            : null);
    final nmeaType = _extractNmeaType(nmea);
    final parts = <String>[
      'X=${_formatOptionalDouble(projectedX ?? projected?.x, decimals: 2)}',
      'Y=${_formatOptionalDouble(projectedY ?? projected?.y, decimals: 2)}',
      'Z=${_formatOptionalDouble(altitude, decimals: 2)} m',
      'Précision=${_formatOptionalDouble(accuracy, decimals: 3)} m',
      if (satellites != null) 'Sat=$satellites',
      if (fixQuality != null) 'Fix=$fixQuality',
      if (hdop != null) 'HDOP=${hdop.toStringAsFixed(2)}',
      if (speed != null) 'V=${speed.toStringAsFixed(2)} m/s',
      if (bearing != null) 'Cap=${bearing.toStringAsFixed(1)}°',
      if (source?.trim().isNotEmpty == true) 'Source=${source!.trim()}',
      if (device != null) 'BT=$device',
      if (timestampMs != null) 'T=${_formatTimestamp(timestampMs)}',
      if (mockInjectedAtMs != null && mockInjectedAtMs != timestampMs)
        'Injecté=${_formatTimestamp(mockInjectedAtMs)}',
      if (nmeaType != null) 'NMEA=$nmeaType',
    ];
    return parts.join(' | ');
  }

  String _formatOptionalDouble(double? value, {required int decimals}) {
    if (value == null || value.isNaN || value.isInfinite) return '--';
    return value.toStringAsFixed(decimals);
  }

  String _formatTimestamp(int timestampMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String? _extractNmeaType(String? nmea) {
    final trimmed = nmea?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final withoutPrefix =
        trimmed.startsWith(r'$') ? trimmed.substring(1) : trimmed;
    final parts = withoutPrefix.split(',');
    final type = parts.first.trim();
    if (type.isEmpty) return null;
    final subtype = parts.length > 1 ? parts[1].trim() : '';
    if (type.toUpperCase() == 'PTNL' && subtype.isNotEmpty) {
      return '$type,$subtype';
    }
    return type;
  }

  Future<void> startPolygonCollection(String entityType) async {
    try {
      _collectionManager.startPolygonCollection(
        entityType: entityType,
        initialPosition: userPosition, // ← ta position actuelle
        locationStream: _locationService.onLocationChanged(), // ← flux GPS réel
      );
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  CollectionResult? finishPolygonCollection() {
    return _collectionManager.finishPolygonCollection();
  }

  /// Appel? lorsque les collectes changent
  void _onCollectionChanged() {
    final ligne = _collectionManager.ligneCollection;
    final polygon = _collectionManager.polygonCollection;

    if (ligne != null) {
      lineActive = ligne.isActive;
      linePaused = ligne.isPaused;
    } else {
      lineActive = false;
      linePaused = false;
    }

    linePoints = [];
    lineTotalDistance = 0.0;
    if (ligne != null) {
      linePoints = List<LatLng>.from(ligne.points);
      lineTotalDistance = ligne.totalDistance;
    }
    if (polygon != null) {
      linePoints = List<LatLng>.from(polygon.points);
      lineTotalDistance = polygon.totalDistance;
    }

    notifyListeners();
  }

  /// Initialisation du contrôleur
  Future<void> initialize() async {
    try {
      final ok = await _locationService.requestPermissionAndService();
      if (!ok) {
        gpsEnabled = false;
        _currentAltitude = null;
        notifyListeners();
        return;
      }

      gpsEnabled = true;
      final loc = await _locationService.getCurrent();
      if (loc.latitude != null && loc.longitude != null) {
        userPosition = LatLng(loc.latitude!, loc.longitude!);
      }
      _currentAltitude = loc.altitude;

      gpsAccuracy = loc.accuracy?.round();
      lastSync = _formatTimeNow();
      notifyListeners();
    } catch (_) {
      gpsEnabled = false;
      notifyListeners();
    }

    startLocationTracking();
    setSyncAvailability(false);
  }

  // Une methode pour tester les lignes dans l'emulateur à supprimer après
  void addRealisticLineSimulation() {
    if (!hasActiveCollection) return;

    final random = Random();
    final numberOfPoints =
        15 + random.nextInt(10); // 15-25 points (plus court pour tester vite)

    double currentLat = userPosition.latitude;
    double currentLng = userPosition.longitude;

    // DIRECTION COMPLÈTEMENT ALÉATOIRE à chaque appel
    double angle = random.nextDouble() * 2 * pi; // 0 à 360°
    double curveIntensity = 0.03; // Léger virage

    List<LatLng> simulatedLinePoints = [];

    for (int i = 0; i < numberOfPoints; i++) {
      final distance = 0.00015 + (random.nextDouble() * 0.00005);
      final curveVariation = (random.nextDouble() - 0.5) * curveIntensity;
      angle += curveVariation;

      currentLat += distance * cos(angle);
      currentLng += distance * sin(angle);

      final point = LatLng(currentLat, currentLng);
      simulatedLinePoints.add(point);

      _collectionManager.addManualPoint(
        activeCollectionType == 'ligne'
            ? CollectionType.ligne
            : CollectionType.polygon,
        point,
        altitude: currentAltitude,
      );
    }

    final bearingDeg = (angle * 180 / pi % 360).toStringAsFixed(0);
    debugPrint(
        '🧪 SIMULATION LIGNE: $numberOfPoints pts, direction ~$bearingDeg°');

    collectedPolylines.add(
      Polyline(
        points: simulatedLinePoints,
        color: const Color(0xFF1976D2),
        strokeWidth: 5.0,
      ),
    );

    notifyListeners();
  }

  void addRealisticLineCollectionSimulation() {
    addRealisticLineSimulation();
  }

  double _haversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (pi / 180.0);

  void startLocationTracking() {
    stopLocationTracking();
    _locationSub = _locationService.onLocationChanged().listen(
      (loc) {
        if (loc.latitude == null || loc.longitude == null) return;

        final lat = loc.latitude!;
        final lon = loc.longitude!;
        if (lat.abs() > 90 || lon.abs() > 180) return;

        final isGnssExterneFix = gpsSourceLabel.startsWith('GNSS');
        // Non-admin : seules les positions issues du pipeline GNSS externe
        // (label "GNSS externe...", deja pose par le polling du pont NMEA)
        // sont acceptees. Le GPS natif du telephone est ignore.
        if (!_canUseInternalGpsSources && !isGnssExterneFix) {
          return;
        }

        userPosition = LatLng(lat, lon);
        _currentAltitude = loc.altitude;
        final projected = _locationService.projection.wgs84ToMerchich(
          longitude: lon,
          latitude: lat,
        );
        _currentProjectedX = projected.x;
        _currentProjectedY = projected.y;
        _currentProjectedZ = loc.altitude;
        gpsAccuracy =
            loc.accuracy != null ? loc.accuracy!.round() : gpsAccuracy;
        if (!isGnssExterneFix) {
          gpsSourceLabel = 'téléphone';
          gpsDetailsLine = _buildPositionDetailsLine(
            latitude: lat,
            longitude: lon,
            altitude: loc.altitude,
            accuracy: loc.accuracy,
            speed: loc.speed,
            source: 'téléphone',
            timestampMs: loc.time?.round(),
          );
        }
        lastSync = _formatTimeNow();
        notifyListeners();
      },
      onError: (_) {
        gpsEnabled = false;
        _currentProjectedX = null;
        _currentProjectedY = null;
        _currentProjectedZ = null;
        notifyListeners();
      },
    );
  }

  void stopLocationTracking() {
    _locationSub?.cancel();
    _locationSub = null;
  }

  // === MÉTHODES DE COLLECTE ===

  Future<void> startLigneCollection(String lineCode) async {
    try {
      _activeLineCode = lineCode;

      _collectionManager.startLigneCollection(
        lineCode: lineCode,
        initialPosition: userPosition,
        locationStream: _locationService.onLocationChanged(),
      );
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  void toggleLigneCollection() {
    final ligne = _collectionManager.ligneCollection;
    if (ligne == null) return;

    if (ligne.isActive) {
      _collectionManager.pauseLigneCollection();
    } else if (ligne.isPaused) {
      try {
        _collectionManager
            .resumeLigneCollection(_locationService.onLocationChanged());
      } catch (_) {
        rethrow;
      }
    }
  }

  void togglePolygonCollection() {
    final polygon = _collectionManager.polygonCollection;
    if (polygon == null) return;

    if (polygon.isActive) {
      _collectionManager.pausePolygonCollection();
    } else if (polygon.isPaused) {
      try {
        _collectionManager
            .resumePolygonCollection(_locationService.onLocationChanged());
      } catch (_) {
        rethrow;
      }
    }
  }

  String? addCurrentPointToActiveCollection() {
    final gnssPoint = CapturedGnssPoint(
      latitude: userPosition.latitude,
      longitude: userPosition.longitude,
      projectedX: currentProjectedX,
      projectedY: currentProjectedY,
      projectedZ: currentProjectedZ,
    );

    if (_collectionManager.ligneCollection?.isActive ?? false) {
      final added = _collectionManager.addManualPoint(
        CollectionType.ligne,
        userPosition,
        altitude: currentAltitude,
        gnssPoint: gnssPoint,
      );
      if (!added) {
        return 'Le point courant existe déjà dans ce tracé.';
      }
      return null;
    }

    if (_collectionManager.polygonCollection?.isActive ?? false) {
      final added = _collectionManager.addManualPoint(
        CollectionType.polygon,
        userPosition,
        altitude: currentAltitude,
        gnssPoint: gnssPoint,
      );
      if (!added) {
        return 'Le point courant existe déjà dans ce tracé.';
      }
      return null;
    }

    return 'Aucune collecte active.';
  }

  CollectionPointEdit? undoLastCollectionPoint(CollectionType type) {
    final edit = _collectionManager.undoLastManualPoint(type);
    if (edit != null) {
      notifyListeners();
    }
    return edit;
  }

  bool redoCollectionPoint(CollectionType type, CollectionPointEdit edit) {
    final restored = _collectionManager.redoManualPoint(type, edit);
    if (restored) {
      notifyListeners();
    }
    return restored;
  }

  Map<String, dynamic>? finishLigneCollection() {
    final result = _collectionManager.finishLigneCollection();

    final String? finishedCode = _activeLineCode;
    _activeLineCode = null;
    notifyListeners();

    if (result == null) return null;
    debugPrint('📏 Résultat ligne - Points: ${result.points.length}');
    debugPrint('📏 Résultat ligne - Distance: ${result.totalDistance}m');
    if (result.points.isNotEmpty) {
      debugPrint('📏 Premier point: ${result.points.first}');
      debugPrint('📏 Dernier point: ${result.points.last}');
    }
    return {
      'points': result.points,
      'gnssPoints': result.gnssPoints,
      'id': result.id,
      'lineCode': result.lineCode ?? finishedCode,
      'totalDistance': result.totalDistance,
      'startTime': result.startTime,
      'endTime': result.endTime,
    };
  }

  Future<void> restoreFinishedLigneAsPaused({
    required int id,
    required String lineCode,
    required List<LatLng> points,
    List<CapturedGnssPoint> gnssPoints = const [],
    required DateTime startTime,
    DateTime? lastPointTime,
    required double totalDistance,
    Map<String, dynamic>? srmMetadata,
  }) async {
    await _collectionManager.restoreFinishedLigneAsPaused(
      id: id,
      lineCode: lineCode,
      points: points,
      gnssPoints: gnssPoints,
      startTime: startTime,
      lastPointTime: lastPointTime,
      totalDistance: totalDistance,
      srmMetadata: srmMetadata,
    );
    _activeLineCode = lineCode;
    notifyListeners();
  }

  Future<void> persistActiveCollectionDraft({
    String reason = 'lifecycle',
  }) async {
    await _collectionManager.persistActiveCollectionAsPausedDraft(
      reason: reason,
    );
    notifyListeners();
  }

  void cancelLigneCollection() {
    _collectionManager.cancelLigneCollection();
    _activeLineCode = null;
    notifyListeners();
  }

  void cancelPolygonCollection() {
    _collectionManager.cancelPolygonCollection();
    notifyListeners();
  }

  void setActiveLineCode(String code) {
    _activeLineCode = code;
    notifyListeners();
  }

  void clearActiveLineCode() {
    _activeLineCode = null;
    notifyListeners();
  }

  String? getActiveCollectionType() {
    return activeCollectionType;
  }

  // === MÉTHODES DE COMPATIBILITÉ (dépréciées) ===

  void startLine() {
    lineActive = true;
    linePaused = false;
    linePoints = [userPosition];
    lineTotalDistance = 0.0;
    startLocationTracking();
    notifyListeners();
  }

  void toggleLine() {
    linePaused = !linePaused;
    if (linePaused) {
      stopLocationTracking();
    } else {
      startLocationTracking();
    }
    notifyListeners();
  }

  List<LatLng>? finishLine() {
    if (linePoints.length < 2) {
      return null;
    }
    final finished = List<LatLng>.from(linePoints);
    lineActive = false;
    linePaused = false;
    linePoints = [];
    lineTotalDistance = 0.0;
    stopLocationTracking();
    notifyListeners();
    return finished;
  }

  void simulateAddPointToLine() {
    if (lineActive && !linePaused) {
      final last = linePoints.isNotEmpty ? linePoints.last : userPosition;
      final newPt = LatLng(last.latitude + 0.0005, last.longitude + 0.0005);
      linePoints.add(newPt);
      lineTotalDistance += _haversineDistance(
        last.latitude,
        last.longitude,
        newPt.latitude,
        newPt.longitude,
      );
      notifyListeners();
    }
  }

  void addManualPointToCollection(CollectionType type) {
    final point = LatLng(userPosition.latitude, userPosition.longitude);
    _collectionManager.addManualPoint(type, point, altitude: currentAltitude);
  }

  // === MÉTHODES UTILITAIRES ===

  String _formatTimeNow() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void updateStatus() {
    notifyListeners();
  }

  void setSyncAvailability(bool canSyncNow) {
    if (isOnline == canSyncNow) {
      return;
    }
    isOnline = canSyncNow;
    notifyListeners();
  }

  void markSyncSuccess() {
    lastSync = _formatTimeNow();
    notifyListeners();
  }

  @override
  void dispose() {
    stopLocationTracking();
    _collectionManager.removeListener(_onCollectionChanged);
    _collectionManager.dispose();
    unawaited(_locationService.dispose());
    super.dispose();
  }
}
