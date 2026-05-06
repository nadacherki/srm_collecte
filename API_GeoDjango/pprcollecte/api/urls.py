"""
URLs API pour SRM Collecte.

Organisation :
  /api/login/                           → Authentification
  /api/communes/                        → Communes
  /api/historique-actions/               → Journal des modifications
  /api/objets-incomplets/               → Objets non collectés
  /api/evaluations/                     → Évaluations agents

  /api/ep/vannes/                       → Vannes EP
  /api/ep/vannes-vidange/               → Vannes de vidange EP
  /api/ep/ventouses/                    → Ventouses EP
  /api/ep/hydrants/                     → Hydrants EP
  /api/ep/bornes-fontaine/              → Bornes fontaine EP
  /api/ep/bornes-onep/                  → Bornes ONEP EP
  /api/ep/bouches-cles/                 → Bouches à clés EP
  /api/ep/bouches-arrosage/             → Bouches d'arrosage EP
  /api/ep/compteurs-abonne/             → Compteurs abonné EP
  /api/ep/compteurs-reseau/             → Compteurs réseau EP
  /api/ep/cones-reduction/              → Cônes de réduction EP
  /api/ep/centres-tampon/               → Centres tampon EP
  /api/ep/noeuds/                       → Noeuds EP
  /api/ep/obturateurs/                  → Obturateurs EP
  /api/ep/reducteurs-pression/          → Réducteurs de pression EP
  /api/ep/forages/                      → Forages EP
  /api/ep/puits/                        → Puits EP
  /api/ep/pompes/                       → Pompes EP
  /api/ep/reservoirs/                   → Réservoirs EP
  /api/ep/stations-pompage/             → Stations de pompage EP
  /api/ep/regards/                      → Regards EP
  /api/ep/autres-objets/                → Autres objets EP
  /api/ep/conduites-terrain/            → Conduites terrain EP
  /api/ep/conduites-bureau/             → Conduites bureau EP
  /api/ep/branchements/                 → Branchements EP
  /api/ep/traverses/                    → Traversées EP
  /api/ass/regards/                     → Regards ASS
  /api/ass/regards-branchement/         → Regards branchement ASS
  /api/ass/canalisations/               → Canalisations ASS
  /api/ass/canalisations-reutilisation/ → Canalisations réutilisation ASS
  /api/ass/branchements/                → Branchements ASS
  /api/ass/bassins/                     → Bassins ASS
  /api/ass/ouvrages/                    → Ouvrages ASS
  /api/ass/equipements/                 → Équipements ASS
  /api/ass/stations/                    → Stations ASS

"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()

# =====================================================================
#  PUBLIC (8 endpoints)
# =====================================================================
router.register(r'communes-oriental', views.CommuneViewSet, basename='commune-oriental')
router.register(r'communes', views.CommuneViewSet, basename='commune')
router.register(r'zones', views.ZoneViewSet, basename='zone')
router.register(r'zone-utilisateurs', views.ZoneUtilisateurViewSet, basename='zone-utilisateur')
router.register(r'historique-actions', views.HistoriqueActionViewSet, basename='historique-action')
router.register(r'objets-incomplets', views.ObjetIncompletViewSet, basename='objet-incomplet')
router.register(r'objets-photos', views.ObjetPhotoViewSet, basename='objet-photo')
router.register(r'interventions-anomalies-terrain', views.InterventionAnomalieTerrainViewSet, basename='intervention-anomalie-terrain')
router.register(r'srm-field-options', views.SrmFieldOptionViewSet, basename='srm-field-option')
router.register(r'metrics-agent-jour', views.MetricAgentJourViewSet, basename='metrics-agent-jour')
router.register(r'metrics-agent-semaine', views.MetricAgentSemaineViewSet, basename='metrics-agent-semaine')
router.register(r'metrics-agent-mois', views.MetricAgentMoisViewSet, basename='metrics-agent-mois')
router.register(r'metrics-agent-table-period', views.MetricAgentTablePeriodViewSet, basename='metrics-agent-table-period')
router.register(r'metrics-agent-period', views.MetricAgentPeriodViewSet, basename='metrics-agent-period')
router.register(r'metrics-agent-resume', views.MetricAgentResumeViewSet, basename='metrics-agent-resume')
router.register(r'metrics-agent-public-jour', views.MetricAgentPublicJourViewSet, basename='metrics-agent-public-jour')
router.register(r'metrics-agent-public-semaine', views.MetricAgentPublicSemaineViewSet, basename='metrics-agent-public-semaine')
router.register(r'metrics-agent-public-mois', views.MetricAgentPublicMoisViewSet, basename='metrics-agent-public-mois')
router.register(r'metrics-agent-public-resume', views.MetricAgentPublicResumeViewSet, basename='metrics-agent-public-resume')

# =====================================================================
#  EP — Eau Potable (27 endpoints)
# =====================================================================
router.register(r'ep/vannes', views.EpVanneViewSet, basename='ep-vanne')
router.register(r'ep/vannes-vidange', views.EpVanneDeVidangeViewSet, basename='ep-vanne-vidange')
router.register(r'ep/ventouses', views.EpVentouseViewSet, basename='ep-ventouse')
router.register(r'ep/hydrants', views.EpHydrantViewSet, basename='ep-hydrant')
router.register(r'ep/bornes-fontaine', views.EpBorneFontaineViewSet, basename='ep-borne-fontaine')
router.register(r'ep/bornes-onep', views.EpBorneOnepViewSet, basename='ep-borne-onep')
router.register(r'ep/bouches-cles', views.EpBoucheClesViewSet, basename='ep-bouche-cles')
router.register(r'ep/bouches-arrosage', views.EpBoucheDarrosageViewSet, basename='ep-bouche-arrosage')
router.register(r'ep/compteurs-abonne', views.EpCompteurAbonneViewSet, basename='ep-compteur-abonne')
router.register(r'ep/compteurs-reseau', views.EpCompteurReseauViewSet, basename='ep-compteur-reseau')
router.register(r'ep/cones-reduction', views.EpConeDeReductionViewSet, basename='ep-cone-reduction')
router.register(r'ep/centres-tampon', views.EpCentreTamponViewSet, basename='ep-centre-tampon')
router.register(r'ep/noeuds', views.EpNoeudViewSet, basename='ep-noeud')
router.register(r'ep/obturateurs', views.EpObturateurViewSet, basename='ep-obturateur')
router.register(r'ep/reducteurs-pression', views.EpReducteurDePressionViewSet, basename='ep-reducteur-pression')
router.register(r'ep/forages', views.EpForageViewSet, basename='ep-forage')
router.register(r'ep/puits', views.EpPuitViewSet, basename='ep-puit')
router.register(r'ep/pompes', views.EpPompeViewSet, basename='ep-pompe')
router.register(r'ep/reservoirs', views.EpReservoirViewSet, basename='ep-reservoir')
router.register(r'ep/stations-pompage', views.EpStationDePompageViewSet, basename='ep-station-pompage')
router.register(r'ep/regards', views.EpRegardViewSet, basename='ep-regard')
router.register(r'ep/regards-miroir', views.EpRegardMiroirViewSet, basename='ep-regard-miroir')
router.register(r'ep/autres-objets', views.EpAutreObjetViewSet, basename='ep-autre-objet')
router.register(r'ep/conduites-terrain', views.EpConduiteTerrainViewSet, basename='ep-conduite-terrain')
router.register(r'ep/conduites-bureau', views.EpConduiteBureauViewSet, basename='ep-conduite-bureau')
router.register(r'ep/branchements', views.EpBranchementViewSet, basename='ep-branchement')
router.register(r'ep/traverses', views.EpTraverseViewSet, basename='ep-traverse')

# =====================================================================
#  ASS — Assainissement (9 endpoints)
# =====================================================================
router.register(r'ass/regards', views.AssRegardViewSet, basename='ass-regard')
router.register(r'ass/regards-branchement', views.AssRegardBranchementViewSet, basename='ass-regard-branchement')
router.register(r'ass/canalisations', views.AssCanalisationViewSet, basename='ass-canalisation')
router.register(r'ass/canalisations-reutilisation', views.AssCanalisationReutilisationViewSet, basename='ass-canalisation-reutilisation')
router.register(r'ass/branchements', views.AssBranchementViewSet, basename='ass-branchement')
router.register(r'ass/bassins', views.AssBassinViewSet, basename='ass-bassin')
router.register(r'ass/ouvrages', views.AssOuvrageViewSet, basename='ass-ouvrage')
router.register(r'ass/equipements', views.AssEquipementViewSet, basename='ass-equipement')
router.register(r'ass/stations', views.AssStationViewSet, basename='ass-station')

# =====================================================================
#  URL PATTERNS
# =====================================================================
mobile_srm_urlpatterns = [
    path(
        f'api/{endpoint}/',
        views.mobile_srm_table_view,
        {'endpoint': endpoint},
        name=f"mobile-srm-{endpoint.replace('/', '-')}",
    )
    for endpoint in views.MOBILE_SRM_TABLE_ENDPOINTS
]

urlpatterns = [
    # Login (vue fonction, pas un ViewSet)
    path('api/login/', views.login_view, name='login'),
    path('api/basemaps/region/manifest/', views.regional_basemap_manifest_view, name='basemap-regional-manifest'),
    path('api/basemaps/region/download/', views.regional_basemap_download_view, name='basemap-regional-download'),
    path('api/statistiques-conduite/jour/', views.statistique_conduite_jour_view, name='statistique-conduite-jour'),
    path('api/statistiques-conduite/valider/', views.statistique_conduite_validate_view, name='statistique-conduite-valider'),
    path('api/attribut-config-mobile/', views.attribut_config_mobile_view, name='attribut-config-mobile'),
    path('api/sync/manifest/', views.sync_manifest_view, name='sync-manifest'),
    path('api/sync/session/<str:sync_uuid>/', views.sync_session_status_view, name='sync-session-status'),
    path('api/photos/upload/', views.photo_upload_view, name='photo-upload'),

    # Routes metier mobiles branchees sur les tables SRM_bureau reelles.
    *mobile_srm_urlpatterns,

    # Toutes les routes du router sous /api/
    path('api/', include(router.urls)),
]
