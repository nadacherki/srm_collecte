part of 'home_page.dart';

Future<void> _loadDownloadedSpecialLinesImpl(_HomePageState state) async {
  if (state.mounted) {
    state._setStateFromPart(() {
      state._downloadedSpecialLinesPolylines = [];
    });
  }
  debugPrint('[_loadDownloadedSpecialLines] stubbed for Sprint 6');
}

Future<void> _loadDownloadedLineOverlaysImpl(_HomePageState state) async {
  debugPrint('[LINE-DOWNLOAD] chargement des polylignes telechargees');
  try {
    final polylines = await state._downloadedLinesService
        .getDownloadedLinesPolylines(
      onTapDetails: (data) {
        state._showLineDetailsSheet(
          context: state.context,
          lineCode: (data['line_code'] ?? '----').toString(),
          statut: 'Sauvegardee (downloaded)',
          region: state._regionNom,
          prefecture: state._prefectureNom,
          commune: state._communeNom,
          nbPoints: (data['nb_points'] as int?) ?? 0,
          distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
          startLat: (data['start_lat'] as num).toDouble(),
          startLng: (data['start_lng'] as num).toDouble(),
          endLat: (data['end_lat'] as num).toDouble(),
          endLng: (data['end_lng'] as num).toDouble(),
        );
      },
    );

    state._setStateFromPart(() {
      state._downloadedLinesPolylines = polylines;
    });

    final total = state.collectedPolylines.length +
        state._finishedLines.length +
        state._downloadedLinesPolylines.length;

    debugPrint('[LINE-DOWNLOAD] ${polylines.length} polyligne(s) chargee(s)');
    debugPrint('[LINE-DOWNLOAD] total avant rendu: $total');
  } catch (e) {
    debugPrint('[LINE-DOWNLOAD] erreur: $e');
  }
  debugPrint('[LINE-DOWNLOAD] chargement termine');
}

double _deg2radImpl(double deg) => deg * (math.pi / 180.0);

double _haversineMetersImpl(LatLng a, LatLng b) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _deg2radImpl(b.latitude - a.latitude);
  final dLng = _deg2radImpl(b.longitude - a.longitude);

  final lat1 = _deg2radImpl(a.latitude);
  final lat2 = _deg2radImpl(b.latitude);

  final sinDLat = math.sin(dLat / 2);
  final sinDLng = math.sin(dLng / 2);

  final h = sinDLat * sinDLat +
      math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng;
  final c = 2 * math.asin(math.min(1.0, math.sqrt(h)));
  return earthRadiusMeters * c;
}

double _polylineDistanceKmImpl(List<LatLng> points) {
  if (points.length < 2) return 0.0;
  double sum = 0.0;
  for (int i = 0; i < points.length - 1; i++) {
    sum += _haversineMetersImpl(points[i], points[i + 1]);
  }
  return sum / 1000.0;
}

Future<void> _loadDownloadedPointsImpl(_HomePageState state) async {
  if (state.mounted) {
    state._setStateFromPart(() {
      state._downloadedPointsByTable = {};
    });
  }
  await state._loadDisplayedPolygons();
  debugPrint('[_loadDownloadedPoints] stubbed for Sprint 6');
}

Future<void> _loadDisplayedSpecialLinesImpl(_HomePageState state) async {
  try {
    final srmLinesByTable = <String, List<Polyline>>{};
    final anomalieByTable = <String, List<Polyline>>{};
    final incompletByTable = <String, List<Polyline>>{};
    final lines = await state._specialLinesService.getDisplayedSpecialLines(
      onTapDetails: (data) {
        final start = LatLng(
          (data['start_lat'] as num).toDouble(),
          (data['start_lng'] as num).toDouble(),
        );
        final end = LatLng(
          (data['end_lat'] as num).toDouble(),
          (data['end_lng'] as num).toDouble(),
        );

        final distanceKm = _polylineDistanceKmImpl([start, end]);

        state._showSpecialLineDetailsSheet(
          context: state.context,
          specialType: (data['special_type'] ?? '----').toString(),
          statut: 'Sauvegardee (downloaded)',
          region: (data['region_name'] ?? '').toString().isNotEmpty
              ? (data['region_name']).toString()
              : state._regionNom,
          prefecture: (data['prefecture_name'] ?? '').toString().isNotEmpty
              ? (data['prefecture_name']).toString()
              : state._prefectureNom,
          commune: (data['commune_name'] ?? '').toString().isNotEmpty
              ? (data['commune_name']).toString()
              : state._communeNom,
          enqueteur: (data['enqueteur'] ?? '').toString(),
          distanceKm: distanceKm,
          startLat: start.latitude,
          startLng: start.longitude,
          endLat: end.latitude,
          endLng: end.longitude,
        );
      },
      onPolylineCreated: (tableName, metier, polyline) {
        srmLinesByTable.putIfAbsent(tableName, () => <Polyline>[]).add(polyline);
        final hitValue = polyline.hitValue;
        if (hitValue is PolylineTapData) {
          final data = hitValue.data;
          final hasAnomalie =
              data['anomalie'] == true || data['anomalie'] == 1;
          final hasIncomplet =
              data['objet_incomplet'] == true ||
              data['objet_incomplet'] == 1;
          if (hasAnomalie) {
            anomalieByTable.putIfAbsent(tableName, () => <Polyline>[]).add(polyline);
          }
          if (hasIncomplet) {
            incompletByTable.putIfAbsent(tableName, () => <Polyline>[]).add(polyline);
          }
        }
      },
    );

    state._setStateFromPart(() {
      state._displayedSpecialLines = lines;
      state._displayedSrmLinesByTable = srmLinesByTable;
      state._displayedLineAnomalieByTable = anomalieByTable;
      state._displayedLineIncompletByTable = incompletByTable;
    });

    debugPrint('[SRM-LINES] ${lines.length} ligne(s) speciale(s) affichee(s)');
  } catch (e) {
    debugPrint('[SPECIAL] Error loading special lines: $e');
  }
}

Future<void> _loadDisplayedPolygonsImpl(_HomePageState state) async {
  try {
    final db = await DatabaseHelper().database;
    final loginId = await DatabaseHelper().resolveLoginId();
    final List<Polygon> mapPolygons = [];

    final polygonTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['enquete_polygone'],
    );

    if (polygonTables.isNotEmpty) {
      final genericPolygons = await db.query(
        'enquete_polygone',
        where: loginId == null ? null : '(login_id = ? OR saved_by_user_id = ?)',
        whereArgs: loginId == null ? null : [loginId, loginId],
      );

      for (final poly in genericPolygons) {
        final points = _extractPolygonPointsImpl(poly['points_json']);
        if (points.length < 3) continue;

        mapPolygons.add(
          Polygon(
            points: points,
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
            borderColor: const Color(0xFF2E7D32),
            borderStrokeWidth: 2.0,
            hitValue: PolygonTapData(
              nom: poly['nom']?.toString() ?? '----',
              lineCode: poly['line_code']?.toString() ?? '----',
              superficie: (poly['superficie_en_ha'] as num?)?.toDouble() ?? 0.0,
              nbSommets: points.length,
              enqueteur: poly['enqueteur']?.toString() ?? '',
              dateCreation: poly['date_creation']?.toString() ?? '----',
              synced: poly['synced'] == 1,
              downloaded: poly['downloaded'] == 1,
              regionName: poly['region_name']?.toString() ?? '',
              prefectureName: poly['prefecture_name']?.toString() ?? '',
              communeName: poly['commune_name']?.toString() ?? '',
            ),
          ),
        );
      }
    }

    final Map<String, List<Polygon>> srmPolygonsByTable = {};

    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getPolygonEntities(metier)) {
        final tableName = SrmConfig.getTableName(metier, entity);
        if (tableName == null || tableName.isEmpty) continue;

        try {
          final columns = await db.rawQuery('PRAGMA table_info($tableName)');
          final availableColumns = columns
              .map((row) => (row['name'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .toSet();

          final filters = <String>[];
          final args = <dynamic>[];
          final userFilterColumns = [
            'id_agent_crea',
            'saved_by_user_id',
            'login_id',
            'id_user_creat',
          ];

          if (ApiService.currentProjetId != null &&
              availableColumns.contains('id_projet')) {
            filters.add('id_projet = ?');
            args.add(ApiService.currentProjetId);
          } else if (loginId != null) {
            for (final column in userFilterColumns) {
              if (availableColumns.contains(column)) {
                filters.add('$column = ?');
                args.add(loginId);
              }
            }
          }

          final rows = await db.query(
            tableName,
            where: filters.isEmpty ? null : filters.join(' OR '),
            whereArgs: args.isEmpty ? null : args,
          );

          for (final poly in rows) {
            final points = _extractPolygonPointsImpl(poly['points_json']);
            if (points.length < 3) continue;

            final polygon = Polygon(
              points: points,
              color: Color(SrmConfig.getMetierColor(metier)).withValues(alpha: 0.25),
              borderColor: Color(SrmConfig.getMetierColor(metier)),
              borderStrokeWidth: 2.0,
              hitValue: PolygonTapData(
                nom: poly['nom']?.toString() ??
                    poly['ep_num']?.toString() ??
                    entity,
                lineCode: poly['line_code']?.toString() ?? '----',
                superficie: (poly['superficie_ha'] as num?)?.toDouble() ??
                    (poly['superficie_en_ha'] as num?)?.toDouble() ??
                    0.0,
                nbSommets: points.length,
                enqueteur: poly['enqueteur']?.toString() ??
                    ApiService.nomPrenom ??
                    '',
                dateCreation: poly['date_collecte']?.toString() ??
                    poly['date_creation']?.toString() ??
                    '----',
                synced: poly['synced'] == 1,
                downloaded: poly['downloaded'] == 1,
                regionName: poly['region_name']?.toString() ?? '',
                prefectureName: poly['prefecture_name']?.toString() ?? '',
                communeName: poly['commune_name']?.toString() ?? '',
              ),
            );
            srmPolygonsByTable.putIfAbsent(tableName, () => []).add(polygon);
            mapPolygons.add(polygon);
          }
        } catch (e) {
          debugPrint('[POLYGONE] Error loading SRM polygon $tableName: $e');
        }
      }
    }

    if (state.mounted) {
      final previewLoaded = state._pendingPolygonPreviewPoints != null &&
          _containsPolygonPreviewImpl(
            mapPolygons,
            state._pendingPolygonPreviewPoints!,
          );
      state._setStateFromPart(() {
        state._displayedPolygons = mapPolygons;
        state._displayedSrmPolygonsByTable = srmPolygonsByTable;
        if (previewLoaded) {
          state._pendingPolygonPreviewPoints = null;
        }
      });
      debugPrint('[SRM-POLYGONES] ${mapPolygons.length} polygone(s) affiche(s)');
    }
  } catch (e) {
    debugPrint('[POLYGONE] Error loading polygons: $e');
  }
}

List<LatLng> _extractPolygonPointsImpl(dynamic rawPoints) {
  if (rawPoints == null) return [];

  try {
    final dynamic decoded = rawPoints is String ? jsonDecode(rawPoints) : rawPoints;
    if (decoded is! List) return [];

    final points = <LatLng>[];
    for (final item in decoded) {
      if (item is List && item.length >= 2) {
        final lng = item[0];
        final lat = item[1];
        if (lng is num && lat is num) {
          points.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      } else if (item is Map) {
        final lat = item['lat'] ?? item['latitude'];
        final lng = item['lon'] ?? item['lng'] ?? item['longitude'];
        if (lat is num && lng is num) {
          points.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
    }

    if (points.length >= 2 && points.first == points.last) {
      return points.sublist(0, points.length - 1);
    }
    return points;
  } catch (_) {
    return [];
  }
}

bool _samePointImpl(LatLng a, LatLng b, {double tolerance = 0.0000001}) {
  return (a.latitude - b.latitude).abs() <= tolerance &&
      (a.longitude - b.longitude).abs() <= tolerance;
}

bool _containsPolygonPreviewImpl(
  List<Polygon> polygons,
  List<LatLng> previewPoints,
) {
  for (final polygon in polygons) {
    final points = polygon.points;
    if (points.length != previewPoints.length) continue;

    var matches = true;
    for (int i = 0; i < points.length; i++) {
      if (!_samePointImpl(points[i], previewPoints[i])) {
        matches = false;
        break;
      }
    }

    if (matches) {
      return true;
    }
  }
  return false;
}

Future<void> _loadDisplayedPointsImpl(_HomePageState state) async {
  debugPrint('[_loadDisplayedPoints] refresh');

  try {
    final Map<String, List<Marker>> callbackByTable = {};
    final Map<String, List<Marker>> anomalieByTable = {};
    final Map<String, List<Marker>> incompletByTable = {};
    final Map<String, int> anomalieCounts = {};
    final Map<String, int> incompletCounts = {};
    final markers = await state._pointsService.getDisplayedPointsMarkers(
      onTapDetails: (data) {
        state._suspendAutoCenterFor(const Duration(seconds: 10));
        state._showPointDetailsSheet(
          context: state.context,
          type: (data['type'] ?? 'Point').toString(),
          name: (data['name'] ?? 'Sans nom').toString(),
          region: (data['region_name'] ?? '').toString().isNotEmpty
              ? (data['region_name']).toString()
              : state._regionNom,
          prefecture: (data['prefecture_name'] ?? '').toString().isNotEmpty
              ? (data['prefecture_name']).toString()
              : state._prefectureNom,
          commune: (data['commune_name'] ?? '').toString().isNotEmpty
              ? (data['commune_name']).toString()
              : state._communeNom,
          enqueteur: (data['enqueteur'] ?? '').toString(),
          lineCode: (data['line_code'] ?? '').toString(),
          lat: (data['lat'] as num).toDouble(),
          lng: (data['lng'] as num).toDouble(),
          statut: (data['synced'].toString() == '1')
              ? 'Synchronisee'
              : 'Enregistree localement',
        );
      },
      onMarkerCreated: (
        tableName,
        marker, {
        bool hasAnomalie = false,
        bool hasIncomplet = false,
      }) {
        callbackByTable.putIfAbsent(tableName, () => []);
        callbackByTable[tableName]!.add(marker);
        if (hasAnomalie) {
          anomalieByTable.putIfAbsent(tableName, () => []).add(marker);
        }
        if (hasIncomplet) {
          incompletByTable.putIfAbsent(tableName, () => []).add(marker);
        }
      },
      onAnomalieDetected: (tableName, hasAnomalie) {
        if (hasAnomalie) {
          anomalieCounts.putIfAbsent(tableName, () => 0);
          anomalieCounts[tableName] = (anomalieCounts[tableName] ?? 0) + 1;
        }
      },
      onIncompletDetected: (tableName, hasIncomplet) {
        if (hasIncomplet) {
          incompletCounts.putIfAbsent(tableName, () => 0);
          incompletCounts[tableName] = (incompletCounts[tableName] ?? 0) + 1;
        }
      },
    );

    final existingPoints = callbackByTable.entries
        .expand(
          (entry) => entry.value.map(
            (marker) => {
              'original_table': entry.key,
              'latitude': marker.point.latitude,
              'longitude': marker.point.longitude,
              'id':
                  '${entry.key}_${marker.point.latitude}_${marker.point.longitude}',
            },
          ),
        )
        .toList();

    final existingPositions = existingPoints.map((point) {
      final lat = (point['latitude'] as num).toDouble();
      final lng = (point['longitude'] as num).toDouble();
      return '${lat}_$lng';
    }).toSet();

    final validMarkers = markers.where((marker) {
      final posKey = '${marker.point.latitude}_${marker.point.longitude}';
      return existingPositions.contains(posKey);
    }).toList();

    final Map<String, List<Marker>> byTable = {};
    final Map<String, List<Map<String, dynamic>>> pointsByPosition = {};
    for (final point in existingPoints) {
      final lat = (point['latitude'] as num).toDouble();
      final lng = (point['longitude'] as num).toDouble();
      final posKey = '${lat}_$lng';
      pointsByPosition.putIfAbsent(posKey, () => []);
      pointsByPosition[posKey]!.add(point);
    }

    for (final marker in validMarkers) {
      final posKey = '${marker.point.latitude}_${marker.point.longitude}';
      final pointsAtPos = pointsByPosition[posKey];
      if (pointsAtPos != null && pointsAtPos.isNotEmpty) {
        final point = pointsAtPos.removeAt(0);
        final table = (point['original_table'] ?? '').toString();
        if (table.isNotEmpty) {
          byTable.putIfAbsent(table, () => []);
          byTable[table]!.add(marker);
        }
      }
    }

    state._setStateFromPart(() {
      state._displayedPointsByTable = byTable;
      state._displayedAnomalieByTable = anomalieByTable;
      state._displayedIncompletByTable = incompletByTable;
      state._anomalieCountsByTable = anomalieCounts;
      state._incompletCountsByTable = incompletCounts;
    });

    await state._loadPointCountsByTable();

    debugPrint(
      '[SRM-POINTS] ${validMarkers.length} point(s) valides affiches',
    );
  } catch (e) {
    debugPrint('[SRM-POINTS] erreur de chargement: $e');
  }
}

Future<void> _loadPointCountsByTableImpl(_HomePageState state) async {
  try {
    final db = await DatabaseHelper().database;
    final loginId = await DatabaseHelper().resolveLoginId();
    final Map<String, int> counts = {};
    final Map<String, int> anomalieCounts = {};
    final Map<String, int> incompletCounts = {};
    final tables = <String>{};

    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getPointEntities(metier)) {
        final tableName = SrmConfig.getTableName(metier, entity);
        if (tableName != null && tableName.isNotEmpty) {
          tables.add(tableName);
        }
      }
      for (final entity in SrmConfig.getLineEntities(metier)) {
        final tableName = SrmConfig.getTableName(metier, entity);
        if (tableName != null && tableName.isNotEmpty) {
          tables.add(tableName);
        }
      }
    }

    for (final table in tables) {
      try {
        final columns = await db.rawQuery('PRAGMA table_info($table)');
        final availableColumns = columns
            .map((row) => (row['name'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .toSet();

        final filters = <String>[];
        final args = <dynamic>[];

        if (ApiService.currentProjetId != null &&
            availableColumns.contains('id_projet')) {
          filters.add('id_projet = ?');
          args.add(ApiService.currentProjetId);
        } else if (loginId != null) {
          for (final column in [
            'id_agent_crea',
            'saved_by_user_id',
            'login_id',
          ]) {
            if (availableColumns.contains(column)) {
              filters.add('$column = ?');
              args.add(loginId);
            }
          }
        }

        final whereClause =
            filters.isEmpty ? '' : ' WHERE ${filters.join(' OR ')}';
        final result = await db.rawQuery(
          'SELECT '
          'COUNT(*) as c, '
          '${availableColumns.contains('anomalie') ? "SUM(CASE WHEN anomalie = 1 THEN 1 ELSE 0 END)" : "0"} as anomalies, '
          '${availableColumns.contains('objet_incomplet') ? "SUM(CASE WHEN objet_incomplet = 1 THEN 1 ELSE 0 END)" : "0"} as incomplets '
          'FROM $table$whereClause',
          args,
        );
        final row = result.first;
        counts[table] = (row['c'] as num?)?.toInt() ?? 0;
        anomalieCounts[table] = (row['anomalies'] as num?)?.toInt() ?? 0;
        incompletCounts[table] = (row['incomplets'] as num?)?.toInt() ?? 0;
      } catch (_) {
        counts[table] = 0;
        anomalieCounts[table] = 0;
        incompletCounts[table] = 0;
      }
    }

    if (state.mounted) {
      state._setStateFromPart(() {
        state._pointCountsByTable = counts;
        state._anomalieCountsByTable = anomalieCounts;
        state._incompletCountsByTable = incompletCounts;
      });
    }
    debugPrint('[SRM-POINTS] compteurs par table: $counts');
  } catch (e) {
    debugPrint('[COUNTS] Error counting points: $e');
  }
}

Future<void> _loadDisplayedLinesImpl(_HomePageState state) async {
  try {
    final storageHelper = LineStorageHelper();
    final rows = await storageHelper.loadDisplayedLinesMaps();
    final displayedLines = <Polyline>[];

    for (final row in rows) {
      final lineCode = (row['line_code'] ?? '----').toString().trim();
      final pointsData = jsonDecode(row['points_json'] as String) as List;
      final pts = <LatLng>[];

      for (final point in pointsData) {
        final lat = point['latitude'] ?? point['lat'];
        final lng = point['longitude'] ?? point['lng'];

        final latD = (lat is num) ? lat.toDouble() : null;
        final lngD = (lng is num) ? lng.toDouble() : null;

        if (latD != null && lngD != null) {
          pts.add(LatLng(latD, lngD));
        }
      }

      if (pts.isEmpty) continue;

      final distanceKm = pts.length >= 2 ? _polylineDistanceKmImpl(pts) : 0.0;

      String piSynced = '0';
      String piRegion = '';
      String piPrefecture = '';
      String piCommune = '';
      String piEnqueteur = '';
      String piPlateforme = '';
      String piRelief = '';
      String piVegetation = '';
      String piDebutTravaux = '';
      String piFinTravaux = '';
      String piFinancement = '';
      String piProjet = '';
      String piEntreprise = '';
      try {
        final lineDb = await LineStorageHelper().database;
        final lineRows = await lineDb.query(
          'lines',
          columns: [
            'synced',
            'region_name',
            'prefecture_name',
            'commune_name',
            'platform',
            'relief',
            'vegetation',
            'work_start',
            'work_end',
            'funding',
            'project',
            'company',
            'user_login',
          ],
          where: 'line_code = ?',
          whereArgs: [lineCode],
          limit: 1,
        );
        if (lineRows.isNotEmpty) {
          piSynced = (lineRows.first['synced']?.toString() == '1') ? '1' : '0';
          piRegion = (lineRows.first['region_name'] ?? '').toString();
          piPrefecture = (lineRows.first['prefecture_name'] ?? '').toString();
          piCommune = (lineRows.first['commune_name'] ?? '').toString();
          piEnqueteur = (lineRows.first['user_login'] ?? '').toString();
          piPlateforme = (lineRows.first['platform'] ?? '').toString();
          piRelief = (lineRows.first['relief'] ?? '').toString();
          piVegetation = (lineRows.first['vegetation'] ?? '').toString();
          piDebutTravaux = (lineRows.first['work_start'] ?? '').toString();
          piFinTravaux = (lineRows.first['work_end'] ?? '').toString();
          piFinancement = (lineRows.first['funding'] ?? '').toString();
          piProjet = (lineRows.first['project'] ?? '').toString();
          piEntreprise = (lineRows.first['company'] ?? '').toString();
        }
      } catch (_) {}

      displayedLines.add(
        Polyline(
          points: pts,
          color: Color(row['color'] as int),
          strokeWidth: 5.0,
          pattern: const StrokePattern.dotted(spacingFactor: 2.0),
          hitValue: PolylineTapData(
            type: 'line_local',
            data: {
              'line_code': lineCode,
              'nb_points': pts.length,
              'distance_km': distanceKm,
              'start_lat': pts.first.latitude,
              'start_lng': pts.first.longitude,
              'end_lat': pts.last.latitude,
              'end_lng': pts.last.longitude,
              'platform': piPlateforme,
              'relief': piRelief,
              'vegetation': piVegetation,
              'work_start': piDebutTravaux,
              'work_end': piFinTravaux,
              'funding': piFinancement,
              'project': piProjet,
              'company': piEntreprise,
              'synced': piSynced,
              'region_name': piRegion,
              'prefecture_name': piPrefecture,
              'commune_name': piCommune,
              'enqueteur': piEnqueteur,
            },
          ),
        ),
      );
    }

    state._setStateFromPart(() {
      state._finishedLines = displayedLines;
    });

    debugPrint('[LINE-OVERLAY] ${displayedLines.length} ligne(s) rechargee(s)');
  } catch (e) {
    debugPrint('[LINE] Error reloading displayed tracks: $e');
  }
}
