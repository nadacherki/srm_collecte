-- Obsolete dashboard script.
--
-- The project/mission dashboard views were removed during the public schema
-- homogenisation. Keep this file as a no-op tombstone so old references to the
-- dated script do not recreate deprecated views.

BEGIN;

DROP VIEW IF EXISTS public.vw_metrics_projet_resume CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_mois CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_semaine CASCADE;
DROP VIEW IF EXISTS public.vw_metrics_projet_jour CASCADE;
DROP VIEW IF EXISTS public.vw_srm_mission_fact CASCADE;

COMMIT;
