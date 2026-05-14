"""Telecharge un PMTiles regional pour SRM Oriental sans intervention manuelle.

Le script s'appuie sur le CLI Protomaps `pmtiles extract` et le planet PMTiles
hebergeur https://build.protomaps.com/<date>.pmtiles. Aucune source locale
n'est requise : seules les tuiles dans la bbox sont telechargees via Range
HTTP (typiquement 20 Mo pour la region Oriental au zoom 15).

Usage rapide (defaut bbox Oriental, derniere build planet) :

    python API_GeoDjango/basemaps/scripts/extract_region_pmtiles.py

Usage avance (bbox custom + zoom max + source explicite) :

    python API_GeoDjango/basemaps/scripts/extract_region_pmtiles.py \\
        --west -3.0 --south 34.0 --east -1.4 --north 35.4 \\
        --maxzoom 16 \\
        --source https://build.protomaps.com/20260501.pmtiles

Resultat : ecriture dans API_GeoDjango/pprcollecte/media/basemaps/region.pmtiles
(ou --output explicite). Le serveur expose ensuite ce fichier via
GET /api/basemaps/region/manifest/ et GET /api/basemaps/region/download/.
"""

from __future__ import annotations

import argparse
import datetime as dt
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_PMTILES_CLI = REPO_ROOT / "basemaps" / "tools" / "pmtiles.exe"
DEFAULT_OUTPUT = (
    REPO_ROOT / "pprcollecte" / "media" / "basemaps" / "region.pmtiles"
)
PROTOMAPS_BUILD_URL_TEMPLATE = "https://build.protomaps.com/{date}.pmtiles"

# bbox region Oriental (Oujda + perimetres EP/ASS), en WGS84 (EPSG:4326)
DEFAULT_BBOX = {
    "west": -2.7,
    "south": 34.2,
    "east": -1.5,
    "north": 35.2,
}
DEFAULT_MAXZOOM = 15


def resolve_pmtiles_cli(explicit: str | None) -> Path:
    if explicit:
        path = Path(explicit).expanduser().resolve()
        if not path.exists():
            raise FileNotFoundError(f"pmtiles CLI introuvable: {path}")
        return path

    if DEFAULT_PMTILES_CLI.exists():
        return DEFAULT_PMTILES_CLI

    which = shutil.which("pmtiles")
    if which:
        return Path(which)

    raise FileNotFoundError(
        "pmtiles CLI introuvable. Specifier --pmtiles-cli ou deposer "
        "API_GeoDjango/basemaps/tools/pmtiles.exe."
    )


def _is_planet_url_available(url: str) -> bool:
    # Cloudflare devant build.protomaps.com peut bloquer HEAD ou les requetes
    # sans User-Agent : on tente un GET Range minimal a la place.
    request = urllib.request.Request(
        url,
        method="GET",
        headers={
            "User-Agent": "srm-collecte-basemap/1.0",
            "Range": "bytes=0-0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status in (200, 206)
    except Exception:
        return False


def discover_latest_planet_url(reference_date: dt.date | None = None) -> str:
    """Cherche la build planet PMTiles la plus recente disponible.

    Les builds Protomaps sont hebdomadaires/mensuelles. On essaie en partant
    d'aujourd'hui en remontant par increments de 15 jours sur 6 mois.
    """
    today = reference_date or dt.date.today()
    candidates = [today - dt.timedelta(days=offset) for offset in range(0, 200, 15)]
    for candidate in candidates:
        url = PROTOMAPS_BUILD_URL_TEMPLATE.format(date=candidate.strftime("%Y%m%d"))
        if _is_planet_url_available(url):
            return url
    raise RuntimeError(
        "Aucune build planet Protomaps trouvee dans les 6 derniers mois. "
        "Specifier explicitement --source <url>."
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--source",
        default=None,
        help=(
            "URL ou chemin local d'un PMTiles source. Par defaut, le script "
            "cherche la derniere build planet disponible sur build.protomaps.com."
        ),
    )
    parser.add_argument("--west", type=float, default=DEFAULT_BBOX["west"])
    parser.add_argument("--south", type=float, default=DEFAULT_BBOX["south"])
    parser.add_argument("--east", type=float, default=DEFAULT_BBOX["east"])
    parser.add_argument("--north", type=float, default=DEFAULT_BBOX["north"])
    parser.add_argument(
        "--maxzoom",
        type=int,
        default=DEFAULT_MAXZOOM,
        help=(
            "Zoom max inclus (defaut 15, ~20 Mo pour la region Oriental). "
            "Z=16 environ x4 (~80 Mo)."
        ),
    )
    parser.add_argument("--minzoom", type=int, default=-1)
    parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT),
        help="Chemin du PMTiles cible (defaut: media/basemaps/region.pmtiles).",
    )
    parser.add_argument(
        "--pmtiles-cli",
        default=None,
        help="Chemin du binaire pmtiles. Defaut: API_GeoDjango/basemaps/tools/pmtiles.exe.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Calcule la taille de l'extraction sans rien telecharger.",
    )
    args = parser.parse_args()

    cli = resolve_pmtiles_cli(args.pmtiles_cli)

    source = args.source
    if source is None:
        print("Recherche de la derniere build planet Protomaps...", file=sys.stderr)
        source = discover_latest_planet_url()
        print(f"  -> {source}", file=sys.stderr)

    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if not args.dry_run and output.exists():
        output.unlink()

    bbox = f"{args.west},{args.south},{args.east},{args.north}"
    command = [
        str(cli),
        "extract",
        str(source),
        str(output),
        f"--bbox={bbox}",
        f"--maxzoom={args.maxzoom}",
    ]
    if args.minzoom >= 0:
        command.append(f"--minzoom={args.minzoom}")
    if args.dry_run:
        command.append("--dry-run")
    print("Commande:", " ".join(command))
    result = subprocess.run(command, check=False)
    if result.returncode != 0:
        print("Echec extraction PMTiles", file=sys.stderr)
        return result.returncode

    if not args.dry_run:
        size = output.stat().st_size
        print(f"OK basemap regional ecrit: {output} ({size / (1024 * 1024):.1f} Mo)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
