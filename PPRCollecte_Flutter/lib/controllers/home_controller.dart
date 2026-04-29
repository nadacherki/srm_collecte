import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

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
  List<Marker> formMarkers = []; // Marqueurs des formulaires enregistrés
  final List<Polyline> collectedPolylines = <Polyline>[];

  // Anciens états ligne pour compatibilité
  bool lineActive = false;
  bool linePaused = false;
  List<LatLng> linePoints = [];
  double lineTotalDistance = 0.0;
  String? _activeLineCode;
  String? _specialCollectionType;
  StreamSubscription<LocationData>? _locationSub;

  HomeController({LocationService? locationService})
      : _locationService = locationService ?? LocationService() {
    _collectionManager.addListener(_onCollectionChanged);
  }

  // Getters pour les nouvelles collectes
  LigneCollection? get ligneCollection => _collectionManager.ligneCollection;
  bool get hasActiveCollection => _collectionManager.hasActiveCollection;
  bool get hasPausedCollection => _collectionManager.hasPausedCollection;
  String? get activeCollectionType => _collectionManager.activeCollectionType;
  String? get activeLineCode => _activeLineCode;
  SpecialCollection? get specialCollection => _collectionManager.specialCollection;
  int get collectionCountdown => _collectionManager.countdown;
  bool get isMockLocationEnabled => _locationService.isMockLocationEnabled;

  LatLng? get mockPosition {
    final mock = _locationService.lastMockLocation;
    if (mock?.latitude == null || mock?.longitude == null) {
      return null;
    }
    return LatLng(mock!.latitude!, mock.longitude!);
  }

  // Expose le collection manager pour la simulation
  CollectionManager get collectionManager => _collectionManager;

  void setMockPosition({
    required double latitude,
    required double longitude,
    double accuracy = 1.0,
  }) {
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw Exception('Coordonnées mock invalides');
    }

    _locationService.setMockLocation(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );

    userPosition = LatLng(latitude, longitude);
    gpsEnabled = true;
    gpsAccuracy = accuracy.round();
    gpsSourceLabel = 'mock interne';
    gpsDetailsLine = _buildPositionDetailsLine(
      latitude: latitude,
      longitude: longitude,
      altitude: 0,
      accuracy: accuracy,
      source: 'mock interne',
    );
    lastSync = _formatTimeNow();
    notifyListeners();
  }

  Future<void> clearMockPosition() async {
    await _locationService.clearMockLocation();

    try {
      final loc = await _locationService.getCurrent();
      if (loc.latitude != null && loc.longitude != null) {
        userPosition = LatLng(loc.latitude!, loc.longitude!);
      }
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
    if (disableInternalMock) {
      await _locationService.clearMockLocation();
    }

    final ok = await _locationService.requestPermissionAndService();
    if (!ok) {
      gpsEnabled = false;
      notifyListeners();
      return null;
    }

    final enriched = await _locationService.getCurrentDeviceEnriched();
    final lat = enriched.raw.latitude;
    final lon = enriched.raw.longitude;
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      gpsEnabled = false;
      notifyListeners();
      return null;
    }

    userPosition = LatLng(lat, lon);
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
  }) {
    if (latitude.abs() > 90 || longitude.abs() > 180) {
      throw Exception('Coordonnées GNSS externe invalides');
    }

    userPosition = LatLng(latitude, longitude);
    gpsEnabled = true;
    gpsAccuracy = accuracy?.round() ?? gpsAccuracy;
    gpsSourceLabel = 'GNSS externe';
    gpsDetailsLine = _buildPositionDetailsLine(
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      accuracy: accuracy,
      speed: speed,
      bearing: bearing,
      fixQuality: fixQuality,
      satellites: satellites,
      hdop: hdop,
      source: 'nmea_bridge',
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
      '[NMEA] fix source=nmea_bridge device=$device '
      'lat=$latitude lon=$longitude accuracy=$accuracy altitude=$altitude '
      'satellites=$satellites hdop=$hdop timestamp=$timestampLabel',
    );
    notifyListeners();
  }

  void markNmeaBridgePending({
    String? deviceLabel,
    String? bridgeStatus,
    String? lastNmea,
  }) {
    gpsEnabled = true;
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

  String _buildPositionDetailsLine({
    required double latitude,
    required double longitude,
    double? altitude,
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
    final projected = _locationService.projection.wgs84ToMerchich(
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
      'X=${projected.x.toStringAsFixed(2)}',
      'Y=${projected.y.toStringAsFixed(2)}',
      'Z=${_formatOptionalDouble(altitude, decimals: 2)} m',
      'Précision=${_formatOptionalDouble(accuracy, decimals: 2)} m',
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
    final withoutPrefix = trimmed.startsWith(r'$')
        ? trimmed.substring(1)
        : trimmed;
    final type = withoutPrefix.split(',').first.trim();
    return type.isEmpty ? null : type;
  }

  Future<void> startSpecialCollection(String specialType) async {
    try {
      _collectionManager.startSpecialCollection(
        specialType: specialType,
        initialPosition: userPosition, // ← ta position actuelle
        locationStream: _locationService.onLocationChanged(), // ← flux GPS réel
      );
      notifyListeners();
    } catch (_) {
      rethrow;
    }
  }

  CollectionResult? finishSpecialCollection() {
    return _collectionManager.finishSpecialCollection();
  }

  void setSpecialCollectionType(String type) {
    _specialCollectionType = type;
  }

  String? getSpecialCollectionType() {
    return _specialCollectionType;
  }

  // Dans HomeController
  void clearSpecialCollectionType() {
    _specialCollectionType = null;
    notifyListeners();
  }

  // SIMULATION ÉMULATEUR — À SUPPRIMER POUR LA PRODUCTION
  void simulatePolygonPoints() {
    if (specialCollection == null || !specialCollection!.isActive) return;

    final centerLat = userPosition.latitude;
    final centerLng = userPosition.longitude;

    // Simuler un quadrilatère autour de la position actuelle
    // ~50m de côté environ
    const offset = 0.0005; // ~55 mètres
    final points = [
      LatLng(centerLat + offset, centerLng - offset), // Nord-Ouest
      LatLng(centerLat + offset, centerLng + offset), // Nord-Est
      LatLng(centerLat - offset, centerLng + offset * 0.8), // Sud-Est
      LatLng(centerLat - offset * 0.6, centerLng - offset * 1.2), // Sud-Ouest
      // Ajouter un 5ème point pour un pentagone plus réaliste
      LatLng(centerLat + offset * 0.3, centerLng - offset * 1.3), // Ouest
    ];

    for (final point in points) {
      _collectionManager.addManualPoint(CollectionType.special, point);
    }

    debugPrint('🧪 SIMULATION: ${points.length} points de polygone simulés');
    notifyListeners();
  }

  // FIN SIMULATION

  // méthode pour la simulation spéciale ( Bacs + Passages)
  void addManualPointToSpecialCollection() {
    if (specialCollection == null || !specialCollection!.isActive) return;

    final random = Random();

    // SIMULATION plus réaliste pour les lignes
    final numberOfPoints = 10 + random.nextInt(5); // 10-15 points

    double currentLat = userPosition.latitude;
    double currentLng = userPosition.longitude;
    double angle = random.nextDouble() * 2 * pi;
    double curveIntensity = 0.05;

    for (int i = 0; i < numberOfPoints; i++) {
      final distance = 0.0001 + (random.nextDouble() * 0.00005); // 10-15m
      final curveVariation = (random.nextDouble() - 0.5) * curveIntensity;
      angle += curveVariation;

      currentLat += distance * cos(angle);
      currentLng += distance * sin(angle);

      final point = LatLng(currentLat, currentLng);
      _collectionManager.addManualPoint(CollectionType.special, point);
    }

    debugPrint('✅ $numberOfPoints points réalistes simulés pour collection spéciale');
    notifyListeners();
  }

  /// Appelé lorsque les collectes changent
  // Vérifier que la collection spéciale est bien mise à jour
  void _onCollectionChanged() {
    final ligne = _collectionManager.ligneCollection;
    final special = _collectionManager.specialCollection;

    if (ligne != null) {
      lineActive = ligne.isActive;
      linePaused = ligne.isPaused;
    } else {
      lineActive = false;
      linePaused = false;
    }

    // AJOUTER LA COLLECTION SPÉCIALE
    linePoints = [];
    lineTotalDistance = 0.0;
    if (ligne != null) {
      linePoints = List<LatLng>.from(ligne.points);
      lineTotalDistance = ligne.totalDistance;
    }
    if (special != null) {
      // Mettre à jour les points pour le traçage
      linePoints = List<LatLng>.from(special.points);
      lineTotalDistance = special.totalDistance;
    }

    notifyListeners();
  }

  /// Initialisation du contrôleur
  Future<void> initialize() async {
    try {
      final ok = await _locationService.requestPermissionAndService();
      if (!ok) {
        gpsEnabled = false;
        notifyListeners();
        return;
      }

      gpsEnabled = true;
      final loc = await _locationService.getCurrent();
      if (loc.latitude != null && loc.longitude != null) {
        userPosition = LatLng(loc.latitude!, loc.longitude!);
      }

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
    final numberOfPoints = 15 + random.nextInt(10); // 15-25 points (plus court pour tester vite)

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
            : CollectionType.special,
        point,
      );
    }

    final bearingDeg = (angle * 180 / pi % 360).toStringAsFixed(0);
    debugPrint('🧪 SIMULATION LIGNE: $numberOfPoints pts, direction ~$bearingDeg°');

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

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000.0;
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) * cos(_degToRad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

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

        userPosition = LatLng(lat, lon);
        gpsAccuracy = loc.accuracy != null ? loc.accuracy!.round() : gpsAccuracy;
        if (!gpsSourceLabel.startsWith('GNSS externe')) {
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
        _collectionManager.resumeLigneCollection(_locationService.onLocationChanged());
      } catch (_) {
        rethrow;
      }
    }
  }

  void toggleSpecialCollection() {
    final special = _collectionManager.specialCollection;
    if (special == null) return;

    if (special.isActive) {
      _collectionManager.pauseSpecialCollection();
    } else if (special.isPaused) {
      try {
        _collectionManager.resumeSpecialCollection(_locationService.onLocationChanged());
      } catch (_) {
        rethrow;
      }
    }
  }

  String? addCurrentPointToActiveCollection() {
    if (_collectionManager.ligneCollection?.isActive ?? false) {
      final added = _collectionManager.addManualPoint(
        CollectionType.ligne,
        userPosition,
      );
      if (!added) {
        return 'Le point courant existe déjà dans ce tracé.';
      }
      return null;
    }

    if (_collectionManager.specialCollection?.isActive ?? false) {
      final added = _collectionManager.addManualPoint(
        CollectionType.special,
        userPosition,
      );
      if (!added) {
        return 'Le point courant existe déjà dans ce tracé.';
      }
      return null;
    }

    return 'Aucune collecte active.';
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
    required DateTime startTime,
    DateTime? lastPointTime,
    required double totalDistance,
    Map<String, dynamic>? srmMetadata,
  }) async {
    await _collectionManager.restoreFinishedLigneAsPaused(
      id: id,
      lineCode: lineCode,
      points: points,
      startTime: startTime,
      lastPointTime: lastPointTime,
      totalDistance: totalDistance,
      srmMetadata: srmMetadata,
    );
    _activeLineCode = lineCode;
    notifyListeners();
  }

  void cancelLigneCollection() {
    _collectionManager.cancelLigneCollection();
    _activeLineCode = null;
    notifyListeners();
  }

  void cancelSpecialCollection() {
    _collectionManager.cancelSpecialCollection();
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
    _collectionManager.addManualPoint(type, point);
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
