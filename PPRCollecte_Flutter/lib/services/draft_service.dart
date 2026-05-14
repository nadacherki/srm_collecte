// lib/services/draft_service.dart
// ── SPRINT 7 : Service de brouillon automatique des formulaires ──
// Sauvegarde/restauration automatique des données de formulaire en SQLite.
// Clé unique : formType + metier + entityType
// Ex: "point__Eau Potable_Vanne", "srm_ligne__Eau Potable_Conduite EP"

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../data/local/database_helper.dart';

class DraftService {
  static final DraftService _instance = DraftService._internal();
  factory DraftService() => _instance;
  DraftService._internal();

  static bool hasMeaningfulDraftContent({
    required Map<String, String> formData,
    Map<int, String?>? photoPaths,
    Map<String, dynamic>? extraState,
  }) {
    final hasFormData = formData.entries.any(
      (entry) => isDraftFieldMeaningfulValue(entry.key, entry.value),
    );
    final hasPhotos =
        photoPaths?.values.any((p) => (p ?? '').trim().isNotEmpty) ?? false;
    final hasExtraState = extraState?.entries.any(
          (entry) => isDraftExtraStateMeaningfulValue(entry.key, entry.value),
        ) ??
        false;
    return hasFormData || hasPhotos || hasExtraState;
  }

  static bool isDraftFieldMeaningfulValue(String field, String value) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) return false;
    final key = field.trim().toLowerCase();
    if (_isAutomaticDraftField(key)) return false;
    if (_isNeutralDefaultDraftValue(key, cleanValue)) return false;
    return true;
  }

  static bool isDraftExtraStateMeaningfulValue(String key, dynamic value) {
    final cleanKey = key.trim().toLowerCase();
    if (cleanKey == 'regardepuuid' || cleanKey == 'regard_ep_uuid') {
      return false;
    }
    if ((cleanKey == 'typeanomalie' || cleanKey == 'type_anomalie') &&
        value is String &&
        _isNeutralDefaultDraftValue(cleanKey, value)) {
      return false;
    }
    return _isMeaningfulDraftValue(value);
  }

  static bool _isAutomaticDraftField(String key) {
    const automaticFields = {
      'id',
      'fid',
      'uuid',
      'source',
      'mode_localisation',
      'latitude',
      'longitude',
      'altitude',
      'latitude_gps',
      'longitude_gps',
      'altitude_gps',
      'altitude_z_moy',
      'x',
      'y',
      'z',
      'lat',
      'lon',
      'lng',
      'x_debut',
      'y_debut',
      'x_fin',
      'y_fin',
      'lat_debut',
      'lon_debut',
      'lat_fin',
      'lon_fin',
      'distance_m',
      'nb_points',
      'points_json',
      'id_agent_crea',
      'id_user_creat',
      'id_user_modif',
      'id_commune',
      'id_province',
      'id_zone',
      'id_mission',
      'id_planche',
      'agent',
      'ep_agent',
      'ep_agent_crea',
      'date_collecte',
      'date_sync',
      'date_creation',
      'ep_date_insertion',
      'date_modif',
      'date_validation',
      'code_gps',
    };
    if (automaticFields.contains(key)) return true;
    if (RegExp(r'(^|_)(coor|coord|coords|coordinate)_?[xyz]$').hasMatch(key)) {
      return true;
    }
    return false;
  }

  static bool _isNeutralDefaultDraftValue(String key, String value) {
    final normalized = _normalizeDraftValue(value);
    if ((key.contains('anomalie') || key == 'typeanomalie') &&
        const {'non', 'false', '0'}.contains(normalized)) {
      return true;
    }
    if ((key.contains('conf') && key.contains('plan')) &&
        normalized == 'objet decouvert') {
      return true;
    }
    if (key == 'mode_localisation' &&
        const {'gnss', 'gps', 'mock', 'nmea'}.contains(normalized)) {
      return true;
    }
    return false;
  }

  static String _normalizeDraftValue(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('\u00e9', 'e')
        .replaceAll('\u00e8', 'e')
        .replaceAll('\u00ea', 'e')
        .replaceAll('\u00eb', 'e')
        .replaceAll('\u00e0', 'a')
        .replaceAll('\u00e2', 'a')
        .replaceAll('\u00f9', 'u')
        .replaceAll('\u00fb', 'u')
        .replaceAll('\u00ee', 'i')
        .replaceAll('\u00ef', 'i')
        .replaceAll('\u00f4', 'o')
        .replaceAll('\u00e7', 'c');
  }

  static bool _isMeaningfulDraftValue(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.trim().isNotEmpty;
    if (value is num) return value != 0;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  // ══════════════════════════════════════════════════════
  // ██ TABLE CREATION (appelé par DatabaseHelper)
  // ══════════════════════════════════════════════════════

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS form_drafts (
        draft_key TEXT PRIMARY KEY,
        form_data TEXT NOT NULL,
        photo_paths TEXT,
        extra_state TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    debugPrint('[DRAFT] table form_drafts creee');
  }

  // ══════════════════════════════════════════════════════
  // ██ CLÉ DE BROUILLON
  // ══════════════════════════════════════════════════════

  /// Génère la clé unique pour un brouillon.
  /// Ex: "point__Eau Potable_Vanne"
  static String buildDraftKey({
    required String formType,
    required String metier,
    required String entityType,
  }) {
    return '${formType}__${metier}_$entityType';
  }

  // ══════════════════════════════════════════════════════
  // ██ SAUVEGARDE
  // ══════════════════════════════════════════════════════

  /// Sauvegarde un brouillon (insert ou replace).
  Future<void> saveDraft({
    required String draftKey,
    required Map<String, String> formData,
    Map<int, String?>? photoPaths,
    Map<String, dynamic>? extraState,
  }) async {
    try {
      final db = await DatabaseHelper().database;
      final now = DateTime.now().toIso8601String();

      // Vérifier si un brouillon existe déjà pour garder created_at
      final existing = await db.query(
        'form_drafts',
        columns: ['created_at'],
        where: 'draft_key = ?',
        whereArgs: [draftKey],
        limit: 1,
      );
      final createdAt =
          existing.isNotEmpty ? existing.first['created_at'] as String : now;

      await db.insert(
        'form_drafts',
        {
          'draft_key': draftKey,
          'form_data': jsonEncode(formData),
          'photo_paths': photoPaths != null
              ? jsonEncode(photoPaths.map((k, v) => MapEntry(k.toString(), v)))
              : null,
          'extra_state': extraState != null ? jsonEncode(extraState) : null,
          'created_at': createdAt,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await DatabaseHelper().recordLocalEvent(
        eventType: 'SAVE_FORM_DRAFT',
        tableName: 'form_drafts',
        cleLigne: draftKey,
        payload: {
          'draft_key': draftKey,
          'field_count': formData.length,
          'photo_count': photoPaths?.values
                  .where((p) => p != null && p.isNotEmpty)
                  .length ??
              0,
        },
      );
    } catch (e) {
      debugPrint('[DRAFT] erreur saveDraft: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ CHARGEMENT
  // ══════════════════════════════════════════════════════

  /// Charge un brouillon. Retourne null si aucun brouillon n'existe.
  Future<DraftData?> loadDraft(String draftKey) async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'form_drafts',
        where: 'draft_key = ?',
        whereArgs: [draftKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      final formDataRaw =
          jsonDecode(row['form_data'] as String) as Map<String, dynamic>;
      final formData =
          formDataRaw.map((k, v) => MapEntry(k, v?.toString() ?? ''));

      Map<int, String?>? photoPaths;
      if (row['photo_paths'] != null) {
        final photoRaw =
            jsonDecode(row['photo_paths'] as String) as Map<String, dynamic>;
        photoPaths =
            photoRaw.map((k, v) => MapEntry(int.parse(k), v as String?));
      }

      Map<String, dynamic>? extraState;
      if (row['extra_state'] != null) {
        extraState =
            jsonDecode(row['extra_state'] as String) as Map<String, dynamic>;
      }

      return DraftData(
        draftKey: draftKey,
        formData: formData,
        photoPaths: photoPaths,
        extraState: extraState,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
    } catch (e) {
      debugPrint('[DRAFT] erreur loadDraft: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ SUPPRESSION
  // ══════════════════════════════════════════════════════

  /// Supprime un brouillon (après enregistrement réussi ou clic "Ignorer").
  Future<void> deleteDraft(String draftKey) async {
    try {
      final db = await DatabaseHelper().database;
      final deletedCount = await db.delete(
        'form_drafts',
        where: 'draft_key = ?',
        whereArgs: [draftKey],
      );
      if (deletedCount == 0) return;
      await DatabaseHelper().recordLocalEvent(
        eventType: 'DELETE_FORM_DRAFT',
        tableName: 'form_drafts',
        cleLigne: draftKey,
        payload: {'draft_key': draftKey},
      );
      debugPrint('[DRAFT] brouillon supprime: $draftKey');
    } catch (e) {
      debugPrint('[DRAFT] erreur deleteDraft: $e');
    }
  }

  /// Supprime tous les brouillons (utile pour reset).
  Future<void> deleteAllDrafts() async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete('form_drafts');
      await DatabaseHelper().recordLocalEvent(
        eventType: 'DELETE_ALL_FORM_DRAFTS',
        tableName: 'form_drafts',
      );
      debugPrint('[DRAFT] tous les brouillons supprimes');
    } catch (e) {
      debugPrint('[DRAFT] erreur deleteAllDrafts: $e');
    }
  }

  // ══════════════════════════════════════════════════════
  // ██ UTILITAIRE : temps écoulé lisible
  // ══════════════════════════════════════════════════════

  /// Retourne un texte lisible comme "il y a 5 minutes", "il y a 2 heures".
  static String timeAgoText(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) {
      return 'il y a quelques secondes';
    }
    if (diff.inMinutes < 60) {
      return 'il y a ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''}';
    }
    if (diff.inHours < 24) {
      return 'il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
    }
    return 'il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
  }
}

// ══════════════════════════════════════════════════════
// ██ MODÈLE DE DONNÉES
// ══════════════════════════════════════════════════════

class DraftData {
  final String draftKey;
  final Map<String, String> formData;
  final Map<int, String?>? photoPaths;
  final Map<String, dynamic>? extraState;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DraftData({
    required this.draftKey,
    required this.formData,
    this.photoPaths,
    this.extraState,
    required this.createdAt,
    required this.updatedAt,
  });
}

// ══════════════════════════════════════════════════════
// ██ MIXIN pour intégration facile dans les formulaires
// ══════════════════════════════════════════════════════

/// Mixin à utiliser dans les State des formulaires.
/// Fournit : auto-save on change, timer 10s, dialog de restauration,
/// suppression après enregistrement.
mixin FormDraftMixin<T extends StatefulWidget> on State<T> {
  Timer? _draftTimer;
  final DraftService _draftService = DraftService();
  bool _draftRestored = false;
  bool _draftCleared = false;

  /// À implémenter : clé du brouillon.
  String get draftKey;

  /// À implémenter : collecte les valeurs actuelles des controllers.
  Map<String, String> collectFormData();

  /// À implémenter : collecte les chemins photos.
  Map<int, String?> collectPhotoPaths();

  /// Optionnel : état supplémentaire (toggles, dropdowns non liés à un controller).
  Map<String, dynamic> collectExtraState() => {};

  /// À implémenter : restaure les données dans les controllers.
  void restoreFormData(Map<String, String> data);

  /// À implémenter : restaure les chemins photos.
  void restorePhotoPaths(Map<int, String?> photos);

  /// Optionnel : restaure l'état supplémentaire.
  void restoreExtraState(Map<String, dynamic> extra) {}

  // ── Lifecycle ──

  /// Appeler dans initState() APRÈS l'initialisation des controllers.
  void initDraft() {
    // Timer de sécurité toutes les 10 secondes
    _draftTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _saveDraftNow(),
    );
    // Vérifier un brouillon existant après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForExistingDraft();
    });
  }

  /// Appeler dans dispose().
  void disposeDraft() {
    _draftTimer?.cancel();
  }

  /// Appeler quand un champ change (onChanged des controllers).
  void onFieldChanged() {
    _saveDraftNow();
  }

  /// Appeler après un enregistrement réussi.
  Future<void> clearDraftAfterSave() async {
    _draftCleared = true;
    _draftTimer?.cancel();
    await _draftService.deleteDraft(draftKey);
  }

  /// Appeler depuis WillPopScope / bouton retour Android.
  Future<void> saveDraftBeforeExit() async {
    await _saveDraftNow();
  }

  // ── Internals ──

  Future<void> _saveDraftNow() async {
    if (!mounted) return;
    if (_draftCleared) return;
    final data = collectFormData();
    final photoPaths = collectPhotoPaths();
    final extraState = collectExtraState();

    if (!_hasMeaningfulDraftContent(
      formData: data,
      photoPaths: photoPaths,
      extraState: extraState,
    )) {
      await _draftService.deleteDraft(draftKey);
      return;
    }

    await _draftService.saveDraft(
      draftKey: draftKey,
      formData: data,
      photoPaths: photoPaths,
      extraState: extraState,
    );
  }

  Future<void> _checkForExistingDraft() async {
    if (_draftRestored) return;
    final draft = await _draftService.loadDraft(draftKey);
    if (draft == null || !mounted) return;

    if (!_hasMeaningfulDraftContent(
      formData: draft.formData,
      photoPaths: draft.photoPaths,
      extraState: draft.extraState,
    )) {
      await _draftService.deleteDraft(draft.draftKey);
      _draftRestored = true;
      return;
    }

    final timeAgo = DraftService.timeAgoText(draft.updatedAt);

    final shouldRestore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.restore, color: Colors.orange, size: 36),
        title: const Text('Brouillon détecté'),
        content: Text(
          'Un brouillon a été sauvegardé $timeAgo.\n'
          'Voulez-vous reprendre là où vous vous étiez arrêté ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ignorer'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.restore),
            label: const Text('Reprendre'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldRestore == true) {
      setState(() {
        restoreFormData(draft.formData);
        if (draft.photoPaths != null) {
          restorePhotoPaths(draft.photoPaths!);
        }
        if (draft.extraState != null) {
          restoreExtraState(draft.extraState!);
        }
        _draftRestored = true;
      });
      await DatabaseHelper().recordLocalEvent(
        eventType: 'RESTORE_FORM_DRAFT',
        tableName: 'form_drafts',
        cleLigne: draft.draftKey,
        payload: {
          'draft_key': draft.draftKey,
          'updated_at': draft.updatedAt.toIso8601String(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Brouillon restauré'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Ignorer → supprimer le brouillon et bloquer toute future sauvegarde
      _draftCleared = true;
      await _draftService.deleteDraft(draftKey);
      _draftRestored = true;
    }
  }

  bool _hasMeaningfulDraftContent({
    required Map<String, String> formData,
    Map<int, String?>? photoPaths,
    Map<String, dynamic>? extraState,
  }) {
    final hasFormData = formData.entries.any(
      (entry) => isDraftFieldMeaningful(entry.key, entry.value),
    );
    final hasPhotos =
        photoPaths?.values.any((p) => (p ?? '').trim().isNotEmpty) ?? false;
    final hasExtraState = extraState?.entries.any(
          (entry) => isDraftExtraStateMeaningful(entry.key, entry.value),
        ) ??
        false;
    return hasFormData || hasPhotos || hasExtraState;
  }

  bool isDraftFieldMeaningful(String field, String value) {
    return DraftService.isDraftFieldMeaningfulValue(field, value);
  }

  bool isDraftExtraStateMeaningful(String key, dynamic value) {
    return DraftService.isDraftExtraStateMeaningfulValue(key, value);
  }
}
