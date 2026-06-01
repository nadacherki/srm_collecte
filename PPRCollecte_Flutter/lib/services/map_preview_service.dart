class MapPreviewService {
  MapPreviewService._();

  static const Set<String> _technicalKeys = {
    'id',
    'fid',
    'gid',
    'uid',
    'uuid',
    'uuid_objet',
    'rowid',
    'sqlite_id',
    'api_id',
    'server_id',
    'remote_id',
    'source_table',
    'source_metier',
    'source_entity',
    'source_title',
    'geometry_type',
    'geometry',
    'geometry_geojson',
    'geom',
    'wkt',
    'points_json',
    'sync_status',
    'synced',
    'downloaded',
    'saved_by_user_id',
    'login_id',
    'created_by',
    'updated_by',
    'date_sync',
    'local_path',
    'remote_path',
    'commune_nom',
    'prefecture_nom',
    'region_nom',
    'commune_id',
    'commune_rurale_id',
    'communes_rurales',
    'communes_rurales_id',
    'prefecture_id',
    'region_id',
    'region_name',
    'prefecture_name',
    'commune_name',
  };

  static const List<String> _nameCandidates = [
    'display_title',
    'nom',
    'name',
    'libelle',
    'libell\u00e9',
    'designation',
    'code',
    'code_gps',
    'line_code',
    'ep_num',
    'numero',
    'num_serie',
    'reference',
    'ref',
    'type',
  ];

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
    r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static bool isTechnicalField(String key) {
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (_technicalKeys.contains(normalized)) return true;
    if (normalized.startsWith('source_')) return true;
    if (normalized.endsWith('_json')) return true;
    if (normalized.endsWith('_geojson')) return true;
    if (normalized.endsWith('_id')) return true;
    if (normalized.contains('password') || normalized.contains('token')) {
      return true;
    }
    if (normalized.contains('photo') || normalized.contains('image')) {
      return true;
    }
    return false;
  }

  static bool isUsefulValue(dynamic value) {
    if (value == null) return false;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;

    final text = value.toString().trim();
    if (text.isEmpty) return false;
    final normalized = text.toLowerCase();
    return normalized != 'null' &&
        normalized != '----' &&
        normalized != '-' &&
        normalized != '\u2014' &&
        normalized != '[]' &&
        normalized != '{}' &&
        normalized != 'nan';
  }

  static String cleanText(dynamic value, {String fallback = '----'}) {
    if (!isUsefulValue(value)) return fallback;
    return value.toString().trim();
  }

  static bool looksLikeTechnicalId(dynamic value) {
    if (!isUsefulValue(value)) return false;
    final text = value.toString().trim();
    if (_uuidPattern.hasMatch(text)) return true;

    final compact = text.replaceAll(RegExp(r'[-_\s]'), '');
    if (compact.length >= 24 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(compact)) {
      return true;
    }
    return false;
  }

  static String displayName(
    Map<String, dynamic> row, {
    required String fallback,
  }) {
    for (final key in _nameCandidates) {
      final value = row[key];
      if (!isUsefulValue(value) || looksLikeTechnicalId(value)) continue;
      return value.toString().trim();
    }

    final cleanFallback = cleanText(fallback, fallback: 'Objet');
    return looksLikeTechnicalId(cleanFallback) ? 'Objet' : cleanFallback;
  }

  static String titleWithOptionalName({
    required String type,
    required String name,
  }) {
    final cleanType = cleanText(type, fallback: 'Objet');
    final cleanName = cleanText(name, fallback: '');

    if (cleanName.isEmpty || looksLikeTechnicalId(cleanName)) {
      return cleanType;
    }
    if (cleanName.toLowerCase() == cleanType.toLowerCase()) {
      return cleanType;
    }
    return '$cleanType - $cleanName';
  }
}
