import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import '../models/affleurant_models.dart';
import '../models/merchich_point.dart';

class AffleurantRefreshResult {
  final int featureCount;
  final bool alreadyUpToDate;
  final String? sha256;

  const AffleurantRefreshResult({
    required this.featureCount,
    required this.alreadyUpToDate,
    this.sha256,
  });
}

class AffleurantService {
  AffleurantService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  static const int requiredSrid = 26191;

  final DatabaseHelper _db;

  Future<int> countLocalFeatures() => _db.countAffleurantFeatures();

  Future<AffleurantRefreshResult> refreshFromServer() async {
    try {
      final manifest = await ApiService.fetchAffleurantsPackageManifest();
      final manifestSrid = _asInt(manifest['srid'] ?? manifest['epsg']);
      final manifestCrs = manifest['crs']?.toString().trim().toUpperCase();
      if (manifestSrid != requiredSrid ||
          (manifestCrs != null &&
              manifestCrs.isNotEmpty &&
              manifestCrs != 'EPSG:$requiredSrid')) {
        throw StateError(
          'Package affleurants refuse: EPSG:$requiredSrid Merchich requis.',
        );
      }
      final manifestSha = _cleanSha(manifest['sha256']);
      final zoneId = _asInt(manifest['zone_id'] ?? manifest['zoneId']);
      if (manifestSha != null &&
          await _hasCurrentPackage(
            zoneId: zoneId,
            sha256: manifestSha,
          )) {
        return AffleurantRefreshResult(
          featureCount: await countLocalFeatures(),
          alreadyUpToDate: true,
          sha256: manifestSha,
        );
      }
    } catch (_) {
      // Older servers may not expose the lightweight manifest yet. In that
      // case we keep the safe full-package path below.
    }

    final package = await ApiService.fetchAffleurantsPackage();
    return importPackage(package);
  }

  Future<AffleurantRefreshResult> importPackage(
    Map<String, dynamic> package, {
    bool skipIfUnchanged = true,
  }) async {
    final srid = _asInt(package['srid'] ?? package['epsg']);
    final crs = package['crs']?.toString().trim().toUpperCase();
    if (srid != requiredSrid ||
        (crs != null && crs.isNotEmpty && crs != 'EPSG:$requiredSrid')) {
      throw StateError(
        'Package affleurants refuse: EPSG:$requiredSrid Merchich requis.',
      );
    }
    final zoneId = _asInt(package['zone_id'] ?? package['zoneId']);
    final sha256 = _cleanSha(package['sha256']);
    if (skipIfUnchanged &&
        sha256 != null &&
        await _hasCurrentPackage(zoneId: zoneId, sha256: sha256)) {
      return AffleurantRefreshResult(
        featureCount: await countLocalFeatures(),
        alreadyUpToDate: true,
        sha256: sha256,
      );
    }
    final layers = _asMapList(package['layers']);
    final features = _asMapList(package['features']);
    await _db.replaceAffleurantPackage(
      zoneId: zoneId,
      version: package['version']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      sha256: sha256,
      layers: layers,
      features: features,
    );
    return AffleurantRefreshResult(
      featureCount: await countLocalFeatures(),
      alreadyUpToDate: false,
      sha256: sha256,
    );
  }

  Future<List<AffleurantFeature>> visibleFeatures({
    double? minX,
    double? minY,
    double? maxX,
    double? maxY,
    int limit = 2000,
  }) async {
    final rows = await _db.queryAffleurantFeatures(
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      visibleOnly: true,
      limit: limit,
    );
    return rows.map(AffleurantFeature.fromDbRow).toList();
  }

  Future<AffleurantSnapResult> snap(
    MerchichPoint rawPoint, {
    double toleranceMeters = 0.30,
  }) async {
    final rows = await _db.queryAffleurantFeatures(
      minX: rawPoint.x - toleranceMeters,
      minY: rawPoint.y - toleranceMeters,
      maxX: rawPoint.x + toleranceMeters,
      maxY: rawPoint.y + toleranceMeters,
      visibleOnly: true,
      snapOnly: true,
      limit: 200,
    );
    final features = rows.map(AffleurantFeature.fromDbRow);
    _SnapCandidate? best;
    for (final feature in features) {
      final candidate = _bestCandidateForFeature(
        rawPoint,
        feature,
        toleranceMeters,
      );
      if (candidate == null) continue;
      if (best == null ||
          candidate.priority > best.priority ||
          (candidate.priority == best.priority &&
              candidate.distance < best.distance)) {
        best = candidate;
      }
    }

    if (best == null) return AffleurantSnapResult.raw(rawPoint);
    return AffleurantSnapResult(
      snapped: true,
      point: best.point,
      rawPoint: rawPoint,
      feature: best.feature,
      distanceMeters: best.distance,
      snapType: best.snapType,
    );
  }

  _SnapCandidate? _bestCandidateForFeature(
    MerchichPoint raw,
    AffleurantFeature feature,
    double toleranceMeters,
  ) {
    if (feature.parts.isEmpty) return null;
    _SnapCandidate? best;
    void consider(MerchichPoint point, String type, int typeBoost) {
      final distance = _distance(raw, point);
      if (distance > toleranceMeters) return;
      final candidate = _SnapCandidate(
        point: point,
        feature: feature,
        distance: distance,
        snapType: type,
        priority: feature.priority + typeBoost,
      );
      if (best == null ||
          candidate.priority > best!.priority ||
          (candidate.priority == best!.priority &&
              candidate.distance < best!.distance)) {
        best = candidate;
      }
    }

    if (feature.isPoint) {
      for (final point in feature.vertices) {
        consider(point, 'point', 1000);
      }
      return best;
    }

    for (final part in feature.parts) {
      for (final vertex in part) {
        consider(vertex, feature.isPolygon ? 'polygon_vertex' : 'line_vertex',
            feature.isPolygon ? 550 : 700);
      }
      for (var i = 0; i < part.length - 1; i++) {
        final projected = _projectOnSegment(raw, part[i], part[i + 1]);
        consider(
          projected,
          feature.isPolygon ? 'polygon_edge' : 'line_projection',
          feature.isPolygon ? 400 : 600,
        );
      }
    }
    return best;
  }

  static double _distance(MerchichPoint a, MerchichPoint b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt((dx * dx) + (dy * dy));
  }

  static MerchichPoint _projectOnSegment(
    MerchichPoint p,
    MerchichPoint a,
    MerchichPoint b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final len2 = (dx * dx) + (dy * dy);
    if (len2 == 0) return a;
    final t = (((p.x - a.x) * dx) + ((p.y - a.y) * dy)) / len2;
    final clamped = t.clamp(0.0, 1.0);
    return MerchichPoint(
      x: a.x + (clamped * dx),
      y: a.y + (clamped * dy),
      z: a.z,
    );
  }

  static List<Marker> markersFor(List<AffleurantFeature> features) {
    return features
        .where((feature) => feature.isPoint && feature.parts.isNotEmpty)
        .map(
          (feature) => Marker(
            point: feature.firstLatLng,
            width: 26,
            height: 26,
            child: const _AffleurantPointMarker(),
          ),
        )
        .toList();
  }

  static List<Polyline> polylinesFor(List<AffleurantFeature> features) {
    final lines = <Polyline>[];
    for (final feature in features) {
      if (!feature.isLine && !feature.isPolygon) continue;
      for (final part in feature.parts) {
        if (part.length < 2) continue;
        lines.add(
          Polyline(
            points: part.map((p) => p.toFlutterLatLng()).toList(),
            color: feature.isPolygon
                ? const Color(0xFF7C3AED)
                : const Color(0xFF0F766E),
            strokeWidth: feature.isPolygon ? 2.0 : 3.0,
          ),
        );
      }
    }
    return lines;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _cleanSha(dynamic value) {
    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Future<bool> _hasCurrentPackage({
    required int? zoneId,
    required String sha256,
  }) async {
    final summary = await _db.getAffleurantPackageSummary(zoneId: zoneId);
    if (summary == null) return false;
    final localSha = _cleanSha(summary['sha256']);
    final featureCount = _asInt(summary['feature_count']) ?? 0;
    return localSha == sha256 && featureCount > 0;
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    final decoded = value is String ? jsonDecode(value) : value;
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

class _SnapCandidate {
  final MerchichPoint point;
  final AffleurantFeature feature;
  final double distance;
  final String snapType;
  final int priority;

  const _SnapCandidate({
    required this.point,
    required this.feature,
    required this.distance,
    required this.snapType,
    required this.priority,
  });
}

class _AffleurantPointMarker extends StatelessWidget {
  const _AffleurantPointMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withValues(alpha: 0.92),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4),
        ],
      ),
      child: const Icon(
        Icons.adjust,
        color: Colors.white,
        size: 15,
      ),
    );
  }
}

// ignore: unused_element
const Map<String, dynamic> _loudayaDemoPackage = {
  'srid': 26191,
  'crs': 'EPSG:26191',
  'zone_id': 30,
  'version': 'loudaya2_demo_v1',
  'layers': [
    {
      'code': 'affleurants_points_restitues',
      'label': 'Affleurants restitués',
      'geometry_type': 'Point',
      'visible_by_default': true,
      'snap_enabled': true,
      'priority': 100,
    },
    {
      'code': 'axes_restitues',
      'label': 'Axes restitués',
      'geometry_type': 'LineString',
      'visible_by_default': true,
      'snap_enabled': true,
      'priority': 70,
    },
  ],
  'features': [
    {
      'id': 'loudaya_aff_001',
      'layer_code': 'affleurants_points_restitues',
      'geometry': {
        'type': 'Point',
        'coordinates': [228580.000, 118670.000],
      },
      'properties': {'label': 'Affleurant test centre'},
    },
    {
      'id': 'loudaya_aff_002',
      'layer_code': 'affleurants_points_restitues',
      'geometry': {
        'type': 'Point',
        'coordinates': [228610.000, 118705.000],
      },
      'properties': {'label': 'Affleurant test nord-est'},
    },
    {
      'id': 'loudaya_axis_001',
      'layer_code': 'axes_restitues',
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [228480.000, 118590.000],
          [228560.000, 118650.000],
          [228680.000, 118760.000],
        ],
      },
      'properties': {'label': 'Axe restitué test'},
    },
  ],
};
