enum SrmResolvedStatus {
  normal,
  anomalie,
  incomplet,
  conflictUnknown,
}

class SrmStatusFlags {
  SrmStatusFlags._();

  static const Set<String> _falseValues = {
    '',
    '-',
    '--',
    '----',
    '0',
    'false',
    'f',
    'non',
    'no',
    'n',
    'none',
    'null',
    'aucun',
    'aucune',
    'neant',
    'néant',
    'non renseigne',
    'non renseigné',
    'sans anomalie',
    'aucune anomalie',
    'ras',
    'na',
    'n/a',
  };

  static const List<String> _anomalieDateKeys = [
    'date_anomalie',
    'anomalie_date',
    'anomalie_at',
    'anomalie_updated_at',
    'updated_anomalie_at',
    'date_signalement_anomalie',
    'date_detection_anomalie',
    'date_constat_anomalie',
    'type_anomalie_at',
    'type_anomalie_updated_at',
    'ep_anomalie_at',
    'ep_anomalie_updated_at',
  ];

  static const List<String> _incompletDateKeys = [
    'date_incomplet',
    'incomplet_date',
    'incomplet_at',
    'incomplet_updated_at',
    'updated_incomplet_at',
    'date_objet_incomplet',
    'objet_incomplet_at',
    'objet_incomplet_updated_at',
    'date_raison_incomplet',
    'raison_incomplet_at',
    'raison_incomplet_updated_at',
  ];

  static bool isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = _normalize(value);
    final numeric = num.tryParse(normalized.replaceAll(',', '.'));
    if (numeric != null) return numeric != 0;
    if (_falseValues.contains(normalized)) return false;

    return normalized.isNotEmpty;
  }

  static bool hasAnomalie(Map<String, dynamic> row) {
    for (final entry in row.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'anomalie' ||
          key == 'ep_anomalie' ||
          key == 'type_anomalie' ||
          key.startsWith('anomalie_')) {
        if (isTruthy(entry.value)) return true;
      }
    }
    return false;
  }

  static bool hasIncomplet(Map<String, dynamic> row) {
    if (row.containsKey('objet_incomplet') && row['objet_incomplet'] != null) {
      return isTruthy(row['objet_incomplet']);
    }
    return isTruthy(row['raison_incomplet']);
  }

  static SrmResolvedStatus resolveStatus(Map<String, dynamic> row) {
    final anomalie = hasAnomalie(row);
    final incomplet = hasIncomplet(row);

    if (anomalie && !incomplet) return SrmResolvedStatus.anomalie;
    if (!anomalie && incomplet) return SrmResolvedStatus.incomplet;
    if (!anomalie && !incomplet) return SrmResolvedStatus.normal;

    final anomalieDate = latestAnomalieDate(row);
    final incompletDate = latestIncompletDate(row);

    if (anomalieDate != null && incompletDate != null) {
      if (anomalieDate.isAfter(incompletDate)) {
        return SrmResolvedStatus.anomalie;
      }
      if (incompletDate.isAfter(anomalieDate)) {
        return SrmResolvedStatus.incomplet;
      }
    }

    return SrmResolvedStatus.conflictUnknown;
  }

  static bool hasStatusConflict(Map<String, dynamic> row) {
    return hasAnomalie(row) && hasIncomplet(row);
  }

  static DateTime? latestAnomalieDate(Map<String, dynamic> row) {
    return _latestDate(row, _anomalieDateKeys);
  }

  static DateTime? latestIncompletDate(Map<String, dynamic> row) {
    return _latestDate(row, _incompletDateKeys);
  }

  static String resolvedStatusName(SrmResolvedStatus status) {
    return status.toString().split('.').last;
  }

  static DateTime? _latestDate(
    Map<String, dynamic> row,
    List<String> candidateKeys,
  ) {
    DateTime? latest;

    for (final rawKey in candidateKeys) {
      final value = _valueForKeyCaseInsensitive(row, rawKey);
      final parsed = _parseDate(value);
      if (parsed == null) continue;

      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }

    return latest;
  }

  static dynamic _valueForKeyCaseInsensitive(
    Map<String, dynamic> row,
    String wantedKey,
  ) {
    if (row.containsKey(wantedKey)) return row[wantedKey];

    final wanted = wantedKey.toLowerCase();
    for (final entry in row.entries) {
      if (entry.key.toLowerCase() == wanted) {
        return entry.value;
      }
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    final isoParsed = DateTime.tryParse(text);
    if (isoParsed != null) return isoParsed.toLocal();

    final slashMatch = RegExp(
      r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
    ).firstMatch(text);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1)!);
      final month = int.tryParse(slashMatch.group(2)!);
      final year = int.tryParse(slashMatch.group(3)!);
      final hour = int.tryParse(slashMatch.group(4) ?? '0') ?? 0;
      final minute = int.tryParse(slashMatch.group(5) ?? '0') ?? 0;
      final second = int.tryParse(slashMatch.group(6) ?? '0') ?? 0;
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    return null;
  }

  static String _normalize(dynamic value) {
    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('ç', 'c');
  }
}
