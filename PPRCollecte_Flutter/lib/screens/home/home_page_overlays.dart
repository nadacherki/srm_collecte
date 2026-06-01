part of 'home_page.dart';

const String _epRegardMiroirOverlayTable = 'ep_regard';
// Cote fixe du carre miroir affiche autour de chaque regard EP : 4 m x 4 m,
// quels que soient ep_longueur / ep_largeur en base. La donnee terrain reste
// stockee dans le regard ; ce constant ne pilote que la representation carte.
const double _regardMiroirLocalSquareSizeMeters = 4.0;
const Color _zoneOverlayColor = Color(0xFF1565C0);
const Color _plancheOverlayColor = Color(0xFF455A64);

// Rayon en mètres pour considérer plusieurs points comme superposés.
// 5m couvre les cas typiques : points exactement à la même coord ou avec
// petite variation GPS, sans inclure des objets distincts à 10m+.
const double _overlappingPointsRadiusMeters = 5.0;

// Haversine simplifié — distance en mètres entre 2 paires lat/lng (WGS84).
double _haversineMetersOverlap(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusM = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLng = (lng2 - lng1) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusM * c;
}

void _showOverlappingPointsSheet({
  required _HomePageState state,
  required List<Map<String, dynamic>> overlapping,
  required Map<String, dynamic> tappedData,
  required void Function(Map<String, dynamic>) onSelect,
}) {
  // Tri : objet réellement tappé en premier, puis distance croissante au tap.
  final tappedLat = (tappedData['lat'] as num).toDouble();
  final tappedLng = (tappedData['lng'] as num).toDouble();
  final sorted = List<Map<String, dynamic>>.from(overlapping)
    ..sort((a, b) {
      if (identical(a, tappedData)) return -1;
      if (identical(b, tappedData)) return 1;
      final da = _haversineMetersOverlap(
        (a['lat'] as num).toDouble(),
        (a['lng'] as num).toDouble(),
        tappedLat,
        tappedLng,
      );
      final db = _haversineMetersOverlap(
        (b['lat'] as num).toDouble(),
        (b['lng'] as num).toDouble(),
        tappedLat,
        tappedLng,
      );
      return da.compareTo(db);
    });

  state._suspendAutoCenterFor(const Duration(seconds: 30));

  showModalBottomSheet<void>(
    context: state.context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.layers, color: Color(0xFF1B4F72)),
                  const SizedBox(width: 8),
                  Text(
                    '${sorted.length} objets superposés ici',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Touchez celui que vous voulez ouvrir.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final data = sorted[i];
                    final type = (data['type'] ?? 'Point').toString();
                    final name = (data['name'] ?? 'Sans nom').toString();
                    final synced = data['synced'].toString() == '1';
                    final hasAnomalie = data['anomalie'] == true;
                    final hasIncomplet = data['objet_incomplet'] == true;
                    final dist = _haversineMetersOverlap(
                      (data['lat'] as num).toDouble(),
                      (data['lng'] as num).toDouble(),
                      tappedLat,
                      tappedLng,
                    );
                    final tableName = (data['table_name'] ?? '').toString();
                    final iconWidget = hasAnomalie
                        ? CustomMarkerIcons.getAnomalieMarkerWidget(
                            tableName,
                            size: 32,
                          )
                        : hasIncomplet
                            ? CustomMarkerIcons.getIncompletMarkerWidget(
                                tableName,
                                size: 32,
                              )
                            : CustomMarkerIcons.getMarkerWidget(
                                tableName,
                                size: 32,
                              );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(child: iconWidget),
                      ),
                      title: Text(
                        type,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '$name${dist > 0.5 ? '  •  ${dist.toStringAsFixed(1)} m' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (hasAnomalie)
                            const Icon(Icons.warning_amber,
                                color: Colors.red, size: 18),
                          if (hasIncomplet)
                            const Icon(Icons.report_problem,
                                color: Colors.orange, size: 18),
                          Icon(
                            synced ? Icons.cloud_done : Icons.phone_android,
                            color: synced ? Colors.green : Colors.blueGrey,
                            size: 18,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onSelect(data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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

Future<void> _loadReferenceOverlaysImpl(_HomePageState state) async {
  try {
    final db = DatabaseHelper();
    final zones = await db.getZonesLocal(activeOnly: true);
    final planches = await db.getPlancheOverlayLocal();

    final zonePolygons = <Polygon>[];
    for (final zone in zones) {
      for (final points in _polygonRingsFromGeoJsonImpl(
        zone['geometry_geojson'],
      )) {
        if (points.length < 3) continue;
        zonePolygons.add(
          Polygon(
            points: points,
            color: _zoneOverlayColor.withValues(alpha: 0.05),
            borderColor: _zoneOverlayColor.withValues(alpha: 0.82),
            borderStrokeWidth: 1.4,
            hitValue: PolygonTapData(
              nom: _displayValueImpl(zone['nom_zone'], fallback: 'Zone'),
              code: _displayValueImpl(zone['id_zone'], fallback: '----'),
              entityType: 'Zone',
              metier: 'Contexte',
              superficie: 0.0,
              nbSommets: points.length,
              enqueteur: '',
              dateCreation: '',
              synced: true,
              downloaded: true,
              statusOverride: 'Couche contexte offline',
              extraDetails: _compactDetailsImpl({
                'Nom': zone['nom_zone'],
                'État': zone['etat'],
              }),
            ),
          ),
        );
      }
    }

    final planchePolygons = <Polygon>[];
    for (final planche in planches) {
      for (final points in _polygonRingsFromGeoJsonImpl(
        planche['geometry_geojson'],
      )) {
        if (points.length < 3) continue;
        planchePolygons.add(
          Polygon(
            points: points,
            color: _plancheOverlayColor.withValues(alpha: 0.015),
            borderColor: _plancheOverlayColor.withValues(alpha: 0.44),
            borderStrokeWidth: 0.7,
            hitValue: PolygonTapData(
              nom:
                  'Planche ${_displayValueImpl(planche['numero'], fallback: '')}'
                      .trim(),
              code: _displayValueImpl(planche['id'], fallback: '----'),
              entityType: 'Planche',
              metier: 'Contexte',
              superficie: 0.0,
              nbSommets: points.length,
              enqueteur: '',
              dateCreation: '',
              synced: true,
              downloaded: true,
              statusOverride: 'Couche contexte offline',
              extraDetails: _compactDetailsImpl({
                'Numéro': planche['numero'],
              }),
            ),
          ),
        );
      }
    }

    if (!state.mounted) return;
    state._setStateFromPart(() {
      state._referenceZonePolygons = zonePolygons;
      state._referencePlanchePolygons = planchePolygons;
      state._referenceOverlayCounts = {
        'overlay_zones': zonePolygons.length,
        'overlay_planche': planchePolygons.length,
      };
    });
  } catch (e) {
    debugPrint('[REFERENCE-OVERLAYS] chargement local ignore: $e');
  }
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

Future<void> _loadDisplayedSrmLinesImpl(_HomePageState state) async {
  try {
    final srmLinesByTable = <String, List<Polyline>>{};
    final anomalieByTable = <String, List<Polyline>>{};
    final incompletByTable = <String, List<Polyline>>{};
    final lines = await state._srmLinesService.getDisplayedSrmLines(
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

        state._showSrmLineDetailsSheet(
          context: state.context,
          entityType: (data['entity_title'] ?? '----').toString(),
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
      state._displayedSrmLinesByTable = srmLinesByTable;
      state._displayedLineAnomalieByTable = anomalieByTable;
      state._displayedLineIncompletByTable = incompletByTable;
    });
    await state._loadPointCountsByTable();

    debugPrint('[SRM-LINES] ${lines.length} ligne(s) SRM affichee(s)');
  } catch (e) {
    debugPrint('[SRM-LINES] erreur chargement lignes SRM: $e');
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

    final Map<String, List<Polygon>> srmPolygonsByTable = {};
    final formulaireConfigService = FormulaireConfigMobileService();

    for (final metier in SrmConfig.getMetiers()) {
      final metierCode =
          SrmConfig.getMetierConfig(metier)?['schema']?.toString();
      final titleByTable = await formulaireConfigService.getTitleByMobileTable(
        mobileMetier: metier,
        refreshIfEmpty: false,
      );
      for (final entity in SrmConfig.getPolygonEntities(metier)) {
        final tableName = SrmConfig.getTableName(metier, entity);
        if (tableName == null || tableName.isEmpty) continue;
        final entityTitle = titleByTable[tableName] ?? entity;

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
          final incompletIndex =
              await DatabaseHelper().getOpenObjetIncompletIndexForTable(
            tableName: tableName,
            metierCode: metierCode,
          );

          for (final rawPoly in rows) {
            final poly = _mergeOpenIncompletStatusImpl(
              rawPoly,
              incompletIndex: incompletIndex,
            );
            final points = _extractPolygonPointsImpl(poly['points_json']);
            if (points.length < 3) continue;
            final hasAnomalie = hasRowAnomalie(poly);
            final hasIncomplet = hasRowIncomplet(poly);
            final editableItem = Map<String, dynamic>.from(poly);
            editableItem['source_table'] = tableName;
            editableItem['source_metier'] = metier;
            editableItem['source_entity'] = entity;
            editableItem['source_title'] = entityTitle;
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
                entityType: entityTitle,
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
    final regardMiroirByUuid = <String, Map<String, dynamic>>{};
    final regardMiroirWithoutUuid = <Map<String, dynamic>>[];
    for (final rawRow in cachedRegardMiroirRows) {
      final row = Map<String, dynamic>.from(rawRow);
      final uuid = row['uuid']?.toString().trim() ?? '';
      if (uuid.isEmpty) {
        regardMiroirWithoutUuid.add(row);
      } else {
        regardMiroirByUuid[uuid.toLowerCase()] = row;
      }
    }

    var localGeneratedCount = 0;
    try {
      final localRegards = await dbHelper.getEntitiesSrm('ep_regard_point');
      final incompletIndex = await dbHelper.getOpenObjetIncompletIndexForTable(
        tableName: 'ep_regard_point',
        metierCode: 'ep',
      );
      for (final rawRegard in localRegards) {
        final regard = _mergeOpenIncompletStatusImpl(
          rawRegard,
          incompletIndex: incompletIndex,
        );
        final uuid = regard['uuid']?.toString().trim() ?? '';

        final miroir = _buildLocalRegardMiroirRowImpl(regard);
        if (miroir == null) continue;
        if (uuid.isEmpty) {
          regardMiroirWithoutUuid.add(miroir);
        } else {
          regardMiroirByUuid[uuid.toLowerCase()] = miroir;
        }
        localGeneratedCount++;
      }
    } catch (e) {
      debugPrint('[REGARD-MIROIR] generation locale impossible: $e');
    }

    final regardMiroirRows = <Map<String, dynamic>>[
      ...regardMiroirByUuid.values,
      ...regardMiroirWithoutUuid,
    ];

    debugPrint(
      '[REGARD-MIROIR] ${cachedRegardMiroirRows.length} miroir(s) serveur en cache'
      ' + $localGeneratedCount miroir(s) local(aux)',
    );
    if (regardMiroirRows.isNotEmpty) {
      var renderedRegardMiroirs = 0;
      for (final poly in regardMiroirRows) {
        final rawPoints = _extractPolygonPointsImpl(poly['points_json']);
        if (rawPoints.length < 3) continue;
        // Surcharge taille : on rebatit toujours un carre fixe 4 m x 4 m
        // centre sur le centroide du polygone d'origine, quelle que soit
        // la longueur/largeur enregistree cote regard ou cote miroir
        // serveur. Cf. _regardMiroirLocalSquareSizeMeters.
        final points =
            _buildRectangleAroundPointImpl(_polygonCentroidImpl(rawPoints));
        if (points.length < 4) continue;

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

  // Taille fixe 4 m x 4 m : on ignore volontairement longueur/largeur du
  // regard ; cf. _regardMiroirLocalSquareSizeMeters.
  final points = _buildRectangleAroundPointImpl(center);
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

Map<String, dynamic> _mergeOpenIncompletStatusImpl(
  Map<String, dynamic> rawRow, {
  required Map<String, Map<String, dynamic>> incompletIndex,
}) {
  final row = Map<String, dynamic>.from(rawRow);
  final id = _toIntImpl(row['id']) ??
      _toIntImpl(row['fid']) ??
      _toIntImpl(row['id_objet']);
  final uuid = row['uuid']?.toString().trim() ??
      row['uuid_objet']?.toString().trim() ??
      '';

  Map<String, dynamic>? support;
  if (uuid.isNotEmpty) {
    support = incompletIndex['uuid:${uuid.toLowerCase()}'];
  }
  support ??= id == null ? null : incompletIndex['id:$id'];
  if (support == null) {
    return row;
  }

  row['objet_incomplet'] = 1;
  final detail = support['detail_raison']?.toString().trim() ?? '';
  if (detail.isNotEmpty &&
      (row['raison_incomplet']?.toString().trim().isEmpty ?? true)) {
    row['raison_incomplet'] = detail;
  }
  final dateSignalement = support['date_signalement']?.toString().trim() ?? '';
  if (dateSignalement.isNotEmpty &&
      (row['date_incomplet']?.toString().trim().isEmpty ?? true)) {
    row['date_incomplet'] = dateSignalement;
  }
  return row;
}

LatLng? _extractRegardLatLngImpl(Map<String, dynamic> row) {
  final x = _toDoubleImpl(row['ep_coor_x']);
  final y = _toDoubleImpl(row['ep_coor_y']);
  if (x != null && y != null) {
    return LatLng(y, x);
  }

  final latitude = _toDoubleImpl(row['latitude_gps']);
  final longitude = _toDoubleImpl(row['longitude_gps']);
  if (latitude != null && longitude != null) {
    final m = ProjectionService().wgs84ToMerchich(
      latitude: latitude,
      longitude: longitude,
    );
    return LatLng(m.y, m.x);
  }

  return null;
}

int? _toIntImpl(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}

double? _toDoubleImpl(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _displayValueImpl(dynamic value, {String fallback = '----'}) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
  return text;
}

Map<String, String> _compactDetailsImpl(Map<String, dynamic> rawDetails) {
  final details = <String, String>{};
  for (final entry in rawDetails.entries) {
    final value = _displayValueImpl(entry.value, fallback: '');
    if (value.isEmpty) continue;
    details[entry.key] = value;
  }
  return details;
}

LatLng _polygonCentroidImpl(List<LatLng> points) {
  // Moyenne arithmetique des sommets : suffisant pour un petit polygone
  // ferme issu d'un rectangle (les coordonnees servent ensuite a recentrer
  // un carre 4 m x 4 m, donc une approximation au degre pres est inutile).
  var sumLat = 0.0;
  var sumLng = 0.0;
  for (final pt in points) {
    sumLat += pt.latitude;
    sumLng += pt.longitude;
  }
  final n = points.length.toDouble();
  return LatLng(sumLat / n, sumLng / n);
}

List<LatLng> _buildRectangleAroundPointImpl(LatLng center) {
  // Carre fixe 4 m x 4 m centre sur le regard.
  //
  // Note CRS : on tourne en MerchichCrs ou LatLng.latitude = Y_Merchich (m)
  // et LatLng.longitude = X_Merchich (m) directement, identite pure (cf.
  // [MerchichCrs.projection]). Donc 1 unite = 1 metre et il suffit
  // d'appliquer +/- demi-cote. L'ancienne version utilisait des formules
  // WGS84 (metersPerLatDegree, cos(lat)) qui rendaient le polygone
  // sub-micrometre, invisible a la carte.
  const halfMeters = _regardMiroirLocalSquareSizeMeters / 2.0;

  return [
    LatLng(center.latitude - halfMeters, center.longitude - halfMeters),
    LatLng(center.latitude - halfMeters, center.longitude + halfMeters),
    LatLng(center.latitude + halfMeters, center.longitude + halfMeters),
    LatLng(center.latitude + halfMeters, center.longitude - halfMeters),
    LatLng(center.latitude - halfMeters, center.longitude - halfMeters),
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

List<List<LatLng>> _polygonRingsFromGeoJsonImpl(dynamic rawGeometry) {
  final geometry = _decodeGeoJsonGeometryImpl(rawGeometry);
  if (geometry is! Map) return const [];

  final type = geometry['type']?.toString();
  final coordinates = geometry['coordinates'];
  if (type == 'Polygon' && coordinates is List) {
    final ring = coordinates.isNotEmpty ? coordinates.first : null;
    final points = _positionsToLatLngImpl(ring);
    return points.length >= 3 ? [points] : const [];
  }
  if (type == 'MultiPolygon' && coordinates is List) {
    final rings = <List<LatLng>>[];
    for (final polygon in coordinates) {
      if (polygon is! List || polygon.isEmpty) continue;
      final points = _positionsToLatLngImpl(polygon.first);
      if (points.length >= 3) rings.add(points);
    }
    return rings;
  }
  if (type == 'GeometryCollection' && geometry['geometries'] is List) {
    return (geometry['geometries'] as List)
        .expand(_polygonRingsFromGeoJsonImpl)
        .toList();
  }
  return const [];
}

dynamic _decodeGeoJsonGeometryImpl(dynamic rawGeometry) {
  if (rawGeometry == null) return null;
  if (rawGeometry is Map) return rawGeometry;
  if (rawGeometry is String) {
    final trimmed = rawGeometry.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }
  return null;
}

List<LatLng> _positionsToLatLngImpl(dynamic rawPositions) {
  if (rawPositions is! List) return const [];
  final points = <LatLng>[];
  for (final item in rawPositions) {
    final point = _latLngFromGeoJsonPositionImpl(item);
    if (point != null) points.add(point);
  }
  if (points.length >= 2 && _samePointImpl(points.first, points.last)) {
    return points.sublist(0, points.length - 1);
  }
  return points;
}

LatLng? _latLngFromGeoJsonPositionImpl(dynamic rawPosition) {
  if (rawPosition is! List || rawPosition.length < 2) return null;
  final x = _toDoubleImpl(rawPosition[0]);
  final y = _toDoubleImpl(rawPosition[1]);
  if (x == null || y == null) return null;

  if (x.abs() <= 180 && y.abs() <= 90) {
    final m = ProjectionService().wgs84ToMerchich(latitude: y, longitude: x);
    return LatLng(m.y, m.x);
  }

  return LatLng(y, x);
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
    final List<Map<String, dynamic>> registry = [];

    void openSinglePoint(Map<String, dynamic> data) {
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
    }

    final markers = await state._pointsService.getDisplayedPointsMarkers(
      onMarkerData: (data) => registry.add(data),
      onTapDetails: (data) {
        final tappedLat = (data['lat'] as num).toDouble();
        final tappedLng = (data['lng'] as num).toDouble();
        final overlapping = registry.where((m) {
          final mLat = (m['lat'] as num?)?.toDouble();
          final mLng = (m['lng'] as num?)?.toDouble();
          if (mLat == null || mLng == null) return false;
          return _haversineMetersOverlap(
                mLat,
                mLng,
                tappedLat,
                tappedLng,
              ) <=
              _overlappingPointsRadiusMeters;
        }).toList();

        if (overlapping.length <= 1) {
          openSinglePoint(data);
        } else {
          _showOverlappingPointsSheet(
            state: state,
            overlapping: overlapping,
            tappedData: data,
            onSelect: openSinglePoint,
          );
        }
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
        if (entry.key == _epRegardMiroirOverlayTable) {
          continue;
        }
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
