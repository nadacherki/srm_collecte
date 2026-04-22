-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_reservoir.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_reservoir" (
    "ep_nom" varchar(400),
    "ep_type" varchar(400),
    "ep_forme" varchar(400),
    "ep_etat_s" varchar(400),
    "ep_ref_rue" varchar(400),
    "ep_date_constr" date,
    "ep_date_rehab" date,
    "ep_type_cap" varchar(400),
    "ep_surf_clot" varchar(400),
    "ep_diam_in" double precision,
    "ep_diam_out" double precision,
    "ep_hr" double precision,
    "ep_capacite" double precision,
    "ep_conf_plan" varchar(400),
    "ep_observation" varchar(400),
    "ep_anomalie" varchar(400),
    "mode_localisation" varchar(400),
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "ep_cote_tp" double precision,
    "ep_cote_rad" double precision,
    "ep_photo" varchar(400),
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
    "ep_agent" varchar(400),
    "ep_zone_hydro" varchar(400),
    "ep_statut" varchar(400),
    "ep_agent_crea" varchar(400),
    "sec_com" varchar(400),
    "sect_hydr" varchar(400),
    "zone" varchar(400),
    CONSTRAINT "ep_reservoir_ep_type_chk" CHECK ("ep_type" IN ('R', 'C')),
    CONSTRAINT "ep_reservoir_ep_etat_s_chk" CHECK ("ep_etat_s" IN ('ES', 'AR', 'R', 'HS', 'E', 'A')),
    CONSTRAINT "ep_reservoir_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_reservoir_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé')),
    CONSTRAINT "ep_reservoir_ep_statut_chk" CHECK ("ep_statut" IN ('EP_POSE', 'EP_REHABILITE', 'EP_EXISTANT', 'EP_PROJETE', 'EP_A REHABI', 'EP_EN COURSS', 'EP_A RESILISE'))
);

COMMENT ON TABLE "ep"."ep_reservoir" IS 'Generated from ep_reservoir.csv';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_nom" IS 'Titre mobile: Nom du réservoir | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_type" IS 'Titre mobile: Type de réservoir | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_forme" IS 'Titre mobile: Forme de l''ouvrage | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_etat_s" IS 'Titre mobile: Etat de service de l''ouvrage | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_ref_rue" IS 'Titre mobile: Référence rue | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_date_constr" IS 'Titre mobile: Date de construction | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_date_rehab" IS 'Titre mobile: Date de réhabilitation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_type_cap" IS 'Titre mobile: Type de captage | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_surf_clot" IS 'Titre mobile: Surface clôturée du réservoir | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_diam_in" IS 'Titre mobile: Diamètre intérieur(m) | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_diam_out" IS 'Titre mobile: Diamètre extérieur(m) | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_hr" IS 'Titre mobile: Hauteur du réservoir(m) | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_capacite" IS 'Titre mobile: Capacité du réservoir(m3) | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_reservoir"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_cote_tp" IS 'Titre mobile: Cote trop plein(Z) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_cote_rad" IS 'Titre mobile: Cote radier(Z) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_photo" IS 'Titre mobile: Photo | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_date_insertion" IS 'Titre mobile: Date D''Insertion Sur Elex | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."altitute" IS 'Titre mobile: Altitude | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_coor_x" IS 'Titre mobile: CopieDeCoordonnées relevées X | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_coor_y" IS 'Titre mobile: CopieDeCoordonnées relevées Y | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_coor_z" IS 'Titre mobile: Coordonnées relevées Z | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_reservoir"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_zone_hydro" IS 'Titre mobile: Zone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_statut" IS 'Titre mobile: Statut de la conduite | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."sect_hydr" IS 'Titre mobile: Secteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_reservoir"."zone" IS 'Titre mobile: CopieDeZone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
