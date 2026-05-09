from django.db import migrations


FORWARD_SQL = r"""
DO $$
DECLARE
    rec record;
    pk_column text;
    audit_trigger_exists boolean;
    trigger_name text;
BEGIN
    IF to_regprocedure('public.capture_historique_attribut()') IS NULL THEN
        RAISE EXCEPTION
            'Fonction public.capture_historique_attribut() introuvable; impossible d installer les triggers d historique.';
    END IF;

    FOR rec IN
        SELECT n.nspname AS schema_name, c.relname AS table_name
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE c.relkind IN ('r', 'p')
           AND n.nspname IN ('ep', 'asst')
        UNION ALL
        SELECT 'public'::name AS schema_name, 'formulaire_config_mobile'::name AS table_name
         ORDER BY schema_name, table_name
    LOOP
        SELECT a.attname
          INTO pk_column
          FROM pg_index i
          JOIN pg_attribute a
            ON a.attrelid = i.indrelid
           AND a.attnum = ANY(i.indkey)
          JOIN pg_class c ON c.oid = i.indrelid
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE i.indisprimary
           AND n.nspname = rec.schema_name
           AND c.relname = rec.table_name
         ORDER BY a.attnum
         LIMIT 1;

        IF pk_column IS NULL THEN
            CONTINUE;
        END IF;

        SELECT EXISTS (
            SELECT 1
              FROM pg_trigger t
              JOIN pg_class c ON c.oid = t.tgrelid
              JOIN pg_namespace n ON n.oid = c.relnamespace
              JOIN pg_proc p ON p.oid = t.tgfoid
             WHERE NOT t.tgisinternal
               AND n.nspname = rec.schema_name
               AND c.relname = rec.table_name
               AND p.proname = 'capture_historique_attribut'
        )
          INTO audit_trigger_exists;

        IF audit_trigger_exists THEN
            CONTINUE;
        END IF;

        trigger_name := left(
            'trg_audit_' || rec.schema_name || '_' ||
            regexp_replace(lower(rec.table_name), '[^a-z0-9_]+', '_', 'g'),
            63
        );

        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON %I.%I',
            trigger_name,
            rec.schema_name,
            rec.table_name
        );

        EXECUTE format(
            'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION public.capture_historique_attribut(%L)',
            trigger_name,
            rec.schema_name,
            rec.table_name,
            pk_column
        );
    END LOOP;
END $$;
"""


REVERSE_SQL = r"""
DO $$
DECLARE
    rec record;
    trigger_name text;
BEGIN
    FOR rec IN
        SELECT n.nspname AS schema_name, c.relname AS table_name
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE c.relkind IN ('r', 'p')
           AND n.nspname IN ('ep', 'asst')
        UNION ALL
        SELECT 'public'::name AS schema_name, 'formulaire_config_mobile'::name AS table_name
         ORDER BY schema_name, table_name
    LOOP
        trigger_name := left(
            'trg_audit_' || rec.schema_name || '_' ||
            regexp_replace(lower(rec.table_name), '[^a-z0-9_]+', '_', 'g'),
            63
        );

        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON %I.%I',
            trigger_name,
            rec.schema_name,
            rec.table_name
        );
    END LOOP;
END $$;
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0038_fill_missing_ep_regard_mirror_geom"),
    ]

    operations = [
        migrations.RunSQL(FORWARD_SQL, reverse_sql=REVERSE_SQL),
    ]
