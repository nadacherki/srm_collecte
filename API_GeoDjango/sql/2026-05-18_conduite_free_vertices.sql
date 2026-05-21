-- 2026-05-18 : Conduites EP/ASS en mode hybride (regards + points libres).
--
-- Objectif : autoriser des sommets intermediaires libres dans le trace d'une
-- conduite, et autoriser une conduite a se terminer sur un point libre
-- (segment "ouvert" : fid_regard_b NULL).
--
-- Changements sur ep.statistique_conduite_segment et
-- asst.statistique_conduite_segment (schema runtime ASS = "asst") :
--   1. fid_regard_b devient NULLABLE (segment ouvert sur point libre).
--   2. La contrainte anti-boucle tolere fid_regard_b NULL.
--   3. La contrainte d'unicite par paire de regards (qui s'appuyait sur les
--      colonnes generees fid_regard_min/fid_regard_max, incompatibles avec
--      un endpoint NULL) est remplacee par une unicite (id_conduite, ordre).
--      Le dedoublonnage des paires regard-regard reste assure cote code
--      (_build_unique_conduite_segments).
--
-- La colonne geom (LineStringZ, 26191) accepte deja N sommets : aucun
-- changement de type n'est necessaire pour stocker les coudes libres.
--
-- Idempotent : reexecutable sans erreur.

BEGIN;

-- ---------------------------------------------------------------------------
-- EP
-- ---------------------------------------------------------------------------
ALTER TABLE ep.statistique_conduite_segment
    ALTER COLUMN fid_regard_b DROP NOT NULL;

ALTER TABLE ep.statistique_conduite_segment
    DROP CONSTRAINT IF EXISTS statistique_conduite_segment_no_loop_chk;
ALTER TABLE ep.statistique_conduite_segment
    ADD CONSTRAINT statistique_conduite_segment_no_loop_chk
    CHECK (fid_regard_b IS NULL OR fid_regard_a <> fid_regard_b);

ALTER TABLE ep.statistique_conduite_segment
    ADD COLUMN IF NOT EXISTS ordre INTEGER NOT NULL DEFAULT 0;

ALTER TABLE ep.statistique_conduite_segment
    DROP CONSTRAINT IF EXISTS statistique_conduite_segment_unique_pair_key;
ALTER TABLE ep.statistique_conduite_segment
    DROP CONSTRAINT IF EXISTS statistique_conduite_segment_unique_ordre_key;
ALTER TABLE ep.statistique_conduite_segment
    ADD CONSTRAINT statistique_conduite_segment_unique_ordre_key
    UNIQUE (id_statistique_conduite, ordre);

-- ---------------------------------------------------------------------------
-- ASS
-- ---------------------------------------------------------------------------
ALTER TABLE asst.statistique_conduite_segment
    ALTER COLUMN fid_regard_b DROP NOT NULL;

ALTER TABLE asst.statistique_conduite_segment
    DROP CONSTRAINT IF EXISTS statistique_conduite_segment_no_loop_chk;
ALTER TABLE asst.statistique_conduite_segment
    ADD CONSTRAINT statistique_conduite_segment_no_loop_chk
    CHECK (fid_regard_b IS NULL OR fid_regard_a <> fid_regard_b);

ALTER TABLE asst.statistique_conduite_segment
    ADD COLUMN IF NOT EXISTS ordre INTEGER NOT NULL DEFAULT 0;

ALTER TABLE asst.statistique_conduite_segment
    DROP CONSTRAINT IF EXISTS statistique_conduite_segment_unique_pair_key;
ALTER TABLE asst.statistique_conduite_segment
    DROP CONSTRAINT IF EXISTS statistique_conduite_segment_unique_ordre_key;
ALTER TABLE asst.statistique_conduite_segment
    ADD CONSTRAINT statistique_conduite_segment_unique_ordre_key
    UNIQUE (id_statistique_conduite, ordre);

COMMENT ON COLUMN ep.statistique_conduite_segment.fid_regard_b IS
'Regard d''arrivee. NULL si le segment se termine sur un point libre (conduite ouverte).';
COMMENT ON COLUMN asst.statistique_conduite_segment.fid_regard_b IS
'Regard d''arrivee. NULL si le segment se termine sur un point libre (conduite ouverte).';
COMMENT ON COLUMN ep.statistique_conduite_segment.ordre IS
'Ordre du segment dans la conduite du jour (0-based). Garantit l''unicite.';
COMMENT ON COLUMN asst.statistique_conduite_segment.ordre IS
'Ordre du segment dans la conduite du jour (0-based). Garantit l''unicite.';

COMMIT;
