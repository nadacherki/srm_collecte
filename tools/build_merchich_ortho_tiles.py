#!/usr/bin/env python
"""Build a reproducible EPSG:26191 ortho tile pyramid from a GeoTIFF.

The app reads the generated manifest and uses the same origin/resolutions for
tap -> X/Y Merchich conversion. The highest zoom is always the source pixel
size, so QGIS and the mobile app share the same geometry.

Run with the QGIS Python runtime when plain Python cannot import osgeo:

  "C:\\Program Files\\QGIS 3.40.14\\bin\\python-qgis-ltr.bat" \
      tools\\build_merchich_ortho_tiles.py LOUDAYA2.tif out\\loudaya2
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path

try:
    from osgeo import gdal, osr
except Exception as exc:  # pragma: no cover - depends on local GDAL install
    raise SystemExit(
        "GDAL Python bindings are required. Use the QGIS Python runtime."
    ) from exc

gdal.UseExceptions()


WEBP_DRIVER = "WEBP"
PNG_DRIVER = "PNG"
JPEG_DRIVER = "JPEG"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build EPSG:26191 raster tiles using the GeoTIFF native resolution."
    )
    parser.add_argument("input_tif", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--name", default=None)
    parser.add_argument(
        "--package-type",
        choices=("ortho", "basemap"),
        default="ortho",
        help="Manifest package type. Use 'basemap' for offline base maps.",
    )
    parser.add_argument("--tile-size", type=int, default=512)
    parser.add_argument(
        "--format",
        choices=("webp", "png", "jpg"),
        default="webp",
        help="Tile image format. WebP is the preferred mobile default.",
    )
    parser.add_argument("--quality", type=int, default=90)
    parser.add_argument(
        "--resampling",
        choices=("nearest", "bilinear", "cubic", "lanczos"),
        default="bilinear",
    )
    parser.add_argument(
        "--min-overview-pixels",
        type=int,
        default=512,
        help="Coarsest zoom target for the longest raster side.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Only print the manifest; do not write tiles.",
    )
    parser.add_argument(
        "--skip-tiles",
        action="store_true",
        help="Reuse an existing output_dir/tiles folder and only rebuild manifest/PMTiles.",
    )
    parser.add_argument(
        "--pmtiles",
        type=Path,
        default=None,
        help="Optional PMTiles output. Requires a 'pmtiles' CLI in PATH.",
    )
    parser.add_argument(
        "--pmtiles-cli",
        type=Path,
        default=None,
        help="Optional explicit pmtiles CLI path.",
    )
    return parser.parse_args()


def dataset_info(input_tif: Path) -> dict:
    ds = gdal.Open(str(input_tif), gdal.GA_ReadOnly)
    if ds is None:
        raise SystemExit(f"Cannot open raster: {input_tif}")

    gt = ds.GetGeoTransform(can_return_null=True)
    if gt is None:
        raise SystemExit("Input raster has no GeoTransform.")

    origin_x, pixel_w, rot_x, origin_y, rot_y, pixel_h = gt
    if abs(rot_x) > 1e-12 or abs(rot_y) > 1e-12:
        raise SystemExit("Rotated rasters are not supported. Rewarp first.")
    if pixel_w <= 0 or pixel_h >= 0:
        raise SystemExit("Expected north-up raster with positive X and negative Y pixel size.")

    native_res_x = abs(pixel_w)
    native_res_y = abs(pixel_h)
    if abs(native_res_x - native_res_y) > 1e-9:
        raise SystemExit(
            f"Non-square pixels are not supported: {native_res_x} x {native_res_y}."
        )

    sr = osr.SpatialReference()
    sr.ImportFromWkt(ds.GetProjectionRef() or "")
    epsg = None
    try:
        authority = sr.GetAuthorityName(None)
        code = sr.GetAuthorityCode(None)
        if authority and code:
            epsg = int(code)
    except Exception:
        epsg = None

    wkt = ds.GetProjectionRef() or ""
    wkt_lower = wkt.lower()
    looks_merchich = epsg == 26191 or (
        "merchich" in wkt_lower
        and "lambert" in wkt_lower
        and "500000" in wkt_lower
        and "300000" in wkt_lower
    )
    if not looks_merchich:
        raise SystemExit(
            "Input CRS is not recognized as Merchich EPSG:26191. Reproject before tiling."
        )

    width = ds.RasterXSize
    height = ds.RasterYSize
    min_x = origin_x
    max_y = origin_y
    max_x = origin_x + width * native_res_x
    min_y = origin_y - height * native_res_y

    return {
        "dataset": ds,
        "epsg": 26191,
        "width": width,
        "height": height,
        "native_resolution": native_res_x,
        "origin_x": origin_x,
        "origin_y": origin_y,
        "min_x": min_x,
        "min_y": min_y,
        "max_x": max_x,
        "max_y": max_y,
    }


def build_resolutions(native_resolution: float, width: int, height: int, min_pixels: int) -> list[float]:
    longest = max(width, height)
    if longest <= min_pixels:
        max_overview_power = 0
    else:
        max_overview_power = math.ceil(math.log2(longest / min_pixels))
    return [native_resolution * (2**power) for power in range(max_overview_power, -1, -1)]


def manifest_for(args: argparse.Namespace, info: dict, resolutions: list[float]) -> dict:
    return {
        "type": args.package_type,
        "name": args.name or args.input_tif.stem,
        "srid": 26191,
        "crs": "EPSG:26191",
        "tileSize": args.tile_size,
        "tileFormat": args.format,
        "quality": args.quality if args.format in ("webp", "jpg") else None,
        "nativeResolution": info["native_resolution"],
        "minZoom": 0,
        "maxZoom": len(resolutions) - 1,
        "origin": {"x": info["origin_x"], "y": info["origin_y"]},
        "boundsMerchich": {
            "minX": info["min_x"],
            "minY": info["min_y"],
            "maxX": info["max_x"],
            "maxY": info["max_y"],
        },
        "rasterSize": {"width": info["width"], "height": info["height"]},
        "resolutions": resolutions,
    }


def driver_for(fmt: str) -> str:
    if fmt == "webp":
        return WEBP_DRIVER
    if fmt == "png":
        return PNG_DRIVER
    return JPEG_DRIVER


def extension_for(fmt: str) -> str:
    return "jpg" if fmt == "jpg" else fmt


def creation_options(fmt: str, quality: int) -> list[str]:
    if fmt == "webp":
        return [f"QUALITY={quality}"]
    if fmt == "jpg":
        return [f"QUALITY={quality}"]
    return []


def build_tiles(args: argparse.Namespace, info: dict, resolutions: list[float]) -> None:
    tiles_root = args.output_dir / "tiles"
    if tiles_root.exists():
        shutil.rmtree(tiles_root)
    tiles_root.mkdir(parents=True, exist_ok=True)

    fmt_ext = extension_for(args.format)
    driver = driver_for(args.format)
    options = creation_options(args.format, args.quality)
    src_ds = info["dataset"]

    for z, resolution in enumerate(resolutions):
        zoom_dir = tiles_root / str(z)
        scale = info["native_resolution"] / resolution
        zoom_width = math.ceil(info["width"] * scale)
        zoom_height = math.ceil(info["height"] * scale)
        tiles_x = math.ceil(zoom_width / args.tile_size)
        tiles_y = math.ceil(zoom_height / args.tile_size)

        for x in range(tiles_x):
            x_dir = zoom_dir / str(x)
            x_dir.mkdir(parents=True, exist_ok=True)
            for y in range(tiles_y):
                min_x = info["origin_x"] + x * args.tile_size * resolution
                max_y = info["origin_y"] - y * args.tile_size * resolution
                max_x = min_x + args.tile_size * resolution
                min_y = max_y - args.tile_size * resolution
                out_path = x_dir / f"{y}.{fmt_ext}"

                warp_options = gdal.WarpOptions(
                    format=driver,
                    outputBounds=(min_x, min_y, max_x, max_y),
                    width=args.tile_size,
                    height=args.tile_size,
                    dstSRS=src_ds.GetProjectionRef(),
                    resampleAlg=args.resampling,
                    srcNodata=None,
                    dstAlpha=args.format != "jpg",
                    creationOptions=options,
                )
                result = gdal.Warp(str(out_path), src_ds, options=warp_options)
                if result is None:
                    raise SystemExit(f"Failed to write tile z={z} x={x} y={y}")
                result = None


def write_manifest(output_dir: Path, manifest: dict) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(
        json.dumps({k: v for k, v in manifest.items() if v is not None}, indent=2),
        encoding="utf-8",
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_pmtiles(output_dir: Path, pmtiles_path: Path, explicit_cli: Path | None) -> None:
    cli = str(explicit_cli) if explicit_cli is not None else shutil.which("pmtiles")
    if explicit_cli is not None and not explicit_cli.exists():
        raise SystemExit(f"Cannot build PMTiles: CLI not found: {explicit_cli}")
    if cli is None and shutil.which("npx") is None:
        raise SystemExit(
            "Cannot build PMTiles: neither 'pmtiles' nor 'npx' is in PATH."
        )
    tiles_root = output_dir / "tiles"
    mbtiles_path = output_dir / "tiles.mbtiles"
    manifest = json.loads((output_dir / "manifest.json").read_text(encoding="utf-8"))
    build_mbtiles(
        tiles_root,
        mbtiles_path,
        tile_format=str(manifest.get("tileFormat") or "webp"),
        package_type=str(manifest.get("type") or "baselayer"),
    )
    command = (
        [cli, "convert", "--force", str(mbtiles_path), str(pmtiles_path)]
        if cli is not None
        else ["npx", "-y", "pmtiles", "convert", "--force", str(mbtiles_path), str(pmtiles_path)]
    )
    subprocess.run(
        command,
        check=True,
    )


def build_mbtiles(
    tiles_root: Path,
    mbtiles_path: Path,
    *,
    tile_format: str,
    package_type: str,
) -> None:
    if mbtiles_path.exists():
        mbtiles_path.unlink()
    connection = sqlite3.connect(str(mbtiles_path))
    try:
        connection.execute(
            "CREATE TABLE metadata (name TEXT, value TEXT)"
        )
        connection.execute(
            "CREATE TABLE tiles (zoom_level INTEGER, tile_column INTEGER, tile_row INTEGER, tile_data BLOB)"
        )
        connection.execute(
            "CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row)"
        )
        metadata = {
            "name": tiles_root.parent.name,
            "type": "baselayer",
            "version": "1",
            "description": "SRM Merchich EPSG:26191 raster tiles",
            "format": "jpg" if tile_format == "jpg" else tile_format,
            "srm_type": package_type,
            "srs": "EPSG:26191",
        }
        connection.executemany(
            "INSERT INTO metadata (name, value) VALUES (?, ?)",
            metadata.items(),
        )
        valid_suffixes = {".webp", ".png", ".jpg", ".jpeg"}
        for tile_path in sorted(tiles_root.glob("*/*/*.*")):
            if tile_path.suffix.lower() not in valid_suffixes:
                continue
            z = int(tile_path.parent.parent.name)
            x = int(tile_path.parent.name)
            y = int(tile_path.stem)
            # MBTiles stores TMS rows. PMTiles convert flips them back to XYZ.
            tms_y = (1 << z) - 1 - y
            connection.execute(
                "INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?)",
                (z, x, tms_y, tile_path.read_bytes()),
            )
        connection.commit()
    finally:
        connection.close()


def main() -> int:
    args = parse_args()
    info = dataset_info(args.input_tif)
    resolutions = build_resolutions(
        info["native_resolution"],
        info["width"],
        info["height"],
        args.min_overview_pixels,
    )
    manifest = manifest_for(args, info, resolutions)

    if args.dry_run:
        print(json.dumps({k: v for k, v in manifest.items() if v is not None}, indent=2))
        return 0

    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_manifest(args.output_dir, manifest)
    if not args.skip_tiles:
        build_tiles(args, info, resolutions)

    if args.pmtiles is not None:
        build_pmtiles(args.output_dir, args.pmtiles, args.pmtiles_cli)
        manifest["sha256"] = sha256(args.pmtiles)
        manifest["size_bytes"] = args.pmtiles.stat().st_size
        write_manifest(args.output_dir, manifest)

    return 0


if __name__ == "__main__":
    sys.exit(main())
