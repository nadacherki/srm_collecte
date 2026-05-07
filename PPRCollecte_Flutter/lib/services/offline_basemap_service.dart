import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../data/local/database_helper.dart';
import '../data/remote/api_service.dart';

/// Resultat d'une mise a jour du basemap regional.
class OfflineBasemapDownloadResult {
  final bool success;
  final bool alreadyUpToDate;
  final String? localPath;
  final String? userMessage;
  final String? errorMessage;

  const OfflineBasemapDownloadResult({
    required this.success,
    this.alreadyUpToDate = false,
    this.localPath,
    this.userMessage,
    this.errorMessage,
  });
}

/// Gere le fichier .pmtiles regional unique : telechargement, verification de
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

    final localPath = state['local_path']?.toString().trim();
    if (localPath == null || localPath.isEmpty) return null;

    final file = File(localPath);
    if (!await file.exists()) {
      await DatabaseHelper().clearRegionalBasemapState();
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
  /// stocke localement, telecharge si besoin (avec reprise via Range).
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
        userMessage: 'Manifest basemap régional indisponible.',
      );
    }

    if (manifest['success'] != true) {
      final message =
          (manifest['message'] ?? 'Manifest basemap régional invalide')
              .toString();
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
    final remoteFormat =
        (manifest['format'] ?? 'pmtiles').toString().trim().toLowerCase();
    final remoteName = (manifest['name'] ?? '').toString().trim();
    final remoteAttribution = (manifest['attribution'] ?? '').toString().trim();
    final remoteGeneratedAt =
        (manifest['generated_at'] ?? '').toString().trim();

    if (remoteUrl.isEmpty || remoteSha256.isEmpty) {
      return const OfflineBasemapDownloadResult(
        success: false,
        errorMessage: 'Manifest basemap incomplet (sha256/url manquants).',
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
      return OfflineBasemapDownloadResult(
        success: true,
        alreadyUpToDate: true,
        localPath: localFile.path,
        userMessage: 'Basemap régional déjà à jour.',
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
        userMessage: 'Impossible de télécharger le basemap régional.',
      );
    }

    final downloadedAt = DateTime.now().toUtc().toIso8601String();
    await db.upsertRegionalBasemapState(
      sha256: remoteSha256,
      version: remoteVersion,
      format: remoteFormat,
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
        'version': remoteVersion,
        'local_path': targetFile.path,
      },
    );

    return OfflineBasemapDownloadResult(
      success: true,
      localPath: targetFile.path,
      userMessage: 'Basemap régional téléchargé.',
    );
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
      return 'Impossible de télécharger le basemap régional.';
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
}
