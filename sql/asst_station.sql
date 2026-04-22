-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\asst_station.csv
CREATE SCHEMA IF NOT EXISTS "asst";

CREATE TABLE IF NOT EXISTS "asst"."station" (
    "conformite_plan" varchar(254),
    "etat" varchar(254),
    "sortie" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "asst"."station" IS 'Generated from asst_station.csv';
COMMENT ON COLUMN "asst"."station"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
COMMENT ON COLUMN "asst"."station"."etat" IS 'Titre mobile: Etat | Liste de choix non enforcee en CHECK: En service, Hors service, Réhabilité, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Etat general (bon, moyen, mauvais...)';
COMMENT ON COLUMN "asst"."station"."sortie" IS 'Titre mobile: Sortie | Liste de choix non enforcee en CHECK: Aucun dispositif, Vers réseau, Vers milieu naturel, Vers puit infiltration | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type sortie';
COMMENT ON COLUMN "asst"."station"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';
