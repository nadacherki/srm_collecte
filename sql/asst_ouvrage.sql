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
