import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/forms/point_form_widget.dart';
import '../../data/local/piste_storage_helper.dart';

class SpecialLineFormPage extends StatefulWidget {
  final List<LatLng> linePoints;
  final String? provisionalCode;
  final DateTime startTime;
  final DateTime endTime;
  final String agentName;
  final String specialType;
  final double totalDistance;
  final String? activePisteCode; // ← PARAMÈTRE AJOUTÉ

  const SpecialLineFormPage({
    super.key,
    required this.linePoints,
    required this.provisionalCode,
    required this.startTime,
    required this.endTime,
    required this.agentName,
    required this.specialType,
    required this.totalDistance,
    this.activePisteCode, // ← PARAMÈTRE AJOUTÉ
  });

  @override
  State<SpecialLineFormPage> createState() => _SpecialLineFormPageState();
}

class _SpecialLineFormPageState extends State<SpecialLineFormPage> {
  String? _nearestPisteCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _findNearestPiste();
  }

  Future<void> _findNearestPiste() async {
    try {
      final firstPoint = widget.linePoints.first;
      String? nearestCode;

      // ⭐⭐ LOGIQUE IDENTIQUE AUX CHAUSSÉES ⭐⭐
      print('🔍 Recherche piste pour spécial - Même logique que chaussées');

      // 1. UTILISER DIRECTEMENT le code actif si fourni
      if (widget.activePisteCode != null && widget.activePisteCode!.isNotEmpty) {
        nearestCode = widget.activePisteCode;
        print('✅ Utilisation piste active: $nearestCode');
      }
      // 2. SINON utiliser le code provisoire (déjà calculé avec la même logique)
      else if (widget.provisionalCode != null && widget.provisionalCode!.isNotEmpty) {
        nearestCode = widget.provisionalCode;
        print('✅ Utilisation code provisoire: $nearestCode');
      }
      // 3. FALLBACK : recherche géographique
      else {
        print('🔍 Recherche géographique de piste...');
        nearestCode = await PisteStorageHelper().findNearestPisteCode(firstPoint);
        print('📍 Piste la plus proche trouvée: $nearestCode');
      }

      setState(() {
        _nearestPisteCode = nearestCode;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Erreur recherche piste: $e');
      setState(() {
        _nearestPisteCode = widget.provisionalCode;
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _prepareFormData() {
    final firstPoint = widget.linePoints.first;
    final lastPoint = widget.linePoints.last;

    print('📍 Premier point: ${firstPoint.latitude}, ${firstPoint.longitude}');
    print('📍 Dernier point: ${lastPoint.latitude}, ${lastPoint.longitude}');
    print('📍 Distance: ${widget.totalDistance}m');
    print('📍 Code Piste final: $_nearestPisteCode');

    return {
      'id': null,
      'latitude': firstPoint.latitude,
      'longitude': firstPoint.longitude,
      'latitude_debut': firstPoint.latitude,
      'longitude_debut': firstPoint.longitude,
      'latitude_fin': lastPoint.latitude,
      'longitude_fin': lastPoint.longitude,
      'distance': widget.totalDistance,
      'code_piste': _nearestPisteCode,
      'date_creation': DateTime.now().toIso8601String(),
      'enqueteur': widget.agentName,
      'nom': null,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
              ),
              const SizedBox(height: 20),
              Text(
                'Recherche de la piste la plus proche...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final formData = _prepareFormData();

    return Scaffold(
      body: PointFormWidget(
        category: "Ouvrages",
        type: widget.specialType,
        pointData: formData,
        onBack: () {
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
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text("Abandonner"),
                ),
              ],
            ),
          );
        },
        onSaved: () {
          Navigator.of(context).pop(true);
        },
        agentName: widget.agentName,
        nearestPisteCode: _nearestPisteCode,
        isSpecialLine: true,
      ),
    );
  }
}
