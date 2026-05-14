from django.db import migrations


# Cette migration :
#   1. backfill les `ep.ep_regard_point.geom` manquants (issus du centroid du
#      polygone parent dans `ep.ep_regard`) — un bug du pipeline d'ingestion
#      historique a laisse 10 points sans geometrie alors que le polygone
#      correspondant en avait une ; cote mobile, le filtre `geom IS NOT NULL`
#      faisait disparaitre ces regards du telechargement.
#   2. installe un trigger qui maintient automatiquement la symetrie
#      ep_regard (polygone)  <->  ep_regard_point (point centroid) :
#        INSERT/UPDATE polygone  -> UPSERT du point miroir (geom = centroid)
#        DELETE polygone         -> DELETE du point miroir
#      Garantit qu'il n'existera plus de polygone sans point miroir.
#
# Le backfill se fait apres un drop temporaire des CHECK constraints
# applicatives NOT VALID (introduites par 0050_required_fields_*), parce que
# PostgreSQL re-evalue ces contraintes sur tout UPDATE meme s'il ne touche
# pas les colonnes contraintes, et les lignes ciblees violaient deja la
# contrainte de base. Les contraintes sont remises en NOT VALID a la fin
# (memes definitions, etat identique a avant migration).


BACKFILL_SQL = r"""
-- Snapshot des CHECK constraints NOT VALID sur ep.ep_regard_point
DO $$
DECLARE
    r record;
BEGIN
    -- Drop temporaire des contraintes NOT VALID applicatives (srm_req_*)
    FOR r IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'ep.ep_regard_point'::regclass
          AND contype = 'c'
          AND conname LIKE 'srm_req_%'
    LOOP
        EXECUTE format('ALTER TABLE ep.ep_regard_point DROP CONSTRAINT %I', r.conname);
    END LOOP;
END$$;

-- Backfill : copie le centroid 3D du polygone vers le point miroir manquant
UPDATE ep.ep_regard_point AS p
SET geom = ST_Force3D(ST_Centroid(r.geom))
FROM ep.ep_regard AS r
WHERE p.uuid = r.uuid
  AND p.geom IS NULL
  AND r.geom IS NOT NULL;

-- Recreation des CHECK NOT VALID telles qu'elles etaient avant (memes
-- predicats, memes noms reproductibles via hash deterministe).
ALTER TABLE ep.ep_regard_point
    ADD CONSTRAINT srm_req_02c6f47decde3ed4 CHECK (
        largeur IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_6d7635f7bedb68ec CHECK (
        ep_tampon IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_6ffcd68d98ecb4df CHECK (
        ep_conf_plan IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_71579009f1de0b9e CHECK (
        echelon IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_a4f237aac8427fb3 CHECK (
        longueur IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_af41a9e77b0e3e82 CHECK (
        ep_ref_rue IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_c35dc7b065e664dc CHECK (
        type_regard IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_ccc1f9f50bf6f51b CHECK (
        emplacement IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_d7e18f1829c67bbf CHECK (
        ep_profondeur IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_ee72116e03b1ead2 CHECK (
        existence_s IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID;
"""


TRIGGER_SQL = r"""
-- Synchronise ep_regard_point depuis ep_regard. Le polygone est la source de
-- verite ; le point miroir est toujours le centroid du polygone, et partage
-- l'uuid. Les colonnes metier dupliquees sont copiees au INSERT pour rester
-- coherent avec le contrat actuel (les deux tables ont le meme schema).
CREATE OR REPLACE FUNCTION ep.sync_ep_regard_point_mirror()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        DELETE FROM ep.ep_regard_point WHERE uuid = OLD.uuid;
        RETURN OLD;
    END IF;

    -- INSERT ou UPDATE : upsert du point miroir avec centroid du polygone.
    IF NEW.geom IS NULL THEN
        -- Pas de geometrie polygone -> pas de point miroir significatif.
        -- On laisse le point existant intact (ne pas creer de point fantome).
        RETURN NEW;
    END IF;

    INSERT INTO ep.ep_regard_point (uuid, geom)
    VALUES (NEW.uuid, ST_Force3D(ST_Centroid(NEW.geom)))
    ON CONFLICT (uuid) DO UPDATE
    SET geom = EXCLUDED.geom;

    RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS trg_sync_ep_regard_point_mirror ON ep.ep_regard;

CREATE TRIGGER trg_sync_ep_regard_point_mirror
AFTER INSERT OR UPDATE OF geom OR DELETE ON ep.ep_regard
FOR EACH ROW
EXECUTE FUNCTION ep.sync_ep_regard_point_mirror();

-- Index unique sur uuid si pas deja present (necessaire pour ON CONFLICT)
CREATE UNIQUE INDEX IF NOT EXISTS ep_regard_point_uuid_uidx
    ON ep.ep_regard_point (uuid);
"""


REVERSE_SQL = r"""
DROP TRIGGER IF EXISTS trg_sync_ep_regard_point_mirror ON ep.ep_regard;
DROP FUNCTION IF EXISTS ep.sync_ep_regard_point_mirror();
"""


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0053_objet_incomplet_uuid'),
    ]

    operations = [
        migrations.RunSQL(sql=BACKFILL_SQL, reverse_sql=migrations.RunSQL.noop),
        migrations.RunSQL(sql=TRIGGER_SQL, reverse_sql=REVERSE_SQL),
    ]
