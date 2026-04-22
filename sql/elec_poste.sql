-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_poste.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."poste" (
    "nature_poste" varchar(254),
    "etat_service" varchar(254),
    "tableau_ep" varchar(254),
    "support_communication" varchar(254),
    "presence_ild" varchar(254),
    "tableau_bt" varchar(254),
    "conformite_plan" varchar(254)
);

COMMENT ON TABLE "elec"."poste" IS 'Generated from elec_poste.csv';
COMMENT ON COLUMN "elec"."poste"."nature_poste" IS 'Titre mobile: Nature Poste | Liste de choix non enforcee en CHECK: Maçonné, Préfabriqué, Abrité, Intégré bâtiment | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Nature poste';
COMMENT ON COLUMN "elec"."poste"."etat_service" IS 'Titre mobile: Etat Service | Liste de choix non enforcee en CHECK: En service, Hors service, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Etat service poste';
COMMENT ON COLUMN "elec"."poste"."tableau_ep" IS 'Titre mobile: Tableau Ep | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Tableau EP (oui/non)';
COMMENT ON COLUMN "elec"."poste"."support_communication" IS 'Titre mobile: Support Communication | Liste de choix non enforcee en CHECK: GSM, LS, Radio, GPRS, LS & GSM, LS & RADIO, 4G, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Support communication (GSM, fibre...)';
COMMENT ON COLUMN "elec"."poste"."presence_ild" IS 'Titre mobile: Presence Ild | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Indicateur lumineux defaut';
COMMENT ON COLUMN "elec"."poste"."tableau_bt" IS 'Titre mobile: Tableau Bt | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Tableau BT';
COMMENT ON COLUMN "elec"."poste"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
