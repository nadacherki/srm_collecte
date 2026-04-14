from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth.hashers import make_password


class Command(BaseCommand):
    help = "Génère un hash Argon2 Django pour un mot de passe SRM."

    def add_arguments(self, parser):
        parser.add_argument("password", type=str, help="Mot de passe en clair à hasher")

    def handle(self, *args, **options):
        password = (options.get("password") or "").strip()
        if not password:
            raise CommandError("Le mot de passe ne peut pas être vide.")

        hashed = make_password(password, hasher="argon2")
        self.stdout.write(hashed)
