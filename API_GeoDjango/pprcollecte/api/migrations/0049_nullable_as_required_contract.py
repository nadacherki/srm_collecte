from django.db import migrations


PATCH_SCHEMA_GUARD_SQL = r"""
DO $$
DECLARE
    fn text;
BEGIN
    SELECT pg_get_functiondef(
        'public.srm_preview_attribut_config_mobile_schema_change(text,jsonb,jsonb)'::regprocedure
    )
      INTO fn;

    fn := replace(
        fn,
        '    reason text;
BEGIN',
        '    reason text;
    null_count bigint := 0;
    constraint_name text;
    check_exists boolean := false;
BEGIN'
    );

    fn := replace(
        fn,
        $old$
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
$old$,
        $new$
    IF op = 'UPDATE' AND new_nullable IS DISTINCT FROM old_nullable THEN
        constraint_name := format('srm_nn_%s', substr(md5(target_column), 1, 16));
        SELECT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_constraint con
            WHERE con.conrelid = table_oid
              AND con.conname = constraint_name
        ) INTO check_exists;

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
        ELSIF NOT physical_not_null AND COALESCE(new_nullable, true) AND check_exists THEN
            ddl_sql := format('ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I', target_schema, target_table, constraint_name);
            steps := steps || jsonb_build_array(jsonb_build_object(
                'operation', 'DROP_NOT_NULL_CHECK',
                'sql', ddl_sql,
                'old_type', physical_type,
                'new_type', new_type,
                'old_nullable', false,
                'new_nullable', true
            ));
        ELSIF NOT physical_not_null AND NOT COALESCE(new_nullable, true) THEN
            EXECUTE format(
                'SELECT count(*) FROM %I.%I WHERE %I IS NULL',
                target_schema, target_table, target_column
            ) INTO null_count;

            IF null_count = 0 THEN
                ddl_sql := format('ALTER TABLE %I.%I ALTER COLUMN %I SET NOT NULL', target_schema, target_table, target_column);
                steps := steps || jsonb_build_array(jsonb_build_object(
                    'operation', 'SET_NOT_NULL',
                    'sql', ddl_sql,
                    'old_type', physical_type,
                    'new_type', new_type,
                    'old_nullable', true,
                    'new_nullable', false
                ));
            ELSE
                ddl_sql := format(
                    'ALTER TABLE %I.%I ADD CONSTRAINT %I CHECK (%I IS NOT NULL) NOT VALID',
                    target_schema, target_table, constraint_name, target_column
                );
                steps := steps || jsonb_build_array(jsonb_build_object(
                    'operation', 'ADD_NOT_NULL_CHECK',
                    'sql', ddl_sql,
                    'old_type', physical_type,
                    'new_type', new_type,
                    'old_nullable', true,
                    'new_nullable', false,
                    'existing_null_rows', null_count
                ));
            END IF;
        END IF;
    END IF;
$new$
    );

    EXECUTE fn;

    SELECT pg_get_functiondef(
        'public.srm_attribut_config_mobile_schema_guard()'::regprocedure
    )
      INTO fn;

    fn := replace(
        fn,
        '    ddl_sql text;
    changed_structure boolean := false;
BEGIN',
        '    ddl_sql text;
    changed_structure boolean := false;
    null_count bigint := 0;
    constraint_name text;
    check_exists boolean := false;
BEGIN'
    );

    fn := replace(
        fn,
        $old$
        IF NOT COALESCE(NEW.nullable, true) THEN
            RAISE EXCEPTION
                'Ajout refuse: %.%.% serait NOT NULL. Safe auto autorise seulement les nouvelles colonnes nullable.',
                target_schema, target_table, target_column;
        END IF;

        IF NOT public.srm_config_sql_type_is_allowed(new_type) THEN
$old$,
        $new$
        IF NOT public.srm_config_sql_type_is_allowed(new_type) THEN
$new$
    );

    fn := replace(
        fn,
        $old$
        INSERT INTO public.srm_config_schema_ddl_log (
            nom_metier, nom_table, nom_champ, operation, old_type, new_type,
            old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
        )
        VALUES (
            target_schema, target_table, target_column, 'ADD_COLUMN', NULL, new_type,
            NULL, true, ddl_sql, NEW.id, 'Safe auto from attribut_config_mobile insert'
        );

        RETURN NEW;
$old$,
        $new$
        INSERT INTO public.srm_config_schema_ddl_log (
            nom_metier, nom_table, nom_champ, operation, old_type, new_type,
            old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
        )
        VALUES (
            target_schema, target_table, target_column, 'ADD_COLUMN', NULL, new_type,
            NULL, true, ddl_sql, NEW.id, 'Safe auto from attribut_config_mobile insert'
        );

        IF NOT COALESCE(NEW.nullable, true) THEN
            constraint_name := format('srm_nn_%s', substr(md5(target_column), 1, 16));
            EXECUTE format('SELECT count(*) FROM %I.%I WHERE %I IS NULL', target_schema, target_table, target_column)
              INTO null_count;

            IF null_count = 0 THEN
                ddl_sql := format(
                    'ALTER TABLE %I.%I ALTER COLUMN %I SET NOT NULL',
                    target_schema, target_table, target_column
                );
                EXECUTE ddl_sql;

                INSERT INTO public.srm_config_schema_ddl_log (
                    nom_metier, nom_table, nom_champ, operation, old_type, new_type,
                    old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
                )
                VALUES (
                    target_schema, target_table, target_column, 'SET_NOT_NULL', new_type, new_type,
                    true, false, ddl_sql, NEW.id, 'Safe auto from attribut_config_mobile nullable'
                );
            ELSE
                ddl_sql := format(
                    'ALTER TABLE %I.%I ADD CONSTRAINT %I CHECK (%I IS NOT NULL) NOT VALID',
                    target_schema, target_table, constraint_name, target_column
                );
                EXECUTE ddl_sql;

                INSERT INTO public.srm_config_schema_ddl_log (
                    nom_metier, nom_table, nom_champ, operation, old_type, new_type,
                    old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
                )
                VALUES (
                    target_schema, target_table, target_column, 'ADD_NOT_NULL_CHECK', new_type, new_type,
                    true, false, ddl_sql, NEW.id,
                    format('Nullable=false enforced for new rows; %s historic NULL rows remain to clean.', null_count)
                );
            END IF;
        END IF;

        RETURN NEW;
$new$
    );

    fn := replace(
        fn,
        $old$
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
$old$,
        $new$
    IF TG_OP = 'UPDATE' AND NEW.nullable IS DISTINCT FROM OLD.nullable THEN
        constraint_name := format('srm_nn_%s', substr(md5(target_column), 1, 16));
        SELECT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_constraint con
            WHERE con.conrelid = table_oid
              AND con.conname = constraint_name
        ) INTO check_exists;

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

            IF check_exists THEN
                ddl_sql := format('ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I', target_schema, target_table, constraint_name);
                EXECUTE ddl_sql;
            END IF;
        ELSIF NOT physical_not_null AND COALESCE(NEW.nullable, true) AND check_exists THEN
            ddl_sql := format('ALTER TABLE %I.%I DROP CONSTRAINT IF EXISTS %I', target_schema, target_table, constraint_name);
            EXECUTE ddl_sql;

            INSERT INTO public.srm_config_schema_ddl_log (
                nom_metier, nom_table, nom_champ, operation, old_type, new_type,
                old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
            )
            VALUES (
                target_schema, target_table, target_column, 'DROP_NOT_NULL_CHECK', physical_type, new_type,
                false, true, ddl_sql, NEW.id, 'Safe auto from attribut_config_mobile nullable'
            );
        ELSIF NOT physical_not_null AND NOT COALESCE(NEW.nullable, true) THEN
            EXECUTE format(
                'SELECT count(*) FROM %I.%I WHERE %I IS NULL',
                target_schema, target_table, target_column
            ) INTO null_count;

            IF null_count = 0 THEN
                ddl_sql := format(
                    'ALTER TABLE %I.%I ALTER COLUMN %I SET NOT NULL',
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
                    target_schema, target_table, target_column, 'SET_NOT_NULL', physical_type, new_type,
                    true, false, ddl_sql, NEW.id, 'Safe auto from attribut_config_mobile nullable'
                );
            ELSIF NOT check_exists THEN
                ddl_sql := format(
                    'ALTER TABLE %I.%I ADD CONSTRAINT %I CHECK (%I IS NOT NULL) NOT VALID',
                    target_schema,
                    target_table,
                    constraint_name,
                    target_column
                );
                EXECUTE ddl_sql;

                INSERT INTO public.srm_config_schema_ddl_log (
                    nom_metier, nom_table, nom_champ, operation, old_type, new_type,
                    old_nullable, new_nullable, sql_applied, attribut_config_mobile_id, note
                )
                VALUES (
                    target_schema, target_table, target_column, 'ADD_NOT_NULL_CHECK', physical_type, new_type,
                    true, false, ddl_sql, NEW.id,
                    format('Nullable=false enforced for new rows; %s historic NULL rows remain to clean.', null_count)
                );
            END IF;
        END IF;
    END IF;
$new$
    );

    EXECUTE fn;
END $$;
"""


UPDATE_NULLABLE_CONTRACT_SQL = r"""
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'attribut_config_mobile'
          AND column_name = 'obligatoire'
    ) THEN
        UPDATE public.attribut_config_mobile acm
           SET nullable = NOT COALESCE(acm.obligatoire, false)
         WHERE lower(acm.nom_metier) IN ('ep', 'asst')
           AND COALESCE(acm.visible, false) = true
           AND COALESCE(acm.primary_key, false) = false
           AND lower(acm.nom_champ) NOT IN ('id', 'fid', 'geom')
           AND EXISTS (
               SELECT 1
               FROM information_schema.columns c
               WHERE c.table_schema = lower(acm.nom_metier)
                 AND c.table_name = acm.nom_table
                 AND lower(c.column_name) = lower(acm.nom_champ)
           )
           AND acm.nullable IS DISTINCT FROM NOT COALESCE(acm.obligatoire, false);
    END IF;
END $$;
"""


DROP_OBLIGATOIRE_SQL = r"""
ALTER TABLE public.attribut_config_mobile
    DROP COLUMN IF EXISTS obligatoire;

COMMENT ON COLUMN public.attribut_config_mobile.nullable IS
    'Source unique du contrat requis: false = NOT NULL cote BD et champ obligatoire cote mobile; true = facultatif.';
"""


class Migration(migrations.Migration):
    atomic = False

    dependencies = [
        ("api", "0048_fix_obligatoire_case_insensitive"),
    ]

    operations = [
        migrations.RunSQL(PATCH_SCHEMA_GUARD_SQL, reverse_sql=migrations.RunSQL.noop),
        migrations.RunSQL(UPDATE_NULLABLE_CONTRACT_SQL, reverse_sql=migrations.RunSQL.noop),
        migrations.RunSQL(DROP_OBLIGATOIRE_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
