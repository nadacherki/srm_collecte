# Basemap offline Merchich

Le fond de carte offline mobile doit etre un package raster deja tuile en
EPSG:26191 (Merchich). L'application ne reprojette pas les donnees terrain ;
elle affiche les tuiles dans le meme repere que les objets collectes.

## Flux de production

1. Le serveur cherche un PMTiles Merchich valide avec sidecar JSON.
2. Si rien n'est pret, il prepare automatiquement le package depuis une source
   serveur :
   - GeoTIFF/VRT EPSG:26191 via `BASEMAP_MERCHICH_SOURCE_PATH`, ou
   - extract `.osm` place dans `API_GeoDjango/basemaps/source/`.
3. Le resultat est ecrit dans
   `API_GeoDjango/pprcollecte/media/basemaps/region.pmtiles` avec
   `region.json`.
4. Le mobile telecharge ce fichier avec reprise HTTP Range et verification
   sha256. Si la carte est indisponible, les donnees metier continuent a se
   telecharger et la carte offline reste simplement vide.

## Endpoints

- `GET /api/basemaps/region/manifest/` retourne le manifest mobile.
- `GET /api/basemaps/region/download/` stream le PMTiles avec support Range.

Le manifest exige :

- `type: basemap`
- `srid: 26191` ou `crs: EPSG:26191`
- `tileSize`
- `origin`
- `resolutions`
- `boundsMerchich`

Un package `ortho`, `orthophoto`, `satellite` ou WebMercator n'est pas accepte
comme basemap offline.

## Commande manuelle

```powershell
python manage.py prepare_merchich_regional_basemap --force
```

Variables utiles :

| Variable | Role |
|---|---|
| `BASEMAP_MERCHICH_SOURCE_PATH` | GeoTIFF/VRT source EPSG:26191 |
| `BASEMAP_BUILD_SOURCE_DIR` | Dossier source alternatif |
| `BASEMAP_REGIONAL_OUTPUT_PATH` | PMTiles cible alternatif |
| `BASEMAP_AUTO_PREPARE` | `true` par defaut |
| `BASEMAP_SCRIPT_PYTHON` | Python QGIS/GDAL explicite |
| `BASEMAP_PMTILES_CLI_PATH` | CLI pmtiles explicite |
| `BASEMAP_TILE_SIZE` | 512 par defaut |
| `BASEMAP_TILE_FORMAT` | `webp` par defaut |

L'ancien flux Protomaps/WebMercator reste utile comme reference historique,
mais il ne satisfait pas le besoin actuel "sat/basemap en Merchich a 100%".
