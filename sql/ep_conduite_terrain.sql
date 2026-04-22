-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_conduite_terrain.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."conduite_terrain" (
    "ep_diam" integer,
    "ep_mat" varchar(400),
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "geom" geometry,
    "id_commune" integer REFERENCES "public"."commune"("fid"),
    "id_province" integer REFERENCES "public"."province"("fid"),
    "id_user_creat" integer REFERENCES "public"."utilisateur"("id_user"),
    "id_user_modif" integer REFERENCES "public"."utilisateur"("id_user"),
    "date_creation" timestamptz,
    "date_modif" timestamptz,
    "is_deleted" boolean DEFAULT false,
    "is_validated" boolean DEFAULT false,
    "id_user_valid" integer REFERENCES "public"."utilisateur"("id_user"),
    "date_validation" timestamp,
    "ep_classe_conduite" varchar(400) DEFAULT 'facultatif',
    CONSTRAINT "conduite_terrain_ep_classe_conduite_chk" CHECK ("ep_classe_conduite" IN ('PN6', 'PN10', 'PN16', 'PN25', 'Inconnue'))
);

COMMENT ON TABLE "ep"."conduite_terrain" IS 'Generated from ep_conduite_terrain.csv';
COMMENT ON COLUMN "ep"."conduite_terrain"."ep_diam" IS 'Titre mobile: Diamètre | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."conduite_terrain"."ep_mat" IS 'Titre mobile: Matériau | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."conduite_terrain"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."conduite_terrain"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."conduite_terrain"."ep_classe_conduite" IS 'Titre mobile: Ep Classe | Mode de remplissage: saisie agent mobile';
