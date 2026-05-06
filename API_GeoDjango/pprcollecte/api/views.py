"""
Vues API pour SRM Collecte.

Le contexte applicatif est porte par utilisateur, zone et synchronisation.
Le login verifie le mot de passe hashe via Django.
"""

import datetime
import hashlib
import os
import re
from pathlib import Path

from django.conf import settings
from django.core.serializers.json import DjangoJSONEncoder
from django.contrib.gis.geos import LineString, Point
from django.db import connection, transaction
from django.http import JsonResponse, HttpResponse, StreamingHttpResponse
from django.urls import reverse
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
from psycopg2 import sql as pg_sql
try:
    from PIL import Image, ExifTags
except ImportError:  # pragma: no cover - depends on runtime env
    Image = None
    ExifTags = None

from .models import (
    Utilisateur, Commune, Zone, ZoneUtilisateur,
    HistoriqueAction, ObjetIncomplet, ObjetPhoto,
    InterventionAnomalie,
    SyncSession, SyncSessionItem, SyncSessionAttachment,
    EpStatistiqueConduite, EpStatistiqueConduiteSegment,
    AssStatistiqueConduite, AssStatistiqueConduiteSegment,
    SrmFieldOption, ListeChoix,
    MetricAgentJour, MetricAgentSemaine, MetricAgentMois,
    MetricAgentTablePeriod, MetricAgentPeriod, MetricAgentResume,
    MetricAgentPublicJour, MetricAgentPublicSemaine, MetricAgentPublicMois, MetricAgentPublicResume,
    EpVanne, EpVanneDeVidange, EpVentouse, EpHydrant,
    EpBorneFontaine, EpBorneOnep, EpBoucheCles, EpBoucheDarrosage,
    EpCompteurAbonne, EpCompteurReseau, EpConeDeReduction, EpCentreTampon,
    EpNoeud, EpObturateur, EpReducteurDePression,
    EpForage, EpPuit, EpPompe, EpReservoir, EpStationDePompage,
    EpRegard, EpRegardMiroir, EpRegardEp, EpAutreObjet,
    EpConduiteTerrain, EpConduiteBureau, EpBranchement, EpTraverse,
    AssRegard, AssRegardBranchement, AssCanalisation, AssCanalisationReutilisation,
    AssBranchement, AssBassin, AssOuvrage, AssEquipement, AssStation,
    ElecSupport, ElecPoste, ElecCoffretBt, ElecNoeudRaccord, ElecPointDesserte,
    ElecTransformateur, ElecCellule, ElecDepartBt, ElecDepartHta,
    ElecTronconBt, ElecTronconHta,
)
from .serializers import (
    CommuneSerializer,
    ZoneSerializer, ZoneUtilisateurSerializer,
    HistoriqueActionSerializer,
    ObjetIncompletSerializer,
    InterventionAnomalieTerrainSerializer,
    SrmFieldOptionSerializer, ListeChoixAsFieldOptionSerializer, ObjetPhotoSerializer,
    MetricAgentJourSerializer, MetricAgentSemaineSerializer, MetricAgentMoisSerializer,
    MetricAgentTablePeriodSerializer, MetricAgentPeriodSerializer, MetricAgentResumeSerializer,
    MetricAgentPublicJourSerializer, MetricAgentPublicSemaineSerializer,
    MetricAgentPublicMoisSerializer, MetricAgentPublicResumeSerializer,
    EpVanneSerializer, EpVanneDeVidangeSerializer, EpVentouseSerializer,
    EpHydrantSerializer, EpBorneFontaineSerializer, EpBorneOnepSerializer,
    EpBoucheClesSerializer, EpBoucheDarrosageSerializer,
    EpCompteurAbonneSerializer, EpCompteurReseauSerializer,
    EpConeDeReductionSerializer, EpCentreTamponSerializer,
    EpNoeudSerializer, EpObturateurSerializer, EpReducteurDePressionSerializer,
    EpForageSerializer, EpPuitSerializer, EpPompeSerializer,
    EpReservoirSerializer, EpStationDePompageSerializer,
    EpRegardSerializer, EpRegardMiroirSerializer, EpRegardEpSerializer, EpAutreObjetSerializer,
    EpConduiteTerrainSerializer, EpConduiteBureauSerializer,
    EpBranchementSerializer, EpTraverseSerializer,
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
    StatistiqueConduiteValidateSerializer,
)


MOBILE_SRM_TABLE_ENDPOINTS = {
    # EP - mobile endpoints kept stable, physical tables follow SRM_bureau.
    'ep/vannes': ('ep', 'ep_vanne'),
    'ep/vannes-vidange': ('ep', 'ep_vidange'),
    'ep/ventouses': ('ep', 'ep_ventouse'),
    'ep/hydrants': ('ep', 'ep_hydrant'),
    'ep/bornes-fontaine': ('ep', 'ep_bf'),
    'ep/bornes-onep': ('ep', 'borne_onep'),
    'ep/bouches-cles': ('ep', 'bouche_a_cles'),
    'ep/bouches-arrosage': ('ep', 'ep_bouche_arro'),
    'ep/compteurs-abonne': ('ep', 'ep_compteur_i'),
    'ep/compteurs-reseau': None,
    'ep/cones-reduction': ('ep', 'ep_cone_reduc'),
    'ep/centres-tampon': ('ep', 'centre_tampon'),
    'ep/noeuds': ('ep', 'ep_noeud'),
    'ep/obturateurs': ('ep', 'ep_obturateur'),
    'ep/reducteurs-pression': ('ep', 'ep_reduc_pres'),
    'ep/forages': ('ep', 'ep_forage'),
    'ep/puits': ('ep', 'ep_puit'),
    'ep/pompes': ('ep', 'ep_pompe'),
    'ep/reservoirs': ('ep', 'ep_reservoir'),
    'ep/stations-pompage': ('ep', 'ep_station_pompage'),
    'ep/regards': ('ep', 'ep_regard_point'),
    'ep/regards-miroir': ('ep', 'ep_regard'),
    'ep/autres-objets': ('ep', 'autre_objet'),
    'ep/conduites-terrain': ('ep', 'conduite_terrain'),
    'ep/conduites-bureau': ('ep', 'ep_conduite'),
    'ep/branchements': ('ep', 'ep_branchement'),
    'ep/traverses': ('ep', 'ep_traversee'),
    # ASS - endpoints kept stable, physical schema/table names follow VF legacy.
    'ass/regards': ('asst', 'ASS_REGARD'),
    'ass/regards-facade': ('asst', 'ASS_REGARD_FACADE'),
    'ass/regards-borgnes': ('asst', 'ASS_BORGNE'),
    'ass/regards-branchement': ('asst', 'ASS_REGARD_FACADE'),
    'ass/bouches': ('asst', 'ASS_BOUCHE'),
    'ass/deversoirs': ('asst', 'ASS_DEVERSOIR'),
    'ass/exutoires': ('asst', 'ASS__EXUTOIRE'),
    'ass/stations-pompage': ('asst', 'ASS_STA_POMP'),
    'ass/collecteurs': ('asst', 'ASS_COLLECTEUR'),
    'ass/canalisations': ('asst', 'ASS_COLLECTEUR'),
    'ass/canalisations-reutilisation': ('asst', 'ASS_REFOULEMENTR'),
    'ass/branchements': ('asst', 'ASS_BRANCHEMENT'),
    'ass/caniveaux': ('asst', 'ASS_CANIVEAU'),
    'ass/caniveaux-branchement': ('asst', 'ASS_CANIV_BRANCHE'),
    'ass/collecteurs-bouche': ('asst', 'ASS_COL_BOUCHE'),
    'ass/bassins-versants': ('asst', 'ASS_BASSIN_VERSANT'),
    'ass/bassins': ('asst', 'ASS_BASSIN_VERSANT'),
    'ass/stations-epuration': ('asst', 'ASS_STA_EPUR'),
    'ass/ouvrages': ('asst', 'ASS_OUV_TRAVERSEE'),
    'ass/equipements': ('asst', 'ASS_POMPE'),
    'ass/stations': ('asst', 'ASS_STA_POMP'),
}


MOBILE_OUTPUT_ALIASES = {
    'ep_ref_rue': 'ref_rue',
    'ep_observation': 'observation',
    'ep_conf_plan': 'conformite_plan',
    'ep_anomalie': 'anomalie',
    'ep_long_r': 'ep_longueur',
    'ep_etat_s': 'ep_etat',
    'id_user_creat': 'id_agent_crea',
    'updated_at': 'date_sync',
    'ASS_CONF_PLAN': 'conformite_plan',
    'ASS_OBSERV': 'observation',
    'ASS_ANOMALIE': 'anomalie',
    'ASS_DATE_INTERV': 'date_leve',
    'ASS_AGENT_CREA': 'id_agent_crea',
    'MODE_LOCALISATION': 'mode_localisation',
    'ASS_COOR_X': 'ass_coor_x',
    'ASS_COOR_Y': 'ass_coor_y',
    'ASS_COOR_Z': 'ass_coor_z',
    'ASS_TYPE_RESEAU': 'typereseau',
    'ASS_STATUT': 'etat',
    'ASS_DIAM': 'diametre',
    'ASS_MAT': 'nature',
    'ASS_LONG_R': 'longueur',
}


MOBILE_INPUT_ALIASES = {
    'ref_rue': 'ep_ref_rue',
    'observation': ('ep_observation', 'ASS_OBSERV'),
    'conformite_plan': ('ep_conf_plan', 'ASS_CONF_PLAN'),
    'anomalie': ('ep_anomalie', 'ASS_ANOMALIE'),
    'ep_longueur': 'ep_long_r',
    'ep_etat': 'ep_etat_s',
    'id_agent_crea': ('id_user_creat', 'ASS_AGENT_CREA'),
    'mode_localisation': 'MODE_LOCALISATION',
    'ass_coor_x': 'ASS_COOR_X',
    'ass_coor_y': 'ASS_COOR_Y',
    'ass_coor_z': 'ASS_COOR_Z',
    'etat': 'ASS_STATUT',
    'type_regard': 'ASS_TYPE',
    'type_tampon': 'ASS_TAMPON',
    'type_conduite': 'ASS_TYPE',
    'typereseau': 'ASS_TYPE_RESEAU',
    'emplacement': 'EMPLACEMENT',
    'diametre': 'ASS_DIAM',
    'nature': 'ASS_MAT',
    'longueur': 'ASS_LONG_R',
    'reference': 'ASS_REFERENCE',
}


def _mobile_empty_page(request, page_size=500, page=1):
    return JsonResponse(
        {
            'count': 0,
            'next': None,
            'previous': None,
            'page': page,
            'page_size': page_size,
            'results': [],
        },
        encoder=DjangoJSONEncoder,
    )


def _mobile_table_columns(schema_name, table_name):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position
            """,
            [schema_name, table_name],
        )
        return [row[0] for row in cursor.fetchall()]


def _mobile_pk_column(columns):
    for candidate in ('fid', 'id', 'gid'):
        if candidate in columns:
            return candidate
    return columns[0] if columns else None


def _mobile_timestamp_filter_column(columns):
    for candidate in (
        'updated_at',
        'date_sync',
        'date_modif',
        'date_leve',
        'date_creation',
        'created_at',
    ):
        if candidate in columns:
            return candidate
    return None


def _mobile_apply_output_aliases(row):
    for source, target in MOBILE_OUTPUT_ALIASES.items():
        if source in row and target not in row:
            row[target] = row[source]
    return row


def _mobile_apply_input_aliases(payload, columns):
    values = dict(payload)
    for source, targets in MOBILE_INPUT_ALIASES.items():
        if not isinstance(targets, (list, tuple)):
            targets = (targets,)
        for target in targets:
            if source in values and target in columns and target not in values:
                values[target] = values[source]
    return values


def _table_foreign_keys(schema_name, table_name):
    """Liste les FK de la table cible : (col_locale, schema_ref, table_ref, col_ref)."""
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                kcu.column_name,
                ccu.table_schema,
                ccu.table_name,
                ccu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu
                ON tc.constraint_schema = kcu.constraint_schema
               AND tc.constraint_name = kcu.constraint_name
            JOIN information_schema.constraint_column_usage ccu
                ON tc.constraint_schema = ccu.constraint_schema
               AND tc.constraint_name = ccu.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
              AND tc.table_schema = %s
              AND tc.table_name = %s
            """,
            [schema_name, table_name],
        )
        return cursor.fetchall()


def _neutralize_invalid_fk_values(*, schema_name, table_name, writable):
    """Met a NULL toute valeur FK qui ne correspond plus a aucune ligne cible.

    Retourne la liste des colonnes neutralisees (pour traçage). Le serveur
    reste tolerant aux desynchros entre l'id local du mobile et les
    referentiels (commune_oriental, planche, agent...) sans planter en 500.
    """
    neutralized = []
    fks = _table_foreign_keys(schema_name, table_name)
    if not fks:
        return neutralized

    with connection.cursor() as cursor:
        for local_col, ref_schema, ref_table, ref_col in fks:
            if local_col not in writable:
                continue
            value = writable.get(local_col)
            if value in (None, ''):
                continue
            check_query = pg_sql.SQL(
                'SELECT 1 FROM {}.{} WHERE {} = %s LIMIT 1'
            ).format(
                pg_sql.Identifier(ref_schema),
                pg_sql.Identifier(ref_table),
                pg_sql.Identifier(ref_col),
            )
            try:
                cursor.execute(check_query, [value])
            except Exception:
                # Type mismatch (ex: int vs uuid) : on neutralise par securite.
                writable[local_col] = None
                neutralized.append(local_col)
                continue
            if cursor.fetchone() is None:
                writable[local_col] = None
                neutralized.append(local_col)

    return neutralized


def _mobile_select_parts(columns):
    parts = []
    for column in columns:
        if column == 'geom':
            parts.append(
                pg_sql.SQL('ST_AsGeoJSON({}) AS {}').format(
                    pg_sql.Identifier(column),
                    pg_sql.Identifier('geometry_geojson'),
                )
            )
        else:
            parts.append(pg_sql.Identifier(column))
    return parts


def _mobile_next_previous_urls(request, count, page, page_size):
    total_pages = (count + page_size - 1) // page_size if page_size else 1

    def build_url(target_page):
        query = request.GET.copy()
        query['page'] = str(target_page)
        query['page_size'] = str(page_size)
        return request.build_absolute_uri(f'{request.path}?{query.urlencode()}')

    next_url = build_url(page + 1) if page < total_pages else None
    previous_url = build_url(page - 1) if page > 1 and total_pages else None
    return next_url, previous_url


def _mobile_fetch_row(schema_name, table_name, columns, pk_column, pk_value):
    qualified = pg_sql.SQL('{}.{}').format(
        pg_sql.Identifier(schema_name),
        pg_sql.Identifier(table_name),
    )
    query = pg_sql.SQL('SELECT {} FROM {} WHERE {} = %s LIMIT 1').format(
        pg_sql.SQL(', ').join(_mobile_select_parts(columns)),
        qualified,
        pg_sql.Identifier(pk_column),
    )
    with connection.cursor() as cursor:
        cursor.execute(query, [pk_value])
        row = cursor.fetchone()
        if row is None:
            return None
        names = [desc[0] for desc in cursor.description]
    return _mobile_apply_output_aliases(dict(zip(names, row)))


@api_view(['GET', 'POST'])
def mobile_srm_table_view(request, endpoint):
    table_ref = MOBILE_SRM_TABLE_ENDPOINTS.get(endpoint)
    page_size = max(1, min(int(request.GET.get('page_size') or 500), 2000))
    page = max(1, int(request.GET.get('page') or 1))

    if table_ref is None:
        if request.method == 'GET':
            return _mobile_empty_page(request, page_size=page_size, page=page)
        return Response(
            {
                'detail': (
                    'Endpoint mobile sans table serveur active. '
                    'Aucune donnee n a ete ecrite.'
                )
            },
            status=status.HTTP_409_CONFLICT,
        )

    schema_name, table_name = table_ref
    columns = _mobile_table_columns(schema_name, table_name)
    if not columns:
        if request.method == 'GET':
            return _mobile_empty_page(request, page_size=page_size, page=page)
        return Response(
            {'detail': f'Table serveur introuvable: {schema_name}.{table_name}'},
            status=status.HTTP_404_NOT_FOUND,
        )

    pk_column = _mobile_pk_column(columns)
    qualified = pg_sql.SQL('{}.{}').format(
        pg_sql.Identifier(schema_name),
        pg_sql.Identifier(table_name),
    )

    if request.method == 'GET':
        where_parts = []
        params = []
        updated_after = request.GET.get('updated_after') or request.GET.get('since')
        filter_column = _mobile_timestamp_filter_column(columns)
        parsed_updated_after = parse_datetime(updated_after) if updated_after else None
        if parsed_updated_after is not None and filter_column:
            where_parts.append(
                pg_sql.SQL('{} >= %s').format(pg_sql.Identifier(filter_column))
            )
            params.append(parsed_updated_after)

        # Exclure les objets sans geometrie : ils sont inutilisables cote
        # mobile (impossibles a placer sur la carte) et viennent surtout
        # d'anciennes syncs cassees ou il manquait le geometry_geojson.
        # Les lignes restent en BDD pour analyse admin.
        if 'geom' in columns:
            where_parts.append(pg_sql.SQL('geom IS NOT NULL'))

        where_sql = (
            pg_sql.SQL(' WHERE ') + pg_sql.SQL(' AND ').join(where_parts)
            if where_parts
            else pg_sql.SQL('')
        )
        order_column = pg_sql.Identifier(pk_column) if pk_column else pg_sql.SQL('1')

        with connection.cursor() as cursor:
            count_query = pg_sql.SQL('SELECT COUNT(*) FROM {}{}').format(
                qualified,
                where_sql,
            )
            cursor.execute(count_query, params)
            count = cursor.fetchone()[0]

            offset = (page - 1) * page_size
            select_query = pg_sql.SQL(
                'SELECT {} FROM {}{} ORDER BY {} LIMIT %s OFFSET %s'
            ).format(
                pg_sql.SQL(', ').join(_mobile_select_parts(columns)),
                qualified,
                where_sql,
                order_column,
            )
            cursor.execute(select_query, [*params, page_size, offset])
            names = [desc[0] for desc in cursor.description]
            results = [
                _mobile_apply_output_aliases(dict(zip(names, row)))
                for row in cursor.fetchall()
            ]

        next_url, previous_url = _mobile_next_previous_urls(request, count, page, page_size)
        return JsonResponse(
            {
                'count': count,
                'next': next_url,
                'previous': previous_url,
                'page': page,
                'page_size': page_size,
                'results': results,
            },
            encoder=DjangoJSONEncoder,
        )

    payload = _mobile_apply_input_aliases(request.data, columns)
    if 'geometry_geojson' in payload and 'geom' in columns:
        payload['geom'] = payload.get('geometry_geojson')

    writable = {
        key: value
        for key, value in payload.items()
        if key in columns and key not in {pk_column, 'geometry_geojson'}
    }
    if not writable:
        return Response(
            {'detail': 'Aucun champ compatible avec la table serveur.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    geometry_value = writable.pop('geom', None)

    # Defense FK : un id local (commune, planche, agent...) qui n'existe pas
    # dans la table referencee fait planter l'INSERT avec IntegrityError.
    # Plutot que de retourner 500, on neutralise la valeur (NULL) et on
    # poursuit. Le mobile recommencera la sync apres avoir resyncronise
    # les referentiels (commune_oriental, etc.).
    fk_columns_neutralized = _neutralize_invalid_fk_values(
        schema_name=schema_name,
        table_name=table_name,
        writable=writable,
    )
    existing_pk = None
    if payload.get('uuid') and 'uuid' in columns:
        query = pg_sql.SQL('SELECT {} FROM {} WHERE uuid = %s LIMIT 1').format(
            pg_sql.Identifier(pk_column),
            qualified,
        )
        with connection.cursor() as cursor:
            cursor.execute(query, [payload.get('uuid')])
            existing = cursor.fetchone()
            existing_pk = existing[0] if existing else None

    with transaction.atomic():
        with connection.cursor() as cursor:
            if existing_pk is not None:
                assignments = [
                    pg_sql.SQL('{} = %s').format(pg_sql.Identifier(column))
                    for column in writable
                ]
                params = list(writable.values())
                if geometry_value is not None:
                    assignments.append(
                        pg_sql.SQL(
                            '{} = ST_SetSRID(ST_GeomFromGeoJSON(%s), 26191)'
                        ).format(pg_sql.Identifier('geom'))
                    )
                    params.append(geometry_value)
                params.append(existing_pk)
                update_query = pg_sql.SQL(
                    'UPDATE {} SET {} WHERE {} = %s RETURNING {}'
                ).format(
                    qualified,
                    pg_sql.SQL(', ').join(assignments),
                    pg_sql.Identifier(pk_column),
                    pg_sql.Identifier(pk_column),
                )
                cursor.execute(update_query, params)
                pk_value = cursor.fetchone()[0]
            else:
                insert_columns = [pg_sql.Identifier(column) for column in writable]
                placeholders = [pg_sql.SQL('%s') for _ in writable]
                params = list(writable.values())
                if geometry_value is not None:
                    insert_columns.append(pg_sql.Identifier('geom'))
                    placeholders.append(
                        pg_sql.SQL('ST_SetSRID(ST_GeomFromGeoJSON(%s), 26191)')
                    )
                    params.append(geometry_value)

                insert_query = pg_sql.SQL(
                    'INSERT INTO {} ({}) VALUES ({}) RETURNING {}'
                ).format(
                    qualified,
                    pg_sql.SQL(', ').join(insert_columns),
                    pg_sql.SQL(', ').join(placeholders),
                    pg_sql.Identifier(pk_column),
                )
                cursor.execute(insert_query, params)
                pk_value = cursor.fetchone()[0]

    row = _mobile_fetch_row(schema_name, table_name, columns, pk_column, pk_value)
    return Response(row or {'id': pk_value}, status=status.HTTP_201_CREATED)


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


_OBJET_PHOTO_SCHEMA_READY = False


def _ensure_objet_photo_schema():
    """Keep development databases aligned with the current photo model."""
    global _OBJET_PHOTO_SCHEMA_READY
    if _OBJET_PHOTO_SCHEMA_READY:
        return

    with connection.cursor() as cursor:
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS public.objet_photo (
                id_photo BIGSERIAL PRIMARY KEY,
                uuid_objet VARCHAR(254) NOT NULL,
                nom_schema VARCHAR(20) NOT NULL,
                nom_table VARCHAR(100) NOT NULL,
                num_photo SMALLINT NOT NULL,
                nom_fichier VARCHAR(255) NOT NULL,
                chemin_relatif TEXT NOT NULL,
                hash_sha256 CHAR(64),
                mime_type VARCHAR(100),
                taille_octets BIGINT,
                id_agent_crea INTEGER,
                date_upload TIMESTAMPTZ NOT NULL DEFAULT now(),
                actif BOOLEAN NOT NULL DEFAULT true,
                date_prise_reelle TIMESTAMPTZ
            )
            """
        )
        cursor.execute(
            """
            ALTER TABLE public.objet_photo
                ADD COLUMN IF NOT EXISTS date_prise_reelle timestamptz,
                ADD COLUMN IF NOT EXISTS date_upload timestamptz
            """
        )
        cursor.execute(
            """
            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_constraint
                    WHERE conname = 'objet_photo_num_photo_check'
                ) THEN
                    ALTER TABLE public.objet_photo
                        ADD CONSTRAINT objet_photo_num_photo_check
                        CHECK (num_photo BETWEEN 1 AND 4);
                END IF;
            END $$;
            """
        )
        cursor.execute(
            """
            CREATE UNIQUE INDEX IF NOT EXISTS
                objet_photo_nom_schema_nom_table_uuid_objet_num_photo_key
                ON public.objet_photo (
                    nom_schema,
                    nom_table,
                    uuid_objet,
                    num_photo
                )
            """
        )
        cursor.execute(
            """
            CREATE INDEX IF NOT EXISTS objet_photo_schema_table_uuid_idx
                ON public.objet_photo (nom_schema, nom_table, uuid_objet)
            """
        )
        cursor.execute(
            """
            CREATE INDEX IF NOT EXISTS objet_photo_uuid_objet_idx
                ON public.objet_photo (uuid_objet)
            """
        )
        cursor.execute(
            """
            CREATE INDEX IF NOT EXISTS objet_photo_date_prise_reelle_idx
                ON public.objet_photo (date_prise_reelle DESC)
                WHERE date_prise_reelle IS NOT NULL
            """
        )
        cursor.execute(
            """
            CREATE INDEX IF NOT EXISTS objet_photo_date_upload_idx
                ON public.objet_photo (date_upload DESC)
                WHERE date_upload IS NOT NULL
            """
        )

    _OBJET_PHOTO_SCHEMA_READY = True


def _resolve_conduite_regard_node(node_payload):
    fid = node_payload.get('fid')
    uuid_value = (node_payload.get('uuid') or '').strip()
    ep_num = (node_payload.get('ep_num') or '').strip()

    if fid is not None:
        try:
            regard = EpRegard.objects.get(fid=fid)
        except EpRegard.DoesNotExist as exc:
            raise ValidationError(
                {
                    'nodes': [
                        f'Regard introuvable sur le serveur pour fid={fid}.'
                    ]
                }
            ) from exc
        if regard.geom is None:
            x = regard.ep_coor_x
            y = regard.ep_coor_y
            z = regard.ep_coor_z
            if x is not None and y is not None:
                regard.geom = Point(
                    float(x),
                    float(y),
                    float(z if z is not None else 0.0),
                    srid=26191,
                )
            else:
                raise ValidationError(
                    {'nodes': [f'Regard fid={fid} sans gÃ©omÃ©trie exploitable.']}
                )
        return regard

    if uuid_value:
        qs = EpRegard.objects.filter(uuid=uuid_value)
        count = qs.count()
        if count == 0:
            label = ep_num or uuid_value
            raise ValidationError(
                {
                    'nodes': [
                        f'Regard {label} absent du serveur. Synchronisez les regards du jour avant validation.'
                    ]
                }
            )
        if count > 1:
            raise ValidationError(
                {
                    'nodes': [
                        f'UUID de regard ambigu sur le serveur: {uuid_value}.'
                    ]
                }
            )
        regard = qs.first()
        if regard is None:
            raise ValidationError(
                {
                    'nodes': [
                        f'Regard {ep_num or uuid_value} introuvable.'
                    ]
                }
            )
        if regard.geom is None:
            x = regard.ep_coor_x
            y = regard.ep_coor_y
            z = regard.ep_coor_z
            if x is not None and y is not None:
                regard.geom = Point(
                    float(x),
                    float(y),
                    float(z if z is not None else 0.0),
                    srid=26191,
                )
            else:
                raise ValidationError(
                    {
                        'nodes': [
                            f'Regard {ep_num or uuid_value} sans gÃ©omÃ©trie exploitable.'
                        ]
                    }
                )
        return regard

    raise ValidationError(
        {'nodes': ['Chaque regard doit fournir fid ou uuid pour la validation.']}
    )


def _build_unique_conduite_segments(regard_nodes):
    unique_segments = []
    seen_pairs = set()
    previous = None

    for current in regard_nodes:
        if current is None:
            previous = None
            continue

        if previous is None:
            previous = current
            continue

        left = previous
        right = current
        if left.fid == right.fid:
            previous = current
            continue

        pair_key = tuple(sorted((left.fid, right.fid)))
        if pair_key in seen_pairs:
            previous = current
            continue

        line = LineString(left.geom.coords, right.geom.coords, srid=26191)
        unique_segments.append(
            {
                'fid_regard_a': left.fid,
                'fid_regard_b': right.fid,
                'geom': line,
            }
        )
        seen_pairs.add(pair_key)
        previous = current

    return unique_segments


def _segment_geom_to_wgs84_points(geom):
    if geom is None:
        return []

    transformed = geom.clone()
    transformed.transform(4326)
    return [
        {'lat': float(coord[1]), 'lng': float(coord[0])}
        for coord in transformed.coords
    ]


_CONDUITE_METIER_CONFIG = {
    'ep': {
        'label': 'EP',
        'regard_model': EpRegard,
        'stat_model': EpStatistiqueConduite,
        'segment_model': EpStatistiqueConduiteSegment,
        'schema': 'ep',
        'stat_table': 'statistique_conduite',
        'segment_table': 'statistique_conduite_segment',
        'coord_fields': ('ep_coor_x', 'ep_coor_y', 'ep_coor_z'),
        'sync_schema': 'ep',
        'sync_table': 'statistique_conduite',
        'ensure_tables': True,
    },
    'asst': {
        'label': 'ASS',
        'regard_model': AssRegard,
        'stat_model': AssStatistiqueConduite,
        'segment_model': AssStatistiqueConduiteSegment,
        'schema': 'asst',
        'stat_table': 'statistique_conduite',
        'segment_table': 'statistique_conduite_segment',
        'coord_fields': ('ass_coor_x', 'ass_coor_y', 'ass_coor_z'),
        'sync_schema': 'asst',
        'sync_table': 'statistique_conduite',
        'ensure_tables': False,
    },
}


def _normalize_conduite_metier(raw_metier, *, default='ep'):
    value = str(raw_metier or '').strip().lower()
    if value in ('ep', 'eau_potable', 'eau potable'):
        return 'ep'
    if value in ('asst', 'ass', 'assainissement'):
        return 'asst'
    if value == '':
        return default
    raise ValidationError({'metier': [f'Metier conduite non supporte: {raw_metier}.']})


def _conduite_config(raw_metier=None, *, default='ep'):
    key = _normalize_conduite_metier(raw_metier, default=default)
    config = _CONDUITE_METIER_CONFIG[key]
    if config.get('ensure_tables'):
        _ensure_conduite_stat_tables(config)
    return key, config


def _ensure_conduite_stat_tables(config):
    schema = config['schema']
    stat_table = config['stat_table']
    segment_table = config['segment_table']
    with connection.cursor() as cursor:
        cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")
        cursor.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {schema}.{stat_table} (
                id_statistique_conduite BIGSERIAL PRIMARY KEY,
                id_agent INTEGER NOT NULL
                    REFERENCES public.utilisateur(id_user)
                    ON DELETE RESTRICT,
                jour DATE NOT NULL,
                geom geometry(MultiLineStringZ,26191),
                longueur_conduite_m DOUBLE PRECISION NOT NULL DEFAULT 0,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                CONSTRAINT {stat_table}_agent_jour_key UNIQUE (id_agent, jour),
                CONSTRAINT {stat_table}_longueur_chk CHECK (longueur_conduite_m >= 0)
            )
            """
        )
        cursor.execute(
            f"""
            CREATE TABLE IF NOT EXISTS {schema}.{segment_table} (
                id_statistique_conduite_segment BIGSERIAL PRIMARY KEY,
                id_statistique_conduite BIGINT NOT NULL
                    REFERENCES {schema}.{stat_table}(id_statistique_conduite)
                    ON DELETE CASCADE,
                fid_regard_a INTEGER NOT NULL,
                fid_regard_b INTEGER NOT NULL,
                fid_regard_min INTEGER GENERATED ALWAYS AS (
                    LEAST(fid_regard_a, fid_regard_b)
                ) STORED,
                fid_regard_max INTEGER GENERATED ALWAYS AS (
                    GREATEST(fid_regard_a, fid_regard_b)
                ) STORED,
                geom geometry(LineStringZ,26191) NOT NULL,
                longueur_segment_m DOUBLE PRECISION NOT NULL DEFAULT 0,
                created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                CONSTRAINT {segment_table}_no_loop_chk CHECK (fid_regard_a <> fid_regard_b),
                CONSTRAINT {segment_table}_longueur_chk CHECK (longueur_segment_m >= 0),
                CONSTRAINT {segment_table}_unique_pair_key UNIQUE (
                    id_statistique_conduite,
                    fid_regard_min,
                    fid_regard_max
                )
            )
            """
        )
        cursor.execute(
            f"""
            CREATE INDEX IF NOT EXISTS {stat_table}_agent_idx
                ON {schema}.{stat_table} (id_agent, jour DESC)
            """
        )
        cursor.execute(
            f"""
            CREATE INDEX IF NOT EXISTS {stat_table}_jour_idx
                ON {schema}.{stat_table} (jour DESC)
            """
        )
        cursor.execute(
            f"""
            CREATE INDEX IF NOT EXISTS {stat_table}_geom_gix
                ON {schema}.{stat_table} USING GIST (geom)
            """
        )
        cursor.execute(
            f"""
            CREATE INDEX IF NOT EXISTS {segment_table}_parent_idx
                ON {schema}.{segment_table} (id_statistique_conduite)
            """
        )
        cursor.execute(
            f"""
            CREATE INDEX IF NOT EXISTS {segment_table}_regard_a_idx
                ON {schema}.{segment_table} (fid_regard_a)
            """
        )
        cursor.execute(
            f"""
            CREATE INDEX IF NOT EXISTS {segment_table}_regard_b_idx
                ON {schema}.{segment_table} (fid_regard_b)
            """
        )
        cursor.execute(
            f"""
            CREATE INDEX IF NOT EXISTS {segment_table}_geom_gix
                ON {schema}.{segment_table} USING GIST (geom)
            """
        )


def _coerce_conduite_node_point(node_payload, config, label):
    x_field, y_field, z_field = config['coord_fields']
    x = node_payload.get('x')
    y = node_payload.get('y')
    z = node_payload.get('z')
    if x is None:
        x = node_payload.get(x_field)
    if y is None:
        y = node_payload.get(y_field)
    if z is None:
        z = node_payload.get(z_field)

    if x is None or y is None:
        raise ValidationError(
            {'nodes': [f'Regard {label} sans geometrie exploitable.']}
        )

    return Point(float(x), float(y), float(z if z is not None else 0.0), srid=26191)


def _resolve_conduite_regard_node(node_payload, config):
    fid = node_payload.get('fid')
    uuid_value = (node_payload.get('uuid') or '').strip()
    label = (
        (node_payload.get('label') or '').strip()
        or (node_payload.get('ep_num') or '').strip()
        or uuid_value
        or str(fid or '')
    )
    regard_model = config['regard_model']
    x_field, y_field, z_field = config['coord_fields']

    if fid is not None:
        try:
            regard = regard_model.objects.get(fid=fid)
        except regard_model.DoesNotExist as exc:
            raise ValidationError(
                {'nodes': [f'Regard introuvable sur le serveur pour fid={fid}.']}
            ) from exc
        if regard.geom is None:
            x = getattr(regard, x_field, None)
            y = getattr(regard, y_field, None)
            z = getattr(regard, z_field, None)
            if x is not None and y is not None:
                regard.geom = Point(
                    float(x),
                    float(y),
                    float(z if z is not None else 0.0),
                    srid=26191,
                )
            else:
                regard.geom = _coerce_conduite_node_point(node_payload, config, fid)
        return regard

    if uuid_value:
        qs = regard_model.objects.filter(uuid=uuid_value)
        count = qs.count()
        if count == 0:
            raise ValidationError(
                {
                    'nodes': [
                        f'Regard {label} absent du serveur. Synchronisez les regards du jour avant validation.'
                    ]
                }
            )
        if count > 1:
            raise ValidationError(
                {'nodes': [f'UUID de regard ambigu sur le serveur: {uuid_value}.']}
            )
        regard = qs.first()
        if regard is None:
            raise ValidationError({'nodes': [f'Regard {label} introuvable.']})
        if regard.geom is None:
            x = getattr(regard, x_field, None)
            y = getattr(regard, y_field, None)
            z = getattr(regard, z_field, None)
            if x is not None and y is not None:
                regard.geom = Point(
                    float(x),
                    float(y),
                    float(z if z is not None else 0.0),
                    srid=26191,
                )
            else:
                regard.geom = _coerce_conduite_node_point(node_payload, config, label)
        return regard

    raise ValidationError(
        {'nodes': ['Chaque regard doit fournir fid ou uuid pour la validation.']}
    )


def _insert_statistique_conduite_segments(
    config,
    id_statistique_conduite,
    unique_segments,
    now,
):
    if not unique_segments:
        return

    rows = [
        (
            id_statistique_conduite,
            segment['fid_regard_a'],
            segment['fid_regard_b'],
            segment['geom'].ewkt,
            0.0,
            now,
            now,
        )
        for segment in unique_segments
    ]

    schema = config['schema']
    segment_table = config['segment_table']
    stat_table = config['stat_table']
    with connection.cursor() as cursor:
        cursor.executemany(
            f"""
            INSERT INTO {schema}.{segment_table} (
                id_statistique_conduite,
                fid_regard_a,
                fid_regard_b,
                geom,
                longueur_segment_m,
                created_at,
                updated_at
            )
            VALUES (
                %s,
                %s,
                %s,
                ST_GeomFromEWKT(%s),
                %s,
                %s,
                %s
            )
            """,
            rows,
        )
        cursor.execute(
            f"""
            UPDATE {schema}.{segment_table}
               SET longueur_segment_m = ST_Length(geom),
                   updated_at = %s
             WHERE id_statistique_conduite = %s
            """,
            [now, id_statistique_conduite],
        )
        cursor.execute(
            f"""
            UPDATE {schema}.{stat_table}
               SET geom = sub.geom,
                   longueur_conduite_m = sub.longueur,
                   updated_at = %s
              FROM (
                    SELECT
                        ST_Multi(ST_Collect(geom))::geometry(MultiLineStringZ,26191) AS geom,
                        COALESCE(SUM(longueur_segment_m), 0.0) AS longueur
                      FROM {schema}.{segment_table}
                     WHERE id_statistique_conduite = %s
              ) AS sub
             WHERE id_statistique_conduite = %s
            """,
            [now, id_statistique_conduite, id_statistique_conduite],
        )


def _statistique_conduite_snapshot(stat_row, config=None, metier_key='ep'):
    config = config or _CONDUITE_METIER_CONFIG['ep']
    segment_qs = config['segment_model'].objects.filter(
        id_statistique_conduite=stat_row.id_statistique_conduite
    ).order_by('fid_regard_min', 'fid_regard_max')

    segments_wgs84 = [
        {
            'fid_regard_a': segment.fid_regard_a,
            'fid_regard_b': segment.fid_regard_b,
            'points': _segment_geom_to_wgs84_points(segment.geom),
            'longueur_segment_m': float(segment.longueur_segment_m or 0.0),
        }
        for segment in segment_qs
    ]

    return {
        'exists': True,
        'frozen': True,
        'metier': metier_key,
        'id_statistique_conduite': stat_row.id_statistique_conduite,
        'id_agent': stat_row.id_agent,
        'jour': stat_row.jour.isoformat(),
        'longueur_conduite_m': float(stat_row.longueur_conduite_m or 0.0),
        'segments_count': len(segments_wgs84),
        'segments_wgs84': segments_wgs84,
    }


def _normalized_db_table(model):
    return str(model._meta.db_table).replace('"', '')


def _split_normalized_db_table(model):
    normalized = _normalized_db_table(model)
    if '.' in normalized:
        return normalized.split('.', 1)
    return 'public', normalized


def _is_truthy_anomaly(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value == 1
    if value is None:
        return False
    return str(value).strip().lower() in {'1', 'true', 't', 'yes', 'oui'}


def _first_non_empty_attr(instance, names):
    for name in names:
        value = getattr(instance, name, None)
        if value in (None, ''):
            continue
        text = str(value).strip()
        if text:
            return text
    return ''


def _instance_has_anomaly(instance):
    return any(
        _is_truthy_anomaly(getattr(instance, field_name, None))
        for field_name in ('anomalie', 'ep_anomalie')
    )


def _upsert_intervention_anomalie_from_instance(instance, id_user=None):
    if instance is None or not _instance_has_anomaly(instance):
        return

    schema_name, table_name = _split_normalized_db_table(instance.__class__)
    nom_table = f'{schema_name}.{table_name}'
    id_objet = getattr(instance, instance._meta.pk.attname, None)
    if id_objet is None:
        return

    uuid_objet = getattr(instance, 'uuid', None)
    uuid_text = str(uuid_objet).strip() if uuid_objet not in (None, '') else None
    commentaire = _first_non_empty_attr(
        instance,
        (
            'type_anomalie',
            'anomalie_regard',
            'anomalie_tamp',
            'ep_observation',
            'observation',
            'commentaire',
        ),
    )

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT id
            FROM public.intervention_anomalie
            WHERE nom_table = %s
              AND id_objet = %s
              AND statut NOT IN ('cloture', 'annule')
            ORDER BY id DESC
            LIMIT 1
            """,
            [nom_table, id_objet],
        )
        row = cursor.fetchone()
        if row:
            cursor.execute(
                """
                UPDATE public.intervention_anomalie
                SET uuid_objet = COALESCE(NULLIF(%s, ''), uuid_objet),
                    commentaire_terrain = COALESCE(NULLIF(%s, ''), commentaire_terrain),
                    id_user_terrain = COALESCE(%s, id_user_terrain),
                    updated_at = now()
                WHERE id = %s
                """,
                [uuid_text, commentaire, id_user, row[0]],
            )
            return

        cursor.execute(
            """
            INSERT INTO public.intervention_anomalie (
                id_objet,
                nom_classe,
                nom_table,
                uuid_objet,
                statut,
                responsable_actuel,
                etat_terrain,
                commentaire_terrain,
                id_user_terrain,
                date_creation
            )
            VALUES (
                %s,
                %s,
                %s,
                %s,
                'signale',
                'terrain',
                'en_attente',
                NULLIF(%s, ''),
                %s,
                now()::timestamp
            )
            """,
            [id_objet, table_name, nom_table, uuid_text, commentaire, id_user],
        )


def _set_local_audit_context(user_id=None, source=None, action=None):
    with connection.cursor() as cursor:
        if user_id is not None:
            cursor.execute(
                "SELECT set_config('app.current_user_id', %s, true)",
                [str(user_id)],
            )

        clean_source = str(source or '').strip().lower()
        if clean_source:
            if clean_source in ('application mobile', 'mobile'):
                clean_source = 'mobile'
            elif clean_source in ('application web', 'web', 'bureau', 'backoffice'):
                clean_source = 'bureau'
            cursor.execute(
                "SELECT set_config('app.history_source', %s, true)",
                [clean_source],
            )

        clean_action = str(action or '').strip().lower()
        if clean_action:
            cursor.execute(
                "SELECT set_config('app.history_action', %s, true)",
                [clean_action],
            )


def _set_local_audit_user_id(user_id):
    _set_local_audit_context(user_id=user_id)


_SRM_PHOTO_MODELS = [
    EpVanne, EpVanneDeVidange, EpVentouse, EpHydrant,
    EpBorneFontaine, EpBorneOnep, EpBoucheCles, EpBoucheDarrosage,
    EpCompteurAbonne, EpCompteurReseau, EpConeDeReduction, EpCentreTampon,
    EpNoeud, EpObturateur, EpReducteurDePression,
    EpForage, EpPuit, EpPompe, EpReservoir, EpStationDePompage,
    EpRegard, EpRegardEp, EpAutreObjet,
    EpConduiteTerrain, EpConduiteBureau, EpBranchement, EpTraverse,
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


def _resolve_srm_photo_model(*, schema_name, table_name, endpoint_hint=''):
    """Resout le model SRM pour un upload photo en tolerant les noms locaux mobile.

    Le mobile envoie souvent le `tableName` Flutter (ex: 'hydrant') alors que
    Postgres heberge la table sous un autre nom (ex: 'ep_hydrant', voire
    'ep_bf' pour les bornes-fontaine). On essaie dans l'ordre :
      1. (schema, table) tel quel (cas direct).
      2. Si endpoint mobile fourni (ex: 'ep/hydrants'), on resout via
         MOBILE_SRM_TABLE_ENDPOINTS.
      3. Prefixe schema : `<schema>_<table>` (couvre la majorite des cas EP).
      4. Match approximatif : 1 seule table dont le nom Postgres se termine
         par `_<table>` ou par `<table>` dans le bon schema.

    Retourne (model, real_table_name) ou (None, table_name).
    """
    direct = _SRM_MODEL_BY_SCHEMA_TABLE.get((schema_name, table_name))
    if direct is not None:
        return direct, table_name

    if endpoint_hint:
        target = MOBILE_SRM_TABLE_ENDPOINTS.get(endpoint_hint)
        if target is not None:
            mapped_schema, mapped_table = target
            mapped = _SRM_MODEL_BY_SCHEMA_TABLE.get((mapped_schema, mapped_table))
            if mapped is not None:
                return mapped, mapped_table

    prefixed_table = f"{schema_name}_{table_name}"
    prefixed = _SRM_MODEL_BY_SCHEMA_TABLE.get((schema_name, prefixed_table))
    if prefixed is not None:
        return prefixed, prefixed_table

    suffix_underscore = f"_{table_name}"
    suffix_matches = [
        (real_table, model)
        for (schema, real_table), model in _SRM_MODEL_BY_SCHEMA_TABLE.items()
        if schema == schema_name
        and (real_table.endswith(suffix_underscore) or real_table == table_name)
    ]
    if len(suffix_matches) == 1:
        real_table, model = suffix_matches[0]
        return model, real_table

    return None, table_name


def _parse_positive_int_value(raw_value):
    if raw_value in (None, ''):
        return None
    try:
        value = int(raw_value)
    except (TypeError, ValueError):
        return None
    return value if value > 0 else None


_SYNC_META_KEYS = {
    '_sync_session_uuid',
    'sync_session_uuid',
    '_sync_client_item_uuid',
    'sync_client_item_uuid',
}


def _extract_sync_meta(data):
    if not isinstance(data, dict):
        return None, None

    sources = [data]
    properties = data.get('properties')
    if isinstance(properties, dict):
        sources.append(properties)

    session_uuid = None
    client_item_uuid = None
    for source in sources:
        session_uuid = session_uuid or source.get('_sync_session_uuid') or source.get('sync_session_uuid')
        client_item_uuid = client_item_uuid or source.get('_sync_client_item_uuid') or source.get('sync_client_item_uuid')

    session_uuid = str(session_uuid).strip() if session_uuid not in (None, '') else None
    client_item_uuid = str(client_item_uuid).strip() if client_item_uuid not in (None, '') else None
    return session_uuid, client_item_uuid


def _strip_sync_meta(data):
    if not isinstance(data, dict):
        return data

    cleaned = dict(data)
    for key in _SYNC_META_KEYS:
        cleaned.pop(key, None)

    properties = cleaned.get('properties')
    if isinstance(properties, dict):
        cleaned_properties = dict(properties)
        for key in _SYNC_META_KEYS:
            cleaned_properties.pop(key, None)
        cleaned['properties'] = cleaned_properties

    return cleaned


def _dict_like_get(source, key):
    if source is None or not hasattr(source, 'get'):
        return None
    return source.get(key)


def _history_source_for_request(request, sync_session_uuid=None, default=None):
    header_source = str(request.headers.get('X-SRM-Source', '')).strip().lower()
    if header_source in ('mobile', 'application mobile'):
        return 'mobile'
    if header_source in ('bureau', 'web', 'application web', 'backoffice'):
        return 'bureau'

    if sync_session_uuid:
        return 'mobile'

    for key in ('_sync_session_uuid', 'sync_session_uuid', 'sync_uuid'):
        value = _request_param(request, key)
        if value not in (None, ''):
            return 'mobile'

    return default


def _payload_truthy(data, field_name):
    sources = []
    if hasattr(data, 'get'):
        sources.append(data)
        properties = data.get('properties')
        if hasattr(properties, 'get'):
            sources.append(properties)

    for source in sources:
        value = source.get(field_name)
        if value in (None, ''):
            continue
        if isinstance(value, bool):
            return value
        if isinstance(value, (int, float)):
            return value != 0
        if str(value).strip().lower() in {'1', 'true', 'yes', 'oui', 'on'}:
            return True
    return False


def _history_action_for_write(request, default_action):
    if default_action == 'update' and _payload_truthy(request.data, 'is_validated'):
        return 'validate'
    return default_action


def _sync_session_payload(session):
    return {
        'sync_uuid': session.sync_uuid,
        'statut': session.statut,
        'id_agent': session.id_agent,
        'total_items': session.total_items,
        'total_attachments': session.total_attachments,
        'received_items': session.received_items,
        'received_attachments': session.received_attachments,
        'failed_items': session.failed_items,
        'started_at': session.started_at.isoformat() if session.started_at else None,
        'last_activity_at': (
            session.last_activity_at.isoformat()
            if session.last_activity_at
            else None
        ),
        'completed_at': session.completed_at.isoformat() if session.completed_at else None,
        'last_error': session.last_error,
    }


def _refresh_sync_session_counters(session):
    total_items = SyncSessionItem.objects.filter(sync_session=session).count()
    total_attachments = SyncSessionAttachment.objects.filter(sync_session=session).count()
    received_items = SyncSessionItem.objects.filter(
        sync_session=session,
        statut__in=('received', 'validated', 'duplicate'),
    ).count()
    received_attachments = SyncSessionAttachment.objects.filter(
        sync_session=session,
        statut='received',
    ).count()
    failed_items = SyncSessionItem.objects.filter(
        sync_session=session,
        statut__in=('rejected', 'failed'),
    ).count()

    now = timezone.now()
    session.total_items = total_items
    session.total_attachments = total_attachments
    session.received_items = received_items
    session.received_attachments = received_attachments
    session.failed_items = failed_items
    session.last_activity_at = now
    if (
        total_items == received_items
        and total_attachments == received_attachments
        and failed_items == 0
    ):
        session.statut = 'completed'
        session.completed_at = session.completed_at or now
    elif received_items > 0 or received_attachments > 0 or failed_items > 0:
        session.statut = 'partial'
        session.completed_at = None
    else:
        session.statut = 'manifest_received'
        session.completed_at = None
    session.save(
        update_fields=[
            'total_items',
            'total_attachments',
            'received_items',
            'received_attachments',
            'failed_items',
            'statut',
            'last_activity_at',
            'completed_at',
        ]
    )
    return session


def _mark_sync_item_received(*, sync_uuid, model, uuid_objet, instance, client_item_uuid=None):
    if not sync_uuid or not uuid_objet:
        return

    normalized = _normalized_db_table(model)
    if '.' not in normalized:
        return
    nom_schema, nom_table = normalized.split('.', 1)

    try:
        session = SyncSession.objects.get(sync_uuid=sync_uuid)
    except SyncSession.DoesNotExist:
        return

    now = timezone.now()
    pk_value = getattr(instance, instance._meta.pk.attname, None) if instance is not None else None
    item, _ = SyncSessionItem.objects.get_or_create(
        sync_session=session,
        nom_schema=nom_schema,
        nom_table=nom_table,
        uuid_objet=str(uuid_objet),
        defaults={
            'client_item_uuid': client_item_uuid,
            'operation': 'upsert',
            'statut': 'pending',
            'last_activity_at': now,
        },
    )
    item.client_item_uuid = client_item_uuid or item.client_item_uuid
    item.statut = 'received'
    item.attempts = (item.attempts or 0) + 1
    item.last_error = None
    item.received_at = item.received_at or now
    item.last_activity_at = now
    item.response_pk = str(pk_value) if pk_value is not None else item.response_pk
    item.response_uuid = str(uuid_objet)
    item.save(
        update_fields=[
            'client_item_uuid',
            'statut',
            'attempts',
            'last_error',
            'received_at',
            'last_activity_at',
            'response_pk',
            'response_uuid',
        ]
    )
    _refresh_sync_session_counters(session)


def _mark_sync_item_received_for_table(
    *,
    sync_uuid,
    nom_schema,
    nom_table,
    uuid_objet,
    response_pk=None,
    client_item_uuid=None,
):
    if not sync_uuid or not uuid_objet:
        return

    try:
        session = SyncSession.objects.get(sync_uuid=sync_uuid)
    except SyncSession.DoesNotExist:
        return

    now = timezone.now()
    item, _ = SyncSessionItem.objects.get_or_create(
        sync_session=session,
        nom_schema=nom_schema,
        nom_table=nom_table,
        uuid_objet=str(uuid_objet),
        defaults={
            'client_item_uuid': client_item_uuid,
            'operation': 'validate',
            'statut': 'pending',
            'last_activity_at': now,
        },
    )
    item.client_item_uuid = client_item_uuid or item.client_item_uuid
    item.statut = 'received'
    item.attempts = (item.attempts or 0) + 1
    item.last_error = None
    item.received_at = item.received_at or now
    item.last_activity_at = now
    item.response_pk = str(response_pk) if response_pk is not None else item.response_pk
    item.response_uuid = str(uuid_objet)
    item.save(
        update_fields=[
            'client_item_uuid',
            'statut',
            'attempts',
            'last_error',
            'received_at',
            'last_activity_at',
            'response_pk',
            'response_uuid',
        ]
    )
    _refresh_sync_session_counters(session)


def _mark_sync_attachment_received(*, sync_uuid, schema_name, table_name, uuid_objet, photo_slot, remote_path):
    if not sync_uuid or not uuid_objet:
        return

    try:
        session = SyncSession.objects.get(sync_uuid=sync_uuid)
    except SyncSession.DoesNotExist:
        return

    now = timezone.now()
    attachment, _ = SyncSessionAttachment.objects.get_or_create(
        sync_session=session,
        nom_schema=schema_name,
        nom_table=table_name,
        uuid_objet=uuid_objet,
        photo_slot=photo_slot,
        defaults={'statut': 'pending', 'last_activity_at': now},
    )
    attachment.statut = 'received'
    attachment.attempts = (attachment.attempts or 0) + 1
    attachment.last_error = None
    attachment.received_at = attachment.received_at or now
    attachment.last_activity_at = now
    attachment.remote_path = remote_path
    attachment.save(
        update_fields=[
            'statut',
            'attempts',
            'last_error',
            'received_at',
            'last_activity_at',
            'remote_path',
        ]
    )
    _refresh_sync_session_counters(session)


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


# =====================================================================
#  BASEMAP REGIONAL OFFLINE
#  Un unique fichier .pmtiles vectoriel OSM-like par region.
#  Le mobile telecharge ce fichier en un seul GET au login.
# =====================================================================

def _resolve_regional_basemap_path():
    configured = (settings.BASEMAP_REGIONAL_PMTILES_PATH or '').strip()
    if configured:
        candidate = Path(configured).expanduser()
        if not candidate.is_absolute():
            candidate = (Path(settings.BASE_DIR) / candidate).resolve()
        return candidate

    media_default = Path(settings.MEDIA_ROOT) / 'basemaps' / 'region.pmtiles'
    if media_default.exists():
        return media_default

    demo_fallback = (
        Path(settings.BASE_DIR).parent
        / 'basemaps'
        / 'build'
        / 'oujda_centre_demo_vector.pmtiles'
    )
    return demo_fallback


def _regional_basemap_manifest():
    pmtiles_path = _resolve_regional_basemap_path()
    if not pmtiles_path.exists() or not pmtiles_path.is_file():
        return None

    stat = pmtiles_path.stat()
    sha256 = hashlib.sha256()
    with pmtiles_path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            sha256.update(chunk)

    return {
        'path': pmtiles_path,
        'size_bytes': stat.st_size,
        'sha256': sha256.hexdigest(),
        'version': datetime.datetime.utcfromtimestamp(stat.st_mtime).strftime('%Y%m%d%H%M%S'),
        'mtime_iso': datetime.datetime.utcfromtimestamp(stat.st_mtime).isoformat() + 'Z',
        'name': settings.BASEMAP_REGIONAL_NAME,
        'attribution': settings.BASEMAP_REGIONAL_ATTRIBUTION,
        'format': 'pmtiles',
    }


# =====================================================================
#  MIXIN : Upsert par UUID (re-synchronisation aprÃ¨s Ã©dition)
# =====================================================================

class UpsertByUuidMixin:
    """
    Override de create() pour gÃ©rer la re-synchronisation mobile.

    ProblÃ¨me rÃ©solu :
      Un objet crÃ©Ã© localement est synchronisÃ© (POST â†’ crÃ©Ã© en base).
      L'agent le rÃ©-Ã©dite (dÃ©sactive toggle anomalie/incomplet).
      L'objet repasse en synced=0 cÃ´tÃ© Flutter.
      Flutter re-poste en POST â†’ Django dÃ©tecte l'UUID existant â†’ UPDATE.

    Comportement :
      - POST sans uuid ou uuid inconnu  â†’ CREATE (comportement standard)
      - POST avec uuid dÃ©jÃ  en base     â†’ UPDATE partiel (PATCH semantics)
      - ModÃ¨le sans champ uuid          â†’ CREATE (comportement standard)
    """

    @staticmethod
    def _model_has_uuid_field(model):
        return any(f.name == 'uuid' for f in model._meta.get_fields())

    def create(self, request, *args, **kwargs):
        qs = self.get_queryset()
        if not self._model_has_uuid_field(qs.model):
            return super().create(request, *args, **kwargs)

        uuid_val = None
        sync_session_uuid, sync_client_item_uuid = _extract_sync_meta(request.data)
        data = _strip_sync_meta(request.data)
        if isinstance(data, dict):
            props = data.get('properties', data)
            uuid_val = props.get('uuid') if isinstance(props, dict) else None

        if not uuid_val:
            if sync_session_uuid:
                serializer = self.get_serializer(data=data)
                serializer.is_valid(raise_exception=True)
                self.perform_create(serializer)
                headers = self.get_success_headers(serializer.data)
                return Response(
                    serializer.data,
                    status=status.HTTP_201_CREATED,
                    headers=headers,
                )
            return super().create(request, *args, **kwargs)

        uuid_clean = str(uuid_val).strip()
        if not uuid_clean:
            if sync_session_uuid:
                serializer = self.get_serializer(data=data)
                serializer.is_valid(raise_exception=True)
                self.perform_create(serializer)
                headers = self.get_success_headers(serializer.data)
                return Response(
                    serializer.data,
                    status=status.HTTP_201_CREATED,
                    headers=headers,
                )
            return super().create(request, *args, **kwargs)

        try:
            instance = qs.get(uuid=uuid_clean)
            serializer = self.get_serializer(
                instance, data=data, partial=True
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
            _mark_sync_item_received(
                sync_uuid=sync_session_uuid,
                model=qs.model,
                uuid_objet=uuid_clean,
                instance=serializer.instance,
                client_item_uuid=sync_client_item_uuid,
            )
            return Response(serializer.data, status=status.HTTP_200_OK)
        except qs.model.DoesNotExist:
            pass
        except qs.model.MultipleObjectsReturned:
            return Response(
                {
                    'error': (
                        f'UUID ambigu dÃ©tectÃ© pour {qs.model.__name__}: {uuid_clean}'
                    )
                },
                status=status.HTTP_409_CONFLICT,
            )

        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        response_uuid = getattr(serializer.instance, 'uuid', None)
        if response_uuid is not None and str(response_uuid).strip() != uuid_clean:
            return Response(
                {
                    'error': (
                        'UUID incoherent apres creation '
                        f'({uuid_clean} != {response_uuid})'
                    )
                },
                status=status.HTTP_409_CONFLICT,
            )
        _mark_sync_item_received(
            sync_uuid=sync_session_uuid,
            model=qs.model,
            uuid_objet=uuid_clean,
            instance=serializer.instance,
            client_item_uuid=sync_client_item_uuid,
        )
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)


# =====================================================================
#  MIXIN : Filtrage commun des entites SRM
# =====================================================================

class SrmEntityFilterMixin(UpsertByUuidMixin):
    """
    Applique les filtres communs encore actifs sur les entites terrain.
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
            'id_agent_incomplet',
            'id_agent_completement',
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
            audit_user_id = self._extract_audit_user_id(serializer)
            _set_local_audit_context(
                user_id=audit_user_id,
                source=_history_source_for_request(self.request),
                action='insert',
            )
            instance = serializer.save()
            _upsert_intervention_anomalie_from_instance(instance, audit_user_id)

    def perform_update(self, serializer):
        with transaction.atomic():
            audit_user_id = self._extract_audit_user_id(serializer)
            history_source = _history_source_for_request(self.request)
            _set_local_audit_context(
                user_id=audit_user_id,
                source=history_source,
                action=_history_action_for_write(self.request, 'update'),
            )
            instance = serializer.save()
            _set_local_audit_context(
                user_id=audit_user_id,
                source=history_source,
                action='update',
            )
            _upsert_intervention_anomalie_from_instance(instance, audit_user_id)

    def perform_destroy(self, instance):
        with transaction.atomic():
            _set_local_audit_context(
                user_id=self._extract_audit_user_id(instance=instance),
                source=_history_source_for_request(self.request),
                action='delete',
            )
            instance.delete()

    def get_queryset(self):
        qs = super().get_queryset()
        id_agent = self._parse_positive_int_param('id_agent_crea')
        updated_after = self._parse_datetime_param('updated_after')
        if id_agent is not None and self._has_model_field(qs, 'id_agent_crea'):
            qs = qs.filter(id_agent_crea=id_agent)
        if updated_after is not None and self._has_model_field(qs, 'updated_at'):
            qs = qs.filter(updated_at__gt=updated_after)
        if not qs.ordered:
            qs = qs.order_by(qs.model._meta.pk.attname)
        return qs


class MetricFilterMixin(SrmEntityFilterMixin):
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

        for param in ('id_agent',):
            value = self._parse_positive_int_param(param)
            if value is not None:
                qs = qs.filter(**{param: value})

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
    VÃ©rifie le mot de passe via les hashers Django configurÃ©s.
    Le backend ne modifie jamais automatiquement la base des mots de passe.
    """
    try:
        payload = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Corps de la requÃªte invalide (JSON attendu)'}, status=400)

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
        return JsonResponse({'error': 'Compte dÃ©sactivÃ©. Contactez votre administrateur.'}, status=403)

    if user.is_deleted:
        return JsonResponse({'error': 'Compte supprimÃ©. Contactez votre administrateur.'}, status=403)

    if not user.mot_de_passe_hash:
        return JsonResponse({'error': 'Aucun mot de passe configurÃ© pour ce compte'}, status=401)

    # Le mot de passe doit dÃ©jÃ  Ãªtre stockÃ© hashÃ© en base.
    if not user.mot_de_passe_hash.startswith(('argon2', 'pbkdf2', 'bcrypt')):
        return JsonResponse({'error': 'Compte non configurÃ© pour lâ€™authentification sÃ©curisÃ©e'}, status=401)

    mot_de_passe_valide = check_password(mot_de_passe, user.mot_de_passe_hash)

    if not mot_de_passe_valide:
        return JsonResponse({'error': 'Login ou mot de passe incorrect'}, status=401)

    roles_mobile = ['admin', 'project_manager', 'editeur_terrain', 'editeur_bureau', 'superadmin']
    if user.role not in roles_mobile:
        return JsonResponse({'error': "Votre profil ne permet pas l'accÃ¨s Ã  l'application mobile"}, status=403)

    user.dernier_login = timezone.now()
    user.save(update_fields=['dernier_login'])

    return JsonResponse({
        'success': True,
        'user': {
            'id_user': user.id_user,
            'login': user.login,
            'nom': user.nom,
            'prenom': user.prenom,
            'nom_complet': user.nom_complet,
            'role': user.role,
            'nb_objets_collectes_total': user.nb_objets_collectes_total,
        },
    })


@api_view(['GET'])
def regional_basemap_manifest_view(request):
    """Manifest du fichier .pmtiles regional unique a telecharger par le mobile."""
    manifest = _regional_basemap_manifest()
    if manifest is None:
        return Response(
            {
                'success': False,
                'message': (
                    "Aucun fichier basemap regional n'est disponible cote serveur. "
                    "Configurer BASEMAP_REGIONAL_PMTILES_PATH ou deposer "
                    "media/basemaps/region.pmtiles."
                ),
            },
            status=status.HTTP_404_NOT_FOUND,
        )

    download_url = request.build_absolute_uri(
        reverse('basemap-regional-download')
    )
    return Response(
        {
            'success': True,
            'name': manifest['name'],
            'attribution': manifest['attribution'],
            'format': manifest['format'],
            'version': manifest['version'],
            'sha256': manifest['sha256'],
            'size_bytes': manifest['size_bytes'],
            'generated_at': manifest['mtime_iso'],
            'download_url': download_url,
        },
        status=status.HTTP_200_OK,
    )


@api_view(['GET'])
def regional_basemap_download_view(request):
    """Stream du fichier .pmtiles regional, avec support Range pour reprise."""
    manifest = _regional_basemap_manifest()
    if manifest is None:
        return Response(
            {
                'success': False,
                'message': "Aucun fichier basemap regional configure.",
            },
            status=status.HTTP_404_NOT_FOUND,
        )

    pmtiles_path = manifest['path']
    file_size = manifest['size_bytes']
    range_header = request.META.get('HTTP_RANGE', '').strip()

    start = 0
    end = file_size - 1
    status_code = 200
    headers_extra = {}

    if range_header.startswith('bytes='):
        spec = range_header[len('bytes='):].split(',')[0].strip()
        if '-' in spec:
            raw_start, raw_end = spec.split('-', 1)
            try:
                if raw_start:
                    start = int(raw_start)
                if raw_end:
                    end = int(raw_end)
            except ValueError:
                start = 0
                end = file_size - 1
        if start < 0 or start >= file_size:
            response = HttpResponse(status=416)
            response['Content-Range'] = f'bytes */{file_size}'
            return response
        if end >= file_size:
            end = file_size - 1
        status_code = 206
        headers_extra['Content-Range'] = f'bytes {start}-{end}/{file_size}'

    length = end - start + 1

    def file_iterator(chunk_size=1024 * 256):
        with pmtiles_path.open('rb') as handle:
            handle.seek(start)
            remaining = length
            while remaining > 0:
                data = handle.read(min(chunk_size, remaining))
                if not data:
                    break
                remaining -= len(data)
                yield data

    response = StreamingHttpResponse(
        file_iterator(),
        status=status_code,
        content_type='application/octet-stream',
    )
    response['Content-Length'] = str(length)
    response['Accept-Ranges'] = 'bytes'
    response['ETag'] = f'"{manifest["sha256"]}"'
    response['Content-Disposition'] = (
        f'attachment; filename="{pmtiles_path.name}"'
    )
    for key, value in headers_extra.items():
        response[key] = value
    return response


@api_view(['POST'])
def sync_manifest_view(request):
    if not isinstance(request.data, dict):
        return Response(
            {'error': 'Payload JSON objet attendu.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    sync_uuid = (
        request.data.get('sync_uuid')
        or request.data.get('session_uuid')
        or request.data.get('sync_session_uuid')
    )
    sync_uuid = str(sync_uuid).strip() if sync_uuid not in (None, '') else ''
    if not sync_uuid:
        return Response(
            {'error': 'sync_uuid est obligatoire.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    raw_items = request.data.get('items') or []
    raw_attachments = request.data.get('attachments') or []
    if not isinstance(raw_items, list) or not isinstance(raw_attachments, list):
        return Response(
            {'error': 'items et attachments doivent etre des listes.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    now = timezone.now()
    id_agent = _parse_positive_int_value(request.data.get('id_agent'))

    with transaction.atomic():
        session, created = SyncSession.objects.get_or_create(
            sync_uuid=sync_uuid,
            defaults={
                'id_agent': id_agent,
                'device_id': str(request.data.get('device_id') or '').strip() or None,
                'app_version': str(request.data.get('app_version') or '').strip() or None,
                'statut': 'manifest_received',
                'started_at': now,
                'last_activity_at': now,
                'metadata_json': request.data.get('metadata'),
                'last_error': None,
            },
        )
        if not created:
            session.id_agent = id_agent
            session.device_id = str(request.data.get('device_id') or '').strip() or None
            session.app_version = str(request.data.get('app_version') or '').strip() or None
            session.statut = 'manifest_received'
            session.last_activity_at = now
            session.metadata_json = request.data.get('metadata')
            session.last_error = None
            session.completed_at = None
            session.save(
                update_fields=[
                    'id_agent',
                    'device_id',
                    'app_version',
                    'statut',
                    'last_activity_at',
                    'metadata_json',
                    'last_error',
                    'completed_at',
                ]
            )

        ignored_items = 0
        for item in raw_items:
            if not isinstance(item, dict):
                ignored_items += 1
                continue

            nom_schema = str(item.get('nom_schema') or item.get('schema_name') or '').strip().lower()
            nom_table = str(item.get('nom_table') or item.get('table_name') or '').strip().lower()
            uuid_objet = str(item.get('uuid_objet') or item.get('uuid') or '').strip()
            if not nom_schema or not nom_table or not uuid_objet:
                ignored_items += 1
                continue

            existing = SyncSessionItem.objects.filter(
                sync_session=session,
                nom_schema=nom_schema,
                nom_table=nom_table,
                uuid_objet=uuid_objet,
            ).first()
            defaults = {
                'client_item_uuid': str(item.get('client_item_uuid') or '').strip() or None,
                'local_id': _parse_positive_int_value(item.get('local_id')),
                'operation': str(item.get('operation') or 'upsert').strip()[:30],
                'payload_hash': str(item.get('payload_hash') or '').strip()[:64] or None,
                'last_activity_at': now,
                'payload_summary_json': item.get('payload_summary'),
            }
            if existing is None:
                SyncSessionItem.objects.create(
                    sync_session=session,
                    nom_schema=nom_schema,
                    nom_table=nom_table,
                    uuid_objet=uuid_objet,
                    statut='pending',
                    **defaults,
                )
            elif existing.statut not in ('received', 'validated', 'duplicate'):
                for key, value in defaults.items():
                    setattr(existing, key, value)
                existing.statut = 'pending'
                existing.save(
                    update_fields=[
                        'client_item_uuid',
                        'local_id',
                        'operation',
                        'payload_hash',
                        'last_activity_at',
                        'payload_summary_json',
                        'statut',
                    ]
                )

        ignored_attachments = 0
        for attachment in raw_attachments:
            if not isinstance(attachment, dict):
                ignored_attachments += 1
                continue

            nom_schema = str(attachment.get('nom_schema') or attachment.get('schema_name') or '').strip().lower()
            nom_table = str(attachment.get('nom_table') or attachment.get('table_name') or '').strip().lower()
            uuid_objet = str(attachment.get('uuid_objet') or attachment.get('uuid') or '').strip()
            photo_slot = _parse_positive_int_value(attachment.get('photo_slot'))
            if not nom_schema or not nom_table or not uuid_objet or photo_slot is None:
                ignored_attachments += 1
                continue

            existing = SyncSessionAttachment.objects.filter(
                sync_session=session,
                nom_schema=nom_schema,
                nom_table=nom_table,
                uuid_objet=uuid_objet,
                photo_slot=photo_slot,
            ).first()
            defaults = {
                'local_path': str(attachment.get('local_path') or '').strip() or None,
                'sha256': str(attachment.get('sha256') or '').strip()[:64] or None,
                'taille_octets': _parse_positive_int_value(attachment.get('taille_octets')),
                'last_activity_at': now,
            }
            if existing is None:
                SyncSessionAttachment.objects.create(
                    sync_session=session,
                    nom_schema=nom_schema,
                    nom_table=nom_table,
                    uuid_objet=uuid_objet,
                    photo_slot=photo_slot,
                    statut='pending',
                    **defaults,
                )
            elif existing.statut != 'received':
                for key, value in defaults.items():
                    setattr(existing, key, value)
                existing.statut = 'pending'
                existing.save(
                    update_fields=[
                        'local_path',
                        'sha256',
                        'taille_octets',
                        'last_activity_at',
                        'statut',
                    ]
                )

        session = _refresh_sync_session_counters(session)

    payload = _sync_session_payload(session)
    payload.update({
        'success': True,
        'created': created,
        'ignored_items': ignored_items,
        'ignored_attachments': ignored_attachments,
    })
    return Response(payload, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


@api_view(['GET'])
def sync_session_status_view(request, sync_uuid):
    try:
        session = SyncSession.objects.get(sync_uuid=sync_uuid)
    except SyncSession.DoesNotExist:
        return Response(
            {'error': 'Session de synchronisation introuvable.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    session = _refresh_sync_session_counters(session)
    payload = _sync_session_payload(session)
    payload['items'] = list(
        SyncSessionItem.objects.filter(sync_session=session)
        .order_by('id_sync_item')
        .values(
            'nom_schema',
            'nom_table',
            'uuid_objet',
            'statut',
            'attempts',
            'last_error',
            'received_at',
            'response_pk',
        )
    )
    payload['attachments'] = list(
        SyncSessionAttachment.objects.filter(sync_session=session)
        .order_by('id_sync_attachment')
        .values(
            'nom_schema',
            'nom_table',
            'uuid_objet',
            'photo_slot',
            'statut',
            'attempts',
            'last_error',
            'received_at',
            'remote_path',
        )
    )
    return Response(payload, status=status.HTTP_200_OK)


@api_view(['POST'])
@parser_classes([MultiPartParser, FormParser])
def photo_upload_view(request):
    _ensure_objet_photo_schema()

    serializer = PhotoUploadSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    data = serializer.validated_data

    schema_name = data['schema_name'].strip().lower()
    table_name = data['table_name'].strip().lower()
    uuid_objet = data['uuid_objet'].strip()
    photo_slot = data['photo_slot']
    endpoint_hint = (data.get('endpoint') or '').strip().strip('/').lower()
    sync_session_uuid = (data.get('sync_session_uuid') or '').strip()
    uploaded_file = data['file']

    model, resolved_table = _resolve_srm_photo_model(
        schema_name=schema_name,
        table_name=table_name,
        endpoint_hint=endpoint_hint,
    )
    if model is None:
        return Response(
            {'error': f'Objet SRM inconnu: {schema_name}.{table_name}'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    table_name = resolved_table

    # Verifier l'existence via raw SQL (et non model.objects.filter) car
    # certains modeles Django ont des colonnes desynchronisees avec la table
    # Postgres reelle (ex: EpHydrant declare 'ref_rue' alors que la table
    # n'a que 'ep_ref_rue'). Un SELECT minimal evite ces mismatches.
    qualified = pg_sql.SQL('{}.{}').format(
        pg_sql.Identifier(schema_name),
        pg_sql.Identifier(table_name),
    )
    with connection.cursor() as cursor:
        cursor.execute(
            pg_sql.SQL('SELECT 1 FROM {} WHERE uuid = %s LIMIT 1').format(qualified),
            [uuid_objet],
        )
        if cursor.fetchone() is None:
            return Response(
                {'error': f'Objet introuvable pour uuid={uuid_objet}'},
                status=status.HTTP_404_NOT_FOUND,
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
        _set_local_audit_context(
            user_id=_parse_positive_int_value(data.get('id_agent_crea')),
            source=_history_source_for_request(
                request,
                sync_session_uuid=sync_session_uuid,
                default='mobile',
            ),
        )
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
                'id_agent_crea': data.get('id_agent_crea'),
                'date_prise_reelle': captured_at,
                'date_upload': uploaded_at,
                'actif': True,
            },
        )

    _mark_sync_attachment_received(
        sync_uuid=sync_session_uuid,
        schema_name=schema_name,
        table_name=table_name,
        uuid_objet=uuid_objet,
        photo_slot=photo_slot,
        remote_path=relative_path,
    )

    media_url = request.build_absolute_uri(f'{settings.MEDIA_URL}{relative_path}')
    return Response(
        {
            'success': True,
            'schema_name': schema_name,
            'table_name': table_name,
            'uuid_objet': uuid_objet,
            'photo_slot': photo_slot,
            'field_name': f'photo_{photo_slot}',
            'storage_table': 'public.objet_photo',
            'relative_path': relative_path,
            'media_url': media_url,
            'date_prise_reelle': captured_at.isoformat() if captured_at else None,
            'date_upload': uploaded_at.isoformat(),
        },
        status=status.HTTP_201_CREATED,
    )


@api_view(['GET'])
def statistique_conduite_jour_view(request):
    raw_agent = (request.query_params.get('id_agent') or '').strip()
    raw_jour = (request.query_params.get('jour') or '').strip()
    metier_key, conduite_config = _conduite_config(
        request.query_params.get('metier'),
        default='ep',
    )

    if not raw_agent:
        return Response(
            {'error': 'ParamÃ¨tre id_agent requis.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if not raw_jour:
        return Response(
            {'error': 'ParamÃ¨tre jour requis.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        id_agent = int(raw_agent)
    except ValueError:
        return Response(
            {'error': 'ParamÃ¨tre id_agent invalide.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    jour = parse_date(raw_jour)
    if jour is None:
        return Response(
            {'error': 'ParamÃ¨tre jour invalide (YYYY-MM-DD attendu).'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    row = conduite_config['stat_model'].objects.filter(
        id_agent=id_agent,
        jour=jour,
    ).first()

    if row is None:
        return Response(
            {
                'exists': False,
                'frozen': False,
                'metier': metier_key,
                'id_agent': id_agent,
                'jour': jour.isoformat(),
                'longueur_conduite_m': 0.0,
                'segments_count': 0,
                'segments_wgs84': [],
            }
        )

    return Response(_statistique_conduite_snapshot(row, conduite_config, metier_key))


@api_view(['POST'])
def statistique_conduite_validate_view(request):
    serializer = StatistiqueConduiteValidateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    validated = serializer.validated_data
    metier_key, conduite_config = _conduite_config(
        validated.get('metier'),
        default='ep',
    )
    id_agent = validated['id_agent']
    jour = validated['jour']
    raw_nodes = validated['nodes']
    sync_session_uuid, sync_client_item_uuid = _extract_sync_meta(request.data)
    conduite_sync_uuid = (
        (validated.get('sync_uuid') or '').strip()
        or sync_client_item_uuid
        or f'{metier_key}-{id_agent}-{jour.isoformat()}'
    )

    existing = conduite_config['stat_model'].objects.filter(
        id_agent=id_agent,
        jour=jour,
    ).first()
    if existing is not None:
        payload = _statistique_conduite_snapshot(existing, conduite_config, metier_key)
        payload['error'] = 'La conduite de ce jour est dÃ©jÃ  figÃ©e.'
        _mark_sync_item_received_for_table(
            sync_uuid=sync_session_uuid,
            nom_schema=conduite_config['sync_schema'],
            nom_table=conduite_config['sync_table'],
            uuid_objet=conduite_sync_uuid,
            response_pk=existing.id_statistique_conduite,
            client_item_uuid=sync_client_item_uuid,
        )
        return Response(payload, status=status.HTTP_409_CONFLICT)

    resolved_nodes = [
        None
        if node.get('separator')
        else _resolve_conduite_regard_node(node, conduite_config)
        for node in raw_nodes
    ]
    unique_segments = _build_unique_conduite_segments(resolved_nodes)
    if not unique_segments:
        raise ValidationError(
            {
                'nodes': [
                    'Aucun segment unique exploitable Ã  enregistrer pour cette conduite.'
                ]
            }
        )

    now = timezone.now()
    with transaction.atomic():
        conduite = conduite_config['stat_model'].objects.create(
            id_agent=id_agent,
            jour=jour,
            geom=None,
            longueur_conduite_m=0.0,
            created_at=now,
            updated_at=now,
        )
        _insert_statistique_conduite_segments(
            conduite_config,
            conduite.id_statistique_conduite,
            unique_segments,
            now,
        )
        conduite.refresh_from_db()
        _mark_sync_item_received_for_table(
            sync_uuid=sync_session_uuid,
            nom_schema=conduite_config['sync_schema'],
            nom_table=conduite_config['sync_table'],
            uuid_objet=conduite_sync_uuid,
            response_pk=conduite.id_statistique_conduite,
            client_item_uuid=sync_client_item_uuid,
        )

    return Response(
        _statistique_conduite_snapshot(conduite, conduite_config, metier_key),
        status=status.HTTP_201_CREATED,
    )


# =====================================================================
#  PUBLIC
# =====================================================================

class CommuneViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Commune.objects.all().order_by('fid')
    serializer_class = CommuneSerializer


class ZoneViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = ZoneSerializer

    def get_queryset(self):
        qs = Zone.objects.all().order_by('nom_zone', 'id_zone')
        etat = self.request.query_params.get('etat')
        if etat:
            qs = qs.filter(etat=etat)
        return qs


class ZoneUtilisateurViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = ZoneUtilisateurSerializer

    def get_queryset(self):
        qs = ZoneUtilisateur.objects.all().order_by('id_user', 'id_zone')
        id_user = _parse_positive_int_value(self.request.query_params.get('id_user'))
        id_zone = _parse_positive_int_value(self.request.query_params.get('id_zone'))
        active_only = _parse_bool_value(
            self.request.query_params.get('active_only'),
            default=False,
        )
        if id_user is not None:
            qs = qs.filter(id_user=id_user)
        if id_zone is not None:
            qs = qs.filter(id_zone=id_zone)
        if active_only:
            qs = qs.filter(actif=True)
        return qs


class HistoriqueActionViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = HistoriqueAction.objects.all()
    serializer_class = HistoriqueActionSerializer

    def get_queryset(self):
        qs = HistoriqueAction.objects.all().order_by('-date_action', '-id')
        query_params = self.request.query_params

        text_filters = {
            'nom_table': 'nom_table',
            'action': 'action',
            'source': 'source',
            'nom_user': 'nom_user',
        }
        for param, field_name in text_filters.items():
            value = query_params.get(param)
            if value not in (None, ''):
                qs = qs.filter(**{field_name: value})

        for param in ('id_objet', 'id_user'):
            raw_value = query_params.get(param)
            if raw_value in (None, ''):
                continue
            try:
                qs = qs.filter(**{param: int(raw_value)})
            except (TypeError, ValueError):
                continue

        return qs


class ObjetIncompletViewSet(viewsets.ModelViewSet):
    queryset = ObjetIncomplet.objects.all().order_by('-date_signalement', '-id_incomplet')
    serializer_class = ObjetIncompletSerializer

    def _extract_audit_user_id(self, serializer=None, instance=None):
        validated_data = getattr(serializer, 'validated_data', None) or {}
        request_data = getattr(self.request, 'data', None)
        for source in (validated_data, request_data):
            if not hasattr(source, 'get'):
                continue
            for key in ('id_agent_completement', 'id_agent_incomplet', 'id_agent', 'id_user'):
                parsed = _parse_positive_int_value(source.get(key))
                if parsed is not None:
                    return parsed

        current_instance = instance or getattr(serializer, 'instance', None)
        if current_instance is not None:
            for key in ('id_agent_completement', 'id_agent_incomplet'):
                parsed = _parse_positive_int_value(getattr(current_instance, key, None))
                if parsed is not None:
                    return parsed

        return None

    def perform_create(self, serializer):
        sync_session_uuid, _ = _extract_sync_meta(self.request.data)
        with transaction.atomic():
            _set_local_audit_context(
                user_id=self._extract_audit_user_id(serializer),
                source=_history_source_for_request(
                    self.request,
                    sync_session_uuid=sync_session_uuid,
                ),
                action='insert',
            )
            serializer.save()

    def perform_update(self, serializer):
        sync_session_uuid, _ = _extract_sync_meta(self.request.data)
        with transaction.atomic():
            _set_local_audit_context(
                user_id=self._extract_audit_user_id(serializer),
                source=_history_source_for_request(
                    self.request,
                    sync_session_uuid=sync_session_uuid,
                ),
                action='update',
            )
            serializer.save()

    def perform_destroy(self, instance):
        with transaction.atomic():
            _set_local_audit_context(
                user_id=self._extract_audit_user_id(instance=instance),
                source=_history_source_for_request(self.request),
                action='delete',
            )
            instance.delete()

    def get_queryset(self):
        qs = ObjetIncomplet.objects.all().order_by('-date_signalement', '-id_incomplet')
        query_params = self.request.query_params

        for param in ('nom_table', 'statut'):
            value = query_params.get(param)
            if value not in (None, ''):
                qs = qs.filter(**{param: value})

        for param in ('id_objet', 'id_agent_incomplet', 'id_agent_completement'):
            value = _parse_positive_int_value(query_params.get(param))
            if value is not None:
                qs = qs.filter(**{param: value})

        open_only = _parse_bool_value(query_params.get('open_only'), default=False)
        if open_only:
            qs = qs.filter(statut='A_COMPLETER')

        return qs

    def _find_existing_for_payload(self, serializer):
        data = serializer.validated_data
        raw_id = self.request.data.get('id_incomplet')
        id_incomplet = _parse_positive_int_value(raw_id)
        if id_incomplet is not None:
            existing = ObjetIncomplet.objects.filter(
                id_incomplet=id_incomplet,
            ).first()
            if existing is not None:
                return existing

        nom_table = data.get('nom_table')
        id_objet = data.get('id_objet')
        if not nom_table or id_objet is None:
            return None

        qs = ObjetIncomplet.objects.filter(
            nom_table=nom_table,
            id_objet=id_objet,
        )
        statut = data.get('statut') or 'A_COMPLETER'
        if statut == 'A_COMPLETER':
            return qs.filter(statut='A_COMPLETER').order_by('-date_signalement', '-id_incomplet').first()

        return qs.filter(statut='A_COMPLETER').order_by('-date_signalement', '-id_incomplet').first()

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        existing = self._find_existing_for_payload(serializer)
        if existing is not None:
            update_serializer = self.get_serializer(
                existing,
                data=request.data,
                partial=True,
            )
            update_serializer.is_valid(raise_exception=True)
            self.perform_update(update_serializer)
            update_serializer.instance.refresh_from_db()
            output_serializer = self.get_serializer(update_serializer.instance)
            return Response(output_serializer.data, status=status.HTTP_200_OK)

        self.perform_create(serializer)
        serializer.instance.refresh_from_db()
        output_serializer = self.get_serializer(serializer.instance)
        headers = self.get_success_headers(output_serializer.data)
        return Response(output_serializer.data, status=status.HTTP_201_CREATED, headers=headers)


class InterventionAnomalieTerrainViewSet(viewsets.ModelViewSet):
    queryset = InterventionAnomalie.objects.all()
    serializer_class = InterventionAnomalieTerrainSerializer
    http_method_names = ['get', 'patch', 'head', 'options']

    def get_queryset(self):
        qs = InterventionAnomalie.objects.all().order_by('-updated_at', '-id')
        query_params = self.request.query_params

        active_only = _parse_bool_value(
            query_params.get('active_only'),
            default=True,
        )
        terrain_only = _parse_bool_value(
            query_params.get('terrain_only'),
            default=True,
        )
        if active_only:
            qs = qs.exclude(statut__in=('cloture', 'annule'))
        if terrain_only:
            qs = qs.filter(responsable_actuel='terrain')

        for param in ('nom_table', 'uuid_objet', 'statut', 'etat_terrain'):
            value = (query_params.get(param) or '').strip()
            if value:
                qs = qs.filter(**{param: value})

        id_objet = _parse_positive_int_value(query_params.get('id_objet'))
        if id_objet is not None:
            qs = qs.filter(id_objet=id_objet)

        id_user_terrain = _parse_positive_int_value(
            query_params.get('id_user_terrain') or query_params.get('id_user')
        )
        if id_user_terrain is not None:
            qs = qs.filter(id_user_terrain=id_user_terrain)

        updated_after = query_params.get('updated_after')
        if updated_after:
            parsed_updated_after = parse_datetime(updated_after)
            if parsed_updated_after is None:
                raise ValidationError({'updated_after': 'Date ISO 8601 attendue'})
            if timezone.is_naive(parsed_updated_after):
                parsed_updated_after = timezone.make_aware(
                    parsed_updated_after,
                    timezone.get_current_timezone(),
                )
            qs = qs.filter(updated_at__gt=parsed_updated_after)

        return qs

    def partial_update(self, request, *args, **kwargs):
        sync_session_uuid, sync_client_item_uuid = _extract_sync_meta(request.data)
        instance = self.get_object()
        data = _strip_sync_meta(request.data)
        serializer = self.get_serializer(instance, data=data, partial=True)
        serializer.is_valid(raise_exception=True)
        audit_user_id = _parse_positive_int_value(
            serializer.validated_data.get('id_user_terrain')
            or getattr(instance, 'id_user_terrain', None)
        )
        with transaction.atomic():
            _set_local_audit_context(
                user_id=audit_user_id,
                source=_history_source_for_request(
                    request,
                    sync_session_uuid=sync_session_uuid,
                    default='mobile',
                ),
                action='update',
            )
            serializer.save()
            serializer.instance.refresh_from_db()
            _mark_sync_item_received_for_table(
                sync_uuid=sync_session_uuid,
                nom_schema='public',
                nom_table='intervention_anomalie',
                uuid_objet=str(instance.id),
                response_pk=instance.id,
                client_item_uuid=sync_client_item_uuid,
            )
        return Response(serializer.data, status=status.HTTP_200_OK)


class ObjetPhotoViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = ObjetPhoto.objects.all()
    serializer_class = ObjetPhotoSerializer

    def get_queryset(self):
        qs = ObjetPhoto.objects.all().order_by(
            'nom_schema',
            'nom_table',
            'uuid_objet',
            'num_photo',
        )
        nom_schema = (self.request.query_params.get('nom_schema') or '').strip()
        nom_table = (self.request.query_params.get('nom_table') or '').strip()
        uuid_objet = (self.request.query_params.get('uuid_objet') or '').strip()

        if nom_schema:
            qs = qs.filter(nom_schema=nom_schema)
        if nom_table:
            qs = qs.filter(nom_table=nom_table)
        if uuid_objet:
            qs = qs.filter(uuid_objet=uuid_objet)
        return qs


class SrmFieldOptionViewSet(viewsets.ReadOnlyModelViewSet):
    """Field options exposees au mobile, lues depuis public.liste_choix.

    Source de verite : `public.liste_choix` (gere conjointement avec
    public.attribut_config_mobile). Le format de reponse reste compatible
    avec l'ancienne implementation basee sur srm_field_option, pour ne pas
    casser le mobile (ApiService.fetchSrmFieldOptions).
    """
    queryset = ListeChoix.objects.all()
    serializer_class = ListeChoixAsFieldOptionSerializer

    def get_queryset(self):
        qs = ListeChoix.objects.all().order_by(
            'nom_metier',
            'nom_table',
            'nom_champ',
            'liste_choix_ordre',
            'liste_choix_valeur',
        )

        table_schema = (self.request.query_params.get('table_schema') or '').strip()
        table_name = (self.request.query_params.get('table_name') or '').strip()
        field_name = (self.request.query_params.get('field_name') or '').strip()
        active_only = self.request.query_params.get('active_only', 'true').lower()

        if table_schema:
            qs = qs.filter(nom_metier__iexact=table_schema)
        if table_name:
            qs = qs.filter(nom_table__iexact=table_name)
        if field_name:
            qs = qs.filter(nom_champ__iexact=field_name)
        if active_only != 'false':
            # liste_choix_actif peut etre NULL : on traite NULL comme actif.
            from django.db.models import Q
            qs = qs.filter(Q(liste_choix_actif=True) | Q(liste_choix_actif__isnull=True))

        return qs


@api_view(['GET'])
def attribut_config_mobile_view(request):
    """Expose public.attribut_config_mobile as the mobile form structure source.

    This endpoint is intentionally separate from /api/srm-field-options/:
    attribut_config_mobile drives order/visibility/labels/types, while
    srm-field-options remains the choice-list compatibility endpoint.
    """
    filters = []
    params = []

    nom_metier = (
        request.query_params.get('nom_metier')
        or request.query_params.get('table_schema')
    )
    nom_table = (
        request.query_params.get('nom_table')
        or request.query_params.get('table_name')
    )
    nom_champ = (
        request.query_params.get('nom_champ')
        or request.query_params.get('field_name')
    )
    visible_only = (
        request.query_params.get('visible_only')
        or request.query_params.get('active_only')
        or ''
    ).strip().lower() in {'1', 'true', 'yes', 'oui'}

    if nom_metier:
        filters.append('nom_metier ILIKE %s')
        params.append(nom_metier.strip())
    if nom_table:
        filters.append('nom_table ILIKE %s')
        params.append(nom_table.strip())
    if nom_champ:
        filters.append('nom_champ ILIKE %s')
        params.append(nom_champ.strip())
    if visible_only:
        filters.append('COALESCE(visible, false) = true')

    where_sql = f"WHERE {' AND '.join(filters)}" if filters else ''
    query = f"""
        SELECT
            id,
            nom_metier,
            nom_table,
            nom_champ,
            type_champ,
            COALESCE(primary_key, false) AS primary_key,
            COALESCE(foreign_key, false) AS foreign_key,
            ordre,
            titre_app,
            COALESCE(visible, false) AS visible,
            contraintes,
            COALESCE(nullable, true) AS nullable,
            valeur_par_defaut,
            valeur_min,
            valeur_max,
            reference_fk
        FROM public.attribut_config_mobile
        {where_sql}
        ORDER BY nom_metier, nom_table, COALESCE(ordre, 999999), id
    """
    columns = [
        'id',
        'nom_metier',
        'nom_table',
        'nom_champ',
        'type_champ',
        'primary_key',
        'foreign_key',
        'ordre',
        'titre_app',
        'visible',
        'contraintes',
        'nullable',
        'valeur_par_defaut',
        'valeur_min',
        'valeur_max',
        'reference_fk',
    ]
    with connection.cursor() as cursor:
        cursor.execute(query, params)
        rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
    return Response(rows)


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


class MetricCanonicalPeriodMixin(MetricFilterMixin):
    allowed_grains = {'jour', 'semaine', 'mois'}

    def _apply_period_filters(self, qs):
        grain = (self.request.query_params.get('grain') or '').strip().lower()
        if grain:
            if grain not in self.allowed_grains:
                raise ValidationError({'grain': 'Valeurs autorisees: jour, semaine, mois'})
            qs = qs.filter(grain=grain)

        periode_debut = self._parse_date_only_param('periode_debut')
        date_from = self._parse_date_only_param('date_from')
        date_to = self._parse_date_only_param('date_to')

        if periode_debut is not None:
            qs = qs.filter(periode_debut=periode_debut)
        if date_from is not None:
            qs = qs.filter(periode_debut__gte=date_from)
        if date_to is not None:
            qs = qs.filter(periode_debut__lte=date_to)

        for param in ('annee', 'mois_numero', 'annee_iso', 'semaine_iso'):
            value = self._parse_positive_int_param(param)
            if value is not None:
                qs = qs.filter(**{param: value})

        value = self._parse_positive_int_param('id_agent')
        if value is not None:
            qs = qs.filter(id_agent=value)

        return qs


class MetricAgentTablePeriodViewSet(MetricCanonicalPeriodMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentTablePeriod.objects.all()
    serializer_class = MetricAgentTablePeriodSerializer

    def get_queryset(self):
        qs = MetricAgentTablePeriod.objects.all().order_by(
            '-periode_debut',
            'grain',
            'id_agent',
            'nom_schema',
            'nom_table',
        )
        qs = self._apply_metric_common_filters(qs)
        qs = self._apply_period_filters(qs)
        return qs


class MetricAgentPeriodViewSet(MetricCanonicalPeriodMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentPeriod.objects.all()
    serializer_class = MetricAgentPeriodSerializer

    def get_queryset(self):
        qs = MetricAgentPeriod.objects.all().order_by(
            '-periode_debut',
            'grain',
            'id_agent',
        )
        qs = self._apply_period_filters(qs)
        return qs


class MetricAgentResumeViewSet(MetricFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = MetricAgentResume.objects.all()
    serializer_class = MetricAgentResumeSerializer

    def get_queryset(self):
        qs = MetricAgentResume.objects.all().order_by('id_agent')
        value = self._parse_positive_int_param('id_agent')
        if value is not None:
            qs = qs.filter(id_agent=value)
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
        qs = MetricAgentPublicResume.objects.all().order_by('id_agent')
        for param in ('id_agent',):
            value = self._parse_positive_int_param(param)
            if value is not None:
                qs = qs.filter(**{param: value})
        return qs


# =====================================================================
#  EP â€” Eau Potable (27 ViewSets)
# =====================================================================

class EpVanneViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpVanne.objects.all()
    serializer_class = EpVanneSerializer


class EpVanneDeVidangeViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpVanneDeVidange.objects.all()
    serializer_class = EpVanneDeVidangeSerializer


class EpVentouseViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpVentouse.objects.all()
    serializer_class = EpVentouseSerializer


class EpHydrantViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpHydrant.objects.all()
    serializer_class = EpHydrantSerializer


class EpBorneFontaineViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpBorneFontaine.objects.all()
    serializer_class = EpBorneFontaineSerializer


class EpBorneOnepViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpBorneOnep.objects.all()
    serializer_class = EpBorneOnepSerializer


class EpBoucheClesViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpBoucheCles.objects.all()
    serializer_class = EpBoucheClesSerializer


class EpBoucheDarrosageViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpBoucheDarrosage.objects.all()
    serializer_class = EpBoucheDarrosageSerializer


class EpCompteurAbonneViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpCompteurAbonne.objects.all()
    serializer_class = EpCompteurAbonneSerializer


class EpCompteurReseauViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpCompteurReseau.objects.all()
    serializer_class = EpCompteurReseauSerializer


class EpConeDeReductionViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpConeDeReduction.objects.all()
    serializer_class = EpConeDeReductionSerializer


class EpCentreTamponViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpCentreTampon.objects.all()
    serializer_class = EpCentreTamponSerializer


class EpNoeudViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpNoeud.objects.all()
    serializer_class = EpNoeudSerializer


class EpObturateurViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpObturateur.objects.all()
    serializer_class = EpObturateurSerializer


class EpReducteurDePressionViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpReducteurDePression.objects.all()
    serializer_class = EpReducteurDePressionSerializer


class EpForageViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpForage.objects.all()
    serializer_class = EpForageSerializer


class EpPuitViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpPuit.objects.all()
    serializer_class = EpPuitSerializer


class EpPompeViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpPompe.objects.all()
    serializer_class = EpPompeSerializer


class EpReservoirViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpReservoir.objects.all()
    serializer_class = EpReservoirSerializer


class EpStationDePompageViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpStationDePompage.objects.all()
    serializer_class = EpStationDePompageSerializer


class EpRegardViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpRegard.objects.all()
    serializer_class = EpRegardSerializer


class EpRegardMiroirViewSet(SrmEntityFilterMixin, viewsets.ReadOnlyModelViewSet):
    queryset = EpRegardMiroir.objects.all()
    serializer_class = EpRegardMiroirSerializer

    def _table_exists(self):
        with connection.cursor() as cursor:
            cursor.execute("SELECT to_regclass(%s)", ['ep.ep_regard'])
            row = cursor.fetchone()
        return bool(row and row[0])

    def get_queryset(self):
        if not self._table_exists():
            return EpRegardMiroir.objects.none()
        return super().get_queryset()

    def list(self, request, *args, **kwargs):
        if not self._table_exists():
            return Response(
                {
                    'count': 0,
                    'next': None,
                    'previous': None,
                    'results': [],
                    'warning': (
                        'La table polygonale ep.ep_regard n existe pas encore. '
                        'Elle doit etre generee depuis ep.ep_regard_point.'
                    ),
                }
            )
        return super().list(request, *args, **kwargs)


class EpAutreObjetViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpAutreObjet.objects.all()
    serializer_class = EpAutreObjetSerializer


class EpConduiteTerrainViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpConduiteTerrain.objects.all()
    serializer_class = EpConduiteTerrainSerializer


class EpConduiteBureauViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpConduiteBureau.objects.all()
    serializer_class = EpConduiteBureauSerializer


class EpBranchementViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpBranchement.objects.all()
    serializer_class = EpBranchementSerializer


class EpTraverseViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = EpTraverse.objects.all()
    serializer_class = EpTraverseSerializer


# =====================================================================
#  ASS â€” Assainissement (9 ViewSets)
# =====================================================================

class AssRegardViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = AssRegard.objects.all()
    serializer_class = AssRegardSerializer


class AssRegardBranchementViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = AssRegardBranchement.objects.all()
    serializer_class = AssRegardBranchementSerializer


class AssCanalisationViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = AssCanalisation.objects.all()
    serializer_class = AssCanalisationSerializer


class AssCanalisationReutilisationViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = AssCanalisationReutilisation.objects.all()
    serializer_class = AssCanalisationReutilisationSerializer


class AssBranchementViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = AssBranchement.objects.all()
    serializer_class = AssBranchementSerializer


class AssBassinViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = AssBassin.objects.all()
    serializer_class = AssBassinSerializer


class AssOuvrageViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = AssOuvrage.objects.all()
    serializer_class = AssOuvrageSerializer


class AssEquipementViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = AssEquipement.objects.all()
    serializer_class = AssEquipementSerializer


class AssStationViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = AssStation.objects.all()
    serializer_class = AssStationSerializer


# =====================================================================
#  ELEC â€” Ã‰lectricitÃ© (11 ViewSets)
# =====================================================================

class ElecSupportViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecSupport.objects.all()
    serializer_class = ElecSupportSerializer


class ElecPosteViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecPoste.objects.all()
    serializer_class = ElecPosteSerializer


class ElecCoffretBtViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecCoffretBt.objects.all()
    serializer_class = ElecCoffretBtSerializer


class ElecNoeudRaccordViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecNoeudRaccord.objects.all()
    serializer_class = ElecNoeudRaccordSerializer


class ElecPointDesserteViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecPointDesserte.objects.all()
    serializer_class = ElecPointDesserteSerializer


class ElecTransformateurViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecTransformateur.objects.all()
    serializer_class = ElecTransformateurSerializer


class ElecCelluleViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecCellule.objects.all()
    serializer_class = ElecCelluleSerializer


class ElecDepartBtViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecDepartBt.objects.all()
    serializer_class = ElecDepartBtSerializer


class ElecDepartHtaViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecDepartHta.objects.all()
    serializer_class = ElecDepartHtaSerializer


class ElecTronconBtViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecTronconBt.objects.all()
    serializer_class = ElecTronconBtSerializer


class ElecTronconHtaViewSet(SrmEntityFilterMixin, viewsets.ModelViewSet):
    queryset = ElecTronconHta.objects.all()
    serializer_class = ElecTronconHtaSerializer
