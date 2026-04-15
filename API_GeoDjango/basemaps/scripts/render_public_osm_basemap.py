from __future__ import annotations

import argparse
import os
import shutil
import subprocess
from pathlib import Path


DEFAULT_GDAL_BIN_DIRS = [
    Path(r"C:\Program Files\QGIS 3.40.14\bin"),
    Path(r"C:\Program Files\QGIS 3.34.12\bin"),
]


def resolve_executable(executable_name: str) -> Path:
    direct_match = shutil.which(executable_name)
    if direct_match:
        return Path(direct_match)

    exe_name = (
        executable_name
        if executable_name.lower().endswith(".exe")
        else f"{executable_name}.exe"
    )

    for bin_dir in DEFAULT_GDAL_BIN_DIRS:
        candidate = bin_dir / exe_name
        if candidate.exists():
            return candidate

    raise FileNotFoundError(f"Executable introuvable: {executable_name}")


def run_command(executable_name: str, arguments: list[str]) -> None:
    executable = resolve_executable(executable_name)
    command = [str(executable), *arguments]
    env = dict(os.environ)
    for bin_dir in DEFAULT_GDAL_BIN_DIRS:
        if executable.parent == bin_dir:
            qgis_root = bin_dir.parent
            env["PATH"] = str(bin_dir) + os.pathsep + env.get("PATH", "")
            proj_dir = qgis_root / "share" / "proj"
            gdal_data_dir = qgis_root / "share" / "gdal"
            if proj_dir.exists():
                env["PROJ_LIB"] = str(proj_dir)
            if gdal_data_dir.exists():
                env["GDAL_DATA"] = str(gdal_data_dir)
            break

    result = subprocess.run(command, capture_output=True, text=True, env=env)
    if result.returncode != 0:
        details = (result.stderr or result.stdout or "").strip() or "aucun detail"
        raise RuntimeError(f"Echec {executable_name}: {details}")


def rasterize(
    *,
    dataset_path: Path,
    target_raster_path: Path,
    layer_name: str,
    where_clause: str,
    color: tuple[int, int, int, int],
) -> None:
    arguments = [
        "-b",
        "1",
        "-b",
        "2",
        "-b",
        "3",
        "-b",
        "4",
        "-at",
        "-burn",
        str(color[0]),
        "-burn",
        str(color[1]),
        "-burn",
        str(color[2]),
        "-burn",
        str(color[3]),
        "-l",
        layer_name,
        "-where",
        where_clause,
        str(dataset_path),
        str(target_raster_path),
    ]
    run_command("gdal_rasterize", arguments)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Rend un fond raster OSM simple a partir d'un extract XML OSM cible. "
            "Le resultat est un GeoTIFF WGS84 qui peut ensuite etre converti en MBTiles."
        )
    )
    parser.add_argument("--osm", required=True, help="Chemin vers le fichier .osm source.")
    parser.add_argument(
        "--output",
        required=True,
        help="Chemin du GeoTIFF cible a produire.",
    )
    parser.add_argument("--west", required=True, type=float)
    parser.add_argument("--south", required=True, type=float)
    parser.add_argument("--east", required=True, type=float)
    parser.add_argument("--north", required=True, type=float)
    parser.add_argument("--width", type=int, default=8192)
    parser.add_argument("--height", type=int, default=8192)
    args = parser.parse_args()

    osm_path = Path(args.osm).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve()
    if not osm_path.exists():
        raise FileNotFoundError(f"Source OSM introuvable: {osm_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    if output_path.exists():
        output_path.unlink()

    run_command(
        "gdal_create",
        [
            "-of",
            "GTiff",
            "-ot",
            "Byte",
            "-outsize",
            str(args.width),
            str(args.height),
            "-bands",
            "4",
            "-burn",
            "246",
            "-burn",
            "243",
            "-burn",
            "236",
            "-burn",
            "255",
            "-a_srs",
            "EPSG:4326",
            "-a_ullr",
            str(args.west),
            str(args.north),
            str(args.east),
            str(args.south),
            "-co",
            "TILED=YES",
            "-co",
            "COMPRESS=DEFLATE",
            str(output_path),
        ],
    )

    render_passes = [
        {
            "layer_name": "multipolygons",
            "where_clause": (
                "leisure IN ('park','recreation_ground','garden','pitch',"
                "'sports_centre','playground') "
                "OR landuse IN ('grass','meadow','farmland','forest','farmyard','cemetery',"
                "'orchard','vineyard') "
                "OR natural IN ('wood','scrub')"
            ),
            "color": (222, 237, 209, 255),
        },
        {
            "layer_name": "multipolygons",
            "where_clause": "natural = 'water' OR landuse = 'reservoir'",
            "color": (173, 216, 230, 255),
        },
        {
            "layer_name": "multipolygons",
            "where_clause": (
                "landuse IN ('commercial','retail','construction','brownfield') "
                "OR amenity IN ('school','hospital','university','college')"
            ),
            "color": (239, 232, 220, 255),
        },
        {
            "layer_name": "multipolygons",
            "where_clause": "landuse IN ('industrial','depot','garages')",
            "color": (230, 226, 221, 255),
        },
        {
            "layer_name": "multipolygons",
            "where_clause": "building IS NOT NULL AND building <> ''",
            "color": (221, 217, 212, 255),
        },
        {
            "layer_name": "lines",
            "where_clause": "waterway IS NOT NULL AND waterway <> ''",
            "color": (133, 188, 224, 255),
        },
        {
            "layer_name": "lines",
            "where_clause": "railway IS NOT NULL AND railway <> ''",
            "color": (153, 153, 153, 255),
        },
        {
            "layer_name": "lines",
            "where_clause": (
                "highway IN ("
                "'tertiary','tertiary_link','residential','living_street',"
                "'service','unclassified','pedestrian','track'"
                ")"
            ),
            "color": (255, 255, 255, 255),
        },
        {
            "layer_name": "lines",
            "where_clause": "highway IN ('tertiary','tertiary_link')",
            "color": (250, 246, 240, 255),
        },
        {
            "layer_name": "lines",
            "where_clause": "highway IN ('footway','path','cycleway','steps')",
            "color": (245, 220, 177, 255),
        },
        {
            "layer_name": "lines",
            "where_clause": (
                "highway IN ("
                "'motorway','motorway_link','trunk','trunk_link',"
                "'primary','primary_link','secondary','secondary_link'"
                ")"
            ),
            "color": (244, 187, 120, 255),
        },
    ]

    for render_pass in render_passes:
        rasterize(
            dataset_path=osm_path,
            target_raster_path=output_path,
            layer_name=render_pass["layer_name"],
            where_clause=render_pass["where_clause"],
            color=render_pass["color"],
        )

    print(f"Raster genere: {output_path}")


if __name__ == "__main__":
    main()
