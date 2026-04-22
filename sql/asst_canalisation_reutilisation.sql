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
