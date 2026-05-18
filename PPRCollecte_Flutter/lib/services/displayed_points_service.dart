import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import '../core/config/srm_config.dart';
import '../data/local/database_helper.dart';
import 'projection_service.dart';
import 'srm_row_visibility_filter.dart';
import 'srm_status_flags.dart';
import 'formulaire_config_mobile_service.dart';
import '../widgets/common/custom_marker_icons.dart';
import '../data/remote/api_service.dart';

class DisplayedPointsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  static const double _pointMarkerSize = 36.0;
  static const double _pointAlertMarkerSize = 40.0;
  static const double _pointTapTargetSize = 36.0;

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
    void Function(Map<String, dynamic> data)? onMarkerData,
  }) async {
    try {
      final db = await _dbHelper.database;
      final loginId = await _dbHelper.resolveLoginId();
      final List<Marker> markers = [];
      final formulaireConfigService = FormulaireConfigMobileService();

      for (final metier in SrmConfig.getMetiers()) {
        final titleByTable =
            await formulaireConfigService.getTitleByMobileTable(
          mobileMetier: metier,
          refreshIfEmpty: false,
        );

        for (final entityType in SrmConfig.getPointEntities(metier)) {
          final tableName = SrmConfig.getTableName(metier, entityType);
          if (tableName == null || tableName.isEmpty) continue;

          final entityTitle = titleByTable[tableName] ?? entityType;

          final rows = await _fetchVisibleRows(
            db: db,
            tableName: tableName,
            loginId: loginId,
          );

          for (final row in rows) {
            final latLng = _extractLatLng(row, metier, tableName: tableName);
            if (latLng == null) continue;

            final editableItem = Map<String, dynamic>.from(row);
            editableItem['source_table'] = tableName;
            editableItem['source_metier'] = metier;
            editableItem['source_entity'] = entityType;
            editableItem['source_title'] = entityTitle;
            editableItem['geometry_type'] = 'Point';

            if (editableItem['latitude_gps'] == null) {
              editableItem['latitude_gps'] = latLng.latitude;
            }
            if (editableItem['longitude_gps'] == null) {
              editableItem['longitude_gps'] = latLng.longitude;
            }

            final statusFlags = _resolveStatusFlags(row, tableName);
            final hasAnomalie = statusFlags.hasAnomalie;
            final hasIncomplet = statusFlags.hasIncomplet;

            final markerSize = _resolveMarkerSize(
              tableName,
              hasAnomalie: hasAnomalie,
              hasIncomplet: hasIncomplet,
            );

            final hitBoxSize = math.max(markerSize, _pointTapTargetSize);

            final markerData = <String, dynamic>{
              'type': entityTitle,
              'name': _resolvePointName(row, entityType),
              'metier': metier,
              'table_name': tableName,
              'anomalie': hasAnomalie,
              'objet_incomplet': hasIncomplet,
              'status_conflict': statusFlags.hasConflict,
              'status_conflict_unresolved': statusFlags.isUnresolvedConflict,
              'resolved_status': statusFlags.statusName,
              'anomalie_status_date': statusFlags.anomalieDateIso,
              'incomplet_status_date': statusFlags.incompletDateIso,
              'type_anomalie': (row['type_anomalie'] ??
                      row['anomalie_regard'] ??
                      row['anomalie_tamp'] ??
                      '')
                  .toString(),
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
              'region_name': (row['region_name'] ?? '').toString(),
              'prefecture_name': (row['prefecture_name'] ?? '').toString(),
              'commune_name': (row['commune_name'] ?? '').toString(),
            };

            onMarkerData?.call(markerData);

            final marker = Marker(
              point: latLng,
              width: hitBoxSize,
              height: hitBoxSize,
              child: GestureDetector(
                onTap: () => onTapDetails(markerData),
                child: Center(
                  child: hasAnomalie
                      ? CustomMarkerIcons.getAnomalieMarkerWidget(
                          tableName,
                          size: markerSize,
                        )
                      : hasIncomplet
                          ? CustomMarkerIcons.getIncompletMarkerWidget(
                              tableName,
                              size: markerSize,
                            )
                          : CustomMarkerIcons.getMarkerWidget(
                              tableName,
                              size: markerSize,
                            ),
                ),
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

      debugPrint(
        'Loaded ${markers.length} displayed SRM point markers '
        '(cache: ${CustomMarkerIcons.getCacheSize()})',
      );

      return markers;
    } catch (e) {
      debugPrint('Error in getDisplayedPointsMarkers: $e');
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
      debugPrint('Error reading table $tableName: $e');
      return [];
    }
  }

  Future<List<Marker>> getDisplayedRegardMarkersForDay({
    required DateTime day,
    required void Function(Map<String, dynamic>) onTapRegard,
    void Function(Map<String, dynamic> row, Marker marker)? onMarkerCreated,
    String metier = 'Eau Potable',
    String entityType = 'Regard',
    String tableName = 'ep_regard_point',
  }) async {
    try {
      final db = await _dbHelper.database;
      final loginId = await _dbHelper.resolveLoginId();

      final rows = await _fetchVisibleRows(
        db: db,
        tableName: tableName,
        loginId: loginId,
      );

      final markers = <Marker>[];

      for (final row in rows) {
        if (!_matchesCalendarDay(_resolveRegardDay(row), day)) {
          continue;
        }

        final latLng = _extractLatLng(row, metier, tableName: tableName);
        if (latLng == null) continue;

        final editableItem = Map<String, dynamic>.from(row);
        editableItem['source_table'] = tableName;
        editableItem['source_metier'] = metier;
        editableItem['source_entity'] = entityType;
        editableItem['geometry_type'] = 'Point';

        final statusFlags = _resolveStatusFlags(row, tableName);
        final hasAnomalie = statusFlags.hasAnomalie;
        final hasIncomplet = statusFlags.hasIncomplet;

        final markerSize = _resolveMarkerSize(
          tableName,
          hasAnomalie: hasAnomalie,
          hasIncomplet: hasIncomplet,
        );

        final hitBoxSize = math.max(markerSize, 58.0);

        final nodeId =
            _toInt(row['fid']) ?? _toInt(row['id']) ?? _toInt(row['rowid']);

        final marker = Marker(
          point: latLng,
          width: hitBoxSize,
          height: hitBoxSize,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              debugPrint(
                '[CONDUITE] direct marker tap nodeId=$nodeId '
                'fid=${row['fid']}',
              );

              onTapRegard({
                'node_id': nodeId,
                'fid': row['fid'],
                'name': _resolvePointName(row, entityType),
                'entity_type': entityType,
                'table_name': tableName,
                'metier': metier,
                'lat': latLng.latitude,
                'lng': latLng.longitude,
                'existing_item': editableItem,
                'anomalie': hasAnomalie,
                'objet_incomplet': hasIncomplet,
                'status_conflict': statusFlags.hasConflict,
                'status_conflict_unresolved': statusFlags.isUnresolvedConflict,
                'resolved_status': statusFlags.statusName,
                'anomalie_status_date': statusFlags.anomalieDateIso,
                'incomplet_status_date': statusFlags.incompletDateIso,
              });
            },
            child: Center(
              child: IgnorePointer(
                child: hasAnomalie
                    ? CustomMarkerIcons.getAnomalieMarkerWidget(
                        tableName,
                        size: markerSize,
                      )
                    : hasIncomplet
                        ? CustomMarkerIcons.getIncompletMarkerWidget(
                            tableName,
                            size: markerSize,
                          )
                        : CustomMarkerIcons.getMarkerWidget(
                            tableName,
                            size: markerSize,
                          ),
              ),
            ),
          ),
        );

        markers.add(marker);
        onMarkerCreated?.call(editableItem, marker);
      }

      return markers;
    } catch (e) {
      debugPrint('Error in getDisplayedRegardMarkersForDay: $e');
      return [];
    }
  }

  _ResolvedPointStatus _resolveStatusFlags(
    Map<String, dynamic> row,
    String tableName,
  ) {
    final resolvedStatus = SrmStatusFlags.resolveStatus(row);
    final hasRawConflict = SrmStatusFlags.hasStatusConflict(row);
    final anomalieDate = SrmStatusFlags.latestAnomalieDate(row);
    final incompletDate = SrmStatusFlags.latestIncompletDate(row);

    if (resolvedStatus == SrmResolvedStatus.conflictUnknown) {
      debugPrint(
        '[SRM_STATUS_CONFLICT] table=$tableName '
        "fid=${row['fid']} id=${row['id']} uuid=${row['uuid']} "
        'anomalieDate=$anomalieDate incompletDate=$incompletDate '
        "type_anomalie=${row['type_anomalie']} "
        "ep_anomalie=${row['ep_anomalie']} "
        "objet_incomplet=${row['objet_incomplet']} "
        "raison_incomplet=${row['raison_incomplet']} "
        "date_creation=${row['date_creation']} "
        "date_modif=${row['date_modif']} "
        "updated_at=${row['updated_at']}",
      );
    }

    return _ResolvedPointStatus(
      status: resolvedStatus,
      hasRawConflict: hasRawConflict,
      anomalieDate: anomalieDate,
      incompletDate: incompletDate,
    );
  }

  double _resolveMarkerSize(
    String tableName, {
    required bool hasAnomalie,
    required bool hasIncomplet,
  }) {
    final isRegard = _isRegardTable(tableName);
    final isAlert = hasAnomalie || hasIncomplet;

    if (isRegard) {
      return isAlert ? _pointAlertMarkerSize : _pointMarkerSize;
    }

    return isAlert ? _pointAlertMarkerSize : _pointMarkerSize;
  }

  LatLng? _extractLatLng(
    Map<String, dynamic> row,
    String metier, {
    required String tableName,
  }) {
    final schema = SrmConfig.getMetierConfig(metier)?['schema']?.toString();
    final isRegard = _isRegardTable(tableName);

    if (isRegard && schema != null && schema.isNotEmpty) {
      final x = _toDouble(row['${schema}_coor_x']);
      final y = _toDouble(row['${schema}_coor_y']);

      if (x != null && y != null) {
        final wgs84 = ProjectionService().merchichToWgs84(x: x, y: y);
        return LatLng(wgs84.latitude, wgs84.longitude);
      }
    }

    final latitude = _toDouble(row['latitude_gps']);
    final longitude = _toDouble(row['longitude_gps']);

    if (latitude != null && longitude != null) {
      return LatLng(latitude, longitude);
    }

    if (schema == null || schema.isEmpty) return null;

    final x = _toDouble(row['${schema}_coor_x']);
    final y = _toDouble(row['${schema}_coor_y']);

    if (x == null || y == null) return null;

    final wgs84 = ProjectionService().merchichToWgs84(x: x, y: y);
    return LatLng(wgs84.latitude, wgs84.longitude);
  }

  bool _isRegardTable(String tableName) {
    return const {
      'regard',
      'regard_ep',
      'ep_regard_point',
      'asst_regard',
    }.contains(tableName);
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  DateTime? _resolveRegardDay(Map<String, dynamic> row) {
    final collecte = _parseDate(row['date_collecte']);
    if (collecte != null) return collecte;

    final insertion = _parseDate(row['ep_date_insertion']);
    if (insertion != null) return insertion;

    final creation = _parseDate(row['date_creation']);
    if (creation != null) return creation;

    return _parseDate(row['date_pose']);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    final parsed = DateTime.tryParse(text);
    return parsed?.toLocal();
  }

  bool _matchesCalendarDay(DateTime? candidate, DateTime day) {
    if (candidate == null) return false;

    return candidate.year == day.year &&
        candidate.month == day.month &&
        candidate.day == day.day;
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

class _ResolvedPointStatus {
  final SrmResolvedStatus status;
  final bool hasRawConflict;
  final DateTime? anomalieDate;
  final DateTime? incompletDate;

  const _ResolvedPointStatus({
    required this.status,
    required this.hasRawConflict,
    required this.anomalieDate,
    required this.incompletDate,
  });

  bool get hasAnomalie {
    return status == SrmResolvedStatus.anomalie;
  }

  bool get hasIncomplet {
    return status == SrmResolvedStatus.incomplet;
  }

  bool get hasConflict => hasRawConflict;

  bool get isUnresolvedConflict {
    return status == SrmResolvedStatus.conflictUnknown;
  }

  String get statusName => SrmStatusFlags.resolvedStatusName(status);

  String? get anomalieDateIso => anomalieDate?.toIso8601String();

  String? get incompletDateIso => incompletDate?.toIso8601String();
}