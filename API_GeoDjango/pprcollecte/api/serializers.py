"""
Serializers GeoJSON pour SRM Collecte â€” COMPLET (55 modÃ¨les).

Utilise GeoFeatureModelSerializer de DRF-GIS pour les tables avec gÃ©omÃ©trie.
Utilise ModelSerializer standard pour les tables sans gÃ©omÃ©trie.
Les donnÃ©es spatiales sont sÃ©rialisÃ©es en GeoJSON (RFC 7946) avec SRID 26191.
"""

import math
from urllib.parse import urlparse

from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer

from .models import (
    # Public
    Utilisateur, Projet, Mission, Commune,
    HistoriqueAttribut, ObjetIncomplet, FondDePlan, EvaluationAgent,
    # EP ponctuels
    EpVanne, EpVanneDeVidange, EpVentouse, EpHydrant,
    EpBorneFontaine, EpBorneOnep, EpBoucheCles, EpBoucheDarrosage,
    EpCompteurAbonne, EpCompteurReseau, EpConeDeReduction, EpCentreTampon,
    EpNoeud, EpObturateur, EpReducteurDePression,
    EpForage, EpPuit, EpPompe, EpReservoir, EpStationDePompage,
    EpRegardEp, EpAutreObjet,
    # EP linÃ©aires + surfacique
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
            if isinstance(value, str):
                stripped = value.strip()
                if any(ord(char) < 32 and char not in '\t\n\r' for char in stripped):
                    errors[key] = 'Caracteres de controle non autorises'
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
                errors[field_name] = f'Maximum {max_length} caracteres'

        if errors:
            raise serializers.ValidationError(errors)

        return validated

    def validate(self, attrs):
        errors = {}

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
                errors[field_name] = 'Coordonnee numerique invalide'

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
            errors['geom'] = 'Geometrie vide non autorisee'

        lat_start = attrs.get('lat_debut')
        lon_start = attrs.get('lon_debut')
        lat_end = attrs.get('lat_fin')
        lon_end = attrs.get('lon_fin')
        if ((lat_start is None) != (lon_start is None)):
            errors['lat_debut'] = 'lat_debut et lon_debut doivent etre fournis ensemble'
        if ((lat_end is None) != (lon_end is None)):
            errors['lat_fin'] = 'lat_fin et lon_fin doivent etre fournis ensemble'

        if errors:
            raise serializers.ValidationError(errors)

        return super().validate(attrs)

    def _is_finite_number(self, value):
        try:
            return math.isfinite(float(value))
        except (TypeError, ValueError):
            return False

    def _validate_photo_reference(self, value):
        normalized = value.strip()
        lowered = normalized.lower()
        if lowered.startswith(('javascript:', 'data:')):
            return 'Format de photo non autorise'

        if '\x00' in normalized:
            return 'Reference photo invalide'

        parsed = urlparse(normalized)
        if parsed.scheme and parsed.scheme not in ('http', 'https', 'file', 'content'):
            return 'Scheme photo non autorise'

        candidate_path = parsed.path or normalized
        if '/../' in candidate_path or '\\..\\' in candidate_path:
            return 'Reference photo invalide'

        if not self._has_allowed_photo_extension(candidate_path):
            return (
                'Extension photo non autorisee '
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


class LoginRequestSerializer(serializers.Serializer):
    login = serializers.CharField(max_length=100, trim_whitespace=True)
    mot_de_passe = serializers.CharField(max_length=255, trim_whitespace=True)

# =====================================================================
#  SCHÃ‰MA PUBLIC
# =====================================================================

class UtilisateurSerializer(StrictModelSerializer):
    class Meta:
        model = Utilisateur
        fields = '__all__'


class ProjetSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = Projet
        geo_field = 'geom_zone'
        fields = '__all__'


class MissionSerializer(StrictModelSerializer):
    class Meta:
        model = Mission
        fields = '__all__'


class CommuneSerializer(StrictGeoFeatureModelSerializer):
    class Meta:
        model = Commune
        geo_field = 'geom'
        fields = '__all__'


class HistoriqueAttributSerializer(StrictModelSerializer):
    class Meta:
        model = HistoriqueAttribut
        fields = '__all__'


class ObjetIncompletSerializer(StrictModelSerializer):
    class Meta:
        model = ObjetIncomplet
        fields = '__all__'


class FondDePlanSerializer(StrictModelSerializer):
    class Meta:
        model = FondDePlan
        fields = '__all__'


class EvaluationAgentSerializer(StrictModelSerializer):
    class Meta:
        model = EvaluationAgent
        fields = '__all__'


# =====================================================================
#  SCHÃ‰MA EP â€” Eau Potable (27 tables)
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


# ---------- LinÃ©aires ----------

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
#  SCHÃ‰MA ASS â€” Assainissement (9 tables)
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
#  SCHÃ‰MA ELEC â€” Ã‰lectricitÃ© (11 tables)
# =====================================================================

# ---------- Ponctuels (avec gÃ©omÃ©trie) ----------

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


# ---------- Attributs (sans gÃ©omÃ©trie) ----------

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


# ---------- LinÃ©aires ----------

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

