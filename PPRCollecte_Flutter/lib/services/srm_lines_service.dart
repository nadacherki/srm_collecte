import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';

import '../core/config/srm_config.dart';
import '../data/local/database_helper.dart';
import 'formulaire_config_mobile_service.dart';
import 'srm_row_visibility_filter.dart';
import 'srm_status_flags.dart';
import '../data/remote/api_service.dart';
import '../models/map_overlay_tap_data.dart';

class SrmLinesService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Polyline>> getDisplayedSrmLines({
    required void Function(Map<String, dynamic>) onTapDetails,
    void Function(String tableName, String metier, Polyline polyline)?
        onPolylineCreated,
  }) async {
    try {
      final db = await _dbHelper.database;
      final loginId = await _dbHelper.resolveLoginId();
      final polylines = <Polyline>[];
      final formulaireConfigService = FormulaireConfigMobileService();

      for (final metier in SrmConfig.getMetiers()) {
        final titleByTable =
            await formulaireConfigService.getTitleByMobileTable(
          mobileMetier: metier,
          refreshIfEmpty: false,
        );
        for (final entityType in SrmConfig.getLineEntities(metier)) {
          final tableName = SrmConfig.getTableName(metier, entityType);
          if (tableName == null || tableName.isEmpty) continue;
          final entityTitle = titleByTable[tableName] ?? entityType;

          final rows = await _fetchVisibleRows(
            db: db,
            tableName: tableName,
            loginId: loginId,
          );

          for (final row in rows) {
            final points = _extractLinePoints(row);
            if (points.length < 2) continue;
            final editableItem = Map<String, dynamic>.from(row);
            editableItem['source_table'] = tableName;
            editableItem['source_metier'] = metier;
            editableItem['source_entity'] = entityType;
            editableItem['source_title'] = entityTitle;
            editableItem['geometry_type'] = 'LineString';

            final hasAnomalie = SrmStatusFlags.hasAnomalie(row);
            final hasIncomplet = SrmStatusFlags.hasIncomplet(row);
            final lineStyle = _lineStyleForStatus(
              baseColor: _lineColorForMetier(metier),
              hasAnomalie: hasAnomalie,
              hasIncomplet: hasIncomplet,
            );

            final polyline = Polyline(
              points: points,
              color: lineStyle.color,
              strokeWidth: lineStyle.strokeWidth,
              pattern: lineStyle.pattern,
              hitValue: PolylineTapData(
                type: 'srm_line_local',
                data: {
                  'entity_title': entityTitle,
                  'table_name': tableName,
                  'metier': metier,
                  'anomalie': hasAnomalie,
                  'objet_incomplet': hasIncomplet,
                  'type_anomalie': (row['type_anomalie'] ?? '').toString(),
                  'start_lat': points.first.latitude,
                  'start_lng': points.first.longitude,
                  'end_lat': points.last.latitude,
                  'end_lng': points.last.longitude,
                  'distance_km': _polylineDistanceKm(points),
                  'synced': (row['synced'] ?? 0).toString(),
                  'existing_item': editableItem,
                  'region_name': (row['region_name'] ?? '').toString(),
                  'prefecture_name': (row['prefecture_name'] ?? '').toString(),
                  'commune_name': (row['commune_name'] ?? '').toString(),
                  'enqueteur': (row['enqueteur'] ??
                          ApiService.nomPrenom ??
                          ApiService.userLogin ??
                          '')
                      .toString(),
                },
              ),
            );

            polylines.add(polyline);
            onPolylineCreated?.call(tableName, metier, polyline);
          }
        }
      }

      debugPrint('[SRM-LIGNES] ${polylines.length} polyligne(s) affichee(s)');
      return polylines;
    } catch (e) {
      debugPrint('Error loading displayed SRM lines: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVisibleRows({
    required Database db,
    required String tableName,
    required int? loginId,
  }) async {
    try {
      final columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final availableColumns = columns
          .map((row) => (row['name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toSet();

      final filter = SrmRowVisibilityFilter.build(
        availableColumns: availableColumns,
        loginId: loginId,
      );
      return await db.query(
        tableName,
        where: filter.where,
        whereArgs: filter.whereArgs,
      );
    } catch (e) {
      debugPrint('Error reading line table $tableName: $e');
      return [];
    }
  }

  List<LatLng> _extractLinePoints(Map<String, dynamic> row) {
    final raw = row['points_json'];
    if (raw == null) return [];

    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) {
        if (raw is String) {
          return _extractLinePointsFromLooseString(raw);
        }
        return [];
      }

      final points = <LatLng>[];
      for (final item in decoded) {
        if (item is Map) {
          final lat = _toDouble(item['lat'] ?? item['latitude']);
          final lng = _toDouble(
            item['lon'] ?? item['lng'] ?? item['longitude'],
          );
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        } else if (item is List && item.length >= 2) {
          final lng = _toDouble(item[0]);
          final lat = _toDouble(item[1]);
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }
      }
      return points;
    } catch (_) {
      if (raw is String) {
        return _extractLinePointsFromLooseString(raw);
      }
      return [];
    }
  }

  List<LatLng> _extractLinePointsFromLooseString(String raw) {
    final matches = RegExp(
      r'lat:\s*([-0-9.]+),\s*lon:\s*([-0-9.]+)',
    ).allMatches(raw);
    return matches
        .map((match) {
          final lat = double.tryParse(match.group(1) ?? '');
          final lon = double.tryParse(match.group(2) ?? '');
          if (lat == null || lon == null) {
            return null;
          }
          return LatLng(lat, lon);
        })
        .whereType<LatLng>()
        .toList();
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Color _lineColorForMetier(String metier) {
    final normalized = metier.toLowerCase();
    if (normalized.contains('eau')) {
      return const Color(0xFF1E88E5);
    }
    if (normalized.contains('assain')) {
      return const Color(0xFF2E7D32);
    }
    return Colors.blueGrey;
  }

  _LineStyle _lineStyleForStatus({
    required Color baseColor,
    required bool hasAnomalie,
    required bool hasIncomplet,
  }) {
    if (hasAnomalie && hasIncomplet) {
      return _LineStyle(
        color: const Color(0xFFD84315),
        strokeWidth: 6.0,
        pattern: StrokePattern.dashed(segments: const [14, 5]),
      );
    }
    if (hasAnomalie) {
      return _LineStyle(
        color: const Color(0xFFD32F2F),
        strokeWidth: 5.0,
        pattern: StrokePattern.dashed(segments: const [12, 6]),
      );
    }
    if (hasIncomplet) {
      return const _LineStyle(
        color: Color(0xFFF57C00),
        strokeWidth: 5.0,
        pattern: StrokePattern.dotted(spacingFactor: 2.0),
      );
    }
    return _LineStyle(
      color: baseColor,
      strokeWidth: 4.0,
      pattern: const StrokePattern.solid(),
    );
  }

  double _polylineDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += _haversineDistance(points[i], points[i + 1]);
    }
    return total;
  }

  double _haversineDistance(LatLng start, LatLng end) {
    const r = 6371.0;
    final dLat = (end.latitude - start.latitude) * pi / 180;
    final dLon = (end.longitude - start.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(start.latitude * pi / 180) *
            cos(end.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }
}

class _LineStyle {
  final Color color;
  final double strokeWidth;
  final StrokePattern pattern;

  const _LineStyle({
    required this.color,
    required this.strokeWidth,
    required this.pattern,
  });
}
