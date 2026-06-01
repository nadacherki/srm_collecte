// lib/core/constants/antenna_catalog.dart
//
// Catalogue des constantes geometriques d'antenne GNSS (R0/H0/DH cote
// CHCNAV ; AntRadius/AntBottomHeight/AntCenter cote Tersus). Chaque entree
// est etiquetee par sa marque ([GnssBrand]) parce que les conventions des
// constantes et les formules de reduction APC -> sol different entre
// constructeurs (cf. memory/project_gnss_brand_z_chain.md).
//
// CHCNAV (process LandStar 8, fichier `CHCNAV/Config/ante.hpc`)
//   R0 : rayon horizontal jusqu'au repere de mesure slant (m)
//   H0 : offset vertical entre la base antenne (APR) et le repere slant (m)
//   DH : offset vertical entre APR et le centre de phase (APC) (m)
//   Formules dans GnssRoverConfig.apcToGroundVerticalOffset :
//     Vertical    : A = H + DH
//     PhaseCenter : A = H
//     Slant       : A = sqrt(H² - R0²) - H0 + DH
//
// Tersus (process Nuwa, table SQLite `TbAntenna` extraite de Nuwa.apk
// asset `project`). Mapping conserve les memes champs r0/h0/dh mais avec
// une semantique differente :
//   r0 ≡ AntRadius
//   h0 ≡ AntBottomHeight (toujours 0.0 sur le catalogue Tersus officiel)
//   dh ≡ AntCenter (offset APR -> APC)
//   Formules Tersus (cf. StaticSurveyActivity.java:564-575 de Nuwa) :
//     Vertical    : A = H                (RIEN ajoute)
//     PhaseCenter : A = H + AntCenter    (alias AHT_G "Pole / Ground")
//     Slant       : A = |sqrt(H² - R²) + AntCenter - AntBottomHeight|

/// Marque du rover GNSS connecte. Determine le catalogue d'antennes
/// disponible et les formules de reduction appliquees. CHCNAV est conserve
/// par defaut pour la retro-compatibilite avec les configs persistees
/// avant l'introduction de cette enum.
enum GnssBrand { chcnav, tersus }

class AntennaConstants {
  final String key;
  final String displayName;
  final String manufacturer;
  final GnssBrand brand;
  final double r0;
  final double h0;
  final double dh;

  const AntennaConstants({
    required this.key,
    required this.displayName,
    required this.manufacturer,
    required this.brand,
    required this.r0,
    required this.h0,
    required this.dh,
  });
}

class AntennaCatalog {
  // Cle utilisee par defaut si la config n'est pas encore renseignee :
  // antenne generique CHCNAV avec DH=0 (hauteur saisie = verticale APR -> sol).
  static const String defaultKey = 'GENERIC';

  // Catalogue CHCNAV : valeurs verifiees dans LandStar 8
  // (CHCNAV/Config/ante.hpc).
  static const Map<String, AntennaConstants> _chcnav = {
    'GENERIC': AntennaConstants(
      key: 'GENERIC',
      displayName: 'Generique (hauteur directe)',
      manufacturer: '',
      brand: GnssBrand.chcnav,
      r0: 0.0,
      h0: 0.0,
      dh: 0.0,
    ),
    'CHC_I89': AntennaConstants(
      key: 'CHC_I89',
      displayName: 'CHCNAV i89 / Z100',
      manufacturer: 'CHCNAV',
      brand: GnssBrand.chcnav,
      r0: 0.124,
      h0: 0.07996,
      dh: 0.00,
    ),
    'CHC_X16': AntennaConstants(
      key: 'CHC_X16',
      displayName: 'CHCNAV X16 / X16 Pro',
      manufacturer: 'CHCNAV',
      brand: GnssBrand.chcnav,
      r0: 0.124,
      h0: 0.08133,
      dh: 0.00,
    ),
  };

  // Catalogue Tersus : extrait de la table TbAntenna shippee dans Nuwa.apk
  // (asset `project`, SQLite 3). Schema : AntName, AntRadius, AntCenter,
  // AntBottomHeight. Mapping : r0 = AntRadius, dh = AntCenter,
  // h0 = AntBottomHeight (toujours 0.0 dans le catalogue officiel).
  static const Map<String, AntennaConstants> _tersus = {
    'TERSUS_GENERIC': AntennaConstants(
      key: 'TERSUS_GENERIC',
      displayName: 'Generique (hauteur directe)',
      manufacturer: '',
      brand: GnssBrand.tersus,
      r0: 0.0,
      h0: 0.0,
      dh: 0.0,
    ),
    'TERSUS_OSCAR': AntennaConstants(
      key: 'TERSUS_OSCAR',
      displayName: 'Tersus OSCAR',
      manufacturer: 'Tersus',
      brand: GnssBrand.tersus,
      r0: 0.13,
      h0: 0.0,
      dh: 0.094,
    ),
    'TERSUS_AX3702': AntennaConstants(
      key: 'TERSUS_AX3702',
      displayName: 'Tersus AX3702',
      manufacturer: 'Tersus',
      brand: GnssBrand.tersus,
      r0: 0.13,
      h0: 0.0,
      dh: 0.054,
    ),
    'TERSUS_AX3702_HG': AntennaConstants(
      key: 'TERSUS_AX3702_HG',
      displayName: 'Tersus AX3702 (HG)',
      manufacturer: 'Tersus',
      brand: GnssBrand.tersus,
      r0: 0.13,
      h0: 0.0,
      dh: 0.0509,
    ),
    'TERSUS_AX4E02': AntennaConstants(
      key: 'TERSUS_AX4E02',
      displayName: 'Tersus AX4E02',
      manufacturer: 'Tersus',
      brand: GnssBrand.tersus,
      r0: 0.13,
      h0: 0.0,
      dh: 0.059,
    ),
    'TERSUS_LUKA': AntennaConstants(
      key: 'TERSUS_LUKA',
      displayName: 'Tersus LUKA',
      manufacturer: 'Tersus',
      brand: GnssBrand.tersus,
      r0: 0.13,
      h0: 0.0,
      dh: 0.082,
    ),
    'TERSUS_TS20': AntennaConstants(
      key: 'TERSUS_TS20',
      displayName: 'Tersus TS20',
      manufacturer: 'Tersus',
      brand: GnssBrand.tersus,
      r0: 0.13,
      h0: 0.0,
      dh: 0.06425,
    ),
    'TERSUS_K1': AntennaConstants(
      key: 'TERSUS_K1',
      displayName: 'Tersus K1',
      manufacturer: 'Tersus',
      brand: GnssBrand.tersus,
      r0: 0.13,
      h0: 0.0,
      dh: 0.082,
    ),
  };

  /// Cle par defaut pour chaque marque. Utilise par l'UI quand l'utilisateur
  /// bascule de marque (CHCNAV <-> Tersus) sans avoir choisi de modele.
  /// Tersus pointe sur OSCAR (le recepteur reellement deploye terrain),
  /// pas sur le generique : c'est le materiel par defaut du parc.
  static String defaultKeyForBrand(GnssBrand brand) {
    switch (brand) {
      case GnssBrand.chcnav:
        return defaultKey;
      case GnssBrand.tersus:
        return 'TERSUS_OSCAR';
    }
  }

  static Map<String, AntennaConstants> get all => {..._chcnav, ..._tersus};

  static AntennaConstants byKey(String? key) {
    final map = all;
    return map[key] ?? map[defaultKey]!;
  }

  /// Renvoie le catalogue trie pour la marque demandee. GENERIC reste en
  /// tete pour chaque marque.
  static List<AntennaConstants> sortedForBrand(GnssBrand brand) {
    final map = brand == GnssBrand.chcnav ? _chcnav : _tersus;
    final list = map.values.toList();
    final defaultForBrand = defaultKeyForBrand(brand);
    list.sort((a, b) {
      if (a.key == defaultForBrand) return -1;
      if (b.key == defaultForBrand) return 1;
      final m = a.manufacturer.compareTo(b.manufacturer);
      if (m != 0) return m;
      return a.displayName.compareTo(b.displayName);
    });
    return list;
  }

  /// Compat ascendante : ancienne liste plate triee, utilisee si du code
  /// legacy ne connait pas encore la notion de marque. Filtre sur CHCNAV
  /// par defaut puisque c'est le catalogue historique.
  static List<AntennaConstants> get sorted => sortedForBrand(GnssBrand.chcnav);
}

/// Methode de mesure de la hauteur d'antenne. Phase 1 = Vertical uniquement.
/// Phase 2 ajoutera la conversion Slant (sqrt) et phaseCenter direct.
enum AntennaSurveyType { vertical, slant, phaseCenter }
