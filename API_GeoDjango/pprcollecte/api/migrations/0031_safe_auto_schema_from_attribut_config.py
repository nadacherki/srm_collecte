from django.db import migrations


CONFIG_SQL = r"""
CREATE TABLE IF NOT EXISTS public.srm_config_schema_ddl_log (
    id bigserial PRIMARY KEY,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    db_user text NOT NULL DEFAULT session_user,
    nom_metier varchar(30) NOT NULL,
    nom_table varchar(100) NOT NULL,
    nom_champ varchar(100) NOT NULL,
    operation text NOT NULL,
    old_type text,
    new_type text,
    old_nullable boolean,
    new_nullable boolean,
    sql_applied text NOT NULL,
    attribut_config_mobile_id integer,
    note text
);

CREATE OR REPLACE FUNCTION public.srm_config_normalize_sql_type(p_type text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    t text;
BEGIN
    IF p_type IS NULL OR btrim(p_type) = '' THEN
        RETURN NULL;
    END IF;

    t := lower(btrim(p_type));
    t := regexp_replace(t, '\s+', ' ', 'g');
    t := regexp_replace(t, '^varchar\s*\(', 'character varying(', 'g');
    t := regexp_replace(t, '^varchar$', 'character varying');
    t := regexp_replace(t, '^character\s+varying$', 'character varying');
    t := regexp_replace(t, '^character\s+varying\s*\(\s*([0-9]+)\s*\)$', 'character varying(\1)');
    t := regexp_replace(t, '^numeric\s*\(\s*([0-9]+)\s*,\s*([0-9]+)\s*\)$', 'numeric(\1,\2)');
    t := regexp_replace(t, '^numeric\s*\(\s*([0-9]+)\s*\)$', 'numeric(\1)');

    RETURN t;
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_config_sql_type_is_allowed(p_type text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    t text := public.srm_config_normalize_sql_type(p_type);
BEGIN
    IF t IS NULL THEN
        RETURN false;
    END IF;

    IF t IN (
        'integer',
        'bigint',
        'double precision',
        'boolean',
        'date',
        'uuid',
        'text',
        'timestamp without time zone',
        'timestamp with time zone',
        'character varying',
        'numeric'
    ) THEN
        RETURN true;
    END IF;

    IF t ~ '^character varying\([1-9][0-9]*\)$' THEN
        RETURN true;
    END IF;

    IF t ~ '^numeric\([1-9][0-9]*(,[0-9]+)?\)$' THEN
        RETURN true;
    END IF;

    RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_config_column_is_protected(p_column text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    c text := lower(coalesce(p_column, ''));
BEGIN
    RETURN c IN (
        'geom',
        'fid',
        'id',
        'gid',
        'uuid',
        'uuid_objet',
        'id_objet',
        'id_sync_session',
        'sync_uuid',
        'sync_status',
        'created_at',
        'updated_at',
        'last_activity_at'
    )
    OR c LIKE 'sync\_%' ESCAPE '\';
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_config_type_change_is_safe(p_old_type text, p_new_type text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    old_t text := public.srm_config_normalize_sql_type(p_old_type);
    new_t text := public.srm_config_normalize_sql_type(p_new_type);
    old_match text[];
    new_match text[];
    old_len integer;
    new_len integer;
BEGIN
    IF old_t IS NULL OR new_t IS NULL THEN
        RETURN false;
    END IF;

    IF old_t = new_t THEN
        RETURN true;
    END IF;

    IF old_t LIKE 'geometry%' OR new_t LIKE 'geometry%' THEN
        RETURN false;
    END IF;

    old_match := regexp_match(old_t, '^character varying\(([0-9]+)\)$');
    new_match := regexp_match(new_t, '^character varying\(([0-9]+)\)$');

    IF old_match IS NOT NULL AND new_match IS NOT NULL THEN
        old_len := old_match[1]::integer;
        new_len := new_match[1]::integer;
        RETURN new_len >= old_len;
    END IF;

    IF old_match IS NOT NULL AND new_t IN ('character varying', 'text') THEN
        RETURN true;
    END IF;

    IF old_t = 'character varying' AND new_t = 'text' THEN
        RETURN true;
    END IF;

    IF old_t = 'integer' AND new_t = 'bigint' THEN
        RETURN true;
    END IF;

    IF old_t IN ('integer', 'bigint')
       AND (new_t = 'numeric' OR new_t ~ '^numeric\([1-9][0-9]*(,[0-9]+)?\)$') THEN
        RETURN true;
    END IF;

    RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_attribut_config_mobile_schema_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    target_schema text;
    target_table text;
    target_column text;
    old_schema text;
    old_table text;
    old_column text;
    form_exists boolean;
    table_oid oid;
    old_table_oid oid;
    physical_type text;
    physical_not_null boolean;
    old_physical_type text;
    new_type text;
    ddl_sql text;
    changed_structure boolean := false;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_schema := OLD.nom_metier;
        target_table := OLD.nom_table;
        target_column := OLD.nom_champ;

        IF target_schema NOT IN ('ep', 'asst') THEN
            RETURN OLD;
        END IF;

        SELECT true INTO form_exists
        FROM public.formulaire_config_mobile f
        WHERE f.nom_metier = target_schema
          AND f.nom_table = target_table
        LIMIT 1;

        IF NOT COALESCE(form_exists, false) THEN
            RETURN OLD;
        END IF;

        table_oid := to_regclass(format('%I.%I', target_schema, target_table));
        IF table_oid IS NULL THEN
            RETURN OLD;
        END IF;

        SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
          INTO physical_type
        FROM pg_catalog.pg_attribute a
        WHERE a.attrelid = table_oid
          AND a.attname = target_column
          AND a.attnum > 0
          AND NOT a.attisdropped;

        IF physical_type IS NOT NULL THEN
            RAISE EXCEPTION
                'Suppression refusee: %.%.% existe physiquement (%). Supprimer/valider la colonne par SQL/migration bureau avant de supprimer attribut_config_mobile.',
                target_schema, target_table, target_column, physical_type;
        END IF;

        RETURN OLD;
    END IF;

    target_schema := NEW.nom_metier;
    target_table := NEW.nom_table;
    target_column := NEW.nom_champ;

    IF target_schema NOT IN ('ep', 'asst') THEN
        RETURN NEW;
    END IF;

    SELECT true INTO form_exists
    FROM public.formulaire_config_mobile f
    WHERE f.nom_metier = target_schema
      AND f.nom_table = target_table
    LIMIT 1;

    IF NOT COALESCE(form_exists, false) THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.nom_metier IN ('ep', 'asst') THEN
        old_schema := OLD.nom_metier;
        old_table := OLD.nom_table;
        old_column := OLD.nom_champ;
        old_table_oid := to_regclass(format('%I.%I', old_schema, old_table));

        IF old_table_oid IS NOT NULL THEN
            SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
              INTO old_physical_type
            FROM pg_catalog.pg_attribute a
            WHERE a.attrelid = old_table_oid
              AND a.attname = old_column
              AND a.attnum > 0
              AND NOT a.attisdropped;

            IF old_physical_type IS NOT NULL
               AND (
                    old_schema IS DISTINCT FROM target_schema
                    OR old_table IS DISTINCT FROM target_table
                    OR old_column IS DISTINCT FROM target_column
               ) THEN
                RAISE EXCEPTION
                    'Renommage/deplacement refuse: %.%.% existe physiquement. Faire une migration SQL explicite puis realigner attribut_config_mobile.',
                    old_schema, old_table, old_column;
            END IF;
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        changed_structure :=
            NEW.type_champ IS DISTINCT FROM OLD.type_champ
            OR NEW.nullable IS DISTINCT FROM OLD.nullable
            OR NEW.primary_key IS DISTINCT FROM OLD.primary_key
            OR NEW.foreign_key IS DISTINCT FROM OLD.foreign_key
            OR NEW.reference_fk IS DISTINCT FROM OLD.reference_fk;
    ELSE
        changed_structure := true;
    END IF;

    table_oid := to_regclass(format('%I.%I', target_schema, target_table));
    IF table_oid IS NULL THEN
        RETURN NEW;
    END IF;

    IF public.srm_config_column_is_protected(target_column) THEN
        IF changed_structure THEN
            RAISE EXCEPTION
                'Changement refuse: %.%.% est une colonne protegee/systeme.',
                target_schema, target_table, target_column;
        END IF;
        RETURN NEW;
    END IF;

    SELECT
        pg_catalog.format_type(a.atttypid, a.atttypmod),
        a.attnotnull
      INTO physical_type, physical_not_null
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = table_oid
      AND a.attname = target_column
      AND a.attnum > 0
      AND NOT a.attisdropped;

    new_type := public.srm_config_normalize_sql_type(NEW.type_champ);

    IF physical_type IS NULL THEN
        IF COALESCE(NEW.primary_key, false) THEN
            RAISE EXCEPTION
                'Ajout refuse: %.%.% est declare primary_key. Les PK restent manuelles.',
                target_schema, target_table, target_column;
        END IF;

        IF COALESCE(NEW.foreign_key, false) THEN
            RAISE EXCEPTION
                'Ajout refuse: %.%.% est declare foreign_key. Les FK physiques restent manuelles.',
                target_schema, target_table, target_column;
        END IF;

        IF NOT COALESCE(NEW.nullable, true) THEN
            RAISE EXCEPTION
                'Ajout refuse: %.%.% serait NOT NULL. Safe auto autorise seulement les nouvelles colonnes nullable.',
                target_schema, target_table, target_column;
        END IF;

        IF NOT public.srm_config_sql_type_is_allowed(new_type) THEN
            RAISE EXCEPTION
                'Ajout refuse: type_champ "%" non autorise pour %.%.%.',
                NEW.type_champ, target_schema, target_table, target_column;
        END IF;

        IF new_type LIKE 'geometry%' THEN
            RAISE EXCEPTION
                'Ajout refuse: les colonnes geometry restent manuelles pour %.%.%.',
                target_schema, target_table, target_column;
        END IF;

        ddl_sql := format(
            'ALTER TABLE %I.%I ADD COLUMN %I %s',
            target_schema,
            target_table,
            target_column,
            new_type
        );
        EXECUTE ddl_sql;

        INSERT INTO public.srm_config_schema_ddl_log (
            nom_metier,
            nom_table,
            nom_champ,
            operation,
            old_type,
            new_type,
            old_nullable,
            new_nullable,
            sql_applied,
            attribut_config_mobile_id,
            note
        )
        VALUES (
            target_schema,
            target_table,
            target_column,
            'ADD_COLUMN',
            NULL,
            new_type,
            NULL,
            true,
            ddl_sql,
            NEW.id,
            'Safe auto from attribut_config_mobile insert'
        );

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.primary_key IS DISTINCT FROM OLD.primary_key THEN
        RAISE EXCEPTION
            'Changement refuse: primary_key de %.%.% reste manuel.',
            target_schema, target_table, target_column;
    END IF;

    IF TG_OP = 'UPDATE'
       AND (
            NEW.foreign_key IS DISTINCT FROM OLD.foreign_key
            OR NEW.reference_fk IS DISTINCT FROM OLD.reference_fk
       ) THEN
        RAISE EXCEPTION
            'Changement refuse: FK physique de %.%.% reste manuelle. Appliquer la FK par SQL puis realigner la config.',
            target_schema, target_table, target_column;
    END IF;

    IF new_type IS NULL THEN
        RAISE EXCEPTION
            'Changement refuse: type_champ vide pour %.%.%.',
            target_schema, target_table, target_column;
    END IF;

    IF NOT public.srm_config_sql_type_is_allowed(new_type) THEN
        RAISE EXCEPTION
            'Changement refuse: type_champ "%" non autorise pour %.%.%.',
            NEW.type_champ, target_schema, target_table, target_column;
    END IF;

    IF public.srm_config_normalize_sql_type(physical_type) IS DISTINCT FROM new_type THEN
        IF NOT public.srm_config_type_change_is_safe(physical_type, new_type) THEN
            RAISE EXCEPTION
                'Changement de type refuse pour %.%.%: % -> %. Operation non-safe, faire une migration SQL validee.',
                target_schema, target_table, target_column, physical_type, new_type;
        END IF;

        ddl_sql := format(
            'ALTER TABLE %I.%I ALTER COLUMN %I TYPE %s',
            target_schema,
            target_table,
            target_column,
            new_type
        );
        EXECUTE ddl_sql;

        INSERT INTO public.srm_config_schema_ddl_log (
            nom_metier,
            nom_table,
            nom_champ,
            operation,
            old_type,
            new_type,
            old_nullable,
            new_nullable,
            sql_applied,
            attribut_config_mobile_id,
            note
        )
        VALUES (
            target_schema,
            target_table,
            target_column,
            'ALTER_TYPE',
            physical_type,
            new_type,
            NOT physical_not_null,
            NOT physical_not_null,
            ddl_sql,
            NEW.id,
            'Safe auto from attribut_config_mobile type_champ'
        );
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.nullable IS DISTINCT FROM OLD.nullable THEN
        IF physical_not_null AND COALESCE(NEW.nullable, true) THEN
            ddl_sql := format(
                'ALTER TABLE %I.%I ALTER COLUMN %I DROP NOT NULL',
                target_schema,
                target_table,
                target_column
            );
            EXECUTE ddl_sql;

            INSERT INTO public.srm_config_schema_ddl_log (
                nom_metier,
                nom_table,
                nom_champ,
                operation,
                old_type,
                new_type,
                old_nullable,
                new_nullable,
                sql_applied,
                attribut_config_mobile_id,
                note
            )
            VALUES (
                target_schema,
                target_table,
                target_column,
                'DROP_NOT_NULL',
                physical_type,
                new_type,
                false,
                true,
                ddl_sql,
                NEW.id,
                'Safe auto from attribut_config_mobile nullable'
            );
        ELSIF NOT physical_not_null AND NOT COALESCE(NEW.nullable, true) THEN
            RAISE EXCEPTION
                'Changement refuse: rendre %.%.% NOT NULL est non-safe.',
                target_schema, target_table, target_column;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_srm_attribut_config_mobile_schema_guard
ON public.attribut_config_mobile;

CREATE TRIGGER trg_srm_attribut_config_mobile_schema_guard
BEFORE INSERT OR UPDATE OF nom_metier, nom_table, nom_champ, type_champ, nullable, primary_key, foreign_key, reference_fk OR DELETE
ON public.attribut_config_mobile
FOR EACH ROW
EXECUTE FUNCTION public.srm_attribut_config_mobile_schema_guard();
"""


REVERSE_SQL = r"""
DROP TRIGGER IF EXISTS trg_srm_attribut_config_mobile_schema_guard
ON public.attribut_config_mobile;
DROP FUNCTION IF EXISTS public.srm_attribut_config_mobile_schema_guard();
DROP FUNCTION IF EXISTS public.srm_config_type_change_is_safe(text, text);
DROP FUNCTION IF EXISTS public.srm_config_column_is_protected(text);
DROP FUNCTION IF EXISTS public.srm_config_sql_type_is_allowed(text);
DROP FUNCTION IF EXISTS public.srm_config_normalize_sql_type(text);
DROP TABLE IF EXISTS public.srm_config_schema_ddl_log;
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0030_align_mobile_config_with_physical_schema"),
    ]

    operations = [
        migrations.RunSQL(CONFIG_SQL, reverse_sql=REVERSE_SQL),
    ]
