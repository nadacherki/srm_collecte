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
