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
  final offlineService = OfflineBasemapService();
  final position = state.userPosition ?? state.homeController.userPosition;
  final selectedPackage = await offlineService.selectReadyPackageForPosition(
    position: position,
    zoom: state._offlineBasemapDefaultZoom,
    citySlug: BasemapConstants.catalogCitySlug,
  );
  final activePackage =
      selectedPackage ?? await offlineService.getActivePackage();

  await _applyOfflineBasemapPackageStateImpl(state, activePackage);
}

Future<void> _selectOfflineBasemapForCameraImpl(
  _HomePageState state,
  LatLng center,
  double zoom,
) async {
  if (state._isSelectingOfflineBasemapForCamera) return;

  state._isSelectingOfflineBasemapForCamera = true;
  try {
    final package = await OfflineBasemapService().selectReadyPackageForPosition(
      position: center,
      zoom: zoom,
      citySlug: BasemapConstants.catalogCitySlug,
    );
    if (package == null) return;

    final packageKey = package['package_key']?.toString().trim();
    final localPath = package['local_path']?.toString().trim();
    if (localPath == null || localPath.isEmpty) return;

    if (packageKey != null &&
        packageKey.isNotEmpty &&
        packageKey == state._offlineBasemapPackageKey) {
      return;
    }
    if ((packageKey == null || packageKey.isEmpty) &&
        localPath == state._offlineBasemapPath) {
      return;
    }

    await _applyOfflineBasemapPackageStateImpl(state, package);
    if (packageKey != null && packageKey.isNotEmpty) {
      debugPrint('[BASEMAP] Offline package switched by camera: $packageKey');
    }
  } finally {
    state._isSelectingOfflineBasemapForCamera = false;
  }
}

Future<void> _applyOfflineBasemapPackageStateImpl(
  _HomePageState state,
  Map<String, dynamic>? package,
) async {
  final db = DatabaseHelper();
  final packagePath = package?['local_path']?.toString().trim();
  final packageFormat = package?['format']?.toString().trim();
  final packageKey = package?['package_key']?.toString().trim();
  final activeZoneId = package?['zone_id']?.toString().trim();
  final embeddedZone = package?['zone'];
  final activeZone = embeddedZone is Map
      ? Map<String, dynamic>.from(embeddedZone)
      : activeZoneId == null || activeZoneId.isEmpty
          ? null
          : await db.getOfflineBasemapZoneById(activeZoneId);
  final localPath =
      (packagePath != null && packagePath.isNotEmpty) ? packagePath : null;

  if (!state.mounted) return;

  state._setStateFromPart(() {
    if (localPath != null && localPath.isNotEmpty) {
      state._offlineBasemapPath = localPath;
      state._offlineBasemapFormat = packageFormat;
      state._offlineBasemapPackageKey = packageKey;
      state._basemapUnavailableMessage = null;
    } else if (state._offlineBasemapPath == null ||
        state._offlineBasemapPath!.isEmpty) {
      state._offlineBasemapPackageKey = null;
      state._basemapUnavailableMessage = BasemapConstants.unavailableMessage;
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
  await _applyOnlineStatusImpl(state, reachable);
}

Future<bool> _refreshOnlineStatusForNetworkActionImpl(_HomePageState state) async {
  final reachable = await _isApiReachableForStatusImpl();
  await _applyOnlineStatusImpl(state, reachable);
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

Future<void> _autoStartNmeaBridgeIfConfiguredImpl(_HomePageState state) async {
  if (!Platform.isAndroid) return;
  if (!state.mounted) return;

  try {
    final bridge = NmeaBridgeService();
    final status = await bridge.getStatus();
    if (!status.mockLocationSelected) {
      print('[NMEA] Auto-connect ignore: SRM Collecte non selectionnee en position fictive');
      return;
    }

    if (!_isNmeaBridgeDisconnectedStatus(status.status)) {
      print('[NMEA] Auto-connect ignore: pont deja actif (${status.status})');
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
      print('[NMEA] Auto-connect ignore: permissions Bluetooth non accordees');
      return;
    }

    final device = await bridge.resolveAutoConnectDevice();
    if (device == null) {
      print('[NMEA] Auto-connect ignore: aucun GNSS appaire reconnu');
      return;
    }

    await bridge.connectBluetooth(device.address);
    print('[NMEA] Auto-connect lance vers ${device.label}');
    state.homeController.markNmeaBridgePending(deviceLabel: device.label);
    _startNmeaBridgeWatchImpl(state);
    unawaited(_centerOnNmeaFirstFixImpl(state, bridge));
  } catch (e) {
    print('[NMEA] Auto-connect echec: $e');
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
        print('[NMEA] Suivi pont GNSS ignore: $e');
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
      print('[NMEA] Attente premier fix GNSS: $e');
    }

    await Future.delayed(retryDelay);
  }

  print('[NMEA] Aucun fix GNSS exploitable recu pour recentrage automatique');
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
  final bluetoothAddress =
      nativeLocation?['bluetoothAddress']?.toString() ?? status.bluetoothAddress;
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
    print('[NMEA] Carte recentree sur fix GNSS externe source=nmea_bridge');
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
