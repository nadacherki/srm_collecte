import '../data/remote/api_service.dart';

class PhotoReferenceService {
  static bool isRemoteReference(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return false;

    final lowered = raw.toLowerCase();
    return lowered.startsWith('http://') ||
        lowered.startsWith('https://') ||
        lowered.startsWith('/media/') ||
        lowered.startsWith('media/') ||
        lowered.startsWith('srm_photos/');
  }

  static bool isLocalReference(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return false;
    if (isRemoteReference(raw)) return false;
    return true;
  }

  static String toLocalFilePath(String value) {
    final raw = value.trim();
    if (raw.startsWith('file://')) {
      return Uri.parse(raw).toFilePath();
    }
    return raw;
  }

  static String? buildRemoteUrl(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/media/')) {
      return '${ApiService.baseUrl}$raw';
    }
    if (raw.startsWith('media/')) {
      return '${ApiService.baseUrl}/$raw';
    }
    if (raw.startsWith('srm_photos/')) {
      return '${ApiService.baseUrl}/media/$raw';
    }
    return null;
  }
}
