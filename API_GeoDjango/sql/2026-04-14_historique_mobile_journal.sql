BEGIN;

CREATE TABLE IF NOT EXISTS public.historique_mobile (
    id_historique_mobile BIGSERIAL PRIMARY KEY,
    sync_uuid VARCHAR(64) NOT NULL UNIQUE,
    type_entree VARCHAR(20) NOT NULL CHECK (type_entree IN ('ATTRIBUT', 'EVENEMENT')),
    source_table_locale VARCHAR(64) NOT NULL,
    source_id_local BIGINT,
    id_objet INTEGER,
    cle_ligne VARCHAR(254),
    uuid_objet VARCHAR(254),
    nom_schema VARCHAR(30),
    nom_table VARCHAR(100),
    nom_classe VARCHAR(100),
    nom_attribut VARCHAR(100),
    ancienne_valeur TEXT,
    nouvelle_valeur TEXT,
    type_action VARCHAR(50),
    type_evenement VARCHAR(100),
    payload_json JSONB,
    date_action TIMESTAMPTZ NOT NULL,
    date_reception TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    id_agent INTEGER
);

CREATE INDEX IF NOT EXISTS historique_mobile_date_action_idx
    ON public.historique_mobile (date_action DESC);

CREATE INDEX IF NOT EXISTS historique_mobile_type_entree_idx
    ON public.historique_mobile (type_entree);

CREATE INDEX IF NOT EXISTS historique_mobile_schema_table_idx
    ON public.historique_mobile (nom_schema, nom_table);

CREATE INDEX IF NOT EXISTS historique_mobile_uuid_objet_idx
    ON public.historique_mobile (uuid_objet);

CREATE INDEX IF NOT EXISTS historique_mobile_source_idx
    ON public.historique_mobile (source_table_locale, source_id_local);

COMMIT;
