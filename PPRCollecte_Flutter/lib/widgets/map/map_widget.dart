import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:pmtiles/pmtiles.dart' as pmtiles;
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_map_tiles_pmtiles/src/themes/v4/_package.dart'
    as protomaps_v4;
import 'package:vector_tile/vector_tile.dart' as vt;
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../core/constants/basemap_constants.dart';

class MapWidget extends StatefulWidget {
  static const String onlineOsmUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  final LatLng userPosition;
  final bool gpsEnabled;
  final bool useOnlineBasemap;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final List<Polygon> polygons;
  final Function(Object?)? onPolygonTap;
  final Function(MapController) onMapCreated;
  final List<Marker> formMarkers;
  final bool isSatellite;
  final Function(Object?)? onPolylineTap;
  final VoidCallback? onUserInteraction;
  final VoidCallback? onGpsButtonPressed;
  final void Function(TapPosition, LatLng)? onMapTap;
  final void Function(LatLng center, double zoom)? onCameraIdle;
  final String? offlineBasemapPath;
  final String? offlineBasemapFormat;
  final String? basemapUnavailableMessage;
  final LatLng? basemapCenter;
  final LatLngBounds? basemapBounds;
  final double? basemapDefaultZoom;
  final double? basemapMinZoom;
  final double? basemapMaxZoom;
  final bool showMapButtons;

  const MapWidget({
    super.key,
    required this.userPosition,
    required this.gpsEnabled,
    required this.useOnlineBasemap,
    required this.markers,
    required this.polylines,
    this.polygons = const [],
    this.onPolygonTap,
    required this.onMapCreated,
    required this.formMarkers,
    this.isSatellite = false,
    this.onPolylineTap,
    this.onUserInteraction,
    this.onGpsButtonPressed,
    this.onMapTap,
    this.onCameraIdle,
    this.offlineBasemapPath,
    this.offlineBasemapFormat,
    this.basemapUnavailableMessage,
    this.basemapCenter,
    this.basemapBounds,
    this.basemapDefaultZoom,
    this.basemapMinZoom,
    this.basemapMaxZoom,
    this.showMapButtons = true,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  static const String _protomapsLightSpriteJsonAsset =
      'assets/basemaps/protomaps/sprites/v4/light.json';
  static const String _protomapsLightSpritePngAsset =
      'assets/basemaps/protomaps/sprites/v4/light.png';
  static const String _offlinePoiOpenStreetMapCartoRoot =
      'assets/map_icons/openstreetmap_carto';
  static const String _offlinePoiOsmicRoot = 'assets/map_icons/osmic';
  static const String _offlinePoiTemakiRoot = 'assets/map_icons/temaki';
  static const Map<String, List<String>> _offlinePoiExactIconCandidates = {
    'school': ['$_offlinePoiTemakiRoot/school.svg'],
    'college': ['$_offlinePoiTemakiRoot/school.svg'],
    'university': ['$_offlinePoiTemakiRoot/school.svg'],
    'kindergarten': ['$_offlinePoiTemakiRoot/school.svg'],
    'mall': ['$_offlinePoiTemakiRoot/shopping_mall.svg'],
    'clinic': ['$_offlinePoiOsmicRoot/health/hospital-14.svg'],
    'mosque': ['$_offlinePoiOsmicRoot/religious/muslim-14.svg'],
    'church': ['$_offlinePoiOsmicRoot/religious/christian-14.svg'],
    'train_station': [
      '$_offlinePoiOsmicRoot/transport/railway-station-14.svg',
      '$_offlinePoiTemakiRoot/train.svg',
    ],
    'ferry_terminal': ['$_offlinePoiOsmicRoot/transport/ferry-14.svg'],
    'stadium': ['$_offlinePoiTemakiRoot/amusement_park.svg'],
    'sports_centre': ['$_offlinePoiOpenStreetMapCartoRoot/shop/sports.svg'],
    'pitch': ['$_offlinePoiTemakiRoot/horizontal_bar.svg'],
    'park': ['$_offlinePoiOpenStreetMapCartoRoot/leisure/park.svg'],
    'garden': ['$_offlinePoiTemakiRoot/garden_bed.svg'],
    'forest': ['$_offlinePoiOsmicRoot/nature/tree-unspecified-14.svg'],
    'cemetery': ['$_offlinePoiOsmicRoot/amenity/cemetery-14.svg'],
    'bank': ['$_offlinePoiOpenStreetMapCartoRoot/amenity/bank.svg'],
    'atm': ['$_offlinePoiOpenStreetMapCartoRoot/amenity/atm.svg'],
    'taxi': [
      '$_offlinePoiOpenStreetMapCartoRoot/amenity/taxi.svg',
      '$_offlinePoiOsmicRoot/transport/taxi-14.svg',
    ],
    'administrative': ['$_offlinePoiTemakiRoot/town_hall.svg'],
    'social_facility': [
      '$_offlinePoiOpenStreetMapCartoRoot/amenity/social_facility.svg',
      '$_offlinePoiTemakiRoot/social_facility.svg',
    ],
    'golf_course': ['$_offlinePoiOpenStreetMapCartoRoot/leisure/golf.svg'],
  };
  static const Set<String> _offlinePoiKindsWithoutIcon = {
    'residential',
    'industrial',
    'construction',
    'pedestrian',
    'commercial',
    'neighbourhood',
    'locality',
  };

  late final MapController _mapController;
  bool _controllerReady = false;
  TileProvider? _rasterTileProvider;
  vmt.VectorTileProvider? _vectorTileProvider;
  vtr.Theme? _vectorTheme;
  vmt.SpriteStyle? _vectorSprites;
  String? _loadedBasemapPath;
  String? _loadedBasemapFormat;
  String? _requestedBasemapPath;
  String? _requestedBasemapFormat;
  String? _basemapLoadError;
  String? _vectorDetailsSummary;
  String? _vectorDetailsWarning;
  Set<String> _vectorSpriteNames = const {};
  List<Marker> _offlinePoiMarkers = const [];
  Timer? _offlinePoiRefreshTimer;
  pmtiles.PmTilesArchive? _offlinePoiArchive;
  String? _offlinePoiArchivePath;
  bool _isBasemapLoading = false;
  int _basemapLoadRequestId = 0;
  int _offlinePoiRefreshRequestId = 0;
  String? _lastIconDiagnosticsKey;
  String? _lastOfflinePoiRefreshKey;
  final Map<String, bool> _offlinePoiAssetAvailabilityCache = {};
  final Map<String, _OfflinePoiMarkerSpec?> _offlinePoiSpecCache = {};

  final _polylineHitNotifier = ValueNotifier<LayerHitResult<Object>?>(null);
  final _polygonHitNotifier = ValueNotifier<LayerHitResult<Object>?>(null);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMapCreated(_mapController);
      setState(() => _controllerReady = true);
      _queueOfflinePoiMarkerRefresh(force: true, immediate: true);
    });
    _polylineHitNotifier.addListener(_onPolylineHit);
    _polygonHitNotifier.addListener(_onPolygonHit);
    _loadBasemapProvider(
      widget.offlineBasemapPath,
      widget.offlineBasemapFormat,
    );
  }

  @override
  void didUpdateWidget(covariant MapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offlineBasemapPath != widget.offlineBasemapPath ||
        oldWidget.offlineBasemapFormat != widget.offlineBasemapFormat) {
      _loadBasemapProvider(
        widget.offlineBasemapPath,
        widget.offlineBasemapFormat,
      );
    }
  }

  @override
  void dispose() {
    _polylineHitNotifier.removeListener(_onPolylineHit);
    _polygonHitNotifier.removeListener(_onPolygonHit);
    _offlinePoiRefreshTimer?.cancel();
    _rasterTileProvider?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onPolylineHit() {
    final hitResult = _polylineHitNotifier.value;
    if (hitResult != null && hitResult.hitValues.isNotEmpty) {
      widget.onPolylineTap?.call(hitResult.hitValues.first);
    }
  }

  void _onPolygonHit() {
    final hitResult = _polygonHitNotifier.value;
    if (hitResult != null && hitResult.hitValues.isNotEmpty) {
      widget.onPolygonTap?.call(hitResult.hitValues.first);
    }
  }

  void _zoomIn() {
    if (_controllerReady) {
      final targetZoom = math.min(
        _mapController.camera.zoom + 1,
        _mapController.camera.maxZoom ?? double.infinity,
      ).toDouble();
      _mapController.move(
        _mapController.camera.center,
        targetZoom,
      );
    }
  }

  void _zoomOut() {
    if (_controllerReady) {
      final targetZoom = math.max(
        _mapController.camera.zoom - 1,
        _mapController.camera.minZoom ?? 1,
      ).toDouble();
      _mapController.move(
        _mapController.camera.center,
        targetZoom,
      );
    }
  }

  void _goToUserLocation() {
    if (_controllerReady) {
      widget.onGpsButtonPressed?.call();
      final targetZoom = math.min(
        17.0,
        _mapController.camera.maxZoom ?? 17.0,
      );
      _mapController.move(widget.userPosition, targetZoom);
    }
  }

  String _normalizedBasemapFormat(String? rawFormat) {
    final normalized = rawFormat?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return 'mbtiles';
    }
    return normalized;
  }

  Future<void> _loadBasemapProvider(
    String? basemapPath,
    String? basemapFormat,
  ) async {
    final normalizedFormat = _normalizedBasemapFormat(basemapFormat);
    final hasLoadedProvider =
        _rasterTileProvider != null ||
        (_vectorTileProvider != null && _vectorTheme != null);
    if (basemapPath == _loadedBasemapPath &&
        normalizedFormat == _loadedBasemapFormat &&
        (basemapPath == null || hasLoadedProvider)) {
      return;
    }

    if (_isBasemapLoading &&
        basemapPath == _requestedBasemapPath &&
        normalizedFormat == _requestedBasemapFormat) {
      return;
    }

    _requestedBasemapPath = basemapPath;
    _requestedBasemapFormat = normalizedFormat;
    final requestId = ++_basemapLoadRequestId;

    if (basemapPath == null || basemapPath.isEmpty) {
      final previousRasterProvider = _rasterTileProvider;
      _rasterTileProvider = null;
      _vectorTileProvider = null;
      _vectorTheme = null;
      _vectorSprites = null;
      _vectorDetailsSummary = null;
      _vectorDetailsWarning = null;
      _loadedBasemapPath = null;
      _loadedBasemapFormat = normalizedFormat;
      _basemapLoadError = null;
      _offlinePoiArchive = null;
      _offlinePoiArchivePath = null;
      _offlinePoiMarkers = const [];
      _lastOfflinePoiRefreshKey = null;
      previousRasterProvider?.dispose();
      if (mounted) {
        setState(() {
          _isBasemapLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isBasemapLoading = true;
        _basemapLoadError = null;
      });
    }

    try {
      TileProvider? rasterProvider;
      vmt.VectorTileProvider? vectorProvider;
      vtr.Theme? vectorTheme;
      vmt.SpriteStyle? vectorSprites;
      String? vectorDetailsSummary;
      String? vectorDetailsWarning;
      switch (normalizedFormat) {
        case 'pmtiles':
          vectorProvider = await PmTilesVectorTileProvider.fromSource(
            basemapPath,
          );
          try {
            final themeBundle = _buildLocalProtomapsLightThemeBundle();
            final spriteResult = await _loadLocalProtomapsLightSprites();
            vectorTheme = themeBundle.theme;
            vectorSprites = spriteResult.style;
            _vectorSpriteNames = spriteResult.spriteNames;
            vectorDetailsSummary =
                'PMTiles details L:${themeBundle.check.layerCount} '
                'S:${themeBundle.check.symbolLayerCount} '
                'T:${themeBundle.check.textLayerCount} '
                'I:${themeBundle.check.iconLayerCount} '
                'Sprites:${spriteResult.spriteCount}';
            final warnings = <String>[];
            if (themeBundle.check.textLayerCount == 0) {
              warnings.add('aucune couche texte');
            }
            if (themeBundle.check.iconLayerCount == 0) {
              warnings.add('aucune couche icone');
            }
            if (spriteResult.spriteCount == 0) {
              warnings.add('sprite atlas vide');
            }
            if (warnings.isNotEmpty) {
              vectorDetailsWarning =
                  'Détails PMTiles partiels: ${warnings.join(', ')}';
            }
            debugPrint('[BASEMAP] $vectorDetailsSummary');
            if (vectorDetailsWarning != null) {
              debugPrint('[BASEMAP] $vectorDetailsWarning');
            }
          } catch (e) {
            debugPrint('[BASEMAP] Fallback theme Protomaps standard: $e');
            vectorTheme = ProtomapsThemes.lightV4();
            vectorDetailsSummary = 'PMTiles details fallback theme standard';
            vectorDetailsWarning = 'Theme local indisponible, fallback standard';
          }
          break;
        case 'mbtiles':
        default:
          rasterProvider = MbTilesTileProvider.fromPath(path: basemapPath);
          break;
      }

      if (!mounted ||
          requestId != _basemapLoadRequestId ||
          widget.offlineBasemapPath != basemapPath ||
          _normalizedBasemapFormat(widget.offlineBasemapFormat) !=
              normalizedFormat) {
        rasterProvider?.dispose();
        return;
      }

      final previousRasterProvider = _rasterTileProvider;
      setState(() {
        _rasterTileProvider = rasterProvider;
        _vectorTileProvider = vectorProvider;
        _vectorTheme = vectorTheme;
        _vectorSprites = vectorSprites;
        _vectorDetailsSummary = vectorDetailsSummary;
        _vectorDetailsWarning = vectorDetailsWarning;
        _loadedBasemapPath = basemapPath;
        _loadedBasemapFormat = normalizedFormat;
        _isBasemapLoading = false;
      });
      if (normalizedFormat == 'pmtiles' && _vectorSpriteNames.isNotEmpty) {
        _schedulePmtilesIconDiagnostics(
          basemapPath: basemapPath,
          spriteNames: _vectorSpriteNames,
        );
        _queueOfflinePoiMarkerRefresh(force: true, immediate: true);
      } else {
        _offlinePoiArchive = null;
        _offlinePoiArchivePath = null;
        _lastOfflinePoiRefreshKey = null;
        if (_offlinePoiMarkers.isNotEmpty && mounted) {
          setState(() {
            _offlinePoiMarkers = const [];
          });
        }
      }
      if (!identical(previousRasterProvider, rasterProvider)) {
        previousRasterProvider?.dispose();
      }
    } catch (e) {
      if (!mounted || requestId != _basemapLoadRequestId) return;
      debugPrint('[BASEMAP] Erreur chargement offline ($normalizedFormat): $e');
      setState(() {
        _basemapLoadError = e.toString();
        _vectorDetailsSummary = null;
        _vectorDetailsWarning = null;
        _isBasemapLoading = false;
      });
    }
  }

  Future<_SpriteLoadResult> _loadLocalProtomapsLightSprites() async {
    final spriteJsonText = await rootBundle.loadString(
      _protomapsLightSpriteJsonAsset,
    );
    final spriteJsonRaw = jsonDecode(spriteJsonText);
    if (spriteJsonRaw is! Map<String, dynamic>) {
      throw Exception('Index sprite Protomaps invalide');
    }

    final atlasBytes = await rootBundle.load(_protomapsLightSpritePngAsset);
    final spriteIndex = vtr.SpriteIndexReader(
      logger: const vtr.Logger.noop(),
    ).read(spriteJsonRaw);

    return _SpriteLoadResult(
      style: vmt.SpriteStyle(
        atlasProvider: () async => atlasBytes.buffer.asUint8List(),
        index: spriteIndex,
      ),
      spriteCount: spriteJsonRaw.length,
      spriteNames: spriteJsonRaw.keys.map((key) => key.toString()).toSet(),
    );
  }

  _LocalProtomapsThemeBundle _buildLocalProtomapsLightThemeBundle() {
    final decoded =
        jsonDecode(jsonEncode(protomaps_v4.themeLight)) as List<dynamic>;
    final rawLayers = decoded.whereType<Map>().toList(growable: false);
    final localizedLayers = <Map<String, Object>>[];
    for (final layer in decoded.whereType<Map>()) {
      final normalized = _normalizeProtomapsLayer(
        layer.cast<String, dynamic>(),
      );
      localizedLayers.addAll(_expandProtomapsLayer(normalized));
    }

    final textAndBaseLayers = localizedLayers
        .where((layer) => !(layer['id']?.toString().endsWith('_icons') ?? false))
        .toList(growable: false);

    final protomaps = ProtomapsThemes(sprites: null);
    return _LocalProtomapsThemeBundle(
      theme: protomaps.build(textAndBaseLayers),
      check: _inspectThemeLayers(rawLayers),
    );
  }

  _VectorDetailsCheck _inspectThemeLayers(List<Map> rawLayers) {
    var symbolLayerCount = 0;
    var textLayerCount = 0;
    var iconLayerCount = 0;

    for (final layer in rawLayers) {
      final type = layer['type']?.toString().trim().toLowerCase() ?? '';
      if (type != 'symbol') continue;
      symbolLayerCount++;
      final layout = layer['layout'];
      if (layout is Map) {
        if (layout['text-field'] != null) {
          textLayerCount++;
        }
        if (layout['icon-image'] != null) {
          iconLayerCount++;
        }
      }
    }

    return _VectorDetailsCheck(
      layerCount: rawLayers.length,
      symbolLayerCount: symbolLayerCount,
      textLayerCount: textLayerCount,
      iconLayerCount: iconLayerCount,
    );
  }

  Map<String, dynamic> _normalizeProtomapsLayer(Map<String, dynamic> layer) {
    final normalizedLayer = Map<String, dynamic>.from(layer);
    final layerId = normalizedLayer['id']?.toString().trim().toLowerCase() ?? '';
    final sourceLayer =
        normalizedLayer['source-layer']?.toString().trim().toLowerCase() ?? '';
    final layout = normalizedLayer['layout'];
    if (layout is Map<String, dynamic>) {
      final normalizedLayout = Map<String, dynamic>.from(layout);
      if (normalizedLayout.containsKey('text-font')) {
        normalizedLayout['text-font'] =
            _normalizeProtomapsTextFont(normalizedLayout['text-font']);
      }
      if (normalizedLayout.containsKey('text-field')) {
        normalizedLayout['text-field'] =
            _normalizeProtomapsTextField(normalizedLayout['text-field']);
      }
      if (normalizedLayout.containsKey('icon-image')) {
        normalizedLayout['icon-image'] = _normalizeProtomapsIconImage(
          layerId: layerId,
          sourceLayer: sourceLayer,
          rawIconImage: normalizedLayout['icon-image'],
        );
      }
      normalizedLayer['layout'] = normalizedLayout;
    }
    if (layerId == 'pois' && sourceLayer == 'pois') {
      normalizedLayer['filter'] = _expandedProtomapsPoiFilter();
    }
    return normalizedLayer;
  }

  List<Map<String, Object>> _expandProtomapsLayer(
    Map<String, dynamic> normalizedLayer,
  ) {
    final layerId = normalizedLayer['id']?.toString().trim().toLowerCase() ?? '';
    final sourceLayer =
        normalizedLayer['source-layer']?.toString().trim().toLowerCase() ?? '';
    final shouldSplit =
        (layerId == 'pois' && sourceLayer == 'pois') ||
        (layerId == 'places_locality' && sourceLayer == 'places');
    if (!shouldSplit) {
      return [Map<String, Object>.from(normalizedLayer)];
    }

    final iconLayer = jsonDecode(jsonEncode(normalizedLayer))
        as Map<String, dynamic>;
    final iconLayout =
        Map<String, dynamic>.from(iconLayer['layout'] as Map? ?? const {});
    iconLayout.remove('text-field');
    iconLayout.remove('text-font');
    iconLayout.remove('text-justify');
    iconLayout.remove('text-transform');
    iconLayout.remove('text-letter-spacing');
    iconLayout.remove('text-max-width');
    iconLayout.remove('text-anchor');
    iconLayout['icon-anchor'] = 'center';
    if (layerId == 'pois') {
      iconLayout['icon-size'] = 0.9;
    }
    iconLayer['id'] = '${normalizedLayer['id']}_icons';
    iconLayer['layout'] = iconLayout;

    final textLayer = jsonDecode(jsonEncode(normalizedLayer))
        as Map<String, dynamic>;
    final textLayout =
        Map<String, dynamic>.from(textLayer['layout'] as Map? ?? const {});
    textLayout.remove('icon-image');
    textLayout.remove('icon-size');
    textLayout.remove('icon-anchor');
    textLayout.remove('icon-rotate');
    textLayout.remove('icon-opacity');
    textLayout.remove('icon-rotation-alignment');
    textLayer['id'] = '${normalizedLayer['id']}_text';
    textLayer['layout'] = textLayout;

    return [
      Map<String, Object>.from(iconLayer),
      Map<String, Object>.from(textLayer),
    ];
  }

  List<String> _normalizeProtomapsTextFont(dynamic rawFont) {
    if (rawFont is List &&
        rawFont.isNotEmpty &&
        rawFont.every((entry) => entry is String)) {
      final first = rawFont.first.toString().trim().toLowerCase();
      final looksLikeExpression = {
        'case',
        'step',
        'match',
        'coalesce',
        'literal',
        'get',
      }.contains(first);
      if (!looksLikeExpression) {
        return rawFont
            .map((fontName) => _mapProtomapsFontFamily(fontName.toString()))
            .toList(growable: false);
      }
    }

    final rawText = rawFont?.toString() ?? '';
    if (rawText.toLowerCase().contains('devanagari')) {
      return const ['Noto Sans Devanagari'];
    }
    if (rawText.toLowerCase().contains('medium')) {
      return const ['Noto Sans Medium'];
    }
    if (rawText.toLowerCase().contains('italic')) {
      return const ['Noto Sans Italic'];
    }
    return const ['Noto Sans Regular'];
  }

  dynamic _normalizeProtomapsTextField(dynamic rawTextField) {
    if (_containsExpressionOperator(rawTextField, 'format')) {
      return _fallbackTextFieldExpression();
    }
    return rawTextField;
  }

  dynamic _normalizeProtomapsIconImage({
    required String layerId,
    required String sourceLayer,
    required dynamic rawIconImage,
  }) {
    if (_containsExpressionOperator(rawIconImage, 'image')) {
      return rawIconImage;
    }
    if (layerId == 'pois' && sourceLayer == 'pois') {
      return _fallbackPoiIconExpression();
    }
    if (layerId == 'places_locality' && sourceLayer == 'places') {
      return _fallbackLocalityIconExpression();
    }
    return ['image', rawIconImage];
  }

  List<dynamic> _fallbackTextFieldExpression() {
    return const [
      'coalesce',
      ['get', 'name:fr'],
      ['get', 'name:en'],
      ['get', 'pgf:name'],
      ['get', 'name'],
      ['get', 'name2'],
      ['get', 'name3'],
      ['get', 'ref'],
    ];
  }

  List<dynamic> _expandedProtomapsPoiFilter() {
    return const [
      'all',
      [
        'in',
        ['get', 'kind'],
        [
          'literal',
          [
            'aerodrome',
            'attraction',
            'artwork',
            'atm',
            'bakery',
            'bank',
            'bar',
            'beach',
            'bench',
            'books',
            'bus_station',
            'bus_stop',
            'cafe',
            'car_rental',
            'car_repair',
            'cinema',
            'clinic',
            'college',
            'convenience',
            'dentist',
            'doctors',
            'drinking_water',
            'fast_food',
            'ferry_terminal',
            'fuel',
            'fast_food',
            'garden',
            'garden_centre',
            'guest_house',
            'hostel',
            'hospital',
            'hotel',
            'ice_cream',
            'kindergarten',
            'ferry_terminal',
            'forest',
            'library',
            'lodging',
            'marina',
            'marketplace',
            'mall',
            'motel',
            'mosque',
            'museum',
            'parking',
            'park',
            'peak',
            'pharmacy',
            'place_of_worship',
            'post_office',
            'pub',
            'restaurant',
            'school',
            'sports_centre',
            'stadium',
            'supermarket',
            'theatre',
            'train_station',
            'university',
            'zoo',
          ],
        ],
      ],
      [
        '>=',
        ['zoom'],
        ['get', 'min_zoom'],
      ],
    ];
  }

  List<dynamic> _fallbackPoiIconExpression() {
    return const [
      'image',
      [
        'match',
        ['get', 'kind'],
        'aerodrome',
        'aerodrome',
        'attraction',
        'attraction',
        'artwork',
        'artwork',
        'atm',
        'building',
        'bakery',
        'supermarket',
        'bank',
        'building',
        'bar',
        'bar',
        'beach',
        'beach',
        'bench',
        'bench',
        'books',
        'books',
        'bus_station',
        'bus_stop',
        'bus_stop',
        'bus_stop',
        'cafe',
        'cafe',
        'car_rental',
        'building',
        'car_repair',
        'building',
        'cinema',
        'theatre',
        'clinic',
        'building',
        'college',
        'university',
        'convenience',
        'convenience',
        'dentist',
        'building',
        'doctors',
        'building',
        'drinking_water',
        'drinking_water',
        'fast_food',
        'fast_food',
        'ferry_terminal',
        'ferry_terminal',
        'fuel',
        'building',
        'forest',
        'forest',
        'garden',
        'garden',
        'garden_centre',
        'garden',
        'guest_house',
        'building',
        'hostel',
        'building',
        'hospital',
        'building',
        'hotel',
        'building',
        'ice_cream',
        'cafe',
        'kindergarten',
        'school',
        'library',
        'library',
        'lodging',
        'building',
        'marina',
        'marina',
        'marketplace',
        'supermarket',
        'mall',
        'supermarket',
        'motel',
        'building',
        'mosque',
        'building',
        'museum',
        'museum',
        'parking',
        'building',
        'park',
        'park',
        'peak',
        'peak',
        'pharmacy',
        'building',
        'place_of_worship',
        'building',
        'post_office',
        'post_office',
        'pub',
        'bar',
        'restaurant',
        'restaurant',
        'school',
        'school',
        'sports_centre',
        'stadium',
        'stadium',
        'stadium',
        'supermarket',
        'supermarket',
        'theatre',
        'theatre',
        'train_station',
        'train_station',
        'university',
        'university',
        'zoo',
        'zoo',
        '',
      ],
    ];
  }

  List<dynamic> _fallbackLocalityIconExpression() {
    return const ['image', 'townspot'];
  }

  void _schedulePmtilesIconDiagnostics({
    required String basemapPath,
    required Set<String> spriteNames,
  }) {
    if (!kDebugMode) return;
    final center = widget.basemapCenter;
    if (center == null) return;
    final diagnosticKey =
        '$basemapPath|${center.latitude.toStringAsFixed(5)}|${center.longitude.toStringAsFixed(5)}';
    if (_lastIconDiagnosticsKey == diagnosticKey) {
      return;
    }
    _lastIconDiagnosticsKey = diagnosticKey;
    Future<void>(() async {
      try {
        await _debugLogPmtilesIconValues(
          basemapPath: basemapPath,
          center: center,
          spriteNames: spriteNames,
        );
      } catch (e) {
        debugPrint('[BASEMAP] Icon diagnostics failed: $e');
      }
    });
  }

  Future<void> _debugLogPmtilesIconValues({
    required String basemapPath,
    required LatLng center,
    required Set<String> spriteNames,
  }) async {
    final archive = await pmtiles.PmTilesArchive.from(basemapPath);
    final sampleZoom = math.max(
      12,
      math.min(14, widget.basemapDefaultZoom?.round() ?? 13),
    );
    final centerTile = _lonLatToTileXY(center, sampleZoom);

    final poiKinds = <String, int>{};
    final placeKinds = <String, int>{};
    final poiNamesByKind = <String, Set<String>>{};

    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final x = centerTile.$1 + dx;
        final y = centerTile.$2 + dy;
        if (x < 0 || y < 0) continue;
        final maxIndex = (1 << sampleZoom) - 1;
        if (x > maxIndex || y > maxIndex) continue;

        try {
          final tileId = pmtiles.ZXY(sampleZoom, x, y).toTileId();
          final tile = await archive.tile(tileId);
          final bytes = tile.bytes();
          if (bytes.isEmpty) continue;

          final vectorTile = vt.VectorTile.fromBytes(
            bytes: Uint8List.fromList(bytes),
          );
          for (final layer in vectorTile.layers) {
            if (layer.name == 'pois') {
              for (final feature in layer.features) {
                final properties = feature.decodeProperties();
                final kind = properties['kind']?.dartStringValue?.trim();
                if (kind == null || kind.isEmpty) continue;
                poiKinds.update(kind, (value) => value + 1, ifAbsent: () => 1);
                final name = properties['name']?.dartStringValue?.trim();
                if (name != null && name.isNotEmpty) {
                  poiNamesByKind.putIfAbsent(kind, () => <String>{}).add(name);
                }
              }
            } else if (layer.name == 'places') {
              for (final feature in layer.features) {
                final properties = feature.decodeProperties();
                final kind = properties['kind']?.dartStringValue?.trim();
                if (kind == null || kind.isEmpty) continue;
                placeKinds.update(kind, (value) => value + 1, ifAbsent: () => 1);
              }
            }
          }
        } catch (e) {
          debugPrint('[BASEMAP] Icon diag skipped tile z$sampleZoom/$x/$y: $e');
        }
      }
    }

    final poiSummary = poiKinds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final placeSummary = placeKinds.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    debugPrint(
      '[BASEMAP] Icon diag z$sampleZoom centerTile=${centerTile.$1},${centerTile.$2}',
    );
    if (poiSummary.isEmpty) {
      debugPrint('[BASEMAP] Icon diag pois: none in sampled tiles');
    } else {
      for (final entry in poiSummary.take(20)) {
        final spriteState = spriteNames.contains(entry.key)
            ? 'sprite=yes'
            : 'sprite=no';
        final sampleNames = (poiNamesByKind[entry.key] ?? const <String>{})
            .take(3)
            .join(' | ');
        debugPrint(
          '[BASEMAP] Icon diag poi kind=${entry.key} count=${entry.value} '
          '$spriteState'
          '${sampleNames.isEmpty ? '' : ' names=$sampleNames'}',
        );
      }
    }
    if (placeSummary.isEmpty) {
      debugPrint('[BASEMAP] Icon diag places: none in sampled tiles');
    } else {
      for (final entry in placeSummary.take(10)) {
        debugPrint(
          '[BASEMAP] Icon diag place kind=${entry.key} count=${entry.value}',
        );
      }
    }
  }

  (int, int) _lonLatToTileXY(LatLng point, int zoom) {
    final scale = 1 << zoom;
    final x = ((point.longitude + 180.0) / 360.0 * scale).floor();
    final latRad = point.latitude * math.pi / 180.0;
    final mercatorY = 1 -
        (math.log(math.tan(latRad) + (1 / math.cos(latRad))) / math.pi);
    final y = ((mercatorY / 2) * scale).floor();
    return (x, y);
  }

  (int, int, int, int) _tileRangeForBounds(LatLngBounds bounds, int zoom) {
    final northWest = _lonLatToTileXY(
      LatLng(bounds.north, bounds.west),
      zoom,
    );
    final southEast = _lonLatToTileXY(
      LatLng(bounds.south, bounds.east),
      zoom,
    );
    final maxIndex = (1 << zoom) - 1;
    final xMin = math.max(0, math.min(northWest.$1, southEast.$1) - 1);
    final xMax = math.min(maxIndex, math.max(northWest.$1, southEast.$1) + 1);
    final yMin = math.max(0, math.min(northWest.$2, southEast.$2) - 1);
    final yMax = math.min(maxIndex, math.max(northWest.$2, southEast.$2) + 1);
    return (xMin, xMax, yMin, yMax);
  }

  Future<pmtiles.PmTilesArchive> _getOfflinePoiArchive(String basemapPath) async {
    if (_offlinePoiArchive != null && _offlinePoiArchivePath == basemapPath) {
      return _offlinePoiArchive!;
    }
    final archive = await pmtiles.PmTilesArchive.from(basemapPath);
    _offlinePoiArchive = archive;
    _offlinePoiArchivePath = basemapPath;
    return archive;
  }

  void _queueOfflinePoiMarkerRefresh({
    bool force = false,
    bool immediate = false,
  }) {
    _offlinePoiRefreshTimer?.cancel();
    if (immediate) {
      Future<void>(() => _refreshOfflinePoiMarkers(force: force));
      return;
    }
    _offlinePoiRefreshTimer = Timer(
      const Duration(milliseconds: 220),
      () => _refreshOfflinePoiMarkers(force: force),
    );
  }

  Future<void> _refreshOfflinePoiMarkers({bool force = false}) async {
    final basemapPath = widget.offlineBasemapPath?.trim();
    final isPmtiles =
        _normalizedBasemapFormat(widget.offlineBasemapFormat) == 'pmtiles';
    if (!_controllerReady ||
        !mounted ||
        widget.useOnlineBasemap ||
        basemapPath == null ||
        basemapPath.isEmpty ||
        !isPmtiles ||
        _vectorTileProvider == null ||
        _vectorTheme == null) {
      if (_offlinePoiMarkers.isNotEmpty && mounted) {
        setState(() {
          _offlinePoiMarkers = const [];
        });
      }
      return;
    }

    final camera = _mapController.camera;
    final zoom = camera.zoom.round().clamp(13, 16);
    if (camera.zoom < 13) {
      if (_offlinePoiMarkers.isNotEmpty && mounted) {
        setState(() {
          _offlinePoiMarkers = const [];
        });
      }
      return;
    }

    final visibleBounds = camera.visibleBounds;
    final tileRange = _tileRangeForBounds(visibleBounds, zoom);
    final refreshKey =
        '$basemapPath|$zoom|${tileRange.$1}:${tileRange.$2}:${tileRange.$3}:${tileRange.$4}';
    if (!force && refreshKey == _lastOfflinePoiRefreshKey) {
      return;
    }
    _lastOfflinePoiRefreshKey = refreshKey;
    final requestId = ++_offlinePoiRefreshRequestId;

    try {
      final archive = await _getOfflinePoiArchive(basemapPath);
      final markers = <Marker>[];
      final seen = <String>{};
      const maxMarkers = 160;

      for (var x = tileRange.$1; x <= tileRange.$2; x++) {
        for (var y = tileRange.$3; y <= tileRange.$4; y++) {
          if (markers.length >= maxMarkers) break;
          try {
            final tileId = pmtiles.ZXY(zoom, x, y).toTileId();
            final tile = await archive.tile(tileId);
            final bytes = tile.bytes();
            if (bytes.isEmpty) continue;
            final vectorTile = vt.VectorTile.fromBytes(
              bytes: Uint8List.fromList(bytes),
            );

            for (final layer in vectorTile.layers) {
              if (layer.name != 'pois') continue;
              for (final feature in layer.features) {
                if (markers.length >= maxMarkers) break;
                if (feature.type != vt.VectorTileGeomType.POINT) continue;

                final properties = feature.decodeProperties();
                final kind =
                    properties['kind']?.dartStringValue?.trim().toLowerCase();
                if (kind == null || kind.isEmpty) continue;
                final spec = await _offlinePoiMarkerSpec(kind);
                if (spec == null) continue;

                final projectedPoints = _projectOfflinePoiFeaturePoints(
                  feature: feature,
                  tileX: x,
                  tileY: y,
                  zoom: zoom,
                );
                for (final coords in projectedPoints) {
                  if (coords.length < 2) continue;
                  _tryAddOfflinePoiMarker(
                    markers: markers,
                    seen: seen,
                    spec: spec,
                    lat: coords[1],
                    lng: coords[0],
                    kind: kind,
                  );
                  if (markers.length >= maxMarkers) break;
                }
              }
            }
          } catch (e) {
            debugPrint('[BASEMAP] Offline POI tile skipped z$zoom/$x/$y: $e');
          }
        }
      }

      if (!mounted || requestId != _offlinePoiRefreshRequestId) return;
      setState(() {
        _offlinePoiMarkers = markers;
      });
      debugPrint(
        '[BASEMAP] Offline POI overlay markers=${markers.length} z=$zoom',
      );
    } catch (e) {
      debugPrint('[BASEMAP] Offline POI overlay failed: $e');
    }
  }

  void _tryAddOfflinePoiMarker({
    required List<Marker> markers,
    required Set<String> seen,
    required _OfflinePoiMarkerSpec spec,
    required double lat,
    required double lng,
    required String kind,
  }) {
    if (lat.isNaN || lng.isNaN) return;
    final dedupeKey =
        '$kind:${lat.toStringAsFixed(5)}:${lng.toStringAsFixed(5)}';
    if (!seen.add(dedupeKey)) return;

    markers.add(
      Marker(
        point: LatLng(lat, lng),
        width: spec.size + 10,
        height: spec.size + 14,
        child: IgnorePointer(
          child: Transform.translate(
            offset: const Offset(0, -6),
            child: Center(
              child: SizedBox(
                width: spec.size,
                height: spec.size,
                child: spec.assetPath != null
                    ? SvgPicture.asset(
                        spec.assetPath!,
                        width: spec.size,
                        height: spec.size,
                        fit: BoxFit.contain,
                      )
                    : Icon(
                        spec.icon,
                        size: spec.size,
                        color: spec.color,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<List<double>> _projectOfflinePoiFeaturePoints({
    required vt.VectorTileFeature feature,
    required int tileX,
    required int tileY,
    required int zoom,
  }) {
    final geometry = feature.decodeGeometry<vt.Geometry?>();
    final extent = feature.extent;
    if (geometry == null || extent == null) {
      return const [];
    }

    final size = extent * (1 << zoom);
    final x0 = extent * tileX;
    final y0 = extent * tileY;

    switch (geometry.type) {
      case vt.GeometryType.Point:
        final point = geometry as vt.GeometryPoint;
        return [_projectOfflinePoiPoint(point.coordinates, x0, y0, size)];
      case vt.GeometryType.MultiPoint:
        final points = geometry as vt.GeometryMultiPoint;
        return points.coordinates
            .map((point) => _projectOfflinePoiPoint(point, x0, y0, size))
            .toList(growable: false);
      default:
        return const [];
    }
  }

  List<double> _projectOfflinePoiPoint(
    List<double> point,
    int x0,
    int y0,
    int size,
  ) {
    final y2 = 180 - (point[1] + y0) * 360 / size;
    return [
      (point[0] + x0) * 360 / size - 180,
      360 / math.pi * math.atan(math.exp(y2 * math.pi / 180)) - 90,
    ];
  }

  Future<_OfflinePoiMarkerSpec?> _offlinePoiMarkerSpec(String kind) async {
    final normalizedKind = kind.trim().toLowerCase();
    if (_offlinePoiSpecCache.containsKey(normalizedKind)) {
      return _offlinePoiSpecCache[normalizedKind];
    }

    final spec = await _resolveOfflinePoiMarkerSpec(normalizedKind);
    _offlinePoiSpecCache[normalizedKind] = spec;
    return spec;
  }

  Future<_OfflinePoiMarkerSpec?> _resolveOfflinePoiMarkerSpec(
    String normalizedKind,
  ) async {
    if (_offlinePoiKindsWithoutIcon.contains(normalizedKind)) {
      return null;
    }

    final assetPath = await _firstExistingOfflinePoiAsset(
      _offlinePoiIconCandidates(normalizedKind),
    );
    if (assetPath != null) {
      return _OfflinePoiMarkerSpec.asset(assetPath: assetPath);
    }

    switch (normalizedKind) {
      case 'school':
      case 'college':
      case 'university':
      case 'kindergarten':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.school,
          color: Colors.indigo,
        );
      case 'post_office':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.local_post_office,
          color: Colors.deepOrange,
        );
      case 'marketplace':
      case 'supermarket':
      case 'mall':
      case 'convenience':
      case 'bakery':
      case 'books':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.storefront,
          color: Colors.teal,
        );
      case 'restaurant':
      case 'cafe':
      case 'bar':
      case 'pub':
      case 'fast_food':
      case 'ice_cream':
      case 'caterer':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.restaurant,
          color: Colors.deepOrange,
        );
      case 'hotel':
      case 'guest_house':
      case 'hostel':
      case 'motel':
      case 'lodging':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.hotel,
          color: Colors.blueGrey,
        );
      case 'hospital':
      case 'clinic':
      case 'doctors':
      case 'dentist':
      case 'pharmacy':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.local_hospital,
          color: Colors.red,
        );
      case 'place_of_worship':
      case 'mosque':
      case 'church':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.account_balance,
          color: Colors.brown,
        );
      case 'museum':
      case 'library':
      case 'cinema':
      case 'theatre':
      case 'attraction':
      case 'artwork':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.attractions,
          color: Colors.purple,
        );
      case 'stadium':
      case 'sports_centre':
      case 'pitch':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.sports_soccer,
          color: Colors.green,
        );
      case 'parking':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.local_parking,
          color: Colors.indigo,
        );
      case 'bank':
      case 'atm':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.account_balance,
          color: Colors.blue,
        );
      case 'bus_station':
      case 'bus_stop':
      case 'train_station':
      case 'ferry_terminal':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.directions_bus,
          color: Colors.blue,
        );
      case 'fuel':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.local_gas_station,
          color: Colors.redAccent,
        );
      case 'aerodrome':
        return const _OfflinePoiMarkerSpec.material(
          icon: Icons.flight,
          color: Colors.blueGrey,
        );
      default:
        return null;
    }
  }

  Future<String?> _firstExistingOfflinePoiAsset(
    List<String> candidateAssets,
  ) async {
    for (final assetPath in candidateAssets) {
      if (await _offlinePoiAssetExists(assetPath)) {
        return assetPath;
      }
    }
    return null;
  }

  Future<bool> _offlinePoiAssetExists(String assetPath) async {
    final cached = _offlinePoiAssetAvailabilityCache[assetPath];
    if (cached != null) {
      return cached;
    }

    try {
      await rootBundle.load(assetPath);
      _offlinePoiAssetAvailabilityCache[assetPath] = true;
      return true;
    } catch (_) {
      _offlinePoiAssetAvailabilityCache[assetPath] = false;
      return false;
    }
  }

  List<String> _offlinePoiIconCandidates(String normalizedKind) {
    final exactCandidates = _offlinePoiExactIconCandidates[normalizedKind];
    if (exactCandidates != null && exactCandidates.isNotEmpty) {
      return exactCandidates;
    }

    final underscoreKind = normalizedKind.replaceAll('-', '_');
    final hyphenKind = normalizedKind.replaceAll('_', '-');
    return [
      '$_offlinePoiOpenStreetMapCartoRoot/amenity/$underscoreKind.svg',
      '$_offlinePoiOpenStreetMapCartoRoot/shop/$underscoreKind.svg',
      '$_offlinePoiOpenStreetMapCartoRoot/tourism/$underscoreKind.svg',
      '$_offlinePoiOpenStreetMapCartoRoot/highway/$underscoreKind.svg',
      '$_offlinePoiOpenStreetMapCartoRoot/leisure/$underscoreKind.svg',
      '$_offlinePoiOpenStreetMapCartoRoot/historic/$underscoreKind.svg',
      '$_offlinePoiOsmicRoot/amenity/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/eat-drink/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/accommodation/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/health/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/money/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/religious/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/shop/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/tourism/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/transport/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/administration/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/outdoor/$hyphenKind-14.svg',
      '$_offlinePoiOsmicRoot/nature/$hyphenKind-14.svg',
      '$_offlinePoiTemakiRoot/$hyphenKind.svg',
    ];
  }

  bool _containsExpressionOperator(dynamic value, String operatorName) {
    if (value is List) {
      if (value.isNotEmpty && value.first == operatorName) {
        return true;
      }
      for (final entry in value) {
        if (_containsExpressionOperator(entry, operatorName)) {
          return true;
        }
      }
    } else if (value is Map) {
      for (final entry in value.values) {
        if (_containsExpressionOperator(entry, operatorName)) {
          return true;
        }
      }
    }
    return false;
  }

  String _mapProtomapsFontFamily(String? fontName) {
    final normalized = fontName?.trim().toLowerCase() ?? '';
    if (normalized.contains('devanagari')) {
      return 'Noto Sans Devanagari';
    }
    if (normalized.contains('medium')) {
      return 'Noto Sans Medium';
    }
    if (normalized.contains('italic')) {
      return 'Noto Sans Italic';
    }
    if (normalized.contains('noto sans')) {
      return 'Noto Sans Regular';
    }
    return 'Noto Sans Regular';
  }

  @override
  Widget build(BuildContext context) {
    final allMarkers = [
      ...widget.markers,
      ...widget.formMarkers,
      if (widget.gpsEnabled)
        Marker(
          point: widget.userPosition,
          width: 18,
          height: 18,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
    ];

    final fallbackCenter = widget.basemapCenter ?? BasemapConstants.fallbackCenter;
    final requestedCenterRaw =
        widget.gpsEnabled ? widget.userPosition : fallbackCenter;
    final desiredInitialZoom =
        widget.gpsEnabled
            ? 15.0
            : (widget.basemapDefaultZoom ??
                BasemapConstants.fallbackDefaultZoom);
    final minZoom = widget.basemapMinZoom ?? BasemapConstants.fallbackMinZoom;
    final maxZoom = widget.basemapMaxZoom ?? BasemapConstants.fallbackMaxZoom;
    final showOnlineBasemap = widget.useOnlineBasemap && !widget.isSatellite;
    final hasRasterBasemap =
        !showOnlineBasemap &&
        _rasterTileProvider != null &&
        (widget.offlineBasemapPath?.trim().isNotEmpty ?? false);
    final hasVectorBasemap =
        !showOnlineBasemap &&
        _vectorTileProvider != null &&
        _vectorTheme != null &&
        _normalizedBasemapFormat(widget.offlineBasemapFormat) == 'pmtiles' &&
        (widget.offlineBasemapPath?.trim().isNotEmpty ?? false);
    // In rasterized vector mode, the provider can still serve translated tiles
    // above its native zoom. Keep the user-facing zoom limit from the active
    // basemap package instead of clamping to the provider's native max zoom.
    final effectiveMaxZoom = maxZoom;
    final initialZoom =
        desiredInitialZoom.clamp(minZoom, effectiveMaxZoom).toDouble();
    final hasOfflineBasemap =
        (hasRasterBasemap || hasVectorBasemap) &&
        (widget.offlineBasemapPath?.trim().isNotEmpty ?? false);
    final initialCenter =
        _controllerReady ? _mapController.camera.center : requestedCenterRaw;

    final basemapMessage = showOnlineBasemap
        ? null
        : _basemapLoadError != null
            ? "Impossible de charger la carte offline active."
            : (!hasOfflineBasemap ? widget.basemapUnavailableMessage : null);

    return Stack(
      children: [
        FlutterMap(
          key: const PageStorageKey<String>('home-flutter-map'),
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            minZoom: minZoom,
            maxZoom: effectiveMaxZoom,
            cameraConstraint: const CameraConstraint.unconstrained(),
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
            onTap: (tapPosition, latLng) {
              widget.onMapTap?.call(tapPosition, latLng);
            },
            onMapEvent: (event) {
              if (event is MapEventMoveStart) {
                widget.onUserInteraction?.call();
              } else if (event is MapEventMoveEnd) {
                widget.onCameraIdle?.call(
                  _mapController.camera.center,
                  _mapController.camera.zoom,
                );
                _queueOfflinePoiMarkerRefresh();
              }
            },
          ),
          children: [
            if (showOnlineBasemap)
              TileLayer(
                urlTemplate: MapWidget.onlineOsmUrlTemplate,
                userAgentPackageName: 'com.srm.collecte',
                maxZoom: math.max(effectiveMaxZoom, 19),
              ),
            if (hasRasterBasemap)
              TileLayer(
                tileProvider: _rasterTileProvider!,
                userAgentPackageName: 'com.example.srmcollecte',
                maxZoom: effectiveMaxZoom,
              ),
            if (hasVectorBasemap)
              vmt.VectorTileLayer(
                theme: _vectorTheme!,
                sprites: _vectorSprites,
                tileProviders: vmt.TileProviders({
                  'protomaps': _vectorTileProvider!,
                }),
                // Use rasterized vector tiles for stability on Android while
                // still rendering labels and icons from the local theme.
                layerMode: vmt.VectorTileLayerMode.raster,
                maximumZoom: effectiveMaxZoom,
                fileCacheTtl: Duration.zero,
              ),
            PolylineLayer(
              polylines: widget.polylines,
              hitNotifier: _polylineHitNotifier,
            ),
            if (widget.polygons.isNotEmpty)
              PolygonLayer(
                polygons: widget.polygons,
                hitNotifier: _polygonHitNotifier,
              ),
            if (!showOnlineBasemap && _offlinePoiMarkers.isNotEmpty)
              MarkerLayer(markers: _offlinePoiMarkers),
            MarkerLayer(markers: allMarkers),
          ],
        ),
        if (kDebugMode &&
            !showOnlineBasemap &&
            hasVectorBasemap &&
            _vectorDetailsSummary != null &&
            _basemapLoadError == null)
          Positioned(
            top: 8,
            left: 12,
            right: 70,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (_vectorDetailsWarning != null
                          ? Colors.orange
                          : Colors.black)
                      .withOpacity(0.72),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _vectorDetailsWarning == null
                      ? _vectorDetailsSummary!
                      : '$_vectorDetailsSummary\n$_vectorDetailsWarning',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (_isBasemapLoading || basemapMessage != null)
          Positioned(
            top: 8,
            left: 12,
            right: 70,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_isBasemapLoading) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                    ] else
                      const Icon(
                        Icons.map_outlined,
                        color: Colors.orange,
                        size: 18,
                      ),
                    Expanded(
                      child: Text(
                        _isBasemapLoading
                            ? "Chargement de la carte offline..."
                            : basemapMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (widget.showMapButtons)
          Positioned(
            top: 8,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location, color: Colors.blue),
                onPressed: _goToUserLocation,
                tooltip: 'Ma position',
              ),
            ),
          ),
        if (widget.showMapButtons)
          Positioned(
            right: 5,
            bottom: 10,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.black87),
                    onPressed: _zoomIn,
                    tooltip: 'Zoom avant',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove, color: Colors.black87),
                    onPressed: _zoomOut,
                    tooltip: 'Zoom arriere',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LocalProtomapsThemeBundle {
  final vtr.Theme theme;
  final _VectorDetailsCheck check;

  const _LocalProtomapsThemeBundle({
    required this.theme,
    required this.check,
  });
}

class _VectorDetailsCheck {
  final int layerCount;
  final int symbolLayerCount;
  final int textLayerCount;
  final int iconLayerCount;

  const _VectorDetailsCheck({
    required this.layerCount,
    required this.symbolLayerCount,
    required this.textLayerCount,
    required this.iconLayerCount,
  });
}

class _SpriteLoadResult {
  final vmt.SpriteStyle style;
  final int spriteCount;
  final Set<String> spriteNames;

  const _SpriteLoadResult({
    required this.style,
    required this.spriteCount,
    required this.spriteNames,
  });
}

class _OfflinePoiMarkerSpec {
  final String? assetPath;
  final IconData? icon;
  final Color? color;
  final double size;

  const _OfflinePoiMarkerSpec.asset({
    required this.assetPath,
  })  : icon = null,
        color = null,
        size = 18;

  const _OfflinePoiMarkerSpec.material({
    required this.icon,
    required this.color,
  })  : assetPath = null,
        size = 16;
}

class MapTypeToggle extends StatelessWidget {
  final bool isSatellite;
  final Function(bool) onMapTypeChanged;

  const MapTypeToggle({
    super.key,
    required this.isSatellite,
    required this.onMapTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 55,
      right: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onMapTypeChanged(!isSatellite),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSatellite ? Icons.map : Icons.satellite,
                    size: 24,
                    color: isSatellite ? Colors.blue : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSatellite ? 'Carte' : 'Satellite',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DownloadedLinesToggle extends StatelessWidget {
  final bool isOn;
  final int count;
  final ValueChanged<bool> onChanged;

  const DownloadedLinesToggle({
    super.key,
    required this.isOn,
    required this.onChanged,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 10,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(!isOn),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.alt_route,
                    size: 22,
                    color: isOn ? const Color(0xFFB86E1D) : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Lignes téléchargées',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isOn
                            ? const Color(0xFFB86E1D).withOpacity(0.12)
                            : Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isOn ? const Color(0xFFB86E1D) : Colors.grey,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOn
                              ? const Color(0xFFB86E1D)
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

