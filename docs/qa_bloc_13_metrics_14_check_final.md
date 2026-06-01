# QA Bloc 13 - Metriques / Dashboard
# QA Bloc 14 - Check final transverse

Date: 2026-05-25

## Resultat automatique

### Flutter

Commande executee:

```powershell
C:\Users\AnasDahou\Desktop\srm_collecte\srmenv\Scripts\python.exe tools\codex_dart_flutter.py --cwd PPRCollecte_Flutter --timeout 60 flutter test test/public_metrics_cache_service_test.dart test/status_lock_and_visibility_test.dart test/database_helper_sqlite_test.dart test/photo_reference_and_validation_test.dart test/draft_and_capture_rules_test.dart test/mobile_config_services_test.dart test/merchich_crs_test.dart test/affleurant_service_test.dart test/projection_and_mapping_test.dart test/constraint_engine_test.dart test/gnss_rover_config_test.dart test/nuwa_base_conversion_check_test.dart
```

Resultat: OK, 89 tests passed.

Analyse statique:

```powershell
C:\Users\AnasDahou\Desktop\srm_collecte\srmenv\Scripts\python.exe tools\codex_dart_flutter.py --cwd PPRCollecte_Flutter --timeout 30 flutter analyze
```

Resultat: OK, no issues found.

### Backend Django

Commandes executees:

```powershell
C:\Users\AnasDahou\Desktop\srm_collecte\srmenv\Scripts\python.exe API_GeoDjango\pprcollecte\manage.py test api.tests api.test_security --verbosity 1
C:\Users\AnasDahou\Desktop\srm_collecte\srmenv\Scripts\python.exe API_GeoDjango\pprcollecte\manage.py check
```

Resultat: OK, 22 tests passed, system check OK.

Note: un warning `InsecureKeyLengthWarning` apparait dans les tests JWT car un test forge volontairement un token avec une cle courte pour verifier le rejet. Ce n'est pas une erreur applicative.

## Bloc 13 - Couverture automatique metriques/dashboard

- Cache metriques publiques: une reponse API vide est stockee comme metrique zero valide, pas comme erreur.
- Erreur reseau: les erreurs ne sont pas transformees en faux zeros.
- Messages d'erreur: les noms techniques d'endpoints `metrics-agent-public-*` sont masques dans le message utilisateur.
- Restauration cache: resume, date de fetch et erreur cachee sont relus correctement au login/relancement.
- Visibilite locale: objets downloaded, synced et objets de l'agent courant restent visibles dans les filtres locaux.
- Statuts: anomalies et objets incomplets sont detectes depuis les champs SRM.
- Photos: queue photo, photos synced, contexts anomalie/incomplet et uploads backend sont couverts.
- Securite session: JWT expire/refuse/tampered et refresh mal utilise sont rejetes cote backend.

## Verification manuelle Bloc 13 - Metriques

### Metriques locales telephone

- Creer localement 1 point, 1 ligne et 1 polygone sans sync.
- Verifier dashboard local: les compteurs doivent inclure les objets locaux non synchronises si le dashboard annonce un etat telephone.
- Ajouter une anomalie: compteur anomalies local augmente.
- Marquer un objet incomplet: compteur incomplets local augmente.
- Ajouter photos: compteur photos locales/pending augmente.
- Supprimer/annuler un brouillon: aucun compteur metier ne doit augmenter.
- Synchroniser: les compteurs locaux doivent basculer de pending/local vers synced sans doublon.

### Metriques serveur

- Apres sync, comparer les compteurs API avec des requetes SQL directes serveur.
- Verifier au minimum:
  - nb objets points crees;
  - nb lignes;
  - nb polygones/surfaces;
  - nb objets avec anomalie;
  - nb objets incomplets signales/completes;
  - nb objets avec photo;
  - nb photos renseignees/uploadees;
  - distance totale des lignes si affichee;
  - surface totale des polygones si affichee.
- Les vues `vw_metrics_agent_*` et `vw_metrics_agent_public_*` doivent compter les donnees reelles serveur, pas seulement les payloads mobiles envoyes.
- Les metriques serveur ne doivent pas inclure les objets locaux non synchronises.

### Cache et refresh au login

- Se connecter online: les metriques doivent se rafraichir.
- Relancer l'app offline: le dernier cache doit s'afficher avec date/etat clair.
- Repasser online et refresh: les valeurs doivent se mettre a jour.
- Serveur joignable mais access token expire: refresh token doit etre tente si valide.
- Serveur joignable mais session vraiment expiree: message session expiree, pas de faux zero.
- Serveur retourne 500 sur metriques: conserver cache precedent et afficher erreur lisible.

### Cas extremes metriques

- Aucune donnee serveur: dashboard affiche zero reel, pas erreur.
- Agent sans donnees mais avec zone: zero reel.
- Agent sans zone: message readiness/zone, pas metriques trompeuses.
- Objet avec plusieurs photos: `nb_objets_avec_photo` compte l'objet une seule fois; `nb_photos_*` compte les photos.
- Objet anomalie + incomplet: doit alimenter les deux compteurs si les deux statuts sont vrais.
- Sync partielle: seules les lignes confirmees serveur doivent monter dans les metriques serveur.
- Changement jour/semaine/mois autour de minuit: periode ISO et cache restent coherents.

## Bloc 14 - Check final transverse

### Resultats croises des blocs precedents

- Bloc 10 download/sync/offline: tests automatiques OK, fiche terrain disponible.
- Bloc 11 photos: tests automatiques OK, contraintes photo et contexts couverts.
- Bloc 12 carte/rendu: CRS Merchich, affichage local/downloaded/synced et affleurants couverts.
- Bloc 13 metriques: cache, erreurs et session couverts; validation serveur SQL a faire sur environnement reel.

### Nuances restantes avant livraison

- Notifications Android, camera native, galerie Android, performance GPU et rendu pixel ortho ne sont pas validables par tests desktop.
- Les metriques serveur doivent etre comparees a la base reelle apres un cycle sync complet.
- Les packages ortho/affleurants de production doivent etre generes en EPSG:26191 et testes par zone agent.
- La validation terrain Loudaya/Nada reste le test final de precision: meme point QGIS ortho vs tap app.
- Les anciens fonds Web Mercator ne doivent pas etre actifs en collecte precise.

### Checklist finale avant APK terrain

- Lancer tests Flutter cibles et `flutter analyze`.
- Lancer `manage.py check` et tests Django critiques.
- Installer APK sur telephone.
- Login agent Nada ou agent affecte.
- Telecharger zone Loudaya.
- Passer hors ligne.
- Verifier ortho ON/OFF.
- Verifier affleurants ON/OFF et snap.
- Creer point/ligne/polygone, anomalie, incomplet, photos.
- Tuer/reouvrir l'app avant sync: donnees encore presentes.
- Synchroniser.
- Verifier backend: objets, photos, anomalies, incomplets, geoms X/Y/Z Merchich.
- Verifier dashboard local puis serveur.
- Verifier qu'un objet synced propre est verrouille.
- Verifier qu'anomalie/incomplet restent traitables selon regle.

## Decision de sortie

Etat actuel du check automatique: favorable.

Validation terrain requise avant livraison: oui, pour les points non automatisables:

- notifications Android;
- camera/galerie;
- performance ortho lourde;
- metriques serveur comparees SQL;
- precision tap ortho EPSG:26191 vs QGIS/Nuwa.
