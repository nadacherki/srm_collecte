// lib/services/form_lock_service.dart
// ── Logique de verrouillage des formulaires ──
//
// Règles métier exactes :
//
//  DONNÉES SAINES (anomalie=0, objet_incomplet=0) :
//    • synced = 0  →  ✅ ÉDITABLE
//    • synced = 1  →  🔒 VERROUILLÉ
//
//  DONNÉES ANOMALIE (anomalie=1) :
//    • synced = 0              →  ✅ ÉDITABLE
//    • synced = 1              →  ✅ ENCORE ÉDITABLE (anomalie pas encore traitée)
//    • anomalie désactivée (=0) + synced = 1  →  🔒 VERROUILLÉ (traitée + synchronisée)
//
//  OBJET INCOMPLET (objet_incomplet=1) :
//    • synced = 0                          →  ✅ ÉDITABLE
//    • synced = 1                          →  ✅ ENCORE ÉDITABLE (incomplet pas traité)
//    • objet_incomplet désactivé (=0) + synced = 1  →  🔒 VERROUILLÉ
//
//  CYCLE :
//    Créer avec anomalie → sync → reste éditable
//    → Agent rouvre → désactive toggle anomalie → sauvegarde (synced=0)
//    → Re-sync → anomalie=0 + synced=1 → 🔒 verrouillé
//
// NB : les coordonnées GPS/Merchich sont TOUJOURS readOnly (géré dans
//      chaque formulaire via _isCoordField()).

class FormLockService {
  FormLockService._();

  /// Retourne true si le formulaire est VERROUILLÉ.
  static bool isLocked(Map<String, dynamic> item) {
    final synced          = _isTruthy(item['synced']);
    final hasAnomalie     = _isTruthy(item['anomalie']);
    final hasIncomplet    = _isTruthy(item['objet_incomplet']);

    // Si pas encore synchronisé → toujours éditable
    if (!synced) return false;

    // Synchronisé + anomalie encore active → encore éditable
    if (hasAnomalie) return false;

    // Synchronisé + objet incomplet encore actif → encore éditable
    if (hasIncomplet) return false;

    // Synchronisé + aucune anomalie/incomplet active → verrouillé
    return true;
  }

  /// Retourne true si le formulaire est ÉDITABLE.
  static bool isEditable(Map<String, dynamic> item) => !isLocked(item);

  /// Message affiché dans la bannière de verrouillage.
  static String lockReason(Map<String, dynamic> item) {
    return 'Donnée synchronisée avec le serveur — modification impossible.';
  }

  /// Gère bool PostgreSQL, int SQLite (0/1) et String.
  static bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s == '1' || s == 'true' || s == 't';
    }
    return false;
  }

  /// Statut lisible pour affichage UI.
  static String statutLabel(String? statut) {
    switch ((statut ?? '').toUpperCase()) {
      case 'A_COMPLETER': return 'À compléter';
      case 'PLANIFIE':    return 'Planifié';
      case 'EN_COURS':    return 'En cours';
      case 'COMPLETE':    return 'Complété';
      default:            return statut ?? '';
    }
  }
}
