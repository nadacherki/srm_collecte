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
