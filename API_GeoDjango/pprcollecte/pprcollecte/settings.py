"""
Django settings for SRM Collecte backend.
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
# SECRET_KEY DOIT venir de l'environnement en prod. Le fallback dev est un
# placeholder explicite qui doit echouer le startup si quelqu'un tente
# de demarrer en prod sans avoir defini DJANGO_SECRET_KEY.
SECRET_KEY = os.environ.get(
    "DJANGO_SECRET_KEY",
    "dev-only-INSECURE-replace-via-DJANGO_SECRET_KEY-env-var",
)

DEBUG = os.environ.get("DJANGO_DEBUG", "False").strip().lower() in {
    "1",
    "true",
    "yes",
    "on",
}

# ALLOWED_HOSTS : whitelist explicite. Plus de fallback ['*'].
# En dev sans variable definie -> localhost uniquement.
_allowed_hosts_env = os.environ.get("DJANGO_ALLOWED_HOSTS", "")
ALLOWED_HOSTS = (
    [host.strip() for host in _allowed_hosts_env.split(",") if host.strip()]
    if _allowed_hosts_env
    else ["127.0.0.1", "localhost", "10.0.2.2"]
)

# Garde-fou : refuse de booter en prod avec la SECRET_KEY de dev.
if not DEBUG and SECRET_KEY.startswith("dev-only-"):
    raise ImproperlyConfigured(
        "DJANGO_SECRET_KEY doit etre defini en production "
        "(la valeur de developpement n'est pas autorisee avec DEBUG=False)."
    )

# ============================================================
# HEADERS DE SECURITE HTTP
# ============================================================
# Anti-MIME sniffing : empeche le navigateur d'interpreter une reponse
# avec un Content-Type different de celui declare.
SECURE_CONTENT_TYPE_NOSNIFF = True

# Anti-clickjacking : interdit l'inclusion en iframe.
X_FRAME_OPTIONS = "DENY"

# Referrer Policy : ne pas leak l'URL d'origine vers les domaines tiers.
SECURE_REFERRER_POLICY = "same-origin"

# Headers HTTPS-only : actives seulement en prod (DEBUG=False) car le dev
# tourne sur http://10.0.2.2:8000 sans TLS.
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SECURE_HSTS_SECONDS = 31536000  # 1 an
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    # Le mobile passe par un reverse proxy qui termine TLS : faire
    # confiance au header X-Forwarded-Proto pour la detection HTTPS.
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

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
    'csp.middleware.CSPMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# ============================================================
# CONTENT SECURITY POLICY (django-csp 4.x)
# ============================================================
# Backend principalement JSON. Politique stricte : pas de script/style
# tiers, pas d'embarquement en iframe, pas de base-uri detournee. Les
# rares surfaces HTML (DRF browsable API / admin) restent fonctionnelles
# avec 'self' + style inline (DRF en a besoin).
CONTENT_SECURITY_POLICY = {
    "DIRECTIVES": {
        "default-src": ["'none'"],
        "script-src": ["'self'"],
        "style-src": ["'self'", "'unsafe-inline'"],
        "img-src": ["'self'", "data:"],
        "font-src": ["'self'"],
        "connect-src": ["'self'"],
        "form-action": ["'self'"],
        "frame-ancestors": ["'none'"],
        "base-uri": ["'none'"],
        "object-src": ["'none'"],
    },
}

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

# Basemap regional unique : un seul fichier .pmtiles vectoriel OSM-like
# couvrant toute la zone d'intervention (Oriental). Le mobile telecharge
# ce fichier en un seul GET au login puis le rejoue offline.
BASEMAP_REGIONAL_PMTILES_PATH = os.environ.get(
    "BASEMAP_REGIONAL_PMTILES_PATH", ""
).strip()
BASEMAP_REGIONAL_NAME = (
    os.environ.get("BASEMAP_REGIONAL_NAME", "SRM Oriental").strip()
    or "SRM Oriental"
)
BASEMAP_REGIONAL_ATTRIBUTION = (
    os.environ.get(
        "BASEMAP_REGIONAL_ATTRIBUTION",
        "© Protomaps © OpenStreetMap contributors",
    ).strip()
    or "© Protomaps © OpenStreetMap contributors"
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
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'api.jwt_auth.SrmJWTAuthentication',
    ],
    # Fail-closed : tout endpoint exige un JWT valide par defaut. Les
    # rares vues publiques (login, refresh) re-declarent explicitement
    # @permission_classes([AllowAny]). Sans ca, un anonyme recevait les
    # donnees NON filtrees par zone (resolve_user_id -> None -> pas de
    # filtre). C'est le verrou qui rend le cloisonnement P1 effectif.
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 500,
    'UNAUTHENTICATED_USER': None,
    # Rate limiting global. Les vues sensibles (login, photo upload)
    # appliquent en plus une throttle dediee via @throttle_classes.
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        # Limites globales : large pour ne pas penaliser la sync legitime
        # (qui peut faire des centaines de requetes en rafale).
        'anon': '60/min',
        'user': '600/min',
        # Throttle dedies : invoquees par les vues via scope=...
        'login': '10/min',         # 10 tentatives par IP/min sur /api/login/
        'login_burst': '3/sec',    # anti-brute-force fin
        'photo_upload': '60/min',  # uploads photo
    },
}

# ============================================================
# JWT (auth custom : api/jwt_auth.py)
# ============================================================
JWT_ACCESS_LIFETIME_MINUTES = int(
    os.environ.get("JWT_ACCESS_LIFETIME_MINUTES", "15")
)
JWT_REFRESH_LIFETIME_DAYS = int(
    os.environ.get("JWT_REFRESH_LIFETIME_DAYS", "7")
)
