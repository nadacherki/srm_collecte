"""
Serializers GeoJSON pour SRM Collecte — COMPLET (55 modèles).

Utilise GeoFeatureModelSerializer de DRF-GIS pour les tables avec géométrie.
Utilise ModelSerializer standard pour les tables sans géométrie.
Les données spatiales sont sérialisées en GeoJSON (RFC 7946) avec SRID 26191.
"""

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


# =====================================================================
#  SCHÉMA PUBLIC
# =====================================================================

class UtilisateurSerializer(serializers.ModelSerializer):
    class Meta:
        model = Utilisateur
        fields = '__all__'


class ProjetSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = Projet
        geo_field = 'geom_zone'
        fields = '__all__'


class MissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Mission
        fields = '__all__'


class CommuneSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = Commune
        geo_field = 'geom'
        fields = '__all__'


class HistoriqueAttributSerializer(serializers.ModelSerializer):
    class Meta:
        model = HistoriqueAttribut
        fields = '__all__'


class ObjetIncompletSerializer(serializers.ModelSerializer):
    class Meta:
        model = ObjetIncomplet
        fields = '__all__'


class FondDePlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = FondDePlan
        fields = '__all__'


class EvaluationAgentSerializer(serializers.ModelSerializer):
    class Meta:
        model = EvaluationAgent
        fields = '__all__'


# =====================================================================
#  SCHÉMA EP — Eau Potable (27 tables)
# =====================================================================

# ---------- Ponctuels ----------

class EpVanneSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpVanne
        geo_field = 'geom'
        fields = '__all__'


class EpVanneDeVidangeSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpVanneDeVidange
        geo_field = 'geom'
        fields = '__all__'


class EpVentouseSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpVentouse
        geo_field = 'geom'
        fields = '__all__'


class EpHydrantSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpHydrant
        geo_field = 'geom'
        fields = '__all__'


class EpBorneFontaineSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpBorneFontaine
        geo_field = 'geom'
        fields = '__all__'


class EpBorneOnepSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpBorneOnep
        geo_field = 'geom'
        fields = '__all__'


class EpBoucheClesSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpBoucheCles
        geo_field = 'geom'
        fields = '__all__'


class EpBoucheDarrosageSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpBoucheDarrosage
        geo_field = 'geom'
        fields = '__all__'


class EpCompteurAbonneSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpCompteurAbonne
        geo_field = 'geom'
        fields = '__all__'


class EpCompteurReseauSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpCompteurReseau
        geo_field = 'geom'
        fields = '__all__'


class EpConeDeReductionSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpConeDeReduction
        geo_field = 'geom'
        fields = '__all__'


class EpCentreTamponSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpCentreTampon
        geo_field = 'geom'
        fields = '__all__'


class EpNoeudSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpNoeud
        geo_field = 'geom'
        fields = '__all__'


class EpObturateurSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpObturateur
        geo_field = 'geom'
        fields = '__all__'


class EpReducteurDePressionSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpReducteurDePression
        geo_field = 'geom'
        fields = '__all__'


class EpForageSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpForage
        geo_field = 'geom'
        fields = '__all__'


class EpPuitSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpPuit
        geo_field = 'geom'
        fields = '__all__'


class EpPompeSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpPompe
        geo_field = 'geom'
        fields = '__all__'


class EpReservoirSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpReservoir
        geo_field = 'geom'
        fields = '__all__'


class EpStationDePompageSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpStationDePompage
        geo_field = 'geom'
        fields = '__all__'


class EpRegardEpSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpRegardEp
        geo_field = 'geom'
        fields = '__all__'


class EpAutreObjetSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpAutreObjet
        geo_field = 'geom'
        fields = '__all__'


# ---------- Linéaires ----------

class EpConduiteTerrainSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpConduiteTerrain
        geo_field = 'geom'
        fields = '__all__'


class EpConduiteBureauSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpConduiteBureau
        geo_field = 'geom'
        fields = '__all__'


class EpBranchementSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpBranchement
        geo_field = 'geom'
        fields = '__all__'


class EpTraverseSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpTraverse
        geo_field = 'geom'
        fields = '__all__'


# ---------- Surfacique ----------

class EpPlancheSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = EpPlanche
        geo_field = 'geom'
        fields = '__all__'


# =====================================================================
#  SCHÉMA ASS — Assainissement (9 tables)
# =====================================================================

class AssRegardSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AssRegard
        geo_field = 'geom'
        fields = '__all__'


class AssRegardBranchementSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AssRegardBranchement
        geo_field = 'geom'
        fields = '__all__'


class AssCanalisationSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AssCanalisation
        geo_field = 'geom'
        fields = '__all__'


class AssCanalisationReutilisationSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AssCanalisationReutilisation
        geo_field = 'geom'
        fields = '__all__'


class AssBranchementSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AssBranchement
        geo_field = 'geom'
        fields = '__all__'


class AssBassinSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AssBassin
        geo_field = 'geom'
        fields = '__all__'


class AssOuvrageSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AssOuvrage
        geo_field = 'geom'
        fields = '__all__'


class AssEquipementSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AssEquipement
        geo_field = 'geom'
        fields = '__all__'


class AssStationSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = AssStation
        geo_field = 'geom'
        fields = '__all__'


# =====================================================================
#  SCHÉMA ELEC — Électricité (11 tables)
# =====================================================================

# ---------- Ponctuels (avec géométrie) ----------

class ElecSupportSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = ElecSupport
        geo_field = 'geom'
        fields = '__all__'


class ElecPosteSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = ElecPoste
        geo_field = 'geom'
        fields = '__all__'


class ElecCoffretBtSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = ElecCoffretBt
        geo_field = 'geom'
        fields = '__all__'


class ElecNoeudRaccordSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = ElecNoeudRaccord
        geo_field = 'geom'
        fields = '__all__'


class ElecPointDesserteSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = ElecPointDesserte
        geo_field = 'geom'
        fields = '__all__'


# ---------- Attributs (sans géométrie) ----------

class ElecTransformateurSerializer(serializers.ModelSerializer):
    class Meta:
        model = ElecTransformateur
        fields = '__all__'


class ElecCelluleSerializer(serializers.ModelSerializer):
    class Meta:
        model = ElecCellule
        fields = '__all__'


class ElecDepartBtSerializer(serializers.ModelSerializer):
    class Meta:
        model = ElecDepartBt
        fields = '__all__'


class ElecDepartHtaSerializer(serializers.ModelSerializer):
    class Meta:
        model = ElecDepartHta
        fields = '__all__'


# ---------- Linéaires ----------

class ElecTronconBtSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = ElecTronconBt
        geo_field = 'geom'
        fields = '__all__'


class ElecTronconHtaSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = ElecTronconHta
        geo_field = 'geom'
        fields = '__all__'
