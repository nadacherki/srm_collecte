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
