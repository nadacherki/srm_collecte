-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_troncon_bt.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."troncon_bt" (
    "techcable" varchar(254),
    "status_troncon" varchar(254),
    "nu" varchar(254),
    "arme" varchar(254)
);

COMMENT ON TABLE "elec"."troncon_bt" IS 'Generated from elec_troncon_bt.csv';
COMMENT ON COLUMN "elec"."troncon_bt"."techcable" IS 'Titre mobile: Techcable | Liste de choix non enforcee en CHECK: Cuivre, Tors BT Alu, Armé cuivre, Armé Alu, Alu | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Technologie cable';
COMMENT ON COLUMN "elec"."troncon_bt"."status_troncon" IS 'Titre mobile: Status Troncon | Liste de choix non enforcee en CHECK: En service, Hors service, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Statut troncon';
COMMENT ON COLUMN "elec"."troncon_bt"."nu" IS 'Titre mobile: Nu | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Nu (oui/non)';
COMMENT ON COLUMN "elec"."troncon_bt"."arme" IS 'Titre mobile: Arme | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Cable arme';
