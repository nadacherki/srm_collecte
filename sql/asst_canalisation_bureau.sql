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
