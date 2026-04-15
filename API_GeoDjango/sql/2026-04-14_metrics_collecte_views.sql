BEGIN;

CREATE INDEX IF NOT EXISTS objet_photo_date_upload_idx
    ON public.objet_photo (date_upload DESC);

CREATE INDEX IF NOT EXISTS objet_photo_schema_table_uuid_idx
    ON public.objet_photo (nom_schema, nom_table, uuid_objet);

CREATE INDEX IF NOT EXISTS objet_incomplet_date_signalement_idx
    ON public.objet_incomplet (date_signalement DESC);

CREATE INDEX IF NOT EXISTS objet_incomplet_date_completion_idx
    ON public.objet_incomplet (date_completion DESC);

CREATE INDEX IF NOT EXISTS objet_incomplet_nom_classe_id_objet_idx
    ON public.objet_incomplet (nom_classe, id_objet);

DROP VIEW IF EXISTS public.vw_metrics_agent_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_jour CASCADE;
DROP VIEW IF EXISTS public.vw_srm_historique_mobile_fact;
DROP VIEW IF EXISTS public.vw_srm_historique_fact;
DROP VIEW IF EXISTS public.vw_srm_incomplet_fact;
DROP VIEW IF EXISTS public.vw_srm_photo_fact;
DROP VIEW IF EXISTS public.vw_srm_objet_dates;
DROP VIEW IF EXISTS public.vw_srm_objet_fact;

DO $$
DECLARE
    rec record;
    select_sql text := '';
    is_first boolean := true;
    has_id_mission boolean;
    has_id_agent_crea boolean;
    has_anomalie boolean;
    has_type_anomalie boolean;
    has_mode_localisation boolean;
    has_updated_at boolean;
    has_photo_1 boolean;
    has_photo_2 boolean;
    has_photo_3 boolean;
    has_photo_4 boolean;
    geometry_type text;
    photo_count_expr text;
BEGIN
    FOR rec IN
        SELECT t.table_schema, t.table_name
        FROM information_schema.tables t
        WHERE t.table_schema IN ('ep', 'ass', 'elec')
          AND t.table_type = 'BASE TABLE'
          AND EXISTS (
              SELECT 1
              FROM information_schema.columns c
              WHERE c.table_schema = t.table_schema
                AND c.table_name = t.table_name
                AND c.column_name = 'fid'
          )
          AND EXISTS (
              SELECT 1
              FROM information_schema.columns c
              WHERE c.table_schema = t.table_schema
                AND c.table_name = t.table_name
                AND c.column_name = 'uuid'
          )
          AND EXISTS (
              SELECT 1
              FROM information_schema.columns c
              WHERE c.table_schema = t.table_schema
                AND c.table_name = t.table_name
                AND c.column_name = 'id_projet'
          )
        ORDER BY t.table_schema, t.table_name
    LOOP
        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'id_mission'
        ) INTO has_id_mission;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'id_agent_crea'
        ) INTO has_id_agent_crea;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'anomalie'
        ) INTO has_anomalie;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'type_anomalie'
        ) INTO has_type_anomalie;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'mode_localisation'
        ) INTO has_mode_localisation;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'updated_at'
        ) INTO has_updated_at;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'photo_1'
        ) INTO has_photo_1;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'photo_2'
        ) INTO has_photo_2;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'photo_3'
        ) INTO has_photo_3;

        SELECT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = rec.table_schema
              AND table_name = rec.table_name
              AND column_name = 'photo_4'
        ) INTO has_photo_4;

        SELECT gc.type
        INTO geometry_type
        FROM geometry_columns gc
        WHERE gc.f_table_schema = rec.table_schema
          AND gc.f_table_name = rec.table_name
        LIMIT 1;

        geometry_type := COALESCE(geometry_type, 'SANS_GEOMETRIE');
        photo_count_expr := '0';

        IF has_photo_1 THEN
            photo_count_expr := photo_count_expr
                || ' + CASE WHEN t.photo_1 IS NOT NULL AND btrim(t.photo_1::text) <> '''' THEN 1 ELSE 0 END';
        END IF;

        IF has_photo_2 THEN
            photo_count_expr := photo_count_expr
                || ' + CASE WHEN t.photo_2 IS NOT NULL AND btrim(t.photo_2::text) <> '''' THEN 1 ELSE 0 END';
        END IF;

        IF has_photo_3 THEN
            photo_count_expr := photo_count_expr
                || ' + CASE WHEN t.photo_3 IS NOT NULL AND btrim(t.photo_3::text) <> '''' THEN 1 ELSE 0 END';
        END IF;

        IF has_photo_4 THEN
            photo_count_expr := photo_count_expr
                || ' + CASE WHEN t.photo_4 IS NOT NULL AND btrim(t.photo_4::text) <> '''' THEN 1 ELSE 0 END';
        END IF;

        IF NOT is_first THEN
            select_sql := select_sql || E'\nUNION ALL\n';
        END IF;

        select_sql := select_sql || format(
$view$
SELECT
    md5(concat_ws('|', %L, %L, COALESCE(t.uuid::text, ''), t.fid::text)) AS objet_uid,
    %L::varchar(30) AS nom_schema,
    %L::varchar(100) AS nom_table,
    (%L || '.' || %L)::varchar(100) AS nom_classe,
    %L::varchar(10) AS metier,
    t.fid::integer AS id_objet,
    COALESCE(t.uuid::text, t.fid::text)::varchar(254) AS cle_ligne,
    t.uuid::varchar(254) AS uuid_objet,
    t.id_projet::integer AS id_projet,
    %s AS id_mission,
    %s AS id_agent_crea,
    %s AS anomalie,
    %s AS type_anomalie,
    %s AS mode_localisation,
    %L::varchar(30) AS type_geometrie,
    CASE
        WHEN %L IN ('POINT', 'MULTIPOINT') THEN 'POINT'
        WHEN %L IN ('LINESTRING', 'MULTILINESTRING') THEN 'LIGNE'
        WHEN %L IN ('POLYGON', 'MULTIPOLYGON') THEN 'SURFACE'
        ELSE 'AUTRE'
    END::varchar(20) AS famille_geometrie,
    (%s)::integer AS nb_photos_renseignees,
    %s AS updated_at
FROM %I.%I t
$view$,
            rec.table_schema,
            rec.table_name,
            rec.table_schema,
            rec.table_name,
            rec.table_schema,
            rec.table_name,
            rec.table_schema,
            CASE WHEN has_id_mission THEN 't.id_mission::integer' ELSE 'NULL::integer' END,
            CASE WHEN has_id_agent_crea THEN 't.id_agent_crea::integer' ELSE 'NULL::integer' END,
            CASE WHEN has_anomalie THEN 'COALESCE(t.anomalie, false)' ELSE 'false' END,
            CASE WHEN has_type_anomalie THEN 'NULLIF(t.type_anomalie::text, '''')' ELSE 'NULL::text' END,
            CASE WHEN has_mode_localisation THEN 'NULLIF(t.mode_localisation::text, '''')' ELSE 'NULL::text' END,
            geometry_type,
            geometry_type,
            geometry_type,
            geometry_type,
            photo_count_expr,
            CASE WHEN has_updated_at THEN 't.updated_at::timestamp' ELSE 'NULL::timestamp' END,
            rec.table_schema,
            rec.table_name
        );

        is_first := false;
    END LOOP;

    IF select_sql = '' THEN
        RAISE EXCEPTION 'Aucune table SRM exploitable trouvee pour construire vw_srm_objet_fact';
    END IF;

    EXECUTE 'CREATE VIEW public.vw_srm_objet_fact AS ' || select_sql;
END;
$$;

CREATE VIEW public.vw_srm_objet_dates AS
WITH historique_objet AS (
    SELECT
        h.nom_schema,
        h.nom_table,
        COALESCE(NULLIF(h.uuid_objet, ''), NULLIF(h.cle_ligne, ''), h.id_objet::text) AS cle_jointure,
        MIN(h.date_action) FILTER (WHERE h.type_action = 'CREATION') AS date_creation_historique,
        MAX(h.date_action) AS date_derniere_action,
        MAX(h.date_action) FILTER (WHERE h.type_action = 'MODIFICATION_TERRAIN') AS date_derniere_modification_terrain,
        MAX(h.date_action) FILTER (WHERE h.type_action = 'VALIDATION_TERRAIN') AS date_derniere_validation_terrain,
        MAX(h.date_action) FILTER (WHERE h.type_action = 'CORRECTION_BACKOFFICE') AS date_derniere_correction_backoffice,
        MAX(h.date_action) FILTER (WHERE h.type_action = 'CORRECTION_SUPERVISEUR') AS date_derniere_correction_superviseur,
        MAX(h.date_action) FILTER (WHERE h.type_action = 'REOUVERTURE') AS date_derniere_reouverture
    FROM public.historique_attribut h
    WHERE h.nom_schema IN ('ep', 'ass', 'elec')
    GROUP BY
        h.nom_schema,
        h.nom_table,
        COALESCE(NULLIF(h.uuid_objet, ''), NULLIF(h.cle_ligne, ''), h.id_objet::text)
),
mobile_objet AS (
    SELECT
        hm.nom_schema,
        hm.nom_table,
        COALESCE(NULLIF(hm.uuid_objet, ''), NULLIF(hm.cle_ligne, ''), hm.id_objet::text) AS cle_jointure,
        MIN(hm.date_action) AS date_premier_journal_mobile,
        MIN(hm.date_reception) AS date_premiere_reception_mobile
    FROM public.historique_mobile hm
    WHERE hm.nom_schema IN ('ep', 'ass', 'elec')
    GROUP BY
        hm.nom_schema,
        hm.nom_table,
        COALESCE(NULLIF(hm.uuid_objet, ''), NULLIF(hm.cle_ligne, ''), hm.id_objet::text)
)
SELECT
    f.*,
    h.date_creation_historique,
    m.date_premier_journal_mobile,
    m.date_premiere_reception_mobile,
    COALESCE(h.date_creation_historique, m.date_premier_journal_mobile) AS date_creation_terrain,
    COALESCE(h.date_creation_historique, m.date_premier_journal_mobile)::date AS jour_creation_terrain,
    h.date_derniere_action,
    h.date_derniere_modification_terrain,
    h.date_derniere_validation_terrain,
    h.date_derniere_correction_backoffice,
    h.date_derniere_correction_superviseur,
    h.date_derniere_reouverture
FROM public.vw_srm_objet_fact f
LEFT JOIN historique_objet h
    ON h.nom_schema = f.nom_schema
   AND h.nom_table = f.nom_table
   AND (
       h.cle_jointure = f.cle_ligne
       OR h.cle_jointure = f.uuid_objet
       OR h.cle_jointure = f.id_objet::text
   )
LEFT JOIN mobile_objet m
    ON m.nom_schema = f.nom_schema
   AND m.nom_table = f.nom_table
   AND (
       m.cle_jointure = f.cle_ligne
       OR m.cle_jointure = f.uuid_objet
       OR m.cle_jointure = f.id_objet::text
   );

CREATE VIEW public.vw_srm_photo_fact AS
SELECT
    md5(concat_ws('|', 'photo', p.id_photo::text, COALESCE(p.uuid_objet, ''))) AS photo_uid,
    p.id_photo,
    o.id_objet,
    p.uuid_objet,
    p.nom_schema,
    p.nom_table,
    (p.nom_schema || '.' || p.nom_table)::varchar(100) AS nom_classe,
    COALESCE(o.metier, p.nom_schema)::varchar(10) AS metier,
    COALESCE(p.id_projet, o.id_projet) AS id_projet,
    COALESCE(p.id_mission, o.id_mission) AS id_mission,
    COALESCE(p.id_agent_crea, o.id_agent_crea) AS id_agent,
    o.type_geometrie,
    o.famille_geometrie,
    p.num_photo,
    p.nom_fichier,
    p.chemin_relatif,
    p.hash_sha256,
    p.mime_type,
    p.taille_octets,
    p.actif,
    p.date_upload,
    p.date_upload::date AS jour_upload
FROM public.objet_photo p
LEFT JOIN public.vw_srm_objet_fact o
    ON o.nom_schema = p.nom_schema
   AND o.nom_table = p.nom_table
   AND o.uuid_objet = p.uuid_objet;

CREATE VIEW public.vw_srm_incomplet_fact AS
WITH base AS (
    SELECT
        oi.*,
        NULLIF(split_part(oi.nom_classe, '.', 1), '') AS nom_schema,
        NULLIF(split_part(oi.nom_classe, '.', 2), '') AS nom_table
    FROM public.objet_incomplet oi
)
SELECT
    md5(concat_ws('|', 'incomplet', b.id_incomplet::text, COALESCE(b.nom_classe, ''), COALESCE(b.id_objet::text, ''))) AS incomplet_uid,
    b.id_incomplet,
    b.id_objet,
    o.uuid_objet,
    b.nom_schema,
    b.nom_table,
    b.nom_classe,
    COALESCE(NULLIF(b.metier::text, ''), o.metier, b.nom_schema)::varchar(10) AS metier,
    COALESCE(b.id_projet, o.id_projet) AS id_projet,
    COALESCE(b.id_mission, o.id_mission) AS id_mission,
    o.type_geometrie,
    o.famille_geometrie,
    b.raison,
    b.detail_raison,
    b.statut,
    b.date_signalement,
    b.date_signalement::date AS jour_signalement,
    b.id_agent_signal,
    b.date_completion,
    b.date_completion::date AS jour_completion,
    b.id_agent_retour
FROM base b
LEFT JOIN public.vw_srm_objet_fact o
    ON o.nom_schema = b.nom_schema
   AND o.nom_table = b.nom_table
   AND o.id_objet = b.id_objet;

CREATE VIEW public.vw_srm_historique_fact AS
WITH base AS (
    SELECT
        h.*,
        COALESCE(NULLIF(h.uuid_objet, ''), NULLIF(h.cle_ligne, ''), h.id_objet::text) AS cle_jointure
    FROM public.historique_attribut h
    WHERE h.nom_schema IN ('ep', 'ass', 'elec')
)
SELECT
    md5(concat_ws('|', 'historique', b.id_historique::text)) AS historique_uid,
    b.id_historique,
    b.id_objet,
    b.cle_ligne,
    b.uuid_objet,
    b.nom_schema,
    b.nom_table,
    b.nom_classe,
    COALESCE(o.metier, b.nom_schema)::varchar(10) AS metier,
    o.id_projet,
    o.id_mission,
    o.type_geometrie,
    o.famille_geometrie,
    b.nom_attribut,
    b.ancienne_valeur,
    b.nouvelle_valeur,
    b.date_action,
    b.date_action::date AS jour_action,
    b.id_agent,
    b.type_action,
    b.commentaire_correction
FROM base b
LEFT JOIN public.vw_srm_objet_fact o
    ON o.nom_schema = b.nom_schema
   AND o.nom_table = b.nom_table
   AND (
       o.cle_ligne = b.cle_jointure
       OR o.uuid_objet = b.cle_jointure
       OR o.id_objet::text = b.cle_jointure
   );

CREATE VIEW public.vw_srm_historique_mobile_fact AS
WITH base AS (
    SELECT
        hm.*,
        COALESCE(NULLIF(hm.uuid_objet, ''), NULLIF(hm.cle_ligne, ''), hm.id_objet::text) AS cle_jointure
    FROM public.historique_mobile hm
)
SELECT
    md5(concat_ws('|', 'historique-mobile', b.id_historique_mobile::text)) AS historique_mobile_uid,
    b.id_historique_mobile,
    b.sync_uuid,
    b.type_entree,
    b.source_table_locale,
    b.source_id_local,
    b.id_objet,
    b.cle_ligne,
    b.uuid_objet,
    b.nom_schema,
    b.nom_table,
    b.nom_classe,
    COALESCE(o.metier, b.nom_schema)::varchar(10) AS metier,
    o.id_projet,
    o.id_mission,
    o.type_geometrie,
    o.famille_geometrie,
    b.nom_attribut,
    b.ancienne_valeur,
    b.nouvelle_valeur,
    b.type_action,
    b.type_evenement,
    b.payload_json,
    b.date_action,
    b.date_action::date AS jour_action,
    b.date_reception,
    b.id_agent
FROM base b
LEFT JOIN public.vw_srm_objet_fact o
    ON o.nom_schema = b.nom_schema
   AND o.nom_table = b.nom_table
   AND (
       o.cle_ligne = b.cle_jointure
       OR o.uuid_objet = b.cle_jointure
       OR o.id_objet::text = b.cle_jointure
   );

CREATE VIEW public.vw_metrics_agent_jour AS
WITH objet_metrics AS (
    SELECT
        o.jour_creation_terrain AS jour,
        o.id_agent_crea AS id_agent,
        o.id_projet,
        o.id_mission,
        o.nom_schema,
        o.nom_table,
        o.metier,
        o.type_geometrie,
        o.famille_geometrie,
        COUNT(*)::bigint AS nb_objets_crees,
        COUNT(*) FILTER (WHERE o.anomalie)::bigint AS nb_objets_anomalie,
        COUNT(*) FILTER (WHERE o.nb_photos_renseignees > 0)::bigint AS nb_objets_avec_photo,
        COALESCE(SUM(o.nb_photos_renseignees), 0)::bigint AS nb_photos_renseignees,
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
    FROM public.vw_srm_objet_dates o
    WHERE o.jour_creation_terrain IS NOT NULL
    GROUP BY
        o.jour_creation_terrain,
        o.id_agent_crea,
        o.id_projet,
        o.id_mission,
        o.nom_schema,
        o.nom_table,
        o.metier,
        o.type_geometrie,
        o.famille_geometrie
),
photo_metrics AS (
    SELECT
        p.jour_upload AS jour,
        p.id_agent,
        p.id_projet,
        p.id_mission,
        p.nom_schema,
        p.nom_table,
        p.metier,
        p.type_geometrie,
        p.famille_geometrie,
        0::bigint AS nb_objets_crees,
        0::bigint AS nb_objets_anomalie,
        0::bigint AS nb_objets_avec_photo,
        0::bigint AS nb_photos_renseignees,
        COUNT(*)::bigint AS nb_photos_uploadees,
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
    FROM public.vw_srm_photo_fact p
    WHERE p.jour_upload IS NOT NULL
    GROUP BY
        p.jour_upload,
        p.id_agent,
        p.id_projet,
        p.id_mission,
        p.nom_schema,
        p.nom_table,
        p.metier,
        p.type_geometrie,
        p.famille_geometrie
),
incomplet_signal_metrics AS (
    SELECT
        i.jour_signalement AS jour,
        i.id_agent_signal AS id_agent,
        i.id_projet,
        i.id_mission,
        i.nom_schema,
        i.nom_table,
        i.metier,
        i.type_geometrie,
        i.famille_geometrie,
        0::bigint AS nb_objets_crees,
        0::bigint AS nb_objets_anomalie,
        0::bigint AS nb_objets_avec_photo,
        0::bigint AS nb_photos_renseignees,
        0::bigint AS nb_photos_uploadees,
        COUNT(*)::bigint AS nb_objets_incomplets_signales,
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
    FROM public.vw_srm_incomplet_fact i
    WHERE i.jour_signalement IS NOT NULL
    GROUP BY
        i.jour_signalement,
        i.id_agent_signal,
        i.id_projet,
        i.id_mission,
        i.nom_schema,
        i.nom_table,
        i.metier,
        i.type_geometrie,
        i.famille_geometrie
),
incomplet_completion_metrics AS (
    SELECT
        i.jour_completion AS jour,
        i.id_agent_retour AS id_agent,
        i.id_projet,
        i.id_mission,
        i.nom_schema,
        i.nom_table,
        i.metier,
        i.type_geometrie,
        i.famille_geometrie,
        0::bigint AS nb_objets_crees,
        0::bigint AS nb_objets_anomalie,
        0::bigint AS nb_objets_avec_photo,
        0::bigint AS nb_photos_renseignees,
        0::bigint AS nb_photos_uploadees,
        0::bigint AS nb_objets_incomplets_signales,
        COUNT(*)::bigint AS nb_objets_incomplets_completes,
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
    FROM public.vw_srm_incomplet_fact i
    WHERE i.jour_completion IS NOT NULL
    GROUP BY
        i.jour_completion,
        i.id_agent_retour,
        i.id_projet,
        i.id_mission,
        i.nom_schema,
        i.nom_table,
        i.metier,
        i.type_geometrie,
        i.famille_geometrie
),
historique_metrics AS (
    SELECT
        h.jour_action AS jour,
        h.id_agent,
        h.id_projet,
        h.id_mission,
        h.nom_schema,
        h.nom_table,
        h.metier,
        h.type_geometrie,
        h.famille_geometrie,
        0::bigint AS nb_objets_crees,
        0::bigint AS nb_objets_anomalie,
        0::bigint AS nb_objets_avec_photo,
        0::bigint AS nb_photos_renseignees,
        0::bigint AS nb_photos_uploadees,
        0::bigint AS nb_objets_incomplets_signales,
        0::bigint AS nb_objets_incomplets_completes,
        COUNT(*) FILTER (WHERE h.type_action = 'MODIFICATION_TERRAIN')::bigint AS nb_modifications_terrain,
        COUNT(*) FILTER (WHERE h.type_action = 'VALIDATION_TERRAIN')::bigint AS nb_validations_terrain,
        COUNT(*) FILTER (WHERE h.type_action = 'CORRECTION_BACKOFFICE')::bigint AS nb_corrections_backoffice,
        COUNT(*) FILTER (WHERE h.type_action = 'CORRECTION_SUPERVISEUR')::bigint AS nb_corrections_superviseur,
        COUNT(*) FILTER (WHERE h.type_action = 'REOUVERTURE')::bigint AS nb_reouvertures,
        0::bigint AS nb_evenements_mobiles,
        0::bigint AS nb_attributs_mobiles,
        0::bigint AS nb_sessions_login,
        0::bigint AS nb_sessions_logout,
        0::bigint AS nb_evenements_sync
    FROM public.vw_srm_historique_fact h
    WHERE h.jour_action IS NOT NULL
    GROUP BY
        h.jour_action,
        h.id_agent,
        h.id_projet,
        h.id_mission,
        h.nom_schema,
        h.nom_table,
        h.metier,
        h.type_geometrie,
        h.famille_geometrie
),
mobile_metrics AS (
    SELECT
        hm.jour_action AS jour,
        hm.id_agent,
        hm.id_projet,
        hm.id_mission,
        hm.nom_schema,
        hm.nom_table,
        hm.metier,
        hm.type_geometrie,
        hm.famille_geometrie,
        0::bigint AS nb_objets_crees,
        0::bigint AS nb_objets_anomalie,
        0::bigint AS nb_objets_avec_photo,
        0::bigint AS nb_photos_renseignees,
        0::bigint AS nb_photos_uploadees,
        0::bigint AS nb_objets_incomplets_signales,
        0::bigint AS nb_objets_incomplets_completes,
        0::bigint AS nb_modifications_terrain,
        0::bigint AS nb_validations_terrain,
        0::bigint AS nb_corrections_backoffice,
        0::bigint AS nb_corrections_superviseur,
        0::bigint AS nb_reouvertures,
        COUNT(*) FILTER (WHERE hm.type_entree = 'EVENEMENT')::bigint AS nb_evenements_mobiles,
        COUNT(*) FILTER (WHERE hm.type_entree = 'ATTRIBUT')::bigint AS nb_attributs_mobiles,
        COUNT(*) FILTER (
            WHERE hm.type_entree = 'EVENEMENT'
              AND hm.type_evenement IN ('SESSION_LOGIN', 'LOGIN_SUCCESS_OFFLINE', 'LOGIN_SUCCESS_ONLINE')
        )::bigint AS nb_sessions_login,
        COUNT(*) FILTER (
            WHERE hm.type_entree = 'EVENEMENT'
              AND hm.type_evenement = 'SESSION_LOGOUT'
        )::bigint AS nb_sessions_logout,
        COUNT(*) FILTER (
            WHERE hm.type_entree = 'EVENEMENT'
              AND (
                  COALESCE(hm.type_evenement, '') LIKE '%SYNC%'
                  OR COALESCE(hm.type_evenement, '') LIKE '%DOWNLOAD%'
              )
        )::bigint AS nb_evenements_sync
    FROM public.vw_srm_historique_mobile_fact hm
    WHERE hm.jour_action IS NOT NULL
    GROUP BY
        hm.jour_action,
        hm.id_agent,
        hm.id_projet,
        hm.id_mission,
        hm.nom_schema,
        hm.nom_table,
        hm.metier,
        hm.type_geometrie,
        hm.famille_geometrie
),
union_metrics AS (
    SELECT * FROM objet_metrics
    UNION ALL
    SELECT * FROM photo_metrics
    UNION ALL
    SELECT * FROM incomplet_signal_metrics
    UNION ALL
    SELECT * FROM incomplet_completion_metrics
    UNION ALL
    SELECT * FROM historique_metrics
    UNION ALL
    SELECT * FROM mobile_metrics
)
SELECT
    md5(concat_ws(
        '|',
        jour::text,
        COALESCE(id_agent::text, ''),
        COALESCE(id_projet::text, ''),
        COALESCE(id_mission::text, ''),
        COALESCE(nom_schema, ''),
        COALESCE(nom_table, ''),
        COALESCE(type_geometrie, '')
    )) AS metric_uid,
    jour,
    id_agent,
    id_projet,
    id_mission,
    nom_schema,
    nom_table,
    metier,
    type_geometrie,
    famille_geometrie,
    SUM(nb_objets_crees)::bigint AS nb_objets_crees,
    SUM(nb_objets_anomalie)::bigint AS nb_objets_anomalie,
    SUM(nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
    SUM(nb_photos_renseignees)::bigint AS nb_photos_renseignees,
    SUM(nb_photos_uploadees)::bigint AS nb_photos_uploadees,
    SUM(nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
    SUM(nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
    SUM(nb_modifications_terrain)::bigint AS nb_modifications_terrain,
    SUM(nb_validations_terrain)::bigint AS nb_validations_terrain,
    SUM(nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
    SUM(nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
    SUM(nb_reouvertures)::bigint AS nb_reouvertures,
    SUM(nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
    SUM(nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
    SUM(nb_sessions_login)::bigint AS nb_sessions_login,
    SUM(nb_sessions_logout)::bigint AS nb_sessions_logout,
    SUM(nb_evenements_sync)::bigint AS nb_evenements_sync
FROM union_metrics
GROUP BY
    jour,
    id_agent,
    id_projet,
    id_mission,
    nom_schema,
    nom_table,
    metier,
    type_geometrie,
    famille_geometrie;

CREATE VIEW public.vw_metrics_agent_semaine AS
SELECT
    md5(concat_ws(
        '|',
        date_trunc('week', m.jour::timestamp)::date::text,
        COALESCE(m.id_agent::text, ''),
        COALESCE(m.id_projet::text, ''),
        COALESCE(m.id_mission::text, ''),
        COALESCE(m.nom_schema, ''),
        COALESCE(m.nom_table, ''),
        COALESCE(m.type_geometrie, '')
    )) AS metric_uid,
    date_trunc('week', m.jour::timestamp)::date AS semaine_debut,
    (date_trunc('week', m.jour::timestamp)::date + 6) AS semaine_fin,
    EXTRACT(ISOYEAR FROM m.jour)::integer AS annee_iso,
    EXTRACT(WEEK FROM m.jour)::integer AS semaine_iso,
    m.id_agent,
    m.id_projet,
    m.id_mission,
    m.nom_schema,
    m.nom_table,
    m.metier,
    m.type_geometrie,
    m.famille_geometrie,
    SUM(m.nb_objets_crees)::bigint AS nb_objets_crees,
    SUM(m.nb_objets_anomalie)::bigint AS nb_objets_anomalie,
    SUM(m.nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
    SUM(m.nb_photos_renseignees)::bigint AS nb_photos_renseignees,
    SUM(m.nb_photos_uploadees)::bigint AS nb_photos_uploadees,
    SUM(m.nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
    SUM(m.nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
    SUM(m.nb_modifications_terrain)::bigint AS nb_modifications_terrain,
    SUM(m.nb_validations_terrain)::bigint AS nb_validations_terrain,
    SUM(m.nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
    SUM(m.nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
    SUM(m.nb_reouvertures)::bigint AS nb_reouvertures,
    SUM(m.nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
    SUM(m.nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
    SUM(m.nb_sessions_login)::bigint AS nb_sessions_login,
    SUM(m.nb_sessions_logout)::bigint AS nb_sessions_logout,
    SUM(m.nb_evenements_sync)::bigint AS nb_evenements_sync
FROM public.vw_metrics_agent_jour m
GROUP BY
    date_trunc('week', m.jour::timestamp)::date,
    EXTRACT(ISOYEAR FROM m.jour),
    EXTRACT(WEEK FROM m.jour),
    m.id_agent,
    m.id_projet,
    m.id_mission,
    m.nom_schema,
    m.nom_table,
    m.metier,
    m.type_geometrie,
    m.famille_geometrie;

CREATE VIEW public.vw_metrics_agent_mois AS
SELECT
    md5(concat_ws(
        '|',
        date_trunc('month', m.jour::timestamp)::date::text,
        COALESCE(m.id_agent::text, ''),
        COALESCE(m.id_projet::text, ''),
        COALESCE(m.id_mission::text, ''),
        COALESCE(m.nom_schema, ''),
        COALESCE(m.nom_table, ''),
        COALESCE(m.type_geometrie, '')
    )) AS metric_uid,
    date_trunc('month', m.jour::timestamp)::date AS mois,
    EXTRACT(YEAR FROM m.jour)::integer AS annee,
    EXTRACT(MONTH FROM m.jour)::integer AS mois_numero,
    m.id_agent,
    m.id_projet,
    m.id_mission,
    m.nom_schema,
    m.nom_table,
    m.metier,
    m.type_geometrie,
    m.famille_geometrie,
    SUM(m.nb_objets_crees)::bigint AS nb_objets_crees,
    SUM(m.nb_objets_anomalie)::bigint AS nb_objets_anomalie,
    SUM(m.nb_objets_avec_photo)::bigint AS nb_objets_avec_photo,
    SUM(m.nb_photos_renseignees)::bigint AS nb_photos_renseignees,
    SUM(m.nb_photos_uploadees)::bigint AS nb_photos_uploadees,
    SUM(m.nb_objets_incomplets_signales)::bigint AS nb_objets_incomplets_signales,
    SUM(m.nb_objets_incomplets_completes)::bigint AS nb_objets_incomplets_completes,
    SUM(m.nb_modifications_terrain)::bigint AS nb_modifications_terrain,
    SUM(m.nb_validations_terrain)::bigint AS nb_validations_terrain,
    SUM(m.nb_corrections_backoffice)::bigint AS nb_corrections_backoffice,
    SUM(m.nb_corrections_superviseur)::bigint AS nb_corrections_superviseur,
    SUM(m.nb_reouvertures)::bigint AS nb_reouvertures,
    SUM(m.nb_evenements_mobiles)::bigint AS nb_evenements_mobiles,
    SUM(m.nb_attributs_mobiles)::bigint AS nb_attributs_mobiles,
    SUM(m.nb_sessions_login)::bigint AS nb_sessions_login,
    SUM(m.nb_sessions_logout)::bigint AS nb_sessions_logout,
    SUM(m.nb_evenements_sync)::bigint AS nb_evenements_sync
FROM public.vw_metrics_agent_jour m
GROUP BY
    date_trunc('month', m.jour::timestamp)::date,
    EXTRACT(YEAR FROM m.jour),
    EXTRACT(MONTH FROM m.jour),
    m.id_agent,
    m.id_projet,
    m.id_mission,
    m.nom_schema,
    m.nom_table,
    m.metier,
    m.type_geometrie,
    m.famille_geometrie;

COMMIT;
