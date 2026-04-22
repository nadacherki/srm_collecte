"""
Vues API pour SRM Collecte — COMPLET (55 modèles).

Chaque ViewSet filtre par id_projet et id_mission via query params.
Le login vérifie le mot de passe hashé PBKDF2 via Django.
"""

import datetime
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile
from io import StringIO
from pathlib import Path
from urllib.parse import urlparse

from django.conf import settings
from django.core.management import call_command
from django.core.management.base import CommandError
from django.db import connection, transaction
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.hashers import check_password
from rest_framework import viewsets
from rest_framework.decorators import api_view, parser_classes
from rest_framework.exceptions import ValidationError
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework import status
from django.utils.dateparse import parse_date, parse_datetime
from django.utils import timezone
import json
try:
    from PIL import Image, ExifTags
except ImportError:  # pragma: no cover - depends on runtime env
    Image = None
    ExifTags = None

from .models import (
    Utilisateur, Projet, Mission, Commune,
    HistoriqueAttribut, HistoriqueMobile, ObjetIncomplet, ObjetPhoto, FondDePlan, EvaluationAgent,
    SrmFieldOption,
    BasemapZone, BasemapPackage, AgentBasemapZone,
    MetricAgentJour, MetricAgentSemaine, MetricAgentMois,
    MetricAgentPublicJour, MetricAgentPublicSemaine, MetricAgentPublicMois, MetricAgentPublicResume,
    MetricProjetJour, MetricProjetSemaine, MetricProjetMois, MetricProjetResume,
    EpVanne, EpVanneDeVidange, EpVentouse, EpHydrant,
    EpBorneFontaine, EpBorneOnep, EpBoucheCles, EpBoucheDarrosage,
    EpCompteurAbonne, EpCompteurReseau, EpConeDeReduction, EpCentreTampon,
    EpNoeud, EpObturateur, EpReducteurDePression,
    EpForage, EpPuit, EpPompe, EpReservoir, EpStationDePompage,
    EpRegardEp, EpAutreObjet,
    EpConduiteTerrain, EpConduiteBureau, EpBranchement, EpTraverse, EpPlanche,
    AssRegard, AssRegardBranchement, AssCanalisation, AssCanalisationReutilisation,
    AssBranchement, AssBassin, AssOuvrage, AssEquipement, AssStation,
    ElecSupport, ElecPoste, ElecCoffretBt, ElecNoeudRaccord, ElecPointDesserte,
    ElecTransformateur, ElecCellule, ElecDepartBt, ElecDepartHta,
    ElecTronconBt, ElecTronconHta,
)
from .serializers import (
    ProjetSerializer, MissionSerializer, CommuneSerializer,
    HistoriqueAttributSerializer, HistoriqueMobileSerializer,
    MobileHistoryUploadSerializer, ObjetIncompletSerializer,
    FondDePlanSerializer, EvaluationAgentSerializer, SrmFieldOptionSerializer,
    BasemapZoneGeoSerializer, BasemapZoneCatalogSerializer, BasemapPackageSerializer,
    MetricAgentJourSerializer, MetricAgentSemaineSerializer, MetricAgentMoisSerializer,
    MetricAgentPublicJourSerializer, MetricAgentPublicSemaineSerializer,
    MetricAgentPublicMoisSerializer, MetricAgentPublicResumeSerializer,
    MetricProjetJourSerializer, MetricProjetSemaineSerializer,
    MetricProjetMoisSerializer, MetricProjetResumeSerializer,
    EpVanneSerializer, EpVanneDeVidangeSerializer, EpVentouseSerializer,
    EpHydrantSerializer, EpBorneFontaineSerializer, EpBorneOnepSerializer,
    EpBoucheClesSerializer, EpBoucheDarrosageSerializer,
    EpCompteurAbonneSerializer, EpCompteurReseauSerializer,
    EpConeDeReductionSerializer, EpCentreTamponSerializer,
    EpNoeudSerializer, EpObturateurSerializer, EpReducteurDePressionSerializer,
    EpForageSerializer, EpPuitSerializer, EpPompeSerializer,
    EpReservoirSerializer, EpStationDePompageSerializer,
    EpRegardEpSerializer, EpAutreObjetSerializer,
    EpConduiteTerrainSerializer, EpConduiteBureauSerializer,
    EpBranchementSerializer, EpTraverseSerializer, EpPlancheSerializer,
    AssRegardSerializer, AssRegardBranchementSerializer,
    AssCanalisationSerializer, AssCanalisationReutilisationSerializer,
    AssBranchementSerializer, AssBassinSerializer,
    AssOuvrageSerializer, AssEquipementSerializer, AssStationSerializer,
    ElecSupportSerializer, ElecPosteSerializer, ElecCoffretBtSerializer,
    ElecNoeudRaccordSerializer, ElecPointDesserteSerializer,
    ElecTransformateurSerializer, ElecCelluleSerializer,
    ElecDepartBtSerializer, ElecDepartHtaSerializer,
    ElecTronconBtSerializer, ElecTronconHtaSerializer,
    LoginRequestSerializer, PhotoUploadSerializer,
)


def _coerce_exif_text(value):
    if value is None:
        return None
    if isinstance(value, bytes):
        try:
            value = value.decode('utf-8', errors='ignore')
        except Exception:
            return None
    value = str(value).strip()
    return value or None


def _parse_exif_datetime(raw_value, raw_offset=None):
    raw_value = _coerce_exif_text(raw_value)
    if raw_value is None:
        return None

    try:
        naive_value = datetime.datetime.strptime(raw_value, '%Y:%m:%d %H:%M:%S')
    except ValueError:
        parsed = parse_datetime(raw_value)
        if parsed is None:
            return None
        if timezone.is_naive(parsed):
            return timezone.make_aware(parsed, timezone.get_current_timezone())
        return parsed

    offset = _coerce_exif_text(raw_offset)
    if offset:
        iso_base = naive_value.strftime('%Y-%m-%dT%H:%M:%S')
        parsed = parse_datetime(f'{iso_base}{offset}')
        if parsed is not None:
            return parsed

    return timezone.make_aware(naive_value, timezone.get_current_timezone())


def _extract_photo_taken_at(photo_path):
    if Image is None or ExifTags is None:
        return None

    try:
        with Image.open(photo_path) as image:
            exif = image.getexif()
    except Exception:
        return None

    if not exif:
        return None

    exif_values = {
        ExifTags.TAGS.get(tag_id, str(tag_id)): value
        for tag_id, value in exif.items()
    }

    for date_tag, offset_tag in (
        ('DateTimeOriginal', 'OffsetTimeOriginal'),
        ('DateTimeDigitized', 'OffsetTimeDigitized'),
        ('DateTime', None),
    ):
        captured_at = _parse_exif_datetime(
            exif_values.get(date_tag),
            exif_values.get(offset_tag) if offset_tag else None,
        )
        if captured_at is not None:
            return captured_at

    return None
def _normalized_db_table(model):
    return str(model._meta.db_table).replace('"', '')


def _set_local_audit_user_id(user_id):
    if user_id is None:
        return

    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT set_config('app.current_user_id', %s, true)",
            [str(user_id)],
        )


_SRM_PHOTO_MODELS = [
    EpVanne, EpVanneDeVidange, EpVentouse, EpHydrant,
    EpBorneFontaine, EpBorneOnep, EpBoucheCles, EpBoucheDarrosage,
    EpCompteurAbonne, EpCompteurReseau, EpConeDeReduction, EpCentreTampon,
    EpNoeud, EpObturateur, EpReducteurDePression,
    EpForage, EpPuit, EpPompe, EpReservoir, EpStationDePompage,
    EpRegardEp, EpAutreObjet,
    EpConduiteTerrain, EpConduiteBureau, EpBranchement, EpTraverse, EpPlanche,
    AssRegard, AssRegardBranchement, AssCanalisation, AssCanalisationReutilisation,
    AssBranchement, AssBassin, AssOuvrage, AssEquipement, AssStation,
    ElecSupport, ElecPoste, ElecCoffretBt, ElecNoeudRaccord, ElecPointDesserte,
    ElecTransformateur, ElecCellule, ElecDepartBt, ElecDepartHta,
    ElecTronconBt, ElecTronconHta,
]

_SRM_MODEL_BY_SCHEMA_TABLE = {
    tuple(_normalized_db_table(model).split('.', 1)): model
    for model in _SRM_PHOTO_MODELS
}


def _media_root_path():
    return Path(settings.MEDIA_ROOT)


def _package_serializer_context(request):
    return {
        'request': request,
        'media_root': _media_root_path(),
    }


def _parse_positive_int_value(raw_value):
    if raw_value in (None, ''):
        return None
    try:
        value = int(raw_value)
    except (TypeError, ValueError):
        return None
    return value if value > 0 else None


def _assigned_zone_ids_for_agent(agent_id):
    return AgentBasemapZone.objects.filter(
        id_user=agent_id,
        actif=True,
    ).values_list('zone_id', flat=True)


def _requested_basemap_agent_id(request):
    return _parse_positive_int_value(
        request.query_params.get('id_user') or request.query_params.get('id_agent')
    )


def _parse_bool_value(raw_value, default=False):
    if raw_value in (None, ''):
        return default
    return str(raw_value).strip().lower() not in {'0', 'false', 'no', 'off'}


def _request_param(request, name):
    request_data = getattr(request, 'data', None)
    value = request_data.get(name) if request_data is not None and hasattr(request_data, 'get') else None
    if value not in (None, ''):
        return value
    return request.query_params.get(name)


def _filtered_basemap_querysets(*, city_slug='', style='', active_only=True, agent_id=None):
    zones_qs = BasemapZone.objects.all().order_by('city_slug', 'nom', 'zone_id')
    packages_qs = BasemapPackage.objects.all().order_by(
        'city_slug',
        'zone_id',
        'style',
        'version',
    )

    if agent_id is not None:
        assigned_zone_ids = _assigned_zone_ids_for_agent(agent_id)
        zones_qs = zones_qs.filter(zone_id__in=assigned_zone_ids)
        packages_qs = packages_qs.filter(zone_id__in=assigned_zone_ids)

    if city_slug:
        zones_qs = zones_qs.filter(city_slug=city_slug)
        packages_qs = packages_qs.filter(city_slug=city_slug)
    if style:
        packages_qs = packages_qs.filter(style=style)
    if active_only:
        zones_qs = zones_qs.filter(actif=True)
        packages_qs = packages_qs.filter(actif=True)

    return zones_qs, packages_qs


def _basemap_catalog_payload(request, *, city_slug='', style='', active_only=True, agent_id=None):
    zones_qs, packages_qs = _filtered_basemap_querysets(
        city_slug=city_slug,
        style=style,
        active_only=active_only,
        agent_id=agent_id,
    )
    zones_payload = BasemapZoneCatalogSerializer(zones_qs, many=True).data
    packages_payload = BasemapPackageSerializer(
        packages_qs,
        many=True,
        context=_package_serializer_context(request),
    ).data
    return {
        'city_slug': city_slug or None,
        'id_user': agent_id,
        'active_only': active_only,
        'zones': zones_payload,
        'packages': packages_payload,
    }


def _package_file_exists(package):
    relative_path = (package.relative_path or '').strip().lstrip('/')
    if not relative_path:
        return False
    return (Path(settings.MEDIA_ROOT) / relative_path).exists()


def _latest_ready_basemap_package(*, zone_id, style='', package_format=''):
    qs = BasemapPackage.objects.filter(zone_id=zone_id)
    if style:
        qs = qs.filter(style=style)
    if package_format:
        qs = qs.filter(format=package_format)
    qs = qs.filter(actif=True).order_by('-generated_at', '-version')
    for package in qs:
        if _package_file_exists(package):
            return package
    return None


def _resolve_basemap_build_source_path():
    explicit_path = Path(settings.BASEMAP_BUILD_SOURCE_PATH).expanduser() if settings.BASEMAP_BUILD_SOURCE_PATH else None
    if explicit_path is not None:
        resolved = explicit_path.resolve()
        if not resolved.exists():
            raise CommandError(f'Source basemap introuvable: {resolved}')
        return resolved

    source_dir = (
        Path(settings.BASEMAP_BUILD_SOURCE_DIR).expanduser().resolve()
        if settings.BASEMAP_BUILD_SOURCE_DIR
        else (Path(settings.BASE_DIR).parent / 'basemaps' / 'source').resolve()
    )
    if not source_dir.exists():
        raise CommandError(
            f'Dossier source basemap introuvable: {source_dir}. '
            'Configurer BASEMAP_BUILD_SOURCE_PATH ou BASEMAP_BUILD_SOURCE_DIR.'
        )

    candidates = sorted(
        path for path in source_dir.iterdir()
        if path.is_file() and path.suffix.lower() in {'.tif', '.tiff', '.vrt', '.mbtiles'}
    )
    if not candidates:
        raise CommandError(
            f'Aucune source basemap exploitable trouvee dans {source_dir}. '
            'Attendu: .tif, .tiff, .vrt ou .mbtiles.'
        )
    if len(candidates) > 1:
        raise CommandError(
            'Plusieurs sources basemap detectees. '
            'Configurer BASEMAP_BUILD_SOURCE_PATH pour choisir explicitement la source.'
        )
    return candidates[0]


def _resolve_osm_extract_source_path():
    explicit_path = Path(settings.BASEMAP_BUILD_OSM_SOURCE_PATH).expanduser() if settings.BASEMAP_BUILD_OSM_SOURCE_PATH else None
    if explicit_path is not None:
        resolved = explicit_path.resolve()
        if not resolved.exists():
            raise CommandError(f'Extract OSM introuvable: {resolved}')
        if resolved.suffix.lower() != '.osm':
            raise CommandError(
                f'Format OSM non supporte pour le moment: {resolved.name}. '
                'Attendu: fichier .osm XML.'
            )
        return resolved

    source_dir = (
        Path(settings.BASEMAP_BUILD_SOURCE_DIR).expanduser().resolve()
        if settings.BASEMAP_BUILD_SOURCE_DIR
        else (Path(settings.BASE_DIR).parent / 'basemaps' / 'source').resolve()
    )
    if not source_dir.exists():
        raise CommandError(
            f'Dossier source OSM introuvable: {source_dir}. '
            'Configurer BASEMAP_BUILD_OSM_SOURCE_PATH ou deposer un extract .osm.'
        )

    candidates = sorted(
        path for path in source_dir.iterdir()
        if path.is_file() and path.suffix.lower() == '.osm'
    )
    if not candidates:
        raise CommandError(
            f'Aucun extract OSM exploitable trouve dans {source_dir}. '
            'Attendu: fichier .osm XML.'
        )
    if len(candidates) > 1:
        raise CommandError(
            'Plusieurs extracts OSM detectes. '
            'Configurer BASEMAP_BUILD_OSM_SOURCE_PATH pour choisir explicitement le bon fichier.'
        )
    return candidates[0]


def _resolve_pmtiles_source_spec():
    explicit_url = (getattr(settings, 'BASEMAP_BUILD_PMTILES_SOURCE_URL', '') or '').strip()
    if explicit_url:
        parsed = urlparse(explicit_url)
        if parsed.scheme not in {'http', 'https'}:
            raise CommandError(
                'BASEMAP_BUILD_PMTILES_SOURCE_URL doit etre une URL http(s) valide.'
            )
        source_name = (
            getattr(settings, 'BASEMAP_BUILD_PMTILES_SOURCE_NAME', '') or Path(parsed.path).name
        )
        return explicit_url, source_name

    explicit_path_raw = (getattr(settings, 'BASEMAP_BUILD_PMTILES_SOURCE_PATH', '') or '').strip()
    if explicit_path_raw:
        explicit_path = Path(explicit_path_raw).expanduser().resolve()
        if not explicit_path.exists():
            raise CommandError(f'Source PMTiles introuvable: {explicit_path}')
        if explicit_path.suffix.lower() != '.pmtiles':
            raise CommandError(
                f'Format PMTiles attendu pour la source: {explicit_path.name}'
            )
        source_name = (
            getattr(settings, 'BASEMAP_BUILD_PMTILES_SOURCE_NAME', '') or explicit_path.name
        )
        return str(explicit_path), source_name

    source_dir = (
        Path(settings.BASEMAP_BUILD_SOURCE_DIR).expanduser().resolve()
        if settings.BASEMAP_BUILD_SOURCE_DIR
        else (Path(settings.BASE_DIR).parent / 'basemaps' / 'source').resolve()
    )
    if not source_dir.exists():
        raise CommandError(
            f'Dossier source PMTiles introuvable: {source_dir}. '
            'Configurer BASEMAP_BUILD_PMTILES_SOURCE_PATH ou BASEMAP_BUILD_PMTILES_SOURCE_URL.'
        )

    candidates = sorted(
        path for path in source_dir.iterdir()
        if path.is_file() and path.suffix.lower() == '.pmtiles'
    )
    if not candidates:
        raise CommandError(
            f'Aucune source PMTiles exploitable trouvee dans {source_dir}. '
            'Attendu: fichier .pmtiles ou BASEMAP_BUILD_PMTILES_SOURCE_URL.'
        )
    if len(candidates) > 1:
        raise CommandError(
            'Plusieurs sources PMTiles detectees. '
            'Configurer BASEMAP_BUILD_PMTILES_SOURCE_PATH pour choisir explicitement la source.'
        )

    source_path = candidates[0]
    source_name = (
        getattr(settings, 'BASEMAP_BUILD_PMTILES_SOURCE_NAME', '') or source_path.name
    )
    return str(source_path), source_name


def _candidate_basemap_script_pythons():
    configured = (getattr(settings, 'BASEMAP_SCRIPT_PYTHON', '') or '').strip()
    if configured:
        yield Path(configured).expanduser().resolve()

    yield Path(sys.executable).resolve()

    for candidate in [
        Path(r"C:\Program Files\QGIS 3.40.14\apps\Python312\python.exe"),
        Path(r"C:\Program Files\QGIS 3.34.12\apps\Python39\python.exe"),
        Path(r"C:\OSGeo4W\bin\python3.exe"),
    ]:
        yield candidate


def _script_runtime_env(python_path: Path):
    env = dict(os.environ)
    python_parent = python_path.parent
    qgis_root = python_parent.parents[1] if len(python_parent.parents) >= 2 else None
    if qgis_root is not None and qgis_root.exists():
        qgis_bin = qgis_root / 'bin'
        qgis_proj = qgis_root / 'share' / 'proj'
        qgis_gdal = qgis_root / 'share' / 'gdal'

        if qgis_bin.exists():
            env['PATH'] = str(qgis_bin) + os.pathsep + env.get('PATH', '')
        if qgis_proj.exists():
            env['PROJ_LIB'] = str(qgis_proj)
        if qgis_gdal.exists():
            env['GDAL_DATA'] = str(qgis_gdal)
    return env


def _resolve_basemap_script_python():
    import_check = 'from osgeo import gdal; from PIL import Image; print("ok")'

    checked_candidates = []
    for candidate in _candidate_basemap_script_pythons():
        if not candidate.exists():
            continue
        checked_candidates.append(str(candidate))
        env = _script_runtime_env(candidate)
        probe = subprocess.run(
            [str(candidate), '-c', import_check],
            capture_output=True,
            text=True,
            cwd=str(Path(settings.BASE_DIR).parent),
            env=env,
        )
        if probe.returncode == 0 and 'ok' in (probe.stdout or ''):
            return candidate, env

    checked_display = ', '.join(checked_candidates) or 'aucun candidat'
    raise CommandError(
        'Aucun interpreteur Python basemap compatible trouve '
        f'(osgeo + PIL). Candidats testes: {checked_display}'
    )


def _run_python_script(script_path, arguments):
    python_path, env = _resolve_basemap_script_python()
    command = [str(python_path), str(script_path), *[str(argument) for argument in arguments]]
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        cwd=str(Path(settings.BASE_DIR).parent),
        env=env,
    )
    if result.returncode != 0:
        details = (result.stderr or result.stdout or '').strip() or 'aucun detail fourni'
        raise CommandError(f'Echec script {script_path.name}: {details}')


def _candidate_pmtiles_cli_paths():
    configured = (getattr(settings, 'BASEMAP_PMTILES_CLI_PATH', '') or '').strip()
    if configured:
        yield Path(configured).expanduser().resolve()

    bundled = (Path(settings.BASE_DIR).parent / 'basemaps' / 'tools' / 'pmtiles.exe').resolve()
    yield bundled

    which_match = shutil.which('pmtiles')
    if which_match:
        yield Path(which_match).resolve()


def _resolve_pmtiles_cli_path():
    checked_candidates = []
    for candidate in _candidate_pmtiles_cli_paths():
        checked_candidates.append(str(candidate))
        if candidate.exists():
            return candidate

    checked_display = ', '.join(checked_candidates) or 'aucun candidat'
    raise CommandError(
        'CLI pmtiles introuvable. Configurer BASEMAP_PMTILES_CLI_PATH '
        'ou deposer pmtiles.exe dans API_GeoDjango/basemaps/tools/. '
        f'Candidats testes: {checked_display}'
    )


def _run_pmtiles_command(arguments):
    executable = _resolve_pmtiles_cli_path()
    command = [str(executable), *[str(argument) for argument in arguments]]
    env = os.environ.copy()
    for proxy_name in (
        'HTTP_PROXY',
        'HTTPS_PROXY',
        'ALL_PROXY',
        'http_proxy',
        'https_proxy',
        'all_proxy',
    ):
        env.pop(proxy_name, None)
    result = subprocess.run(
        command,
        capture_output=True,
        text=True,
        cwd=str(Path(settings.BASE_DIR).parent),
        env=env,
    )
    if result.returncode != 0:
        details = (result.stderr or result.stdout or '').strip() or 'aucun detail fourni'
        raise CommandError(f'Echec pmtiles: {details}')
    return result.stdout or ''


def _read_pmtiles_header(pmtiles_path):
    header_text = _run_pmtiles_command(['show', str(pmtiles_path), '--header-json'])
    try:
        header_data = json.loads(header_text)
    except json.JSONDecodeError as exc:
        raise CommandError(
            f'Reponse header PMTiles invalide pour {pmtiles_path}: {exc}'
        ) from exc
    if not isinstance(header_data, dict):
        raise CommandError(f'Header PMTiles invalide pour {pmtiles_path}')
    return header_data


def _read_pmtiles_metadata(pmtiles_path):
    metadata_text = _run_pmtiles_command(['show', str(pmtiles_path), '--metadata'])
    try:
        metadata_data = json.loads(metadata_text)
    except json.JSONDecodeError as exc:
        raise CommandError(
            f'Reponse metadata PMTiles invalide pour {pmtiles_path}: {exc}'
        ) from exc
    if not isinstance(metadata_data, dict):
        raise CommandError(f'Metadata PMTiles invalide pour {pmtiles_path}')
    return metadata_data


def _generate_zone_package_from_pmtiles(
    *,
    zone,
    style,
    package_version,
    pmtiles_source_spec,
    source_name,
):
    basemap_root = Path(settings.BASE_DIR).parent / 'basemaps'
    work_dir = Path(
        tempfile.mkdtemp(
            prefix=f'{zone.zone_id}_pmtiles_',
            dir=str((basemap_root / 'build').resolve()),
        )
    )
    output_pmtiles = work_dir / 'package.pmtiles'
    bbox = f'{zone.bbox_west},{zone.bbox_south},{zone.bbox_east},{zone.bbox_north}'
    try:
        _run_pmtiles_command([
            'extract',
            str(pmtiles_source_spec),
            str(output_pmtiles),
            f'--bbox={bbox}',
        ])

        header_data = _read_pmtiles_header(output_pmtiles)
        metadata_data = _read_pmtiles_metadata(output_pmtiles)
        try:
            min_zoom = int(header_data.get('min_zoom'))
        except (TypeError, ValueError):
            min_zoom = None
        try:
            max_zoom = int(header_data.get('max_zoom'))
        except (TypeError, ValueError):
            max_zoom = None

        stdout = StringIO()
        stderr = StringIO()
        call_command(
            'register_basemap_package',
            zone_id=zone.zone_id,
            style=style,
            format='pmtiles',
            file=str(output_pmtiles),
            package_version=package_version,
            copy_to_media=True,
            source_name=source_name,
            attribution=getattr(settings, 'BASEMAP_BUILD_PMTILES_ATTRIBUTION', ''),
            min_zoom=min_zoom,
            max_zoom=max_zoom,
            stdout=stdout,
            stderr=stderr,
        )

        package = BasemapPackage.objects.filter(
            zone_id=zone.zone_id,
            style=style,
            version=package_version,
        ).first()
        if package is not None:
            package.metadata_json = metadata_data
            package.save(update_fields=['metadata_json'])
    finally:
        shutil.rmtree(work_dir, ignore_errors=True)


def _render_public_osm_raster_for_zone(*, zone, osm_source_path):
    basemap_root = Path(settings.BASE_DIR).parent / 'basemaps'
    scripts_dir = basemap_root / 'scripts'
    render_script = scripts_dir / 'render_public_osm_basemap.py'
    label_script = scripts_dir / 'label_public_osm_basemap.py'
    if not render_script.exists():
        raise CommandError(f'Script de rendu introuvable: {render_script}')
    if not label_script.exists():
        raise CommandError(f'Script de libelles introuvable: {label_script}')

    work_dir = Path(
        tempfile.mkdtemp(
            prefix=f'{zone.zone_id}_osm_',
            dir=str((basemap_root / 'build').resolve()),
        )
    )
    raw_raster = work_dir / 'public_osm.tif'
    labeled_raster = work_dir / 'public_osm_labeled.tif'
    try:
        common_bounds_args = [
            '--west', zone.bbox_west,
            '--south', zone.bbox_south,
            '--east', zone.bbox_east,
            '--north', zone.bbox_north,
        ]
        _run_python_script(
            render_script,
            [
                '--osm', osm_source_path,
                '--output', raw_raster,
                *common_bounds_args,
                '--width', 4096,
                '--height', 4096,
            ],
        )
        _run_python_script(
            label_script,
            [
                '--osm', osm_source_path,
                '--input-raster', raw_raster,
                '--output-raster', labeled_raster,
                *common_bounds_args,
            ],
        )
        return labeled_raster, work_dir
    except Exception:
        shutil.rmtree(work_dir, ignore_errors=True)
        raise


def _generate_zone_package_from_osm(*, zone, style, package_version, osm_source_path, source_name):
    labeled_raster, work_dir = _render_public_osm_raster_for_zone(
        zone=zone,
        osm_source_path=osm_source_path,
    )
    try:
        stdout = StringIO()
        stderr = StringIO()
        call_command(
            'build_basemap_zone_package',
            zone_id=zone.zone_id,
            source=str(labeled_raster),
            package_version=package_version,
            style=style,
            source_name=source_name,
            skip_zoom_validation=True,
            stdout=stdout,
            stderr=stderr,
        )
    finally:
        shutil.rmtree(work_dir, ignore_errors=True)



# =====================================================================
#  MIXIN : Upsert par UUID (re-synchronisation après édition)
# =====================================================================

class UpsertByUuidMixin:
    """
    Override de create() pour gérer la re-synchronisation mobile.

    Problème résolu :
      Un objet créé localement est synchronisé (POST → créé en base).
      L'agent le ré-édite (désactive toggle anomalie/incomplet).
      L'objet repasse en synced=0 côté Flutter.
      Flutter re-poste en POST → Django détecte l'UUID existant → UPDATE.

    Comportement :
      - POST sans uuid ou uuid inconnu  → CREATE (comportement standard)
      - POST avec uuid déjà en base     → UPDATE partiel (PATCH semantics)
      - Modèle sans champ uuid          → CREATE (comportement standard)
    """

    @staticmethod
    def _model_has_uuid_field(model):
        return any(f.name == 'uuid' for f in model._meta.get_fields())

    def create(self, request, *args, **kwargs):
        qs = self.get_queryset()
        if not self._model_has_uuid_field(qs.model):
            return super().create(request, *args, **kwargs)

        uuid_val = None
        data = request.data
        if isinstance(data, dict):
            props = data.get('properties', data)
            uuid_val = props.get('uuid') if isinstance(props, dict) else None

        if not uuid_val:
            return super().create(request, *args, **kwargs)

        uuid_clean = str(uuid_val).strip()
        if not uuid_clean:
            return super().create(request, *args, **kwargs)

        try:
            instance = qs.get(uuid=uuid_clean)
            serializer = self.get_serializer(
                instance, data=request.data, partial=True
            )
            serializer.is_valid(raise_exception=True)
            self.perform_update(serializer)
            response_uuid = getattr(serializer.instance, 'uuid', None)
            if response_uuid is not None and str(response_uuid).strip() != uuid_clean:
                return Response(
                    {
                        'error': (
                            'UUID incoherent apres mise a jour '
                            f'({uuid_clean} != {response_uuid})'
                        )
                    },
                    status=status.HTTP_409_CONFLICT,
                )
            return Response(serializer.data, status=status.HTTP_200_OK)
        except qs.model.DoesNotExist:
            pass
        except qs.model.MultipleObjectsReturned:
            return Response(
                {
                    'error': (
                        f'UUID ambigu detecte pour {qs.model.__name__}: {uuid_clean}'
                    )
                },
                status=status.HTTP_409_CONFLICT,
            )

        return super().create(request, *args, **kwargs)


# =====================================================================
#  MIXIN : Filtrage par projet et mission (réutilisé par tous les ViewSets)
# =====================================================================

class ProjetMissionFilterMixin(UpsertByUuidMixin):
    """
    Filtre automatiquement le queryset par id_projet et id_mission
    si ces paramètres sont passés dans l'URL (?id_projet=1&id_mission=5).
    """
    def _parse_positive_int_param(self, name):
        raw_value = self.request.query_params.get(name)
        if raw_value in (None, ''):
            return None

        try:
            value = int(raw_value)
        except (TypeError, ValueError):
            raise ValidationError({name: 'Entier positif attendu'})

        if value <= 0:
            raise ValidationError({name: 'Entier positif attendu'})

        return value

    def _parse_datetime_param(self, name):
        raw_value = self.request.query_params.get(name)
        if raw_value in (None, ''):
            return None

        value = parse_datetime(raw_value)
        if value is None:
            raise ValidationError({name: 'Date ISO 8601 attendue'})

        if timezone.is_naive(value):
            value = timezone.make_aware(value, timezone.get_current_timezone())

        return value

    def _has_model_field(self, qs, field_name):
        return any(field.name == field_name for field in qs.model._meta.fields)

    def _coerce_positive_int(self, value):
        if value in (None, ''):
            return None

        try:
            parsed = int(value)
        except (TypeError, ValueError):
            return None

        return parsed if parsed > 0 else None

    def _extract_audit_user_id(self, serializer=None, instance=None):
        candidate_keys = (
            'id_agent_modif',
            'id_agent',
            'id_agent_crea',
            'id_agent_signal',
            'id_agent_retour',
            'id_user',
        )

        validated_data = getattr(serializer, 'validated_data', None) or {}
        request_data = getattr(self.request, 'data', None)

        for source in (validated_data, request_data):
            if not hasattr(source, 'get'):
                continue
            for key in candidate_keys:
                parsed = self._coerce_positive_int(source.get(key))
                if parsed is not None:
                    return parsed

        current_instance = instance or getattr(serializer, 'instance', None)
        if current_instance is not None:
            for key in candidate_keys:
                parsed = self._coerce_positive_int(getattr(current_instance, key, None))
                if parsed is not None:
                    return parsed

        return None

    def perform_create(self, serializer):
        with transaction.atomic():
            _set_local_audit_user_id(self._extract_audit_user_id(serializer))
            serializer.save()

    def perform_update(self, serializer):
        with transaction.atomic():
            _set_local_audit_user_id(self._extract_audit_user_id(serializer))
            serializer.save()

    def perform_destroy(self, instance):
        with transaction.atomic():
            _set_local_audit_user_id(self._extract_audit_user_id(instance=instance))
            instance.delete()

    def get_queryset(self):
        qs = super().get_queryset()
        id_projet = self._parse_positive_int_param('id_projet')
        id_mission = self._parse_positive_int_param('id_mission')
        id_agent = self._parse_positive_int_param('id_agent_crea')
        updated_after = self._parse_datetime_param('updated_after')
        if id_projet is not None and self._has_model_field(qs, 'id_projet'):
            qs = qs.filter(id_projet=id_projet)
        if id_mission is not None and self._has_model_field(qs, 'id_mission'):
            qs = qs.filter(id_mission=id_mission)
        if id_agent is not None and self._has_model_field(qs, 'id_agent_crea'):
            qs = qs.filter(id_agent_crea=id_agent)
        if updated_after is not None and self._has_model_field(qs, 'updated_at'):
            qs = qs.filter(updated_at__gt=updated_after)
        if not qs.ordered:
            qs = qs.order_by(qs.model._meta.pk.attname)
        return qs


class MetricFilterMixin(ProjetMissionFilterMixin):
    metric_text_filters = {
        'nom_schema': 'nom_schema',
        'nom_table': 'nom_table',
        'metier': 'metier',
        'type_geometrie': 'type_geometrie',
        'famille_geometrie': 'famille_geometrie',
    }

    def _parse_date_only_param(self, name):
        raw_value = self.request.query_params.get(name)
        if raw_value in (None, ''):
            return None

        value = parse_date(raw_value)
        if value is None:
            raise ValidationError({name: 'Date YYYY-MM-DD attendue'})

        return value

    def _apply_metric_common_filters(self, qs):
        for param, field_name in self.metric_text_filters.items():
            value = self.request.query_params.get(param)
            if value not in (None, ''):
                qs = qs.filter(**{field_name: value})

        for param in ('id_agent', 'id_projet', 'id_mission'):
            value = self._parse_positive_int_param(param)
            if value is not None:
                qs = qs.filter(**{param: value})

        return qs


class ProjectMetricFilterMixin(ProjetMissionFilterMixin):
    def _apply_project_metric_filters(self, qs):
        id_projet = self._parse_positive_int_param('id_projet')
        if id_projet is not None:
            qs = qs.filter(id_projet=id_projet)
        return qs


# =====================================================================
#  AUTHENTIFICATION
# =====================================================================

@csrf_exempt
@api_view(['POST'])
def login_view(request):
    """
    POST /api/login/
    Body: { "login": "username", "mot_de_passe": "password" }
    Vérifie le mot de passe via les hashers Django configurés.
    Le backend ne modifie jamais automatiquement la base des mots de passe.
    """
    try:
        payload = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Corps de la requête invalide (JSON attendu)'}, status=400)

    serializer = LoginRequestSerializer(data=payload)
    if not serializer.is_valid():
        return JsonResponse({'error': serializer.errors}, status=400)

    login_val = serializer.validated_data['login']
    mot_de_passe = serializer.validated_data['mot_de_passe']

    try:
        user = Utilisateur.objects.get(login=login_val)
    except Utilisateur.DoesNotExist:
        return JsonResponse({'error': 'Login ou mot de passe incorrect'}, status=401)

    if not user.actif:
        return JsonResponse({'error': 'Compte désactivé. Contactez votre administrateur.'}, status=403)

    if not user.mot_de_passe:
        return JsonResponse({'error': 'Aucun mot de passe configuré pour ce compte'}, status=401)

    # Le mot de passe doit déjà être stocké hashé en base.
    if not user.mot_de_passe.startswith(('argon2', 'pbkdf2', 'bcrypt')):
        return JsonResponse({'error': 'Compte non configuré pour l’authentification sécurisée'}, status=401)

    mot_de_passe_valide = check_password(mot_de_passe, user.mot_de_passe)

    if not mot_de_passe_valide:
        return JsonResponse({'error': 'Login ou mot de passe incorrect'}, status=401)

    roles_mobile = ['admin', 'project_manager', 'editeur_terrain', 'editeur_bureau']
    if user.role not in roles_mobile:
        return JsonResponse({'error': "Votre profil ne permet pas l'accès à l'application mobile"}, status=403)

    projet_data = None
    if user.id_projet_actif:
        try:
            projet = Projet.objects.get(id_projet=user.id_projet_actif)
            projet_data = {
                'id_projet': projet.id_projet,
                'code_affaire': projet.code_affaire,
                'nom': projet.nom,
                'srm': projet.srm,
                'region': projet.region,
                'metier': projet.metier,
                'statut': projet.statut,
            }
        except Projet.DoesNotExist:
            pass

    user.dernier_login = timezone.now()
    user.save(update_fields=['dernier_login'])

    return JsonResponse({
        'success': True,
        'user': {
            'id_user': user.id_user,
            'login': user.login,
            'nom_prenom': user.nom_prenom,
            'role': user.role,
            'id_projet_actif': user.id_projet_actif,
            'nb_objets_collectes_total': user.nb_objets_collectes_total,
        },
        'projet_actif': projet_data,
    })


@api_view(['GET'])
def basemap_catalog_view(request):
    city_slug = (request.query_params.get('city_slug') or '').strip()
    style = (request.query_params.get('style') or '').strip()
    active_only = request.query_params.get('active_only', 'true').lower() != 'false'
    agent_id = _requested_basemap_agent_id(request)
    payload = _basemap_catalog_payload(
        request,
        city_slug=city_slug,
        style=style,
        active_only=active_only,
        agent_id=agent_id,
    )
    return Response(payload, status=status.HTTP_200_OK)


@api_view(['POST'])
def prepare_agent_basemap_packages_view(request):
    agent_id = _parse_positive_int_value(
        _request_param(request, 'id_user') or _request_param(request, 'id_agent')
    )
    if agent_id is None:
        return Response(
            {'success': False, 'message': "id_user est obligatoire pour preparer les cartes de l'agent."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    city_slug = str(_request_param(request, 'city_slug') or '').strip()
    style = str(
        _request_param(request, 'style') or settings.BASEMAP_BUILD_DEFAULT_STYLE or 'standard'
    ).strip()
    active_only = _parse_bool_value(_request_param(request, 'active_only'), default=True)
    force_rebuild = _parse_bool_value(_request_param(request, 'force'), default=False)

    zones_qs, _ = _filtered_basemap_querysets(
        city_slug=city_slug,
        style='',
        active_only=active_only,
        agent_id=agent_id,
    )
    zones = list(zones_qs)
    if not zones:
        payload = _basemap_catalog_payload(
            request,
            city_slug=city_slug,
            style=style,
            active_only=active_only,
            agent_id=agent_id,
        )
        payload.update({
            'success': True,
            'message': "Aucune zone n'est affectee a cet agent.",
            'generated_count': 0,
            'reused_count': 0,
            'failed_count': 0,
            'errors': [],
        })
        return Response(payload, status=status.HTTP_200_OK)

    generated_count = 0
    reused_count = 0
    failed_count = 0
    errors = []

    pmtiles_source_spec = None
    osm_source_path = None
    raster_source_path = None
    pipeline_mode = None
    pipeline_source_name = None
    resolution_errors = []

    try:
        pmtiles_source_spec, pmtiles_source_name = _resolve_pmtiles_source_spec()
        _resolve_pmtiles_cli_path()
        pmtiles_source_spec = str(pmtiles_source_spec)
        pipeline_mode = 'pmtiles'
        pipeline_source_name = pmtiles_source_name
    except CommandError as exc:
        resolution_errors.append(str(exc))

    if pipeline_mode is None:
        try:
            osm_source_path = _resolve_osm_extract_source_path()
            pipeline_mode = 'osm'
            pipeline_source_name = settings.BASEMAP_BUILD_OSM_SOURCE_NAME or osm_source_path.name
        except CommandError as exc:
            resolution_errors.append(str(exc))

    if pipeline_mode is None:
        try:
            raster_source_path = _resolve_basemap_build_source_path()
            pipeline_mode = 'raster'
            pipeline_source_name = settings.BASEMAP_BUILD_SOURCE_NAME or raster_source_path.name
        except CommandError as exc:
            resolution_errors.append(str(exc))

    if pipeline_mode is None:
        payload = _basemap_catalog_payload(
            request,
            city_slug=city_slug,
            style=style,
            active_only=active_only,
            agent_id=agent_id,
        )
        resolution_message = resolution_errors[0] if resolution_errors else (
            "Aucune source basemap serveur n'est configuree."
        )
        payload.update({
            'success': False,
            'message': resolution_message,
            'generated_count': 0,
            'reused_count': 0,
            'failed_count': len(zones),
            'errors': [{'zone_id': zone.zone_id, 'error': resolution_message} for zone in zones],
        })
        return Response(payload, status=status.HTTP_200_OK)

    timestamp_prefix = timezone.now().strftime('auto-%Y%m%d%H%M%S')
    target_format = 'pmtiles' if pipeline_mode == 'pmtiles' else 'mbtiles'

    for index, zone in enumerate(zones, start=1):
        existing_package = None if force_rebuild else _latest_ready_basemap_package(
            zone_id=zone.zone_id,
            style=style,
            package_format=target_format,
        )
        if existing_package is not None:
            reused_count += 1
            continue

        try:
            package_version = f'{timestamp_prefix}-{index}'
            if pipeline_mode == 'pmtiles':
                _generate_zone_package_from_pmtiles(
                    zone=zone,
                    style=style,
                    package_version=package_version,
                    pmtiles_source_spec=pmtiles_source_spec,
                    source_name=pipeline_source_name,
                )
            elif pipeline_mode == 'osm':
                _generate_zone_package_from_osm(
                    zone=zone,
                    style=style,
                    package_version=package_version,
                    osm_source_path=osm_source_path,
                    source_name=pipeline_source_name,
                )
            else:
                stdout = StringIO()
                stderr = StringIO()
                call_command(
                    'build_basemap_zone_package',
                    zone_id=zone.zone_id,
                    source=str(raster_source_path),
                    package_version=package_version,
                    style=style,
                    source_name=pipeline_source_name,
                    skip_zoom_validation=True,
                    stdout=stdout,
                    stderr=stderr,
                )
            generated_count += 1
        except Exception as exc:
            failed_count += 1
            errors.append({
                'zone_id': zone.zone_id,
                'zone_name': zone.nom,
                'error': str(exc),
            })

    payload = _basemap_catalog_payload(
        request,
        city_slug=city_slug,
        style=style,
        active_only=active_only,
        agent_id=agent_id,
    )
    success = failed_count == 0 and (generated_count > 0 or reused_count > 0)
    if generated_count > 0 and failed_count == 0:
        message = (
            f'{generated_count} zone(s) preparee(s) et {reused_count} deja disponible(s).'
            if reused_count > 0
            else f'{generated_count} zone(s) preparee(s) avec succes.'
        )
    elif reused_count > 0 and failed_count == 0:
        message = (
            'Les cartes des zones de cet agent sont deja disponibles.'
            if reused_count == len(zones)
            else f'{reused_count} zone(s) deja disponible(s).'
        )
    elif generated_count > 0 or reused_count > 0:
        message = (
            f'{generated_count} zone(s) preparee(s), '
            f'{reused_count} deja disponible(s), '
            f'{failed_count} en echec.'
        )
    else:
        message = "Aucune carte n'a pu etre preparee pour les zones de cet agent."
    if pipeline_mode == 'pmtiles':
        message = f'{message} Source: PMTiles serveur.'
    elif pipeline_mode == 'osm':
        message = f'{message} Source: extract OSM serveur.'
    elif pipeline_mode == 'raster':
        message = f'{message} Source: raster serveur.'

    payload.update({
        'success': success,
        'message': message,
        'pipeline_mode': pipeline_mode,
        'generated_count': generated_count,
        'reused_count': reused_count,
        'failed_count': failed_count,
        'errors': errors,
    })
    return Response(payload, status=status.HTTP_200_OK)


@api_view(['POST'])
@parser_classes([MultiPartParser, FormParser])
def photo_upload_view(request):
    serializer = PhotoUploadSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data

    schema_name = data['schema_name'].strip().lower()
    table_name = data['table_name'].strip().lower()
    uuid_objet = data['uuid_objet'].strip()
    photo_slot = data['photo_slot']
    uploaded_file = data['file']

    model = _SRM_MODEL_BY_SCHEMA_TABLE.get((schema_name, table_name))
    if model is None:
        return Response(
            {'error': f'Objet SRM inconnu: {schema_name}.{table_name}'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    instance = model.objects.filter(uuid=uuid_objet).first()
    if instance is None:
        return Response(
            {'error': f'Objet introuvable pour uuid={uuid_objet}'},
            status=status.HTTP_404_NOT_FOUND,
        )

    field_name = f'photo_{photo_slot}'
    model_fields = {field.name for field in model._meta.fields}
    if field_name not in model_fields:
        return Response(
            {'error': f'Le champ {field_name} n’existe pas sur {schema_name}.{table_name}'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    safe_uuid = re.sub(r'[^A-Za-z0-9._-]+', '_', uuid_objet)
    extension = Path(uploaded_file.name).suffix.lower()
    file_name = f'{safe_uuid}_{photo_slot}{extension}'
    relative_dir = Path('srm_photos') / schema_name / table_name
    absolute_dir = Path(settings.MEDIA_ROOT) / relative_dir
    absolute_dir.mkdir(parents=True, exist_ok=True)

    existing_photo = ObjetPhoto.objects.filter(
        nom_schema=schema_name,
        nom_table=table_name,
        uuid_objet=uuid_objet,
        num_photo=photo_slot,
    ).first()
    if existing_photo and existing_photo.chemin_relatif:
        previous_file = Path(settings.MEDIA_ROOT) / existing_photo.chemin_relatif
        if previous_file.exists() and previous_file.name != file_name:
            previous_file.unlink(missing_ok=True)

    final_path = absolute_dir / file_name
    temp_path = absolute_dir / f'.tmp_{file_name}'
    sha256 = hashlib.sha256()

    with temp_path.open('wb') as destination:
        for chunk in uploaded_file.chunks():
            destination.write(chunk)
            sha256.update(chunk)

    os.replace(temp_path, final_path)

    relative_path = (relative_dir / file_name).as_posix()
    captured_at = _extract_photo_taken_at(final_path)
    uploaded_at = timezone.now()
    with transaction.atomic():
        _set_local_audit_user_id(data.get('id_agent_crea'))
        setattr(instance, field_name, relative_path)
        instance.save(update_fields=[field_name])

        ObjetPhoto.objects.update_or_create(
            nom_schema=schema_name,
            nom_table=table_name,
            uuid_objet=uuid_objet,
            num_photo=photo_slot,
            defaults={
                'nom_fichier': file_name,
                'chemin_relatif': relative_path,
                'hash_sha256': sha256.hexdigest(),
                'mime_type': getattr(uploaded_file, 'content_type', '') or None,
                'taille_octets': getattr(uploaded_file, 'size', None),
                'id_projet': data.get('id_projet'),
                'id_mission': data.get('id_mission'),
                'id_agent_crea': data.get('id_agent_crea'),
                'date_prise_reelle': captured_at,
                'date_upload': uploaded_at,
                'actif': True,
            },
        )

    media_url = request.build_absolute_uri(f'{settings.MEDIA_URL}{relative_path}')
    return Response(
        {
            'success': True,
            'schema_name': schema_name,
            'table_name': table_name,
            'uuid_objet': uuid_objet,
            'photo_slot': photo_slot,
            'field_name': field_name,
            'relative_path': relative_path,
            'media_url': media_url,
            'date_prise_reelle': captured_at.isoformat() if captured_at else None,
            'date_upload': uploaded_at.isoformat(),
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(['POST'])
def mobile_history_upload_view(request):
    serializer = MobileHistoryUploadSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data

    attributes = data.get('attributes', [])
    events = data.get('events', [])
    created_count = 0
    updated_count = 0

    with transaction.atomic():
        for item in attributes:
            _, created = HistoriqueMobile.objects.update_or_create(
                sync_uuid=item['sync_uuid'],
                defaults={
                    'type_entree': 'ATTRIBUT',
                    'source_table_locale': 'historique_local_attribut',
                    'source_id_local': item.get('id_historique_local'),
                    'id_objet': item.get('id_objet'),
                    'cle_ligne': item.get('cle_ligne'),
                    'uuid_objet': item.get('uuid_objet'),
                    'nom_schema': item.get('nom_schema'),
                    'nom_table': item.get('nom_table'),
                    'nom_classe': item.get('nom_classe'),
                    'nom_attribut': item.get('nom_attribut'),
                    'ancienne_valeur': item.get('ancienne_valeur'),
                    'nouvelle_valeur': item.get('nouvelle_valeur'),
                    'type_action': item.get('type_action'),
                    'type_evenement': None,
                    'payload_json': None,
                    'date_action': item.get('date_action'),
                    'date_reception': timezone.now(),
                    'id_agent': item.get('id_agent'),
                },
            )
            if created:
                created_count += 1
            else:
                updated_count += 1

        for item in events:
            _, created = HistoriqueMobile.objects.update_or_create(
                sync_uuid=item['sync_uuid'],
                defaults={
                    'type_entree': 'EVENEMENT',
                    'source_table_locale': 'historique_local_evenement',
                    'source_id_local': item.get('id_evenement_local'),
                    'id_objet': item.get('id_objet'),
                    'cle_ligne': item.get('cle_ligne'),
                    'uuid_objet': item.get('uuid_objet'),
                    'nom_schema': item.get('nom_schema'),
                    'nom_table': item.get('nom_table'),
                    'nom_classe': None,
                    'nom_attribut': None,
                    'ancienne_valeur': None,
                    'nouvelle_valeur': None,
                    'type_action': None,
                    'type_evenement': item.get('type_evenement'),
                    'payload_json': item.get('payload_json'),
                    'date_action': item.get('date_action'),
                    'date_reception': timezone.now(),
                    'id_agent': item.get('id_agent'),
                },
            )
            if created:
                created_count += 1
            else:
                updated_count += 1

    return Response(
        {
            'success': True,
            'attributes_received': len(attributes),
            'events_received': len(events),
            'created_count': created_count,
            'updated_count': updated_count,
        },
        status=status.HTTP_201_CREATED,
    )


# =====================================================================
#  PUBLIC
# =====================================================================

class ProjetViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Projet.objects.all()
    serializer_class = ProjetSerializer


class MissionViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = Mission.objects.all()
    serializer_class = MissionSerializer

    def get_queryset(self):
        qs = Mission.objects.all()
        id_agent = self._parse_positive_int_param('id_agent')
        id_projet = self._parse_positive_int_param('id_projet')
        if id_agent is not None:
            qs = qs.filter(id_agent=id_agent)
        if id_projet is not None:
            qs = qs.filter(id_projet=id_projet)
        return qs.order_by('-id_mission')


class CommuneViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Commune.objects.all().order_by('id_commune')
    serializer_class = CommuneSerializer


class HistoriqueAttributViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = HistoriqueAttribut.objects.all()
    serializer_class = HistoriqueAttributSerializer

    def get_queryset(self):
        qs = HistoriqueAttribut.objects.all().order_by('-date_action', '-id_historique')
        query_params = self.request.query_params

        text_filters = {
            'nom_schema': 'nom_schema',
            'nom_table': 'nom_table',
            'nom_classe': 'nom_classe',
            'nom_attribut': 'nom_attribut',
            'uuid_objet': 'uuid_objet',
            'cle_ligne': 'cle_ligne',
            'type_action': 'type_action',
        }
        for param, field_name in text_filters.items():
            value = query_params.get(param)
            if value not in (None, ''):
                qs = qs.filter(**{field_name: value})

        for param in ('id_objet', 'id_agent'):
            raw_value = query_params.get(param)
            if raw_value in (None, ''):
                continue
            try:
                qs = qs.filter(**{param: int(raw_value)})
            except (TypeError, ValueError):
                continue

        return qs


class HistoriqueMobileViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = HistoriqueMobile.objects.all()
    serializer_class = HistoriqueMobileSerializer

    def get_queryset(self):
        qs = HistoriqueMobile.objects.all().order_by('-date_action', '-id_historique_mobile')
        query_params = self.request.query_params

        text_filters = {
            'type_entree': 'type_entree',
            'type_evenement': 'type_evenement',
            'type_action': 'type_action',
            'nom_schema': 'nom_schema',
            'nom_table': 'nom_table',
            'nom_attribut': 'nom_attribut',
            'uuid_objet': 'uuid_objet',
            'cle_ligne': 'cle_ligne',
            'source_table_locale': 'source_table_locale',
            'sync_uuid': 'sync_uuid',
        }
        for param, field_name in text_filters.items():
            value = query_params.get(param)
            if value not in (None, ''):
                qs = qs.filter(**{field_name: value})

        for param in ('id_objet', 'id_agent', 'source_id_local'):
            raw_value = query_params.get(param)
            if raw_value in (None, ''):
                continue
            try:
                qs = qs.filter(**{param: int(raw_value)})
            except (TypeError, ValueError):
                continue

        return qs


class ObjetIncompletViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ObjetIncomplet.objects.all()
    serializer_class = ObjetIncompletSerializer


class FondDePlanViewSet(ProjetMissionFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = FondDePlan.objects.all()
    serializer_class = FondDePlanSerializer

    def get_queryset(self):
        qs = FondDePlan.objects.all()
        id_projet = self._parse_positive_int_param('id_projet')
        if id_projet is not None:
            qs = qs.filter(id_projet=id_projet)
        return qs


class EvaluationAgentViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = EvaluationAgent.objects.all()
    serializer_class = EvaluationAgentSerializer


class SrmFieldOptionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = SrmFieldOption.objects.all()
    serializer_class = SrmFieldOptionSerializer

    def get_queryset(self):
        qs = SrmFieldOption.objects.all().order_by(
            'table_schema',
            'table_name',
            'field_name',
            'display_order',
            'code_value',
        )

        table_schema = (self.request.query_params.get('table_schema') or '').strip()
        table_name = (self.request.query_params.get('table_name') or '').strip()
        field_name = (self.request.query_params.get('field_name') or '').strip()
        active_only = self.request.query_params.get('active_only', 'true').lower()

        if table_schema:
            qs = qs.filter(table_schema=table_schema)
        if table_name:
            qs = qs.filter(table_name=table_name)
        if field_name:
            qs = qs.filter(field_name=field_name)
        if active_only != 'false':
            qs = qs.filter(actif=True)

        return qs


class BasemapZoneViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = BasemapZone.objects.all()
    serializer_class = BasemapZoneGeoSerializer

    def get_queryset(self):
        qs = BasemapZone.objects.all().order_by('city_slug', 'nom', 'zone_id')
        agent_id = _requested_basemap_agent_id(self.request)
        if agent_id is not None:
            qs = qs.filter(zone_id__in=_assigned_zone_ids_for_agent(agent_id))

        city_slug = (self.request.query_params.get('city_slug') or '').strip()
        if city_slug:
            qs = qs.filter(city_slug=city_slug)

        active_only = self.request.query_params.get('active_only', 'true').lower()
        if active_only != 'false':
            qs = qs.filter(actif=True)

        return qs


class BasemapPackageViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = BasemapPackage.objects.all()
    serializer_class = BasemapPackageSerializer

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context.update(_package_serializer_context(self.request))
        return context

    def get_queryset(self):
        qs = BasemapPackage.objects.all().order_by(
            'city_slug',
            'zone_id',
            'style',
            'version',
        )
        agent_id = _requested_basemap_agent_id(self.request)
        if agent_id is not None:
            qs = qs.filter(zone_id__in=_assigned_zone_ids_for_agent(agent_id))

        city_slug = (self.request.query_params.get('city_slug') or '').strip()
        zone_id = (self.request.query_params.get('zone_id') or '').strip()
        style = (self.request.query_params.get('style') or '').strip()
        package_format = (self.request.query_params.get('format') or '').strip()

        if city_slug:
            qs = qs.filter(city_slug=city_slug)
        if zone_id:
            qs = qs.filter(zone_id=zone_id)
        if style:
            qs = qs.filter(style=style)
        if package_format:
            qs = qs.filter(format=package_format)

        active_only = self.request.query_params.get('active_only', 'true').lower()
        if active_only != 'false':
            qs = qs.filter(actif=True)

        return qs


class MetricAgentJourViewSet(MetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentJour.objects.all()
    serializer_class = MetricAgentJourSerializer

    def get_queryset(self):
        qs = MetricAgentJour.objects.all().order_by('-jour', 'id_agent', 'nom_schema', 'nom_table')
        qs = self._apply_metric_common_filters(qs)

        jour = self._parse_date_only_param('jour')
        date_from = self._parse_date_only_param('date_from')
        date_to = self._parse_date_only_param('date_to')

        if jour is not None:
            qs = qs.filter(jour=jour)
        if date_from is not None:
            qs = qs.filter(jour__gte=date_from)
        if date_to is not None:
            qs = qs.filter(jour__lte=date_to)

        return qs


class MetricAgentSemaineViewSet(MetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentSemaine.objects.all()
    serializer_class = MetricAgentSemaineSerializer

    def get_queryset(self):
        qs = MetricAgentSemaine.objects.all().order_by('-semaine_debut', 'id_agent', 'nom_schema', 'nom_table')
        qs = self._apply_metric_common_filters(qs)

        semaine_debut = self._parse_date_only_param('semaine_debut')
        annee_iso = self._parse_positive_int_param('annee_iso')
        semaine_iso = self._parse_positive_int_param('semaine_iso')

        if semaine_debut is not None:
            qs = qs.filter(semaine_debut=semaine_debut)
        if annee_iso is not None:
            qs = qs.filter(annee_iso=annee_iso)
        if semaine_iso is not None:
            qs = qs.filter(semaine_iso=semaine_iso)

        return qs


class MetricAgentMoisViewSet(MetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentMois.objects.all()
    serializer_class = MetricAgentMoisSerializer

    def get_queryset(self):
        qs = MetricAgentMois.objects.all().order_by('-mois', 'id_agent', 'nom_schema', 'nom_table')
        qs = self._apply_metric_common_filters(qs)

        mois = self._parse_date_only_param('mois')
        annee = self._parse_positive_int_param('annee')
        mois_numero = self._parse_positive_int_param('mois_numero')

        if mois is not None:
            qs = qs.filter(mois=mois)
        if annee is not None:
            qs = qs.filter(annee=annee)
        if mois_numero is not None:
            if not 1 <= mois_numero <= 12:
                raise ValidationError({'mois_numero': 'Valeur entre 1 et 12 attendue'})
            qs = qs.filter(mois_numero=mois_numero)

        return qs


class MetricAgentPublicJourViewSet(MetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentPublicJour.objects.all()
    serializer_class = MetricAgentPublicJourSerializer

    def get_queryset(self):
        qs = MetricAgentPublicJour.objects.all().order_by('-jour', 'id_agent')
        qs = self._apply_metric_common_filters(qs)

        jour = self._parse_date_only_param('jour')
        date_from = self._parse_date_only_param('date_from')
        date_to = self._parse_date_only_param('date_to')

        if jour is not None:
            qs = qs.filter(jour=jour)
        if date_from is not None:
            qs = qs.filter(jour__gte=date_from)
        if date_to is not None:
            qs = qs.filter(jour__lte=date_to)

        return qs


class MetricAgentPublicSemaineViewSet(MetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentPublicSemaine.objects.all()
    serializer_class = MetricAgentPublicSemaineSerializer

    def get_queryset(self):
        qs = MetricAgentPublicSemaine.objects.all().order_by('-semaine_debut', 'id_agent')
        qs = self._apply_metric_common_filters(qs)

        semaine_debut = self._parse_date_only_param('semaine_debut')
        annee_iso = self._parse_positive_int_param('annee_iso')
        semaine_iso = self._parse_positive_int_param('semaine_iso')

        if semaine_debut is not None:
            qs = qs.filter(semaine_debut=semaine_debut)
        if annee_iso is not None:
            qs = qs.filter(annee_iso=annee_iso)
        if semaine_iso is not None:
            qs = qs.filter(semaine_iso=semaine_iso)

        return qs


class MetricAgentPublicMoisViewSet(MetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentPublicMois.objects.all()
    serializer_class = MetricAgentPublicMoisSerializer

    def get_queryset(self):
        qs = MetricAgentPublicMois.objects.all().order_by('-mois', 'id_agent')
        qs = self._apply_metric_common_filters(qs)

        mois = self._parse_date_only_param('mois')
        annee = self._parse_positive_int_param('annee')
        mois_numero = self._parse_positive_int_param('mois_numero')

        if mois is not None:
            qs = qs.filter(mois=mois)
        if annee is not None:
            qs = qs.filter(annee=annee)
        if mois_numero is not None:
            if not 1 <= mois_numero <= 12:
                raise ValidationError({'mois_numero': 'Valeur entre 1 et 12 attendue'})
            qs = qs.filter(mois_numero=mois_numero)

        return qs


class MetricAgentPublicResumeViewSet(MetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentPublicResume.objects.all()
    serializer_class = MetricAgentPublicResumeSerializer

    def get_queryset(self):
        qs = MetricAgentPublicResume.objects.all().order_by('id_agent', 'id_projet')
        for param in ('id_agent', 'id_projet'):
            value = self._parse_positive_int_param(param)
            if value is not None:
                qs = qs.filter(**{param: value})
        return qs


class MetricProjetJourViewSet(ProjectMetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricProjetJour.objects.all()
    serializer_class = MetricProjetJourSerializer

    def get_queryset(self):
        qs = MetricProjetJour.objects.all().order_by('-jour', 'id_projet')
        qs = self._apply_project_metric_filters(qs)

        jour = self._parse_date_only_param('jour')
        date_from = self._parse_date_only_param('date_from')
        date_to = self._parse_date_only_param('date_to')

        if jour is not None:
            qs = qs.filter(jour=jour)
        if date_from is not None:
            qs = qs.filter(jour__gte=date_from)
        if date_to is not None:
            qs = qs.filter(jour__lte=date_to)

        return qs


class MetricProjetSemaineViewSet(ProjectMetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricProjetSemaine.objects.all()
    serializer_class = MetricProjetSemaineSerializer

    def get_queryset(self):
        qs = MetricProjetSemaine.objects.all().order_by('-semaine_debut', 'id_projet')
        qs = self._apply_project_metric_filters(qs)

        semaine_debut = self._parse_date_only_param('semaine_debut')
        annee_iso = self._parse_positive_int_param('annee_iso')
        semaine_iso = self._parse_positive_int_param('semaine_iso')

        if semaine_debut is not None:
            qs = qs.filter(semaine_debut=semaine_debut)
        if annee_iso is not None:
            qs = qs.filter(annee_iso=annee_iso)
        if semaine_iso is not None:
            qs = qs.filter(semaine_iso=semaine_iso)

        return qs


class MetricProjetMoisViewSet(ProjectMetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricProjetMois.objects.all()
    serializer_class = MetricProjetMoisSerializer

    def get_queryset(self):
        qs = MetricProjetMois.objects.all().order_by('-mois', 'id_projet')
        qs = self._apply_project_metric_filters(qs)

        mois = self._parse_date_only_param('mois')
        annee = self._parse_positive_int_param('annee')
        mois_numero = self._parse_positive_int_param('mois_numero')

        if mois is not None:
            qs = qs.filter(mois=mois)
        if annee is not None:
            qs = qs.filter(annee=annee)
        if mois_numero is not None:
            if not 1 <= mois_numero <= 12:
                raise ValidationError({'mois_numero': 'Valeur entre 1 et 12 attendue'})
            qs = qs.filter(mois_numero=mois_numero)

        return qs


class MetricProjetResumeViewSet(ProjectMetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricProjetResume.objects.all()
    serializer_class = MetricProjetResumeSerializer

    def get_queryset(self):
        qs = MetricProjetResume.objects.all().order_by('id_projet')
        qs = self._apply_project_metric_filters(qs)
        return qs


# =====================================================================
#  EP — Eau Potable (27 ViewSets)
# =====================================================================

class EpVanneViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpVanne.objects.all()
    serializer_class = EpVanneSerializer


class EpVanneDeVidangeViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpVanneDeVidange.objects.all()
    serializer_class = EpVanneDeVidangeSerializer


class EpVentouseViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpVentouse.objects.all()
    serializer_class = EpVentouseSerializer


class EpHydrantViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpHydrant.objects.all()
    serializer_class = EpHydrantSerializer


class EpBorneFontaineViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpBorneFontaine.objects.all()
    serializer_class = EpBorneFontaineSerializer


class EpBorneOnepViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpBorneOnep.objects.all()
    serializer_class = EpBorneOnepSerializer


class EpBoucheClesViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpBoucheCles.objects.all()
    serializer_class = EpBoucheClesSerializer


class EpBoucheDarrosageViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpBoucheDarrosage.objects.all()
    serializer_class = EpBoucheDarrosageSerializer


class EpCompteurAbonneViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpCompteurAbonne.objects.all()
    serializer_class = EpCompteurAbonneSerializer


class EpCompteurReseauViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpCompteurReseau.objects.all()
    serializer_class = EpCompteurReseauSerializer


class EpConeDeReductionViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpConeDeReduction.objects.all()
    serializer_class = EpConeDeReductionSerializer


class EpCentreTamponViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpCentreTampon.objects.all()
    serializer_class = EpCentreTamponSerializer


class EpNoeudViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpNoeud.objects.all()
    serializer_class = EpNoeudSerializer


class EpObturateurViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpObturateur.objects.all()
    serializer_class = EpObturateurSerializer


class EpReducteurDePressionViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpReducteurDePression.objects.all()
    serializer_class = EpReducteurDePressionSerializer


class EpForageViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpForage.objects.all()
    serializer_class = EpForageSerializer


class EpPuitViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpPuit.objects.all()
    serializer_class = EpPuitSerializer


class EpPompeViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpPompe.objects.all()
    serializer_class = EpPompeSerializer


class EpReservoirViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpReservoir.objects.all()
    serializer_class = EpReservoirSerializer


class EpStationDePompageViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpStationDePompage.objects.all()
    serializer_class = EpStationDePompageSerializer


class EpRegardEpViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpRegardEp.objects.all()
    serializer_class = EpRegardEpSerializer


class EpAutreObjetViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpAutreObjet.objects.all()
    serializer_class = EpAutreObjetSerializer


class EpConduiteTerrainViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpConduiteTerrain.objects.all()
    serializer_class = EpConduiteTerrainSerializer


class EpConduiteBureauViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpConduiteBureau.objects.all()
    serializer_class = EpConduiteBureauSerializer


class EpBranchementViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpBranchement.objects.all()
    serializer_class = EpBranchementSerializer


class EpTraverseViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = EpTraverse.objects.all()
    serializer_class = EpTraverseSerializer


class EpPlancheViewSet(ProjetMissionFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = EpPlanche.objects.all()
    serializer_class = EpPlancheSerializer


# =====================================================================
#  ASS — Assainissement (9 ViewSets)
# =====================================================================

class AssRegardViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = AssRegard.objects.all()
    serializer_class = AssRegardSerializer


class AssRegardBranchementViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = AssRegardBranchement.objects.all()
    serializer_class = AssRegardBranchementSerializer


class AssCanalisationViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = AssCanalisation.objects.all()
    serializer_class = AssCanalisationSerializer


class AssCanalisationReutilisationViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = AssCanalisationReutilisation.objects.all()
    serializer_class = AssCanalisationReutilisationSerializer


class AssBranchementViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = AssBranchement.objects.all()
    serializer_class = AssBranchementSerializer


class AssBassinViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = AssBassin.objects.all()
    serializer_class = AssBassinSerializer


class AssOuvrageViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = AssOuvrage.objects.all()
    serializer_class = AssOuvrageSerializer


class AssEquipementViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = AssEquipement.objects.all()
    serializer_class = AssEquipementSerializer


class AssStationViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = AssStation.objects.all()
    serializer_class = AssStationSerializer


# =====================================================================
#  ELEC — Électricité (11 ViewSets)
# =====================================================================

class ElecSupportViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecSupport.objects.all()
    serializer_class = ElecSupportSerializer


class ElecPosteViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecPoste.objects.all()
    serializer_class = ElecPosteSerializer


class ElecCoffretBtViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecCoffretBt.objects.all()
    serializer_class = ElecCoffretBtSerializer


class ElecNoeudRaccordViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecNoeudRaccord.objects.all()
    serializer_class = ElecNoeudRaccordSerializer


class ElecPointDesserteViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecPointDesserte.objects.all()
    serializer_class = ElecPointDesserteSerializer


class ElecTransformateurViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecTransformateur.objects.all()
    serializer_class = ElecTransformateurSerializer


class ElecCelluleViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecCellule.objects.all()
    serializer_class = ElecCelluleSerializer


class ElecDepartBtViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecDepartBt.objects.all()
    serializer_class = ElecDepartBtSerializer


class ElecDepartHtaViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecDepartHta.objects.all()
    serializer_class = ElecDepartHtaSerializer


class ElecTronconBtViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecTronconBt.objects.all()
    serializer_class = ElecTronconBtSerializer


class ElecTronconHtaViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ElecTronconHta.objects.all()
    serializer_class = ElecTronconHtaSerializer
