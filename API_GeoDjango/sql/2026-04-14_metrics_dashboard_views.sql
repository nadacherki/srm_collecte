BEGIN;

DROP VIEW IF EXISTS public.vw_metrics_projet_resume;
DROP VIEW IF EXISTS public.vw_metrics_projet_mois;
DROP VIEW IF EXISTS public.vw_metrics_projet_semaine;
DROP VIEW IF EXISTS public.vw_metrics_projet_jour;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_resume;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_mois;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_semaine;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_jour;
DROP VIEW IF EXISTS public.vw_srm_mission_fact;

CREATE VIEW public.vw_srm_mission_fact AS
SELECT
    md5(concat_ws('|', 'mission', m.id_mission::text)) AS mission_uid,
    m.id_mission,
    m.id_agent,
    m.id_projet,
    COALESCE(m.date_debut, m.heure_debut::date, m.date_fin, m.heure_fin::date) AS jour_mission,
    m.heure_debut,
    m.heure_fin,
    m.date_debut,
    m.date_fin,
    m.etat_mission,
    COALESCE(m.nb_objets_collectes, 0)::bigint AS nb_objets_collectes,
    COALESCE(m.nb_objets_incomplets, 0)::bigint AS nb_objets_incomplets,
    COALESCE(m.nb_photos_prises, 0)::bigint AS nb_photos_prises,
    CASE
        WHEN m.heure_debut IS NOT NULL
         AND m.heure_fin IS NOT NULL
         AND m.heure_fin >= m.heure_debut
            THEN ROUND((EXTRACT(EPOCH FROM (m.heure_fin - m.heure_debut)) / 3600.0)::numeric, 2)::double precision
        ELSE NULL::double precision
    END AS duree_mission_heures,
    CASE
        WHEN m.heure_fin IS NOT NULL
          OR m.date_fin IS NOT NULL
          OR COALESCE(m.etat_mission, '') IN ('TERMINEE', 'TERMINE', 'CLOTUREE', 'CLOTURE', 'CLOSED')
            THEN true
        ELSE false
    END AS mission_cloturee
FROM public.mission m;

CREATE VIEW public.vw_metrics_agent_public_jour AS
WITH agent_base AS (
    SELECT
        m.jour,
        m.id_agent,
        m.id_projet,
        COALESCE(SUM(m.nb_objets_crees), 0)::bigint AS nb_objets_crees,
        COALESCE(SUM(m.nb_objets_crees) FILTER (WHERE m.famille_geometrie = 'POINT'), 0)::bigint AS nb_points,
        COALESCE(SUM(m.nb_objets_crees) FILTER (WHERE m.famille_geometrie = 'LIGNE'), 0)::bigint AS nb_lignes,
        COALESCE(SUM(m.nb_objets_crees) FILTER (WHERE m.famille_geometrie = 'SURFACE'), 0)::bigint AS nb_surfaces,
        COALESCE(SUM(m.nb_objets_anomalie), 0)::bigint AS nb_objets_anomalie,
        COALESCE(SUM(m.nb_objets_avec_photo), 0)::bigint AS nb_objets_avec_photo,
        COALESCE(SUM(m.nb_photos_renseignees), 0)::bigint AS nb_photos_renseignees,
        COALESCE(SUM(m.nb_photos_uploadees), 0)::bigint AS nb_photos_uploadees,
        COALESCE(SUM(m.nb_objets_incomplets_signales), 0)::bigint AS nb_objets_incomplets_signales,
        COALESCE(SUM(m.nb_objets_incomplets_completes), 0)::bigint AS nb_objets_incomplets_completes,
        COALESCE(SUM(m.nb_modifications_terrain), 0)::bigint AS nb_modifications_terrain,
        COALESCE(SUM(m.nb_validations_terrain), 0)::bigint AS nb_validations_terrain,
        COALESCE(SUM(m.nb_corrections_backoffice), 0)::bigint AS nb_corrections_backoffice,
        COALESCE(SUM(m.nb_corrections_superviseur), 0)::bigint AS nb_corrections_superviseur,
        COALESCE(SUM(m.nb_reouvertures), 0)::bigint AS nb_reouvertures,
        COALESCE(SUM(m.nb_evenements_mobiles), 0)::bigint AS nb_evenements_mobiles,
        COALESCE(SUM(m.nb_attributs_mobiles), 0)::bigint AS nb_attributs_mobiles,
        COALESCE(SUM(m.nb_sessions_login), 0)::bigint AS nb_sessions_login,
        COALESCE(SUM(m.nb_sessions_logout), 0)::bigint AS nb_sessions_logout,
        COALESCE(SUM(m.nb_evenements_sync), 0)::bigint AS nb_evenements_sync
    FROM public.vw_metrics_agent_jour m
    GROUP BY
        m.jour,
        m.id_agent,
        m.id_projet
),
mission_day AS (
    SELECT
        mf.jour_mission AS jour,
        mf.id_agent,
        mf.id_projet,
        COUNT(*)::bigint AS nb_missions,
        COUNT(*) FILTER (WHERE mf.mission_cloturee)::bigint AS nb_missions_cloturees,
        COALESCE(SUM(mf.duree_mission_heures), 0)::double precision AS duree_mission_heures
    FROM public.vw_srm_mission_fact mf
    WHERE mf.jour_mission IS NOT NULL
    GROUP BY
        mf.jour_mission,
        mf.id_agent,
        mf.id_projet
),
keys AS (
    SELECT jour, id_agent, id_projet FROM agent_base
    UNION
    SELECT jour, id_agent, id_projet FROM mission_day
)
SELECT
    md5(concat_ws('|', k.jour::text, COALESCE(k.id_agent::text, ''), COALESCE(k.id_projet::text, ''))) AS metric_uid,
    k.jour,
    k.id_agent,
    k.id_projet,
    COALESCE(a.nb_objets_crees, 0)::bigint AS nb_objets_crees,
    COALESCE(a.nb_points, 0)::bigint AS nb_points,
    COALESCE(a.nb_lignes, 0)::bigint AS nb_lignes,
    COALESCE(a.nb_surfaces, 0)::bigint AS nb_surfaces,
    COALESCE(a.nb_objets_anomalie, 0)::bigint AS nb_objets_anomalie,
    CASE
        WHEN COALESCE(a.nb_objets_crees, 0) > 0
            THEN ROUND((100.0 * COALESCE(a.nb_objets_anomalie, 0) / a.nb_objets_crees)::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_anomalie_pct,
    COALESCE(a.nb_objets_avec_photo, 0)::bigint AS nb_objets_avec_photo,
    CASE
        WHEN COALESCE(a.nb_objets_crees, 0) > 0
            THEN ROUND((100.0 * COALESCE(a.nb_objets_avec_photo, 0) / a.nb_objets_crees)::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_objets_avec_photo_pct,
    COALESCE(a.nb_photos_renseignees, 0)::bigint AS nb_photos_renseignees,
    COALESCE(a.nb_photos_uploadees, 0)::bigint AS nb_photos_uploadees,
    CASE
        WHEN COALESCE(a.nb_objets_crees, 0) > 0
            THEN ROUND((COALESCE(a.nb_photos_renseignees, 0)::numeric / a.nb_objets_crees)::numeric, 2)::double precision
        ELSE 0::double precision
    END AS moyenne_photos_par_objet,
    COALESCE(a.nb_objets_incomplets_signales, 0)::bigint AS nb_objets_incomplets_signales,
    COALESCE(a.nb_objets_incomplets_completes, 0)::bigint AS nb_objets_incomplets_completes,
    (COALESCE(a.nb_objets_incomplets_signales, 0) - COALESCE(a.nb_objets_incomplets_completes, 0))::bigint AS solde_incomplets,
    COALESCE(a.nb_modifications_terrain, 0)::bigint AS nb_modifications_terrain,
    COALESCE(a.nb_validations_terrain, 0)::bigint AS nb_validations_terrain,
    COALESCE(a.nb_corrections_backoffice, 0)::bigint AS nb_corrections_backoffice,
    COALESCE(a.nb_corrections_superviseur, 0)::bigint AS nb_corrections_superviseur,
    COALESCE(a.nb_reouvertures, 0)::bigint AS nb_reouvertures,
    COALESCE(a.nb_evenements_mobiles, 0)::bigint AS nb_evenements_mobiles,
    COALESCE(a.nb_attributs_mobiles, 0)::bigint AS nb_attributs_mobiles,
    COALESCE(a.nb_sessions_login, 0)::bigint AS nb_sessions_login,
    COALESCE(a.nb_sessions_logout, 0)::bigint AS nb_sessions_logout,
    COALESCE(a.nb_evenements_sync, 0)::bigint AS nb_evenements_sync,
    COALESCE(md.nb_missions, 0)::bigint AS nb_missions,
    COALESCE(md.nb_missions_cloturees, 0)::bigint AS nb_missions_cloturees,
    COALESCE(md.duree_mission_heures, 0)::double precision AS duree_mission_heures,
    CASE
        WHEN COALESCE(md.nb_missions, 0) > 0
            THEN ROUND((COALESCE(a.nb_objets_crees, 0)::numeric / md.nb_missions)::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_mission,
    CASE
        WHEN COALESCE(md.duree_mission_heures, 0) > 0
            THEN ROUND((COALESCE(a.nb_objets_crees, 0)::numeric / md.duree_mission_heures)::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_heure,
    CASE
        WHEN COALESCE(a.nb_objets_crees, 0) > 0
          OR COALESCE(a.nb_modifications_terrain, 0) > 0
          OR COALESCE(a.nb_evenements_sync, 0) > 0
          OR COALESCE(md.nb_missions, 0) > 0
            THEN true
        ELSE false
    END AS actif,
    CASE
        WHEN COALESCE(a.nb_objets_crees, 0) > 0
          OR COALESCE(a.nb_modifications_terrain, 0) > 0
          OR COALESCE(a.nb_evenements_sync, 0) > 0
          OR COALESCE(md.nb_missions, 0) > 0
            THEN 1
        ELSE 0
    END::bigint AS nb_jours_actifs
FROM keys k
LEFT JOIN agent_base a
    ON a.jour = k.jour
   AND a.id_agent IS NOT DISTINCT FROM k.id_agent
   AND a.id_projet IS NOT DISTINCT FROM k.id_projet
LEFT JOIN mission_day md
    ON md.jour = k.jour
   AND md.id_agent IS NOT DISTINCT FROM k.id_agent
   AND md.id_projet IS NOT DISTINCT FROM k.id_projet;

CREATE VIEW public.vw_metrics_agent_public_semaine AS
SELECT
    md5(concat_ws('|', ap.id_agent::text, COALESCE(ap.id_projet::text, ''), aps.annee_iso::text, aps.semaine_iso::text)) AS metric_uid,
    aps.semaine_debut,
    (aps.semaine_debut + 6) AS semaine_fin,
    aps.annee_iso,
    aps.semaine_iso,
    ap.id_agent,
    ap.id_projet,
    SUM(ap.nb_objets_crees)::bigint AS nb_objets_crees,
    SUM(ap.nb_points)::bigint AS nb_points,
    SUM(ap.nb_lignes)::bigint AS nb_lignes,
    SUM(ap.nb_surfaces)::bigint AS nb_surfaces,
    SUM(ap.nb_objets_anomalie)::bigint AS nb_objets_anomalie,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(ap.nb_objets_anomalie) / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_anomalie_pct,
    SUM(ap.nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(ap.nb_objets_avec_photo) / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_objets_avec_photo_pct,
    SUM(ap.nb_photos_renseignees)::bigint AS nb_photos_renseignees,
    SUM(ap.nb_photos_uploadees)::bigint AS nb_photos_uploadees,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((SUM(ap.nb_photos_renseignees)::numeric / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS moyenne_photos_par_objet,
    SUM(ap.nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
    SUM(ap.nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
    (SUM(ap.nb_objets_incomplets_signales) - SUM(ap.nb_objets_incomplets_completes))::bigint AS solde_incomplets,
    SUM(ap.nb_modifications_terrain)::bigint AS nb_modifications_terrain,
    SUM(ap.nb_validations_terrain)::bigint AS nb_validations_terrain,
    SUM(ap.nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
    SUM(ap.nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
    SUM(ap.nb_reouvertures)::bigint AS nb_reouvertures,
    SUM(ap.nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
    SUM(ap.nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
    SUM(ap.nb_sessions_login)::bigint AS nb_sessions_login,
    SUM(ap.nb_sessions_logout)::bigint AS nb_sessions_logout,
    SUM(ap.nb_evenements_sync)::bigint AS nb_evenements_sync,
    SUM(ap.nb_missions)::bigint AS nb_missions,
    SUM(ap.nb_missions_cloturees)::bigint AS nb_missions_cloturees,
    ROUND(SUM(ap.duree_mission_heures)::numeric, 2)::double precision AS duree_mission_heures,
    CASE WHEN SUM(ap.nb_missions) > 0
        THEN ROUND((SUM(ap.nb_objets_crees)::numeric / SUM(ap.nb_missions))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_mission,
    CASE WHEN SUM(ap.duree_mission_heures) > 0
        THEN ROUND((SUM(ap.nb_objets_crees)::numeric / SUM(ap.duree_mission_heures))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_heure,
    BOOL_OR(ap.actif) AS actif,
    SUM(ap.nb_jours_actifs)::bigint AS nb_jours_actifs
FROM public.vw_metrics_agent_public_jour ap
JOIN (
    SELECT
        date_trunc('week', jour::timestamp)::date AS semaine_debut,
        EXTRACT(ISOYEAR FROM jour)::integer AS annee_iso,
        EXTRACT(WEEK FROM jour)::integer AS semaine_iso,
        id_agent,
        id_projet
    FROM public.vw_metrics_agent_public_jour
    GROUP BY
        date_trunc('week', jour::timestamp)::date,
        EXTRACT(ISOYEAR FROM jour),
        EXTRACT(WEEK FROM jour),
        id_agent,
        id_projet
) aps
    ON aps.semaine_debut = date_trunc('week', ap.jour::timestamp)::date
   AND aps.id_agent IS NOT DISTINCT FROM ap.id_agent
   AND aps.id_projet IS NOT DISTINCT FROM ap.id_projet
GROUP BY
    aps.annee_iso,
    aps.semaine_iso,
    aps.semaine_debut,
    ap.id_agent,
    ap.id_projet;

CREATE VIEW public.vw_metrics_agent_public_mois AS
SELECT
    md5(concat_ws('|', ap.id_agent::text, COALESCE(ap.id_projet::text, ''), apm.annee::text, apm.mois_numero::text)) AS metric_uid,
    apm.mois,
    apm.annee,
    apm.mois_numero,
    ap.id_agent,
    ap.id_projet,
    SUM(ap.nb_objets_crees)::bigint AS nb_objets_crees,
    SUM(ap.nb_points)::bigint AS nb_points,
    SUM(ap.nb_lignes)::bigint AS nb_lignes,
    SUM(ap.nb_surfaces)::bigint AS nb_surfaces,
    SUM(ap.nb_objets_anomalie)::bigint AS nb_objets_anomalie,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(ap.nb_objets_anomalie) / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_anomalie_pct,
    SUM(ap.nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(ap.nb_objets_avec_photo) / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_objets_avec_photo_pct,
    SUM(ap.nb_photos_renseignees)::bigint AS nb_photos_renseignees,
    SUM(ap.nb_photos_uploadees)::bigint AS nb_photos_uploadees,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((SUM(ap.nb_photos_renseignees)::numeric / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS moyenne_photos_par_objet,
    SUM(ap.nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
    SUM(ap.nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
    (SUM(ap.nb_objets_incomplets_signales) - SUM(ap.nb_objets_incomplets_completes))::bigint AS solde_incomplets,
    SUM(ap.nb_modifications_terrain)::bigint AS nb_modifications_terrain,
    SUM(ap.nb_validations_terrain)::bigint AS nb_validations_terrain,
    SUM(ap.nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
    SUM(ap.nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
    SUM(ap.nb_reouvertures)::bigint AS nb_reouvertures,
    SUM(ap.nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
    SUM(ap.nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
    SUM(ap.nb_sessions_login)::bigint AS nb_sessions_login,
    SUM(ap.nb_sessions_logout)::bigint AS nb_sessions_logout,
    SUM(ap.nb_evenements_sync)::bigint AS nb_evenements_sync,
    SUM(ap.nb_missions)::bigint AS nb_missions,
    SUM(ap.nb_missions_cloturees)::bigint AS nb_missions_cloturees,
    ROUND(SUM(ap.duree_mission_heures)::numeric, 2)::double precision AS duree_mission_heures,
    CASE WHEN SUM(ap.nb_missions) > 0
        THEN ROUND((SUM(ap.nb_objets_crees)::numeric / SUM(ap.nb_missions))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_mission,
    CASE WHEN SUM(ap.duree_mission_heures) > 0
        THEN ROUND((SUM(ap.nb_objets_crees)::numeric / SUM(ap.duree_mission_heures))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_heure,
    BOOL_OR(ap.actif) AS actif,
    SUM(ap.nb_jours_actifs)::bigint AS nb_jours_actifs
FROM public.vw_metrics_agent_public_jour ap
JOIN (
    SELECT
        date_trunc('month', jour::timestamp)::date AS mois,
        EXTRACT(YEAR FROM jour)::integer AS annee,
        EXTRACT(MONTH FROM jour)::integer AS mois_numero,
        id_agent,
        id_projet
    FROM public.vw_metrics_agent_public_jour
    GROUP BY
        date_trunc('month', jour::timestamp)::date,
        EXTRACT(YEAR FROM jour),
        EXTRACT(MONTH FROM jour),
        id_agent,
        id_projet
 ) apm
    ON apm.mois = date_trunc('month', ap.jour::timestamp)::date
   AND apm.id_agent IS NOT DISTINCT FROM ap.id_agent
   AND apm.id_projet IS NOT DISTINCT FROM ap.id_projet
GROUP BY
    apm.mois,
    apm.annee,
    apm.mois_numero,
    ap.id_agent,
    ap.id_projet;

CREATE VIEW public.vw_metrics_agent_public_resume AS
SELECT
    md5(concat_ws('|', 'agent-resume', COALESCE(ap.id_agent::text, ''), COALESCE(ap.id_projet::text, ''))) AS metric_uid,
    ap.id_agent,
    ap.id_projet,
    MIN(ap.jour) FILTER (WHERE ap.actif) AS premiere_activite,
    MAX(ap.jour) FILTER (WHERE ap.actif) AS derniere_activite,
    SUM(ap.nb_jours_actifs)::bigint AS nb_jours_actifs,
    SUM(ap.nb_objets_crees)::bigint AS nb_objets_crees_total,
    SUM(ap.nb_points)::bigint AS nb_points_total,
    SUM(ap.nb_lignes)::bigint AS nb_lignes_total,
    SUM(ap.nb_surfaces)::bigint AS nb_surfaces_total,
    SUM(ap.nb_objets_anomalie)::bigint AS nb_objets_anomalie_total,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(ap.nb_objets_anomalie) / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_anomalie_global_pct,
    SUM(ap.nb_objets_avec_photo)::bigint AS nb_objets_avec_photo_total,
    SUM(ap.nb_photos_renseignees)::bigint AS nb_photos_renseignees_total,
    SUM(ap.nb_photos_uploadees)::bigint AS nb_photos_uploadees_total,
    SUM(ap.nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales_total,
    SUM(ap.nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes_total,
    SUM(ap.nb_modifications_terrain)::bigint AS nb_modifications_terrain_total,
    SUM(ap.nb_validations_terrain)::bigint AS nb_validations_terrain_total,
    SUM(ap.nb_corrections_backoffice)::bigint AS nb_corrections_backoffice_total,
    SUM(ap.nb_corrections_superviseur)::bigint AS nb_corrections_superviseur_total,
    SUM(ap.nb_reouvertures)::bigint AS nb_reouvertures_total,
    SUM(ap.nb_evenements_sync)::bigint AS nb_evenements_sync_total,
    SUM(ap.nb_missions)::bigint AS nb_missions_total,
    SUM(ap.nb_missions_cloturees)::bigint AS nb_missions_cloturees_total,
    ROUND(SUM(ap.duree_mission_heures)::numeric, 2)::double precision AS duree_mission_heures_total,
    CASE WHEN SUM(ap.nb_missions) > 0
        THEN ROUND((SUM(ap.nb_objets_crees)::numeric / SUM(ap.nb_missions))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_mission_global,
    CASE WHEN SUM(ap.duree_mission_heures) > 0
        THEN ROUND((SUM(ap.nb_objets_crees)::numeric / SUM(ap.duree_mission_heures))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_heure_global,
    COALESCE(SUM(ap.nb_objets_crees) FILTER (WHERE ap.jour >= CURRENT_DATE - 6), 0)::bigint AS nb_objets_7j,
    COALESCE(SUM(ap.nb_objets_crees) FILTER (WHERE ap.jour >= CURRENT_DATE - 29), 0)::bigint AS nb_objets_30j,
    COALESCE(SUM(ap.nb_objets_crees) FILTER (WHERE date_trunc('month', ap.jour::timestamp)::date = date_trunc('month', CURRENT_DATE::timestamp)::date), 0)::bigint AS nb_objets_mois_courant,
    COALESCE(SUM(ap.nb_objets_crees) FILTER (WHERE date_trunc('week', ap.jour::timestamp)::date = date_trunc('week', CURRENT_DATE::timestamp)::date), 0)::bigint AS nb_objets_semaine_courante
FROM public.vw_metrics_agent_public_jour ap
GROUP BY
    ap.id_agent,
    ap.id_projet;

CREATE VIEW public.vw_metrics_projet_jour AS
SELECT
    md5(concat_ws('|', 'projet-jour', ap.jour::text, COALESCE(ap.id_projet::text, ''))) AS metric_uid,
    ap.jour,
    ap.id_projet,
    COUNT(DISTINCT ap.id_agent) FILTER (WHERE ap.actif AND ap.id_agent IS NOT NULL)::bigint AS nb_agents_actifs,
    SUM(ap.nb_objets_crees)::bigint AS nb_objets_crees,
    SUM(ap.nb_points)::bigint AS nb_points,
    SUM(ap.nb_lignes)::bigint AS nb_lignes,
    SUM(ap.nb_surfaces)::bigint AS nb_surfaces,
    SUM(ap.nb_objets_anomalie)::bigint AS nb_objets_anomalie,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(ap.nb_objets_anomalie) / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_anomalie_pct,
    SUM(ap.nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(ap.nb_objets_avec_photo) / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_objets_avec_photo_pct,
    SUM(ap.nb_photos_renseignees)::bigint AS nb_photos_renseignees,
    SUM(ap.nb_photos_uploadees)::bigint AS nb_photos_uploadees,
    CASE WHEN SUM(ap.nb_objets_crees) > 0
        THEN ROUND((SUM(ap.nb_photos_renseignees)::numeric / SUM(ap.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS moyenne_photos_par_objet,
    SUM(ap.nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
    SUM(ap.nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
    (SUM(ap.nb_objets_incomplets_signales) - SUM(ap.nb_objets_incomplets_completes))::bigint AS solde_incomplets,
    SUM(ap.nb_modifications_terrain)::bigint AS nb_modifications_terrain,
    SUM(ap.nb_validations_terrain)::bigint AS nb_validations_terrain,
    SUM(ap.nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
    SUM(ap.nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
    SUM(ap.nb_reouvertures)::bigint AS nb_reouvertures,
    SUM(ap.nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
    SUM(ap.nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
    SUM(ap.nb_sessions_login)::bigint AS nb_sessions_login,
    SUM(ap.nb_sessions_logout)::bigint AS nb_sessions_logout,
    SUM(ap.nb_evenements_sync)::bigint AS nb_evenements_sync,
    SUM(ap.nb_missions)::bigint AS nb_missions,
    SUM(ap.nb_missions_cloturees)::bigint AS nb_missions_cloturees,
    ROUND(SUM(ap.duree_mission_heures)::numeric, 2)::double precision AS duree_mission_heures,
    CASE WHEN SUM(ap.nb_missions) > 0
        THEN ROUND((SUM(ap.nb_objets_crees)::numeric / SUM(ap.nb_missions))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_mission,
    CASE WHEN SUM(ap.duree_mission_heures) > 0
        THEN ROUND((SUM(ap.nb_objets_crees)::numeric / SUM(ap.duree_mission_heures))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_heure,
    CASE WHEN COUNT(DISTINCT ap.id_agent) FILTER (WHERE ap.actif AND ap.id_agent IS NOT NULL) > 0
        THEN ROUND((SUM(ap.nb_objets_crees)::numeric / COUNT(DISTINCT ap.id_agent) FILTER (WHERE ap.actif AND ap.id_agent IS NOT NULL))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS moyenne_objets_par_agent_actif,
    BOOL_OR(ap.actif) AS actif,
    CASE WHEN BOOL_OR(ap.actif) THEN 1 ELSE 0 END::bigint AS nb_jours_actifs
FROM public.vw_metrics_agent_public_jour ap
GROUP BY
    ap.jour,
    ap.id_projet;

CREATE VIEW public.vw_metrics_projet_semaine AS
WITH agents AS (
    SELECT
        date_trunc('week', jour::timestamp)::date AS semaine_debut,
        EXTRACT(ISOYEAR FROM jour)::integer AS annee_iso,
        EXTRACT(WEEK FROM jour)::integer AS semaine_iso,
        id_projet,
        COUNT(DISTINCT id_agent) FILTER (WHERE actif AND id_agent IS NOT NULL)::bigint AS nb_agents_actifs
    FROM public.vw_metrics_agent_public_jour
    GROUP BY
        date_trunc('week', jour::timestamp)::date,
        EXTRACT(ISOYEAR FROM jour),
        EXTRACT(WEEK FROM jour),
        id_projet
)
SELECT
    md5(concat_ws('|', 'projet-semaine', EXTRACT(ISOYEAR FROM pj.jour)::text, EXTRACT(WEEK FROM pj.jour)::text, COALESCE(pj.id_projet::text, ''))) AS metric_uid,
    date_trunc('week', pj.jour::timestamp)::date AS semaine_debut,
    (date_trunc('week', pj.jour::timestamp)::date + 6) AS semaine_fin,
    EXTRACT(ISOYEAR FROM pj.jour)::integer AS annee_iso,
    EXTRACT(WEEK FROM pj.jour)::integer AS semaine_iso,
    pj.id_projet,
    ag.nb_agents_actifs,
    SUM(pj.nb_objets_crees)::bigint AS nb_objets_crees,
    SUM(pj.nb_points)::bigint AS nb_points,
    SUM(pj.nb_lignes)::bigint AS nb_lignes,
    SUM(pj.nb_surfaces)::bigint AS nb_surfaces,
    SUM(pj.nb_objets_anomalie)::bigint AS nb_objets_anomalie,
    CASE WHEN SUM(pj.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(pj.nb_objets_anomalie) / SUM(pj.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_anomalie_pct,
    SUM(pj.nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
    SUM(pj.nb_photos_renseignees)::bigint AS nb_photos_renseignees,
    SUM(pj.nb_photos_uploadees)::bigint AS nb_photos_uploadees,
    SUM(pj.nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
    SUM(pj.nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
    SUM(pj.nb_modifications_terrain)::bigint AS nb_modifications_terrain,
    SUM(pj.nb_validations_terrain)::bigint AS nb_validations_terrain,
    SUM(pj.nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
    SUM(pj.nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
    SUM(pj.nb_reouvertures)::bigint AS nb_reouvertures,
    SUM(pj.nb_evenements_sync)::bigint AS nb_evenements_sync,
    SUM(pj.nb_missions)::bigint AS nb_missions,
    SUM(pj.nb_missions_cloturees)::bigint AS nb_missions_cloturees,
    ROUND(SUM(pj.duree_mission_heures)::numeric, 2)::double precision AS duree_mission_heures,
    CASE WHEN SUM(pj.nb_missions) > 0
        THEN ROUND((SUM(pj.nb_objets_crees)::numeric / SUM(pj.nb_missions))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_mission,
    CASE WHEN SUM(pj.duree_mission_heures) > 0
        THEN ROUND((SUM(pj.nb_objets_crees)::numeric / SUM(pj.duree_mission_heures))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_heure,
    CASE WHEN COALESCE(ag.nb_agents_actifs, 0) > 0
        THEN ROUND((SUM(pj.nb_objets_crees)::numeric / ag.nb_agents_actifs)::numeric, 2)::double precision
        ELSE 0::double precision
    END AS moyenne_objets_par_agent_actif,
    BOOL_OR(pj.actif) AS actif,
    SUM(pj.nb_jours_actifs)::bigint AS nb_jours_actifs
FROM public.vw_metrics_projet_jour pj
JOIN agents ag
    ON ag.semaine_debut = date_trunc('week', pj.jour::timestamp)::date
   AND ag.id_projet IS NOT DISTINCT FROM pj.id_projet
GROUP BY
    date_trunc('week', pj.jour::timestamp)::date,
    EXTRACT(ISOYEAR FROM pj.jour),
    EXTRACT(WEEK FROM pj.jour),
    pj.id_projet,
    ag.nb_agents_actifs;

CREATE VIEW public.vw_metrics_projet_mois AS
WITH agents AS (
    SELECT
        date_trunc('month', jour::timestamp)::date AS mois,
        EXTRACT(YEAR FROM jour)::integer AS annee,
        EXTRACT(MONTH FROM jour)::integer AS mois_numero,
        id_projet,
        COUNT(DISTINCT id_agent) FILTER (WHERE actif AND id_agent IS NOT NULL)::bigint AS nb_agents_actifs
    FROM public.vw_metrics_agent_public_jour
    GROUP BY
        date_trunc('month', jour::timestamp)::date,
        EXTRACT(YEAR FROM jour),
        EXTRACT(MONTH FROM jour),
        id_projet
)
SELECT
    md5(concat_ws('|', 'projet-mois', EXTRACT(YEAR FROM pj.jour)::text, EXTRACT(MONTH FROM pj.jour)::text, COALESCE(pj.id_projet::text, ''))) AS metric_uid,
    date_trunc('month', pj.jour::timestamp)::date AS mois,
    EXTRACT(YEAR FROM pj.jour)::integer AS annee,
    EXTRACT(MONTH FROM pj.jour)::integer AS mois_numero,
    pj.id_projet,
    ag.nb_agents_actifs,
    SUM(pj.nb_objets_crees)::bigint AS nb_objets_crees,
    SUM(pj.nb_points)::bigint AS nb_points,
    SUM(pj.nb_lignes)::bigint AS nb_lignes,
    SUM(pj.nb_surfaces)::bigint AS nb_surfaces,
    SUM(pj.nb_objets_anomalie)::bigint AS nb_objets_anomalie,
    CASE WHEN SUM(pj.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(pj.nb_objets_anomalie) / SUM(pj.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_anomalie_pct,
    SUM(pj.nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
    SUM(pj.nb_photos_renseignees)::bigint AS nb_photos_renseignees,
    SUM(pj.nb_photos_uploadees)::bigint AS nb_photos_uploadees,
    SUM(pj.nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
    SUM(pj.nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
    SUM(pj.nb_modifications_terrain)::bigint AS nb_modifications_terrain,
    SUM(pj.nb_validations_terrain)::bigint AS nb_validations_terrain,
    SUM(pj.nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
    SUM(pj.nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
    SUM(pj.nb_reouvertures)::bigint AS nb_reouvertures,
    SUM(pj.nb_evenements_sync)::bigint AS nb_evenements_sync,
    SUM(pj.nb_missions)::bigint AS nb_missions,
    SUM(pj.nb_missions_cloturees)::bigint AS nb_missions_cloturees,
    ROUND(SUM(pj.duree_mission_heures)::numeric, 2)::double precision AS duree_mission_heures,
    CASE WHEN SUM(pj.nb_missions) > 0
        THEN ROUND((SUM(pj.nb_objets_crees)::numeric / SUM(pj.nb_missions))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_mission,
    CASE WHEN SUM(pj.duree_mission_heures) > 0
        THEN ROUND((SUM(pj.nb_objets_crees)::numeric / SUM(pj.duree_mission_heures))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_heure,
    CASE WHEN COALESCE(ag.nb_agents_actifs, 0) > 0
        THEN ROUND((SUM(pj.nb_objets_crees)::numeric / ag.nb_agents_actifs)::numeric, 2)::double precision
        ELSE 0::double precision
    END AS moyenne_objets_par_agent_actif,
    BOOL_OR(pj.actif) AS actif,
    SUM(pj.nb_jours_actifs)::bigint AS nb_jours_actifs
FROM public.vw_metrics_projet_jour pj
JOIN agents ag
    ON ag.mois = date_trunc('month', pj.jour::timestamp)::date
   AND ag.id_projet IS NOT DISTINCT FROM pj.id_projet
GROUP BY
    date_trunc('month', pj.jour::timestamp)::date,
    EXTRACT(YEAR FROM pj.jour),
    EXTRACT(MONTH FROM pj.jour),
    pj.id_projet,
    ag.nb_agents_actifs;

CREATE VIEW public.vw_metrics_projet_resume AS
WITH agents AS (
    SELECT
        id_projet,
        COUNT(DISTINCT id_agent) FILTER (WHERE actif AND id_agent IS NOT NULL)::bigint AS nb_agents_actifs
    FROM public.vw_metrics_agent_public_jour
    GROUP BY id_projet
)
SELECT
    md5(concat_ws('|', 'projet-resume', COALESCE(pj.id_projet::text, ''))) AS metric_uid,
    pj.id_projet,
    MIN(pj.jour) FILTER (WHERE pj.actif) AS premiere_activite,
    MAX(pj.jour) FILTER (WHERE pj.actif) AS derniere_activite,
    SUM(pj.nb_jours_actifs)::bigint AS nb_jours_actifs,
    ag.nb_agents_actifs,
    SUM(pj.nb_objets_crees)::bigint AS nb_objets_crees_total,
    SUM(pj.nb_points)::bigint AS nb_points_total,
    SUM(pj.nb_lignes)::bigint AS nb_lignes_total,
    SUM(pj.nb_surfaces)::bigint AS nb_surfaces_total,
    SUM(pj.nb_objets_anomalie)::bigint AS nb_objets_anomalie_total,
    CASE WHEN SUM(pj.nb_objets_crees) > 0
        THEN ROUND((100.0 * SUM(pj.nb_objets_anomalie) / SUM(pj.nb_objets_crees))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS taux_anomalie_global_pct,
    SUM(pj.nb_objets_avec_photo)::bigint AS nb_objets_avec_photo_total,
    SUM(pj.nb_photos_renseignees)::bigint AS nb_photos_renseignees_total,
    SUM(pj.nb_photos_uploadees)::bigint AS nb_photos_uploadees_total,
    SUM(pj.nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales_total,
    SUM(pj.nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes_total,
    SUM(pj.nb_modifications_terrain)::bigint AS nb_modifications_terrain_total,
    SUM(pj.nb_validations_terrain)::bigint AS nb_validations_terrain_total,
    SUM(pj.nb_corrections_backoffice)::bigint AS nb_corrections_backoffice_total,
    SUM(pj.nb_corrections_superviseur)::bigint AS nb_corrections_superviseur_total,
    SUM(pj.nb_reouvertures)::bigint AS nb_reouvertures_total,
    SUM(pj.nb_evenements_sync)::bigint AS nb_evenements_sync_total,
    SUM(pj.nb_missions)::bigint AS nb_missions_total,
    SUM(pj.nb_missions_cloturees)::bigint AS nb_missions_cloturees_total,
    ROUND(SUM(pj.duree_mission_heures)::numeric, 2)::double precision AS duree_mission_heures_total,
    CASE WHEN SUM(pj.nb_missions) > 0
        THEN ROUND((SUM(pj.nb_objets_crees)::numeric / SUM(pj.nb_missions))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_mission_global,
    CASE WHEN SUM(pj.duree_mission_heures) > 0
        THEN ROUND((SUM(pj.nb_objets_crees)::numeric / SUM(pj.duree_mission_heures))::numeric, 2)::double precision
        ELSE 0::double precision
    END AS objets_par_heure_global,
    CASE WHEN COALESCE(ag.nb_agents_actifs, 0) > 0
        THEN ROUND((SUM(pj.nb_objets_crees)::numeric / ag.nb_agents_actifs)::numeric, 2)::double precision
        ELSE 0::double precision
    END AS moyenne_objets_par_agent_actif,
    COALESCE(SUM(pj.nb_objets_crees) FILTER (WHERE pj.jour >= CURRENT_DATE - 6), 0)::bigint AS nb_objets_7j,
    COALESCE(SUM(pj.nb_objets_crees) FILTER (WHERE pj.jour >= CURRENT_DATE - 29), 0)::bigint AS nb_objets_30j,
    COALESCE(SUM(pj.nb_objets_crees) FILTER (WHERE date_trunc('month', pj.jour::timestamp)::date = date_trunc('month', CURRENT_DATE::timestamp)::date), 0)::bigint AS nb_objets_mois_courant,
    COALESCE(SUM(pj.nb_objets_crees) FILTER (WHERE date_trunc('week', pj.jour::timestamp)::date = date_trunc('week', CURRENT_DATE::timestamp)::date), 0)::bigint AS nb_objets_semaine_courante
FROM public.vw_metrics_projet_jour pj
JOIN agents ag
    ON ag.id_projet IS NOT DISTINCT FROM pj.id_projet
GROUP BY
    pj.id_projet,
    ag.nb_agents_actifs;

COMMIT;
