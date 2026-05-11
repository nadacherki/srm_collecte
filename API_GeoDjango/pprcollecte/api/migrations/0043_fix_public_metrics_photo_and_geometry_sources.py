from django.db import migrations


FORWARD_SQL = r"""
CREATE OR REPLACE VIEW public.vw_srm_photo_object_fact AS
SELECT t.id_photo::text AS photo_uid,
       t.nom_schema::varchar(30) AS nom_schema,
       t.nom_table::varchar(100) AS nom_table,
       t.uuid_objet::varchar(254) AS uuid_objet,
       t.id_agent_crea::integer AS id_agent,
       t.date_upload::timestamp without time zone AS date_photo,
       t.num_photo::integer AS photo_slot,
       COALESCE(t.actif, true) AS actif
FROM public.objet_photo t
WHERE COALESCE(t.actif, true) = true;

CREATE OR REPLACE VIEW public.vw_srm_photo_fact AS
SELECT t.id_photo::text AS photo_uid,
       t.nom_table::text AS nom_table,
       NULL::integer AS id_objet,
       t.id_agent_crea::integer AS id_agent,
       t.date_upload::timestamp without time zone AS date_photo,
       t.num_photo::integer AS photo_slot
FROM public.objet_photo t
WHERE COALESCE(t.actif, true) = true;

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
        SELECT c.table_schema, c.table_name
        FROM information_schema.columns c
        WHERE c.table_schema IN ('ep', 'asst')
          AND c.column_name = 'geom'
          AND EXISTS (
              SELECT 1
              FROM public.formulaire_config_mobile f
              WHERE lower(f.nom_metier) = c.table_schema
                AND lower(f.nom_table) = lower(c.table_name)
                AND COALESCE(f.visible, false) = true
          )
        GROUP BY c.table_schema, c.table_name
        ORDER BY c.table_schema, c.table_name
    LOOP
        table_sql := format($fmt$
            SELECT
                %L || '.' || %L || ':' || COALESCE(%s, md5(ST_AsEWKB(t.geom)::text)) AS objet_uid,
                %L::varchar(30) AS nom_schema,
                %L::varchar(100) AS nom_table,
                %L::varchar(100) AS nom_classe,
                %L::varchar(10) AS metier,
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
                CASE ST_Dimension(t.geom)
                    WHEN 0 THEN 'POINT'
                    WHEN 1 THEN 'LINE'
                    WHEN 2 THEN 'POLYGON'
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

    EXECUTE 'CREATE OR REPLACE VIEW public.vw_srm_objet_fact AS ' || union_sql;
END $$;

CREATE OR REPLACE VIEW public.vw_srm_objet_dates AS
SELECT objet_uid,
       nom_schema,
       nom_table,
       metier,
       id_agent_crea AS id_agent,
       date_action::date AS date_action
FROM public.vw_srm_objet_fact;

CREATE OR REPLACE VIEW public.vw_srm_objet_activity_fact AS
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

CREATE OR REPLACE VIEW public.vw_metrics_agent_jour AS
WITH photo_by_object AS (
    SELECT nom_schema,
           nom_table,
           uuid_objet,
           count(*)::integer AS nb_photos_uploadees
    FROM public.vw_srm_photo_object_fact
    GROUP BY nom_schema, nom_table, uuid_objet
),
object_rows AS (
    SELECT o.*,
           COALESCE(p.nb_photos_uploadees, 0)::integer AS nb_photos_uploadees_objet
    FROM public.vw_srm_objet_fact o
    LEFT JOIN photo_by_object p
      ON p.nom_schema = o.nom_schema
     AND p.nom_table = o.nom_table
     AND p.uuid_objet = o.uuid_objet
)
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
       count(*) FILTER (
           WHERE COALESCE(nb_photos_renseignees, 0) > 0
              OR COALESCE(nb_photos_uploadees_objet, 0) > 0
       )::bigint AS nb_objets_avec_photo,
       COALESCE(sum(nb_photos_renseignees), 0)::bigint AS nb_photos_renseignees,
       COALESCE(sum(nb_photos_uploadees_objet), 0)::bigint AS nb_photos_uploadees,
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
FROM object_rows
GROUP BY COALESCE(date_action::date, CURRENT_DATE),
         id_agent_crea,
         nom_schema,
         nom_table,
         metier,
         type_geometrie,
         famille_geometrie;
"""


class Migration(migrations.Migration):
    dependencies = [
        ('api', '0042_create_asst_statistique_conduite'),
    ]

    operations = [
        migrations.RunSQL(sql=FORWARD_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
