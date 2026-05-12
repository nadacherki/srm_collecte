// lib/widgets/forms/srm_point_form_widget.dart
// ── SPRINT 5 : Formulaire dynamique SRM — entités ponctuelles ──
// Fonctionne pour EP / ASS selon srm_config.dart
// Les photos photo_1..photo_4 restent locales avant upload; le serveur
// centralise les references dans public.objet_photo.
//
// SPRINT 6 : Modifications
//  1. uuid retiré du formulaire (généré automatiquement par Uuid().v4() dans _save)
//  2. Champs obligatoires marqués * via AttributConfigMobileField.isRequired
//  3. Champs auto (coordonnées GPS) affichés readOnly sans *
//  4. Toggle "Objet Incomplet" : griser les champs + saisir raison depuis objet_incomplet
//     (même principe que le Switch Anomalie existant)

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../services/photo_validation_service.dart';
import '../../services/photo_reference_service.dart';
import '../../services/photo_slot_service.dart';
import '../../services/photo_storage_service.dart';
import '../../services/projection_service.dart';
import '../../services/draft_service.dart';
import '../../services/form_lock_service.dart';
import '../../services/attribut_config_mobile_service.dart';
import '../../services/srm_field_option_service.dart';

/// Option vide pour les listes déroulantes — permet à l'agent de désélectionner
/// son choix s'il a sélectionné par erreur. La validation Champ obligatoire
/// continue à bloquer si nécessaire.
const DropdownMenuItem<String> _kEmptyChoiceMenuItem = DropdownMenuItem<String>(
  value: null,
  child: Text(
    '—',
    style: TextStyle(
      color: Color(0xFF9CA3AF),
      fontStyle: FontStyle.italic,
    ),
  ),
);

class SrmPointFormWidget extends StatefulWidget {
  final String metier; // "Eau Potable" | "Assainissement"
  final String entityType; // ex: "Vanne", "Regard ASS"
  final String? displayTitle;
  final double latitude;
  final double longitude;
  final double? altitude;
  final String? agentName;
  final Map<String, dynamic>? existingData; // non-null = mode édition
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const SrmPointFormWidget({
    super.key,
    required this.metier,
    required this.entityType,
    this.displayTitle,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.agentName,
    this.existingData,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<SrmPointFormWidget> createState() => _SrmPointFormWidgetState();
}

class _SrmPointFormWidgetState extends State<SrmPointFormWidget>
    with FormDraftMixin<SrmPointFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  // Anomalie (existant)
  bool _hasAnomalie = false;
  String? _typeAnomalie;

  // Objet incomplet (nouveau)
  bool _isObjetIncomplet = false;
  String? _raisonIncomplet;
  final TextEditingController _detailRaisonController = TextEditingController();
  bool _isLocked = false;

  bool _isSaving = false;
  final _picker = ImagePicker();
  final Map<int, String?> _photoPaths = {1: null, 2: null, 3: null, 4: null};

  late final Map<String, dynamic>? _entityConfig;
  List<String> _fields = [];
  List<String> _requiredFields = [];
  Map<String, AttributConfigMobileField> _attributConfigByField = {};
  // True tant que la config dynamique des champs (depuis attribut_config_mobile)
  // n'est pas encore chargee : evite le flash entre les champs SrmConfig codes
  // en dur et les champs reels du serveur.
  bool _isLoadingFields = true;
  // Quand vrai, onFieldChanged ne déclenche pas la sauvegarde de brouillon.
  // Utilisé pendant l'application des valeurs par défaut auto (ETAFAT, dates,
  // coordonnées GPS, mode_localisation) afin de ne pas créer un brouillon
  // alors que l'agent n'a rien touché.
  bool _suppressDraftSave = false;
  Map<String, List<SrmFieldChoice>> _choicesByField = {};
  late final List<String> _typeOptions;
  late final String? _typeField;
  late final int _maxPhotos;
  late double _merchichX;
  late double _merchichY;
  Timer? _customerLinkTimer;
  bool _isCustomerLinkLoading = false;
  String? _customerLinkMessage;
  String? _lastCustomerLinkKey;
  bool _isApplyingCustomerLink = false;
  final Set<String> _customerLinkListenerFields = {};

  bool _isTruthyFlag(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 't' ||
        text == 'yes' ||
        text == 'oui' ||
        text == 'o';
  }

  String get _metierCode => widget.metier == 'Eau Potable'
      ? 'EP'
      : widget.metier == 'Assainissement'
          ? 'ASS'
          : 'SRM';

  String get _tableName =>
      SrmConfig.getTableName(widget.metier, widget.entityType) ?? '';
  String get _displayTitle => (widget.displayTitle?.trim().isNotEmpty == true)
      ? widget.displayTitle!.trim()
      : widget.entityType;

  bool get _isEpRegardPoint =>
      widget.metier == 'Eau Potable' && _tableName == 'ep_regard_point';

  String _foldLabel(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp('[\\u00e0\\u00e1\\u00e2\\u00e3\\u00e4\\u00e5]'), 'a')
        .replaceAll(RegExp('[\\u00e7]'), 'c')
        .replaceAll(RegExp('[\\u00e8\\u00e9\\u00ea\\u00eb]'), 'e')
        .replaceAll(RegExp('[\\u00ec\\u00ed\\u00ee\\u00ef]'), 'i')
        .replaceAll(RegExp('[\\u00f1]'), 'n')
        .replaceAll(RegExp('[\\u00f2\\u00f3\\u00f4\\u00f5\\u00f6]'), 'o')
        .replaceAll(RegExp('[\\u00f9\\u00fa\\u00fb\\u00fc]'), 'u')
        .replaceAll(RegExp('[\\u00fd\\u00ff]'), 'y');
  }

  bool get _isEpCompteurAbonne {
    if (widget.metier != 'Eau Potable') return false;
    final tableName = _tableName.toLowerCase();
    if (tableName == 'compteur_abonne' || tableName == 'ep_brc_pt') {
      return true;
    }
    final label =
        _foldLabel('${widget.entityType} ${widget.displayTitle ?? ''}');
    return label.contains('compteur') && label.contains('abonne');
  }

  bool get _isEpMinimalLocationForm =>
      widget.metier == 'Eau Potable' &&
      const {'borne_onep', 'bouche_a_cles', 'autre_objet'}.contains(_tableName);

  @override
  void initState() {
    super.initState();
    _entityConfig = SrmConfig.getEntityConfig(widget.metier, widget.entityType);
    _fields = SrmConfig.getFields(widget.metier, widget.entityType);
    // _requiredFields est alimenté par _loadAttributConfigMobileFields()
    // depuis la SQLite locale (synchronisée au login). Pas de hardcoding.
    _typeOptions = SrmConfig.getTypeOptions(widget.metier, widget.entityType);
    _typeField = _entityConfig?['typeField'] as String?;
    _maxPhotos = SrmConfig.getMaxPhotos(widget.metier, widget.entityType);

    final m = ProjectionService().wgs84ToMerchich(
      longitude: widget.longitude,
      latitude: widget.latitude,
    );
    _merchichX = m.x;
    _merchichY = m.y;

    for (final field in _fields) {
      final initial = widget.existingData?[field]?.toString() ?? '';
      _controllers[field] = TextEditingController(text: initial);
    }
    _ensureCustomerLinkListeners();
    _loadAttributConfigMobileFields();
    _prefillCoordinates();
    _applyEntitySpecificDefaults();

    if (widget.existingData != null) {
      _hasAnomalie = _isTruthyFlag(widget.existingData!['anomalie']) ||
          _isTruthyFlag(widget.existingData!['ep_anomalie']);
      _typeAnomalie = widget.existingData!['type_anomalie']?.toString() ??
          widget.existingData!['anomalie_regard']?.toString() ??
          widget.existingData!['anomalie_tamp']?.toString();

      // Restaurer état objet incomplet en mode édition
      _isObjetIncomplet =
          _isTruthyFlag(widget.existingData!['objet_incomplet']);
      _raisonIncomplet = widget.existingData!['raison_incomplet']?.toString();
      _detailRaisonController.text =
          widget.existingData!['detail_raison_incomplet']?.toString() ?? '';

      for (int i = 1; i <= 4; i++) {
        _photoPaths[i] = widget.existingData!['photo_$i']?.toString();
      }
      _photoPaths.addAll(
        PhotoSlotService.compact(
          _photoPaths,
          _maxPhotos,
          isLockedReference: PhotoReferenceService.isRemoteReference,
        ),
      );

      _isLocked = FormLockService.isLocked(widget.existingData!);
      _restoreLinkedObjetIncompletDetails();
    }

    // ── SPRINT 7 : Brouillon automatique (uniquement en mode création) ──
    if (widget.existingData == null) {
      // Écouter les changements de chaque controller
      for (final c in _controllers.values) {
        c.addListener(onFieldChanged);
      }
      _detailRaisonController.addListener(onFieldChanged);
      initDraft();
    }
  }

  Future<void> _loadAttributConfigMobileFields() async {
    try {
      final nomMetier =
          AttributConfigMobileService.nomMetierForMobileMetier(widget.metier);
      final nomTable = AttributConfigMobileService.configTableForMobileTable(
        nomMetier,
        _tableName,
      );
      final results = await Future.wait<dynamic>([
        AttributConfigMobileService().getFormFields(
          metier: widget.metier,
          entityType: widget.entityType,
          refreshIfEmpty: false,
          forceRefresh: true,
        ),
        SrmFieldOptionService().getOptionsByField(
          tableSchema: nomMetier,
          tableName: nomTable,
          refreshIfEmpty: false,
        ),
      ]);
      final configFields = results[0] as List<AttributConfigMobileField>;
      final rawChoicesByField = results[1] as Map<String, List<SrmFieldChoice>>;
      if (!mounted) return;
      if (configFields.isEmpty) return;

      final formFields = <String>[];
      final requiredFields = <String>[];
      final byField = <String, AttributConfigMobileField>{};
      for (final config in configFields) {
        if (config.nomChamp.isEmpty ||
            config.primaryKey ||
            config.nomChamp.toLowerCase() == 'geom') {
          continue;
        }
        byField[config.nomChamp] = config;
        if (_isWorkflowManagedField(config.nomChamp)) {
          continue;
        }
        if (!config.visible && !config.isAutoVisibleCoordinate) {
          continue;
        }
        if (!formFields.contains(config.nomChamp)) {
          formFields.add(config.nomChamp);
        }
        if (config.isRequired) {
          requiredFields.add(config.nomChamp);
        }
      }

      final choicesByField = Map.fromEntries(
        rawChoicesByField.entries.where((entry) => byField.containsKey(
              entry.key,
            )),
      );

      setState(() {
        _attributConfigByField = byField;
        _choicesByField = choicesByField;
        _fields = formFields;
        _requiredFields = requiredFields;
        for (final field in _fields) {
          if (!_controllers.containsKey(field)) {
            final controller = TextEditingController(
              text: widget.existingData?[field]?.toString() ??
                  byField[field]?.valeurParDefaut ??
                  '',
            );
            if (widget.existingData == null) {
              controller.addListener(onFieldChanged);
            }
            _controllers[field] = controller;
          }
        }
        for (final config in byField.values) {
          if (!_isAnomalieDetailField(config.nomChamp)) continue;
          if (!config.visible) continue;
          _controllers.putIfAbsent(
            config.nomChamp,
            () {
              final controller = TextEditingController(
                text: widget.existingData?[config.nomChamp]?.toString() ??
                    config.valeurParDefaut,
              );
              if (widget.existingData == null) {
                controller.addListener(onFieldChanged);
              }
              return controller;
            },
          );
        }
        _applyConfiguredDefaults();
        _prefillCoordinates();
        _applyEntitySpecificDefaults();
        _ensureCustomerLinkListeners();
      });
    } catch (e) {
      debugPrint('[ATTRIBUT-CONFIG-MOBILE] Form fallback $_tableName: $e');
    } finally {
      // Quoi qu'il arrive (succes, config vide, exception, widget demonte),
      // on bascule l'etat "loading" pour debloquer l'affichage du formulaire.
      if (mounted && _isLoadingFields) {
        setState(() {
          _isLoadingFields = false;
        });
      }
    }
  }

  void _applyConfiguredDefaults() {
    if (widget.existingData != null) return;
    final wasSuppressed = _suppressDraftSave;
    _suppressDraftSave = true;
    try {
      for (final entry in _attributConfigByField.entries) {
        final defaultValue = _configuredDefaultValueForField(entry.key);
        if (defaultValue.isEmpty) continue;
        final controller = _controllers[entry.key];
        if (controller == null || controller.text.trim().isNotEmpty) continue;
        controller.text = defaultValue;
      }
    } finally {
      _suppressDraftSave = wasSuppressed;
    }
  }

  @override
  void onFieldChanged() {
    if (_suppressDraftSave) return;
    super.onFieldChanged();
  }

  String _configuredDefaultValueForField(String field) {
    final defaultValue =
        _attributConfigByField[field]?.valeurParDefaut.trim() ?? '';
    if (defaultValue.isEmpty) return '';

    final choices = _choicesByField[field] ?? const <SrmFieldChoice>[];
    if (choices.isNotEmpty &&
        !choices.any((choice) => choice.code == defaultValue)) {
      return '';
    }
    return defaultValue;
  }

  void _prefillCoordinates() {
    final wasSuppressed = _suppressDraftSave;
    _suppressDraftSave = true;
    try {
      if (widget.altitude == null) {
        if (widget.existingData == null) {
          for (final entry in _controllers.entries) {
            if (_isCoordField(entry.key)) {
              entry.value.clear();
            }
          }
        }
        return;
      }

      final zStr = widget.altitude!.toStringAsFixed(3);
      final coordFields = {
        'ep_coor_x': _merchichX.toStringAsFixed(3),
        'ep_coor_y': _merchichY.toStringAsFixed(3),
        'ep_coor_z': zStr,
        'ass_coor_x': _merchichX.toStringAsFixed(3),
        'ass_coor_y': _merchichY.toStringAsFixed(3),
        'ass_coor_z': zStr,
      };
      for (final entry in _controllers.entries) {
        final value = coordFields[entry.key.toLowerCase()];
        if (value != null) {
          entry.value.text = value;
        }
      }
    } finally {
      _suppressDraftSave = wasSuppressed;
    }
  }

  Future<void> _restoreLinkedObjetIncompletDetails() async {
    if (!_isObjetIncomplet) return;
    if ((_raisonIncomplet?.trim().isNotEmpty ?? false) &&
        _detailRaisonController.text.trim().isNotEmpty) {
      return;
    }

    final existingId = widget.existingData?['id'] is int
        ? widget.existingData!['id'] as int
        : int.tryParse(widget.existingData?['id']?.toString() ?? '');
    final tableName =
        SrmConfig.getTableName(widget.metier, widget.entityType) ?? '';
    if (existingId == null || tableName.isEmpty) return;

    final linked = await DatabaseHelper().getOpenObjetIncompletForEntity(
      tableName: tableName,
      idObjet: existingId,
    );
    if (!mounted || linked == null) return;

    setState(() {
      _raisonIncomplet ??= linked['raison']?.toString();
      if (_detailRaisonController.text.trim().isEmpty) {
        _detailRaisonController.text =
            linked['detail_raison']?.toString() ?? '';
      }
    });
  }

  void _applyEntitySpecificDefaults() {
    if (!_isEpRegardPoint || widget.existingData != null) return;
    final wasSuppressed = _suppressDraftSave;
    _suppressDraftSave = true;
    try {
      final now = DateTime.now();
      _setControllerIfEmpty('ep_agent', 'ETAFAT');
      _setControllerIfEmpty('ep_agent_crea', 'ETAFAT');
      _setControllerIfEmpty('ep_date_insertion', _formatDateOnly(now));
      _setControllerIfEmpty(
          'id_user_creat', ApiService.userId?.toString() ?? '');
      _setControllerIfEmpty('date_creation', now.toIso8601String());
      _setControllerIfEmpty('mode_localisation', 'Levé topographique');
      _setControllerIfEmpty('ep_anomalie', '0');
    } finally {
      _suppressDraftSave = wasSuppressed;
    }
  }

  void _setControllerIfEmpty(String field, String value) {
    if (value.trim().isEmpty) return;
    final controller = _controllers[field];
    if (controller == null) return;
    if (controller.text.trim().isEmpty) {
      controller.text = value;
    }
  }

  void _ensureCustomerLinkListeners() {
    if (!_isEpCompteurAbonne) return;
    for (final field in const ['num_contrat', 'ancienne_police']) {
      if (_customerLinkListenerFields.contains(field)) continue;
      final controller = _controllers[field];
      if (controller == null) continue;
      controller.addListener(_scheduleCustomerLinkLookup);
      _customerLinkListenerFields.add(field);
    }
  }

  void _scheduleCustomerLinkLookup() {
    if (!_isEpCompteurAbonne || _isLocked || _isApplyingCustomerLink) return;
    _customerLinkTimer?.cancel();
    _customerLinkTimer = Timer(
      const Duration(milliseconds: 700),
      _fetchCustomerLink,
    );
  }

  Future<void> _fetchCustomerLink() async {
    if (!_isEpCompteurAbonne || !mounted) return;
    final numContrat = _controllers['num_contrat']?.text.trim() ?? '';
    final anciennePolice = _controllers['ancienne_police']?.text.trim() ?? '';
    if (numContrat.isEmpty && anciennePolice.isEmpty) {
      setState(() {
        _customerLinkMessage = null;
        _isCustomerLinkLoading = false;
      });
      return;
    }

    final requestKey = '$numContrat|$anciennePolice|'
        '${_merchichX.toStringAsFixed(3)}|${_merchichY.toStringAsFixed(3)}';
    if (requestKey == _lastCustomerLinkKey) return;
    _lastCustomerLinkKey = requestKey;

    setState(() {
      _isCustomerLinkLoading = true;
      _customerLinkMessage = 'Recherche client ONEP...';
    });

    try {
      final response = await ApiService.fetchCompteurAbonneCustomerLink(
        numContrat: numContrat,
        anciennePolice: anciennePolice,
        x: _merchichX,
        y: _merchichY,
      );
      if (!mounted || response == null) return;
      _handleCustomerLinkResponse(response);
    } catch (e) {
      debugPrint('[ONEP-LINK] $e');
      final localResponse = await DatabaseHelper().findOnepCustomerLocal(
        numContrat: numContrat,
        anciennePolice: anciennePolice,
        x: _merchichX,
        y: _merchichY,
      );
      if (mounted && localResponse != null) {
        _handleCustomerLinkResponse(localResponse, offline: true);
        return;
      }
      if (mounted) {
        setState(() {
          _customerLinkMessage = 'Liaison client indisponible hors ligne.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCustomerLinkLoading = false;
        });
      }
    }
  }

  void _handleCustomerLinkResponse(
    Map<String, dynamic> response, {
    bool offline = false,
  }) {
    if (!mounted) return;
    final matched = response['matched'] == true;
    if (matched) {
      final rawData = response['data'];
      if (rawData is Map) {
        _applyCustomerLinkData(Map<String, dynamic>.from(rawData));
      }
      final note = response['observation_note']?.toString().trim() ?? '';
      if (note.isNotEmpty) {
        _appendObservationNote(note);
      }
      final matchType = response['match_type']?.toString();
      final warnings = response['warnings'];
      final warningText = warnings is List && warnings.isNotEmpty
          ? warnings.first.toString()
          : '';
      setState(() {
        final baseMessage = matchType == 'ancienne_police_commune'
            ? 'Client ONEP trouvé par ancienne police + commune.'
            : 'Client ONEP trouvé par numéro de contrat.';
        final sourceSuffix = offline ? ' (cache local).' : '';
        _customerLinkMessage = warningText.isEmpty
            ? '$baseMessage$sourceSuffix'
            : '$baseMessage$sourceSuffix $warningText';
      });
    } else {
      final warnings = response['warnings'];
      final warningText = warnings is List && warnings.isNotEmpty
          ? warnings.first.toString()
          : 'Aucun client ONEP trouvé pour ces informations.';
      setState(() {
        _customerLinkMessage =
            offline ? '$warningText (cache local).' : warningText;
      });
    }
  }

  void _applyCustomerLinkData(Map<String, dynamic> data) {
    const fields = [
      'num_contrat',
      'ancienne_police',
      'abon',
      'nom',
      'adresse',
      'etat_abonnement',
      'ancien_ref_sap',
      'id_geo',
      'ref',
    ];
    _isApplyingCustomerLink = true;
    try {
      for (final field in fields) {
        final value = data[field]?.toString().trim() ?? '';
        if (value.isEmpty) continue;
        final controller = _controllers[field];
        if (controller != null && controller.text.trim() != value) {
          controller.text = value;
        }
      }
    } finally {
      _isApplyingCustomerLink = false;
    }
  }

  void _appendObservationNote(String note) {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) return;
    final controller =
        _controllers['ep_observation'] ?? _controllers['observation'];
    if (controller == null) return;
    final current = controller.text.trim();
    if (current.contains(cleanNote)) return;
    controller.text = current.isEmpty ? cleanNote : '$current | $cleanNote';
  }

  String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _isConfiguredReadOnlyField(String field) {
    return SrmConfig.getReadOnlyFields(widget.metier, widget.entityType)
        .contains(field);
  }

  bool _isAnomalieFlagField(String field) {
    final normalized = field.toLowerCase();
    if (_isCompteurAbonneAnomalieChoiceField(normalized)) return false;
    return normalized == 'anomalie' ||
        normalized == 'ep_anomalie' ||
        normalized == 'ass_anomalie';
  }

  bool _isAnomalieDetailField(String field) {
    final normalized = field.toLowerCase();
    if (_isCompteurAbonneAnomalieChoiceField(normalized)) return false;
    if (_isAnomalieFlagField(normalized)) return false;
    return normalized == 'type_anomalie' ||
        normalized.startsWith('anomalie_') ||
        normalized.endsWith('_anomalie');
  }

  bool _isAnomalieManagedField(String field) =>
      _isAnomalieFlagField(field) || _isAnomalieDetailField(field);

  bool _isCompteurAbonneAnomalieChoiceField(String field) =>
      _isEpCompteurAbonne && field.toLowerCase() == 'ep_anomalie';

  bool _isConfiguredVisibleField(String field) {
    final config = _attributConfigByField[field.toLowerCase()];
    return config == null || config.visible;
  }

  bool _isObjetIncompletManagedField(String field) {
    final normalized = field.toLowerCase();
    return normalized == 'objet_incomplet' ||
        normalized == 'raison_incomplet' ||
        normalized == 'detail_raison';
  }

  bool _isWorkflowManagedField(String field) =>
      _isAnomalieManagedField(field) || _isObjetIncompletManagedField(field);

  bool _isHiddenField(String field) => _isWorkflowManagedField(field);

  bool _isCustomerLinkTriggerField(String field) =>
      field == 'num_contrat' || field == 'ancienne_police';

  @override
  void dispose() {
    // ── SPRINT 7 : arrêter le timer de brouillon ──
    if (widget.existingData == null) disposeDraft();
    _customerLinkTimer?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _detailRaisonController.dispose(); // NOUVEAU
    super.dispose();
  }

  // ── SPRINT 7 : Implémentation FormDraftMixin ──

  @override
  String get draftKey => DraftService.buildDraftKey(
        formType: 'point',
        metier: widget.metier,
        entityType: widget.entityType,
      );

  @override
  Map<String, String> collectFormData() {
    final data = <String, String>{};
    for (final entry in _controllers.entries) {
      data[entry.key] = entry.value.text;
    }
    data['__detail_raison'] = _detailRaisonController.text;
    return data;
  }

  @override
  bool isDraftFieldMeaningful(String field, String value) {
    if (!super.isDraftFieldMeaningful(field, value)) return false;
    final defaultValue = _configuredDefaultValueForField(field).trim();
    return defaultValue.isEmpty || value.trim() != defaultValue;
  }

  @override
  Map<int, String?> collectPhotoPaths() => Map.from(_photoPaths);

  @override
  Map<String, dynamic> collectExtraState() => {
        'hasAnomalie': _hasAnomalie,
        'typeAnomalie': _typeAnomalie,
        'isObjetIncomplet': _isObjetIncomplet,
        'raisonIncomplet': _raisonIncomplet,
      };

  @override
  void restoreFormData(Map<String, String> data) {
    for (final entry in data.entries) {
      if (entry.key == '__detail_raison') {
        _detailRaisonController.text = entry.value;
      } else if (_controllers.containsKey(entry.key)) {
        _controllers[entry.key]!.text = entry.value;
      }
    }
  }

  @override
  void restorePhotoPaths(Map<int, String?> photos) {
    _photoPaths.addAll(photos);
    _photoPaths.addAll(
      PhotoSlotService.compact(
        _photoPaths,
        _maxPhotos,
        isLockedReference: PhotoReferenceService.isRemoteReference,
      ),
    );
  }

  @override
  void restoreExtraState(Map<String, dynamic> extra) {
    _hasAnomalie = extra['hasAnomalie'] == true;
    _typeAnomalie = extra['typeAnomalie'] as String?;
    _isObjetIncomplet = extra['isObjetIncomplet'] == true;
    _raisonIncomplet = extra['raisonIncomplet'] as String?;
  }

  Color get _metierColor => Color(SrmConfig.getMetierColor(widget.metier));

  // Photos
  Future<void> _pickPhoto(int index) async {
    if (!PhotoSlotService.canPickSlot(_photoPaths, index, _maxPhotos)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ajoutez les photos dans l'ordre."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Source photo'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Appareil photo'),
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Galerie'),
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;

    try {
      await PhotoValidationService.validatePickedPhoto(picked);
    } on PhotoValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo refusée: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Vérification anti-doublon.
    // On compare la photo sélectionnée avec toutes les autres slots déjà remplis.
    // Si une photo identique est détectée (même chemin ou même contenu binaire),
    // on rejette la sélection avec un message explicite.
    final duplicateSlot = await PhotoValidationService.findDuplicateSlot(
      candidatePath: picked.path,
      existingPaths: _photoPaths,
      currentSlot: index,
    );
    if (duplicateSlot != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.content_copy, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Photo déjà utilisée dans le slot Photo $duplicateSlot. '
                  'Veuillez sélectionner une photo différente.',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    // Fin de la vérification anti-doublon.

    late final String durablePath;
    try {
      durablePath = await PhotoStorageService.persistPickedPhoto(
        picked: picked,
        schemaName: _metierCode.toLowerCase(),
        tableName: _tableName,
        photoSlot: index,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo non sauvegardee localement: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _photoPaths[index] = durablePath;
      _photoPaths.addAll(
        PhotoSlotService.compact(
          _photoPaths,
          _maxPhotos,
          isLockedReference: PhotoReferenceService.isRemoteReference,
        ),
      );
    });
    if (widget.existingData == null) onFieldChanged();
  }

  void _removePhoto(int index) {
    setState(() {
      _photoPaths.addAll(
        PhotoSlotService.removeAndCompact(
          _photoPaths,
          index,
          _maxPhotos,
          isLockedReference: PhotoReferenceService.isRemoteReference,
        ),
      );
    });
    if (widget.existingData == null) onFieldChanged();
  }

  Future<void> _cancelRemovedLocalPhotoUploadsAfterSave(
      DatabaseHelper db) async {
    final uuid = widget.existingData?['uuid']?.toString().trim() ?? '';
    if (uuid.isEmpty || _tableName.isEmpty) return;

    for (var slot = 1; slot <= 4; slot++) {
      final previous =
          widget.existingData?['photo_$slot']?.toString().trim() ?? '';
      final current = _photoPaths[slot]?.trim() ?? '';
      if (previous.isEmpty || current == previous) continue;
      if (!PhotoReferenceService.isRemoteReference(previous)) {
        await db.cancelPhotoSyncItem(
          schemaName: _metierCode.toLowerCase(),
          tableName: _tableName,
          uuidObjet: uuid,
          photoSlot: slot,
        );
      }
    }
  }

  Widget _buildPhotoPreview(String path) {
    final remoteUrl = PhotoReferenceService.buildRemoteUrl(path);
    if (remoteUrl != null) {
      return Image.network(
        remoteUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    }

    return Image.file(
      File(PhotoReferenceService.toLocalFilePath(path)),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
    );
  }

  // Sauvegarde
  Future<void> _save() async {
    if (_isLocked) return;
    // Si objet incomplet : on ne valide PAS les champs métier (ils sont grisés)
    // mais on valide quand même la raison
    if (!_isObjetIncomplet && !_formKey.currentState!.validate()) return;
    if (_isObjetIncomplet && _raisonIncomplet == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('⚠️ Veuillez sélectionner une raison pour l\'objet incomplet'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    if (widget.existingData == null && widget.altitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez activer le GPS'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final tableName =
          SrmConfig.getTableName(widget.metier, widget.entityType) ?? '';
      if (tableName.isEmpty) throw Exception('Table non trouvée');

      final data = <String, dynamic>{};

      // UUID : toujours automatique, jamais saisi.
      data['uuid'] = widget.existingData?['uuid'] ?? const Uuid().v4();

      // Champs deja renseignes conserves meme si l'objet est incomplet.
      for (final field in _fields) {
        final val = _controllers[field]?.text.trim();
        if (val != null && val.isNotEmpty) {
          data[field] = _normalizeFieldValue(field, val);
        }
      }

      // ── Coordonnées GPS brutes (toujours sauvegardées) ──
      data['latitude_gps'] = widget.latitude;
      data['longitude_gps'] = widget.longitude;
      if (widget.altitude != null) data['altitude_gps'] = widget.altitude;

      // ── Coordonnées Merchich (toujours sauvegardées) ──
      // même si objet incomplet, on garde la position approximative
      final xField = _fields.firstWhere((f) => _isCoordSuffix(f, '_coor_x'),
          orElse: () => '');
      final yField = _fields.firstWhere((f) => _isCoordSuffix(f, '_coor_y'),
          orElse: () => '');
      final zField = _fields.firstWhere((f) => _isCoordSuffix(f, '_coor_z'),
          orElse: () => '');
      if (xField.isNotEmpty) data[xField] = _merchichX.toStringAsFixed(3);
      if (yField.isNotEmpty) data[yField] = _merchichY.toStringAsFixed(3);
      if (zField.isNotEmpty && widget.altitude != null) {
        data[zField] = widget.altitude!.toStringAsFixed(3);
      }

      // Anomalie
      _applyAnomaliePayload(data);

      if (_isEpRegardPoint) {
        data['mode_localisation'] =
            (_controllers['mode_localisation']?.text.trim().isNotEmpty ?? false)
                ? _controllers['mode_localisation']!.text.trim()
                : 'Levé topographique';
        data['id_user_creat'] ??= ApiService.userId;
        if (widget.existingData != null) {
          data['id_user_modif'] = ApiService.userId;
          data['date_modif'] = DateTime.now().toIso8601String();
        } else {
          data['date_creation'] ??= DateTime.now().toIso8601String();
        }
      }

      // ── Objet Incomplet : flag dans la table métier uniquement ──
      // Les détails vont dans la table objet_incomplet séparément
      data['objet_incomplet'] = _isObjetIncomplet ? 1 : 0;

      // Photos
      for (int i = 1; i <= 4; i++) {
        data['photo_$i'] = _photoPaths[i];
      }

      // ── Clés étrangères (injectées automatiquement) ──
      data['id_agent_crea'] = ApiService.userId;
      if (!_isEpRegardPoint) {
        data['mode_localisation'] = 'gnss';
      } else {
        data['mode_localisation'] =
            data['mode_localisation']?.toString().trim().isNotEmpty == true
                ? data['mode_localisation']
                : 'Levé topographique';
      }
      data['synced'] = 0;
      data['date_collecte'] = DateTime.now().toIso8601String();

      final db = DatabaseHelper();

      // Resoudre id_commune via la position Merchich pour eviter d'envoyer
      // un id local invalide au serveur (FK commune_oriental.fid).
      if (data['id_commune'] == null &&
          _merchichX != 0.0 &&
          _merchichY != 0.0) {
        try {
          final commune = await db.findCommuneLocalByPoint(
            x: _merchichX,
            y: _merchichY,
          );
          final idCommune = commune?['id_commune'];
          if (idCommune != null) {
            data['id_commune'] = idCommune;
            final idProvince = commune?['id_province'];
            if (idProvince != null && data['id_province'] == null) {
              data['id_province'] = idProvince;
            }
          }
        } catch (e) {
          debugPrint('id_commune via geom ignore: $e');
        }
      }

      // ── INSERT ou UPDATE dans la table métier ──
      late final int localId;
      if (widget.existingData != null && widget.existingData!['id'] != null) {
        final existingId = widget.existingData!['id'] is int
            ? widget.existingData!['id'] as int
            : int.tryParse(widget.existingData!['id'].toString());
        if (existingId == null) {
          throw Exception('Identifiant local invalide pour la mise à jour');
        }
        localId = existingId;
        await db.updateEntitySrm(
          tableName,
          existingId,
          data,
          recordHistory: true,
        );
      } else {
        localId = await db.insertEntitySrm(
          tableName,
          data,
          recordHistory: true,
        );
      }

      if (_isObjetIncomplet) {
        await db.upsertObjetIncompletForEntity(
          tableName: tableName,
          idObjet: localId,
          metierCode: _metierCode,
          raison: _raisonIncomplet,
          detailRaison: _detailRaisonController.text.trim(),
        );
      } else {
        await db.resolveObjetIncompletForEntity(
          tableName: tableName,
          idObjet: localId,
        );
      }

      await _cancelRemovedLocalPhotoUploadsAfterSave(db);

      if (mounted) {
        // ── SPRINT 7 : supprimer le brouillon après enregistrement réussi ──
        await clearDraftAfterSave();
        if (!mounted) return;
        final label = _isObjetIncomplet
            ? '⚠️ $_displayTitle signalé incomplet'
            : '✅ $_displayTitle enregistré';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(label),
          backgroundColor: _isObjetIncomplet ? Colors.orange : Colors.green,
        ));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<String> _anomalieDetailFields() {
    final configs = _attributConfigByField.values
        .where((config) =>
            config.visible && _isAnomalieDetailField(config.nomChamp))
        .toList()
      ..sort((a, b) => a.ordre.compareTo(b.ordre));

    final result = <String>[];
    for (final config in configs) {
      if (!result.contains(config.nomChamp)) {
        result.add(config.nomChamp);
      }
    }
    for (final field in _controllers.keys) {
      if (_isAnomalieDetailField(field) &&
          _isConfiguredVisibleField(field) &&
          !result.contains(field)) {
        result.add(field);
      }
    }
    return result;
  }

  bool _hasAnomalieColumn(String field) =>
      _attributConfigByField.containsKey(field) ||
      _controllers.containsKey(field) ||
      _fields.contains(field) ||
      (widget.existingData?.containsKey(field) ?? false);

  dynamic _anomalieFlagValue(String field) {
    if (field == 'anomalie') return _hasAnomalie ? 1 : 0;
    final type = _attributConfigByField[field]?.typeChamp.toLowerCase() ?? '';
    if (type.contains('bool') || type.contains('int')) {
      return _hasAnomalie ? 1 : 0;
    }
    return _hasAnomalie ? 'Oui' : 'Non';
  }

  bool _isNoAnomalieValue(String value) {
    final normalized = _foldLabel(value);
    return normalized.isEmpty ||
        normalized == 'non' ||
        normalized == 'no' ||
        normalized == 'n' ||
        normalized == '0' ||
        normalized == 'false' ||
        normalized == 'aucun' ||
        normalized == 'aucune' ||
        normalized == 'sans anomalie' ||
        normalized == 'aucune anomalie';
  }

  void _applyCompteurAbonneAnomaliePayload(Map<String, dynamic> data) {
    final value = (_controllers['ep_anomalie']?.text ??
            data['ep_anomalie']?.toString() ??
            '')
        .trim();
    data['ep_anomalie'] = value.isEmpty ? null : value;
    data['anomalie'] = value.isNotEmpty && !_isNoAnomalieValue(value) ? 1 : 0;
    data['type_anomalie'] = null;
  }

  void _applyAnomaliePayload(Map<String, dynamic> data) {
    if (_isEpCompteurAbonne) {
      _applyCompteurAbonneAnomaliePayload(data);
      return;
    }

    data['anomalie'] = _hasAnomalie ? 1 : 0;

    for (final field in const ['ep_anomalie', 'ass_anomalie']) {
      if (_hasAnomalieColumn(field)) {
        data[field] = _anomalieFlagValue(field);
      }
    }

    final detailFields = _anomalieDetailFields();
    for (final field in detailFields) {
      if (!_hasAnomalie) {
        data[field] = null;
        continue;
      }
      if (field == 'type_anomalie') {
        final value = (_typeAnomalie ?? _controllers[field]?.text ?? '').trim();
        data[field] = value.isEmpty ? null : value;
        continue;
      }
      final raw = _controllers[field]?.text.trim() ?? '';
      data[field] = raw.isEmpty ? null : _normalizeFieldValue(field, raw);
    }

    if (!detailFields.contains('type_anomalie')) {
      final value = (_typeAnomalie ?? '').trim();
      data['type_anomalie'] = _hasAnomalie && value.isNotEmpty ? value : null;
    }

    if (_isEpRegardPoint && _hasAnomalie) {
      final regardValue =
          (data['anomalie_regard'] ?? _typeAnomalie ?? '').toString().trim();
      data['anomalie_regard'] = regardValue.isEmpty ? null : regardValue;
    }
    if (_isEpRegardPoint && !_hasAnomalie) {
      data['anomalie_regard'] = null;
      data['anomalie_tamp'] = null;
    }
  }

  // Construction d'un champ
  bool _isCoordSuffix(String field, String suffix) =>
      field.toLowerCase().endsWith(suffix);

  bool _isCoordField(String field) =>
      _isCoordSuffix(field, '_coor_x') ||
      _isCoordSuffix(field, '_coor_y') ||
      _isCoordSuffix(field, '_coor_z');

  List<Widget> _buildDynamicFields() {
    if (!_isEpCompteurAbonne) {
      return _fields.map(_buildField).toList();
    }
    return _buildCompteurAbonneFields();
  }

  List<Widget> _buildCompteurAbonneFields() {
    final widgets = <Widget>[];
    final rendered = <String>{};

    List<String> visibleFields(List<String> fields) {
      return fields
          .where((field) =>
              _fields.contains(field) &&
              !rendered.contains(field) &&
              !_isHiddenField(field))
          .toList();
    }

    void addFields(List<String> fields) {
      for (final field in fields) {
        rendered.add(field);
        widgets.add(_buildField(field));
      }
    }

    void addSection(
      String title,
      List<String> fields, {
      Widget? leading,
    }) {
      final sectionFields = visibleFields(fields);
      if (sectionFields.isEmpty && leading == null) return;
      widgets.add(_buildSectionHeader(title));
      if (leading != null) widgets.add(leading);
      addFields(sectionFields);
    }

    final coordFields = _fields.where(_isCoordField).toList();
    addSection('Terrain', [
      'type_cpt',
      'diametre',
      ...coordFields,
      'ep_conf_plan',
      'mode_localisation',
      'ep_observation',
      'ep_anomalie',
    ]);

    addSection(
      'Liaison clientèle',
      const [
        'num_contrat',
        'ancienne_police',
        'abon',
        'nom',
        'adresse',
        'etat_abonnement',
        'ancien_ref_sap',
        'id_geo',
        'ref',
      ],
      leading: _buildCustomerLinkStatus(),
    );

    final remaining = _fields
        .where((field) => !rendered.contains(field) && !_isHiddenField(field))
        .toList();
    addSection('Autres', remaining);

    return widgets;
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              color: _metierColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: _metierColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
        ],
      ),
    );
  }

  Widget _buildCustomerLinkStatus() {
    final message = _customerLinkMessage?.trim();
    if (!_isCustomerLinkLoading && (message == null || message.isEmpty)) {
      return const SizedBox.shrink();
    }

    final isSuccess = !_isCustomerLinkLoading &&
        (message?.startsWith('Client ONEP') ?? false);
    final color = isSuccess ? Colors.green.shade700 : Colors.orange.shade700;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCustomerLinkLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _metierColor,
              ),
            )
          else
            Icon(
              isSuccess ? Icons.link : Icons.info_outline,
              size: 18,
              color: color,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message ?? 'Recherche client ONEP...',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String field) {
    if (_isHiddenField(field)) {
      return const SizedBox.shrink();
    }

    final isCoord = _isCoordField(field);
    final isTypeField = field == _typeField && _typeOptions.isNotEmpty;
    final rule = _fieldRule(field);
    final isRequired =
        !isCoord && (_requiredFields.contains(field) || rule.required);
    final label = _fieldLabel(field);
    final controller = _controllers[field]!;
    final choices = _choicesByField[field] ?? const <SrmFieldChoice>[];

    // ── NOUVEAU : grisage si objet incomplet activé ──
    // Les coordonnées restent visibles mais désactivées de toute façon (readOnly)
    Widget fieldWidget;

    if (choices.isNotEmpty && !isCoord) {
      fieldWidget = _buildChoiceField(
        field: field,
        label: label,
        controller: controller,
        choices: choices,
        isRequired: isRequired,
      );
    } else if (isTypeField) {
      fieldWidget = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: controller.text.isEmpty ? null : controller.text,
          decoration: _deco(label, required: isRequired && !_isLocked),
          isExpanded: true,
          items: [
            _kEmptyChoiceMenuItem,
            ..._typeOptions
                .map((o) => DropdownMenuItem<String>(value: o, child: Text(o))),
          ],
          onChanged: (_isObjetIncomplet || _isLocked)
              ? null // désactivé si objet incomplet
              : (v) => controller.text = v ?? '',
          validator: (!_isObjetIncomplet && !_isLocked && isRequired)
              ? (v) => (v == null || v.isEmpty) ? 'Champ obligatoire *' : null
              : null,
        ),
      );
    } else if (isCoord) {
      // Coordonnées : toujours readOnly, remplies par GPS
      fieldWidget = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: _deco(label).copyWith(
            filled: true,
            fillColor: Colors.grey.shade100,
            suffixIcon: const Icon(Icons.gps_fixed, size: 16),
            helperText: 'Rempli automatiquement par le GPS',
            helperStyle: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          readOnly: true,
          style: const TextStyle(
              fontFamily: 'monospace', fontWeight: FontWeight.w600),
        ),
      );
    } else {
      final fieldIsReadOnly =
          _isLocked || _isObjetIncomplet || _isConfiguredReadOnlyField(field);
      fieldWidget = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: _deco(label,
                  required: isRequired && !_isLocked && !_isObjetIncomplet)
              .copyWith(
            filled: fieldIsReadOnly,
            fillColor: fieldIsReadOnly ? Colors.grey.shade50 : null,
          ),
          keyboardType: _kbType(rule),
          maxLines: rule.multiline ? 3 : 1,
          maxLength: rule.maxLength,
          inputFormatters: _inputFormatters(rule),
          readOnly: fieldIsReadOnly,
          onChanged: fieldIsReadOnly
              ? null
              : (_) {
                  if (_isCustomerLinkTriggerField(field)) {
                    _scheduleCustomerLinkLookup();
                  }
                },
          validator: (value) => (_isObjetIncomplet || _isLocked)
              ? null
              : _validateField(field, value),
        ),
      );
    }

    // ── NOUVEAU : opacité réduite quand objet incomplet (sauf coordonnées) ──
    if ((_isObjetIncomplet || _isLocked) && !isCoord) {
      return Opacity(
        opacity: _isLocked ? 0.55 : 0.35,
        child: fieldWidget,
      );
    }
    return fieldWidget;
  }

  // InputDecoration avec astérisque si requis
  Widget _buildChoiceField({
    required String field,
    required String label,
    required TextEditingController controller,
    required List<SrmFieldChoice> choices,
    required bool isRequired,
  }) {
    final currentValue = controller.text.trim();
    final seenValues = <String>{};
    final items = <DropdownMenuItem<String>>[_kEmptyChoiceMenuItem];

    for (final choice in choices) {
      if (!seenValues.add(choice.code)) continue;
      items.add(
        DropdownMenuItem<String>(
          value: choice.code,
          child: Text(choice.label),
        ),
      );
    }
    if (currentValue.isNotEmpty && seenValues.add(currentValue)) {
      items.add(
        DropdownMenuItem<String>(
          value: currentValue,
          child: Text(currentValue),
        ),
      );
    }

    final fieldIsReadOnly =
        _isLocked || _isObjetIncomplet || _isConfiguredReadOnlyField(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: currentValue.isEmpty ? null : currentValue,
        decoration: _deco(
          label,
          required: isRequired && !_isLocked && !_isObjetIncomplet,
        ).copyWith(
          filled: fieldIsReadOnly,
          fillColor: fieldIsReadOnly ? Colors.grey.shade50 : null,
        ),
        isExpanded: true,
        items: items,
        onChanged: fieldIsReadOnly
            ? null
            : (value) {
                controller.text = value ?? '';
                if (widget.existingData == null) onFieldChanged();
              },
        validator: (_isObjetIncomplet || _isLocked || !isRequired)
            ? null
            : (value) =>
                (value == null || value.isEmpty) ? 'Champ obligatoire *' : null,
      ),
    );
  }

  InputDecoration _deco(String label, {bool required = false}) =>
      InputDecoration(
        // ── NOUVEAU : astérisque rouge sur les champs obligatoires ──
        label: required
            ? RichText(
                text: TextSpan(
                  text: label,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                  children: const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
              )
            : null,
        labelText: required ? null : label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      );

  SrmFieldRule _fieldRule(String field) {
    final fallback = SrmConfig.getFieldRule(
      widget.metier,
      widget.entityType,
      field,
    );
    final config = _attributConfigByField[field];
    if (config == null) return fallback;

    final type = config.typeChamp.toLowerCase();
    final configuredMaxLength = _configuredTextMaxLength(type);
    if (type.contains('int') || type.contains('serial')) {
      return SrmFieldRule(
        kind: SrmFieldKind.integer,
        maxLength: fallback.maxLength,
        required: config.isRequired,
        multiline: fallback.multiline,
        readOnly: fallback.readOnly,
      );
    }
    if (type.contains('double') ||
        type.contains('numeric') ||
        type.contains('decimal') ||
        type.contains('real') ||
        type.contains('float')) {
      return SrmFieldRule(
        kind: SrmFieldKind.decimal,
        maxLength: fallback.maxLength,
        required: config.isRequired,
        multiline: fallback.multiline,
        readOnly: fallback.readOnly,
      );
    }
    if (type.contains('date') || type.contains('timestamp')) {
      return SrmFieldRule(
        kind: SrmFieldKind.date,
        maxLength: fallback.maxLength,
        required: config.isRequired,
        multiline: fallback.multiline,
        readOnly: fallback.readOnly,
      );
    }
    if (type.contains('uuid')) {
      return SrmFieldRule(
        kind: SrmFieldKind.uuid,
        maxLength: fallback.maxLength,
        required: config.isRequired,
        multiline: fallback.multiline,
        readOnly: fallback.readOnly,
      );
    }
    if (type.contains('bool')) {
      return SrmFieldRule(
        kind: SrmFieldKind.booleanLike,
        maxLength: fallback.maxLength,
        required: config.isRequired,
        multiline: fallback.multiline,
        readOnly: fallback.readOnly,
      );
    }
    if (type.contains('char') || type.contains('text')) {
      return SrmFieldRule(
        kind: SrmFieldKind.text,
        maxLength: configuredMaxLength ?? fallback.maxLength,
        required: config.isRequired,
        multiline: fallback.multiline,
        readOnly: fallback.readOnly,
        allowedValues: fallback.allowedValues,
      );
    }
    return SrmFieldRule(
      kind: fallback.kind,
      maxLength: configuredMaxLength ?? fallback.maxLength,
      required: config.isRequired,
      multiline: fallback.multiline,
      readOnly: fallback.readOnly,
      allowedValues: fallback.allowedValues,
    );
  }

  int? _configuredTextMaxLength(String type) {
    final match = RegExp(
      r'(?:character varying|varchar|character)\s*\((\d+)\)',
    ).firstMatch(type);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  TextInputType _kbType(SrmFieldRule rule) {
    switch (rule.kind) {
      case SrmFieldKind.integer:
        return TextInputType.number;
      case SrmFieldKind.decimal:
        return const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        );
      case SrmFieldKind.date:
        return TextInputType.datetime;
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter> _inputFormatters(SrmFieldRule rule) {
    switch (rule.kind) {
      case SrmFieldKind.integer:
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))];
      case SrmFieldKind.decimal:
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\-]'))];
      case SrmFieldKind.date:
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))];
      case SrmFieldKind.uuid:
        return [FilteringTextInputFormatter.allow(RegExp(r'[a-fA-F0-9-]'))];
      default:
        return const [];
    }
  }

  String? _validateConfiguredRange(
    String field,
    String normalized,
    SrmFieldRule rule,
  ) {
    final config = _attributConfigByField[field];
    if (config == null) return null;

    if (rule.kind == SrmFieldKind.integer ||
        rule.kind == SrmFieldKind.decimal) {
      final number = double.tryParse(normalized.replaceAll(',', '.'));
      if (number == null) return null;
      final min = config.numericMin;
      if (min != null && number < min) {
        return 'Valeur minimale : ${config.valeurMin}';
      }
      final max = config.numericMax;
      if (max != null && number > max) {
        return 'Valeur maximale : ${config.valeurMax}';
      }
      return null;
    }

    if (rule.kind == SrmFieldKind.date) {
      final date = DateTime.tryParse(normalized);
      if (date == null) return null;
      final min = config.dateMin;
      if (min != null && date.isBefore(min)) {
        return 'Date minimale : ${config.valeurMin}';
      }
      final max = config.dateMax;
      if (max != null && date.isAfter(max)) {
        return 'Date maximale : ${config.valeurMax}';
      }
    }

    return null;
  }

  String? _validateField(String field, String? value) {
    final normalized = (value ?? '').trim();
    final rule = _fieldRule(field);

    if (normalized.isEmpty) {
      return rule.required || _requiredFields.contains(field)
          ? 'Champ obligatoire *'
          : null;
    }

    if (rule.maxLength != null && normalized.length > rule.maxLength!) {
      return 'Maximum ${rule.maxLength} caractères';
    }

    switch (rule.kind) {
      case SrmFieldKind.integer:
        if (int.tryParse(normalized) == null) {
          return 'Nombre entier attendu';
        }
        break;
      case SrmFieldKind.decimal:
        if (double.tryParse(normalized.replaceAll(',', '.')) == null) {
          return 'Nombre décimal attendu';
        }
        break;
      case SrmFieldKind.date:
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalized)) {
          return 'Format attendu : YYYY-MM-DD';
        }
        break;
      case SrmFieldKind.uuid:
        if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(normalized)) {
          return 'UUID invalide';
        }
        break;
      case SrmFieldKind.enumValue:
        if (rule.allowedValues.isNotEmpty &&
            !rule.allowedValues.contains(normalized)) {
          return 'Valeur non autorisée';
        }
        break;
      case SrmFieldKind.booleanLike:
      case SrmFieldKind.text:
        break;
    }

    final rangeError = _validateConfiguredRange(field, normalized, rule);
    if (rangeError != null) return rangeError;

    return null;
  }

  dynamic _normalizeFieldValue(String field, String value) {
    final normalized = value.trim();
    final rule = _fieldRule(field);

    switch (rule.kind) {
      case SrmFieldKind.integer:
        return int.tryParse(normalized);
      case SrmFieldKind.decimal:
        return double.tryParse(normalized.replaceAll(',', '.'));
      case SrmFieldKind.date:
      case SrmFieldKind.uuid:
      case SrmFieldKind.enumValue:
      case SrmFieldKind.booleanLike:
      case SrmFieldKind.text:
        return normalized;
    }
  }

  String _fieldLabel(String field) {
    final dbLabel = _attributConfigByField[field]?.titreApp.trim() ?? '';
    if (dbLabel.isNotEmpty) {
      return dbLabel;
    }
    final configuredLabel = SrmConfig.getFieldLabel(
      widget.metier,
      widget.entityType,
      field,
    );
    final defaultConfigLabel = field.replaceAll('_', ' ');
    if (configuredLabel != defaultConfigLabel) {
      return configuredLabel;
    }

    final labels = <String, String>{
      'marque': 'Marque',
      'ref': 'Reference',
      'sect': 'Secteur',
      'tour': 'Tour',
      'abon': 'Abonne',
      'nom': 'Nom',
      'cin': 'CIN',
      'adresse': 'Adresse',
      'num_contrat': 'Numéro contrat',
      'num_compteur': 'Numéro compteur',
      'type_cpt': 'Type compteur',
      'type_abonnement': 'Type abonnement',
      'etat_abonnement': 'État abonnement',
      'consommation': 'Consommation',
      'date_pose': 'Date pose',
      'date_releve': 'Date relevé',
      'anne_fabr_compt': 'Année fabrication',
      'anomalie_rdo': 'Anomalie RDO',
      'diametre_calibre_terrain': 'Diamètre calibre terrain',
      'diametre_conduite': 'Diamètre conduite',
      // EP
      'ep_num': 'Numéro', 'ep_type': 'Type', 'ep_modele': 'Modèle',
      'ep_marque': 'Marque', 'ep_diam': 'Diamètre (mm)',
      'ep_ref_regard': 'Réf. regard', 'ep_sens_ferm': 'Sens fermeture',
      'ep_manoeuvre': 'Manœuvre', 'ep_etat': 'État',
      'ep_sectionnement': 'Sectionnement', 'emplacement': 'Emplacement',
      'ep_ref': 'Référence', 'ref_rue': 'Réf. rue',
      'ep_entreprise': 'Entreprise', 'ep_ref_marche': 'Réf. marché',
      'etage_aqua': 'Étage aqua', 'secteur_aqua': 'Secteur aqua',
      'ep_statut': 'Statut', 'observation': 'Observation',
      'date_leve': 'Date leve',
      'ep_coor_x': 'X Merchich (m)', 'ep_coor_y': 'Y Merchich (m)',
      'ep_coor_z': 'Z Altitude (m)', 'ep_pression': 'Pression (bar)',
      'ep_calibre': 'Calibre',
      'ep_capacite': 'Capacité (m³)', 'ep_cote_radier': 'Cote radier (m)',
      'ep_cote_trop_plein': 'Cote trop-plein', 'ep_cote_tn': 'Cote TN',
      'ep_nb_pompes': 'Nb pompes', 'ep_profondeur': 'Profondeur (m)',
      'ep_debit': 'Débit (m³/h)', 'ep_puissance': 'Puissance (kW)',
      'ep_forme': 'Forme', 'ep_longueur': 'Longueur (m)',
      'ep_largeur': 'Largeur (m)', 'ep_cote_tampon': 'Cote tampon',
      'ep_cote_fil_eau': 'Cote fil eau', 'zamont': 'Z amont (m)',
      'zaval': 'Z aval (m)', 'pente': 'Pente (%)',
      // ASS
      'conformite_plan': 'Conformité plan',
      'etat': 'État', 'type_regard': 'Type regard',
      'type_tampon': 'Type tampon', 'typereseau': 'Type réseau',
      'classe_tampon': 'Classe tampon', 'forme': 'Forme',
      'verrouille': 'Verrouillé',
      'accessibilite': 'Accessibilité', 'rehabilitation': 'Réhabilitation',
      'date_rehabilitation': 'Date réhabilitation',
      'nature_corps': 'Nature corps', 'presence_cunette': 'Présence cunette',
      'cote_tampon': 'Cote tampon (m)', 'cote_radier': 'Cote radier (m)',
      'chute': 'Chute (m)', 'profondeur_radier': 'Profondeur radier (m)',
      'ass_coor_x': 'X Merchich (m)', 'ass_coor_y': 'Y Merchich (m)',
      'ass_coor_z': 'Z Altitude (m)', 'centre': 'Centre',
      'commentaire': 'Commentaire',
    };
    return labels[field.toLowerCase()] ?? configuredLabel;
  }

  // Section photos
  Widget _buildPhotoSection() {
    if (_maxPhotos == 0) return const SizedBox.shrink();
    final disabled = _isObjetIncomplet || _isLocked;
    final visibleSlotCount = PhotoSlotService.visibleSlotCount(
      _photoPaths,
      _maxPhotos,
      allowAdd: !disabled,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text('Photos (max $_maxPhotos)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Text(
          'Formats autorisés: JPG, PNG, WEBP, HEIC • Taille max: ${PhotoValidationService.maxPhotoSizeLabel}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(visibleSlotCount, (i) {
            final idx = i + 1;
            final path = _photoPaths[idx];
            final isRemotePhoto =
                path != null && PhotoReferenceService.isRemoteReference(path);
            final canEditSlot = !disabled &&
                !isRemotePhoto &&
                PhotoSlotService.canPickSlot(_photoPaths, idx, _maxPhotos);
            return GestureDetector(
              onTap: canEditSlot ? () => _pickPhoto(idx) : null,
              child: Opacity(
                opacity: disabled ? (_isLocked ? 0.55 : 0.35) : 1.0,
                child: Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade100,
                      ),
                      child: path != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: _buildPhotoPreview(path))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo,
                                    color: Colors.grey.shade400),
                                Text('Photo $idx',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500)),
                              ],
                            ),
                    ),
                    if (path != null && canEditSlot)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            _removePhoto(idx);
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  List<String> _anomalieExtraDetailFields() => _anomalieDetailFields()
      .where((field) => field != 'type_anomalie')
      .toList();

  bool get _hasTypeAnomalieField =>
      _isConfiguredVisibleField('type_anomalie') &&
      (_attributConfigByField.containsKey('type_anomalie') ||
          _controllers.containsKey('type_anomalie') ||
          _choicesByField.containsKey('type_anomalie') ||
          (widget.existingData?.containsKey('type_anomalie') ?? false));

  List<DropdownMenuItem<String>> _choiceDropdownItemsForField(String field) {
    final choices = _choicesByField[field] ?? const <SrmFieldChoice>[];
    final currentValue = (_controllers[field]?.text ?? '').trim();
    final seenValues = <String>{};
    final items = <DropdownMenuItem<String>>[_kEmptyChoiceMenuItem];
    for (final choice in choices) {
      if (!seenValues.add(choice.code)) continue;
      items.add(
        DropdownMenuItem(value: choice.code, child: Text(choice.label)),
      );
    }
    if (currentValue.isNotEmpty && seenValues.add(currentValue)) {
      items.add(
          DropdownMenuItem(value: currentValue, child: Text(currentValue)));
    }
    return items;
  }

  Widget _buildTypeAnomalieField() {
    const field = 'type_anomalie';
    final controller = _controllers.putIfAbsent(
      field,
      () {
        final controller = TextEditingController(
          text: widget.existingData?[field]?.toString() ??
              _attributConfigByField[field]?.valeurParDefaut ??
              '',
        );
        if (widget.existingData == null) {
          controller.addListener(onFieldChanged);
        }
        return controller;
      },
    );
    final choices = _choicesByField[field] ?? const <SrmFieldChoice>[];
    if (choices.isNotEmpty) {
      final value = (_typeAnomalie ?? controller.text).trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: value.isEmpty ? null : value,
          decoration: _deco(_fieldLabel(field)),
          hint: const Text('Selectionner'),
          isExpanded: true,
          items: _choiceDropdownItemsForField(field),
          onChanged: _isLocked
              ? null
              : (value) => setState(() {
                    _typeAnomalie = value;
                    controller.text = value ?? '';
                  }),
        ),
      );
    }

    final rule = _fieldRule(field);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: _deco(_fieldLabel(field)),
        keyboardType: _kbType(rule),
        maxLines: rule.multiline ? 3 : 1,
        maxLength: rule.maxLength,
        inputFormatters: _inputFormatters(rule),
        readOnly: _isLocked,
        onChanged: (value) {
          final normalized = value.trim();
          _typeAnomalie = normalized.isEmpty ? null : normalized;
        },
        validator: _isLocked ? null : (value) => _validateField(field, value),
      ),
    );
  }

  Widget _buildAnomalieTextField(String field) {
    final controller = _controllers.putIfAbsent(
      field,
      () {
        final controller = TextEditingController(
          text: widget.existingData?[field]?.toString() ??
              _attributConfigByField[field]?.valeurParDefaut ??
              '',
        );
        if (widget.existingData == null) {
          controller.addListener(onFieldChanged);
        }
        return controller;
      },
    );
    final choices = _choicesByField[field] ?? const <SrmFieldChoice>[];
    if (choices.isNotEmpty) {
      return _buildChoiceField(
        field: field,
        label: _fieldLabel(field),
        controller: controller,
        choices: choices,
        isRequired: _attributConfigByField[field]?.isRequired ?? false,
      );
    }
    final rule = _fieldRule(field);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: _deco(_fieldLabel(field)),
        keyboardType: _kbType(rule),
        maxLines: rule.multiline ? 3 : 1,
        maxLength: rule.maxLength,
        inputFormatters: _inputFormatters(rule),
        readOnly: _isLocked,
        validator: _isLocked
            ? null
            : (value) {
                final config = _attributConfigByField[field];
                if (_hasAnomalie &&
                    config != null &&
                    config.isRequired &&
                    (value ?? '').trim().isEmpty) {
                  return 'Champ requis';
                }
                return _validateField(field, value);
              },
      ),
    );
  }

  // Section anomalie
  Widget _buildAnomalieSection() {
    final disabled = _isObjetIncomplet || _isLocked;
    return Opacity(
      opacity: disabled ? (_isLocked ? 0.55 : 0.35) : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          SwitchListTile(
            title: const Text('Anomalie détectée',
                style: TextStyle(fontWeight: FontWeight.bold)),
            value: _hasAnomalie,
            activeThumbColor: Colors.red,
            onChanged: disabled
                ? null
                : (v) => setState(() {
                      _hasAnomalie = v;
                      if (!v) {
                        _typeAnomalie = null;
                        for (final field in _anomalieDetailFields()) {
                          _controllers[field]?.clear();
                        }
                      }
                    }),
            contentPadding: EdgeInsets.zero,
          ),
          if (_hasAnomalie && !_isObjetIncomplet && _hasTypeAnomalieField)
            _buildTypeAnomalieField(),
          if (_hasAnomalie && !_isObjetIncomplet)
            ..._anomalieExtraDetailFields().map(_buildAnomalieTextField),
        ],
      ),
    );
  }

  // Section objet incomplet
  Widget _buildObjetIncompletSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        // Bandeau d'avertissement quand activé
        if (_isObjetIncomplet)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les champs de l\'objet sont désactivés.\n'
                    'Seule la position GPS et la raison sont enregistrées.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),

        SwitchListTile(
          title: const Text(
            'Signaler comme objet incomplet',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Active si l\'objet est inaccessible ou impossible à collecter',
            style: TextStyle(fontSize: 12),
          ),
          value: _isObjetIncomplet,
          activeThumbColor: Colors.orange,
          onChanged: (v) => setState(() {
            _isObjetIncomplet = v;
            // Si on désactive l'incomplet, on remet les anomalies à zéro
            if (!v) {
              _raisonIncomplet = null;
              _detailRaisonController.clear();
            }
            // Si on active l'incomplet, on force l'anomalie à false
            if (v) {
              _hasAnomalie = false;
              _typeAnomalie = null;
              for (final field in _anomalieDetailFields()) {
                _controllers[field]?.clear();
              }
            }
          }),
          contentPadding: EdgeInsets.zero,
        ),

        // Champs supplémentaires visibles seulement si toggle ON
        if (_isObjetIncomplet) ...[
          const SizedBox(height: 8),

          // Raison obligatoire depuis enum raison_incomplet_enum de la BDD
          DropdownButtonFormField<String>(
            initialValue: _raisonIncomplet,
            decoration: _deco('Raison', required: true),
            hint: const Text('Sélectionner une raison'),
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                  value: 'ACCES_BLOQUE', child: Text('Accès bloqué')),
              DropdownMenuItem(
                  value: 'VEHICULE_STATIONNE',
                  child: Text('Véhicule stationné sur la voie')),
              DropdownMenuItem(
                  value: 'TAMPON_INACCESSIBLE',
                  child: Text('Tampon inaccessible / scellé')),
              DropdownMenuItem(
                  value: 'CONDITIONS_METEO',
                  child: Text('Conditions météo défavorables')),
              DropdownMenuItem(value: 'DANGER', child: Text('Danger sur site')),
              DropdownMenuItem(value: 'AUTRE', child: Text('Autre raison')),
            ],
            onChanged: (v) => setState(() => _raisonIncomplet = v),
            validator: (v) => (v == null) ? 'Raison obligatoire *' : null,
          ),

          const SizedBox(height: 10),

          // Détail / commentaire libre
          TextFormField(
            controller: _detailRaisonController,
            decoration: _deco('Détail / commentaire (facultatif)'),
            maxLines: 2,
            keyboardType: TextInputType.multiline,
          ),

          const SizedBox(height: 4),
          Text(
            'Statut automatique : A_COMPLETER',
            style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade700,
                fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }

  // Build principal
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (widget.existingData == null) await saveDraftBeforeExit();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _isLocked
              ? Colors.grey.shade700
              : (_isObjetIncomplet ? Colors.orange : _metierColor),
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_displayTitle,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  if (_isLocked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline,
                              size: 10, color: Colors.white),
                          SizedBox(width: 3),
                          Text('VERROUILLÉ',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  if (_isObjetIncomplet && !_isLocked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('INCOMPLET',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              Text(widget.metier,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)),
              )
            else if (!_isLocked)
              IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Enregistrer',
                  onPressed: _save)
            else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Icon(Icons.lock_outline, color: Colors.white70),
              ),
          ],
        ),
        body: _isLoadingFields
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: _metierColor),
                    const SizedBox(height: 20),
                    Text(
                      'Préparation du formulaire...',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_isLocked)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                color: Colors.grey.shade600, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                FormLockService.lockReason(
                                    widget.existingData!),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Bandeau GPS
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _metierColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _metierColor.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.gps_fixed,
                                size: 14, color: _metierColor),
                            const SizedBox(width: 6),
                            Text('Position collectée',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _metierColor,
                                    fontSize: 13)),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            'Lat: ${widget.latitude.toStringAsFixed(7)}  '
                            'Lon: ${widget.longitude.toStringAsFixed(7)}',
                            style: const TextStyle(
                                fontSize: 11, fontFamily: 'monospace'),
                          ),
                          Text(
                            'X: ${_merchichX.toStringAsFixed(3)} m  '
                            'Y: ${_merchichY.toStringAsFixed(3)} m'
                            '${widget.altitude != null ? "  Z: ${widget.altitude!.toStringAsFixed(3)} m" : ""}',
                            style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: _metierColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                    // ── Légende champs obligatoires ──
                    if (_requiredFields.isNotEmpty &&
                        !_isObjetIncomplet &&
                        !_isLocked)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Text(' * ',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            Text('Champ obligatoire',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),

                    // Champs dynamiques
                    ..._buildDynamicFields(),

                    // Sections anomalie + incomplet
                    if (!_isEpMinimalLocationForm && !_isEpCompteurAbonne) ...[
                      _buildAnomalieSection(),
                      if (!_isLocked) _buildObjetIncompletSection(),
                    ],
                    _buildPhotoSection(),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: widget.onCancel,
                            child: const Text('Fermer'),
                          ),
                        ),
                        if (!_isLocked) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isObjetIncomplet
                                    ? Colors.orange
                                    : _metierColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : Icon(_isObjetIncomplet
                                      ? Icons.warning_amber_rounded
                                      : Icons.save),
                              label: Text(_isSaving
                                  ? 'Enregistrement...'
                                  : _isObjetIncomplet
                                      ? 'Signaler incomplet'
                                      : 'Enregistrer'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}
