import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

class OfflineBasemapPackageDownloadResult {
  final bool success;
  final bool alreadyAvailable;
  final String? localPath;
  final String? userMessage;
  final String? errorMessage;

  const OfflineBasemapPackageDownloadResult({
    required this.success,
    this.alreadyAvailable = false,
    this.localPath,
    this.userMessage,
    this.errorMessage,
  });
}

class OfflineBasemapService {
  static final OfflineBasemapService _instance =
      OfflineBasemapService._internal();

  static const String _defaultBasemapStyle = 'standard';

  factory OfflineBasemapService() => _instance;
  OfflineBasemapService._internal();

  Future<Directory> _basemapDirectory() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(path.join(root.path, 'basemaps'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _packageTargetFile(Map<String, dynamic> packageRow) async {
    final dir = await _basemapDirectory();
    final citySlug = packageRow['city_slug']?.toString().trim();
    final zoneId = packageRow['zone_id']?.toString().trim();
    final style = packageRow['style']?.toString().trim();
    final version = packageRow['version']?.toString().trim();
    final fileName = packageRow['file_name']?.toString().trim();

    final targetDir = Directory(
      path.join(
        dir.path,
        citySlug?.isNotEmpty == true ? citySlug! : 'city',
        zoneId?.isNotEmpty == true ? zoneId! : 'zone',
        style?.isNotEmpty == true ? style! : 'standard',
        version?.isNotEmpty == true ? version! : 'v1',
      ),
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    return File(
      path.join(
        targetDir.path,
        fileName?.isNotEmpty == true ? fileName! : 'package.mbtiles',
      ),
    );
  }

  String packageKeyFor(Map<String, dynamic> packageRow) {
    return packageRow['package_key']?.toString().trim() ??
        '${packageRow['zone_id']}:${packageRow['style']}:${packageRow['version']}';
  }

  String _normalizedStyle(String? style) {
    final normalized = style?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return _defaultBasemapStyle;
    }
    return normalized;
  }

  Future<List<Map<String, dynamic>>> getReadyPackages({
    String? citySlug,
    String? zoneId,
    String style = _defaultBasemapStyle,
  }) {
    return DatabaseHelper().getReadyOfflineBasemapPackages(
      citySlug: citySlug,
      zoneId: zoneId,
      style: _normalizedStyle(style),
    );
  }

  Future<Map<String, dynamic>?> getActivePackage({
    String style = _defaultBasemapStyle,
  }) async {
    final db = DatabaseHelper();
    final package = await db.getActiveOfflineBasemapPackage(
      style: _normalizedStyle(style),
    );
    if (package == null) {
      return null;
    }

    final packageKey = package['package_key']?.toString();
    final localPath = package['local_path']?.toString().trim();
    if (localPath == null || localPath.isEmpty) {
      if (packageKey != null && packageKey.isNotEmpty) {
        await db.updateOfflineBasemapPackageDownloadState(
          packageKey: packageKey,
          status: 'not_downloaded',
          lastError: null,
        );
      }
      await db.setActiveOfflineBasemapPackageKey(
        style: _normalizedStyle(style),
        packageKey: null,
        recordEvent: false,
      );
      return null;
    }

    final file = File(localPath);
    if (!await file.exists()) {
      if (packageKey != null && packageKey.isNotEmpty) {
        await db.updateOfflineBasemapPackageDownloadState(
          packageKey: packageKey,
          status: 'failed',
          localPath: '',
          lastError: 'Fichier package introuvable sur le stockage local',
        );
      }
      await db.setActiveOfflineBasemapPackageKey(
        style: _normalizedStyle(style),
        packageKey: null,
        recordEvent: false,
      );
      return null;
    }

    return package;
  }

  Future<String?> getActiveBasemapPath({
    String style = _defaultBasemapStyle,
  }) async {
    final activePackage = await getActivePackage(style: style);
    final packagePath = activePackage?['local_path']?.toString().trim();
    if (packagePath != null && packagePath.isNotEmpty) {
      return packagePath;
    }
    return null;
  }

  Future<String?> getActiveBasemapFormat({
    String style = _defaultBasemapStyle,
  }) async {
    final activePackage = await getActivePackage(style: style);
    final packageFormat = activePackage?['format']?.toString().trim();
    if (packageFormat != null && packageFormat.isNotEmpty) {
      return packageFormat;
    }
    return null;
  }

  Future<Map<String, dynamic>> setActivePackage(
    String packageKey, {
    bool recordEvent = true,
  }) async {
    final db = DatabaseHelper();
    final package = await db.getOfflineBasemapPackageByKey(packageKey);
    if (package == null) {
      throw Exception('Package introuvable: $packageKey');
    }

    final style = _normalizedStyle(package['style']?.toString());
    final localPath = package['local_path']?.toString().trim();
    if (localPath == null || localPath.isEmpty || !await File(localPath).exists()) {
      throw Exception('Package non téléchargé localement: $packageKey');
    }

    await db.setActiveOfflineBasemapPackageKey(
      style: style,
      packageKey: packageKey,
      recordEvent: recordEvent,
    );
    return package;
  }

  Future<void> clearActivePackage({
    String style = _defaultBasemapStyle,
    bool recordEvent = true,
  }) async {
    final normalizedStyle = _normalizedStyle(style);
    await DatabaseHelper().setActiveOfflineBasemapPackageKey(
      style: normalizedStyle,
      packageKey: null,
      recordEvent: recordEvent,
    );
  }

  Future<void> _maybeActivateDownloadedPackage(
    Map<String, dynamic> packageRow,
    String packageKey,
  ) async {
    final db = DatabaseHelper();
    final style = _normalizedStyle(packageRow['style']?.toString());
    final activePackage = await db.getActiveOfflineBasemapPackage(style: style);

    var shouldActivate = activePackage == null;
    if (!shouldActivate) {
      final sameZone = activePackage['zone_id']?.toString() ==
          packageRow['zone_id']?.toString();
      final sameStyle = _normalizedStyle(activePackage['style']?.toString()) ==
          style;
      shouldActivate = sameZone && sameStyle;
    }

    if (!shouldActivate) {
      return;
    }

    await setActivePackage(packageKey, recordEvent: true);
  }

  Future<String?> _readyLocalPathForPackage(
    Map<String, dynamic> packageRow,
  ) async {
    final packageKey = packageKeyFor(packageRow);
    final db = DatabaseHelper();
    final stored = await db.getOfflineBasemapPackageByKey(packageKey);
    final targetFile = await _packageTargetFile(packageRow);
    final candidates = <String>[
      (packageRow['local_path'] ?? '').toString().trim(),
      (stored?['local_path'] ?? '').toString().trim(),
      targetFile.path,
    ].where((value) => value.isNotEmpty).toSet();

    final expectedSize = packageRow['size_bytes'] is int
        ? packageRow['size_bytes'] as int
        : int.tryParse(packageRow['size_bytes']?.toString() ?? '');
    final expectedSha256 = packageRow['sha256']?.toString().trim();
    final status =
        (packageRow['status'] ?? stored?['status'] ?? '').toString().trim();
    final shouldVerifyChecksum = status.toLowerCase() != 'ready';

    for (final candidate in candidates) {
      final file = File(candidate);
      if (!await file.exists()) continue;
      final actualSize = await file.length();
      if (expectedSize != null &&
          expectedSize > 0 &&
          actualSize != expectedSize) {
        continue;
      }
      if (shouldVerifyChecksum &&
          expectedSha256 != null &&
          expectedSha256.isNotEmpty) {
        final actualSha256 =
            (await crypto.sha256.bind(file.openRead()).first)
                .toString()
                .toLowerCase();
        if (actualSha256 != expectedSha256.toLowerCase()) {
          continue;
        }
      }
      await _deleteCompletedPackagePartialDownloads(
        validPackagePath: candidate,
        targetPackagePath: targetFile.path,
      );
      return candidate;
    }
    return null;
  }

  Future<void> _deleteCompletedPackagePartialDownloads({
    required String validPackagePath,
    required String targetPackagePath,
  }) async {
    final candidates = <String>{
      '$validPackagePath.download',
      '$targetPackagePath.download',
    };
    for (final candidate in candidates) {
      final file = File(candidate);
      if (!await file.exists()) continue;
      try {
        await file.delete();
      } catch (_) {
        // A stale partial download is only an optimization target; never fail
        // package selection because cleanup could not delete it.
      }
    }
  }

  Future<Map<String, dynamic>?> selectReadyPackageForPosition({
    required LatLng position,
    double? zoom,
    String? citySlug,
    String style = _defaultBasemapStyle,
  }) async {
    final db = DatabaseHelper();
    final packages = await db.getReadyOfflineBasemapPackages(
      citySlug: citySlug,
      style: _normalizedStyle(style),
    );
    final candidates = <Map<String, dynamic>>[];

    for (final packageRow in packages) {
      final localPath = await _readyLocalPathForPackage(packageRow);
      if (localPath == null) continue;

      final zoneId = packageRow['zone_id']?.toString().trim();
      if (zoneId == null || zoneId.isEmpty) continue;
      final zone = await db.getOfflineBasemapZoneById(zoneId);
      if (zone == null) continue;

      final west = _asDouble(zone['bbox_west']);
      final south = _asDouble(zone['bbox_south']);
      final east = _asDouble(zone['bbox_east']);
      final north = _asDouble(zone['bbox_north']);
      if (west == null || south == null || east == null || north == null) {
        continue;
      }

      final containsPosition = position.longitude >= west &&
          position.longitude <= east &&
          position.latitude >= south &&
          position.latitude <= north;
      if (!containsPosition) continue;

      final minZoom = _asDouble(packageRow['min_zoom'] ?? zone['min_zoom']);
      final maxZoom = _asDouble(packageRow['max_zoom'] ?? zone['max_zoom']);
      final containsZoom = zoom == null ||
          ((minZoom == null || zoom >= minZoom) &&
              (maxZoom == null || zoom <= maxZoom));
      if (!containsZoom) continue;

      candidates.add({
        ...packageRow,
        'local_path': localPath,
        'zone': zone,
      });
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final generatedAtA =
          DateTime.tryParse(a['generated_at']?.toString().trim() ?? '');
      final generatedAtB =
          DateTime.tryParse(b['generated_at']?.toString().trim() ?? '');
      if (generatedAtA != null && generatedAtB != null) {
        return generatedAtB.compareTo(generatedAtA);
      }
      if (generatedAtA != null) return -1;
      if (generatedAtB != null) return 1;
      return (b['version']?.toString() ?? '')
          .compareTo(a['version']?.toString() ?? '');
    });
    return candidates.first;
  }

  Future<OfflineBasemapPackageDownloadResult> downloadCatalogPackage(
    Map<String, dynamic> packageRow,
  ) async {
    final db = DatabaseHelper();
    final packageKey = packageKeyFor(packageRow);
    final downloadUrl = packageRow['download_url']?.toString().trim();
    final sizeBytes = packageRow['size_bytes'] is int
        ? packageRow['size_bytes'] as int
        : int.tryParse(packageRow['size_bytes']?.toString() ?? '');
    final sha256 = packageRow['sha256']?.toString();

    if (downloadUrl == null || downloadUrl.isEmpty) {
      await db.updateOfflineBasemapPackageDownloadState(
        packageKey: packageKey,
        status: 'failed',
        lastError: 'URL de téléchargement absente',
      );
      return const OfflineBasemapPackageDownloadResult(
        success: false,
        errorMessage: 'URL de téléchargement absente',
      );
    }

    final readyLocalPath = await _readyLocalPathForPackage(packageRow);
    if (readyLocalPath != null) {
      final downloadedAt =
          (packageRow['downloaded_at'] ?? '').toString().trim().isNotEmpty
              ? packageRow['downloaded_at'].toString()
              : DateTime.now().toUtc().toIso8601String();
      await db.updateOfflineBasemapPackageDownloadState(
        packageKey: packageKey,
        status: 'ready',
        localPath: readyLocalPath,
        downloadedAt: downloadedAt,
        lastError: null,
      );
      await _maybeActivateDownloadedPackage(
        {
          ...packageRow,
          'package_key': packageKey,
          'local_path': readyLocalPath,
          'downloaded_at': downloadedAt,
        },
        packageKey,
      );
      return OfflineBasemapPackageDownloadResult(
        success: true,
        alreadyAvailable: true,
        localPath: readyLocalPath,
        userMessage: 'Package ${packageRow['zone_id']} déjà présent.',
      );
    }

    await db.updateOfflineBasemapPackageDownloadState(
      packageKey: packageKey,
      status: 'downloading',
      lastError: null,
    );

    await db.recordLocalEvent(
      eventType: 'BASEMAP_PACKAGE_DOWNLOAD_STARTED',
      tableName: 'offline_basemap_package',
      cleLigne: packageKey,
      payload: {
        'zone_id': packageRow['zone_id'],
        'style': packageRow['style'],
        'version': packageRow['version'],
      },
    );

    try {
      final targetFile = await _packageTargetFile(packageRow);
      await _downloadToFile(
        downloadUrl,
        targetFile,
        expectedSizeBytes: sizeBytes,
        expectedSha256: sha256,
      );

      final downloadedAt = DateTime.now().toUtc().toIso8601String();
      await db.updateOfflineBasemapPackageDownloadState(
        packageKey: packageKey,
        status: 'ready',
        localPath: targetFile.path,
        downloadedAt: downloadedAt,
        lastError: null,
      );

      await _maybeActivateDownloadedPackage(
        {
          ...packageRow,
          'package_key': packageKey,
          'local_path': targetFile.path,
          'downloaded_at': downloadedAt,
        },
        packageKey,
      );

      await db.recordLocalEvent(
        eventType: 'BASEMAP_PACKAGE_DOWNLOADED',
        tableName: 'offline_basemap_package',
        cleLigne: packageKey,
        payload: {
          'zone_id': packageRow['zone_id'],
          'style': packageRow['style'],
          'version': packageRow['version'],
          'local_path': targetFile.path,
        },
      );

      return OfflineBasemapPackageDownloadResult(
        success: true,
        localPath: targetFile.path,
        userMessage:
            'Package ${packageRow['zone_id']} ${packageRow['style']} téléchargé.',
      );
    } catch (e) {
      await db.updateOfflineBasemapPackageDownloadState(
        packageKey: packageKey,
        status: 'failed',
        lastError: e.toString(),
      );
      await db.recordLocalEvent(
        eventType: 'BASEMAP_PACKAGE_DOWNLOAD_FAILED',
        tableName: 'offline_basemap_package',
        cleLigne: packageKey,
        payload: {
          'zone_id': packageRow['zone_id'],
          'style': packageRow['style'],
          'version': packageRow['version'],
          'error': e.toString(),
        },
      );
      return OfflineBasemapPackageDownloadResult(
        success: false,
        errorMessage: e.toString(),
        userMessage: 'Impossible de télécharger ce package de zone.',
      );
    }
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

    final streamed = await request.send().timeout(const Duration(minutes: 5));
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
        'Erreur téléchargement basemap: ${streamed.statusCode}',
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

    final actualSha256 = expectedSha256 == null || expectedSha256.isEmpty
        ? null
        : (await crypto.sha256.bind(tempFile.openRead()).first).toString();

    if (expectedSha256 != null &&
        expectedSha256.isNotEmpty &&
        actualSha256 != null &&
        actualSha256.toLowerCase() != expectedSha256.toLowerCase()) {
      await tempFile.delete();
      throw Exception(
        'Checksum basemap invalide ($actualSha256 au lieu de $expectedSha256)',
      );
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

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
