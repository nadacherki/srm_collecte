-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_depart_hta.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."depart_hta" (
    "tension_hta" varchar(254)
);

COMMENT ON TABLE "elec"."depart_hta" IS 'Generated from elec_depart_hta.csv';
COMMENT ON COLUMN "elec"."depart_hta"."tension_hta" IS 'Titre mobile: Tension Hta | Liste de choix non enforcee en CHECK: 225kV, 60kV, 20kV, 11kV, 5.5kV, 400V | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Tension HTA';
