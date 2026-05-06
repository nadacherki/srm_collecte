# Basemap regional offline

Cette stack repose desormais sur **un seul fichier `.pmtiles`** vectoriel
couvrant toute la zone d'intervention (region Oriental).
Le mobile telecharge ce fichier en un GET HTTP unique au login, puis le rejoue
hors ligne via `vector_map_tiles_pmtiles`.

## Architecture

```
serveur:  media/basemaps/region.pmtiles  (un seul fichier)
              |
              v  GET /api/basemaps/region/manifest/   (sha256, taille, version, url)
              v  GET /api/basemaps/region/download/   (stream avec Range)
              |
mobile:   ApplicationSupport/basemaps/region.pmtiles
              |
              v  PmTilesVectorTileProvider.fromSource(localPath)
              v  vector_map_tiles VectorTileLayer
```

Plus de zonage 21 communes, plus de packages multiples, plus de catalogue.
Le manifest est aussi stable que le fichier source.

## Endpoints

- `GET /api/basemaps/region/manifest/` -> `{ success, name, attribution,
  format, version, sha256, size_bytes, generated_at, download_url }`.
  Reponse `404` si aucun fichier n'est configure.
- `GET /api/basemaps/region/download/` -> stream `application/octet-stream`,
  supporte `Range: bytes=...` pour la reprise.

## Ou poser le fichier `.pmtiles`

Par defaut, le backend cherche dans cet ordre :

1. La variable d'environnement `BASEMAP_REGIONAL_PMTILES_PATH` (chemin absolu
   ou relatif a `BASE_DIR`).
2. `API_GeoDjango/pprcollecte/media/basemaps/region.pmtiles`.
3. (Fallback dev) `API_GeoDjango/basemaps/build/oujda_centre_demo_vector.pmtiles`.

## Generation du fichier

### Option A - Script automatique (recommande)

Aucune intervention manuelle, aucune source locale a telecharger : le script
s'appuie sur le CLI Protomaps `pmtiles extract` et le planet hebdomadaire
heberge sur `build.protomaps.com`. Seules les tuiles dans la bbox sont
telechargees via Range HTTP (~20 Mo pour la region Oriental au zoom 15).

```powershell
python API_GeoDjango/basemaps/scripts/extract_region_pmtiles.py
```

Le script :

1. Cherche automatiquement la derniere build planet disponible
   (`https://build.protomaps.com/<date>.pmtiles`).
2. Decoupe la bbox Oriental (`-2.7,34.2,-1.5,35.2` par defaut) au zoom max 15.
3. Ecrit le resultat dans
   `API_GeoDjango/pprcollecte/media/basemaps/region.pmtiles`.

Options utiles :

- `--maxzoom 16` -> ~80 Mo, detail batiment plus fin.
- `--west / --south / --east / --north` -> bbox personnalisee.
- `--source https://build.protomaps.com/YYYYMMDD.pmtiles` -> figer la version.
- `--dry-run` -> estime la taille sans telecharger.

A relancer apres mise a jour OSM (mensuelle suffit). Le mobile detecte le
nouveau sha256 via le manifest et re-telecharge automatiquement.

### Option B - Decoupage local depuis un planet PMTiles deja sur disque

```powershell
API_GeoDjango/basemaps/tools/pmtiles.exe extract `
    "C:\path\to\source\maroc.pmtiles" `
    "API_GeoDjango/pprcollecte/media/basemaps/region.pmtiles" `
    --bbox=-2.7,34.2,-1.5,35.2 `
    --maxzoom=15
```

### Option C - Build OSM -> PMTiles via planetiler

Pipeline avance pour generer un PMTiles vectoriel a partir d'un extract OSM
PBF (cf. https://github.com/protomaps/basemaps). Utile pour un style ou une
couverture differente du Protomaps public.

## Variables d'environnement

| Variable                          | Defaut                                     |
|-----------------------------------|--------------------------------------------|
| `BASEMAP_REGIONAL_PMTILES_PATH`   | (auto, voir ordre ci-dessus)               |
| `BASEMAP_REGIONAL_NAME`           | `SRM Oriental`                             |
| `BASEMAP_REGIONAL_ATTRIBUTION`    | `(c) Protomaps (c) OpenStreetMap contributors` |

## Cycle de mise a jour cote mobile

A chaque login (et a chaque telechargement de donnees) :

1. Le mobile appelle `/api/basemaps/region/manifest/`.
2. Si le `sha256` est identique au `regional_basemap_state` local, rien n'est
   telecharge.
3. Sinon, le fichier est recupere (Range pour reprise) et stocke dans
   `ApplicationSupport/basemaps/region.pmtiles`. La table SQLite
   `regional_basemap_state` est mise a jour.
