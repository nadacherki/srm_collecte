from django.db import migrations


DROP_EP_UPDATED_AT_SQL = """
CREATE TEMP TABLE codex_view_defs_for_ep_updated_at_drop (
    view_name text PRIMARY KEY,
    definition text NOT NULL
) ON COMMIT DROP;

INSERT INTO codex_view_defs_for_ep_updated_at_drop (view_name, definition)
SELECT viewname, definition
FROM pg_views
WHERE schemaname = 'public'
  AND viewname IN (
      'vw_srm_objet_fact',
      'vw_metrics_agent_semaine',
      'vw_metrics_agent_mois',
      'vw_metrics_agent_public_jour',
      'vw_metrics_agent_public_semaine',
      'vw_metrics_agent_public_mois',
      'vw_metrics_agent_period',
      'vw_metrics_agent_public_resume',
      'vw_metrics_agent_resume',
      'vw_metrics_agent_table_period'
  );

DO $$
DECLARE
    object_fact_definition text;
    date_action_expression text := 'COALESCE(NULLIF(to_jsonb(t)->>''date_modif'','''')::timestamp without time zone, NULLIF(to_jsonb(t)->>''date_validation'','''')::timestamp without time zone, NULLIF(to_jsonb(t)->>''date_creation'','''')::timestamp without time zone, NULLIF(to_jsonb(t)->>''ep_date_insertion'','''')::timestamp without time zone, NULLIF(to_jsonb(t)->>''date_leve'','''')::timestamp without time zone, NULLIF(to_jsonb(t)->>''created_at'','''')::timestamp without time zone, CURRENT_TIMESTAMP::timestamp without time zone) AS date_action';
    dependent_view text;
    dependent_definition text;
BEGIN
    SELECT definition
      INTO object_fact_definition
      FROM codex_view_defs_for_ep_updated_at_drop
     WHERE view_name = 'vw_srm_objet_fact';

    IF object_fact_definition IS NOT NULL THEN
        object_fact_definition := regexp_replace(
            object_fact_definition,
            E'\\n\\s*[^\\n]+ AS updated_at',
            E'\\n    ' || date_action_expression,
            'g'
        );

        IF object_fact_definition ILIKE '%updated_at%' THEN
            RAISE EXCEPTION 'vw_srm_objet_fact still references updated_at after rewrite';
        END IF;
    END IF;

    DROP VIEW IF EXISTS public.vw_srm_objet_fact CASCADE;

    IF object_fact_definition IS NOT NULL THEN
        EXECUTE 'CREATE VIEW public.vw_srm_objet_fact AS ' || object_fact_definition;

        EXECUTE $view$
            CREATE VIEW public.vw_srm_objet_dates AS
            SELECT objet_uid,
                   nom_schema,
                   nom_table,
                   metier,
                   id_agent_crea AS id_agent,
                   (date_action)::date AS date_action
              FROM public.vw_srm_objet_fact
        $view$;

        EXECUTE $view$
            CREATE VIEW public.vw_srm_objet_activity_fact AS
            SELECT objet_uid,
                   nom_schema,
                   nom_table,
                   metier,
                   id_agent_crea AS id_agent,
                   COALESCE((date_action)::date, CURRENT_DATE) AS date_action,
                   type_geometrie,
                   famille_geometrie,
                   anomalie,
                   nb_photos_renseignees
              FROM public.vw_srm_objet_fact
        $view$;

        EXECUTE $view$
            CREATE VIEW public.vw_metrics_agent_jour AS
            SELECT md5(concat_ws(
                       '|'::text,
                       COALESCE((id_agent_crea)::text, '-'::text),
                       nom_schema,
                       nom_table,
                       (COALESCE((date_action)::date, CURRENT_DATE))::text
                   )) AS metric_uid,
                   COALESCE((date_action)::date, CURRENT_DATE) AS jour,
                   id_agent_crea AS id_agent,
                   nom_schema,
                   nom_table,
                   metier,
                   type_geometrie,
                   famille_geometrie,
                   count(*) AS nb_objets_crees,
                   count(*) FILTER (WHERE anomalie) AS nb_objets_anomalie,
                   count(*) FILTER (WHERE nb_photos_renseignees > 0) AS nb_objets_avec_photo,
                   COALESCE(sum(nb_photos_renseignees), 0::bigint) AS nb_photos_renseignees,
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
             GROUP BY COALESCE((date_action)::date, CURRENT_DATE),
                      id_agent_crea,
                      nom_schema,
                      nom_table,
                      metier,
                      type_geometrie,
                      famille_geometrie
        $view$;

        FOREACH dependent_view IN ARRAY ARRAY[
            'vw_metrics_agent_semaine',
            'vw_metrics_agent_mois',
            'vw_metrics_agent_public_jour',
            'vw_metrics_agent_public_semaine',
            'vw_metrics_agent_public_mois',
            'vw_metrics_agent_period',
            'vw_metrics_agent_public_resume',
            'vw_metrics_agent_resume',
            'vw_metrics_agent_table_period'
        ]
        LOOP
            SELECT definition
              INTO dependent_definition
              FROM codex_view_defs_for_ep_updated_at_drop
             WHERE view_name = dependent_view;

            IF dependent_definition IS NOT NULL THEN
                EXECUTE format('CREATE VIEW public.%I AS %s', dependent_view, dependent_definition);
            END IF;
        END LOOP;
    END IF;
END $$;

DO $$
DECLARE
    trigger_row record;
BEGIN
    FOR trigger_row IN
        SELECT event_object_table, trigger_name
        FROM information_schema.triggers
        WHERE event_object_schema = 'ep'
          AND action_statement = 'EXECUTE FUNCTION set_updated_at()'
    LOOP
        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON ep.%I',
            trigger_row.trigger_name,
            trigger_row.event_object_table
        );
    END LOOP;
END $$;

ALTER TABLE ep.autre_objet DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.borne_onep DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.bouche_a_cles DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.centre_tampon DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.conduite_terrain DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_bf DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_branchement DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_brc_pt DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_compteur_i DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_conduite DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_cone_reduc DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_forage DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_hydrant DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_noeud DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_obturateur DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_pompe DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_reduc_pres DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_reservoir DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_station_pompage DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_traversee DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_vanne DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_ventouse DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.ep_vidange DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.statistique_conduite DROP COLUMN IF EXISTS updated_at;
ALTER TABLE ep.statistique_conduite_segment DROP COLUMN IF EXISTS updated_at;

DELETE FROM public.attribut_config_mobile
WHERE nom_metier = 'ep'
  AND nom_champ = 'updated_at';
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0017_attribut_config_physical_types"),
    ]

    operations = [
        migrations.RunSQL(
            DROP_EP_UPDATED_AT_SQL,
            reverse_sql=migrations.RunSQL.noop,
        ),
    ]
