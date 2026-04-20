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
    } catch (_) {
      // On conserve la dernière position connue si le GPS réel n'est pas encore disponible.
    }

    lastSync = _formatTimeNow();
    notifyListeners();
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
