// lib/services/gnss_config_service.dart
//
// Configuration GNSS rover (modele d'antenne, hauteur, methode de mesure,
// ajustement vertical). Persistance via DatabaseHelper.app_metadata pour
// survivre aux relances de l'app et aux changements de session.
//
// Phase 1 : methode Vertical seule + reduction A = H + DH.
// Phase 2 : methode Slant (V = sqrt(SHMP² - R0²) - H0 + DH), methode
//   Phase Center directe, ajustement vertical Constante (calibration sur
//   point connu).
// Phase 3 : ajustement vertical Geoide (.ggf) + Plan incline / surface
//   fitting (futurs sous-types de VerticalAdjustment).

import 'dart:math' as math;

import '../core/constants/antenna_catalog.dart';
import '../data/local/database_helper.dart';

/// Ajustement vertical applique a l'elevation locale (Merchich).
/// Sealed pour expansion claire en Phase 3 (Geoide bilineaire, surface
/// fitting...). En Phase 3.A : None + Constante + Plan incline.
sealed class VerticalAdjustment {
  const VerticalAdjustment();

  /// Applique l'ajustement sur une elevation deja en datum local.
  /// Les coordonnees [x] et [y] (Merchich, en metres) ne sont consommees
  /// que par les sous-types qui en dependent (Plan incline, surface).
  double apply(double localElevation, {double x = 0, double y = 0});

  String get displayName;

  /// Forme texte pour persistance dans app_metadata.
  String serialize();

  /// Parse la forme persistee. Tolerant : un format inconnu retombe sur
  /// l'absence d'ajustement (None).
  static VerticalAdjustment deserialize(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty || value == 'none') {
      return const NoVerticalAdjustment();
    }
    final parts = value.split(':');
    if (parts.first == 'constant' && parts.length >= 2) {
      final offset = double.tryParse(parts[1].replaceAll(',', '.'));
      if (offset != null) {
        return ConstantVerticalAdjustment(offset);
      }
    }
    if (parts.first == 'plane' && parts.length >= 2) {
      final coefs = parts[1].split(',');
      if (coefs.length >= 3) {
        final a = double.tryParse(coefs[0].replaceAll(',', '.'));
        final b = double.tryParse(coefs[1].replaceAll(',', '.'));
        final c = double.tryParse(coefs[2].replaceAll(',', '.'));
        if (a != null && b != null && c != null) {
          return InclinedPlaneAdjustment(a: a, b: b, c: c);
        }
      }
    }
    return const NoVerticalAdjustment();
  }
}

class NoVerticalAdjustment extends VerticalAdjustment {
  const NoVerticalAdjustment();

  @override
  double apply(double localElevation, {double x = 0, double y = 0}) =>
      localElevation;

  @override
  String get displayName => 'Aucun';

  @override
  String serialize() => 'none';
}

class ConstantVerticalAdjustment extends VerticalAdjustment {
  final double offsetMeters;

  const ConstantVerticalAdjustment(this.offsetMeters);

  @override
  double apply(double localElevation, {double x = 0, double y = 0}) =>
      localElevation + offsetMeters;

  @override
  String get displayName =>
      'Constante (${offsetMeters.toStringAsFixed(3)} m)';

  @override
  String serialize() => 'constant:${offsetMeters.toStringAsFixed(6)}';
}

/// Plan incline : H_local_ajuste = H + a*X + b*Y + c
/// Adapte aux chantiers ou un calage 3+ points montre que l'ecart Z varie
/// lineairement avec la position. Les coefficients (a, b, c) sont en
/// general issus d'un calcul moindres carres sur des points connus ; la
/// saisie directe (a, b, c) est exposee dans l'UI Phase 3, l'outil de
/// calibration multi-points est prevu en Phase 3.1.
class InclinedPlaneAdjustment extends VerticalAdjustment {
  final double a;
  final double b;
  final double c;

  const InclinedPlaneAdjustment({
    required this.a,
    required this.b,
    required this.c,
  });

  @override
  double apply(double localElevation, {double x = 0, double y = 0}) =>
      localElevation + a * x + b * y + c;

  @override
  String get displayName => 'Plan incline (a*X + b*Y + c)';

  @override
  String serialize() => 'plane:'
      '${a.toStringAsExponential(9)},'
      '${b.toStringAsExponential(9)},'
      '${c.toStringAsFixed(6)}';
}

class GnssRoverConfig {
  final GnssBrand brand;
  final AntennaConstants antenna;
  final double heightMeters;
  final AntennaSurveyType surveyType;
  final VerticalAdjustment verticalAdjustment;

  const GnssRoverConfig({
    required this.brand,
    required this.antenna,
    required this.heightMeters,
    required this.surveyType,
    this.verticalAdjustment = const NoVerticalAdjustment(),
  });

  /// Decalage vertical (en m) a soustraire au Z du centre de phase pour
  /// obtenir le Z du point sol. Les formules different selon la marque
  /// du rover (cf. memory/project_gnss_brand_z_chain.md).
  ///
  /// CHCNAV (process LandStar) :
  ///   Vertical    : A = H + DH
  ///   PhaseCenter : A = H
  ///   Slant       : A = sqrt(H² - R0²) - H0 + DH
  ///
  /// Tersus (process Nuwa, StaticSurveyActivity.java:564-575) :
  ///   Vertical    : A = H              (rien ajoute)
  ///   PhaseCenter : A = H + AntCenter  (alias AHT_G "Pole / Ground")
  ///   Slant       : A = |sqrt(H² - R²) + AntCenter - AntBottomHeight|
  ///
  /// Pour Slant : si la geometrie d'antenne est inconnue (R0=0) ou si la
  /// hauteur saisie est inferieure au rayon, on retombe sur Vertical par
  /// surete (sinon racine imaginaire ou distance fausse).
  double get apcToGroundVerticalOffset {
    switch (brand) {
      case GnssBrand.chcnav:
        return _chcnavOffset();
      case GnssBrand.tersus:
        return _tersusOffset();
    }
  }

  double _chcnavOffset() {
    switch (surveyType) {
      case AntennaSurveyType.vertical:
        return heightMeters + antenna.dh;
      case AntennaSurveyType.phaseCenter:
        return heightMeters;
      case AntennaSurveyType.slant:
        if (antenna.r0 <= 0 || heightMeters <= antenna.r0) {
          return heightMeters + antenna.dh;
        }
        final v = math.sqrt(
              heightMeters * heightMeters - antenna.r0 * antenna.r0,
            ) -
            antenna.h0;
        return v + antenna.dh;
    }
  }

  double _tersusOffset() {
    switch (surveyType) {
      case AntennaSurveyType.vertical:
        return heightMeters;
      case AntennaSurveyType.phaseCenter:
        return heightMeters + antenna.dh;
      case AntennaSurveyType.slant:
        if (antenna.r0 <= 0 || heightMeters <= antenna.r0) {
          return heightMeters;
        }
        final raw = math.sqrt(
              heightMeters * heightMeters - antenna.r0 * antenna.r0,
            ) +
            antenna.dh -
            antenna.h0;
        return raw.abs();
    }
  }

  GnssRoverConfig copyWith({
    GnssBrand? brand,
    AntennaConstants? antenna,
    double? heightMeters,
    AntennaSurveyType? surveyType,
    VerticalAdjustment? verticalAdjustment,
  }) =>
      GnssRoverConfig(
        brand: brand ?? this.brand,
        antenna: antenna ?? this.antenna,
        heightMeters: heightMeters ?? this.heightMeters,
        surveyType: surveyType ?? this.surveyType,
        verticalAdjustment: verticalAdjustment ?? this.verticalAdjustment,
      );

  /// Config par defaut quand rien n'est encore persiste : rover Tersus OSCAR
  /// en methode Vertical, hauteur 1.00 m. C'est le materiel reellement
  /// deploye sur le terrain (cf. memory/project_gnss_brand_z_chain.md).
  /// Getter (et non const) pour lire l'antenne OSCAR depuis le catalogue
  /// sans dupliquer ses constantes (r0/h0/dh).
  static GnssRoverConfig get fallback => GnssRoverConfig(
        brand: GnssBrand.tersus,
        antenna: AntennaCatalog.byKey('TERSUS_OSCAR'),
        heightMeters: _defaultHeightMeters,
        surveyType: AntennaSurveyType.vertical,
      );

  static const double _defaultHeightMeters = 1.00;
}

class GnssConfigService {
  static const String _brandKey = 'gnss_rover_brand';
  static const String _antennaKey = 'gnss_rover_antenna_model';
  static const String _heightKey = 'gnss_rover_antenna_height';
  static const String _typeKey = 'gnss_rover_antenna_survey_type';
  static const String _verticalAdjustmentKey = 'gnss_vertical_adjustment';

  final DatabaseHelper _db;

  GnssConfigService({DatabaseHelper? databaseHelper})
      : _db = databaseHelper ?? DatabaseHelper();

  Future<GnssRoverConfig> loadRoverConfig() async {
    final brandStr = await _db.getAppMetadataValue(_brandKey);
    final antennaKey = await _db.getAppMetadataValue(_antennaKey);
    final heightStr = await _db.getAppMetadataValue(_heightKey);
    final typeStr = await _db.getAppMetadataValue(_typeKey);
    final adjustmentStr =
        await _db.getAppMetadataValue(_verticalAdjustmentKey);
    // Retro-compat : pas de brand persiste = installation pre-Tersus,
    // on retombe sur CHCNAV (le seul process existant avant cette phase).
    final brand = _parseBrand(brandStr);
    // Defense : si l'antenne persistee n'appartient pas a la marque (cas
    // d'une downgrade ou d'un app_metadata corrompu), on prend l'antenne
    // par defaut de la marque pour eviter d'appliquer la mauvaise formule.
    var antenna = AntennaCatalog.byKey(antennaKey);
    if (antenna.brand != brand) {
      antenna =
          AntennaCatalog.byKey(AntennaCatalog.defaultKeyForBrand(brand));
    }
    final height = double.tryParse(heightStr ?? '') ??
        GnssRoverConfig.fallback.heightMeters;
    final type = _parseType(typeStr);
    final adjustment = VerticalAdjustment.deserialize(adjustmentStr);
    return GnssRoverConfig(
      brand: brand,
      antenna: antenna,
      heightMeters: height,
      surveyType: type,
      verticalAdjustment: adjustment,
    );
  }

  Future<void> saveRoverConfig(GnssRoverConfig config) async {
    await _db.saveAppMetadataValue(
      _antennaKey,
      config.antenna.key,
      eventType: 'SET_GNSS_ROVER_ANTENNA',
      payload: {
        'brand': config.brand.name,
        'model': config.antenna.key,
        'height_m': config.heightMeters,
        'survey_type': config.surveyType.name,
        'vertical_adjustment': config.verticalAdjustment.serialize(),
      },
    );
    await _db.saveAppMetadataValue(_brandKey, config.brand.name);
    await _db.saveAppMetadataValue(
      _heightKey,
      config.heightMeters.toStringAsFixed(4),
    );
    await _db.saveAppMetadataValue(_typeKey, config.surveyType.name);
    await _db.saveAppMetadataValue(
      _verticalAdjustmentKey,
      config.verticalAdjustment.serialize(),
    );
  }

  GnssBrand _parseBrand(String? str) {
    // Defaut Tersus : c'est le rover reellement deploye terrain (OSCAR).
    // Une install sans brand persiste (anterieure a l'ajout de la marque)
    // bascule donc sur Tersus au prochain load. Choix assume cote produit.
    if (str == null) return GnssBrand.tersus;
    return GnssBrand.values.firstWhere(
      (b) => b.name == str,
      orElse: () => GnssBrand.tersus,
    );
  }

  AntennaSurveyType _parseType(String? str) {
    if (str == null) return AntennaSurveyType.vertical;
    return AntennaSurveyType.values.firstWhere(
      (t) => t.name == str,
      orElse: () => AntennaSurveyType.vertical,
    );
  }
}
