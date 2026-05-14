-- Obsolete metrics script.
--
-- The original version created collection metrics with id_projet/id_mission.
-- Those historical context columns were removed during public schema
-- homogenisation on 2026-05-04. The active databases now use regenerated
-- metrics views without project/mission context.
--
-- This file is intentionally kept as a no-op tombstone so dated references do
-- not recreate deprecated columns or fail on databases where they no longer
-- exist.

BEGIN;
COMMIT;
