BEGIN;

ALTER TYPE public.type_action_enum
    ADD VALUE IF NOT EXISTS 'SUPPRESSION_TERRAIN';

ALTER TABLE public.historique_attribut
    ADD COLUMN IF NOT EXISTS cle_ligne VARCHAR(254),
    ADD COLUMN IF NOT EXISTS uuid_objet VARCHAR(254),
    ADD COLUMN IF NOT EXISTS nom_schema VARCHAR(30),
    ADD COLUMN IF NOT EXISTS nom_table VARCHAR(100);

CREATE INDEX IF NOT EXISTS historique_attribut_date_action_idx
    ON public.historique_attribut (date_action DESC);

CREATE INDEX IF NOT EXISTS historique_attribut_schema_table_idx
    ON public.historique_attribut (nom_schema, nom_table);

CREATE INDEX IF NOT EXISTS historique_attribut_uuid_objet_idx
    ON public.historique_attribut (uuid_objet);

CREATE INDEX IF NOT EXISTS historique_attribut_cle_ligne_idx
    ON public.historique_attribut (cle_ligne);

CREATE OR REPLACE FUNCTION public.capture_historique_attribut()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    pk_column_name text := TG_ARGV[0];
    v_new jsonb := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE '{}'::jsonb END;
    v_old jsonb := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE '{}'::jsonb END;
    v_key text;
    v_old_value text;
    v_new_value text;
    v_pk_value text;
    v_uuid_objet text;
    v_cle_ligne text;
    v_id_objet integer;
    v_id_agent integer;
    v_id_agent_text text;
    v_nom_classe text := TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME;
    v_ignored_columns text[] := ARRAY['updated_at'];
BEGIN
    v_pk_value := COALESCE(v_new ->> pk_column_name, v_old ->> pk_column_name);
    v_uuid_objet := COALESCE(
        v_new ->> 'uuid',
        v_old ->> 'uuid',
        v_new ->> 'uuid_objet',
        v_old ->> 'uuid_objet'
    );
    v_cle_ligne := COALESCE(v_uuid_objet, v_pk_value);

    IF v_pk_value ~ '^[0-9]+$' THEN
        v_id_objet := v_pk_value::integer;
    ELSE
        v_id_objet := NULL;
    END IF;

    v_id_agent_text := NULLIF(current_setting('app.current_user_id', true), '');
    IF v_id_agent_text IS NULL THEN
        v_id_agent_text := COALESCE(
            NULLIF(v_new ->> 'id_agent_modif', ''),
            NULLIF(v_old ->> 'id_agent_modif', ''),
            NULLIF(v_new ->> 'id_agent', ''),
            NULLIF(v_old ->> 'id_agent', ''),
            NULLIF(v_new ->> 'id_agent_crea', ''),
            NULLIF(v_old ->> 'id_agent_crea', ''),
            NULLIF(v_new ->> 'id_agent_signal', ''),
            NULLIF(v_old ->> 'id_agent_signal', ''),
            NULLIF(v_new ->> 'id_user', ''),
            NULLIF(v_old ->> 'id_user', '')
        );
    END IF;

    IF v_id_agent_text ~ '^[0-9]+$' THEN
        v_id_agent := v_id_agent_text::integer;
    ELSE
        v_id_agent := NULL;
    END IF;

    IF TG_OP = 'INSERT' THEN
        FOR v_key IN
            SELECT jsonb_object_keys(v_new)
        LOOP
            IF v_key = ANY (v_ignored_columns) THEN
                CONTINUE;
            END IF;

            v_new_value := v_new ->> v_key;
            IF v_new_value IS NULL THEN
                CONTINUE;
            END IF;

            INSERT INTO public.historique_attribut (
                id_objet,
                cle_ligne,
                uuid_objet,
                nom_schema,
                nom_table,
                nom_classe,
                nom_attribut,
                ancienne_valeur,
                nouvelle_valeur,
                date_action,
                id_agent,
                type_action
            ) VALUES (
                v_id_objet,
                v_cle_ligne,
                v_uuid_objet,
                TG_TABLE_SCHEMA,
                TG_TABLE_NAME,
                v_nom_classe,
                v_key,
                NULL,
                v_new_value,
                now(),
                v_id_agent,
                'CREATION'
            );
        END LOOP;

        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        FOR v_key IN
            SELECT key
            FROM (
                SELECT jsonb_object_keys(v_new) AS key
                UNION
                SELECT jsonb_object_keys(v_old) AS key
            ) keys_union
        LOOP
            IF v_key = ANY (v_ignored_columns) THEN
                CONTINUE;
            END IF;

            v_old_value := v_old ->> v_key;
            v_new_value := v_new ->> v_key;

            IF v_old_value IS NOT DISTINCT FROM v_new_value THEN
                CONTINUE;
            END IF;

            INSERT INTO public.historique_attribut (
                id_objet,
                cle_ligne,
                uuid_objet,
                nom_schema,
                nom_table,
                nom_classe,
                nom_attribut,
                ancienne_valeur,
                nouvelle_valeur,
                date_action,
                id_agent,
                type_action
            ) VALUES (
                v_id_objet,
                v_cle_ligne,
                v_uuid_objet,
                TG_TABLE_SCHEMA,
                TG_TABLE_NAME,
                v_nom_classe,
                v_key,
                v_old_value,
                v_new_value,
                now(),
                v_id_agent,
                'MODIFICATION_TERRAIN'
            );
        END LOOP;

        RETURN NEW;
    END IF;

    FOR v_key IN
        SELECT jsonb_object_keys(v_old)
    LOOP
        IF v_key = ANY (v_ignored_columns) THEN
            CONTINUE;
        END IF;

        v_old_value := v_old ->> v_key;
        IF v_old_value IS NULL THEN
            CONTINUE;
        END IF;

        INSERT INTO public.historique_attribut (
            id_objet,
            cle_ligne,
            uuid_objet,
            nom_schema,
            nom_table,
            nom_classe,
            nom_attribut,
            ancienne_valeur,
            nouvelle_valeur,
            date_action,
            id_agent,
            type_action
        ) VALUES (
            v_id_objet,
            v_cle_ligne,
            v_uuid_objet,
            TG_TABLE_SCHEMA,
            TG_TABLE_NAME,
            v_nom_classe,
            v_key,
            v_old_value,
            NULL,
            now(),
            v_id_agent,
            'SUPPRESSION_TERRAIN'
        );
    END LOOP;

    RETURN OLD;
END;
$$;

DO $$
DECLARE
    rec record;
    pk_column text;
    trigger_name text;
BEGIN
    FOR rec IN
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND (
              table_schema IN ('ep', 'ass', 'elec')
              OR (table_schema = 'public' AND table_name IN ('objet_incomplet', 'objet_photo'))
          )
        ORDER BY table_schema, table_name
    LOOP
        SELECT a.attname
          INTO pk_column
        FROM pg_index i
        JOIN pg_class c
          ON c.oid = i.indrelid
        JOIN pg_namespace n
          ON n.oid = c.relnamespace
        JOIN pg_attribute a
          ON a.attrelid = c.oid
         AND a.attnum = ANY(i.indkey)
        WHERE i.indisprimary
          AND n.nspname = rec.table_schema
          AND c.relname = rec.table_name
        ORDER BY a.attnum
        LIMIT 1;

        IF pk_column IS NULL THEN
            CONTINUE;
        END IF;

        trigger_name := format('trg_audit_%s', rec.table_name);

        EXECUTE format(
            'DROP TRIGGER IF EXISTS %I ON %I.%I',
            trigger_name,
            rec.table_schema,
            rec.table_name
        );

        EXECUTE format(
            'CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON %I.%I FOR EACH ROW EXECUTE FUNCTION public.capture_historique_attribut(%L)',
            trigger_name,
            rec.table_schema,
            rec.table_name,
            pk_column
        );
    END LOOP;
END;
$$;

COMMIT;
