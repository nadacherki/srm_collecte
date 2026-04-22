-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_brc_pt.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_brc_pt" (
    "abon" varchar(400) NOT NULL,
    "nom" varchar(400) NOT NULL,
    "num_contrat" varchar(400) NOT NULL,
    "num_compteur" varchar(400),
    "type_cpt" varchar(400),
    "diametre" varchar(400),
    "ep_conf_plan" varchar(400) DEFAULT 'decouvert sur terrain',
    "ep_observation" varchar(400),
    "ep_anomalie" varchar(400),
    "type_anomalie" varchar(400),
    "mode_localisation" varchar(400) DEFAULT 'Levé topographique',
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "ref" varchar(400),
    "sect" varchar(400),
    "ep_coor_x" double precision,
    "ep_coor_Z" varchar(400),
    "ep_coor_y" double precision,
    "type_abonnement" varchar(400),
    "etat_abonnement" varchar(400),
    "ep_date_insertion" date,
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
    "sect_hydr" varchar(400),
    "zone" varchar(400),
    "adresse" varchar(400),
    "ep_agent" varchar(400),
    "ep_agent_crea" varchar(400),
    "sec_com" varchar(400),
    "ancien_ref_sap" integer,
    "id_geo" integer,
    "ancienne_police" integer,
    CONSTRAINT "ep_brc_pt_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_brc_pt_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé'))
);

COMMENT ON TABLE "ep"."ep_brc_pt" IS 'Generated from ep_brc_pt.csv';
COMMENT ON COLUMN "ep"."ep_brc_pt"."abon" IS 'Titre mobile: Abonné | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_brc_pt"."nom" IS 'Titre mobile: Nom | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_brc_pt"."num_contrat" IS 'Titre mobile: Numéro de contrat | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_brc_pt"."num_compteur" IS 'Titre mobile: Numéro de compteur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."type_cpt" IS 'Titre mobile: Type de compteur | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_brc_pt"."diametre" IS 'Titre mobile: Diamètre | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_brc_pt"."type_anomalie" IS 'Titre mobile: Type Anomalie | Type SQL infere a partir du CSV | Mode de remplissage: saisie agent mobile | Valeur attendue: abscence de comtpeur , branchement non raccordé ,fraude';
COMMENT ON COLUMN "ep"."ep_brc_pt"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ref" IS 'Titre mobile: Référence | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."sect" IS 'Titre mobile: Secteur commercial | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ep_coor_x" IS 'Titre mobile: Coordonnées relevées X | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ep_coor_Z" IS 'Titre mobile: Coor Z | Type SQL infere a partir du CSV | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ep_coor_y" IS 'Titre mobile: Coordonnées relevées Y | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."type_abonnement" IS 'Titre mobile: Type d''abonnement | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."etat_abonnement" IS 'Titre mobile: Etat abonnement | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ep_date_insertion" IS 'Titre mobile: Date d''insertion sur Elyx | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."is_validated" IS 'Titre mobile: Validation exploitant | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_brc_pt"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."sect_hydr" IS 'Titre mobile: Secteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."zone" IS 'Titre mobile: Zone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."adresse" IS 'Titre mobile: Adresse | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ancien_ref_sap" IS 'Titre mobile: Ancienne reference SAP | Valeur par defaut interpretee comme note: liaison avec db clientel | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_brc_pt"."id_geo" IS 'Titre mobile: Identifiant geographique | Valeur par defaut interpretee comme note: liaison avec db clientel | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_brc_pt"."ancienne_police" IS 'Titre mobile: Ancienne police | Valeur par defaut interpretee comme note: liaison avec db clientel | Mode de remplissage: saisie agent mobile';
