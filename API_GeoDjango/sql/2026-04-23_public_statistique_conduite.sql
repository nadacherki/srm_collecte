-- Obsolete since 2026-05-04.
-- Conduite statistics are now stored per metier:
--   ep.statistique_conduite / ep.statistique_conduite_segment
--   ass.statistique_conduite / ass.statistique_conduite_segment
--
-- Keep this tombstone so older deployment lists do not recreate the
-- legacy public tables.

BEGIN;

DROP TABLE IF EXISTS public.statistique_conduite_segment CASCADE;
DROP TABLE IF EXISTS public.statistique_conduite CASCADE;
DROP TABLE IF EXISTS public.conduite_statistique_ep_segment CASCADE;
DROP TABLE IF EXISTS public.conduite_statistique_ep CASCADE;
DROP TABLE IF EXISTS public.conduite_statique_asst_segment CASCADE;
DROP TABLE IF EXISTS public.conduite_statique_asst CASCADE;

COMMIT;
