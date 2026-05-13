import json
import tempfile
from pathlib import Path
from unittest.mock import patch

from django.contrib.gis.geos import Polygon
from django.test import RequestFactory, SimpleTestCase, override_settings

from . import views


def _write_orthophoto_package(root: Path, *, tile_count=1) -> Path:
    package_dir = root / "active" / "v1"
    tiles_dir = package_dir / "tiles" / "17" / "1"
    tiles_dir.mkdir(parents=True)
    tiles = []
    for y in range(tile_count):
        tile_path = tiles_dir / f"{y}.tif"
        content = f"tile-{y}".encode("ascii")
        tile_path.write_bytes(content)
        tiles.append(
            {
                "z": 17,
                "x": 1,
                "y": y,
                "path": f"tiles/17/1/{y}.tif",
                "size_bytes": len(content),
                "sha256": "0" * 64,
                "bounds_4326": [-9.0, 31.0, -8.0, 32.0],
            }
        )
    manifest = {
        "ortho_id": "active",
        "version": "v1",
        "format": "tif",
        "min_zoom": 17,
        "max_zoom": 22,
        "bounds_4326": [-9.0, 31.0, -8.0, 32.0],
        "tile_count": tile_count,
        "total_bytes": sum(tile["size_bytes"] for tile in tiles),
        "tiles": tiles,
    }
    (package_dir / "manifest.json").write_text(
        json.dumps(manifest),
        encoding="utf-8",
    )
    return package_dir


class OrthophotoApiTests(SimpleTestCase):
    def setUp(self):
        self.factory = RequestFactory()

    def _zone_geom(self):
        geom = Polygon.from_bbox((-9.5, 30.5, -7.5, 32.5))
        geom.srid = 4326
        return geom

    def test_manifest_is_filtered_to_agent_zone(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_orthophoto_package(root, tile_count=2)
            request = self.factory.get(
                "/api/orthophotos/agent/manifest/",
                HTTP_X_USER_ID="7",
            )
            with override_settings(
                ORTHOPHOTO_ROOT=root,
                ORTHOPHOTO_ACTIVE_ID="active",
                ORTHO_MAX_TILES_PER_AGENT_ZONE=10,
                ORTHO_MAX_AGENT_BYTES=1024,
            ), patch.object(
                views,
                "_orthophoto_agent_zone_geom_4326",
                return_value=self._zone_geom(),
            ):
                response = views.orthophoto_agent_manifest_view(request)

            self.assertEqual(response.status_code, 200)
            self.assertTrue(response.data["success"])
            self.assertEqual(response.data["tile_count"], 2)
            self.assertIn("{z}/{x}/{y}.tif", response.data["tile_url_template"])

    def test_manifest_without_agent_zone_returns_empty_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_orthophoto_package(root, tile_count=1)
            request = self.factory.get(
                "/api/orthophotos/agent/manifest/",
                HTTP_X_USER_ID="7",
            )
            with override_settings(
                ORTHOPHOTO_ROOT=root,
                ORTHOPHOTO_ACTIVE_ID="active",
            ), patch.object(
                views,
                "_orthophoto_agent_zone_geom_4326",
                return_value=None,
            ):
                response = views.orthophoto_agent_manifest_view(request)

            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.data["tile_count"], 0)
            self.assertEqual(response.data["total_bytes"], 0)

    def test_manifest_refuses_too_many_tiles(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_orthophoto_package(root, tile_count=2)
            request = self.factory.get(
                "/api/orthophotos/agent/manifest/",
                HTTP_X_USER_ID="7",
            )
            with override_settings(
                ORTHOPHOTO_ROOT=root,
                ORTHOPHOTO_ACTIVE_ID="active",
                ORTHO_MAX_TILES_PER_AGENT_ZONE=1,
                ORTHO_MAX_AGENT_BYTES=1024,
            ), patch.object(
                views,
                "_orthophoto_agent_zone_geom_4326",
                return_value=self._zone_geom(),
            ):
                response = views.orthophoto_agent_manifest_view(request)

            self.assertEqual(response.status_code, 413)
            self.assertFalse(response.data["success"])

    def test_tile_endpoint_streams_authorized_tile(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            _write_orthophoto_package(root, tile_count=1)
            request = self.factory.get(
                "/api/orthophotos/active/tiles/17/1/0.tif",
                HTTP_X_USER_ID="7",
            )
            with override_settings(
                ORTHOPHOTO_ROOT=root,
                ORTHOPHOTO_ACTIVE_ID="active",
            ), patch.object(
                views,
                "_orthophoto_agent_zone_geom_4326",
                return_value=self._zone_geom(),
            ):
                response = views.orthophoto_tile_view(
                    request,
                    "active",
                    17,
                    1,
                    0,
                    "tif",
                )

            self.assertEqual(response.status_code, 200)
            self.assertEqual(response["Content-Type"], "image/tiff")
            self.assertEqual(b"".join(response.streaming_content), b"tile-0")
