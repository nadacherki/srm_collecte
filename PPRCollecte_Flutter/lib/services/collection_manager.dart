// lib/services/collection_manager.dart - SPRINT 5 : SRM + Altitude Z
// ── SPRINT 7 : Brouillon collecte en pause + levé point pendant pause ──
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:sqflite/sqflite.dart';
import '../data/local/database_helper.dart';
import '../models/collection_models.dart';
import 'collection_service.dart';

class CollectionManager extends ChangeNotifier {
  final CollectionService _collectionService = CollectionService();
  static const double _duplicatePointThresholdMeters = 0.1;
  static int _nextLineCollectionId = 1;
  LigneCollection? _ligneCollection;
  SpecialCollection? _specialCollection;
  int _countdown = 0;

  // Getters
  LigneCollection? get ligneCollection => _ligneCollection;
  SpecialCollection? get specialCollection => _specialCollection;
  int get countdown => _countdown;

  // ── SPRINT 5 : Altitude Z courante et données SRM ──
  /// Altitude Z du GNSS (Mock Location ou GPS natif) — null si indisponible
  double? get currentAltitude => _collectionService.currentAltitude;

  /// Altitudes Z de tous les points capturés (parallèle à collection.points)

  /// Altitude Z moyenne des points capturés (pour hasZ=true)
  double? get averageAltitude => _collectionService.getAverageAltitude();

  /// FK SRM à injecter à la sauvegarde

  bool get hasActiveCollection => (_ligneCollection?.isActive ?? false) || (_specialCollection?.isActive ?? false);
  bool get hasPausedCollection => (_ligneCollection?.isPaused ?? false) || (_specialCollection?.isPaused ?? false);

  String? get activeCollectionType {
    if (_ligneCollection?.isActive ?? false) return 'ligne';
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
      id: _nextLineCollectionId++,
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
      lineCode: null,
      type: CollectionType.special,
      points: List<LatLng>.from(_specialCollection!.points),
      totalDistance: _specialCollection!.totalDistance,
      startTime: _specialCollection!.startTime,
      endTime: DateTime.now(),
    );

    _specialCollection = null;
    _collectionService.stopCollection();
    _clearPausedDraft(); // SPRINT 7
    notifyListeners();

    return result;
  }

  /// Démarre une collecte de ligne
  void startLigneCollection({
    required String lineCode,
    required LatLng initialPosition,
    required Stream<LocationData> locationStream,
  }) {
    if (hasActiveCollection) {
      throw Exception('Une collecte est déjà en cours. Veuillez la mettre en pause d\'abord.');
    }

    _ligneCollection = LigneCollection(
      id: _nextLineCollectionId++,
      lineCode: lineCode,
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
      _savePausedDraft(); // SPRINT 7
      DatabaseHelper().recordLocalEvent(
        eventType: 'PAUSE_COLLECTION',
        tableName: 'app_metadata',
        cleLigne: 'paused_collection_draft',
        payload: {
          'collection_type': 'ligne',
          'point_count': _ligneCollection!.points.length,
          'collection_id': _ligneCollection!.id,
        },
      );
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
      DatabaseHelper().recordLocalEvent(
        eventType: 'RESUME_COLLECTION',
        tableName: 'app_metadata',
        cleLigne: 'paused_collection_draft',
        payload: {
          'collection_type': 'ligne',
          'point_count': _ligneCollection!.points.length,
          'collection_id': _ligneCollection!.id,
        },
      );
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
      _savePausedDraft(); // SPRINT 7
      DatabaseHelper().recordLocalEvent(
        eventType: 'PAUSE_COLLECTION',
        tableName: 'app_metadata',
        cleLigne: 'paused_collection_draft',
        payload: {
          'collection_type': 'special',
          'point_count': _specialCollection!.points.length,
          'collection_id': _specialCollection!.id,
          'special_type': _specialCollection!.specialType,
        },
      );
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
      DatabaseHelper().recordLocalEvent(
        eventType: 'RESUME_COLLECTION',
        tableName: 'app_metadata',
        cleLigne: 'paused_collection_draft',
        payload: {
          'collection_type': 'special',
          'point_count': _specialCollection!.points.length,
          'collection_id': _specialCollection!.id,
          'special_type': _specialCollection!.specialType,
        },
      );
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
      lineCode: _ligneCollection!.lineCode,
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
    _clearPausedDraft(); // SPRINT 7
    notifyListeners();

    return result;
  }

  void cancelLigneCollection() {
    if (_ligneCollection == null) return;
    _ligneCollection = null;
    _countdown = 0;
    _collectionService.stopCollection();
    _clearPausedDraft(); // SPRINT 7
    notifyListeners();
  }

  /// Ajoute un point manuellement sur la position courante.
  /// Retourne false si la collecte n'est pas active ou si le point duplique
  /// exactement le dernier point déjà capturé.
  bool addManualPoint(CollectionType type, LatLng point) {
    CollectionBase? collection;

    if (type == CollectionType.ligne) {
      collection = _ligneCollection;
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

  // ══════════════════════════════════════════════════════
  // ██ SPRINT 7 : Restauration collecte en pause
  // ══════════════════════════════════════════════════════

  CollectionPointEdit? undoLastManualPoint(CollectionType type) {
    final collection = _collectionFor(type);
    if (collection == null || collection.isInactive || collection.points.isEmpty) {
      return null;
    }

    final updatedPoints = List<LatLng>.from(collection.points);
    final removedPoint = updatedPoints.removeLast();
    final removedAltitude = _collectionService.removeLastRecordedAltitude();

    _replaceCollectionPoints(type, updatedPoints);
    _savePausedDraftIfNeeded(type);

    return CollectionPointEdit(
      point: removedPoint,
      altitude: removedAltitude,
    );
  }

  bool redoManualPoint(CollectionType type, CollectionPointEdit edit) {
    final collection = _collectionFor(type);
    if (collection == null || collection.isInactive) {
      return false;
    }

    if (collection.points.isNotEmpty) {
      final lastPoint = collection.points.last;
      final segmentDistance = _collectionService.calculateTotalDistance([
        lastPoint,
        edit.point,
      ]);
      if (segmentDistance <= _duplicatePointThresholdMeters) {
        return false;
      }
    }

    _collectionService.recordAltitudeForManualPoint(edit.altitude);
    final updatedPoints = List<LatLng>.from(collection.points)..add(edit.point);
    _replaceCollectionPoints(type, updatedPoints);
    _savePausedDraftIfNeeded(type);
    return true;
  }

  CollectionBase? _collectionFor(CollectionType type) {
    if (type == CollectionType.ligne) {
      return _ligneCollection;
    }
    if (type == CollectionType.special) {
      return _specialCollection;
    }
    return null;
  }

  void _replaceCollectionPoints(CollectionType type, List<LatLng> points) {
    final totalDistance = _collectionService.calculateTotalDistance(points);
    final lastPointTime = DateTime.now();

    if (type == CollectionType.ligne && _ligneCollection != null) {
      _ligneCollection = _ligneCollection!.copyWith(
        points: points,
        totalDistance: totalDistance,
        lastPointTime: lastPointTime,
      );
    } else if (type == CollectionType.special && _specialCollection != null) {
      _specialCollection = _specialCollection!.copyWith(
        points: points,
        totalDistance: totalDistance,
        lastPointTime: lastPointTime,
      );
    }

    notifyListeners();
  }

  void _savePausedDraftIfNeeded(CollectionType type) {
    final collection = _collectionFor(type);
    if (collection?.isPaused ?? false) {
      _savePausedDraft();
    }
  }

  /// Restaure une collecte de ligne en état paused (depuis brouillon SQLite).
  void restorePausedLigneCollection(LigneCollection paused) {
    _ligneCollection = paused;
    notifyListeners();
  }

  /// Restaure une collecte spéciale en état paused (depuis brouillon SQLite).
  void restorePausedSpecialCollection(SpecialCollection paused) {
    _specialCollection = paused;
    notifyListeners();
  }

  /// Recrée une ligne en état paused à partir d'un snapshot déjà finalisé
  /// puis resauvegarde immédiatement son brouillon de collecte.
  Future<void> restoreFinishedLigneAsPaused({
    required int id,
    required String lineCode,
    required List<LatLng> points,
    required DateTime startTime,
    DateTime? lastPointTime,
    required double totalDistance,
    Map<String, dynamic>? srmMetadata,
  }) async {
    _collectionService.stopCollection();
    _countdown = 0;
    _srmMetadata = srmMetadata;
    _ligneCollection = LigneCollection(
      id: id,
      lineCode: lineCode,
      status: CollectionStatus.paused,
      points: List<LatLng>.from(points),
      startTime: startTime,
      lastPointTime: lastPointTime,
      totalDistance: totalDistance,
    );
    await _savePausedDraft();
    await DatabaseHelper().recordLocalEvent(
      eventType: 'RESTORE_FINISHED_LINE_TO_PAUSED',
      tableName: 'app_metadata',
      cleLigne: 'paused_collection_draft',
      payload: {
        'collection_type': 'ligne',
        'point_count': points.length,
        'collection_id': id,
      },
    );
    notifyListeners();
  }

  void cancelSpecialCollection() {
    if (_specialCollection == null) return;
    _specialCollection = null;
    _countdown = 0;
    _collectionService.stopCollection();
    _clearPausedDraft(); // SPRINT 7
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════
  // ██ SPRINT 7 : Brouillon collecte en pause
  // ══════════════════════════════════════════════════════

  /// Métadonnées SRM stockées par le HomeController avant la pause
  Map<String, dynamic>? _srmMetadata;

  /// Définir les métadonnées SRM pour le brouillon
  void setSrmMetadata(Map<String, dynamic> metadata) {
    _srmMetadata = metadata;
  }

  /// Sauvegarde la collecte en pause dans SQLite
  Future<void> _savePausedDraft() async {
    try {
      final data = <String, dynamic>{};

      if (_ligneCollection?.isPaused ?? false) {
        data['collectionType'] = 'ligne';
        data['id'] = _ligneCollection!.id;
        data['lineCode'] = _ligneCollection!.lineCode;
        data['points'] = _ligneCollection!.points
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList();
        data['startTime'] = _ligneCollection!.startTime.toIso8601String();
        data['lastPointTime'] = _ligneCollection!.lastPointTime?.toIso8601String();
        data['totalDistance'] = _ligneCollection!.totalDistance;
      } else if (_specialCollection?.isPaused ?? false) {
        data['collectionType'] = 'special';
        data['id'] = _specialCollection!.id;
        data['specialType'] = _specialCollection!.specialType;
        data['points'] = _specialCollection!.points
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList();
        data['startTime'] = _specialCollection!.startTime.toIso8601String();
        data['lastPointTime'] = _specialCollection!.lastPointTime?.toIso8601String();
        data['totalDistance'] = _specialCollection!.totalDistance;
      } else {
        return;
      }

      // Inclure les métadonnées SRM si disponibles
      if (_srmMetadata != null) {
        data['srmMetadata'] = _srmMetadata;
      }

      data['pausedAt'] = DateTime.now().toIso8601String();

      final db = await DatabaseHelper().database;
      await db.insert(
        'app_metadata',
        {'key': 'paused_collection_draft', 'value': jsonEncode(data)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await DatabaseHelper().recordLocalEvent(
        eventType: 'SAVE_PAUSED_COLLECTION_DRAFT',
        tableName: 'app_metadata',
        cleLigne: 'paused_collection_draft',
        payload: {
          'collection_type': data['collectionType'],
          'point_count': (data['points'] as List).length,
        },
      );
      print('💾 Collecte en pause sauvegardée (${data['collectionType']}, ${(data['points'] as List).length} pts)');
    } catch (e) {
      print('⚠️ Erreur sauvegarde brouillon collecte: $e');
    }
  }

  /// Charge le brouillon de collecte en pause depuis SQLite
  /// Retourne les données brutes (le HomeController restaure les objets)
  static Future<Map<String, dynamic>?> loadPausedDraft() async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['paused_collection_draft'],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final raw = rows.first['value'] as String?;
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      print('⚠️ Erreur chargement brouillon collecte: $e');
      return null;
    }
  }

  /// Restaure une collecte ligne en pause depuis les données JSON
  void restoreLigneCollection(Map<String, dynamic> data) {
    final points = (data['points'] as List)
        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();

    _ligneCollection = LigneCollection(
      id: data['id'] as int,
      lineCode: (data['lineCode']) as String,
      status: CollectionStatus.paused,
      points: points,
      startTime: DateTime.parse(data['startTime'] as String),
      lastPointTime: data['lastPointTime'] != null
          ? DateTime.parse(data['lastPointTime'] as String)
          : null,
      totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
    );
    DatabaseHelper().recordLocalEvent(
      eventType: 'RESTORE_PAUSED_COLLECTION',
      tableName: 'app_metadata',
      cleLigne: 'paused_collection_draft',
      payload: {
        'collection_type': 'ligne',
        'point_count': points.length,
        'collection_id': data['id'],
      },
    );
    notifyListeners();
  }

  /// Restaure une collecte spéciale (polygone) en pause
  void restoreSpecialCollection(Map<String, dynamic> data) {
    final points = (data['points'] as List)
        .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
        .toList();

    _specialCollection = SpecialCollection(
      id: data['id'] as int,
      specialType: data['specialType'] as String? ?? 'Zone de Plaine',
      status: CollectionStatus.paused,
      points: points,
      startTime: DateTime.parse(data['startTime'] as String),
      lastPointTime: data['lastPointTime'] != null
          ? DateTime.parse(data['lastPointTime'] as String)
          : null,
      totalDistance: (data['totalDistance'] as num?)?.toDouble() ?? 0.0,
    );
    DatabaseHelper().recordLocalEvent(
      eventType: 'RESTORE_PAUSED_COLLECTION',
      tableName: 'app_metadata',
      cleLigne: 'paused_collection_draft',
      payload: {
        'collection_type': 'special',
        'point_count': points.length,
        'collection_id': data['id'],
        'special_type': data['specialType'],
      },
    );
    notifyListeners();
  }

  /// Supprime le brouillon de collecte en pause
  Future<void> _clearPausedDraft() async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete(
        'app_metadata',
        where: 'key = ?',
        whereArgs: ['paused_collection_draft'],
      );
      await DatabaseHelper().recordLocalEvent(
        eventType: 'DELETE_PAUSED_COLLECTION_DRAFT',
        tableName: 'app_metadata',
        cleLigne: 'paused_collection_draft',
      );
    } catch (e) {
      print('⚠️ Erreur suppression brouillon collecte: $e');
    }
  }

  /// Supprime le brouillon (accessible publiquement)
  Future<void> clearPausedDraft() => _clearPausedDraft();

  /// Temps écoulé depuis la pause (pour la dialog)
  static String pauseTimeAgo(String pausedAt) {
    final diff = DateTime.now().difference(DateTime.parse(pausedAt));
    if (diff.inSeconds < 60) return 'quelques secondes';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
  }

  @override
  void dispose() {
    _collectionService.dispose();
    super.dispose();
  }
}
