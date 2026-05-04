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

  static Future<void> validatePickedPhoto(XFile picked) async {
    final file = File(picked.path);
    if (!await file.exists()) {
      throw const PhotoValidationException('Photo introuvable sur l’appareil');
    }

    final size = await file.length();
    if (size <= 0) {
      throw const PhotoValidationException('Photo vide ou illisible');
    }
    if (size > maxPhotoBytes) {
      throw PhotoValidationException(
        'Photo trop volumineuse. Maximum autorise: $maxPhotoSizeLabel',
      );
    }

    final extension = p.extension(picked.path).toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw const PhotoValidationException(
        'Format photo non autorise. Utilisez JPG, PNG, WEBP ou HEIC',
      );
    }

    final header = await _readHeader(file, 32);
    final mimeType = _detectMimeType(header);
    if (mimeType == null || !allowedMimeTypes.contains(mimeType)) {
      throw const PhotoValidationException(
        'Le fichier sélectionné n’est pas une image valide',
      );
    }

    if (!_extensionMatchesMime(extension, mimeType)) {
      throw const PhotoValidationException(
        'Extension photo incoherente avec le contenu du fichier',
      );
    }
  }

  static Future<Uint8List> _readHeader(File file, int byteCount) async {
    final stream = file.openRead(0, byteCount);
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

  // ── Détection de doublon ─────────────────────────────────────────────────
  //
  // Compare une photo nouvellement sélectionnée [candidate] contre toutes les
  // photos déjà présentes dans le formulaire [existingPaths].
  //
  // Stratégie : deux photos sont considérées identiques si elles partagent
  // le même chemin absolu OU si leurs empreintes binaires concordent
  // (taille + 64 premiers octets + 64 derniers octets).  Cette approche
  // fonctionne sans dépendance externe et couvre les cas où le même fichier
  // est référencé par deux chemins différents (ex : cache temporaire).
  //
  // Retourne l'index (1-based) du slot déjà occupé par la même photo,
  // ou null si aucun doublon n'est détecté.
  static Future<int?> findDuplicateSlot({
    required String candidatePath,
    required Map<int, String?> existingPaths,
    int?
        currentSlot, // slot en cours de remplacement (ignoré dans la comparaison)
  }) async {
    final candidateFile = File(candidatePath);
    if (!await candidateFile.exists()) return null;

    final candidateSize = await candidateFile.length();
    final candidateHeader =
        await _readFingerprint(candidateFile, candidateSize);

    for (final entry in existingPaths.entries) {
      final slot = entry.key;
      final slotPath = entry.value;

      // Ignorer le slot qu'on est en train de remplacer et les slots vides
      if (slot == currentSlot || slotPath == null) continue;

      // 1) Comparaison rapide par chemin absolu
      if (slotPath == candidatePath) return slot;

      // 2) Comparaison par empreinte binaire
      final slotFile = File(slotPath);
      if (!await slotFile.exists()) continue;

      final slotSize = await slotFile.length();
      if (slotSize != candidateSize) {
        continue;
      }

      final slotHeader = await _readFingerprint(slotFile, slotSize);
      if (_fingerprintsMatch(candidateHeader, slotHeader)) return slot;
    }

    return null; // aucun doublon
  }

  /// Lit jusqu'à 64 octets au début ET 64 octets à la fin du fichier.
  /// Cette empreinte légère suffit à discriminer des photos distinctes tout
  /// en restant rapide (pas de lecture intégrale du fichier).
  static Future<_PhotoFingerprint> _readFingerprint(File file, int size) async {
    const sampleSize = 64;
    final header = await _readHeader(file, sampleSize);

    Uint8List footer = Uint8List(0);
    if (size > sampleSize) {
      final start = size - sampleSize;
      final stream = file.openRead(start, size);
      final chunks = <int>[];
      await for (final chunk in stream) {
        chunks.addAll(chunk);
      }
      footer = Uint8List.fromList(chunks);
    }

    return _PhotoFingerprint(size: size, header: header, footer: footer);
  }

  static bool _fingerprintsMatch(_PhotoFingerprint a, _PhotoFingerprint b) {
    if (a.size != b.size) return false;
    if (a.header.length != b.header.length) return false;
    for (int i = 0; i < a.header.length; i++) {
      if (a.header[i] != b.header[i]) return false;
    }
    if (a.footer.length != b.footer.length) return false;
    for (int i = 0; i < a.footer.length; i++) {
      if (a.footer[i] != b.footer[i]) return false;
    }
    return true;
  }
}

/// Empreinte légère d'une photo pour détecter les doublons sans lire le
/// fichier entier en mémoire.
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
