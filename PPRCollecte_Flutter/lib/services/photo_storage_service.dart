import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class PhotoStorageService {
  static const String _photoRootFolder = 'srm_photos_pending';

  static Future<String> persistPickedPhoto({
    required XFile picked,
    required String schemaName,
    required String tableName,
    required int photoSlot,
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
      ),
    );
    await destinationDir.create(recursive: true);

    final extension = _safeExtension(picked.path);
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final fileName = 'photo_${photoSlot}_$timestamp$extension';
    final destination = File(path.join(destinationDir.path, fileName));

    final copied = await source.copy(destination.path);
    if (!await copied.exists()) {
      throw Exception('Copie locale de la photo impossible');
    }

    return copied.path;
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
