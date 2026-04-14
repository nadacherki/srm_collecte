import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../screens/home/home_page.dart';
import '../data/remote/api_service.dart';

class SpecialLinesService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Polyline>> getDisplayedSpecialLines({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    try {
      final db = await _dbHelper.database;
      final loginId = await _dbHelper.resolveLoginId();
      final List<Polyline> polylines = [];

      for (final metier in SrmConfig.getMetiers()) {
        for (final entityType in SrmConfig.getLineEntities(metier)) {
          final tableName = SrmConfig.getTableName(metier, entityType);
          if (tableName == null || tableName.isEmpty) continue;

          final rows = await _fetchVisibleRows(
            db: db,
            tableName: tableName,
            loginId: loginId,
          );

          for (final row in rows) {
            final points = _extractLinePoints(row);
            if (points.length < 2) continue;

            final polyline = Polyline(
              points: points,
              color: _lineColorForMetier(metier),
              strokeWidth: 4.0,
              pattern: const StrokePattern.solid(),
              hitValue: PolylineTapData(
                type: 'special_local',
                data: {
                  'special_type': entityType,
                  'table_name': tableName,
                  'metier': metier,
                  'start_lat': points.first.latitude,
                  'start_lng': points.first.longitude,
                  'end_lat': points.last.latitude,
                  'end_lng': points.last.longitude,
                  'distance_km': _polylineDistanceKm(points),
                  'synced': (row['synced'] ?? 0).toString(),
                  'region_name':
                      (row['region_name'] ?? ApiService.currentProjetRegion ?? '')
                          .toString(),
                  'prefecture_name':
                      (row['prefecture_name'] ?? ApiService.currentProjetNom ?? '')
                          .toString(),
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
          }
        }
      }

      print('[SRM-LIGNES] ${polylines.length} polyligne(s) affichee(s)');
      return polylines;
    } catch (e) {
      print('Error loading displayed SRM lines: $e');
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
          .where((name) => name.toString().isNotEmpty)
          .toSet();

      final filters = <String>[];
      final args = <dynamic>[];

      if (loginId != null) {
        for (final column in ['id_agent_crea', 'saved_by_user_id', 'login_id']) {
          if (availableColumns.contains(column)) {
            filters.add('$column = ?');
            args.add(loginId);
          }
        }
      }

      if (ApiService.currentProjetId != null &&
          availableColumns.contains('id_projet')) {
        filters.add('id_projet = ?');
        args.add(ApiService.currentProjetId);
      }

      final where = filters.isEmpty ? null : filters.join(' OR ');
      return await db.query(tableName, where: where, whereArgs: args);
    } catch (e) {
      print('Error reading line table $tableName: $e');
      return [];
    }
  }

  List<LatLng> _extractLinePoints(Map<String, dynamic> row) {
    final raw = row['points_json'];
    if (raw == null) return [];

    try {
      final dynamic decoded = raw is String ? jsonDecode(raw) : raw;
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
          final lng = _toDouble(item['lon'] ?? item['lng'] ?? item['longitude']);
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
    final matches = RegExp(r'lat:\s*([-0-9.]+),\s*lon:\s*([-0-9.]+)')
        .allMatches(raw);
    return matches.map((match) {
      final lat = double.tryParse(match.group(1) ?? '');
      final lon = double.tryParse(match.group(2) ?? '');
      if (lat == null || lon == null) {
        return null;
      }
      return LatLng(lat, lon);
    }).whereType<LatLng>().toList();
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Color _lineColorForMetier(String metier) {
    switch (metier) {
      case 'Eau Potable':
        return const Color(0xFF1E88E5);
      case 'Assainissement':
        return const Color(0xFF2E7D32);
      case 'Électricité':
        return const Color(0xFFF57C00);
      default:
        return Colors.blueGrey;
    }
  }

  double _polylineDistanceKm(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _haversineDistance(points[i], points[i + 1]);
    }
    return total;
  }

  double _haversineDistance(LatLng start, LatLng end) {
    const double r = 6371;
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

class DownloadedSpecialLinesService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Polyline>> getDownloadedSpecialLinesPolylines({
    required void Function(Map<String, dynamic>) onTapDetails,
  }) async {
    final polylines = <Polyline>{};

    try {
      final db = await _dbHelper.database;
      final loginId = await DatabaseHelper().resolveLoginId();

      if (loginId == null) {
        print('[DL-SPECIAL] Impossible de determiner login_id (viewer)');
        return [];
      }

      const tableName = 'special_lines';

      final rows = await db.query(
        tableName,
        where: 'downloaded = ? AND saved_by_user_id = ?',
        whereArgs: [1, loginId],
      );

      int added = 0, skipped = 0;

      for (final r in rows) {
        final specialTypeRaw = (r['special_type'] ?? r['type'] ?? '').toString();
        final st = specialTypeRaw.toLowerCase().trim();

        final latDebut = r['lat_debut'];
        final lngDebut = r['lng_debut'];
        final latFin = r['lat_fin'];
        final lngFin = r['lng_fin'];

        if (latDebut == null || lngDebut == null || latFin == null || lngFin == null) {
          skipped++;
          continue;
        }

        final start = LatLng((latDebut as num).toDouble(), (lngDebut as num).toDouble());
        final end = LatLng((latFin as num).toDouble(), (lngFin as num).toDouble());

        final String tag =
            st.contains('bac') ? 'bac' : (st.contains('passage') ? 'passage_submersible' : 'special');

        Color lineColor;
        StrokePattern? linePattern;

        if (tag == 'bac') {
          lineColor = Colors.purple;
          linePattern = StrokePattern.dashed(segments: const [15, 5]);
        } else if (tag == 'passage_submersible') {
          lineColor = Colors.cyan;
          linePattern = StrokePattern.dashed(segments: const [15, 5]);
        } else {
          lineColor = Colors.blueGrey;
          linePattern = null;
        }

        polylines.add(
          Polyline(
            points: [start, end],
            color: lineColor,
            strokeWidth: 4.0,
            pattern: linePattern ?? const StrokePattern.solid(),
            hitValue: PolylineTapData(
              type: 'special_downloaded',
              data: {
                'special_type': specialTypeRaw,
                'start_lat': start.latitude,
                'start_lng': start.longitude,
                'end_lat': end.latitude,
                'end_lng': end.longitude,
                'code_piste': (r['code_piste'] ?? '----').toString(),
                'distance_km': _haversineDistance(start, end),
                'region_name': (r['region_name'] ?? '----').toString(),
                'prefecture_name': (r['prefecture_name'] ?? '----').toString(),
                'commune_name': (r['commune_name'] ?? '----').toString(),
                'enqueteur': (r['enqueteur'] ?? '').toString(),
              },
            ),
          ),
        );

        added++;
      }

      print('[DL-SPECIAL] ajoutees: $added | ignorees: $skipped');
      return polylines.toList();
    } catch (e) {
      print('[DL-SPECIAL] Erreur chargement: $e');
      return [];
    }
  }

  double _haversineDistance(LatLng start, LatLng end) {
    const double r = 6371;
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
