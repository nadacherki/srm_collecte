# Strategie de generation des packages basemap Oujda par zone

## Objectif

Produire des packages de zone pour Oujda afin d'afficher la basemap de la meme
facon en ligne et hors ligne, selon l'architecture catalogue `zone -> package`.

Le mobile consomme actuellement des **packages MBTiles raster par zone**.

## Decision technique

- Format retenu maintenant : `MBTiles raster`
- Zone couverte : zones Oujda selon le catalogue
- Zooms cibles : portes par chaque zone
- Emplacement serveur attendu :
  - `API_GeoDjango/pprcollecte/media/basemaps/oujda/<zone_id>/<style>/<version>/package.mbtiles`

## Pipeline industrialise maintenant disponible

Le depot contient maintenant un pipeline reproductible :

- dossier source : `API_GeoDjango/basemaps/source/`
- dossier de build temporaire : `API_GeoDjango/basemaps/build/`
- commande Django :
  - depuis `API_GeoDjango/pprcollecte`
  - `python manage.py build_basemap_zone_package --zone-id oujda_centre --source "..\\basemaps\\source\\oujda_source.tif" --style standard --package-version v1`
- sortie integrite :
  - `API_GeoDjango/pprcollecte/media/basemaps/oujda/<zone_id>/<style>/<version>/package.mbtiles.sha256`

Sources acceptees actuellement :

- `*.tif`
- `*.tiff`
- `*.vrt`
- `*.mbtiles`

Si l'equipe SIG produit deja un MBTiles autorise, la commande sait aussi
le clipper et l'enregistrer au bon endroit pour la zone cible.

## Pourquoi ce choix

- `MBTiles` reste un format simple, portable et robuste pour le mobile
- un package par zone evite de telecharger toute la ville
- le mobile est deja branche pour ce format, donc on evite une refonte vectorielle immediate

## Contrainte importante

Ne pas aspirer massivement `tile.openstreetmap.org`.

Pour un pack offline distribue a des agents, il faut utiliser :

- soit une source raster sous licence adaptee
- soit une generation interne a partir de donnees OSM et d'un rendu maitrise

## Strategie recommandee en 2026

### Option recommandee pour ce projet

1. Prendre les donnees OSM source du Maroc
   - source typique : extract `morocco-latest.osm.pbf`
2. Decouper la zone Oujda avec une bounding box stable
3. Generer une base de tuiles avec un pipeline maitrise
4. Exporter un `MBTiles raster` final pour les zooms `11 -> 19`
5. Poser le fichier sur le serveur Django dans `media/basemaps/`
6. Laisser le mobile le telecharger au premier login si absent

### BBox de travail initiale

- north : `34.7380`
- south : `34.6220`
- east : `-1.8400`
- west : `-1.9800`

Cette emprise correspond a celle deja branchee dans l'application.

## Outils possibles

### Voie la plus simple pour l'equipe SIG

QGIS / GDAL avec export MBTiles raster.

Usage :
- charger une couche basemap autorisee
- regler l'emprise Oujda
- regler les zooms `11 -> 19`
- exporter en `MBTiles`

Avantage :
- rapide
- visuel
- faible friction pour produire une premiere version propre

### Voie industrialisee en place dans ce projet

Pipeline reproductible a partir d'une source locale deja autorisee.

Exemple de chaine actuellement prise en charge :
- source raster ou MBTiles locale
- decoupage Oujda
- reprojection Web Mercator
- generation MBTiles
- controles zoom/emprise/metadata
- checksum SHA-256 du fichier final pour verification mobile

Avantage :
- reproductible
- simple a executer par l'equipe
- compatible avec le mobile deja branche

Limite assumee :
- un `*.osm.pbf` brut n'est pas rendu directement par cette commande
- il faut d'abord une source raster ou un MBTiles deja rendu

## Regles de validation avant livraison

Avant de deposer `oujda.mbtiles`, verifier :

- le fichier s'ouvre bien localement
- les zooms `11 -> 19` existent
- l'emprise ne depasse pas inutilement Oujda
- les libelles principaux sont lisibles
- les routes et quartiers utiles au leve terrain sont visibles
- la taille finale reste acceptable pour un premier download mobile

## Budget de taille conseille

Pour un premier lot mobile :

- cible confortable : `< 300 Mo`
- acceptable : `< 500 Mo`
- au-dela, il faudra probablement reduire soit l'emprise, soit le zoom max

## Versionning recommande

Conserver :

- nom stable mobile : `oujda.mbtiles`
- version metier dans le manifeste serveur via date de modification du fichier

Plus tard, si besoin :

- `oujda_v2026_04.mbtiles`
- puis copie ou lien vers `oujda.mbtiles`

## Procedure de depot

1. Deposer la source dans :
   - `API_GeoDjango/basemaps/source/`
2. Generer le package final :
   - depuis `API_GeoDjango/pprcollecte`
   - `python manage.py build_basemap_zone_package --zone-id oujda_centre --source "..\\basemaps\\source\\oujda_source.tif" --style standard --package-version v1`
3. Verifier le catalogue :
   - `GET /api/basemaps/catalog/?city_slug=oujda`
4. Verifier que le package apparait avec `download_url` et `sha256`
5. Se connecter une premiere fois depuis le mobile
6. Verifier le download cible de la zone
7. Repasser hors ligne et verifier que la carte continue de s'afficher sur la zone

## Evolution plus tard

Quand on passera au zoning :

- un manifeste pourra exposer plusieurs packs
- ex. `oujda-centre`, `oujda-nord`, `oujda-sud`
- ou un decoupage par quartier/secteur selon la taille finale

Pour l'instant, on garde volontairement :

- une seule ville
- une architecture de zoning simple
- une seule logique de catalogue et d'import
