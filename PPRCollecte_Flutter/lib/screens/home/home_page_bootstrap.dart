part of 'home_page.dart';

Future<void> _checkPausedCollectionDraftImpl(_HomePageState state) async {
  final draft = await CollectionManager.loadPausedDraft();
  if (draft == null || !state.mounted) return;

  final type = draft['collectionType'] as String? ?? '?';
  final nbPoints = (draft['points'] as List?)?.length ?? 0;

  // Brouillon vide (0 point) -> rien a reprendre. On purge silencieusement
  // pour ne pas reproposer le dialog au prochain demarrage.
  if (nbPoints < 1) {
    await state.homeController.collectionManager.clearPausedDraft();
    return;
  }

  final pausedAt = draft['pausedAt'] as String?;
  final timeAgo =
      pausedAt != null ? CollectionManager.pauseTimeAgo(pausedAt) : '?';

  final shouldRestore = await showDialog<bool>(
    context: state.context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon:
          const Icon(Icons.pause_circle_filled, color: Colors.orange, size: 36),
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
      if (srmMeta != null && srmMeta['geometryEdit'] == true) {
        state._geometryEditLineItem = {
          'id': draft['id'],
          'source_metier': srmMeta['srmMetier'],
          'source_entity': srmMeta['srmEntityType'],
          'source_title': srmMeta['srmTitleApp'],
          'source_table': srmMeta['srmTableName'],
          'geometry_type': 'LineString',
        };
      } else if (srmMeta != null && srmMeta['srmMetier'] != null) {
        state._pendingSrmLigneSelection = SrmSelection(
          metier: srmMeta['srmMetier'] as String,
          entityType: srmMeta['srmEntityType'] as String? ?? '',
          tableName: srmMeta['srmTableName'] as String? ?? '',
          schema: srmMeta['srmSchema'] as String? ?? '',
          titleApp: srmMeta['srmTitleApp'] as String? ?? '',
          isLine: true,
        );
      }
      final lineCode = draft['lineCode'] as String?;
      if (lineCode != null) {
        state.homeController.setActiveLineCode(lineCode);
      }
      break;

    case 'polygon':
      state.homeController.collectionManager.restorePolygonCollection(draft);
      if (srmMeta != null) {
        state._pendingSrmPolygoneMetier = srmMeta['srmMetier'] as String?;
        state._pendingSrmPolygoneEntityType =
            srmMeta['srmEntityType'] as String?;
        state._pendingSrmPolygoneTitleApp = srmMeta['srmTitleApp'] as String?;
        state._isPolygonCollection = true;
        state._polygonEntityType = srmMeta['polygonEntityType'] as String?;
      } else {
        state._isPolygonCollection = true;
        state._polygonEntityType = draft['entityType'] as String?;
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
  final activeBasemap = await OfflineBasemapService().getActiveBasemap();
  await _applyOfflineBasemapPackageStateImpl(state, activeBasemap);
}

Future<void> _applyOfflineBasemapPackageStateImpl(
  _HomePageState state,
  Map<String, dynamic>? basemap,
) async {
  final localPath = basemap?['local_path']?.toString().trim();
  final format = basemap?['format']?.toString().trim();

  if (!state.mounted) return;

  state._setStateFromPart(() {
    if (localPath != null && localPath.isNotEmpty) {
      state._offlineBasemapPath = localPath;
      state._offlineBasemapFormat = format;
      state._basemapUnavailableMessage = null;
    } else if (state._offlineBasemapPath == null ||
        state._offlineBasemapPath!.isEmpty) {
      state._basemapUnavailableMessage = BasemapConstants.unavailableMessage;
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
    if (!state.mounted) return;
    state._setStateFromPart(() {
      state._regionNom = '----';
      state._prefectureNom = '----';
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
  final checks = await Future.wait<bool>([
    _isApiReachableForStatusImpl(),
    _isOnlineBasemapReachableImpl(),
  ]);
  await _applyOnlineStatusImpl(state, checks[0]);
  _applyOnlineBasemapStatusImpl(state, checks[1]);
}

Future<bool> _refreshOnlineStatusForNetworkActionImpl(
    _HomePageState state) async {
  final checks = await Future.wait<bool>([
    _isApiReachableForStatusImpl(),
    _isOnlineBasemapReachableImpl(),
  ]);
  final reachable = checks[0];
  await _applyOnlineStatusImpl(state, reachable);
  _applyOnlineBasemapStatusImpl(state, checks[1]);
  return reachable;
}

Future<void> _applyOnlineStatusImpl(
  _HomePageState state,
  bool reachable,
) async {
  if (!state.mounted) return;

  final wasOffline = !state._isOnlineDynamic;

  if (reachable != state._isOnlineDynamic) {
    state._setStateFromPart(() {
      state._isOnlineDynamic = reachable;
    });
    state.homeController.setSyncAvailability(reachable);

    if (wasOffline && reachable) {
      await _restoreApiServiceFromLocalImpl(state);
      unawaited(_refreshMobileConfigAfterReconnectImpl(state));
    }
  }
}

void _applyOnlineBasemapStatusImpl(
  _HomePageState state,
  bool reachable,
) {
  if (!state.mounted) return;
  if (reachable == state._canUseOnlineBasemap) return;

  state._setStateFromPart(() {
    state._canUseOnlineBasemap = reachable;
  });
}

Future<void> _refreshMobileConfigAfterReconnectImpl(
  _HomePageState state,
) async {
  if (!state.mounted) return;
  if (state._mobileConfigAutoRefreshRunning) return;

  final now = DateTime.now();
  final lastRefresh = state._lastMobileConfigAutoRefreshAt;
  if (lastRefresh != null &&
      now.difference(lastRefresh) < const Duration(minutes: 2)) {
    return;
  }

  state._mobileConfigAutoRefreshRunning = true;
  state._lastMobileConfigAutoRefreshAt = now;

  try {
    await _restoreApiServiceFromLocalImpl(state);
    await Future.wait<void>([
      _runReconnectRefreshStep(
        'FORMULAIRE-CONFIG-MOBILE',
        FormulaireConfigMobileService().refreshConfig(),
      ),
      _runReconnectRefreshStep(
        'ATTRIBUT-CONFIG-MOBILE',
        AttributConfigMobileService().refreshConfig(),
      ),
      _runReconnectRefreshStep(
        'SRM-FIELD-OPTIONS',
        SrmFieldOptionService().refreshOptions(),
      ),
      _runReconnectRefreshStep(
        'COMMUNES',
        CommuneSyncService().refreshCommunes(),
      ),
      _runReconnectRefreshStep(
        'REFERENCE-OVERLAYS',
        ReferenceOverlaySyncService().refreshLightOverlays(),
      ),
      _runReconnectRefreshStep(
        'METRICS',
        PublicMetricsCacheService().prefetchForCurrentSession(
            requestTimeout: const Duration(seconds: 15)),
      ),
    ]);
    await state._loadReferenceOverlays();
    debugPrint('[RECONNECT-CONFIG] Refresh auto termine');
  } finally {
    state._mobileConfigAutoRefreshRunning = false;
  }
}

Future<void> _runReconnectRefreshStep(
  String label,
  Future<dynamic> future,
) async {
  try {
    await future;
  } catch (e) {
    debugPrint('[$label] Refresh reconnexion ignore: $e');
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
    ApiService.userNom = user['nom']?.toString();
    ApiService.userPrenom = user['prenom']?.toString();
    ApiService.nomPrenom = DatabaseHelper.fullNameFromUserRow(user);
  } catch (_) {
    // Échec silencieux : on retentera au prochain retour en ligne.
  }
}

Future<void> _autoStartNmeaBridgeIfConfiguredImpl(_HomePageState state) async {
  if (!Platform.isAndroid) return;
  if (!state.mounted) return;

  try {
    final bridge = NmeaBridgeService();
    final status = await bridge.getStatus();
    if (!status.mockLocationSelected) {
      debugPrint(
          '[NMEA] Auto-connect ignore: SRM Collecte non selectionnee en position fictive');
      return;
    }

    if (!_isNmeaBridgeDisconnectedStatus(status.status)) {
      debugPrint(
          '[NMEA] Auto-connect ignore: pont deja actif (${status.status})');
      state.homeController.markNmeaBridgePending(
        deviceLabel: status.bluetoothName ?? status.bluetoothAddress,
        bridgeStatus: status.status,
        lastNmea: status.lastNmea,
      );
      _applyNmeaBridgeFixToMapImpl(
        state,
        status,
        recenter: state._lastCameraPosition == null,
      );
      _startNmeaBridgeWatchImpl(state);
      return;
    }

    final permissionsOk = await _ensureNmeaBluetoothPermissionsImpl();
    if (!permissionsOk) {
      debugPrint(
          '[NMEA] Auto-connect ignore: permissions Bluetooth non accordees');
      return;
    }

    final device = await bridge.resolveAutoConnectDevice();
    if (device == null) {
      debugPrint('[NMEA] Auto-connect ignore: aucun GNSS appaire reconnu');
      return;
    }

    await bridge.connectBluetooth(device.address);
    debugPrint('[NMEA] Auto-connect lance vers ${device.label}');
    state.homeController.markNmeaBridgePending(deviceLabel: device.label);
    _startNmeaBridgeWatchImpl(state);
    unawaited(_centerOnNmeaFirstFixImpl(state, bridge));
  } catch (e) {
    debugPrint('[NMEA] Auto-connect echec: $e');
  }
}

void _startNmeaBridgeWatchImpl(_HomePageState state) {
  state._nmeaBridgeWatchTimer?.cancel();
  final bridge = NmeaBridgeService();

  state._nmeaBridgeWatchTimer = Timer.periodic(
    const Duration(seconds: 1),
    (timer) async {
      if (!state.mounted) {
        timer.cancel();
        return;
      }

      try {
        final status = await bridge.getStatus();
        if (_isNmeaBridgeDisconnectedStatus(status.status)) {
          timer.cancel();
          return;
        }
        final applied = _applyNmeaBridgeFixToMapImpl(
          state,
          status,
          recenter: false,
        );
        if (!applied &&
            state.homeController.gpsSourceLabel.startsWith('GNSS externe')) {
          state.homeController.markNmeaBridgePending(
            deviceLabel: status.bluetoothName ?? status.bluetoothAddress,
            bridgeStatus: status.status,
            lastNmea: status.lastNmea,
          );
        }
      } catch (e) {
        debugPrint('[NMEA] Suivi pont GNSS ignore: $e');
      }
    },
  );
}

Future<void> _centerOnNmeaFirstFixImpl(
  _HomePageState state,
  NmeaBridgeService bridge,
) async {
  const maxAttempts = 20;
  const retryDelay = Duration(milliseconds: 700);

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (!state.mounted) return;

    try {
      final status = await bridge.getStatus();
      final applied = _applyNmeaBridgeFixToMapImpl(state, status);
      if (applied) {
        return;
      }
    } catch (e) {
      debugPrint('[NMEA] Attente premier fix GNSS: $e');
    }

    await Future.delayed(retryDelay);
  }

  debugPrint(
      '[NMEA] Aucun fix GNSS exploitable recu pour recentrage automatique');
}

bool _applyNmeaBridgeFixToMapImpl(
  _HomePageState state,
  NmeaBridgeStatus status, {
  bool recenter = true,
}) {
  final nativeLocation = status.lastLocation;
  final source = nativeLocation?['source']?.toString();
  if (source != 'nmea_bridge') {
    return false;
  }

  final nativeLat = _asDoubleOrNullImpl(nativeLocation?['latitude']);
  final nativeLon = _asDoubleOrNullImpl(nativeLocation?['longitude']);
  if (nativeLat == null ||
      nativeLon == null ||
      nativeLat.abs() > 90 ||
      nativeLon.abs() > 180) {
    return false;
  }

  final accuracy = _asDoubleOrNullImpl(nativeLocation?['accuracy']);
  final altitude = _asDoubleOrNullImpl(nativeLocation?['altitude']);
  final speed = _asDoubleOrNullImpl(nativeLocation?['speed']);
  final bearing = _asDoubleOrNullImpl(nativeLocation?['bearing']);
  final hdop = _asDoubleOrNullImpl(nativeLocation?['hdop']);
  final fixQuality = _asIntOrNullImpl(nativeLocation?['fixQuality']);
  final satellites = _asIntOrNullImpl(nativeLocation?['satellites']);
  final timestamp = _asIntOrNullImpl(
    nativeLocation?['nmeaReceivedAt'] ?? nativeLocation?['time'],
  );
  final mockInjectedAt = _asIntOrNullImpl(nativeLocation?['mockInjectedAt']);
  final nmea = nativeLocation?['nmea']?.toString() ?? status.lastNmea;
  final bluetoothName =
      nativeLocation?['bluetoothName']?.toString() ?? status.bluetoothName;
  final bluetoothAddress = nativeLocation?['bluetoothAddress']?.toString() ??
      status.bluetoothAddress;
  final target = LatLng(nativeLat, nativeLon);

  state.homeController.applyNmeaBridgeLocation(
    latitude: nativeLat,
    longitude: nativeLon,
    accuracy: accuracy,
    altitude: altitude,
    speed: speed,
    bearing: bearing,
    fixQuality: fixQuality,
    satellites: satellites,
    hdop: hdop,
    nmea: nmea,
    bluetoothName: bluetoothName,
    bluetoothAddress: bluetoothAddress,
    timestampMs: timestamp,
    mockInjectedAtMs: mockInjectedAt,
  );

  if (recenter) {
    state._autoCenterDisabledByUser = false;
    if (state._mapController != null) {
      state._mapController!.move(target, 17);
      state._lastCameraPosition = target;
    }
    debugPrint(
        '[NMEA] Carte recentree sur fix GNSS externe source=nmea_bridge');
  }
  return true;
}

bool _isNmeaBridgeDisconnectedStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'idle' ||
      normalized == 'erreur' ||
      normalized == 'bluetooth_disconnected' ||
      normalized.startsWith('bluetooth_error');
}

Future<bool> _ensureNmeaBluetoothPermissionsImpl() async {
  final connectStatus = await Permission.bluetoothConnect.request();
  final scanStatus = await Permission.bluetoothScan.request();
  return connectStatus.isGranted && scanStatus.isGranted;
}

int? _asIntOrNullImpl(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

Future<bool> _isApiReachableForStatusImpl() async {
  try {
    final uri = Uri.parse(ApiService.baseUrl);
    final host = uri.host;
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

    return _canConnectSocketImpl(host, port);
  } catch (_) {
    return false;
  }
}

Future<bool> _isOnlineBasemapReachableImpl() async {
  final checks = await Future.wait<bool>([
    _canConnectSocketImpl('tile.openstreetmap.org', 443),
    _canConnectSocketImpl('mt1.google.com', 443),
  ]);
  return checks.any((reachable) => reachable);
}

Future<bool> _canConnectSocketImpl(String host, int port) async {
  try {
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

const Duration _focusOverlayVisibleDuration = Duration(seconds: 2);

double _focusTargetZoomImpl(_HomePageState state) {
  final rawMaxZoom = state._mapController?.camera.maxZoom ??
      state._offlineBasemapMaxZoom ??
      BasemapConstants.fallbackMaxZoom;
  final maxZoom = rawMaxZoom.isFinite
      ? rawMaxZoom.toDouble()
      : BasemapConstants.fallbackMaxZoom;

  if (maxZoom < 15.0) return maxZoom;
  return maxZoom.clamp(15.0, BasemapConstants.fallbackMaxZoom).toDouble();
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
    state._focusOverlayPolylines.clear();
    state._focusOverlayMarkers.clear();
    if (focusPolyline != null) state._focusOverlayPolylines.add(focusPolyline);
    if (focusMarker != null) state._focusOverlayMarkers.add(focusMarker);
  });

  await Future.delayed(const Duration(milliseconds: 50));

  if (state._mapController != null) {
    if (target.kind == 'point' && target.point != null) {
      state._mapController!.move(target.point!, _focusTargetZoomImpl(state));
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

  Future.delayed(_focusOverlayVisibleDuration, () {
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

  if (state._isConduiteDrawingMode && state._conduiteModeMarkers.isNotEmpty) {
    state._focusConduiteModeBounds();
    return;
  }

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
  if (state._isConduiteDrawingMode) return;
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
