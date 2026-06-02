import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';
import '../core/constants/basemap_constants.dart';

/// Resultat d'une mise à jour du basemap regional.
class OfflineBasemapDownloadResult {
  final bool success;
  final bool alreadyUpToDate;
  final int? tileCount;
  final int? sizeBytes;
  final String? localPath;
  final String? userMessage;
  final String? errorMessage;

  const OfflineBasemapDownloadResult({
    required this.success,
    this.alreadyUpToDate = false,
    this.tileCount,
    this.sizeBytes,
    this.localPath,
    this.userMessage,
    this.errorMessage,
  });
}

/// Gere le fichier .pmtiles regional unique : téléchargement, vérification de
/// version (sha256), stockage local et exposition du chemin actif a la carte.
class OfflineBasemapService {
  static final OfflineBasemapService _instance =
      OfflineBasemapService._internal();

  factory OfflineBasemapService() => _instance;
  OfflineBasemapService._internal();

  static const String _localFileName = 'region.pmtiles';

  Future<Directory> _basemapDirectory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(path.join(root.path, 'basemaps'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _localBasemapFile() async {
    final dir = await _basemapDirectory();
    return File(path.join(dir.path, _localFileName));
  }

  /// Etat actif du basemap si un fichier valide existe localement.
  Future<Map<String, dynamic>?> getActiveBasemap() async {
    final state = await DatabaseHelper().getRegionalBasemapState();
    if (state == null) return null;

    if (_looksLikeNonBasemapState(state)) {
      await DatabaseHelper().clearRegionalBasemapState();
      return null;
    }

    final localPath = state['local_path']?.toString().trim();
    if (localPath == null || localPath.isEmpty) return null;

    final file = File(localPath);
    if (!await file.exists()) {
      await DatabaseHelper().clearRegionalBasemapState();
      return null;
    }
    final srid = _asInt(state['srid']) ?? 3857;
    if (srid != BasemapConstants.requiredSrid) {
      return null;
    }
    final tileSize = _asInt(state['tile_size']);
    final originX = _asDouble(state['origin_x']);
    final originY = _asDouble(state['origin_y']);
    final resolutions = _asDoubleList(state['resolutions_json']);
    final boundsMerchich = _asMap(_jsonValue(state['bounds_merchich_json']));
    if (tileSize == null ||
        tileSize <= 0 ||
        originX == null ||
        originY == null ||
        resolutions == null ||
        resolutions.isEmpty ||
        !_isValidBounds(boundsMerchich)) {
      return null;
    }
    return state;
  }

  Future<String?> getActiveBasemapPath() async {
    final state = await getActiveBasemap();
    return state?['local_path']?.toString();
  }

  Future<String?> getActiveBasemapFormat() async {
    final state = await getActiveBasemap();
    return state?['format']?.toString();
  }

  /// Synchronise le basemap regional : recupere le manifest, compare au sha256
  /// stocke localement, télécharge si besoin (avec reprise via Range).
  Future<OfflineBasemapDownloadResult> ensureRegionalBasemapDownloaded({
    bool force = false,
  }) async {
    Map<String, dynamic> manifest;
    try {
      manifest = await ApiService.fetchRegionalBasemapManifest();
    } catch (e) {
      final message = _downloadErrorMessage(e);
      return OfflineBasemapDownloadResult(
        success: false,
        errorMessage: message,
        userMessage: 'La carte offline est indisponible pour le moment.',
      );
    }

    if (manifest['success'] != true) {
      final message =
          (manifest['message'] ?? 'Carte offline indisponible').toString();
      return OfflineBasemapDownloadResult(
        success: false,
        errorMessage: message,
        userMessage: message,
      );
    }

    final remoteSha256 =
        (manifest['sha256'] ?? '').toString().trim().toLowerCase();
    final remoteUrl = (manifest['download_url'] ?? '').toString().trim();
    final remoteSize = manifest['size_bytes'] is int
        ? manifest['size_bytes'] as int
        : int.tryParse(manifest['size_bytes']?.toString() ?? '');
    final remoteVersion = (manifest['version'] ?? '').toString().trim();
    final packageType =
        (manifest['type'] ?? manifest['package_type'] ?? 'basemap')
            .toString()
            .trim()
            .toLowerCase();
    if (!isAllowedBasemapPackageType(packageType)) {
      return OfflineBasemapDownloadResult(
        success: false,
        errorMessage:
            'Package offline refuse: type "$packageType" au lieu de basemap.',
        userMessage:
            'La carte offline disponible sur le serveur n\'est pas un fond de carte.',
      );
    }
    final remoteFormat =
        (manifest['format'] ?? 'pmtiles').toString().trim().toLowerCase();
    final remoteSrid = _asInt(
          manifest['srid'] ??
              manifest['epsg'] ??
              manifest['crs']?.toString().replaceAll('EPSG:', ''),
        ) ??
        3857;
    if (remoteSrid != BasemapConstants.requiredSrid) {
      return OfflineBasemapDownloadResult(
        success: false,
        errorMessage: 'Basemap refuse: SRID $remoteSrid au lieu de EPSG:26191.',
        userMessage: BasemapConstants.invalidCrsMessage,
      );
    }
    final tileSize = _asInt(manifest['tileSize'] ?? manifest['tile_size']);
    final origin = _asMap(manifest['origin']);
    final originX = _asDouble(
      manifest['origin_x'] ?? manifest['originX'] ?? origin?['x'],
    );
    final originY = _asDouble(
      manifest['origin_y'] ?? manifest['originY'] ?? origin?['y'],
    );
    final resolutions = _asDoubleList(manifest['resolutions']);
    final boundsMerchich =
        manifest['boundsMerchich'] ?? manifest['bounds_merchich'];
    final boundsMerchichMap =
        _asMap(_jsonValue(boundsMerchich) ?? boundsMerchich);
    final remoteName = (manifest['name'] ?? '').toString().trim();
    final remoteAttribution = (manifest['attribution'] ?? '').toString().trim();
    final remoteGeneratedAt =
        (manifest['generated_at'] ?? '').toString().trim();
    final tileCount = estimateTileCountFromManifest(manifest);

    if (remoteUrl.isEmpty || remoteSha256.isEmpty) {
      return const OfflineBasemapDownloadResult(
        success: false,
        errorMessage: 'Carte offline incomplete (sha256/url manquants).',
      );
    }
    if (tileSize == null ||
        tileSize <= 0 ||
        originX == null ||
        originY == null ||
        resolutions == null ||
        resolutions.isEmpty ||
        !_isValidBounds(boundsMerchichMap)) {
      return const OfflineBasemapDownloadResult(
        success: false,
        errorMessage:
            'Carte offline incomplete: tileSize/origin/resolutions/boundsMerchich requis.',
        userMessage:
            "La carte offline EPSG:26191 n'annonce pas sa grille de tuilage.",
      );
    }

    final db = DatabaseHelper();
    final targetFile = await _localBasemapFile();
    final localState = await db.getRegionalBasemapState();
    final localSha256 =
        (localState?['sha256'] ?? '').toString().trim().toLowerCase();
    final localPath = (localState?['local_path'] ?? '').toString().trim();
    final localFile = localPath.isNotEmpty ? File(localPath) : null;
    final localFileExists = localFile != null && await localFile.exists();

    if (!force &&
        localFileExists &&
        localSha256 == remoteSha256 &&
        await _verifyChecksum(localFile, remoteSha256)) {
      final localDownloadedAt = localState?['downloaded_at']?.toString();
      await db.upsertRegionalBasemapState(
        sha256: remoteSha256,
        version: remoteVersion,
        packageType: packageType,
        format: remoteFormat,
        srid: remoteSrid,
        tileSize: tileSize,
        tileCount: tileCount,
        originX: originX,
        originY: originY,
        resolutionsJson: jsonEncode(resolutions),
        boundsMerchichJson:
            boundsMerchichMap == null ? null : jsonEncode(boundsMerchichMap),
        sizeBytes: remoteSize,
        localPath: localFile.path,
        downloadUrl: remoteUrl,
        name: remoteName,
        attribution: remoteAttribution,
        generatedAt: remoteGeneratedAt.isNotEmpty ? remoteGeneratedAt : null,
        downloadedAt: localDownloadedAt?.isNotEmpty == true
            ? localDownloadedAt
            : DateTime.now().toUtc().toIso8601String(),
      );
      return OfflineBasemapDownloadResult(
        success: true,
        alreadyUpToDate: true,
        tileCount: tileCount,
        sizeBytes: remoteSize,
        localPath: localFile.path,
        userMessage: 'Carte offline déjà à jour.',
      );
    }

    try {
      await _downloadToFile(
        remoteUrl,
        targetFile,
        expectedSizeBytes: remoteSize,
        expectedSha256: remoteSha256,
      );
    } catch (e) {
      final message = _downloadErrorMessage(e);
      await db.recordLocalEvent(
        eventType: 'BASEMAP_REGIONAL_DOWNLOAD_FAILED',
        tableName: 'regional_basemap_state',
        cleLigne: 'region',
        payload: {'error': message, 'sha256_remote': remoteSha256},
      );
      return OfflineBasemapDownloadResult(
        success: false,
        errorMessage: message,
        userMessage: 'Impossible de télécharger la carte offline.',
      );
    }

    final downloadedAt = DateTime.now().toUtc().toIso8601String();
    await db.upsertRegionalBasemapState(
      sha256: remoteSha256,
      version: remoteVersion,
      format: remoteFormat,
      packageType: packageType,
      srid: remoteSrid,
      tileSize: tileSize,
      tileCount: tileCount,
      originX: originX,
      originY: originY,
      resolutionsJson: jsonEncode(resolutions),
      boundsMerchichJson:
          boundsMerchichMap == null ? null : jsonEncode(boundsMerchichMap),
      sizeBytes: remoteSize,
      localPath: targetFile.path,
      downloadUrl: remoteUrl,
      name: remoteName,
      attribution: remoteAttribution,
      generatedAt: remoteGeneratedAt.isNotEmpty ? remoteGeneratedAt : null,
      downloadedAt: downloadedAt,
    );
    await db.recordLocalEvent(
      eventType: 'BASEMAP_REGIONAL_DOWNLOADED',
      tableName: 'regional_basemap_state',
      cleLigne: 'region',
      payload: {
        'sha256': remoteSha256,
        'size_bytes': remoteSize,
        'tile_count': tileCount,
        'version': remoteVersion,
        'local_path': targetFile.path,
      },
    );

    return OfflineBasemapDownloadResult(
      success: true,
      tileCount: tileCount,
      sizeBytes: remoteSize,
      localPath: targetFile.path,
      userMessage: 'Carte offline téléchargée.',
    );
  }

  static int? estimateTileCountFromManifest(Map<String, dynamic> manifest) {
    final explicit = _asIntStatic(
      manifest['tile_count'] ??
          manifest['tileCount'] ??
          manifest['tiles_count'],
    );
    if (explicit != null && explicit >= 0) return explicit;

    final tileSize =
        _asIntStatic(manifest['tileSize'] ?? manifest['tile_size']);
    final rasterSize = _asMapStatic(manifest['rasterSize']);
    final width = _asDoubleStatic(rasterSize?['width']);
    final height = _asDoubleStatic(rasterSize?['height']);
    final resolutions = _asDoubleListStatic(manifest['resolutions']);
    final nativeResolution = _asDoubleStatic(manifest['nativeResolution']) ??
        _asDoubleStatic(manifest['native_resolution']) ??
        (resolutions == null || resolutions.isEmpty ? null : resolutions.last);

    if (tileSize == null ||
        tileSize <= 0 ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        nativeResolution == null ||
        nativeResolution <= 0 ||
        resolutions == null ||
        resolutions.isEmpty) {
      return null;
    }

    var total = 0;
    for (final resolution in resolutions) {
      if (resolution <= 0) return null;
      final scale = nativeResolution / resolution;
      final zoomWidth = (width * scale).ceil();
      final zoomHeight = (height * scale).ceil();
      final tilesX = (zoomWidth / tileSize).ceil();
      final tilesY = (zoomHeight / tileSize).ceil();
      total += tilesX * tilesY;
    }
    return total;
  }

  static bool isAllowedBasemapPackageType(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'basemap' ||
        normalized == 'map' ||
        normalized == 'regional_basemap' ||
        normalized == 'regional-basemap';
  }

  bool _looksLikeNonBasemapState(Map<String, dynamic> state) {
    final packageType =
        (state['package_type'] ?? state['type'] ?? '').toString().trim();
    if (packageType.isNotEmpty) {
      return !isAllowedBasemapPackageType(packageType);
    }

    // Older local states did not store package_type. A previously downloaded
    // ortho may otherwise survive as "basemap" and render as a tiny/blank
    // layer outside the agent's current map view.
    final label = [
      state['name'],
      state['attribution'],
      state['download_url'],
      state['local_path'],
    ].whereType<Object>().join(' ').toLowerCase();
    return label.contains('ortho') || label.contains('orthophoto');
  }

  Future<bool> _verifyChecksum(File file, String expectedSha256) async {
    if (expectedSha256.isEmpty) return true;
    final actual = (await crypto.sha256.bind(file.openRead()).first)
        .toString()
        .toLowerCase();
    return actual == expectedSha256.toLowerCase();
  }

  Future<void> _downloadToFile(
    String url,
    File targetFile, {
    int? expectedSizeBytes,
    String? expectedSha256,
  }) async {
    final tempFile = File('${targetFile.path}.download');
    var existingBytes = 0;
    if (await tempFile.exists()) {
      existingBytes = await tempFile.length();
      if (expectedSizeBytes != null &&
          expectedSizeBytes > 0 &&
          existingBytes >= expectedSizeBytes) {
        await tempFile.delete();
        existingBytes = 0;
      }
    }

    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(_headers());
    if (existingBytes > 0) {
      request.headers['Range'] = 'bytes=$existingBytes-';
    }

    final streamed = await request.send().timeout(const Duration(minutes: 10));
    if (streamed.statusCode == 416 && existingBytes > 0) {
      await tempFile.delete();
      return _downloadToFile(
        url,
        targetFile,
        expectedSizeBytes: expectedSizeBytes,
        expectedSha256: expectedSha256,
      );
    }

    final canResume = existingBytes > 0 && streamed.statusCode == 206;
    if (existingBytes > 0 && streamed.statusCode == 200) {
      await tempFile.delete();
      existingBytes = 0;
    }

    if (streamed.statusCode != 200 && streamed.statusCode != 206) {
      throw Exception(
        'Erreur téléchargement basemap : ${streamed.statusCode}',
      );
    }

    IOSink? sink;
    var writtenBytes = existingBytes;
    try {
      sink = tempFile.openWrite(
        mode: canResume ? FileMode.append : FileMode.write,
      );
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        writtenBytes += chunk.length;
      }
      await sink.flush();
    } finally {
      await sink?.close();
    }

    if (expectedSizeBytes != null &&
        expectedSizeBytes > 0 &&
        writtenBytes != expectedSizeBytes) {
      await tempFile.delete();
      throw Exception(
        'Taille basemap invalide ($writtenBytes au lieu de $expectedSizeBytes)',
      );
    }

    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final actualSha256 = (await crypto.sha256.bind(tempFile.openRead()).first)
          .toString()
          .toLowerCase();
      if (actualSha256 != expectedSha256.toLowerCase()) {
        await tempFile.delete();
        throw Exception(
          'Checksum basemap invalide ($actualSha256 vs $expectedSha256)',
        );
      }
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await tempFile.rename(targetFile.path);
  }

  Map<String, String> _headers() => {
        if (ApiService.authToken != null)
          'Authorization': 'Bearer ${ApiService.authToken}',
      };

  String _downloadErrorMessage(Object error) {
    if (_isNetworkFailure(error)) {
      return 'Connexion interrompue pendant le téléchargement du basemap.';
    }

    var value = error.toString().trim();
    value = value
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^SocketException:\s*'), '')
        .replaceFirst(RegExp(r'^TimeoutException(?: after .*?)?:\s*'), '')
        .replaceFirst(RegExp(r'^ClientException:\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (value.isEmpty) {
      return 'Impossible de télécharger la carte offline.';
    }
    return value.length > 180 ? value.substring(0, 180) : value;
  }

  bool _isNetworkFailure(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('connexion interrompue') ||
        value.contains('timeout') ||
        value.contains('socketexception') ||
        value.contains('clientexception') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused') ||
        value.contains('connection reset') ||
        value.contains('connection closed') ||
        value.contains('network is unreachable') ||
        value.contains('no route to host') ||
        value.contains('software caused connection abort') ||
        value.contains('broken pipe');
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return int.tryParse(text);
  }

  static int? _asIntStatic(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return int.tryParse(text);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().trim().replaceAll(',', '.');
    if (text == null || text.isEmpty) return null;
    return double.tryParse(text);
  }

  static double? _asDoubleStatic(dynamic value) {
    if (value is num) return value.toDouble();
    final text = value?.toString().trim().replaceAll(',', '.');
    if (text == null || text.isEmpty) return null;
    return double.tryParse(text);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static Map<String, dynamic>? _asMapStatic(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<double>? _asDoubleList(dynamic value) {
    final decoded = _jsonValue(value);
    if (decoded != null) value = decoded;
    if (value is! List) return null;
    final parsed = value.map(_asDouble).whereType<double>().toList();
    return parsed.isEmpty ? null : parsed;
  }

  static List<double>? _asDoubleListStatic(dynamic value) {
    final decoded = _jsonValueStatic(value);
    if (decoded != null) value = decoded;
    if (value is! List) return null;
    final parsed = value.map(_asDoubleStatic).whereType<double>().toList();
    return parsed.isEmpty ? null : parsed;
  }

  dynamic _jsonValue(dynamic value) {
    if (value is List || value is Map) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        return jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static dynamic _jsonValueStatic(dynamic value) {
    if (value is List || value is Map) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        return jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _isValidBounds(Map<String, dynamic>? value) {
    if (value == null) return false;
    final minX = _asDouble(value['minX'] ?? value['min_x']);
    final minY = _asDouble(value['minY'] ?? value['min_y']);
    final maxX = _asDouble(value['maxX'] ?? value['max_x']);
    final maxY = _asDouble(value['maxY'] ?? value['max_y']);
    if (minX == null || minY == null || maxX == null || maxY == null) {
      return false;
    }
    return minX < maxX && minY < maxY;
  }
}
