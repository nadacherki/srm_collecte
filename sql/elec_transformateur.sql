-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_transformateur.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."transformateur" (
    "puiss_transfo" varchar(254),
    "regleur_en_charge" varchar(254),
    "anomalie" boolean DEFAULT false,
    CONSTRAINT "transformateur_puiss_transfo_chk" CHECK ("puiss_transfo" IN ('kVA'))
);

COMMENT ON TABLE "elec"."transformateur" IS 'Generated from elec_transformateur.csv';
COMMENT ON COLUMN "elec"."transformateur"."puiss_transfo" IS 'Titre mobile: Puiss Transfo | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Puissance transfo (kVA)';
COMMENT ON COLUMN "elec"."transformateur"."regleur_en_charge" IS 'Titre mobile: Regleur En Charge | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Regleur en charge';
COMMENT ON COLUMN "elec"."transformateur"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';
