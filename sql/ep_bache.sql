-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_bache.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_bache" (
    "ep_section" varchar(400),
    "ep_capacite" double precision,
    "ep_prof" double precision,
    "ep_ref_rue" varchar(400),
    "emplacement" varchar(400),
    "ep_conf_plan" varchar(400),
    "ep_observation" varchar(400),
    "ep_anomalie" varchar(400),
    "mode_localisation" varchar(400),
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "radier" double precision,
    "zsurf" double precision,
    "ep_date_insertion" date,
    "altitute" double precision,
    "ep_coor_x" double precision,
    "ep_coor_y" double precision,
    "ep_coor_z" double precision,
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
    "ep_secteur_com" varchar(400),
    "ep_agent" varchar(400),
    "ep_agent_crea" varchar(400),
    "sec_com" varchar(400),
    "sect_hydr" varchar(400),
    "zone" varchar(400),
    CONSTRAINT "ep_bache_ep_section_chk" CHECK ("ep_section" IN ('40X40', 'AUTRE', 'INCONNU')),
    CONSTRAINT "ep_bache_emplacement_chk" CHECK ("emplacement" IN ('S-TROTTOIR', 'S-CHAUSSEE', 'S-TROTOIR C-CHAISSI', 'TN', 'PISTE', 'TERRE_AGRICOLE')),
    CONSTRAINT "ep_bache_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_bache_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé'))
);

COMMENT ON TABLE "ep"."ep_bache" IS 'Generated from ep_bache.csv';
COMMENT ON COLUMN "ep"."ep_bache"."ep_section" IS 'Titre mobile: Section de la bache | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bache"."ep_capacite" IS 'Titre mobile: Capacite de la bâche m3 | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bache"."ep_prof" IS 'Titre mobile: Profondeur | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bache"."ep_ref_rue" IS 'Titre mobile: Référence rue | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bache"."emplacement" IS 'Titre mobile: Emplacement du regard | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bache"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bache"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bache"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bache"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bache"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."radier" IS 'Titre mobile: Côte radier (m) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."zsurf" IS 'Titre mobile: Côte surface (m) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."ep_date_insertion" IS 'Titre mobile: Date D''Insertion Sur Elex | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."altitute" IS 'Titre mobile: Altitude | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."ep_coor_x" IS 'Titre mobile: Coordonnées relevées X | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."ep_coor_y" IS 'Titre mobile: Coordonnées relevées Y | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."ep_coor_z" IS 'Titre mobile: Coordonnées relevées Z | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_bache"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."ep_secteur_com" IS 'Titre mobile: Secteur commercial | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."sect_hydr" IS 'Titre mobile: Secteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bache"."zone" IS 'Titre mobile: Zone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
