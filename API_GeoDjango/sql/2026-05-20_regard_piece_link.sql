-- 2026-05-20 : Table d'association "piece de regard".
--
-- Permet de rattacher un objet metier (vanne, vidange, ventouse, cone de
-- reduction, compteur reseau, reducteur de pression, obturateur, pompe,
-- conduite terrain) au regard parent dont il est une "piece".
--
-- Cle d'association : UUIDs cote regard ET cote objet, pour rester
-- compatible avec le flot offline-first (l'agent cree d'abord les
-- objets/regards localement puis le serveur attribue les fid plus tard).
-- Les FK strictes vers les tables sources ne sont volontairement PAS
-- posees ici : l'ordre de synchronisation entre l'objet, le regard et le
-- lien n'est pas garanti. Le backend valide la presence des UUIDs au
-- moment de la creation et garde le lien sinon en file d'attente cote
-- client.
--
-- Discriminateur : `table_objet` = tableName client (cf. srm_config.dart),
-- l'un de {vanne, vanne_de_vidange, ventouse, cone_de_reduction,
-- compteur_reseau, reducteur_de_pression, obturateur, pompe,
-- conduite_terrain}. Le serveur traduit vers le schema/table physique via
-- MOBILE_SRM_TABLE_ENDPOINTS.
--
-- Idempotent : reexecutable sans erreur.

BEGIN;

CREATE SCHEMA IF NOT EXISTS ep;

CREATE TABLE IF NOT EXISTS ep.regard_piece_link (
    id_regard_piece_link BIGSERIAL PRIMARY KEY,
    uuid UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    uuid_regard UUID NOT NULL,
    fid_regard INTEGER,
    table_objet VARCHAR(64) NOT NULL,
    uuid_objet UUID NOT NULL,
    fid_objet INTEGER,
    id_agent INTEGER
        REFERENCES public.utilisateur(id_user)
        ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT regard_piece_link_table_objet_chk
        CHECK (table_objet IN (
            'vanne',
            'vanne_de_vidange',
            'ventouse',
            'cone_de_reduction',
            'compteur_reseau',
            'reducteur_de_pression',
            'obturateur',
            'pompe',
            'conduite_terrain'
        )),
    CONSTRAINT regard_piece_link_unique_object_key
        UNIQUE (table_objet, uuid_objet)
);

CREATE INDEX IF NOT EXISTS regard_piece_link_uuid_regard_idx
    ON ep.regard_piece_link (uuid_regard);
CREATE INDEX IF NOT EXISTS regard_piece_link_table_objet_idx
    ON ep.regard_piece_link (table_objet);
CREATE INDEX IF NOT EXISTS regard_piece_link_fid_regard_idx
    ON ep.regard_piece_link (fid_regard);
CREATE INDEX IF NOT EXISTS regard_piece_link_agent_idx
    ON ep.regard_piece_link (id_agent, created_at DESC);

COMMENT ON TABLE ep.regard_piece_link IS
'Association "piece de regard" : rattache un objet (vanne, pompe, conduite terrain, ...) au regard parent. UUIDs pour offline-first.';
COMMENT ON COLUMN ep.regard_piece_link.table_objet IS
'Discriminateur : tableName client (cf. srm_config.dart).';
COMMENT ON COLUMN ep.regard_piece_link.uuid_regard IS
'UUID du regard parent (ep_regard_point.uuid).';
COMMENT ON COLUMN ep.regard_piece_link.uuid_objet IS
'UUID de l''objet metier (table_objet.uuid).';
COMMENT ON COLUMN ep.regard_piece_link.fid_regard IS
'FID serveur du regard parent (rempli au moment du lien si dispo, sinon NULL et reconciliable plus tard).';
COMMENT ON COLUMN ep.regard_piece_link.fid_objet IS
'FID serveur de l''objet metier (rempli au moment du lien si dispo, sinon NULL).';

COMMIT;
