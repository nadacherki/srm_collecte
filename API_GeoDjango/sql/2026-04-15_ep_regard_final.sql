BEGIN;

CREATE SCHEMA IF NOT EXISTS ep;

CREATE TABLE IF NOT EXISTS public.srm_field_option (
    id_option BIGSERIAL PRIMARY KEY,
    table_schema VARCHAR(100) NOT NULL,
    table_name VARCHAR(100) NOT NULL,
    field_name VARCHAR(100) NOT NULL,
    code_value VARCHAR(400) NOT NULL,
    label_value VARCHAR(400) NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    actif BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT srm_field_option_uq UNIQUE (table_schema, table_name, field_name, code_value)
);

CREATE INDEX IF NOT EXISTS srm_field_option_lookup_idx
    ON public.srm_field_option (table_schema, table_name, field_name, display_order);

DROP TABLE IF EXISTS ep.regard_ep CASCADE;

CREATE TABLE ep.regard_ep (
    fid BIGSERIAL PRIMARY KEY,
    geom geometry(PolygonZ, 26191),
    ep_agent VARCHAR(400) DEFAULT 'ETAFAT',
    ep_sect_com VARCHAR(400),
    ep_statut VARCHAR(400),
    ep_adresse VARCHAR(400),
    ep_agent_crea VARCHAR(400) DEFAULT 'ETAFAT',
    sec_com VARCHAR(400),
    sect_hydr VARCHAR(400),
    zone VARCHAR(400),
    uuid UUID,
    z_radier VARCHAR(400),
    z_surf VARCHAR(400),
    ep_date_insertion DATE,
    ep_coor_x DOUBLE PRECISION,
    ep_coor_y DOUBLE PRECISION,
    ep_coor_z DOUBLE PRECISION,
    id_commune INTEGER,
    id_province INTEGER,
    id_user_creat INTEGER,
    id_user_modif INTEGER,
    date_creation TIMESTAMPTZ,
    date_modif TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT FALSE,
    is_validated BOOLEAN DEFAULT FALSE,
    id_user_valid INTEGER,
    date_validation TIMESTAMP,
    emplacement VARCHAR(400),
    ep_ref_rue VARCHAR(400),
    ep_section VARCHAR(400),
    ep_tampon VARCHAR(400),
    ep_conf_plan VARCHAR(400),
    ep_observation VARCHAR(400),
    ep_anomalie BOOLEAN DEFAULT FALSE,
    mode_localisation VARCHAR(400) DEFAULT 'Levé topographique',
    echelon VARCHAR(400),
    anomalie_tamp VARCHAR(400),
    anomalie_regard VARCHAR(400),
    "GENRATRICE_SUP" DOUBLE PRECISION,
    ep_profondeur DOUBLE PRECISION,
    CONSTRAINT regard_ep_ep_statut_chk CHECK (
        ep_statut IS NULL OR ep_statut IN (
            'EP_POSE',
            'EP_REHABILITE',
            'EP_EXISTANT',
            'EP_PROJETE',
            'EP_A REHABI',
            'EP_EN COURSS',
            'EP_A RESILISE'
        )
    ),
    CONSTRAINT regard_ep_emplacement_chk CHECK (
        emplacement IS NULL OR emplacement IN (
            'S-TROTTOIR',
            'S-CHAUSSEE',
            'S-TROTOIR C-CHAISSI',
            'TN',
            'PISTE',
            'TERRE_AGRICOLE'
        )
    ),
    CONSTRAINT regard_ep_ep_tampon_chk CHECK (
        ep_tampon IS NULL OR ep_tampon IN (
            'FD400',
            'FD250',
            'Béton'
        )
    ),
    CONSTRAINT regard_ep_ep_conf_plan_chk CHECK (
        ep_conf_plan IS NULL OR ep_conf_plan IN (
            'Conforme aux plan',
            'Objet découvrt sur terrain',
            'Objet non trouvé sur le terrain'
        )
    ),
    CONSTRAINT regard_ep_mode_localisation_chk CHECK (
        mode_localisation IS NULL OR mode_localisation IN (
            'Levé topographique',
            'Triangulé',
            'Schématique',
            'Indéterminé'
        )
    ),
    CONSTRAINT regard_ep_echelon_chk CHECK (
        echelon IS NULL OR echelon IN (
            'O',
            'N'
        )
    ),
    CONSTRAINT regard_ep_anomalie_tamp_chk CHECK (
        anomalie_tamp IS NULL OR anomalie_tamp IN (
            'Tampons en mauvais état',
            'Tampons Manquant',
            'Tampons Scellés'
        )
    ),
    CONSTRAINT regard_ep_anomalie_regard_chk CHECK (
        anomalie_regard IS NULL OR anomalie_regard IN (
            'A mettre à la cote',
            'Inaccessible',
            'Ouvrage dégradés',
            'Regards Enterrés',
            'Regards Noyés',
            'Regards à curer',
            'Sectionnement enterré',
            'Autre'
        )
    )
);

COMMENT ON TABLE ep.regard_ep IS 'Table finale SRM client pour les regards EP.';
COMMENT ON COLUMN ep.regard_ep.fid IS 'Identifiant lisible serveur auto-incremente.';
COMMENT ON COLUMN ep.regard_ep.uuid IS 'Identifiant metier unique mobile/serveur.';
COMMENT ON COLUMN ep.regard_ep.sec_com IS 'Champ client conserve tel quel, meme si redondant avec ep_sect_com.';
COMMENT ON COLUMN ep.regard_ep."GENRATRICE_SUP" IS 'Champ client conserve tel quel, conforme au CSV contractuel.';
COMMENT ON COLUMN ep.regard_ep.ep_ref_rue IS 'Champ libre. Le CSV mentionne "REF RUE / DOUAR" comme indication de saisie, pas comme liste fermee.';

CREATE UNIQUE INDEX regard_ep_uuid_uidx
    ON ep.regard_ep (uuid)
    WHERE uuid IS NOT NULL;

CREATE INDEX regard_ep_geom_gix
    ON ep.regard_ep
    USING GIST (geom);

CREATE INDEX regard_ep_id_commune_idx
    ON ep.regard_ep (id_commune);

CREATE INDEX regard_ep_id_province_idx
    ON ep.regard_ep (id_province);

CREATE INDEX regard_ep_date_creation_idx
    ON ep.regard_ep (date_creation DESC);

CREATE INDEX regard_ep_is_deleted_idx
    ON ep.regard_ep (is_deleted);

DELETE FROM public.srm_field_option
WHERE table_schema = 'ep'
  AND table_name = 'regard_ep';

INSERT INTO public.srm_field_option (table_schema, table_name, field_name, code_value, label_value, display_order) VALUES
    ('ep', 'regard_ep', 'ep_statut', 'EP_POSE', 'EP_POSE', 1),
    ('ep', 'regard_ep', 'ep_statut', 'EP_REHABILITE', 'EP_REHABILITE', 2),
    ('ep', 'regard_ep', 'ep_statut', 'EP_EXISTANT', 'EP_EXISTANT', 3),
    ('ep', 'regard_ep', 'ep_statut', 'EP_PROJETE', 'EP_PROJETE', 4),
    ('ep', 'regard_ep', 'ep_statut', 'EP_A REHABI', 'EP_A REHABILITE', 5),
    ('ep', 'regard_ep', 'ep_statut', 'EP_EN COURSS', 'EP_EN COURS', 6),
    ('ep', 'regard_ep', 'ep_statut', 'EP_A RESILISE', 'EP_A RESILISER', 7),

    ('ep', 'regard_ep', 'emplacement', 'S-TROTTOIR', 'TR', 1),
    ('ep', 'regard_ep', 'emplacement', 'S-CHAUSSEE', 'CH', 2),
    ('ep', 'regard_ep', 'emplacement', 'S-TROTOIR C-CHAISSI', 'TR-CH', 3),
    ('ep', 'regard_ep', 'emplacement', 'TN', 'TN', 4),
    ('ep', 'regard_ep', 'emplacement', 'PISTE', 'PISTE', 5),
    ('ep', 'regard_ep', 'emplacement', 'TERRE_AGRICOLE', 'AGRI', 6),

    ('ep', 'regard_ep', 'ep_tampon', 'FD400', 'FD400', 1),
    ('ep', 'regard_ep', 'ep_tampon', 'FD250', 'FD250', 2),
    ('ep', 'regard_ep', 'ep_tampon', 'Béton', 'Béton', 3),

    ('ep', 'regard_ep', 'ep_conf_plan', 'Conforme aux plan', 'Conforme aux plan', 1),
    ('ep', 'regard_ep', 'ep_conf_plan', 'Objet découvrt sur terrain', 'Objet découvrt sur terrain', 2),
    ('ep', 'regard_ep', 'ep_conf_plan', 'Objet non trouvé sur le terrain', 'Objet non trouvé sur le terrain', 3),

    ('ep', 'regard_ep', 'ep_anomalie', 'O', 'Oui', 1),
    ('ep', 'regard_ep', 'ep_anomalie', 'N', 'Non', 2),

    ('ep', 'regard_ep', 'mode_localisation', 'Levé topographique', 'Levé topographique', 1),
    ('ep', 'regard_ep', 'mode_localisation', 'Triangulé', 'Triangulé', 2),
    ('ep', 'regard_ep', 'mode_localisation', 'Schématique', 'Schématique', 3),
    ('ep', 'regard_ep', 'mode_localisation', 'Indéterminé', 'Indéterminé', 4),

    ('ep', 'regard_ep', 'echelon', 'O', 'Oui', 1),
    ('ep', 'regard_ep', 'echelon', 'N', 'Non', 2),

    ('ep', 'regard_ep', 'anomalie_tamp', 'Tampons en mauvais état', 'Tampons en mauvais état', 1),
    ('ep', 'regard_ep', 'anomalie_tamp', 'Tampons Manquant', 'Tampons Manquant', 2),
    ('ep', 'regard_ep', 'anomalie_tamp', 'Tampons Scellés', 'Tampons Scellés', 3),

    ('ep', 'regard_ep', 'anomalie_regard', 'A mettre à la cote', 'A mettre à la cote', 1),
    ('ep', 'regard_ep', 'anomalie_regard', 'Inaccessible', 'Inaccessible', 2),
    ('ep', 'regard_ep', 'anomalie_regard', 'Ouvrage dégradés', 'Ouvrage dégradés', 3),
    ('ep', 'regard_ep', 'anomalie_regard', 'Regards Enterrés', 'Regards Enterrés', 4),
    ('ep', 'regard_ep', 'anomalie_regard', 'Regards Noyés', 'Regards Noyés', 5),
    ('ep', 'regard_ep', 'anomalie_regard', 'Regards à curer', 'Regards à curer', 6),
    ('ep', 'regard_ep', 'anomalie_regard', 'Sectionnement enterré', 'Sectionnement enterré', 7),
    ('ep', 'regard_ep', 'anomalie_regard', 'Autre', 'Autre', 8);

CREATE OR REPLACE FUNCTION public.touch_regard_ep()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.date_creation IS NULL THEN
            NEW.date_creation := NOW();
        END IF;

        IF NEW.date_modif IS NULL THEN
            NEW.date_modif := NEW.date_creation;
        END IF;

        IF NEW.ep_date_insertion IS NULL AND NEW.date_creation IS NOT NULL THEN
            NEW.ep_date_insertion := NEW.date_creation::date;
        END IF;
    ELSE
        NEW.date_modif := NOW();

        IF NEW.ep_date_insertion IS NULL AND NEW.date_creation IS NOT NULL THEN
            NEW.ep_date_insertion := NEW.date_creation::date;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_touch_regard_ep
BEFORE INSERT OR UPDATE
ON ep.regard_ep
FOR EACH ROW
EXECUTE FUNCTION public.touch_regard_ep();

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_proc p
        JOIN pg_namespace n
          ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = 'capture_historique_attribut'
    ) THEN
        EXECUTE 'CREATE TRIGGER trg_audit_regard_ep AFTER INSERT OR UPDATE OR DELETE ON ep.regard_ep FOR EACH ROW EXECUTE FUNCTION public.capture_historique_attribut(''fid'')';
    END IF;
END;
$$;

COMMIT;
