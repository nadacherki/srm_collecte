BEGIN;

CREATE TABLE IF NOT EXISTS public.utilisateur_backup_before_nom_prenom_split_20260504
AS TABLE public.utilisateur;

ALTER TABLE public.utilisateur
    ADD COLUMN IF NOT EXISTS nom varchar(200),
    ADD COLUMN IF NOT EXISTS prenom varchar(200);

WITH source_names AS (
    SELECT
        id_user,
        NULLIF(btrim(nom_prenom), '') AS full_name
    FROM public.utilisateur
    WHERE nom_prenom IS NOT NULL
),
split_names AS (
    SELECT
        id_user,
        split_part(full_name, ' ', 1) AS inferred_prenom,
        NULLIF(btrim(regexp_replace(full_name, '^\S+\s*', '')), '') AS inferred_nom
    FROM source_names
)
UPDATE public.utilisateur u
SET
    prenom = COALESCE(NULLIF(btrim(u.prenom), ''), s.inferred_prenom),
    nom = COALESCE(NULLIF(btrim(u.nom), ''), s.inferred_nom)
FROM split_names s
WHERE u.id_user = s.id_user;

ALTER TABLE public.utilisateur
    DROP COLUMN IF EXISTS nom_prenom;

CREATE OR REPLACE FUNCTION public.capture_historique_attribut()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
    pk_column_name text := TG_ARGV[0];
    v_new jsonb := CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE '{}'::jsonb END;
    v_old jsonb := CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE '{}'::jsonb END;
    v_old_delta jsonb := '{}'::jsonb;
    v_new_delta jsonb := '{}'::jsonb;
    v_payload_old jsonb;
    v_payload_new jsonb;
    v_key text;
    v_pk_value text;
    v_id_objet integer;
    v_id_user integer;
    v_id_user_text text;
    v_nom_user text;
    v_action text;
    v_source text;
    v_ignored_columns text[] := ARRAY['updated_at'];
BEGIN
    v_pk_value := COALESCE(v_new ->> pk_column_name, v_old ->> pk_column_name);
    IF v_pk_value ~ '^[0-9]+$' THEN
        v_id_objet := v_pk_value::integer;
    ELSE
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;
        RETURN NEW;
    END IF;

    v_id_user_text := NULLIF(current_setting('app.current_user_id', true), '');
    IF v_id_user_text IS NULL THEN
        v_id_user_text := COALESCE(
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

    IF v_id_user_text ~ '^[0-9]+$'
       AND EXISTS (SELECT 1 FROM public.utilisateur u WHERE u.id_user = v_id_user_text::integer) THEN
        v_id_user := v_id_user_text::integer;
        SELECT COALESCE(NULLIF(btrim(concat_ws(' ', u.prenom, u.nom)), ''), u.login)
        INTO v_nom_user
        FROM public.utilisateur u
        WHERE u.id_user = v_id_user;
    ELSE
        v_id_user := NULL;
        v_nom_user := NULL;
    END IF;

    v_source := lower(NULLIF(current_setting('app.history_source', true), ''));
    IF v_source IN ('application mobile', 'mobile') THEN
        v_source := 'mobile';
    ELSE
        v_source := 'bureau';
    END IF;

    v_action := lower(NULLIF(current_setting('app.history_action', true), ''));
    IF v_action IS NULL THEN
        v_action := CASE TG_OP
            WHEN 'INSERT' THEN 'insert'
            WHEN 'UPDATE' THEN 'update'
            WHEN 'DELETE' THEN 'delete'
        END;
    END IF;

    IF TG_OP = 'INSERT' THEN
        v_payload_old := NULL;
        v_payload_new := v_new - v_ignored_columns;
        IF v_payload_new = '{}'::jsonb THEN
            RETURN NEW;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
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
            IF (v_old -> v_key) IS NOT DISTINCT FROM (v_new -> v_key) THEN
                CONTINUE;
            END IF;
            v_old_delta := v_old_delta || jsonb_build_object(v_key, v_old -> v_key);
            v_new_delta := v_new_delta || jsonb_build_object(v_key, v_new -> v_key);
        END LOOP;

        IF v_old_delta = '{}'::jsonb AND v_new_delta = '{}'::jsonb THEN
            RETURN NEW;
        END IF;

        v_payload_old := v_old_delta;
        v_payload_new := v_new_delta;
    ELSE
        v_payload_old := v_old - v_ignored_columns;
        v_payload_new := NULL;
        IF v_payload_old = '{}'::jsonb THEN
            RETURN OLD;
        END IF;
    END IF;

    INSERT INTO public.historique_action (
        nom_table,
        id_objet,
        action,
        source,
        id_user,
        nom_user,
        date_action,
        old_data,
        new_data
    ) VALUES (
        TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
        v_id_objet,
        v_action,
        v_source,
        v_id_user,
        v_nom_user,
        now(),
        v_payload_old,
        v_payload_new
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$function$;

COMMIT;
