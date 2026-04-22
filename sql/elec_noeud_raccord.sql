-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_noeud_raccord.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."noeud_raccord" (
    "type_raccord" varchar(254),
    "conformite_plan" varchar(254)
);

COMMENT ON TABLE "elec"."noeud_raccord" IS 'Generated from elec_noeud_raccord.csv';
COMMENT ON COLUMN "elec"."noeud_raccord"."type_raccord" IS 'Titre mobile: Type Raccord | Liste de choix non enforcee en CHECK: Boîte Jonction, Chgt Section, Remontée aéro-sout., Noeud Etoilement, Limite tronçon, Arrêt ligne, Pt ouverture | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type raccordement';
COMMENT ON COLUMN "elec"."noeud_raccord"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';
