"""
Django settings for SRM Collecte backend.
Adapté de pprcollecte (GeoDNGR) pour le projet SIG SRM.
"""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# ============================================================
# SÉCURITÉ
# ============================================================
SECRET_KEY = 'django-insecure-srm-collecte-change-this-in-production'
DEBUG = True
ALLOWED_HOSTS = ['127.0.0.1', 'localhost', '10.0.2.2']

# ============================================================
# APPLICATIONS
# ============================================================
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.gis',
    'rest_framework',
    'rest_framework_gis',
    'api',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
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
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'pprcollecte.wsgi.application'

from pathlib import Path
import environ

BASE_DIR = Path(__file__).resolve().parent.parent

env = environ.Env()
environ.Env.read_env(BASE_DIR / ".env")

# ============================================================
# BASE DE DONNÉES — sig_srm (PostgreSQL/PostGIS)
# ============================================================
DATABASES = {
    "default": {
        "ENGINE": "django.contrib.gis.db.backends.postgis",
        "NAME": env("DB_NAME", default="sig_srm"),
        "USER": env("DB_USER", default="postgres"),
        "PASSWORD": env("DB_PASSWORD", default="geoinfo"),
        "HOST": env("DB_HOST", default="127.0.0.1"),
        "PORT": env("DB_PORT", default="5432"),
        "OPTIONS": {
            "client_encoding": env("DB_CLIENT_ENCODING", default="UTF8"),
        },
    }
}

# ============================================================
# MOT DE PASSE — Validation
# ============================================================
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

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

# Dossier pour stocker les photos uploadées par les agents
MEDIA_URL = '/media/'

MEDIA_ROOT = BASE_DIR / 'media'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ============================================================
# GDAL / GEOS / PROJ — fournis par QGIS
# Adapter les chemins selon votre version de QGIS installée
# ============================================================
GDAL_LIBRARY_PATH = r"C:\Program Files\QGIS 3.40.14\bin\gdal312.dll"
GEOS_LIBRARY_PATH = r"C:\Program Files\QGIS 3.40.14\bin\geos_c.dll"
PROJ_LIB = r"C:\Program Files\QGIS 3.34.12\share\proj"

os.environ['PATH'] = r"C:\Program Files\QGIS 3.34.12\bin;" + os.environ['PATH']
os.environ['PROJ_LIB'] = PROJ_LIB

# ============================================================
# REST FRAMEWORK
# ============================================================
REST_FRAMEWORK = {
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 500,
}
