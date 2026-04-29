import json
import os
import shutil
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone as django_timezone

from api.basemap_utils import (
    compute_file_sha256,
    read_mbtiles_metadata,
    read_mbtiles_tile_stats,
    upsert_mbtiles_metadata,
)
from api.models import BasemapPackage, BasemapZone


class Command(BaseCommand):
    help = (
        "Construit un package MBTiles offline pour une zone du catalogue, "
        "puis l'enregistre automatiquement dans basemap_package."
    )

    def add_arguments(self, parser):
        parser.add_argument("--zone-id", required=True, help="Identifiant de la zone.")
        parser.add_argument(
            "--source",
            required=True,
            help="Chemin source local (.tif, .tiff, .vrt, .mbtiles).",
        )
        parser.add_argument(
            "--package-version",
            required=True,
            help="Version logique du package, ex: v1 ou 2026-04-14.",
        )
        parser.add_argument(
            "--style",
            default="standard",
            choices=["standard", "satellite"],
            help="Style du package.",
        )
        parser.add_argument(
            "--output",
            default="",
            help=(
                "Chemin MBTiles final. Par défaut: "
                "MEDIA_ROOT/basemaps/<city>/<zone>/<style>/<version>/package.mbtiles"
            ),
        )
        parser.add_argument(
            "--scratch-dir",
            default="",
            help="Dossier de travail temporaire. Par défaut: API_GeoDjango/basemaps/build/",
        )
        parser.add_argument(
            "--tile-format",
            default="PNG",
            choices=["PNG", "JPEG", "WEBP"],
            help="Format raster des tuiles MBTiles.",
        )
        parser.add_argument(
            "--attribution",
            default="Source cartographique autorisée par l'équipe SIG.",
            help="Attribution à inscrire dans les métadonnées MBTiles.",
        )
        parser.add_argument(
            "--source-name",
            default="",
            help="Nom lisible de la source cartographique.",
        )
        parser.add_argument(
            "--skip-zoom-validation",
            action="store_true",
            help="N'échoue pas si les zooms de la zone ne sont pas tous présents.",
        )
        parser.add_argument(
            "--keep-workdir",
            action="store_true",
            help="Conserve le dossier de travail intermédiaire après exécution.",
        )
        parser.add_argument(
            "--inactive",
            action="store_true",
            help="Enregistre le package comme inactif dans le catalogue.",
        )

    def handle(self, *args, **options):
        zone_id = str(options["zone_id"]).strip()
        zone = BasemapZone.objects.filter(zone_id=zone_id).first()
        if zone is None:
            raise CommandError(f"Zone inconnue: {zone_id}")
        if zone.geom is None or zone.geom.empty:
            raise CommandError(f"La zone {zone_id} ne contient pas de géométrie exploitable.")

        source_path = Path(options["source"]).expanduser().resolve()
        if not source_path.exists():
            raise CommandError(f"Source introuvable: {source_path}")
        if source_path.suffix.lower() not in {".tif", ".tiff", ".vrt", ".mbtiles"}:
            raise CommandError(
                "Source non supportée. Utiliser .tif, .tiff, .vrt ou .mbtiles."
            )

        package_version = str(options["package_version"]).strip()
        style = str(options["style"]).strip()
        tile_format = str(options["tile_format"]).upper()
        attribution = str(options["attribution"]).strip()
        source_name = str(options["source_name"]).strip() or source_path.name
        source_sha256 = compute_file_sha256(source_path)
        output_path = self._resolve_output_path(
            zone=zone,
            style=style,
            package_version=package_version,
            raw_output=str(options["output"]).strip(),
        )
        output_path.parent.mkdir(parents=True, exist_ok=True)

        scratch_root = self._resolve_scratch_root(str(options["scratch_dir"]).strip())
        scratch_root.mkdir(parents=True, exist_ok=True)
        keep_workdir = bool(options["keep_workdir"])
        skip_zoom_validation = bool(options["skip_zoom_validation"])

        self.stdout.write(self.style.NOTICE(f"Zone: {zone.city_slug}/{zone.zone_id}"))
        self.stdout.write(self.style.NOTICE(f"Source: {source_path}"))
        self.stdout.write(self.style.NOTICE(f"Sortie: {output_path}"))

        work_dir = Path(tempfile.mkdtemp(prefix=f"{zone.zone_id}_", dir=scratch_root))
        work_output = work_dir / "package.mbtiles"

        try:
            cutline_geojson = work_dir / f"{zone.zone_id}.geojson"
            cutline_geojson.write_text(
                json.dumps(self._zone_feature_collection(zone), ensure_ascii=False),
                encoding="utf-8",
            )

            self._build_from_source(
                source_path=source_path,
                cutline_geojson=cutline_geojson,
                zone=zone,
                work_dir=work_dir,
                output_path=work_output,
                tile_format=tile_format,
            )

            build_time = datetime.now(timezone.utc).isoformat()
            tile_stats = read_mbtiles_tile_stats(work_output)
            effective_tile_format = tile_format
            output_metadata = read_mbtiles_metadata(work_output)
            if output_metadata.get("format"):
                effective_tile_format = output_metadata["format"].strip().upper()

            self._write_standard_metadata(
                mbtiles_path=work_output,
                zone=zone,
                style=style,
                package_version=package_version,
                tile_format=effective_tile_format,
                attribution=attribution,
                source_name=source_name,
                source_sha256=source_sha256,
                generated_at=build_time,
                min_zoom=tile_stats.get("min_zoom"),
                max_zoom=tile_stats.get("max_zoom"),
                tile_count=tile_stats.get("tile_count"),
            )

            tile_stats = read_mbtiles_tile_stats(work_output)
            self._validate_output(
                zone=zone,
                tile_stats=tile_stats,
                skip_zoom_validation=skip_zoom_validation,
            )

            self._finalize_output_file(
                source_path=work_output,
                destination_path=output_path,
            )

            final_stats = read_mbtiles_tile_stats(output_path)
            final_metadata = read_mbtiles_metadata(output_path)
            final_sha256 = compute_file_sha256(output_path)
            final_size = output_path.stat().st_size
            self._write_sha256_sidecar(output_path, final_sha256)
            self._register_package(
                zone=zone,
                style=style,
                package_version=package_version,
                output_path=output_path,
                source_name=source_name,
                attribution=attribution,
                metadata_json=final_metadata,
                tile_stats=final_stats,
                sha256_value=final_sha256,
                inactive=bool(options["inactive"]),
            )

            self.stdout.write(self.style.SUCCESS("Package de zone généré et enregistré."))
            self.stdout.write(f"Tiles: {final_stats['tile_count']}")
            self.stdout.write(
                f"Zooms: {final_stats['min_zoom']} -> {final_stats['max_zoom']}"
            )
            self.stdout.write(f"Taille: {final_size} octets")
            self.stdout.write(f"SHA256: {final_sha256}")
        finally:
            if keep_workdir:
                self.stdout.write(
                    self.style.WARNING(f"Dossier de travail conservé: {work_dir}")
                )
            else:
                shutil.rmtree(work_dir, ignore_errors=True)

    def _resolve_output_path(
        self,
        *,
        zone: BasemapZone,
        style: str,
        package_version: str,
        raw_output: str,
    ) -> Path:
        if raw_output:
            return Path(raw_output).expanduser().resolve()
        return (
            Path(settings.MEDIA_ROOT)
            / "basemaps"
            / zone.city_slug
            / zone.zone_id
            / style
            / package_version
            / "package.mbtiles"
        ).resolve()

    def _resolve_scratch_root(self, raw_scratch_dir: str) -> Path:
        if raw_scratch_dir:
            return Path(raw_scratch_dir).expanduser().resolve()
        return (Path(settings.BASE_DIR).parent / "basemaps" / "build").resolve()

    def _build_from_source(
        self,
        *,
        source_path: Path,
        cutline_geojson: Path,
        zone: BasemapZone,
        work_dir: Path,
        output_path: Path,
        tile_format: str,
    ) -> None:
        clipped_raster = work_dir / "zone_clipped_3857.tif"
        self._run_gdal_command(
            "gdalwarp",
            [
                "-overwrite",
                "-multi",
                "-dstalpha",
                "-r",
                "bilinear",
                "-t_srs",
                "EPSG:3857",
                "-te",
                str(zone.bbox_west),
                str(zone.bbox_south),
                str(zone.bbox_east),
                str(zone.bbox_north),
                "-te_srs",
                "EPSG:4326",
                "-cutline",
                str(cutline_geojson),
                "-crop_to_cutline",
                "-co",
                "TILED=YES",
                "-co",
                "COMPRESS=DEFLATE",
                str(source_path),
                str(clipped_raster),
            ],
        )
        self._run_gdal_command(
            "gdal_translate",
            [
                "-of",
                "MBTILES",
                "-co",
                f"TILE_FORMAT={tile_format}",
                "-co",
                f"NAME={zone.nom}",
                "-co",
                "TYPE=baselayer",
                "-co",
                f"DESCRIPTION=Basemap raster offline de la zone {zone.nom}.",
                "-co",
                "VERSION=1.0",
                "-co",
                "WRITE_BOUNDS=YES",
                str(clipped_raster),
                str(output_path),
            ],
        )
        self._run_gdal_command(
            "gdaladdo",
            [
                "-r",
                "average",
                str(output_path),
                "2",
                "4",
                "8",
                "16",
                "32",
                "64",
                "128",
                "256",
            ],
        )

    def _write_standard_metadata(
        self,
        *,
        mbtiles_path: Path,
        zone: BasemapZone,
        style: str,
        package_version: str,
        tile_format: str,
        attribution: str,
        source_name: str,
        source_sha256: str,
        generated_at: str,
        min_zoom: int | None,
        max_zoom: int | None,
        tile_count: int | None,
    ) -> None:
        upsert_mbtiles_metadata(
            mbtiles_path,
            {
                "name": f"SRM {zone.nom} ({style})",
                "description": f"Basemap raster offline de la zone {zone.nom}.",
                "type": "baselayer",
                "format": tile_format.lower(),
                "bounds": self._bounds_metadata(zone),
                "center": self._center_metadata(zone),
                "minzoom": min_zoom if min_zoom is not None else zone.min_zoom,
                "maxzoom": max_zoom if max_zoom is not None else zone.max_zoom,
                "attribution": attribution,
                "version": "1.0",
                "srm_city_slug": zone.city_slug,
                "srm_zone_id": zone.zone_id,
                "srm_zone_name": zone.nom,
                "srm_style": style,
                "srm_package_version": package_version,
                "srm_generated_at": generated_at,
                "srm_source_name": source_name,
                "srm_source_sha256": source_sha256,
                "srm_tile_count": tile_count or 0,
            },
        )

    def _validate_output(
        self,
        *,
        zone: BasemapZone,
        tile_stats: dict[str, int | None],
        skip_zoom_validation: bool,
    ) -> None:
        tile_count = tile_stats.get("tile_count") or 0
        if tile_count <= 0:
            raise CommandError("Le MBTiles généré ne contient aucune tuile.")

        min_zoom = tile_stats.get("min_zoom")
        max_zoom = tile_stats.get("max_zoom")
        if min_zoom is None or max_zoom is None:
            raise CommandError(
                "Impossible de lire les niveaux de zoom du MBTiles généré."
            )

        if not skip_zoom_validation and (
            min_zoom > zone.min_zoom or max_zoom < zone.max_zoom
        ):
            raise CommandError(
                "Le MBTiles généré ne couvre pas les zooms attendus "
                f"{zone.min_zoom}-{zone.max_zoom}. "
                f"Zooms trouvés: {min_zoom}-{max_zoom}."
            )

    def _register_package(
        self,
        *,
        zone: BasemapZone,
        style: str,
        package_version: str,
        output_path: Path,
        source_name: str,
        attribution: str,
        metadata_json: dict[str, str],
        tile_stats: dict[str, int | None],
        sha256_value: str,
        inactive: bool,
    ) -> None:
        media_root = Path(settings.MEDIA_ROOT).resolve()
        try:
            relative_path = output_path.relative_to(media_root)
        except ValueError as exc:
            raise CommandError(
                "Le package généré doit être situé sous MEDIA_ROOT pour être distribué."
            ) from exc

        now = django_timezone.now()
        defaults = {
            "city_slug": zone.city_slug,
            "style": style,
            "format": "mbtiles",
            "version": package_version,
            "file_name": output_path.name,
            "relative_path": relative_path.as_posix(),
            "size_bytes": output_path.stat().st_size,
            "sha256": sha256_value,
            "min_zoom": tile_stats.get("min_zoom"),
            "max_zoom": tile_stats.get("max_zoom"),
            "generated_at": now,
            "source_name": source_name,
            "attribution": attribution or None,
            "tile_count": tile_stats.get("tile_count"),
            "metadata_json": metadata_json,
            "actif": not inactive,
            "requires_wifi": True,
            "updated_at": now,
        }

        BasemapPackage.objects.update_or_create(
            zone_id=zone.zone_id,
            style=style,
            version=package_version,
            defaults=defaults,
            create_defaults={
                **defaults,
                "created_at": now,
            },
        )

    def _zone_feature_collection(self, zone: BasemapZone) -> dict[str, object]:
        geometry = json.loads(zone.geom.geojson)
        return {
            "type": "FeatureCollection",
            "features": [
                {
                    "type": "Feature",
                    "properties": {
                        "zone_id": zone.zone_id,
                        "nom": zone.nom,
                        "city_slug": zone.city_slug,
                    },
                    "geometry": geometry,
                }
            ],
        }

    def _bounds_metadata(self, zone: BasemapZone) -> str:
        return (
            f"{zone.bbox_west},{zone.bbox_south},"
            f"{zone.bbox_east},{zone.bbox_north}"
        )

    def _center_metadata(self, zone: BasemapZone) -> str:
        center_zoom = min(max(zone.min_zoom or 11, 13), zone.max_zoom or 19)
        return f"{zone.center_longitude},{zone.center_latitude},{center_zoom}"

    def _run_gdal_command(self, executable_name: str, arguments: list[str]) -> None:
        executable = self._resolve_executable(executable_name)
        command = [str(executable), *arguments]
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            env=self._command_environment(),
        )
        if result.returncode != 0:
            stderr = (result.stderr or "").strip()
            stdout = (result.stdout or "").strip()
            debug_output = stderr or stdout or "aucun détail fourni"
            raise CommandError(f"Échec {executable_name}: {debug_output}")

    def _resolve_executable(self, executable_name: str) -> Path:
        direct_match = shutil.which(executable_name)
        if direct_match:
            return Path(direct_match)

        exe_name = (
            executable_name
            if executable_name.lower().endswith(".exe")
            else f"{executable_name}.exe"
        )
        for bin_dir in self._candidate_bin_dirs():
            candidate = bin_dir / exe_name
            if candidate.exists():
                return candidate

        raise CommandError(
            f"Exécutable GDAL introuvable: {executable_name}. "
            "Vérifier l'installation QGIS/GDAL."
        )

    def _candidate_bin_dirs(self) -> list[Path]:
        candidates: list[Path] = []

        gdal_library = getattr(settings, "GDAL_LIBRARY_PATH", None)
        if gdal_library:
            candidates.append(Path(gdal_library).resolve().parent)

        for env_name in ("GDAL_BIN_PATH", "QGIS_BIN_PATH"):
            raw_value = os.environ.get(env_name)
            if raw_value:
                candidates.append(Path(raw_value).expanduser().resolve())

        for root in (
            r"C:\Program Files\QGIS 3.40.14\bin",
            r"C:\Program Files\QGIS 3.34.12\bin",
        ):
            candidates.append(Path(root))

        unique_candidates: list[Path] = []
        seen: set[str] = set()
        for candidate in candidates:
            key = str(candidate).lower()
            if key not in seen:
                seen.add(key)
                unique_candidates.append(candidate)
        return unique_candidates

    def _command_environment(self) -> dict[str, str]:
        env = dict(os.environ)

        gdal_library = getattr(settings, "GDAL_LIBRARY_PATH", None)
        if gdal_library:
            bin_dir = str(Path(gdal_library).resolve().parent)
            env["PATH"] = bin_dir + os.pathsep + env.get("PATH", "")
            qgis_root = str(Path(bin_dir).parent)
            gdal_data = Path(qgis_root) / "share" / "gdal"
            if gdal_data.exists():
                env.setdefault("GDAL_DATA", str(gdal_data))

        proj_lib = getattr(settings, "PROJ_LIB", None)
        if proj_lib:
            env["PROJ_LIB"] = str(proj_lib)

        return env

    def _write_sha256_sidecar(self, file_path: Path, sha256_value: str) -> None:
        sidecar_path = file_path.with_suffix(f"{file_path.suffix}.sha256")
        sidecar_path.write_text(f"{sha256_value}\n", encoding="utf-8")

    def _finalize_output_file(
        self,
        *,
        source_path: Path,
        destination_path: Path,
        retries: int = 20,
        delay_seconds: float = 1.5,
    ) -> None:
        if destination_path.exists():
            destination_path.unlink()

        last_error: Exception | None = None
        for attempt in range(1, retries + 1):
            try:
                source_path.replace(destination_path)
                return
            except PermissionError as exc:
                last_error = exc
            except OSError as exc:
                last_error = exc

            if attempt >= retries:
                break
            time.sleep(delay_seconds)

        for attempt in range(1, retries + 1):
            try:
                shutil.copy2(str(source_path), str(destination_path))
                try:
                    source_path.unlink(missing_ok=True)
                except OSError:
                    pass
                return
            except PermissionError as exc:
                last_error = exc
            except OSError as exc:
                last_error = exc

            if attempt >= retries:
                break
            time.sleep(delay_seconds)

        raise CommandError(
            "Impossible de finaliser le package MBTiles généré. "
            f"Windows conserve encore un verrou sur le fichier source: {last_error}"
        )
