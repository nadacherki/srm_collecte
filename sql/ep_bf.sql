-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_bf.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_bf" (
    "ep_type_bf" varchar(400),
    "ep_etat" varchar(400),
    "ep_ref_rue" varchar(400),
    "statut" varchar(400),
    "diam_brts" integer,
    "conform" varchar(400),
    "ep_fonct" varchar(400),
    "vanne" varchar(400),
    "ep_conf_plan" varchar(400),
    "ep_observation" varchar(400),
    "ep_anomalie" varchar(400),
    "nb_robinets" integer,
    "mat_brts" integer,
    "compt_g" varchar(400),
    "diam_comp" integer,
    "mode_localisation" varchar(400),
    "ep_service" varchar(400),
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "ep_alti" double precision,
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
    CONSTRAINT "ep_bf_ep_type_bf_chk" CHECK ("ep_type_bf" IN ('SIMPLE', 'DOUBLE', 'MULTIROBINET')),
    CONSTRAINT "ep_bf_ep_etat_chk" CHECK ("ep_etat" IN ('BON', 'MOYEN', 'MO')),
    CONSTRAINT "ep_bf_statut_chk" CHECK ("statut" IN ('PRIVE', 'PUBLIC')),
    CONSTRAINT "ep_bf_diam_brts_chk" CHECK ("diam_brts" IN ('16', '25', '32', '40', '50', '60', '63', '70', '75', '80', '90', '100', '110', '125', '135', '140', '150', '160', '175', '180', '200', '225', '250', '300', '350', '400', '450', '500', '600', '800', '900', '1000', '1200', '-1')),
    CONSTRAINT "ep_bf_conform_chk" CHECK ("conform" IN ('O', 'N')),
    CONSTRAINT "ep_bf_ep_fonct_chk" CHECK ("ep_fonct" IN ('O', 'N')),
    CONSTRAINT "ep_bf_vanne_chk" CHECK ("vanne" IN ('O', 'N')),
    CONSTRAINT "ep_bf_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_bf_ep_anomalie_chk" CHECK ("ep_anomalie" IN ('O', 'N')),
    CONSTRAINT "ep_bf_mat_brts_chk" CHECK ("mat_brts" IN ('AC', 'AMC', 'BE', 'BEP', 'FO', 'FOD', 'FOG', 'PB', 'PVC', 'PE', 'IN', 'BVA', 'CAO', 'PP', 'PEHD', 'BETON ARME', 'INC')),
    CONSTRAINT "ep_bf_compt_g_chk" CHECK ("compt_g" IN ('O', 'N')),
    CONSTRAINT "ep_bf_diam_comp_chk" CHECK ("diam_comp" IN ('1000', '800', '700', '600', '500', '400', '350', '315', '300', '250', '225', '200', '160', '150', '125', '110', '100', '90', '80', '75', '63', '60', '40', '50', '32')),
    CONSTRAINT "ep_bf_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé')),
    CONSTRAINT "ep_bf_ep_statut_chk" CHECK ("ep_statut" IN ('EP_POSE', 'EP_REHABILITE', 'EP_EXISTANT', 'EP_PROJETE', 'EP_A REHABI', 'EP_EN COURSS', 'EP_A RESILISE'))
);

COMMENT ON TABLE "ep"."ep_bf" IS 'Generated from ep_bf.csv';
COMMENT ON COLUMN "ep"."ep_bf"."ep_type_bf" IS 'Titre mobile: Type BF | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."ep_etat" IS 'Titre mobile: Etat BF | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."ep_ref_rue" IS 'Titre mobile: Référence rue | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."statut" IS 'Titre mobile: Statut | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."diam_brts" IS 'Titre mobile: Diamètre branchement | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."conform" IS 'Titre mobile: Conformité | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."ep_fonct" IS 'Titre mobile: Fonctionnelle | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."vanne" IS 'Titre mobile: Présence d''une vanne | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."nb_robinets" IS 'Titre mobile: Nombre robinets | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."mat_brts" IS 'Titre mobile: Matériau branchement | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."compt_g" IS 'Titre mobile: Compteur géneral | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."diam_comp" IS 'Titre mobile: Diaméttre compteur | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: saisie agent mobile | Description: levé topographique';
COMMENT ON COLUMN "ep"."ep_bf"."ep_service" IS 'Titre mobile: Etat De Service | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_bf"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."ep_alti" IS 'Titre mobile: Altitude(Z) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."ep_date_insertion" IS 'Titre mobile: Date D''Insertion Sur Elex | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: date_creation';
COMMENT ON COLUMN "ep"."ep_bf"."ep_coor_x" IS 'Titre mobile: Coordonnées relevées X | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."ep_coor_y" IS 'Titre mobile: Coordonnées relevées Y | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."ep_coor_z" IS 'Titre mobile: Coordonnées relevées Z | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_bf"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."ep_secteur_com" IS 'Titre mobile: Secteur commercial | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."ep_zone_hydro" IS 'Titre mobile: Zone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: commune';
COMMENT ON COLUMN "ep"."ep_bf"."ep_secteur_hydro" IS 'Titre mobile: Secteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: commune';
COMMENT ON COLUMN "ep"."ep_bf"."adresse" IS 'Titre mobile: Adresse | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: ref_rue';
COMMENT ON COLUMN "ep"."ep_bf"."ep_statut" IS 'Titre mobile: Statut de la conduite | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_bf"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: ETAFAT';
COMMENT ON COLUMN "ep"."ep_bf"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: commune';
COMMENT ON COLUMN "ep"."ep_bf"."sect_hydr" IS 'Titre mobile: CopieDeSecteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: commune';
