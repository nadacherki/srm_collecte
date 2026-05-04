BEGIN;

DO $$
BEGIN
    IF to_regclass('public.intervention_anomalie') IS NOT NULL
       AND to_regclass('public.intervention_anomalie_backup_before_hardening_20260504') IS NULL THEN
        EXECUTE 'CREATE TABLE public.intervention_anomalie_backup_before_hardening_20260504 AS TABLE public.intervention_anomalie';
    END IF;

    IF to_regclass('public.intervention_log') IS NOT NULL
       AND to_regclass('public.intervention_log_backup_before_hardening_20260504') IS NULL THEN
        EXECUTE 'CREATE TABLE public.intervention_log_backup_before_hardening_20260504 AS TABLE public.intervention_log';
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.intervention_anomalie (
    id SERIAL PRIMARY KEY,
    id_objet INTEGER NOT NULL,
    nom_classe VARCHAR(100) NOT NULL,
    retour_terrain BOOLEAN DEFAULT false,
    statut VARCHAR(50) NOT NULL DEFAULT 'signale',
    responsable_actuel VARCHAR(50) DEFAULT 'terrain',
    etat_exploitant VARCHAR(50) DEFAULT 'en_attente',
    commentaire_exploitant TEXT,
    date_exploitant TIMESTAMP,
    id_user_exploitant INTEGER REFERENCES public.utilisateur(id_user),
    etat_terrain VARCHAR(50) DEFAULT 'en_attente',
    commentaire_terrain TEXT,
    date_terrain TIMESTAMP,
    id_user_terrain INTEGER REFERENCES public.utilisateur(id_user),
    etat_bureau VARCHAR(50) DEFAULT 'en_attente',
    commentaire_bureau TEXT,
    date_bureau TIMESTAMP,
    id_user_bureau INTEGER REFERENCES public.utilisateur(id_user),
    date_creation TIMESTAMP DEFAULT now(),
    date_cloture TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.intervention_log (
    id SERIAL PRIMARY KEY,
    id_intervention INTEGER NOT NULL REFERENCES public.intervention_anomalie(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    de_statut VARCHAR(50),
    a_statut VARCHAR(50),
    id_user INTEGER REFERENCES public.utilisateur(id_user),
    commentaire TEXT,
    date_action TIMESTAMP DEFAULT now()
);

ALTER TABLE public.intervention_anomalie
    ADD COLUMN IF NOT EXISTS nom_table VARCHAR(255),
    ADD COLUMN IF NOT EXISTS uuid_objet VARCHAR(254),
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

ALTER TABLE public.intervention_anomalie
    ALTER COLUMN statut TYPE VARCHAR(50),
    ALTER COLUMN responsable_actuel TYPE VARCHAR(50),
    ALTER COLUMN etat_exploitant TYPE VARCHAR(50),
    ALTER COLUMN etat_terrain TYPE VARCHAR(50),
    ALTER COLUMN etat_bureau TYPE VARCHAR(50),
    ALTER COLUMN responsable_actuel SET DEFAULT 'terrain',
    ALTER COLUMN created_at SET DEFAULT now(),
    ALTER COLUMN updated_at SET DEFAULT now();

ALTER TABLE public.intervention_log
    ALTER COLUMN action TYPE VARCHAR(50),
    ALTER COLUMN de_statut TYPE VARCHAR(50),
    ALTER COLUMN a_statut TYPE VARCHAR(50),
    ALTER COLUMN date_action SET DEFAULT now();

UPDATE public.intervention_anomalie
SET nom_table = CASE
        WHEN nom_table IS NOT NULL AND btrim(nom_table) <> '' THEN nom_table
        WHEN position('.' in nom_classe) > 0 THEN nom_classe
        WHEN nom_classe LIKE 'ep_%' THEN 'ep.' || nom_classe
        WHEN nom_classe LIKE 'asst_%' THEN 'ass.' || nom_classe
        WHEN nom_classe LIKE 'ass_%' THEN 'ass.' || nom_classe
        ELSE 'public.' || nom_classe
    END,
    created_at = COALESCE(created_at, date_creation AT TIME ZONE current_setting('TimeZone'), now()),
    updated_at = COALESCE(updated_at, date_creation AT TIME ZONE current_setting('TimeZone'), now())
WHERE nom_table IS NULL
   OR btrim(nom_table) = ''
   OR created_at IS NULL
   OR updated_at IS NULL;

DO $$
BEGIN
    IF to_regclass('ep.ep_regard') IS NOT NULL THEN
        UPDATE public.intervention_anomalie i
           SET uuid_objet = r.uuid::text
          FROM ep.ep_regard r
         WHERE i.nom_table = 'ep.ep_regard'
           AND i.id_objet = r.fid
           AND (i.uuid_objet IS NULL OR btrim(i.uuid_objet) = '');
    END IF;
END $$;

ALTER TABLE public.intervention_anomalie
    ALTER COLUMN nom_table SET NOT NULL,
    ALTER COLUMN created_at SET NOT NULL,
    ALTER COLUMN updated_at SET NOT NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'intervention_anomalie_id_objet_nom_classe_key'
          AND conrelid = 'public.intervention_anomalie'::regclass
    ) THEN
        ALTER TABLE public.intervention_anomalie
            DROP CONSTRAINT intervention_anomalie_id_objet_nom_classe_key;
    END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS intervention_anomalie_open_object_uniq
    ON public.intervention_anomalie (nom_table, id_objet)
    WHERE statut NOT IN ('cloture', 'annule');

CREATE INDEX IF NOT EXISTS idx_intervention_objet
    ON public.intervention_anomalie (id_objet, nom_classe);
CREATE INDEX IF NOT EXISTS idx_intervention_nom_table_objet
    ON public.intervention_anomalie (nom_table, id_objet);
CREATE INDEX IF NOT EXISTS idx_intervention_uuid_objet
    ON public.intervention_anomalie (uuid_objet)
    WHERE uuid_objet IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_intervention_responsable
    ON public.intervention_anomalie (responsable_actuel);
CREATE INDEX IF NOT EXISTS idx_intervention_statut
    ON public.intervention_anomalie (statut);
CREATE INDEX IF NOT EXISTS idx_intervention_log_intervention
    ON public.intervention_log (id_intervention);
CREATE INDEX IF NOT EXISTS idx_intervention_log_date
    ON public.intervention_log (date_action DESC);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'intervention_anomalie_statut_check') THEN
        ALTER TABLE public.intervention_anomalie
            ADD CONSTRAINT intervention_anomalie_statut_check
            CHECK (statut IN ('signale', 'exploitant_traite', 'terrain_traite', 'bureau_traite', 'cloture', 'annule', 'retour_terrain'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'intervention_anomalie_responsable_check') THEN
        ALTER TABLE public.intervention_anomalie
            ADD CONSTRAINT intervention_anomalie_responsable_check
            CHECK (responsable_actuel IS NULL OR responsable_actuel IN ('exploitant', 'terrain', 'bureau', 'cloture'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'intervention_anomalie_etat_exploitant_check') THEN
        ALTER TABLE public.intervention_anomalie
            ADD CONSTRAINT intervention_anomalie_etat_exploitant_check
            CHECK (etat_exploitant IS NULL OR etat_exploitant IN ('en_attente', 'traite', 'rejete', 'a_corriger'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'intervention_anomalie_etat_terrain_check') THEN
        ALTER TABLE public.intervention_anomalie
            ADD CONSTRAINT intervention_anomalie_etat_terrain_check
            CHECK (etat_terrain IS NULL OR etat_terrain IN ('en_attente', 'traite', 'rejete', 'a_corriger'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'intervention_anomalie_etat_bureau_check') THEN
        ALTER TABLE public.intervention_anomalie
            ADD CONSTRAINT intervention_anomalie_etat_bureau_check
            CHECK (etat_bureau IS NULL OR etat_bureau IN ('en_attente', 'traite', 'rejete', 'valide', 'a_corriger'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'intervention_log_action_check') THEN
        ALTER TABLE public.intervention_log
            ADD CONSTRAINT intervention_log_action_check
            CHECK (action IN ('signale', 'exploitant_traite', 'terrain_traite', 'bureau_traite', 'cloture', 'annule', 'retour_terrain', 'update'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'intervention_log_de_statut_check') THEN
        ALTER TABLE public.intervention_log
            ADD CONSTRAINT intervention_log_de_statut_check
            CHECK (de_statut IS NULL OR de_statut IN ('signale', 'exploitant_traite', 'terrain_traite', 'bureau_traite', 'cloture', 'annule', 'retour_terrain'));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'intervention_log_a_statut_check') THEN
        ALTER TABLE public.intervention_log
            ADD CONSTRAINT intervention_log_a_statut_check
            CHECK (a_statut IS NULL OR a_statut IN ('signale', 'exploitant_traite', 'terrain_traite', 'bureau_traite', 'cloture', 'annule', 'retour_terrain'));
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.intervention_anomalie_before_write()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.nom_table IS NULL OR btrim(NEW.nom_table) = '' THEN
        NEW.nom_table := CASE
            WHEN position('.' in NEW.nom_classe) > 0 THEN NEW.nom_classe
            WHEN NEW.nom_classe LIKE 'ep_%' THEN 'ep.' || NEW.nom_classe
            WHEN NEW.nom_classe LIKE 'asst_%' THEN 'ass.' || NEW.nom_classe
            WHEN NEW.nom_classe LIKE 'ass_%' THEN 'ass.' || NEW.nom_classe
            ELSE 'public.' || NEW.nom_classe
        END;
    END IF;

    IF TG_OP = 'INSERT' THEN
        NEW.date_creation := COALESCE(NEW.date_creation, now()::timestamp);
        NEW.created_at := COALESCE(NEW.created_at, NEW.date_creation AT TIME ZONE current_setting('TimeZone'), now());
    ELSE
        NEW.created_at := COALESCE(NEW.created_at, OLD.created_at, NEW.date_creation AT TIME ZONE current_setting('TimeZone'), now());
    END IF;

    NEW.updated_at := now();
    NEW.statut := COALESCE(NULLIF(NEW.statut, ''), 'signale');
    NEW.responsable_actuel := COALESCE(NULLIF(NEW.responsable_actuel, ''), 'terrain');
    NEW.etat_exploitant := COALESCE(NULLIF(NEW.etat_exploitant, ''), 'en_attente');
    NEW.etat_terrain := COALESCE(NULLIF(NEW.etat_terrain, ''), 'en_attente');
    NEW.etat_bureau := COALESCE(NULLIF(NEW.etat_bureau, ''), 'en_attente');

    IF NEW.statut = 'signale' THEN
        NEW.etat_terrain := COALESCE(NULLIF(NEW.etat_terrain, ''), 'en_attente');
        NEW.responsable_actuel := 'terrain';
    ELSIF NEW.statut = 'exploitant_traite' THEN
        NEW.etat_exploitant := 'traite';
        NEW.date_exploitant := COALESCE(NEW.date_exploitant, now()::timestamp);
        NEW.responsable_actuel := 'terrain';
    ELSIF NEW.statut = 'terrain_traite' THEN
        NEW.etat_terrain := 'traite';
        NEW.date_terrain := COALESCE(NEW.date_terrain, now()::timestamp);
        NEW.responsable_actuel := 'exploitant';
    ELSIF NEW.statut = 'bureau_traite' THEN
        NEW.etat_bureau := 'traite';
        NEW.date_bureau := COALESCE(NEW.date_bureau, now()::timestamp);
        NEW.responsable_actuel := 'bureau';
    ELSIF NEW.statut = 'cloture' THEN
        NEW.date_cloture := COALESCE(NEW.date_cloture, now()::timestamp);
        NEW.responsable_actuel := 'cloture';
    ELSIF NEW.statut = 'annule' THEN
        NEW.date_cloture := COALESCE(NEW.date_cloture, now()::timestamp);
        NEW.responsable_actuel := 'cloture';
    ELSIF NEW.statut = 'retour_terrain' THEN
        NEW.retour_terrain := true;
        NEW.etat_terrain := 'en_attente';
        NEW.responsable_actuel := 'terrain';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.intervention_anomalie_after_write_log()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_action varchar(50);
    v_user integer;
    v_comment text;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_action := NEW.statut;
        v_user := COALESCE(NEW.id_user_exploitant, NEW.id_user_terrain, NEW.id_user_bureau);
        v_comment := COALESCE(NEW.commentaire_exploitant, NEW.commentaire_terrain, NEW.commentaire_bureau, '');

        INSERT INTO public.intervention_log (
            id_intervention, action, de_statut, a_statut, id_user, commentaire, date_action
        ) VALUES (
            NEW.id, v_action, NULL, NEW.statut, v_user, v_comment, COALESCE(NEW.date_creation, now()::timestamp)
        );
        RETURN NEW;
    END IF;

    IF OLD.statut IS DISTINCT FROM NEW.statut
       OR OLD.responsable_actuel IS DISTINCT FROM NEW.responsable_actuel
       OR OLD.etat_exploitant IS DISTINCT FROM NEW.etat_exploitant
       OR OLD.etat_terrain IS DISTINCT FROM NEW.etat_terrain
       OR OLD.etat_bureau IS DISTINCT FROM NEW.etat_bureau
       OR OLD.commentaire_exploitant IS DISTINCT FROM NEW.commentaire_exploitant
       OR OLD.commentaire_terrain IS DISTINCT FROM NEW.commentaire_terrain
       OR OLD.commentaire_bureau IS DISTINCT FROM NEW.commentaire_bureau THEN
        v_action := CASE
            WHEN OLD.statut IS DISTINCT FROM NEW.statut THEN NEW.statut
            ELSE 'update'
        END;
        v_user := COALESCE(
            NEW.id_user_bureau,
            NEW.id_user_terrain,
            NEW.id_user_exploitant,
            OLD.id_user_bureau,
            OLD.id_user_terrain,
            OLD.id_user_exploitant
        );
        v_comment := COALESCE(
            NULLIF(NEW.commentaire_bureau, ''),
            NULLIF(NEW.commentaire_terrain, ''),
            NULLIF(NEW.commentaire_exploitant, ''),
            ''
        );

        INSERT INTO public.intervention_log (
            id_intervention, action, de_statut, a_statut, id_user, commentaire, date_action
        ) VALUES (
            NEW.id, v_action, OLD.statut, NEW.statut, v_user, v_comment, now()::timestamp
        );
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.intervention_log_prevent_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF current_setting('app.allow_intervention_log_mutation', true) = 'on' THEN
        RETURN COALESCE(NEW, OLD);
    END IF;

    RAISE EXCEPTION 'intervention_log is append-only. Set app.allow_intervention_log_mutation=on for controlled maintenance.';
END;
$$;

DROP TRIGGER IF EXISTS trg_intervention_anomalie_before_write
    ON public.intervention_anomalie;
CREATE TRIGGER trg_intervention_anomalie_before_write
BEFORE INSERT OR UPDATE
ON public.intervention_anomalie
FOR EACH ROW
EXECUTE FUNCTION public.intervention_anomalie_before_write();

DROP TRIGGER IF EXISTS trg_intervention_anomalie_after_write_log
    ON public.intervention_anomalie;
CREATE TRIGGER trg_intervention_anomalie_after_write_log
AFTER INSERT OR UPDATE
ON public.intervention_anomalie
FOR EACH ROW
EXECUTE FUNCTION public.intervention_anomalie_after_write_log();

INSERT INTO public.intervention_log (
    id_intervention, action, de_statut, a_statut, id_user, commentaire, date_action
)
SELECT
    i.id,
    'signale',
    NULL,
    'signale',
    COALESCE(i.id_user_exploitant, i.id_user_terrain, i.id_user_bureau),
    COALESCE(i.commentaire_exploitant, i.commentaire_terrain, i.commentaire_bureau, ''),
    COALESCE(i.date_creation, now()::timestamp)
FROM public.intervention_anomalie i
WHERE NOT EXISTS (
    SELECT 1
    FROM public.intervention_log l
    WHERE l.id_intervention = i.id
      AND l.action = 'signale'
      AND l.de_statut IS NULL
      AND l.a_statut = 'signale'
);

INSERT INTO public.intervention_log (
    id_intervention, action, de_statut, a_statut, id_user, commentaire, date_action
)
SELECT
    i.id,
    i.statut,
    'signale',
    i.statut,
    COALESCE(i.id_user_bureau, i.id_user_terrain, i.id_user_exploitant),
    COALESCE(i.commentaire_bureau, i.commentaire_terrain, i.commentaire_exploitant, ''),
    COALESCE(i.date_bureau, i.date_terrain, i.date_exploitant, i.date_creation, now()::timestamp)
FROM public.intervention_anomalie i
WHERE i.statut <> 'signale'
  AND NOT EXISTS (
      SELECT 1
      FROM public.intervention_log l
      WHERE l.id_intervention = i.id
        AND l.a_statut = i.statut
  );

UPDATE public.intervention_anomalie
SET responsable_actuel = 'terrain',
    etat_terrain = COALESCE(NULLIF(etat_terrain, ''), 'en_attente')
WHERE statut = 'signale';

UPDATE public.intervention_anomalie
SET responsable_actuel = 'exploitant'
WHERE statut = 'terrain_traite';

DROP TRIGGER IF EXISTS trg_intervention_log_prevent_update
    ON public.intervention_log;
CREATE TRIGGER trg_intervention_log_prevent_update
BEFORE UPDATE OR DELETE
ON public.intervention_log
FOR EACH ROW
EXECUTE FUNCTION public.intervention_log_prevent_mutation();

COMMIT;
