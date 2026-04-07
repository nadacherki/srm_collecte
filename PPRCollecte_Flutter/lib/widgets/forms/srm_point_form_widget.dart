// lib/widgets/forms/srm_point_form_widget.dart
// ── SPRINT 5 : Formulaire dynamique SRM — entités ponctuelles ──
// Fonctionne pour EP / ASS / ELEC selon srm_config.dart
// Les photos photo_1..photo_4 sont portées directement par l'objet

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
import '../../services/photo_validation_service.dart';
import '../../services/projection_service.dart';

class SrmPointFormWidget extends StatefulWidget {
  final String metier;      // "Eau Potable" | "Assainissement" | "Électricité"
  final String entityType;  // ex: "Vanne", "Regard ASS", "Support"
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

class _SrmPointFormWidgetState extends State<SrmPointFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  bool _hasAnomalie = false;
  String? _typeAnomalie;
  bool _isSaving = false;
  final _picker = ImagePicker();
  final Map<int, String?> _photoPaths = {1: null, 2: null, 3: null, 4: null};

  late final Map<String, dynamic>? _entityConfig;
  late final List<String> _fields;
  late final List<String> _typeOptions;
  late final String? _typeField;
  late final int _maxPhotos;
  late final bool _hasZ;
  late double _merchichX;
  late double _merchichY;

  @override
  void initState() {
    super.initState();
    _entityConfig = SrmConfig.getEntityConfig(widget.metier, widget.entityType);
    _fields = SrmConfig.getFields(widget.metier, widget.entityType);
    _typeOptions = SrmConfig.getTypeOptions(widget.metier, widget.entityType);
    _typeField = _entityConfig?['typeField'] as String?;
    _maxPhotos = SrmConfig.getMaxPhotos(widget.metier, widget.entityType);
    _hasZ = SrmConfig.hasAltitudeZ(widget.metier, widget.entityType);

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
    _prefillCoordinates();

    if (widget.existingData != null) {
      _hasAnomalie = widget.existingData!['anomalie'] == 1 ||
          widget.existingData!['anomalie'] == true;
      _typeAnomalie = widget.existingData!['type_anomalie']?.toString();
      for (int i = 1; i <= 4; i++) {
        _photoPaths[i] = widget.existingData!['photo_$i']?.toString();
      }
    }
  }

  void _prefillCoordinates() {
    final coordFields = {
      'ep_coor_x': _merchichX.toStringAsFixed(3),
      'ep_coor_y': _merchichY.toStringAsFixed(3),
      'ass_coor_x': _merchichX.toStringAsFixed(3),
      'ass_coor_y': _merchichY.toStringAsFixed(3),
      'elec_coor_x': _merchichX.toStringAsFixed(3),
      'elec_coor_y': _merchichY.toStringAsFixed(3),
    };
    if (widget.altitude != null) {
      final zStr = widget.altitude!.toStringAsFixed(3);
      coordFields['ep_coor_z'] = zStr;
      coordFields['ass_coor_z'] = zStr;
      coordFields['elec_coor_z'] = zStr;
    }
    for (final entry in coordFields.entries) {
      if (_controllers.containsKey(entry.key)) {
        _controllers[entry.key]!.text = entry.value;
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Color get _metierColor => Color(SrmConfig.getMetierColor(widget.metier));

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
          content: Text('Photo refusee: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _photoPaths[index] = picked.path);
  }

  void _removePhoto(int index) => setState(() => _photoPaths[index] = null);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final tableName =
          SrmConfig.getTableName(widget.metier, widget.entityType) ?? '';
      if (tableName.isEmpty) throw Exception('Table non trouvée');

      final data = <String, dynamic>{};
      data['uuid'] = widget.existingData?['uuid'] ?? const Uuid().v4();

      for (final field in _fields) {
        final val = _controllers[field]?.text.trim();
        if (val != null && val.isNotEmpty) {
          data[field] = _normalizeFieldValue(field, val);
        }
      }

      data['latitude_gps'] = widget.latitude;
      data['longitude_gps'] = widget.longitude;
      if (widget.altitude != null) data['altitude_gps'] = widget.altitude;

      data['anomalie'] = _hasAnomalie ? 1 : 0;
      if (_hasAnomalie && _typeAnomalie != null) {
        data['type_anomalie'] = _typeAnomalie;
      }

      for (int i = 1; i <= 4; i++) {
        data['photo_$i'] = _photoPaths[i];
      }

      data['id_projet'] = ApiService.currentProjetId;
      data['id_mission'] = ApiService.currentMissionId;
      data['id_agent_crea'] = ApiService.userId;
      data['synced'] = 0;
      data['date_collecte'] = DateTime.now().toIso8601String();

      final db = DatabaseHelper();
      if (widget.existingData != null && widget.existingData!['id'] != null) {
        final dbRaw = await db.database;
        await dbRaw.update(tableName, data,
            where: 'id = ?', whereArgs: [widget.existingData!['id']]);
      } else {
        await db.insertEntitySrm(tableName, data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ ${widget.entityType} enregistré'),
          backgroundColor: Colors.green,
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

  Widget _buildField(String field) {
    final isCoord = field.endsWith('_coor_x') ||
        field.endsWith('_coor_y') ||
        field.endsWith('_coor_z');
    final isTypeField = field == _typeField && _typeOptions.isNotEmpty;
    final rule = SrmConfig.getFieldRule(widget.metier, widget.entityType, field);
    final label = _fieldLabel(field);
    final controller = _controllers[field]!;

    if (isTypeField) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: controller.text.isEmpty ? null : controller.text,
          decoration: _deco(label),
          isExpanded: true,
          items: _typeOptions
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => controller.text = v ?? '',
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Champ requis' : null,
        ),
      );
    }

    if (isCoord) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: _deco(label).copyWith(
            filled: true,
            fillColor: Colors.grey.shade100,
            suffixIcon: const Icon(Icons.gps_fixed, size: 16),
          ),
          readOnly: true,
          style: const TextStyle(
              fontFamily: 'monospace', fontWeight: FontWeight.w600),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: _deco(label),
        keyboardType: _kbType(rule),
        maxLines: rule.multiline ? 3 : 1,
        maxLength: rule.maxLength,
        inputFormatters: _inputFormatters(rule),
        validator: (value) => _validateField(field, value),
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
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
        return const TextInputType.numberWithOptions(decimal: true, signed: true);
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
      'ep_coor_x': 'X Merchich (m)', 'ep_coor_y': 'Y Merchich (m)',
      'ep_coor_z': 'Z Altitude (m)', 'ep_pression': 'Pression (bar)',
      'ep_calibre': 'Calibre', 'ep_numero': 'Numéro',
      'ep_diam_amont': 'Diam. amont (mm)', 'ep_diam_aval': 'Diam. aval (mm)',
      'ep_capacite': 'Capacité (m³)', 'ep_cote_radier': 'Cote radier (m)',
      'ep_cote_trop_plein': 'Cote trop-plein', 'ep_cote_tn': 'Cote TN',
      'ep_nb_pompes': 'Nb pompes', 'ep_profondeur': 'Profondeur (m)',
      'ep_debit': 'Débit (m³/h)', 'ep_puissance': 'Puissance (kW)',
      'ep_forme': 'Forme', 'ep_longueur': 'Longueur (m)',
      'ep_largeur': 'Largeur (m)', 'ep_cote_tampon': 'Cote tampon',
      'ep_cote_fil_eau': 'Cote fil eau', 'zamont': 'Z amont (m)',
      'zaval': 'Z aval (m)', 'pente': 'Pente (%)',
      // ASS
      'uuid': 'UUID', 'conformite_plan': 'Conformité plan',
      'etat': 'État', 'type_regard': 'Type regard',
      'type_tampon': 'Type tampon', 'typereseau': 'Type réseau',
      'classe_tampon': 'Classe tampon', 'forme': 'Forme',
      'date_pose': 'Date pose', 'verrouille': 'Verrouillé',
      'accessibilite': 'Accessibilité', 'rehabilitation': 'Réhabilitation',
      'date_rehabilitation': 'Date réhabilitation',
      'nature_corps': 'Nature corps', 'presence_cunette': 'Présence cunette',
      'cote_tampon': 'Cote tampon (m)', 'cote_radier': 'Cote radier (m)',
      'chute': 'Chute (m)', 'profondeur_radier': 'Profondeur radier (m)',
      'ass_coor_x': 'X Merchich (m)', 'ass_coor_y': 'Y Merchich (m)',
      'ass_coor_z': 'Z Altitude (m)', 'centre': 'Centre',
      'commentaire': 'Commentaire', 'nom': 'Nom',
      // ELEC
      'type_support': 'Type support', 'console': 'Console',
      'etat_support': 'État support', 'materiel_supp': 'Matériel',
      'type_assemblage': 'Type assemblage', 'type_armement': 'Type armement',
      'type_protection': 'Type protection', 'status': 'Statut',
      'mise_a_la_terre': 'Mise à la terre', 'type_isolateur': 'Type isolateur',
      'code_support': 'Code support', 'lumineux': 'Lumineux',
      'hauteur_supp': 'Hauteur (m)', 'type_mise_a_la_terre': 'Type MAT',
      'type_balise': 'Type balise', 'elec_coor_x': 'X Merchich (m)',
      'elec_coor_y': 'Y Merchich (m)', 'elec_coor_z': 'Z Altitude (m)',
      'nom_poste': 'Nom poste', 'type_poste': 'Type poste',
      'nature_poste': 'Nature', 'etat_service': 'État service',
      'tension': 'Tension (kV)', 'code_poste': 'Code poste',
      'type_coffret': 'Type coffret', 'num_coffret': 'N° coffret',
    };
    return labels[field] ?? field.replaceAll('_', ' ');
  }

  Widget _buildPhotoSection() {
    if (_maxPhotos == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text('Photos (max $_maxPhotos)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Text(
          'Formats autorises: JPG, PNG, WEBP, HEIC • Taille max: ${PhotoValidationService.maxPhotoSizeLabel}',
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
              onTap: () => _pickPhoto(idx),
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
                            child: Image.file(File(path), fit: BoxFit.cover))
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
                  if (path != null)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removePhoto(idx),
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
            );
          }),
        ),
      ],
    );
  }

  Widget _buildAnomalieSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        SwitchListTile(
          title: const Text('Anomalie détectée',
              style: TextStyle(fontWeight: FontWeight.bold)),
          value: _hasAnomalie,
          activeThumbColor: Colors.red,
          onChanged: (v) => setState(() {
            _hasAnomalie = v;
            if (!v) _typeAnomalie = null;
          }),
          contentPadding: EdgeInsets.zero,
        ),
        if (_hasAnomalie)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: _typeAnomalie,
              decoration: _deco('Type d\'anomalie'),
              hint: const Text('Sélectionner'),
              items: const [
                DropdownMenuItem(value: 'Fuite', child: Text('Fuite')),
                DropdownMenuItem(value: 'Corrosion', child: Text('Corrosion')),
                DropdownMenuItem(
                    value: 'Obstruction', child: Text('Obstruction')),
                DropdownMenuItem(
                    value: 'Dommage physique',
                    child: Text('Dommage physique')),
                DropdownMenuItem(
                    value: 'Dysfonctionnement',
                    child: Text('Dysfonctionnement')),
                DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                DropdownMenuItem(value: 'Autre', child: Text('Autre')),
              ],
              onChanged: (v) => setState(() => _typeAnomalie = v),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _metierColor,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.entityType,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.metier,
                style:
                    const TextStyle(fontSize: 12, color: Colors.white70)),
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
          else
            IconButton(
                icon: const Icon(Icons.check),
                tooltip: 'Enregistrer',
                onPressed: _save),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Bandeau GPS
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _metierColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _metierColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.gps_fixed, size: 14, color: _metierColor),
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

            // Champs dynamiques
            ..._fields.map(_buildField),

            _buildAnomalieSection(),
            _buildPhotoSection(),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _metierColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_isSaving
                        ? 'Enregistrement...'
                        : 'Enregistrer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
