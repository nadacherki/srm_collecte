import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'photo_validation_service.dart';

class PhotoStorageService {
  static const String _photoRootFolder = 'srm_photos_pending';
  static const Duration orphanRetention = Duration(days: 7);
  static const int workflowPhotoSlotLimit = 2;

  static Future<String> persistPickedPhoto({
    required XFile picked,
    required String schemaName,
    required String tableName,
    required int photoSlot,
    String photoContext = 'collecte_initiale',
  }) async {
    final source = File(picked.path);
    if (!await source.exists()) {
      throw Exception('Photo source introuvable: ${picked.path}');
    }

    final supportDir = await getApplicationSupportDirectory();
    final destinationDir = Directory(
      path.join(
        supportDir.path,
        _photoRootFolder,
        _safePathPart(schemaName),
        _safePathPart(tableName),
        _safePathPart(photoContext),
      ),
    );
    await destinationDir.create(recursive: true);

    final extension = _safeExtension(picked.path);
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final contextPart = _safePathPart(photoContext);
    final fileName = 'photo_${contextPart}_${photoSlot}_$timestamp$extension';
    final destination = File(path.join(destinationDir.path, fileName));

    final copied = await source.copy(destination.path);
    if (!await copied.exists()) {
      throw Exception('Copie locale de la photo impossible');
    }
    try {
      await PhotoValidationService.validateStoredPhotoPath(copied.path);
    } catch (_) {
      if (await copied.exists()) {
        await copied.delete();
      }
      rethrow;
    }

    return copied.path;
  }

  static Future<void> deleteLocalPhotoReference(String? reference) async {
    final raw = reference?.trim() ?? '';
    if (raw.isEmpty) return;

    final filePath =
        raw.startsWith('file://') ? Uri.parse(raw).toFilePath() : raw;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best effort cleanup only: a failed delete must not block form saving.
    }
  }

  static Future<int> cleanupOldPendingPhotos({
    Duration retention = orphanRetention,
    DateTime? now,
    Set<String> protectedPaths = const {},
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final root = Directory(path.join(supportDir.path, _photoRootFolder));
    if (!await root.exists()) return 0;

    final threshold = (now ?? DateTime.now().toUtc()).subtract(retention);
    var deleted = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        if (protectedPaths.contains(entity.path)) continue;
        final modified = await entity.lastModified();
        if (modified.toUtc().isBefore(threshold)) {
          await entity.delete();
          deleted++;
        }
      } catch (_) {
        // Best effort cleanup only.
      }
    }
    return deleted;
  }

  static String _safeExtension(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    if (extension.isEmpty) return '.jpg';
    final cleaned = extension.replaceAll(RegExp(r'[^a-z0-9.]'), '');
    return cleaned == '.' ? '.jpg' : cleaned;
  }

  static String _safePathPart(String value) {
    final cleaned = value.trim().toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9_-]+'),
          '_',
        );
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }
}
