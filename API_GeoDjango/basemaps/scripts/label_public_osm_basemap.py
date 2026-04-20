from __future__ import annotations

import argparse
import math
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

from osgeo import gdal
from PIL import Image, ImageDraw, ImageFont


@dataclass(frozen=True)
class Label:
    text: str
    lon: float
    lat: float
    size: int
    fill: tuple[int, int, int, int]
    stroke_fill: tuple[int, int, int, int]
    stroke_width: int


POINT_TAGS = {
    "amenity",
    "shop",
    "tourism",
    "place",
    "leisure",
    "historic",
    "office",
    "craft",
}


POINT_FONT_SIZES = {
    "place:city": 22,
    "place:town": 20,
    "place:suburb": 18,
    "place:neighbourhood": 16,
    "amenity": 14,
    "shop": 13,
    "tourism": 13,
    "leisure": 13,
    "historic": 13,
}


ROAD_FONT_SIZES = {
    "motorway": 14,
    "trunk": 14,
    "primary": 14,
    "secondary": 13,
    "tertiary": 12,
    "residential": 11,
    "living_street": 11,
    "service": 10,
    "unclassified": 10,
    "pedestrian": 10,
}


ROAD_TAGS = {
    "motorway",
    "motorway_link",
    "trunk",
    "trunk_link",
    "primary",
    "primary_link",
    "secondary",
    "secondary_link",
    "tertiary",
    "tertiary_link",
    "residential",
    "living_street",
    "service",
    "unclassified",
    "pedestrian",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Ajoute des libelles simples (voies et points nommes) a un raster "
            "OSM deja genere, en preservant le georeferencement GeoTIFF."
        )
    )
    parser.add_argument("--osm", required=True, help="Fichier .osm source.")
    parser.add_argument("--input-raster", required=True, help="GeoTIFF source.")
    parser.add_argument("--output-raster", required=True, help="GeoTIFF cible.")
    parser.add_argument("--west", required=True, type=float)
    parser.add_argument("--south", required=True, type=float)
    parser.add_argument("--east", required=True, type=float)
    parser.add_argument("--north", required=True, type=float)
    parser.add_argument(
        "--max-point-labels",
        type=int,
        default=180,
        help="Nombre maximal de libelles ponctuels.",
    )
    parser.add_argument(
        "--max-road-labels",
        type=int,
        default=220,
        help="Nombre maximal de libelles de voirie.",
    )
    return parser.parse_args()


def load_font(size: int) -> ImageFont.ImageFont:
    font_candidates = [
        Path(r"C:\Windows\Fonts\segoeui.ttf"),
        Path(r"C:\Windows\Fonts\arial.ttf"),
        Path(r"C:\Windows\Fonts\DejaVuSans.ttf"),
    ]
    for candidate in font_candidates:
        if candidate.exists():
            try:
                return ImageFont.truetype(str(candidate), size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def category_font_size(tags: dict[str, str]) -> int:
    place = tags.get("place")
    if place:
        return POINT_FONT_SIZES.get(f"place:{place}", 15)
    for tag in ("amenity", "shop", "tourism", "leisure", "historic"):
        if tag in tags:
            return POINT_FONT_SIZES.get(tag, 13)
    return 12


def road_font_size(highway: str) -> int:
    return ROAD_FONT_SIZES.get(highway, 11)


def waypoint_midpoint(refs: list[str], nodes: dict[str, tuple[float, float]]) -> tuple[float, float] | None:
    coordinates = [nodes[ref] for ref in refs if ref in nodes]
    if len(coordinates) < 2:
        return None

    segment_lengths: list[float] = []
    total = 0.0
    for start, end in zip(coordinates, coordinates[1:]):
        dx = end[0] - start[0]
        dy = end[1] - start[1]
        length = math.hypot(dx, dy)
        segment_lengths.append(length)
        total += length

    if total <= 0:
        lon = sum(coord[0] for coord in coordinates) / len(coordinates)
        lat = sum(coord[1] for coord in coordinates) / len(coordinates)
        return lon, lat

    target = total / 2
    walked = 0.0
    for index, segment_length in enumerate(segment_lengths):
        if walked + segment_length >= target:
            ratio = 0.0 if segment_length == 0 else (target - walked) / segment_length
            start = coordinates[index]
            end = coordinates[index + 1]
            lon = start[0] + (end[0] - start[0]) * ratio
            lat = start[1] + (end[1] - start[1]) * ratio
            return lon, lat
        walked += segment_length

    return coordinates[len(coordinates) // 2]


def extract_labels(
    osm_path: Path,
    *,
    max_point_labels: int,
    max_road_labels: int,
) -> tuple[list[Label], list[Label]]:
    nodes: dict[str, tuple[float, float]] = {}
    point_labels: list[Label] = []
    road_labels: list[Label] = []

    for _, elem in ET.iterparse(str(osm_path), events=("end",)):
        if elem.tag == "node":
            node_id = elem.attrib.get("id")
            lon = elem.attrib.get("lon")
            lat = elem.attrib.get("lat")
            if node_id and lon and lat:
                nodes[node_id] = (float(lon), float(lat))

            if len(point_labels) < max_point_labels:
                tags = {
                    child.attrib["k"]: child.attrib["v"]
                    for child in elem
                    if child.tag == "tag"
                }
                name = tags.get("name", "").strip()
                if name and any(tag in tags for tag in POINT_TAGS):
                    lon_lat = nodes.get(node_id or "")
                    if lon_lat is not None:
                        point_labels.append(
                            Label(
                                text=name,
                                lon=lon_lat[0],
                                lat=lon_lat[1],
                                size=category_font_size(tags),
                                fill=(64, 64, 64, 220),
                                stroke_fill=(255, 255, 255, 235),
                                stroke_width=2,
                            )
                        )
            elem.clear()
            continue

        if elem.tag == "way":
            if len(road_labels) >= max_road_labels:
                elem.clear()
                continue

            tags = {
                child.attrib["k"]: child.attrib["v"]
                for child in elem
                if child.tag == "tag"
            }
            highway = tags.get("highway", "").strip()
            name = tags.get("name", "").strip()
            if highway in ROAD_TAGS and name:
                refs = [
                    child.attrib["ref"]
                    for child in elem
                    if child.tag == "nd" and "ref" in child.attrib
                ]
                midpoint = waypoint_midpoint(refs, nodes)
                if midpoint is not None:
                    road_labels.append(
                        Label(
                            text=name,
                            lon=midpoint[0],
                            lat=midpoint[1],
                            size=road_font_size(highway),
                            fill=(106, 88, 65, 210),
                            stroke_fill=(255, 255, 255, 235),
                            stroke_width=2,
                        )
                    )
            elem.clear()

    return deduplicate_labels(point_labels), deduplicate_labels(road_labels)


def deduplicate_labels(labels: list[Label]) -> list[Label]:
    kept: list[Label] = []
    seen_text_positions: dict[str, list[tuple[float, float]]] = {}
    for label in labels:
        positions = seen_text_positions.setdefault(label.text.lower(), [])
        if any(
            math.hypot(existing_x - label.lon, existing_y - label.lat) < 0.0008
            for existing_x, existing_y in positions
        ):
            continue
        positions.append((label.lon, label.lat))
        kept.append(label)
    return kept


def lon_lat_to_pixel(
    lon: float,
    lat: float,
    *,
    west: float,
    south: float,
    east: float,
    north: float,
    width: int,
    height: int,
) -> tuple[float, float]:
    x = ((lon - west) / (east - west)) * max(width - 1, 1)
    y = ((north - lat) / (north - south)) * max(height - 1, 1)
    return x, y


def draw_labels(
    image: Image.Image,
    labels: list[Label],
    *,
    west: float,
    south: float,
    east: float,
    north: float,
) -> None:
    draw = ImageDraw.Draw(image)
    width, height = image.size
    for label in labels:
        if not (west <= label.lon <= east and south <= label.lat <= north):
            continue
        x, y = lon_lat_to_pixel(
            label.lon,
            label.lat,
            west=west,
            south=south,
            east=east,
            north=north,
            width=width,
            height=height,
        )
        font = load_font(label.size)
        bbox = draw.textbbox((0, 0), label.text, font=font, stroke_width=label.stroke_width)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        anchor_x = max(4, min(width - text_width - 4, int(x - (text_width / 2))))
        anchor_y = max(4, min(height - text_height - 4, int(y - (text_height / 2))))
        draw.text(
            (anchor_x, anchor_y),
            label.text,
            font=font,
            fill=label.fill,
            stroke_fill=label.stroke_fill,
            stroke_width=label.stroke_width,
        )


def main() -> None:
    args = parse_args()
    osm_path = Path(args.osm).expanduser().resolve()
    input_raster = Path(args.input_raster).expanduser().resolve()
    output_raster = Path(args.output_raster).expanduser().resolve()

    if not osm_path.exists():
        raise FileNotFoundError(f"Fichier OSM introuvable: {osm_path}")
    if not input_raster.exists():
        raise FileNotFoundError(f"Raster source introuvable: {input_raster}")

    output_raster.parent.mkdir(parents=True, exist_ok=True)

    dataset = gdal.Open(str(input_raster))
    if dataset is None:
        raise RuntimeError(f"Impossible d'ouvrir le raster: {input_raster}")

    width = dataset.RasterXSize
    height = dataset.RasterYSize
    if dataset.RasterCount < 4:
        raise RuntimeError("Le raster doit contenir 4 bandes RGBA.")

    channels = []
    for band_index in range(4):
        band = dataset.GetRasterBand(band_index + 1)
        band_bytes = band.ReadRaster(0, 0, width, height, buf_type=gdal.GDT_Byte)
        if band_bytes is None:
            raise RuntimeError("Impossible de lire une bande raster RGBA.")
        channels.append(Image.frombytes("L", (width, height), band_bytes))

    image = Image.merge("RGBA", channels)

    point_labels, road_labels = extract_labels(
        osm_path,
        max_point_labels=args.max_point_labels,
        max_road_labels=args.max_road_labels,
    )

    draw_labels(
        image,
        road_labels,
        west=args.west,
        south=args.south,
        east=args.east,
        north=args.north,
    )
    draw_labels(
        image,
        point_labels,
        west=args.west,
        south=args.south,
        east=args.east,
        north=args.north,
    )

    driver = gdal.GetDriverByName("GTiff")
    if output_raster.exists():
        output_raster.unlink()
    output_dataset = driver.Create(
        str(output_raster),
        width,
        height,
        4,
        gdal.GDT_Byte,
        options=["TILED=YES", "COMPRESS=DEFLATE"],
    )
    if output_dataset is None:
        raise RuntimeError(f"Impossible de creer le raster cible: {output_raster}")

    output_dataset.SetGeoTransform(dataset.GetGeoTransform())
    output_dataset.SetProjection(dataset.GetProjection())
    for band_index, channel in enumerate(image.split(), start=1):
        output_dataset.GetRasterBand(band_index).WriteRaster(
            0,
            0,
            width,
            height,
            channel.tobytes(),
            buf_type=gdal.GDT_Byte,
        )

    output_dataset.FlushCache()
    output_dataset = None
    dataset = None

    print(
        f"Raster avec libelles genere: {output_raster} "
        f"(points={len(point_labels)}, voies={len(road_labels)})"
    )


if __name__ == "__main__":
    main()
