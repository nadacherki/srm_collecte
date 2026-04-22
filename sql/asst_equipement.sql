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
