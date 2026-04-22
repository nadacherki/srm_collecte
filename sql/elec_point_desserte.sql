-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_point_desserte.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."point_desserte" (
    "boite_coupure" varchar(254),
    "conformite_plan" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "elec"."point_desserte" IS 'Generated from elec_point_desserte.csv';
COMMENT ON COLUMN "elec"."point_desserte"."boite_coupure" IS 'Titre mobile: Boite Coupure | Liste de choix non enforcee en CHECK: Aucune, Fonte, Métal, Niche, Polyester, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Boite coupure';
COMMENT ON COLUMN "elec"."point_desserte"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "elec"."point_desserte"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';
