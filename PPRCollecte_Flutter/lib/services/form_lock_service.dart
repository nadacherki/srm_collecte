class FormLockService {
  FormLockService._();

  static bool isLocked(Map<String, dynamic> item) {
    final synced = _isTruthy(item['synced']);
    final hasAnomalie = _isTruthy(item['anomalie']);
    final hasIncomplet = _isTruthy(item['objet_incomplet']);

    if (!synced) return false;
    if (hasAnomalie) return false;
    if (hasIncomplet) return false;

    return true;
  }

  static bool isEditable(Map<String, dynamic> item) => !isLocked(item);

  static String lockReason(Map<String, dynamic> item) {
    return 'Donn\u00e9e synchronis\u00e9e avec le serveur - modification impossible.';
  }

  static bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == '1' || normalized == 'true' || normalized == 't';
    }
    return false;
  }

  static String statutLabel(String? statut) {
    switch ((statut ?? '').toUpperCase()) {
      case 'A_COMPLETER':
        return '\u00c0 compl\u00e9ter';
      case 'PLANIFIE':
        return 'Planifi\u00e9';
      case 'EN_COURS':
        return 'En cours';
      case 'COMPLETE':
        return 'Compl\u00e9t\u00e9';
      default:
        return statut ?? '';
    }
  }
}
