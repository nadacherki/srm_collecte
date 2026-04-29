import json
from pathlib import Path

from django.contrib.gis.geos import GEOSGeometry, MultiPolygon, Polygon
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone
from django.utils.text import slugify

from api.models import BasemapZone


class Command(BaseCommand):
    help = "Importe ou met à jour les zones basemap à partir d'un GeoJSON."

    def add_arguments(self, parser):
        parser.add_argument(
            "--geojson",
            required=True,
            help="Chemin du fichier GeoJSON des zones.",
        )
        parser.add_argument(
            "--city-slug",
            default="oujda",
            help="Slug ville appliqué si absent dans les properties.",
        )
        parser.add_argument(
            "--clear-city",
            action="store_true",
            help="Supprime les zones existantes de cette ville absentes du GeoJSON.",
        )

    def handle(self, *args, **options):
        geojson_path = Path(options["geojson"]).expanduser().resolve()
        if not geojson_path.exists():
            raise CommandError(f"GeoJSON introuvable: {geojson_path}")

        try:
            payload = json.loads(geojson_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise CommandError(f"GeoJSON invalide: {exc}") from exc

        features = payload.get("features")
        if payload.get("type") != "FeatureCollection" or not isinstance(features, list):
            raise CommandError("Le fichier doit être un GeoJSON FeatureCollection.")

        default_city_slug = (options["city_slug"] or "oujda").strip()
        clear_city = bool(options["clear_city"])
        imported_zone_ids: set[str] = set()

        with transaction.atomic():
            for feature in features:
                zone = self._upsert_feature(feature, default_city_slug)
                imported_zone_ids.add(zone.zone_id)

            if clear_city:
                deleted_count, _ = BasemapZone.objects.filter(
                    city_slug=default_city_slug,
                ).exclude(zone_id__in=imported_zone_ids).delete()
                if deleted_count:
                    self.stdout.write(
                        self.style.WARNING(
                            f"{deleted_count} zone(s) supprimée(s) pour {default_city_slug}."
                        )
                    )

        self.stdout.write(
            self.style.SUCCESS(
                f"{len(imported_zone_ids)} zone(s) importée(s) depuis {geojson_path.name}."
            )
        )

    def _upsert_feature(self, feature: dict, default_city_slug: str) -> BasemapZone:
        if feature.get("type") != "Feature":
            raise CommandError("Chaque entrée du GeoJSON doit être une Feature.")

        properties = feature.get("properties") or {}
        geometry = feature.get("geometry")
        if geometry is None:
            raise CommandError("Une zone GeoJSON ne contient pas de geometry.")

        geom = GEOSGeometry(json.dumps(geometry), srid=4326)
        if isinstance(geom, Polygon):
            geom = MultiPolygon(geom)
        elif not isinstance(geom, MultiPolygon):
            raise CommandError("La géométrie de zone doit être Polygon ou MultiPolygon.")

        zone_id = (
            str(properties.get("zone_id") or properties.get("id") or "").strip()
            or slugify(str(properties.get("nom") or properties.get("name") or "zone"))
        )
        if not zone_id:
            raise CommandError("Impossible de déterminer zone_id.")

        nom = (
            str(properties.get("nom") or properties.get("name") or zone_id).strip()
        )
        city_slug = (
            str(properties.get("city_slug") or default_city_slug).strip()
            or default_city_slug
        )

        extent = geom.extent
        if extent is None:
            raise CommandError(f"Emprise invalide pour la zone {zone_id}.")

        center = geom.centroid
        known_keys = {"zone_id", "id", "nom", "name", "city_slug", "min_zoom", "max_zoom", "actif"}
        metadata_json = {
            key: value
            for key, value in properties.items()
            if key not in known_keys
        } or None

        now = timezone.now()
        defaults = {
            "city_slug": city_slug,
            "nom": nom,
            "geom": geom,
            "bbox_west": float(extent[0]),
            "bbox_south": float(extent[1]),
            "bbox_east": float(extent[2]),
            "bbox_north": float(extent[3]),
            "center_latitude": float(center.y),
            "center_longitude": float(center.x),
            "min_zoom": int(properties.get("min_zoom") or 11),
            "max_zoom": int(properties.get("max_zoom") or 19),
            "actif": self._as_bool(properties.get("actif", True)),
            "metadata_json": metadata_json,
            "updated_at": now,
        }

        zone, created = BasemapZone.objects.update_or_create(
            zone_id=zone_id,
            defaults=defaults,
            create_defaults={
                **defaults,
                "created_at": now,
            },
        )

        self.stdout.write(
            self.style.NOTICE(f"Zone importee: {zone.city_slug}/{zone.zone_id}")
        )
        return zone

    def _as_bool(self, value) -> bool:
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return value != 0
        if value is None:
            return False
        return str(value).strip().lower() not in {"0", "false", "non", "no", ""}
