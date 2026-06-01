import 'dart:convert';

import 'package:latlong2/latlong.dart';

import 'merchich_point.dart';

class AffleurantLayer {
  final int? id;
  final String code;
  final String label;
  final String geometryType;
  final bool visible;
  final bool snapEnabled;
  final int priority;
  final Map<String, dynamic> style;

  const AffleurantLayer({
    this.id,
    required this.code,
    required this.label,
    required this.geometryType,
    required this.visible,
    required this.snapEnabled,
    required this.priority,
    this.style = const {},
  });
}

class AffleurantFeature {
  final int id;
  final int layerId;
  final String layerCode;
  final String layerLabel;
  final String geometryType;
  final bool snapEnabled;
  final int priority;
  final String? serverId;
  final List<List<MerchichPoint>> parts;
  final Map<String, dynamic> properties;
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  const AffleurantFeature({
    required this.id,
    required this.layerId,
    required this.layerCode,
    required this.layerLabel,
    required this.geometryType,
    required this.snapEnabled,
    required this.priority,
    required this.serverId,
    required this.parts,
    required this.properties,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  bool get isPoint => geometryType == 'Point' || geometryType == 'MultiPoint';
  bool get isLine =>
      geometryType == 'LineString' || geometryType == 'MultiLineString';
  bool get isPolygon =>
      geometryType == 'Polygon' || geometryType == 'MultiPolygon';

  Iterable<MerchichPoint> get vertices sync* {
    for (final part in parts) {
      for (final point in part) {
        yield point;
      }
    }
  }

  LatLng get firstLatLng {
    final point = parts.first.first;
    return point.toFlutterLatLng();
  }

  static AffleurantFeature fromDbRow(Map<String, dynamic> row) {
    final geometryJson = row['geometry_json_merchich']?.toString() ?? '{}';
    final propertiesJson = row['properties_json']?.toString() ?? '{}';
    return AffleurantFeature(
      id: (row['id'] as num).toInt(),
      layerId: (row['layer_id'] as num).toInt(),
      layerCode: row['layer_code']?.toString() ?? '',
      layerLabel: row['layer_label']?.toString() ?? '',
      geometryType: row['geometry_type']?.toString() ?? 'Point',
      snapEnabled: ((row['snap_enabled'] as num?)?.toInt() ?? 1) == 1,
      priority: (row['priority'] as num?)?.toInt() ?? 0,
      serverId: row['server_id']?.toString(),
      parts: _partsFromGeometryJson(geometryJson),
      properties: _jsonMap(propertiesJson),
      minX: (row['min_x'] as num).toDouble(),
      minY: (row['min_y'] as num).toDouble(),
      maxX: (row['max_x'] as num).toDouble(),
      maxY: (row['max_y'] as num).toDouble(),
    );
  }

  static List<List<MerchichPoint>> _partsFromGeometryJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return const [];
    final type = decoded['type']?.toString() ?? 'Point';
    final coordinates = decoded['coordinates'];

    List<MerchichPoint> pointList(dynamic values) {
      if (values is! List) return const [];
      return values
          .map((item) {
            if (item is! List || item.length < 2) return null;
            return MerchichPoint.tryParse(item[0], item[1],
                z: item.length > 2 ? item[2] : null);
          })
          .whereType<MerchichPoint>()
          .toList(growable: false);
    }

    if (type == 'Point' && coordinates is List && coordinates.length >= 2) {
      final point = MerchichPoint.tryParse(coordinates[0], coordinates[1],
          z: coordinates.length > 2 ? coordinates[2] : null);
      return point == null
          ? const []
          : [
              <MerchichPoint>[point]
            ];
    }
    if (type == 'MultiPoint') {
      final points = pointList(coordinates);
      return points.isEmpty ? const [] : [points];
    }
    if (type == 'LineString') {
      final points = pointList(coordinates);
      return points.isEmpty ? const [] : [points];
    }
    if (type == 'MultiLineString' && coordinates is List) {
      return coordinates
          .map(pointList)
          .where((part) => part.isNotEmpty)
          .toList();
    }
    if (type == 'Polygon' && coordinates is List) {
      return coordinates
          .map(pointList)
          .where((ring) => ring.isNotEmpty)
          .toList();
    }
    if (type == 'MultiPolygon' && coordinates is List) {
      return coordinates
          .expand((polygon) => polygon is List
              ? polygon.map(pointList)
              : const <List<MerchichPoint>>[])
          .where((ring) => ring.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static Map<String, dynamic> _jsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return const {};
  }
}

class AffleurantSnapResult {
  final bool snapped;
  final MerchichPoint point;
  final MerchichPoint rawPoint;
  final AffleurantFeature? feature;
  final double distanceMeters;
  final String snapType;

  const AffleurantSnapResult({
    required this.snapped,
    required this.point,
    required this.rawPoint,
    this.feature,
    required this.distanceMeters,
    required this.snapType,
  });

  factory AffleurantSnapResult.raw(MerchichPoint rawPoint) {
    return AffleurantSnapResult(
      snapped: false,
      point: rawPoint,
      rawPoint: rawPoint,
      distanceMeters: 0,
      snapType: 'raw',
    );
  }

  String get label {
    if (!snapped || feature == null) return 'Point brut';
    return '${feature!.layerLabel} (${distanceMeters.toStringAsFixed(2)} m)';
  }
}
