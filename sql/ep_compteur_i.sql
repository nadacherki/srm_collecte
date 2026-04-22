-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_compteur_i.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_compteur_i" (
    "ep_type" varchar(400),
    "ep_modele" varchar(400),
    "ep_calibre" varchar(400),
    "ep_sourc_alim" varchar(400) DEFAULT 'ONEP',
    "ep_ref_regard" varchar(400),
    "ep_n_serie" varchar(400),
    "ep_marque" varchar(400) DEFAULT 'modele compteur',
    "ep_compt_fonction" varchar(400) DEFAULT 'P',
    "ep_conf_plan" varchar(400),
    "ep_observation" varchar(400),
    "ep_anomalie" varchar(400),
    "mode_localisation" varchar(400),
    "emplacement" varchar(400),
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "ep_alti" double precision,
    "ep_ref_rue" varchar(400),
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
    "ep_zone_hydro" varchar(400),
    "ep_secteur_hydro" varchar(400),
    "ep_statut" varchar(400),
    "ep_agent_crea" varchar(400),
    "sec_com" varchar(400),
    "sect_hydr" varchar(400),
    "zone" varchar(400),
    CONSTRAINT "ep_compteur_i_ep_sourc_alim_chk" CHECK ("ep_sourc_alim" IN ('RADEEO', 'ONEP', 'SRM')),
    CONSTRAINT "ep_compteur_i_ep_ref_regard_chk" CHECK ("ep_ref_regard" IN ('OUI', 'NON')),
    CONSTRAINT "ep_compteur_i_ep_compt_fonction_chk" CHECK ("ep_compt_fonction" IN ('P', 'S', 'D', 'A')),
    CONSTRAINT "ep_compteur_i_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_compteur_i_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé')),
    CONSTRAINT "ep_compteur_i_emplacement_chk" CHECK ("emplacement" IN ('S-TROTTOIR', 'S-CHAUSSEE', 'S-TROTOIR C-CHAISSI', 'TN', 'PISTE', 'TERRE_AGRICOLE')),
    CONSTRAINT "ep_compteur_i_ep_statut_chk" CHECK ("ep_statut" IN ('EP_POSE', 'EP_REHABILITE', 'EP_EXISTANT', 'EP_PROJETE', 'EP_A REHABI', 'EP_EN COURSS', 'EP_A RESILISE'))
);

COMMENT ON TABLE "ep"."ep_compteur_i" IS 'Generated from ep_compteur_i.csv';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_type" IS 'Titre mobile: Type de compteur | Mode de remplissage: saisie agent mobile | Valeur attendue: debimetre , compteur';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_modele" IS 'Titre mobile: Modèle de compteur | Mode de remplissage: saisie agent mobile | Contrainte: illisible';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_calibre" IS 'Titre mobile: Calibre du compteur(mm) | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_sourc_alim" IS 'Titre mobile: Source alimentant le compteur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_ref_regard" IS 'Titre mobile: Existence d''un regard | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_n_serie" IS 'Titre mobile: N° De Serie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_marque" IS 'Titre mobile: Ep Marque | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_compt_fonction" IS 'Titre mobile: Ep Compt Fonction | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_compteur_i"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_compteur_i"."emplacement" IS 'Titre mobile: Emplacement regard | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_compteur_i"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_alti" IS 'Titre mobile: Altitude(Z) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_ref_rue" IS 'Titre mobile: Référence rue | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_date_insertion" IS 'Titre mobile: Date D''Insertion Sur Elex | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."altitute" IS 'Titre mobile: Altitude | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_coor_x" IS 'Titre mobile: Coordonnées relevées X | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_coor_y" IS 'Titre mobile: Coordonnées relevées Y | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_coor_z" IS 'Titre mobile: Coordonnées relevées Z | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_compteur_i"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_secteur_com" IS 'Titre mobile: Secteur commercial | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_zone_hydro" IS 'Titre mobile: Zone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_secteur_hydro" IS 'Titre mobile: Secteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_statut" IS 'Titre mobile: Statut de la conduite | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."sect_hydr" IS 'Titre mobile: CopieDeSecteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_compteur_i"."zone" IS 'Titre mobile: CopieDeZone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
