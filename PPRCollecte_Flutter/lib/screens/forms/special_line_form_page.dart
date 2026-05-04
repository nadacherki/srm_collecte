import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/local/database_helper.dart';
import '../../data/local/line_storage_helper.dart';

class SpecialLineFormPage extends StatefulWidget {
  final List<LatLng> linePoints;
  final String? provisionalCode;
  final DateTime startTime;
  final DateTime endTime;
  final String agentName;
  final String specialType;
  final double totalDistance;
  final String? activeLineCode;

  const SpecialLineFormPage({
    super.key,
    required this.linePoints,
    required this.provisionalCode,
    required this.startTime,
    required this.endTime,
    required this.agentName,
    required this.specialType,
    required this.totalDistance,
    this.activeLineCode,
  });

  @override
  State<SpecialLineFormPage> createState() => _SpecialLineFormPageState();
}

class _SpecialLineFormPageState extends State<SpecialLineFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _watercourseController = TextEditingController();

  String? _nearestLineCode;
  String? _selectedTypeValue;
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<String> _bacTypes = ['Manuel', 'Motorise'];
  static const List<String> _submersibleTypes = [
    'beton',
    'bloc de pierre',
    'gabion',
    'autre',
  ];

  bool get _isBac => widget.specialType == 'Bac';

  List<String> get _typeOptions => _isBac ? _bacTypes : _submersibleTypes;

  String get _tableName => _isBac ? 'bacs' : 'passages_submersibles';

  @override
  void initState() {
    super.initState();
    _findNearestLine();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _watercourseController.dispose();
    super.dispose();
  }

  Future<void> _findNearestLine() async {
    try {
      final firstPoint = widget.linePoints.first;
      String? nearestCode;

      if (widget.activeLineCode != null && widget.activeLineCode!.isNotEmpty) {
        nearestCode = widget.activeLineCode;
      } else if (widget.provisionalCode != null &&
          widget.provisionalCode!.isNotEmpty) {
        nearestCode = widget.provisionalCode;
      } else {
        nearestCode = await LineStorageHelper().findNearestLineCode(firstPoint);
      }

      if (!mounted) return;
      setState(() {
        _nearestLineCode = nearestCode;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearestLineCode = widget.provisionalCode;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final dbHelper = DatabaseHelper();
      final loginId = await dbHelper.resolveLoginId();
      if (loginId == null) {
        throw Exception('login_id introuvable');
      }

      final firstPoint = widget.linePoints.first;
      final lastPoint = widget.linePoints.last;
      final now = DateTime.now().toIso8601String();

      final data = <String, dynamic>{
        'nom': _nameController.text.trim().isEmpty
            ? widget.specialType
            : _nameController.text.trim(),
        'line_code': _nearestLineCode,
        'enqueteur': widget.agentName,
        'date_creation': now,
        'id_agent_crea': loginId,
        'login_id': loginId,
        'synced': 0,
        'downloaded': 0,
      };

      if (_isBac) {
        data.addAll({
          'type_bac': _selectedTypeValue,
          'nom_cours_eau': _watercourseController.text.trim(),
          'x_debut_traversee_bac': firstPoint.longitude,
          'y_debut_traversee_bac': firstPoint.latitude,
          'x_fin_traversee_bac': lastPoint.longitude,
          'y_fin_traversee_bac': lastPoint.latitude,
        });
      } else {
        data.addAll({
          'type_materiau': _selectedTypeValue,
          'x_debut_passage_submersible': firstPoint.longitude,
          'y_debut_passage_submersible': firstPoint.latitude,
          'x_fin_passage_submersible': lastPoint.longitude,
          'y_fin_passage_submersible': lastPoint.latitude,
        });
      }

      await dbHelper.insertEntityLocal(
        _tableName,
        data,
        recordHistory: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur sauvegarde: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmCancel() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner la saisie ?'),
        content: const Text('Les données non sauvegardées seront perdues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.specialType),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _confirmCancel,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Code ligne',
                border: OutlineInputBorder(),
              ),
              child: Text(_nearestLineCode ?? 'Non spécifié'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedTypeValue,
              items: _typeOptions
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedTypeValue = value),
              decoration: InputDecoration(
                labelText: _isBac ? 'Type de bac' : 'Type de matériau',
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Champ requis' : null,
            ),
            if (_isBac) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _watercourseController,
                decoration: const InputDecoration(
                  labelText: 'Nom du cours d\'eau',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Distance',
                border: OutlineInputBorder(),
              ),
              child: Text('${widget.totalDistance.toStringAsFixed(2)} m'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
