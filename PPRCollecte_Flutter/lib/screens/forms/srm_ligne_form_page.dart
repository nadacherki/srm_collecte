// lib/screens/forms/srm_ligne_form_page.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../services/draft_service.dart';
import '../../services/form_lock_service.dart';
import '../../services/line_form_payload_service.dart';
import '../../services/photo_reference_service.dart';
import '../../services/photo_slot_service.dart';
import '../../services/photo_storage_service.dart';
import '../../services/photo_validation_service.dart';
import '../../services/projection_service.dart';
import '../../services/attribut_config_mobile_service.dart';
import '../../services/srm_field_option_service.dart';

/// Option vide partagée par les listes déroulantes du formulaire ligne.
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

class SrmLigneFormPage extends StatefulWidget {
  final String metier;
  final String entityType;
  final String? displayTitle;
  final List<LatLng> linePoints;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? agentName;
  final Map<String, dynamic>? existingData;
  final double? averageAltitude;

  const SrmLigneFormPage({
    super.key,
    required this.metier,
    required this.entityType,
    this.displayTitle,
    required this.linePoints,
    this.startTime,
    this.endTime,
    this.agentName,
    this.existingData,
    this.averageAltitude,
  });

  @override
  State<SrmLigneFormPage> createState() => _SrmLigneFormPageState();
}

class _SrmLigneFormPageState extends State<SrmLigneFormPage>
    with FormDraftMixin<SrmLigneFormPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final _detailRaisonController = TextEditingController();
  final _picker = ImagePicker();
  final Map<int, String?> _photoPaths = {1: null, 2: null, 3: null, 4: null};
  final Map<int, String?> _anomaliePhotoPaths = {
    1: null,
    2: null,
    3: null,
    4: null,
  };
  final Map<int, String?> _retourTerrainPhotoPaths = {
    1: null,
    2: null,
    3: null,
    4: null,
  };
  final Map<int, String?> _incompletPhotoPaths = {
    1: null,
    2: null,
    3: null,
    4: null,
  };
  final Map<int, String?> _incompletComplementPhotoPaths = {
    1: null,
    2: null,
    3: null,
    4: null,
  };
  final Map<String, Map<int, String?>> _initialWorkflowPhotoPaths = {};
  bool _wasObjetIncompletAtOpen = false;
  int _workflowInterventionId = 0;

  bool _hasAnomalie = false;
  String? _typeAnomalie;
  bool _isObjetIncomplet = false;
  String? _raisonIncomplet;
  bool _isSaving = false;
  bool _isLocked = false;

  List<({String label, Map<int, String?> paths})> _allPhotoGroups() {
    return [
      (label: 'photos standards', paths: _photoPaths),
      (label: 'photos anomalie', paths: _anomaliePhotoPaths),
      (label: 'photos incomplet', paths: _incompletPhotoPaths),
      (label: 'photos complément', paths: _incompletComplementPhotoPaths),
      (label: 'photos retour terrain', paths: _retourTerrainPhotoPaths),
    ];
  }

  Future<String?> _findDuplicatePhotoLocation({
    required String candidatePath,
    required Map<int, String?> currentPaths,
    required int currentSlot,
  }) async {
    for (final group in _allPhotoGroups()) {
      final duplicateSlot = await PhotoValidationService.findDuplicateSlot(
        candidatePath: candidatePath,
        existingPaths: group.paths,
        currentSlot: identical(group.paths, currentPaths) ? currentSlot : null,
      );
      if (duplicateSlot != null) {
        return '${group.label} / Photo $duplicateSlot';
      }
    }
    return null;
  }

  List<String> _fields = [];
  List<String> _requiredFields = [];
  Map<String, AttributConfigMobileField> _attributConfigByField = {};
  Map<String, List<SrmFieldChoice>> _choicesByField = {};
  Map<String, String> _fieldValidationErrors = {};
  // True tant que la config dynamique des champs n'est pas chargee :
  // evite le flash entre les SrmConfig en dur et la config serveur.
  bool _isLoadingFields = true;
  late final List<String> _typeOptions;
  late final String? _typeField;
  late final int _maxPhotos;
  late final double _distanceTotaleM;
  int get _photoSlotCount =>
      _maxPhotos < 0 ? 0 : (_maxPhotos > 4 ? 4 : _maxPhotos);

  late double _xDebut;
  late double _yDebut;
  late double _xFin;
  late double _yFin;

  Color get _metierColor => Color(SrmConfig.getMetierColor(widget.metier));
  String get _tableName =>
      SrmConfig.getTableName(widget.metier, widget.entityType) ?? '';
  String get _displayTitle => (widget.displayTitle?.trim().isNotEmpty == true)
      ? widget.displayTitle!.trim()
      : widget.entityType;
  String get _metierCode => widget.metier == 'Eau Potable'
      ? 'EP'
      : widget.metier == 'Assainissement'
          ? 'ASS'
          : 'SRM';

  static const String _photoContextAnomalieAvant = 'anomalie_avant';
  static const String _photoContextRetourTerrain = 'retour_terrain_apres';
  static const String _photoContextIncompletInitial = 'incomplet_initial';
  static const String _photoContextIncompletComplement = 'incomplet_complement';
  static const int _requiredGeneralPhotoCount = 4;
  static const int _requiredWorkflowPhotoCount = 2;

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

  bool _isAnomalieFlagField(String field) {
    final normalized = field.toLowerCase();
    return normalized == 'anomalie' ||
        normalized == 'ep_anomalie' ||
        normalized == 'ass_anomalie';
  }

  bool _isAnomalieDetailField(String field) {
    final normalized = field.toLowerCase();
    if (_isAnomalieFlagField(normalized)) return false;
    return normalized == 'type_anomalie' ||
        normalized.startsWith('anomalie_') ||
        normalized.endsWith('_anomalie');
  }

  bool _isAnomalieManagedField(String field) =>
      _isAnomalieFlagField(field) || _isAnomalieDetailField(field);

  List<String> _anomalieEvidenceFields() {
    return _anomalieDetailFields()
        .where((field) => _isAnomalieEvidenceFieldVisibleOnForm(field))
        .toList()
      ..sort();
  }

  bool _isAnomalieEvidenceFieldVisibleOnForm(String field) {
    if (_isAnomalieFlagField(field)) return false;
    if (field == 'type_anomalie') return _hasTypeAnomalieField;
    final config = _configForField(field);
    return config != null && config.visible;
  }

  String? _validateAnomalieEvidence() {
    if (!_hasAnomalie || _isObjetIncomplet) return null;
    final fields = _anomalieEvidenceFields();
    if (fields.isEmpty) return null;
    for (final field in fields) {
      if ((_controllers[field]?.text.trim() ?? '').isNotEmpty) return null;
    }
    return 'Veuillez renseigner le type ou un detail de l\'anomalie';
  }

  AttributConfigMobileField? _configForField(String field) {
    final direct = _attributConfigByField[field];
    if (direct != null) return direct;
    final normalized = field.trim().toLowerCase();
    final lower = _attributConfigByField[normalized];
    if (lower != null) return lower;
    for (final entry in _attributConfigByField.entries) {
      if (entry.key.trim().toLowerCase() == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  bool _isConfiguredVisibleField(String field) {
    final config = _configForField(field);
    return config == null || config.visible || config.isAutoVisibleCoordinate;
  }

  bool _isObjetIncompletManagedField(String field) {
    final normalized = field.toLowerCase();
    return normalized == 'objet_incomplet' ||
        normalized == 'raison_incomplet' ||
        normalized == 'detail_raison';
  }

  bool _isWorkflowManagedField(String field) =>
      _isAnomalieManagedField(field) || _isObjetIncompletManagedField(field);

  List<LatLng> _decodeExistingLinePoints(dynamic rawPoints) {
    if (rawPoints == null) return const [];

    try {
      final decoded = rawPoints is String ? jsonDecode(rawPoints) : rawPoints;
      if (decoded is! List) {
        if (rawPoints is String) {
          return RegExp(
            r'lat:\s*([-0-9.]+),\s*lon:\s*([-0-9.]+)',
          )
              .allMatches(rawPoints)
              .map((match) {
                final lat = double.tryParse(match.group(1) ?? '');
                final lon = double.tryParse(match.group(2) ?? '');
                if (lat == null || lon == null) return null;
                return LatLng(lat, lon);
              })
              .whereType<LatLng>()
              .toList();
        }
        return const [];
      }

      final points = <LatLng>[];
      for (final item in decoded) {
        if (item is Map) {
          final lat = item['lat'] ?? item['latitude'];
          final lng = item['lon'] ?? item['lng'] ?? item['longitude'];
          if (lat is num && lng is num) {
            points.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        } else if (item is List && item.length >= 2) {
          final lng = item[0];
          final lat = item[1];
          if (lat is num && lng is num) {
            points.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
      return points;
    } catch (_) {
      if (rawPoints is! String) return const [];
      return RegExp(
        r'lat:\s*([-0-9.]+),\s*lon:\s*([-0-9.]+)',
      )
          .allMatches(rawPoints)
          .map((match) {
            final lat = double.tryParse(match.group(1) ?? '');
            final lon = double.tryParse(match.group(2) ?? '');
            if (lat == null || lon == null) return null;
            return LatLng(lat, lon);
          })
          .whereType<LatLng>()
          .toList();
    }
  }

  List<LatLng> get _effectiveLinePoints {
    if (widget.linePoints.length >= 2) return widget.linePoints;
    return _decodeExistingLinePoints(widget.existingData?['points_json']);
  }

  @override
  void initState() {
    super.initState();
    _fields = SrmConfig.getFields(widget.metier, widget.entityType);
    // _requiredFields est alimenté par _loadAttributConfigMobileFields()
    // depuis la SQLite locale (synchronisée au login). Pas de hardcoding.
    _typeOptions = SrmConfig.getTypeOptions(widget.metier, widget.entityType);
    _typeField = SrmConfig.getEntityConfig(
      widget.metier,
      widget.entityType,
    )?['typeField'] as String?;
    _maxPhotos = _requiredGeneralPhotoCount;
    final initialLinePoints = _effectiveLinePoints;
    _distanceTotaleM = _calcDistance(initialLinePoints);

    final proj = ProjectionService();
    if (initialLinePoints.isNotEmpty) {
      final debut = initialLinePoints.first;
      final fin = initialLinePoints.last;
      final md = proj.wgs84ToMerchich(
        longitude: debut.longitude,
        latitude: debut.latitude,
      );
      final mf = proj.wgs84ToMerchich(
        longitude: fin.longitude,
        latitude: fin.latitude,
      );
      _xDebut = md.x;
      _yDebut = md.y;
      _xFin = mf.x;
      _yFin = mf.y;
    } else {
      _xDebut = 0.0;
      _yDebut = 0.0;
      _xFin = 0.0;
      _yFin = 0.0;
    }

    for (final field in _fields) {
      final initial = widget.existingData?[field]?.toString() ?? '';
      _controllers[field] = TextEditingController(text: initial);
    }
    _loadAttributConfigMobileFields();
    _prefillCoordinates();

    if (widget.existingData != null) {
      _hasAnomalie = _isTruthyFlag(widget.existingData!['anomalie']) ||
          _isTruthyFlag(widget.existingData!['ep_anomalie']);
      _typeAnomalie = widget.existingData!['type_anomalie']?.toString();
      _isObjetIncomplet =
          _isTruthyFlag(widget.existingData!['objet_incomplet']);
      _raisonIncomplet = widget.existingData!['raison_incomplet']?.toString();
      _detailRaisonController.text =
          widget.existingData!['detail_raison_incomplet']?.toString() ?? '';
      _wasObjetIncompletAtOpen = _isObjetIncomplet;
      for (int i = 1; i <= _photoSlotCount; i++) {
        _photoPaths[i] = widget.existingData!['photo_$i']?.toString();
      }
      _photoPaths.addAll(
        PhotoSlotService.compact(
          _photoPaths,
          _photoSlotCount,
          isLockedReference: PhotoReferenceService.isRemoteReference,
        ),
      );
      _isLocked = FormLockService.isLocked(widget.existingData!);
      _restoreLinkedObjetIncompletDetails();
      _loadWorkflowPhotoQueues();
    }

    if (widget.existingData == null) {
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
      if (!mounted || configFields.isEmpty) return;

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
      });
    } catch (e) {
      debugPrint('[ATTRIBUT-CONFIG-MOBILE] Form fallback $_tableName: $e');
    } finally {
      // Quoi qu'il arrive : debloquer l'affichage du formulaire pour
      // eviter le flash entre les SrmConfig en dur et la config serveur.
      if (mounted && _isLoadingFields) {
        setState(() {
          _isLoadingFields = false;
        });
      }
    }
  }

  void _applyConfiguredDefaults() {
    if (widget.existingData != null) return;
    for (final entry in _attributConfigByField.entries) {
      final defaultValue = _configuredDefaultValueForField(entry.key);
      if (defaultValue.isEmpty) continue;
      final controller = _controllers[entry.key];
      if (controller == null || controller.text.trim().isNotEmpty) continue;
      controller.text = defaultValue;
    }
  }

  String _configuredDefaultValueForField(String field) {
    final defaultValue = _configForField(field)?.valeurParDefaut.trim() ?? '';
    if (defaultValue.isEmpty) return '';

    final choices = _choicesByField[field] ?? const <SrmFieldChoice>[];
    if (choices.isNotEmpty &&
        !choices.any((choice) => choice.code == defaultValue)) {
      return '';
    }
    return defaultValue;
  }

  void _prefillCoordinates() {
    final distStr = _distanceTotaleM.toStringAsFixed(2);
    if (_controllers.containsKey('longueur')) {
      _controllers['longueur']!.text = distStr;
    }
    if (_controllers.containsKey('ep_long_c')) {
      _controllers['ep_long_c']!.text = distStr;
    }
    if (_controllers.containsKey('ep_long_r')) {
      _controllers['ep_long_r']!.text = distStr;
    }
    if (_controllers.containsKey('long_troncon')) {
      _controllers['long_troncon']!.text = distStr;
    }

    if (widget.startTime != null && _controllers.containsKey('heure_debut')) {
      _controllers['heure_debut']!.text = _formatTime(widget.startTime!);
    }
    if (widget.endTime != null && _controllers.containsKey('heure_fin')) {
      _controllers['heure_fin']!.text = _formatTime(widget.endTime!);
    }
    if (widget.startTime != null && _controllers.containsKey('date_pose')) {
      _controllers['date_pose']!.text =
          widget.startTime!.toIso8601String().substring(0, 10);
    }
  }

  double _calcDistance(List<LatLng> pts) {
    if (pts.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < pts.length - 1; i++) {
      total += _haversine(pts[i], pts[i + 1]);
    }
    return total;
  }

  double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) *
            cos(b.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 2 * r * atan2(sqrt(h), sqrt(1 - h));
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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

  @override
  void dispose() {
    if (widget.existingData == null) disposeDraft();
    for (final c in _controllers.values) {
      c.dispose();
    }
    _detailRaisonController.dispose();
    super.dispose();
  }

  @override
  String get draftKey => DraftService.buildDraftKey(
        formType: 'srm_ligne',
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
    if (field == '__detail_raison') {
      return _isObjetIncomplet && value.trim().isNotEmpty;
    }
    final config = _configForField(field);
    if (config != null) {
      if (!config.visible && !config.isAutoVisibleCoordinate) return false;
    } else if (_attributConfigByField.isNotEmpty) {
      return false;
    }
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
        _photoSlotCount,
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

  Future<void> _pickPhoto(
    int index, {
    Map<int, String?>? targetPaths,
    String photoContext = 'collecte_initiale',
    int? maxSlots,
  }) async {
    final paths = targetPaths ?? _photoPaths;
    final slotLimit = maxSlots ??
        (targetPaths == null
            ? _photoSlotCount
            : _workflowPhotoSlotCount(photoContext));
    final previousPath = paths[index]?.trim();
    if (!PhotoSlotService.canPickSlot(paths, index, slotLimit)) {
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

    final duplicateLocation = await _findDuplicatePhotoLocation(
      candidatePath: picked.path,
      currentPaths: paths,
      currentSlot: index,
    );
    if (duplicateLocation != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.content_copy, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Photo déjà utilisée dans $duplicateLocation. '
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final tableName =
        SrmConfig.getTableName(widget.metier, widget.entityType) ?? '';
    late final String durablePath;
    try {
      durablePath = await PhotoStorageService.persistPickedPhoto(
        picked: picked,
        schemaName: _metierCode.toLowerCase(),
        tableName: tableName,
        photoSlot: index,
        photoContext: photoContext,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo non sauvegardée localement: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    if (PhotoReferenceService.isLocalReference(previousPath)) {
      await PhotoStorageService.deleteLocalPhotoReference(previousPath);
    }
    setState(() {
      paths[index] = durablePath;
      paths.addAll(
        PhotoSlotService.compact(
          paths,
          slotLimit,
          isLockedReference: PhotoReferenceService.isRemoteReference,
        ),
      );
    });
    if (targetPaths == null && widget.existingData == null) onFieldChanged();
  }

  Future<void> _removePhoto(
    int index, {
    Map<int, String?>? targetPaths,
    int? maxSlots,
  }) async {
    final paths = targetPaths ?? _photoPaths;
    final slotLimit = maxSlots ?? _photoSlotCount;
    final removedPath = paths[index]?.trim();
    setState(() {
      paths.addAll(
        PhotoSlotService.removeAndCompact(
          paths,
          index,
          slotLimit,
          isLockedReference: PhotoReferenceService.isRemoteReference,
        ),
      );
    });
    if (PhotoReferenceService.isLocalReference(removedPath)) {
      await PhotoStorageService.deleteLocalPhotoReference(removedPath);
    }
    if (targetPaths == null && widget.existingData == null) onFieldChanged();
  }

  Future<void> _cancelRemovedLocalPhotoUploadsAfterSave(
      DatabaseHelper db) async {
    final uuid = widget.existingData?['uuid']?.toString().trim() ?? '';
    if (uuid.isEmpty || _tableName.isEmpty) return;

    for (var slot = 1; slot <= _photoSlotCount; slot++) {
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
        await PhotoStorageService.deleteLocalPhotoReference(previous);
      }
    }
  }

  Map<int, String?> _workflowPhotoMapForContext(String photoContext) {
    switch (photoContext) {
      case _photoContextAnomalieAvant:
        return _anomaliePhotoPaths;
      case _photoContextRetourTerrain:
        return _retourTerrainPhotoPaths;
      case _photoContextIncompletInitial:
        return _incompletPhotoPaths;
      case _photoContextIncompletComplement:
        return _incompletComplementPhotoPaths;
      default:
        return _anomaliePhotoPaths;
    }
  }

  int _workflowPhotoSlotCount(String photoContext) {
    return PhotoStorageService.workflowPhotoSlotLimit;
  }

  int _countFilledPhotos(
    Map<int, String?> photoPaths,
    int maxSlots,
  ) {
    var count = 0;
    for (var slot = 1; slot <= maxSlots; slot++) {
      final value = photoPaths[slot]?.trim() ?? '';
      if (value.isNotEmpty) {
        count++;
      }
    }
    return count;
  }

  bool get _requiresWorkflowAnomaliePhotos =>
      _hasAnomalie;

  bool get _requiresWorkflowIncompletPhotos =>
      _isObjetIncomplet || (_wasObjetIncompletAtOpen && !_isObjetIncomplet);

  String? _validatePhotoRequirements() {
    if (_isLocked) return null;

    if (_requiresWorkflowAnomaliePhotos) {
      const context = _photoContextAnomalieAvant;
      const label = 'photos anomalie';
      final count = _countFilledPhotos(
        _workflowPhotoMapForContext(context),
        _workflowPhotoSlotCount(context),
      );
      if (count < _requiredWorkflowPhotoCount) {
        return 'Veuillez ajouter au moins $_requiredWorkflowPhotoCount $label.';
      }
    }

    if (_requiresWorkflowIncompletPhotos) {
      final context = _isObjetIncomplet
          ? _photoContextIncompletInitial
          : _photoContextIncompletComplement;
      final label = _isObjetIncomplet
          ? 'photos objet incomplet'
          : 'photos de complement';
      final count = _countFilledPhotos(
        _workflowPhotoMapForContext(context),
        _workflowPhotoSlotCount(context),
      );
      if (count < _requiredWorkflowPhotoCount) {
        return 'Veuillez ajouter au moins $_requiredWorkflowPhotoCount $label.';
      }
    }

    final generalCount = _countFilledPhotos(_photoPaths, _photoSlotCount);
    if (generalCount < _requiredGeneralPhotoCount &&
        !_requiresWorkflowAnomaliePhotos &&
        !_requiresWorkflowIncompletPhotos) {
      return 'Veuillez ajouter les $_requiredGeneralPhotoCount photos obligatoires.';
    }

    return null;
  }

  Future<void> _loadWorkflowPhotoQueues() async {
    final uuid = widget.existingData?['uuid']?.toString().trim() ?? '';
    if (uuid.isEmpty || _tableName.isEmpty) return;

    try {
      final db = DatabaseHelper();
      final resolvedInterventionId =
          await db.resolveInterventionAnomalieIdForObject(
        schemaName: _metierCode.toLowerCase(),
        tableName: _tableName,
        uuidObjet: uuid,
      );
      var queueInterventionId = resolvedInterventionId;
      var rows = await db.getPhotoSyncItemsForObject(
        schemaName: _metierCode.toLowerCase(),
        tableName: _tableName,
        uuidObjet: uuid,
        idInterventionAnomalie: queueInterventionId,
      );
      if (resolvedInterventionId != 0 && rows.isEmpty) {
        queueInterventionId = 0;
        rows = await db.getPhotoSyncItemsForObject(
          schemaName: _metierCode.toLowerCase(),
          tableName: _tableName,
          uuidObjet: uuid,
          idInterventionAnomalie: queueInterventionId,
        );
      }
      if (rows.isEmpty) {
        rows = _selectWorkflowPhotoRows(
          await db.getPhotoSyncItemsForObject(
            schemaName: _metierCode.toLowerCase(),
            tableName: _tableName,
            uuidObjet: uuid,
          ),
          preferredInterventionId: resolvedInterventionId,
        );
        queueInterventionId = _detectWorkflowInterventionId(
          rows,
          fallback: queueInterventionId,
        );
      }
      if (!mounted) return;
      setState(() {
        _workflowInterventionId = queueInterventionId;
        for (final row in rows) {
          final photoContext =
              row['photo_context']?.toString().trim() ?? 'collecte_initiale';
          if (photoContext == 'collecte_initiale') continue;
          final slot = int.tryParse(row['photo_slot']?.toString() ?? '');
          if (slot == null || slot < 1 || slot > 4) continue;
          final remote = row['remote_path']?.toString().trim() ?? '';
          final local = row['local_path']?.toString().trim() ?? '';
          final value = remote.isNotEmpty ? remote : local;
          if (value.isEmpty) continue;
          _workflowPhotoMapForContext(photoContext)[slot] = value;
        }
        for (final context in const [
          _photoContextAnomalieAvant,
          _photoContextRetourTerrain,
          _photoContextIncompletInitial,
          _photoContextIncompletComplement,
        ]) {
          final paths = _workflowPhotoMapForContext(context);
          paths.addAll(PhotoSlotService.compact(
            paths,
            _workflowPhotoSlotCount(context),
            isLockedReference: PhotoReferenceService.isRemoteReference,
          ));
          _initialWorkflowPhotoPaths[context] = Map<int, String?>.from(paths);
        }
      });
    } catch (e) {
      debugPrint('Photos workflow ignorees: $e');
    }
  }

  List<Map<String, dynamic>> _selectWorkflowPhotoRows(
    List<Map<String, dynamic>> rows, {
    required int preferredInterventionId,
  }) {
    if (rows.isEmpty) return rows;

    final selected = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final photoContext = row['photo_context']?.toString().trim() ?? '';
      if (photoContext.isEmpty || photoContext == 'collecte_initiale') continue;
      final slot = int.tryParse(row['photo_slot']?.toString() ?? '');
      if (slot == null || slot < 1 || slot > 4) continue;
      final key = '$photoContext|$slot';
      final current = selected[key];
      if (current == null ||
          _workflowPhotoRowScore(
                row,
                preferredInterventionId: preferredInterventionId,
              ) >
              _workflowPhotoRowScore(
                current,
                preferredInterventionId: preferredInterventionId,
              )) {
        selected[key] = row;
      }
    }

    final normalized = selected.values
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    normalized.sort((a, b) {
      final contextA = a['photo_context']?.toString() ?? '';
      final contextB = b['photo_context']?.toString() ?? '';
      final contextCompare = contextA.compareTo(contextB);
      if (contextCompare != 0) return contextCompare;
      final slotA = int.tryParse(a['photo_slot']?.toString() ?? '') ?? 0;
      final slotB = int.tryParse(b['photo_slot']?.toString() ?? '') ?? 0;
      return slotA.compareTo(slotB);
    });
    return normalized;
  }

  int _workflowPhotoRowScore(
    Map<String, dynamic> row, {
    required int preferredInterventionId,
  }) {
    final rowInterventionId =
        int.tryParse(row['id_intervention_anomalie']?.toString() ?? '') ?? 0;
    final remote = row['remote_path']?.toString().trim() ?? '';
    final local = row['local_path']?.toString().trim() ?? '';
    final synced = int.tryParse(row['synced']?.toString() ?? '') ?? 0;

    var score = 0;
    if (preferredInterventionId > 0 && rowInterventionId == preferredInterventionId) {
      score += 100;
    }
    if (rowInterventionId > 0) score += 20;
    if (remote.isNotEmpty) score += 10;
    if (synced == 1) score += 5;
    if (local.isNotEmpty) score += 1;
    return score;
  }

  int _detectWorkflowInterventionId(
    List<Map<String, dynamic>> rows, {
    required int fallback,
  }) {
    for (final row in rows) {
      final value =
          int.tryParse(row['id_intervention_anomalie']?.toString() ?? '') ?? 0;
      if (value > 0) return value;
    }
    return fallback;
  }

  Future<void> _enqueueWorkflowPhotosAfterSave({
    required DatabaseHelper dbHelper,
    required String uuid,
  }) async {
    if (uuid.trim().isEmpty || _tableName.isEmpty) return;
    final resolvedInterventionId =
        await dbHelper.resolveInterventionAnomalieIdForObject(
      schemaName: _metierCode.toLowerCase(),
      tableName: _tableName,
      uuidObjet: uuid,
    );
    final interventionId = _workflowInterventionId != 0
        ? _workflowInterventionId
        : resolvedInterventionId;

    final allWorkflowPhotos = <String, Map<int, String?>>{
      _photoContextAnomalieAvant: _anomaliePhotoPaths,
      _photoContextRetourTerrain: _retourTerrainPhotoPaths,
      _photoContextIncompletInitial: _incompletPhotoPaths,
      _photoContextIncompletComplement: _incompletComplementPhotoPaths,
    };
    final activeContexts = <String>{
      if (_hasAnomalie && !_isObjetIncomplet) _photoContextAnomalieAvant,
      if (_isObjetIncomplet) _photoContextIncompletInitial,
      if (_wasObjetIncompletAtOpen && !_isObjetIncomplet)
        _photoContextIncompletComplement,
    };

    for (final entry in allWorkflowPhotos.entries) {
      if (activeContexts.contains(entry.key)) continue;
      for (var slot = 1; slot <= _photoSlotCount; slot++) {
        final current = entry.value[slot]?.trim() ?? '';
        if (!PhotoReferenceService.isLocalReference(current)) continue;
        await dbHelper.cancelPhotoSyncItem(
          schemaName: _metierCode.toLowerCase(),
          tableName: _tableName,
          uuidObjet: uuid,
          photoSlot: slot,
          photoContext: entry.key,
          idInterventionAnomalie: interventionId,
        );
        await PhotoStorageService.deleteLocalPhotoReference(current);
      }
    }

    for (final entry in allWorkflowPhotos.entries) {
      if (!activeContexts.contains(entry.key)) continue;
      final slotLimit = _workflowPhotoSlotCount(entry.key);
      final initial =
          _initialWorkflowPhotoPaths[entry.key] ?? const <int, String?>{};
      for (var slot = 1; slot <= _photoSlotCount; slot++) {
        final previous = initial[slot]?.trim() ?? '';
        final current = entry.value[slot]?.trim() ?? '';
        if (slot > slotLimit) {
          if (PhotoReferenceService.isLocalReference(current)) {
            await dbHelper.cancelPhotoSyncItem(
              schemaName: _metierCode.toLowerCase(),
              tableName: _tableName,
              uuidObjet: uuid,
              photoSlot: slot,
              photoContext: entry.key,
              idInterventionAnomalie: interventionId,
            );
            await PhotoStorageService.deleteLocalPhotoReference(current);
          }
          continue;
        }
        if (previous.isNotEmpty &&
            current != previous &&
            !PhotoReferenceService.isRemoteReference(previous)) {
          await dbHelper.cancelPhotoSyncItem(
            schemaName: _metierCode.toLowerCase(),
            tableName: _tableName,
            uuidObjet: uuid,
            photoSlot: slot,
            photoContext: entry.key,
            idInterventionAnomalie: interventionId,
          );
        }
        if (current.isEmpty ||
            !PhotoReferenceService.isLocalReference(current)) {
          continue;
        }
        await dbHelper.enqueuePhotoSyncItem(
          schemaName: _metierCode.toLowerCase(),
          tableName: _tableName,
          uuidObjet: uuid,
          photoSlot: slot,
          photoContext: entry.key,
          idInterventionAnomalie: interventionId,
          localPath: PhotoReferenceService.toLocalFilePath(current),
          idAgentCrea: ApiService.userId,
        );
      }
    }
  }

  void _clearFieldValidationError(String field) {
    if (!_fieldValidationErrors.containsKey(field)) return;
    setState(() {
      _fieldValidationErrors = Map<String, String>.from(_fieldValidationErrors)
        ..remove(field);
    });
  }

  Map<String, String> _collectFieldValidationErrors() {
    if (_isObjetIncomplet || _isLocked) return const {};
    final errors = <String, String>{};
    for (final field in _fields) {
      if (_isWorkflowManagedField(field)) continue;
      final error = _validateField(field, _controllers[field]?.text);
      if (error != null) {
        errors[field] = error;
      }
    }
    return errors;
  }

  void _showValidationSummary(Map<String, String> errors) {
    if (!mounted || errors.isEmpty) return;
    final labels = errors.keys.map(_fieldLabel).take(4).join(', ');
    final remaining = errors.length - errors.keys.take(4).length;
    final suffix = remaining > 0 ? ' (+$remaining)' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Champs obligatoires manquants : $labels$suffix'),
        backgroundColor: Colors.red,
      ),
    );
  }

  bool _validateBeforeSave() {
    if (_isLoadingFields || _formKey.currentState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Formulaire en cours de préparation. Réessayez.'),
        backgroundColor: Colors.orange,
      ));
      return false;
    }

    FocusScope.of(context).unfocus();
    final errors = _collectFieldValidationErrors();
    setState(() {
      _fieldValidationErrors = errors;
    });
    final mountedFieldsValid = _formKey.currentState?.validate() ?? true;
    if (errors.isNotEmpty || !mountedFieldsValid) {
      _showValidationSummary(errors);
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_isLocked || _isSaving) return;
    if (!_isObjetIncomplet && !_validateBeforeSave()) return;
    if (_isObjetIncomplet && _raisonIncomplet == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Veuillez sélectionner une raison pour l\'objet incomplet',
        ),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final anomalieEvidenceError = _validateAnomalieEvidence();
    if (anomalieEvidenceError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(anomalieEvidenceError),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final photoRequirementError = _validatePhotoRequirements();
    if (photoRequirementError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(photoRequirementError),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final tableName =
          SrmConfig.getTableName(widget.metier, widget.entityType) ?? '';
      if (tableName.isEmpty) throw Exception('Table non trouvée');
      final effectiveLinePoints = _effectiveLinePoints;
      if (effectiveLinePoints.length < 2) {
        throw Exception('Géométrie de ligne invalide');
      }

      final data = <String, dynamic>{};
      data['uuid'] = widget.existingData?['uuid'] ?? const Uuid().v4();

      for (final field in _fields) {
        final val = _controllers[field]?.text.trim();
        if (val != null && val.isNotEmpty) {
          data[field] = _normalizeFieldValue(field, val);
        }
      }

      data['points_json'] = jsonEncode(effectiveLinePoints
          .map((p) => {'lat': p.latitude, 'lon': p.longitude})
          .toList());
      data['nb_points'] = effectiveLinePoints.length;
      data['distance_m'] = _distanceTotaleM;
      LineFormPayloadService.applyAverageAltitude(
        data,
        widget.averageAltitude,
      );

      data['x_debut'] = _xDebut;
      data['y_debut'] = _yDebut;
      data['x_fin'] = _xFin;
      data['y_fin'] = _yFin;

      if (effectiveLinePoints.isNotEmpty) {
        data['lat_debut'] = effectiveLinePoints.first.latitude;
        data['lon_debut'] = effectiveLinePoints.first.longitude;
        data['lat_fin'] = effectiveLinePoints.last.latitude;
        data['lon_fin'] = effectiveLinePoints.last.longitude;
      }

      _applyAnomaliePayload(data);
      data['objet_incomplet'] = _isObjetIncomplet ? 1 : 0;

      for (int i = 1; i <= _photoSlotCount; i++) {
        data['photo_$i'] = _photoPaths[i];
      }

      data['id_agent_crea'] = ApiService.userId;
      data['mode_localisation'] = 'gnss';
      data['synced'] = 0;
      data['date_collecte'] = DateTime.now().toIso8601String();

      final dbHelper = DatabaseHelper();

      // Resoudre id_commune via le 1er point de la ligne (Merchich) afin que
      // la sync serveur ait un id valide. Sinon le backend neutralisera la FK
      // a NULL au moment du POST, mais autant le faire propre des le depart.
      if ((data['id_commune'] == null) && _xDebut != 0.0 && _yDebut != 0.0) {
        try {
          final commune = await dbHelper.findCommuneLocalByPoint(
            x: _xDebut,
            y: _yDebut,
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

      // Champs invisibles : remplissage automatique depuis valeur_par_defaut
      // configurée côté serveur (n'écrase jamais une valeur déjà résolue).
      // Pour les invisibles NOT NULL sans valeur_par_defaut, injection d'une
      // sentinelle typée pour éviter une violation NOT NULL côté serveur.
      for (final entry in _attributConfigByField.entries) {
        final field = entry.key;
        final config = entry.value;
        if (config.visible) continue;
        if (config.primaryKey) continue;
        if (field.toLowerCase() == 'geom') continue;
        if (data.containsKey(field) && data[field] != null) continue;
        final defaultValue = config.valeurParDefaut.trim();
        if (defaultValue.isNotEmpty) {
          data[field] = _normalizeFieldValue(field, defaultValue);
        } else if (!config.nullable) {
          data[field] = config.fallbackValueForInvisibleNotNull;
        }
      }

      late final int localId;
      if (widget.existingData != null && widget.existingData!['id'] != null) {
        final existingId = widget.existingData!['id'] is int
            ? widget.existingData!['id'] as int
            : int.tryParse(widget.existingData!['id'].toString());
        if (existingId == null) {
          throw Exception('Identifiant local invalide pour la mise à jour');
        }
        localId = existingId;
        await dbHelper.updateEntitySrm(
          tableName,
          existingId,
          data,
          recordHistory: true,
        );
      } else {
        localId = await dbHelper.insertEntitySrm(
          tableName,
          data,
          recordHistory: true,
        );
      }

      if (_isObjetIncomplet) {
        await dbHelper.upsertObjetIncompletForEntity(
          tableName: tableName,
          idObjet: localId,
          metierCode: _metierCode,
          raison: _raisonIncomplet,
          detailRaison: _detailRaisonController.text.trim(),
        );
      } else {
        await dbHelper.resolveObjetIncompletForEntity(
          tableName: tableName,
          idObjet: localId,
        );
      }

      final uuidObjet = data['uuid']?.toString().trim() ?? '';
      if (_hasAnomalie && !_isObjetIncomplet && uuidObjet.isNotEmpty) {
        await dbHelper.upsertLocalInterventionAnomalieSignalement(
          schemaName: _metierCode.toLowerCase(),
          tableName: tableName,
          idObjet: localId,
          uuidObjet: uuidObjet,
          rowData: data,
        );
      } else {
        await dbHelper.resolveLocalInterventionAnomalieSignalement(
          schemaName: _metierCode.toLowerCase(),
          tableName: tableName,
          idObjet: localId,
          uuidObjet: uuidObjet,
        );
      }

      await _cancelRemovedLocalPhotoUploadsAfterSave(dbHelper);
      await _enqueueWorkflowPhotosAfterSave(
        dbHelper: dbHelper,
        uuid: uuidObjet,
      );

      if (mounted) {
        await clearDraftAfterSave();
        if (!mounted) return;
        final label = _isObjetIncomplet
            ? '$_displayTitle signalé incomplet'
            : '$_displayTitle enregistré '
                '(${_distanceTotaleM.toStringAsFixed(1)} m, '
                '${widget.linePoints.length} pts)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label),
            backgroundColor: _isObjetIncomplet ? Colors.orange : Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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

  void _applyAnomaliePayload(Map<String, dynamic> data) {
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
  }

  bool _isCoordField(String field) {
    final normalized = field.toLowerCase();
    return normalized.endsWith('_coor_x') ||
        normalized.endsWith('_coor_y') ||
        normalized.endsWith('_coor_z');
  }

  Widget _buildField(String field) {
    if (_isWorkflowManagedField(field)) {
      return const SizedBox.shrink();
    }

    final isCoordField = _isCoordField(field);
    final isTypeField = field == _typeField && _typeOptions.isNotEmpty;
    final isDistanceField = field == 'longueur' ||
        field == 'ep_long_c' ||
        field == 'ep_long_r' ||
        field == 'long_troncon';
    final rule = _fieldRule(field);
    final label = _fieldLabel(field);
    final controller = _controllers[field]!;
    final isDisabled = _isLocked || _isObjetIncomplet;
    final shouldFade = isDisabled && !isCoordField && !isDistanceField;
    final isRequired = !isCoordField &&
        !isDistanceField &&
        !_hasAnomalie &&
        (_requiredFields.contains(field) || rule.required);
    final choices = _choicesByField[field] ?? const <SrmFieldChoice>[];

    if (choices.isNotEmpty && !isCoordField && !isDistanceField) {
      return _buildChoiceField(
        field: field,
        label: label,
        controller: controller,
        choices: choices,
        isRequired: isRequired,
        isDisabled: isDisabled,
        shouldFade: shouldFade,
      );
    }

    if (isTypeField) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Opacity(
          opacity: shouldFade ? (_isLocked ? 0.55 : 0.35) : 1.0,
          child: DropdownButtonFormField<String>(
            initialValue: controller.text.isEmpty ? null : controller.text,
            decoration: _deco(
              label,
              required: isRequired && !isDisabled,
              errorText: _fieldValidationErrors[field],
            ),
            isExpanded: true,
            items: [
              _kEmptyChoiceMenuItem,
              ..._typeOptions.map(
                  (o) => DropdownMenuItem<String>(value: o, child: Text(o))),
            ],
            onChanged: isDisabled
                ? null
                : (v) {
                    controller.text = v ?? '';
                    _clearFieldValidationError(field);
                  },
            validator: isDisabled || !isRequired
                ? null
                : (v) => (v == null || v.isEmpty) ? 'Champ requis' : null,
          ),
        ),
      );
    }

    if (isDistanceField) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: _deco(label).copyWith(
            filled: true,
            fillColor: Colors.grey.shade100,
            helperText: 'Calculée automatiquement depuis le tracé GPS',
            suffixIcon: const Icon(Icons.straighten, size: 16),
          ),
          readOnly: true,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: shouldFade ? (_isLocked ? 0.55 : 0.35) : 1.0,
        child: TextFormField(
          controller: controller,
          decoration: _deco(
            label,
            required: isRequired && !isDisabled,
            errorText: _fieldValidationErrors[field],
          ).copyWith(
            filled: isDisabled,
            fillColor: isDisabled ? Colors.grey.shade50 : null,
          ),
          keyboardType: _kbType(rule),
          maxLines: rule.multiline ? 3 : 1,
          maxLength: rule.maxLength,
          inputFormatters: _inputFormatters(rule),
          readOnly: isDisabled,
          onChanged:
              isDisabled ? null : (_) => _clearFieldValidationError(field),
          validator:
              isDisabled ? null : (value) => _validateField(field, value),
        ),
      ),
    );
  }

  Widget _buildChoiceField({
    required String field,
    required String label,
    required TextEditingController controller,
    required List<SrmFieldChoice> choices,
    required bool isRequired,
    required bool isDisabled,
    required bool shouldFade,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: shouldFade ? (_isLocked ? 0.55 : 0.35) : 1.0,
        child: DropdownButtonFormField<String>(
          initialValue: currentValue.isEmpty ? null : currentValue,
          decoration: _deco(
            label,
            required: isRequired && !isDisabled,
            errorText: _fieldValidationErrors[field],
          ).copyWith(
            filled: isDisabled,
            fillColor: isDisabled ? Colors.grey.shade50 : null,
          ),
          isExpanded: true,
          items: items,
          onChanged: isDisabled
              ? null
              : (value) {
                  controller.text = value ?? '';
                  _clearFieldValidationError(field);
                  if (widget.existingData == null) onFieldChanged();
                },
          validator: isDisabled || !isRequired
              ? null
              : (value) =>
                  (value == null || value.isEmpty) ? 'Champ requis' : null,
        ),
      ),
    );
  }

  InputDecoration _deco(
    String label, {
    bool required = false,
    String? errorText,
  }) =>
      InputDecoration(
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
                        fontSize: 14,
                      ),
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
        errorText: errorText,
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
      if (_hasAnomalie && !_isObjetIncomplet) return null;
      return rule.required || _requiredFields.contains(field)
          ? 'Champ requis'
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
    const labels = {
      'ep_num': 'Numéro',
      'ep_type': 'Type conduite',
      'ep_diam': 'Diamètre (mm)',
      'ep_mat': 'Matériau',
      'ep_long_c': 'Longueur calculée (m)',
      'ep_long_r': 'Longueur réelle (m)',
      'ep_profondeur': 'Profondeur (m)',
      'ep_classe_conduite': 'Classe',
      'emplacement': 'Emplacement',
      'zamont': 'Z amont (m)',
      'zaval': 'Z aval (m)',
      'pente': 'Pente (%)',
      'zalerte': 'Z alerte',
      'ref_rue': 'Réf. rue',
      'ep_entreprise': 'Entreprise',
      'ep_ref_marche': 'Réf. marché',
      'ep_sect_hydro': 'Secteur hydro',
      'ep_etage_p': 'Étage P',
      'etage_aqua': 'Étage aqua',
      'secteur_aqua': 'Secteur aqua',
      'ep_statut': 'Statut',
      'ep_long': 'Longueur (m)',
      'ep_etat': 'État',
      'uuid': 'UUID',
      'conformite_plan': 'Conformité plan',
      'classe': 'Classe',
      'etat': 'État',
      'date_pose': 'Date pose',
      'longueur': 'Longueur (m)',
      'nature': 'Nature',
      'typereseau': 'Type réseau',
      'reference': 'Référence',
      'rehabilitation': 'Réhabilitation',
      'date_rehabilitation': 'Date réhabilitation',
      'diametre': 'Diamètre (mm)',
      'largeur_base': 'Largeur base',
      'profondeur_aval': 'Profondeur aval (m)',
      'profondeur_amont': 'Profondeur amont (m)',
      'type_ecoulement': 'Type écoulement',
      'type_section': 'Type section',
      'type_conduite': 'Type conduite',
      'type_rehabilitation': 'Type réhabilitation',
      'protection_anticorrosion': 'Protection anti-corrosion',
      'type_activite': 'Type activité',
      'centre': 'Centre',
      'commentaire': 'Commentaire',
      'observation': 'Observation',
      'date_mise_service': 'Date mise en service',
      'caracteristique': 'Caractéristique',
      'date_mise_en_service': 'Date MES',
    };
    return labels[field.toLowerCase()] ?? field.replaceAll('_', ' ');
  }

  Widget _buildPhotoSection() {
    if (_photoSlotCount == 0) return const SizedBox.shrink();
    final disabled = _isObjetIncomplet ||
        _hasAnomalie ||
        _wasObjetIncompletAtOpen ||
        _isLocked;
    final visibleSlotCount = PhotoSlotService.visibleSlotCount(
      _photoPaths,
      _photoSlotCount,
      allowAdd: !disabled,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        const Text(
          'Photos obligatoires ($_requiredGeneralPhotoCount requises)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          'Formats autorisés: JPG, PNG, WEBP, HEIC • Taille max: '
          '${PhotoValidationService.maxPhotoSizeLabel}',
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
                PhotoSlotService.canPickSlot(
                  _photoPaths,
                  idx,
                  _photoSlotCount,
                );
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
                              child: _buildPhotoPreview(path),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  color: Colors.grey.shade400,
                                ),
                                Text(
                                  'Photo $idx',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
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
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
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

  Widget _buildWorkflowPhotoSection({
    required String title,
    String? subtitle,
    required String photoContext,
    required Map<int, String?> photoPaths,
    Color color = Colors.red,
  }) {
    final maxWorkflowPhotos = _workflowPhotoSlotCount(photoContext);
    if (maxWorkflowPhotos == 0) return const SizedBox.shrink();
    final disabled = _isLocked;
    final visibleSlotCount = PhotoSlotService.visibleSlotCount(
      photoPaths,
      maxWorkflowPhotos,
      allowAdd: !disabled,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.photo_camera_outlined, color: color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(visibleSlotCount, (i) {
                  final idx = i + 1;
                  final path = photoPaths[idx];
                  final isRemotePhoto = path != null &&
                      PhotoReferenceService.isRemoteReference(path);
                  final canEditSlot = !disabled &&
                      !isRemotePhoto &&
                      PhotoSlotService.canPickSlot(
                        photoPaths,
                        idx,
                        maxWorkflowPhotos,
                      );
                  return GestureDetector(
                    onTap: canEditSlot
                        ? () => _pickPhoto(
                              idx,
                              targetPaths: photoPaths,
                              photoContext: photoContext,
                              maxSlots: maxWorkflowPhotos,
                            )
                        : null,
                    child: Opacity(
                      opacity: disabled ? 0.55 : 1.0,
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: color.withValues(alpha: 0.45),
                              ),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: path != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: _buildPhotoPreview(path),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        color: color.withValues(alpha: 0.55),
                                      ),
                                      Text(
                                        'Photo $idx',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: color.withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                          if (path != null && canEditSlot)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removePhoto(
                                  idx,
                                  targetPaths: photoPaths,
                                  maxSlots: maxWorkflowPhotos,
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 14,
                                  ),
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
          ),
        ),
      ],
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
        isRequired: false,
        isDisabled: _isLocked,
        shouldFade: _isLocked,
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
                return _validateField(field, value);
              },
      ),
    );
  }

  Widget _buildAnomalieSection() {
    final disabled = _isObjetIncomplet || _isLocked;
    return Opacity(
      opacity: disabled ? (_isLocked ? 0.55 : 0.35) : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          SwitchListTile(
            title: const Text(
              'Anomalie détectée',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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

  Widget _buildObjetIncompletSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
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
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Les champs obligatoires sont neutralises.\n'
                    'Les valeurs deja saisies et les photos sont conservees.',
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
            if (!v) {
              _raisonIncomplet = null;
              _detailRaisonController.clear();
            }
            if (v) {
              _hasAnomalie = false;
            }
          }),
          contentPadding: EdgeInsets.zero,
        ),
        if (_isObjetIncomplet) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _raisonIncomplet,
            decoration: _deco('Raison', required: true),
            hint: const Text('Sélectionner une raison'),
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: 'ACCES_BLOQUE',
                child: Text('Accès bloqué'),
              ),
              DropdownMenuItem(
                value: 'VEHICULE_STATIONNE',
                child: Text('Véhicule stationné sur la voie'),
              ),
              DropdownMenuItem(
                value: 'TAMPON_INACCESSIBLE',
                child: Text('Tampon inaccessible / scellé'),
              ),
              DropdownMenuItem(
                value: 'CONDITIONS_METEO',
                child: Text('Conditions météo défavorables'),
              ),
              DropdownMenuItem(value: 'DANGER', child: Text('Danger sur site')),
              DropdownMenuItem(value: 'AUTRE', child: Text('Autre raison')),
            ],
            onChanged: (v) => setState(() => _raisonIncomplet = v),
          ),
          const SizedBox(height: 10),
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
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final distKm = (_distanceTotaleM / 1000).toStringAsFixed(3);

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
                  Text(
                    _displayTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isObjetIncomplet && !_isLocked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'INCOMPLET',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${widget.metier} — tracé GPS',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
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
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.check),
                tooltip: 'Enregistrer',
                onPressed: (_isLoadingFields || _isLocked) ? null : _save,
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _metierColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _metierColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timeline, color: _metierColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.linePoints.length} points  •  $distKm km  •  '
                                  '${_distanceTotaleM.toStringAsFixed(1)} m',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _metierColor,
                                  ),
                                ),
                                Text(
                                  'Début: X ${_xDebut.toStringAsFixed(1)} / '
                                  'Y ${_yDebut.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  'Fin:    X ${_xFin.toStringAsFixed(1)} / '
                                  'Y ${_yFin.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ..._fields.map(_buildField),
                    _buildAnomalieSection(),
                    if (!_isLocked) _buildObjetIncompletSection(),
                    _buildPhotoSection(),
                    if (_hasAnomalie)
                      _buildWorkflowPhotoSection(
                        title:
                            'Photos anomalie ($_requiredWorkflowPhotoCount requises)',
                        photoContext: _photoContextAnomalieAvant,
                        photoPaths: _anomaliePhotoPaths,
                        color: Colors.red,
                      ),
                    if (_isObjetIncomplet)
                      _buildWorkflowPhotoSection(
                        title:
                            'Photos objet incomplet ($_requiredWorkflowPhotoCount requises)',
                        photoContext: _photoContextIncompletInitial,
                        photoPaths: _incompletPhotoPaths,
                        color: Colors.orange,
                      ),
                    if (_wasObjetIncompletAtOpen && !_isObjetIncomplet)
                      _buildWorkflowPhotoSection(
                        title:
                            'Photos complement ($_requiredWorkflowPhotoCount requises)',
                        subtitle:
                            'Preuves ajoutees lors du completement de l\'objet.',
                        photoContext: _photoContextIncompletComplement,
                        photoPaths: _incompletComplementPhotoPaths,
                        color: Colors.blueGrey,
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Fermer'),
                          ),
                        ),
                        if (_isLocked) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Verrouillé'),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: (_isSaving || _isLoadingFields)
                                  ? null
                                  : _save,
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
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _isObjetIncomplet
                                          ? Icons.warning_amber_rounded
                                          : Icons.save,
                                    ),
                              label: Text(
                                _isSaving
                                    ? 'Enregistrement...'
                                    : _isObjetIncomplet
                                        ? 'Signaler incomplet'
                                        : 'Enregistrer',
                              ),
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
