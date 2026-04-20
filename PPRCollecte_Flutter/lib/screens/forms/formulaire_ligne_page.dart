import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../../data/local/line_storage_helper.dart';
import '../../data/local/database_helper.dart';

class FormulaireLignePage extends StatefulWidget {
  final List<LatLng> linePoints;
  final String? provisionalCode;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? agentName;
  final Map<String, dynamic>? initialData;
  final bool isEditingMode;

  const FormulaireLignePage({
    super.key,
    required this.linePoints,
    this.provisionalCode,
    this.startTime,
    this.endTime,
    this.agentName,
    this.initialData,
    this.isEditingMode = false,
  });

  @override
  State<FormulaireLignePage> createState() => _FormulairePageState();
}

class _FormulairePageState extends State<FormulaireLignePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Champs du formulaire selon le MCD
  final _codeController = TextEditingController();
  final _nomOrigineController = TextEditingController();
  final _nomDestinationController = TextEditingController();
  final _xOrigineController = TextEditingController();
  final _yOrigineController = TextEditingController();
  final _xDestinationController = TextEditingController();
  final _yDestinationController = TextEditingController();
  final _userLoginController = TextEditingController();
  final _heureDebutController = TextEditingController();
  final _heureFinController = TextEditingController();
  final _entrepriseController = TextEditingController();
  final _travauxRealisesController = TextEditingController();

  // Évaluation et Priorisation
  final _niveauServiceController = TextEditingController();
  final _fonctionnaliteController = TextEditingController();
  final _interetSocioAdminController = TextEditingController();
  final _populationDesservieController = TextEditingController();
  final _potentielAgricoleController = TextEditingController();
  final _coutInvestissementController = TextEditingController();
  final _protectionEnvController = TextEditingController();
// ===== CHAMPS TERRAIN =====
  final _plateformeController = TextEditingController();
  final _reliefController = TextEditingController();
  final _vegetationController = TextEditingController();

  final _financementController = TextEditingController();
  final _projetController = TextEditingController();
  double _noteGlobale = 0.0;
  DateTime? _debutTravaux;
  DateTime? _finTravaux;

  DateTime? _dateDebutTravaux;
  DateTime? _dateCreation; // ← NOUVEAU
  DateTime? _dateModification;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _setupNoteGlobaleListeners();
    _setupAutoCapitalize();
  }

  /// Nettoie les valeurs d'évaluation : si 0.0 ou null → vide (pour que le hint s'affiche)
  String _cleanEvalValue(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    if (s.isEmpty || s == '0.0' || s == '0' || s == 'null') return '';
    return s;
  }

  void _setupNoteGlobaleListeners() {
    final controllers = [
      _niveauServiceController,
      _fonctionnaliteController,
      _interetSocioAdminController,
      _populationDesservieController,
      _potentielAgricoleController,
      _coutInvestissementController,
      _protectionEnvController,
    ];

    for (var controller in controllers) {
      controller.addListener(_calculateNoteGlobale);
    }
  }

  void _setupAutoCapitalize() {
    final textControllers = [
      _nomOrigineController,
      _nomDestinationController,
      _entrepriseController,
      _travauxRealisesController,
      _plateformeController,
      _reliefController,
      _vegetationController,
      _financementController,
      _projetController,
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

  void _calculateNoteGlobale() {
    double ns = double.tryParse(_niveauServiceController.text) ?? 0.0;
    double fo = double.tryParse(_fonctionnaliteController.text) ?? 0.0;
    double isa = double.tryParse(_interetSocioAdminController.text) ?? 0.0;
    double p = double.tryParse(_populationDesservieController.text) ?? 0.0;
    double pa = double.tryParse(_potentielAgricoleController.text) ?? 0.0;
    double ci = double.tryParse(_coutInvestissementController.text) ?? 0.0;
    double pe = double.tryParse(_protectionEnvController.text) ?? 0.0;

    setState(() {
      _noteGlobale = (0.05 * ns) + (0.05 * fo) + (0.15 * isa) + (0.20 * p) + (0.30 * pa) + (0.20 * ci) + (0.05 * pe);
    });
  }

  void _initializeForm() {
    if (widget.isEditingMode && widget.initialData != null) {
      _fillFormWithExistingData();
    }
    if (widget.provisionalCode != null) {
      _codeController.text = widget.provisionalCode!;
    }

    // Récupérer automatiquement l'utilisateur connecté et l'heure actuelle
    _userLoginController.text = widget.agentName ?? _getCurrentUser(); // À implémenter selon votre système d'auth
    // Date de création = maintenant par défaut
    _dateCreation = DateTime.now();

    // Date de modification = maintenant (automatique)
    _dateModification = null;
    if (widget.startTime != null) {
      final startTime = TimeOfDay.fromDateTime(widget.startTime!);
      _heureDebutController.text = "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";
    } else {
      // Fallback : heure actuelle
      final now = TimeOfDay.now();
      _heureDebutController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    }

    // 🚀 NOUVEAU : Heure de fin automatique
    if (widget.endTime != null) {
      final endTime = TimeOfDay.fromDateTime(widget.endTime!);
      _heureFinController.text = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";
    } else {
      // Cas exceptionnel : utiliser l'heure actuelle comme fallback
      final now = TimeOfDay.now();
      _heureFinController.text = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    }

    // Calculer et remplir automatiquement les coordonnées d'origine et destination
    if (widget.linePoints.isNotEmpty) {
      final firstPoint = widget.linePoints.first;
      final lastPoint = widget.linePoints.last;

      _xOrigineController.text = firstPoint.longitude.toStringAsFixed(6);
      _yOrigineController.text = firstPoint.latitude.toStringAsFixed(6);
      _xDestinationController.text = lastPoint.longitude.toStringAsFixed(6);
      _yDestinationController.text = lastPoint.latitude.toStringAsFixed(6);
    }
  }

  void _fillFormWithExistingData() {
    final data = widget.initialData!;

    setState(() {
      _codeController.text = data['line_code'] ?? '';
      _userLoginController.text = data['user_login'] ?? '';
      _heureDebutController.text = data['start_time'] ?? '';
      _heureFinController.text = data['end_time'] ?? '';
      _nomOrigineController.text = data['origin_name'] ?? '';
      _xOrigineController.text = data['origin_x']?.toString() ?? '';
      _yOrigineController.text = data['origin_y']?.toString() ?? '';
      _nomDestinationController.text = data['destination_name'] ?? '';
      _xDestinationController.text = data['destination_x']?.toString() ?? '';
      _yDestinationController.text = data['destination_y']?.toString() ?? '';
      _travauxRealisesController.text = data['completed_works'] ?? '';
      _dateDebutTravaux = data['work_date'] != null ? DateTime.parse(data['work_date']) : null;
      _entrepriseController.text = data['company'] ?? '';
      _dateCreation = data['created_at'] != null ? DateTime.parse(data['created_at']) : null;
      _dateModification = DateTime.now(); // ← Date modif actuelle

      _niveauServiceController.text = _cleanEvalValue(data['service_level']);
      _fonctionnaliteController.text = _cleanEvalValue(data['fonctionnalite']);
      _interetSocioAdminController.text = _cleanEvalValue(data['socio_administrative_interest']);
      _populationDesservieController.text = _cleanEvalValue(data['served_population']);
      _potentielAgricoleController.text = _cleanEvalValue(data['agricultural_potential']);
      _coutInvestissementController.text = _cleanEvalValue(data['investment_cost']);
      _protectionEnvController.text = _cleanEvalValue(data['environmental_protection']);
      _noteGlobale = data['global_score']?.toDouble() ?? 0.0;
      // ===== CHAMPS TERRAIN =====
      _plateformeController.text = data['platform'] ?? '';
      _reliefController.text = data['relief'] ?? '';
      _vegetationController.text = data['vegetation'] ?? '';
      _debutTravaux = (data['work_start'] != null && data['work_start'].toString().isNotEmpty) ? DateTime.tryParse(data['work_start'].toString()) : null;
      _finTravaux = (data['work_end'] != null && data['work_end'].toString().isNotEmpty) ? DateTime.tryParse(data['work_end'].toString()) : null;
      _financementController.text = data['funding'] ?? '';
      _projetController.text = data['project'] ?? '';
    });
  }

  // Méthode pour récupérer l'utilisateur actuel
  String _getCurrentUser() {
    // je vais complèter ça après

    return 'user_demo'; // Valeur temporaire pour test
  }

  double _calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _distanceBetween(points[i], points[i + 1]);
    }
    return total;
  }

  double _distanceBetween(LatLng point1, LatLng point2) {
    // Formule de Haversine
    const double p = 0.017453292519943295; // pi/180

    final dLat = (point2.latitude - point1.latitude) * p;
    final dLon = (point2.longitude - point1.longitude) * p;

    final a = sin(dLat / 2) * sin(dLat / 2) + cos(point1.latitude * p) * cos(point2.latitude * p) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return 6371000 * c; // Rayon de la Terre en mètres
  }

  Future<DateTime?> _showDatePickerWithValidation(BuildContext context, DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      selectableDayPredicate: (DateTime day) {
        // Bloquer les dates passées
        return !day.isBefore(DateTime.now().subtract(const Duration(days: 1)));
      },
      builder: (BuildContext _, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1976D2), // Couleur principale
              onPrimary: Colors.white,
            ), dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final DateTime? picked = await _showDatePickerWithValidation(context, DateTime.now());
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _dateDebutTravaux = picked;
      });
    }
  }


  Future<void> _selectTravauxDate(BuildContext context, bool isStart) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final DateTime? picked = await _showDatePickerWithValidation(context, DateTime.now());
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        if (isStart) {
          _debutTravaux = picked;
        } else {
          _finTravaux = picked;
        }
      });
    }
  }

  Future<void> _saveLine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 1));
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();

      if (loginId == null) {
        debugPrint('❌ [_saveLine] Impossible de déterminer login_id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de déterminer l’utilisateur (login_id).'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final lineData = {
        // ✅ L'ID sera auto-généré par la BDD, ne pas l'inclure ici
        if (widget.isEditingMode) 'id': widget.initialData!['id'],
        'line_code': _codeController.text,
        'user_login': widget.agentName,
        'start_time': _heureDebutController.text,
        'end_time': _heureFinController.text,
        'origin_name': _nomOrigineController.text,
        'destination_name': _nomDestinationController.text,
        'completed_works': _travauxRealisesController.text.isNotEmpty ? _travauxRealisesController.text : null,
        'work_date': _dateDebutTravaux?.toIso8601String(),
        'company': _entrepriseController.text.isNotEmpty ? _entrepriseController.text : null,
        'service_level': double.tryParse(_niveauServiceController.text),
        'fonctionnalite': double.tryParse(_fonctionnaliteController.text),
        'socio_administrative_interest': double.tryParse(_interetSocioAdminController.text),
        'served_population': double.tryParse(_populationDesservieController.text),
        'agricultural_potential': double.tryParse(_potentielAgricoleController.text),
        'investment_cost': double.tryParse(_coutInvestissementController.text),
        'environmental_protection': double.tryParse(_protectionEnvController.text),
        'global_score': _noteGlobale,
        // ===== CHAMPS TERRAIN =====
        'platform': _plateformeController.text.isNotEmpty ? _plateformeController.text : null,
        'relief': _reliefController.text.isNotEmpty ? _reliefController.text : null,
        'vegetation': _vegetationController.text.isNotEmpty ? _vegetationController.text : null,
        'work_start': _debutTravaux?.toIso8601String(),
        'work_end': _finTravaux?.toIso8601String(),
        'funding': _financementController.text.isNotEmpty ? _financementController.text : null,
        'project': _projetController.text.isNotEmpty ? _projetController.text : null,

        // ✅ TOUS les points de la ligne (MultiLineString)
        'points': widget.linePoints
            .map((p) => {
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                })
            .toList(),

        // Coordonnées extraites depuis les points de la ligne
        'origin_x': widget.linePoints.first.longitude,
        'origin_y': widget.linePoints.first.latitude,
        'destination_x': widget.linePoints.last.longitude,
        'destination_y': widget.linePoints.last.latitude,

        // ✅ Dates
        'created_at': widget.initialData != null ? widget.initialData!['created_at'] : DateTime.now().toIso8601String(),
        'updated_at': widget.initialData != null
            ? DateTime.now().toIso8601String() // seulement si modification
            : null,
        'is_editing': widget.isEditingMode,

        'sync_status': 'pending',
        'login_id': loginId,
      };
      final storageHelper = LineStorageHelper();
      if (widget.isEditingMode) {
        await storageHelper.updateLine(lineData);
        debugPrint('✅ Ligne "${lineData['line_code']}" mise à jour (ID: ${lineData['id']})');
      } else {
        final savedId = await storageHelper.saveLine(lineData);
        if (savedId != null) {
          debugPrint('✅ Ligne sauvegardée en local avec ID: $savedId');
          await storageHelper.debugPrintAllLines();
          await storageHelper.saveDisplayedLine(_codeController.text, widget.linePoints, Colors.blue, 4.0);
        }
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
              'Ligne "${_nomOrigineController.text} → ${_nomDestinationController.text}" enregistrée avec succès\n'
              'Code ligne: ${_codeController.text}\n'
              'Origine: ${widget.linePoints.first.latitude.toStringAsFixed(6)}, ${widget.linePoints.first.longitude.toStringAsFixed(6)}\n'
              'Destination: ${widget.linePoints.last.latitude.toStringAsFixed(6)}, ${widget.linePoints.last.longitude.toStringAsFixed(6)}\n'
              'Nombre de points: ${widget.linePoints.length}',
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
          Navigator.of(context).pop(lineData);
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateModification(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateModification ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _dateModification = picked;
      });
    }
  }


  void _confirmExit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Abandonner la saisie ?"),
        content: const Text("Les données non sauvegardées seront perdues."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(this.context).pop(false);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Abandonner"),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr de vouloir effacer tous les champs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performClear();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  void _performClear() {
    setState(() {
      // Réinitialiser seulement les champs modifiables
      _nomOrigineController.clear();
      _entrepriseController.clear();
      _travauxRealisesController.clear();
      _niveauServiceController.clear();
      _fonctionnaliteController.clear();
      _interetSocioAdminController.clear();
      _populationDesservieController.clear();
      _potentielAgricoleController.clear();
      _coutInvestissementController.clear();
      _protectionEnvController.clear();
      _noteGlobale = 0.0;
      // ===== CHAMPS TERRAIN =====
      _plateformeController.clear();
      _reliefController.clear();
      _vegetationController.clear();
      _debutTravaux = null;
      _finTravaux = null;
      _financementController.clear();
      _projetController.clear();

      _dateDebutTravaux = null;

      // Garder les champs en lecture seule (ils seront réinitialisés automatiquement)
      // _codeController - Garder le code ligne
      // _userLoginController - Garder le nom de l'agent
      // _heureDebutController - Garder l'heure de début
      // _heureFinController - Garder l'heure de fin
      // _xOrigineController - Garder les coordonnées
      // _yOrigineController - Garder les coordonnées
      // _xDestinationController - Garder les coordonnées
      // _yDestinationController - Garder les coordonnées
      // _dateCreation - Garder la date de création
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formulaire effacé'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nomOrigineController.dispose();
    _nomDestinationController.dispose();
    _xOrigineController.dispose();
    _yOrigineController.dispose();
    _xDestinationController.dispose();
    _yDestinationController.dispose();
    _userLoginController.dispose();
    _heureDebutController.dispose();
    _heureFinController.dispose();
    _entrepriseController.dispose();
    _travauxRealisesController.dispose();
    _niveauServiceController.dispose();
    _fonctionnaliteController.dispose();
    _interetSocioAdminController.dispose();
    _populationDesservieController.dispose();
    _potentielAgricoleController.dispose();
    _coutInvestissementController.dispose();
    _protectionEnvController.dispose();
    _plateformeController.dispose();
    _reliefController.dispose();
    _vegetationController.dispose();
    _financementController.dispose();
    _projetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // Remplacer tout le header actuel par ceci :
// Header du formulaire - Style React Native
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1976D2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _confirmExit(), // ← On va créer cette méthode
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    padding: const EdgeInsets.all(8),
                  ),
                  const Expanded(
                    child: Text(
                      "🛤️ Formulaire Ligne",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
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
                  ), // Équilibrer avec le bouton back
                ],
              ),
            ),

            // Contenu du formulaire
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Section Identification
                    _buildFormSection(
                      title: '🏷️ Identification',
                      children: [
                        // ⭐ Code ligne - Affichage conditionnel
                        Builder(builder: (_) {
                          final String lineCode = _codeController.text;
                          final bool isTemporary = lineCode.isEmpty || lineCode.startsWith('Line_0_0_0_') || lineCode.startsWith('TEMP_');

                          if (isTemporary) {
                            // CAS 1 : Temporaire → message vert
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.sync, size: 20, color: Color(0xFF4CAF50)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Code ligne',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF388E3C),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Le code officiel sera attribué automatiquement lors de la synchronisation',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // CAS 2 : Officiel → afficher normalement
                            return _buildTextField(
                              controller: _codeController,
                              label: 'Code ligne',
                              hint: 'Code unique de la ligne',
                              required: false,
                              enabled: false,
                            );
                          }
                        }),
                        _buildDateCreationField(),
                        _buildDateModificationField(),
                        // Remplacer le TextField "Utilisateur" par :
                        _buildReadOnlyField(
                          label: 'Agent enquêteur',
                          icon: Icons.person,
                          value: _userLoginController.text,
                        ),
                        //  la section des heures - les deux en lecture seule
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeField(
                                label: 'Heure Début',
                                controller: _heureDebutController,
                                enabled: false, // 🔒 Lecture seule
                                // onTap supprimé car non nécessaire
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTimeField(
                                label: 'Heure Fin',
                                controller: _heureFinController,
                                enabled: false, // 🔒 Lecture seule
                                // onTap supprimé car non nécessaire
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Section Points
                    _buildFormSection(
                      title: '🎯 Points de la ligne',
                      children: [
                        _buildTextField(
                          controller: _nomOrigineController,
                          label: 'Nom Origine *',
                          hint: 'Point de départ de la ligne',
                          required: true,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _xOrigineController,
                                label: 'X Origine',
                                hint: 'Longitude origine',
                                keyboardType: TextInputType.number,
                                enabled: false, // CORRECTION : Lecture seule
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _yOrigineController,
                                label: 'Y Origine',
                                hint: 'Latitude origine',
                                keyboardType: TextInputType.number,
                                enabled: false, // CORRECTION : Lecture seule
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _nomDestinationController,
                          label: 'Nom Destination *',
                          hint: 'Point d\'arrivée de la ligne',
                          required: true,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _xDestinationController,
                                label: 'X Destination',
                                hint: 'Longitude destination',
                                keyboardType: TextInputType.number,
                                enabled: false, // CORRECTION : Lecture seule
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _yDestinationController,
                                label: 'Y Destination',
                                hint: 'Latitude destination',
                                keyboardType: TextInputType.number,
                                enabled: false, // CORRECTION : Lecture seule
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),


                    // Section Évaluation et Priorisation
                    _buildFormSection(
                      title: '📊 Évaluation et Priorisation',
                      children: [
                        _buildEvaluationField(
                          controller: _niveauServiceController,
                          label: 'Niveau de service (NS)',
                        ),
                        _buildEvaluationField(
                          controller: _fonctionnaliteController,
                          label: 'Fonctionnalité (FO)',
                        ),
                        _buildEvaluationField(
                          controller: _interetSocioAdminController,
                          label: 'Intérêt socio-administratif (ISA)',
                        ),
                        _buildEvaluationField(
                          controller: _populationDesservieController,
                          label: 'Population desservie (P)',
                        ),
                        _buildEvaluationField(
                          controller: _potentielAgricoleController,
                          label: 'Potentiel agricole (PA)',
                        ),
                        _buildEvaluationField(
                          controller: _coutInvestissementController,
                          label: 'Coût d’investissement (CI)',
                        ),
                        _buildEvaluationField(
                          controller: _protectionEnvController,
                          label: 'Protection de l’environnement (PE)',
                        ),
                        const Divider(height: 32, thickness: 1, color: Colors.blueAccent),
                        _buildReadOnlyField(
                          label: 'Note Globale (NG)',
                          icon: Icons.star,
                          value: _noteGlobale.toStringAsFixed(2),
                        ),
                      ],
                    ),

                    // Section Travaux
                    _buildFormSection(
                      title: '🔧 Travaux',
                      children: [
                        _buildTextField(
                          controller: _travauxRealisesController,
                          label: 'Travaux réalisés',
                          hint: 'Description des travaux réalisés',
                          maxLines: 3,
                        ),
                        _buildDateField(
                          label: 'Date des Travaux',
                          value: _dateDebutTravaux,
                          onTap: () => _selectDate(context),
                        ),
                        _buildTextField(
                          controller: _entrepriseController,
                          label: 'Entreprise',
                          hint: 'Nom de l\'entreprise',
                        ),
                      ],
                    ),
// Section Caractéristiques Terrain
                    _buildFormSection(
                      title: '🌍 Caractéristiques Terrain',
                      children: [
                        _buildTextField(
                          controller: _plateformeController,
                          label: 'Plateforme',
                          hint: 'Ex: Latérite, Terre, Sable...',
                        ),
                        _buildTextField(
                          controller: _reliefController,
                          label: 'Relief',
                          hint: 'Ex: Plat, Vallonné, Montagneux...',
                        ),
                        _buildTextField(
                          controller: _vegetationController,
                          label: 'Végétation',
                          hint: 'Ex: Savane, Forêt, Steppe...',
                        ),
                        _buildTextField(
                          controller: _financementController,
                          label: 'Financement',
                          hint: 'Source de financement',
                        ),
                        _buildTextField(
                          controller: _projetController,
                          label: 'Projet',
                          hint: 'Nom du projet',
                        ),
                        _buildDateField(
                          label: 'Début des travaux',
                          value: _debutTravaux,
                          onTap: () => _selectTravauxDate(context, true),
                        ),
                        _buildDateField(
                          label: 'Fin des travaux',
                          value: _finTravaux,
                          onTap: () => _selectTravauxDate(context, false),
                        ),
                      ],
                    ),
                    // Section GPS
                    _buildFormSection(
                      title: '📍 Géolocalisation',
                      children: [
                        _buildGpsInfo(),
                      ],
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),

            // Bouton Sauvegarder
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveLine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Enregistrer la ligne',
                              style: TextStyle(
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
    );
  }


  Widget _buildReadOnlyField({
    required String label,
    required IconData icon,
    required String value,
  }) {
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
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
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

  Widget _buildDateCreationField() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date de création *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB), // ← Même couleur que les champs normaux
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Color(0xFF1976D2)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _dateCreation != null
                        ? "${_dateCreation!.day.toString().padLeft(2, '0')}/${_dateCreation!.month.toString().padLeft(2, '0')}/${_dateCreation!.year} "
                            "${_dateCreation!.hour.toString().padLeft(2, '0')}:${_dateCreation!.minute.toString().padLeft(2, '0')}" // ← Ajouter l'heure
                        : "Date/heure automatique",
                    style: TextStyle(
                      fontSize: 14,
                      color: _dateCreation != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
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

  Widget _buildDateModificationField() {
    final bool isCreation = !widget.isEditingMode; // ✅ Vrai si mode création

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
              color: isCreation ? Colors.grey : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isCreation
                ? null // ✅ Désactivé en création
                : () => _selectDateModification(context),
            child: Container(
              decoration: BoxDecoration(
                color: isCreation ? const Color(0xFFF5F5F5) : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCreation ? const Color(0xFFE0E0E0) : const Color(0xFFE5E7EB),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: isCreation ? Colors.grey : const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isCreation
                          ? "Non modifié" // ✅ Texte grisé en création
                          : (_dateModification != null ? "${_dateModification!.day.toString().padLeft(2, '0')}/${_dateModification!.month.toString().padLeft(2, '0')}/${_dateModification!.year}" : "Sélectionner une date"),
                      style: TextStyle(
                        fontSize: 14,
                        color: isCreation
                            ? const Color(0xFF9E9E9E) // ✅ Gris en création
                            : (_dateModification != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection({required String title, required List<Widget> children}) {
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB), // ← TOUJOURS la même couleur
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
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)), // ← Même bordure
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1976D2)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(
              // ← Style du texte
              fontSize: 14,
              color: Color(0xFF374151), // ← Même couleur que les champs normaux
            ),
            textAlignVertical: maxLines > 1 ? TextAlignVertical.top : null,
            validator: required
                ? (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '$label est obligatoire';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20, color: Color(0xFF666666)),
                  const SizedBox(width: 12),
                  Text(
                    value != null ? "${value.day}/${value.month}/${value.year}" : "Sélectionner une date",
                    style: TextStyle(
                      fontSize: 14,
                      color: value != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB), // ← Même couleur de fond
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)), // ← Même bordure
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 20,
                color: enabled ? const Color(0xFF666666) : const Color(0xFF666666), // ← Même couleur d'icône
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  controller.text.isEmpty ? "Heure automatique" : controller.text,
                  style: const TextStyle(
                    // ← Même style de texte
                    fontSize: 14,
                    color: Color(0xFF374151), // ← Même couleur de texte
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGpsInfo() {
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
              Icon(Icons.gps_fixed, size: 20, color: Color(0xFF1976D2)),
              SizedBox(width: 8),
              Text(
                'Tracé GPS collecté',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGpsInfoRow('Points collectés:', '${widget.linePoints.length}'),
          _buildGpsInfoRow('Distance totale:', '${(_calculateTotalDistance(widget.linePoints) / 1000).toStringAsFixed(2)} km'),
          if (widget.linePoints.isNotEmpty) ...[
            _buildGpsInfoRow('Premier point:', '${widget.linePoints.first.latitude.toStringAsFixed(6)}°, ${widget.linePoints.first.longitude.toStringAsFixed(6)}°'),
            _buildGpsInfoRow('Dernier point:', '${widget.linePoints.last.latitude.toStringAsFixed(6)}°, ${widget.linePoints.last.longitude.toStringAsFixed(6)}°'),
          ],
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
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


  Widget _buildEvaluationField({
    required TextEditingController controller,
    required String label,
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Note (0-10)',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final n = double.tryParse(value.trim());
              if (n == null) return 'Veuillez entrer un nombre valide';
              if (n < 0) return 'La note ne peut pas être inférieure à 0';
              if (n > 10) return 'La note ne peut pas dépasser 10';
              return null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ],
      ),
    );
  }
}
