-- PostgreSQL bundle for schema asst

-- Source: asst_bassin.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_bassin.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."bassin" (
    "conformite_plan" varchar(254),
    "type_bassin" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "asst"."bassin" IS 'Generated from asst_bassin.csv';
COMMENT ON COLUMN "asst"."bassin"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."bassin"."type_bassin" IS 'Titre mobile: Type Bassin | Liste de choix non enforcee en CHECK: Bassin stockage enterré, Bassin stockage ciel ouvert | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type bassin (retention, decantation...)';
COMMENT ON COLUMN "asst"."bassin"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';

-- Source: asst_branchement.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_branchement.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."branchement" (
    "conformite_plan" varchar(254),
    "etat" varchar(254),
    "typereseau" varchar(254),
    "rehabilitation" varchar(254),
    "type_activite" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "asst"."branchement" IS 'Generated from asst_branchement.csv';
COMMENT ON COLUMN "asst"."branchement"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."branchement"."etat" IS 'Titre mobile: Etat | Liste de choix non enforcee en CHECK: En service, Hors service, Réhabilité, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Etat general (bon, moyen, mauvais...)';
COMMENT ON COLUMN "asst"."branchement"."typereseau" IS 'Titre mobile: Typereseau | Liste de choix non enforcee en CHECK: Eaux usées, Eaux pluviales, Unitaire, Irrigation, Pseudo-séparatif | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type reseau (unitaire, separatif, pluvial...)';
COMMENT ON COLUMN "asst"."branchement"."rehabilitation" IS 'Titre mobile: Rehabilitation | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Rehabilitation effectuee (oui/non)';
COMMENT ON COLUMN "asst"."branchement"."type_activite" IS 'Titre mobile: Type Activite | Liste de choix non enforcee en CHECK: Domestique, Industrielle, Equip. sanitaires, Poissonneries, Hotels/restaurants, Hydrocarbures, Chimiques, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type activite branchement';
COMMENT ON COLUMN "asst"."branchement"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';

-- Source: asst_canalisation_bureau.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_canalisation_bureau.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."canalisation_bureau" (
    "classe" varchar(254),
    "nature" varchar(254),
    "type_ecoulement" varchar(254),
    "type_conduite" varchar(254),
    "protection_anticorrosion" varchar(254)
);

COMMENT ON TABLE "asst"."canalisation_bureau" IS 'Generated from asst_canalisation_bureau.csv';
COMMENT ON COLUMN "asst"."canalisation_bureau"."classe" IS 'Titre mobile: Classe | Liste de choix non enforcee en CHECK: K7, K9, K10, 135A, 190A, 90A, CR8, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Classe conduite/canalisation';
COMMENT ON COLUMN "asst"."canalisation_bureau"."nature" IS 'Titre mobile: Nature | Liste de choix non enforcee en CHECK: Amiante ciment, PEHD, Fonte, PVC, CAO, Béton vibré, Béton vibré armé, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Nature du materiau';
COMMENT ON COLUMN "asst"."canalisation_bureau"."type_ecoulement" IS 'Titre mobile: Type Ecoulement | Liste de choix non enforcee en CHECK: Gravitaire, Sous pression | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type ecoulement (gravitaire, sous pression...)';
COMMENT ON COLUMN "asst"."canalisation_bureau"."type_conduite" IS 'Titre mobile: Type Conduite | Liste de choix non enforcee en CHECK: Circulaire, Cadre, Ovoïde, Arche, En U, Trapézoïde, Quelconque, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type conduite';
COMMENT ON COLUMN "asst"."canalisation_bureau"."protection_anticorrosion" IS 'Titre mobile: Protection Anticorrosion | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Protection anticorrosion';

-- Source: asst_canalisation_reutilisation.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_canalisation_reutilisation.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."canalisation_reutilisation" (
    "conformite_plan" varchar(254),
    "etat" varchar(254),
    "type_ecoulement" varchar(254)
);

COMMENT ON TABLE "asst"."canalisation_reutilisation" IS 'Generated from asst_canalisation_reutilisation.csv';
COMMENT ON COLUMN "asst"."canalisation_reutilisation"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."canalisation_reutilisation"."etat" IS 'Titre mobile: Etat | Liste de choix non enforcee en CHECK: En service, Hors service, Réhabilité, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Etat general (bon, moyen, mauvais...)';
COMMENT ON COLUMN "asst"."canalisation_reutilisation"."type_ecoulement" IS 'Titre mobile: Type Ecoulement | Liste de choix non enforcee en CHECK: Gravitaire, Sous pression | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type ecoulement (gravitaire, sous pression...)';

-- Source: asst_canalisation_terrain.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_canalisation_terrain.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."canalisation_terrain" (
    "conformite_plan" varchar(254),
    "etat" varchar(254),
    "typereseau" varchar(254),
    "rehabilitation" varchar(254),
    "emplacement" varchar(254),
    "type_section" varchar(254),
    "type_rehabilitation" varchar(254)
);

COMMENT ON TABLE "asst"."canalisation_terrain" IS 'Generated from asst_canalisation_terrain.csv';
COMMENT ON COLUMN "asst"."canalisation_terrain"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."canalisation_terrain"."etat" IS 'Titre mobile: Etat | Liste de choix non enforcee en CHECK: En service, Hors service, Réhabilité, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Etat general (bon, moyen, mauvais...)';
COMMENT ON COLUMN "asst"."canalisation_terrain"."typereseau" IS 'Titre mobile: Typereseau | Liste de choix non enforcee en CHECK: Eaux usées, Eaux pluviales, Unitaire, Irrigation, Pseudo-séparatif | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type reseau (unitaire, separatif, pluvial...)';
COMMENT ON COLUMN "asst"."canalisation_terrain"."rehabilitation" IS 'Titre mobile: Rehabilitation | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Rehabilitation effectuee (oui/non)';
COMMENT ON COLUMN "asst"."canalisation_terrain"."emplacement" IS 'Titre mobile: Emplacement | Liste de choix non enforcee en CHECK: Chaussée, Trottoir, Accotement, Privé, Terrain naturel, Terrain agricole, Espace vert, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Emplacement (chaussee, trottoir...)';
COMMENT ON COLUMN "asst"."canalisation_terrain"."type_section" IS 'Titre mobile: Type Section | Liste de choix non enforcee en CHECK: Section fermée, Section à ciel ouvert | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type section (circulaire, ovoide...)';
COMMENT ON COLUMN "asst"."canalisation_terrain"."type_rehabilitation" IS 'Titre mobile: Type Rehabilitation | Liste de choix non enforcee en CHECK: TRANCHE, CHEMISAGE, GAINAGE, TUBAGE, ECLATEMENT | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type rehabilitation';

-- Source: asst_equipement.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_equipement.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."equipement" (
    "conformite_plan" varchar(254),
    "typereseau" varchar(254),
    "situation_equipement" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "asst"."equipement" IS 'Generated from asst_equipement.csv';
COMMENT ON COLUMN "asst"."equipement"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."equipement"."typereseau" IS 'Titre mobile: Typereseau | Liste de choix non enforcee en CHECK: Eaux usées, Eaux pluviales, Unitaire, Irrigation, Pseudo-séparatif | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type reseau (unitaire, separatif, pluvial...)';
COMMENT ON COLUMN "asst"."equipement"."situation_equipement" IS 'Titre mobile: Situation Equipement | Liste de choix non enforcee en CHECK: En service, Hors service | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Situation (en service, hors service...)';
COMMENT ON COLUMN "asst"."equipement"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';

-- Source: asst_ouvrage.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_ouvrage.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."ouvrage" (
    "conformite_plan" varchar(254),
    "type_ouvrage" varchar(254),
    "pretraitement" varchar(254)
);

COMMENT ON TABLE "asst"."ouvrage" IS 'Generated from asst_ouvrage.csv';
COMMENT ON COLUMN "asst"."ouvrage"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."ouvrage"."type_ouvrage" IS 'Titre mobile: Type Ouvrage | Liste de choix non enforcee en CHECK: Déversoir d''orage, Ouvrage traverse, Fosse septique, Puit perdu, Puit infiltration, Exutoire, Déshuileur | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type ouvrage';
COMMENT ON COLUMN "asst"."ouvrage"."pretraitement" IS 'Titre mobile: Pretraitement | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence pretraitement';

-- Source: asst_regard.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_regard.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."regard" (
    "conformite_plan" varchar(254),
    "type_regard" varchar(254),
    "typereseau" varchar(254),
    "forme" varchar(254),
    "verrouille" varchar(254),
    "rehabilitation" varchar(254),
    "nature_corps" varchar(254),
    "chute" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "asst"."regard" IS 'Generated from asst_regard.csv';
COMMENT ON COLUMN "asst"."regard"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."regard"."type_regard" IS 'Titre mobile: Type regard | Liste de choix non enforcee en CHECK: Regard de visite, Regard borgne, Regard avaloir, Grille avaloir | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type regard (visite, chasse, cascade...)';
COMMENT ON COLUMN "asst"."regard"."typereseau" IS 'Titre mobile: Typereseau | Liste de choix non enforcee en CHECK: Eaux usées, Eaux pluviales, Unitaire, Irrigation, Pseudo-séparatif | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type reseau (unitaire, separatif, pluvial...)';
COMMENT ON COLUMN "asst"."regard"."forme" IS 'Titre mobile: Forme | Liste de choix non enforcee en CHECK: Circulaire, Rectangulaire, Carré | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Forme (circulaire, rectangulaire...)';
COMMENT ON COLUMN "asst"."regard"."verrouille" IS 'Titre mobile: Verrouille | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Tampon verrouille (oui/non)';
COMMENT ON COLUMN "asst"."regard"."rehabilitation" IS 'Titre mobile: Rehabilitation | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Rehabilitation effectuee (oui/non)';
COMMENT ON COLUMN "asst"."regard"."nature_corps" IS 'Titre mobile: Nature Corps | Liste de choix non enforcee en CHECK: Béton, Préfabriqué, Maçonnerie, Brique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Nature corps regard';
COMMENT ON COLUMN "asst"."regard"."chute" IS 'Titre mobile: Chute | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence chute';
COMMENT ON COLUMN "asst"."regard"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';

-- Source: asst_regard_branchement.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_regard_branchement.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."regard_branchement" (
    "conformite_plan" varchar(254),
    "type_tampon" varchar(254),
    "classe_tampon" varchar(254),
    "accessibilite" varchar(254),
    "rehabilitation" varchar(254),
    "nature_corps" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "asst"."regard_branchement" IS 'Generated from asst_regard_branchement.csv';
COMMENT ON COLUMN "asst"."regard_branchement"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."regard_branchement"."type_tampon" IS 'Titre mobile: Type Tampon | Liste de choix non enforcee en CHECK: Fonte grise, Fonte ductile, Béton, Composite, Trappe | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type tampon';
COMMENT ON COLUMN "asst"."regard_branchement"."classe_tampon" IS 'Titre mobile: Classe Tampon | Liste de choix non enforcee en CHECK: D400, C25, B125, CL400, C250, E600 | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Classe resistance tampon';
COMMENT ON COLUMN "asst"."regard_branchement"."accessibilite" IS 'Titre mobile: Accessibilite | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Accessibilite';
COMMENT ON COLUMN "asst"."regard_branchement"."rehabilitation" IS 'Titre mobile: Rehabilitation | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Rehabilitation effectuee (oui/non)';
COMMENT ON COLUMN "asst"."regard_branchement"."nature_corps" IS 'Titre mobile: Nature Corps | Liste de choix non enforcee en CHECK: Béton, Préfabriqué, Maçonnerie, Brique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Nature corps regard';
COMMENT ON COLUMN "asst"."regard_branchement"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';

-- Source: asst_station.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_station.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."station" (
    "conformite_plan" varchar(254),
    "etat" varchar(254),
    "sortie" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "asst"."station" IS 'Generated from asst_station.csv';
COMMENT ON COLUMN "asst"."station"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."station"."etat" IS 'Titre mobile: Etat | Liste de choix non enforcee en CHECK: En service, Hors service, Réhabilité, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Etat general (bon, moyen, mauvais...)';
COMMENT ON COLUMN "asst"."station"."sortie" IS 'Titre mobile: Sortie | Liste de choix non enforcee en CHECK: Aucun dispositif, Vers réseau, Vers milieu naturel, Vers puit infiltration | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type sortie';
COMMENT ON COLUMN "asst"."station"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';
