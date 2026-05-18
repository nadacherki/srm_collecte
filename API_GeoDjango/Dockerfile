# SRM Collecte — backend Django/GeoDjango (production).
# Image avec GDAL/GEOS/PROJ (requis par django.contrib.gis + PostGIS).
FROM python:3.11-slim-bookworm AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DJANGO_SETTINGS_MODULE=pprcollecte.settings

# Libs systeme geospatiales + client postgres + outils de build.
RUN apt-get update && apt-get install --no-install-recommends -y \
        gdal-bin \
        libgdal-dev \
        libgeos-dev \
        libproj-dev \
        proj-bin \
        binutils \
        libpq-dev \
        gcc \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependances Python (couche cache si requirements inchange).
COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && pip install -r /app/requirements.txt

# Code applicatif.
COPY pprcollecte /app/pprcollecte
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

WORKDIR /app/pprcollecte

# Utilisateur non-root.
RUN useradd --create-home --uid 10001 srm \
    && mkdir -p /app/pprcollecte/staticfiles /app/pprcollecte/media \
    && chown -R srm:srm /app
USER srm

EXPOSE 8000

# Healthcheck applicatif (login renvoie 400 sur body vide => process up).
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS -X POST http://127.0.0.1:8000/api/login/ \
        -H "Content-Type: application/json" -d '{}' || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
