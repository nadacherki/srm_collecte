import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../core/config/srm_config.dart';
import '../../services/commune_sync_service.dart';
import '../../services/projection_service.dart';
import '../../services/draft_service.dart';
import '../../services/form_lock_service.dart';
import '../../services/srm_field_option_service.dart';
import '../../services/attribut_config_mobile_service.dart';

/// Option vide partagée par les listes déroulantes du formulaire polygone.
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

class PolygonFormPage extends StatefulWidget {
  final List<LatLng> polygonPoints;
  final DateTime startTime;
  final DateTime endTime;
  final String agentName;
  final Map<String, dynamic>? existingData;

  // Contexte SRM du formulaire polygone
  // Ces champs sont requis par le flux actuel.
  final String metier;
  final String entityType;
  final String? displayTitle;

  const PolygonFormPage({
    super.key,
    required this.polygonPoints,
    required this.startTime,
    required this.endTime,
    required this.agentName,
    this.existingData,
    required this.metier,
    required this.entityType,
    this.displayTitle,
  });

  @override
  State<PolygonFormPage> createState() => _PolygonFormPageState();
}

class _PolygonFormPageState extends State<PolygonFormPage>
    with FormDraftMixin<PolygonFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocked = false;
  bool _hasAnomalie = false;
  String? _typeAnomalie;
  bool _isObjetIncomplet = false;
  String? _raisonIncomplet;
  final _detailRaisonController = TextEditingController();
  final _nomController = TextEditingController();
  final _codeGpsController = TextEditingController();

  // Champs SRM pour Regard EP
  final _epNumController = TextEditingController();
  final _epTypeController = TextEditingController();
  final _epFormeController = TextEditingController();
  final _epLongueurController = TextEditingController();
  final _epLargeurController = TextEditingController();
  final _epCoteTamponController = TextEditingController();
  final _epCoteRadierController = TextEditingController();
  final _epCoteFilEauController = TextEditingController();
  final _epEtatController = TextEditingController();
  final _emplacementController = TextEditingController();
  final _refRueController = TextEditingController();
  final _etageAquaController = TextEditingController();
  final _secteurAquaController = TextEditingController();
  final _observationController = TextEditingController();
  final Map<String, TextEditingController> _regardEpControllers = {};
  final Map<String, AttributConfigMobileField> _regardEpConfigByField = {};
  final Map<String, List<SrmFieldChoice>> _regardEpOptions = {};
  final List<String> _regardEpVisibleFields = [];
  final Set<String> _regardEpRequiredFields = {};
  final Map<String, List<SrmFieldChoice>> _polygonStatusChoicesByField = {};
  String _regardEpCommuneName = '';
  String _regardEpProvinceName = '';
  String _regardEpUuid = '';
  // Coordonnées Merchich du centroïde
  double _xMerchich = 0.0;
  double _yMerchich = 0.0;

  late List<LatLng> _polygonPoints;
  late double _superficieHa;
  late List<List<double>> _closedCoordinates;

  bool get _isEditing =>
      widget.existingData != null && widget.existingData!['id'] != null;

  bool get _isRegardEp =>
      widget.metier == 'Eau Potable' &&
      (widget.entityType == 'Regard EP' || widget.entityType == 'Regard');

  bool _isTruthyFlag(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 't';
  }

  Color get _categoryColor => Color(SrmConfig.getMetierColor(widget.metier));
  String get _metierCode => widget.metier == 'Eau Potable'
      ? 'EP'
      : widget.metier == 'Assainissement'
          ? 'ASS'
          : 'SRM';

  String get _pageTitle => (widget.displayTitle?.trim().isNotEmpty == true)
      ? widget.displayTitle!.trim()
      : widget.entityType;

  String get _tableName {
    if (_isRegardEp) return 'ep_regard';
    return SrmConfig.getTableName(widget.metier, widget.entityType) ??
        widget.entityType.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _polygonPoints = List<LatLng>.from(widget.polygonPoints);
    _initializeData();
    _setupAutoCapitalize();

    // Activer le brouillon automatique uniquement en création simple
    if (!_isEditing && !_isRegardEp) {
      final allControllers = [
        _nomController,
        _codeGpsController,
        _epNumController,
        _epTypeController,
        _epFormeController,
        _epLongueurController,
        _epLargeurController,
        _epCoteTamponController,
        _epCoteRadierController,
        _epCoteFilEauController,
        _epEtatController,
        _emplacementController,
        _refRueController,
        _etageAquaController,
        _secteurAquaController,
        _observationController,
      ];
      for (final c in allControllers) {
        c.addListener(onFieldChanged);
      }
      _detailRaisonController.addListener(onFieldChanged);
      initDraft();
    }
  }

  Future<void> _initializeData() async {
    _superficieHa = _calculateAreaHectares(widget.polygonPoints);
    await _loadPolygonStatusChoices();

    _closedCoordinates =
        widget.polygonPoints.map((p) => [p.longitude, p.latitude]).toList();
    if (_closedCoordinates.isNotEmpty) {
      _closedCoordinates.add(List<double>.from(_closedCoordinates.first));
    }

    // Calcul du centroïde Merchich Nord
    if (widget.polygonPoints.isNotEmpty) {
      final centroidLat =
          widget.polygonPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
              widget.polygonPoints.length;
      final centroidLon =
          widget.polygonPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
              widget.polygonPoints.length;
      final m = ProjectionService()
          .wgs84ToMerchich(longitude: centroidLon, latitude: centroidLat);
      _xMerchich = m.x;
      _yMerchich = m.y;

      // Pré-remplir les coordonnées SRM
      _epLongueurController.text =
          (widget.polygonPoints.length > 1 ? sqrt(_superficieHa * 10000) : 0.0)
              .toStringAsFixed(2);
    }

    // Pré-remplir en mode édition
    if (_isRegardEp) {
      await _initializeRegardEpForm();
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    if (_isEditing) {
      _nomController.text = widget.existingData!['nom']?.toString() ?? '';
      _codeGpsController.text = widget.existingData!['code']?.toString() ??
          widget.existingData!['code_gps']?.toString() ??
          '';
      _epNumController.text = widget.existingData!['ep_num']?.toString() ?? '';
      _epTypeController.text =
          widget.existingData!['ep_type']?.toString() ?? '';
      _epFormeController.text =
          widget.existingData!['ep_forme']?.toString() ?? '';
      _epEtatController.text =
          widget.existingData!['ep_etat']?.toString() ?? '';
      _emplacementController.text =
          widget.existingData!['emplacement']?.toString() ?? '';
      _observationController.text =
          widget.existingData!['observation']?.toString() ?? '';

      _hasAnomalie = _isTruthyFlag(widget.existingData!['anomalie']) ||
          (_isRegardEp && _isTruthyFlag(widget.existingData!['ep_anomalie']));
      _typeAnomalie = widget.existingData!['type_anomalie']?.toString();
      _isObjetIncomplet =
          _isTruthyFlag(widget.existingData!['objet_incomplet']);
      _raisonIncomplet = widget.existingData!['raison_incomplet']?.toString();
      _detailRaisonController.text =
          widget.existingData!['detail_raison_incomplet']?.toString() ?? '';
      _isLocked = FormLockService.isLocked(widget.existingData!);
      await _restoreLinkedObjetIncompletDetails();
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _initializeRegardEpForm() async {
    await _loadRegardEpConfigAndOptions();
    if (!mounted) return;
    final existingUuid = widget.existingData?['uuid']?.toString().trim() ?? '';
    _regardEpUuid = existingUuid.isNotEmpty ? existingUuid : const Uuid().v4();

    final fields = _regardEpConfigByField.isNotEmpty
        ? _regardEpConfigByField.keys.toList()
        : SrmConfig.getFields(widget.metier, widget.entityType);
    final now = DateTime.now();
    for (final field in fields) {
      final initialValue = _resolveRegardEpInitialValue(field, now);
      _regardEpControllers[field] = TextEditingController(text: initialValue);
    }

    await _populateRegardEpSpatialContext();
    if (!mounted) return;
    _applyRegardEpDerivedValues(now);
    _regardEpControllers['ep_ref_rue']
        ?.addListener(_syncRegardEpAdresseFromRefRue);

    if (!_isEditing) {
      for (final controller in _regardEpControllers.values) {
        controller.addListener(onFieldChanged);
      }
      _detailRaisonController.addListener(onFieldChanged);
      initDraft();
    }
  }

  void _recomputePolygonGeometry({bool prefillDerivedFields = false}) {
    _superficieHa = _calculateAreaHectares(_polygonPoints);

    _closedCoordinates =
        _polygonPoints.map((p) => <double>[p.longitude, p.latitude]).toList();
    if (_closedCoordinates.isNotEmpty) {
      _closedCoordinates.add(List<double>.from(_closedCoordinates.first));
    }

    if (_polygonPoints.isEmpty) {
      _xMerchich = 0.0;
      _yMerchich = 0.0;
      return;
    }

    final centroidLat =
        _polygonPoints.map((p) => p.latitude).reduce((a, b) => a + b) /
            _polygonPoints.length;
    final centroidLon =
        _polygonPoints.map((p) => p.longitude).reduce((a, b) => a + b) /
            _polygonPoints.length;
    final merchich = ProjectionService()
        .wgs84ToMerchich(longitude: centroidLon, latitude: centroidLat);
    _xMerchich = merchich.x;
    _yMerchich = merchich.y;

    if (prefillDerivedFields && _epLongueurController.text.trim().isEmpty) {
      _epLongueurController.text =
          (_polygonPoints.length > 1 ? sqrt(_superficieHa * 10000) : 0.0)
              .toStringAsFixed(2);
    }
  }

  List<LatLng> _decodeDraftPolygonPoints(dynamic raw) {
    if (raw is! List) return const <LatLng>[];

    final points = <LatLng>[];
    for (final item in raw) {
      if (item is Map) {
        final lat = item['lat'] ?? item['latitude'];
        final lng = item['lng'] ?? item['lon'] ?? item['longitude'];
        if (lat is num && lng is num) {
          points.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      } else if (item is List && item.length >= 2) {
        final lat = item[0];
        final lng = item[1];
        if (lat is num && lng is num) {
          points.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
    }

    if (points.length > 1 &&
        points.first.latitude == points.last.latitude &&
        points.first.longitude == points.last.longitude) {
      points.removeLast();
    }

    return points;
  }

  Future<void> _loadRegardEpConfigAndOptions() async {
    final configService = AttributConfigMobileService();
    final nomMetier =
        AttributConfigMobileService.nomMetierForMobileMetier(widget.metier);
    final nomTable = AttributConfigMobileService.configTableForMobileTable(
      nomMetier,
      _tableName,
    );

    final configs = await configService.getFieldsForConfigTable(
      nomMetier: nomMetier,
      nomTable: nomTable,
    );

    _regardEpConfigByField.clear();
    _regardEpVisibleFields.clear();
    _regardEpRequiredFields.clear();

    for (final config in configs) {
      final field = config.nomChamp.trim();
      if (field.isEmpty || config.primaryKey || field.toLowerCase() == 'geom') {
        continue;
      }
      _regardEpConfigByField[field] = config;
      if (config.visible || config.isAutoVisibleCoordinate) {
        _regardEpVisibleFields.add(field);
      }
      if (config.isRequired) {
        _regardEpRequiredFields.add(field);
      }
    }

    _regardEpVisibleFields.sort((a, b) {
      final aOrder = _regardEpConfigByField[a]?.ordre ?? 0;
      final bOrder = _regardEpConfigByField[b]?.ordre ?? 0;
      return aOrder.compareTo(bOrder);
    });

    try {
      final choices = await SrmFieldOptionService().getOptionsByField(
        tableSchema: nomMetier,
        tableName: nomTable,
        fieldNames: _regardEpConfigByField.keys,
      );
      _regardEpOptions
        ..clear()
        ..addAll(choices);
    } catch (e) {
      debugPrint('Options Regard EP indisponibles: $e');
    }
  }

  Future<void> _loadPolygonStatusChoices() async {
    final nomMetier =
        AttributConfigMobileService.nomMetierForMobileMetier(widget.metier);
    final nomTable = AttributConfigMobileService.configTableForMobileTable(
      nomMetier,
      _tableName,
    );
    if (nomMetier.isEmpty || nomTable.isEmpty) return;

    try {
      final choices = await SrmFieldOptionService().getOptionsByField(
        tableSchema: nomMetier,
        tableName: nomTable,
        fieldNames: const ['type_anomalie'],
      );
      _polygonStatusChoicesByField
        ..clear()
        ..addAll(choices);
    } catch (e) {
      debugPrint('Options statut polygone indisponibles: $e');
    }
  }

  Future<void> _populateRegardEpSpatialContext() async {
    final db = DatabaseHelper();
    Map<String, dynamic>? commune = await db.findCommuneLocalByPoint(
      x: _xMerchich,
      y: _yMerchich,
    );

    if (commune == null) {
      try {
        await CommuneSyncService(databaseHelper: db).refreshCommunes();
        commune = await db.findCommuneLocalByPoint(
          x: _xMerchich,
          y: _yMerchich,
        );
      } catch (e) {
        debugPrint('Communes locales indisponibles: $e');
      }
    }

    _regardEpCommuneName = commune?['nom_commune']?.toString().trim() ?? '';
    _regardEpProvinceName = commune?['nom_province']?.toString().trim() ?? '';

    if (commune == null) return;

    final communeName = _regardEpCommuneName;
    if (communeName.isNotEmpty) {
      _setRegardEpControllerIfEmpty('ep_sect_com', communeName);
      _setRegardEpControllerIfEmpty('sec_com', communeName);
      _setRegardEpControllerIfEmpty('sect_hydr', communeName);
      _setRegardEpControllerIfEmpty('zone', communeName);
    }

    final idCommune = commune['id_commune'];
    if (idCommune != null) {
      _setRegardEpControllerIfEmpty('id_commune', idCommune.toString());
    }

    final idProvince = commune['id_province'];
    if (idProvince != null) {
      _setRegardEpControllerIfEmpty('id_province', idProvince.toString());
    }
  }

  void _applyRegardEpDerivedValues(DateTime now) {
    _setRegardEpControllerIfEmpty('ep_agent', 'ETAFAT');
    _setRegardEpControllerIfEmpty('ep_agent_crea', 'ETAFAT');
    _setRegardEpControllerIfEmpty('ep_date_insertion', _formatDateOnly(now));
    _setRegardEpControllerIfEmpty('ep_coor_x', _xMerchich.toStringAsFixed(3));
    _setRegardEpControllerIfEmpty('ep_coor_y', _yMerchich.toStringAsFixed(3));
    _setRegardEpControllerIfEmpty(
        'id_user_creat', ApiService.userId?.toString() ?? '');
    _setRegardEpControllerIfEmpty('date_creation', now.toIso8601String());
    _syncRegardEpAdresseFromRefRue();
  }

  void _setRegardEpControllerIfEmpty(String field, String value) {
    if (value.trim().isEmpty) return;
    final controller = _regardEpControllers[field];
    if (controller == null) return;
    if (controller.text.trim().isEmpty) {
      controller.text = value;
    }
  }

  void _syncRegardEpAdresseFromRefRue() {
    final addressController = _regardEpControllers['ep_adresse'];
    final refRueController = _regardEpControllers['ep_ref_rue'];
    if (addressController == null || refRueController == null) return;

    final refRue = refRueController.text.trim();
    if (addressController.text != refRue) {
      addressController.text = refRue;
    }
  }

  String _resolveRegardEpInitialValue(String field, DateTime now) {
    final existing = widget.existingData?[field];
    if (existing != null) {
      return _stringifyRegardEpValue(field, existing);
    }

    final configDefault = _regardEpConfiguredDefaultValueForField(field);
    if (configDefault.trim().isNotEmpty) {
      return configDefault.trim();
    }

    switch (field) {
      case 'ep_agent':
      case 'ep_agent_crea':
        return 'ETAFAT';
      case 'ep_date_insertion':
        return _formatDateOnly(now);
      case 'ep_coor_x':
        return _xMerchich.toStringAsFixed(3);
      case 'ep_coor_y':
        return _yMerchich.toStringAsFixed(3);
      case 'id_user_creat':
        return ApiService.userId?.toString() ?? '';
      case 'date_creation':
        return now.toIso8601String();
      case 'is_deleted':
      case 'is_validated':
      case 'ep_anomalie':
        return '0';
      case 'mode_localisation':
        return _defaultModeLocalisationCode() ?? '';
      default:
        return '';
    }
  }

  String _regardEpConfiguredDefaultValueForField(String field) {
    final defaultValue =
        _regardEpConfigForField(field)?.valeurParDefaut.trim() ?? '';
    if (defaultValue.isEmpty) return '';

    final options = _regardEpOptions[field] ?? const <SrmFieldChoice>[];
    if (options.isNotEmpty &&
        !options.any((choice) => choice.code == defaultValue)) {
      return '';
    }
    return defaultValue;
  }

  AttributConfigMobileField? _regardEpConfigForField(String field) {
    final direct = _regardEpConfigByField[field];
    if (direct != null) return direct;
    final normalized = field.trim().toLowerCase();
    final lower = _regardEpConfigByField[normalized];
    if (lower != null) return lower;
    for (final entry in _regardEpConfigByField.entries) {
      if (entry.key.trim().toLowerCase() == normalized) {
        return entry.value;
      }
    }
    return null;
  }

  bool _isRegardEpConfiguredVisibleField(String field) {
    final config = _regardEpConfigForField(field);
    return config == null || config.visible || config.isAutoVisibleCoordinate;
  }

  String _stringifyRegardEpValue(String field, dynamic value) {
    if (value == null) return '';
    if (_isRegardEpBooleanField(field)) {
      final text = value.toString().trim().toLowerCase();
      if (value == true || text == 'true' || text == '1') {
        return '1';
      }
      return '0';
    }
    return value.toString();
  }

  String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _isRegardEpBooleanField(String field) {
    final type = _regardEpConfigByField[field]?.typeChamp.toLowerCase() ?? '';
    if (type.contains('bool')) return true;
    return field == 'ep_anomalie' ||
        field == 'is_deleted' ||
        field == 'is_validated';
  }

  bool _isRegardEpReadOnlyField(String field) {
    return _isLocked ||
        _isObjetIncomplet ||
        SrmConfig.getReadOnlyFields(widget.metier, widget.entityType)
            .contains(field);
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
    if (existingId == null) return;

    final linked = await DatabaseHelper().getOpenObjetIncompletForEntity(
      tableName: _tableName,
      idObjet: existingId,
    );
    if (!mounted || linked == null) return;

    _raisonIncomplet ??= linked['raison']?.toString();
    if (_detailRaisonController.text.trim().isEmpty) {
      _detailRaisonController.text = linked['detail_raison']?.toString() ?? '';
    }
  }

  bool _isRegardEpAnomalieActive() {
    final value = _regardEpControllers['ep_anomalie']?.text.trim() ?? '';
    return value == '1' || value.toLowerCase() == 'true';
  }

  bool _isRegardEpAnomalieDetailField(String field) {
    return field == 'anomalie_tamp' ||
        field == 'anomalie_regard' ||
        field == 'type_anomalie';
  }

  bool _shouldRelaxRegardEpRequiredField(String field) {
    return _isRegardEpAnomalieActive() &&
        !_isObjetIncomplet &&
        field != 'ep_anomalie' &&
        !_isRegardEpAnomalieDetailField(field);
  }

  String? _defaultRegardEpOptionCode(
    String field, {
    String? preferredLabel,
    Iterable<String> preferredLabels = const <String>[],
  }) {
    final options = _regardEpOptions[field] ?? const <SrmFieldChoice>[];
    if (options.isEmpty) return null;

    final requestedLabels = <String>[
      if (preferredLabel != null && preferredLabel.trim().isNotEmpty)
        preferredLabel.trim(),
      ...preferredLabels
          .where((label) => label.trim().isNotEmpty)
          .map((label) => label.trim()),
    ];

    if (requestedLabels.isNotEmpty) {
      final normalizedTargets = requestedLabels
          .map(_normalizeRegardEpLookupText)
          .where((value) => value.isNotEmpty)
          .toSet();

      for (final option in options) {
        final label = _normalizeRegardEpLookupText(option.label);
        if (normalizedTargets.contains(label) && option.code.isNotEmpty) {
          return option.code;
        }
      }
    }

    final firstCode = options.first.code.trim();
    return firstCode.isEmpty ? null : firstCode;
  }

  String? _defaultModeLocalisationCode() {
    return _defaultRegardEpOptionCode(
      'mode_localisation',
      preferredLabels: const <String>[
        'Leve topographique',
        'Lev\u00e9 topographique',
      ],
    );
  }

  String _resolveRegardEpOptionLabel(String field, String code) {
    final options = _regardEpOptions[field] ?? const <SrmFieldChoice>[];
    for (final option in options) {
      if (option.code == code) {
        final label = option.label.trim();
        return label.isEmpty ? code : label;
      }
    }
    return code;
  }

  String _normalizeRegardEpLookupText(String value) {
    var normalized = value.trim().toLowerCase();
    const replacements = <String, String>{
      '\u00e0': 'a',
      '\u00e2': 'a',
      '\u00e4': 'a',
      '\u00e7': 'c',
      '\u00e9': 'e',
      '\u00e8': 'e',
      '\u00ea': 'e',
      '\u00eb': 'e',
      '\u00ee': 'i',
      '\u00ef': 'i',
      '\u00f4': 'o',
      '\u00f6': 'o',
      '\u00f9': 'u',
      '\u00fb': 'u',
      '\u00fc': 'u',
      '\u00ff': 'y',
      '\u0153': 'oe',
      '\u00e6': 'ae',
    };
    replacements.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return normalized;
  }

  dynamic _normalizeRegardEpFieldValue(String field, String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;

    if (_isRegardEpBooleanField(field)) {
      return (normalized == '1' || normalized.toLowerCase() == 'true') ? 1 : 0;
    }

    final rule = _regardEpFieldRule(field);
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

  void _setupAutoCapitalize() {
    final textControllers = [
      _nomController,
      _codeGpsController,
    ];
    for (var ctrl in textControllers) {
      ctrl.addListener(() {
        final text = ctrl.text;
        if (text.isEmpty) return;
        final corrected =
            text[0].toUpperCase() + text.substring(1).toLowerCase();
        if (text != corrected) {
          final pos = ctrl.selection;
          ctrl.value = ctrl.value.copyWith(
            text: corrected,
            selection: pos,
          );
        }
      });
    }
  }

  double _calculateAreaHectares(List<LatLng> points) {
    if (points.length < 3) return 0.0;
    final refLat = points.first.latitude;
    final refLng = points.first.longitude;
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng = 111320.0 * cos(refLat * pi / 180);

    List<List<double>> meterPoints = points.map((p) {
      return [
        (p.longitude - refLng) * metersPerDegreeLng,
        (p.latitude - refLat) * metersPerDegreeLat,
      ];
    }).toList();

    double area = 0.0;
    for (int i = 0; i < meterPoints.length; i++) {
      int j = (i + 1) % meterPoints.length;
      area += meterPoints[i][0] * meterPoints[j][1];
      area -= meterPoints[j][0] * meterPoints[i][1];
    }
    return (area.abs() / 2.0) / 10000.0;
  }

  String _formatDisplayDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.day.toString().padLeft(2, '0')}/"
          "${date.month.toString().padLeft(2, '0')}/"
          "${date.year} "
          "${date.hour.toString().padLeft(2, '0')}:"
          "${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateString;
    }
  }

  String _formatRegardEpDisplayValue(String field, String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return normalized;

    switch (field) {
      case 'date_creation':
      case 'date_modif':
        return _formatDisplayDate(normalized);
      case 'ep_date_insertion':
        final formatted = _formatDisplayDate(normalized);
        return formatted.endsWith(' 00:00')
            ? formatted.substring(0, formatted.length - 6)
            : formatted;
      default:
        return normalized;
    }
  }

  // ==================================================================
  // ===================== SAUVEGARDE =====================
  // ==================================================================
  Future<void> _handleSave() async {
    if (_isLocked) return;
    setState(() => _isSaving = true);

    if (_superficieHa < 0.0001) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Polygone invalide : surface trop faible ou points trop proches.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    if (_isObjetIncomplet && _raisonIncomplet == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Veuillez sélectionner une raison pour l\'objet incomplet.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    if (!_isObjetIncomplet && !(_formKey.currentState?.validate() ?? true)) {
      setState(() => _isSaving = false);
      return;
    }

    try {
      final now = DateTime.now();
      final dbHelper = DatabaseHelper();

      if (_isRegardEp) {
        final currentModeLocalisation =
            _regardEpControllers['mode_localisation']?.text.trim() ?? '';
        final modeLocalisationCode = currentModeLocalisation.isNotEmpty
            ? currentModeLocalisation
            : _defaultModeLocalisationCode();
        final fields = _regardEpConfigByField.isNotEmpty
            ? _regardEpConfigByField.keys.toList()
            : SrmConfig.getFields(widget.metier, widget.entityType);
        final regardAnomalieActive =
            !_isObjetIncomplet && _isRegardEpAnomalieActive();

        final data = <String, dynamic>{
          'uuid': _regardEpUuid,
          'points_json': jsonEncode(_closedCoordinates),
          'nb_points': _polygonPoints.length,
          'ep_coor_x': double.tryParse(_xMerchich.toStringAsFixed(3)),
          'ep_coor_y': double.tryParse(_yMerchich.toStringAsFixed(3)),
          'id_agent_crea':
              widget.existingData?['id_agent_crea'] ?? ApiService.userId,
          'anomalie': regardAnomalieActive ? 1 : 0,
          'type_anomalie': regardAnomalieActive ? _typeAnomalie : null,
          'objet_incomplet': _isObjetIncomplet ? 1 : 0,
          'synced': 0,
          'date_collecte':
              widget.existingData?['date_collecte'] ?? now.toIso8601String(),
        };

        if (modeLocalisationCode != null && modeLocalisationCode.isNotEmpty) {
          data['mode_localisation'] = modeLocalisationCode;
        }

        for (final field in fields) {
          final controller = _regardEpControllers[field];
          if (controller == null) continue;

          final normalized =
              _normalizeRegardEpFieldValue(field, controller.text.trim());
          if (normalized != null) {
            data[field] = normalized;
          }
        }

        if (!regardAnomalieActive) {
          data['ep_anomalie'] = 0;
          data['type_anomalie'] = null;
          data['anomalie_tamp'] = null;
          data['anomalie_regard'] = null;
        }

        if ((data['ep_adresse'] == null ||
                data['ep_adresse'].toString().trim().isEmpty) &&
            data['ep_ref_rue'] != null &&
            data['ep_ref_rue'].toString().trim().isNotEmpty) {
          data['ep_adresse'] = data['ep_ref_rue'];
        }

        if ((data['sec_com'] == null ||
                data['sec_com'].toString().trim().isEmpty) &&
            data['ep_sect_com'] != null &&
            data['ep_sect_com'].toString().trim().isNotEmpty) {
          data['sec_com'] = data['ep_sect_com'];
        }

        if (_isEditing) {
          data['id_user_modif'] = ApiService.userId;
          data['date_modif'] = now.toIso8601String();
        } else {
          data['id_user_creat'] ??= ApiService.userId;
          data['date_creation'] ??= now.toIso8601String();
          data['ep_date_insertion'] ??= _formatDateOnly(now);
        }

        // Champs invisibles : remplissage automatique depuis valeur_par_defaut
        // configurée côté serveur (n'écrase jamais une valeur déjà résolue).
        // Pour les invisibles NOT NULL sans valeur_par_defaut, injection d'une
        // sentinelle typée pour éviter une violation NOT NULL côté serveur.
        for (final entry in _regardEpConfigByField.entries) {
          final field = entry.key;
          final config = entry.value;
          if (config.visible) continue;
          if (config.primaryKey) continue;
          if (field.toLowerCase() == 'geom') continue;
          if (data.containsKey(field) && data[field] != null) continue;
          final defaultValue = config.valeurParDefaut.trim();
          if (defaultValue.isNotEmpty) {
            final normalized =
                _normalizeRegardEpFieldValue(field, defaultValue);
            if (normalized != null) {
              data[field] = normalized;
            }
          } else if (!config.nullable) {
            data[field] = config.fallbackValueForInvisibleNotNull;
          }
        }

        late final int localId;
        if (_isEditing) {
          final existingId = widget.existingData!['id'] is int
              ? widget.existingData!['id'] as int
              : int.tryParse(widget.existingData!['id'].toString());
          if (existingId == null) {
            throw Exception('Identifiant local invalide pour la mise à jour');
          }
          localId = existingId;

          await dbHelper.updateEntitySrm(
            _tableName,
            existingId,
            data,
            recordHistory: true,
          );
        } else {
          localId = await dbHelper.insertEntitySrm(
            _tableName,
            data,
            recordHistory: true,
          );
        }
        if (_isObjetIncomplet) {
          await dbHelper.upsertObjetIncompletForEntity(
            tableName: _tableName,
            idObjet: localId,
            metierCode: _metierCode,
            raison: _raisonIncomplet,
            detailRaison: _detailRaisonController.text.trim(),
          );
        } else {
          await dbHelper.resolveObjetIncompletForEntity(
            tableName: _tableName,
            idObjet: localId,
          );
        }

        final uuidObjet = data['uuid']?.toString().trim() ?? '';
        if (_hasAnomalie && !_isObjetIncomplet && uuidObjet.isNotEmpty) {
          await dbHelper.upsertLocalInterventionAnomalieSignalement(
            schemaName: _metierCode.toLowerCase(),
            tableName: _tableName,
            idObjet: localId,
            uuidObjet: uuidObjet,
            rowData: data,
          );
        } else {
          await dbHelper.resolveLocalInterventionAnomalieSignalement(
            schemaName: _metierCode.toLowerCase(),
            tableName: _tableName,
            idObjet: localId,
            uuidObjet: uuidObjet,
          );
        }

        if (mounted) {
          await clearDraftAfterSave();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$_pageTitle enregistré localement (${_superficieHa.toStringAsFixed(4)} ha)',
              ),
              backgroundColor: _categoryColor,
            ),
          );
          Navigator.of(context).pop(true);
        }
        return;
      }

      final data = <String, dynamic>{
        'uuid': widget.existingData?['uuid'] ?? const Uuid().v4(),
        'nom': _nomController.text.trim().isEmpty
            ? null
            : _nomController.text.trim(),
        'code': _codeGpsController.text.trim().isEmpty
            ? null
            : _codeGpsController.text.trim(),
        'ep_num': _epNumController.text.trim().isEmpty
            ? null
            : _epNumController.text.trim(),
        'ep_type': _epTypeController.text.trim().isEmpty
            ? null
            : _epTypeController.text.trim(),
        'ep_forme': _epFormeController.text.trim().isEmpty
            ? null
            : _epFormeController.text.trim(),
        'ep_longueur': _epLongueurController.text.trim().isEmpty
            ? null
            : _epLongueurController.text.trim(),
        'ep_largeur': _epLargeurController.text.trim().isEmpty
            ? null
            : _epLargeurController.text.trim(),
        'ep_cote_tampon': _epCoteTamponController.text.trim().isEmpty
            ? null
            : _epCoteTamponController.text.trim(),
        'ep_cote_radier': _epCoteRadierController.text.trim().isEmpty
            ? null
            : _epCoteRadierController.text.trim(),
        'ep_cote_fil_eau': _epCoteFilEauController.text.trim().isEmpty
            ? null
            : _epCoteFilEauController.text.trim(),
        'ep_etat': _epEtatController.text.trim().isEmpty
            ? null
            : _epEtatController.text.trim(),
        'emplacement': _emplacementController.text.trim().isEmpty
            ? null
            : _emplacementController.text.trim(),
        'ref_rue': _refRueController.text.trim().isEmpty
            ? null
            : _refRueController.text.trim(),
        'etage_aqua': _etageAquaController.text.trim().isEmpty
            ? null
            : _etageAquaController.text.trim(),
        'secteur_aqua': _secteurAquaController.text.trim().isEmpty
            ? null
            : _secteurAquaController.text.trim(),
        'observation': _observationController.text.trim().isEmpty
            ? null
            : _observationController.text.trim(),
        'ep_coor_x': _xMerchich,
        'ep_coor_y': _yMerchich,
        'points_json': jsonEncode(_closedCoordinates),
        'superficie_ha': _superficieHa,
        'nb_points': _polygonPoints.length,
        'anomalie': _hasAnomalie ? 1 : 0,
        'type_anomalie': _hasAnomalie ? _typeAnomalie : null,
        'objet_incomplet': _isObjetIncomplet ? 1 : 0,
        'id_agent_crea': ApiService.userId,
        'mode_localisation': 'gnss',
        'synced': 0,
        'date_collecte': now.toIso8601String(),
      };

      late final int localId;
      if (_isEditing) {
        final existingId = widget.existingData!['id'] is int
            ? widget.existingData!['id'] as int
            : int.tryParse(widget.existingData!['id'].toString());
        if (existingId == null) {
          throw Exception('Identifiant local invalide pour la mise à jour');
        }
        localId = existingId;

        await dbHelper.updateEntitySrm(
          _tableName,
          existingId,
          data,
          recordHistory: true,
        );
      } else {
        localId = await dbHelper.insertEntitySrm(
          _tableName,
          data,
          recordHistory: true,
        );
      }

      if (_isObjetIncomplet) {
        await dbHelper.upsertObjetIncompletForEntity(
          tableName: _tableName,
          idObjet: localId,
          metierCode: _metierCode,
          raison: _raisonIncomplet,
          detailRaison: _detailRaisonController.text.trim(),
        );
      } else {
        await dbHelper.resolveObjetIncompletForEntity(
          tableName: _tableName,
          idObjet: localId,
        );
      }

      final uuidObjet = data['uuid']?.toString().trim() ?? '';
      if (_hasAnomalie && !_isObjetIncomplet && uuidObjet.isNotEmpty) {
        await dbHelper.upsertLocalInterventionAnomalieSignalement(
          schemaName: _metierCode.toLowerCase(),
          tableName: _tableName,
          idObjet: localId,
          uuidObjet: uuidObjet,
          rowData: data,
        );
      } else {
        await dbHelper.resolveLocalInterventionAnomalieSignalement(
          schemaName: _metierCode.toLowerCase(),
          tableName: _tableName,
          idObjet: localId,
          uuidObjet: uuidObjet,
        );
      }

      if (mounted) {
        await clearDraftAfterSave();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$_pageTitle enregistré avec succès (${_superficieHa.toStringAsFixed(4)} ha)',
            ),
            backgroundColor: _categoryColor,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde polygone: $e');
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

  void _clearForm() {
    if (_isLocked) return;
    if (_isRegardEp) {
      final now = DateTime.now();
      _regardEpUuid = const Uuid().v4();
      setState(() {
        _regardEpCommuneName = '';
        _regardEpProvinceName = '';
        _hasAnomalie = false;
        _typeAnomalie = null;
        _isObjetIncomplet = false;
        _raisonIncomplet = null;
        _detailRaisonController.clear();
        for (final field in _regardEpControllers.keys) {
          _regardEpControllers[field]!.text =
              _resolveRegardEpInitialValue(field, now);
        }
      });
      _populateRegardEpSpatialContext().then((_) {
        if (!mounted) return;
        _applyRegardEpDerivedValues(now);
        setState(() {});
      });
      return;
    }

    setState(() {
      _nomController.clear();
      _codeGpsController.clear();
      _hasAnomalie = false;
      _typeAnomalie = null;
      _isObjetIncomplet = false;
      _raisonIncomplet = null;
      _detailRaisonController.clear();
    });
  }

  Future<void> _handleBack() async {
    // Sauvegarder le brouillon avant de quitter le formulaire
    if (!_isEditing) await saveDraftBeforeExit();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Abandonner la saisie ?"),
        content: const Text("Les données non sauvegardées seront perdues."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Abandonner"),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // Build principal du formulaire polygone
  // ==================================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F8FF),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _categoryColor),
              const SizedBox(height: 20),
              Text('Préparation du formulaire...',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final dateCreation = _isEditing
        ? (widget.existingData!['date_creation']?.toString() ??
            DateTime.now().toIso8601String())
        : DateTime.now().toIso8601String();
    final formSections = <Widget>[
      if (_isRegardEp)
        ..._buildRegardEpSections()
      else ...[
        _buildFormSection(
          title: 'Attributs $_pageTitle',
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _categoryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: _categoryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Centroïde Merchich Nord',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _categoryColor,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'X: ${_xMerchich.toStringAsFixed(3)} m  '
                    'Y: ${_yMerchich.toStringAsFixed(3)} m',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Superficie: ${_superficieHa.toStringAsFixed(4)} ha  '
                    '(${(_superficieHa * 10000).toStringAsFixed(1)} m²)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            if (widget.entityType == 'Regard EP') ...[
              for (final field
                  in SrmConfig.getFields(widget.metier, widget.entityType))
                _buildRegardEpField(field),
            ],
          ],
        ),
      ],
      _buildFormSection(
        title: 'Identification',
        children: [
          _buildTextField(
            label: 'Nom',
            hint: 'Nom de la zone (optionnel)',
            controller: _nomController,
          ),
          _buildTextField(
            label: 'Code GPS',
            hint: 'Code GPS optionnel',
            controller: _codeGpsController,
          ),
          _buildDateField(
            label: 'Date de création *',
            value: dateCreation,
            readOnly: true,
          ),
          _buildDateModificationField(),
        ],
      ),
      if (!_isRegardEp) ...[
        _buildFormSection(
          title: 'Géométrie du polygone',
          children: [
            _buildPolygonGpsInfo(),
          ],
        ),
        _buildFormSection(
          title: 'Coordonnées des sommets',
          children: [
            for (int i = 0; i < _polygonPoints.length; i++)
              _buildGpsInfoRow(
                'Sommet ${i + 1}:',
                '${_polygonPoints[i].latitude.toStringAsFixed(7)}, '
                    '${_polygonPoints[i].longitude.toStringAsFixed(7)}',
              ),
          ],
        ),
        _buildFormSection(
          title: 'Géolocalisation',
          children: [
            _buildReadOnlyAgentField(),
          ],
        ),
        _buildAnomalieStatusSection(),
        const SizedBox(height: 120),
      ],
    ];

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (!_isEditing) await saveDraftBeforeExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F8FF),
        body: SafeArea(
          child: Column(
            children: [
              // ===== Header =====
              Container(
                decoration: BoxDecoration(
                  color: _isLocked
                      ? Colors.grey.shade700
                      : (_isObjetIncomplet ? Colors.orange : _categoryColor),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _handleBack,
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 24),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            _pageTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Table: $_tableName',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Colors.white.withAlpha((0.9 * 255).round()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _clearForm,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Effacer'),
                    ),
                  ],
                ),
              ),

              // ===== CONTENU DU FORMULAIRE =====
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: formSections,
                  ),
                ),
              ),

              // ===== Bouton enregistrer =====
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, -2)),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isObjetIncomplet ? Colors.orange : _categoryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isObjetIncomplet
                                    ? Icons.warning_amber_rounded
                                    : Icons.save,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isObjetIncomplet
                                    ? 'Signaler incomplet'
                                    : 'Enregistrer',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================================
  // Widgets secondaires du formulaire
  // ==================================================================

  List<Widget> _buildRegardEpSections() {
    final communeId = _regardEpControllers['id_commune']?.text.trim() ?? '';
    final provinceId = _regardEpControllers['id_province']?.text.trim() ?? '';
    final visibleFields = _regardEpVisibleFields.isNotEmpty
        ? _regardEpVisibleFields
        : SrmConfig.getFields(widget.metier, widget.entityType);

    return [
      _buildFormSection(
        title: 'Contexte spatial',
        children: [
          _buildRegardEpStaticField(
            'Commune',
            _regardEpCommuneName,
            helperText: communeId.isNotEmpty ? 'ID commune: $communeId' : null,
          ),
          _buildRegardEpStaticField(
            'Province',
            _regardEpProvinceName,
            helperText:
                provinceId.isNotEmpty ? 'ID province: $provinceId' : null,
          ),
        ],
      ),
      _buildFormSection(
        title: 'G\u00E9om\u00E9trie',
        children: [
          _buildRegardEpGeometrySummaryField(),
        ],
      ),
      _buildFormSection(
        title: 'Attributs',
        children: [
          for (final field in visibleFields)
            if (_shouldRenderRegardEpField(field)) _buildRegardEpField(field),
        ],
      ),
    ];
  }

  bool _shouldRenderRegardEpField(String field) {
    if (!_regardEpControllers.containsKey(field)) return false;
    if (field == 'geom' || field == 'uuid' || field == 'points_json') {
      return false;
    }
    if (field == 'id_commune' || field == 'id_province') {
      return false;
    }
    if (!_isRegardEpAnomalieActive() &&
        (field == 'anomalie_tamp' ||
            field == 'anomalie_regard' ||
            field == 'type_anomalie')) {
      return false;
    }
    return true;
  }

  Widget _buildRegardEpStaticField(
    String label,
    String value, {
    String? helperText,
    bool isRequired = false,
  }) {
    final displayValue =
        value.trim().isEmpty ? 'Non d\u00E9termin\u00E9' : value.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requiredLabel(label, isRequired),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
                if (helperText != null && helperText.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    helperText.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegardEpGeometrySummaryField() {
    return Column(
      children: [
        _buildPolygonGpsInfo(),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3F2FD)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.route, size: 20, color: Color(0xFF1976D2)),
                  SizedBox(width: 8),
                  Text(
                    'Coordonn\u00E9es des sommets',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1976D2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < _polygonPoints.length; i++)
                _buildGpsInfoRow(
                  'Sommet ${i + 1}:',
                  '${_polygonPoints[i].latitude.toStringAsFixed(7)}, ${_polygonPoints[i].longitude.toStringAsFixed(7)}',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(
      {required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE3F2FD))),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1976D2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  String _labelForRegardEpField(String field) {
    final config = _regardEpConfigByField[field];
    if (config != null && config.label.trim().isNotEmpty) {
      return config.label.trim();
    }
    return SrmConfig.getFieldLabel(widget.metier, widget.entityType, field);
  }

  TextStyle get _fieldLabelStyle => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      );

  Widget _requiredLabel(String label, bool isRequired) {
    if (!isRequired) {
      return Text(label, style: _fieldLabelStyle);
    }
    return RichText(
      text: TextSpan(
        text: label,
        style: _fieldLabelStyle,
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegardEpField(String field) {
    final controller = _regardEpControllers[field];
    if (controller == null) return const SizedBox.shrink();

    final label = _labelForRegardEpField(field);
    final options = _regardEpOptions[field] ?? const <SrmFieldChoice>[];
    final isReadOnly = _isRegardEpReadOnlyField(field);
    final isRequired = !_isObjetIncomplet &&
        _regardEpRequiredFields.contains(field) &&
        !_shouldRelaxRegardEpRequiredField(field);
    final rule =
        SrmConfig.getFieldRule(widget.metier, widget.entityType, field);

    if (_isRegardEpBooleanField(field)) {
      final boolValue = controller.text.trim() == '1';
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: SwitchListTile(
          title: _requiredLabel(label, isRequired),
          value: boolValue,
          onChanged: isReadOnly
              ? null
              : (value) {
                  setState(() {
                    controller.text = value ? '1' : '0';
                    if (field == 'ep_anomalie' && !value) {
                      _regardEpControllers['anomalie_tamp']?.clear();
                      _regardEpControllers['anomalie_regard']?.clear();
                    }
                  });
                  onFieldChanged();
                },
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      );
    }

    if (options.isNotEmpty) {
      if (isReadOnly) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _requiredLabel(label, isRequired),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Text(
                  _resolveRegardEpOptionLabel(field, controller.text.trim()),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      final currentValue = controller.text.trim();
      final seenValues = <String>{};
      final items = <DropdownMenuItem<String>>[_kEmptyChoiceMenuItem];
      for (final option in options) {
        if (!seenValues.add(option.code)) continue;
        items.add(
          DropdownMenuItem<String>(
            value: option.code,
            child: Text(option.label),
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

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _requiredLabel(label, isRequired),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: currentValue.isEmpty ? null : currentValue,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1976D2)),
                ),
              ),
              items: items,
              onChanged: (value) {
                controller.text = value ?? '';
                onFieldChanged();
              },
              validator: (value) =>
                  _validateRegardEpField(field, value, isRequired, rule),
            ),
          ],
        ),
      );
    }

    if (isReadOnly) {
      return _buildRegardEpStaticField(
        label,
        _formatRegardEpDisplayValue(field, controller.text),
        isRequired: isRequired,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _requiredLabel(label, isRequired),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: !isReadOnly,
            readOnly: isReadOnly,
            keyboardType: _keyboardTypeForRegardEpRule(rule),
            inputFormatters: _inputFormattersForRegardEpRule(rule),
            maxLength: rule.maxLength,
            maxLines: rule.multiline ? 3 : 1,
            validator: (value) =>
                _validateRegardEpField(field, value, isRequired, rule),
            decoration: InputDecoration(
              hintText: _hintForRegardEpField(field),
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: isReadOnly
                  ? const Color(0xFFF5F5F5)
                  : const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1976D2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextInputType _keyboardTypeForRegardEpRule(SrmFieldRule rule) {
    switch (rule.kind) {
      case SrmFieldKind.integer:
        return TextInputType.number;
      case SrmFieldKind.decimal:
        return const TextInputType.numberWithOptions(
            decimal: true, signed: true);
      case SrmFieldKind.date:
        return TextInputType.datetime;
      default:
        return TextInputType.text;
    }
  }

  SrmFieldRule _regardEpFieldRule(String field) {
    final fallback = SrmConfig.getFieldRule(
      widget.metier,
      widget.entityType,
      field,
    );
    final config = _regardEpConfigByField[field];
    if (config == null) return fallback;

    final type = config.typeChamp.toLowerCase();
    final configuredMaxLength = _configuredRegardEpTextMaxLength(type);
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

  int? _configuredRegardEpTextMaxLength(String type) {
    final match = RegExp(
      r'(?:character varying|varchar|character)\s*\((\d+)\)',
    ).firstMatch(type);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  List<TextInputFormatter> _inputFormattersForRegardEpRule(SrmFieldRule rule) {
    switch (rule.kind) {
      case SrmFieldKind.integer:
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))];
      case SrmFieldKind.decimal:
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\-]'))];
      case SrmFieldKind.date:
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9T:\-+.Z]'))];
      default:
        return const [];
    }
  }

  String? _validateRegardEpField(
    String field,
    String? value,
    bool isRequired,
    SrmFieldRule rule,
  ) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      if (_shouldRelaxRegardEpRequiredField(field)) return null;
      return isRequired || rule.required ? 'Champ requis' : null;
    }
    if (rule.maxLength != null && normalized.length > rule.maxLength!) {
      return 'Maximum ${rule.maxLength} caracteres';
    }

    switch (rule.kind) {
      case SrmFieldKind.integer:
        if (int.tryParse(normalized) == null) {
          return 'Nombre entier attendu';
        }
        break;
      case SrmFieldKind.decimal:
        if (double.tryParse(normalized.replaceAll(',', '.')) == null) {
          return 'Nombre decimal attendu';
        }
        break;
      case SrmFieldKind.date:
        if (DateTime.tryParse(normalized) == null) {
          return 'Date invalide';
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
          return 'Valeur non autorisee';
        }
        break;
      case SrmFieldKind.booleanLike:
      case SrmFieldKind.text:
        break;
    }

    final rangeError = _validateRegardEpConfiguredRange(
      field,
      normalized,
      rule,
    );
    if (rangeError != null) return rangeError;

    return null;
  }

  String? _validateRegardEpConfiguredRange(
    String field,
    String normalized,
    SrmFieldRule rule,
  ) {
    final config = _regardEpConfigByField[field];
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

  String _hintForRegardEpField(String field) {
    switch (field) {
      case 'z_radier':
      case 'z_surf':
        return 'Valeur libre';
      case 'ep_profondeur':
      case 'GENRATRICE_SUP':
      case 'ep_coor_z':
        return '0.000';
      case 'id_commune':
      case 'id_province':
      case 'id_user_creat':
      case 'id_user_modif':
      case 'id_user_valid':
        return 'Identifiant numerique';
      case 'date_creation':
      case 'date_modif':
      case 'date_validation':
        return 'YYYY-MM-DDTHH:MM:SS';
      case 'ep_date_insertion':
        return 'YYYY-MM-DD';
      default:
        return '';
    }
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    final effectiveEnabled = enabled && !_isLocked && !_isObjetIncomplet;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: effectiveEnabled,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: effectiveEnabled
                  ? const Color(0xFFF9FAFB)
                  : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1976D2))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required String value,
    bool readOnly = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151))),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 20, color: Color(0xFF1976D2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatDisplayDate(value),
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                  ),
                ),
              ],
            ),
          ),
          if (readOnly)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Date automatique (non modifiable)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
            ),
        ],
      ),
    );
  }

  // ===== Date de modification =====
  Widget _buildDateModificationField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date de modification',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _isEditing ? const Color(0xFF374151) : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: _isEditing
                  ? const Color(0xFFF9FAFB)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isEditing
                    ? const Color(0xFFE5E7EB)
                    : const Color(0xFFE0E0E0),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: _isEditing ? const Color(0xFF1976D2) : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEditing
                        ? 'Sera mise à jour automatiquement'
                        : 'Non modifiée',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isEditing
                          ? const Color(0xFF374151)
                          : const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== Info polygone =====
  Widget _buildPolygonGpsInfo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3F2FD)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pentagon, size: 20, color: Color(0xFF1976D2)),
              SizedBox(width: 8),
              Text(
                'Informations du polygone',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGpsInfoRow(
              'Nombre de sommets :', '${_polygonPoints.length} points'),
          _buildGpsInfoRow(
              'Superficie :', '${_superficieHa.toStringAsFixed(4)} ha'),
          _buildGpsInfoRow('Surface :',
              '${(_superficieHa * 10000).toStringAsFixed(1)} m\u00B2'),
        ],
      ),
    );
  }

  Widget _buildGpsInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyAgentField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.person, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Agent enqu\u00EAteur',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  widget.agentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolygonTypeAnomalieField() {
    final choices = _polygonStatusChoicesByField['type_anomalie'] ??
        const <SrmFieldChoice>[];
    if (choices.isEmpty) {
      return TextFormField(
        initialValue: _typeAnomalie,
        decoration: _statusDecoration('Type d\'anomalie'),
        maxLength: 254,
        onChanged: _isLocked
            ? null
            : (value) {
                final text = value.trim();
                _typeAnomalie = text.isEmpty ? null : text;
              },
      );
    }

    final currentValue = (_typeAnomalie ?? '').trim();
    final seenValues = <String>{};
    final items = <DropdownMenuItem<String>>[];
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

    return DropdownButtonFormField<String>(
      initialValue: currentValue.isEmpty ? null : currentValue,
      decoration: _statusDecoration('Type d\'anomalie'),
      hint: const Text('Selectionner'),
      isExpanded: true,
      items: items,
      onChanged:
          _isLocked ? null : (value) => setState(() => _typeAnomalie = value),
    );
  }

  Widget _buildAnomalieStatusSection() {
    return _buildFormSection(
      title: 'Statut de l\'objet',
      children: [
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
                    'Les valeurs deja saisies sont conservees.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        SwitchListTile(
          title: const Text(
            'Anomalie détectée',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          value: _hasAnomalie,
          activeThumbColor: Colors.red,
          contentPadding: EdgeInsets.zero,
          onChanged: (_isLocked || _isObjetIncomplet)
              ? null
              : (value) => setState(() {
                    _hasAnomalie = value;
                    if (!value) _typeAnomalie = null;
                  }),
        ),
        if (_hasAnomalie && !_isObjetIncomplet)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPolygonTypeAnomalieField(),
          ),
        if (!_isLocked) ...[
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
            contentPadding: EdgeInsets.zero,
            onChanged: (value) => setState(() {
              _isObjetIncomplet = value;
              if (!value) {
                _raisonIncomplet = null;
                _detailRaisonController.clear();
              }
              if (value) {
                _hasAnomalie = false;
                _regardEpControllers['ep_anomalie']?.text = '0';
              }
            }),
          ),
          if (_isObjetIncomplet) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _raisonIncomplet,
              decoration: _statusDecoration('Raison'),
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
                DropdownMenuItem(
                  value: 'DANGER',
                  child: Text('Danger sur site'),
                ),
                DropdownMenuItem(
                  value: 'AUTRE',
                  child: Text('Autre raison'),
                ),
              ],
              onChanged: (value) => setState(() => _raisonIncomplet = value),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _detailRaisonController,
              decoration:
                  _statusDecoration('Détail / commentaire (facultatif)'),
              maxLines: 2,
            ),
          ],
        ],
      ],
    );
  }

  InputDecoration _statusDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1976D2)),
      ),
    );
  }

  @override
  void dispose() {
    if (!_isEditing) disposeDraft();
    for (final controller in _regardEpControllers.values) {
      controller.dispose();
    }
    _nomController.dispose();
    _codeGpsController.dispose();
    _epNumController.dispose();
    _epTypeController.dispose();
    _epFormeController.dispose();
    _epLongueurController.dispose();
    _epLargeurController.dispose();
    _epCoteTamponController.dispose();
    _epCoteRadierController.dispose();
    _epCoteFilEauController.dispose();
    _epEtatController.dispose();
    _emplacementController.dispose();
    _refRueController.dispose();
    _etageAquaController.dispose();
    _secteurAquaController.dispose();
    _observationController.dispose();
    _detailRaisonController.dispose();
    super.dispose();
  }

  // ===== Brouillon automatique =====

  @override
  String get draftKey => DraftService.buildDraftKey(
        formType: 'polygon',
        metier: widget.metier,
        entityType: widget.entityType,
      );

  @override
  Map<String, String> collectFormData() {
    if (_isRegardEp) {
      return {
        for (final entry in _regardEpControllers.entries)
          entry.key: entry.value.text,
        '__detail_raison': _detailRaisonController.text,
      };
    }

    return {
      'nom': _nomController.text,
      'code': _codeGpsController.text,
      'ep_num': _epNumController.text,
      'ep_type': _epTypeController.text,
      'ep_forme': _epFormeController.text,
      'ep_longueur': _epLongueurController.text,
      'ep_largeur': _epLargeurController.text,
      'ep_cote_tampon': _epCoteTamponController.text,
      'ep_cote_radier': _epCoteRadierController.text,
      'ep_cote_fil_eau': _epCoteFilEauController.text,
      'ep_etat': _epEtatController.text,
      'emplacement': _emplacementController.text,
      'ref_rue': _refRueController.text,
      'etage_aqua': _etageAquaController.text,
      'secteur_aqua': _secteurAquaController.text,
      'observation': _observationController.text,
      '__detail_raison': _detailRaisonController.text,
    };
  }

  @override
  bool isDraftFieldMeaningful(String field, String value) {
    if (!super.isDraftFieldMeaningful(field, value)) return false;
    if (field == '__detail_raison') {
      return _isObjetIncomplet && value.trim().isNotEmpty;
    }

    if (_isRegardEp) {
      if (!_isRegardEpConfiguredVisibleField(field)) return false;
      if (_regardEpConfigForField(field) == null &&
          _regardEpConfigByField.isNotEmpty) {
        return false;
      }
      final defaultValue =
          _regardEpConfiguredDefaultValueForField(field).trim();
      return defaultValue.isEmpty || value.trim() != defaultValue;
    }

    return true;
  }

  @override
  Map<int, String?> collectPhotoPaths() => {};

  @override
  Map<String, dynamic> collectExtraState() => {
        'hasAnomalie': _hasAnomalie,
        'typeAnomalie': _typeAnomalie,
        'isObjetIncomplet': _isObjetIncomplet,
        'raisonIncomplet': _raisonIncomplet,
        'polygonPoints': _polygonPoints
            .map((p) => {
                  'lat': p.latitude,
                  'lng': p.longitude,
                })
            .toList(),
        if (_isRegardEp && _regardEpUuid.trim().isNotEmpty)
          'regardEpUuid': _regardEpUuid,
      };

  @override
  void restoreFormData(Map<String, String> data) {
    if (_isRegardEp) {
      for (final entry in data.entries) {
        if (entry.key == '__detail_raison') {
          _detailRaisonController.text = entry.value;
        } else if (_regardEpControllers.containsKey(entry.key)) {
          _regardEpControllers[entry.key]!.text = entry.value;
        }
      }
      return;
    }

    final mapping = <String, TextEditingController>{
      'nom': _nomController,
      'code': _codeGpsController,
      'code_gps': _codeGpsController,
      'ep_num': _epNumController,
      'ep_type': _epTypeController,
      'ep_forme': _epFormeController,
      'ep_longueur': _epLongueurController,
      'ep_largeur': _epLargeurController,
      'ep_cote_tampon': _epCoteTamponController,
      'ep_cote_radier': _epCoteRadierController,
      'ep_cote_fil_eau': _epCoteFilEauController,
      'ep_etat': _epEtatController,
      'emplacement': _emplacementController,
      'ref_rue': _refRueController,
      'etage_aqua': _etageAquaController,
      'secteur_aqua': _secteurAquaController,
      'observation': _observationController,
    };
    for (final entry in data.entries) {
      if (entry.key == '__detail_raison') {
        _detailRaisonController.text = entry.value;
      } else if (mapping.containsKey(entry.key)) {
        mapping[entry.key]!.text = entry.value;
      }
    }
  }

  @override
  void restorePhotoPaths(Map<int, String?> photos) {}

  @override
  void restoreExtraState(Map<String, dynamic> extra) {
    _hasAnomalie = extra['hasAnomalie'] == true;
    _typeAnomalie = extra['typeAnomalie'] as String?;
    _isObjetIncomplet = extra['isObjetIncomplet'] == true;
    _raisonIncomplet = extra['raisonIncomplet'] as String?;
    final restoredPoints = _decodeDraftPolygonPoints(extra['polygonPoints']);
    if (restoredPoints.length >= 3) {
      _polygonPoints = restoredPoints;
      _recomputePolygonGeometry();
    }
    final restoredUuid = extra['regardEpUuid']?.toString().trim() ?? '';
    if (restoredUuid.isNotEmpty) {
      _regardEpUuid = restoredUuid;
    }
  }
}
