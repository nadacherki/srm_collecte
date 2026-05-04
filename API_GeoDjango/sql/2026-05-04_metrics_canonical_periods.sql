BEGIN;

-- Metrics cleanup / compatibility boundary.
-- SRM_bureau remains the functional reference, but the repeated day/week/month
-- views are now generated from one canonical period structure.

DROP VIEW IF EXISTS public.vw_metrics_agent_public_resume CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_jour CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_jour CASCADE;

DROP VIEW IF EXISTS public.vw_metrics_agent_resume CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_period CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_table_period CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_table_day CASCADE;
DROP VIEW IF EXISTS public.vw_srm_intervention_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_objet_activity_fact CASCADE;

DROP VIEW IF EXISTS public.vw_metrics_projet_resume CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_jour CASCADE;
DROP VIEW IF EXISTS public.vw_srm_mission_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_historique_mobile_fact CASCADE;

CREATE OR REPLACE VIEW public.vw_srm_objet_activity_fact AS
SELECT
    o.objet_uid,
    o.nom_schema,
    o.nom_table,
    o.nom_classe,
    o.metier,
    o.id_objet,
    o.cle_ligne,
    o.uuid_objet,
    o.id_agent_crea,
    o.anomalie,
    o.type_anomalie,
    o.mode_localisation,
    o.type_geometrie,
    o.famille_geometrie,
    COALESCE(p.nb_photos_renseignees, 0)::integer AS nb_photos_renseignees,
    o.updated_at,
    o.date_creation_historique,
    o.date_premier_journal_mobile,
    o.date_premiere_reception_mobile,
    o.date_creation_terrain,
    COALESCE(
        (o.date_creation_terrain AT TIME ZONE 'Africa/Casablanca')::date,
        o.jour_creation_terrain
    ) AS jour_creation_terrain,
    o.date_derniere_action,
    o.date_derniere_modification_terrain,
    o.date_derniere_validation_terrain,
    o.date_derniere_correction_backoffice,
    o.date_derniere_correction_superviseur,
    o.date_derniere_reouverture
FROM public.vw_srm_objet_dates o
LEFT JOIN (
    SELECT
        nom_schema,
        nom_table,
        uuid_objet,
        count(*) FILTER (WHERE actif IS DISTINCT FROM false)::integer AS nb_photos_renseignees
    FROM public.vw_srm_photo_fact
    GROUP BY nom_schema, nom_table, uuid_objet
) p
    ON p.nom_schema = o.nom_schema
   AND p.nom_table = o.nom_table
   AND p.uuid_objet = o.uuid_objet;

CREATE OR REPLACE VIEW public.vw_srm_intervention_fact AS
SELECT
    md5(concat_ws('|', 'intervention', i.id::text)) AS intervention_uid,
    i.id AS id_intervention,
    i.id_objet,
    i.uuid_objet,
    COALESCE(
        o.nom_schema,
        CASE
            WHEN position('.' in COALESCE(i.nom_table, '')) > 0 THEN NULLIF(split_part(i.nom_table, '.', 1), '')
            ELSE NULL
        END
    )::varchar(30) AS nom_schema,
    COALESCE(
        o.nom_table,
        CASE
            WHEN position('.' in COALESCE(i.nom_table, '')) > 0 THEN NULLIF(split_part(i.nom_table, '.', 2), '')
            ELSE NULLIF(i.nom_table, '')
        END,
        NULLIF(i.nom_table, '')
    )::varchar(100) AS nom_table,
    COALESCE(o.nom_classe, i.nom_classe)::varchar(100) AS nom_classe,
    COALESCE(
        o.metier,
        CASE
            WHEN position('.' in COALESCE(i.nom_table, '')) > 0 THEN NULLIF(split_part(i.nom_table, '.', 1), '')
            ELSE NULL
        END
    )::varchar(10) AS metier,
    o.type_geometrie,
    o.famille_geometrie,
    i.retour_terrain,
    i.statut,
    i.responsable_actuel,
    i.etat_terrain,
    i.etat_exploitant,
    i.etat_bureau,
    i.date_creation,
    i.date_creation::date AS jour_creation,
    i.date_terrain,
    i.date_terrain::date AS jour_terrain,
    i.date_exploitant,
    i.date_exploitant::date AS jour_exploitant,
    i.date_bureau,
    i.date_bureau::date AS jour_bureau,
    i.date_cloture,
    i.date_cloture::date AS jour_cloture,
    i.id_user_terrain,
    i.id_user_exploitant,
    i.id_user_bureau,
    i.updated_at
FROM public.intervention_anomalie i
LEFT JOIN public.vw_srm_objet_fact o
    ON o.id_objet = i.id_objet
   AND (
        o.uuid_objet IS NOT DISTINCT FROM i.uuid_objet
        OR i.uuid_objet IS NULL
        OR i.uuid_objet = ''
   )
   AND (
        i.nom_table IS NULL
        OR i.nom_table = ''
        OR i.nom_table = o.nom_schema || '.' || o.nom_table
        OR i.nom_table = o.nom_table
   );

CREATE OR REPLACE VIEW public.vw_metrics_agent_table_day AS
WITH raw_metrics AS (
    SELECT
        o.jour_creation_terrain AS jour,
        o.id_agent_crea AS id_agent,
        o.nom_schema,
        o.nom_table,
        o.metier,
        o.type_geometrie,
        o.famille_geometrie,
        count(*)::bigint AS nb_objets_crees,
        count(*) FILTER (WHERE o.anomalie IS TRUE)::bigint AS nb_objets_anomalie,
        count(*) FILTER (WHERE o.nb_photos_renseignees > 0)::bigint AS nb_objets_avec_photo,
        0::bigint AS nb_photos_renseignees,
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
        0::bigint AS nb_evenements_sync,
        0::bigint AS nb_interventions_signalees,
        0::bigint AS nb_interventions_terrain_traitees,
        0::bigint AS nb_interventions_cloturees
    FROM public.vw_srm_objet_activity_fact o
    WHERE o.jour_creation_terrain IS NOT NULL
    GROUP BY
        o.jour_creation_terrain,
        o.id_agent_crea,
        o.nom_schema,
        o.nom_table,
        o.metier,
        o.type_geometrie,
        o.famille_geometrie

    UNION ALL

    SELECT
        COALESCE(
            (p.date_photo_reference AT TIME ZONE 'Africa/Casablanca')::date,
            p.jour_photo
        ) AS jour,
        p.id_agent,
        p.nom_schema,
        p.nom_table,
        p.metier,
        p.type_geometrie,
        p.famille_geometrie,
        0::bigint,
        0::bigint,
        0::bigint,
        count(*)::bigint,
        count(*) FILTER (WHERE p.actif IS DISTINCT FROM false)::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint
    FROM public.vw_srm_photo_fact p
    WHERE COALESCE(
        (p.date_photo_reference AT TIME ZONE 'Africa/Casablanca')::date,
        p.jour_photo
    ) IS NOT NULL
    GROUP BY
        COALESCE(
            (p.date_photo_reference AT TIME ZONE 'Africa/Casablanca')::date,
            p.jour_photo
        ),
        p.id_agent,
        p.nom_schema,
        p.nom_table,
        p.metier,
        p.type_geometrie,
        p.famille_geometrie

    UNION ALL

    SELECT
        i.jour_signalement AS jour,
        i.id_agent_signal AS id_agent,
        i.nom_schema,
        i.nom_table,
        i.metier,
        i.type_geometrie,
        i.famille_geometrie,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        count(*)::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint
    FROM public.vw_srm_incomplet_fact i
    WHERE i.jour_signalement IS NOT NULL
    GROUP BY
        i.jour_signalement,
        i.id_agent_signal,
        i.nom_schema,
        i.nom_table,
        i.metier,
        i.type_geometrie,
        i.famille_geometrie

    UNION ALL

    SELECT
        i.jour_completion AS jour,
        i.id_agent_retour AS id_agent,
        i.nom_schema,
        i.nom_table,
        i.metier,
        i.type_geometrie,
        i.famille_geometrie,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        count(*)::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint
    FROM public.vw_srm_incomplet_fact i
    WHERE i.jour_completion IS NOT NULL
    GROUP BY
        i.jour_completion,
        i.id_agent_retour,
        i.nom_schema,
        i.nom_table,
        i.metier,
        i.type_geometrie,
        i.famille_geometrie

    UNION ALL

    SELECT
        COALESCE(
            (h.date_action AT TIME ZONE 'Africa/Casablanca')::date,
            h.jour_action
        ) AS jour,
        h.id_agent,
        h.nom_schema::varchar(30),
        h.nom_table::varchar(100),
        h.metier,
        h.type_geometrie,
        h.famille_geometrie,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        count(*) FILTER (WHERE lower(h.type_action) IN ('update', 'modification', 'modifier'))::bigint,
        count(*) FILTER (WHERE lower(h.type_action) IN ('validate', 'validation', 'valider'))::bigint,
        count(*) FILTER (WHERE lower(h.type_action) IN ('correction_backoffice', 'correction backoffice', 'backoffice'))::bigint,
        count(*) FILTER (WHERE lower(h.type_action) IN ('correction_superviseur', 'correction superviseur', 'superviseur'))::bigint,
        count(*) FILTER (WHERE lower(h.type_action) IN ('reouverture', 'reouvert', 'reopen'))::bigint,
        count(*) FILTER (WHERE lower(h.type_action) IN ('insert', 'update', 'validate'))::bigint,
        count(*)::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint
    FROM public.vw_srm_historique_fact h
    WHERE COALESCE(
        (h.date_action AT TIME ZONE 'Africa/Casablanca')::date,
        h.jour_action
    ) IS NOT NULL
    GROUP BY
        COALESCE(
            (h.date_action AT TIME ZONE 'Africa/Casablanca')::date,
            h.jour_action
        ),
        h.id_agent,
        h.nom_schema,
        h.nom_table,
        h.metier,
        h.type_geometrie,
        h.famille_geometrie

    UNION ALL

    SELECT
        (s.started_at AT TIME ZONE 'Africa/Casablanca')::date AS jour,
        s.id_agent,
        NULL::varchar(30) AS nom_schema,
        NULL::varchar(100) AS nom_table,
        NULL::varchar(10) AS metier,
        NULL::varchar(30) AS type_geometrie,
        NULL::varchar(20) AS famille_geometrie,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        count(*)::bigint,
        0::bigint,
        0::bigint,
        0::bigint
    FROM public.sync_session s
    WHERE s.started_at IS NOT NULL
    GROUP BY (s.started_at AT TIME ZONE 'Africa/Casablanca')::date, s.id_agent

    UNION ALL

    SELECT
        v.jour_creation AS jour,
        COALESCE(v.id_user_terrain, v.id_user_bureau, v.id_user_exploitant) AS id_agent,
        v.nom_schema,
        v.nom_table,
        v.metier,
        v.type_geometrie,
        v.famille_geometrie,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        count(*)::bigint,
        0::bigint,
        0::bigint
    FROM public.vw_srm_intervention_fact v
    WHERE v.jour_creation IS NOT NULL
    GROUP BY
        v.jour_creation,
        COALESCE(v.id_user_terrain, v.id_user_bureau, v.id_user_exploitant),
        v.nom_schema,
        v.nom_table,
        v.metier,
        v.type_geometrie,
        v.famille_geometrie

    UNION ALL

    SELECT
        v.jour_terrain AS jour,
        v.id_user_terrain AS id_agent,
        v.nom_schema,
        v.nom_table,
        v.metier,
        v.type_geometrie,
        v.famille_geometrie,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        count(*) FILTER (WHERE v.etat_terrain = 'traite')::bigint,
        0::bigint
    FROM public.vw_srm_intervention_fact v
    WHERE v.jour_terrain IS NOT NULL
    GROUP BY
        v.jour_terrain,
        v.id_user_terrain,
        v.nom_schema,
        v.nom_table,
        v.metier,
        v.type_geometrie,
        v.famille_geometrie

    UNION ALL

    SELECT
        v.jour_cloture AS jour,
        COALESCE(v.id_user_exploitant, v.id_user_bureau, v.id_user_terrain) AS id_agent,
        v.nom_schema,
        v.nom_table,
        v.metier,
        v.type_geometrie,
        v.famille_geometrie,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        0::bigint,
        count(*)::bigint
    FROM public.vw_srm_intervention_fact v
    WHERE v.jour_cloture IS NOT NULL
    GROUP BY
        v.jour_cloture,
        COALESCE(v.id_user_exploitant, v.id_user_bureau, v.id_user_terrain),
        v.nom_schema,
        v.nom_table,
        v.metier,
        v.type_geometrie,
        v.famille_geometrie
)
SELECT
    md5(concat_ws(
        '|',
        'agent_table_day',
        jour::text,
        COALESCE(id_agent::text, ''),
        COALESCE(nom_schema, ''),
        COALESCE(nom_table, ''),
        COALESCE(type_geometrie, ''),
        COALESCE(famille_geometrie, '')
    )) AS metric_uid,
    jour,
    id_agent,
    nom_schema::varchar(30) AS nom_schema,
    nom_table::varchar(100) AS nom_table,
    metier::varchar(10) AS metier,
    type_geometrie::varchar(30) AS type_geometrie,
    famille_geometrie::varchar(20) AS famille_geometrie,
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
    sum(nb_evenements_sync)::bigint AS nb_evenements_sync,
    sum(nb_interventions_signalees)::bigint AS nb_interventions_signalees,
    sum(nb_interventions_terrain_traitees)::bigint AS nb_interventions_terrain_traitees,
    sum(nb_interventions_cloturees)::bigint AS nb_interventions_cloturees
FROM raw_metrics
WHERE jour IS NOT NULL
GROUP BY
    jour,
    id_agent,
    nom_schema,
    nom_table,
    metier,
    type_geometrie,
    famille_geometrie;

CREATE OR REPLACE VIEW public.vw_metrics_agent_table_period AS
SELECT
    md5(concat_ws('|', 'agent_table_period', 'jour', metric_uid)) AS metric_uid,
    'jour'::varchar(10) AS grain,
    jour AS periode_debut,
    jour AS periode_fin,
    EXTRACT(YEAR FROM jour)::integer AS annee,
    EXTRACT(MONTH FROM jour)::integer AS mois_numero,
    EXTRACT(ISOYEAR FROM jour)::integer AS annee_iso,
    EXTRACT(WEEK FROM jour)::integer AS semaine_iso,
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
    nb_interventions_signalees,
    nb_interventions_terrain_traitees,
    nb_interventions_cloturees
FROM public.vw_metrics_agent_table_day

UNION ALL

SELECT
    md5(concat_ws(
        '|',
        'agent_table_period',
        'semaine',
        date_trunc('week', jour)::date::text,
        COALESCE(id_agent::text, ''),
        COALESCE(nom_schema, ''),
        COALESCE(nom_table, ''),
        COALESCE(type_geometrie, ''),
        COALESCE(famille_geometrie, '')
    )) AS metric_uid,
    'semaine'::varchar(10) AS grain,
    date_trunc('week', jour)::date AS periode_debut,
    (date_trunc('week', jour)::date + 6) AS periode_fin,
    EXTRACT(YEAR FROM date_trunc('week', jour)::date)::integer AS annee,
    EXTRACT(MONTH FROM date_trunc('week', jour)::date)::integer AS mois_numero,
    EXTRACT(ISOYEAR FROM jour)::integer AS annee_iso,
    EXTRACT(WEEK FROM jour)::integer AS semaine_iso,
    id_agent,
    nom_schema,
    nom_table,
    metier,
    type_geometrie,
    famille_geometrie,
    sum(nb_objets_crees)::bigint,
    sum(nb_objets_anomalie)::bigint,
    sum(nb_objets_avec_photo)::bigint,
    sum(nb_photos_renseignees)::bigint,
    sum(nb_photos_uploadees)::bigint,
    sum(nb_objets_incomplets_signales)::bigint,
    sum(nb_objets_incomplets_completes)::bigint,
    sum(nb_modifications_terrain)::bigint,
    sum(nb_validations_terrain)::bigint,
    sum(nb_corrections_backoffice)::bigint,
    sum(nb_corrections_superviseur)::bigint,
    sum(nb_reouvertures)::bigint,
    sum(nb_evenements_mobiles)::bigint,
    sum(nb_attributs_mobiles)::bigint,
    sum(nb_sessions_login)::bigint,
    sum(nb_sessions_logout)::bigint,
    sum(nb_evenements_sync)::bigint,
    sum(nb_interventions_signalees)::bigint,
    sum(nb_interventions_terrain_traitees)::bigint,
    sum(nb_interventions_cloturees)::bigint
FROM public.vw_metrics_agent_table_day
GROUP BY
    date_trunc('week', jour)::date,
    EXTRACT(ISOYEAR FROM jour)::integer,
    EXTRACT(WEEK FROM jour)::integer,
    id_agent,
    nom_schema,
    nom_table,
    metier,
    type_geometrie,
    famille_geometrie

UNION ALL

SELECT
    md5(concat_ws(
        '|',
        'agent_table_period',
        'mois',
        date_trunc('month', jour)::date::text,
        COALESCE(id_agent::text, ''),
        COALESCE(nom_schema, ''),
        COALESCE(nom_table, ''),
        COALESCE(type_geometrie, ''),
        COALESCE(famille_geometrie, '')
    )) AS metric_uid,
    'mois'::varchar(10) AS grain,
    date_trunc('month', jour)::date AS periode_debut,
    (date_trunc('month', jour)::date + interval '1 month - 1 day')::date AS periode_fin,
    EXTRACT(YEAR FROM jour)::integer AS annee,
    EXTRACT(MONTH FROM jour)::integer AS mois_numero,
    NULL::integer AS annee_iso,
    NULL::integer AS semaine_iso,
    id_agent,
    nom_schema,
    nom_table,
    metier,
    type_geometrie,
    famille_geometrie,
    sum(nb_objets_crees)::bigint,
    sum(nb_objets_anomalie)::bigint,
    sum(nb_objets_avec_photo)::bigint,
    sum(nb_photos_renseignees)::bigint,
    sum(nb_photos_uploadees)::bigint,
    sum(nb_objets_incomplets_signales)::bigint,
    sum(nb_objets_incomplets_completes)::bigint,
    sum(nb_modifications_terrain)::bigint,
    sum(nb_validations_terrain)::bigint,
    sum(nb_corrections_backoffice)::bigint,
    sum(nb_corrections_superviseur)::bigint,
    sum(nb_reouvertures)::bigint,
    sum(nb_evenements_mobiles)::bigint,
    sum(nb_attributs_mobiles)::bigint,
    sum(nb_sessions_login)::bigint,
    sum(nb_sessions_logout)::bigint,
    sum(nb_evenements_sync)::bigint,
    sum(nb_interventions_signalees)::bigint,
    sum(nb_interventions_terrain_traitees)::bigint,
    sum(nb_interventions_cloturees)::bigint
FROM public.vw_metrics_agent_table_day
GROUP BY
    date_trunc('month', jour)::date,
    EXTRACT(YEAR FROM jour)::integer,
    EXTRACT(MONTH FROM jour)::integer,
    id_agent,
    nom_schema,
    nom_table,
    metier,
    type_geometrie,
    famille_geometrie;

CREATE OR REPLACE VIEW public.vw_metrics_agent_period AS
WITH periodized AS (
    SELECT
        'jour'::varchar(10) AS grain,
        jour AS periode_debut,
        jour AS periode_fin,
        EXTRACT(YEAR FROM jour)::integer AS annee,
        EXTRACT(MONTH FROM jour)::integer AS mois_numero,
        EXTRACT(ISOYEAR FROM jour)::integer AS annee_iso,
        EXTRACT(WEEK FROM jour)::integer AS semaine_iso,
        jour,
        id_agent,
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
        nb_interventions_signalees,
        nb_interventions_terrain_traitees,
        nb_interventions_cloturees
    FROM public.vw_metrics_agent_table_day

    UNION ALL

    SELECT
        'semaine'::varchar(10) AS grain,
        date_trunc('week', jour)::date AS periode_debut,
        (date_trunc('week', jour)::date + 6) AS periode_fin,
        EXTRACT(YEAR FROM date_trunc('week', jour)::date)::integer AS annee,
        EXTRACT(MONTH FROM date_trunc('week', jour)::date)::integer AS mois_numero,
        EXTRACT(ISOYEAR FROM jour)::integer AS annee_iso,
        EXTRACT(WEEK FROM jour)::integer AS semaine_iso,
        jour,
        id_agent,
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
        nb_interventions_signalees,
        nb_interventions_terrain_traitees,
        nb_interventions_cloturees
    FROM public.vw_metrics_agent_table_day

    UNION ALL

    SELECT
        'mois'::varchar(10) AS grain,
        date_trunc('month', jour)::date AS periode_debut,
        (date_trunc('month', jour)::date + interval '1 month - 1 day')::date AS periode_fin,
        EXTRACT(YEAR FROM jour)::integer AS annee,
        EXTRACT(MONTH FROM jour)::integer AS mois_numero,
        NULL::integer AS annee_iso,
        NULL::integer AS semaine_iso,
        jour,
        id_agent,
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
        nb_interventions_signalees,
        nb_interventions_terrain_traitees,
        nb_interventions_cloturees
    FROM public.vw_metrics_agent_table_day
)
SELECT
    md5(concat_ws(
        '|',
        'agent_period',
        grain,
        periode_debut::text,
        COALESCE(id_agent::text, '')
    )) AS metric_uid,
    grain,
    periode_debut,
    periode_fin,
    annee,
    mois_numero,
    annee_iso,
    semaine_iso,
    id_agent,
    sum(nb_objets_crees)::bigint AS nb_objets_crees,
    COALESCE(sum(nb_objets_crees) FILTER (WHERE famille_geometrie = 'POINT'), 0)::bigint AS nb_points,
    COALESCE(sum(nb_objets_crees) FILTER (WHERE famille_geometrie = 'LIGNE'), 0)::bigint AS nb_lignes,
    COALESCE(sum(nb_objets_crees) FILTER (WHERE famille_geometrie = 'SURFACE'), 0)::bigint AS nb_surfaces,
    sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
    CASE
        WHEN sum(nb_objets_crees) = 0 THEN 0::double precision
        ELSE round((sum(nb_objets_anomalie)::numeric * 100.0 / sum(nb_objets_crees)::numeric), 2)::double precision
    END AS taux_anomalie_pct,
    sum(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
    CASE
        WHEN sum(nb_objets_crees) = 0 THEN 0::double precision
        ELSE round((sum(nb_objets_avec_photo)::numeric * 100.0 / sum(nb_objets_crees)::numeric), 2)::double precision
    END AS taux_objets_avec_photo_pct,
    sum(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
    sum(nb_photos_uploadees)::bigint AS nb_photos_uploadees,
    CASE
        WHEN sum(nb_objets_crees) = 0 THEN 0::double precision
        ELSE round((sum(nb_photos_renseignees)::numeric / sum(nb_objets_crees)::numeric), 2)::double precision
    END AS moyenne_photos_par_objet,
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
    sum(nb_interventions_signalees)::bigint AS nb_interventions_signalees,
    sum(nb_interventions_terrain_traitees)::bigint AS nb_interventions_terrain_traitees,
    sum(nb_interventions_cloturees)::bigint AS nb_interventions_cloturees,
    CASE
        WHEN count(DISTINCT CASE WHEN nb_objets_crees > 0 THEN jour END) = 0 THEN 0::double precision
        ELSE round((sum(nb_objets_crees)::numeric / (count(DISTINCT CASE WHEN nb_objets_crees > 0 THEN jour END)::numeric * 8.0)), 2)::double precision
    END AS objets_par_heure,
    (
        sum(nb_objets_crees)
        + sum(nb_photos_renseignees)
        + sum(nb_objets_incomplets_signales)
        + sum(nb_modifications_terrain)
        + sum(nb_evenements_sync)
        + sum(nb_interventions_signalees)
    ) > 0 AS actif,
    count(DISTINCT CASE WHEN nb_objets_crees > 0 THEN jour END)::bigint AS nb_jours_actifs
FROM periodized
GROUP BY
    grain,
    periode_debut,
    periode_fin,
    annee,
    mois_numero,
    annee_iso,
    semaine_iso,
    id_agent;

CREATE OR REPLACE VIEW public.vw_metrics_agent_resume AS
WITH daily AS (
    SELECT *
    FROM public.vw_metrics_agent_period
    WHERE grain = 'jour'
)
SELECT
    md5(concat_ws('|', 'agent_resume', COALESCE(id_agent::text, ''))) AS metric_uid,
    id_agent,
    min(periode_debut) FILTER (WHERE actif) AS premiere_activite,
    max(periode_debut) FILTER (WHERE actif) AS derniere_activite,
    count(*) FILTER (WHERE actif)::bigint AS nb_jours_actifs,
    sum(nb_objets_crees)::bigint AS nb_objets_crees_total,
    sum(nb_points)::bigint AS nb_points_total,
    sum(nb_lignes)::bigint AS nb_lignes_total,
    sum(nb_surfaces)::bigint AS nb_surfaces_total,
    sum(nb_objets_anomalie)::bigint AS nb_objets_anomalie_total,
    CASE
        WHEN sum(nb_objets_crees) = 0 THEN 0::double precision
        ELSE round((sum(nb_objets_anomalie)::numeric * 100.0 / sum(nb_objets_crees)::numeric), 2)::double precision
    END AS taux_anomalie_global_pct,
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
    sum(nb_interventions_signalees)::bigint AS nb_interventions_signalees_total,
    sum(nb_interventions_terrain_traitees)::bigint AS nb_interventions_terrain_traitees_total,
    sum(nb_interventions_cloturees)::bigint AS nb_interventions_cloturees_total,
    CASE
        WHEN count(*) FILTER (WHERE nb_objets_crees > 0) = 0 THEN 0::double precision
        ELSE round((sum(nb_objets_crees)::numeric / (count(*) FILTER (WHERE nb_objets_crees > 0)::numeric * 8.0)), 2)::double precision
    END AS objets_par_heure_global,
    sum(nb_objets_crees) FILTER (WHERE periode_debut >= current_date - 6)::bigint AS nb_objets_7j,
    sum(nb_objets_crees) FILTER (WHERE periode_debut >= current_date - 29)::bigint AS nb_objets_30j,
    sum(nb_objets_crees) FILTER (WHERE periode_debut >= date_trunc('month', current_date)::date)::bigint AS nb_objets_mois_courant,
    sum(nb_objets_crees) FILTER (WHERE periode_debut >= date_trunc('week', current_date)::date)::bigint AS nb_objets_semaine_courante
FROM daily
GROUP BY id_agent;

-- Compatibility views kept for the existing Django/Flutter endpoints.

CREATE OR REPLACE VIEW public.vw_metrics_agent_jour AS
SELECT
    md5(concat_ws('|', 'compat_agent_jour', metric_uid)) AS metric_uid,
    periode_debut AS jour,
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
    nb_evenements_sync
FROM public.vw_metrics_agent_table_period
WHERE grain = 'jour';

CREATE OR REPLACE VIEW public.vw_metrics_agent_semaine AS
SELECT
    md5(concat_ws('|', 'compat_agent_semaine', metric_uid)) AS metric_uid,
    periode_debut AS semaine_debut,
    periode_fin AS semaine_fin,
    annee_iso,
    semaine_iso,
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
    nb_evenements_sync
FROM public.vw_metrics_agent_table_period
WHERE grain = 'semaine';

CREATE OR REPLACE VIEW public.vw_metrics_agent_mois AS
SELECT
    md5(concat_ws('|', 'compat_agent_mois', metric_uid)) AS metric_uid,
    periode_debut AS mois,
    annee,
    mois_numero,
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
    nb_evenements_sync
FROM public.vw_metrics_agent_table_period
WHERE grain = 'mois';

CREATE OR REPLACE VIEW public.vw_metrics_agent_public_jour AS
SELECT
    md5(concat_ws('|', 'compat_agent_public_jour', metric_uid)) AS metric_uid,
    periode_debut AS jour,
    id_agent,
    nb_objets_crees,
    COALESCE(nb_points, 0) AS nb_points,
    COALESCE(nb_lignes, 0) AS nb_lignes,
    COALESCE(nb_surfaces, 0) AS nb_surfaces,
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
    nb_jours_actifs
FROM public.vw_metrics_agent_period
WHERE grain = 'jour';

CREATE OR REPLACE VIEW public.vw_metrics_agent_public_semaine AS
SELECT
    md5(concat_ws('|', 'compat_agent_public_semaine', metric_uid)) AS metric_uid,
    periode_debut AS semaine_debut,
    periode_fin AS semaine_fin,
    annee_iso,
    semaine_iso,
    id_agent,
    nb_objets_crees,
    COALESCE(nb_points, 0) AS nb_points,
    COALESCE(nb_lignes, 0) AS nb_lignes,
    COALESCE(nb_surfaces, 0) AS nb_surfaces,
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
    nb_jours_actifs
FROM public.vw_metrics_agent_period
WHERE grain = 'semaine';

CREATE OR REPLACE VIEW public.vw_metrics_agent_public_mois AS
SELECT
    md5(concat_ws('|', 'compat_agent_public_mois', metric_uid)) AS metric_uid,
    periode_debut AS mois,
    annee,
    mois_numero,
    id_agent,
    nb_objets_crees,
    COALESCE(nb_points, 0) AS nb_points,
    COALESCE(nb_lignes, 0) AS nb_lignes,
    COALESCE(nb_surfaces, 0) AS nb_surfaces,
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
    nb_jours_actifs
FROM public.vw_metrics_agent_period
WHERE grain = 'mois';

CREATE OR REPLACE VIEW public.vw_metrics_agent_public_resume AS
SELECT
    md5(concat_ws('|', 'compat_agent_public_resume', metric_uid)) AS metric_uid,
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
    objets_par_heure_global,
    COALESCE(nb_objets_7j, 0) AS nb_objets_7j,
    COALESCE(nb_objets_30j, 0) AS nb_objets_30j,
    COALESCE(nb_objets_mois_courant, 0) AS nb_objets_mois_courant,
    COALESCE(nb_objets_semaine_courante, 0) AS nb_objets_semaine_courante
FROM public.vw_metrics_agent_resume;

COMMIT;
