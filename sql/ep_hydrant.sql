-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_hydrant.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_hydrant" (
    "ep_type" varchar(400),
    "ep_etat" varchar(400),
    "ep_conform" varchar(400),
    "statut" varchar(400),
    "type" varchar(400),
    "marque" varchar(400),
    "diametre" integer,
    "diamcond" integer,
    "conform" varchar(400),
    "dispo" varchar(400),
    "vanne" varchar(400),
    "codinsee" varchar(400),
    "ep_conf_plan" varchar(400),
    "ep_observation" varchar(400),
    "ep_anomalie" varchar(400),
    "mode_localisation" varchar(400),
    "emplacement" varchar(400),
    "ep_ref_regard" varchar(400),
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "ep_alti" double precision,
    "ep_ref_rue" varchar(400),
    "ep_date_insertion" date,
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
    "adresse" varchar(400),
    "ep_statut" varchar(400),
    "ep_agent_crea" varchar(400),
    "sec_com" varchar(400),
    "sect_hydr" varchar(400),
    "zone" varchar(400),
    CONSTRAINT "ep_hydrant_ep_etat_chk" CHECK ("ep_etat" IN ('OUVERT', 'FERME')),
    CONSTRAINT "ep_hydrant_statut_chk" CHECK ("statut" IN ('PRIVE', 'PUBLIC')),
    CONSTRAINT "ep_hydrant_type_chk" CHECK ("type" IN ('BOU_INC', 'POT_INC', 'CITERNE', 'PRISERSV', 'PRISERIV', 'NON_DEF')),
    CONSTRAINT "ep_hydrant_marque_chk" CHECK ("marque" IN ('RAYARD', 'BMX', 'RAMUS', 'ILLISIBLE')),
    CONSTRAINT "ep_hydrant_diametre_chk" CHECK ("diametre" IN ('16', '25', '32', '40', '50', '60', '63', '70', '75', '80', '90', '100', '110', '125', '135', '140', '150', '160', '175', '180', '200', '225', '250', '300', '350', '400', '450', '500', '600', '800', '900', '1000', '1200', '-1')),
    CONSTRAINT "ep_hydrant_diamcond_chk" CHECK ("diamcond" IN ('16', '25', '32', '40', '50', '60', '63', '70', '75', '80', '90', '100', '110', '125', '135', '140', '150', '160', '175', '180', '200', '225', '250', '300', '350', '400', '450', '500', '600', '800', '900', '1000', '1200', '-1')),
    CONSTRAINT "ep_hydrant_conform_chk" CHECK ("conform" IN ('O', 'N')),
    CONSTRAINT "ep_hydrant_dispo_chk" CHECK ("dispo" IN ('O', 'N')),
    CONSTRAINT "ep_hydrant_vanne_chk" CHECK ("vanne" IN ('O', 'N')),
    CONSTRAINT "ep_hydrant_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_hydrant_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé')),
    CONSTRAINT "ep_hydrant_emplacement_chk" CHECK ("emplacement" IN ('S-TROTTOIR', 'S-CHAUSSEE', 'S-TROTOIR C-CHAISSI', 'TN', 'PISTE', 'TERRE_AGRICOLE')),
    CONSTRAINT "ep_hydrant_ep_ref_regard_chk" CHECK ("ep_ref_regard" IN ('O', 'N')),
    CONSTRAINT "ep_hydrant_ep_statut_chk" CHECK ("ep_statut" IN ('EP_POSE', 'EP_REHABILITE', 'EP_EXISTANT', 'EP_PROJETE', 'EP_A REHABI', 'EP_EN COURSS', 'EP_A RESILISE'))
);

COMMENT ON TABLE "ep"."ep_hydrant" IS 'Generated from ep_hydrant.csv';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_type" IS 'Titre mobile: Type d''hydrant | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_etat" IS 'Titre mobile: Etat d''ouverture | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_conform" IS 'Titre mobile: Conformité. | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."statut" IS 'Titre mobile: Statut | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."type" IS 'Titre mobile: Type | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."marque" IS 'Titre mobile: Marque | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."diametre" IS 'Titre mobile: Diamètre | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."diamcond" IS 'Titre mobile: Diamètre raccordement de la conduite | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."conform" IS 'Titre mobile: Conformité | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."dispo" IS 'Titre mobile: Disponibilité | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."vanne" IS 'Titre mobile: Présence d''une vanne | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."codinsee" IS 'Titre mobile: Code INSEE | Liste de choix non enforcee en CHECK: A | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."emplacement" IS 'Titre mobile: Emplacement regard | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_ref_regard" IS 'Titre mobile: Existence d''un regard | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_hydrant"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_alti" IS 'Titre mobile: Altitude(Z) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_ref_rue" IS 'Titre mobile: Référence rue | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_date_insertion" IS 'Titre mobile: Date D''Insertion Sur Elex | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_coor_x" IS 'Titre mobile: Coordonnées relevées X | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_coor_y" IS 'Titre mobile: Coordonnées relevées Y | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_coor_z" IS 'Titre mobile: Coordonnées relevées Z | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_hydrant"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_secteur_com" IS 'Titre mobile: Secteur commercial | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_zone_hydro" IS 'Titre mobile: Zone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_secteur_hydro" IS 'Titre mobile: Secteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."adresse" IS 'Titre mobile: Adresse | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_statut" IS 'Titre mobile: Statut de la conduite | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."sect_hydr" IS 'Titre mobile: CopieDeSecteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_hydrant"."zone" IS 'Titre mobile: CopieDeZone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
