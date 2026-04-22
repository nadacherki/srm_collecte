-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_vidange.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_vidange" (
    "ep_type" varchar(400),
    "ep_modele" varchar(400),
    "ep_point_vid" varchar(400),
    "ep_diam" varchar(400),
    "ep_ref_regard" varchar(400),
    "ep_etat" varchar(400),
    "ep_conf_plan" varchar(400),
    "ep_observation" varchar(400),
    "ep_anomalie" varchar(400),
    "ep_marque" varchar(400),
    "mode_localisation" varchar(400),
    "ep_sectionnement" varchar(400),
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "ep_alti" double precision,
    "ep_ref_rue" varchar(400),
    "ep_date_insertion" date,
    "ep_coor_x" double precision,
    "ep_coor_y" double precision,
    "ep_coor_z" double precision,
    "emplacement" varchar(400),
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
    "ep_zone_hydro" varchar(400),
    "ep_secteur_hydro" varchar(400),
    "ep_statut" varchar(400),
    "sec_com" varchar(400),
    "sect_hydr" varchar(400),
    "zone" varchar(400),
    CONSTRAINT "ep_vidange_ep_point_vid_chk" CHECK ("ep_point_vid" IN ('A', 'N')),
    CONSTRAINT "ep_vidange_ep_diam_chk" CHECK ("ep_diam" IN ('1000', '800', '700', '600', '500', '400', '350', '315', '300', '250', '225', '200', '160', '150', '125', '110', '100', '90', '80', '75', '63', '60', '40', '50', '32')),
    CONSTRAINT "ep_vidange_ep_ref_regard_chk" CHECK ("ep_ref_regard" IN ('O', 'N')),
    CONSTRAINT "ep_vidange_ep_etat_chk" CHECK ("ep_etat" IN ('OUVERT', 'FERME')),
    CONSTRAINT "ep_vidange_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_vidange_ep_marque_chk" CHECK ("ep_marque" IN ('RAYARD', 'BMX', 'RAMUS', 'ILLISIBLE')),
    CONSTRAINT "ep_vidange_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé')),
    CONSTRAINT "ep_vidange_ep_sectionnement_chk" CHECK ("ep_sectionnement" IN ('à opercule', 'à papillon', 'à boisseau sphérique')),
    CONSTRAINT "ep_vidange_emplacement_chk" CHECK ("emplacement" IN ('S-TROTTOIR', 'S-CHAUSSEE', 'S-TROTOIR C-CHAISSI', 'TN', 'PISTE', 'TERRE_AGRICOLE')),
    CONSTRAINT "ep_vidange_ep_statut_chk" CHECK ("ep_statut" IN ('EP_POSE', 'EP_REHABILITE', 'EP_EXISTANT', 'EP_PROJETE', 'EP_A REHABI', 'EP_EN COURSS', 'EP_A RESILISE'))
);

COMMENT ON TABLE "ep"."ep_vidange" IS 'Generated from ep_vidange.csv';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_type" IS 'Titre mobile: Type de vanne de vidange | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_modele" IS 'Titre mobile: Modèle de vanne de vidange | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_point_vid" IS 'Titre mobile: Point de vidange | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_diam" IS 'Titre mobile: Diamètre | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_ref_regard" IS 'Titre mobile: Existence d''un regard | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_etat" IS 'Titre mobile: Etat de service | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_marque" IS 'Titre mobile: Marque de ventouse | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_sectionnement" IS 'Titre mobile: Type de Sectionnement | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vidange"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_alti" IS 'Titre mobile: Altitude(Z) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_ref_rue" IS 'Titre mobile: Référence rue | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_date_insertion" IS 'Titre mobile: Date D''Insertion Sur Elex | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_coor_x" IS 'Titre mobile: Coordonnées relevées X | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_coor_y" IS 'Titre mobile: Coordonnées relevées Y | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_coor_z" IS 'Titre mobile: Coordonnées relevées Z | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."emplacement" IS 'Titre mobile: Emplacement regard | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_vidange"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_secteur_com" IS 'Titre mobile: Secteur commercial | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_zone_hydro" IS 'Titre mobile: Zone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_secteur_hydro" IS 'Titre mobile: Secteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."ep_statut" IS 'Titre mobile: Statut de la conduite | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."sect_hydr" IS 'Titre mobile: CopieDeSecteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vidange"."zone" IS 'Titre mobile: CopieDeZone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
