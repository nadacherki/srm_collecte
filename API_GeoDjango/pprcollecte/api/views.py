"""
Vues API pour SRM Collecte — COMPLET (55 modèles).

Chaque ViewSet filtre par id_projet et id_mission via query params.
Le login vérifie le mot de passe hashé PBKDF2 via Django.
"""

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.hashers import check_password, make_password
from rest_framework import viewsets
from rest_framework.decorators import api_view
import json

from .models import (
    Utilisateur, Projet, Mission, Commune,
    HistoriqueAttribut, ObjetIncomplet, FondDePlan, EvaluationAgent,
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
    HistoriqueAttributSerializer, ObjetIncompletSerializer,
    FondDePlanSerializer, EvaluationAgentSerializer,
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
)


# =====================================================================
#  MIXIN : Filtrage par projet et mission (réutilisé par tous les ViewSets)
# =====================================================================

class ProjetMissionFilterMixin:
    """
    Filtre automatiquement le queryset par id_projet et id_mission
    si ces paramètres sont passés dans l'URL (?id_projet=1&id_mission=5).
    """
    def get_queryset(self):
        qs = super().get_queryset()
        id_projet = self.request.query_params.get('id_projet')
        id_mission = self.request.query_params.get('id_mission')
        id_agent = self.request.query_params.get('id_agent_crea')
        if id_projet:
            qs = qs.filter(id_projet=int(id_projet))
        if id_mission:
            qs = qs.filter(id_mission=int(id_mission))
        if id_agent:
            qs = qs.filter(id_agent_crea=int(id_agent))
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
    """
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({'error': 'Corps de la requête invalide (JSON attendu)'}, status=400)

    login_val = data.get('login', '').strip()
    mot_de_passe = data.get('mot_de_passe', '').strip()

    if not login_val or not mot_de_passe:
        return JsonResponse({'error': 'Login et mot de passe requis'}, status=400)

    try:
        user = Utilisateur.objects.get(login=login_val)
    except Utilisateur.DoesNotExist:
        return JsonResponse({'error': 'Login ou mot de passe incorrect'}, status=401)

    if not user.actif:
        return JsonResponse({'error': 'Compte désactivé. Contactez votre administrateur.'}, status=403)

    if not user.mot_de_passe_hash:
        return JsonResponse({'error': 'Aucun mot de passe configuré pour ce compte'}, status=401)

    if not check_password(mot_de_passe, user.mot_de_passe_hash):
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

    from django.utils import timezone
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


# =====================================================================
#  PUBLIC
# =====================================================================

class ProjetViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Projet.objects.all()
    serializer_class = ProjetSerializer


class MissionViewSet(viewsets.ModelViewSet):
    queryset = Mission.objects.all()
    serializer_class = MissionSerializer

    def get_queryset(self):
        qs = Mission.objects.all()
        id_agent = self.request.query_params.get('id_agent')
        id_projet = self.request.query_params.get('id_projet')
        if id_agent:
            qs = qs.filter(id_agent=int(id_agent))
        if id_projet:
            qs = qs.filter(id_projet=int(id_projet))
        return qs.order_by('-id_mission')


class CommuneViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Commune.objects.all()
    serializer_class = CommuneSerializer


class HistoriqueAttributViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = HistoriqueAttribut.objects.all()
    serializer_class = HistoriqueAttributSerializer


class ObjetIncompletViewSet(ProjetMissionFilterMixin, viewsets.ModelViewSet):
    queryset = ObjetIncomplet.objects.all()
    serializer_class = ObjetIncompletSerializer


class FondDePlanViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = FondDePlan.objects.all()
    serializer_class = FondDePlanSerializer

    def get_queryset(self):
        qs = FondDePlan.objects.all()
        id_projet = self.request.query_params.get('id_projet')
        if id_projet:
            qs = qs.filter(id_projet=int(id_projet))
        return qs


class EvaluationAgentViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = EvaluationAgent.objects.all()
    serializer_class = EvaluationAgentSerializer


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
