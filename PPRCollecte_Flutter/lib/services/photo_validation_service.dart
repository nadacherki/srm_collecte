import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class PhotoValidationException implements Exception {
  final String message;

  const PhotoValidationException(this.message);

  @override
  String toString() => message;
}

class PhotoValidationService {
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  static const Set<String> allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.heic',
    '.heif',
  };
  static const Set<String> allowedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'image/heif',
  };

  static String get maxPhotoSizeLabel => '5 Mo';

  static Future<String> validatePickedPhoto(XFile picked) {
    return validateStoredPhotoPath(picked.path);
  }

  static Future<String> validateStoredPhotoPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const PhotoValidationException('Photo introuvable sur l appareil');
    }

    final sizeBefore = await file.length();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final size = await file.length();
    if (sizeBefore != size) {
      throw const PhotoValidationException(
        'Photo encore en cours d ecriture. Reessayez.',
      );
    }
    if (size <= 0) {
      throw const PhotoValidationException('Photo vide ou illisible');
    }
    if (size > maxPhotoBytes) {
      throw PhotoValidationException(
        'Photo trop volumineuse. Maximum autorise: $maxPhotoSizeLabel',
      );
    }

    final extension = p.extension(filePath).toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw const PhotoValidationException(
        'Format photo non autorise. Utilisez JPG, PNG, WEBP ou HEIC',
      );
    }

    final header = await _readHeader(file, 32);
    final mimeType = _detectMimeType(header);
    if (mimeType == null || !allowedMimeTypes.contains(mimeType)) {
      throw const PhotoValidationException(
        'Le fichier selectionne n est pas une image valide',
      );
    }

    if (!_extensionMatchesMime(extension, mimeType)) {
      throw const PhotoValidationException(
        'Extension photo incoherente avec le contenu du fichier',
      );
    }

    await _assertImageLooksComplete(file, size, header, mimeType);
    return mimeType;
  }

  static Future<Uint8List> _readHeader(File file, int byteCount) async {
    final stream = file.openRead(0, byteCount);
    final chunks = <int>[];
    await for (final chunk in stream) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }

  static Future<Uint8List> _readFooter(
    File file,
    int size,
    int byteCount,
  ) async {
    if (size <= 0) return Uint8List(0);
    final start = size > byteCount ? size - byteCount : 0;
    final stream = file.openRead(start, size);
    final chunks = <int>[];
    await for (final chunk in stream) {
      chunks.addAll(chunk);
    }
    return Uint8List.fromList(chunks);
  }

  static String? _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'image/png';
    }

    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      if ({'heic', 'heix', 'hevc', 'hevx'}.contains(brand)) {
        return 'image/heic';
      }
      if ({'mif1', 'msf1', 'heif'}.contains(brand)) {
        return 'image/heif';
      }
    }

    return null;
  }

  static bool _extensionMatchesMime(String extension, String mimeType) {
    switch (mimeType) {
      case 'image/jpeg':
        return extension == '.jpg' || extension == '.jpeg';
      case 'image/png':
        return extension == '.png';
      case 'image/webp':
        return extension == '.webp';
      case 'image/heic':
        return extension == '.heic';
      case 'image/heif':
        return extension == '.heif' || extension == '.heic';
      default:
        return false;
    }
  }

  static Future<void> _assertImageLooksComplete(
    File file,
    int size,
    Uint8List header,
    String mimeType,
  ) async {
    switch (mimeType) {
      case 'image/jpeg':
        final footer = await _readFooter(file, size, 2);
        if (footer.length < 2 ||
            footer[footer.length - 2] != 0xFF ||
            footer[footer.length - 1] != 0xD9) {
          throw const PhotoValidationException(
            'Photo JPG incomplete ou corrompue',
          );
        }
        return;
      case 'image/png':
        final footer = await _readFooter(file, size, 12);
        const iendFooter = [
          0x00,
          0x00,
          0x00,
          0x00,
          0x49,
          0x45,
          0x4E,
          0x44,
          0xAE,
          0x42,
          0x60,
          0x82,
        ];
        if (footer.length < iendFooter.length) {
          throw const PhotoValidationException(
            'Photo PNG incomplete ou corrompue',
          );
        }
        for (var i = 0; i < iendFooter.length; i++) {
          if (footer[footer.length - iendFooter.length + i] != iendFooter[i]) {
            throw const PhotoValidationException(
              'Photo PNG incomplete ou corrompue',
            );
          }
        }
        return;
      case 'image/webp':
        if (header.length < 12) {
          throw const PhotoValidationException(
            'Photo WEBP incomplete ou corrompue',
          );
        }
        final riffPayloadSize = header[4] |
            (header[5] << 8) |
            (header[6] << 16) |
            (header[7] << 24);
        if (riffPayloadSize + 8 > size) {
          throw const PhotoValidationException(
            'Photo WEBP incomplete ou corrompue',
          );
        }
        return;
      case 'image/heic':
      case 'image/heif':
        if (size < 32) {
          throw const PhotoValidationException(
            'Photo HEIC incomplete ou corrompue',
          );
        }
        return;
      default:
        return;
    }
  }

  static Future<int?> findDuplicateSlot({
    required String candidatePath,
    required Map<int, String?> existingPaths,
    int? currentSlot,
  }) async {
    final candidateFile = File(candidatePath);
    if (!await candidateFile.exists()) return null;

    final candidateSize = await candidateFile.length();
    final candidateHeader =
        await _readFingerprint(candidateFile, candidateSize);

    for (final entry in existingPaths.entries) {
      final slot = entry.key;
      final slotPath = entry.value;
      if (slot == currentSlot || slotPath == null) continue;
      if (slotPath == candidatePath) return slot;

      final slotFile = File(slotPath);
      if (!await slotFile.exists()) continue;

      final slotSize = await slotFile.length();
      if (slotSize != candidateSize) {
        continue;
      }

      final slotHeader = await _readFingerprint(slotFile, slotSize);
      if (_fingerprintsMatch(candidateHeader, slotHeader)) return slot;
    }

    return null;
  }

  static Future<_PhotoFingerprint> _readFingerprint(File file, int size) async {
    const sampleSize = 64;
    final header = await _readHeader(file, sampleSize);
    final footer = size > sampleSize
        ? await _readFooter(file, size, sampleSize)
        : Uint8List(0);
    return _PhotoFingerprint(size: size, header: header, footer: footer);
  }

  static bool _fingerprintsMatch(_PhotoFingerprint a, _PhotoFingerprint b) {
    if (a.size != b.size) return false;
    if (a.header.length != b.header.length) return false;
    for (var i = 0; i < a.header.length; i++) {
      if (a.header[i] != b.header[i]) return false;
    }
    if (a.footer.length != b.footer.length) return false;
    for (var i = 0; i < a.footer.length; i++) {
      if (a.footer[i] != b.footer[i]) return false;
    }
    return true;
  }
}

class _PhotoFingerprint {
  final int size;
  final Uint8List header;
  final Uint8List footer;

  const _PhotoFingerprint({
    required this.size,
    required this.header,
    required this.footer,
  });
}
