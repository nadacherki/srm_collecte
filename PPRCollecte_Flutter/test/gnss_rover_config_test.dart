import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:srm_collecte/core/constants/antenna_catalog.dart';
import 'package:srm_collecte/services/gnss_config_service.dart';

void main() {
  group('AntennaCatalog', () {
    test('byKey retourne GENERIC en fallback', () {
      expect(AntennaCatalog.byKey(null).key, 'GENERIC');
      expect(AntennaCatalog.byKey('inconnu_xyz').key, 'GENERIC');
    });

    test('constantes CHC verifiees dans ante.hpc LandStar', () {
      final i89 = AntennaCatalog.byKey('CHC_I89');
      expect(i89.brand, GnssBrand.chcnav);
      expect(i89.r0, closeTo(0.124, 1e-6));
      expect(i89.h0, closeTo(0.07996, 1e-6));
      expect(i89.dh, closeTo(0.0, 1e-6));

      final x16 = AntennaCatalog.byKey('CHC_X16');
      expect(x16.brand, GnssBrand.chcnav);
      expect(x16.r0, closeTo(0.124, 1e-6));
      expect(x16.h0, closeTo(0.08133, 1e-6));
      expect(x16.dh, closeTo(0.0, 1e-6));
    });

    test('catalogue Tersus aligne sur TbAntenna SQLite (Nuwa.apk)', () {
      // Valeurs extraites directement de assets/project (table TbAntenna).
      // Mapping : r0 = AntRadius, dh = AntCenter, h0 = AntBottomHeight.
      final oscar = AntennaCatalog.byKey('TERSUS_OSCAR');
      expect(oscar.brand, GnssBrand.tersus);
      expect(oscar.r0, closeTo(0.13, 1e-6));
      expect(oscar.dh, closeTo(0.094, 1e-6));
      expect(oscar.h0, closeTo(0.0, 1e-6));

      final ts20 = AntennaCatalog.byKey('TERSUS_TS20');
      expect(ts20.dh, closeTo(0.06425, 1e-6));

      final ax3702hg = AntennaCatalog.byKey('TERSUS_AX3702_HG');
      expect(ax3702hg.dh, closeTo(0.0509, 1e-6));
    });

    test('sortedForBrand place l\'antenne par defaut de la marque en premier',
        () {
      // CHCNAV : default = GENERIC. Tersus : default = OSCAR (materiel
      // terrain). Le tri place toujours l'antenne par defaut en tete.
      final chc = AntennaCatalog.sortedForBrand(GnssBrand.chcnav);
      expect(chc.first.key, 'GENERIC');
      expect(chc.every((a) => a.brand == GnssBrand.chcnav), isTrue);

      final tersus = AntennaCatalog.sortedForBrand(GnssBrand.tersus);
      expect(tersus.first.key, 'TERSUS_OSCAR');
      expect(tersus.every((a) => a.brand == GnssBrand.tersus), isTrue);
    });
  });

  group('GnssRoverConfig.apcToGroundVerticalOffset (CHCNAV)', () {
    test('Vertical : offset = hauteur + DH (DH=0 sur GENERIC)', () {
      final c = GnssRoverConfig(
        brand: GnssBrand.chcnav,
        antenna: AntennaCatalog.byKey('GENERIC'),
        heightMeters: 1.00,
        surveyType: AntennaSurveyType.vertical,
      );
      expect(c.apcToGroundVerticalOffset, closeTo(1.00, 1e-9));
    });

    test('Vertical avec DH non nul applique correctement', () {
      const ant = AntennaConstants(
        key: 'TEST',
        displayName: 'Test DH',
        manufacturer: 'Test',
        brand: GnssBrand.chcnav,
        r0: 0.0,
        h0: 0.0,
        dh: 0.05,
      );
      const c = GnssRoverConfig(
        brand: GnssBrand.chcnav,
        antenna: ant,
        heightMeters: 1.80,
        surveyType: AntennaSurveyType.vertical,
      );
      expect(c.apcToGroundVerticalOffset, closeTo(1.85, 1e-9));
    });

    test('PhaseCenter : offset = hauteur (DH ignore)', () {
      const ant = AntennaConstants(
        key: 'TEST',
        displayName: 'Test',
        manufacturer: 'Test',
        brand: GnssBrand.chcnav,
        r0: 0.0,
        h0: 0.0,
        dh: 0.05,
      );
      const c = GnssRoverConfig(
        brand: GnssBrand.chcnav,
        antenna: ant,
        heightMeters: 1.80,
        surveyType: AntennaSurveyType.phaseCenter,
      );
      expect(c.apcToGroundVerticalOffset, closeTo(1.80, 1e-9));
    });

    test('Slant Phase 2 : formule sqrt(SHMP^2 - R0^2) - H0 + DH', () {
      // CHC i89 reel : R0=0.124, H0=0.07996, DH=0.0. SHMP=2.000.
      // V = sqrt(4 - 0.015376) - 0.07996 = 1.99616 - 0.07996 = 1.91620
      final c = GnssRoverConfig(
        brand: GnssBrand.chcnav,
        antenna: AntennaCatalog.byKey('CHC_I89'),
        heightMeters: 2.000,
        surveyType: AntennaSurveyType.slant,
      );
      expect(c.apcToGroundVerticalOffset, closeTo(1.91620, 1e-4));
    });

    test('Slant fallback si SHMP <= R0', () {
      final c = GnssRoverConfig(
        brand: GnssBrand.chcnav,
        antenna: AntennaCatalog.byKey('CHC_I89'),
        heightMeters: 0.100,
        surveyType: AntennaSurveyType.slant,
      );
      expect(c.apcToGroundVerticalOffset, closeTo(0.100, 1e-9));
    });
  });

  group('GnssRoverConfig.apcToGroundVerticalOffset (Tersus)', () {
    test('Vertical : offset = H brut (rien ajoute), divergence vs CHCNAV', () {
      // Meme antenne OSCAR (dh=0.094) en Vertical : Tersus rend H brut,
      // CHCNAV rendrait H + 0.094. C'est la divergence operationnelle
      // critique documentee dans memory/project_gnss_brand_z_chain.md.
      final c = GnssRoverConfig(
        brand: GnssBrand.tersus,
        antenna: AntennaCatalog.byKey('TERSUS_OSCAR'),
        heightMeters: 1.80,
        surveyType: AntennaSurveyType.vertical,
      );
      expect(c.apcToGroundVerticalOffset, closeTo(1.80, 1e-9));
    });

    test('PhaseCenter (Pole AHT_G) : offset = H + AntCenter', () {
      // OSCAR AntCenter = 0.094. H = 1.80 → V = 1.894.
      final c = GnssRoverConfig(
        brand: GnssBrand.tersus,
        antenna: AntennaCatalog.byKey('TERSUS_OSCAR'),
        heightMeters: 1.80,
        surveyType: AntennaSurveyType.phaseCenter,
      );
      expect(c.apcToGroundVerticalOffset, closeTo(1.894, 1e-9));
    });

    test('Slant Tersus : |sqrt(H² - R²) + AntCenter - AntBottomHeight|', () {
      // OSCAR : R=0.13, AntCenter=0.094, AntBottomHeight=0.0. H=2.000.
      // V = |sqrt(4 - 0.0169) + 0.094 - 0| = sqrt(3.9831) + 0.094
      //   = 1.995770... + 0.094 = 2.089770...
      final c = GnssRoverConfig(
        brand: GnssBrand.tersus,
        antenna: AntennaCatalog.byKey('TERSUS_OSCAR'),
        heightMeters: 2.000,
        surveyType: AntennaSurveyType.slant,
      );
      final expected = math.sqrt(2.0 * 2.0 - 0.13 * 0.13) + 0.094;
      expect(c.apcToGroundVerticalOffset, closeTo(expected, 1e-9));
    });

    test('Slant fallback si H <= R', () {
      // Hauteur inferieure au rayon de l'antenne : on retombe sur
      // Vertical Tersus (H brut, sans AntCenter).
      final c = GnssRoverConfig(
        brand: GnssBrand.tersus,
        antenna: AntennaCatalog.byKey('TERSUS_OSCAR'),
        heightMeters: 0.10,
        surveyType: AntennaSurveyType.slant,
      );
      expect(c.apcToGroundVerticalOffset, closeTo(0.10, 1e-9));
    });
  });

  group('Divergence CHCNAV vs Tersus, meme saisie agent', () {
    test('Vertical 1.80 m : CHCNAV ajoute DH, Tersus non', () {
      // Si l'agent saisit "1.80 m" en mode Vertical, le Z calcule
      // diverge selon la marque selectionnee. C'est exactement le bug
      // que la branche par marque corrige (cf. memory).
      const dh = 0.094;
      const chcnav = GnssRoverConfig(
        brand: GnssBrand.chcnav,
        antenna: AntennaConstants(
          key: 'CHC_FAKE_OSCAR',
          displayName: 'fake',
          manufacturer: 'CHCNAV',
          brand: GnssBrand.chcnav,
          r0: 0.13,
          h0: 0.0,
          dh: dh,
        ),
        heightMeters: 1.80,
        surveyType: AntennaSurveyType.vertical,
      );
      final tersus = GnssRoverConfig(
        brand: GnssBrand.tersus,
        antenna: AntennaCatalog.byKey('TERSUS_OSCAR'),
        heightMeters: 1.80,
        surveyType: AntennaSurveyType.vertical,
      );
      // Ecart attendu = dh = 0.094 m.
      expect(
        chcnav.apcToGroundVerticalOffset - tersus.apcToGroundVerticalOffset,
        closeTo(dh, 1e-9),
      );
    });
  });

  group('VerticalAdjustment', () {
    test('None passe l\'elevation inchangee', () {
      const adj = NoVerticalAdjustment();
      expect(adj.apply(55.70), 55.70);
      expect(adj.serialize(), 'none');
    });

    test('Constante ajoute l\'offset', () {
      const adj = ConstantVerticalAdjustment(0.190);
      expect(adj.apply(55.70), closeTo(55.890, 1e-9));
      expect(adj.serialize(), 'constant:0.190000');
    });

    test('Constante negative : soustrait', () {
      const adj = ConstantVerticalAdjustment(-0.050);
      expect(adj.apply(55.70), closeTo(55.650, 1e-9));
    });

    test('deserialize tolere format inconnu -> None', () {
      expect(VerticalAdjustment.deserialize(null), isA<NoVerticalAdjustment>());
      expect(VerticalAdjustment.deserialize(''), isA<NoVerticalAdjustment>());
      expect(
        VerticalAdjustment.deserialize('bogus'),
        isA<NoVerticalAdjustment>(),
      );
    });

    test('deserialize parse constant correctement', () {
      final adj = VerticalAdjustment.deserialize('constant:0.190000');
      expect(adj, isA<ConstantVerticalAdjustment>());
      expect((adj as ConstantVerticalAdjustment).offsetMeters,
          closeTo(0.190, 1e-9));
    });

    test('round-trip serialize / deserialize', () {
      const original = ConstantVerticalAdjustment(-0.273);
      final back = VerticalAdjustment.deserialize(original.serialize());
      expect(back, isA<ConstantVerticalAdjustment>());
      expect((back as ConstantVerticalAdjustment).offsetMeters,
          closeTo(-0.273, 1e-9));
    });

    test('Plan incline : H + a*X + b*Y + c', () {
      const plan = InclinedPlaneAdjustment(a: 1.2e-6, b: -8.4e-7, c: 0.250);
      final result = plan.apply(55.700, x: 288574.0, y: 333608.0);
      expect(result, closeTo(56.016, 1e-3));
    });

    test('Plan incline : x=y=0 -> H + c', () {
      const plan = InclinedPlaneAdjustment(a: 0.1, b: 0.2, c: 0.5);
      expect(plan.apply(10.0), closeTo(10.5, 1e-9));
    });

    test('round-trip plane serialize / deserialize', () {
      const original =
          InclinedPlaneAdjustment(a: 1.2e-6, b: -8.4e-7, c: 0.250);
      final back = VerticalAdjustment.deserialize(original.serialize());
      expect(back, isA<InclinedPlaneAdjustment>());
      final p = back as InclinedPlaneAdjustment;
      expect(p.a, closeTo(1.2e-6, 1e-15));
      expect(p.b, closeTo(-8.4e-7, 1e-15));
      expect(p.c, closeTo(0.250, 1e-9));
    });
  });

  group('GnssRoverConfig.fallback', () {
    test('defaut : Tersus OSCAR, 1.00 m, Vertical', () {
      final c = GnssRoverConfig.fallback;
      expect(c.brand, GnssBrand.tersus);
      expect(c.antenna.key, 'TERSUS_OSCAR');
      expect(c.heightMeters, 1.00);
      expect(c.surveyType, AntennaSurveyType.vertical);
      // Tersus Vertical = H brut (AntCenter PAS ajoute en Vertical), donc
      // offset = 1.00 meme si OSCAR a dh=0.094.
      expect(c.apcToGroundVerticalOffset, closeTo(1.00, 1e-9));
    });
  });

  group('defaultKeyForBrand', () {
    test('Tersus pointe sur OSCAR (materiel terrain par defaut)', () {
      expect(AntennaCatalog.defaultKeyForBrand(GnssBrand.tersus),
          'TERSUS_OSCAR');
      expect(AntennaCatalog.defaultKeyForBrand(GnssBrand.chcnav), 'GENERIC');
    });
  });
}
