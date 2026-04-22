-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_troncon_hta.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."troncon_hta" (
    "status_troncon" varchar(254),
    "metal_conduct" varchar(254),
    "type_mise_terre" varchar(254),
    "tension" varchar(254),
    CONSTRAINT "troncon_hta_metal_conduct_chk" CHECK ("metal_conduct" IN ('Alu-acier', 'Alu', 'Almélec', 'Cuivre', 'LA, LR'))
);

COMMENT ON TABLE "elec"."troncon_hta" IS 'Generated from elec_troncon_hta.csv';
COMMENT ON COLUMN "elec"."troncon_hta"."status_troncon" IS 'Titre mobile: Status Troncon | Liste de choix non enforcee en CHECK: En service, Hors service, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Statut troncon';
COMMENT ON COLUMN "elec"."troncon_hta"."metal_conduct" IS 'Titre mobile: Metal Conduct | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Metal conducteur (cuivre, alu...)';
COMMENT ON COLUMN "elec"."troncon_hta"."type_mise_terre" IS 'Titre mobile: Type Mise Terre | Liste de choix non enforcee en CHECK: Inexistant, Continu, En Dérivation, Piquet | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type mise a la terre';
COMMENT ON COLUMN "elec"."troncon_hta"."tension" IS 'Titre mobile: Tension | Liste de choix non enforcee en CHECK: 225kV, 60kV, 20kV, 11kV, 5.5kV, 400V | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Niveau tension';
