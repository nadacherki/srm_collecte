BEGIN;

DO $$
BEGIN
    IF to_regclass('public.intervention_anomalie') IS NULL THEN
        RAISE EXCEPTION 'Table public.intervention_anomalie introuvable';
    END IF;

    IF to_regclass('public.intervention_log') IS NULL THEN
        RAISE EXCEPTION 'Table public.intervention_log introuvable';
    END IF;

    IF to_regclass('public.intervention_anomalie_backup_before_bureau_workflow_20260508') IS NULL THEN
        EXECUTE 'CREATE TABLE public.intervention_anomalie_backup_before_bureau_workflow_20260508 AS TABLE public.intervention_anomalie';
    END IF;

    IF to_regclass('public.intervention_log_backup_before_bureau_workflow_20260508') IS NULL THEN
        EXECUTE 'CREATE TABLE public.intervention_log_backup_before_bureau_workflow_20260508 AS TABLE public.intervention_log';
    END IF;
END $$;

ALTER TABLE public.intervention_anomalie
    ALTER COLUMN responsable_actuel SET DEFAULT 'exploitant';

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
        NEW.created_at := COALESCE(
            NEW.created_at,
            NEW.date_creation AT TIME ZONE current_setting('TimeZone'),
            now()
        );
    ELSE
        NEW.created_at := COALESCE(
            NEW.created_at,
            OLD.created_at,
            NEW.date_creation AT TIME ZONE current_setting('TimeZone'),
            now()
        );
    END IF;

    NEW.updated_at := now();
    NEW.retour_terrain := COALESCE(NEW.retour_terrain, false);
    NEW.statut := COALESCE(NULLIF(NEW.statut, ''), 'signale');
    NEW.responsable_actuel := COALESCE(NULLIF(NEW.responsable_actuel, ''), 'exploitant');
    NEW.etat_exploitant := COALESCE(NULLIF(NEW.etat_exploitant, ''), 'en_attente');
    NEW.etat_terrain := COALESCE(NULLIF(NEW.etat_terrain, ''), 'en_attente');
    NEW.etat_bureau := COALESCE(NULLIF(NEW.etat_bureau, ''), 'en_attente');

    IF NEW.statut = 'signale' THEN
        NEW.responsable_actuel := 'exploitant';
    ELSIF NEW.statut = 'exploitant_traite' THEN
        NEW.etat_exploitant := 'traite';
        NEW.date_exploitant := COALESCE(NEW.date_exploitant, now()::timestamp);
        NEW.responsable_actuel := 'terrain';
    ELSIF NEW.statut = 'terrain_traite' THEN
        NEW.etat_terrain := 'traite';
        NEW.date_terrain := COALESCE(NEW.date_terrain, now()::timestamp);
        NEW.responsable_actuel := 'bureau';
    ELSIF NEW.statut = 'bureau_traite' THEN
        NEW.etat_bureau := 'traite';
        NEW.date_bureau := COALESCE(NEW.date_bureau, now()::timestamp);
        NEW.responsable_actuel := 'bureau';
    ELSIF NEW.statut = 'cloture' THEN
        NEW.etat_bureau := 'traite';
        NEW.date_bureau := COALESCE(NEW.date_bureau, now()::timestamp);
        NEW.date_cloture := COALESCE(NEW.date_cloture, now()::timestamp);
        NEW.responsable_actuel := 'cloture';
    ELSIF NEW.statut = 'annule' THEN
        NEW.etat_bureau := 'traite';
        NEW.date_bureau := COALESCE(NEW.date_bureau, now()::timestamp);
        NEW.date_cloture := COALESCE(NEW.date_cloture, now()::timestamp);
        NEW.responsable_actuel := 'cloture';
    ELSIF NEW.statut = 'retour_terrain' THEN
        NEW.retour_terrain := true;
        NEW.etat_bureau := 'rejete';
        NEW.date_bureau := COALESCE(NEW.date_bureau, now()::timestamp);
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
        v_user := COALESCE(
            NEW.id_user_bureau,
            NEW.id_user_terrain,
            NEW.id_user_exploitant
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
            NEW.id, v_action, NULL, NEW.statut, v_user, v_comment, COALESCE(NEW.date_creation, now()::timestamp)
        );
        RETURN NEW;
    END IF;

    IF OLD.statut IS DISTINCT FROM NEW.statut
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

DROP TRIGGER IF EXISTS trg_intervention_log_prevent_update
    ON public.intervention_log;
CREATE TRIGGER trg_intervention_log_prevent_update
BEFORE UPDATE OR DELETE
ON public.intervention_log
FOR EACH ROW
EXECUTE FUNCTION public.intervention_log_prevent_mutation();

UPDATE public.intervention_anomalie
   SET responsable_actuel = CASE statut
           WHEN 'signale' THEN 'exploitant'
           WHEN 'exploitant_traite' THEN 'terrain'
           WHEN 'terrain_traite' THEN 'bureau'
           WHEN 'bureau_traite' THEN 'bureau'
           WHEN 'retour_terrain' THEN 'terrain'
           WHEN 'cloture' THEN 'cloture'
           WHEN 'annule' THEN 'cloture'
           ELSE responsable_actuel
       END
 WHERE responsable_actuel IS DISTINCT FROM CASE statut
           WHEN 'signale' THEN 'exploitant'
           WHEN 'exploitant_traite' THEN 'terrain'
           WHEN 'terrain_traite' THEN 'bureau'
           WHEN 'bureau_traite' THEN 'bureau'
           WHEN 'retour_terrain' THEN 'terrain'
           WHEN 'cloture' THEN 'cloture'
           WHEN 'annule' THEN 'cloture'
           ELSE responsable_actuel
       END;

DO $$
DECLARE
    v_mismatch_count integer;
BEGIN
    SELECT count(*)
      INTO v_mismatch_count
      FROM public.intervention_anomalie
     WHERE responsable_actuel IS DISTINCT FROM CASE statut
               WHEN 'signale' THEN 'exploitant'
               WHEN 'exploitant_traite' THEN 'terrain'
               WHEN 'terrain_traite' THEN 'bureau'
               WHEN 'bureau_traite' THEN 'bureau'
               WHEN 'retour_terrain' THEN 'terrain'
               WHEN 'cloture' THEN 'cloture'
               WHEN 'annule' THEN 'cloture'
               ELSE responsable_actuel
           END;

    IF v_mismatch_count <> 0 THEN
        RAISE EXCEPTION 'Workflow intervention_anomalie non aligne: % lignes en ecart', v_mismatch_count;
    END IF;
END $$;

COMMIT;
