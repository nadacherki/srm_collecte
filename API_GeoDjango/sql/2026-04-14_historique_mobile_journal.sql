-- Obsolete mobile history script.
--
-- `public.historique_mobile` was merged into the unique active history table
-- `public.historique_action` during the 2026-05-04 homogenisation.
-- Keep this dated script as a tombstone so an old deployment sequence cannot
-- recreate the deprecated table after it has been dropped.

BEGIN;

DO $$
DECLARE
    has_rows boolean;
BEGIN
    IF to_regclass('public.historique_mobile') IS NOT NULL
       AND to_regclass('public.historique_mobile_backup_before_unified_20260504') IS NULL THEN
        EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.historique_mobile)' INTO has_rows;
        IF has_rows THEN
            EXECUTE 'CREATE TABLE public.historique_mobile_backup_before_unified_20260504 AS TABLE public.historique_mobile';
        END IF;
    END IF;
END $$;

DROP TABLE IF EXISTS public.historique_mobile;

COMMIT;
