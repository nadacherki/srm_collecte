# QA Bloc 10 - Telechargement / Sync / Online-offline

Date: 2026-05-25

## Resultat automatique

Commande executee:

```powershell
C:\Users\AnasDahou\Desktop\srm_collecte\srmenv\Scripts\python.exe tools\codex_dart_flutter.py --cwd PPRCollecte_Flutter --timeout 60 flutter test test/draft_and_capture_rules_test.dart test/status_lock_and_visibility_test.dart test/mobile_config_services_test.dart test/database_helper_sqlite_test.dart test/affleurant_service_test.dart
```

Resultat: OK, 30 tests passed.

Couverture verifiee automatiquement:

- Brouillons: les coordonnees automatiques et valeurs neutres ne creent pas de brouillon inutile; les attributs metier/photos creent un brouillon utile.
- Download/sync exclusifs: un seul job mobile peut tourner a la fois; un sync ne demarre pas pendant un download et inversement.
- Readiness mobile: session expiree, config mobile absente et zone non affectee remontent des messages bloquants explicites.
- Permissions de collecte: le garde de capture exige GNSS externe, Z et precision conforme selon role.
- Affichage downloaded/synced/local: les lignes downloaded, synced et celles de l'agent courant restent visibles.
- Verrouillage sync: les lignes synced propres sont bloquees; anomalies et objets incomplets restent editables.
- DB locale: tables critiques, files photo sync, retries, lignes, regards et anomalies terrain sont coherents.
- Affleurants: package EPSG:26191 accepte, package non-Merchich refuse, snap renvoie X/Y Merchich.

## Verification manuelle terrain

### 1. Online / offline

- Se connecter en ligne avec un agent affecte a une zone.
- Passer en mode avion apres telechargement.
- Relancer l'app: la carte, les orthos, affleurants, points/lignes/polygones locaux doivent rester visibles.
- Verifier que les actions reseau indiquent clairement l'indisponibilite au lieu de bloquer l'ecran.

### 2. Telechargement

- Lancer Telecharger avec connexion active.
- Verifier progression UI et notification Android.
- Verifier que la zone affectee, l'ortho EPSG:26191, les affleurants et les donnees SRM sont disponibles localement.
- Couper le reseau pendant un telechargement: l'echec doit etre signale et l'app doit redevenir utilisable.

### 3. Synchronisation

- Creer un point, une ligne, un polygone, une anomalie et un objet incomplet.
- Lancer Sync.
- Verifier progression UI et notification Android.
- Confirmer cote backend que les payloads utilisent X/Y/Z Merchich.
- Verifier que les objets synced deviennent verrouilles sauf anomalies/objets incomplets.

### 4. Permissions et acces

- Refuser permission notification sur Android 13+: l'app ne doit pas crasher.
- Refuser localisation: la collecte GPS doit etre bloquee avec message explicite.
- Agent sans zone: telechargement bloque avec message zone absente.
- Agent hors zone: warning de confirmation avant enregistrement.

### 5. Affichage donnees

- Activer/desactiver orthos.
- Activer/desactiver affleurants.
- Verifier legendes et filtres: locaux, telecharges, synchronises, anomalies, incomplets.
- Verifier qu'une donnee synced propre n'est pas editable.

### 6. Brouillons

- Ouvrir un formulaire, saisir un attribut metier, quitter sans sauver: brouillon propose.
- Ouvrir un formulaire sans modifier autre chose que les coordonnees automatiques: pas de brouillon parasite.
- Reprendre un brouillon et sauvegarder: la donnee doit apparaitre localement puis se synchroniser.

## Point de vigilance

Les notifications Android et les permissions systeme ne peuvent pas etre validees completement par test unitaire desktop. Elles doivent etre confirmees sur APK installe, idealement sur Android 13+ et sur un appareil terrain avec reseau coupe/repris.

## Cas extremes a tester

### Priorite haute

- Reseau coupe avant Telecharger: l'action doit etre refusee proprement, sans vider les donnees locales deja presentes.
- Reseau coupe pendant Telecharger: progression interrompue, notification echec, app reutilisable, package partiel non active.
- Reseau coupe pendant Sync: les objets non confirmes serveur restent `synced=0` et repartent au prochain sync.
- App fermee de force pendant Telecharger: au redemarrage, aucun package incomplet ne doit etre considere actif.
- App fermee de force pendant Sync: aucune ligne ne doit passer en `synced=1` sans confirmation serveur.
- Token expire pendant Telecharger/Sync: message session expiree, retour login ou refresh token, pas de boucle infinie.
- Agent sans zone affectee: telechargement bloque avant tout appel lourd, message explicite.
- Zone retiree cote serveur apres un ancien telechargement: prochain telechargement doit refuser/mettre a jour le perimetre, sans supprimer brutalement les donnees locales utiles avant confirmation.
- Package ortho/basemap `srid=3857` ou absent: refuse pour collecte precise, aucun affichage actif de pointage.
- Package affleurants non EPSG:26191: refuse, pas d'accrochage vectoriel active.

### Priorite moyenne

- Espace disque insuffisant pendant Telecharger: echec lisible, pas de crash, nettoyage du fichier temporaire si possible.
- Fichier PMTiles/ortho corrompu: package refuse, ancienne ortho compatible conservee si elle existe.
- Manifest basemap incomplet: refus si `srid`, `origin`, `resolutions` ou `boundsMerchich` manquent.
- Gros volume telecharge: carte reste navigable, boutons desactives pendant job, pas de double telechargement.
- Double tap rapide sur Telecharger ou Sync: un seul job demarre.
- Notification Android refusee: le job continue avec progression UI interne, sans crash.
- Permission localisation refusee: collecte GPS bloquee; pointage carte/ortho reste possible si la logique metier l'autorise.
- Passage arriere-plan/avant-plan pendant job: progression reprend ou echec clair, pas d'ecran bloque.
- Changement d'heure telephone: les brouillons et statuts sync ne doivent pas disparaitre.
- Donnee synced modifiee localement par anomalie/objet incomplet: reste editable selon regle, puis sync comme update terrain.

### Priorite basse mais utile

- Brouillon corrompu ou ancien schema: ignore proprement ou propose suppression, sans bloquer l'ouverture du formulaire.
- Photos manquantes/deplacees apres brouillon: formulaire ouvre, signale la photo indisponible, ne casse pas la sync.
- Meme objet cree deux fois hors ligne: sync doit gerer l'UUID local pour eviter un doublon serveur non controle.
- Backend renvoie une table inconnue/non configuree: import ignore ou warning, sans stopper tout le telechargement.
- Agent se deconnecte pendant job: job annule proprement ou termine avec compte courant coherent.
- Ancienne base locale pre-Merchich: migration ne doit pas afficher du WGS comme si c'etait du Merchich.
- Ortho active mais affleurants absents: carte reste utilisable, bouton affleurants masque/desactive.
- Affleurants presents mais ortho absente: accrochage possible seulement si la carte precise EPSG:26191 est active ou explicitement acceptee.
