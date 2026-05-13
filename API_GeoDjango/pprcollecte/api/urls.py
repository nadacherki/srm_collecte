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

# EP/ASS metier routes are served by mobile_srm_urlpatterns below.
# Do not register the legacy DRF ModelViewSets here: their unmanaged models can
# drift from physical client schemas, while mobile_srm_table_view reads the live
# columns directly and is the canonical API surface for the mobile app.

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
    path('api/orthophotos/agent/manifest/', views.orthophoto_agent_manifest_view, name='orthophoto-agent-manifest'),
    path('api/orthophotos/agent/tiles/', views.orthophoto_agent_tiles_view, name='orthophoto-agent-tiles'),
    path('api/orthophotos/<str:ortho_id>/tiles/<int:z>/<int:x>/<int:y>.<str:tile_format>', views.orthophoto_tile_view, name='orthophoto-tile'),
    path('api/reference-overlays/planches/', views.reference_planches_overlay_view, name='reference-overlays-planches'),
    path('api/reference-overlays/fond-plan/', views.reference_fond_plan_overlay_view, name='reference-overlays-fond-plan'),
    path('api/statistiques-conduite/jour/', views.statistique_conduite_jour_view, name='statistique-conduite-jour'),
    path('api/statistiques-conduite/valider/', views.statistique_conduite_validate_view, name='statistique-conduite-valider'),
    path('api/attribut-config-mobile/schema-preview/', views.attribut_config_mobile_schema_preview_view, name='attribut-config-mobile-schema-preview'),
    path('api/attribut-config-mobile/', views.attribut_config_mobile_view, name='attribut-config-mobile'),
    path('api/formulaire-config-mobile/', views.formulaire_config_mobile_view, name='formulaire-config-mobile'),
    path('api/mobile-export-manifest/', views.mobile_export_manifest_view, name='mobile-export-manifest'),
    path('api/ep/onep-db/', views.onep_db_mobile_view, name='onep-db-mobile'),
    path('api/ep/compteurs-abonne/customer-link/', views.ep_compteur_abonne_customer_link_view, name='ep-compteur-abonne-customer-link'),
    path('api/ep/compteurs-abonne/commune-audit/', views.ep_compteur_abonne_commune_audit_view, name='ep-compteur-abonne-commune-audit'),
    path('api/sync/manifest/', views.sync_manifest_view, name='sync-manifest'),
    path('api/sync/session/<str:sync_uuid>/', views.sync_session_status_view, name='sync-session-status'),
    path('api/photos/upload/', views.photo_upload_view, name='photo-upload'),

    # Routes metier mobiles branchees sur les tables SRM_bureau reelles.
    *mobile_srm_urlpatterns,

    # Toutes les routes du router sous /api/
    path('api/', include(router.urls)),
]
