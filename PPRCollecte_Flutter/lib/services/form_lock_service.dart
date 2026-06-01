import 'srm_status_flags.dart';

class FormLockService {
  FormLockService._();

  static bool isLocked(Map<String, dynamic> item) {
    final synced = SrmStatusFlags.isTruthy(item['synced']);
    final downloaded = SrmStatusFlags.isTruthy(item['downloaded']);
    final hasAnomalie = SrmStatusFlags.hasAnomalie(item);
    final hasIncomplet = SrmStatusFlags.hasIncomplet(item);

    if (!synced && !downloaded) return false;
    if (hasAnomalie) return false;
    if (hasIncomplet) return false;

    return true;
  }

  static bool isEditable(Map<String, dynamic> item) => !isLocked(item);

  static bool isDraftEditable(Map<String, dynamic> item) {
    final synced = SrmStatusFlags.isTruthy(item['synced']);
    final downloaded = SrmStatusFlags.isTruthy(item['downloaded']);
    return !synced && !downloaded;
  }

  static String draftEditBlockReason(Map<String, dynamic> item) {
    if (SrmStatusFlags.isTruthy(item['downloaded'])) {
      return 'Cette donn\u00e9e vient d\u00e9j\u00e0 du serveur. Elle peut \u00eatre consult\u00e9e, mais pas modifi\u00e9e depuis la carte.';
    }
    if (SrmStatusFlags.isTruthy(item['synced'])) {
      return 'Cette donn\u00e9e a d\u00e9j\u00e0 \u00e9t\u00e9 envoy\u00e9e au serveur. Elle peut \u00eatre consult\u00e9e, mais pas modifi\u00e9e depuis la carte.';
    }
    return 'Cette donn\u00e9e ne peut pas \u00eatre modifi\u00e9e depuis la carte.';
  }

  static String lockReason(Map<String, dynamic> item) {
    if (SrmStatusFlags.isTruthy(item['downloaded'])) {
      return 'Donn\u00e9e t\u00e9l\u00e9charg\u00e9e depuis le serveur - modification impossible.';
    }
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
