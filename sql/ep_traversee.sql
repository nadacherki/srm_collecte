-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_traversee.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_traversee" (
    "type_traver" varchar(400),
    "ep_diam" varchar(400),
    "ep_mat" varchar(400),
    "ep_profondeur" double precision,
    "ep_classe_conduite" varchar(400),
    "ep_ref_rue" varchar(400),
    "ep_observ" varchar(400),
    "ep_conf_plan" varchar(400),
    "ep_observation" varchar(400),
    "ep_anomalie" varchar(400),
    "nom_obstac" varchar(400),
    "type_prot" varchar(400),
    "mode_localisation" varchar(400),
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "ep_date_insertion" date,
    "ep_long_r" double precision,
    "ep_photo" varchar(400),
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
    "ep_adresse" varchar(400),
    "ep_secteur_com" varchar(400),
    "ep_agent_maj" varchar(400),
    "ep_statut" varchar(400),
    "ep_agent_crea" varchar(400),
    "sec_com" varchar(400),
    CONSTRAINT "ep_traversee_type_traver_chk" CHECK ("type_traver" IN ('Route', 'Oued', 'Voie', 'Chaaba')),
    CONSTRAINT "ep_traversee_ep_diam_chk" CHECK ("ep_diam" IN ('1000', '800', '700', '600', '500', '400', '350', '315', '300', '250', '225', '200', '160', '150', '125', '110', '100', '90', '80', '75', '63', '60', '40', '50', '32')),
    CONSTRAINT "ep_traversee_ep_mat_chk" CHECK ("ep_mat" IN ('AC', 'AMC', 'BE', 'BEP', 'FO', 'FOD', 'FOG', 'PB', 'PVC', 'PE', 'IN', 'BVA', 'CAO', 'PP', 'PEHD', 'BETON ARME', 'INC')),
    CONSTRAINT "ep_traversee_ep_classe_conduite_chk" CHECK ("ep_classe_conduite" IN ('PN6', 'PN10', 'PN16', 'PN25', 'Inconnue')),
    CONSTRAINT "ep_traversee_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_traversee_nom_obstac_chk" CHECK ("nom_obstac" IN ('Nom_route')),
    CONSTRAINT "ep_traversee_type_prot_chk" CHECK ("type_prot" IN ('Fourreau', 'Béton', 'Aucun')),
    CONSTRAINT "ep_traversee_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé')),
    CONSTRAINT "ep_traversee_ep_statut_chk" CHECK ("ep_statut" IN ('EP_POSE', 'EP_REHABILITE', 'EP_EXISTANT', 'EP_PROJETE', 'EP_A REHABI', 'EP_EN COURSS', 'EP_A RESILISE'))
);

COMMENT ON TABLE "ep"."ep_traversee" IS 'Generated from ep_traversee.csv';
COMMENT ON COLUMN "ep"."ep_traversee"."type_traver" IS 'Titre mobile: Type traverssé | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_diam" IS 'Titre mobile: Diamètre | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_mat" IS 'Titre mobile: Matériau | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_profondeur" IS 'Titre mobile: Profondeur | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_classe_conduite" IS 'Titre mobile: Ep Classe | Mode de remplissage: saisie agent mobile | Note: facultative';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_ref_rue" IS 'Titre mobile: Référence rue | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_observ" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Valeur attendue: oui ou non';
COMMENT ON COLUMN "ep"."ep_traversee"."nom_obstac" IS 'Titre mobile: Nom Obstacle | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."type_prot" IS 'Titre mobile: Type protection | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_traversee"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_date_insertion" IS 'Titre mobile: Date D''Insertion Sur Elex | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_long_r" IS 'Titre mobile: Longueur réelle | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_photo" IS 'Titre mobile: Photo | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_traversee"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_adresse" IS 'Titre mobile: Adresse | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_secteur_com" IS 'Titre mobile: Secteur commercial | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_agent_maj" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_statut" IS 'Titre mobile: Statut de la conduite | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_traversee"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
