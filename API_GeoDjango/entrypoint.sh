#!/usr/bin/env bash
# Entrypoint prod : attend la DB, applique migrations, collecte les
# statics, puis lance gunicorn. Idempotent (rejouable au redemarrage).
set -euo pipefail

cd /app/pprcollecte

DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-5432}"

echo "[entrypoint] Attente PostgreSQL ${DB_HOST}:${DB_PORT}..."
for i in $(seq 1 30); do
    if python -c "import socket,sys; s=socket.socket(); s.settimeout(2); \
sys.exit(0) if s.connect_ex(('${DB_HOST}', ${DB_PORT}))==0 else sys.exit(1)"; then
        echo "[entrypoint] PostgreSQL joignable."
        break
    fi
    if [ "$i" -eq 30 ]; then
        echo "[entrypoint] PostgreSQL injoignable apres 30 essais." >&2
        exit 1
    fi
    sleep 2
done

# Migrations : seules les migrations api/ (modeles managed=False -> ne
# touchent que fonctions/contraintes PostGIS). Echec = arret (fail-fast).
echo "[entrypoint] python manage.py migrate --noinput"
python manage.py migrate --noinput

echo "[entrypoint] python manage.py collectstatic --noinput"
python manage.py collectstatic --noinput

# Garde-fou prod : refuse de demarrer si DEBUG=True.
python - <<'PY'
import os, sys
from django.conf import settings
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'pprcollecte.settings')
django.setup()
if settings.DEBUG:
    sys.stderr.write("[entrypoint] REFUS: DJANGO_DEBUG=True interdit en prod.\n")
    sys.exit(1)
PY

WORKERS="${GUNICORN_WORKERS:-3}"
TIMEOUT="${GUNICORN_TIMEOUT:-60}"
echo "[entrypoint] gunicorn ${WORKERS} workers, timeout ${TIMEOUT}s"
exec gunicorn pprcollecte.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers "${WORKERS}" \
    --timeout "${TIMEOUT}" \
    --access-logfile - \
    --error-logfile - \
    --forwarded-allow-ips '*'
