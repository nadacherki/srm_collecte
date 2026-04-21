import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../services/projection_service.dart';
import '../widgets/common/custom_marker_icons.dart';
import '../data/remote/api_service.dart';

class DisplayedPointsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Marker>> getDisplayedPointsMarkers({
    required void Function(Map<String, dynamic>) onTapDetails,
    void Function(
      String tableName,
      Marker marker, {
      bool hasAnomalie,
      bool hasIncomplet,
    })? onMarkerCreated,
    void Function(String tableName, bool hasAnomalie)? onAnomalieDetected,
    void Function(String tableName, bool hasIncomplet)? onIncompletDetected,
  }) async {
    try {
      final db = await _dbHelper.database;
      final loginId = await _dbHelper.resolveLoginId();
      final List<Marker> markers = [];

      for (final metier in SrmConfig.getMetiers()) {
        for (final entityType in SrmConfig.getPointEntities(metier)) {
          final tableName = SrmConfig.getTableName(metier, entityType);
          if (tableName == null || tableName.isEmpty) continue;

          final rows = await _fetchVisibleRows(
            db: db,
            tableName: tableName,
            loginId: loginId,
          );

          for (final row in rows) {
            final latLng = _extractLatLng(row, metier);
            if (latLng == null) continue;
            final editableItem = Map<String, dynamic>.from(row);
            editableItem['source_table'] = tableName;
            editableItem['source_metier'] = metier;
            editableItem['source_entity'] = entityType;
            editableItem['geometry_type'] = 'Point';
            if (editableItem['latitude_gps'] == null) {
              editableItem['latitude_gps'] = latLng.latitude;
            }
            if (editableItem['longitude_gps'] == null) {
              editableItem['longitude_gps'] = latLng.longitude;
            }

            // Detecter l'anomalie stockee comme 1 / true en base.
            final hasAnomalie =
                row['anomalie'] == 1 || row['anomalie'] == true;
            final hasIncomplet =
                row['objet_incomplet'] == 1 || row['objet_incomplet'] == true;

            final marker = Marker(
              point: latLng,
              width: (hasAnomalie || hasIncomplet) ? 44 : 40,
              height: (hasAnomalie || hasIncomplet) ? 44 : 40,
              child: GestureDetector(
                onTap: () {
                  onTapDetails({
                    'type': entityType,
                    'name': _resolvePointName(row, entityType),
                    'metier': metier,
                    'table_name': tableName,
                    'anomalie': hasAnomalie,
                    'objet_incomplet': hasIncomplet,
                    'type_anomalie': (row['type_anomalie'] ?? '').toString(),
                    'enqueteur': (row['enqueteur'] ??
                            ApiService.nomPrenom ??
                            ApiService.userLogin ??
                            '')
                        .toString(),
                    'line_code': (row['line_code'] ?? '').toString(),
                    'lat': latLng.latitude,
                    'lng': latLng.longitude,
                    'synced': (row['synced'] ?? 0).toString(),
                    'existing_item': editableItem,
                    'region_name':
                        (row['region_name'] ?? ApiService.currentProjetRegion ?? '')
                            .toString(),
                    'prefecture_name':
                        (row['prefecture_name'] ?? ApiService.currentProjetNom ?? '')
                            .toString(),
                    'commune_name': (row['commune_name'] ?? '').toString(),
                  });
                },
                child: hasAnomalie
                    ? CustomMarkerIcons.getAnomalieMarkerWidget(tableName)
                    : hasIncomplet
                        ? CustomMarkerIcons.getIncompletMarkerWidget(tableName)
                        : CustomMarkerIcons.getMarkerWidget(tableName),
              ),
            );

            markers.add(marker);
            onMarkerCreated?.call(
              tableName,
              marker,
              hasAnomalie: hasAnomalie,
              hasIncomplet: hasIncomplet,
            );
            onAnomalieDetected?.call(tableName, hasAnomalie);
            onIncompletDetected?.call(tableName, hasIncomplet);
          }
        }
      }

      print(
        'Loaded ${markers.length} displayed SRM point markers (cache: ${CustomMarkerIcons.getCacheSize()})',
      );
      return markers;
    } catch (e) {
      print('Error in getDisplayedPointsMarkers: $e');
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
      print('Error reading table $tableName: $e');
      return [];
    }
  }

  LatLng? _extractLatLng(Map<String, dynamic> row, String metier) {
    final latitude = _toDouble(row['latitude_gps']);
    final longitude = _toDouble(row['longitude_gps']);
    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }

    final schema = SrmConfig.getMetierConfig(metier)?['schema']?.toString();
    if (schema == null || schema.isEmpty) return null;

    final x = _toDouble(row['${schema}_coor_x']);
    final y = _toDouble(row['${schema}_coor_y']);
    if (x == null || y == null) return null;

    final wgs84 = ProjectionService().merchichToWgs84(x: x, y: y);
    return LatLng(wgs84.latitude, wgs84.longitude);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _resolvePointName(Map<String, dynamic> point, String fallback) {
    for (final key in ['nom', 'name', 'libelle', 'ep_num', 'uuid']) {
      final value = point[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }
}
