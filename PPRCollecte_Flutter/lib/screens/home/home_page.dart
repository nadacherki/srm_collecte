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
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================
// WIDGETS
// ============================================================
import '../../widgets/common/top_bar_widget.dart';
import '../../widgets/common/bottom_buttons_widget.dart';
import '../../widgets/common/bottom_status_bar_widget.dart';
import '../../widgets/common/custom_marker_icons.dart';
import '../../widgets/map/map_widget.dart';
import '../../widgets/map/map_controls_widget.dart';
import '../../widgets/map/legend_widget.dart';
import '../../widgets/status/collection_status_widgets.dart';

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
import '../../models/collection_models.dart';
import '../../models/map_overlay_tap_data.dart';

// ============================================================
// SCREENS
// ============================================================
import '../auth/login_page.dart';
import '../data/data_categories_page.dart';
import '../forms/polygon_form_page.dart';
import '../../services/srm_lines_service.dart';
import '../../services/displayed_points_service.dart';
import '../../services/offline_basemap_service.dart';
import '../../services/downloaded_lines_service.dart';
import '../../services/formulaire_config_mobile_service.dart';
import '../../services/attribut_config_mobile_service.dart';
import '../../services/srm_field_option_service.dart';
import '../../services/commune_sync_service.dart';
import '../../services/projection_service.dart';
import '../../core/constants/basemap_constants.dart';
import '../../services/form_lock_service.dart';
import '../../services/nmea_bridge_service.dart';
import '../../services/public_metrics_cache_service.dart';
import '../../services/capture_location_guard.dart';
import '../../services/download_notification_service.dart';
import '../../services/reference_overlay_sync_service.dart';
import '../../services/srm_row_visibility_filter.dart';
import '../../services/srm_status_flags.dart';

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
part 'home_page_conduite_mode.dart';

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

class _ConduiteRegardNode {
  final int nodeId;
  final int? sourceFid;
  final LatLng point;
  final Map<String, dynamic> row;

  const _ConduiteRegardNode({
    required this.nodeId,
    required this.sourceFid,
    required this.point,
    required this.row,
  });
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
  String gpsSourceLabel = 'téléphone';
  String? gpsDetailsLine;
  String _regionNom = '----';
  String _prefectureNom = '----';
  String _communeNom = '----';

  DateTime? _suspendAutoCenterUntil;
  bool _autoCenterDisabledByUser = false;
  List<Marker> collectedMarkers = [];
  List<Polyline> collectedPolylines = [];
  List<Polyline> _finishedLines = [];
  List<Marker> formMarkers = [];
  Map<String, dynamic>? _geometryEditLineItem;
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
  bool _isPolygonCollection = false;
  String? _polygonEntityType;
  final List<CollectionPointEdit> _ligneRedoPoints = [];
  final List<CollectionPointEdit> _polygonRedoPoints = [];
  List<Polygon> _displayedPolygons = [];
  List<Polygon> _referencePlanchePolygons = [];
  List<Polygon> _referenceZonePolygons = [];
  List<Polyline> _referenceFondPlanPolylines = [];
  Map<String, List<Polygon>> _displayedSrmPolygonsByTable = {};
  Map<String, List<Polygon>> _displayedPolygonAnomalieByTable = {};
  Map<String, List<Polygon>> _displayedPolygonIncompletByTable = {};
  List<LatLng>? _pendingPolygonPreviewPoints;
  bool _isLegendExpanded = false;
  Map<String, int> _pointCountsByTable = {};
  Map<String, int> _anomalieCountsByTable = {};
  Map<String, int> _incompletCountsByTable = {};
  Map<String, int> _referenceOverlayCounts = {};
  MapController? _mapController;
  LatLng? _lastCameraPosition;
  late final HomeController homeController;
  final DisplayedPointsService _pointsService = DisplayedPointsService();
  final SrmLinesService _srmLinesService = SrmLinesService();
  Map<String, List<Polyline>> _displayedSrmLinesByTable = {};
  Map<String, List<Polyline>> _displayedLineAnomalieByTable = {};
  Map<String, List<Polyline>> _displayedLineIncompletByTable = {};
  Map<String, List<Marker>> _displayedPointsByTable = {};
  Map<String, List<Marker>> _displayedAnomalieByTable = {};
  Map<String, List<Marker>> _displayedIncompletByTable = {};
  bool _isSatellite = false;

  SrmSelection? _pendingSrmLigneSelection;

  final DownloadedLinesService _downloadedLinesService =
      DownloadedLinesService();
  List<Polyline> _downloadedLinesPolylines = [];
  bool _showDownloadedLines = true; // comme pour les points
  bool get _autoCenterSuspended =>
      _autoCenterDisabledByUser ||
      (_suspendAutoCenterUntil != null &&
          DateTime.now().isBefore(_suspendAutoCenterUntil!));
  bool get _canUseAdminGpsTools =>
      (ApiService.userRole ?? '').trim().toLowerCase() == 'admin';
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
  bool _mobileConfigAutoRefreshRunning = false;
  DateTime? _lastMobileConfigAutoRefreshAt;
  Timer? _nmeaBridgeWatchTimer;
  bool _isConduiteDrawingMode = false;
  String _conduiteModeMetier = 'ep';
  DateTime? _conduiteModeDay;
  List<Marker> _conduiteModeMarkers = [];
  List<Polyline> _conduiteModePolylines = [];
  final Map<int, _ConduiteRegardNode> _conduiteRegardNodesById = {};
  final List<int> _conduiteSelectionHistoryNodeIds = <int>[];
  final List<int> _conduiteRedoStackNodeIds = <int>[];
  final Set<String> _conduiteSegmentKeys = <String>{};
  double _conduitePreviewLengthM = 0.0;
  LatLng? _conduiteCurrentRegardPoint;
  bool _conduiteIsFrozenForDay = false;
  bool _conduiteIsSaving = false;
  String? _conduiteModeError;
  String _conduiteModeStatusText = 'Touchez un regard pour commencer.';
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
    'zone_plaine': true,
    'srm_ep_regard_polygon': true,
    'overlay_zones': true,
    'overlay_planche': false,
    'overlay_fond_plan': false,
  };
  String enqueteurDisplayByStatut({
    required String? enqueteurValue,
    required String statut,
  }) {
    final v = (enqueteurValue ?? '').trim();

    if (v.isNotEmpty &&
        v.toLowerCase() != 'null' &&
        v.toLowerCase() != 'sync') {
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
    _loadDisplayedSrmLines();
    _loadDownloadedLineOverlays();
    _isOnlineDynamic = widget.isOnline;
    homeController.setSyncAvailability(_isOnlineDynamic);
    _loadLastSyncTime();
    _startOnlineWatcher();
    _loadAdminNamesOffline();
    _loadDisplayedPolygons();
    _loadReferenceOverlays();
    unawaited(_refreshReferenceOverlaysForMapStartup());
    _hydrateOfflineBasemapState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInitialBasemapNoticeIfNeeded();
      _autoStartNmeaBridgeIfConfiguredImpl(this);
    });

    homeController.addListener(
      () {
        setState(
          () {
            userPosition = homeController.userPosition;
            gpsEnabled = homeController.gpsEnabled;
            gpsSourceLabel = homeController.gpsSourceLabel;
            gpsDetailsLine = homeController.gpsDetailsLine;
            formMarkers = homeController.formMarkers;
          },
        );

        if (_mapController != null &&
            _lastCameraPosition == null &&
            userPosition != null) {
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

  void _showSrmLineDetailsSheet({
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
  }) =>
      _showSrmLineDetailsSheetImpl(
        this,
        context: context,
        entityType: entityType,
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
        editableItem: editableItem,
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
    String? entreprise,
    Map<String, dynamic>? editableItem,
  }) =>
      _showLineDetailsSheetImpl(
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
        entreprise: entreprise,
        editableItem: editableItem,
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
    Map<String, dynamic>? editableItem,
  }) =>
      _showPointDetailsSheetImpl(
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
        editableItem: editableItem,
      );

  Future<void> _editMapItem(Map<String, dynamic> item) =>
      _editMapItemImpl(this, item);

  Future<void> _editMapGeometry(Map<String, dynamic> item) =>
      _editMapGeometryImpl(this, item);

  void _handlePolylineTap(Object? hitValue) =>
      _handlePolylineTapImpl(this, hitValue);

  void _handlePolygonTap(Object? hitValue) =>
      _handlePolygonTapImpl(this, hitValue);

  void _handlePolygonLongPress(Object? hitValue) =>
      _handlePolygonLongPressImpl(this, hitValue);

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[700], fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAdminNamesOffline() => _loadAdminNamesOfflineImpl(this);

  void _suspendAutoCenterFor(Duration d) => _suspendAutoCenterForImpl(this, d);

  void _startOnlineWatcher() => _startOnlineWatcherImpl(this);

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
    if (_legendVisibility['overlay_fond_plan'] == true) {
      filtered.addAll(_referenceFondPlanPolylines);
    }
    if (_legendVisibility['lines'] == true) {
      filtered.addAll(_finishedLines);
    }

    if (_legendVisibility['lines'] == true && _showDownloadedLines) {
      filtered.addAll(_downloadedLinesPolylines);
    }

    final bool anomalieFilterOn = _legendVisibility['srm_anomalie'] == true;
    final bool incompletFilterOn = _legendVisibility['srm_incomplet'] == true;

    if (anomalieFilterOn && !incompletFilterOn) {
      for (final entry in _displayedLineAnomalieByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          filtered.addAll(entry.value);
        }
      }
    } else if (incompletFilterOn && !anomalieFilterOn) {
      for (final entry in _displayedLineIncompletByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          filtered.addAll(entry.value);
        }
      }
    } else if (anomalieFilterOn && incompletFilterOn) {
      final combined = <Polyline>{};
      for (final entry in _displayedLineAnomalieByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          combined.addAll(entry.value);
        }
      }
      for (final entry in _displayedLineIncompletByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          combined.addAll(entry.value);
        }
      }
      filtered.addAll(combined);
    } else {
      for (final entry in _displayedSrmLinesByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          filtered.addAll(entry.value);
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
            color: homeController.ligneCollection!.isPaused
                ? Colors.orange
                : Colors.green,
            strokeWidth: 4.0,
            pattern: homeController.ligneCollection!.isPaused
                ? StrokePattern.dashed(segments: const [10, 5])
                : const StrokePattern.solid(),
          ),
        );
      }
    }

    if (homeController.polygonCollection != null) {
      final polygonPoints = homeController.polygonCollection!.points;
      if (polygonPoints.length > 1) {
        filtered.add(
          Polyline(
            points: [...polygonPoints, polygonPoints.first],
            color: const Color(0xFF2E7D32),
            strokeWidth: 3.0,
            pattern: const StrokePattern.solid(),
          ),
        );
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
      return _withActiveTraceVertexMarkers(filtered);
    }

    // === Mode isolement incomplet ===
    if (incompletFilterOn && !anomalieFilterOn) {
      for (final entry in _displayedIncompletByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          filtered.addAll(entry.value);
        }
      }
      return _withActiveTraceVertexMarkers(filtered);
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
      return _withActiveTraceVertexMarkers(combined.toList());
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

    return _withActiveTraceVertexMarkers(filtered);
  }

  List<Marker> _withActiveTraceVertexMarkers(List<Marker> markers) {
    return <Marker>[
      ...markers,
      ..._getActiveTraceVertexMarkers(),
    ];
  }

  List<Marker> _getActiveTraceVertexMarkers() {
    final markers = <Marker>[];
    final ligne = homeController.ligneCollection;
    if (ligne != null) {
      markers.addAll(
        _buildTraceVertexMarkers(
          points: ligne.points,
          color: ligne.isPaused ? Colors.orange : Colors.green,
        ),
      );
    }

    final polygon = homeController.polygonCollection;
    if (polygon != null) {
      const polygonColor = Color(0xFF1B5E20);
      markers.addAll(
        _buildTraceVertexMarkers(
          points: polygon.points,
          color: polygon.isPaused ? Colors.orange : polygonColor,
        ),
      );
    }

    return markers;
  }

  List<Marker> _buildTraceVertexMarkers({
    required List<LatLng> points,
    required Color color,
  }) {
    return [
      for (var i = 0; i < points.length; i++)
        _buildTraceVertexMarker(
          point: points[i],
          color: color,
          label: '${i + 1}',
          isLast: i == points.length - 1,
        ),
    ];
  }

  Marker _buildTraceVertexMarker({
    required LatLng point,
    required Color color,
    required String label,
    required bool isLast,
  }) {
    return Marker(
      point: point,
      width: 30,
      height: 30,
      child: IgnorePointer(
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: isLast ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: label.length > 2 ? 9 : 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  List<Polygon> _getFilteredPolygons() {
    final bool anomalieFilterOn = _legendVisibility['srm_anomalie'] == true;
    final bool incompletFilterOn = _legendVisibility['srm_incomplet'] == true;
    final List<Polygon> filtered = <Polygon>[];

    if (_legendVisibility['overlay_zones'] != false) {
      filtered.addAll(_referenceZonePolygons);
    }
    if (_legendVisibility['overlay_planche'] == true) {
      filtered.addAll(_referencePlanchePolygons);
    }

    if (anomalieFilterOn && !incompletFilterOn) {
      for (final entry in _displayedPolygonAnomalieByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          filtered.addAll(entry.value);
        }
      }
      return filtered;
    }

    if (incompletFilterOn && !anomalieFilterOn) {
      for (final entry in _displayedPolygonIncompletByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          filtered.addAll(entry.value);
        }
      }
      return filtered;
    }

    if (anomalieFilterOn && incompletFilterOn) {
      final combined = <Polygon>{};
      for (final entry in _displayedPolygonAnomalieByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          combined.addAll(entry.value);
        }
      }
      for (final entry in _displayedPolygonIncompletByTable.entries) {
        if (_isSrmTableVisible(entry.key)) {
          combined.addAll(entry.value);
        }
      }
      return combined.toList();
    }

    if (_legendVisibility['zone_plaine'] != false) {
      filtered.addAll(
        _displayedPolygons.where(
          (polygon) => !_displayedSrmPolygonsByTable.values.any(
            (list) => list.contains(polygon),
          ),
        ),
      );
    }

    for (final entry in _displayedSrmPolygonsByTable.entries) {
      if (_isSrmTableVisible(entry.key)) {
        filtered.addAll(entry.value);
      }
    }

    return filtered;
  }

  void _updateVisibilityFromLegend(Map<String, bool> visibility) {
    setState(() {
      _legendVisibility = visibility;
      _showDownloadedLines = visibility['lines'] ?? true;
    });
  }

  Future<void> _checkOnlineStatus() => _checkOnlineStatusImpl(this);

  Future<bool> _refreshOnlineStatusForNetworkAction() =>
      _refreshOnlineStatusForNetworkActionImpl(this);

  Future<void> _loadLastSyncTime() => _loadLastSyncTimeImpl(this);

  String _formatTimeHHmm(DateTime dt) => _formatTimeHHmmImpl(dt);

  Future<void> _loadDownloadedLineOverlays() =>
      _loadDownloadedLineOverlaysImpl(this);

  double polylineDistanceKm(List<LatLng> pts) => _polylineDistanceKmImpl(pts);

  Future<void> _focusOnTarget(MapFocusTarget target) =>
      _focusOnTargetImpl(this, target);

  Future<void> _refreshAllPoints() async {
    await _loadDisplayedPoints(); // Points locaux (rouges)
    await _loadDisplayedPolygons();
    await _loadDownloadedLineOverlays();
  }

  Future<void> _refreshAfterNavigation() async {
    await _loadDisplayedSrmLines();
    await _refreshAllPoints();
  }

  Future<void> _loadDisplayedSrmLines() => _loadDisplayedSrmLinesImpl(this);

  Future<void> _loadReferenceOverlays() => _loadReferenceOverlaysImpl(this);

  Future<void> _refreshReferenceOverlaysForMapStartup() async {
    if (!_isOnlineDynamic) return;
    try {
      await ReferenceOverlaySyncService().refreshLightOverlays();
      await _loadReferenceOverlays();
    } catch (e) {
      debugPrint('[REFERENCE-OVERLAYS] Refresh carte ignore: $e');
    }
  }

  Future<void> finishPolygonCollection() => _finishPolygonCollectionImpl();

  Future<void> cancelPolygonCollection() => _cancelPolygonCollectionImpl();

  Future<void> _loadDisplayedPolygons() => _loadDisplayedPolygonsImpl(this);

  bool _containsPolygonPreview(
    List<Polygon> polygons,
    List<LatLng> previewPoints,
  ) =>
      _containsPolygonPreviewImpl(polygons, previewPoints);
  Future<void> _loadDisplayedPoints() => _loadDisplayedPointsImpl(this);

  Future<void> _loadPointCountsByTable() => _loadPointCountsByTableImpl(this);

  Future<void> _enterConduiteDrawingMode([String metier = 'ep']) =>
      _enterConduiteDrawingModeImpl(this, metier: metier);

  Widget _buildConduiteModeHeader() => _buildConduiteModeHeaderImpl(this);

  void _handleConduiteRegardTap(Map<String, dynamic> data) =>
      _handleConduiteRegardTapImpl(this, data);

  void _handleConduiteMapTap(TapPosition tapPosition, LatLng latLng) =>
      _handleConduiteMapTapImpl(this, tapPosition, latLng);

  void _focusConduiteModeBounds() => _focusConduiteModeBoundsImpl(this);

  void _onMapCreated(MapController controller) =>
      _onMapCreatedImpl(this, controller);

  void _moveCameraIfNeeded() => _moveCameraIfNeededImpl(this);

// === SPRINT 5 : COLLECTE POINT SRM (EP / ASS) ===
  Future<void> addPointOfInterest() => _addPointOfInterestImpl();

  // === SPRINT 5 : COLLECTE LIGNE SRM ===
  Future<void> startLigneSrmCollection() => _startLigneSrmCollectionImpl();

// === COLLECTE POLYGONE (Zone de Plaine) ===
  String? _pendingSrmPolygoneMetier;
  String? _pendingSrmPolygoneEntityType;
  String? _pendingSrmPolygoneTitleApp;

  Future<void> startPolygonCollection({
    String? metier,
    String? entityType,
  }) =>
      _startPolygonCollectionImpl(
        metier: metier,
        entityType: entityType,
      );

  void togglePolygonCollection() => _togglePolygonCollectionImpl();

  void toggleLigneCollection() => _toggleLigneCollectionImpl();

  void undoLignePoint() => _undoLignePointImpl();

  void redoLignePoint() => _redoLignePointImpl();

  void undoPolygonPoint() => _undoPolygonPointImpl();

  void redoPolygonPoint() => _redoPolygonPointImpl();

  Future<void> finishLigneCollection() => _finishLigneCollectionImpl();

  Future<void> cancelLigneCollection() => _cancelLigneCollectionImpl();

  // Dans la classe _HomePageState
  Future<void> _loadDisplayedLines() => _loadDisplayedLinesImpl(this);

  void _showSyncConfirmationDialog() => _showSyncConfirmationDialogImpl(this);

  void _showSyncResult(SyncResult result) => _showSyncResultImpl(this, result);

  void _showSaveConfirmationDialog() => _showSaveConfirmationDialogImpl(this);

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
    _nmeaBridgeWatchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isConduiteMode = _isConduiteDrawingMode;
    final List<Marker> filteredMarkers = isConduiteMode
        ? [
            ..._conduiteModeMarkers,
            if (_conduiteCurrentRegardPoint != null)
              Marker(
                point: _conduiteCurrentRegardPoint!,
                width: 44,
                height: 44,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00ACC1).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF00ACC1),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF00ACC1).withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ]
        : (_getFilteredMarkers()..addAll(_focusOverlayMarkers));

    final List<Polyline> filteredPolylines = isConduiteMode
        ? List<Polyline>.from(_conduiteModePolylines)
        : (_getFilteredPolylines()..addAll(_focusOverlayPolylines));
    final List<Polygon> filteredPolygons =
        isConduiteMode ? <Polygon>[] : _getFilteredPolygons();
    if (isConduiteMode) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F8FF),
        body: SafeArea(
          child: Column(
            children: [
              _buildConduiteModeHeader(),
              Expanded(
                child: Stack(
                  children: [
                    MapWidget(
                      userPosition: userPosition ?? homeController.userPosition,
                      gpsEnabled: false,
                      useOnlineBasemap: _isOnlineDynamic,
                      markers: filteredMarkers,
                      polylines: filteredPolylines,
                      polygons: filteredPolygons,
                      onPolygonTap: null,
                      onMapCreated: _onMapCreated,
                      formMarkers: const [],
                      isSatellite: _isSatellite,
                      onPolylineTap: null,
                      onMapTap: _handleConduiteMapTap,
                      onCameraIdle: null,
                      offlineBasemapPath: _offlineBasemapPath,
                      offlineBasemapFormat: _offlineBasemapFormat,
                      basemapUnavailableMessage: _basemapUnavailableMessage,
                      basemapCenter: _offlineBasemapCenter,
                      basemapBounds: _offlineBasemapBounds,
                      basemapDefaultZoom: _offlineBasemapDefaultZoom,
                      basemapMinZoom: _offlineBasemapMinZoom,
                      basemapMaxZoom: _offlineBasemapMaxZoom,
                      showMapButtons: false,
                    ),
                    if (_conduiteModeError != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F)
                                  .withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _conduiteModeError!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (homeController.polygonCollection != null) {
      final polygonPoints = homeController.polygonCollection!.points;
      if (polygonPoints.length > 1) {
        filteredPolylines.add(
          Polyline(
            points: [...polygonPoints, polygonPoints.first],
            color: const Color(0xFF2E7D32),
            strokeWidth: 3.0,
            pattern: const StrokePattern.solid(),
          ),
        );
      }
    }
// === AFFICHER LE POLYGONE EN COURS DE COLLECTE ===
    if (_isPolygonCollection && homeController.polygonCollection != null) {
      final polyPoints = homeController.polygonCollection!.points;
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
            color: homeController.ligneCollection!.isPaused
                ? Colors.orange
                : Colors.green,
            strokeWidth: 4.0,
            pattern: homeController.ligneCollection!.isPaused
                ? StrokePattern.dashed(segments: const [10, 5])
                : const StrokePattern.solid(),
          ),
        );
      }
    }

    final hasTraceCollection = homeController.ligneCollection != null ||
        homeController.polygonCollection != null;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF0F8FF,
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: isDownloading || isSyncing,
          child: Column(
            children: [
              TopBarWidget(
                agentName: widget.agentName,
                onLogout: _showLogoutConfirmation,
                onStartConduiteDrawing: (metier) =>
                    _enterConduiteDrawingMode(metier),
              ),
              Expanded(
                child: Stack(
                  children: [
                    MapWidget(
                      userPosition: userPosition ?? homeController.userPosition,
                      gpsEnabled: gpsEnabled,
                      useOnlineBasemap: _isOnlineDynamic,
                      markers: filteredMarkers,
                      polylines: filteredPolylines,
                      polygons: filteredPolygons,
                      onPolygonTap: _handlePolygonTap,
                      onPolygonLongPress: _handlePolygonLongPress,
                      onMapCreated: _onMapCreated,
                      formMarkers: formMarkers,
                      isSatellite: _isSatellite,
                      onMapTypeChanged: (value) {
                        setState(() {
                          _isSatellite = value;
                        });
                      },
                      onPolylineTap: _handlePolylineTap,
                      onCameraIdle: null,
                      offlineBasemapPath: _offlineBasemapPath,
                      offlineBasemapFormat: _offlineBasemapFormat,
                      basemapUnavailableMessage: _basemapUnavailableMessage,
                      basemapCenter: _offlineBasemapCenter,
                      basemapBounds: _offlineBasemapBounds,
                      basemapDefaultZoom: _offlineBasemapDefaultZoom,
                      basemapMinZoom: _offlineBasemapMinZoom,
                      basemapMaxZoom: _offlineBasemapMaxZoom,
                      showMapButtons: true,
                      showLocationButton: !hasTraceCollection,
                      showZoomButtons: !hasTraceCollection,
                      onMapTap: (_, __) {
                        if (_isLegendExpanded) {
                          setState(() => _isLegendExpanded = false);
                        }
                      },
                      onUserInteraction: () {
                        _autoCenterDisabledByUser = true;
                      },
                      onGpsButtonPressed: () {
                        _autoCenterDisabledByUser = false;
                      },
                    ),
                    LegendWidget(
                      initialVisibility: _legendVisibility,
                      expanded: _isLegendExpanded,
                      onVisibilityChanged: _updateVisibilityFromLegend,
                      allPolylines: filteredPolylines,
                      allMarkers: filteredMarkers,
                      polygonCount: _displayedPolygons.length,
                      pointCountsByTable: _pointCountsByTable,
                      anomalieCountsByTable: _anomalieCountsByTable,
                      incompletCountsByTable: _incompletCountsByTable,
                      referenceOverlayCounts: _referenceOverlayCounts,
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
                        visible: _canUseAdminGpsTools &&
                            !_isLegendExpanded &&
                            !_isConduiteDrawingMode,
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
                        onTogglePolygon: togglePolygonCollection,
                        onUndoLigne: undoLignePoint,
                        onRedoLigne: redoLignePoint,
                        onUndoPolygon: undoPolygonPoint,
                        onRedoPolygon: redoPolygonPoint,
                        canRedoLigne: _ligneRedoPoints.isNotEmpty,
                        canRedoPolygon: _polygonRedoPoints.isNotEmpty,
                        onFinishLigne: finishLigneCollection,
                        onFinishPolygon: finishPolygonCollection,
                        onCancelLigne: cancelLigneCollection,
                        onCancelPolygon: cancelPolygonCollection,
                        onRefresh: _loadDisplayedPoints,
                        isPolygonCollection: _isPolygonCollection,
                        showRefresh: !hasTraceCollection,
                      ),
                    // === WIDGETS DE STATUT (NOUVEAU SYSTEME UNIQUEMENT) ===

                    // Afficher le statut de ligne si active
                    if (homeController.ligneCollection != null)
                      LigneStatusWidget(
                        collection: homeController.ligneCollection!,
                        topOffset: 16,
                      ),

                    if (homeController.polygonCollection != null)
                      PolygonStatusWidget(
                        collection: homeController.polygonCollection!,
                        topOffset:
                            homeController.ligneCollection != null ? 70 : 16,
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
                gpsSourceLabel: gpsSourceLabel,
                gpsDetailsLine: gpsDetailsLine,
                isOnline: _isOnlineDynamic,
                lastSyncTime: _lastSyncTimeText,
              ),
              BottomButtonsWidget(
                onSave: (!_isOnlineDynamic || isDownloading || isSyncing)
                    ? null
                    : _showSaveConfirmationDialog,
                isSaveEnabled: _isOnlineDynamic && !isDownloading && !isSyncing,
                onSync: (!_isOnlineDynamic || isSyncing || isDownloading)
                    ? null
                    : _showSyncConfirmationDialog,
                isSyncEnabled: _isOnlineDynamic && !isSyncing && !isDownloading,
                onMenu: handleMenuPress,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
