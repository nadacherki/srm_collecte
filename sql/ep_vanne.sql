-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_vanne.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_vanne" (
    "ep_type" varchar(400),
    "ep_modele" varchar(400),
    "ep_diam" varchar(400),
    "ep_ref_regard" varchar(400),
    "ep_sens_ferm" varchar(400),
    "ep_manoeuvre" varchar(400),
    "ep_etat" varchar(400),
    "ep_sectionnement" varchar(400),
    "ep_observation" varchar(400),
    "ep_conf_plan" varchar(400),
    "ep_anomalie" varchar(400),
    "type_anomalie" varchar(400),
    "mode_localisation" varchar(400),
    "ep_marque" varchar(400),
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "ep_alti" varchar(400),
    "ep_ref_rue" varchar(400),
    "emplacement" varchar(400),
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
    "ep_agent_crea" varchar(400),
    "ep_agent" varchar(400),
    "ep_zone_hydro" varchar(400),
    "ep_secteur_hydro" varchar(400),
    "ep_statut" varchar(400),
    "sec_com" varchar(400),
    "sect_hydr" varchar(400),
    "zone" varchar(400),
    CONSTRAINT "ep_vanne_ep_type_chk" CHECK ("ep_type" IN ('V', 'VE', 'VS', 'VSS', 'VF', 'VFC', 'VR', 'VA')),
    CONSTRAINT "ep_vanne_ep_ref_regard_chk" CHECK ("ep_ref_regard" IN ('O', 'N')),
    CONSTRAINT "ep_vanne_ep_sens_ferm_chk" CHECK ("ep_sens_ferm" IN ('HORAIRE', 'ANTI-HORAIRE')),
    CONSTRAINT "ep_vanne_ep_manoeuvre_chk" CHECK ("ep_manoeuvre" IN ('O', 'N')),
    CONSTRAINT "ep_vanne_ep_etat_chk" CHECK ("ep_etat" IN ('OUVERT', 'FERME')),
    CONSTRAINT "ep_vanne_ep_sectionnement_chk" CHECK ("ep_sectionnement" IN ('à opercule', 'à papillon', 'à boisseau sphérique')),
    CONSTRAINT "ep_vanne_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_vanne_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé')),
    CONSTRAINT "ep_vanne_ep_marque_chk" CHECK ("ep_marque" IN ('RAYARD', 'BMX', 'RAMUS', 'ILLISIBLE')),
    CONSTRAINT "ep_vanne_emplacement_chk" CHECK ("emplacement" IN ('S-TROTTOIR', 'S-CHAUSSEE', 'S-TROTOIR C-CHAISSI', 'TN', 'PISTE', 'TERRE_AGRICOLE')),
    CONSTRAINT "ep_vanne_ep_statut_chk" CHECK ("ep_statut" IN ('EP_POSE', 'EP_REHABILITE', 'EP_EXISTANT', 'EP_PROJETE', 'EP_A REHABI', 'EP_EN COURSS', 'EP_A RESILISE'))
);

COMMENT ON TABLE "ep"."ep_vanne" IS 'Generated from ep_vanne.csv';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_type" IS 'Titre mobile: Type de vanne | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_modele" IS 'Titre mobile: Modèle de vanne | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_diam" IS 'Titre mobile: Diamètre | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_ref_regard" IS 'Titre mobile: Existence d''un regard | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_sens_ferm" IS 'Titre mobile: Sens de fermeture de la vanne | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_manoeuvre" IS 'Titre mobile: Manoeuvrage de la vanne auto OUI/NON | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_etat" IS 'Titre mobile: Etat d''ouverture | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_sectionnement" IS 'Titre mobile: Type de Sectionnement | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."type_anomalie" IS 'Titre mobile: type d anomalie | Type SQL infere a partir du CSV | Mode de remplissage: saisie agent mobile | Valeur attendue: sectionnement enterre , sectionnement degradé';
COMMENT ON COLUMN "ep"."ep_vanne"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_marque" IS 'Titre mobile: Ep Marque | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_vanne"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_alti" IS 'Titre mobile: Altitude(Z) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_ref_rue" IS 'Titre mobile: Référence rue | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."emplacement" IS 'Titre mobile: Emplacement | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_date_insertion" IS 'Titre mobile: Date D''Insertion Sur Elex | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."altitute" IS 'Titre mobile: Altitude | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_coor_x" IS 'Titre mobile: Coordonnées relevées X | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_coor_y" IS 'Titre mobile: Coordonnées relevées Y | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_coor_z" IS 'Titre mobile: Coordonnées relevées Z | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_vanne"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_secteur_com" IS 'Titre mobile: Secteur commercial | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_zone_hydro" IS 'Titre mobile: Zone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_secteur_hydro" IS 'Titre mobile: Secteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."ep_statut" IS 'Titre mobile: Statut de la conduite | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."sect_hydr" IS 'Titre mobile: CopieDeSecteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_vanne"."zone" IS 'Titre mobile: CopieDeZone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
