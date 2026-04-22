-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_coffret_bt.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."coffret_bt" (
    "type_coffret" varchar(254),
    "statut_coffret" varchar(254),
    "enveloppe_coffret" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "elec"."coffret_bt" IS 'Generated from elec_coffret_bt.csv';
COMMENT ON COLUMN "elec"."coffret_bt"."type_coffret" IS 'Titre mobile: Type Coffret | Liste de choix non enforcee en CHECK: Paninter, Soclinter, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type coffret BT';
COMMENT ON COLUMN "elec"."coffret_bt"."statut_coffret" IS 'Titre mobile: Statut Coffret | Liste de choix non enforcee en CHECK: En service, Hors service, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Statut coffret';
COMMENT ON COLUMN "elec"."coffret_bt"."enveloppe_coffret" IS 'Titre mobile: Enveloppe Coffret | Liste de choix non enforcee en CHECK: Polyester, Métallique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Enveloppe coffret';
COMMENT ON COLUMN "elec"."coffret_bt"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';
