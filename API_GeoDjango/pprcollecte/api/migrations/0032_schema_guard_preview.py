from django.db import migrations


CONFIG_SQL = r"""
CREATE OR REPLACE FUNCTION public.srm_preview_attribut_config_mobile_schema_change(
    p_operation text,
    p_old_config jsonb DEFAULT NULL,
    p_new_config jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_catalog
AS $$
DECLARE
    op text := upper(coalesce(nullif(btrim(p_operation), ''), 'UPDATE'));
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
    new_nullable boolean := true;
    new_primary_key boolean := false;
    new_foreign_key boolean := false;
    old_nullable boolean;
    old_primary_key boolean;
    old_foreign_key boolean;
    new_reference_fk text;
    old_reference_fk text;
    changed_structure boolean := false;
    ddl_sql text;
    steps jsonb := '[]'::jsonb;
    reason text;
BEGIN
    IF op NOT IN ('INSERT', 'UPDATE', 'DELETE') THEN
        RETURN jsonb_build_object(
            'blocked', true,
            'will_apply', false,
            'action', 'BLOCK',
            'reason', 'Operation non supportee: ' || coalesce(p_operation, ''),
            'steps', steps
        );
    END IF;

    IF op = 'DELETE' THEN
        target_schema := p_old_config->>'nom_metier';
        target_table := p_old_config->>'nom_table';
        target_column := p_old_config->>'nom_champ';
    ELSE
        target_schema := p_new_config->>'nom_metier';
        target_table := p_new_config->>'nom_table';
        target_column := p_new_config->>'nom_champ';
        new_type := public.srm_config_normalize_sql_type(p_new_config->>'type_champ');
        new_nullable := CASE
            WHEN p_new_config ? 'nullable' AND p_new_config->>'nullable' IS NOT NULL
                THEN (p_new_config->>'nullable')::boolean
            ELSE true
        END;
        new_primary_key := CASE
            WHEN p_new_config ? 'primary_key' AND p_new_config->>'primary_key' IS NOT NULL
                THEN (p_new_config->>'primary_key')::boolean
            ELSE false
        END;
        new_foreign_key := CASE
            WHEN p_new_config ? 'foreign_key' AND p_new_config->>'foreign_key' IS NOT NULL
                THEN (p_new_config->>'foreign_key')::boolean
            ELSE false
        END;
        new_reference_fk := p_new_config->>'reference_fk';
    END IF;

    IF target_schema IS NULL OR target_table IS NULL OR target_column IS NULL THEN
        RETURN jsonb_build_object(
            'blocked', true,
            'will_apply', false,
            'action', 'BLOCK',
            'reason', 'nom_metier, nom_table et nom_champ sont obligatoires pour previsualiser le changement.',
            'steps', steps
        );
    END IF;

    IF target_schema NOT IN ('ep', 'asst') THEN
        RETURN jsonb_build_object(
            'blocked', false,
            'will_apply', false,
            'action', 'IGNORE',
            'reason', 'Le garde-fou schema cible seulement ep/asst.',
            'nom_metier', target_schema,
            'nom_table', target_table,
            'nom_champ', target_column,
            'steps', steps
        );
    END IF;

    IF op = 'UPDATE' AND p_old_config IS NOT NULL THEN
        old_schema := p_old_config->>'nom_metier';
        old_table := p_old_config->>'nom_table';
        old_column := p_old_config->>'nom_champ';
        old_nullable := CASE
            WHEN p_old_config ? 'nullable' AND p_old_config->>'nullable' IS NOT NULL
                THEN (p_old_config->>'nullable')::boolean
            ELSE true
        END;
        old_primary_key := CASE
            WHEN p_old_config ? 'primary_key' AND p_old_config->>'primary_key' IS NOT NULL
                THEN (p_old_config->>'primary_key')::boolean
            ELSE false
        END;
        old_foreign_key := CASE
            WHEN p_old_config ? 'foreign_key' AND p_old_config->>'foreign_key' IS NOT NULL
                THEN (p_old_config->>'foreign_key')::boolean
            ELSE false
        END;
        old_reference_fk := p_old_config->>'reference_fk';

        IF old_schema IN ('ep', 'asst') THEN
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
                    reason := format(
                        'Renommage/deplacement refuse: %s.%s.%s existe physiquement. Faire une migration SQL explicite puis realigner attribut_config_mobile.',
                        old_schema,
                        old_table,
                        old_column
                    );
                    RETURN jsonb_build_object(
                        'blocked', true,
                        'will_apply', false,
                        'action', 'BLOCK',
                        'reason', reason,
                        'nom_metier', target_schema,
                        'nom_table', target_table,
                        'nom_champ', target_column,
                        'old_type', old_physical_type,
                        'steps', steps
                    );
                END IF;
            END IF;
        END IF;
    END IF;

    SELECT true INTO form_exists
    FROM public.formulaire_config_mobile f
    WHERE f.nom_metier = target_schema
      AND f.nom_table = target_table
    LIMIT 1;

    IF NOT COALESCE(form_exists, false) THEN
        RETURN jsonb_build_object(
            'blocked', false,
            'will_apply', false,
            'action', 'IGNORE',
            'reason', 'Table non declaree dans formulaire_config_mobile, aucun DDL safe-auto.',
            'nom_metier', target_schema,
            'nom_table', target_table,
            'nom_champ', target_column,
            'steps', steps
        );
    END IF;

    table_oid := to_regclass(format('%I.%I', target_schema, target_table));
    IF table_oid IS NULL THEN
        RETURN jsonb_build_object(
            'blocked', false,
            'will_apply', false,
            'action', 'IGNORE',
            'reason', 'Table physique absente, aucun DDL safe-auto.',
            'nom_metier', target_schema,
            'nom_table', target_table,
            'nom_champ', target_column,
            'steps', steps
        );
    END IF;

    IF op = 'DELETE' THEN
        SELECT pg_catalog.format_type(a.atttypid, a.atttypmod)
          INTO physical_type
        FROM pg_catalog.pg_attribute a
        WHERE a.attrelid = table_oid
          AND a.attname = target_column
          AND a.attnum > 0
          AND NOT a.attisdropped;

        IF physical_type IS NOT NULL THEN
            reason := format(
                'Suppression refusee: %s.%s.%s existe physiquement (%s). Supprimer/valider la colonne par SQL/migration bureau avant de supprimer attribut_config_mobile.',
                target_schema,
                target_table,
                target_column,
                physical_type
            );
            RETURN jsonb_build_object(
                'blocked', true,
                'will_apply', false,
                'action', 'BLOCK',
                'reason', reason,
                'nom_metier', target_schema,
                'nom_table', target_table,
                'nom_champ', target_column,
                'old_type', physical_type,
                'steps', steps
            );
        END IF;

        RETURN jsonb_build_object(
            'blocked', false,
            'will_apply', false,
            'action', 'NO_DDL',
            'reason', 'Aucune colonne physique correspondante, suppression de config autorisee.',
            'nom_metier', target_schema,
            'nom_table', target_table,
            'nom_champ', target_column,
            'steps', steps
        );
    END IF;

    changed_structure := (
        op = 'INSERT'
        OR p_new_config->>'type_champ' IS DISTINCT FROM p_old_config->>'type_champ'
        OR new_nullable IS DISTINCT FROM old_nullable
        OR new_primary_key IS DISTINCT FROM old_primary_key
        OR new_foreign_key IS DISTINCT FROM old_foreign_key
        OR new_reference_fk IS DISTINCT FROM old_reference_fk
    );

    IF public.srm_config_column_is_protected(target_column) THEN
        IF changed_structure THEN
            reason := format(
                'Changement refuse: %s.%s.%s est une colonne protegee/systeme.',
                target_schema,
                target_table,
                target_column
            );
            RETURN jsonb_build_object(
                'blocked', true,
                'will_apply', false,
                'action', 'BLOCK',
                'reason', reason,
                'nom_metier', target_schema,
                'nom_table', target_table,
                'nom_champ', target_column,
                'steps', steps
            );
        END IF;

        RETURN jsonb_build_object(
            'blocked', false,
            'will_apply', false,
            'action', 'NO_DDL',
            'reason', 'Colonne protegee sans changement structurel.',
            'nom_metier', target_schema,
            'nom_table', target_table,
            'nom_champ', target_column,
            'steps', steps
        );
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

    IF physical_type IS NULL THEN
        IF COALESCE(new_primary_key, false) THEN
            reason := format('Ajout refuse: %s.%s.%s est declare primary_key. Les PK restent manuelles.', target_schema, target_table, target_column);
            RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'new_type', new_type, 'steps', steps);
        END IF;

        IF COALESCE(new_foreign_key, false) THEN
            reason := format('Ajout refuse: %s.%s.%s est declare foreign_key. Les FK physiques restent manuelles.', target_schema, target_table, target_column);
            RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'new_type', new_type, 'steps', steps);
        END IF;

        IF NOT COALESCE(new_nullable, true) THEN
            reason := format('Ajout refuse: %s.%s.%s serait NOT NULL. Safe auto autorise seulement les nouvelles colonnes nullable.', target_schema, target_table, target_column);
            RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'new_type', new_type, 'steps', steps);
        END IF;

        IF NOT public.srm_config_sql_type_is_allowed(new_type) THEN
            reason := format('Ajout refuse: type_champ "%s" non autorise pour %s.%s.%s.', coalesce(p_new_config->>'type_champ', ''), target_schema, target_table, target_column);
            RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'new_type', new_type, 'steps', steps);
        END IF;

        IF new_type LIKE 'geometry%' THEN
            reason := format('Ajout refuse: les colonnes geometry restent manuelles pour %s.%s.%s.', target_schema, target_table, target_column);
            RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'new_type', new_type, 'steps', steps);
        END IF;

        ddl_sql := format('ALTER TABLE %I.%I ADD COLUMN %I %s', target_schema, target_table, target_column, new_type);
        steps := steps || jsonb_build_array(jsonb_build_object(
            'operation', 'ADD_COLUMN',
            'sql', ddl_sql,
            'old_type', NULL,
            'new_type', new_type,
            'old_nullable', NULL,
            'new_nullable', true
        ));

        RETURN jsonb_build_object(
            'blocked', false,
            'will_apply', true,
            'action', 'APPLY_SAFE',
            'reason', 'Ajout de colonne nullable sans perte.',
            'nom_metier', target_schema,
            'nom_table', target_table,
            'nom_champ', target_column,
            'new_type', new_type,
            'new_nullable', true,
            'steps', steps
        );
    END IF;

    IF op = 'UPDATE' AND new_primary_key IS DISTINCT FROM old_primary_key THEN
        reason := format('Changement refuse: primary_key de %s.%s.%s reste manuel.', target_schema, target_table, target_column);
        RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'old_type', physical_type, 'new_type', new_type, 'steps', steps);
    END IF;

    IF op = 'UPDATE'
       AND (
            new_foreign_key IS DISTINCT FROM old_foreign_key
            OR new_reference_fk IS DISTINCT FROM old_reference_fk
       ) THEN
        reason := format('Changement refuse: FK physique de %s.%s.%s reste manuelle. Appliquer la FK par SQL puis realigner la config avec validation explicite.', target_schema, target_table, target_column);
        RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'old_type', physical_type, 'new_type', new_type, 'steps', steps);
    END IF;

    IF new_type IS NULL THEN
        reason := format('Changement refuse: type_champ vide pour %s.%s.%s.', target_schema, target_table, target_column);
        RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'old_type', physical_type, 'steps', steps);
    END IF;

    IF NOT public.srm_config_sql_type_is_allowed(new_type) THEN
        reason := format('Changement refuse: type_champ "%s" non autorise pour %s.%s.%s.', coalesce(p_new_config->>'type_champ', ''), target_schema, target_table, target_column);
        RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'old_type', physical_type, 'new_type', new_type, 'steps', steps);
    END IF;

    IF public.srm_config_normalize_sql_type(physical_type) IS DISTINCT FROM new_type THEN
        IF NOT public.srm_config_type_change_is_safe(physical_type, new_type) THEN
            reason := format('Changement de type refuse pour %s.%s.%s: %s -> %s. Operation non-safe, faire une migration SQL validee.', target_schema, target_table, target_column, physical_type, new_type);
            RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'old_type', physical_type, 'new_type', new_type, 'steps', steps);
        END IF;

        ddl_sql := format('ALTER TABLE %I.%I ALTER COLUMN %I TYPE %s', target_schema, target_table, target_column, new_type);
        steps := steps || jsonb_build_array(jsonb_build_object(
            'operation', 'ALTER_TYPE',
            'sql', ddl_sql,
            'old_type', physical_type,
            'new_type', new_type,
            'old_nullable', NOT physical_not_null,
            'new_nullable', NOT physical_not_null
        ));
    END IF;

    IF op = 'UPDATE' AND new_nullable IS DISTINCT FROM old_nullable THEN
        IF physical_not_null AND COALESCE(new_nullable, true) THEN
            ddl_sql := format('ALTER TABLE %I.%I ALTER COLUMN %I DROP NOT NULL', target_schema, target_table, target_column);
            steps := steps || jsonb_build_array(jsonb_build_object(
                'operation', 'DROP_NOT_NULL',
                'sql', ddl_sql,
                'old_type', physical_type,
                'new_type', new_type,
                'old_nullable', false,
                'new_nullable', true
            ));
        ELSIF NOT physical_not_null AND NOT COALESCE(new_nullable, true) THEN
            reason := format('Changement refuse: rendre %s.%s.%s NOT NULL est non-safe.', target_schema, target_table, target_column);
            RETURN jsonb_build_object('blocked', true, 'will_apply', false, 'action', 'BLOCK', 'reason', reason, 'nom_metier', target_schema, 'nom_table', target_table, 'nom_champ', target_column, 'old_type', physical_type, 'new_type', new_type, 'old_nullable', true, 'new_nullable', false, 'steps', steps);
        END IF;
    END IF;

    IF jsonb_array_length(steps) > 0 THEN
        RETURN jsonb_build_object(
            'blocked', false,
            'will_apply', true,
            'action', 'APPLY_SAFE',
            'reason', 'Changement physique safe-auto applicable.',
            'nom_metier', target_schema,
            'nom_table', target_table,
            'nom_champ', target_column,
            'old_type', physical_type,
            'new_type', new_type,
            'old_nullable', NOT physical_not_null,
            'new_nullable', new_nullable,
            'steps', steps
        );
    END IF;

    RETURN jsonb_build_object(
        'blocked', false,
        'will_apply', false,
        'action', 'NO_DDL',
        'reason', 'Aucun changement physique necessaire.',
        'nom_metier', target_schema,
        'nom_table', target_table,
        'nom_champ', target_column,
        'old_type', physical_type,
        'new_type', new_type,
        'old_nullable', NOT physical_not_null,
        'new_nullable', new_nullable,
        'steps', steps
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_attribut_config_mobile_schema_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    preview jsonb;
    step jsonb;
    ddl_sql text;
BEGIN
    IF TG_OP = 'DELETE' THEN
        preview := public.srm_preview_attribut_config_mobile_schema_change(
            TG_OP,
            to_jsonb(OLD),
            NULL
        );
    ELSIF TG_OP = 'INSERT' THEN
        preview := public.srm_preview_attribut_config_mobile_schema_change(
            TG_OP,
            NULL,
            to_jsonb(NEW)
        );
    ELSE
        preview := public.srm_preview_attribut_config_mobile_schema_change(
            TG_OP,
            to_jsonb(OLD),
            to_jsonb(NEW)
        );
    END IF;

    IF COALESCE((preview->>'blocked')::boolean, false) THEN
        RAISE EXCEPTION '%', preview->>'reason';
    END IF;

    IF COALESCE((preview->>'will_apply')::boolean, false) THEN
        FOR step IN SELECT value FROM jsonb_array_elements(preview->'steps') AS s(value)
        LOOP
            ddl_sql := step->>'sql';
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
                preview->>'nom_metier',
                preview->>'nom_table',
                preview->>'nom_champ',
                step->>'operation',
                step->>'old_type',
                step->>'new_type',
                (step->>'old_nullable')::boolean,
                (step->>'new_nullable')::boolean,
                ddl_sql,
                CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
                'Safe auto from attribut_config_mobile schema preview'
            );
        END LOOP;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;
"""


REVERSE_SQL = r"""
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

        ddl_sql := format(
            'ALTER TABLE %I.%I ADD COLUMN %I %s',
            target_schema,
            target_table,
            target_column,
            new_type
        );
        EXECUTE ddl_sql;

        INSERT INTO public.srm_config_schema_ddl_log (
            nom_metier, nom_table, nom_champ, operation, old_type, new_type,
            old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
        )
        VALUES (
            target_schema, target_table, target_column, 'ADD_COLUMN', NULL, new_type,
            NULL, true, ddl_sql, NEW.id, 'Safe auto from attribut_config_mobile insert'
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
            nom_metier, nom_table, nom_champ, operation, old_type, new_type,
            old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
        )
        VALUES (
            target_schema, target_table, target_column, 'ALTER_TYPE', physical_type, new_type,
            NOT physical_not_null, NOT physical_not_null, ddl_sql, NEW.id,
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
                nom_metier, nom_table, nom_champ, operation, old_type, new_type,
                old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
            )
            VALUES (
                target_schema, target_table, target_column, 'DROP_NOT_NULL', physical_type, new_type,
                false, true, ddl_sql, NEW.id, 'Safe auto from attribut_config_mobile nullable'
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

DROP FUNCTION IF EXISTS public.srm_preview_attribut_config_mobile_schema_change(text, jsonb, jsonb);
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0031_safe_auto_schema_from_attribut_config"),
    ]

    operations = [
        migrations.RunSQL(CONFIG_SQL, reverse_sql=REVERSE_SQL),
    ]
