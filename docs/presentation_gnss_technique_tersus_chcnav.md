# Intégration GNSS double récepteur (Tersus / CHCNAV) : dossier technique

> Version technique du deck de cadrage produit. Public visé : ingénierie,
> topographes, revue d'architecture. Tout est calé sur le code réel :
> `antenna_catalog.dart`, `gnss_config_service.dart`, `projection_service.dart`,
> `nmea_bridge_service.dart`. Sources Nuwa décompilées :
> `StaticSurveyActivity.java:564-575`, `CoordTransf.BLH84_XYh`.

---

## Slide 1 - Thèse technique

L'app ne « parle pas le langage » des récepteurs par analogie : elle
**réimplémente bit pour bit** la chaîne de réduction de Nuwa (Tersus) et de
LandStar (CHCNAV). Le pipeline de positionnement est **identique** entre les
deux marques. Seules **deux choses** divergent et sont branchées par marque :

1. Les **constantes géométriques d'antenne** (catalogue par marque).
2. Les **formules de réduction APC -> sol** (offset vertical).

Tout le reste (NMEA -> WGS84 -> Merchich) est commun et validé empiriquement à
**0.1 mm** contre Nuwa.

---

## Slide 2 - Le pipeline complet (commun aux deux marques)

```
Trame NMEA GGA (rover, Bluetooth)
   |  champ 9  : altitude orthométrique H
   |  champ 11 : séparation géoïdale N
   v
h_ellipsoidale = H + N            <- on reconstruit l'ellipsoïdal, PAS l'ortho
   v
proj4dart : WGS84 (lon, lat, h)  ->  Merchich Nord EPSG:26191
   |  Helmert towgs84 = 31,146,47,0,0,0,0  (translation pure)
   |  changement d'ellipsoïde WGS84 -> Clarke 1880
   |  AUCUN modèle de géoïde (.ggf) : pur datum, comme Nuwa BLH84_XYh
   v
(X, Y, Z_apc) en mètres Merchich  <- Z = centre de phase de l'antenne
   v
Z_sol = Z_apc - apcToGroundVerticalOffset   <- LE point de branchement marque
   v
VerticalAdjustment.apply()        <- None | Constante | Plan incliné (calage)
   v
(X, Y, Z_sol) stocké
```

Référence code :
- `projection_service.dart:41-88` (`merchichPointFromGnss`, `wgs84HeightToMerchich`)
- La soustraction antenne se fait **au save** (Z stocké = h_sol), comme
  LandStar. Tersus/Nuwa stocke h_apc et soustrait à l'export. On a aligné sur
  le modèle LandStar pour avoir un Z déjà exploitable en base.

---

## Slide 3 - Pourquoi le datum tombe juste (preuve, pas analogie)

Notre `projection_constants.dart` : `+towgs84=31,146,47,0,0,0,0`.

Écran Nuwa, système « MERCHICH MAROC Zone 1 », onglet Datum Trans (capture
2026-05-31) :
- Transformation : Bursa-Wolf
- Dx=-31, Dy=-146, Dz=-47, Rx=Ry=Rz=0, Scale=0

Rotations et échelle **nulles des deux côtés** => le Bursa 7 paramètres dégénère
en Helmert 3 paramètres (translation pure). Le signe inversé (-31 vs +31) est
la convention de sens (Nuwa exprime WGS84->Merchich, nous Merchich->WGS84) ;
pour une translation pure, l'inverse est la négation exacte.

**Conséquence :** l'aller-retour RTK se referme au cm, horizontal ET vertical.
Confirmé empiriquement : `proj4dart 3D = Nuwa BLH->NEH à 0.1 mm`.

---

## Slide 4 - Le seul point de divergence : la réduction APC -> sol

`GnssRoverConfig.apcToGroundVerticalOffset` (`gnss_config_service.dart:158-202`)
fait un `switch (brand)`. Les formules, par méthode de mesure :

| Méthode | CHCNAV (LandStar) | Tersus (Nuwa) |
|---|---|---|
| Vertical (canne droite) | `A = H + DH` | `A = H` (rien ajouté) |
| PhaseCenter | `A = H` | `A = H + AntCenter` |
| Slant (oblique) | `A = sqrt(H² - R0²) - H0 + DH` | `A = \|sqrt(H² - R²) + AntCenter - AntBottomHeight\|` |

Mapping des constantes (même champs `r0/h0/dh`, sémantique différente) :

| Champ code | CHCNAV | Tersus |
|---|---|---|
| `r0` | R0 (rayon slant) | AntRadius |
| `h0` | H0 (offset APR -> repère slant) | AntBottomHeight (0.0 au catalogue officiel) |
| `dh` | DH (offset APR -> APC) | AntCenter |

**Le piège métier :** pour une même hauteur de canne saisie (ex : 1,80 m), passer
d'un rover CHCNAV à un Tersus sans brancher la bonne formule produit un Z
décalé de **5 à 10 cm** (la différence `DH` vs `AntCenter`). Invisible à l'oeil,
mais faux pour des profondeurs de réseau.

Garde-fou Slant (les deux marques) : si `r0 <= 0` ou `H <= r0` (racine
imaginaire / distance fausse), on retombe sur Vertical par sûreté.

---

## Slide 5 - Catalogues d'antennes (valeurs réelles, par marque)

Deux maps séparées dans `antenna_catalog.dart`, jamais fusionnées dans l'UI
(`sortedForBrand` filtre par marque).

**CHCNAV** (source : `CHCNAV/Config/ante.hpc`, LandStar 8)

| Modèle | r0 (R0) | h0 (H0) | dh (DH) |
|---|---|---|---|
| GENERIC | 0.0 | 0.0 | 0.0 |
| i89 / Z100 | 0.124 | 0.07996 | 0.0 |
| X16 / X16 Pro | 0.124 | 0.08133 | 0.0 |

**Tersus** (source : table SQLite `TbAntenna` extraite de `Nuwa.apk`, asset `project`)

| Modèle | r0 (AntRadius) | h0 (AntBottomHeight) | dh (AntCenter) |
|---|---|---|---|
| GENERIC | 0.0 | 0.0 | 0.0 |
| OSCAR (défaut parc) | 0.13 | 0.0 | 0.094 |
| AX3702 | 0.13 | 0.0 | 0.054 |
| AX3702 (HG) | 0.13 | 0.0 | 0.0509 |
| AX4E02 | 0.13 | 0.0 | 0.059 |
| LUKA | 0.13 | 0.0 | 0.082 |
| TS20 | 0.13 | 0.0 | 0.06425 |
| K1 | 0.13 | 0.0 | 0.082 |

Note : `h0 = 0.0` systématique côté Tersus, conforme au catalogue officiel.
Tout le décalage APC est porté par `AntCenter` (`dh`).

---

## Slide 6 - Architecture logicielle de la bascule

```
enum GnssBrand { chcnav, tersus }     <- antenna_catalog.dart:33

GnssRoverConfig {
  brand, antenna, heightMeters, surveyType, verticalAdjustment
  apcToGroundVerticalOffset  ->  switch(brand) { _chcnavOffset | _tersusOffset }
}

GnssConfigService  <- persistance app_metadata (survit aux relances)
  clés : gnss_rover_brand / _antenna_model / _antenna_height
         / _antenna_survey_type / gnss_vertical_adjustment
```

Trois défenses notables dans `gnss_config_service.dart` :

1. **Défaut Tersus assumé** (`_parseBrand:302`) : pas de brand persistée =
   install antérieure à l'enum => bascule sur Tersus OSCAR (matériel réellement
   déployé), pas sur CHCNAV.
2. **Anti-mismatch antenne/marque** (`loadRoverConfig:259-263`) : si l'antenne
   persistée n'appartient pas à la marque (downgrade, metadata corrompu), on
   force l'antenne par défaut de la marque pour ne jamais appliquer la mauvaise
   formule.
3. **`copyWith` + sérialisation tolérante** : un `VerticalAdjustment` au format
   inconnu retombe sur `None` au lieu de planter.

---

## Slide 7 - Ajustement vertical (au-dessus de la réduction antenne)

`sealed class VerticalAdjustment` (`gnss_config_service.dart:22-124`),
appliqué APRÈS la réduction APC -> sol, sur l'élévation déjà en Merchich :

| Type | Formule | Usage |
|---|---|---|
| None | `H` | défaut |
| Constante | `H + offset` | calage sur un point connu (1 point) |
| Plan incliné | `H + a*X + b*Y + c` | calage multi-points, écart Z linéaire avec la position |

Le plan incliné est destiné à un calage moindres carrés sur 3+ points connus
(outil Phase 3.1). C'est le levier si un jour le client exige un rattachement
borne NGM officielle au cm : la translation pure Nuwa reste une approx ~5 m vs
Merchich géodésique officiel, mais la cohérence interne et le rattachement au
point base sont parfaits tant qu'on ne touche pas à l'onglet Datum Trans.

---

## Slide 8 - Les deux phases terrain (vue technique)

**Phase A - config base (carnet constructeur, Nuwa/LandStar)**
- Process B validé : l'agent saisit X/Y/Z **Merchich** du point de stationnement
  de la base. Nuwa convertit Merchich->WGS84 (transfo du projet) au moment de la
  config base et cale la base sur ce WGS84.
- Le calage s'applique **une seule fois**, à la config base. Le lat/long NMEA
  émis ensuite contient déjà l'effet de la saisie Merchich.

**Phase B - collecte (app SRM)**
- Connexion Bluetooth au rover, auto-détection (`Tersus`, `Oscar`, `CHC`,
  `GNSS`, `RTK`, `NMEA`...).
- Sélection marque (Tersus par défaut) + hauteur de canne.
- À chaque fix : `nmea_bridge_service` lit la GGA -> projection -> réduction
  antenne par marque -> Z_sol stocké.
- Capture stricte agent : Z obligatoire, précision <= 0.50 m, fix RTK
  obligatoire, satellites + HDOP acceptables.

---

## Slide 9 - Limites connues et dette assumée

- **Pas de géoïde (.ggf)** : volontaire, pour reproduire exactement Nuwa. Z =
  élévation dans le datum Merchich, pas une altitude orthométrique au géoïde
  officiel. Acceptable car cohérent avec le carnet constructeur utilisé.
- **Approx ~5 m vs Merchich géodésique officiel** sur l'absolu (translation 3
  paramètres). Cohérence interne et rattachement base = cm.
- **L'égalité Nuwa casse** si un jour : rotation/échelle ajoutées dans Datum
  Trans, grille NTv2, ou exigence borne NGM. Réponse prévue = calage local
  (Plan incliné) ou grille, pas une refonte du pipeline.
- **Doctrine terrain :** NE PAS modifier l'onglet Datum Trans de Nuwa (garder
  Bursa -31/-146/-47, rot/scale nuls).

---

## Slide 10 - Synthèse pour la revue

| Dimension | État |
|---|---|
| Pipeline NMEA -> Merchich | commun, validé 0.1 mm vs Nuwa |
| Datum | translation pure, identique à Nuwa (preuve écran + empirique) |
| Réduction antenne | branchée par marque, formules alignées sur sources décompilées |
| Catalogues | séparés par marque, valeurs vérifiées (ante.hpc / TbAntenna) |
| Défenses | défaut Tersus, anti-mismatch antenne/marque, parse tolérant |
| Calage cm officiel | non couvert (Plan incliné en levier, Phase 3.1) |

**Une phrase :** une seule app native qui réimplémente fidèlement deux chaînes
de réduction constructeur ; le pipeline est commun et prouvé, la seule
divergence (constantes + formule antenne) est isolée derrière un `enum
GnssBrand` et un catalogue par marque.
