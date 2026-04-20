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
    void Function(String tableName, Marker marker, {bool hasAnomalie, bool hasIncomplet})? onMarkerCreated,
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

            // Détecter l'anomalie (stockée comme 1 / true en base)
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
                    'type_anomalie':
                        (row['type_anomalie'] ?? '').toString(),
                    'enqueteur': (row['enqueteur'] ??
                            ApiService.nomPrenom ??
                            ApiService.userLogin ??
                            '')
                        .toString(),
                    'line_code': (row['line_code'] ?? '').toString(),
                    'lat': latLng.latitude,
                    'lng': latLng.longitude,
                    'synced': (row['synced'] ?? 0).toString(),
                    'region_name': (row['region_name'] ??
                            ApiService.currentProjetRegion ??
                            '')
                        .toString(),
                    'prefecture_name': (row['prefecture_name'] ??
                            ApiService.currentProjetNom ??
                            '')
                        .toString(),
                    'commune_name':
                        (row['commune_name'] ?? '').toString(),
                  });
                },
                // Marqueur rouge danger si anomalie, sinon marqueur normal
                child: hasAnomalie
                    ? CustomMarkerIcons.getAnomalieMarkerWidget(tableName)
                    : hasIncomplet
                        ? CustomMarkerIcons.getIncompletMarkerWidget(tableName)
                        : CustomMarkerIcons.getMarkerWidget(tableName),
              ),
            );

            markers.add(marker);
            onMarkerCreated?.call(tableName, marker, hasAnomalie: hasAnomalie, hasIncomplet: hasIncomplet);
            // Notifier home_page pour comptage anomalies → légende
            onAnomalieDetected?.call(tableName, hasAnomalie);
            onIncompletDetected?.call(tableName, hasIncomplet);
          }
        }
      }

      print(
          'Loaded ${markers.length} displayed SRM point markers (cache: ${CustomMarkerIcons.getCacheSize()})');
      return markers;
    } catch (e) {
      print('Error in getDisplayedPointsMarkers: $e');
      return [];
    }
  }

  Future<List<Marker>> refreshDisplayedPoints({
    required void Function(Map<String, dynamic>) onTapDetails,
    void Function(String tableName, Marker marker, {bool hasAnomalie, bool hasIncomplet})? onMarkerCreated,
    void Function(String tableName, bool hasAnomalie)? onAnomalieDetected,
    void Function(String tableName, bool hasIncomplet)? onIncompletDetected,
  }) async {
    return await getDisplayedPointsMarkers(
      onTapDetails: onTapDetails,
      onMarkerCreated: onMarkerCreated,
      onAnomalieDetected: onAnomalieDetected,
    );
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

class DownloadedPointsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<Marker>> getDownloadedPointsMarkers({
    required void Function(Map<String, dynamic>) onTapDetails,
    void Function(String tableName, Marker marker)? onMarkerCreated,
  }) async {
    try {
      final List<String> pointTables = [
        'localites',
        'ecoles',
        'marches',
        'services_santes',
        'batiments_administratifs',
        'infrastructures_hydrauliques',
        'autres_infrastructures',
        'ponts',
        'buses',
        'dalots',
        'points_critiques',
        'points_coupures',
        'site_enquete',
        'enquete_polygone',
      ];

      final List<Marker> markers = [];
      final loginId = await DatabaseHelper().resolveLoginId();

      if (loginId == null) {
        print('Viewer login_id unavailable for downloaded points');
        return [];
      }

      for (var tableName in pointTables) {
        try {
          final db = await _dbHelper.database;
          final points = await db.query(
            tableName,
            where: 'downloaded = ? AND saved_by_user_id = ?',
            whereArgs: [1, loginId],
          );

          for (var point in points) {
            final coordinates = _getCoordinatesFromPoint(point, tableName);

            if (coordinates['lat'] != null && coordinates['lng'] != null) {
              final double lat = (coordinates['lat'] as num).toDouble();
              final double lng = (coordinates['lng'] as num).toDouble();
              final lineCode = point['line_code'] ?? 'N/A';

              markers.add(
                Marker(
                  point: LatLng(lat, lng),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      onTapDetails({
                        'type': _getEntityTypeFromTable(tableName),
                        'name': (point['nom'] ??
                                point['name'] ??
                                point['libelle'] ??
                                'Sans nom')
                            .toString(),
                        'enqueteur': (point['enqueteur'] ?? '').toString(),
                        'line_code': (lineCode).toString(),
                        'lat': lat,
                        'lng': lng,
                        'region_name': (point['region_name'] ?? '').toString(),
                        'prefecture_name':
                            (point['prefecture_name'] ?? '').toString(),
                        'commune_name': (point['commune_name'] ?? '').toString(),
                      });
                    },
                    child: CustomMarkerIcons.getMarkerWidget(tableName),
                  ),
                ),
              );
              if (onMarkerCreated != null) {
                onMarkerCreated(tableName, markers.last);
              }
            }
          }
        } catch (e) {
          print('Error loading downloaded points from $tableName: $e');
        }
      }

      print(
          'Loaded ${markers.length} downloaded point markers (cache: ${CustomMarkerIcons.getCacheSize()})');
      return markers;
    } catch (e) {
      print('Error in getDownloadedPointsMarkers: $e');
      return [];
    }
  }

  Map<String, dynamic> _getCoordinatesFromPoint(
    Map<String, dynamic> point,
    String tableName,
  ) {
    final coordinateMappings = {
      'localites': {
        'lat': 'y_localite',
        'lng': 'x_localite',
      },
      'ecoles': {
        'lat': 'y_ecole',
        'lng': 'x_ecole',
      },
      'marches': {
        'lat': 'y_marche',
        'lng': 'x_marche',
      },
      'services_santes': {
        'lat': 'y_sante',
        'lng': 'x_sante',
      },
      'batiments_administratifs': {
        'lat': 'y_batiment_administratif',
        'lng': 'x_batiment_administratif',
      },
      'infrastructures_hydrauliques': {
        'lat': 'y_infrastructure_hydraulique',
        'lng': 'x_infrastructure_hydraulique',
      },
      'autres_infrastructures': {
        'lat': 'y_autre_infrastructure',
        'lng': 'x_autre_infrastructure',
      },
      'ponts': {
        'lat': 'y_pont',
        'lng': 'x_pont',
      },
      'buses': {
        'lat': 'y_buse',
        'lng': 'x_buse',
      },
      'dalots': {
        'lat': 'y_dalot',
        'lng': 'x_dalot',
      },
      'points_critiques': {
        'lat': 'y_point_critique',
        'lng': 'x_point_critique',
      },
      'points_coupures': {
        'lat': 'y_point_coupure',
        'lng': 'x_point_coupure',
      },
      'site_enquete': {
        'lat': 'y_site',
        'lng': 'x_site',
      },
      'enquete_polygone': {
        'lat': 'y_site',
        'lng': 'x_site'
      },
    };

    final mapping = coordinateMappings[tableName];
    if (mapping != null) {
      return {
        'lat': point[mapping['lat']],
        'lng': point[mapping['lng']],
      };
    }

    return {
      'lat': null,
      'lng': null,
    };
  }

  String _getEntityTypeFromTable(
    String tableName,
  ) {
    const entityTypes = {
      'localites': 'Localité',
      'ecoles': 'École',
      'marches': 'Marché',
      'services_santes': 'Service de Santé',
      'batiments_administratifs': 'Bâtiment Administratif',
      'infrastructures_hydrauliques': 'Infrastructure Hydraulique',
      'autres_infrastructures': 'Autre Infrastructure',
      'ponts': 'Pont',
      'buses': 'Buse',
      'dalots': 'Dalot',
      'points_critiques': 'Point Critique',
      'points_coupures': 'Point de Coupure',
      'site_enquete': 'Site de Plaine',
      'enquete_polygone': 'Zone de Plaine',
    };
    return entityTypes[tableName] ?? tableName;
  }
}
