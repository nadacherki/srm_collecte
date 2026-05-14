from django.db import migrations


FORWARD_SQL = r"""
CREATE OR REPLACE VIEW public.vw_metrics_agent_public_jour AS
WITH object_metrics AS (
    SELECT jour,
           id_agent,
           sum(nb_objets_crees)::bigint AS nb_objets_crees,
           sum(CASE WHEN famille_geometrie = 'POINT' THEN nb_objets_crees ELSE 0 END)::bigint AS nb_points,
           sum(CASE WHEN famille_geometrie = 'LINE' THEN nb_objets_crees ELSE 0 END)::bigint AS nb_lignes,
           sum(CASE WHEN famille_geometrie = 'POLYGON' THEN nb_objets_crees ELSE 0 END)::bigint AS nb_surfaces,
           sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
           sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
           sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
           sum(nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
           sum(nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
           sum(nb_modifications_terrain)::bigint AS nb_modifications_terrain,
           sum(nb_validations_terrain)::bigint AS nb_validations_terrain,
           sum(nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
           sum(nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
           sum(nb_reouvertures)::bigint AS nb_reouvertures,
           sum(nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
           sum(nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
           sum(nb_sessions_login)::bigint AS nb_sessions_login,
           sum(nb_sessions_logout)::bigint AS nb_sessions_logout,
           sum(nb_evenements_sync)::bigint AS nb_evenements_sync
    FROM public.vw_metrics_agent_jour
    GROUP BY jour, id_agent
),
object_photo_keys AS (
    SELECT COALESCE(date_action::date, CURRENT_DATE) AS jour,
           id_agent_crea AS id_agent,
           concat_ws('|', nom_schema, nom_table, uuid_objet) AS objet_key
    FROM public.vw_srm_objet_fact
    WHERE id_agent_crea IS NOT NULL
      AND COALESCE(nb_photos_renseignees, 0) > 0
),
uploaded_photo_keys AS (
    SELECT date_photo::date AS jour,
           id_agent,
           concat_ws('|', nom_schema, nom_table, uuid_objet) AS objet_key
    FROM public.vw_srm_photo_object_fact
    WHERE id_agent IS NOT NULL
      AND date_photo IS NOT NULL
),
photo_object_counts AS (
    SELECT jour,
           id_agent,
           count(DISTINCT objet_key)::bigint AS nb_objets_avec_photo
    FROM (
        SELECT jour, id_agent, objet_key FROM object_photo_keys
        UNION
        SELECT jour, id_agent, objet_key FROM uploaded_photo_keys
    ) q
    GROUP BY jour, id_agent
),
photo_upload_counts AS (
    SELECT date_photo::date AS jour,
           id_agent,
           count(*)::bigint AS nb_photos_uploadees
    FROM public.vw_srm_photo_object_fact
    WHERE id_agent IS NOT NULL
      AND date_photo IS NOT NULL
    GROUP BY date_photo::date, id_agent
),
incomplet_events AS (
    SELECT date_signalement::date AS jour,
           id_agent,
           count(*)::bigint AS nb_objets_incomplets_signales,
           0::bigint AS nb_objets_incomplets_completes
    FROM public.vw_srm_incomplet_fact
    WHERE id_agent IS NOT NULL
      AND date_signalement IS NOT NULL
    GROUP BY date_signalement::date, id_agent
    UNION ALL
    SELECT date_completion::date AS jour,
           id_agent,
           0::bigint AS nb_objets_incomplets_signales,
           count(*)::bigint AS nb_objets_incomplets_completes
    FROM public.vw_srm_incomplet_fact
    WHERE id_agent IS NOT NULL
      AND date_completion IS NOT NULL
    GROUP BY date_completion::date, id_agent
),
incomplet_metrics AS (
    SELECT jour,
           id_agent,
           sum(nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
           sum(nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes
    FROM incomplet_events
    GROUP BY jour, id_agent
),
history_metrics AS (
    SELECT date_action::date AS jour,
           id_agent,
           count(*) FILTER (WHERE lower(COALESCE(source, '')) = 'mobile')::bigint
               AS nb_evenements_mobiles,
           count(*) FILTER (
               WHERE lower(COALESCE(source, '')) = 'mobile'
                 AND lower(COALESCE(action, '')) IN ('update', 'modification')
           )::bigint AS nb_modifications_terrain,
           count(*) FILTER (
               WHERE lower(COALESCE(source, '')) = 'mobile'
                 AND lower(COALESCE(action, '')) IN ('validate', 'validation')
           )::bigint AS nb_validations_terrain,
           count(*) FILTER (
               WHERE lower(COALESCE(source, '')) = 'mobile'
                 AND lower(COALESCE(action, '')) IN ('insert', 'update', 'modification')
           )::bigint AS nb_attributs_mobiles
    FROM public.vw_srm_historique_fact
    WHERE id_agent IS NOT NULL
      AND date_action IS NOT NULL
    GROUP BY date_action::date, id_agent
),
sync_metrics AS (
    SELECT started_at::date AS jour,
           id_agent,
           count(*)::bigint AS nb_evenements_sync
    FROM public.sync_session
    WHERE id_agent IS NOT NULL
      AND started_at IS NOT NULL
    GROUP BY started_at::date, id_agent
),
metric_keys AS (
    SELECT jour, id_agent FROM object_metrics
    UNION
    SELECT jour, id_agent FROM photo_object_counts
    UNION
    SELECT jour, id_agent FROM photo_upload_counts
    UNION
    SELECT jour, id_agent FROM incomplet_metrics
    UNION
    SELECT jour, id_agent FROM history_metrics
    UNION
    SELECT jour, id_agent FROM sync_metrics
),
merged AS (
    SELECT k.jour,
           k.id_agent,
           COALESCE(o.nb_objets_crees, 0)::bigint AS nb_objets_crees,
           COALESCE(o.nb_points, 0)::bigint AS nb_points,
           COALESCE(o.nb_lignes, 0)::bigint AS nb_lignes,
           COALESCE(o.nb_surfaces, 0)::bigint AS nb_surfaces,
           COALESCE(o.nb_objets_anomalie, 0)::bigint AS nb_objets_anomalie,
           COALESCE(poc.nb_objets_avec_photo, 0)::bigint AS nb_objets_avec_photo,
           COALESCE(o.nb_photos_renseignees, 0)::bigint AS nb_photos_renseignees,
           COALESCE(puc.nb_photos_uploadees, 0)::bigint AS nb_photos_uploadees,
           COALESCE(im.nb_objets_incomplets_signales, 0)::bigint AS nb_objets_incomplets_signales,
           COALESCE(im.nb_objets_incomplets_completes, 0)::bigint AS nb_objets_incomplets_completes,
           (
               COALESCE(o.nb_modifications_terrain, 0)
               + COALESCE(hm.nb_modifications_terrain, 0)
           )::bigint AS nb_modifications_terrain,
           (
               COALESCE(o.nb_validations_terrain, 0)
               + COALESCE(hm.nb_validations_terrain, 0)
           )::bigint AS nb_validations_terrain,
           COALESCE(o.nb_corrections_backoffice, 0)::bigint AS nb_corrections_backoffice,
           COALESCE(o.nb_corrections_superviseur, 0)::bigint AS nb_corrections_superviseur,
           COALESCE(o.nb_reouvertures, 0)::bigint AS nb_reouvertures,
           (
               COALESCE(o.nb_evenements_mobiles, 0)
               + COALESCE(hm.nb_evenements_mobiles, 0)
           )::bigint AS nb_evenements_mobiles,
           (
               COALESCE(o.nb_attributs_mobiles, 0)
               + COALESCE(hm.nb_attributs_mobiles, 0)
           )::bigint AS nb_attributs_mobiles,
           COALESCE(o.nb_sessions_login, 0)::bigint AS nb_sessions_login,
           COALESCE(o.nb_sessions_logout, 0)::bigint AS nb_sessions_logout,
           (
               COALESCE(o.nb_evenements_sync, 0)
               + COALESCE(sm.nb_evenements_sync, 0)
           )::bigint AS nb_evenements_sync
    FROM metric_keys k
    LEFT JOIN object_metrics o
      ON o.jour = k.jour
     AND o.id_agent IS NOT DISTINCT FROM k.id_agent
    LEFT JOIN photo_object_counts poc
      ON poc.jour = k.jour
     AND poc.id_agent IS NOT DISTINCT FROM k.id_agent
    LEFT JOIN photo_upload_counts puc
      ON puc.jour = k.jour
     AND puc.id_agent IS NOT DISTINCT FROM k.id_agent
    LEFT JOIN incomplet_metrics im
      ON im.jour = k.jour
     AND im.id_agent IS NOT DISTINCT FROM k.id_agent
    LEFT JOIN history_metrics hm
      ON hm.jour = k.jour
     AND hm.id_agent IS NOT DISTINCT FROM k.id_agent
    LEFT JOIN sync_metrics sm
      ON sm.jour = k.jour
     AND sm.id_agent IS NOT DISTINCT FROM k.id_agent
)
SELECT md5(concat_ws('|', 'public-jour', COALESCE(id_agent::text, '-'), jour::text)) AS metric_uid,
       jour,
       id_agent,
       nb_objets_crees,
       nb_points,
       nb_lignes,
       nb_surfaces,
       nb_objets_anomalie,
       CASE WHEN nb_objets_crees > 0
            THEN round((nb_objets_anomalie::numeric * 100) / nb_objets_crees::numeric, 2)::double precision
            ELSE 0::double precision END AS taux_anomalie_pct,
       nb_objets_avec_photo,
       CASE WHEN nb_objets_crees > 0
            THEN LEAST(
                100::numeric,
                round((nb_objets_avec_photo::numeric * 100) / nb_objets_crees::numeric, 2)
            )::double precision
            ELSE 0::double precision END AS taux_objets_avec_photo_pct,
       nb_photos_renseignees,
       nb_photos_uploadees,
       CASE WHEN nb_objets_crees > 0
            THEN round((nb_photos_renseignees + nb_photos_uploadees)::numeric / nb_objets_crees::numeric, 2)::double precision
            ELSE 0::double precision END AS moyenne_photos_par_objet,
       nb_objets_incomplets_signales,
       nb_objets_incomplets_completes,
       (nb_objets_incomplets_signales - nb_objets_incomplets_completes)::bigint AS solde_incomplets,
       nb_modifications_terrain,
       nb_validations_terrain,
       nb_corrections_backoffice,
       nb_corrections_superviseur,
       nb_reouvertures,
       nb_evenements_mobiles,
       nb_attributs_mobiles,
       nb_sessions_login,
       nb_sessions_logout,
       nb_evenements_sync,
       0::double precision AS objets_par_heure,
       true AS actif,
       1::bigint AS nb_jours_actifs
FROM merged;

CREATE OR REPLACE VIEW public.vw_metrics_agent_public_semaine AS
SELECT md5(concat_ws('|', 'public-week', COALESCE(id_agent::text, '-'), date_trunc('week', jour::timestamp with time zone)::date::text)) AS metric_uid,
       date_trunc('week', jour::timestamp with time zone)::date AS semaine_debut,
       date_trunc('week', jour::timestamp with time zone)::date + 6 AS semaine_fin,
       EXTRACT(isoyear FROM jour)::integer AS annee_iso,
       EXTRACT(week FROM jour)::integer AS semaine_iso,
       id_agent,
       sum(nb_objets_crees)::bigint AS nb_objets_crees,
       sum(nb_points)::bigint AS nb_points,
       sum(nb_lignes)::bigint AS nb_lignes,
       sum(nb_surfaces)::bigint AS nb_surfaces,
       sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN round((sum(nb_objets_anomalie)::numeric * 100) / sum(nb_objets_crees)::numeric, 2)::double precision
            ELSE 0::double precision END AS taux_anomalie_pct,
       sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN LEAST(
                100::numeric,
                round((sum(nb_objets_avec_photo)::numeric * 100) / sum(nb_objets_crees)::numeric, 2)
            )::double precision
            ELSE 0::double precision END AS taux_objets_avec_photo_pct,
       sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
       sum(nb_photos_uploadees)::bigint AS nb_photos_uploadees,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN round((sum(nb_photos_renseignees) + sum(nb_photos_uploadees))::numeric / sum(nb_objets_crees)::numeric, 2)::double precision
            ELSE 0::double precision END AS moyenne_photos_par_objet,
       sum(nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
       sum(nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
       sum(solde_incomplets)::bigint AS solde_incomplets,
       sum(nb_modifications_terrain)::bigint AS nb_modifications_terrain,
       sum(nb_validations_terrain)::bigint AS nb_validations_terrain,
       sum(nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
       sum(nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
       sum(nb_reouvertures)::bigint AS nb_reouvertures,
       sum(nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
       sum(nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
       sum(nb_sessions_login)::bigint AS nb_sessions_login,
       sum(nb_sessions_logout)::bigint AS nb_sessions_logout,
       sum(nb_evenements_sync)::bigint AS nb_evenements_sync,
       0::double precision AS objets_par_heure,
       bool_or(actif) AS actif,
       count(DISTINCT jour)::bigint AS nb_jours_actifs
FROM public.vw_metrics_agent_public_jour
GROUP BY date_trunc('week', jour::timestamp with time zone)::date,
         EXTRACT(isoyear FROM jour),
         EXTRACT(week FROM jour),
         id_agent;

CREATE OR REPLACE VIEW public.vw_metrics_agent_public_mois AS
SELECT md5(concat_ws('|', 'public-month', COALESCE(id_agent::text, '-'), date_trunc('month', jour::timestamp with time zone)::date::text)) AS metric_uid,
       date_trunc('month', jour::timestamp with time zone)::date AS mois,
       EXTRACT(year FROM jour)::integer AS annee,
       EXTRACT(month FROM jour)::integer AS mois_numero,
       id_agent,
       sum(nb_objets_crees)::bigint AS nb_objets_crees,
       sum(nb_points)::bigint AS nb_points,
       sum(nb_lignes)::bigint AS nb_lignes,
       sum(nb_surfaces)::bigint AS nb_surfaces,
       sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN round((sum(nb_objets_anomalie)::numeric * 100) / sum(nb_objets_crees)::numeric, 2)::double precision
            ELSE 0::double precision END AS taux_anomalie_pct,
       sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN LEAST(
                100::numeric,
                round((sum(nb_objets_avec_photo)::numeric * 100) / sum(nb_objets_crees)::numeric, 2)
            )::double precision
            ELSE 0::double precision END AS taux_objets_avec_photo_pct,
       sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
       sum(nb_photos_uploadees)::bigint AS nb_photos_uploadees,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN round((sum(nb_photos_renseignees) + sum(nb_photos_uploadees))::numeric / sum(nb_objets_crees)::numeric, 2)::double precision
            ELSE 0::double precision END AS moyenne_photos_par_objet,
       sum(nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
       sum(nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
       sum(solde_incomplets)::bigint AS solde_incomplets,
       sum(nb_modifications_terrain)::bigint AS nb_modifications_terrain,
       sum(nb_validations_terrain)::bigint AS nb_validations_terrain,
       sum(nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
       sum(nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
       sum(nb_reouvertures)::bigint AS nb_reouvertures,
       sum(nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
       sum(nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
       sum(nb_sessions_login)::bigint AS nb_sessions_login,
       sum(nb_sessions_logout)::bigint AS nb_sessions_logout,
       sum(nb_evenements_sync)::bigint AS nb_evenements_sync,
       0::double precision AS objets_par_heure,
       bool_or(actif) AS actif,
       count(DISTINCT jour)::bigint AS nb_jours_actifs
FROM public.vw_metrics_agent_public_jour
GROUP BY date_trunc('month', jour::timestamp with time zone)::date,
         EXTRACT(year FROM jour),
         EXTRACT(month FROM jour),
         id_agent;

CREATE OR REPLACE VIEW public.vw_metrics_agent_period AS
SELECT md5(concat_ws('|', 'period', COALESCE(id_agent::text, '-'), jour::text)) AS metric_uid,
       'jour'::varchar(10) AS grain,
       jour AS periode_debut,
       jour AS periode_fin,
       EXTRACT(year FROM jour)::integer AS annee,
       EXTRACT(month FROM jour)::integer AS mois_numero,
       EXTRACT(isoyear FROM jour)::integer AS annee_iso,
       EXTRACT(week FROM jour)::integer AS semaine_iso,
       id_agent,
       nb_objets_crees,
       nb_points,
       nb_lignes,
       nb_surfaces,
       nb_objets_anomalie,
       taux_anomalie_pct,
       nb_objets_avec_photo,
       taux_objets_avec_photo_pct,
       nb_photos_renseignees,
       nb_photos_uploadees,
       moyenne_photos_par_objet,
       nb_objets_incomplets_signales,
       nb_objets_incomplets_completes,
       solde_incomplets,
       nb_modifications_terrain,
       nb_validations_terrain,
       nb_corrections_backoffice,
       nb_corrections_superviseur,
       nb_reouvertures,
       nb_evenements_mobiles,
       nb_attributs_mobiles,
       nb_sessions_login,
       nb_sessions_logout,
       nb_evenements_sync,
       objets_par_heure,
       actif,
       nb_jours_actifs,
       0::bigint AS nb_interventions_signalees,
       0::bigint AS nb_interventions_terrain_traitees,
       0::bigint AS nb_interventions_cloturees
FROM public.vw_metrics_agent_public_jour;

CREATE OR REPLACE VIEW public.vw_metrics_agent_public_resume AS
SELECT md5(concat_ws('|', 'public-resume', COALESCE(id_agent::text, '-'))) AS metric_uid,
       id_agent,
       min(jour) AS premiere_activite,
       max(jour) AS derniere_activite,
       count(DISTINCT jour)::bigint AS nb_jours_actifs,
       sum(nb_objets_crees)::bigint AS nb_objets_crees_total,
       sum(nb_points)::bigint AS nb_points_total,
       sum(nb_lignes)::bigint AS nb_lignes_total,
       sum(nb_surfaces)::bigint AS nb_surfaces_total,
       sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie_total,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN round((sum(nb_objets_anomalie)::numeric * 100) / sum(nb_objets_crees)::numeric, 2)::double precision
            ELSE 0::double precision END AS taux_anomalie_global_pct,
       sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo_total,
       sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees_total,
       sum(nb_photos_uploadees)::bigint AS nb_photos_uploadees_total,
       sum(nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales_total,
       sum(nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes_total,
       sum(nb_modifications_terrain)::bigint AS nb_modifications_terrain_total,
       sum(nb_validations_terrain)::bigint AS nb_validations_terrain_total,
       sum(nb_corrections_backoffice)::bigint AS nb_corrections_backoffice_total,
       sum(nb_corrections_superviseur)::bigint AS nb_corrections_superviseur_total,
       sum(nb_reouvertures)::bigint AS nb_reouvertures_total,
       sum(nb_evenements_sync)::bigint AS nb_evenements_sync_total,
       0::double precision AS objets_par_heure_global,
       COALESCE(sum(nb_objets_crees) FILTER (WHERE jour >= CURRENT_DATE - 7), 0)::bigint AS nb_objets_7j,
       COALESCE(sum(nb_objets_crees) FILTER (WHERE jour >= CURRENT_DATE - 30), 0)::bigint AS nb_objets_30j,
       COALESCE(sum(nb_objets_crees) FILTER (WHERE date_trunc('month', jour::timestamp with time zone) = date_trunc('month', CURRENT_DATE::timestamp with time zone)), 0)::bigint AS nb_objets_mois_courant,
       COALESCE(sum(nb_objets_crees) FILTER (WHERE date_trunc('week', jour::timestamp with time zone) = date_trunc('week', CURRENT_DATE::timestamp with time zone)), 0)::bigint AS nb_objets_semaine_courante
FROM public.vw_metrics_agent_public_jour
GROUP BY id_agent;

CREATE OR REPLACE VIEW public.vw_metrics_agent_resume AS
SELECT metric_uid,
       id_agent,
       premiere_activite,
       derniere_activite,
       nb_jours_actifs,
       nb_objets_crees_total,
       nb_points_total,
       nb_lignes_total,
       nb_surfaces_total,
       nb_objets_anomalie_total,
       taux_anomalie_global_pct,
       nb_objets_avec_photo_total,
       nb_photos_renseignees_total,
       nb_photos_uploadees_total,
       nb_objets_incomplets_signales_total,
       nb_objets_incomplets_completes_total,
       nb_modifications_terrain_total,
       nb_validations_terrain_total,
       nb_corrections_backoffice_total,
       nb_corrections_superviseur_total,
       nb_reouvertures_total,
       nb_evenements_sync_total,
       0::bigint AS nb_interventions_signalees_total,
       0::bigint AS nb_interventions_terrain_traitees_total,
       0::bigint AS nb_interventions_cloturees_total,
       objets_par_heure_global,
       nb_objets_7j,
       nb_objets_30j,
       nb_objets_mois_courant,
       nb_objets_semaine_courante
FROM public.vw_metrics_agent_public_resume;
"""


class Migration(migrations.Migration):
    dependencies = [
        ('api', '0044_count_uploaded_photos_in_public_metrics'),
    ]

    operations = [
        migrations.RunSQL(sql=FORWARD_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
