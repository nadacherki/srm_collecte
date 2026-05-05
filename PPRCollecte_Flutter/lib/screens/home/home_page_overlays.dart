part of 'home_page.dart';

const String _epRegardMiroirOverlayTable = 'regard_miroir';
const double _regardMiroirLocalSquareSizeMeters = 24.0;

Future<void> _loadDownloadedSpecialLinesImpl(_HomePageState state) async {
  if (state.mounted) {
    state._setStateFromPart(() {
      state._downloadedSpecialLinesPolylines = [];
    });
  }
  debugPrint('[_loadDownloadedSpecialLines] stubbed for Sprint 6');
}

Future<void> _loadDownloadedLineOverlaysImpl(_HomePageState state) async {
  debugPrint('[LINE-DOWNLOAD] chargement des polylignes téléchargées');
  try {
    final polylines =
        await state._downloadedLinesService.getDownloadedLinesPolylines(
      onTapDetails: (data) {
        state._showLineDetailsSheet(
          context: state.context,
          lineCode: (data['line_code'] ?? '----').toString(),
          statut: 'Sauvegardée (téléchargée)',
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

  final h =
      sinDLat * sinDLat + math.cos(lat1) * math.cos(lat2) * sinDLng * sinDLng;
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
          statut: 'Sauvegardée (téléchargée)',
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
        srmLinesByTable
            .putIfAbsent(tableName, () => <Polyline>[])
            .add(polyline);
        final hitValue = polyline.hitValue;
        if (hitValue is PolylineTapData) {
          final data = hitValue.data;
          final hasAnomalie = data['anomalie'] == true || data['anomalie'] == 1;
          final hasIncomplet =
              data['objet_incomplet'] == true || data['objet_incomplet'] == 1;
          if (hasAnomalie) {
            anomalieByTable
                .putIfAbsent(tableName, () => <Polyline>[])
                .add(polyline);
          }
          if (hasIncomplet) {
            incompletByTable
                .putIfAbsent(tableName, () => <Polyline>[])
                .add(polyline);
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
    await state._loadPointCountsByTable();

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
    final Map<String, List<Polygon>> anomalieByTable = {};
    final Map<String, List<Polygon>> incompletByTable = {};

    bool hasRowAnomalie(Map<String, dynamic> row) {
      return SrmStatusFlags.hasAnomalie(row);
    }

    bool hasRowIncomplet(Map<String, dynamic> row) {
      return SrmStatusFlags.hasIncomplet(row);
    }

    Polygon buildPolygon({
      required List<LatLng> points,
      required Color baseColor,
      required PolygonTapData hitValue,
      bool hasAnomalie = false,
      bool hasIncomplet = false,
      double normalFillAlpha = 0.25,
      double alertFillAlpha = 0.22,
      double normalBorderWidth = 2.0,
      double alertBorderWidth = 2.8,
    }) {
      final borderColor = hasAnomalie
          ? const Color(0xFFD32F2F)
          : hasIncomplet
              ? const Color(0xFFF57C00)
              : baseColor;
      final fillColor = hasAnomalie
          ? const Color(0xFFD32F2F).withValues(alpha: alertFillAlpha)
          : hasIncomplet
              ? const Color(0xFFF57C00).withValues(alpha: alertFillAlpha)
              : baseColor.withValues(alpha: normalFillAlpha);

      return Polygon(
        points: points,
        color: fillColor,
        borderColor: borderColor,
        borderStrokeWidth:
            hasAnomalie || hasIncomplet ? alertBorderWidth : normalBorderWidth,
        hitValue: hitValue,
      );
    }

    final polygonTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      ['enquete_polygone'],
    );

    if (polygonTables.isNotEmpty) {
      final genericPolygons = await db.query(
        'enquete_polygone',
        where:
            loginId == null ? null : '(login_id = ? OR saved_by_user_id = ?)',
        whereArgs: loginId == null ? null : [loginId, loginId],
      );

      for (final poly in genericPolygons) {
        final points = _extractPolygonPointsImpl(poly['points_json']);
        if (points.length < 3) continue;
        final hasAnomalie = hasRowAnomalie(poly);
        final hasIncomplet = hasRowIncomplet(poly);

        mapPolygons.add(
          buildPolygon(
            points: points,
            baseColor: const Color(0xFF2E7D32),
            hasAnomalie: hasAnomalie,
            hasIncomplet: hasIncomplet,
            hitValue: PolygonTapData(
              nom: poly['nom']?.toString() ?? '----',
              code: poly['code']?.toString() ??
                  poly['line_code']?.toString() ??
                  '----',
              entityType: poly['entity_type']?.toString() ?? 'Zone de Plaine',
              metier: poly['metier']?.toString() ?? '',
              superficie: (poly['superficie_ha'] as num?)?.toDouble() ??
                  (poly['superficie_en_ha'] as num?)?.toDouble() ??
                  0.0,
              nbSommets: points.length,
              enqueteur: poly['enqueteur']?.toString() ?? '',
              dateCreation: poly['date_creation']?.toString() ?? '----',
              synced: poly['synced'] == 1,
              downloaded: poly['downloaded'] == 1,
              hasAnomalie: hasAnomalie,
              hasIncomplet: hasIncomplet,
              typeAnomalie: poly['type_anomalie']?.toString(),
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

          final filter = SrmRowVisibilityFilter.build(
            availableColumns: availableColumns,
            loginId: loginId,
          );

          final rows = await db.query(
            tableName,
            where: filter.where,
            whereArgs: filter.whereArgs,
          );

          for (final poly in rows) {
            final points = _extractPolygonPointsImpl(poly['points_json']);
            if (points.length < 3) continue;
            final hasAnomalie = hasRowAnomalie(poly);
            final hasIncomplet = hasRowIncomplet(poly);
            final editableItem = Map<String, dynamic>.from(poly);
            editableItem['source_table'] = tableName;
            editableItem['source_metier'] = metier;
            editableItem['source_entity'] = entity;
            editableItem['geometry_type'] = 'Polygon';

            final polygon = buildPolygon(
              points: points,
              baseColor: Color(SrmConfig.getMetierColor(metier)),
              hasAnomalie: hasAnomalie,
              hasIncomplet: hasIncomplet,
              hitValue: PolygonTapData(
                nom: poly['nom']?.toString() ??
                    poly['ep_num']?.toString() ??
                    entity,
                code: poly['code']?.toString() ??
                    poly['code_gps']?.toString() ??
                    poly['line_code']?.toString() ??
                    poly['ep_num']?.toString() ??
                    '----',
                entityType: entity,
                metier: metier,
                superficie: (poly['superficie_ha'] as num?)?.toDouble() ??
                    (poly['superficie_en_ha'] as num?)?.toDouble() ??
                    0.0,
                nbSommets: points.length,
                enqueteur:
                    poly['enqueteur']?.toString() ?? ApiService.nomPrenom ?? '',
                dateCreation: poly['date_collecte']?.toString() ??
                    poly['date_creation']?.toString() ??
                    '----',
                synced: poly['synced'] == 1,
                downloaded: poly['downloaded'] == 1,
                hasAnomalie: hasAnomalie,
                hasIncomplet: hasIncomplet,
                typeAnomalie: poly['type_anomalie']?.toString(),
                regionName: poly['region_name']?.toString() ?? '',
                prefectureName: poly['prefecture_name']?.toString() ?? '',
                communeName: poly['commune_name']?.toString() ?? '',
                editableItem: editableItem,
              ),
            );
            srmPolygonsByTable.putIfAbsent(tableName, () => []).add(polygon);
            if (hasAnomalie) {
              anomalieByTable.putIfAbsent(tableName, () => []).add(polygon);
            }
            if (hasIncomplet) {
              incompletByTable.putIfAbsent(tableName, () => []).add(polygon);
            }
            mapPolygons.add(polygon);
          }
        } catch (e) {
          debugPrint('[POLYGONE] Error loading SRM polygon $tableName: $e');
        }
      }
    }

    final dbHelper = DatabaseHelper();
    final cachedRegardMiroirRows = await dbHelper.getRegardMiroirCache();
    final regardMiroirRows = <Map<String, dynamic>>[
      ...cachedRegardMiroirRows,
    ];
    final cachedUuids = cachedRegardMiroirRows
        .map((row) => row['uuid']?.toString().trim())
        .whereType<String>()
        .where((uuid) => uuid.isNotEmpty)
        .toSet();

    var localGeneratedCount = 0;
    try {
      final localRegards = await dbHelper.getEntities('regard');
      for (final regard in localRegards) {
        final uuid = regard['uuid']?.toString().trim();
        if (uuid != null && uuid.isNotEmpty && cachedUuids.contains(uuid)) {
          continue;
        }

        final miroir = _buildLocalRegardMiroirRowImpl(regard);
        if (miroir == null) continue;
        regardMiroirRows.add(miroir);
        localGeneratedCount++;
      }
    } catch (e) {
      debugPrint('[REGARD-MIROIR] generation locale impossible: $e');
    }

    debugPrint(
      '[REGARD-MIROIR] ${cachedRegardMiroirRows.length} miroir(s) serveur en cache'
      ' + $localGeneratedCount miroir(s) local(aux)',
    );
    if (regardMiroirRows.isNotEmpty) {
      var renderedRegardMiroirs = 0;
      for (final poly in regardMiroirRows) {
        final points = _extractPolygonPointsImpl(poly['points_json']);
        if (points.length < 3) continue;

        final hasAnomalie = hasRowAnomalie(poly);
        final hasIncomplet = hasRowIncomplet(poly);
        final polygon = buildPolygon(
          points: points,
          baseColor: const Color(0xFF2E7D32),
          hasAnomalie: hasAnomalie,
          hasIncomplet: hasIncomplet,
          normalFillAlpha: 0.00,
          alertFillAlpha: 0.04,
          normalBorderWidth: 2.0,
          alertBorderWidth: 2.4,
          hitValue: PolygonTapData(
            nom: poly['nom']?.toString() ??
                poly['ep_num']?.toString() ??
                'Regard',
            code: poly['code']?.toString() ??
                poly['code_gps']?.toString() ??
                poly['ep_num']?.toString() ??
                poly['uuid']?.toString() ??
                '----',
            entityType: 'Regard miroir',
            metier: 'Eau Potable',
            superficie: (poly['superficie_ha'] as num?)?.toDouble() ??
                (poly['superficie_en_ha'] as num?)?.toDouble() ??
                0.0,
            nbSommets: points.length,
            enqueteur:
                poly['enqueteur']?.toString() ?? ApiService.nomPrenom ?? '',
            dateCreation: poly['date_collecte']?.toString() ??
                poly['date_creation']?.toString() ??
                '----',
            synced: true,
            downloaded: true,
            hasAnomalie: hasAnomalie,
            hasIncomplet: hasIncomplet,
            typeAnomalie: poly['type_anomalie']?.toString() ??
                poly['anomalie_regard']?.toString(),
            regionName: poly['region_name']?.toString() ?? '',
            prefectureName: poly['prefecture_name']?.toString() ?? '',
            communeName: poly['commune_name']?.toString() ?? '',
          ),
        );
        srmPolygonsByTable
            .putIfAbsent(_epRegardMiroirOverlayTable, () => [])
            .add(polygon);
        if (hasAnomalie) {
          anomalieByTable
              .putIfAbsent(_epRegardMiroirOverlayTable, () => [])
              .add(polygon);
        }
        if (hasIncomplet) {
          incompletByTable
              .putIfAbsent(_epRegardMiroirOverlayTable, () => [])
              .add(polygon);
        }
        mapPolygons.add(polygon);
        renderedRegardMiroirs++;
      }
      debugPrint(
        '[REGARD-MIROIR] $renderedRegardMiroirs miroir(s) affiche(s)',
      );
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
        state._displayedPolygonAnomalieByTable = anomalieByTable;
        state._displayedPolygonIncompletByTable = incompletByTable;
        if (previewLoaded) {
          state._pendingPolygonPreviewPoints = null;
        }
      });
      debugPrint(
          '[SRM-POLYGONES] ${mapPolygons.length} polygone(s) affiche(s)');
    }
    await state._loadPointCountsByTable();
  } catch (e) {
    debugPrint('[POLYGONE] Error loading polygons: $e');
  }
}

Map<String, dynamic>? _buildLocalRegardMiroirRowImpl(
  Map<String, dynamic> regard,
) {
  final center = _extractRegardLatLngImpl(regard);
  if (center == null) return null;

  final points = _buildSquareAroundPointImpl(
    center,
    _regardMiroirLocalSquareSizeMeters,
  );
  if (points.length < 4) return null;

  return {
    ...regard,
    'points_json': jsonEncode(
      points.map((point) => <double>[point.longitude, point.latitude]).toList(),
    ),
    'fid_regard_source': regard['fid'] ?? regard['id'],
    'downloaded': regard['downloaded'] ?? 0,
    'synced': regard['synced'] ?? 0,
  };
}

LatLng? _extractRegardLatLngImpl(Map<String, dynamic> row) {
  final x = _toDoubleImpl(row['ep_coor_x']);
  final y = _toDoubleImpl(row['ep_coor_y']);
  if (x != null && y != null) {
    final wgs84 = ProjectionService().merchichToWgs84(x: x, y: y);
    return LatLng(wgs84.latitude, wgs84.longitude);
  }

  final latitude = _toDoubleImpl(row['latitude_gps']);
  final longitude = _toDoubleImpl(row['longitude_gps']);
  if (latitude != null && longitude != null) {
    return LatLng(latitude, longitude);
  }

  return null;
}

double? _toDoubleImpl(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

List<LatLng> _buildSquareAroundPointImpl(LatLng center, double sizeMeters) {
  final halfSize = sizeMeters / 2.0;
  const metersPerLatDegree = 111320.0;
  final cosLat = math.cos(center.latitude * math.pi / 180.0).abs();
  if (cosLat < 0.000001) return const [];

  final deltaLat = halfSize / metersPerLatDegree;
  final deltaLng = halfSize / (metersPerLatDegree * cosLat);

  return [
    LatLng(center.latitude - deltaLat, center.longitude - deltaLng),
    LatLng(center.latitude - deltaLat, center.longitude + deltaLng),
    LatLng(center.latitude + deltaLat, center.longitude + deltaLng),
    LatLng(center.latitude + deltaLat, center.longitude - deltaLng),
    LatLng(center.latitude - deltaLat, center.longitude - deltaLng),
  ];
}

List<LatLng> _extractPolygonPointsImpl(dynamic rawPoints) {
  if (rawPoints == null) return [];

  try {
    final dynamic decoded =
        rawPoints is String ? jsonDecode(rawPoints) : rawPoints;
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
              ? 'Synchronisée'
              : 'Enregistrée localement',
          editableItem: _editableItemFromDynamicImpl(data['existing_item']),
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
    final Map<String, int> counts = {};
    final Map<String, int> anomalieCounts = {};
    final Map<String, int> incompletCounts = {};

    void addCounts<T>(
      Map<String, List<T>> source,
      Map<String, int> target,
    ) {
      for (final entry in source.entries) {
        target[entry.key] = (target[entry.key] ?? 0) + entry.value.length;
      }
    }

    addCounts(state._displayedPointsByTable, counts);
    addCounts(state._displayedSrmLinesByTable, counts);
    addCounts(state._displayedSrmPolygonsByTable, counts);
    addCounts(state._displayedAnomalieByTable, anomalieCounts);
    addCounts(state._displayedLineAnomalieByTable, anomalieCounts);
    addCounts(state._displayedPolygonAnomalieByTable, anomalieCounts);
    addCounts(state._displayedIncompletByTable, incompletCounts);
    addCounts(state._displayedLineIncompletByTable, incompletCounts);
    addCounts(state._displayedPolygonIncompletByTable, incompletCounts);

    if (state.mounted) {
      state._setStateFromPart(() {
        state._pointCountsByTable = counts;
        state._anomalieCountsByTable = anomalieCounts;
        state._incompletCountsByTable = incompletCounts;
      });
    }
    debugPrint(
      '[SRM-LEGENDE] compteurs carte: $counts; '
      'anomalies: $anomalieCounts; incomplets: $incompletCounts',
    );
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
