// lib/screens/home/gnss_rover_setup_dialog.dart
//
// Dialog Phase 1+2 de saisie de la configuration GNSS rover :
//   - modele d'antenne (catalogue R0/H0/DH)
//   - hauteur de canne (m)
//   - methode de mesure : Vertical / Slant / Phase Center
//   - ajustement vertical : Aucun / Constante (offset m)
//
// Persistance : DatabaseHelper.app_metadata via GnssConfigService.
// Apres sauvegarde : HomeController.reloadGnssConfig() pour que le prochain
// fix NMEA applique immediatement la nouvelle reduction.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/home_controller.dart';
import '../../core/constants/antenna_catalog.dart';
import '../../services/gnss_config_service.dart';

class GnssRoverSetupDialog extends StatefulWidget {
  final HomeController homeController;

  const GnssRoverSetupDialog({super.key, required this.homeController});

  static Future<void> show(
    BuildContext context, {
    required HomeController homeController,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => GnssRoverSetupDialog(homeController: homeController),
    );
  }

  @override
  State<GnssRoverSetupDialog> createState() => _GnssRoverSetupDialogState();
}

enum _AdjustmentKind { none, constant, plane }

class _GnssRoverSetupDialogState extends State<GnssRoverSetupDialog> {
  late GnssBrand _selectedBrand;
  late String _selectedAntennaKey;
  late TextEditingController _heightController;
  late TextEditingController _offsetController;
  late TextEditingController _planAController;
  late TextEditingController _planBController;
  late TextEditingController _planCController;
  AntennaSurveyType _surveyType = AntennaSurveyType.vertical;
  _AdjustmentKind _adjustmentKind = _AdjustmentKind.none;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = widget.homeController.currentRoverConfig;
    _selectedBrand = current.brand;
    _selectedAntennaKey = current.antenna.key;
    _heightController = TextEditingController(
      text: current.heightMeters.toStringAsFixed(3),
    );
    _surveyType = current.surveyType;
    final adjustment = current.verticalAdjustment;
    _offsetController = TextEditingController(text: '0.000');
    _planAController = TextEditingController(text: '0');
    _planBController = TextEditingController(text: '0');
    _planCController = TextEditingController(text: '0.000');
    if (adjustment is ConstantVerticalAdjustment) {
      _adjustmentKind = _AdjustmentKind.constant;
      _offsetController.text = adjustment.offsetMeters.toStringAsFixed(3);
    } else if (adjustment is InclinedPlaneAdjustment) {
      _adjustmentKind = _AdjustmentKind.plane;
      _planAController.text = adjustment.a.toString();
      _planBController.text = adjustment.b.toString();
      _planCController.text = adjustment.c.toStringAsFixed(3);
    } else {
      _adjustmentKind = _AdjustmentKind.none;
    }
  }

  @override
  void dispose() {
    _heightController.dispose();
    _offsetController.dispose();
    _planAController.dispose();
    _planBController.dispose();
    _planCController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _heightController.text.trim().replaceAll(',', '.');
    final height = double.tryParse(raw);
    if (height == null || height <= 0 || height > 5) {
      setState(() {
        _error = 'Hauteur invalide (saisir entre 0 et 5 m).';
      });
      return;
    }
    final antenna = AntennaCatalog.byKey(_selectedAntennaKey);
    // Defense : l'antenne selectionnee doit appartenir a la marque choisie.
    // Garantit qu'on ne combine pas par accident des constantes CHCNAV avec
    // les formules Tersus (ou vice-versa), ce qui produirait un Z faux.
    if (antenna.brand != _selectedBrand) {
      setState(() {
        _error = 'Modele d\'antenne incompatible avec la marque selectionnee.';
      });
      return;
    }
    // Garde-fou Slant : la hauteur doit etre superieure au rayon antenne,
    // sinon la racine carree n'a pas de sens. Le calcul retombe sur Vertical
    // mais on previent l'utilisateur.
    if (_surveyType == AntennaSurveyType.slant &&
        antenna.r0 > 0 &&
        height <= antenna.r0) {
      setState(() {
        _error = 'Slant : hauteur doit etre > ${antenna.r0.toStringAsFixed(3)} m '
            '(rayon de l\'antenne).';
      });
      return;
    }

    VerticalAdjustment adjustment = const NoVerticalAdjustment();
    if (_adjustmentKind == _AdjustmentKind.constant) {
      final rawOffset = _offsetController.text.trim().replaceAll(',', '.');
      final offset = double.tryParse(rawOffset);
      if (offset == null || offset.abs() > 100) {
        setState(() {
          _error = 'Offset constante invalide (|valeur| <= 100 m).';
        });
        return;
      }
      adjustment = ConstantVerticalAdjustment(offset);
    } else if (_adjustmentKind == _AdjustmentKind.plane) {
      final a = double.tryParse(
        _planAController.text.trim().replaceAll(',', '.'),
      );
      final b = double.tryParse(
        _planBController.text.trim().replaceAll(',', '.'),
      );
      final c = double.tryParse(
        _planCController.text.trim().replaceAll(',', '.'),
      );
      if (a == null || b == null || c == null) {
        setState(() {
          _error = 'Plan incline : coefficients a, b, c invalides.';
        });
        return;
      }
      adjustment = InclinedPlaneAdjustment(a: a, b: b, c: c);
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final config = GnssRoverConfig(
      brand: _selectedBrand,
      antenna: antenna,
      heightMeters: height,
      surveyType: _surveyType,
      verticalAdjustment: adjustment,
    );
    try {
      await GnssConfigService().saveRoverConfig(config);
      await widget.homeController.reloadGnssConfig();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur sauvegarde : $e';
          _saving = false;
        });
      }
    }
  }

  String _surveyTypeLabel(AntennaSurveyType t) {
    switch (t) {
      case AntennaSurveyType.vertical:
        return 'Vertical (canne droite)';
      case AntennaSurveyType.slant:
        return 'Slant (ruban incline vers repere)';
      case AntennaSurveyType.phaseCenter:
        return 'Phase Center (hauteur deja au centre de phase)';
    }
  }

  String _heightLabel() {
    switch (_surveyType) {
      case AntennaSurveyType.vertical:
        return 'Hauteur rover verticale (m)';
      case AntennaSurveyType.slant:
        return 'Hauteur slant SHMP (m)';
      case AntennaSurveyType.phaseCenter:
        return 'Hauteur centre de phase (m)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final antennas = AntennaCatalog.sortedForBrand(_selectedBrand);
    const primaryBlue = Color(0xFF1976D2);
    const skyBlue = Color(0xFF42A5F5);
    const border = Color(0xFFE2E8F0);
    const muted = Color(0xFF64748B);
    final formulaHint = _selectedBrand == GnssBrand.chcnav
        ? 'CHCNAV : Vertical = H + DH ; Slant = sqrt(H² - R0²) - H0 + DH ; '
            'Phase Center = H.'
        : 'Tersus : Vertical = H brut ; Pole / Phase Center = H + AntCenter ; '
            'Slant = |sqrt(H² - R²) + AntCenter - AntBottomHeight|.';
    InputDecoration fieldDecoration(String label, {String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(
          color: muted,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: skyBlue, width: 1.6),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFF1F5F9),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      actionsPadding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          gradient: LinearGradient(
            colors: [primaryBlue, skyBlue],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
              ),
              child: const Icon(
                Icons.satellite_alt,
                color: Colors.white,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuration antenne rover',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Modele, hauteur et ajustement vertical',
                    style: TextStyle(
                      color: Color(0xFFE0F2FE),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: primaryBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Z sol = elevation Merchich(h_ellip - A_apc) + ajustement. $formulaHint',
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GnssBrand>(
              initialValue: _selectedBrand,
              isExpanded: true,
              decoration: fieldDecoration('Marque du rover'),
              items: const [
                DropdownMenuItem(
                  value: GnssBrand.chcnav,
                  child: Text('CHCNAV (LandStar)'),
                ),
                DropdownMenuItem(
                  value: GnssBrand.tersus,
                  child: Text('Tersus (Nuwa)'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null || value == _selectedBrand) return;
                      // Changement de marque : on retombe sur l'antenne par
                      // defaut de la nouvelle marque pour eviter qu'une
                      // antenne CHCNAV reste selectionnee sous formules
                      // Tersus (ou inverse).
                      setState(() {
                        _selectedBrand = value;
                        _selectedAntennaKey =
                            AntennaCatalog.defaultKeyForBrand(value);
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedAntennaKey,
              isExpanded: true,
              decoration: fieldDecoration('Modele d\'antenne'),
              items: antennas
                  .map(
                    (a) => DropdownMenuItem<String>(
                      value: a.key,
                      child: Text(
                        a.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedAntennaKey = value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AntennaSurveyType>(
              initialValue: _surveyType,
              isExpanded: true,
              decoration: fieldDecoration('Methode de mesure'),
              items: AntennaSurveyType.values
                  .map(
                    (t) => DropdownMenuItem<AntennaSurveyType>(
                      value: t,
                      child: Text(
                        _surveyTypeLabel(t),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _surveyType = value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _heightController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: fieldDecoration(_heightLabel(), hint: 'Ex : 1.000'),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Ajustement vertical',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Applique apres la conversion Merchich. Sert a caler un offset '
              'constant (PCO antenne, ecart geoide local non modelise...).',
              style: TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<_AdjustmentKind>(
              initialValue: _adjustmentKind,
              isExpanded: true,
              decoration: fieldDecoration('Type d\'ajustement'),
              items: const [
                DropdownMenuItem(
                  value: _AdjustmentKind.none,
                  child: Text('Aucun'),
                ),
                DropdownMenuItem(
                  value: _AdjustmentKind.constant,
                  child: Text('Constante (offset m)'),
                ),
                DropdownMenuItem(
                  value: _AdjustmentKind.plane,
                  child: Text('Plan incline (a*X + b*Y + c)'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _adjustmentKind = value);
                      }
                    },
            ),
            if (_adjustmentKind == _AdjustmentKind.constant) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _offsetController,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                ],
                decoration: fieldDecoration(
                  'Offset constante (m)',
                  hint: 'Ex : 0.190 ou -0.050',
                ),
              ),
            ],
            if (_adjustmentKind == _AdjustmentKind.plane) ...[
              const SizedBox(height: 8),
              const Text(
                'H_ajuste = H + a*X + b*Y + c (X, Y en m Merchich). '
                'Calibration multi-points : outil prevu en Phase 3.1.',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _planAController,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,eE+\-]'),
                        ),
                      ],
                      decoration: fieldDecoration('a', hint: 'Ex : 1.2e-6'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _planBController,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,eE+\-]'),
                        ),
                      ],
                      decoration: fieldDecoration('b', hint: 'Ex : -8.4e-7'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _planCController,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                ],
                decoration: fieldDecoration('c (m)', hint: 'Ex : 0.250'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: muted,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
