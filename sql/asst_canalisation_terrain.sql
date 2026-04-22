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
