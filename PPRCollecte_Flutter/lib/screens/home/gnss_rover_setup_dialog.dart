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
    final formulaHint = _selectedBrand == GnssBrand.chcnav
        ? 'CHCNAV : Vertical = H + DH ; Slant = sqrt(H² - R0²) - H0 + DH ; '
            'Phase Center = H.'
        : 'Tersus : Vertical = H brut ; Pole / Phase Center = H + AntCenter ; '
            'Slant = |sqrt(H² - R²) + AntCenter - AntBottomHeight|.';
    return AlertDialog(
      title: const Text('Configuration antenne rover'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Z sol = elevation Merchich(h_ellip - A_apc) + ajustement. $formulaHint',
              style: const TextStyle(fontSize: 11.5, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<GnssBrand>(
              initialValue: _selectedBrand,
              decoration: const InputDecoration(
                labelText: 'Marque du rover',
                isDense: true,
                border: OutlineInputBorder(),
              ),
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
              decoration: const InputDecoration(
                labelText: 'Modele d\'antenne',
                isDense: true,
                border: OutlineInputBorder(),
              ),
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
              decoration: const InputDecoration(
                labelText: 'Methode de mesure',
                isDense: true,
                border: OutlineInputBorder(),
              ),
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
              decoration: InputDecoration(
                labelText: _heightLabel(),
                hintText: 'Ex : 1.000',
                isDense: true,
                border: const OutlineInputBorder(),
              ),
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
              decoration: const InputDecoration(
                labelText: 'Type d\'ajustement',
                isDense: true,
                border: OutlineInputBorder(),
              ),
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
                decoration: const InputDecoration(
                  labelText: 'Offset constante (m)',
                  hintText: 'Ex : 0.190 ou -0.050',
                  isDense: true,
                  border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        labelText: 'a',
                        hintText: 'Ex : 1.2e-6',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
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
                      decoration: const InputDecoration(
                        labelText: 'b',
                        hintText: 'Ex : -8.4e-7',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
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
                decoration: const InputDecoration(
                  labelText: 'c (m)',
                  hintText: 'Ex : 0.250',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
