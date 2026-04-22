-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_cellule.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."cellule" (
    "fonction" varchar(254),
    "type_commande" varchar(254)
);

COMMENT ON TABLE "elec"."cellule" IS 'Generated from elec_cellule.csv';
COMMENT ON COLUMN "elec"."cellule"."fonction" IS 'Titre mobile: Fonction | Liste de choix non enforcee en CHECK: Départ, Arrivée, Couplage, Condensateur, Interrupteur, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Fonction objet';
COMMENT ON COLUMN "elec"."cellule"."type_commande" IS 'Titre mobile: Type Commande | Liste de choix non enforcee en CHECK: Cellule, Horloge, Horloge Astro., Pulsadis, Manuel, Télécommandé, Aucune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type commande (manuelle, electrique...)';
