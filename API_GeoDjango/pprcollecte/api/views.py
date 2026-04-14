"""
Vues API pour SRM Collecte — COMPLET (55 modèles).

Chaque ViewSet filtre par id_projet et id_mission via query params.
Le login vérifie le mot de passe hashé PBKDF2 via Django.
"""

import hashlib
import os
import re
from pathlib import Path

from django.conf import settings
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

from .models import (
    Utilisateur, Projet, Mission, Commune,
    HistoriqueAttribut, HistoriqueMobile, ObjetIncomplet, ObjetPhoto, FondDePlan, EvaluationAgent,
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
    FondDePlanSerializer, EvaluationAgentSerializer,
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


# =====================================================================
#  MIXIN : Filtrage par projet et mission (réutilisé par tous les ViewSets)
# =====================================================================

class ProjetMissionFilterMixin:
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
        if id_projet is not None:
            qs = qs.filter(id_projet=id_projet)
        if id_mission is not None:
            qs = qs.filter(id_mission=id_mission)
        if id_agent is not None:
            qs = qs.filter(id_agent_crea=id_agent)
        if updated_after is not None and self._has_model_field(qs, 'updated_at'):
            qs = qs.filter(updated_at__gt=updated_after)
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
                'date_upload': timezone.now(),
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
    queryset = Commune.objects.all()
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
