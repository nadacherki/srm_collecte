// lib/services/collection_manager.dart - SPRINT 5 : SRM + Altitude Z
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import '../models/collection_models.dart';
import 'collection_service.dart';

class CollectionManager extends ChangeNotifier {
  final CollectionService _collectionService = CollectionService();
  static const double _duplicatePointThresholdMeters = 0.1;
  static int _nextPisteId = 1;
  static int _nextChausseeId = 1;

  LigneCollection? _ligneCollection;
  ChausseeCollection? _chausseeCollection;
  SpecialCollection? _specialCollection;
  int _countdown = 0;

  // Getters
  LigneCollection? get ligneCollection => _ligneCollection;
  ChausseeCollection? get chausseeCollection => _chausseeCollection;
  SpecialCollection? get specialCollection => _specialCollection;
  int get countdown => _countdown;

  // ── SPRINT 5 : Altitude Z courante et données SRM ──
  /// Altitude Z du GNSS (Mock Location ou GPS natif) — null si indisponible
  double? get currentAltitude => _collectionService.currentAltitude;

  /// Altitudes Z de tous les points capturés (parallèle à collection.points)
  List<double?> get capturedAltitudes => _collectionService.capturedAltitudes;

  /// Altitude Z moyenne des points capturés (pour hasZ=true)
  double? get averageAltitude => _collectionService.getAverageAltitude();

  /// FK SRM à injecter à la sauvegarde
  Map<String, dynamic> get srmFkData => _collectionService.getSrmFkData();

  bool get hasActiveCollection => (_ligneCollection?.isActive ?? false) || (_chausseeCollection?.isActive ?? false) || (_specialCollection?.isActive ?? false);
  bool get hasPausedCollection => (_ligneCollection?.isPaused ?? false) || (_chausseeCollection?.isPaused ?? false) || (_specialCollection?.isPaused ?? false);

  String? get activeCollectionType {
    if (_ligneCollection?.isActive ?? false) return 'ligne';
    if (_chausseeCollection?.isActive ?? false) return 'chaussée';
    if (_specialCollection?.isActive ?? false) return 'spéciale';
    return null;
  }

  void startSpecialCollection({
    required String specialType,
    required LatLng initialPosition,
    required Stream<LocationData> locationStream,
  }) {
    if (hasActiveCollection) {
      throw Exception('Une collecte est déjà en cours.');
    }

    _specialCollection = SpecialCollection(
      id: _nextPisteId++,
      specialType: specialType,
      status: CollectionStatus.active,
      points: const [],
      startTime: DateTime.now(),
      lastPointTime: DateTime.now(),
    );

    _startCollectionService(locationStream);
    notifyListeners();
  }

  CollectionResult? finishSpecialCollection() {
    if (_specialCollection == null) return null;

    if (!_collectionService.canFinishCollection(_specialCollection!)) {
      return null;
    }

    final result = CollectionResult(
      id: _specialCollection!.id,
      codePiste: null,
      type: CollectionType.special,
      points: List<LatLng>.from(_specialCollection!.points),
      totalDistance: _specialCollection!.totalDistance,
      startTime: _specialCollection!.startTime,
      endTime: DateTime.now(),
    );

    _specialCollection = null;
    _collectionService.stopCollection();
    notifyListeners();

    return result;
  }

  /// Démarre une collecte de ligne
  void startLigneCollection({
    required String codePiste, // ✅ Code piste saisi par l'utilisateur
    required LatLng initialPosition,
    required Stream<LocationData> locationStream,
  }) {
    if (hasActiveCollection) {
      throw Exception('Une collecte est déjà en cours. Veuillez la mettre en pause d\'abord.');
    }

    _ligneCollection = LigneCollection(
      id: _nextPisteId++, // ✅ Générer ID automatiquement
      codePiste: codePiste, // ✅ Utiliser le code piste fourni
      status: CollectionStatus.active,
      points: const [],
      startTime: DateTime.now(),
      lastPointTime: DateTime.now(),
    );

    _startCollectionService(locationStream);
    notifyListeners();
  }

  /// Démarre une collecte de chaussée
  void startChausseeCollection({
    required LatLng initialPosition,
    required Stream<LocationData> locationStream,
  }) {
    if (hasActiveCollection) {
      throw Exception('Une collecte est déjà en cours. Veuillez la mettre en pause d\'abord.');
    }

    _chausseeCollection = ChausseeCollection(
      id: _nextChausseeId++, // ✅ Générer ID automatiquement
      status: CollectionStatus.active,
      points: const [],
      startTime: DateTime.now(),
      lastPointTime: DateTime.now(),
    );

    _startCollectionService(locationStream);
    notifyListeners();
  }

  /// Démarre le service de collecte pour une collection donnée
  void _startCollectionService(Stream<LocationData> locationStream) {
    _collectionService.startCollection(
      locationStream: locationStream,
      onCountdownChanged: (seconds) {
        _countdown = seconds;
        notifyListeners();
      },
    );
  }

  /// Ajoute un point à la collecte appropriée
  void _addPointToCollection(CollectionType type, LatLng point, double distance) {
    if (type == CollectionType.ligne && _ligneCollection != null) {
      final updatedPoints = List<LatLng>.from(_ligneCollection!.points)..add(point);
      final newDistance = _ligneCollection!.totalDistance + distance;

      _ligneCollection = _ligneCollection!.copyWith(
        points: updatedPoints,
        totalDistance: newDistance,
        lastPointTime: DateTime.now(),
      );
    } else if (type == CollectionType.chaussee && _chausseeCollection != null) {
      final updatedPoints = List<LatLng>.from(_chausseeCollection!.points)..add(point);
      final newDistance = _chausseeCollection!.totalDistance + distance;

      _chausseeCollection = _chausseeCollection!.copyWith(
        points: updatedPoints,
        totalDistance: newDistance,
        lastPointTime: DateTime.now(),
      );
    } else if (type == CollectionType.special && _specialCollection != null) {
      final updatedPoints = List<LatLng>.from(_specialCollection!.points)..add(point);
      final newDistance = _specialCollection!.totalDistance + distance;

      _specialCollection = _specialCollection!.copyWith(
        points: updatedPoints,
        totalDistance: newDistance,
        lastPointTime: DateTime.now(),
      );
    }

    notifyListeners();
  }

  /// Met en pause une collecte de ligne
  void pauseLigneCollection() {
    if (_ligneCollection?.isActive ?? false) {
      _ligneCollection = _ligneCollection!.copyWith(
        status: CollectionStatus.paused,
      );
      _collectionService.stopCollection();
      notifyListeners();
    }
  }

  /// Met en pause une collecte de chaussée
  void pauseChausseeCollection() {
    if (_chausseeCollection?.isActive ?? false) {
      _chausseeCollection = _chausseeCollection!.copyWith(
        status: CollectionStatus.paused,
      );
      _collectionService.stopCollection();
      notifyListeners();
    }
  }

  /// Reprend une collecte de ligne
  void resumeLigneCollection(Stream<LocationData> locationStream) {
    if (_ligneCollection?.isPaused ?? false) {
      if (hasActiveCollection) {
        throw Exception('Une autre collecte est en cours. Veuillez la mettre en pause d\'abord.');
      }

      _ligneCollection = _ligneCollection!.copyWith(
        status: CollectionStatus.active,
      );
      _startCollectionService(locationStream);
      notifyListeners();
    }
  }

  /// Reprend une collecte de chaussée
  void resumeChausseeCollection(Stream<LocationData> locationStream) {
    if (_chausseeCollection?.isPaused ?? false) {
      if (hasActiveCollection) {
        throw Exception('Une autre collecte est en cours. Veuillez la mettre en pause d\'abord.');
      }

      _chausseeCollection = _chausseeCollection!.copyWith(
        status: CollectionStatus.active,
      );
      _startCollectionService(locationStream);
      notifyListeners();
    }
  }

  /// Met en pause une collecte spéciale (Zone de Plaine)
  void pauseSpecialCollection() {
    if (_specialCollection?.isActive ?? false) {
      _specialCollection = _specialCollection!.copyWith(
        status: CollectionStatus.paused,
      );
      _collectionService.stopCollection();
      notifyListeners();
    }
  }

  /// Reprend une collecte spéciale (Zone de Plaine)
  void resumeSpecialCollection(Stream<LocationData> locationStream) {
    if (_specialCollection?.isPaused ?? false) {
      if (hasActiveCollection) {
        throw Exception('Une autre collecte est en cours. Veuillez la mettre en pause d\'abord.');
      }

      _specialCollection = _specialCollection!.copyWith(
        status: CollectionStatus.active,
      );
      _startCollectionService(locationStream);
      notifyListeners();
    }
  }

  /// Termine une collecte de ligne — Sprint 5 : inclut altitudes Z SRM
  CollectionResult? finishLigneCollection() {
    if (_ligneCollection == null) return null;

    if (!_collectionService.canFinishCollection(_ligneCollection!)) {
      return null;
    }

    // Sprint 5 : capturer altitude Z moyenne avant d'arrêter
    final avgZ = _collectionService.getAverageAltitude();

    final result = CollectionResult(
      id: _ligneCollection!.id,
      codePiste: _ligneCollection!.codePiste,
      type: CollectionType.ligne,
      points: List<LatLng>.from(_ligneCollection!.points),
      totalDistance: _ligneCollection!.totalDistance,
      startTime: _ligneCollection!.startTime,
      endTime: DateTime.now(),
    );

    // Stocker Z dans un champ accessible globalement (via ApiService temporaire)
    if (avgZ != null) {
      print('📐 Altitude Z moyenne collecte ligne: ${avgZ.toStringAsFixed(3)} m');
    }

    _ligneCollection = null;
    _collectionService.stopCollection();
    notifyListeners();

    return result;
  }

  void cancelLigneCollection() {
    if (_ligneCollection == null) return;
    _ligneCollection = null;
    _countdown = 0;
    _collectionService.stopCollection();
    notifyListeners();
  }

  /// Termine une collecte de chaussée
  CollectionResult? finishChausseeCollection() {
    if (_chausseeCollection == null) return null;

    if (!_collectionService.canFinishCollection(_chausseeCollection!)) {
      return null;
    }

    final result = CollectionResult(
      id: _chausseeCollection!.id,
      codePiste: null, // ✅ Pas de code piste pour chaussée
      type: CollectionType.chaussee,
      points: List<LatLng>.from(_chausseeCollection!.points),
      totalDistance: _chausseeCollection!.totalDistance,
      startTime: _chausseeCollection!.startTime,
      endTime: DateTime.now(),
    );

    _chausseeCollection = null;
    _collectionService.stopCollection();
    notifyListeners();

    return result;
  }

  void cancelChausseeCollection() {
    if (_chausseeCollection == null) return;
    _chausseeCollection = null;
    _countdown = 0;
    _collectionService.stopCollection();
    notifyListeners();
  }

  /// Ajoute un point manuellement sur la position courante.
  /// Retourne false si la collecte n'est pas active ou si le point duplique
  /// exactement le dernier point déjà capturé.
  bool addManualPoint(CollectionType type, LatLng point) {
    CollectionBase? collection;

    if (type == CollectionType.ligne) {
      collection = _ligneCollection;
    } else if (type == CollectionType.chaussee) {
      collection = _chausseeCollection;
    } else if (type == CollectionType.special) {
      collection = _specialCollection;
    }

    if (collection == null || !collection.isActive) {
      return false;
    }

    double segmentDistance = 0.0;
    if (collection.points.isNotEmpty) {
      final lastPoint = collection.points.last;
      segmentDistance = _collectionService.calculateTotalDistance([
        lastPoint,
        point,
      ]);

      if (segmentDistance <= _duplicatePointThresholdMeters) {
        return false;
      }
    }

    _collectionService.recordCurrentAltitudeForManualPoint();
    _addPointToCollection(type, point, segmentDistance);
    return true;
  }

  void cancelSpecialCollection() {
    if (_specialCollection == null) return;
    _specialCollection = null;
    _countdown = 0;
    _collectionService.stopCollection();
    notifyListeners();
  }

  @override
  void dispose() {
    _collectionService.dispose();
    super.dispose();
  }
}
