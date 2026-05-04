part of 'home_page.dart';

const int _conduitePathSeparatorNodeId = -1;

class _ConduiteMetierConfig {
  final String code;
  final String metier;
  final String entityType;
  final String tableName;
  final String title;
  final String shortLabel;
  final String xField;
  final String yField;
  final String zField;

  const _ConduiteMetierConfig({
    required this.code,
    required this.metier,
    required this.entityType,
    required this.tableName,
    required this.title,
    required this.shortLabel,
    required this.xField,
    required this.yField,
    required this.zField,
  });
}

class _ConduiteLocalPendingPreview {
  final List<Polyline> polylines;
  final Set<String> segmentKeys;
  final double lengthMeters;

  const _ConduiteLocalPendingPreview({
    required this.polylines,
    required this.segmentKeys,
    required this.lengthMeters,
  });
}

const _conduiteEpConfig = _ConduiteMetierConfig(
  code: 'ep',
  metier: 'Eau Potable',
  entityType: 'Regard',
  tableName: 'regard',
  title: 'eau potable',
  shortLabel: 'EP',
  xField: 'ep_coor_x',
  yField: 'ep_coor_y',
  zField: 'ep_coor_z',
);

const _conduiteAsstConfig = _ConduiteMetierConfig(
  code: 'asst',
  metier: 'Assainissement',
  entityType: 'Regard ASS',
  tableName: 'asst_regard',
  title: 'assainissement',
  shortLabel: 'ASS',
  xField: 'ass_coor_x',
  yField: 'ass_coor_y',
  zField: 'ass_coor_z',
);

_ConduiteMetierConfig _conduiteConfigFor(String? metier) {
  final value = (metier ?? '').trim().toLowerCase();
  return value == 'asst' || value == 'ass'
      ? _conduiteAsstConfig
      : _conduiteEpConfig;
}

Future<void> _enterConduiteDrawingModeImpl(
  _HomePageState state, {
  String metier = 'ep',
}) async {
  final config = _conduiteConfigFor(metier);
  final now = DateTime.now();
  final regardNodes = <int, _ConduiteRegardNode>{};
  final markers = await state._pointsService.getDisplayedRegardMarkersForDay(
    day: now,
    onTapRegard: state._handleConduiteRegardTap,
    metier: config.metier,
    entityType: config.entityType,
    tableName: config.tableName,
    onMarkerCreated: (row, marker) {
      final nodeId = _resolveConduiteNodeId(row);
      if (nodeId == null) return;
      regardNodes[nodeId] = _ConduiteRegardNode(
        nodeId: nodeId,
        sourceFid: _asIntConduite(row['fid']),
        point: marker.point,
        row: Map<String, dynamic>.from(row),
      );
    },
  );

  if (markers.isEmpty) {
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context).showSnackBar(
      const SnackBar(
        content:
            Text("Aucun regard levé aujourd'hui pour démarrer la conduite."),
      ),
    );
    return;
  }

  Map<String, dynamic>? existingSnapshot;
  String? loadWarning;
  final agentId = ApiService.userId;
  if (state._isOnlineDynamic) {
    try {
      existingSnapshot = await ApiService.fetchStatistiqueConduiteJour(
        idAgent: agentId,
        jour: now,
        metier: config.code,
      );
    } catch (e) {
      loadWarning = e.toString();
    }
  }
  final localPending = agentId == null
      ? null
      : await DatabaseHelper().getConduiteSyncItemForDay(
          metier: config.code,
          idAgent: agentId,
          jour: now,
        );
  final localPendingPreview = localPending == null
      ? null
      : _buildConduiteLocalPendingPreview(localPending);

  final isServerFrozen = existingSnapshot != null &&
      existingSnapshot['exists'] == true &&
      existingSnapshot['frozen'] == true;
  final serverFrozenSnapshot = isServerFrozen ? existingSnapshot : null;
  final isFrozen = isServerFrozen || localPendingPreview != null;
  final frozenPolylines = serverFrozenSnapshot != null
      ? _buildConduitePolylinesFromServerPayload(serverFrozenSnapshot)
      : (localPendingPreview?.polylines ?? <Polyline>[]);
  final frozenSegmentKeys = serverFrozenSnapshot != null
      ? _segmentKeysFromServerPayload(serverFrozenSnapshot)
      : (localPendingPreview?.segmentKeys ?? <String>{});

  state._setStateFromPart(() {
    state._mapController = null;
    state._isConduiteDrawingMode = true;
    state._conduiteModeMetier = config.code;
    state._conduiteModeDay = now;
    state._conduiteModeMarkers = markers;
    state._conduiteModePolylines = frozenPolylines;
    state._conduiteRegardNodesById
      ..clear()
      ..addAll(regardNodes);
    state._conduiteSelectionHistoryNodeIds.clear();
    state._conduiteSegmentKeys
      ..clear()
      ..addAll(frozenSegmentKeys);
    state._conduitePreviewLengthM = isServerFrozen
        ? _asDoubleConduite(existingSnapshot?['longueur_conduite_m']) ?? 0.0
        : localPendingPreview?.lengthMeters ?? 0.0;
    state._conduiteCurrentRegardPoint = null;
    state._conduiteIsFrozenForDay = isFrozen;
    state._conduiteIsSaving = false;
    state._conduiteModeError = loadWarning;
    state._conduiteModeStatusText = localPendingPreview != null
        ? 'Conduite locale en attente de synchronisation.'
        : isFrozen
            ? 'La conduite du jour est déjà validée et figée.'
            : state._isOnlineDynamic
                ? 'Touchez un regard pour commencer.'
                : 'Touchez un regard pour préparer la conduite. Validation disponible seulement en ligne.';
    state._autoCenterDisabledByUser = true;
  });

  if (!state.mounted) return;
  ScaffoldMessenger.of(state.context).showSnackBar(
    SnackBar(
      content: Text(
        isFrozen
            ? 'Conduite du jour déjà validée : consultation seule.'
            : 'Mode conduite activé : ${markers.length} regard(s) du jour disponibles.',
      ),
    ),
  );
}

void _exitConduiteDrawingModeImpl(_HomePageState state) {
  state._setStateFromPart(() {
    state._mapController = null;
    state._isConduiteDrawingMode = false;
    state._conduiteModeMetier = 'ep';
    state._conduiteModeDay = null;
    state._conduiteModeMarkers = <Marker>[];
    state._conduiteModePolylines = <Polyline>[];
    state._conduiteRegardNodesById.clear();
    state._conduiteSelectionHistoryNodeIds.clear();
    state._conduiteSegmentKeys.clear();
    state._conduitePreviewLengthM = 0.0;
    state._conduiteCurrentRegardPoint = null;
    state._conduiteIsFrozenForDay = false;
    state._conduiteIsSaving = false;
    state._conduiteModeError = null;
    state._conduiteModeStatusText = 'Touchez un regard pour commencer.';
    state._autoCenterDisabledByUser = false;
  });
}

void _handleConduiteRegardTapImpl(
  _HomePageState state,
  Map<String, dynamic> data,
) {
  if (state._conduiteIsSaving) {
    _showConduiteModeSnack(state, 'Validation en cours, patientez un instant.');
    return;
  }
  if (state._conduiteIsFrozenForDay) {
    _showConduiteModeSnack(
      state,
      'La conduite de ce jour est déjà validée et figée.',
    );
    return;
  }

  final nodeId = _resolveConduiteNodeId(data);
  if (nodeId == null) return;

  final node = state._conduiteRegardNodesById[nodeId];
  if (node == null) return;

  final currentLabel = _labelForConduiteNode(node);
  final previousNodeId = _currentConduiteLastNodeId(state);

  if (previousNodeId == nodeId) {
    state._setStateFromPart(() {
      state._conduiteCurrentRegardPoint = node.point;
      state._conduiteModeError = null;
      state._conduiteModeStatusText = '$currentLabel déjà actif.';
    });
    _showConduiteModeSnack(state, '$currentLabel déjà actif.');
    return;
  }

  String statusText;
  if (previousNodeId == null) {
    statusText = '$currentLabel sélectionné.';
  } else {
    final previousNode = state._conduiteRegardNodesById[previousNodeId];
    final previousLabel = previousNode == null
        ? 'Regard précédent'
        : _labelForConduiteNode(previousNode);
    final segmentKey = _conduiteSegmentKey(previousNodeId, nodeId);
    final isNewSegment = !state._conduiteSegmentKeys.contains(segmentKey);
    statusText = isNewSegment
        ? 'Segment $previousLabel -> $currentLabel ajouté.'
        : 'Segment $previousLabel -> $currentLabel déjà compté. $currentLabel actif.';
  }

  state._conduiteSelectionHistoryNodeIds.add(nodeId);
  _recomputeConduitePreviewFromHistory(state, statusText: statusText);
  _showConduiteModeSnack(state, statusText);
}

void _handleConduiteMapTapImpl(
  _HomePageState state,
  TapPosition tapPosition,
  LatLng latLng,
) {
  final mapController = state._mapController;
  if (!state._isConduiteDrawingMode ||
      state._conduiteRegardNodesById.isEmpty ||
      mapController == null) {
    return;
  }

  if (state._conduiteIsFrozenForDay || state._conduiteIsSaving) {
    return;
  }

  debugPrint(
    '[CONDUITE] map tap received lat=${latLng.latitude.toStringAsFixed(6)} '
    'lng=${latLng.longitude.toStringAsFixed(6)}',
  );

  _ConduiteRegardNode? nearest;
  double? nearestDistance;
  final relativeTapPoint = tapPosition.relative;
  final tapPoint = relativeTapPoint != null
      ? Point<double>(
          relativeTapPoint.dx,
          relativeTapPoint.dy,
        )
      : mapController.camera.latLngToScreenPoint(latLng);

  for (final node in state._conduiteRegardNodesById.values) {
    final markerPoint = mapController.camera.latLngToScreenPoint(
      node.point,
    );
    final dx = markerPoint.x - tapPoint.x;
    final dy = markerPoint.y - tapPoint.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (nearestDistance == null || distance < nearestDistance) {
      nearest = node;
      nearestDistance = distance;
    }
  }

  if (nearest == null) {
    return;
  }

  final zoom = mapController.camera.zoom;
  final maxTapSnapDistancePx = zoom >= 18
      ? 72.0
      : zoom >= 16
          ? 88.0
          : 104.0;
  if ((nearestDistance ?? double.infinity) > maxTapSnapDistancePx) {
    state._setStateFromPart(() {
      state._conduiteModeError =
          "Touchez plus près d'un regard pour l'ajouter à la conduite.";
      state._conduiteModeStatusText =
          'Aucun regard détecté à proximité du toucher.';
    });
    debugPrint(
      '[CONDUITE] map tap missed nearest=${nearestDistance?.toStringAsFixed(1)}px',
    );
    return;
  }

  debugPrint(
    '[CONDUITE] map tap snapped nodeId=${nearest.nodeId} sourceFid=${nearest.sourceFid} distance=${nearestDistance?.toStringAsFixed(1)}px',
  );

  _handleConduiteRegardTapImpl(state, {
    'node_id': nearest.nodeId,
    'fid': nearest.sourceFid,
    'lat': nearest.point.latitude,
    'lng': nearest.point.longitude,
    'existing_item': nearest.row,
  });
}

void _focusConduiteModeBoundsImpl(_HomePageState state) {
  final mapController = state._mapController;
  if (mapController == null || state._conduiteModeMarkers.isEmpty) {
    return;
  }

  try {
    if (state._conduiteModeMarkers.length == 1) {
      final point = state._conduiteModeMarkers.first.point;
      mapController.move(point, 18);
      state._lastCameraPosition = point;
      return;
    }

    final bounds = LatLngBounds.fromPoints(
      state._conduiteModeMarkers.map((marker) => marker.point).toList(),
    );
    mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
    );
    state._lastCameraPosition = bounds.center;
  } catch (_) {
    // Le contrôleur peut être remplacé pendant le switch de mode ; le prochain
    // onMapCreated refera le centrage proprement.
  }
}

Widget _buildConduiteModeHeaderImpl(_HomePageState state) {
  final config = _conduiteConfigFor(state._conduiteModeMetier);
  final countRegards = state._conduiteModeMarkers.length;
  final countSegments = state._conduiteSegmentKeys.length;
  final day = state._conduiteModeDay ?? DateTime.now();
  final canUndo = !state._conduiteIsFrozenForDay &&
      !state._conduiteIsSaving &&
      state._conduiteSelectionHistoryNodeIds.isNotEmpty;
  final canFinishCurrentConduite = !state._conduiteIsFrozenForDay &&
      !state._conduiteIsSaving &&
      _currentConduiteNodeCount(state) >= 2 &&
      !_selectionHistoryEndsWithSeparator(state);
  final canValidate = !state._conduiteIsFrozenForDay &&
      !state._conduiteIsSaving &&
      state._conduiteSegmentKeys.isNotEmpty;
  final countConduites =
      _conduitePathCount(state._conduiteSelectionHistoryNodeIds);

  return Container(
    color: const Color(0xFF1B4F72),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mode dessin conduite ${config.shortLabel}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Regards du ${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (state._conduiteIsFrozenForDay)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Figée',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _conduiteChip('Regards', '$countRegards'),
            _conduiteChip('Segments', '$countSegments'),
            _conduiteChip('Conduites', '$countConduites'),
            _conduiteChip(
              'Longueur',
              _formatConduiteLength(state._conduitePreviewLengthM),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildConduiteActionButton(
              label: 'Annuler',
              icon: Icons.close,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1B4F72),
              onPressed: state._conduiteIsSaving
                  ? null
                  : () => _handleConduiteCancelImpl(state),
            ),
            _buildConduiteActionButton(
              label: 'Undo',
              icon: Icons.undo,
              backgroundColor: const Color(0xFFE3F2FD),
              foregroundColor: const Color(0xFF0D47A1),
              onPressed: canUndo ? () => _handleConduiteUndoImpl(state) : null,
            ),
            _buildConduiteActionButton(
              label: 'Terminer',
              icon: Icons.call_split,
              backgroundColor: const Color(0xFFFFF3E0),
              foregroundColor: const Color(0xFFE65100),
              onPressed: canFinishCurrentConduite
                  ? () => _handleConduiteFinishCurrentImpl(state)
                  : null,
            ),
            _buildConduiteActionButton(
              label: state._conduiteIsFrozenForDay
                  ? 'Validée'
                  : state._conduiteIsSaving
                      ? 'Validation...'
                      : 'Valider',
              icon: Icons.check_circle,
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              onPressed:
                  canValidate ? () => _handleConduiteValidateImpl(state) : null,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          state._conduiteModeStatusText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget _buildConduiteActionButton({
  required String label,
  required IconData icon,
  required Color backgroundColor,
  required Color foregroundColor,
  required VoidCallback? onPressed,
}) {
  return ElevatedButton.icon(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      disabledBackgroundColor: Colors.white.withValues(alpha: 0.25),
      disabledForegroundColor: Colors.white70,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

Widget _conduiteChip(String label, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label : ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _handleConduiteCancelImpl(_HomePageState state) async {
  if (state._conduiteIsSaving) {
    return;
  }

  if (state._conduiteIsFrozenForDay ||
      state._conduiteSelectionHistoryNodeIds.isEmpty) {
    _exitConduiteDrawingModeImpl(state);
    return;
  }

  final shouldExit = await showDialog<bool>(
    context: state.context,
    builder: (context) => AlertDialog(
      title: const Text('Abandonner le dessin ?'),
      content: const Text(
        'Le dessin de conduite en cours sera perdu si vous annulez maintenant.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Retour'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Annuler le dessin'),
        ),
      ],
    ),
  );

  if (shouldExit == true) {
    _exitConduiteDrawingModeImpl(state);
  }
}

void _handleConduiteUndoImpl(_HomePageState state) {
  if (state._conduiteIsSaving || state._conduiteIsFrozenForDay) {
    return;
  }
  if (state._conduiteSelectionHistoryNodeIds.isEmpty) {
    _showConduiteModeSnack(state, 'Aucun regard à annuler.');
    return;
  }

  final removedNodeId = state._conduiteSelectionHistoryNodeIds.removeLast();
  final removedNode = state._conduiteRegardNodesById[removedNodeId];
  final removedLabel = _isConduitePathSeparator(removedNodeId)
      ? 'Séparation de conduite'
      : removedNode == null
          ? 'Dernier regard'
          : _labelForConduiteNode(removedNode);

  final activeNodeId = _currentConduiteLastNodeId(state);
  final activeNode = activeNodeId == null
      ? null
      : state._conduiteRegardNodesById[activeNodeId];
  final statusText = activeNode == null
      ? '$removedLabel retiré. Touchez un regard pour continuer.'
      : '$removedLabel retiré. ${_labelForConduiteNode(activeNode)} actif.';

  _recomputeConduitePreviewFromHistory(state, statusText: statusText);
  _showConduiteModeSnack(state, statusText);
}

void _handleConduiteFinishCurrentImpl(_HomePageState state) {
  if (state._conduiteIsSaving || state._conduiteIsFrozenForDay) {
    return;
  }

  if (_selectionHistoryEndsWithSeparator(state)) {
    _showConduiteModeSnack(
      state,
      'Cette conduite est déjà terminée. Touchez un regard pour démarrer la suivante.',
    );
    return;
  }

  if (_currentConduiteNodeCount(state) < 2) {
    _showConduiteModeSnack(
      state,
      'Sélectionnez au moins deux regards avant de terminer cette conduite.',
    );
    return;
  }

  state._conduiteSelectionHistoryNodeIds.add(_conduitePathSeparatorNodeId);
  const statusText =
      'Conduite terminée. Touchez un regard pour démarrer une autre conduite.';
  _recomputeConduitePreviewFromHistory(state, statusText: statusText);
  _showConduiteModeSnack(state, statusText);
}

Future<void> _handleConduiteValidateImpl(_HomePageState state) async {
  if (state._conduiteIsSaving || state._conduiteIsFrozenForDay) {
    return;
  }
  if (state._conduiteSegmentKeys.isEmpty) {
    _showConduiteModeSnack(
      state,
      'Dessinez au moins un segment avant de valider la conduite.',
    );
    return;
  }

  final confirmed = await showDialog<bool>(
    context: state.context,
    builder: (context) => AlertDialog(
      title: const Text('Valider la conduite ?'),
      content: Text(
        'Cette conduite sera figée pour le ${_formatDateOnly(state._conduiteModeDay ?? DateTime.now())}. '
        'Après confirmation, le bouton restera grisé jusqu’au lendemain.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Revenir au dessin'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );

  if (confirmed != true) {
    return;
  }

  if (!state._isOnlineDynamic) {
    await _saveConduiteValidationLocally(state);
    return;
  }

  state._setStateFromPart(() {
    state._conduiteIsSaving = true;
    state._conduiteModeError = null;
    state._conduiteModeStatusText = 'Validation en cours de la conduite...';
  });

  try {
    final response = await ApiService.validateStatistiqueConduite(
      idAgent: ApiService.userId,
      jour: state._conduiteModeDay ?? DateTime.now(),
      nodes: _buildConduiteValidationNodes(state),
      metier: state._conduiteModeMetier,
    );
    _applyConduiteServerSnapshot(
      state,
      response,
      statusText: 'Conduite du jour validée et figée.',
    );
    _showConduiteModeSnack(
      state,
      'Conduite enregistrée. Elle restera figée jusqu’au lendemain.',
    );
  } catch (e) {
    try {
      final refreshed = await ApiService.fetchStatistiqueConduiteJour(
        idAgent: ApiService.userId,
        jour: state._conduiteModeDay ?? DateTime.now(),
        metier: state._conduiteModeMetier,
      );
      if (refreshed['exists'] == true && refreshed['frozen'] == true) {
        _applyConduiteServerSnapshot(
          state,
          refreshed,
          statusText: 'Conduite du jour déjà validée et figée.',
        );
        _showConduiteModeSnack(
          state,
          'Cette conduite était déjà figée côté serveur.',
        );
        return;
      }
    } catch (_) {
      // On garde l'erreur initiale.
    }

    if (_shouldQueueConduiteAfterValidationFailure(e)) {
      await _saveConduiteValidationLocally(state);
      return;
    }

    state._setStateFromPart(() {
      state._conduiteIsSaving = false;
      state._conduiteModeError = e.toString();
      state._conduiteModeStatusText =
          'Validation impossible pour le moment. Corrigez puis réessayez.';
    });
    _showConduiteModeSnack(state, e.toString());
  }
}

bool _shouldQueueConduiteAfterValidationFailure(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('absent du serveur') ||
      text.contains('synchronisez les regards') ||
      text.contains('erreur reseau') ||
      text.contains('erreur réseau') ||
      text.contains('timeout');
}

Future<void> _saveConduiteValidationLocally(_HomePageState state) async {
  final idAgent = ApiService.userId;
  if (idAgent == null) {
    _showConduiteModeSnack(
      state,
      'Utilisateur non connecte pour enregistrer la conduite.',
    );
    return;
  }

  final nodes = _buildConduiteValidationNodes(state);
  await DatabaseHelper().enqueueConduiteSyncItem(
    metier: state._conduiteModeMetier,
    idAgent: idAgent,
    jour: state._conduiteModeDay ?? DateTime.now(),
    nodes: nodes,
  );

  state._setStateFromPart(() {
    state._conduiteIsSaving = false;
    state._conduiteIsFrozenForDay = true;
    state._conduiteCurrentRegardPoint = null;
    state._conduiteModeError = null;
    state._conduiteModeStatusText =
        'Conduite enregistree localement. Elle partira au prochain Synchroniser.';
  });
  _showConduiteModeSnack(
    state,
    'Conduite sauvegardee localement pour synchronisation.',
  );
}

void _recomputeConduitePreviewFromHistory(
  _HomePageState state, {
  required String statusText,
}) {
  final segmentKeys = <String>{};
  final polylines = <Polyline>[];
  var totalMeters = 0.0;

  for (var index = 1;
      index < state._conduiteSelectionHistoryNodeIds.length;
      index++) {
    final leftId = state._conduiteSelectionHistoryNodeIds[index - 1];
    final rightId = state._conduiteSelectionHistoryNodeIds[index];
    if (_isConduitePathSeparator(leftId) || _isConduitePathSeparator(rightId)) {
      continue;
    }
    if (leftId == rightId) {
      continue;
    }

    final leftNode = state._conduiteRegardNodesById[leftId];
    final rightNode = state._conduiteRegardNodesById[rightId];
    if (leftNode == null || rightNode == null) {
      continue;
    }

    final segmentKey = _conduiteSegmentKey(leftId, rightId);
    if (!segmentKeys.add(segmentKey)) {
      continue;
    }

    totalMeters += _conduiteSegmentLengthMeters(state, leftNode, rightNode);
    polylines.add(
      Polyline(
        points: [leftNode.point, rightNode.point],
        color: const Color(0xFF00897B),
        strokeWidth: 5.0,
      ),
    );
  }

  final currentNodeId = _currentConduiteLastNodeId(state);
  final currentPoint = currentNodeId == null
      ? null
      : state._conduiteRegardNodesById[currentNodeId]?.point;

  state._setStateFromPart(() {
    state._conduiteSegmentKeys
      ..clear()
      ..addAll(segmentKeys);
    state._conduiteModePolylines = polylines;
    state._conduitePreviewLengthM = totalMeters;
    state._conduiteCurrentRegardPoint = currentPoint;
    state._conduiteModeError = null;
    state._conduiteModeStatusText = statusText;
  });
}

void _applyConduiteServerSnapshot(
  _HomePageState state,
  Map<String, dynamic> payload, {
  required String statusText,
}) {
  final segmentKeys = _segmentKeysFromServerPayload(payload);
  state._setStateFromPart(() {
    state._conduiteIsSaving = false;
    state._conduiteIsFrozenForDay = payload['frozen'] == true;
    state._conduiteSelectionHistoryNodeIds.clear();
    state._conduiteSegmentKeys
      ..clear()
      ..addAll(segmentKeys);
    state._conduiteModePolylines =
        _buildConduitePolylinesFromServerPayload(payload);
    state._conduitePreviewLengthM =
        _asDoubleConduite(payload['longueur_conduite_m']) ?? 0.0;
    state._conduiteCurrentRegardPoint = null;
    state._conduiteModeError = null;
    state._conduiteModeStatusText = statusText;
  });
}

List<Polyline> _buildConduitePolylinesFromServerPayload(
  Map<String, dynamic> payload,
) {
  final result = <Polyline>[];
  final rawSegments = payload['segments_wgs84'];
  if (rawSegments is! List) {
    return result;
  }

  for (final rawSegment in rawSegments) {
    if (rawSegment is! Map) continue;
    final pointsRaw = rawSegment['points'];
    if (pointsRaw is! List || pointsRaw.length < 2) continue;

    final points = <LatLng>[];
    for (final rawPoint in pointsRaw) {
      if (rawPoint is! Map) continue;
      final lat = _asDoubleConduite(rawPoint['lat']);
      final lng = _asDoubleConduite(rawPoint['lng']);
      if (lat == null || lng == null) continue;
      points.add(LatLng(lat, lng));
    }

    if (points.length < 2) continue;
    result.add(
      Polyline(
        points: points,
        color: const Color(0xFF00897B),
        strokeWidth: 5.0,
      ),
    );
  }

  return result;
}

_ConduiteLocalPendingPreview? _buildConduiteLocalPendingPreview(
  Map<String, dynamic> queueItem,
) {
  final raw = queueItem['nodes_json']?.toString().trim() ?? '';
  if (raw.isEmpty) return null;

  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return null;
  }
  if (decoded is! List || decoded.length < 2) return null;

  final nodes = decoded
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
  final polylines = <Polyline>[];
  final segmentKeys = <String>{};
  var lengthMeters = 0.0;

  for (var i = 1; i < nodes.length; i++) {
    final left = nodes[i - 1];
    final right = nodes[i];
    if (_isConduiteSerializedSeparator(left) ||
        _isConduiteSerializedSeparator(right)) {
      continue;
    }
    final leftId = _resolveConduiteNodeId(left);
    final rightId = _resolveConduiteNodeId(right);
    if (leftId == null || rightId == null || leftId == rightId) {
      continue;
    }

    final segmentKey = _conduiteSegmentKey(leftId, rightId);
    if (!segmentKeys.add(segmentKey)) continue;

    final leftPoint = _latLngFromConduiteNode(left);
    final rightPoint = _latLngFromConduiteNode(right);
    if (leftPoint == null || rightPoint == null) continue;

    final ax = _asDoubleConduite(left['x']);
    final ay = _asDoubleConduite(left['y']);
    final bx = _asDoubleConduite(right['x']);
    final by = _asDoubleConduite(right['y']);
    if (ax != null && ay != null && bx != null && by != null) {
      final dx = bx - ax;
      final dy = by - ay;
      lengthMeters += math.sqrt(dx * dx + dy * dy);
    } else {
      lengthMeters += _haversineMetersImpl(leftPoint, rightPoint);
    }

    polylines.add(
      Polyline(
        points: [leftPoint, rightPoint],
        color: const Color(0xFF00897B),
        strokeWidth: 5.0,
      ),
    );
  }

  return _ConduiteLocalPendingPreview(
    polylines: polylines,
    segmentKeys: segmentKeys,
    lengthMeters: lengthMeters,
  );
}

LatLng? _latLngFromConduiteNode(Map<String, dynamic> node) {
  final lat = _asDoubleConduite(node['lat']);
  final lng = _asDoubleConduite(node['lng']);
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}

bool _isConduitePathSeparator(int nodeId) =>
    nodeId == _conduitePathSeparatorNodeId;

bool _isConduiteSerializedSeparator(Map<String, dynamic> node) =>
    node['separator'] == true || node['type'] == 'separator';

bool _selectionHistoryEndsWithSeparator(_HomePageState state) =>
    state._conduiteSelectionHistoryNodeIds.isNotEmpty &&
    _isConduitePathSeparator(state._conduiteSelectionHistoryNodeIds.last);

int? _currentConduiteLastNodeId(_HomePageState state) {
  if (state._conduiteSelectionHistoryNodeIds.isEmpty ||
      _selectionHistoryEndsWithSeparator(state)) {
    return null;
  }
  return state._conduiteSelectionHistoryNodeIds.last;
}

int _currentConduiteNodeCount(_HomePageState state) {
  var count = 0;
  for (var i = state._conduiteSelectionHistoryNodeIds.length - 1; i >= 0; i--) {
    final nodeId = state._conduiteSelectionHistoryNodeIds[i];
    if (_isConduitePathSeparator(nodeId)) break;
    count++;
  }
  return count;
}

int _conduitePathCount(List<int> history) {
  var count = 0;
  var nodeCountInPath = 0;
  for (final nodeId in history) {
    if (_isConduitePathSeparator(nodeId)) {
      if (nodeCountInPath >= 2) count++;
      nodeCountInPath = 0;
      continue;
    }
    nodeCountInPath++;
  }
  if (nodeCountInPath >= 2) count++;
  return count;
}

Set<String> _segmentKeysFromServerPayload(Map<String, dynamic> payload) {
  final keys = <String>{};
  final rawSegments = payload['segments_wgs84'];
  if (rawSegments is! List) {
    return keys;
  }

  for (final rawSegment in rawSegments) {
    if (rawSegment is! Map) continue;
    final left = _asIntConduite(rawSegment['fid_regard_a']);
    final right = _asIntConduite(rawSegment['fid_regard_b']);
    if (left == null || right == null) continue;
    keys.add(_conduiteSegmentKey(left, right));
  }
  return keys;
}

List<Map<String, dynamic>> _buildConduiteValidationNodes(_HomePageState state) {
  final config = _conduiteConfigFor(state._conduiteModeMetier);
  final nodes = <Map<String, dynamic>>[];
  var previousWasSeparator = true;

  for (final nodeId in state._conduiteSelectionHistoryNodeIds) {
    if (_isConduitePathSeparator(nodeId)) {
      if (!previousWasSeparator && nodes.isNotEmpty) {
        nodes.add({
          'separator': true,
          'metier': config.code,
          'table_name': config.tableName,
        });
        previousWasSeparator = true;
      }
      continue;
    }

    final node = state._conduiteRegardNodesById[nodeId];
    if (node == null) continue;
    nodes.add({
      'node_id': node.nodeId,
      'fid': node.sourceFid,
      'uuid': node.row['uuid']?.toString(),
      'label': _labelForConduiteNode(node),
      'metier': config.code,
      'table_name': config.tableName,
      'ep_num': node.row['ep_num']?.toString(),
      'x': _asDoubleConduite(node.row[config.xField]),
      'y': _asDoubleConduite(node.row[config.yField]),
      'z': _asDoubleConduite(node.row[config.zField]),
      'lat': node.point.latitude,
      'lng': node.point.longitude,
    });
    previousWasSeparator = false;
  }

  if (nodes.isNotEmpty && _isConduiteSerializedSeparator(nodes.last)) {
    nodes.removeLast();
  }
  return nodes;
}

String _formatConduiteLength(double meters) {
  if (meters >= 1000.0) {
    return '${(meters / 1000.0).toStringAsFixed(2)} km';
  }
  return '${meters.toStringAsFixed(1)} m';
}

String _formatDateOnly(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString().padLeft(4, '0');
  return '$day/$month/$year';
}

String _conduiteSegmentKey(int a, int b) {
  final min = math.min(a, b);
  final max = math.max(a, b);
  return '$min:$max';
}

int? _asIntConduite(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _conduiteSegmentLengthMeters(
  _HomePageState state,
  _ConduiteRegardNode a,
  _ConduiteRegardNode b,
) {
  final config = _conduiteConfigFor(state._conduiteModeMetier);
  final ax = _asDoubleConduite(a.row[config.xField]);
  final ay = _asDoubleConduite(a.row[config.yField]);
  final bx = _asDoubleConduite(b.row[config.xField]);
  final by = _asDoubleConduite(b.row[config.yField]);

  if (ax != null && ay != null && bx != null && by != null) {
    final dx = bx - ax;
    final dy = by - ay;
    return math.sqrt(dx * dx + dy * dy);
  }

  return _haversineMetersImpl(a.point, b.point);
}

double? _asDoubleConduite(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int? _resolveConduiteNodeId(Map<String, dynamic> row) {
  for (final key in ['node_id', 'fid', 'id', 'rowid']) {
    final parsed = _asIntConduite(row[key]);
    if (parsed != null) return parsed;
  }
  return null;
}

String _labelForConduiteNode(_ConduiteRegardNode node) {
  for (final key in ['ep_num', 'id_regard', 'objectid', 'uuid']) {
    final value = node.row[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
      return 'Regard $value';
    }
  }
  if (node.sourceFid != null) {
    return 'Regard #${node.sourceFid}';
  }
  return 'Regard local #${node.nodeId}';
}

void _showConduiteModeSnack(_HomePageState state, String message) {
  if (!state.mounted) return;
  final messenger = ScaffoldMessenger.of(state.context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(message),
    ),
  );
}
