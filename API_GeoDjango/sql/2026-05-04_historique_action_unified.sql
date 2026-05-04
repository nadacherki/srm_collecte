BEGIN;

DO $$
DECLARE
    has_rows boolean;
BEGIN
    IF to_regclass('public.historique_action') IS NOT NULL
       AND to_regclass('public.historique_action_backup_before_unified_20260504') IS NULL THEN
        EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.historique_action)' INTO has_rows;
        IF has_rows THEN
            EXECUTE 'CREATE TABLE public.historique_action_backup_before_unified_20260504 AS TABLE public.historique_action';
        END IF;
    END IF;

    IF to_regclass('public.historique_attribut') IS NOT NULL
       AND to_regclass('public.historique_attribut_backup_before_unified_20260504') IS NULL THEN
        EXECUTE 'CREATE TABLE public.historique_attribut_backup_before_unified_20260504 AS TABLE public.historique_attribut';
    END IF;

    IF to_regclass('public.historique_mobile') IS NOT NULL
       AND to_regclass('public.historique_mobile_backup_before_unified_20260504') IS NULL THEN
        EXECUTE 'CREATE TABLE public.historique_mobile_backup_before_unified_20260504 AS TABLE public.historique_mobile';
    END IF;
END $$;

DROP VIEW IF EXISTS public.vw_metrics_agent_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_jour CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_jour CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_agent_public_resume CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_jour CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_resume CASCADE;
DROP VIEW IF EXISTS public.vw_srm_historique_mobile_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_historique_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_incomplet_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_photo_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_objet_dates CASCADE;
DROP VIEW IF EXISTS public.vw_srm_mission_fact CASCADE;
DROP VIEW IF EXISTS public.vw_srm_objet_fact CASCADE;

CREATE TABLE IF NOT EXISTS public.historique_action (
    id serial PRIMARY KEY,
    nom_table varchar(100) NOT NULL,
    id_objet integer NOT NULL,
    action varchar(50) NOT NULL,
    source varchar(20) NOT NULL DEFAULT 'bureau',
    id_user integer,
    nom_user varchar(255),
    date_action timestamptz NOT NULL DEFAULT now(),
    old_data jsonb,
    new_data jsonb
);

ALTER TABLE public.historique_action
    ADD COLUMN IF NOT EXISTS nom_table varchar(100),
    ADD COLUMN IF NOT EXISTS id_objet integer,
    ADD COLUMN IF NOT EXISTS action varchar(50),
    ADD COLUMN IF NOT EXISTS source varchar(20),
    ADD COLUMN IF NOT EXISTS id_user integer,
    ADD COLUMN IF NOT EXISTS nom_user varchar(255),
    ADD COLUMN IF NOT EXISTS date_action timestamptz,
    ADD COLUMN IF NOT EXISTS old_data jsonb,
    ADD COLUMN IF NOT EXISTS new_data jsonb;

ALTER TABLE public.historique_action
    ALTER COLUMN nom_table TYPE varchar(100),
    ALTER COLUMN action TYPE varchar(50),
    ALTER COLUMN source TYPE varchar(20),
    ALTER COLUMN nom_user TYPE varchar(255);

ALTER TABLE public.historique_action DROP CONSTRAINT IF EXISTS chk_source;
ALTER TABLE public.historique_action DROP CONSTRAINT IF EXISTS historique_action_source_check;
ALTER TABLE public.historique_action DROP CONSTRAINT IF EXISTS historique_action_mobile_action_check;
ALTER TABLE public.historique_action DROP CONSTRAINT IF EXISTS historique_action_id_user_fkey;

UPDATE public.historique_action
SET
    nom_table = replace(trim(nom_table), '"', ''),
    source = CASE
        WHEN source IS NULL OR btrim(source) = '' THEN 'bureau'
        WHEN lower(btrim(source)) IN ('application web', 'web', 'bureau', 'backoffice') THEN 'bureau'
        WHEN lower(btrim(source)) IN ('application mobile', 'mobile') THEN 'mobile'
        ELSE 'bureau'
    END,
    date_action = COALESCE(date_action, now());

UPDATE public.historique_action h
SET id_user = NULL
WHERE h.id_user IS NOT NULL
  AND to_regclass('public.utilisateur') IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM public.utilisateur u
      WHERE u.id_user = h.id_user
  );

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'historique_action'
          AND column_name = 'source'
          AND ordinal_position <> 5
    ) THEN
        DROP TABLE IF EXISTS public.historique_action_reordered_20260504;

        CREATE TABLE public.historique_action_reordered_20260504 (
            id integer NOT NULL,
            nom_table varchar(100),
            id_objet integer,
            action varchar(50),
            source varchar(20),
            id_user integer,
            nom_user varchar(255),
            date_action timestamptz,
            old_data jsonb,
            new_data jsonb
        );

        INSERT INTO public.historique_action_reordered_20260504 (
            id,
            nom_table,
            id_objet,
            action,
            source,
            id_user,
            nom_user,
            date_action,
            old_data,
            new_data
        )
        SELECT
            id,
            nom_table,
            id_objet,
            action,
            source,
            id_user,
            nom_user,
            date_action,
            old_data,
            new_data
        FROM public.historique_action
        ORDER BY id;

        DROP TABLE public.historique_action;
        ALTER TABLE public.historique_action_reordered_20260504 RENAME TO historique_action;

        CREATE SEQUENCE IF NOT EXISTS public.historique_action_id_seq;
        ALTER SEQUENCE public.historique_action_id_seq OWNED BY public.historique_action.id;
        ALTER TABLE public.historique_action
            ALTER COLUMN id SET DEFAULT nextval('public.historique_action_id_seq'::regclass);
        PERFORM setval(
            'public.historique_action_id_seq',
            COALESCE((SELECT max(id) FROM public.historique_action), 1),
            EXISTS (SELECT 1 FROM public.historique_action)
        );
    END IF;
END $$;

ALTER TABLE public.historique_action
    ALTER COLUMN id SET NOT NULL,
    ALTER COLUMN nom_table SET NOT NULL,
    ALTER COLUMN id_objet SET NOT NULL,
    ALTER COLUMN action SET NOT NULL,
    ALTER COLUMN source SET DEFAULT 'bureau',
    ALTER COLUMN source SET NOT NULL,
    ALTER COLUMN date_action SET DEFAULT now(),
    ALTER COLUMN date_action SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'public'
          AND t.relname = 'historique_action'
          AND c.conname = 'historique_action_pkey'
    ) THEN
        ALTER TABLE public.historique_action
            ADD CONSTRAINT historique_action_pkey PRIMARY KEY (id);
    END IF;
END $$;

ALTER TABLE public.historique_action
    ADD CONSTRAINT historique_action_source_check
    CHECK (source IN ('bureau', 'mobile'));

ALTER TABLE public.historique_action
    ADD CONSTRAINT historique_action_mobile_action_check
    CHECK (source <> 'mobile' OR lower(action) IN ('insert', 'update', 'validate'));

DO $$
BEGIN
    IF to_regclass('public.utilisateur') IS NOT NULL THEN
        ALTER TABLE public.historique_action
            ADD CONSTRAINT historique_action_id_user_fkey
            FOREIGN KEY (id_user)
            REFERENCES public.utilisateur(id_user)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;
END $$;

DROP INDEX IF EXISTS public.idx_historique_action_date;
DROP INDEX IF EXISTS public.idx_historique_action_objet;

CREATE INDEX IF NOT EXISTS historique_action_table_objet_date_idx
    ON public.historique_action (nom_table, id_objet, date_action DESC);

CREATE INDEX IF NOT EXISTS historique_action_source_date_idx
    ON public.historique_action (source, date_action DESC);

CREATE INDEX IF NOT EXISTS historique_action_user_date_idx
    ON public.historique_action (id_user, date_action DESC);

DROP TABLE IF EXISTS public.historique_attribut;
DROP TABLE IF EXISTS public.historique_mobile;

CREATE OR REPLACE FUNCTION public.capture_historique_attribut()
RETURNS trigger
LANGUAGE plpgsql
AS $$
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
$$;

COMMIT;
