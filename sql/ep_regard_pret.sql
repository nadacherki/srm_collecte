-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\ep_regard_pret.csv
CREATE SCHEMA IF NOT EXISTS "ep";

CREATE TABLE IF NOT EXISTS "ep"."regard_pret" (
    "ep_agent" varchar(400) DEFAULT 'ETAFAT',
    "ep_sect_com" varchar(400) DEFAULT 'public.commune.nom_commune',
    "ep_statut" varchar(400),
    "ep_adresse" varchar(400),
    "ep_agent_crea" varchar(400) DEFAULT 'ETAFAT',
    "sec_com" varchar(400) DEFAULT 'même chose que ep_sect_com',
    "sect_hydr" varchar(400) DEFAULT 'public.commune.nom_commune',
    "zone" varchar(400) DEFAULT 'public.commune.nom_commune',
    "fid" serial PRIMARY KEY,
    "uuid" uuid,
    "z_radier" varchar(400),
    "z_surf" varchar(400),
    "ep_date_insertion" date,
    "ep_coor_x" double precision,
    "ep_coor_y" double precision,
    "ep_coor_z" double precision,
    "geom" geometry,
    "id_commune" integer,
    "id_province" integer,
    "id_user_creat" integer,
    "id_user_modif" integer,
    "date_creation" timestamptz,
    "date_modif" timestamptz,
    "is_deleted" boolean DEFAULT false,
    "is_validated" boolean DEFAULT false,
    "id_user_valid" integer,
    "date_validation" timestamp,
    "emplacement" varchar(400),
    "ep_ref_rue" varchar(400),
    "ep_section" varchar(400),
    "ep_tampon" varchar(400),
    "ep_conf_plan" varchar(400),
    "ep_observation" varchar(400),
    "ep_anomalie" boolean DEFAULT false,
    "mode_localisation" varchar(400) DEFAULT 'Levé topographique',
    "echelon" varchar(400),
    "anomalie_tamp" varchar(400),
    "anomalie_regard" varchar(400),
    "GENRATRICE_SUP" double precision,
    "ep_profondeur" double precision,
    "z levée par gps va correspondre a z surface ou z radier." zsurface,
    "Règles de gestion" varchar(400),
    CONSTRAINT "regard_pret_ep_statut_chk" CHECK ("ep_statut" IN ('EP_POSE', 'EP_REHABILITE', 'EP_EXISTANT', 'EP_PROJETE', 'EP_A REHABI', 'EP_EN COURSS', 'EP_A RESILISE')),
    CONSTRAINT "regard_pret_emplacement_chk" CHECK ("emplacement" IN ('S-TROTTOIR', 'S-CHAUSSEE', 'S-TROTOIR C-CHAISSI', 'TN', 'PISTE', 'TERRE_AGRICOLE')),
    CONSTRAINT "regard_pret_ep_tampon_chk" CHECK ("ep_tampon" IN ('FD400', 'FD250', 'Béton')),
    CONSTRAINT "regard_pret_ep_conf_plan_chk" CHECK ("ep_conf_plan" IN ('Conforme aux plan', 'Objet découvrt sur terrain', 'Objet non trouvé sur le terrain')),
    CONSTRAINT "regard_pret_mode_localisation_chk" CHECK ("mode_localisation" IN ('Levé topographique', 'Triangulé', 'Schématique', 'Indéterminé')),
    CONSTRAINT "regard_pret_echelon_chk" CHECK ("echelon" IN ('O', 'N')),
    CONSTRAINT "regard_pret_anomalie_tamp_chk" CHECK ("anomalie_tamp" IN ('Tampons en mauvais état', 'Tampons Manquant', 'Tampons Scellés')),
    CONSTRAINT "regard_pret_anomalie_regard_chk" CHECK ("anomalie_regard" IN ('A mettre à la cote', 'Inaccessible', 'Ouvrage dégradés', 'Regards Enterrés', 'Regards Noyés', 'Regards à curer', 'Sectionnement enterré', 'Autre'))
);

COMMENT ON TABLE "ep"."regard_pret" IS 'Generated from ep_regard_pret.csv';
COMMENT ON COLUMN "ep"."regard_pret"."ep_agent" IS 'Titre mobile: Dernier intervenant SIG | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_sect_com" IS 'Titre mobile: Secteur commercial | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_statut" IS 'Titre mobile: Statut | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_adresse" IS 'Titre mobile: Adresse | Valeur par defaut interpretee comme note: Réécrire la valeur depuis ep_ref_rue | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_agent_crea" IS 'Titre mobile: Agent de création SIG | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."sec_com" IS 'Titre mobile: SEC_COM | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."sect_hydr" IS 'Titre mobile: Secteur hydraulique | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."zone" IS 'Titre mobile: Zone hydraulique | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."fid" IS 'Titre mobile: ID lisible serveur | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."uuid" IS 'Titre mobile: UUID objet | Valeur par defaut interpretee comme note: se génère en version 4 depuis le mobile | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."z_radier" IS 'Titre mobile: Côte radier | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."z_surf" IS 'Titre mobile: Côte surface | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_date_insertion" IS 'Titre mobile: Date d''insertion Elyx | Valeur par defaut interpretee comme note: on remplit avec date_creation | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_coor_x" IS 'Titre mobile: Coordonnée X | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_coor_y" IS 'Titre mobile: Coordonnée Y | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_coor_z" IS 'Titre mobile: Coordonnée Z | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."geom" IS 'Titre mobile: Géométrie | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."id_commune" IS 'Titre mobile: Commune | Valeur par defaut interpretee comme note: public.commune.fid | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."id_province" IS 'Titre mobile: Province | Valeur par defaut interpretee comme note: public.province.fid | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."id_user_creat" IS 'Titre mobile: Utilisateur créateur | Valeur par defaut interpretee comme note: public.utilisateur.id_user | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."id_user_modif" IS 'Titre mobile: Dernier utilisateur modificateur | Valeur par defaut interpretee comme note: public.utilisateur.id_user | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."date_creation" IS 'Titre mobile: Date de création | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."date_modif" IS 'Titre mobile: Date de modification | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."is_deleted" IS 'Titre mobile: Suppression logique | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."is_validated" IS 'Titre mobile: Validation exploitant | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."id_user_valid" IS 'Titre mobile: Utilisateur validateur | Valeur par defaut interpretee comme note: public.utilisateur.id_user | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."date_validation" IS 'Titre mobile: Date de validation | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."emplacement" IS 'Titre mobile: Emplacement du regard | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_ref_rue" IS 'Titre mobile: Référence rue / Douar | Liste de choix non enforcee en CHECK: REF RUE / DOUAR | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_section" IS 'Titre mobile: Section du regard | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_tampon" IS 'Titre mobile: Type de tampon | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_conf_plan" IS 'Titre mobile: Conformité au plan | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_observation" IS 'Titre mobile: Observation | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_anomalie" IS 'Titre mobile: Anomalie | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."mode_localisation" IS 'Titre mobile: Mode de localisation | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."echelon" IS 'Titre mobile: Existence échelon | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."anomalie_tamp" IS 'Titre mobile: Anomalie tampon | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."anomalie_regard" IS 'Titre mobile: Anomalie regard | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."GENRATRICE_SUP" IS 'Titre mobile: Génératrice supérieure | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."ep_profondeur" IS 'Titre mobile: Profondeur | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."z levée par gps va correspondre a z surface ou z radier." IS 'Titre mobile: Z levée par gps va correspondre a z surface ou z radier. | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
COMMENT ON COLUMN "ep"."regard_pret"."Règles de gestion" IS 'Titre mobile: Règles de gestion | Type SQL infere a partir du CSV | Source: feuille pre-formatee sans code couleur | Obligatoire derive du champ Null faute de colonne obligatoire dediee';
