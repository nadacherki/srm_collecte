part of 'home_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Mode "Pieces regard"
//
//  Permet a l'agent de :
//    1. Choisir un regard du jour (marker carte).
//    2. Taper dans le carre miroir du regard, ou son buffer terrain, pour
//       positionner une piece de regard.
//    3. Choisir le type de piece dans un selecteur restreint a :
//         vanne, vanne_de_vidange, ventouse, cone_de_reduction,
//         compteur_reseau, reducteur_de_pression, obturateur, pompe,
//         conduite_terrain.
//    4. Remplir le formulaire (SrmPointFormWidget) avec la position tapee.
//    5. Au save, on enregistre localement le lien (uuid_regard, table_objet,
//       uuid_objet) dans `regard_piece_link_sync_queue`. Le push HTTP est
//       fait au prochain cycle de synchro via /api/regard-piece-link/.
//
//  La conduite_terrain (ligne) n'est pas encore activee depuis ce mode pour
//  le MVP : un message renvoie l'agent vers le flot "Ligne" existant.
// ─────────────────────────────────────────────────────────────────────────────

const double _regardPieceTapBufferMeters =
    RegardPieceGeometryService.defaultTapBufferMeters;
const Color _regardPieceModeColor = Color(0xFF6A1B9A);

Future<void> _enterRegardPieceModeImpl(_HomePageState state) async {
  final now = DateTime.now();
  final regardNodes = <int, _ConduiteRegardNode>{};
  final markers = await state._pointsService.getDisplayedRegardMarkersForDay(
    day: now,
    onTapRegard: state._handleRegardPieceRegardTap,
    metier: 'Eau Potable',
    entityType: 'Regard',
    tableName: 'ep_regard_point',
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
        content: Text(
          "Aucun regard levé aujourd'hui : impossible de rattacher une pièce.",
        ),
      ),
    );
    return;
  }

  state._setStateFromPart(() {
    state._mapController = null;
    state._isRegardPieceMode = true;
    state._regardPieceModeMarkers = markers;
    state._regardPieceRegardNodesById
      ..clear()
      ..addAll(regardNodes);
    state._selectedRegardPieceNodeId = null;
    state._regardPieceStatusText =
        'Touchez un regard du jour pour le choisir comme parent.';
    state._regardPieceModeError = null;
    state._autoCenterDisabledByUser = true;
  });

  if (!state.mounted) return;
  ScaffoldMessenger.of(state.context).showSnackBar(
    SnackBar(
      content: Text(
        'Mode Pièces regard : ${markers.length} regard(s) du jour.',
      ),
    ),
  );
}

void _exitRegardPieceModeImpl(_HomePageState state) {
  state._setStateFromPart(() {
    state._mapController = null;
    state._isRegardPieceMode = false;
    state._regardPieceModeMarkers = <Marker>[];
    state._regardPieceRegardNodesById.clear();
    state._selectedRegardPieceNodeId = null;
    state._regardPieceStatusText = 'Touchez un regard pour commencer.';
    state._regardPieceModeError = null;
    state._autoCenterDisabledByUser = false;
  });
}

void _handleRegardPieceRegardTapImpl(
  _HomePageState state,
  Map<String, dynamic> data,
) {
  final nodeId = _resolveConduiteNodeId(data);
  if (nodeId == null) return;
  final node = state._regardPieceRegardNodesById[nodeId];
  if (node == null) return;
  final label = _labelForConduiteNode(node);
  state._setStateFromPart(() {
    state._selectedRegardPieceNodeId = nodeId;
    state._regardPieceModeError = null;
    state._regardPieceStatusText =
        '$label sélectionné. Touchez la position de la pièce sur la carte.';
  });
  ScaffoldMessenger.of(state.context).showSnackBar(
    SnackBar(content: Text('$label sélectionné comme parent.')),
  );
}

Future<void> _handleRegardPieceMapTapImpl(
  _HomePageState state,
  TapPosition tapPosition,
  LatLng latLng,
) async {
  if (!state._isRegardPieceMode) return;

  final selectedNodeId = state._selectedRegardPieceNodeId;
  if (selectedNodeId == null) {
    state._setStateFromPart(() {
      state._regardPieceModeError =
          'Choisissez d\'abord un regard parent en touchant son marqueur.';
      state._regardPieceStatusText =
          'Aucun regard parent sélectionné. Touchez un regard sur la carte.';
    });
    return;
  }

  final regardNode = state._regardPieceRegardNodesById[selectedNodeId];
  if (regardNode == null) return;
  final regardUuid = regardNode.row['uuid']?.toString().trim() ?? '';
  if (regardUuid.isEmpty) {
    state._setStateFromPart(() {
      state._regardPieceModeError =
          'Le regard parent n\'a pas d\'UUID local : impossible de créer le lien.';
    });
    return;
  }

  if (!_isRegardPieceTapInsideAllowedZone(regardNode, latLng)) {
    final message = 'Touchez dans le regard sélectionné ou dans la zone '
        'de tolérance '
        '(${_regardPieceTapBufferMeters.toStringAsFixed(0)} m).';
    state._setStateFromPart(() {
      state._regardPieceModeError = message;
      state._regardPieceStatusText =
          'Position hors zone : gardez la pièce autour du regard parent.';
    });
    ScaffoldMessenger.of(state.context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  if (!state.mounted) return;
  final selection = await showSrmRegardPieceSelector(state.context);
  if (!state.mounted || selection == null) return;

  if (selection.isLine) {
    await _startRegardPieceLineCollectionImpl(
      state,
      selection: selection,
      regardNode: regardNode,
      regardUuid: regardUuid,
      firstTargetPoint: latLng,
    );
    return;
  }

  if (!state.mounted) return;
  final targetX = latLng.longitude;
  final targetY = latLng.latitude;
  await Navigator.push(
    state.context,
    MaterialPageRoute(
      builder: (_) => SrmPointFormWidget(
        metier: selection.metier,
        entityType: selection.entityType,
        displayTitle: selection.titleApp,
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        altitude: state.homeController.currentProjectedZ ??
            state.homeController.currentAltitude,
        projectedX: targetX,
        projectedY: targetY,
        agentName: state.widget.agentName,
        onSaved: () {
          if (!state.mounted) return;
          Navigator.pop(state.context);
        },
        onCancel: () {
          if (!state.mounted) return;
          Navigator.pop(state.context);
        },
        onSavedWithMeta: (uuidObjet, tableName) async {
          // Enqueue immediat du lien piece-regard ; le push HTTP suivra au
          // prochain cycle de sync (idempotent serveur sur (table_objet,
          // uuid_objet)).
          try {
            await DatabaseHelper().enqueueRegardPieceLink(
              uuidRegard: regardUuid,
              tableObjet: tableName,
              uuidObjet: uuidObjet,
              fidRegard: regardNode.sourceFid,
              idAgent: ApiService.userId,
            );
            debugPrint(
              '[REGARD_PIECE] link enqueued regard=$regardUuid '
              'table=$tableName obj=$uuidObjet',
            );
          } catch (e) {
            debugPrint('[REGARD_PIECE] enqueue link failed: $e');
            // P1 / RP-1 : notifier l'agent. Sans ça, la piece est saisie
            // comme objet metier mais le lien parent-regard manque ; la
            // piece sera traitee comme orpheline cote bureau. Le lien
            // pourra etre re-cree manuellement en re-ouvrant la piece
            // dans le mode Pieces regard (idempotent UUID).
            if (state.mounted) {
              ScaffoldMessenger.of(state.context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Pièce enregistrée, mais le lien avec le regard parent '
                    "n'a pas pu être mémorisé. Re-ouvrez la pièce dans le "
                    'mode Pièces regard pour réessayer.',
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 8),
                ),
              );
            }
          }
        },
      ),
    ),
  );

  if (!state.mounted) return;
  state._setStateFromPart(() {
    state._regardPieceModeError = null;
    state._regardPieceStatusText =
        'Pièce ajoutée. Touchez un autre point pour une autre pièce, ou un autre regard pour changer de parent.';
  });
}

Future<void> _startRegardPieceLineCollectionImpl(
  _HomePageState state, {
  required SrmSelection selection,
  required _ConduiteRegardNode regardNode,
  required String regardUuid,
  required LatLng firstTargetPoint,
}) async {
  if (state.homeController.hasActiveCollection) {
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context).showSnackBar(
      SnackBar(
        content: Text(
          "Collecte de ${state.homeController.activeCollectionType} en cours, mettez-la en pause d'abord",
        ),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  if (!await state._confirmCaptureInsideAssignedZones(
    lat: firstTargetPoint.latitude,
    lng: firstTargetPoint.longitude,
  )) {
    return;
  }
  if (!state.mounted) return;

  state._pendingSrmLigneSelection = selection;
  state._pendingRegardPieceLineUuidRegard = regardUuid;
  state._pendingRegardPieceLineFidRegard = regardNode.sourceFid;

  final lineCode =
      'SRM_${selection.tableName}_${DateTime.now().millisecondsSinceEpoch}';
  try {
    await state.homeController.startLigneCollection(lineCode);
    state.homeController.collectionManager.addManualPoint(
      CollectionType.ligne,
      regardNode.point,
      altitude: _regardPieceRowDouble(regardNode.row, const [
        'ep_coor_z',
        'coor_z',
        'z',
        'altitude',
      ]),
      gnssPoint: _regardPieceGnssFromRegardNode(regardNode),
    );
    state.homeController.collectionManager.addManualPoint(
      CollectionType.ligne,
      firstTargetPoint,
      altitude: state.homeController.currentProjectedZ ??
          state.homeController.currentAltitude,
      gnssPoint: CapturedGnssPoint(
        latitude: firstTargetPoint.latitude,
        longitude: firstTargetPoint.longitude,
        projectedX: firstTargetPoint.longitude,
        projectedY: firstTargetPoint.latitude,
        projectedZ: state.homeController.currentProjectedZ,
      ),
    );
    state._ligneRedoPoints.clear();
    _exitRegardPieceModeImpl(state);
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context).showSnackBar(
      SnackBar(
        content: Text(
          'Tracé ${selection.titleApp} démarré depuis le regard parent. '
          'Continuez le dessin puis validez avec le bouton ligne.',
        ),
        backgroundColor: const Color(0xFF00897B),
      ),
    );
    state._setStateFromPart(() {});
  } catch (e) {
    state._pendingSrmLigneSelection = null;
    state._clearPendingRegardPieceLineLink();
    if (!state.mounted) return;
    ScaffoldMessenger.of(state.context).showSnackBar(
      SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

List<LatLng> _buildRegardPieceAllowedZone(LatLng center) {
  return RegardPieceGeometryService.buildAllowedZone(
    center: center,
    mirrorSquareSizeMeters: _regardMiroirLocalSquareSizeMeters,
    tapBufferMeters: _regardPieceTapBufferMeters,
  );
}

Polygon _buildRegardPieceAllowedZonePolygon(_ConduiteRegardNode node) {
  return Polygon(
    points: _buildRegardPieceAllowedZone(node.point),
    color: _regardPieceModeColor.withValues(alpha: 0.10),
    borderColor: _regardPieceModeColor.withValues(alpha: 0.85),
    borderStrokeWidth: 2.0,
  );
}

bool _isRegardPieceTapInsideAllowedZone(
  _ConduiteRegardNode node,
  LatLng tapPoint,
) {
  return RegardPieceGeometryService.containsTap(
    center: node.point,
    tapPoint: tapPoint,
    mirrorSquareSizeMeters: _regardMiroirLocalSquareSizeMeters,
    tapBufferMeters: _regardPieceTapBufferMeters,
  );
}

CapturedGnssPoint _regardPieceGnssFromRegardNode(_ConduiteRegardNode node) {
  return CapturedGnssPoint(
    latitude: node.point.latitude,
    longitude: node.point.longitude,
    projectedX: _regardPieceRowDouble(node.row, const [
      'ep_coor_x',
      'coor_x',
      'x',
    ]),
    projectedY: _regardPieceRowDouble(node.row, const [
      'ep_coor_y',
      'coor_y',
      'y',
    ]),
    projectedZ: _regardPieceRowDouble(node.row, const [
      'ep_coor_z',
      'coor_z',
      'z',
      'altitude',
    ]),
  );
}

double? _regardPieceRowDouble(
  Map<String, dynamic> row,
  List<String> keys,
) {
  for (final key in keys) {
    final value = row[key];
    if (value is num) return value.toDouble();
    final parsed =
        double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

Widget _buildRegardPieceModeHeaderImpl(_HomePageState state) {
  final selectedNodeId = state._selectedRegardPieceNodeId;
  final selectedNode = selectedNodeId == null
      ? null
      : state._regardPieceRegardNodesById[selectedNodeId];
  final selectedLabel =
      selectedNode == null ? '—' : _labelForConduiteNode(selectedNode);
  return Container(
    color: _regardPieceModeColor,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mode Pièces regard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Regard parent : $selectedLabel',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                state._regardPieceStatusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _exitRegardPieceModeImpl(state),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Quitter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6A1B9A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
