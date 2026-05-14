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
    SrmFieldOption,
    MetricAgentJour, MetricAgentSemaine, MetricAgentMois,
    MetricAgentTablePeriod, MetricAgentPeriod, MetricAgentResume,
    MetricAgentPublicJour, MetricAgentPublicSemaine, MetricAgentPublicMois, MetricAgentPublicResume,
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
    allowed_photo_contexts = {
        'collecte_initiale',
        'anomalie_avant',
        'retour_terrain_apres',
        'incomplet_initial',
        'incomplet_complement',
    }

    schema_name = serializers.CharField(max_length=20, trim_whitespace=True)
    table_name = serializers.CharField(max_length=100, trim_whitespace=True)
    uuid_objet = serializers.CharField(max_length=254, trim_whitespace=True)
    photo_slot = serializers.IntegerField(min_value=1, max_value=4)
    photo_context = serializers.CharField(
        max_length=40,
        required=False,
        allow_blank=True,
        allow_null=True,
        trim_whitespace=True,
    )
    contexte_photo = serializers.CharField(
        max_length=40,
        required=False,
        allow_blank=True,
        allow_null=True,
        trim_whitespace=True,
    )
    id_intervention_anomalie = serializers.IntegerField(
        required=False,
        allow_null=True,
        min_value=0,
    )
    endpoint = serializers.CharField(
        max_length=120,
        required=False,
        allow_blank=True,
        allow_null=True,
        trim_whitespace=True,
    )
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

    def validate(self, attrs):
        context = (
            attrs.pop('photo_context', None)
            or attrs.pop('contexte_photo', None)
            or 'collecte_initiale'
        )
        context = str(context).strip().lower() or 'collecte_initiale'
        if context not in self.allowed_photo_contexts:
            raise serializers.ValidationError({
                'photo_context': 'Contexte photo non autorise'
            })
        attrs['photo_context'] = context
        attrs['id_intervention_anomalie'] = attrs.get(
            'id_intervention_anomalie'
        ) or 0
        return attrs

    def _has_allowed_signature(self, extension, header):
        if extension in ('.jpg', '.jpeg'):
            return header.startswith(b'\xff\xd8\xff')
        if extension == '.png':
            return header.startswith(b'\x89PNG\r\n\x1a\n')
        if extension == '.webp':
            return (
                len(header) >= 12
                and header[:4] == b'RIFF'
                and header[8:12] == b'WEBP'
            )
        if extension in ('.heic', '.heif'):
            return b'ftyp' in header[:16] and any(
                brand in header[:32]
                for brand in (
                    b'heic',
                    b'heix',
                    b'hevc',
                    b'hevx',
                    b'heif',
                    b'mif1',
                    b'msf1',
                )
            )
        return False

    def _read_tail(self, value, size, byte_count):
        try:
            position = value.tell()
        except (AttributeError, OSError):
            position = None
        try:
            value.seek(max(size - byte_count, 0))
            tail = value.read(byte_count)
        finally:
            try:
                value.seek(position or 0)
            except (AttributeError, OSError):
                pass
        return tail

    def _assert_file_complete(self, extension, value, size, header):
        if extension in ('.jpg', '.jpeg'):
            if not self._read_tail(value, size, 2).endswith(b'\xff\xd9'):
                raise serializers.ValidationError(
                    'Photo JPG incomplete ou corrompue'
                )
            return

        if extension == '.png':
            png_iend = b'\x00\x00\x00\x00IEND\xaeB`\x82'
            if not self._read_tail(value, size, len(png_iend)).endswith(png_iend):
                raise serializers.ValidationError(
                    'Photo PNG incomplete ou corrompue'
                )
            return

        if extension == '.webp':
            if len(header) < 12:
                raise serializers.ValidationError(
                    'Photo WEBP incomplete ou corrompue'
                )
            riff_payload_size = int.from_bytes(header[4:8], byteorder='little')
            if riff_payload_size + 8 > size:
                raise serializers.ValidationError(
                    'Photo WEBP incomplete ou corrompue'
                )
            return

        if extension in ('.heic', '.heif') and size < 32:
            raise serializers.ValidationError(
                'Photo HEIC incomplete ou corrompue'
            )

    def validate_file(self, value):
        file_name = getattr(value, 'name', '') or ''
        lowered = file_name.lower()
        extension = next(
            (ext for ext in self.allowed_photo_extensions if lowered.endswith(ext)),
            None,
        )
        if extension is None:
            raise serializers.ValidationError(
                'Extension photo non autorisée (jpg, jpeg, png, webp, heic, heif)'
            )

        if getattr(value, 'size', 0) <= 0:
            raise serializers.ValidationError('Fichier photo vide')

        if value.size > self.max_photo_bytes:
            raise serializers.ValidationError('Photo trop volumineuse (maximum 5 Mo)')

        try:
            position = value.tell()
        except (AttributeError, OSError):
            position = None
        header = value.read(32)
        try:
            value.seek(position or 0)
        except (AttributeError, OSError):
            pass

        if not self._has_allowed_signature(extension, header):
            raise serializers.ValidationError('Signature fichier photo invalide')

        self._assert_file_complete(extension, value, value.size, header)
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
            'etat_exploitant',
            'commentaire_exploitant',
            'date_exploitant',
            'etat_terrain',
            'commentaire_terrain',
            'date_terrain',
            'id_user_terrain',
            'etat_bureau',
            'commentaire_bureau',
            'date_bureau',
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
            'etat_exploitant',
            'commentaire_exploitant',
            'date_exploitant',
            'etat_bureau',
            'commentaire_bureau',
            'date_bureau',
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
        if obj.code_provi == '02.381.':
            return 'Province de Nador'
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


class ListeChoixAsFieldOptionSerializer(serializers.Serializer):
    """Projette une ligne public.liste_choix au format attendu par le mobile
    (compatible avec l'ancien endpoint base sur public.srm_field_option).
    """
    id_option = serializers.IntegerField(source='id', read_only=True)
    table_schema = serializers.CharField(source='nom_metier', read_only=True)
    table_name = serializers.CharField(source='nom_table', read_only=True)
    field_name = serializers.CharField(source='nom_champ', read_only=True)
    code_value = serializers.CharField(source='liste_choix_valeur', read_only=True)
    label_value = serializers.SerializerMethodField()
    display_order = serializers.SerializerMethodField()
    actif = serializers.SerializerMethodField()
    created_at = serializers.SerializerMethodField()

    def get_label_value(self, obj):
        alias = (obj.liste_choix_alias or '').strip()
        if alias:
            return alias
        # Fallback : la valeur brute, comme srm_field_option historique.
        return (obj.liste_choix_valeur or '').strip()

    def get_display_order(self, obj):
        return obj.liste_choix_ordre or 0

    def get_actif(self, obj):
        # liste_choix_actif peut etre NULL : on considere actif par defaut.
        return obj.liste_choix_actif if obj.liste_choix_actif is not None else True

    def get_created_at(self, obj):
        return None


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
