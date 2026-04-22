-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_regard.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."ep_regard" (
    "emplacement" varchar(400) NOT NULL,
    "ep_ref_rue" varchar(400) NOT NULL,
    "ep_section" varchar(400) NOT NULL,
    "ep_tampon" varchar(400) NOT NULL,
    "ep_conf_plan" varchar(400) NOT NULL,
    "ep_observation" varchar(400) NOT NULL,
    "ep_anomalie" varchar(400) NOT NULL,
    "mode_localisation" varchar(400) DEFAULT 'Levé topographique',
    "echelon" varchar(400) NOT NULL,
    "anomalie_tamp" varchar(400) NOT NULL,
    "anomalie_regard" varchar(400) NOT NULL,
    "GENRATRICE_SUP" double precision NOT NULL,
    "ep_profondeur" double precision NOT NULL,
    "fid" serial PRIMARY KEY,
    "uuid" varchar(254),
    "z_radier" varchar(400) DEFAULT 'Z_coor-profondeur',
    "z_surf" varchar(400) DEFAULT 'Z_coor-',
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
    "ep_agent" varchar(400) DEFAULT 'ETAFAT',
    "ep_sect_com" varchar(400),
    "ep_statut" varchar(400),
    "ep_adresse" varchar(400),
    "ep_agent_crea" varchar(400) DEFAULT 'ETAFAT',
    "sec_com" varchar(400) DEFAULT 'COMMUNE',
    "sect_hydr" varchar(400) DEFAULT 'COMMUNE',
    "zone" varchar(400) DEFAULT 'COMMUNE',
    "ep_code_ter" varchar(400),
    "ep_date_pose" varchar(400),
    "type regard" varchar(400),
    CONSTRAINT "ep_regard_emplacement_chk" CHECK ("emplacement" IN ('S-TROTTOIR', 'S-CHAUSSEE', 'S-TROTOIR C-CHAISSI', 'TN', 'PISTE', 'TERRE_AGRICOLE')),
    CONSTRAINT "ep_regard_ep_tampon_chk" CHECK ("ep_tampon" IN ('FD400', 'FD250', 'Béton')),
    CONSTRAINT "ep_regard_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "ep_regard_ep_anomalie_chk" CHECK ("ep_anomalie" IN ('O', 'N')),
    CONSTRAINT "ep_regard_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé')),
    CONSTRAINT "ep_regard_echelon_chk" CHECK ("echelon" IN ('O', 'N')),
    CONSTRAINT "ep_regard_anomalie_tamp_chk" CHECK ("anomalie_tamp" IN ('Tampons en mauvais état', 'Tampons Manquant', 'Tampons Scellés')),
    CONSTRAINT "ep_regard_anomalie_regard_chk" CHECK ("anomalie_regard" IN ('A mettre à la cote', 'Inaccessible', 'Ouvrage dégradés', 'Regards Enterrés', 'Regards Noyés', 'Regards à curer', 'Sectionnement enterré', 'Autre')),
    CONSTRAINT "ep_regard_ep_statut_chk" CHECK ("ep_statut" IN ('EP_POSE', 'EP_REHABILITE', 'EP_EXISTANT', 'EP_PROJETE', 'EP_A REHABI', 'EP_EN COURSS', 'EP_A RESILISE'))
);

COMMENT ON TABLE "ep"."ep_regard" IS 'Generated from ep_regard.csv';
COMMENT ON COLUMN "ep"."ep_regard"."emplacement" IS 'Titre mobile: Emplacement regard | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_regard"."ep_ref_rue" IS 'Titre mobile: Reference rue | Mode de remplissage: saisie agent mobile | Valeur attendue: REF RUE / DOUAR';
COMMENT ON COLUMN "ep"."ep_regard"."ep_section" IS 'Titre mobile: Section du regard | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_tampon" IS 'Titre mobile: Type de tampon | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_regard"."ep_conf_plan" IS 'Titre mobile: Conformité des plans | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_regard"."ep_observation" IS 'Titre mobile: Observation | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_regard"."ep_anomalie" IS 'Titre mobile: Anomalie | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_regard"."mode_localisation" IS 'Titre mobile: Mode localisation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."echelon" IS 'Titre mobile: Existance échelon | Mode de remplissage: saisie agent mobile';
COMMENT ON COLUMN "ep"."ep_regard"."anomalie_tamp" IS 'Titre mobile: Anomalie tampon | Mode de remplissage: saisie agent mobile | Contrainte: si tampon scellé ou regard enterreé user , bloquer la saisie de profondeur , generatrice superieur , retour_terran doit = oui';
COMMENT ON COLUMN "ep"."ep_regard"."anomalie_regard" IS 'Titre mobile: Anomalie Regard | Mode de remplissage: saisie agent mobile | Contrainte: inacessible, bloquer ,';
COMMENT ON COLUMN "ep"."ep_regard"."GENRATRICE_SUP" IS 'Titre mobile: generatrice superieur | Valeur par defaut interpretee comme note: distance entre z_tampon et z_conduite | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: distance entre z_tampon et z_conduite | Contrainte: 4m alerte , positive';
COMMENT ON COLUMN "ep"."ep_regard"."ep_profondeur" IS 'Titre mobile: Ep Profondeur | Mode de remplissage: saisie agent mobile | Contrainte: 4m alerte , positive';
COMMENT ON COLUMN "ep"."ep_regard"."fid" IS 'Titre mobile: Identifiant unique (PK) | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."uuid" IS 'Titre mobile: Identifiant unique universel | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."z_radier" IS 'Titre mobile: Cote radier | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."z_surf" IS 'Titre mobile: Cote surface | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_date_insertion" IS 'Titre mobile: Date d''insertion sur Elyx | Valeur par defaut interpretee comme note: on remplie avec date_creation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_coor_x" IS 'Titre mobile: Coordonnées relevées X | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_coor_y" IS 'Titre mobile: Coordonnées relevées Y | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_coor_z" IS 'Titre mobile: Coordonnées relevées Z | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."geom" IS 'Titre mobile: Géométrie PostGIS | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."id_commune" IS 'Titre mobile: FK commune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."id_province" IS 'Titre mobile: FK province | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."id_user_creat" IS 'Titre mobile: FK utilisateur créateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."id_user_modif" IS 'Titre mobile: FK utilisateur modificateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."date_creation" IS 'Titre mobile: Date/heure de création | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."date_modif" IS 'Titre mobile: Date/heure dernière modification | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."is_deleted" IS 'Titre mobile: Suppression logique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."is_validated" IS 'Titre mobile: Validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Validation exploitant';
COMMENT ON COLUMN "ep"."ep_regard"."id_user_valid" IS 'Titre mobile: FK utilisateur validateur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."date_validation" IS 'Titre mobile: Date/heure validation | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_sect_com" IS 'Titre mobile: Secteur commercial | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Valeur attendue: COMMUNE';
COMMENT ON COLUMN "ep"."ep_regard"."ep_statut" IS 'Titre mobile: Statut | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_adresse" IS 'Titre mobile: Adresse | Valeur par defaut interpretee comme note: Réécrire la valeur depuis ep_ref_rue | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."sec_com" IS 'Titre mobile: Sec Com | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."sect_hydr" IS 'Titre mobile: Secteur hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."zone" IS 'Titre mobile: Zone hydraulique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_code_ter" IS 'Titre mobile: Code Terrain | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source';
COMMENT ON COLUMN "ep"."ep_regard"."ep_date_pose" IS 'Titre mobile: Date de pose | Mode de remplissage: saisie agent mobile | Valeur attendue: facultative';
COMMENT ON COLUMN "ep"."ep_regard"."type regard" IS 'Titre mobile: type regard | Type SQL infere a partir du CSV | Valeur par defaut interpretee comme note: liste : vidange , ventouse ,compteur ,chambre de vanne, regard standard (defautl) | Mode de remplissage: saisie agent mobile';
