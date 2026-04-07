// lib/widgets/forms/srm_point_form_widget.dart
// ── SPRINT 5 : Formulaire dynamique SRM — entités ponctuelles ──
// Fonctionne pour EP / ASS / ELEC selon srm_config.dart
// Les photos photo_1..photo_4 sont portées directement par l'objet
//
// ── SPRINT 6 — Modifications ──
//  1. uuid retiré du formulaire (généré automatiquement par Uuid().v4() dans _save)
//  2. Champs obligatoires marqués * via SrmConfig.isRequiredField() + validator
//  3. Champs auto (coordonnées GPS) affichés readOnly sans *
//  4. Toggle "Objet Incomplet" : griser les champs + saisir raison depuis objet_incomplet
//     (même principe que le Switch Anomalie existant)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/srm_config.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/api_service.dart';
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

  // ── Anomalie (existant) ──
  bool _hasAnomalie = false;
  String? _typeAnomalie;

  // ── Objet Incomplet (NOUVEAU) ──
  bool _isObjetIncomplet = false;
  String? _raisonIncomplet;
  final TextEditingController _detailRaisonController = TextEditingController();

  bool _isSaving = false;
  final _picker = ImagePicker();
  final Map<int, String?> _photoPaths = {1: null, 2: null, 3: null, 4: null};

  late final Map<String, dynamic>? _entityConfig;
  late final List<String> _fields;
  late final List<String> _requiredFields; // NOUVEAU
  late final List<String> _typeOptions;
  late final String? _typeField;
  late final int _maxPhotos;
  late final bool _hasZ;
  late double _merchichX;
  late double _merchichY;

  @override
  void initState() {
    super.initState();
    _entityConfig  = SrmConfig.getEntityConfig(widget.metier, widget.entityType);
    _fields        = SrmConfig.getFields(widget.metier, widget.entityType);
    _requiredFields = SrmConfig.getRequiredFields(widget.metier, widget.entityType); // NOUVEAU
    _typeOptions   = SrmConfig.getTypeOptions(widget.metier, widget.entityType);
    _typeField     = _entityConfig?['typeField'] as String?;
    _maxPhotos     = SrmConfig.getMaxPhotos(widget.metier, widget.entityType);
    _hasZ          = SrmConfig.hasAltitudeZ(widget.metier, widget.entityType);

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

      // Restaurer état objet incomplet en mode édition
      _isObjetIncomplet = widget.existingData!['objet_incomplet'] == 1 ||
          widget.existingData!['objet_incomplet'] == true;
      _raisonIncomplet = widget.existingData!['raison_incomplet']?.toString();
      _detailRaisonController.text =
          widget.existingData!['detail_raison_incomplet']?.toString() ?? '';

      for (int i = 1; i <= 4; i++) {
        _photoPaths[i] = widget.existingData!['photo_$i']?.toString();
      }
    }
  }

  void _prefillCoordinates() {
    final coordFields = {
      'ep_coor_x':   _merchichX.toStringAsFixed(3),
      'ep_coor_y':   _merchichY.toStringAsFixed(3),
      'ass_coor_x':  _merchichX.toStringAsFixed(3),
      'ass_coor_y':  _merchichY.toStringAsFixed(3),
      'elec_coor_x': _merchichX.toStringAsFixed(3),
      'elec_coor_y': _merchichY.toStringAsFixed(3),
    };
    if (widget.altitude != null) {
      final zStr = widget.altitude!.toStringAsFixed(3);
      coordFields['ep_coor_z']   = zStr;
      coordFields['ass_coor_z']  = zStr;
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
    for (final c in _controllers.values) c.dispose();
    _detailRaisonController.dispose(); // NOUVEAU
    super.dispose();
  }

  Color get _metierColor => Color(SrmConfig.getMetierColor(widget.metier));

  // ────────────────────────────────────────────
  // Photos
  // ────────────────────────────────────────────
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
    final picked = await _picker.pickImage(
        source: source, imageQuality: 75, maxWidth: 1280);
    if (picked != null) setState(() => _photoPaths[index] = picked.path);
  }

  void _removePhoto(int index) => setState(() => _photoPaths[index] = null);

  // ────────────────────────────────────────────
  // Sauvegarde
  // ────────────────────────────────────────────
  Future<void> _save() async {
    // Si objet incomplet : on ne valide PAS les champs métier (ils sont grisés)
    // mais on valide quand même la raison
    if (!_isObjetIncomplet && !_formKey.currentState!.validate()) return;
    if (_isObjetIncomplet && _raisonIncomplet == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('⚠️ Veuillez sélectionner une raison pour l\'objet incomplet'),
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

      // ── UUID : toujours automatique, jamais saisi ──
      data['uuid'] = widget.existingData?['uuid'] ?? const Uuid().v4();

      // ── Champs métier (ignorés si objet incomplet) ──
      if (!_isObjetIncomplet) {
        for (final field in _fields) {
          final val = _controllers[field]?.text.trim();
          if (val != null && val.isNotEmpty) data[field] = val;
        }
      }

      // ── Coordonnées GPS brutes (toujours sauvegardées) ──
      data['latitude_gps']  = widget.latitude;
      data['longitude_gps'] = widget.longitude;
      if (widget.altitude != null) data['altitude_gps'] = widget.altitude;

      // ── Coordonnées Merchich (toujours sauvegardées) ──
      // même si objet incomplet, on garde la position approximative
      final xField = _fields.firstWhere(
        (f) => f.endsWith('_coor_x'), orElse: () => '');
      final yField = _fields.firstWhere(
        (f) => f.endsWith('_coor_y'), orElse: () => '');
      if (xField.isNotEmpty) data[xField] = _merchichX.toStringAsFixed(3);
      if (yField.isNotEmpty) data[yField] = _merchichY.toStringAsFixed(3);

      // ── Anomalie ──
      data['anomalie'] = _hasAnomalie ? 1 : 0;
      if (_hasAnomalie && _typeAnomalie != null) {
        data['type_anomalie'] = _typeAnomalie;
      }

      // ── Objet Incomplet (NOUVEAU) ──
      data['objet_incomplet'] = _isObjetIncomplet ? 1 : 0;
      if (_isObjetIncomplet) {
        data['raison_incomplet']        = _raisonIncomplet;
        data['detail_raison_incomplet'] = _detailRaisonController.text.trim();
      }

      // ── Photos ──
      for (int i = 1; i <= 4; i++) {
        data['photo_$i'] = _photoPaths[i];
      }

      // ── Clés étrangères (injectées automatiquement) ──
      data['id_projet']     = ApiService.currentProjetId;
      data['id_mission']    = ApiService.currentMissionId;
      data['id_agent_crea'] = ApiService.userId;
      data['synced']        = 0;
      data['date_collecte'] = DateTime.now().toIso8601String();

      final db = DatabaseHelper();

      // ── INSERT ou UPDATE dans la table métier ──
      if (widget.existingData != null && widget.existingData!['id'] != null) {
        final dbRaw = await db.database;
        await dbRaw.update(tableName, data,
            where: 'id = ?', whereArgs: [widget.existingData!['id']]);
      } else {
        await db.insertEntitySrm(tableName, data);
      }

      // ── INSERT dans objet_incomplet si toggle activé (NOUVEAU) ──
      if (_isObjetIncomplet) {
        final metierCode = widget.metier == 'Eau Potable'
            ? 'EP'
            : widget.metier == 'Assainissement'
                ? 'ASS'
                : 'ELEC';
        final incompletData = {
          'uuid_objet':        data['uuid'],     // lien avec l'objet parent
          'nom_classe':        tableName,
          'metier':            metierCode,
          'raison':            _raisonIncomplet,
          'detail_raison':     _detailRaisonController.text.trim(),
          'date_signalement':  DateTime.now().toIso8601String(),
          'id_agent_signal':   ApiService.userId,
          'statut':            'A_COMPLETER',
          'id_mission':        ApiService.currentMissionId,
          'id_projet':         ApiService.currentProjetId,
          'synced':            0,
        };
        await db.insertEntitySrm('objet_incomplet', incompletData);
      }

      if (mounted) {
        final label = _isObjetIncomplet
            ? '⚠️ ${widget.entityType} signalé incomplet'
            : '✅ ${widget.entityType} enregistré';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(label),
          backgroundColor:
              _isObjetIncomplet ? Colors.orange : Colors.green,
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

  // ────────────────────────────────────────────
  // Construction d'un champ
  // ────────────────────────────────────────────
  bool _isCoordField(String field) =>
      field.endsWith('_coor_x') ||
      field.endsWith('_coor_y') ||
      field.endsWith('_coor_z');

  Widget _buildField(String field) {
    final isCoord    = _isCoordField(field);
    final isTypeField = field == _typeField && _typeOptions.isNotEmpty;
    // ── NOUVEAU : champ obligatoire ? ──
    final isRequired = !isCoord && _requiredFields.contains(field);
    final label      = _fieldLabel(field);
    final controller = _controllers[field]!;

    // ── NOUVEAU : grisage si objet incomplet activé ──
    // Les coordonnées restent visibles mais désactivées de toute façon (readOnly)
    Widget fieldWidget;

    if (isTypeField) {
      fieldWidget = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: controller.text.isEmpty ? null : controller.text,
          decoration: _deco(label, required: isRequired),
          isExpanded: true,
          items: _typeOptions
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: _isObjetIncomplet
              ? null // désactivé si objet incomplet
              : (v) => controller.text = v ?? '',
          validator: (!_isObjetIncomplet && isRequired)
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
      fieldWidget = Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: _deco(label, required: isRequired),
          keyboardType: _kbType(field),
          maxLines: (field == 'observation' || field == 'commentaire') ? 3 : 1,
          readOnly: _isObjetIncomplet,
          validator: (!_isObjetIncomplet && isRequired)
              ? (v) => (v == null || v.trim().isEmpty)
                  ? 'Champ obligatoire *'
                  : null
              : null,
        ),
      );
    }

    // ── NOUVEAU : opacité réduite quand objet incomplet (sauf coordonnées) ──
    if (_isObjetIncomplet && !isCoord) {
      return Opacity(
        opacity: 0.35,
        child: fieldWidget,
      );
    }
    return fieldWidget;
  }

  // ────────────────────────────────────────────
  // InputDecoration avec astérisque si requis
  // ────────────────────────────────────────────
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

  TextInputType _kbType(String field) {
    final num = [
      'diam', 'long', 'pression', 'profondeur', 'cote', 'capacite',
      'debit', 'puissance', 'calibre', 'hauteur', 'largeur', 'tension',
      'chute', 'nb_'
    ];
    for (final k in num) {
      if (field.contains(k)) return TextInputType.number;
    }
    return TextInputType.text;
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
      'conformite_plan': 'Conformité plan',
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

  // ────────────────────────────────────────────
  // Section Photos
  // ────────────────────────────────────────────
  Widget _buildPhotoSection() {
    if (_maxPhotos == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),
        Text('Photos (max $_maxPhotos)',
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_maxPhotos, (i) {
            final idx = i + 1;
            final path = _photoPaths[idx];
            return GestureDetector(
              onTap: _isObjetIncomplet ? null : () => _pickPhoto(idx),
              child: Opacity(
                opacity: _isObjetIncomplet ? 0.35 : 1.0,
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
                              child:
                                  Image.file(File(path), fit: BoxFit.cover))
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
                    if (path != null && !_isObjetIncomplet)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removePhoto(idx),
                          child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle),
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

  // ────────────────────────────────────────────
  // Section Anomalie (inchangée)
  // ────────────────────────────────────────────
  Widget _buildAnomalieSection() {
    // Désactivée si objet incomplet est activé
    return Opacity(
      opacity: _isObjetIncomplet ? 0.35 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          SwitchListTile(
            title: const Text('Anomalie détectée',
                style: TextStyle(fontWeight: FontWeight.bold)),
            value: _hasAnomalie,
            activeColor: Colors.red,
            onChanged: _isObjetIncomplet
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
                value: _typeAnomalie,
                decoration: _deco('Type d\'anomalie'),
                hint: const Text('Sélectionner'),
                items: const [
                  DropdownMenuItem(value: 'Fuite',           child: Text('Fuite')),
                  DropdownMenuItem(value: 'Corrosion',       child: Text('Corrosion')),
                  DropdownMenuItem(value: 'Obstruction',     child: Text('Obstruction')),
                  DropdownMenuItem(value: 'Dommage physique',child: Text('Dommage physique')),
                  DropdownMenuItem(value: 'Dysfonctionnement',child: Text('Dysfonctionnement')),
                  DropdownMenuItem(value: 'Absent',          child: Text('Absent')),
                  DropdownMenuItem(value: 'Autre',           child: Text('Autre')),
                ],
                onChanged: (v) => setState(() => _typeAnomalie = v),
              ),
            ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  // NOUVEAU — Section Objet Incomplet
  // ────────────────────────────────────────────
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
            child: Row(
              children: const [
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
          activeColor: Colors.orange,
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
            }
          }),
          contentPadding: EdgeInsets.zero,
        ),

        // Champs supplémentaires visibles seulement si toggle ON
        if (_isObjetIncomplet) ...[
          const SizedBox(height: 8),

          // Raison (OBLIGATOIRE) — depuis enum raison_incomplet_enum de la BDD
          DropdownButtonFormField<String>(
            value: _raisonIncomplet,
            decoration: _deco('Raison', required: true),
            hint: const Text('Sélectionner une raison'),
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                  value: 'ACCES_BLOQUE',
                  child: Text('Accès bloqué')),
              DropdownMenuItem(
                  value: 'VEHICULE_STATIONNE',
                  child: Text('Véhicule stationné sur la voie')),
              DropdownMenuItem(
                  value: 'TAMPON_INACCESSIBLE',
                  child: Text('Tampon inaccessible / scellé')),
              DropdownMenuItem(
                  value: 'CONDITIONS_METEO',
                  child: Text('Conditions météo défavorables')),
              DropdownMenuItem(
                  value: 'DANGER',
                  child: Text('Danger sur site')),
              DropdownMenuItem(
                  value: 'AUTRE',
                  child: Text('Autre raison')),
            ],
            onChanged: (v) => setState(() => _raisonIncomplet = v),
            validator: (v) =>
                (v == null) ? 'Raison obligatoire *' : null,
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

  // ────────────────────────────────────────────
  // Build principal
  // ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isObjetIncomplet ? Colors.orange : _metierColor,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(widget.entityType,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                // NOUVEAU : badge "INCOMPLET" dans l'AppBar
                if (_isObjetIncomplet) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
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
            // ── Bandeau GPS ──
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

            // ── Légende champs obligatoires ──
            if (_requiredFields.isNotEmpty && !_isObjetIncomplet)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: const [
                    Text(' * ', style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                    Text('Champ obligatoire',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),

            // ── Champs dynamiques ──
            ..._fields.map(_buildField),

            // ── Sections Anomalie + Incomplet ──
            _buildAnomalieSection(),
            _buildObjetIncompletSection(), // NOUVEAU
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
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
