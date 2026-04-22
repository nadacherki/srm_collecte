-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_depart_bt.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."depart_bt" (
    "tension_bt" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "elec"."depart_bt" IS 'Generated from elec_depart_bt.csv';
COMMENT ON COLUMN "elec"."depart_bt"."tension_bt" IS 'Titre mobile: Tension Bt | Liste de choix non enforcee en CHECK: B1, B2, B1/B2 | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Tension BT';
COMMENT ON COLUMN "elec"."depart_bt"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';
