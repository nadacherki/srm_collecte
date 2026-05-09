part of 'home_page.dart';

void _showSrmLineDetailsSheetImpl(
  _HomePageState state, {
  required BuildContext context,
  required String entityType,
  required String statut,
  String? enqueteur,
  required String region,
  required String prefecture,
  required String commune,
  required double distanceKm,
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
  Map<String, dynamic>? editableItem,
}) {
  String safe(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return '----';
    return text;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              safe(entityType),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            state._detailRow('Statut', safe(statut)),
            state._detailRow(
              'Enquêteur',
              state.enqueteurDisplayByStatut(
                enqueteurValue: enqueteur,
                statut: statut,
              ),
            ),
            if (!statut.toLowerCase().contains('localement')) ...[
              state._detailRow('Région', safe(region)),
              state._detailRow('Préfecture', safe(prefecture)),
              state._detailRow('Commune', safe(commune)),
            ],
            state._detailRow(
              'Début',
              'X=${startLng.toStringAsFixed(6)} / Y=${startLat.toStringAsFixed(6)}',
            ),
            state._detailRow(
              'Fin',
              'X=${endLng.toStringAsFixed(6)} / Y=${endLat.toStringAsFixed(6)}',
            ),
            state._detailRow('Distance', '${distanceKm.toStringAsFixed(2)} km'),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                children: [
                  if (editableItem != null &&
                      FormLockService.isEditable(editableItem))
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await state._editMapItem(editableItem);
                      },
                      child: const Text('Éditer'),
                    ),
                  if (_supportsGeometryEditImpl(editableItem))
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await state._editMapGeometry(editableItem!);
                      },
                      child: const Text('Éditer géométrie'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _showLineDetailsSheetImpl(
  _HomePageState state, {
  required BuildContext context,
  required String lineCode,
  String? enqueteur,
  required String region,
  required String prefecture,
  required String commune,
  required String statut,
  required int nbPoints,
  required double startLat,
  required double startLng,
  required double endLat,
  required double endLng,
  required double distanceKm,
  String? plateforme,
  String? relief,
  String? vegetation,
  String? debutTravaux,
  String? finTravaux,
  String? financement,
  String? entreprise,
  Map<String, dynamic>? editableItem,
}) {
  String safe(String? value) =>
      (value ?? '').trim().isEmpty ? '----' : value!.trim();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.45,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ligne - ${safe(lineCode)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      state._detailRow('Statut', safe(statut)),
                      state._detailRow(
                        'Enquêteur',
                        state.enqueteurDisplayByStatut(
                          enqueteurValue: enqueteur,
                          statut: statut,
                        ),
                      ),
                      if (!statut.toLowerCase().contains('localement')) ...[
                        state._detailRow('Région', safe(region)),
                        state._detailRow('Préfecture', safe(prefecture)),
                        state._detailRow('Commune', safe(commune)),
                      ],
                      state._detailRow('Nb points', nbPoints.toString()),
                      state._detailRow(
                        'Début',
                        'X=${startLng.toStringAsFixed(6)} / Y=${startLat.toStringAsFixed(6)}',
                      ),
                      state._detailRow(
                        'Fin',
                        'X=${endLng.toStringAsFixed(6)} / Y=${endLat.toStringAsFixed(6)}',
                      ),
                      state._detailRow(
                          'Distance', '${distanceKm.toStringAsFixed(2)} km'),
                      const Divider(),
                      state._detailRow('Plateforme', safe(plateforme)),
                      state._detailRow('Relief', safe(relief)),
                      state._detailRow('Végétation', safe(vegetation)),
                      state._detailRow('Début travaux', safe(debutTravaux)),
                      state._detailRow('Fin travaux', safe(finTravaux)),
                      state._detailRow('Financement', safe(financement)),
                      state._detailRow('Entreprise', safe(entreprise)),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  children: [
                    if (editableItem != null &&
                        FormLockService.isEditable(editableItem))
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await state._editMapItem(editableItem);
                        },
                        child: const Text('Éditer'),
                      ),
                    if (_supportsGeometryEditImpl(editableItem))
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await state._editMapGeometry(editableItem!);
                        },
                        child: const Text('Éditer géométrie'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showPointDetailsSheetImpl(
  _HomePageState state, {
  required BuildContext context,
  required String type,
  required String name,
  required String region,
  required String prefecture,
  required String commune,
  required String enqueteur,
  required String lineCode,
  required double lat,
  required double lng,
  required String statut,
  Map<String, dynamic>? editableItem,
}) {
  String safe(String value) => value.trim().isEmpty ? '----' : value.trim();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$type - ${safe(name)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            state._detailRow('Statut', safe(statut)),
            if (!statut.toLowerCase().contains('localement')) ...[
              state._detailRow('Région', safe(region)),
              state._detailRow('Préfecture', safe(prefecture)),
              state._detailRow('Commune', safe(commune)),
            ],
            state._detailRow(
              'Enquêteur',
              state.enqueteurDisplayByStatut(
                enqueteurValue: enqueteur,
                statut: statut,
              ),
            ),
            state._detailRow('Code ligne', safe(lineCode)),
            state._detailRow(
              'Coordonnées',
              'X=${lng.toStringAsFixed(6)} / Y=${lat.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                children: [
                  if (editableItem != null &&
                      FormLockService.isEditable(editableItem))
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await state._editMapItem(editableItem);
                      },
                      child: const Text('Éditer'),
                    ),
                  if (_supportsGeometryEditImpl(editableItem))
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await state._editMapGeometry(editableItem!);
                      },
                      child: const Text('Éditer géométrie'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

void _handlePolylineTapImpl(_HomePageState state, Object? hitValue) {
  if (hitValue == null || hitValue is! PolylineTapData) return;

  final tapData = hitValue;
  final type = tapData.type;
  final data = tapData.data;
  final editableItem = _editableItemFromDynamicImpl(data['existing_item']);

  debugPrint('[Polyline] tapped: type=$type');

  switch (type) {
    case 'line_local':
    case 'line_downloaded':
      state._showLineDetailsSheet(
        context: state.context,
        lineCode: (data['line_code'] ?? '----').toString(),
        statut: type == 'line_local'
            ? ((data['synced'].toString() == '1')
                ? 'Synchronisée'
                : 'Enregistrée localement')
            : 'Sauvegardée (téléchargée)',
        region: type == 'line_downloaded'
            ? (data['region_name'] ?? '----').toString()
            : (data['region_name'] ?? '').toString().isNotEmpty
                ? (data['region_name']).toString()
                : state._regionNom,
        prefecture: type == 'line_downloaded'
            ? (data['prefecture_name'] ?? '----').toString()
            : (data['prefecture_name'] ?? '').toString().isNotEmpty
                ? (data['prefecture_name']).toString()
                : state._prefectureNom,
        commune: type == 'line_downloaded'
            ? (data['commune_name'] ?? '----').toString()
            : (data['commune_name'] ?? '').toString().isNotEmpty
                ? (data['commune_name']).toString()
                : state._communeNom,
        enqueteur: (data['enqueteur'] ?? '').toString(),
        nbPoints: (data['nb_points'] as int?) ?? 0,
        distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
        startLat: (data['start_lat'] as num).toDouble(),
        startLng: (data['start_lng'] as num).toDouble(),
        endLat: (data['end_lat'] as num).toDouble(),
        endLng: (data['end_lng'] as num).toDouble(),
        plateforme: (data['platform'] ?? '----').toString(),
        relief: (data['relief'] ?? '----').toString(),
        vegetation: (data['vegetation'] ?? '----').toString(),
        debutTravaux: (data['work_start'] ?? '----').toString(),
        finTravaux: (data['work_end'] ?? '----').toString(),
        financement: (data['funding'] ?? '----').toString(),
        entreprise: (data['company'] ?? '----').toString(),
        editableItem: editableItem,
      );
      break;

    case 'srm_line_local':
    case 'srm_line_downloaded':
      state._showSrmLineDetailsSheet(
        context: state.context,
        entityType: (data['entity_title'] ?? '----').toString(),
        statut: type == 'srm_line_local'
            ? ((data['synced'].toString() == '1')
                ? 'Synchronisée'
                : 'Enregistrée localement')
            : 'Sauvegardée (téléchargée)',
        region: type == 'srm_line_downloaded'
            ? (data['region_name'] ?? '----').toString()
            : (data['region_name'] ?? '').toString().isNotEmpty
                ? (data['region_name']).toString()
                : state._regionNom,
        prefecture: type == 'srm_line_downloaded'
            ? (data['prefecture_name'] ?? '----').toString()
            : (data['prefecture_name'] ?? '').toString().isNotEmpty
                ? (data['prefecture_name']).toString()
                : state._prefectureNom,
        commune: type == 'srm_line_downloaded'
            ? (data['commune_name'] ?? '----').toString()
            : (data['commune_name'] ?? '').toString().isNotEmpty
                ? (data['commune_name']).toString()
                : state._communeNom,
        enqueteur: (data['enqueteur'] ?? '').toString(),
        distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0.0,
        startLat: (data['start_lat'] as num).toDouble(),
        startLng: (data['start_lng'] as num).toDouble(),
        endLat: (data['end_lat'] as num).toDouble(),
        endLng: (data['end_lng'] as num).toDouble(),
        editableItem: editableItem,
      );
      break;
  }
}

void _handlePolygonTapImpl(_HomePageState state, Object? hitValue) {
  if (hitValue == null || hitValue is! PolygonTapData) return;
  final data = hitValue;
  final titlePrefix =
      data.entityType.trim().isEmpty ? 'Polygone' : data.entityType.trim();

  showModalBottomSheet(
    context: state.context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$titlePrefix - ${data.nom}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            state._detailRow('Statut', data.statut),
            if (data.metier.trim().isNotEmpty)
              state._detailRow('Métier', data.metier),
            state._detailRow('Code', data.code),
            if (data.downloaded || data.synced) ...[
              state._detailRow(
                  'Région', data.regionName.isEmpty ? '----' : data.regionName),
              state._detailRow('Préfecture',
                  data.prefectureName.isEmpty ? '----' : data.prefectureName),
              state._detailRow('Commune',
                  data.communeName.isEmpty ? '----' : data.communeName),
            ],
            if (data.hasAnomalie)
              state._detailRow(
                'Anomalie',
                data.typeAnomalie?.trim().isNotEmpty == true
                    ? data.typeAnomalie!
                    : 'Oui',
              ),
            if (data.hasIncomplet) state._detailRow('Objet incomplet', 'Oui'),
            state._detailRow(
                'Superficie', '${data.superficie.toStringAsFixed(4)} ha'),
            state._detailRow('Sommets', '${data.nbSommets} points'),
            state._detailRow(
              'Enquêteur',
              state.enqueteurDisplayByStatut(
                enqueteurValue: data.enqueteur,
                statut: data.statut,
              ),
            ),
            state._detailRow(
              'Date création',
              data.dateCreation.length > 10
                  ? data.dateCreation.substring(0, 10)
                  : data.dateCreation,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.editableItem != null &&
                      FormLockService.isEditable(data.editableItem!))
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await state._editMapItem(data.editableItem!);
                      },
                      child: const Text('Éditer'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Map<String, dynamic>? _editableItemFromDynamicImpl(dynamic raw) {
  if (raw == null) return null;
  if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

bool _supportsGeometryEditImpl(Map<String, dynamic>? item) {
  if (item == null || !FormLockService.isEditable(item)) {
    return false;
  }
  final geoType = item['geometry_type']?.toString() ?? 'Point';
  return geoType == 'Point' || geoType == 'LineString';
}

List<LatLng> _decodeGeometryPointsFromLooseStringImpl(String raw) {
  final matches = RegExp(
    r'lat:\s*([-0-9.]+),\s*lon:\s*([-0-9.]+)',
  ).allMatches(raw);
  return matches
      .map((match) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lon = double.tryParse(match.group(2) ?? '');
        if (lat == null || lon == null) return null;
        return LatLng(lat, lon);
      })
      .whereType<LatLng>()
      .toList();
}

List<LatLng> _decodeGeometryPointsImpl(dynamic rawPoints) {
  if (rawPoints == null) return const [];

  try {
    final decoded = rawPoints is String ? jsonDecode(rawPoints) : rawPoints;
    if (decoded is! List) {
      if (rawPoints is String) {
        return _decodeGeometryPointsFromLooseStringImpl(rawPoints);
      }
      return const [];
    }

    final points = <LatLng>[];
    for (final coord in decoded) {
      if (coord is Map) {
        final lat = coord['lat'] ?? coord['latitude'];
        final lng = coord['lon'] ?? coord['lng'] ?? coord['longitude'];
        if (lat is num && lng is num) {
          points.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      } else if (coord is List && coord.length >= 2) {
        final lng = coord[0];
        final lat = coord[1];
        if (lat is num && lng is num) {
          points.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
    }
    return points;
  } catch (_) {
    if (rawPoints is String) {
      return _decodeGeometryPointsFromLooseStringImpl(rawPoints);
    }
    return const [];
  }
}

Future<void> _editMapItemImpl(
  _HomePageState state,
  Map<String, dynamic> item,
) async {
  if (!FormLockService.isEditable(item)) {
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context).showSnackBar(
      SnackBar(
        content: Text(FormLockService.lockReason(item)),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final metier = item['source_metier']?.toString();
  final entityType = item['source_entity']?.toString();
  final geoType = item['geometry_type']?.toString() ?? 'Point';
  if (metier == null || entityType == null) return;

  if (geoType == 'LineString') {
    final points = _decodeGeometryPointsImpl(item['points_json']);
    if (points.length < 2) return;

    await Navigator.push(
      state.context,
      MaterialPageRoute(
        builder: (_) => SrmLigneFormPage(
          metier: metier,
          entityType: entityType,
          displayTitle: item['source_title']?.toString(),
          linePoints: points,
          agentName: state.widget.agentName,
          existingData: item,
        ),
      ),
    );
  } else if (geoType == 'Polygon') {
    final points = _decodeGeometryPointsImpl(item['points_json']);
    if (points.length > 1 &&
        points.first.latitude == points.last.latitude &&
        points.first.longitude == points.last.longitude) {
      points.removeLast();
    }
    if (points.length < 3) {
      if (!state.mounted) return;
      ScaffoldMessenger.of(state.context).showSnackBar(
        const SnackBar(
          content: Text('Polygone invalide'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Navigator.push(
      state.context,
      MaterialPageRoute(
        builder: (_) => PolygonFormPage(
          polygonPoints: points,
          startTime: item['date_collecte'] != null
              ? DateTime.tryParse(item['date_collecte'].toString()) ??
                  DateTime.now()
              : DateTime.now(),
          endTime: DateTime.now(),
          agentName: state.widget.agentName,
          existingData: item,
          metier: metier,
          entityType: entityType,
          displayTitle: item['source_title']?.toString(),
        ),
      ),
    );
  } else {
    final latLng = _resolveEditablePointLatLngImpl(
      item: item,
      metier: metier,
      entityType: entityType,
    );

    await Navigator.push(
      state.context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SrmPointFormWidget(
            metier: metier,
            entityType: entityType,
            displayTitle: item['source_title']?.toString(),
            latitude: latLng?.latitude ?? 0.0,
            longitude: latLng?.longitude ?? 0.0,
            altitude: (item['altitude_gps'] as num?)?.toDouble(),
            agentName: state.widget.agentName,
            existingData: item,
            onSaved: () {
              Navigator.pop(state.context);
            },
            onCancel: () => Navigator.pop(state.context),
          ),
        ),
      ),
    );
  }

  if (state.mounted) {
    await state._refreshAfterNavigation();
  }
}

Future<void> _editMapGeometryImpl(
  _HomePageState state,
  Map<String, dynamic> item,
) async {
  if (!FormLockService.isEditable(item)) {
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context).showSnackBar(
      SnackBar(
        content: Text(FormLockService.lockReason(item)),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final geoType = item['geometry_type']?.toString() ?? 'Point';
  if (geoType == 'Point') {
    await _movePointGeometryToCurrentGpsImpl(state, item);
    return;
  }
  if (geoType == 'LineString') {
    await _startLineGeometryEditImpl(state, item);
    return;
  }

  if (!state.mounted) return;
  ScaffoldMessenger.of(state.context).showSnackBar(
    const SnackBar(
      content:
          Text('Édition géométrique disponible pour les points et lignes.'),
      backgroundColor: Colors.orange,
    ),
  );
}

Future<void> _movePointGeometryToCurrentGpsImpl(
  _HomePageState state,
  Map<String, dynamic> item,
) async {
  final metier = item['source_metier']?.toString();
  final entityType = item['source_entity']?.toString();
  final tableName = item['source_table']?.toString();
  final id = _dynamicToIntImpl(item['id']);
  if (metier == null || entityType == null || tableName == null || id == null) {
    return;
  }

  final target = state.userPosition ?? state.homeController.userPosition;
  final confirm = await showDialog<bool>(
    context: state.context,
    builder: (ctx) => AlertDialog(
      title: const Text('Déplacer le point'),
      content: Text(
        'La géométrie sera remplacée par la position GPS actuelle :\n'
        'Lat ${target.latitude.toStringAsFixed(7)} / '
        'Lon ${target.longitude.toStringAsFixed(7)}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Appliquer'),
        ),
      ],
    ),
  );
  if (confirm != true) return;

  try {
    final projected = ProjectionService().wgs84ToMerchich(
      longitude: target.longitude,
      latitude: target.latitude,
    );
    final fields = SrmConfig.getFields(metier, entityType);
    final xField = fields.firstWhere(
      (field) => field.toLowerCase().endsWith('_coor_x'),
      orElse: () => '',
    );
    final yField = fields.firstWhere(
      (field) => field.toLowerCase().endsWith('_coor_y'),
      orElse: () => '',
    );
    final zField = fields.firstWhere(
      (field) => field.toLowerCase().endsWith('_coor_z'),
      orElse: () => '',
    );

    final altitude = state.homeController.currentAltitude;
    final data = <String, dynamic>{
      'latitude_gps': target.latitude,
      'longitude_gps': target.longitude,
      'synced': 0,
      'date_collecte': DateTime.now().toIso8601String(),
      'mode_localisation': 'gnss',
    };
    if (altitude != null) {
      data['altitude_gps'] = altitude;
    }
    if (xField.isNotEmpty) {
      data[xField] = projected.x;
    }
    if (yField.isNotEmpty) {
      data[yField] = projected.y;
    }
    if (zField.isNotEmpty && altitude != null) {
      data[zField] = altitude;
    }

    await DatabaseHelper().updateEntitySrm(
      tableName,
      id,
      data,
      recordHistory: true,
    );

    if (!state.mounted) return;
    await state._refreshAfterNavigation();
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(
        content: Text('Géométrie du point mise à jour.'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context).showSnackBar(
      SnackBar(
        content: Text('Erreur édition géométrie : $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

Future<void> _startLineGeometryEditImpl(
  _HomePageState state,
  Map<String, dynamic> item,
) async {
  if (state.homeController.hasActiveCollection ||
      state.homeController.hasPausedCollection) {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(
        content: Text(
            'Terminez ou annulez le tracé en cours avant de modifier cette ligne.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  final metier = item['source_metier']?.toString();
  final entityType = item['source_entity']?.toString();
  final tableName = item['source_table']?.toString();
  final id = _dynamicToIntImpl(item['id']);
  if (metier == null || entityType == null || tableName == null || id == null) {
    return;
  }

  final points = _decodeGeometryPointsImpl(item['points_json']);
  if (points.length < 2) {
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(
        content: Text('Géométrie de ligne invalide.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  state._geometryEditLineItem = Map<String, dynamic>.from(item)
    ..['source_metier'] = metier
    ..['source_entity'] = entityType
    ..['source_title'] = item['source_title']
    ..['source_table'] = tableName;
  state._pendingSrmLigneSelection = null;
  state._ligneRedoPoints.clear();

  final lineCode =
      (item['line_code'] ?? item['code'] ?? item['uuid'] ?? 'geometry_edit_$id')
          .toString();
  await state.homeController.restoreFinishedLigneAsPaused(
    id: id,
    lineCode: lineCode,
    points: points,
    startTime: DateTime.tryParse(item['date_collecte']?.toString() ?? '') ??
        DateTime.now(),
    lastPointTime: DateTime.now(),
    totalDistance: _polylineDistanceKmImpl(points) * 1000,
    srmMetadata: {
      'srmMetier': metier,
      'srmEntityType': entityType,
      'srmTitleApp': item['source_title'],
      'srmTableName': tableName,
      'geometryEdit': true,
    },
  );
  state.homeController.toggleLigneCollection();

  if (!state.mounted) return;
  state._setStateFromPart(() {});
  ScaffoldMessenger.of(state.context).showSnackBar(
    const SnackBar(
      content: Text(
        'Mode édition géométrie activé. Ajustez la ligne puis validez.',
      ),
      backgroundColor: Color(0xFF1976D2),
      duration: Duration(seconds: 3),
    ),
  );
}

LatLng? _resolveEditablePointLatLngImpl({
  required Map<String, dynamic> item,
  required String metier,
  required String entityType,
}) {
  final latitude = (item['latitude_gps'] as num?)?.toDouble();
  final longitude = (item['longitude_gps'] as num?)?.toDouble();
  if (latitude != null && longitude != null) {
    return LatLng(latitude, longitude);
  }

  final schema = SrmConfig.getSchema(metier, entityType);
  if (schema == null || schema.isEmpty) {
    return null;
  }

  final x = _dynamicToDoubleImpl(item['${schema}_coor_x']);
  final y = _dynamicToDoubleImpl(item['${schema}_coor_y']);
  if (x == null || y == null) {
    return null;
  }

  final projected = ProjectionService().merchichToWgs84(x: x, y: y);
  return LatLng(projected.latitude, projected.longitude);
}

int? _dynamicToIntImpl(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim());
}

double? _dynamicToDoubleImpl(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim());
}
