"""
Serializers GeoJSON pour SRM Collecte — COMPLET (55 modèles).

Utilise GeoFeatureModelSerializer de DRF-GIS pour les tables avec géométrie.
Utilise ModelSerializer standard pour les tables sans géométrie.
Les données spatiales sont sérialisées en GeoJSON (RFC 7946) avec SRID 26191.
"""

import datetime
import json
import math
from urllib.parse import urlparse

from django.conf import settings
from django.contrib.gis.geos import Point
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer

from .models import (
    # Public
    Utilisateur, Commune, Zone, ZoneUtilisateur,
    HistoriqueAction, ObjetIncomplet, ObjetPhoto,
    InterventionAnomalie,
    EpStatistiqueConduite, EpStatistiqueConduiteSegment,
    SrmFieldOption, BasemapPackage,
    MetricAgentJour, MetricAgentSemaine, MetricAgentMois,
    MetricAgentTablePeriod, MetricAgentPeriod, MetricAgentResume,
    MetricAgentPublicJour, MetricAgentPublicSemaine, MetricAgentPublicMois, MetricAgentPublicResume,
    # EP ponctuels
    EpVanne, EpVanneDeVidange, EpVentouse, EpHydrant,
    EpBorneFontaine, EpBorneOnep, EpBoucheCles, EpBoucheDarrosage,
    EpCompteurAbonne, EpCompteurReseau, EpConeDeReduction, EpCentreTampon,
    EpNoeud, EpObturateur, EpReducteurDePression,
    EpForage, EpPuit, EpPompe, EpReservoir, EpStationDePompage,
    EpRegard, EpRegardMiroir, EpRegardEp, EpAutreObjet,
    # EP linéaires + surfacique
    EpConduiteTerrain, EpConduiteBureau, EpBranchement, EpTraverse, EpPlanche,
    # ASS
    AssRegard, AssRegardBranchement, AssCanalisation, AssCanalisationReutilisation,
    AssBranchement, AssBassin, AssOuvrage, AssEquipement, AssStation,
    # ELEC
    ElecSupport, ElecPoste, ElecCoffretBt, ElecNoeudRaccord, ElecPointDesserte,
    ElecTransformateur, ElecCellule, ElecDepartBt, ElecDepartHta,
    ElecTronconBt, ElecTronconHta,
)


class StrictSerializerMixin:
    default_text_max_length = 500
    extended_text_limits = {
        'commentaire': 1000,
        'observation': 1000,
        'type_anomalie': 500,
        'photo_1': 2048,
        'photo_2': 2048,
        'photo_3': 2048,
        'photo_4': 2048,
        'url_service': 2048,
    }
    latitude_fields = {'latitude_gps', 'lat_debut', 'lat_fin'}
    longitude_fields = {'longitude_gps', 'lon_debut', 'lon_fin'}
    metric_coordinate_fields = {
        'x_debut', 'y_debut', 'x_fin', 'y_fin',
        'ep_coor_x', 'ep_coor_y', 'ep_coor_z',
        'ass_coor_x', 'ass_coor_y', 'ass_coor_z',
        'elec_coor_x', 'elec_coor_y', 'elec_coor_z',
    }
    photo_fields = {'photo_1', 'photo_2', 'photo_3', 'photo_4'}
    allowed_photo_extensions = {
        '.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'
    }

    def to_internal_value(self, data):
        if not isinstance(data, dict):
            raise serializers.ValidationError('Payload JSON objet attendu')

        cleaned = {}
        errors = {}

        for key, value in data.items():
            if key in self.photo_fields and value not in (None, ''):
                errors[key] = (
                    'Reference photo centralisee: utiliser /api/photos/upload/.'
                )
                continue
            if isinstance(value, str):
                stripped = value.strip()
                if any(ord(char) < 32 and char not in '\t\n\r' for char in stripped):
                    errors[key] = 'Caractères de contrôle non autorisés'
                    continue
                cleaned[key] = stripped
            else:
                cleaned[key] = value

        if errors:
            raise serializers.ValidationError(errors)

        validated = super().to_internal_value(cleaned)

        for field_name, value in validated.items():
            if not isinstance(value, str):
                continue

            field = self.fields.get(field_name)
            if not isinstance(field, serializers.CharField):
                continue

            max_length = field.max_length or self.extended_text_limits.get(
                field_name,
                self.default_text_max_length,
            )
            if max_length and len(value) > max_length:
                errors[field_name] = f'Maximum {max_length} caractères'

        if errors:
            raise serializers.ValidationError(errors)

        return validated

    def validate(self, attrs):
        errors = {}

        instance = getattr(self, 'instance', None)
        current_uuid = getattr(instance, 'uuid', None) if instance is not None else None
        incoming_uuid = attrs.get('uuid')
        if current_uuid not in (None, '') and incoming_uuid not in (None, ''):
            if str(current_uuid).strip() != str(incoming_uuid).strip():
                errors['uuid'] = 'UUID immuable : modification interdite'

        for field_name in self.latitude_fields:
            value = attrs.get(field_name)
            if value is None:
                continue
            if not self._is_finite_number(value) or not (-90 <= float(value) <= 90):
                errors[field_name] = 'Latitude hors plage [-90, 90]'

        for field_name in self.longitude_fields:
            value = attrs.get(field_name)
            if value is None:
                continue
            if not self._is_finite_number(value) or not (-180 <= float(value) <= 180):
                errors[field_name] = 'Longitude hors plage [-180, 180]'

        for field_name in self.metric_coordinate_fields:
            value = attrs.get(field_name)
            if value is None:
                continue
            if not self._is_finite_number(value):
                errors[field_name] = 'Coordonnée numérique invalide'

        url_value = attrs.get('url_service')
        if url_value:
            parsed = urlparse(url_value)
            if parsed.scheme not in ('http', 'https'):
                errors['url_service'] = 'URL http/https attendue'

        for field_name in self.photo_fields:
            value = attrs.get(field_name)
            if not value:
                continue
            if not isinstance(value, str):
                errors[field_name] = 'Chemin photo invalide'
                continue
            photo_error = self._validate_photo_reference(value)
            if photo_error:
                errors[field_name] = photo_error

        geom = attrs.get('geom') or attrs.get('geom_zone')
        if geom is not None and getattr(geom, 'empty', False):
            errors['geom'] = 'Géométrie vide non autorisée'

        lat_start = attrs.get('lat_debut')
        lon_start = attrs.get('lon_debut')
        lat_end = attrs.get('lat_fin')
        lon_end = attrs.get('lon_fin')
        if ((lat_start is None) != (lon_start is None)):
            errors['lat_debut'] = 'lat_debut et lon_debut doivent être fournis ensemble'
        if ((lat_end is None) != (lon_end is None)):
            errors['lat_fin'] = 'lat_fin et lon_fin doivent être fournis ensemble'

        if errors:
            raise serializers.ValidationError(errors)

        return super().validate(attrs)

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        for field_name in self.photo_fields:
            representation.pop(field_name, None)
        return representation

    def _is_finite_number(self, value):
        try:
            return math.isfinite(float(value))
        except (TypeError, ValueError):
            return False

    def _validate_photo_reference(self, value):
        normalized = value.strip()
        lowered = normalized.lower()
        if lowered.startswith(('javascript:', 'data:')):
            return 'Format de photo non autorisé'

        if '\x00' in normalized:
            return 'Référence photo invalide'

        parsed = urlparse(normalized)
        if parsed.scheme and parsed.scheme not in ('http', 'https', 'file', 'content'):
            return 'Schéma photo non autorisé'

        candidate_path = parsed.path or normalized
        if '/../' in candidate_path or '\\..\\' in candidate_path:
            return 'Référence photo invalide'

        if not self._has_allowed_photo_extension(candidate_path):
            return (
                'Extension photo non autorisée '
                '(jpg, jpeg, png, webp, heic, heif)'
            )

        return None

    def _has_allowed_photo_extension(self, value):
        lowered = value.lower()
        for extension in self.allowed_photo_extensions:
            if lowered.endswith(extension):
                return True
        return False


class StrictModelSerializer(StrictSerializerMixin, serializers.ModelSerializer):
    pass


class StrictGeoFeatureModelSerializer(StrictSerializerMixin, GeoFeatureModelSerializer):
    pass


class LenientDateField(serializers.DateField):
    """Accepts datetime values from PostgreSQL timestamp columns and exposes a date."""

    def to_representation(self, value):
        if isinstance(value, datetime.datetime):
            if timezone.is_aware(value):
                value = timezone.localtime(value)
            value = value.date()
        return super().to_representation(value)

    def to_internal_value(self, data):
        if isinstance(data, datetime.datetime):
            if timezone.is_aware(data):
                data = timezone.localtime(data)
            data = data.date()
        elif isinstance(data, str):
            parsed_datetime = parse_datetime(data.strip())
            if parsed_datetime is not None:
                if timezone.is_aware(parsed_datetime):
                    parsed_datetime = timezone.localtime(parsed_datetime)
                data = parsed_datetime.date()
        return super().to_internal_value(data)


class LoginRequestSerializer(serializers.Serializer):
    login = serializers.CharField(max_length=100, trim_whitespace=True)
    mot_de_passe = serializers.CharField(max_length=255, trim_whitespace=True)


class PhotoUploadSerializer(serializers.Serializer):
    schema_name = serializers.CharField(max_length=20, trim_whitespace=True)
    table_name = serializers.CharField(max_length=100, trim_whitespace=True)
    uuid_objet = serializers.CharField(max_length=254, trim_whitespace=True)
    photo_slot = serializers.IntegerField(min_value=1, max_value=4)
    sync_session_uuid = serializers.CharField(
        max_length=64,
        required=False,
        allow_blank=True,
        allow_null=True,
        trim_whitespace=True,
    )
    id_agent_crea = serializers.IntegerField(required=False, allow_null=True)
    file = serializers.FileField()

    allowed_photo_extensions = {
        '.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'
    }
    max_photo_bytes = 5 * 1024 * 1024

    def validate_file(self, value):
        file_name = getattr(value, 'name', '') or ''
        lowered = file_name.lower()
        if not any(lowered.endswith(ext) for ext in self.allowed_photo_extensions):
            raise serializers.ValidationError(
                'Extension photo non autorisée (jpg, jpeg, png, webp, heic, heif)'
            )

        if getattr(value, 'size', 0) <= 0:
            raise serializers.ValidationError('Fichier photo vide')

        if value.size > self.max_photo_bytes:
            raise serializers.ValidationError('Photo trop volumineuse (maximum 5 Mo)')

        return value


class StatistiqueConduiteNodeSerializer(serializers.Serializer):
    separator = serializers.BooleanField(required=False, default=False)
    fid = serializers.IntegerField(required=False, allow_null=True)
    uuid = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        max_length=254,
        trim_whitespace=True,
    )
    label = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        max_length=254,
        trim_whitespace=True,
    )
    table_name = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        max_length=100,
        trim_whitespace=True,
    )
    metier = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        max_length=20,
        trim_whitespace=True,
    )
    x = serializers.FloatField(required=False, allow_null=True)
    y = serializers.FloatField(required=False, allow_null=True)
    z = serializers.FloatField(required=False, allow_null=True)
    ep_num = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        max_length=254,
        trim_whitespace=True,
    )

    def validate(self, attrs):
        if attrs.get('separator'):
            return attrs

        fid = attrs.get('fid')
        uuid = (attrs.get('uuid') or '').strip()
        if fid is None and not uuid:
            raise serializers.ValidationError(
                'Chaque regard doit fournir fid ou uuid.'
            )
        return attrs


class StatistiqueConduiteValidateSerializer(serializers.Serializer):
    metier = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        max_length=20,
        trim_whitespace=True,
    )
    sync_uuid = serializers.CharField(
        required=False,
        allow_blank=True,
        allow_null=True,
        max_length=128,
        trim_whitespace=True,
    )
    id_agent = serializers.IntegerField(min_value=1)
    jour = LenientDateField()
    nodes = StatistiqueConduiteNodeSerializer(many=True)

    def validate_nodes(self, value):
        real_nodes = [node for node in value if not node.get('separator')]
        if len(real_nodes) < 2:
            raise serializers.ValidationError(
                'Au moins deux regards sont necessaires pour valider une conduite.'
            )
        return value


class StatistiqueConduiteSegmentSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpStatistiqueConduiteSegment
        geo_field = 'geom'
        fields = '__all__'


class StatistiqueConduiteSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpStatistiqueConduite
        geo_field = 'geom'
        fields = '__all__'

# =====================================================================
#  SCHÉMA PUBLIC
# =====================================================================

class UtilisateurSerializer(StrictModelSerializer):
    class Meta:
        model = Utilisateur
        exclude = ('mot_de_passe_hash',)


class ObjetPhotoSerializer(StrictModelSerializer):
    class Meta:
        model = ObjetPhoto
        fields = '__all__'
        read_only_fields = ('id_photo',)


class InterventionAnomalieTerrainSerializer(StrictModelSerializer):
    writable_fields = {'etat_terrain', 'commentaire_terrain', 'id_user_terrain'}
    allowed_terrain_states = {'en_attente', 'traite'}

    class Meta:
        model = InterventionAnomalie
        fields = (
            'id',
            'id_objet',
            'nom_classe',
            'nom_table',
            'uuid_objet',
            'retour_terrain',
            'statut',
            'responsable_actuel',
            'etat_terrain',
            'commentaire_terrain',
            'date_terrain',
            'id_user_terrain',
            'date_creation',
            'date_cloture',
            'created_at',
            'updated_at',
        )
        read_only_fields = (
            'id',
            'id_objet',
            'nom_classe',
            'nom_table',
            'uuid_objet',
            'retour_terrain',
            'statut',
            'responsable_actuel',
            'date_terrain',
            'date_creation',
            'date_cloture',
            'created_at',
            'updated_at',
        )

    def to_internal_value(self, data):
        if not isinstance(data, dict):
            raise serializers.ValidationError('Payload JSON objet attendu')

        forbidden = sorted(set(data) - self.writable_fields)
        if forbidden:
            raise serializers.ValidationError({
                field: 'Champ non modifiable depuis le mobile terrain.'
                for field in forbidden
            })

        return super().to_internal_value(data)

    def validate_etat_terrain(self, value):
        clean_value = (value or '').strip()
        if clean_value not in self.allowed_terrain_states:
            raise serializers.ValidationError(
                'Etat terrain mobile autorise: en_attente ou traite.'
            )
        return clean_value

    def update(self, instance, validated_data):
        for field in ('commentaire_terrain', 'id_user_terrain'):
            if field in validated_data:
                setattr(instance, field, validated_data[field])

        if 'etat_terrain' in validated_data:
            instance.etat_terrain = validated_data['etat_terrain']
            if instance.etat_terrain == 'traite':
                instance.statut = 'terrain_traite'
            elif instance.statut in (None, '', 'signale', 'retour_terrain'):
                instance.statut = 'signale'

        instance.save()
        return instance


class CommuneSerializer(StrictGeoFeatureModelSerializer):
    id_commune = serializers.IntegerField(source='fid', read_only=True)
    nom_commune = serializers.SerializerMethodField()
    nom_province = serializers.SerializerMethodField()
    nom_region = serializers.SerializerMethodField()

    def get_nom_commune(self, obj):
        return obj.nom

    def get_nom_province(self, obj):
        if obj.code_provi == '02.411.':
            return "Préfecture d'Oujda-Angad"
        return None

    def get_nom_region(self, obj):
        if obj.code_regio == '02.':
            return 'Oriental'
        return None

    class Meta:
        model = Commune
        geo_field = 'geom'
        fields = (
            'fid',
            'code_provi',
            'code_regio',
            'nom',
            'nom_arabe',
            'id_province',
            'id_commune',
            'nom_commune',
            'nom_province',
            'nom_region',
        )


class ZoneSerializer(StrictGeoFeatureModelSerializer):
    geometry_geojson = serializers.SerializerMethodField()

    class Meta:
        model = Zone
        geo_field = 'geom'
        fields = (
            'id_zone',
            'nom_zone',
            'etat',
            'date_debut',
            'date_cloture',
            'id_user_creat',
            'id_user_cloture',
            'geometry_geojson',
        )

    def get_geometry_geojson(self, obj):
        if obj.geom is None:
            return None
        try:
            return json.loads(obj.geom.json)
        except AttributeError:
            return None
        except json.JSONDecodeError:
            return None


class ZoneUtilisateurSerializer(StrictModelSerializer):
    class Meta:
        model = ZoneUtilisateur
        fields = '__all__'


class HistoriqueActionSerializer(StrictModelSerializer):
    class Meta:
        model = HistoriqueAction
        fields = '__all__'


class ObjetIncompletSerializer(StrictModelSerializer):
    allowed_statuses = {'A_COMPLETER', 'COMPLETE'}

    class Meta:
        model = ObjetIncomplet
        fields = '__all__'

    def validate_statut(self, value):
        if value in (None, ''):
            return 'A_COMPLETER'
        normalized = str(value).strip().upper()
        if normalized not in self.allowed_statuses:
            raise serializers.ValidationError(
                "Statut attendu: A_COMPLETER ou COMPLETE"
            )
        return normalized

    def validate(self, attrs):
        attrs = super().validate(attrs)
        has_incoming_status = 'statut' in attrs
        statut = attrs.get('statut')
        if statut in (None, ''):
            statut = getattr(self.instance, 'statut', None) or 'A_COMPLETER'
            if self.instance is None:
                attrs['statut'] = statut
        if self.instance is None and attrs.get('date_signalement') is None:
            attrs['date_signalement'] = timezone.localtime(timezone.now())
        if (
            statut == 'COMPLETE'
            and has_incoming_status
            and attrs.get('date_completion') is None
            and getattr(self.instance, 'date_completion', None) is None
        ):
            attrs['date_completion'] = timezone.localtime(timezone.now())
        if statut == 'A_COMPLETER' and has_incoming_status:
            attrs['date_completion'] = None
            attrs['id_agent_completement'] = None
        return attrs

    def update(self, instance, validated_data):
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if validated_data:
            instance.save(update_fields=list(validated_data.keys()))
        return instance


class SrmFieldOptionSerializer(StrictModelSerializer):
    class Meta:
        model = SrmFieldOption
        fields = '__all__'


class ZoneBasemapCatalogSerializer(StrictModelSerializer):
    zone_id = serializers.SerializerMethodField()
    city_slug = serializers.SerializerMethodField()
    nom = serializers.SerializerMethodField()
    bbox = serializers.SerializerMethodField()
    center = serializers.SerializerMethodField()
    geometry = serializers.SerializerMethodField()
    min_zoom = serializers.SerializerMethodField()
    max_zoom = serializers.SerializerMethodField()
    actif = serializers.SerializerMethodField()
    metadata_json = serializers.SerializerMethodField()

    class Meta:
        model = Zone
        fields = (
            'zone_id',
            'city_slug',
            'nom',
            'bbox',
            'center',
            'geometry',
            'min_zoom',
            'max_zoom',
            'actif',
            'metadata_json',
        )

    def get_zone_id(self, obj):
        return f'zone_{obj.id_zone}'

    def get_city_slug(self, obj):
        return 'oujda'

    def get_nom(self, obj):
        return obj.nom_zone

    def _geom_4326(self, obj):
        if obj.geom is None:
            return None
        geom = obj.geom
        try:
            geom = geom.clone()
            geom.transform(4326)
            return geom
        except Exception:
            return None

    def get_bbox(self, obj):
        geom = self._geom_4326(obj)
        if geom is None:
            return {'west': 0, 'south': 0, 'east': 0, 'north': 0}
        extent = geom.extent
        return {
            'west': extent[0],
            'south': extent[1],
            'east': extent[2],
            'north': extent[3],
        }

    def get_center(self, obj):
        geom = self._geom_4326(obj)
        if geom is None:
            return {'latitude': 0, 'longitude': 0}
        center = geom.point_on_surface
        return {
            'latitude': center.y,
            'longitude': center.x,
        }

    def get_geometry(self, obj):
        geom = self._geom_4326(obj)
        if geom is None:
            return None
        try:
            return json.loads(geom.json)
        except AttributeError:
            return None
        except json.JSONDecodeError:
            return None

    def get_min_zoom(self, obj):
        return 11

    def get_max_zoom(self, obj):
        return 19

    def get_actif(self, obj):
        return (obj.etat or 'active') == 'active'

    def get_metadata_json(self, obj):
        return {
            'source': 'public.zone',
            'id_zone': obj.id_zone,
            'nom_zone': obj.nom_zone,
        }


class BasemapPackageSerializer(StrictModelSerializer):
    zone_id = serializers.SerializerMethodField()
    download_url = serializers.SerializerMethodField()
    file_available = serializers.SerializerMethodField()

    class Meta:
        model = BasemapPackage
        fields = (
            'id_package',
            'id_zone',
            'zone_id',
            'city_slug',
            'style',
            'format',
            'version',
            'file_name',
            'relative_path',
            'size_bytes',
            'sha256',
            'min_zoom',
            'max_zoom',
            'generated_at',
            'source_name',
            'attribution',
            'tile_count',
            'metadata_json',
            'actif',
            'requires_wifi',
            'created_at',
            'updated_at',
            'download_url',
            'file_available',
        )

    def get_zone_id(self, obj):
        return f'zone_{obj.id_zone}'

    def get_download_url(self, obj):
        request = self.context.get('request')
        relative_path = (obj.relative_path or '').strip()
        if not request or not relative_path:
            return None

        normalized_path = relative_path.lstrip('/')
        media_url = str(settings.MEDIA_URL).rstrip('/')
        return request.build_absolute_uri(f'{media_url}/{normalized_path}')

    def get_file_available(self, obj):
        media_root = self.context.get('media_root')
        relative_path = (obj.relative_path or '').strip()
        if not media_root or not relative_path:
            return False
        return (media_root / relative_path).exists()


class MetricAgentJourSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentJour
        fields = '__all__'


class MetricAgentSemaineSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentSemaine
        fields = '__all__'


class MetricAgentMoisSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentMois
        fields = '__all__'


class MetricAgentTablePeriodSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentTablePeriod
        fields = '__all__'


class MetricAgentPeriodSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentPeriod
        fields = '__all__'


class MetricAgentResumeSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentResume
        fields = '__all__'


class MetricAgentPublicJourSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentPublicJour
        fields = '__all__'


class MetricAgentPublicSemaineSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentPublicSemaine
        fields = '__all__'


class MetricAgentPublicMoisSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentPublicMois
        fields = '__all__'


class MetricAgentPublicResumeSerializer(StrictModelSerializer):
    class Meta:
        model = MetricAgentPublicResume
        fields = '__all__'


# =====================================================================
#  SCHÉMA EP — Eau Potable (27 tables)
# =====================================================================

# ---------- Ponctuels ----------

class EpVanneSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpVanne
        geo_field = 'geom'
        fields = '__all__'


class EpVanneDeVidangeSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpVanneDeVidange
        geo_field = 'geom'
        fields = '__all__'


class EpVentouseSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpVentouse
        geo_field = 'geom'
        fields = '__all__'


class EpHydrantSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpHydrant
        geo_field = 'geom'
        fields = '__all__'


class EpBorneFontaineSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpBorneFontaine
        geo_field = 'geom'
        fields = '__all__'


class EpBorneOnepSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpBorneOnep
        geo_field = 'geom'
        fields = '__all__'


class EpBoucheClesSerializer(StrictGeoFeatureModelSerializer):
    date_leve = LenientDateField(required=False, allow_null=True)

    class Meta:
        model = EpBoucheCles
        geo_field = 'geom'
        fields = '__all__'


class EpBoucheDarrosageSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpBoucheDarrosage
        geo_field = 'geom'
        fields = '__all__'


class EpCompteurAbonneSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpCompteurAbonne
        geo_field = 'geom'
        fields = '__all__'


class EpCompteurReseauSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpCompteurReseau
        geo_field = 'geom'
        fields = '__all__'


class EpConeDeReductionSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpConeDeReduction
        geo_field = 'geom'
        fields = '__all__'


class EpCentreTamponSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpCentreTampon
        geo_field = 'geom'
        fields = '__all__'


class EpNoeudSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpNoeud
        geo_field = 'geom'
        fields = '__all__'


class EpObturateurSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpObturateur
        geo_field = 'geom'
        fields = '__all__'


class EpReducteurDePressionSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpReducteurDePression
        geo_field = 'geom'
        fields = '__all__'


class EpForageSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpForage
        geo_field = 'geom'
        fields = '__all__'


class EpPuitSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpPuit
        geo_field = 'geom'
        fields = '__all__'


class EpPompeSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpPompe
        geo_field = 'geom'
        fields = '__all__'


class EpReservoirSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpReservoir
        geo_field = 'geom'
        fields = '__all__'


class EpStationDePompageSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpStationDePompage
        geo_field = 'geom'
        fields = '__all__'


class EpRegardSerializer(StrictGeoFeatureModelSerializer):
    def validate(self, attrs):
        attrs = super().validate(attrs)

        geom = attrs.get('geom')
        x = attrs.get(
            'ep_coor_x',
            getattr(self.instance, 'ep_coor_x', None),
        )
        y = attrs.get(
            'ep_coor_y',
            getattr(self.instance, 'ep_coor_y', None),
        )
        z = attrs.get(
            'ep_coor_z',
            getattr(self.instance, 'ep_coor_z', None),
        )

        if geom is None and x is not None and y is not None:
            attrs['geom'] = Point(
                float(x),
                float(y),
                float(z if z is not None else 0.0),
                srid=26191,
            )

        return attrs

    class Meta:
        model = EpRegard
        geo_field = 'geom'
        fields = '__all__'


class EpRegardMiroirSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpRegardMiroir
        geo_field = 'geom'
        fields = '__all__'


class EpRegardEpSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpRegardEp
        geo_field = 'geom'
        fields = '__all__'


class EpAutreObjetSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpAutreObjet
        geo_field = 'geom'
        fields = '__all__'


# ---------- Linéaires ----------

class EpConduiteTerrainSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpConduiteTerrain
        geo_field = 'geom'
        fields = '__all__'


class EpConduiteBureauSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpConduiteBureau
        geo_field = 'geom'
        fields = '__all__'


class EpBranchementSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpBranchement
        geo_field = 'geom'
        fields = '__all__'


class EpTraverseSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpTraverse
        geo_field = 'geom'
        fields = '__all__'


# ---------- Surfacique ----------

class EpPlancheSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = EpPlanche
        geo_field = 'geom'
        fields = '__all__'


# =====================================================================
#  SCHÉMA ASS — Assainissement (9 tables)
# =====================================================================

class AssRegardSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = AssRegard
        geo_field = 'geom'
        fields = '__all__'


class AssRegardBranchementSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = AssRegardBranchement
        geo_field = 'geom'
        fields = '__all__'


class AssCanalisationSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = AssCanalisation
        geo_field = 'geom'
        fields = '__all__'


class AssCanalisationReutilisationSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = AssCanalisationReutilisation
        geo_field = 'geom'
        fields = '__all__'


class AssBranchementSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = AssBranchement
        geo_field = 'geom'
        fields = '__all__'


class AssBassinSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = AssBassin
        geo_field = 'geom'
        fields = '__all__'


class AssOuvrageSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = AssOuvrage
        geo_field = 'geom'
        fields = '__all__'


class AssEquipementSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = AssEquipement
        geo_field = 'geom'
        fields = '__all__'


class AssStationSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = AssStation
        geo_field = 'geom'
        fields = '__all__'


# =====================================================================
#  SCHÉMA ELEC — Électricité (11 tables)
# =====================================================================

# ---------- Ponctuels (avec géométrie) ----------

class ElecSupportSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = ElecSupport
        geo_field = 'geom'
        fields = '__all__'


class ElecPosteSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = ElecPoste
        geo_field = 'geom'
        fields = '__all__'


class ElecCoffretBtSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = ElecCoffretBt
        geo_field = 'geom'
        fields = '__all__'


class ElecNoeudRaccordSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = ElecNoeudRaccord
        geo_field = 'geom'
        fields = '__all__'


class ElecPointDesserteSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = ElecPointDesserte
        geo_field = 'geom'
        fields = '__all__'


# ---------- Attributs (sans géométrie) ----------

class ElecTransformateurSerializer(StrictModelSerializer):
    class Meta:
        model = ElecTransformateur
        fields = '__all__'


class ElecCelluleSerializer(StrictModelSerializer):
    class Meta:
        model = ElecCellule
        fields = '__all__'


class ElecDepartBtSerializer(StrictModelSerializer):
    class Meta:
        model = ElecDepartBt
        fields = '__all__'


class ElecDepartHtaSerializer(StrictModelSerializer):
    class Meta:
        model = ElecDepartHta
        fields = '__all__'


# ---------- Linéaires ----------

class ElecTronconBtSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = ElecTronconBt
        geo_field = 'geom'
        fields = '__all__'


class ElecTronconHtaSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = ElecTronconHta
        geo_field = 'geom'
        fields = '__all__'

