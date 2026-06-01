# QA bloc 15 - audit GNSS/NMEA

Date audit: 2026-06-01

## Synthese

Etat global: favorable cote implementation, avec quelques validations terrain/metier restantes avant production.

Decisions appliquees:

- Les agents utilisent le recepteur GNSS externe, pas le GPS telephone ni le mock interne.
- La position fictive Android est reservee aux administrateurs.
- Les agents peuvent capturer depuis `GNSS XYZ` ou `GNSS lat/lon converti`.
- `GNSS lat/lon converti` est accepte parce que c'est le process terrain disponible aujourd'hui: le rover fournit latitude/longitude, puis l'app convertit/corrige en Merchich.
- La capture agent reste stricte: Z obligatoire, precision <= 0.50 m, fix RTK obligatoire, satellites suffisants et HDOP acceptable.

## Corrections appliquees

- Auto-detection Bluetooth: reconnaissance de `GPS`, `Tersus`, `Oscar`, `RTK`, `GNSS`, `CHC`, `NMEA`.
- Le pont NMEA peut maintenant lire les fixes et alimenter l'app sans exiger que SRM Collecte soit selectionnee comme app de position fictive Android.
- Si la position fictive Android est active, l'injection Android continue de fonctionner pour les admins.
- Dans le dialogue Pont NMEA, les agents voient un message de lecture GNSS directe; le bouton `Options mock` est masque.
- L'auto-connexion NMEA au demarrage ne depend plus du mode position fictive Android.
- Les metriques RTK du dernier fix (`fixQuality`, satellites, HDOP) sont conservees dans `HomeController` et transmises au garde de capture.
- Le listener GPS Android n'ecrase plus l'etat porte par le pont NMEA.

## Workflow verifie

1. Acces UI

- Fichiers:
  - `lib/screens/home/home_page.dart`
  - `lib/screens/home/home_page_dialogs.dart`
- Bouton carte GNSS/GPS: ouvre le flux GNSS.
- Agent non admin: acces direct au pont NMEA.
- Admin: acces aux outils diagnostic/mock et au pont NMEA.

2. Configuration rover

- Fichier: `lib/screens/home/gnss_rover_setup_dialog.dart`
- Champs exposes:
  - marque rover: CHCNAV / Tersus
  - modele antenne
  - methode de mesure: Vertical / Slant / Phase Center
  - hauteur rover
  - ajustement vertical: aucun / constante / plan incline
- Defaut code:
  - Tersus
  - Tersus OSCAR
  - hauteur 1.00 m
  - methode Vertical
  - aucun ajustement vertical

3. Bluetooth / pont NMEA

- Fichiers:
  - `lib/services/nmea_bridge_service.dart`
  - `android/app/src/main/kotlin/com/srm/collecte/MainActivity.kt`
- L'app liste les appareils Bluetooth deja appaires.
- La selection manuelle est memorisee dans `app_metadata`.
- A l'ouverture de la carte, l'app tente l'auto-connexion si un appareil prefere est memorise, ou si un seul appareil appaire ressemble a un recepteur GNSS.
- Le polling du pont est fait toutes les 1 s.
- Un fix est considere expire apres 5 s sans nouveau fix exploitable.
- En cas de deconnexion/expiration, une collecte ligne/polygone active est mise en pause.

4. Parsing NMEA natif

- Trames prises en charge:
  - `GGA`: lat/lon, fix quality, satellites, HDOP, hauteur.
  - `RMC`: lat/lon, vitesse, cap.
  - `PJK`: coordonnees projetees X/Y/Z si le recepteur les envoie.
  - `GST`: precision, utilisee si disponible.
- Precision:
  - priorite a GST recent;
  - sinon estimation `HDOP * 2`, min 0.2 m.

5. Conversion et correction

- Fichiers:
  - `lib/services/projection_service.dart`
  - `lib/controllers/home_controller.dart`
  - `lib/services/gnss_config_service.dart`
- Pour un fix lat/lon:
  - conversion WGS84 vers Merchich EPSG:26191;
  - hauteur GGA: orthometrique + separation geoidale = hauteur ellipsoidale WGS84;
  - conversion Z vers elevation Merchich;
  - soustraction du decalage antenne -> sol selon marque/methode;
  - application de l'ajustement vertical eventuel.
- Pour un fix direct X/Y/Z:
  - l'app conserve les X/Y/Z projetes fournis par le recepteur.

6. Seuils de capture

- Fichier: `lib/services/capture_location_guard.dart`
- Admin:
  - sources internes autorisees;
  - precision max 5.0 m.
- Agent terrain:
  - source interne telephone/mock bloquee;
  - altitude/Z obligatoire;
  - precision max 0.5 m;
  - sources acceptees: `GNSS XYZ`, `GNSS lat/lon converti`;
  - `fixQuality` accepte: 4 ou 5;
  - satellites minimum: 8;
  - HDOP maximum: 1.0.

## Tests automatiques associes

- `test/gnss_rover_config_test.dart`
  - constantes antennes CHCNAV/Tersus;
  - defaut Tersus OSCAR, 1.00 m, Vertical;
  - formules Vertical, Slant, Phase Center;
  - ajustement vertical constant/plan.
- `test/nuwa_base_conversion_check_test.dart`
  - conversion X/Y/Z WGS84 vers Merchich comparee a Nuwa.
- `test/draft_and_capture_rules_test.dart`
  - seuil admin 5 m;
  - seuil agent 0.5 m;
  - blocage GPS telephone pour agents;
  - acceptation agent de `GNSS XYZ` et `GNSS lat/lon converti` sous garde RTK;
  - blocage fix non RTK, satellites insuffisants, HDOP degrade.
- `test/nmea_bridge_service_test.dart`
  - auto-detection des noms Tersus OSCAR / RTK / CHCNAV.

## Zones grises restantes a remonter metier

1. Hauteur rover par defaut

Le code est a 1.00 m. La transcription mentionne "1 m ou 1,8 m". A confirmer avec l'equipe terrain.

2. Seuil agent

Le code impose 0.5 m pour agents; admin 5.0 m. A confirmer: 0.5 m partout, ou 1.0 m pour certains metiers/zones.

3. Garde RTK

Valeurs actuelles: `fixQuality` 4/5, satellites >= 8, HDOP <= 1.0. C'est coherent pour production stricte, mais a valider avec les recepteurs utilises reellement.

4. Z direct fourni par PJK / recepteur

Quand le recepteur fournit X/Y/Z projetes, l'app conserve le Z tel quel et ne reapplique pas la hauteur rover. A confirmer: le Z PJK est-il deja corrige au point sol ?

5. Test terrain obligatoire

Scenario final a faire avec l'equipe metier:

- telephone agent sans position fictive Android;
- Tersus OSCAR appaire Bluetooth;
- config rover verifiee dans l'app;
- lecture d'un point connu;
- comparaison X/Y/Z app vs Nuwa et/ou QGIS;
- verification du message precision/RTK;
- verification du blocage si fix degrade;
- verification pause automatique si le pont GNSS est coupe pendant une ligne/polygone.

## Etat production provisoire

Le bloc GNSS est maintenant coherent avec la decision produit: agents = recepteur GNSS externe, `GNSS lat/lon converti` autorise sous garde RTK, position fictive reservee admin.

Production possible apres validation terrain des zones grises 1 a 5.
