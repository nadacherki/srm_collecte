from django.core.management.base import BaseCommand, CommandError


class Command(BaseCommand):
    help = "Commande obsolete: les fonds de plan offline utilisent public.zone."

    def handle(self, *args, **options):
        raise CommandError(
            "import_basemap_zones est obsolete. "
            "Alimenter public.zone et zone_utilisateur, puis generer les packages "
            "avec build_basemap_zone_package --zone-id zone_<id_zone>."
        )
