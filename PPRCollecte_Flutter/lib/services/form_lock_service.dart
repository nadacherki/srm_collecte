import 'srm_status_flags.dart';

class FormLockService {
  FormLockService._();

  static bool isLocked(Map<String, dynamic> item) {
    final synced = SrmStatusFlags.isTruthy(item['synced']);
    final hasAnomalie = SrmStatusFlags.hasAnomalie(item);
    final hasIncomplet = SrmStatusFlags.hasIncomplet(item);

    if (!synced) return false;
    if (hasAnomalie) return false;
    if (hasIncomplet) return false;

    return true;
  }

  static bool isEditable(Map<String, dynamic> item) => !isLocked(item);

  static String lockReason(Map<String, dynamic> item) {
    return 'Donn\u00e9e synchronis\u00e9e avec le serveur - modification impossible.';
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
