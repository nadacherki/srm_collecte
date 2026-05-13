from django.db import migrations


SQL = r"""
CREATE OR REPLACE FUNCTION public.srm_required_exception_sql(
    p_schema text,
    p_table text
)
RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_catalog
AS $$
DECLARE
    candidate text;
    physical_column text;
    terms text[] := ARRAY[]::text[];
BEGIN
    FOREACH candidate IN ARRAY ARRAY['anomalie', 'ep_anomalie', 'ass_anomalie', 'objet_incomplet']
    LOOP
        SELECT c.column_name
          INTO physical_column
            FROM information_schema.columns c
            WHERE c.table_schema = p_schema
              AND c.table_name = p_table
              AND lower(c.column_name) = candidate
            LIMIT 1;

        IF physical_column IS NOT NULL THEN
            terms := terms || format(
                '(lower(btrim(coalesce(%I::text, ''''))) NOT IN ('''', ''0'', ''false'', ''f'', ''no'', ''non'', ''n''))',
                physical_column
            );
        END IF;
    END LOOP;

    IF array_length(terms, 1) IS NULL THEN
        RETURN 'false';
    END IF;

    RETURN array_to_string(terms, ' OR ');
END;
$$;

DO $$
DECLARE
    r record;
    old_constraint_name text;
    new_constraint_name text;
    exception_sql text;
    ddl_sql text;
BEGIN
    FOR r IN
        SELECT
            lower(acm.nom_metier) AS schema_name,
            acm.nom_table AS table_name,
            c.column_name,
            a.attnotnull
        FROM public.attribut_config_mobile acm
        JOIN information_schema.columns c
          ON c.table_schema = lower(acm.nom_metier)
         AND c.table_name = acm.nom_table
         AND lower(c.column_name) = lower(acm.nom_champ)
        JOIN pg_catalog.pg_class cls
          ON cls.relname = c.table_name
        JOIN pg_catalog.pg_namespace ns
          ON ns.oid = cls.relnamespace
         AND ns.nspname = c.table_schema
        JOIN pg_catalog.pg_attribute a
          ON a.attrelid = cls.oid
         AND a.attname = c.column_name
         AND a.attnum > 0
         AND NOT a.attisdropped
        WHERE lower(acm.nom_metier) IN ('ep', 'asst')
          AND COALESCE(acm.visible, false) = true
          AND COALESCE(acm.nullable, true) = false
          AND COALESCE(acm.primary_key, false) = false
          AND lower(acm.nom_champ) NOT IN ('id', 'fid', 'geom')
    LOOP
        old_constraint_name := format('srm_nn_%s', substr(md5(r.column_name), 1, 16));
        new_constraint_name := format('srm_req_%s', substr(md5(r.column_name), 1, 16));
        exception_sql := public.srm_required_exception_sql(r.schema_name, r.table_name);

        ddl_sql := format(
            'ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I',
            r.schema_name,
            r.table_name,
            old_constraint_name
        );
        EXECUTE ddl_sql;

        ddl_sql := format(
            'ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I',
            r.schema_name,
            r.table_name,
            new_constraint_name
        );
        EXECUTE ddl_sql;

        IF r.attnotnull THEN
            ddl_sql := format(
                'ALTER TABLE %I.%I ALTER COLUMN %I DROP NOT NULL',
                r.schema_name,
                r.table_name,
                r.column_name
            );
            EXECUTE ddl_sql;
        END IF;

        ddl_sql := format(
            'ALTER TABLE %I.%I ADD CONSTRAINT %I CHECK (%I IS NOT NULL OR %s) NOT VALID',
            r.schema_name,
            r.table_name,
            new_constraint_name,
            r.column_name,
            exception_sql
        );
        EXECUTE ddl_sql;

        INSERT INTO public.srm_config_schema_ddl_log (
            nom_metier, nom_table, nom_champ, operation, old_type, new_type,
            old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
        )
        SELECT
            r.schema_name,
            r.table_name,
            r.column_name,
            'ADD_REQUIRED_CONDITIONAL_CHECK',
            c.data_type,
            c.data_type,
            true,
            false,
            ddl_sql,
            acm.id,
            'Nullable=false enforced for normal rows; anomaly/incomplete rows may keep required fields empty.'
        FROM public.attribut_config_mobile acm
        JOIN information_schema.columns c
          ON c.table_schema = r.schema_name
         AND c.table_name = r.table_name
         AND lower(c.column_name) = lower(r.column_name)
        WHERE lower(acm.nom_metier) = r.schema_name
          AND acm.nom_table = r.table_name
          AND lower(acm.nom_champ) = lower(r.column_name)
        LIMIT 1;
    END LOOP;
END $$;

COMMENT ON COLUMN public.attribut_config_mobile.nullable IS
    'Source unique du contrat requis: false = champ requis pour objet normal; anomalie/objet_incomplet autorisent une valeur vide avec trace workflow.';
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0049_nullable_as_required_contract"),
    ]

    operations = [
        migrations.RunSQL(SQL, reverse_sql=migrations.RunSQL.noop),
    ]
