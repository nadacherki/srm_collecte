import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class OfflineOrthophotoDownloadResult {
  final bool success;
  final bool partial;
  final int downloadedTiles;
  final int alreadyCachedTiles;
  final int skippedTiles;
  final String? warningMessage;
  final String? errorMessage;

  const OfflineOrthophotoDownloadResult({
    required this.success,
    this.partial = false,
    this.downloadedTiles = 0,
    this.alreadyCachedTiles = 0,
    this.skippedTiles = 0,
    this.warningMessage,
    this.errorMessage,
  });
}

class OrthophotoLayerState {
  final String orthoId;
  final String version;
  final String format;
  final int minZoom;
  final int maxZoom;
  final int tileCount;
  final int totalBytes;
  final String? tilesUrl;
  final String? tileUrlTemplate;
  final double opacity;

  const OrthophotoLayerState({
    required this.orthoId,
    required this.version,
    required this.format,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.totalBytes,
    this.tilesUrl,
    this.tileUrlTemplate,
    this.opacity = 0.75,
  });

  factory OrthophotoLayerState.fromManifest(Map<String, dynamic> manifest) {
    return OrthophotoLayerState(
      orthoId: (manifest['ortho_id'] ?? '').toString(),
      version: (manifest['version'] ?? '').toString(),
      format: _normalizeTileFormat(manifest['format']),
      minZoom: _asInt(manifest['min_zoom']) ?? 17,
      maxZoom: _asInt(manifest['max_zoom']) ?? 21,
      tileCount: _asInt(manifest['tile_count']) ?? 0,
      totalBytes: _asInt(manifest['total_bytes']) ?? 0,
      tilesUrl: manifest['tiles_url']?.toString(),
      tileUrlTemplate: manifest['tile_url_template']?.toString(),
      opacity: 0.75,
    );
  }

  factory OrthophotoLayerState.fromRow(Map<String, dynamic> row) {
    return OrthophotoLayerState(
      orthoId: (row['ortho_id'] ?? '').toString(),
      version: (row['version'] ?? '').toString(),
      format: _normalizeTileFormat(row['format']),
      minZoom: _asInt(row['min_zoom']) ?? 17,
      maxZoom: _asInt(row['max_zoom']) ?? 21,
      tileCount: _asInt(row['tile_count']) ?? 0,
      totalBytes: _asInt(row['total_bytes']) ?? 0,
      tilesUrl: row['tiles_url']?.toString(),
      tileUrlTemplate: row['tile_url_template']?.toString(),
      opacity: _asDouble(row['opacity']) ?? 0.75,
    );
  }

  bool get isUsable => orthoId.isNotEmpty && version.isNotEmpty;

  String get tileFileExtension => _tileFileExtension(format);

  bool get isGeoTiff => tileFileExtension == 'tif';
}

class OrthophotoTileSpec {
  final String orthoId;
  final String version;
  final int z;
  final int x;
  final int y;
  final int sizeBytes;
  final String sha256;
  final String url;
  final String format;

  const OrthophotoTileSpec({
    required this.orthoId,
    required this.version,
    required this.z,
    required this.x,
    required this.y,
    required this.sizeBytes,
    required this.sha256,
    required this.url,
    this.format = 'tif',
  });

  factory OrthophotoTileSpec.fromMap(
    Map<String, dynamic> row, {
    required String orthoId,
    required String version,
  }) {
    return OrthophotoTileSpec(
      orthoId: orthoId,
      version: version,
      z: _asInt(row['z']) ?? 0,
      x: _asInt(row['x']) ?? 0,
      y: _asInt(row['y']) ?? 0,
      sizeBytes: _asInt(row['size_bytes']) ?? 0,
      sha256: (row['sha256'] ?? '').toString().trim().toLowerCase(),
      url: (row['url'] ?? '').toString().trim(),
      format: _normalizeTileFormat(row['format']),
    );
  }

  String get key => '$orthoId/$version/$z/$x/$y';

  String get tileFileExtension => _tileFileExtension(format);
}

class OfflineOrthophotoService {
  static final OfflineOrthophotoService _instance =
      OfflineOrthophotoService._internal();

  factory OfflineOrthophotoService({
    DatabaseHelper? databaseHelper,
    Directory? cacheRootOverride,
    http.Client? httpClient,
  }) {
    if (databaseHelper != null ||
        cacheRootOverride != null ||
        httpClient != null) {
      return OfflineOrthophotoService._internal(
        databaseHelper: databaseHelper,
        cacheRootOverride: cacheRootOverride,
        httpClient: httpClient,
      );
    }
    return _instance;
  }

  OfflineOrthophotoService._internal({
    DatabaseHelper? databaseHelper,
    Directory? cacheRootOverride,
    http.Client? httpClient,
  })  : _db = databaseHelper ?? DatabaseHelper(),
        _cacheRootOverride = cacheRootOverride,
        _httpClient = httpClient ?? http.Client();

  static const int maxConcurrentDownloads = 3;
  static const int defaultMaxCacheBytes = 4 * 1024 * 1024 * 1024;

  final DatabaseHelper _db;
  final Directory? _cacheRootOverride;
  final http.Client _httpClient;
  final Set<String> _inFlightTileKeys = <String>{};
  final Map<String, OrthophotoTileSpec> _tileSpecsByKey = {};

  Directory? _cacheRoot;
  OrthophotoLayerState? _activeState;
  Future<void>? _warmUpFuture;

  OrthophotoLayerState? get activeStateSync => _activeState;

  Future<void> warmUp() {
    return _warmUpFuture ??= _warmUp();
  }

  Future<void> _warmUp() async {
    _cacheRoot = await _resolveCacheRoot();
    final stateRow = await _db.getActiveOrthophotoState();
    if (stateRow != null) {
      final state = OrthophotoLayerState.fromRow(stateRow);
      if (state.isUsable) {
        _activeState = state;
      }
    }
  }

  Future<Directory> _resolveCacheRoot() async {
    final override = _cacheRootOverride;
    if (override != null) {
      if (!await override.exists()) {
        await override.create(recursive: true);
      }
      return override;
    }
    final root = await getApplicationSupportDirectory();
    final dir = Directory(path.join(root.path, 'orthophotos'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _ensureCacheRoot() async {
    final cached = _cacheRoot;
    if (cached != null) return cached;
    _cacheRoot = await _resolveCacheRoot();
    return _cacheRoot!;
  }

  File? localTileFileIfReady(int z, int x, int y) {
    final state = _activeState;
    final root = _cacheRoot;
    if (state == null || root == null || !state.isUsable) return null;
    return File(path.join(
      root.path,
      state.orthoId,
      state.version,
      z.toString(),
      x.toString(),
      '$y.${state.tileFileExtension}',
    ));
  }

  Future<File> _localTileFile(OrthophotoTileSpec tile) async {
    final root = await _ensureCacheRoot();
    final dir = Directory(path.join(
      root.path,
      tile.orthoId,
      tile.version,
      tile.z.toString(),
      tile.x.toString(),
    ));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final extension = tile.tileFileExtension;
    return File(path.join(dir.path, '${tile.y}.$extension'));
  }

  Future<OfflineOrthophotoDownloadResult> ensureAgentOrthophotoDownloaded({
    void Function(double progress, String operation, int processed, int total)?
        onProgress,
    int maxCacheBytes = defaultMaxCacheBytes,
  }) async {
    Map<String, dynamic> manifestMap;
    try {
      manifestMap = await ApiService.fetchOrthophotoAgentManifest();
    } catch (e) {
      return OfflineOrthophotoDownloadResult(
        success: false,
        errorMessage: _shortError(e),
      );
    }

    if (manifestMap['success'] != true) {
      return OfflineOrthophotoDownloadResult(
        success: false,
        errorMessage: (manifestMap['message'] ?? 'Manifest orthophoto invalide')
            .toString(),
      );
    }

    final state = OrthophotoLayerState.fromManifest(manifestMap);
    if (!state.isUsable || state.tileCount == 0) {
      await _db.upsertOrthophotoLayerState(
        orthoId: state.orthoId,
        version: state.version,
        format: state.format,
        minZoom: state.minZoom,
        maxZoom: state.maxZoom,
        bounds4326: _boundsFromManifest(manifestMap),
        tileCount: state.tileCount,
        totalBytes: state.totalBytes,
        tilesUrl: state.tilesUrl,
        tileUrlTemplate: state.tileUrlTemplate,
      );
      _activeState = state;
      return const OfflineOrthophotoDownloadResult(
        success: true,
        warningMessage: 'Aucune tuile orthophoto disponible pour cette zone.',
      );
    }

    await _db.upsertOrthophotoLayerState(
      orthoId: state.orthoId,
      version: state.version,
      format: state.format,
      minZoom: state.minZoom,
      maxZoom: state.maxZoom,
      bounds4326: _boundsFromManifest(manifestMap),
      tileCount: state.tileCount,
      totalBytes: state.totalBytes,
      tilesUrl: state.tilesUrl,
      tileUrlTemplate: state.tileUrlTemplate,
    );
    _activeState = state;
    await _ensureCacheRoot();

    final lowZoomOnly = state.totalBytes > maxCacheBytes;
    final totalForProgress = lowZoomOnly ? state.tileCount : state.tileCount;
    var processed = 0;
    var downloaded = 0;
    var cached = 0;
    var skipped = 0;
    var page = 1;
    var nextPage = 1;

    while (nextPage > 0) {
      Map<String, dynamic> pageMap;
      try {
        pageMap = await ApiService.fetchOrthophotoAgentTiles(
          page: page,
          pageSize: 500,
        );
      } catch (e) {
        return OfflineOrthophotoDownloadResult(
          success: downloaded > 0 || cached > 0,
          partial: true,
          downloadedTiles: downloaded,
          alreadyCachedTiles: cached,
          skippedTiles: skipped,
          warningMessage:
              'Orthophoto partielle: ${downloaded + cached} tuiles locales.',
          errorMessage: _shortError(e),
        );
      }

      final items = (pageMap['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => OrthophotoTileSpec.fromMap(
                Map<String, dynamic>.from(item),
                orthoId: state.orthoId,
                version: state.version,
              ))
          .where((tile) => tile.url.isNotEmpty && tile.sha256.isNotEmpty)
          .where((tile) => !lowZoomOnly || tile.z <= state.minZoom + 1)
          .toList();

      final stats = await _downloadTiles(
        items,
        onTileDone: () {
          processed++;
          onProgress?.call(
            totalForProgress <= 0 ? 0 : processed / totalForProgress,
            'Telechargement orthophoto - tuile $processed/$totalForProgress',
            processed,
            totalForProgress,
          );
        },
      );
      downloaded += stats.downloaded;
      cached += stats.cached;
      skipped += stats.skipped;

      nextPage = _asInt(pageMap['next_page']) ?? 0;
      page = nextPage;
    }

    final downloadedBytes = await _db.getOrthophotoCacheBytes();
    await _db.upsertOrthophotoLayerState(
      orthoId: state.orthoId,
      version: state.version,
      format: state.format,
      minZoom: state.minZoom,
      maxZoom: state.maxZoom,
      bounds4326: _boundsFromManifest(manifestMap),
      tileCount: state.tileCount,
      totalBytes: state.totalBytes,
      tilesUrl: state.tilesUrl,
      tileUrlTemplate: state.tileUrlTemplate,
      downloadedTiles: downloaded + cached,
      downloadedBytes: downloadedBytes,
    );
    await evictCacheIfNeeded(maxCacheBytes: maxCacheBytes);

    return OfflineOrthophotoDownloadResult(
      success: true,
      partial: lowZoomOnly,
      downloadedTiles: downloaded,
      alreadyCachedTiles: cached,
      skippedTiles: skipped,
      warningMessage: lowZoomOnly
          ? 'Orthophoto lourde: seuls les zooms de base ont ete precharges.'
          : null,
    );
  }

  Future<void> queueVisibleTileDownload(
    int z,
    int x,
    int y, {
    VoidCallback? onTileAvailable,
  }) async {
    unawaited(_downloadVisibleTile(
      z,
      x,
      y,
      onTileAvailable: onTileAvailable,
    ));
  }

  Future<void> _downloadVisibleTile(
    int z,
    int x,
    int y, {
    VoidCallback? onTileAvailable,
  }) async {
    try {
      await warmUp();
      final state = _activeState;
      if (state == null || !state.isUsable) return;
      final key = '${state.orthoId}/${state.version}/$z/$x/$y';
      if (_inFlightTileKeys.contains(key)) return;

      var spec = _tileSpecsByKey[key];
      if (spec == null) {
        final page = await ApiService.fetchOrthophotoAgentTiles(
          page: 1,
          pageSize: 1,
          z: z,
          x: x,
          y: y,
        );
        final items = page['items'] as List? ?? const [];
        if (items.isEmpty || items.first is! Map) return;
        spec = OrthophotoTileSpec.fromMap(
          Map<String, dynamic>.from(items.first as Map),
          orthoId: state.orthoId,
          version: state.version,
        );
        if (spec.url.isEmpty || spec.sha256.isEmpty) return;
        _tileSpecsByKey[key] = spec;
      }

      final result = await _downloadTile(spec);
      if (result == _TileDownloadStatus.downloaded ||
          result == _TileDownloadStatus.cached) {
        onTileAvailable?.call();
      }
    } catch (e) {
      debugPrint('[ORTHO] tuile visible ignoree: ${_shortError(e)}');
    }
  }

  Future<_TileBatchStats> _downloadTiles(
    List<OrthophotoTileSpec> tiles, {
    required VoidCallback onTileDone,
  }) async {
    var nextIndex = 0;
    var downloaded = 0;
    var cached = 0;
    var skipped = 0;

    Future<void> worker() async {
      while (nextIndex < tiles.length) {
        final tile = tiles[nextIndex++];
        try {
          final status = await _downloadTile(tile);
          if (status == _TileDownloadStatus.downloaded) {
            downloaded++;
          } else if (status == _TileDownloadStatus.cached) {
            cached++;
          } else {
            skipped++;
          }
        } catch (e) {
          skipped++;
          debugPrint('[ORTHO] tuile ignoree ${tile.key}: ${_shortError(e)}');
        } finally {
          onTileDone();
        }
      }
    }

    final workerCount = tiles.length < maxConcurrentDownloads
        ? tiles.length
        : maxConcurrentDownloads;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return _TileBatchStats(
      downloaded: downloaded,
      cached: cached,
      skipped: skipped,
    );
  }

  Future<_TileDownloadStatus> _downloadTile(OrthophotoTileSpec tile) async {
    if (_inFlightTileKeys.contains(tile.key)) {
      return _TileDownloadStatus.skipped;
    }
    _inFlightTileKeys.add(tile.key);
    try {
      final targetFile = await _localTileFile(tile);
      if (await _isValidCachedTile(targetFile, tile.sha256)) {
        await _recordDownloadedTile(tile, targetFile);
        return _TileDownloadStatus.cached;
      }

      final tempFile = File('${targetFile.path}.part');
      final request = http.Request('GET', Uri.parse(tile.url));
      request.headers.addAll(_headers());
      final response =
          await _httpClient.send(request).timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      IOSink? sink;
      var writtenBytes = 0;
      try {
        sink = tempFile.openWrite(mode: FileMode.write);
        await for (final chunk in response.stream) {
          sink.add(chunk);
          writtenBytes += chunk.length;
        }
        await sink.flush();
      } finally {
        await sink?.close();
      }

      if (tile.sizeBytes > 0 && writtenBytes != tile.sizeBytes) {
        await _deleteIfExists(tempFile);
        throw Exception('taille tuile invalide');
      }

      if (!await _isValidCachedTile(tempFile, tile.sha256)) {
        await _deleteIfExists(tempFile);
        throw Exception('checksum tuile invalide');
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);
      await _recordDownloadedTile(tile, targetFile);
      await evictCacheIfNeeded();
      return _TileDownloadStatus.downloaded;
    } finally {
      _inFlightTileKeys.remove(tile.key);
    }
  }

  Future<void> _recordDownloadedTile(
    OrthophotoTileSpec tile,
    File targetFile,
  ) async {
    final now = DateTime.now().toIso8601String();
    await _db.upsertOrthophotoTileCache(
      orthoId: tile.orthoId,
      version: tile.version,
      z: tile.z,
      x: tile.x,
      y: tile.y,
      sha256: tile.sha256,
      sizeBytes:
          tile.sizeBytes > 0 ? tile.sizeBytes : await targetFile.length(),
      localPath: targetFile.path,
      status: 'downloaded',
      downloadedAt: now,
      lastAccessedAt: now,
    );
  }

  Future<bool> _isValidCachedTile(File file, String expectedSha256) async {
    if (!await file.exists()) return false;
    if (expectedSha256.isEmpty) return true;
    final actual = (await crypto.sha256.bind(file.openRead()).first).toString();
    return actual.toLowerCase() == expectedSha256.toLowerCase();
  }

  Future<void> evictCacheIfNeeded({
    int maxCacheBytes = defaultMaxCacheBytes,
  }) async {
    var total = await _db.getOrthophotoCacheBytes();
    if (total <= maxCacheBytes) return;

    final victims = await _db.getLeastRecentlyUsedOrthophotoTiles(limit: 200);
    for (final row in victims) {
      if (total <= maxCacheBytes) break;
      final localPath = row['local_path']?.toString();
      final sizeBytes = _asInt(row['size_bytes']) ?? 0;
      if (localPath != null && localPath.isNotEmpty) {
        await _deleteIfExists(File(localPath));
      }
      await _db.deleteOrthophotoTileCacheRow(
        orthoId: row['ortho_id'].toString(),
        version: row['version'].toString(),
        z: _asInt(row['z']) ?? 0,
        x: _asInt(row['x']) ?? 0,
        y: _asInt(row['y']) ?? 0,
      );
      total -= sizeBytes;
    }
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Map<String, String> _headers() => {
        if (ApiService.authToken != null)
          'Authorization': 'Bearer ${ApiService.authToken}',
        if (ApiService.userId != null)
          'X-User-Id': ApiService.userId!.toString(),
      };

  static List<double>? _boundsFromManifest(Map<String, dynamic> manifest) {
    final raw = manifest['bounds_4326'];
    if (raw is! List || raw.length != 4) return null;
    final values = raw.map(_asDouble).toList();
    if (values.any((value) => value == null)) return null;
    return values.cast<double>();
  }

  static String _shortError(Object error) {
    var value = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isEmpty) return 'erreur inconnue';
    return value.length > 180 ? value.substring(0, 180) : value;
  }
}

class OrthophotoTileProvider extends TileProvider {
  OrthophotoTileProvider({
    required this.service,
    this.onTileAvailable,
  });

  final OfflineOrthophotoService service;
  final VoidCallback? onTileAvailable;

  static final Uint8List _transparentPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0l'
    'EQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
  );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final state = service.activeStateSync;
    final file = service.localTileFileIfReady(
      coordinates.z,
      coordinates.x,
      coordinates.y,
    );
    if (file != null && file.existsSync()) {
      unawaited(_touch(coordinates));
      if (state?.isGeoTiff ?? false) {
        return GeoTiffFileImage(file);
      }
      return FileImage(file);
    }

    service.queueVisibleTileDownload(
      coordinates.z,
      coordinates.x,
      coordinates.y,
      onTileAvailable: onTileAvailable,
    );
    return MemoryImage(_transparentPng);
  }

  Future<void> _touch(TileCoordinates coordinates) async {
    final state = service.activeStateSync;
    if (state == null) return;
    await DatabaseHelper().touchOrthophotoTile(
      orthoId: state.orthoId,
      version: state.version,
      z: coordinates.z,
      x: coordinates.x,
      y: coordinates.y,
    );
  }
}

class GeoTiffFileImage extends ImageProvider<GeoTiffFileImage> {
  const GeoTiffFileImage(this.file, {this.scale = 1.0});

  final File file;
  final double scale;

  @override
  Future<GeoTiffFileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<GeoTiffFileImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    GeoTiffFileImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadImageAsync(key, decode),
      scale: key.scale,
      debugLabel: key.file.path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('GeoTIFF path: ${file.path}'),
      ],
    );
  }

  Future<ui.Codec> _loadImageAsync(
    GeoTiffFileImage key,
    ImageDecoderCallback decode,
  ) async {
    final buffer = await _loadDecodedPngBuffer(key);
    return decode(buffer);
  }

  Future<ui.ImmutableBuffer> _loadDecodedPngBuffer(
    GeoTiffFileImage key,
  ) async {
    assert(key == this);
    final lengthInBytes = await file.length();
    if (lengthInBytes == 0) {
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('$file is empty and cannot be loaded as a GeoTIFF.');
    }

    final pngBytes =
        await compute(_decodeGeoTiffToPngBytes, await file.readAsBytes());
    if (pngBytes == null || pngBytes.isEmpty) {
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('$file cannot be decoded as a GeoTIFF tile.');
    }
    return ui.ImmutableBuffer.fromUint8List(pngBytes);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is GeoTiffFileImage &&
        other.file.path == file.path &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(file.path, scale);
}

Uint8List? _decodeGeoTiffToPngBytes(Uint8List bytes) {
  final image = img.decodeTiff(bytes);
  if (image == null) return null;
  return Uint8List.fromList(img.encodePng(image));
}

enum _TileDownloadStatus { downloaded, cached, skipped }

class _TileBatchStats {
  final int downloaded;
  final int cached;
  final int skipped;

  const _TileBatchStats({
    required this.downloaded,
    required this.cached,
    required this.skipped,
  });
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _normalizeTileFormat(dynamic value) {
  return _tileFileExtension(value?.toString());
}

String _tileFileExtension(String? value) {
  final normalized =
      (value ?? 'tif').trim().toLowerCase().replaceFirst('.', '');
  if (normalized.isEmpty) return 'tif';
  if (normalized == 'tiff' ||
      normalized == 'geotiff' ||
      normalized == 'gtiff') {
    return 'tif';
  }
  return normalized;
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
