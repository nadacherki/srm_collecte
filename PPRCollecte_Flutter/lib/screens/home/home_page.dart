// ============================================================
// lib/screens/home/home_page.dart
// ============================================================

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ============================================================
// WIDGETS
// ============================================================
import '../../widgets/common/top_bar_widget.dart';
import '../../widgets/common/bottom_buttons_widget.dart';
import '../../widgets/common/bottom_status_bar_widget.dart';
import '../../widgets/map/map_widget.dart';
import '../../widgets/map/map_controls_widget.dart';
import '../../widgets/map/legend_widget.dart';
import '../../widgets/status/collection_status_widgets.dart';
import '../../widgets/forms/provisional_form_dialog.dart';

// ============================================================
// CONTROLLERS
// ============================================================
import '../../controllers/home_controller.dart';

// ============================================================
// SERVICES
// ============================================================
import '../../services/sync_service.dart';
import '../../services/collection_manager.dart';

// ============================================================
// DATA
// ============================================================
import '../../data/local/database_helper.dart';
import '../../data/local/line_storage_helper.dart';
import '../../data/remote/api_service.dart';

// ============================================================
// MODELS
// ============================================================
import '../../models/map_overlay_tap_data.dart';

// ============================================================
// SCREENS
// ============================================================
import '../auth/login_page.dart';
import '../data/data_categories_page.dart';
import '../forms/special_line_form_page.dart';
import '../forms/formulaire_ligne_page.dart';
import '../forms/polygon_form_page.dart';
import '../../services/special_lines_service.dart';
import '../../services/displayed_points_service.dart';
import '../../services/offline_basemap_service.dart';
import '../../services/downloaded_lines_service.dart';
import '../../core/constants/basemap_constants.dart';

import '../../core/config/srm_config.dart';
import '../../widgets/forms/srm_metier_selector.dart';
import '../../widgets/forms/srm_point_form_widget.dart';
import '../forms/srm_ligne_form_page.dart';

part 'home_page_tap_handlers.dart';
part 'home_page_dialogs.dart';
part 'home_page_overlays.dart';
part 'home_page_collection_actions.dart';
part 'home_page_bootstrap.dart';
part 'home_page_app_actions.dart';

class MapFocusTarget {
  final String kind; // 'point' | 'polyline'
  final String pointStyle;
  final LatLng? point;
  final List<LatLng>? polyline;
  final String? label;
  final String? id;

  const MapFocusTarget.point({
    required LatLng this.point,
    this.label,
    this.id,
    this.pointStyle = 'normal',
  })  : kind = 'point',
        polyline = null;

  const MapFocusTarget.polyline({
    required List<LatLng> this.polyline,
    this.label,
    this.id,
  })  : kind = 'polyline',
        point = null,
        pointStyle = 'normal';
}

class HomePage extends StatefulWidget {
  static MapFocusTarget? pendingFocusTarget;
  final Function onLogout;
  final String agentName;
  final bool isOnline;
  final MapFocusTarget? initialFocus;
  final String? initialOfflineBasemapPath;
  final String? initialOfflineBasemapFormat;
  final String? initialBasemapNotice;
  const HomePage({
    super.key,
    required this.onLogout,
    required this.agentName,
    required this.isOnline,
    this.initialFocus,
    this.initialOfflineBasemapPath,
    this.initialOfflineBasemapFormat,
    this.initialBasemapNotice,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng? userPosition;
  bool gpsEnabled = true;
  String _regionNom = '----';
  String _prefectureNom = '----';
  String _communeNom = '----';

  DateTime? _suspendAutoCenterUntil;
  bool _autoCenterDisabledByUser = false;
  List<Marker> collectedMarkers = [];
  List<Polyline> collectedPolylines = [];
  List<Polyline> _finishedLines = [];
  List<Marker> formMarkers = [];
  bool isSyncing = false;
  bool isDownloading = false;
  SyncResult? lastSyncResult;
  double _progressValue = 0.0;
  String _currentOperation = "Préparation de la sauvegarde...";
  int _totalItems = 0;
  int _processedItems = 0;
  double _syncProgressValue = 0.0;
  String _currentSyncOperation = "Préparation de la synchronisation...";
  int _syncTotalItems = 0;
  int _syncProcessedItems = 0;
  final List<Marker> _focusOverlayMarkers = [];
  final List<Polyline> _focusOverlayPolylines = [];
  bool _isSpecialCollection = false;
  String? _specialCollectionType;
  bool _isPolygonCollection = false;
  List<Polygon> _displayedPolygons = [];
  Map<String, List<Polygon>> _displayedSrmPolygonsByTable = {};
  List<LatLng>? _pendingPolygonPreviewPoints;
  bool _isLegendExpanded = false;
  Map<String, int> _pointCountsByTable = {};
  Map<String, int> _anomalieCountsByTable = {};
  Map<String, int> _incompletCountsByTable = {};
  MapController? _mapController;
  LatLng? _lastCameraPosition;
  late final HomeController homeController;
  final DisplayedPointsService _pointsService = DisplayedPointsService();
  final SpecialLinesService _specialLinesService = SpecialLinesService();
  List<Polyline> _displayedSpecialLines = [];
  Map<String, List<Polyline>> _displayedSrmLinesByTable = {};
  bool _showDownloadedPoints = true;
  Map<String, List<Marker>> _displayedPointsByTable = {};
  Map<String, List<Marker>> _displayedAnomalieByTable = {};
  Map<String, List<Marker>> _displayedIncompletByTable = {};
  Map<String, List<Marker>> _downloadedPointsByTable = {};
  final bool _isSatellite = false;
  List<Polyline> _downloadedSpecialLinesPolylines = [];
  bool _showDownloadedSpecialLines = true;

  SrmSelection? _pendingSrmLigneSelection;


  final DownloadedLinesService _downloadedLinesService = DownloadedLinesService();
  List<Polyline> _downloadedLinesPolylines = [];
  bool _showDownloadedLines = true; // comme pour les points
  bool get _autoCenterSuspended => _autoCenterDisabledByUser || (_suspendAutoCenterUntil != null && DateTime.now().isBefore(_suspendAutoCenterUntil!));
  String? _lastSyncTimeText;
  String? _offlineBasemapPath;
  String? _offlineBasemapFormat;
  String? _basemapUnavailableMessage;
  LatLng? _offlineBasemapCenter;
  LatLngBounds? _offlineBasemapBounds;
  double? _offlineBasemapDefaultZoom;
  double? _offlineBasemapMinZoom;
  double? _offlineBasemapMaxZoom;
  late bool _isOnlineDynamic;
  Timer? _onlineWatchTimer;
// Dans _HomePageState
  Map<String, bool> _legendVisibility = {
    'points': true,
    'lines': true,
    'line_bitume': true,
    'line_terre': true,
    'line_laterite': true,
    'line_bouwal': true,
    'line_deviation': true,
    'line_coupure': true,
    'line_submersible': true,
    'line_col': true,
    'line_autre': true,
    'bac': true,
    'passage_submersible': true,
    'zone_plaine': true,
  };
  String enqueteurDisplayByStatut({
    required String? enqueteurValue,
    required String statut,
  }) {
    final v = (enqueteurValue ?? '').trim();

    if (v.isNotEmpty && v.toLowerCase() != 'null' && v.toLowerCase() != 'sync') {
      return v;
    }

    final isLocal = statut.toLowerCase().contains('localement');
    if (isLocal) {
      final a = widget.agentName.trim();
      if (a.isNotEmpty) return a;
    }

    return '-----';
  }

  @override
  void initState() {
    super.initState();
    _offlineBasemapPath = widget.initialOfflineBasemapPath;
    _offlineBasemapFormat = widget.initialOfflineBasemapFormat;
    _basemapUnavailableMessage = _offlineBasemapPath == null
        ? BasemapConstants.unavailableMessage
        : null;
    _offlineBasemapCenter = BasemapConstants.fallbackCenter;
    _offlineBasemapBounds = BasemapConstants.fallbackBounds;
    _offlineBasemapDefaultZoom = BasemapConstants.fallbackDefaultZoom;
    _offlineBasemapMinZoom = BasemapConstants.fallbackMinZoom;
    _offlineBasemapMaxZoom = BasemapConstants.fallbackMaxZoom;
    homeController = HomeController();
    //_cleanupDisplayedPoints();
    _loadDisplayedLines();
    _loadDisplayedPoints();
    _loadDisplayedSpecialLines();
    _loadDownloadedPoints();
    _loadDownloadedLineOverlays();
    _isOnlineDynamic = widget.isOnline;
    homeController.setSyncAvailability(_isOnlineDynamic);
    _loadLastSyncTime();
    _startOnlineWatcher();
    _loadAdminNamesOffline();
    _loadDownloadedSpecialLines();
    _loadDisplayedPolygons();
    _hydrateOfflineBasemapState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialBasemapNoticeIfNeeded();
    });

    homeController.addListener(
      () {
        setState(
          () {
            userPosition = homeController.userPosition;
            gpsEnabled = homeController.gpsEnabled;
            formMarkers = homeController.formMarkers;
          },
        );

        if (_mapController != null && _lastCameraPosition == null && userPosition != null) {
          _mapController!.move(userPosition!, 17);
          _lastCameraPosition = userPosition;
        } else {
          _moveCameraIfNeeded();
        }
      },
    );

    homeController.initialize();

    _checkPausedCollectionDraft();

    /* collectedMarkers.addAll([
      Marker(
        markerId: const MarkerId('poi1'),
        position: const LatLng(34.021, -6.841),
        infoWindow: const InfoWindow(title: 'Point d\'int?r?t 1', snippet: 'Infrastructure - Point'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    ]);*/

    /* collectedPolylines.add(const Polyline(
      polylineId: PolylineId('line1'),
      points: [
        LatLng(34.020, -6.840),
        LatLng(34.022, -6.842),
        LatLng(34.023, -6.843),
      ],
      color: Colors.blue,
      width: 3,
    ));*/
  }

  // ------------------------------------------------------
  // ------------------------------------------------------

  void _setStateFromPart(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<void> _checkPausedCollectionDraft() =>
      _checkPausedCollectionDraftImpl(this);

  void _restorePausedCollection(Map<String, dynamic> draft) =>
      _restorePausedCollectionImpl(this, draft);

  Future<void> _hydrateOfflineBasemapState() =>
      _hydrateOfflineBasemapStateImpl(this);

  void _showInitialBasemapNoticeIfNeeded() =>
      _showInitialBasemapNoticeIfNeededImpl(this);

  Future<void> _loadDownloadedSpecialLines() =>
      _loadDownloadedSpecialLinesImpl(this);



  void _showSpecialLineDetailsSheet({
    required BuildContext context,
    required String specialType,
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
  }) => _showSpecialLineDetailsSheetImpl(
        this,
        context: context,
        specialType: specialType,
        statut: statut,
        enqueteur: enqueteur,
        region: region,
        prefecture: prefecture,
        commune: commune,
        distanceKm: distanceKm,
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
      );

  void _showLineDetailsSheet({
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
    String? projet,
    String? entreprise,
  }) => _showLineDetailsSheetImpl(
        this,
        context: context,
        lineCode: lineCode,
        enqueteur: enqueteur,
        region: region,
        prefecture: prefecture,
        commune: commune,
        statut: statut,
        nbPoints: nbPoints,
        startLat: startLat,
        startLng: startLng,
        endLat: endLat,
        endLng: endLng,
        distanceKm: distanceKm,
        plateforme: plateforme,
        relief: relief,
        vegetation: vegetation,
        debutTravaux: debutTravaux,
        finTravaux: finTravaux,
        financement: financement,
        projet: projet,
        entreprise: entreprise,
      );

  void _showPointDetailsSheet({
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
  }) => _showPointDetailsSheetImpl(
        this,
        context: context,
        type: type,
        name: name,
        region: region,
        prefecture: prefecture,
        commune: commune,
        enqueteur: enqueteur,
        lineCode: lineCode,
        lat: lat,
        lng: lng,
        statut: statut,
      );

  void _handlePolylineTap(Object? hitValue) =>
      _handlePolylineTapImpl(this, hitValue);

  void _handlePolygonTap(Object? hitValue) =>
      _handlePolygonTapImpl(this, hitValue);

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAdminNamesOffline() =>
      _loadAdminNamesOfflineImpl(this);

  void _suspendAutoCenterFor(Duration d) =>
      _suspendAutoCenterForImpl(this, d);

  void _startOnlineWatcher() =>
      _startOnlineWatcherImpl(this);


  bool _isSrmTableVisible(String tableName) {
    final entityKey = 'srm_$tableName';
    if (_legendVisibility.containsKey(entityKey)) {
      return _legendVisibility[entityKey] != false;
    }

    for (final metier in SrmConfig.getMetiers()) {
      for (final entity in SrmConfig.getEntitiesForMetier(metier)) {
        if (SrmConfig.getTableName(metier, entity) == tableName) {
          final metierKey = 'srm_metier_$metier';
          if (_legendVisibility.containsKey(metierKey)) {
            return _legendVisibility[metierKey] != false;
          }
          return true;
        }
      }
    }

    return true;
  }

  List<Polyline> _getFilteredPolylines() {
    final List<Polyline> filtered = List<Polyline>.from(collectedPolylines);
    if (_legendVisibility['lines'] == true) {
      filtered.addAll(_finishedLines);
    }

    if (_legendVisibility['lines'] == true && _showDownloadedLines) {
      filtered.addAll(_downloadedLinesPolylines);
    }

    final bool anomalieFilterOn = _legendVisibility['srm_anomalie'] == true;
    final bool incompletFilterOn = _legendVisibility['srm_incomplet'] == true;

    if (!(anomalieFilterOn || incompletFilterOn)) {
      for (final entry in _displayedSrmLinesByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          filtered.addAll(entry.value);
        }
      }
    }

    for (final l in _displayedSpecialLines) {
      final color = l.color;
      final isBac = color == Colors.purple;
      final isPassage = color == Colors.cyan;

      if (isBac && (_legendVisibility['bac'] == true)) {
        filtered.add(l);
      } else if (isPassage &&
          (_legendVisibility['passage_submersible'] == true)) {
        filtered.add(l);
      }
    }

    if (_showDownloadedSpecialLines) {
      for (final l in _downloadedSpecialLinesPolylines) {
        // flutter_map n'a pas d'ID sur Polyline, on utilise la couleur pour identifier
        final color = l.color;

        // Bac = purple, Passage submersible = cyan
        final isBac = color == Colors.purple;
        final isPassage = color == Colors.cyan;

        if (isBac && (_legendVisibility['bac'] == true)) {
          filtered.add(l);
        } else if (isPassage && (_legendVisibility['passage_submersible'] == true)) {
          filtered.add(l);
        } else if (!isBac && !isPassage) {
          filtered.add(l);
        }
      }
    }

    // 6. Lignes en cours (TOUJOURS visibles)
    // Ligne en cours
    if (homeController.ligneCollection != null) {
      final lignePoints = homeController.ligneCollection!.points;
      if (lignePoints.length > 1) {
        filtered.add(
          Polyline(
            points: lignePoints,
            color: homeController.ligneCollection!.isPaused ? Colors.orange : Colors.green,
            strokeWidth: 4.0,
            pattern: homeController.ligneCollection!.isPaused
                ? StrokePattern.dashed(segments: const [
                    10,
                    5
                  ])
                : const StrokePattern.solid(),
          ),
        );
      }
    }

    if (homeController.specialCollection != null) {
      final specialPoints = homeController.specialCollection!.points;
      if (specialPoints.length > 1) {
        if (_isPolygonCollection) {
          // Zone de Plaine : afficher comme POLYGONE semi-transparent
          // (on ajoute le contour comme polyline + le polygone sera dans _displayedPolygons)
          filtered.add(
            Polyline(
              points: [
                ...specialPoints,
                specialPoints.first
              ], // fermer le contour
              color: const Color(0xFF2E7D32),
              strokeWidth: 3.0,
              pattern: const StrokePattern.solid(),
            ),
          );
        } else {
          // Bac / Passage : afficher comme LIGNE
          final specialColor = _specialCollectionType == "Bac" ? Colors.purple : Colors.deepPurple;
          filtered.add(
            Polyline(
              points: specialPoints,
              color: specialColor,
              strokeWidth: 5.0,
              pattern: homeController.specialCollection!.isPaused
                  ? StrokePattern.dashed(segments: const [
                      10,
                      5
                    ])
                  : const StrokePattern.solid(),
            ),
          );
        }
      }
    }
    filtered.addAll(_focusOverlayPolylines);
    return filtered;
  }

  List<Marker> _getFilteredMarkers() {
    final bool anomalieFilterOn = _legendVisibility['srm_anomalie'] == true;
    final bool incompletFilterOn = _legendVisibility['srm_incomplet'] == true;
    final List<Marker> filtered = <Marker>[];

    // === Mode isolement anomalie ===
    if (anomalieFilterOn && !incompletFilterOn) {
      for (final entry in _displayedAnomalieByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          filtered.addAll(entry.value);
        }
      }
      return filtered;
    }

    // === Mode isolement incomplet ===
    if (incompletFilterOn && !anomalieFilterOn) {
      for (final entry in _displayedIncompletByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          filtered.addAll(entry.value);
        }
      }
      return filtered;
    }

    // === Mode isolement anomalie + incomplet ===
    if (anomalieFilterOn && incompletFilterOn) {
      final Set<Marker> combined = {};
      for (final entry in _displayedAnomalieByTable.entries) {
        if (_isSrmTableVisible(entry.key)) combined.addAll(entry.value);
      }
      for (final entry in _displayedIncompletByTable.entries) {
        if (_isSrmTableVisible(entry.key)) combined.addAll(entry.value);
      }
      return combined.toList();
    }

    for (final entry in _displayedPointsByTable.entries) {
      final tableName = entry.key;
      final srmKey = 'srm_$tableName';
      final pointKey = 'point_$tableName';
      final isVisible = _legendVisibility.containsKey(srmKey)
          ? _isSrmTableVisible(tableName)
          : (_legendVisibility[pointKey] ?? true);
      if (!isVisible) continue;
      filtered.addAll(entry.value);
    }

    if (_showDownloadedPoints) {
      for (final entry in _downloadedPointsByTable.entries) {
        final subKey = 'point_${entry.key}';
        if (_legendVisibility[subKey] != false) {
          filtered.addAll(entry.value);
        }
      }
    }

    return filtered;
  }

  void _updateVisibilityFromLegend(Map<String, bool> visibility) {
    setState(() {
      _legendVisibility = visibility;
      _showDownloadedPoints = visibility['points'] ?? true;
      _showDownloadedLines = visibility['lines'] ?? true;

      // Bac + Passage submersible
      final showBac = visibility['bac'] ?? true;
      final showPassage = visibility['passage_submersible'] ?? true;
      _showDownloadedSpecialLines = showBac || showPassage;

      // Zone de plaine
      if (visibility['zone_plaine'] == false) {
        _displayedPolygons = [];
      } else {
        _loadDisplayedPolygons();
      }
    });
  }

  Future<void> _checkOnlineStatus() =>
      _checkOnlineStatusImpl(this);

  Future<void> _loadLastSyncTime() =>
      _loadLastSyncTimeImpl(this);

  String _formatTimeHHmm(DateTime dt) =>
      _formatTimeHHmmImpl(dt);

  Future<void> _loadDownloadedLineOverlays() =>
      _loadDownloadedLineOverlaysImpl(this);


  double polylineDistanceKm(List<LatLng> pts) =>
      _polylineDistanceKmImpl(pts);



  Future<void> _focusOnTarget(MapFocusTarget target) =>
      _focusOnTargetImpl(this, target);

  Future<void> _refreshAllPoints() async {
    await _loadDisplayedPoints(); // Points locaux (rouges)
    await _loadDownloadedPoints();
    await _loadDownloadedLineOverlays();
  }

  Future<void> _loadDownloadedPoints() =>
      _loadDownloadedPointsImpl(this);

  Future<void> _refreshAfterNavigation() async {
    await _loadDisplayedSpecialLines();
    await _refreshAllPoints();
  }

  Future<void> _loadDisplayedSpecialLines() =>
      _loadDisplayedSpecialLinesImpl(this);

  // Dans _HomePageState
  // Remplacer startSpecialLineCollection par :
  Future<void> startSpecialCollection(String type) =>
      _startSpecialCollectionImpl(type);

  // Remplacer finishSpecialLigneCollection par :
  Future<void> finishSpecialCollection() =>
      _finishSpecialCollectionImpl();

  Future<void> cancelSpecialCollection() =>
      _cancelSpecialCollectionImpl();

  Future<void> _loadDisplayedPolygons() =>
      _loadDisplayedPolygonsImpl(this);

  bool _containsPolygonPreview(
    List<Polygon> polygons,
    List<LatLng> previewPoints,
  ) =>
      _containsPolygonPreviewImpl(polygons, previewPoints);


  Future<String> generateLineCode() async {
    // horodatage YYYYMMDDhhmmssSSS
    final now = DateTime.now();
    final ts = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}'
        '${now.millisecond.toString().padLeft(3, '0')}';

    // Sprint 4: SRM utilise id_projet, id_mission, id_agent au lieu de commune/prefecture/region.
    final projetId = ApiService.currentProjetId ?? 0;
    final agentId = ApiService.userId ?? 0;

    final code = 'Line_${projetId}_${agentId}_$ts';
    return code;
  }

  Future<void> _loadDisplayedPoints() =>
      _loadDisplayedPointsImpl(this);

  Future<void> _loadPointCountsByTable() =>
      _loadPointCountsByTableImpl(this);

  void _onMapCreated(MapController controller) =>
      _onMapCreatedImpl(this, controller);

  void _moveCameraIfNeeded() =>
      _moveCameraIfNeededImpl(this);

  // === SPRINT 5 : COLLECTE POINT SRM (EP / ASS / ELEC) ===
  Future<void> addPointOfInterest() =>
      _addPointOfInterestImpl();


  // === SPRINT 5 : COLLECTE LIGNE SRM ===
  Future<void> startLigneSrmCollection() =>
      _startLigneSrmCollectionImpl();



// === COLLECTE POLYGONE (Zone de Plaine) ===
  String? _pendingSrmPolygoneMetier;
  String? _pendingSrmPolygoneEntityType;

  Future<void> startPolygonCollection({
    String? metier,
    String? entityType,
  }) =>
      _startPolygonCollectionImpl(
        metier: metier,
        entityType: entityType,
      );

  Future<void> startLigneCollection() =>
      _startLigneCollectionImpl();

  void toggleSpecialCollection() =>
      _toggleSpecialCollectionImpl();

  void toggleLigneCollection() =>
      _toggleLigneCollectionImpl();

  Future<void> finishLigneCollection() =>
      _finishLigneCollectionImpl();

  Future<void> cancelLigneCollection() =>
      _cancelLigneCollectionImpl();


  // Dans la classe _HomePageState
  Future<void> _loadDisplayedLines() =>
      _loadDisplayedLinesImpl(this);


  void _showSyncConfirmationDialog() =>
      _showSyncConfirmationDialogImpl(this);


  void _showSyncResult(SyncResult result) =>
      _showSyncResultImpl(this, result);


  void _showSaveConfirmationDialog() =>
      _showSaveConfirmationDialogImpl(this);


  void _showDownloadResult(
    SyncResult result, {
    required bool alreadyDownloaded,
    required bool nothingAvailable,
  }) =>
      _showDownloadResultImpl(
        this,
        result,
        alreadyDownloaded: alreadyDownloaded,
        nothingAvailable: nothingAvailable,
      );

  double _coordinateDistance(
    lat1,
    lon1,
    lat2,
    lon2,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        (cos(
              (lat2 - lat1) * p,
            ) /
            2) +
        cos(
              lat1 * p,
            ) *
            cos(
              lat2 * p,
            ) *
            (1 -
                cos(
                  (lon2 - lon1) * p,
                )) /
            2;
    return 12742000 *
        asin(
          sqrt(
            a,
          ),
        );
  }

  @override
  void dispose() {
    homeController.dispose();
    _onlineWatchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final List<Marker> filteredMarkers = _getFilteredMarkers()..addAll(_focusOverlayMarkers);

    final List<Polyline> filteredPolylines = _getFilteredPolylines()..addAll(_focusOverlayPolylines);
    List<Polygon> filteredPolygons = (_legendVisibility['zone_plaine'] != false)
        ? _displayedPolygons
            .where((p) => !_displayedSrmPolygonsByTable.values.any((list) => list.contains(p)))
            .toList()
        : <Polygon>[];
    for (final entry in _displayedSrmPolygonsByTable.entries) {
      if (_isSrmTableVisible(entry.key)) {
        filteredPolygons.addAll(entry.value);
      }
    }
    if (homeController.specialCollection != null) {
      final specialPoints = homeController.specialCollection!.points;
      if (specialPoints.length > 1) {
        if (_isPolygonCollection) {
          filteredPolylines.add(
            Polyline(
              points: [
                ...specialPoints,
                specialPoints.first
              ],
              color: const Color(0xFF2E7D32),
              strokeWidth: 3.0,
              pattern: const StrokePattern.solid(),
            ),
          );
        } else {
          final specialColor = _specialCollectionType == "Bac" ? Colors.purple : Colors.deepPurple;
          filteredPolylines.add(
            Polyline(
              points: specialPoints,
              color: specialColor,
              strokeWidth: 5.0,
              pattern: homeController.specialCollection!.isPaused
                  ? StrokePattern.dashed(segments: const [
                      10,
                      5
                    ])
                  : const StrokePattern.solid(),
            ),
          );
        }
      }
    }
// === AFFICHER LE POLYGONE EN COURS DE COLLECTE ===
    if (_isPolygonCollection && homeController.specialCollection != null) {
      final polyPoints = homeController.specialCollection!.points;
      if (polyPoints.length >= 3) {
        filteredPolygons.add(
          Polygon(
            points: polyPoints,
            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
            borderColor: const Color(0xFF1B5E20),
            borderStrokeWidth: 3.0,
          ),
        );
      }
    }

    final previewPoints = _pendingPolygonPreviewPoints;
    if (previewPoints != null &&
        previewPoints.length >= 3 &&
        !_containsPolygonPreview(filteredPolygons, previewPoints)) {
      filteredPolygons.add(
        Polygon(
          points: previewPoints,
          color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
          borderColor: const Color(0xFF1B5E20),
          borderStrokeWidth: 3.0,
        ),
      );
    }
    // Ajouter la ligne en cours si active
    if (homeController.ligneCollection != null) {
      final lignePoints = homeController.ligneCollection!.points;
      if (lignePoints.length > 1) {
        filteredPolylines.add(
          Polyline(
            points: lignePoints,
            color: homeController.ligneCollection!.isPaused ? Colors.orange : Colors.green,
            strokeWidth: 4.0,
            pattern: homeController.ligneCollection!.isPaused
                ? StrokePattern.dashed(segments: const [
                    10,
                    5
                  ])
                : const StrokePattern.solid(),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(
        0xFFF0F8FF,
      ),
      body: SafeArea(
        child: Column(
          children: [
            TopBarWidget(
                agentName: widget.agentName,
                onLogout: _showLogoutConfirmation,
                onReturnFromProfile: _hydrateOfflineBasemapState,
              ),
            Expanded(
              child: Stack(
                children: [
                  MapWidget(
                    userPosition: userPosition ?? homeController.userPosition,
                    gpsEnabled: gpsEnabled,
                    markers: filteredMarkers,
                    polylines: filteredPolylines,
                    polygons: filteredPolygons,
                    onPolygonTap: _handlePolygonTap,
                    onMapCreated: _onMapCreated,
                    formMarkers: formMarkers,
                    isSatellite: _isSatellite,
                    onPolylineTap: _handlePolylineTap,
                    offlineBasemapPath: _offlineBasemapPath,
                    offlineBasemapFormat: _offlineBasemapFormat,
                    basemapUnavailableMessage: _basemapUnavailableMessage,
                    basemapCenter: _offlineBasemapCenter,
                    basemapBounds: _offlineBasemapBounds,
                    basemapDefaultZoom: _offlineBasemapDefaultZoom,
                    basemapMinZoom: _offlineBasemapMinZoom,
                    basemapMaxZoom: _offlineBasemapMaxZoom,
                    onUserInteraction: () {
                      _autoCenterDisabledByUser = true;
                    },
                    onGpsButtonPressed: () {
                      _autoCenterDisabledByUser = false;
                    },
                  ),
                  LegendWidget(
                    initialVisibility: _legendVisibility,
                    onVisibilityChanged: _updateVisibilityFromLegend,
                    allPolylines: filteredPolylines,
                    allMarkers: filteredMarkers,
                    polygonCount: _displayedPolygons.length,
                    pointCountsByTable: _pointCountsByTable,
                    anomalieCountsByTable: _anomalieCountsByTable,
                    incompletCountsByTable: _incompletCountsByTable,
                    onExpandedChanged: (expanded) {
                      setState(() => _isLegendExpanded = expanded);
                    },
                  ),
                  if (isSyncing)
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 3,
                        sigmaY: 3,
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.2),
                      ),
                    ),

                  if (isDownloading)
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 3,
                        sigmaY: 3,
                      ),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.2),
                      ),
                    ),

                  Positioned(
                    bottom: 280,
                    right: 16,
                    child: Visibility(
                      visible: kDebugMode && !_isLegendExpanded,
                      child: FloatingActionButton(
                        onPressed: _showMockLocationDialogSafe,
                        backgroundColor: homeController.isMockLocationEnabled
                            ? Colors.teal
                            : Colors.blueGrey,
                        mini: true,
                        heroTag: 'mock_gps_button',
                        child: Icon(
                          homeController.isMockLocationEnabled
                              ? Icons.gps_fixed
                              : Icons.edit_location_alt,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (!_isLegendExpanded)
                    MapControlsWidget(
                        controller: homeController,
                        onAddPoint: addPointOfInterest,
                        onStartLigne: startLigneSrmCollection, // Sprint 5: SRM
                        onStartPolygon: startPolygonCollection,
                        onToggleLigne: toggleLigneCollection,
                        onTogglePolygon: toggleSpecialCollection,
                        onFinishLigne: finishLigneCollection,
                        onFinishPolygon: finishSpecialCollection,
                        onCancelLigne: cancelLigneCollection,
                        onCancelPolygon: cancelSpecialCollection,
                        onRefresh: _loadDisplayedPoints,
                        isSpecialCollection: _isSpecialCollection,
                        onStopSpecial: finishSpecialCollection,
                        isPolygonCollection: _isPolygonCollection,
                    ),
                  // === WIDGETS DE STATUT (NOUVEAU SYSTEME UNIQUEMENT) ===

                // Afficher le statut de ligne si active
                  if (homeController.ligneCollection != null)
                    LigneStatusWidget(
                      collection: homeController.ligneCollection!,
                      topOffset: 16,
                    ),

                  if (homeController.specialCollection != null)
                    SpecialStatusWidget(
                      collection: homeController.specialCollection!,
                      topOffset: homeController.ligneCollection != null ? 70 : 16,
                    ),

                  // DataCountWidget(count: collectedMarkers.length + collectedPolylines.length),
                  // Remplacez le Positioned actuel par ceci :
                  if (isDownloading)
                    Positioned(
                      top: 70, // Position sous la barre d'outils
                      left: 0,
                      right: 0,
                      child: AnimatedSlide(
                        duration: const Duration(
                          milliseconds: 300,
                        ),
                        curve: Curves.easeOut,
                        offset: isDownloading
                            ? Offset.zero
                            : const Offset(
                                0,
                                -1,
                              ),
                        child: AnimatedOpacity(
                          duration: const Duration(
                            milliseconds: 300,
                          ),
                          opacity: isDownloading ? 1.0 : 0.0,
                          child: _buildProgressIndicator(),
                        ),
                      ),
                    ),
                  if (isSyncing)
                    Positioned(
                      top: 70, // Position sous la top bar
                      left: 0,
                      right: 0,
                      child: AnimatedSlide(
                        duration: const Duration(
                          milliseconds: 300,
                        ),
                        curve: Curves.easeOut,
                        offset: isSyncing
                            ? Offset.zero
                            : const Offset(
                                0,
                                -1,
                              ),
                        child: AnimatedOpacity(
                          duration: const Duration(
                            milliseconds: 300,
                          ),
                          opacity: isSyncing ? 1.0 : 0.0,
                          child: _buildSyncProgressIndicator(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            BottomStatusBarWidget(
              gpsEnabled: gpsEnabled,
              isOnline: _isOnlineDynamic,
              lastSyncTime: _lastSyncTimeText,
            ),
            BottomButtonsWidget(
              onSave: isDownloading ? () {} : _showSaveConfirmationDialog,
              onSync: isSyncing ? () {} : _showSyncConfirmationDialog,
              onMenu: handleMenuPress,
            ),
          ],
        ),
      ),
    );
  }
}

