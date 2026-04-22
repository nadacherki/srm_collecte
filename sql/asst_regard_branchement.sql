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
