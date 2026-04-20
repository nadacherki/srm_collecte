part of 'home_page.dart';

Future<void> _checkPausedCollectionDraftImpl(_HomePageState state) async {
  final draft = await CollectionManager.loadPausedDraft();
  if (draft == null || !state.mounted) return;

  final type = draft['collectionType'] as String? ?? '?';
  final nbPoints = (draft['points'] as List?)?.length ?? 0;
  final pausedAt = draft['pausedAt'] as String?;
  final timeAgo = pausedAt != null
      ? CollectionManager.pauseTimeAgo(pausedAt)
      : '?';

  final shouldRestore = await showDialog<bool>(
    context: state.context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.pause_circle_filled, color: Colors.orange, size: 36),
      title: const Text('Collecte en pause'),
      content: Text(
        'Une collecte de $type avec $nbPoints points a été '
        'mise en pause il y a $timeAgo.\n\n'
        'Voulez-vous la reprendre ?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Ignorer et supprimer'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Reprendre'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );

  if (!state.mounted) return;

  if (shouldRestore == true) {
    state._restorePausedCollection(draft);
  } else {
    await state.homeController.collectionManager.clearPausedDraft();
  }
}

void _restorePausedCollectionImpl(
  _HomePageState state,
  Map<String, dynamic> draft,
) {
  final type = draft['collectionType'] as String;
  final srmMeta = draft['srmMetadata'] as Map<String, dynamic>?;

  switch (type) {
    case 'ligne':
      state.homeController.collectionManager.restoreLigneCollection(draft);
      if (srmMeta != null && srmMeta['srmMetier'] != null) {
        state._pendingSrmLigneSelection = SrmSelection(
          metier: srmMeta['srmMetier'] as String,
          entityType: srmMeta['srmEntityType'] as String? ?? '',
          tableName: srmMeta['srmTableName'] as String? ?? '',
          schema: srmMeta['srmSchema'] as String? ?? '',
          isLine: true,
        );
      }
      final lineCode = draft['lineCode'] as String?;
      if (lineCode != null) {
        state.homeController.setActiveLineCode(lineCode);
      }
      break;

    case 'special':
      state.homeController.collectionManager.restoreSpecialCollection(draft);
      if (srmMeta != null) {
        state._pendingSrmPolygoneMetier = srmMeta['srmMetier'] as String?;
        state._pendingSrmPolygoneEntityType =
            srmMeta['srmEntityType'] as String?;
        state._isPolygonCollection = srmMeta['isPolygonCollection'] == true;
        state._isSpecialCollection = srmMeta['isSpecialCollection'] == true;
        state._specialCollectionType =
            srmMeta['specialCollectionType'] as String?;
      }
      break;
  }

  state._setStateFromPart(() {});

  ScaffoldMessenger.of(state.context).showSnackBar(
    SnackBar(
      content: Text(
        'Collecte de $type restaurée '
        '(${(draft['points'] as List).length} points)',
      ),
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 3),
    ),
  );
}

Future<void> _hydrateOfflineBasemapStateImpl(_HomePageState state) async {
  final db = DatabaseHelper();
  final activePackage = await OfflineBasemapService().getActivePackage();
  final packagePath = activePackage?['local_path']?.toString().trim();
  final packageFormat = activePackage?['format']?.toString().trim();
  final activeZoneId = activePackage?['zone_id']?.toString().trim();
  final activeZone = activeZoneId == null || activeZoneId.isEmpty
      ? null
      : await db.getOfflineBasemapZoneById(activeZoneId);
  final localPath =
      (packagePath != null && packagePath.isNotEmpty) ? packagePath : null;

  if (!state.mounted) return;

  state._setStateFromPart(() {
    if (localPath != null && localPath.isNotEmpty) {
      state._offlineBasemapPath = localPath;
      state._offlineBasemapFormat = packageFormat;
      state._basemapUnavailableMessage = null;
    }

    if (activeZone != null) {
      final centerLat = _asDoubleOrNullImpl(activeZone['center_latitude']);
      final centerLng = _asDoubleOrNullImpl(activeZone['center_longitude']);
      final west = _asDoubleOrNullImpl(activeZone['bbox_west']);
      final south = _asDoubleOrNullImpl(activeZone['bbox_south']);
      final east = _asDoubleOrNullImpl(activeZone['bbox_east']);
      final north = _asDoubleOrNullImpl(activeZone['bbox_north']);
      final minZoom = _asDoubleOrNullImpl(activeZone['min_zoom']);
      final maxZoom = _asDoubleOrNullImpl(activeZone['max_zoom']);

      if (centerLat != null && centerLng != null) {
        state._offlineBasemapCenter = LatLng(centerLat, centerLng);
      }
      if (west != null && south != null && east != null && north != null) {
        state._offlineBasemapBounds = LatLngBounds(
          LatLng(north, west),
          LatLng(south, east),
        );
      }
      if (minZoom != null) {
        state._offlineBasemapMinZoom = minZoom;
      }
      if (maxZoom != null) {
        state._offlineBasemapMaxZoom = maxZoom;
      }
      if (state._offlineBasemapMinZoom != null &&
          state._offlineBasemapMaxZoom != null) {
        state._offlineBasemapDefaultZoom =
            (state._offlineBasemapMinZoom! + state._offlineBasemapMaxZoom!) / 2;
      }
    }

    if (state._mapController != null &&
        state._lastCameraPosition == null &&
        state.userPosition == null &&
        state._offlineBasemapCenter != null) {
      state._mapController!.move(
        state._offlineBasemapCenter!,
        state._offlineBasemapDefaultZoom ??
            BasemapConstants.fallbackDefaultZoom,
      );
      state._lastCameraPosition = state._offlineBasemapCenter;
    }
  });
}

void _showInitialBasemapNoticeIfNeededImpl(_HomePageState state) {
  final message = state.widget.initialBasemapNotice;
  if (!state.mounted || message == null || message.trim().isEmpty) {
    return;
  }

  ScaffoldMessenger.of(state.context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

double? _asDoubleOrNullImpl(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

Future<void> _loadAdminNamesOfflineImpl(_HomePageState state) async {
  try {
    final projetRegion =
        (ApiService.currentProjetRegion ?? '').toString().trim();
    final projetNom = (ApiService.currentProjetNom ?? '').toString().trim();

    if (!state.mounted) return;
    state._setStateFromPart(() {
      state._regionNom = projetRegion.isNotEmpty ? projetRegion : '----';
      state._prefectureNom = projetNom.isNotEmpty ? projetNom : '----';
      state._communeNom = '----';
    });
  } catch (_) {
    // On laisse les valeurs par défaut.
  }
}

void _suspendAutoCenterForImpl(_HomePageState state, Duration duration) {
  state._suspendAutoCenterUntil = DateTime.now().add(duration);
}

void _startOnlineWatcherImpl(_HomePageState state) {
  state._onlineWatchTimer?.cancel();
  state._checkOnlineStatus();

  state._onlineWatchTimer = Timer.periodic(
    const Duration(seconds: 10),
    (_) => state._checkOnlineStatus(),
  );
}

Future<void> _checkOnlineStatusImpl(_HomePageState state) async {
  final reachable = await _isApiReachableForStatusImpl();
  if (!state.mounted) return;

  final wasOffline = !state._isOnlineDynamic;

  if (reachable != state._isOnlineDynamic) {
    state._setStateFromPart(() {
      state._isOnlineDynamic = reachable;
    });
    state.homeController.setSyncAvailability(reachable);

    if (wasOffline && reachable) {
      await _restoreApiServiceFromLocalImpl(state);
    }
  }
}

Future<void> _restoreApiServiceFromLocalImpl(_HomePageState state) async {
  try {
    if (ApiService.userId != null) return;

    final user = await DatabaseHelper().getCurrentUserSrm();
    if (user == null) return;

    ApiService.userId = user['id_user'] is int
        ? user['id_user']
        : int.tryParse(user['id_user']?.toString() ?? '');
    ApiService.userRole = user['role']?.toString();
    ApiService.userLogin = user['login']?.toString();
    ApiService.nomPrenom = user['nom_prenom']?.toString();

    final idProjetActif = user['id_projet_actif'];
    if (idProjetActif != null && ApiService.currentProjetId == null) {
      ApiService.currentProjetId = idProjetActif is int
          ? idProjetActif
          : int.tryParse(idProjetActif.toString());

      if (ApiService.currentProjetId != null) {
        final projet = await DatabaseHelper()
            .getProjetLocal(ApiService.currentProjetId!);
        if (projet != null) {
          ApiService.currentProjetNom = projet['nom']?.toString();
          ApiService.currentProjetStatut = projet['statut']?.toString();
          ApiService.currentProjetMetier = projet['metier']?.toString();
          ApiService.currentProjetRegion = projet['region']?.toString();
        }
      }
    }
  } catch (_) {
    // Échec silencieux : on retentera au prochain retour en ligne.
  }
}

Future<bool> _isApiReachableForStatusImpl() async {
  try {
    final uri = Uri.parse(ApiService.baseUrl);
    final host = uri.host;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

    final socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 1),
    );
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _loadLastSyncTimeImpl(_HomePageState state) async {
  final dt = await DatabaseHelper().getLastSyncTime();
  if (!state.mounted) return;
  state._setStateFromPart(() {
    state._lastSyncTimeText = dt != null ? _formatTimeHHmmImpl(dt) : null;
  });
}

String _formatTimeHHmmImpl(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

Future<void> _focusOnTargetImpl(
  _HomePageState state,
  MapFocusTarget target,
) async {
  state._autoCenterDisabledByUser = true;

  Polyline? focusPolyline;
  Marker? focusMarker;

  if (target.kind == 'polyline' &&
      target.polyline != null &&
      target.polyline!.isNotEmpty) {
    focusPolyline = Polyline(
      points: target.polyline!,
      color: Colors.purpleAccent,
      strokeWidth: 6.0,
      pattern: StrokePattern.dashed(segments: const [12, 6]),
    );
  } else if (target.kind == 'point' && target.point != null) {
    if (target.pointStyle == 'intersection') {
      focusMarker = Marker(
        point: target.point!,
        width: 48,
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepOrange,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 28),
        ),
      );
    } else {
      focusMarker = Marker(
        point: target.point!,
        width: 52,
        height: 52,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withValues(alpha: 0.5),
                blurRadius: 14,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 30),
        ),
      );
    }
  }

  state._setStateFromPart(() {
    if (focusPolyline != null) state._focusOverlayPolylines.add(focusPolyline);
    if (focusMarker != null) state._focusOverlayMarkers.add(focusMarker);
  });

  await Future.delayed(const Duration(milliseconds: 50));

  if (state._mapController != null) {
    if (target.kind == 'point' && target.point != null) {
      state._mapController!.move(target.point!, 15);
      state._lastCameraPosition = target.point;
    } else if (target.kind == 'polyline' &&
        target.polyline != null &&
        target.polyline!.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(target.polyline!);
      state._mapController!.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(64)),
      );
      state._lastCameraPosition = bounds.center;
    }
  }

  Future.delayed(const Duration(seconds: 15), () {
    if (!state.mounted) return;
    state._setStateFromPart(() {
      if (focusPolyline != null) {
        state._focusOverlayPolylines.remove(focusPolyline);
      }
      if (focusMarker != null) {
        state._focusOverlayMarkers.remove(focusMarker);
      }
    });
  });
}

void _onMapCreatedImpl(_HomePageState state, MapController controller) {
  state._mapController = controller;

  if (state.widget.initialFocus != null) {
    state._suspendAutoCenterFor(const Duration(seconds: 10));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (state.mounted) {
        state._focusOnTarget(state.widget.initialFocus!);
      }
    });
    return;
  }

  if (state.userPosition != null) {
    controller.move(state.userPosition!, 17);
    state._lastCameraPosition = state.userPosition;
  } else if (state._offlineBasemapCenter != null) {
    controller.move(
      state._offlineBasemapCenter!,
      state._offlineBasemapDefaultZoom ?? BasemapConstants.fallbackDefaultZoom,
    );
    state._lastCameraPosition = state._offlineBasemapCenter;
  }
}

void _moveCameraIfNeededImpl(_HomePageState state) {
  if (state._mapController == null || state.userPosition == null) return;

  try {
    final shouldMove = state._lastCameraPosition == null ||
        state._coordinateDistance(
              state._lastCameraPosition!.latitude,
              state._lastCameraPosition!.longitude,
              state.userPosition!.latitude,
              state.userPosition!.longitude,
            ) >
            20;

    if (!state._autoCenterSuspended && shouldMove) {
      state._mapController!.move(state.userPosition!, 17);
      state._lastCameraPosition = state.userPosition;
    }
  } catch (_) {
    // Échec silencieux : on laissera la prochaine mise à jour recentrer.
  }
}
