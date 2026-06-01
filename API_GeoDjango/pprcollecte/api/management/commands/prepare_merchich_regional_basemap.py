from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from defusedxml import ElementTree as ET
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = (
        "Prepare un basemap regional raster EPSG:26191 en PMTiles, "
        "avec manifest JSON compatible mobile."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--source",
            default="",
            help="GeoTIFF/VRT source deja en EPSG:26191. Defaut: settings/env.",
        )
        parser.add_argument(
            "--output",
            default="",
            help="PMTiles cible. Defaut: MEDIA_ROOT/basemaps/region.pmtiles.",
        )
        parser.add_argument("--name", default="")
        parser.add_argument("--tile-size", type=int, default=0)
        parser.add_argument(
            "--format",
            choices=("webp", "png", "jpg"),
            default="",
        )
        parser.add_argument("--quality", type=int, default=0)
        parser.add_argument(
            "--user-id",
            type=int,
            default=0,
            help="Prepare la carte pour les zones affectees a cet agent.",
        )
        parser.add_argument("--keep-workdir", action="store_true")
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Verifie la source et les executables sans generer de tuiles.",
        )
        parser.add_argument(
            "--force",
            action="store_true",
            help="Reconstruit meme si la sortie et son sidecar existent deja.",
        )

    def handle(self, *args, **options):
        agent_id = options["user_id"] if options["user_id"] > 0 else None
        output_path = self._resolve_output_path(options["output"], agent_id=agent_id)
        sidecar_path = output_path.with_suffix(".json")
        if (
            not options["force"]
            and output_path.exists()
            and sidecar_path.exists()
            and self._sidecar_is_merchich_basemap(sidecar_path)
        ):
            self.stdout.write(self.style.SUCCESS(f"Basemap deja pret: {output_path}"))
            return

        script_path = self._tile_script_path()
        python_path, env = self._resolve_script_python()
        pmtiles_cli = self._resolve_pmtiles_cli_path()
        source_path = self._resolve_source_path(options["source"])
        if options["dry_run"]:
            self.stdout.write(f"Source basemap: {source_path}")
            self.stdout.write(f"Sortie basemap: {output_path}")
            self.stdout.write(f"Python GDAL: {python_path}")
            self.stdout.write(f"PMTiles CLI: {pmtiles_cli}")
            self.stdout.write(self.style.SUCCESS("Dry-run basemap OK."))
            return

        output_path.parent.mkdir(parents=True, exist_ok=True)
        work_root = Path(settings.BASE_DIR).parent / "basemaps" / "build"
        work_root.mkdir(parents=True, exist_ok=True)
        work_dir = Path(
            tempfile.mkdtemp(prefix="regional_basemap_", dir=str(work_root))
        )
        temp_pmtiles = work_dir / "region.pmtiles"
        tile_source_path = source_path
        if source_path.suffix.lower() == ".osm":
            tile_source_path = self._render_osm_to_merchich_raster(
                osm_path=source_path,
                work_dir=work_dir,
                python_path=python_path,
                env=env,
                agent_id=agent_id,
            )

        command = [
            str(python_path),
            str(script_path),
            str(tile_source_path),
            str(work_dir),
            "--package-type",
            "basemap",
            "--name",
            options["name"].strip() or self._default_basemap_name(),
            "--tile-size",
            str(options["tile_size"] or getattr(settings, "BASEMAP_TILE_SIZE", 512)),
            "--format",
            options["format"]
            or getattr(settings, "BASEMAP_TILE_FORMAT", "webp")
            or "webp",
            "--quality",
            str(options["quality"] or getattr(settings, "BASEMAP_TILE_QUALITY", 90)),
            "--pmtiles",
            str(temp_pmtiles),
            "--pmtiles-cli",
            str(pmtiles_cli),
        ]

        self.stdout.write(f"Source basemap: {source_path}")
        self.stdout.write(f"Sortie basemap: {output_path}")
        try:
            result = subprocess.run(
                command,
                capture_output=True,
                text=True,
                cwd=str(Path(settings.BASE_DIR).parent),
                env=env,
            )
            if result.returncode != 0:
                details = (result.stderr or result.stdout or "").strip()
                raise CommandError(
                    "Echec generation basemap Merchich: "
                    f"{details or 'aucun detail fourni'}"
                )

            manifest_path = work_dir / "manifest.json"
            if not temp_pmtiles.exists() or not manifest_path.exists():
                raise CommandError(
                    "Generation basemap incomplete: PMTiles ou manifest manquant."
                )

            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["type"] = "basemap"
            manifest["format"] = "pmtiles"
            manifest.setdefault("srid", 26191)
            manifest.setdefault("crs", "EPSG:26191")
            manifest.setdefault("attribution", self._default_basemap_attribution())

            temp_sidecar = work_dir / "region.json"
            temp_sidecar.write_text(
                json.dumps(
                    {key: value for key, value in manifest.items() if value is not None},
                    indent=2,
                ),
                encoding="utf-8",
            )

            self._replace_file(temp_pmtiles, output_path)
            self._replace_file(temp_sidecar, sidecar_path)
        finally:
            if options["keep_workdir"]:
                self.stdout.write(self.style.WARNING(f"Workdir conserve: {work_dir}"))
            else:
                shutil.rmtree(work_dir, ignore_errors=True)

        self.stdout.write(self.style.SUCCESS("Basemap regional Merchich prepare."))

    def _resolve_output_path(self, explicit: str, *, agent_id: int | None) -> Path:
        raw = (
            explicit
            or getattr(settings, "BASEMAP_REGIONAL_OUTPUT_PATH", "")
            or ""
        ).strip()
        if raw:
            path = Path(raw).expanduser()
            if not path.is_absolute():
                path = Path(settings.BASE_DIR) / path
            return path.resolve()
        if agent_id is not None:
            return (
                Path(settings.MEDIA_ROOT)
                / "basemaps"
                / "agents"
                / f"user_{agent_id}"
                / "region.pmtiles"
            ).resolve()
        return (Path(settings.MEDIA_ROOT) / "basemaps" / "region.pmtiles").resolve()

    def _default_basemap_name(self) -> str:
        configured = str(getattr(settings, "BASEMAP_REGIONAL_NAME", "") or "").strip()
        if configured and not any(
            marker in configured.lower()
            for marker in ("ortho", "orthophoto", "satellite", "sat ", "test")
        ):
            return configured
        return "SRM basemap regional Merchich"

    def _default_basemap_attribution(self) -> str:
        configured = str(
            getattr(settings, "BASEMAP_REGIONAL_ATTRIBUTION", "") or ""
        ).strip()
        if configured and not any(
            marker in configured.lower()
            for marker in ("ortho", "orthophoto", "satellite", "sat ")
        ):
            return configured
        return "OpenStreetMap contributors"

    def _resolve_source_path(self, explicit: str) -> Path:
        raw = (
            explicit
            or getattr(settings, "BASEMAP_MERCHICH_SOURCE_PATH", "")
            or getattr(settings, "BASEMAP_BUILD_SOURCE_PATH", "")
            or ""
        ).strip()
        if raw:
            path = Path(raw).expanduser()
            if not path.is_absolute():
                path = Path(settings.BASE_DIR) / path
            path = path.resolve()
            if not path.exists():
                raise CommandError(f"Source basemap introuvable: {path}")
            return path

        source_dir_raw = (getattr(settings, "BASEMAP_BUILD_SOURCE_DIR", "") or "").strip()
        source_dir = (
            Path(source_dir_raw).expanduser().resolve()
            if source_dir_raw
            else (Path(settings.BASE_DIR).parent / "basemaps" / "source").resolve()
        )
        if not source_dir.exists():
            raise CommandError(
                "Aucune source basemap Merchich configuree. "
                "Configurer BASEMAP_MERCHICH_SOURCE_PATH ou deposer un GeoTIFF "
                f"EPSG:26191 dans {source_dir}."
            )

        candidates = sorted(
            path
            for path in source_dir.iterdir()
            if path.is_file()
            and path.suffix.lower() in {".tif", ".tiff", ".vrt", ".osm"}
        )
        if not candidates:
            raise CommandError(
                "Aucune source basemap Merchich trouvee. "
                "Attendu: .tif, .tiff ou .vrt en EPSG:26191, ou .osm."
            )
        if len(candidates) > 1:
            raise CommandError(
                "Plusieurs sources basemap detectees. "
                "Configurer BASEMAP_MERCHICH_SOURCE_PATH pour choisir la bonne."
            )
        return candidates[0].resolve()

    def _tile_script_path(self) -> Path:
        script = Path(settings.BASE_DIR).parent.parent / "tools" / "build_merchich_ortho_tiles.py"
        if not script.exists():
            raise CommandError(f"Script de tuilage introuvable: {script}")
        return script.resolve()

    def _render_osm_to_merchich_raster(
        self,
        *,
        osm_path: Path,
        work_dir: Path,
        python_path: Path,
        env: dict[str, str],
        agent_id: int | None,
    ) -> Path:
        scripts_dir = Path(settings.BASE_DIR).parent / "basemaps" / "scripts"
        render_script = scripts_dir / "render_public_osm_basemap.py"
        label_script = scripts_dir / "label_public_osm_basemap.py"
        if not render_script.exists():
            raise CommandError(f"Script rendu OSM introuvable: {render_script}")
        if not label_script.exists():
            raise CommandError(f"Script libelles OSM introuvable: {label_script}")

        west, south, east, north = self._compute_osm_bbox(
            osm_path,
            agent_id=agent_id,
        )
        raw_raster = work_dir / "basemap_osm_wgs84.tif"
        labeled_raster = work_dir / "basemap_osm_wgs84_labeled.tif"
        merchich_raster = work_dir / "basemap_osm_merchich.tif"
        common_bounds = [
            "--west",
            west,
            "--south",
            south,
            "--east",
            east,
            "--north",
            north,
        ]
        render_size = int(os.environ.get("BASEMAP_OSM_RENDER_SIZE", "4096"))
        self._run_python_script(
            python_path,
            render_script,
            [
                "--osm",
                osm_path,
                "--output",
                raw_raster,
                *common_bounds,
                "--width",
                render_size,
                "--height",
                render_size,
            ],
            env,
        )
        self._run_python_script(
            python_path,
            label_script,
            [
                "--osm",
                osm_path,
                "--input-raster",
                raw_raster,
                "--output-raster",
                labeled_raster,
                *common_bounds,
            ],
            env,
        )
        self._run_gdal_command(
            "gdalwarp",
            [
                "-overwrite",
                "-t_srs",
                "EPSG:26191",
                "-r",
                "bilinear",
                "-co",
                "TILED=YES",
                "-co",
                "COMPRESS=DEFLATE",
                str(labeled_raster),
                str(merchich_raster),
            ],
            env,
        )
        return merchich_raster

    def _compute_osm_bbox(
        self,
        osm_path: Path,
        *,
        agent_id: int | None,
    ) -> tuple[float, float, float, float]:
        zone_bbox = self._compute_zone_bbox(agent_id=agent_id)
        if zone_bbox is not None:
            return self._padded_bbox(zone_bbox)

        bounds = None
        min_lon = min_lat = float("inf")
        max_lon = max_lat = float("-inf")
        for _, elem in ET.iterparse(str(osm_path), events=("end",)):
            if elem.tag == "bounds":
                try:
                    bounds = (
                        float(elem.attrib["minlon"]),
                        float(elem.attrib["minlat"]),
                        float(elem.attrib["maxlon"]),
                        float(elem.attrib["maxlat"]),
                    )
                except (KeyError, ValueError):
                    bounds = None
                elem.clear()
                continue
            if elem.tag == "node":
                try:
                    lon = float(elem.attrib["lon"])
                    lat = float(elem.attrib["lat"])
                except (KeyError, ValueError):
                    elem.clear()
                    continue
                min_lon = min(min_lon, lon)
                min_lat = min(min_lat, lat)
                max_lon = max(max_lon, lon)
                max_lat = max(max_lat, lat)
                elem.clear()

        if bounds is None and min_lon != float("inf"):
            bounds = (min_lon, min_lat, max_lon, max_lat)
        if bounds is None:
            raise CommandError(f"Impossible de lire la bbox OSM: {osm_path}")

        return self._padded_bbox(bounds)

    def _compute_zone_bbox(
        self,
        *,
        agent_id: int | None,
    ) -> tuple[float, float, float, float] | None:
        try:
            from api.models import Zone, ZoneUtilisateur

            zones_qs = Zone.objects.filter(geom__isnull=False)
            if agent_id is not None:
                assigned_ids = ZoneUtilisateur.objects.filter(
                    id_user=agent_id,
                    actif=True,
                ).values_list("id_zone", flat=True)
                zones_qs = zones_qs.filter(id_zone__in=assigned_ids)
            zones = list(zones_qs)
        except Exception:
            return None
        if not zones:
            return None
        west = min(zone.bbox_west for zone in zones)
        south = min(zone.bbox_south for zone in zones)
        east = max(zone.bbox_east for zone in zones)
        north = max(zone.bbox_north for zone in zones)
        return west, south, east, north

    def _padded_bbox(
        self,
        bbox: tuple[float, float, float, float],
    ) -> tuple[float, float, float, float]:
        west, south, east, north = bbox
        pad_x = max((east - west) * 0.03, 0.002)
        pad_y = max((north - south) * 0.03, 0.002)
        return west - pad_x, south - pad_y, east + pad_x, north + pad_y

    def _run_python_script(
        self,
        python_path: Path,
        script_path: Path,
        arguments: list[object],
        env: dict[str, str],
    ) -> None:
        result = subprocess.run(
            [str(python_path), str(script_path), *[str(arg) for arg in arguments]],
            capture_output=True,
            text=True,
            cwd=str(Path(settings.BASE_DIR).parent),
            env=env,
        )
        if result.returncode != 0:
            details = (result.stderr or result.stdout or "").strip()
            raise CommandError(
                f"Echec script {script_path.name}: {details or 'aucun detail'}"
            )

    def _run_gdal_command(
        self,
        executable_name: str,
        arguments: list[str],
        env: dict[str, str],
    ) -> None:
        executable = self._resolve_gdal_executable(executable_name)
        result = subprocess.run(
            [str(executable), *arguments],
            capture_output=True,
            text=True,
            env=env,
        )
        if result.returncode != 0:
            details = (result.stderr or result.stdout or "").strip()
            raise CommandError(
                f"Echec {executable_name}: {details or 'aucun detail'}"
            )

    def _resolve_gdal_executable(self, executable_name: str) -> Path:
        direct = shutil.which(executable_name)
        if direct:
            return Path(direct)

        exe_name = (
            executable_name
            if executable_name.lower().endswith(".exe")
            else f"{executable_name}.exe"
        )
        candidates = []
        gdal_library = getattr(settings, "GDAL_LIBRARY_PATH", None)
        if gdal_library:
            candidates.append(Path(gdal_library).resolve().parent / exe_name)
        candidates.extend(
            [
                Path(r"C:\Program Files\QGIS 3.40.14\bin") / exe_name,
                Path(r"C:\Program Files\QGIS 3.34.12\bin") / exe_name,
                Path(r"C:\OSGeo4W\bin") / exe_name,
            ]
        )
        for candidate in candidates:
            if candidate.exists():
                return candidate
        raise CommandError(f"Executable GDAL introuvable: {executable_name}")

    def _candidate_script_pythons(self):
        configured = (getattr(settings, "BASEMAP_SCRIPT_PYTHON", "") or "").strip()
        if configured:
            yield Path(configured).expanduser().resolve()
        yield Path(sys.executable).resolve()
        for candidate in (
            Path(r"C:\Program Files\QGIS 3.40.14\apps\Python312\python.exe"),
            Path(r"C:\Program Files\QGIS 3.34.12\apps\Python39\python.exe"),
            Path(r"C:\OSGeo4W\bin\python3.exe"),
        ):
            yield candidate

    def _resolve_script_python(self) -> tuple[Path, dict[str, str]]:
        checked = []
        for candidate in self._candidate_script_pythons():
            if not candidate.exists():
                continue
            checked.append(str(candidate))
            env = self._script_runtime_env(candidate)
            probe = subprocess.run(
                [str(candidate), "-c", "from osgeo import gdal, osr; print('ok')"],
                capture_output=True,
                text=True,
                cwd=str(Path(settings.BASE_DIR).parent),
                env=env,
            )
            if probe.returncode == 0 and "ok" in (probe.stdout or ""):
                return candidate, env
        raise CommandError(
            "Aucun Python compatible GDAL trouve pour tuiler la basemap. "
            f"Candidats testes: {', '.join(checked) or 'aucun'}."
        )

    def _script_runtime_env(self, python_path: Path) -> dict[str, str]:
        env = dict(os.environ)
        gdal_library = getattr(settings, "GDAL_LIBRARY_PATH", None)
        if gdal_library:
            bin_dir = str(Path(gdal_library).resolve().parent)
            env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "")
        proj_lib = getattr(settings, "PROJ_LIB", None)
        if proj_lib:
            env["PROJ_LIB"] = str(proj_lib)

        python_parent = python_path.parent
        qgis_root = python_parent.parents[1] if len(python_parent.parents) >= 2 else None
        if qgis_root is not None and qgis_root.exists():
            qgis_bin = qgis_root / "bin"
            qgis_proj = qgis_root / "share" / "proj"
            qgis_gdal = qgis_root / "share" / "gdal"
            if qgis_bin.exists():
                env["PATH"] = str(qgis_bin) + os.pathsep + env.get("PATH", "")
            if qgis_proj.exists():
                env["PROJ_LIB"] = str(qgis_proj)
            if qgis_gdal.exists():
                env["GDAL_DATA"] = str(qgis_gdal)
        return env

    def _resolve_pmtiles_cli_path(self) -> Path:
        configured = (getattr(settings, "BASEMAP_PMTILES_CLI_PATH", "") or "").strip()
        candidates = []
        if configured:
            candidates.append(Path(configured).expanduser().resolve())
        candidates.append(
            (Path(settings.BASE_DIR).parent / "basemaps" / "tools" / "pmtiles.exe").resolve()
        )
        candidates.append(
            (
                Path(settings.BASE_DIR).parent
                / "basemaps"
                / "tools"
                / "go-pmtiles_1.30.1"
                / "pmtiles.exe"
            ).resolve()
        )
        which = shutil.which("pmtiles")
        if which:
            candidates.append(Path(which).resolve())

        for candidate in candidates:
            if candidate.exists():
                return candidate
        raise CommandError(
            "CLI pmtiles introuvable. Configurer BASEMAP_PMTILES_CLI_PATH "
            "ou deposer pmtiles.exe dans API_GeoDjango/basemaps/tools/."
        )

    def _sidecar_is_merchich_basemap(self, sidecar_path: Path) -> bool:
        try:
            data = json.loads(sidecar_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return False
        package_type = str(data.get("type") or "").strip().lower()
        srid = data.get("srid") or str(data.get("crs") or "").replace("EPSG:", "")
        try:
            srid_value = int(srid)
        except (TypeError, ValueError):
            return False
        return (
            package_type in {"basemap", "map", "regional_basemap", "regional-basemap"}
            and srid_value == 26191
            and bool(data.get("resolutions"))
            and bool(data.get("boundsMerchich") or data.get("bounds_merchich"))
        )

    def _replace_file(self, source_path: Path, destination_path: Path) -> None:
        destination_path.parent.mkdir(parents=True, exist_ok=True)
        if destination_path.exists():
            destination_path.unlink()
        shutil.move(str(source_path), str(destination_path))
