# Basemaps Offline

Ce dossier porte le pipeline reproductible de generation des packs basemap
offline.

## Structure

- `source/` : deposez ici une source cartographique autorisee pour Oujda
- `build/` : artefacts temporaires de generation
- `zones/` : decoupage GeoJSON des zones offline

## Source attendue

Le pipeline actuel sait industrialiser ces entrees locales :

- `*.tif`
- `*.tiff`
- `*.vrt`
- `*.mbtiles`

Un `*.osm.pbf` brut n'est pas directement rendu par cette commande. Il faut
d'abord passer par un rendu SIG autorise, puis fournir une source raster ou un
MBTiles deja rendu.

## Commande de reference

Depuis `API_GeoDjango/pprcollecte` :

```powershell
python manage.py build_basemap_zone_package --zone-id oujda_centre --source "..\\basemaps\\source\\oujda_source.tif" --style standard --package-version v1
```

ou avec une source MBTiles deja autorisee :

```powershell
python manage.py build_basemap_zone_package --zone-id oujda_centre --source "..\\basemaps\\source\\oujda_source.mbtiles" --style standard --package-version v1
```

La sortie standard sera :

- `API_GeoDjango/pprcollecte/media/basemaps/oujda/<zone_id>/<style>/<version>/package.mbtiles`
- `API_GeoDjango/pprcollecte/media/basemaps/oujda/<zone_id>/<style>/<version>/package.mbtiles.sha256`

Le catalogue serveur expose ensuite ces packages via :

- `GET /api/basemaps/zones/`
- `GET /api/basemaps/packages/`
- `GET /api/basemaps/catalog/`

## Zoning GeoJSON

Le zoning cible est porte par un GeoJSON versionne, par exemple :

- `API_GeoDjango/basemaps/zones/oujda_zones.geojson`

Import des zones :

```powershell
python manage.py import_basemap_zones --geojson "..\\basemaps\\zones\\oujda_zones.geojson" --city-slug oujda
```

Enregistrement d'un package de zone :

```powershell
python manage.py register_basemap_package --zone-id oujda_centre --style standard --format mbtiles --package-version v1 --file "..\\media\\basemaps\\oujda\\oujda_centre_standard.mbtiles"
```

Generation directe d'un vrai package par zone a partir d'une source autorisee :

```powershell
python manage.py build_basemap_zone_package --zone-id oujda_centre --source "..\\basemaps\\source\\oujda_source.tif" --style standard --package-version v1
```

Cette commande :

- clippe la source sur la geometrie de la zone
- genere le `package.mbtiles`
- ecrit le checksum `.sha256`
- enregistre ou met a jour `basemap_package`

Catalogue API :

- `GET /api/basemaps/zones/`
- `GET /api/basemaps/packages/`
- `GET /api/basemaps/catalog/`
