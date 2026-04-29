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
import '../../services/photo_reference_service.dart';
import '../../services/photo_storage_service.dart';
import '../../services/photo_validation_service.dart';
import '../../services/projection_service.dart';

class SrmLigneFormPage extends StatefulWidget {
  final String metier;
  final String entityType;
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
  final Map<int, String?> _photoPaths = {1: null, 2: null};

  bool _hasAnomalie = false;
  String? _typeAnomalie;
  bool _isObjetIncomplet = false;
  String? _raisonIncomplet;
  bool _isSaving = false;
  bool _isLocked = false;

  late final List<String> _fields;
  late final List<String> _typeOptions;
  late final String? _typeField;
  late final int _maxPhotos;
  late final double _distanceTotaleM;

  late double _xDebut;
  late double _yDebut;
  late double _xFin;
  late double _yFin;

  Color get _metierColor => Color(SrmConfig.getMetierColor(widget.metier));
  String get _metierCode => widget.metier == 'Eau Potable'
      ? 'EP'
      : widget.metier == 'Assainissement'
          ? 'ASS'
          : 'ELEC';

  bool _isTruthyFlag(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value.toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 't';
  }

  List<LatLng> _decodeExistingLinePoints(dynamic rawPoints) {
    if (rawPoints == null) return const [];

    try {
      final decoded = rawPoints is String ? jsonDecode(rawPoints) : rawPoints;
      if (decoded is! List) {
        if (rawPoints is String) {
          return RegExp(
            r'lat:\s*([-0-9.]+),\s*lon:\s*([-0-9.]+)',
          ).allMatches(rawPoints).map((match) {
            final lat = double.tryParse(match.group(1) ?? '');
            final lon = double.tryParse(match.group(2) ?? '');
            if (lat == null || lon == null) return null;
            return LatLng(lat, lon);
          }).whereType<LatLng>().toList();
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
      ).allMatches(rawPoints).map((match) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lon = double.tryParse(match.group(2) ?? '');
        if (lat == null || lon == null) return null;
        return LatLng(lat, lon);
      }).whereType<LatLng>().toList();
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
    _typeOptions = SrmConfig.getTypeOptions(widget.metier, widget.entityType);
    _typeField = SrmConfig.getEntityConfig(
      widget.metier,
      widget.entityType,
    )?['typeField'] as String?;
    _maxPhotos = SrmConfig.getMaxPhotos(widget.metier, widget.entityType);
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
    _prefillCoordinates();

    if (widget.existingData != null) {
      _hasAnomalie = _isTruthyFlag(widget.existingData!['anomalie']) ||
          _isTruthyFlag(widget.existingData!['ep_anomalie']);
      _typeAnomalie = widget.existingData!['type_anomalie']?.toString();
      _isObjetIncomplet = _isTruthyFlag(widget.existingData!['objet_incomplet']);
      _raisonIncomplet = widget.existingData!['raison_incomplet']?.toString();
      _detailRaisonController.text =
          widget.existingData!['detail_raison_incomplet']?.toString() ?? '';
      for (int i = 1; i <= 2; i++) {
        _photoPaths[i] = widget.existingData!['photo_$i']?.toString();
      }
      _isLocked = FormLockService.isLocked(widget.existingData!);
      _restoreLinkedObjetIncompletDetails();
    }

    if (widget.existingData == null) {
      for (final c in _controllers.values) {
        c.addListener(onFieldChanged);
      }
      _detailRaisonController.addListener(onFieldChanged);
      initDraft();
    }
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

  Future<void> _pickPhoto(int index) async {
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
    setState(() => _photoPaths[index] = durablePath);
  }

  void _removePhoto(int index) => setState(() => _photoPaths[index] = null);

  Future<void> _save() async {
    if (_isLocked) return;
    if (!_isObjetIncomplet && !_formKey.currentState!.validate()) return;
    if (_isObjetIncomplet && _raisonIncomplet == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Veuillez sélectionner une raison pour l\'objet incomplet',
        ),
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

      if (!_isObjetIncomplet) {
        for (final field in _fields) {
          final val = _controllers[field]?.text.trim();
          if (val != null && val.isNotEmpty) {
            data[field] = _normalizeFieldValue(field, val);
          }
        }
      }

      data['points_json'] = jsonEncode(effectiveLinePoints
          .map((p) => {'lat': p.latitude, 'lon': p.longitude})
          .toList());
      data['nb_points'] = effectiveLinePoints.length;
      data['distance_m'] = _distanceTotaleM;

      if (widget.averageAltitude != null) {
        data['altitude_z_moy'] = widget.averageAltitude;
        final schema =
            SrmConfig.getEntityConfig(widget.metier, widget.entityType)?[
                    'schema'] ??
                '';
        data['${schema}_coor_z'] = widget.averageAltitude;
      }

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

      data['anomalie'] = _hasAnomalie ? 1 : 0;
      if (_hasAnomalie && _typeAnomalie != null) {
        data['type_anomalie'] = _typeAnomalie;
      }
      data['objet_incomplet'] = _isObjetIncomplet ? 1 : 0;

      for (int i = 1; i <= 2; i++) {
        data['photo_$i'] = _photoPaths[i];
      }

      data['id_projet'] = ApiService.currentProjetId;
      data['id_agent_crea'] = ApiService.userId;
      data['mode_localisation'] = 'gnss';
      data['synced'] = 0;
      data['date_collecte'] = DateTime.now().toIso8601String();

      final dbHelper = DatabaseHelper();
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

      if (mounted) {
        await clearDraftAfterSave();
        if (!mounted) return;
        final label = _isObjetIncomplet
            ? '${widget.entityType} signalé incomplet'
            : '${widget.entityType} enregistré '
                '(${_distanceTotaleM.toStringAsFixed(1)} m, '
                '${widget.linePoints.length} pts)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label),
            backgroundColor:
                _isObjetIncomplet ? Colors.orange : Colors.green,
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

  bool _isCoordField(String field) =>
      field.endsWith('_coor_x') ||
      field.endsWith('_coor_y') ||
      field.endsWith('_coor_z');

  Widget _buildField(String field) {
    final isCoordField = _isCoordField(field);
    final isTypeField = field == _typeField && _typeOptions.isNotEmpty;
    final isDistanceField = field == 'longueur' ||
        field == 'ep_long_c' ||
        field == 'ep_long_r' ||
        field == 'long_troncon';
    final rule = SrmConfig.getFieldRule(widget.metier, widget.entityType, field);
    final label = _fieldLabel(field);
    final controller = _controllers[field]!;
    final isDisabled = _isLocked || _isObjetIncomplet;
    final shouldFade = isDisabled && !isCoordField && !isDistanceField;

    if (isTypeField) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Opacity(
          opacity: shouldFade ? (_isLocked ? 0.55 : 0.35) : 1.0,
          child: DropdownButtonFormField<String>(
            initialValue: controller.text.isEmpty ? null : controller.text,
            decoration: _deco(label),
            isExpanded: true,
            items: _typeOptions
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: isDisabled ? null : (v) => controller.text = v ?? '',
            validator: isDisabled
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
          decoration: _deco(label).copyWith(
            filled: isDisabled,
            fillColor: isDisabled ? Colors.grey.shade50 : null,
          ),
          keyboardType: _kbType(rule),
          maxLines: rule.multiline ? 3 : 1,
          maxLength: rule.maxLength,
          inputFormatters: _inputFormatters(rule),
          readOnly: isDisabled,
          validator:
              isDisabled ? null : (value) => _validateField(field, value),
        ),
      ),
    );
  }

  InputDecoration _deco(String label, {bool required = false}) =>
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
      );

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

  String? _validateField(String field, String? value) {
    final normalized = (value ?? '').trim();
    final rule = SrmConfig.getFieldRule(widget.metier, widget.entityType, field);

    if (normalized.isEmpty) {
      return rule.required ? 'Champ requis' : null;
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
    return null;
  }

  dynamic _normalizeFieldValue(String field, String value) {
    final normalized = value.trim();
    final rule = SrmConfig.getFieldRule(widget.metier, widget.entityType, field);

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
      'techcable': 'Tech câble',
      'type_liaison': 'Type liaison',
      'section_conducteur': 'Section conducteur',
      'mode_pose': 'Mode pose',
      'status_troncon': 'Statut tronçon',
      'date_mise_service': 'Date mise en service',
      'code_poste': 'Code poste',
      'num_transfo': 'N° transfo',
      'codedepart': 'Code départ',
      'nbphases': 'Nb phases',
      'section_neutre': 'Section neutre',
      'nu': 'NU',
      'section_phase': 'Section phase',
      'arme': 'Armé',
      'cable_unipolaire': 'Câble unipolaire',
      'marque': 'Marque',
      'type_troncon': 'Type tronçon',
      'section_conduct': 'Section conduct',
      'type_cable': 'Type câble',
      'metal_conduct': 'Métal conducteur',
      'phasage_segment': 'Phasage segment',
      'caracteristique': 'Caractéristique',
      'technologie_utilisee': 'Technologie',
      'neutre': 'Neutre',
      'type_mise_terre': 'Type mise à la terre',
      'section_mise_terre': 'Section MAT',
      'tension': 'Tension (kV)',
      'postesource': 'Poste source',
      'date_mise_en_service': 'Date MES',
      'long_troncon': 'Longueur tronçon (m)',
      'depart': 'Départ',
    };
    return labels[field] ?? field.replaceAll('_', ' ');
  }

  Widget _buildPhotoSection() {
    if (_maxPhotos == 0) return const SizedBox.shrink();
    final disabled = _isObjetIncomplet || _isLocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text(
          'Photos (max $_maxPhotos)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
          children: List.generate(_maxPhotos, (i) {
            final idx = i + 1;
            final path = _photoPaths[idx];
            return GestureDetector(
              onTap: disabled ? null : () => _pickPhoto(idx),
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
                    if (path != null && !disabled)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removePhoto(idx),
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
                      if (!v) _typeAnomalie = null;
                    }),
            contentPadding: EdgeInsets.zero,
          ),
          if (_hasAnomalie && !_isObjetIncomplet)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _typeAnomalie,
                decoration: _deco('Type d\'anomalie'),
                hint: const Text('Sélectionner'),
                items: const [
                  DropdownMenuItem(value: 'Fuite', child: Text('Fuite')),
                  DropdownMenuItem(
                    value: 'Corrosion',
                    child: Text('Corrosion'),
                  ),
                  DropdownMenuItem(
                    value: 'Obstruction',
                    child: Text('Obstruction'),
                  ),
                  DropdownMenuItem(
                    value: 'Dommage physique',
                    child: Text('Dommage physique'),
                  ),
                  DropdownMenuItem(value: 'Autre', child: Text('Autre')),
                ],
                onChanged: _isLocked
                    ? null
                    : (v) => setState(() => _typeAnomalie = v),
              ),
            ),
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
                    'Les champs de l\'objet sont désactivés.\n'
                    'Seuls le tracé GPS et la raison sont enregistrés.',
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
              _typeAnomalie = null;
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
                    widget.entityType,
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
                onPressed: _save,
              ),
          ],
        ),
        body: Form(
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
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isObjetIncomplet ? Colors.orange : _metierColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
