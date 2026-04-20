import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/local/database_helper.dart';
import '../data/local/line_storage_helper.dart';
import '../models/map_overlay_tap_data.dart';

class DownloadedLinesService {
  final LineStorageHelper _storageHelper = LineStorageHelper();

  static const Color downloadedLineColor = Color(0xFFB86E1D);

  LatLng? _parsePoint(dynamic item) {
    try {
      if (item is List && item.length >= 2) {
        final lon = (item[0] as num?)?.toDouble();
        final lat = (item[1] as num?)?.toDouble();
        if (lon != null && lat != null) return LatLng(lat, lon);
      }

      if (item is Map) {
        const lonKeys = ['lon', 'lng', 'x', 'longitude'];
        const latKeys = ['lat', 'y', 'latitude'];

        double? lon;
        double? lat;

        for (final key in lonKeys) {
          if (item.containsKey(key)) {
            final value = item[key];
            if (value is num) lon = value.toDouble();
            if (value is String) lon = double.tryParse(value);
            break;
          }
        }

        for (final key in latKeys) {
          if (item.containsKey(key)) {
            final value = item[key];
            if (value is num) lat = value.toDouble();
            if (value is String) lat = double.tryParse(value);
            break;
          }
        }

        if (lon != null && lat != null) return LatLng(lat, lon);
      }

      if (item is String) {
        final source = item.trim();
        final separator = source.contains(',') ? ',' : ' ';
        final parts = source
            .split(separator)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList();
        if (parts.length >= 2) {
          final lon = double.tryParse(parts[0]);
          final lat = double.tryParse(parts[1]);
          if (lon != null && lat != null) return LatLng(lat, lon);
        }
      }
    } catch (_) {}

    return null;
  }

  List<LatLng> _toLatLngList(dynamic coords) {
    final result = <LatLng>[];
    if (coords is! List) return result;

    for (final item in coords) {
      final point = _parsePoint(item);
      if (point != null) result.add(point);
    }
    return result;
  }

  dynamic _extractLineCoordsFromGeoJson(Map<String, dynamic> geoJson) {
    final geometryType = (geoJson['type'] ?? '').toString();
    final coords = geoJson['coordinates'];
    if (geometryType == 'MultiLineString' && coords is List && coords.isNotEmpty) {
      return coords.first;
    }
    if (geometryType == 'LineString' && coords is List) {
      return coords;
    }
    return null;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  double _haversineMeters(LatLng a, LatLng b) {
    const earthRadius = 6371000.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLng = _deg2rad(b.longitude - a.longitude);

    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);

    final haversine = sinDLat * sinDLat +
        math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng;
    final centralAngle = 2 * math.asin(math.min(1.0, math.sqrt(haversine)));
    return earthRadius * centralAngle;
  }

  double _polylineDistanceKm(List<LatLng> pts) {
    if (pts.length < 2) return 0.0;
    double sum = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      sum += _haversineMeters(pts[i], pts[i + 1]);
    }
    return sum / 1000.0;
  }

  Future<List<Polyline>> getDownloadedLinesPolylines({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    try {
      final db = await _storageHelper.database;
      final loginId = await DatabaseHelper().resolveLoginId();
      if (loginId == null) {
        debugPrint('[LINE-DOWNLOAD] impossible de resoudre le login_id courant');
        return [];
      }

      debugPrint(
        '[LINE-DOWNLOAD] chargement des lignes downloaded=1 pour login_id=$loginId',
      );

      final rows = await db.query(
        'lines',
        where: 'downloaded = ? AND saved_by_user_id = ?',
        whereArgs: [1, loginId],
      );

      debugPrint(
        '[LINE-DOWNLOAD] ${rows.length} ligne(s) trouvee(s) en SQLite (table lines)',
      );

      final polylines = <Polyline>{};

      for (final row in rows) {
        final id = row['id'];
        final code = row['line_code'];

        List<LatLng> points = [];

        final pointsJson = row['points_json'];
        if (pointsJson is String && pointsJson.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(pointsJson);
            points = _toLatLngList(decoded);
          } catch (e) {
            debugPrint('[LINE-DOWNLOAD:$id] erreur decode points_json: $e');
          }
        }

        if (points.isEmpty) {
          final geom = row['geom'];
          final geomString = geom?.toString().trim() ?? '';
          if (geomString.startsWith('{')) {
            try {
              final geoJson = jsonDecode(geomString);
              if (geoJson is Map<String, dynamic>) {
                final lineCoords = _extractLineCoordsFromGeoJson(geoJson);
                if (lineCoords != null) {
                  points = _toLatLngList(lineCoords);
                }
              }
            } catch (e) {
              debugPrint('[LINE-DOWNLOAD:$id] erreur decode geom: $e');
            }
          }
        }

        if (points.length < 2) {
          continue;
        }

        final distanceKm = _polylineDistanceKm(points);

        polylines.add(
          Polyline(
            points: points,
            color: downloadedLineColor,
            strokeWidth: 5.0,
            pattern: const StrokePattern.dotted(spacingFactor: 2.0),
            hitValue: PolylineTapData(
              type: 'line_downloaded',
              data: {
                'line_code': (code ?? '----').toString(),
                'nb_points': points.length,
                'start_lat': points.first.latitude,
                'start_lng': points.first.longitude,
                'end_lat': points.last.latitude,
                'end_lng': points.last.longitude,
                'distance_km': distanceKm,
                'platform': (row['platform'] ?? '----').toString(),
                'relief': (row['relief'] ?? '----').toString(),
                'vegetation': (row['vegetation'] ?? '----').toString(),
                'work_start': (row['work_start'] ?? '----').toString(),
                'work_end': (row['work_end'] ?? '----').toString(),
                'funding': (row['funding'] ?? '----').toString(),
                'project': (row['project'] ?? '----').toString(),
                'company': (row['company'] ?? '----').toString(),
                'region_name': (row['region_name'] ?? '----').toString(),
                'prefecture_name': (row['prefecture_name'] ?? '----').toString(),
                'commune_name': (row['commune_name'] ?? '----').toString(),
                'enqueteur': (row['user_login'] ?? '').toString(),
              },
            ),
          ),
        );
      }

      return polylines.toList();
    } catch (e) {
      debugPrint('[LINE-DOWNLOAD] erreur de chargement: $e');
      return [];
    }
  }
}
