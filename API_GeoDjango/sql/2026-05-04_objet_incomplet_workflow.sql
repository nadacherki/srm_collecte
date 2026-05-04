BEGIN;

ALTER TABLE public.objet_incomplet
    ALTER COLUMN statut SET DEFAULT 'A_COMPLETER';

UPDATE public.objet_incomplet
SET statut = 'A_COMPLETER'
WHERE statut IS NULL OR btrim(statut) = '';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'objet_incomplet_statut_check'
          AND conrelid = 'public.objet_incomplet'::regclass
    ) THEN
        ALTER TABLE public.objet_incomplet
            ADD CONSTRAINT objet_incomplet_statut_check
            CHECK (statut IN ('A_COMPLETER', 'COMPLETE'));
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'objet_incomplet_nom_table_format_check'
          AND conrelid = 'public.objet_incomplet'::regclass
    ) THEN
        ALTER TABLE public.objet_incomplet
            ADD CONSTRAINT objet_incomplet_nom_table_format_check
            CHECK (
                nom_table ~ '^[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*$'
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'objet_incomplet_id_agent_incomplet_fkey'
          AND conrelid = 'public.objet_incomplet'::regclass
    ) THEN
        ALTER TABLE public.objet_incomplet
            ADD CONSTRAINT objet_incomplet_id_agent_incomplet_fkey
            FOREIGN KEY (id_agent_incomplet)
            REFERENCES public.utilisateur(id_user)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'objet_incomplet_id_agent_completement_fkey'
          AND conrelid = 'public.objet_incomplet'::regclass
    ) THEN
        ALTER TABLE public.objet_incomplet
            ADD CONSTRAINT objet_incomplet_id_agent_completement_fkey
            FOREIGN KEY (id_agent_completement)
            REFERENCES public.utilisateur(id_user)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS objet_incomplet_nom_table_id_objet_idx
    ON public.objet_incomplet (nom_table, id_objet);

CREATE INDEX IF NOT EXISTS objet_incomplet_statut_idx
    ON public.objet_incomplet (statut);

CREATE INDEX IF NOT EXISTS objet_incomplet_date_signalement_idx
    ON public.objet_incomplet (date_signalement DESC);

CREATE INDEX IF NOT EXISTS objet_incomplet_date_completion_idx
    ON public.objet_incomplet (date_completion DESC);

CREATE UNIQUE INDEX IF NOT EXISTS objet_incomplet_open_unique_idx
    ON public.objet_incomplet (nom_table, id_objet)
    WHERE statut = 'A_COMPLETER';

DROP TRIGGER IF EXISTS trg_audit_objet_incomplet ON public.objet_incomplet;
CREATE TRIGGER trg_audit_objet_incomplet
AFTER INSERT OR UPDATE OR DELETE ON public.objet_incomplet
FOR EACH ROW
EXECUTE FUNCTION public.capture_historique_attribut('id_incomplet');

COMMIT;
