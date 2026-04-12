import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/piste_chaussee_db_helper.dart';
import '../../data/remote/api_service.dart';
import '../../core/config/srm_config.dart';
import '../../services/projection_service.dart';
import '../../services/draft_service.dart';

class PolygonFormPage extends StatefulWidget {
  final List<LatLng> polygonPoints;
  final DateTime startTime;
  final DateTime endTime;
  final String agentName;
  final String? activePisteCode;
  final String? nearestPisteCode;
  final Map<String, dynamic>? existingData;

  // ── SPRINT 5 : métier + type SRM pour polygone ──
  // Si null → comportement historique (Zone de Plaine)
  final String? metier;      // "Eau Potable" etc.
  final String? entityType;  // "Regard EP" | "Planche"

  const PolygonFormPage({
    super.key,
    required this.polygonPoints,
    required this.startTime,
    required this.endTime,
    required this.agentName,
    this.activePisteCode,
    this.nearestPisteCode,
    this.existingData,
    this.metier,
    this.entityType,
  });

  @override
  State<PolygonFormPage> createState() => _PolygonFormPageState();
}

class _PolygonFormPageState extends State<PolygonFormPage>
    with FormDraftMixin<PolygonFormPage> {
  String? _nearestPisteCode;
  bool _isLoading = true;
  bool _isSaving = false;
  final _nomController = TextEditingController();
  final _codeGpsController = TextEditingController();

  // ── SPRINT 5 : champs SRM pour Regard EP / Planche ──
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
  // Coordonnées Merchich du centroïde
  double _xMerchich = 0.0;
  double _yMerchich = 0.0;

  late double _superficieHa;
  late List<List<double>> _closedCoordinates;

  bool get _isEditing =>
      widget.existingData != null && widget.existingData!['id'] != null;

  // SRM : est-ce un objet SRM (pas GeoDNGR) ?
  bool get _isSrm =>
      widget.metier != null && widget.entityType != null;

  // Couleur selon contexte
  Color get _categoryColor => _isSrm
      ? Color(SrmConfig.getMetierColor(widget.metier!))
      : const Color(0xFF212121);

  String get _pageTitle =>
      widget.entityType ?? 'Zone de Plaine';

  String get _tableName {
    if (!_isSrm) return 'enquete_polygone';
    return SrmConfig.getTableName(widget.metier!, widget.entityType!) ??
        widget.entityType!.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupAutoCapitalize();

    // ── SPRINT 7 : Brouillon automatique (uniquement en mode création) ──
    if (!_isEditing) {
      final allControllers = [
        _nomController, _codeGpsController, _epNumController,
        _epTypeController, _epFormeController, _epLongueurController,
        _epLargeurController, _epCoteTamponController, _epCoteRadierController,
        _epCoteFilEauController, _epEtatController, _emplacementController,
        _refRueController, _etageAquaController, _secteurAquaController,
        _observationController,
      ];
      for (final c in allControllers) {
        c.addListener(onFieldChanged);
      }
      initDraft();
    }
  }

  Future<void> _initializeData() async {
    _superficieHa = _calculateAreaHectares(widget.polygonPoints);

    _closedCoordinates = widget.polygonPoints
        .map((p) => [p.longitude, p.latitude])
        .toList();
    if (_closedCoordinates.isNotEmpty) {
      _closedCoordinates.add(List<double>.from(_closedCoordinates.first));
    }

    // ── SPRINT 5 : Calcul centroïde Merchich Nord ──
    if (widget.polygonPoints.isNotEmpty) {
      final centroidLat = widget.polygonPoints
              .map((p) => p.latitude)
              .reduce((a, b) => a + b) /
          widget.polygonPoints.length;
      final centroidLon = widget.polygonPoints
              .map((p) => p.longitude)
              .reduce((a, b) => a + b) /
          widget.polygonPoints.length;
      final m = ProjectionService()
          .wgs84ToMerchich(longitude: centroidLon, latitude: centroidLat);
      _xMerchich = m.x;
      _yMerchich = m.y;

      // Pré-remplir coordonnées SRM
      _epLongueurController.text =
          (widget.polygonPoints.length > 1 ? sqrt(_superficieHa * 10000) : 0.0)
              .toStringAsFixed(2);
    }

    // Pré-remplir en mode édition
    if (_isEditing) {
      _nomController.text = widget.existingData!['nom']?.toString() ?? '';
      _codeGpsController.text =
          widget.existingData!['code_gps']?.toString() ?? '';
      if (_isSrm) {
        _epNumController.text =
            widget.existingData!['ep_num']?.toString() ?? '';
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
      }
    }

    // Chercher la piste (seulement mode GeoDNGR)
    if (!_isSrm) {
      try {
        if (widget.activePisteCode != null &&
            widget.activePisteCode!.isNotEmpty) {
          _nearestPisteCode = widget.activePisteCode;
        } else if (widget.nearestPisteCode != null &&
            widget.nearestPisteCode!.isNotEmpty) {
          _nearestPisteCode = widget.nearestPisteCode;
        } else {
          _nearestPisteCode = await SimpleStorageHelper()
              .findNearestPisteCode(widget.polygonPoints.first);
        }
      } catch (e) {
        print('❌ Erreur recherche piste: $e');
      }
    }

    setState(() => _isLoading = false);
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
        final corrected = text[0].toUpperCase() + text.substring(1).toLowerCase();
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

  // ==================================================================
  //  SAUVEGARDE — INSERT en création, UPDATE en édition
  // ==================================================================
  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    if (_superficieHa < 0.0001) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '❌ Les points sont alignés ou trop proches. Polygone invalide.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      final now = DateTime.now();

      // ── SPRINT 5 : Sauvegarde entité SRM polygone ──
      if (_isSrm) {
        final data = <String, dynamic>{
          'uuid': widget.existingData?['uuid'] ?? const Uuid().v4(),
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
          // Coordonnées Merchich centroïde
          'ep_coor_x': _xMerchich,
          'ep_coor_y': _yMerchich,
          // Géométrie polygone
          'points_json': jsonEncode(_closedCoordinates),
          'superficie_ha': _superficieHa,
          'nb_points': widget.polygonPoints.length,
          // FK SRM
          'id_projet': ApiService.currentProjetId,
          'id_agent_crea': ApiService.userId,
          'mode_localisation': 'gnss',
          'synced': 0,
          'date_collecte': now.toIso8601String(),
        };

        await DatabaseHelper().insertEntitySrm(_tableName, data);

        if (mounted) {
          await clearDraftAfterSave();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '✅ ${widget.entityType} enregistré (${_superficieHa.toStringAsFixed(4)} ha)'),
            backgroundColor: _categoryColor,
          ));
          Navigator.of(context).pop(true);
        }
        return;
      }

      // ── Comportement historique GeoDNGR (Zone de Plaine) ──
      final db = await DatabaseHelper().database;

      if (_isEditing) {
        final id = widget.existingData!['id'];
        await db.update(
          'enquete_polygone',
          {
            'nom': _nomController.text.isEmpty ? null : _nomController.text,
            'points_json': jsonEncode(_closedCoordinates),
            'superficie_en_ha': _superficieHa,
            'code_gps': _codeGpsController.text.isEmpty
                ? null
                : _codeGpsController.text,
            'date_modification': now.toIso8601String(),
            'code_piste': _nearestPisteCode,
            'synced': 0,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await db.insert('enquete_polygone', {
          'nom': _nomController.text.isEmpty ? null : _nomController.text,
          'points_json': jsonEncode(_closedCoordinates),
          'superficie_en_ha': _superficieHa,
          'enqueteur': widget.agentName,
          'date_creation': now.toIso8601String(),
          'date_modification': null,
          'code_piste': _nearestPisteCode,
          'code_gps': _codeGpsController.text.isEmpty
              ? null
              : _codeGpsController.text,
          'synced': 0,
          'downloaded': 0,
          'login_id':
              ApiService.userId ?? await DatabaseHelper().resolveLoginId(),
          'saved_by_user_id': ApiService.userId,
          'commune_id': null,
        });
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Succès'),
              ],
            ),
            content: Text(
              'Zone de Plaine "${_nomController.text.isNotEmpty ? _nomController.text : "Sans nom"}" enregistrée\n'
              'Code Piste: ${_nearestPisteCode ?? "Non spécifié"}\n'
              'Superficie: ${_superficieHa.toStringAsFixed(4)} ha\n'
              'Nombre de points: ${widget.polygonPoints.length}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          await clearDraftAfterSave();
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      print('❌ Erreur sauvegarde polygone: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearForm() {
    setState(() {
      _nomController.clear();
    });
  }

  void _handleBack() async {
    // ── SPRINT 7 : sauvegarder le brouillon avant de quitter ──
    if (!_isEditing) await saveDraftBeforeExit();
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
  //  BUILD — Style identique au PointFormWidget
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
              Text('Préparation du formulaire...', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    final String dateCreation = _isEditing ? (widget.existingData!['date_creation']?.toString() ?? DateTime.now().toIso8601String()) : DateTime.now().toIso8601String();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER — identique au PointFormWidget =====
            Container(
              decoration: BoxDecoration(color: _categoryColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _handleBack,
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Zone de Plaine',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Table: $_tableName',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withAlpha((0.9 * 255).round()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearForm,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withOpacity(0.2),
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
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ====== SECTION SRM — Regard EP / Planche ======
                  if (_isSrm) ...[
                    _buildFormSection(
                      title: '🔧 ${widget.entityType} — Attributs',
                      children: [
                        // Bandeau coordonnées Merchich
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _categoryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _categoryColor.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Centroïde Merchich Nord',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _categoryColor,
                                    fontSize: 13),
                              ),
                              Text(
                                'X: ${_xMerchich.toStringAsFixed(3)} m  '
                                'Y: ${_yMerchich.toStringAsFixed(3)} m',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600),
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
                          _buildTextField(
                              label: 'Numéro (ep_num)',
                              hint: 'Ex: R001',
                              controller: _epNumController),
                          _buildTextField(
                              label: 'Type',
                              hint: '',
                              controller: _epTypeController),
                          _buildTextField(
                              label: 'Forme',
                              hint: 'Circulaire / Rectangulaire',
                              controller: _epFormeController),
                          _buildTextField(
                              label: 'Longueur (m)',
                              hint: '0.00',
                              controller: _epLongueurController),
                          _buildTextField(
                              label: 'Largeur (m)',
                              hint: '0.00',
                              controller: _epLargeurController),
                          _buildTextField(
                              label: 'Cote tampon (m)',
                              hint: '0.000',
                              controller: _epCoteTamponController),
                          _buildTextField(
                              label: 'Cote radier (m)',
                              hint: '0.000',
                              controller: _epCoteRadierController),
                          _buildTextField(
                              label: 'Cote fil eau (m)',
                              hint: '0.000',
                              controller: _epCoteFilEauController),
                          _buildTextField(
                              label: 'État',
                              hint: 'Bon / Moyen / Mauvais',
                              controller: _epEtatController),
                          _buildTextField(
                              label: 'Emplacement',
                              hint: '',
                              controller: _emplacementController),
                          _buildTextField(
                              label: 'Réf. rue',
                              hint: '',
                              controller: _refRueController),
                          _buildTextField(
                              label: 'Étage aqua',
                              hint: '',
                              controller: _etageAquaController),
                          _buildTextField(
                              label: 'Secteur aqua',
                              hint: '',
                              controller: _secteurAquaController),
                          _buildTextField(
                              label: 'Observation',
                              hint: '',
                              controller: _observationController),
                        ] else if (widget.entityType == 'Planche') ...[
                          _buildTextField(
                              label: 'Nom de la planche',
                              hint: 'Ex: Planche_01',
                              controller: _nomController),
                          _buildTextField(
                              label: 'Code',
                              hint: '',
                              controller: _codeGpsController),
                        ],
                      ],
                    ),
                  ],

                  // ====== SECTION ASSOCIATION (mode GeoDNGR seulement) ======
                  if (!_isSrm) ...[
                  _buildFormSection(
                    title: '🔗 Association',
                    children: [
                      _buildInfoBox(
                        'Ce polygone sera associé à une piste lors de la synchronisation.',
                        Colors.blue,
                      ),
                      if (_nearestPisteCode != null) _buildPisteDetectedBanner(),
                      _buildCodePisteField(),
                    ],
                  ),

                  // ====== SECTION IDENTIFICATION ======
                  _buildFormSection(
                    title: '🏷️ Identification',
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
                  ],

                  // ====== SECTION GÉOMÉTRIE ======
                  _buildFormSection(
                    title: '📐 Géométrie du Polygone',
                    children: [
                      _buildPolygonGpsInfo(),
                    ],
                  ),

                  // ====== SECTION COORDONNÉES DES SOMMETS ======
                  _buildFormSection(
                    title: '📍 Coordonnées des sommets',
                    children: [
                      for (int i = 0; i < widget.polygonPoints.length; i++)
                        _buildGpsInfoRow(
                          'Sommet ${i + 1}:',
                          '${widget.polygonPoints[i].latitude.toStringAsFixed(7)}°, ${widget.polygonPoints[i].longitude.toStringAsFixed(7)}°',
                        ),
                    ],
                  ),

                  // ====== SECTION MÉTADONNÉES ======
                  _buildFormSection(
                    title: '📍 Géolocalisation',
                    children: [
                      _buildReadOnlyAgentField(),
                    ],
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            ),

            // ===== BOUTON ENREGISTRER — identique au PointFormWidget =====
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2)),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _categoryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, size: 20),
                            SizedBox(width: 8),
                            Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================================================================
  //  WIDGETS — copie exacte du style PointFormWidget
  // ==================================================================

  Widget _buildFormSection({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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

  Widget _buildInfoBox(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color.withOpacity(0.8), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPisteDetectedBanner() {
    final String code = _nearestPisteCode ?? '';
    final bool isTemporary = code.isEmpty || code.startsWith('Piste_0_0_0_') || code.startsWith('TEMP_');

    if (isTemporary) {
      // Pas de banner pour code temporaire (le message est dans _buildCodePisteField)
      return const SizedBox.shrink();
    }

    // Code officiel → afficher le banner normalement
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 20, color: Colors.green[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Piste la plus proche détectée:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                Text(code, style: TextStyle(color: Colors.green[700], fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodePisteField() {
    final String code = _nearestPisteCode ?? '';
    final bool isTemporary = code.isEmpty || code.startsWith('Piste_0_0_0_') || code.startsWith('TEMP_');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Code Piste *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          if (isTemporary)
            // CAS 1 : Temporaire → message vert
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sync, size: 20, color: Color(0xFF4CAF50)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Attribué automatiquement lors de la synchronisation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            // CAS 2 : Officiel → afficher le code
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number, size: 20, color: Color(0xFF1976D2)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: code,
                      decoration: const InputDecoration(
                        hintText: 'Code piste',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 16, color: Color(0xFF374151)),
                      enabled: false,
                      readOnly: true,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF5F5F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1976D2))),
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
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
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
                const Icon(Icons.calendar_today, size: 20, color: Color(0xFF1976D2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatDisplayDate(value),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
                  ),
                ),
              ],
            ),
          ),
          if (readOnly)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Date automatique (non modifiable)', style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E))),
            ),
        ],
      ),
    );
  }

  // ===== Date de modification — grisée en création, active en édition =====
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
              color: _isEditing ? const Color(0xFFF9FAFB) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isEditing ? const Color(0xFFE5E7EB) : const Color(0xFFE0E0E0),
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
                    _isEditing ? 'Sera mise à jour automatiquement' : 'Non modifié',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isEditing ? const Color(0xFF374151) : const Color(0xFF9E9E9E),
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

  // ===== Info polygone — même style que _buildGpsInfo =====
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
          _buildGpsInfoRow('Nombre de sommets:', '${widget.polygonPoints.length} points'),
          _buildGpsInfoRow('Superficie:', '${_superficieHa.toStringAsFixed(4)} ha'),
          _buildGpsInfoRow('Superficie:', '${(_superficieHa * 10000).toStringAsFixed(1)} m²'),
        ],
      ),
    );
  }

  Widget _buildGpsInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF333333),
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
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
            color: Colors.black.withOpacity(0.05),
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
                const Text('Agent enquêteur', style: TextStyle(fontSize: 12, color: Colors.grey)),
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

  @override
  void dispose() {
    if (!_isEditing) disposeDraft();
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
    super.dispose();
  }

  // ── SPRINT 7 : Implémentation FormDraftMixin ──

  @override
  String get draftKey => DraftService.buildDraftKey(
        formType: 'polygon',
        metier: widget.metier ?? 'GeoDNGR',
        entityType: widget.entityType ?? 'Zone de Plaine',
      );

  @override
  Map<String, String> collectFormData() => {
        'nom': _nomController.text,
        'code_gps': _codeGpsController.text,
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
      };

  @override
  Map<int, String?> collectPhotoPaths() => {};

  @override
  void restoreFormData(Map<String, String> data) {
    final mapping = <String, TextEditingController>{
      'nom': _nomController,
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
      if (mapping.containsKey(entry.key)) {
        mapping[entry.key]!.text = entry.value;
      }
    }
  }

  @override
  void restorePhotoPaths(Map<int, String?> photos) {}
}
