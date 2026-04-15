import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart' as vmt;
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import '../../core/constants/basemap_constants.dart';

class MapWidget extends StatefulWidget {
  final LatLng userPosition;
  final bool gpsEnabled;
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
  final String? offlineBasemapPath;
  final String? offlineBasemapFormat;
  final String? basemapUnavailableMessage;
  final LatLng? basemapCenter;
  final LatLngBounds? basemapBounds;
  final double? basemapDefaultZoom;
  final double? basemapMinZoom;
  final double? basemapMaxZoom;

  const MapWidget({
    super.key,
    required this.userPosition,
    required this.gpsEnabled,
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
    this.offlineBasemapPath,
    this.offlineBasemapFormat,
    this.basemapUnavailableMessage,
    this.basemapCenter,
    this.basemapBounds,
    this.basemapDefaultZoom,
    this.basemapMinZoom,
    this.basemapMaxZoom,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  static const String _protomapsLightSpriteJsonAsset =
      'assets/basemaps/protomaps/sprites/v4/light.json';
  static const String _protomapsLightSpritePngAsset =
      'assets/basemaps/protomaps/sprites/v4/light.png';

  late final MapController _mapController;
  bool _controllerReady = false;
  TileProvider? _rasterTileProvider;
  vmt.VectorTileProvider? _vectorTileProvider;
  vtr.Theme? _vectorTheme;
  vmt.SpriteStyle? _vectorSprites;
  String? _loadedBasemapPath;
  String? _loadedBasemapFormat;
  String? _basemapLoadError;
  bool _isBasemapLoading = false;

  final _polylineHitNotifier = ValueNotifier<LayerHitResult<Object>?>(null);
  final _polygonHitNotifier = ValueNotifier<LayerHitResult<Object>?>(null);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMapCreated(_mapController);
      setState(() => _controllerReady = true);
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
      _mapController.move(
        _mapController.camera.center,
        _mapController.camera.zoom + 1,
      );
    }
  }

  void _zoomOut() {
    if (_controllerReady) {
      _mapController.move(
        _mapController.camera.center,
        _mapController.camera.zoom - 1,
      );
    }
  }

  void _goToUserLocation() {
    if (_controllerReady) {
      widget.onGpsButtonPressed?.call();
      _mapController.move(widget.userPosition, 17);
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
    if (basemapPath == _loadedBasemapPath &&
        normalizedFormat == _loadedBasemapFormat &&
        (basemapPath == null ||
            _rasterTileProvider != null ||
            (_vectorTileProvider != null && _vectorTheme != null))) {
      return;
    }

    final previousRasterProvider = _rasterTileProvider;
    _rasterTileProvider = null;
    _vectorTileProvider = null;
    _vectorTheme = null;
    _vectorSprites = null;
    _loadedBasemapPath = basemapPath;
    _loadedBasemapFormat = normalizedFormat;
    _basemapLoadError = null;

    if (basemapPath == null || basemapPath.isEmpty) {
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
      });
    }

    previousRasterProvider?.dispose();

    try {
      TileProvider? rasterProvider;
      vmt.VectorTileProvider? vectorProvider;
      vtr.Theme? vectorTheme;
      vmt.SpriteStyle? vectorSprites;
      switch (normalizedFormat) {
        case 'pmtiles':
          vectorProvider = await PmTilesVectorTileProvider.fromSource(
            basemapPath,
          );
          vectorTheme = ProtomapsThemes.lightV4();
          vectorSprites = await _loadLocalProtomapsLightSprites();
          break;
        case 'mbtiles':
        default:
          rasterProvider = MbTilesTileProvider.fromPath(path: basemapPath);
          break;
      }

      if (!mounted ||
          widget.offlineBasemapPath != basemapPath ||
          _normalizedBasemapFormat(widget.offlineBasemapFormat) !=
              normalizedFormat) {
        rasterProvider?.dispose();
        return;
      }

      setState(() {
        _rasterTileProvider = rasterProvider;
        _vectorTileProvider = vectorProvider;
        _vectorTheme = vectorTheme;
        _vectorSprites = vectorSprites;
        _loadedBasemapPath = basemapPath;
        _loadedBasemapFormat = normalizedFormat;
        _isBasemapLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _basemapLoadError = e.toString();
        _isBasemapLoading = false;
      });
    }
  }

  Future<vmt.SpriteStyle> _loadLocalProtomapsLightSprites() async {
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

    return vmt.SpriteStyle(
      atlasProvider: () async => atlasBytes.buffer.asUint8List(),
      index: spriteIndex,
    );
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
    final requestedCenter =
        widget.gpsEnabled ? widget.userPosition : fallbackCenter;
    final initialZoom =
        widget.gpsEnabled
            ? 15.0
            : (widget.basemapDefaultZoom ??
                BasemapConstants.fallbackDefaultZoom);
    final minZoom = widget.basemapMinZoom ?? BasemapConstants.fallbackMinZoom;
    final maxZoom = widget.basemapMaxZoom ?? BasemapConstants.fallbackMaxZoom;
    final basemapBounds =
        widget.basemapBounds ?? BasemapConstants.fallbackBounds;
    final hasRasterBasemap =
        _rasterTileProvider != null &&
        (widget.offlineBasemapPath?.trim().isNotEmpty ?? false);
    final hasVectorBasemap =
        _vectorTileProvider != null &&
        _vectorTheme != null &&
        _normalizedBasemapFormat(widget.offlineBasemapFormat) == 'pmtiles' &&
        (widget.offlineBasemapPath?.trim().isNotEmpty ?? false);
    final hasOfflineBasemap =
        (hasRasterBasemap || hasVectorBasemap) &&
        (widget.offlineBasemapPath?.trim().isNotEmpty ?? false);
    final currentCenter =
        _controllerReady ? _mapController.camera.center : requestedCenter;
    final shouldConstrainCamera =
        hasOfflineBasemap && basemapBounds.contains(currentCenter);
    final initialCenter =
        shouldConstrainCamera && !basemapBounds.contains(requestedCenter)
            ? fallbackCenter
            : requestedCenter;

    final basemapMessage = _basemapLoadError != null
        ? "Impossible de charger la carte offline active."
        : (!hasOfflineBasemap ? widget.basemapUnavailableMessage : null);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            minZoom: minZoom,
            maxZoom: maxZoom,
            cameraConstraint: shouldConstrainCamera
                ? CameraConstraint.containCenter(bounds: basemapBounds)
                : const CameraConstraint.unconstrained(),
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
            onMapEvent: (event) {
              if (event is MapEventMoveStart) {
                widget.onUserInteraction?.call();
              }
            },
          ),
          children: [
            if (hasRasterBasemap)
              TileLayer(
                tileProvider: _rasterTileProvider!,
                userAgentPackageName: 'com.example.srmcollecte',
                maxZoom: maxZoom,
              ),
            if (hasVectorBasemap)
              vmt.VectorTileLayer(
                theme: _vectorTheme!,
                sprites: _vectorSprites,
                tileProviders: vmt.TileProviders({
                  'protomaps': _vectorTileProvider!,
                }),
                layerMode: vmt.VectorTileLayerMode.vector,
                maximumZoom: maxZoom,
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
            MarkerLayer(markers: allMarkers),
          ],
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

class DownloadedPistesToggle extends StatelessWidget {
  final bool isOn;
  final int count;
  final ValueChanged<bool> onChanged;

  const DownloadedPistesToggle({
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
                    'Pistes telechargees',
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

class DownloadedChausseesToggle extends StatelessWidget {
  final bool isOn;
  final int count;
  final ValueChanged<bool> onChanged;

  const DownloadedChausseesToggle({
    super.key,
    required this.isOn,
    required this.onChanged,
    this.count = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 206,
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
                    Icons.alt_route_rounded,
                    size: 22,
                    color: isOn ? const Color(0xFFB86E1D) : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Chaussees telechargees',
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
