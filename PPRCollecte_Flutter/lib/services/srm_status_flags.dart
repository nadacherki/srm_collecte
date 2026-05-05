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
    'non renseigne',
    'sans anomalie',
    'aucune anomalie',
    'ras',
    'na',
    'n/a',
  };

  static bool isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value.toString().trim().toLowerCase();
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
}
