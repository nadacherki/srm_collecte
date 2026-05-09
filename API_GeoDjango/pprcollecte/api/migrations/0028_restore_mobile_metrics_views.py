from django.db import migrations


RESTORE_MOBILE_METRICS_VIEWS_SQL = r"""
DROP VIEW IF EXISTS public.vw_metrics_agent_period CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_resume CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_resume CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_jour CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_table_period CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_jour CASCADE;
DROP VIEW IF EXISTS public.vw_srm_objet_activity_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_objet_dates CASCADE;
DROP VIEW IF EXISTS public.vw_srm_objet_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_photo_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_incomplet_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_intervention_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_historique_fact CASCADE;

DO $$
DECLARE
    table_row record;
    union_sql text := '';
    table_sql text;
    id_text_expr text := $expr$COALESCE(
        NULLIF(to_jsonb(t.*)->>'fid', ''),
        NULLIF(to_jsonb(t.*)->>'id', ''),
        NULLIF(to_jsonb(t.*)->>'gid', ''),
        NULLIF(to_jsonb(t.*)->>'id_statistique_conduite', ''),
        NULLIF(to_jsonb(t.*)->>'id_statistique_conduite_segment', '')
    )$expr$;
BEGIN
    FOR table_row IN
        SELECT table_schema, table_name
        FROM information_schema.columns
        WHERE table_schema IN ('ep', 'asst', 'elec')
          AND column_name = 'geom'
        GROUP BY table_schema, table_name
        ORDER BY table_schema, table_name
    LOOP
        table_sql := format($fmt$
            SELECT
                %L || '.' || %L || ':' || COALESCE(%s, md5(ST_AsEWKB(t.geom)::text)) AS objet_uid,
                %L::varchar(30) AS nom_schema,
                %L::varchar(100) AS nom_table,
                %L::varchar(100) AS nom_classe,
                CASE WHEN %L = 'asst' THEN 'asst' ELSE %L END::varchar(10) AS metier,
                CASE WHEN (%s) ~ '^[0-9]+$' THEN (%s)::integer ELSE NULL::integer END AS id_objet,
                COALESCE((%s)::varchar(254), md5(ST_AsEWKB(t.geom)::text)::varchar(254)) AS cle_ligne,
                COALESCE(NULLIF(to_jsonb(t.*)->>'uuid', ''), (%s), md5(ST_AsEWKB(t.geom)::text))::varchar(254) AS uuid_objet,
                CASE
                    WHEN COALESCE(
                        NULLIF(to_jsonb(t.*)->>'id_user_creat', ''),
                        NULLIF(to_jsonb(t.*)->>'id_agent_crea', ''),
                        NULLIF(to_jsonb(t.*)->>'ASS_AGENT_CREA', '')
                    ) ~ '^[0-9]+$'
                    THEN COALESCE(
                        NULLIF(to_jsonb(t.*)->>'id_user_creat', ''),
                        NULLIF(to_jsonb(t.*)->>'id_agent_crea', ''),
                        NULLIF(to_jsonb(t.*)->>'ASS_AGENT_CREA', '')
                    )::integer
                    ELSE NULL::integer
                END AS id_agent_crea,
                upper(COALESCE(
                    NULLIF(to_jsonb(t.*)->>'anomalie', ''),
                    NULLIF(to_jsonb(t.*)->>'ep_anomalie', ''),
                    NULLIF(to_jsonb(t.*)->>'ass_anomalie', ''),
                    NULLIF(to_jsonb(t.*)->>'ASS_ANOMALIE', ''),
                    'false'
                )) IN ('OUI', 'YES', 'TRUE', '1') AS anomalie,
                COALESCE(
                    NULLIF(to_jsonb(t.*)->>'type_anomalie', ''),
                    NULLIF(to_jsonb(t.*)->>'anomalie_regard', ''),
                    NULLIF(to_jsonb(t.*)->>'anomalie_tamp', ''),
                    NULLIF(to_jsonb(t.*)->>'TYPE_ANOMALIE', '')
                )::text AS type_anomalie,
                COALESCE(
                    NULLIF(to_jsonb(t.*)->>'mode_localisation', ''),
                    NULLIF(to_jsonb(t.*)->>'MODE_LOCALISATION', '')
                )::text AS mode_localisation,
                geometrytype(t.geom)::varchar(30) AS type_geometrie,
                CASE
                    WHEN geometrytype(t.geom) ILIKE '%%POINT%%' THEN 'POINT'
                    WHEN geometrytype(t.geom) ILIKE '%%LINE%%' THEN 'LINE'
                    WHEN geometrytype(t.geom) ILIKE '%%POLYGON%%' THEN 'POLYGON'
                    ELSE geometrytype(t.geom)
                END::varchar(20) AS famille_geometrie,
                (
                    CASE WHEN NULLIF(btrim(COALESCE(to_jsonb(t.*)->>'photo_1', '')), '') IS NULL THEN 0 ELSE 1 END +
                    CASE WHEN NULLIF(btrim(COALESCE(to_jsonb(t.*)->>'photo_2', '')), '') IS NULL THEN 0 ELSE 1 END +
                    CASE WHEN NULLIF(btrim(COALESCE(to_jsonb(t.*)->>'photo_3', '')), '') IS NULL THEN 0 ELSE 1 END +
                    CASE WHEN NULLIF(btrim(COALESCE(to_jsonb(t.*)->>'photo_4', '')), '') IS NULL THEN 0 ELSE 1 END +
                    CASE WHEN NULLIF(btrim(COALESCE(to_jsonb(t.*)->>'ASS_PHOTO', '')), '') IS NULL THEN 0 ELSE 1 END
                )::integer AS nb_photos_renseignees,
                COALESCE(
                    NULLIF(to_jsonb(t.*)->>'date_modif', '')::timestamp without time zone,
                    NULLIF(to_jsonb(t.*)->>'date_validation', '')::timestamp without time zone,
                    NULLIF(to_jsonb(t.*)->>'date_creation', '')::timestamp without time zone,
                    NULLIF(to_jsonb(t.*)->>'ep_date_insertion', '')::timestamp without time zone,
                    NULLIF(to_jsonb(t.*)->>'date_leve', '')::timestamp without time zone,
                    NULLIF(to_jsonb(t.*)->>'created_at', '')::timestamp without time zone,
                    CURRENT_TIMESTAMP::timestamp without time zone
                ) AS date_action
            FROM %I.%I t
            WHERE t.geom IS NOT NULL
        $fmt$,
            table_row.table_schema,
            table_row.table_name,
            id_text_expr,
            table_row.table_schema,
            table_row.table_name,
            table_row.table_name,
            table_row.table_schema,
            table_row.table_schema,
            id_text_expr,
            id_text_expr,
            id_text_expr,
            id_text_expr,
            table_row.table_schema,
            table_row.table_name
        );

        union_sql := CASE
            WHEN union_sql = '' THEN table_sql
            ELSE union_sql || E'\nUNION ALL\n' || table_sql
        END;
    END LOOP;

    IF union_sql = '' THEN
        union_sql := $empty$
            SELECT
                NULL::text AS objet_uid,
                NULL::varchar(30) AS nom_schema,
                NULL::varchar(100) AS nom_table,
                NULL::varchar(100) AS nom_classe,
                NULL::varchar(10) AS metier,
                NULL::integer AS id_objet,
                NULL::varchar(254) AS cle_ligne,
                NULL::varchar(254) AS uuid_objet,
                NULL::integer AS id_agent_crea,
                false AS anomalie,
                NULL::text AS type_anomalie,
                NULL::text AS mode_localisation,
                NULL::varchar(30) AS type_geometrie,
                NULL::varchar(20) AS famille_geometrie,
                0::integer AS nb_photos_renseignees,
                CURRENT_TIMESTAMP::timestamp without time zone AS date_action
            WHERE false
        $empty$;
    END IF;

    EXECUTE 'CREATE VIEW public.vw_srm_objet_fact AS ' || union_sql;
END $$;

CREATE VIEW public.vw_srm_objet_dates AS
SELECT objet_uid,
       nom_schema,
       nom_table,
       metier,
       id_agent_crea AS id_agent,
       date_action::date AS date_action
FROM public.vw_srm_objet_fact;

CREATE VIEW public.vw_srm_objet_activity_fact AS
SELECT objet_uid,
       nom_schema,
       nom_table,
       metier,
       id_agent_crea AS id_agent,
       COALESCE(date_action::date, CURRENT_DATE) AS date_action,
       type_geometrie,
       famille_geometrie,
       anomalie,
       nb_photos_renseignees
FROM public.vw_srm_objet_fact;

CREATE VIEW public.vw_metrics_agent_jour AS
SELECT md5(concat_ws('|',
           COALESCE(id_agent_crea::text, '-'),
           nom_schema,
           nom_table,
           COALESCE(date_action::date, CURRENT_DATE)::text
       )) AS metric_uid,
       COALESCE(date_action::date, CURRENT_DATE) AS jour,
       id_agent_crea AS id_agent,
       nom_schema,
       nom_table,
       metier,
       type_geometrie,
       famille_geometrie,
       count(*)::bigint AS nb_objets_crees,
       count(*) FILTER (WHERE anomalie)::bigint AS nb_objets_anomalie,
       count(*) FILTER (WHERE nb_photos_renseignees > 0)::bigint AS nb_objets_avec_photo,
       COALESCE(sum(nb_photos_renseignees), 0)::bigint AS nb_photos_renseignees,
       0::bigint AS nb_photos_uploadees,
       0::bigint AS nb_objets_incomplets_signales,
       0::bigint AS nb_objets_incomplets_completes,
       0::bigint AS nb_modifications_terrain,
       0::bigint AS nb_validations_terrain,
       0::bigint AS nb_corrections_backoffice,
       0::bigint AS nb_corrections_superviseur,
       0::bigint AS nb_reouvertures,
       0::bigint AS nb_evenements_mobiles,
       0::bigint AS nb_attributs_mobiles,
       0::bigint AS nb_sessions_login,
       0::bigint AS nb_sessions_logout,
       0::bigint AS nb_evenements_sync
FROM public.vw_srm_objet_fact
GROUP BY COALESCE(date_action::date, CURRENT_DATE),
         id_agent_crea,
         nom_schema,
         nom_table,
         metier,
         type_geometrie,
         famille_geometrie;

CREATE VIEW public.vw_metrics_agent_semaine AS
SELECT md5(concat_ws('|',
           'week',
           id_agent::text,
           nom_schema,
           nom_table,
           date_trunc('week', jour::timestamp with time zone)::date::text
       )) AS metric_uid,
       date_trunc('week', jour::timestamp with time zone)::date AS semaine_debut,
       date_trunc('week', jour::timestamp with time zone)::date + 6 AS semaine_fin,
       EXTRACT(isoyear FROM jour)::integer AS annee_iso,
       EXTRACT(week FROM jour)::integer AS semaine_iso,
       id_agent,
       nom_schema,
       nom_table,
       metier,
       type_geometrie,
       famille_geometrie,
       sum(nb_objets_crees)::bigint AS nb_objets_crees,
       sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
       sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
       sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
       sum(nb_photos_uploadees)::bigint AS nb_photos_uploadees,
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
GROUP BY date_trunc('week', jour::timestamp with time zone)::date,
         EXTRACT(isoyear FROM jour),
         EXTRACT(week FROM jour),
         id_agent,
         nom_schema,
         nom_table,
         metier,
         type_geometrie,
         famille_geometrie;

CREATE VIEW public.vw_metrics_agent_mois AS
SELECT md5(concat_ws('|',
           'month',
           id_agent::text,
           nom_schema,
           nom_table,
           date_trunc('month', jour::timestamp with time zone)::date::text
       )) AS metric_uid,
       date_trunc('month', jour::timestamp with time zone)::date AS mois,
       EXTRACT(year FROM jour)::integer AS annee,
       EXTRACT(month FROM jour)::integer AS mois_numero,
       id_agent,
       nom_schema,
       nom_table,
       metier,
       type_geometrie,
       famille_geometrie,
       sum(nb_objets_crees)::bigint AS nb_objets_crees,
       sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
       sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
       sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
       sum(nb_photos_uploadees)::bigint AS nb_photos_uploadees,
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
GROUP BY date_trunc('month', jour::timestamp with time zone)::date,
         EXTRACT(year FROM jour),
         EXTRACT(month FROM jour),
         id_agent,
         nom_schema,
         nom_table,
         metier,
         type_geometrie,
         famille_geometrie;

CREATE VIEW public.vw_metrics_agent_public_jour AS
SELECT md5(concat_ws('|', 'public-jour', id_agent::text, jour::text)) AS metric_uid,
       jour,
       id_agent,
       sum(nb_objets_crees)::bigint AS nb_objets_crees,
       sum(CASE WHEN famille_geometrie = 'POINT' THEN nb_objets_crees ELSE 0 END)::bigint AS nb_points,
       sum(CASE WHEN famille_geometrie = 'LINE' THEN nb_objets_crees ELSE 0 END)::bigint AS nb_lignes,
       sum(CASE WHEN famille_geometrie = 'POLYGON' THEN nb_objets_crees ELSE 0 END)::bigint AS nb_surfaces,
       sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN round((sum(nb_objets_anomalie)::numeric * 100) / sum(nb_objets_crees)::numeric, 2)::double precision
            ELSE 0::double precision END AS taux_anomalie_pct,
       sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN round((sum(nb_objets_avec_photo)::numeric * 100) / sum(nb_objets_crees)::numeric, 2)::double precision
            ELSE 0::double precision END AS taux_objets_avec_photo_pct,
       sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
       sum(nb_photos_uploadees)::bigint AS nb_photos_uploadees,
       CASE WHEN sum(nb_objets_crees) > 0
            THEN round(sum(nb_photos_renseignees)::numeric / sum(nb_objets_crees)::numeric, 2)::double precision
            ELSE 0::double precision END AS moyenne_photos_par_objet,
       sum(nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
       sum(nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
       (sum(nb_objets_incomplets_signales) - sum(nb_objets_incomplets_completes))::bigint AS solde_incomplets,
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
       true AS actif,
       1::bigint AS nb_jours_actifs
FROM public.vw_metrics_agent_jour
GROUP BY jour, id_agent;

CREATE VIEW public.vw_metrics_agent_public_semaine AS
SELECT md5(concat_ws('|', 'public-week', id_agent::text, date_trunc('week', jour::timestamp with time zone)::date::text)) AS metric_uid,
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
       0::double precision AS taux_anomalie_pct,
       sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
       0::double precision AS taux_objets_avec_photo_pct,
       sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
       sum(nb_photos_uploadees)::bigint AS nb_photos_uploadees,
       0::double precision AS moyenne_photos_par_objet,
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

CREATE VIEW public.vw_metrics_agent_public_mois AS
SELECT md5(concat_ws('|', 'public-month', id_agent::text, date_trunc('month', jour::timestamp with time zone)::date::text)) AS metric_uid,
       date_trunc('month', jour::timestamp with time zone)::date AS mois,
       EXTRACT(year FROM jour)::integer AS annee,
       EXTRACT(month FROM jour)::integer AS mois_numero,
       id_agent,
       sum(nb_objets_crees)::bigint AS nb_objets_crees,
       sum(nb_points)::bigint AS nb_points,
       sum(nb_lignes)::bigint AS nb_lignes,
       sum(nb_surfaces)::bigint AS nb_surfaces,
       sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
       0::double precision AS taux_anomalie_pct,
       sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
       0::double precision AS taux_objets_avec_photo_pct,
       sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
       sum(nb_photos_uploadees)::bigint AS nb_photos_uploadees,
       0::double precision AS moyenne_photos_par_objet,
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

CREATE VIEW public.vw_metrics_agent_period AS
SELECT md5(concat_ws('|', 'period', id_agent::text, jour::text)) AS metric_uid,
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

CREATE VIEW public.vw_metrics_agent_public_resume AS
SELECT md5(concat_ws('|', 'public-resume', id_agent::text)) AS metric_uid,
       id_agent,
       min(jour) AS premiere_activite,
       max(jour) AS derniere_activite,
       count(DISTINCT jour)::bigint AS nb_jours_actifs,
       sum(nb_objets_crees)::bigint AS nb_objets_crees_total,
       sum(nb_points)::bigint AS nb_points_total,
       sum(nb_lignes)::bigint AS nb_lignes_total,
       sum(nb_surfaces)::bigint AS nb_surfaces_total,
       sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie_total,
       0::double precision AS taux_anomalie_global_pct,
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

CREATE VIEW public.vw_metrics_agent_resume AS
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

CREATE VIEW public.vw_metrics_agent_table_period AS
SELECT md5(concat_ws('|', 'jour', id_agent::text, nom_schema, nom_table, jour::text)) AS metric_uid,
       'jour'::varchar(10) AS grain,
       jour AS periode_debut,
       jour AS periode_fin,
       EXTRACT(year FROM jour)::integer AS annee,
       EXTRACT(month FROM jour)::integer AS mois_numero,
       EXTRACT(isoyear FROM jour)::integer AS annee_iso,
       EXTRACT(week FROM jour)::integer AS semaine_iso,
       id_agent,
       nom_schema,
       nom_table,
       metier,
       type_geometrie,
       famille_geometrie,
       nb_objets_crees,
       nb_objets_anomalie,
       nb_objets_avec_photo,
       nb_photos_renseignees,
       nb_photos_uploadees,
       nb_objets_incomplets_signales,
       nb_objets_incomplets_completes,
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
       0::bigint AS nb_interventions_signalees,
       0::bigint AS nb_interventions_terrain_traitees,
       0::bigint AS nb_interventions_cloturees
FROM public.vw_metrics_agent_jour;

CREATE VIEW public.vw_srm_photo_fact AS
SELECT (to_jsonb(t.*)->>'id_photo')::text AS photo_uid,
       to_jsonb(t.*)->>'nom_table' AS nom_table,
       NULL::integer AS id_objet,
       CASE WHEN (to_jsonb(t.*)->>'id_agent_crea') ~ '^[0-9]+$' THEN (to_jsonb(t.*)->>'id_agent_crea')::integer ELSE NULL::integer END AS id_agent,
       NULLIF(to_jsonb(t.*)->>'date_upload', '')::timestamp without time zone AS date_photo,
       CASE WHEN (to_jsonb(t.*)->>'num_photo') ~ '^[0-9]+$' THEN (to_jsonb(t.*)->>'num_photo')::integer ELSE NULL::integer END AS photo_slot
FROM public.objet_photo t;

CREATE VIEW public.vw_srm_incomplet_fact AS
SELECT (to_jsonb(t.*)->>'id_incomplet')::text AS event_uid,
       to_jsonb(t.*)->>'nom_table' AS nom_table,
       CASE WHEN (to_jsonb(t.*)->>'id_objet') ~ '^[0-9]+$' THEN (to_jsonb(t.*)->>'id_objet')::integer ELSE NULL::integer END AS id_objet,
       CASE WHEN (to_jsonb(t.*)->>'id_agent_incomplet') ~ '^[0-9]+$' THEN (to_jsonb(t.*)->>'id_agent_incomplet')::integer ELSE NULL::integer END AS id_agent,
       to_jsonb(t.*)->>'statut' AS statut,
       NULLIF(to_jsonb(t.*)->>'date_signalement', '')::timestamp without time zone AS date_signalement,
       NULLIF(to_jsonb(t.*)->>'date_completion', '')::timestamp without time zone AS date_completion
FROM public.objet_incomplet t;

CREATE VIEW public.vw_srm_intervention_fact AS
SELECT (to_jsonb(t.*)->>'id')::text AS event_uid,
       to_jsonb(t.*)->>'nom_table' AS nom_table,
       CASE WHEN (to_jsonb(t.*)->>'id_objet') ~ '^[0-9]+$' THEN (to_jsonb(t.*)->>'id_objet')::integer ELSE NULL::integer END AS id_objet,
       CASE
           WHEN COALESCE(to_jsonb(t.*)->>'id_user_terrain', to_jsonb(t.*)->>'id_user_bureau', to_jsonb(t.*)->>'id_user_exploitant') ~ '^[0-9]+$'
           THEN COALESCE(to_jsonb(t.*)->>'id_user_terrain', to_jsonb(t.*)->>'id_user_bureau', to_jsonb(t.*)->>'id_user_exploitant')::integer
           ELSE NULL::integer
       END AS id_agent,
       to_jsonb(t.*)->>'etat_terrain' AS etat_terrain,
       to_jsonb(t.*)->>'statut' AS statut,
       COALESCE(NULLIF(to_jsonb(t.*)->>'created_at', '')::timestamp without time zone, NULLIF(to_jsonb(t.*)->>'date_creation', '')::timestamp without time zone) AS date_signalement,
       NULLIF(to_jsonb(t.*)->>'updated_at', '')::timestamp without time zone AS updated_at
FROM public.intervention_anomalie t;

CREATE VIEW public.vw_srm_historique_fact AS
SELECT (to_jsonb(t.*)->>'id')::text AS event_uid,
       to_jsonb(t.*)->>'nom_table' AS nom_table,
       CASE WHEN (to_jsonb(t.*)->>'id_objet') ~ '^[0-9]+$' THEN (to_jsonb(t.*)->>'id_objet')::integer ELSE NULL::integer END AS id_objet,
       to_jsonb(t.*)->>'action' AS action,
       to_jsonb(t.*)->>'source' AS source,
       CASE WHEN (to_jsonb(t.*)->>'id_user') ~ '^[0-9]+$' THEN (to_jsonb(t.*)->>'id_user')::integer ELSE NULL::integer END AS id_agent,
       NULLIF(to_jsonb(t.*)->>'date_action', '')::timestamp without time zone AS date_action
FROM public.historique_action t;
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0027_show_asst_bassin_versant_mobile"),
    ]

    operations = [
        migrations.RunSQL(
            RESTORE_MOBILE_METRICS_VIEWS_SQL,
            reverse_sql=migrations.RunSQL.noop,
        ),
    ]
