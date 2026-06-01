# QA Bloc 11 - Photos / Bloc 12 - Carte, rendu, affichage general

Date: 2026-05-25

## Resultat automatique

Commande executee:

```powershell
C:\Users\AnasDahou\Desktop\srm_collecte\srmenv\Scripts\python.exe tools\codex_dart_flutter.py --cwd PPRCollecte_Flutter --timeout 60 flutter test test/photo_reference_and_validation_test.dart test/database_helper_sqlite_test.dart test/status_lock_and_visibility_test.dart test/merchich_crs_test.dart test/affleurant_service_test.dart test/projection_and_mapping_test.dart
```

Resultat: OK, 37 tests passed.

Analyse statique:

```powershell
C:\Users\AnasDahou\Desktop\srm_collecte\srmenv\Scripts\python.exe tools\codex_dart_flutter.py --cwd PPRCollecte_Flutter --timeout 30 flutter analyze
```

Resultat: OK, no issues found.

## Bloc 11 - Couverture automatique photos

- References photo: distinction entre references locales et references serveur.
- URLs photo: construction d'URL seulement pour les chemins serveur, pas pour les chemins locaux.
- Slots photo: affichage des slots remplis et du prochain slot autorise seulement.
- Slots photo: impossibilite de sauter vers un slot vide plus loin.
- Suppression photo locale: compactage des slots locaux apres suppression d'un slot intermediaire.
- Photos deja serveur: les references remote restent ancrees pendant le compactage local.
- Duplication: detection par empreinte de contenu, pas seulement par nom de fichier.
- Fichiers manquants/distincts: pas de faux doublon.
- Type/taille: JPG valide accepte; photo trop lourde, mime incoherent ou fichier tronque refuses.
- Queue photo sync: pending, retry threshold, rejet sans boucle, synced non remplacable localement.
- Separation standard/anomalie/incomplet: contexts photo separes pour un meme objet et meme slot.
- Cycle anomalie: resolution et stockage de `id_intervention_anomalie`.
- Apres sync: photo synced conservee, remote path conserve, remplacement local bloque.

## Bloc 12 - Couverture automatique carte/rendu

- CRS carte: round-trip pixel -> Merchich -> pixel sans passer par WGS.
- Contrat basemap: CRS EPSG:26191 attendu.
- Projection/mapping: conversion Merchich coherente avec les services metier.
- Affleurants: package EPSG:26191 accepte, non-Merchich refuse, snap renvoie X/Y Merchich.
- Statuts rendu: detection normal/anomalie/incomplet depuis lignes SRM.
- Verrouillage visuel/metier: synced propre verrouille; anomalie/incomplet editable.
- Visibilite carte: downloaded, synced et objets de l'agent courant restent affichables.
- DB locale: les regards du jour pour mode conduite sont retrouvables et donc rendables.

## Verification manuelle Bloc 11 - Photos

### Parcours standard

- Creer un objet standard avec 1 photo, sauvegarder, rouvrir en edition: photo visible.
- Ajouter une deuxieme photo, supprimer la premiere: les slots locaux doivent se compacter sans casser la photo restante.
- Synchroniser, rouvrir: les photos serveur doivent rester visibles et non remplacees par erreur.
- Tenter de remplacer une photo synced propre: l'app doit bloquer ou conserver l'ancrage serveur selon la regle.

### Parcours anomalie

- Creer un objet avec anomalie et photo anomalie.
- Synchroniser.
- Reouvrir l'objet: photo anomalie visible dans son contexte, distincte des photos standard.
- Traiter l'anomalie ou ajouter un retour terrain: la photo initiale doit rester conservee.
- Ajouter une photo de retour terrain si le workflow le permet: elle doit aller dans un contexte separe.

### Parcours incomplet

- Creer un objet incomplet avec photo justificative.
- Synchroniser.
- Reouvrir en edition: photo incomplet visible et editable selon la regle incomplet.
- Completer l'objet: verifier quelles photos sont conservees, lesquelles deviennent standard, lesquelles restent archivees comme contexte incomplet.

### Contraintes terrain

- Photo > limite taille: message clair, pas d'ajout.
- PNG renomme en JPG ou JPG tronque: refus.
- Meme photo ajoutee dans deux slots: doublon detecte.
- Photo prise puis fichier local supprime/deplace: formulaire doit signaler indisponible sans crasher.
- Sync interrompue pendant upload photo: photo reste pending et repart au prochain sync.

## Verification manuelle Bloc 12 - Carte / rendu

### Carte et couches

- Demarrer sans basemap compatible: message fond EPSG:26191 requis.
- Telecharger une zone puis relancer hors ligne: ortho, donnees, affleurants et zones restent visibles.
- Toggle ortho ON/OFF: aucun deplacement des objets, aucun changement de coordonnees tap.
- Toggle affleurants ON/OFF: couche visible/masquee, snap actif seulement quand couche active.
- Refresh apres download: nouveaux objets visibles sans redemarrage.
- Refresh apres sync: objets locaux passent en etat synced sans disparaitre.

### Logos et icones

- Objet normal: icone standard attendue.
- Objet anomalie: icone/couleur anomalie coherent et visible sur ortho.
- Objet incomplet: icone/couleur incomplet distinct de normal/anomalie.
- Objet synced propre: rendu visible mais non editable.
- Objet anomalie/incomplet synced: rendu visible et action edition/intervention disponible.

### Cas limites affichage

- Plusieurs objets au meme X/Y: selection lisible, pas de marker invisible.
- Tres gros zoom: icones restent lisibles, pas d'offset incoherent.
- Zoom min: carte ne devient pas blanche, objets ne declenchent pas de crash.
- Rotation/orientation telephone: pas de chevauchement bouton/legende/carte.
- Texte long dans popup/detail: pas de debordement hors ecran.
- Ortho lourde + affleurants + points/lignes/polygones: navigation acceptable, pas de freeze prolonge.
- Package corrompu ou manifest incomplet: ancienne couche valide conservee ou message d'erreur clair.
- Coordonnees hors bounds Merchich: objet ignore ou signale, jamais affiche comme WGS par erreur.

## Cas extremes communs

- App tuee pendant prise photo avant sauvegarde: pas de brouillon photo corrompu bloquant.
- App tuee apres sauvegarde locale avant sync: photo locale encore presente et syncable.
- App tuee pendant upload photo: queue photo reste coherente, pas de `synced=1` sans remote path.
- Nettoyage stockage Android/cache: photos manquantes signalees proprement.
- Ancien objet avec anciennes colonnes photo: migration ouvre l'edition sans perte silencieuse.
- Basemap/ortho absent mais donnees locales presentes: objets restent accessibles via liste/detail si la carte ne peut pas afficher le fond.

## Limites de verification desktop

Les tests unitaires ne valident pas le rendu pixel reel sur un appareil Android, la camera native, la galerie Android, ni la performance GPU sur une ortho lourde. Ces points doivent etre valides sur APK installe avec au moins un appareil terrain et le package Loudaya EPSG:26191.
