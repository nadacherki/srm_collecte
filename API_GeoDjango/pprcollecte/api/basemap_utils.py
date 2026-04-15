import sqlite3
import hashlib
from pathlib import Path
from typing import Optional


def read_mbtiles_metadata(mbtiles_path: Path) -> dict[str, str]:
    if not mbtiles_path.exists():
        return {}

    with sqlite3.connect(mbtiles_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='metadata'"
        )
        if cursor.fetchone() is None:
            return {}

        cursor.execute("SELECT name, value FROM metadata")
        return {
            str(name): "" if value is None else str(value)
            for name, value in cursor.fetchall()
        }


def compute_file_sha256(file_path: Path) -> str:
    sha256 = hashlib.sha256()
    with file_path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def read_mbtiles_tile_stats(mbtiles_path: Path) -> dict[str, Optional[int]]:
    if not mbtiles_path.exists():
        return {"min_zoom": None, "max_zoom": None, "tile_count": 0}

    with sqlite3.connect(mbtiles_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type IN ('table', 'view') AND name='tiles'"
        )
        if cursor.fetchone() is None:
            return {"min_zoom": None, "max_zoom": None, "tile_count": 0}

        cursor.execute(
            "SELECT MIN(zoom_level), MAX(zoom_level), COUNT(*) FROM tiles"
        )
        min_zoom, max_zoom, tile_count = cursor.fetchone()
        return {
            "min_zoom": int(min_zoom) if min_zoom is not None else None,
            "max_zoom": int(max_zoom) if max_zoom is not None else None,
            "tile_count": int(tile_count or 0),
        }


def upsert_mbtiles_metadata(mbtiles_path: Path, metadata: dict[str, object]) -> None:
    with sqlite3.connect(mbtiles_path) as conn:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='metadata'"
        )
        has_metadata_table = cursor.fetchone() is not None
        if not has_metadata_table:
            cursor.execute(
                "CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT)"
            )

        for name, value in metadata.items():
            normalized_name = str(name)
            normalized_value = "" if value is None else str(value)
            cursor.execute(
                "DELETE FROM metadata WHERE name = ?",
                (normalized_name,),
            )
            cursor.execute(
                "INSERT INTO metadata(name, value) VALUES (?, ?)",
                (normalized_name, normalized_value),
            )
        conn.commit()


def parse_bounds_metadata(value: Optional[str]) -> Optional[dict[str, float]]:
    if not value:
        return None

    parts = [item.strip() for item in value.split(",")]
    if len(parts) != 4:
        return None

    try:
        west, south, east, north = [float(item) for item in parts]
    except ValueError:
        return None

    return {
        "north": north,
        "south": south,
        "east": east,
        "west": west,
    }


def parse_center_metadata(value: Optional[str]) -> Optional[dict[str, float]]:
    if not value:
        return None

    parts = [item.strip() for item in value.split(",")]
    if len(parts) < 2:
        return None

    try:
        longitude = float(parts[0])
        latitude = float(parts[1])
    except ValueError:
        return None

    return {
        "latitude": latitude,
        "longitude": longitude,
    }
