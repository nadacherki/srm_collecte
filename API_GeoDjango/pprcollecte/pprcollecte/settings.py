"""
Django settings for SRM Collecte backend.
Adapté de pprcollecte (GeoDNGR) pour le projet SIG SRM.
"""

import os
from pathlib import Path
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent


def _load_local_env(env_path: Path) -> None:
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            os.environ.setdefault(key, value)


_load_local_env(BASE_DIR / ".env")

# ============================================================
# SÉCURITÉ
# ============================================================
SECRET_KEY = 'django-insecure-srm-collecte-change-this-in-production'
DEBUG = True
_allowed_hosts_env = os.environ.get("DJANGO_ALLOWED_HOSTS", "")
ALLOWED_HOSTS = (
    [host.strip() for host in _allowed_hosts_env.split(",") if host.strip()]
    if _allowed_hosts_env
    else ['*']
)

# ============================================================
# APPLICATIONS
# ============================================================
INSTALLED_APPS = [
    'django.contrib.staticfiles',
    'django.contrib.gis',
    'rest_framework',
    'rest_framework_gis',
    'api',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'pprcollecte.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
            ],
        },
    },
]

WSGI_APPLICATION = 'pprcollecte.wsgi.application'

# ============================================================
# BASE DE DONNÉES — sig_srm (PostgreSQL/PostGIS)
# ============================================================
DATABASES = {
    "default": {
        "ENGINE": "django.contrib.gis.db.backends.postgis",
        "NAME": os.environ.get("DB_NAME", "sig_srm"),
        "USER": os.environ.get("DB_USER", "postgres"),
        "PASSWORD": os.environ.get("DB_PASSWORD", "geoinfo"),
        "HOST": os.environ.get("DB_HOST", "127.0.0.1"),
        "PORT": os.environ.get("DB_PORT", "5432"),
        "OPTIONS": {
            "client_encoding": os.environ.get("DB_CLIENT_ENCODING", "UTF8"),
        },
    }
}

# ============================================================
# MOT DE PASSE — Argon2
# pip install argon2-cffi
# ============================================================
PASSWORD_HASHERS = [
    'django.contrib.auth.hashers.Argon2PasswordHasher',
    'django.contrib.auth.hashers.PBKDF2PasswordHasher',
    'django.contrib.auth.hashers.PBKDF2SHA1PasswordHasher',
    'django.contrib.auth.hashers.BCryptSHA256PasswordHasher',
]

AUTH_PASSWORD_VALIDATORS = []

# ============================================================
# INTERNATIONALISATION
# ============================================================
LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Africa/Casablanca'
USE_I18N = True
USE_TZ = True

# ============================================================
# FICHIERS STATIQUES
# ============================================================
STATIC_URL = 'static/'
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'
BASEMAP_BUILD_SOURCE_PATH = os.environ.get("BASEMAP_BUILD_SOURCE_PATH", "").strip()
BASEMAP_BUILD_SOURCE_DIR = os.environ.get("BASEMAP_BUILD_SOURCE_DIR", "").strip()
BASEMAP_BUILD_DEFAULT_STYLE = (
    os.environ.get("BASEMAP_BUILD_DEFAULT_STYLE", "standard").strip() or "standard"
)
BASEMAP_BUILD_SOURCE_NAME = os.environ.get("BASEMAP_BUILD_SOURCE_NAME", "").strip()
BASEMAP_SCRIPT_PYTHON = os.environ.get("BASEMAP_SCRIPT_PYTHON", "").strip()
BASEMAP_PMTILES_CLI_PATH = os.environ.get("BASEMAP_PMTILES_CLI_PATH", "").strip()
BASEMAP_BUILD_PMTILES_SOURCE_PATH = os.environ.get("BASEMAP_BUILD_PMTILES_SOURCE_PATH", "").strip()
BASEMAP_BUILD_PMTILES_SOURCE_URL = os.environ.get("BASEMAP_BUILD_PMTILES_SOURCE_URL", "").strip()
BASEMAP_BUILD_PMTILES_SOURCE_NAME = (
    os.environ.get("BASEMAP_BUILD_PMTILES_SOURCE_NAME", "Protomaps basemap").strip()
    or "Protomaps basemap"
)
BASEMAP_BUILD_PMTILES_ATTRIBUTION = (
    os.environ.get(
        "BASEMAP_BUILD_PMTILES_ATTRIBUTION",
        "© Protomaps © OpenStreetMap contributors",
    ).strip()
    or "© Protomaps © OpenStreetMap contributors"
)
BASEMAP_BUILD_OSM_SOURCE_PATH = os.environ.get("BASEMAP_BUILD_OSM_SOURCE_PATH", "").strip()
BASEMAP_BUILD_OSM_SOURCE_NAME = (
    os.environ.get("BASEMAP_BUILD_OSM_SOURCE_NAME", "OpenStreetMap contributors").strip()
    or "OpenStreetMap contributors"
)
REGARD_MIROIR_SQUARE_SIZE_METERS = float(
    os.environ.get("REGARD_MIROIR_SQUARE_SIZE_METERS", "24.0")
)

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ============================================================
# GDAL / GEOS / PROJ
# Prefer explicit environment variables, otherwise detect a known QGIS install.
# ============================================================
GDAL_LIBRARY_PATH = os.environ.get("GDAL_LIBRARY_PATH")
GEOS_LIBRARY_PATH = os.environ.get("GEOS_LIBRARY_PATH")
PROJ_LIB = os.environ.get("PROJ_LIB")

if not (GDAL_LIBRARY_PATH and GEOS_LIBRARY_PATH and PROJ_LIB):
    _qgis_candidates = [
        {
            "root": r"C:\Program Files\QGIS 3.40.14",
            "gdal": "gdal312.dll",
        },
        {
            "root": r"C:\Program Files\QGIS 3.34.12",
            "gdal": "gdal309.dll",
        },
    ]

    for _candidate in _qgis_candidates:
        _root = _candidate["root"]
        _gdal = os.path.join(_root, "bin", _candidate["gdal"])
        _geos = os.path.join(_root, "bin", "geos_c.dll")
        _proj = os.path.join(_root, "share", "proj")

        if os.path.exists(_gdal) and os.path.exists(_geos) and os.path.exists(_proj):
            GDAL_LIBRARY_PATH = _gdal
            GEOS_LIBRARY_PATH = _geos
            PROJ_LIB = _proj
            os.environ["PATH"] = os.path.join(_root, "bin") + os.pathsep + os.environ["PATH"]
            os.environ["PROJ_LIB"] = PROJ_LIB
            break

if not (GDAL_LIBRARY_PATH and GEOS_LIBRARY_PATH and PROJ_LIB):
    raise ImproperlyConfigured(
        "Unable to locate GDAL/GEOS/PROJ. Set GDAL_LIBRARY_PATH, "
        "GEOS_LIBRARY_PATH and PROJ_LIB, or install a supported QGIS version."
    )

# ============================================================
# REST FRAMEWORK
# ============================================================
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 500,
    'UNAUTHENTICATED_USER': None,
}
