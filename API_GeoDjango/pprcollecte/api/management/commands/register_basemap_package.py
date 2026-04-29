import shutil
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from api.basemap_utils import (
    compute_file_sha256,
    read_mbtiles_metadata,
    read_mbtiles_tile_stats,
)
from api.models import BasemapPackage, BasemapZone


class Command(BaseCommand):
    help = "Enregistre un package basemap de zone dans le catalogue serveur."

    def add_arguments(self, parser):
        parser.add_argument("--zone-id", required=True, help="Identifiant de la zone.")
        parser.add_argument(
            "--style",
            required=True,
            choices=["standard", "satellite"],
            help="Style du package.",
        )
        parser.add_argument(
            "--format",
            required=True,
            choices=["mbtiles", "pmtiles"],
            help="Format du package.",
        )
        parser.add_argument("--file", required=True, help="Chemin du fichier package.")
        parser.add_argument(
            "--package-version",
            required=True,
            help="Version logique du package.",
        )
        parser.add_argument(
            "--copy-to-media",
            action="store_true",
            help="Copie le package dans MEDIA_ROOT/basemaps/<city>/<zone>/<style>/<version>/.",
        )
        parser.add_argument(
            "--relative-path",
            default="",
            help="Chemin relatif media à utiliser si le fichier est déjà sous MEDIA_ROOT.",
        )
        parser.add_argument("--source-name", default="", help="Nom de la source carto.")
        parser.add_argument("--attribution", default="", help="Attribution licence/source.")
        parser.add_argument("--min-zoom", type=int, default=None)
        parser.add_argument("--max-zoom", type=int, default=None)
        parser.add_argument("--tile-count", type=int, default=None)
        parser.add_argument("--requires-wifi", action="store_true")
        parser.add_argument("--inactive", action="store_true")

    def handle(self, *args, **options):
        zone_id = str(options["zone_id"]).strip()
        zone = BasemapZone.objects.filter(zone_id=zone_id).first()
        if zone is None:
            raise CommandError(f"Zone inconnue: {zone_id}")

        file_path = Path(options["file"]).expanduser().resolve()
        if not file_path.exists():
            raise CommandError(f"Fichier package introuvable: {file_path}")

        relative_path, final_path = self._resolve_target_path(
            zone=zone,
            file_path=file_path,
            style=str(options["style"]).strip(),
            version=str(options["package_version"]).strip(),
            copy_to_media=bool(options["copy_to_media"]),
            relative_path_arg=str(options["relative_path"]).strip(),
        )

        metadata_json = None
        min_zoom = options["min_zoom"]
        max_zoom = options["max_zoom"]
        tile_count = options["tile_count"]

        if str(options["format"]).strip() == "mbtiles":
            metadata_json = read_mbtiles_metadata(final_path)
            tile_stats = read_mbtiles_tile_stats(final_path)
            min_zoom = min_zoom if min_zoom is not None else tile_stats.get("min_zoom")
            max_zoom = max_zoom if max_zoom is not None else tile_stats.get("max_zoom")
            tile_count = tile_count if tile_count is not None else tile_stats.get("tile_count")
            if min_zoom is None and metadata_json:
                min_zoom = self._as_int(metadata_json.get("minzoom"))
            if max_zoom is None and metadata_json:
                max_zoom = self._as_int(metadata_json.get("maxzoom"))

        now = timezone.now()
        sha256 = compute_file_sha256(final_path)
        self._write_sha256_sidecar(final_path, sha256)
        defaults = {
            "city_slug": zone.city_slug,
            "style": str(options["style"]).strip(),
            "format": str(options["format"]).strip(),
            "version": str(options["package_version"]).strip(),
            "file_name": final_path.name,
            "relative_path": relative_path.as_posix(),
            "size_bytes": final_path.stat().st_size,
            "sha256": sha256,
            "min_zoom": min_zoom,
            "max_zoom": max_zoom,
            "generated_at": now,
            "source_name": str(options["source_name"]).strip() or final_path.name,
            "attribution": str(options["attribution"]).strip() or None,
            "tile_count": tile_count,
            "metadata_json": metadata_json,
            "actif": not bool(options["inactive"]),
            "requires_wifi": bool(options["requires_wifi"]),
            "updated_at": now,
        }

        with transaction.atomic():
            basemap_package, created = BasemapPackage.objects.update_or_create(
                zone_id=zone.zone_id,
                style=defaults["style"],
                version=defaults["version"],
                defaults=defaults,
                create_defaults={
                    **defaults,
                    "created_at": now,
                },
            )

        self.stdout.write(
            self.style.SUCCESS(
                f"Package enregistré: {zone.city_slug}/{zone.zone_id}/{defaults['style']}/{defaults['version']}"
            )
        )
        self.stdout.write(f"Chemin média: {relative_path.as_posix()}")
        self.stdout.write(f"SHA256: {sha256}")

    def _resolve_target_path(
        self,
        *,
        zone: BasemapZone,
        file_path: Path,
        style: str,
        version: str,
        copy_to_media: bool,
        relative_path_arg: str,
    ) -> tuple[Path, Path]:
        media_root = Path(settings.MEDIA_ROOT).resolve()

        if copy_to_media:
            relative_path = (
                Path("basemaps")
                / zone.city_slug
                / zone.zone_id
                / style
                / version
                / file_path.name
            )
            target_path = media_root / relative_path
            target_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(file_path, target_path)
            return relative_path, target_path

        if relative_path_arg:
            relative_path = Path(relative_path_arg)
            target_path = (media_root / relative_path).resolve()
            if not target_path.exists():
                raise CommandError(
                    f"Le fichier relatif n'existe pas sous MEDIA_ROOT: {target_path}"
                )
            return relative_path, target_path

        try:
            relative_path = file_path.relative_to(media_root)
        except ValueError as exc:
            raise CommandError(
                "Le fichier doit être sous MEDIA_ROOT, ou utiliser --copy-to-media "
                "ou --relative-path."
            ) from exc

        return relative_path, file_path

    def _write_sha256_sidecar(self, file_path: Path, sha256_value: str) -> None:
        sidecar_path = file_path.with_suffix(f"{file_path.suffix}.sha256")
        sidecar_path.write_text(f"{sha256_value}\n", encoding="utf-8")

    def _as_int(self, value):
        if value in (None, ""):
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None
