"""
Build XYZ lossless orthophoto tiles from a GeoTIFF and write manifest.json.

Requires GDAL command line tools on PATH: gdalinfo, gdalwarp.
The mobile app never consumes the GeoTIFF directly; it only reads 256px tiles.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
API_ROOT = SCRIPT_DIR.parents[1]
DEFAULT_OUTPUT_ROOT = API_ROOT / "pprcollecte" / "media" / "orthophotos"
WEB_MERCATOR_HALF_WORLD = 20037508.342789244
WEB_MERCATOR_MAX_LAT = 85.0511287798066


def run_command(args: list[str]) -> None:
    print("+ " + " ".join(str(arg) for arg in args), flush=True)
    subprocess.run(args, check=True)


def run_quiet(args: list[str]) -> None:
    try:
        subprocess.run(args, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as exc:
        if exc.stdout:
            print(exc.stdout, file=sys.stderr)
        if exc.stderr:
            print(exc.stderr, file=sys.stderr)
        raise


def require_tool(name: str) -> str:
    resolved = shutil.which(name)
    if resolved:
        return resolved
    raise FileNotFoundError(
        f"{name} introuvable. Installer GDAL/OSGeo4W et ajouter ses outils au PATH."
    )


def read_gdalinfo(source: Path) -> dict:
    os.environ.setdefault("GTIFF_SRS_SOURCE", "EPSG")
    gdalinfo = require_tool("gdalinfo")
    output = subprocess.check_output(
        [gdalinfo, "-json", str(source)],
        text=True,
        encoding="utf-8",
    )
    return json.loads(output)


def detect_epsg(info: dict) -> int | None:
    stac_epsg = (info.get("stac") or {}).get("proj:epsg")
    if stac_epsg:
        return int(stac_epsg)
    coordinate_system = info.get("coordinateSystem") or {}
    wkt = coordinate_system.get("wkt") or ""
    if "ID[\"EPSG\"," in wkt:
        tail = wkt.rsplit("ID[\"EPSG\",", 1)[-1]
        digits = []
        for char in tail:
            if char.isdigit():
                digits.append(char)
            elif digits:
                break
        if digits:
            return int("".join(digits))
    for metadata in (info.get("metadata") or {}).values():
        if isinstance(metadata, dict):
            for value in metadata.values():
                if "EPSG" in str(value):
                    digits = "".join(ch for ch in str(value) if ch.isdigit())
                    if digits:
                        return int(digits)
    return None


def wgs84_bounds(info: dict) -> list[float]:
    extent = info.get("wgs84Extent") or {}
    coordinates = extent.get("coordinates") or []
    points = coordinates[0] if coordinates else []
    xs = [float(point[0]) for point in points]
    ys = [float(point[1]) for point in points]
    if not xs or not ys:
        raise RuntimeError("gdalinfo ne retourne pas wgs84Extent.")
    return [min(xs), min(ys), max(xs), max(ys)]


def tile_bounds_4326(z: int, x: int, y: int) -> list[float]:
    n = 2.0**z
    west = x / n * 360.0 - 180.0
    east = (x + 1) / n * 360.0 - 180.0

    def mercator_y_to_lat(tile_y: int) -> float:
        radians = math.atan(math.sinh(math.pi * (1 - 2 * tile_y / n)))
        return math.degrees(radians)

    north = mercator_y_to_lat(y)
    south = mercator_y_to_lat(y + 1)
    return [west, south, east, north]


def tile_bounds_3857(z: int, x: int, y: int) -> list[float]:
    tile_width = (WEB_MERCATOR_HALF_WORLD * 2) / (2**z)
    west = -WEB_MERCATOR_HALF_WORLD + x * tile_width
    east = west + tile_width
    north = WEB_MERCATOR_HALF_WORLD - y * tile_width
    south = north - tile_width
    return [west, south, east, north]


def lon_to_tile_x(lon: float, z: int) -> int:
    n = 2**z
    value = int(math.floor((lon + 180.0) / 360.0 * n))
    return max(0, min(n - 1, value))


def lat_to_tile_y(lat: float, z: int) -> int:
    lat = max(-WEB_MERCATOR_MAX_LAT, min(WEB_MERCATOR_MAX_LAT, lat))
    n = 2**z
    lat_rad = math.radians(lat)
    value = int(
        math.floor(
            (1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n
        )
    )
    return max(0, min(n - 1, value))


def iter_xyz_tile_specs(bounds: list[float], min_zoom: int, max_zoom: int):
    west, south, east, north = bounds
    for z in range(min_zoom, max_zoom + 1):
        x_min = lon_to_tile_x(west, z)
        x_max = lon_to_tile_x(east, z)
        y_min = lat_to_tile_y(north, z)
        y_max = lat_to_tile_y(south, z)
        for x in range(x_min, x_max + 1):
            for y in range(y_min, y_max + 1):
                yield {
                    "z": z,
                    "x": x,
                    "y": y,
                    "bounds_4326": tile_bounds_4326(z, x, y),
                    "bounds_3857": tile_bounds_3857(z, x, y),
                }


def iter_tiles(tiles_dir: Path, tile_format: str):
    for tile_path in sorted(tiles_dir.glob(f"*/*/*.{tile_format}")):
        try:
            z = int(tile_path.parents[1].name)
            x = int(tile_path.parent.name)
            y = int(tile_path.stem)
        except ValueError:
            continue
        yield z, x, y, tile_path


def write_manifest(
    package_dir: Path,
    source: Path,
    ortho_id: str,
    version: str,
    min_zoom: int,
    max_zoom: int,
    bounds: list[float],
    tile_format: str,
    resampling: str,
    source_epsg: int | None,
) -> None:
    tiles_dir = package_dir / "tiles"
    tiles = []
    total_bytes = 0
    for z, x, y, tile_path in iter_tiles(tiles_dir, tile_format):
        digest = hashlib.sha256(tile_path.read_bytes()).hexdigest()
        size_bytes = tile_path.stat().st_size
        total_bytes += size_bytes
        tiles.append(
            {
                "z": z,
                "x": x,
                "y": y,
                "path": tile_path.relative_to(package_dir).as_posix(),
                "size_bytes": size_bytes,
                "sha256": digest,
                "bounds_4326": tile_bounds_4326(z, x, y),
                "bounds_3857": tile_bounds_3857(z, x, y),
            }
        )

    manifest = {
        "ortho_id": ortho_id,
        "version": version,
        "format": tile_format,
        "mime_type": "image/tiff",
        "lossless": True,
        "compression": "NONE",
        "resampling": resampling,
        "source_epsg": source_epsg,
        "tile_epsg": 3857,
        "tile_grid": "XYZ",
        "tile_size": 256,
        "min_zoom": min_zoom,
        "max_zoom": max_zoom,
        "bounds_4326": bounds,
        "source_name": source.name,
        "generated_at": dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
        "tile_count": len(tiles),
        "total_bytes": total_bytes,
        "tiles": tiles,
    }
    (package_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def build_geotiff_tile(
    gdalwarp: str,
    warped_source: Path,
    tile: dict,
    tile_path: Path,
    resampling: str,
) -> None:
    west, south, east, north = tile["bounds_3857"]
    tile_path.parent.mkdir(parents=True, exist_ok=True)
    run_quiet(
        [
            gdalwarp,
            "-overwrite",
            "-of",
            "GTiff",
            "-te",
            str(west),
            str(south),
            str(east),
            str(north),
            "-te_srs",
            "EPSG:3857",
            "-ts",
            "256",
            "256",
            "-r",
            resampling,
            "-srcalpha",
            "-dstalpha",
            "-co",
            "TILED=YES",
            "-co",
            "BLOCKXSIZE=256",
            "-co",
            "BLOCKYSIZE=256",
            "-co",
            "COMPRESS=NONE",
            "-co",
            "BIGTIFF=IF_SAFER",
            str(warped_source),
            str(tile_path),
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="GeoTIFF source.")
    parser.add_argument("--ortho-id", default="active")
    parser.add_argument("--version", default="")
    parser.add_argument("--output-root", default=str(DEFAULT_OUTPUT_ROOT))
    parser.add_argument("--minzoom", type=int, default=17)
    parser.add_argument("--maxzoom", type=int, default=22)
    parser.add_argument(
        "--tile-format",
        choices=["tif", "geotiff"],
        default="tif",
        help="Format des tuiles: GeoTIFF non compresse.",
    )
    parser.add_argument(
        "--resampling",
        default="lanczos",
        help="Methode GDAL pour la reprojection et les pyramides.",
    )
    parser.add_argument("--processes", type=int, default=max(os.cpu_count() or 1, 1))
    parser.add_argument("--keep-work", action="store_true")
    args = parser.parse_args()

    source = Path(args.source).expanduser().resolve()
    if not source.exists():
        raise FileNotFoundError(f"GeoTIFF introuvable: {source}")

    version = args.version.strip() or dt.datetime.utcnow().strftime("%Y%m%d%H%M%S")
    output_root = Path(args.output_root).expanduser().resolve()
    package_dir = output_root / args.ortho_id / version
    tiles_dir = package_dir / "tiles"
    if package_dir.exists():
        raise FileExistsError(f"Package deja existant: {package_dir}")
    tiles_dir.mkdir(parents=True, exist_ok=True)

    gdalwarp = require_tool("gdalwarp")
    info = read_gdalinfo(source)
    epsg = detect_epsg(info)
    if epsg != 26191:
        print(
            f"Attention: EPSG source detecte {epsg}; le GeoTIFF attendu est EPSG:26191.",
            file=sys.stderr,
        )
    bounds = wgs84_bounds(info)
    tile_format = "tif"
    tile_specs = list(iter_xyz_tile_specs(bounds, args.minzoom, args.maxzoom))
    if not tile_specs:
        raise RuntimeError("Aucune tuile XYZ ne croise l'emprise source.")

    work_dir_obj = tempfile.TemporaryDirectory(prefix="srm_ortho_")
    work_dir = Path(work_dir_obj.name)
    try:
        warped = work_dir / "warped_3857.tif"
        run_command(
            [
                gdalwarp,
                "-t_srs",
                "EPSG:3857",
                "-r",
                args.resampling,
                "-dstalpha",
                "-of",
                "GTiff",
                "-co",
                "TILED=YES",
                "-co",
                "BIGTIFF=YES",
                "-co",
                "COMPRESS=NONE",
                str(source),
                str(warped),
            ]
        )
        print(f"Generation GeoTIFF: {len(tile_specs)} tuiles", flush=True)
        completed = 0
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=max(args.processes, 1)
        ) as executor:
            futures = []
            for tile in tile_specs:
                z = tile["z"]
                x = tile["x"]
                y = tile["y"]
                tile_path = tiles_dir / str(z) / str(x) / f"{y}.{tile_format}"
                futures.append(
                    executor.submit(
                        build_geotiff_tile,
                        gdalwarp,
                        warped,
                        tile,
                        tile_path,
                        args.resampling,
                    )
                )
            for future in concurrent.futures.as_completed(futures):
                future.result()
                completed += 1
                if completed == len(futures) or completed % 100 == 0:
                    print(
                        f"  {completed}/{len(futures)} tuiles GeoTIFF",
                        flush=True,
                    )
        write_manifest(
            package_dir,
            source,
            args.ortho_id,
            version,
            args.minzoom,
            args.maxzoom,
            bounds,
            tile_format,
            args.resampling,
            epsg,
        )
        print(f"Orthophoto package genere: {package_dir}")
        return 0
    finally:
        if args.keep_work:
            print(f"Workdir conserve: {work_dir}")
        else:
            work_dir_obj.cleanup()


if __name__ == "__main__":
    raise SystemExit(main())
