-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_support.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."support" (
    "type_support" varchar(254),
    "etat_support" varchar(254),
    "type_assemblage" varchar(254),
    "type_protection" varchar(254),
    "mise_a_la_terre" varchar(254),
    "type_balise" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "elec"."support" IS 'Generated from elec_support.csv';
COMMENT ON COLUMN "elec"."support"."type_support" IS 'Titre mobile: Type Support | Liste de choix non enforcee en CHECK: Candélabre, Candélabre Courbe, Mât, Potelet Ambiance, Potelet Réseau, Façade, Poteau | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type support (beton, bois, metallique...)';
COMMENT ON COLUMN "elec"."support"."etat_support" IS 'Titre mobile: Etat Support | Liste de choix non enforcee en CHECK: Bon, Moyen, Mauvais, Dangereux à changer | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Etat support';
COMMENT ON COLUMN "elec"."support"."type_assemblage" IS 'Titre mobile: Type Assemblage | Liste de choix non enforcee en CHECK: Simple, Jumelé, Contre Fiché, Haubané, Double | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type assemblage';
COMMENT ON COLUMN "elec"."support"."type_protection" IS 'Titre mobile: Type Protection | Liste de choix non enforcee en CHECK: Pas de protection, Fusible, Fusible cartouche, Fusible HPC, Fusible couteau, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type protection';
COMMENT ON COLUMN "elec"."support"."mise_a_la_terre" IS 'Titre mobile: Mise A La Terre | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Mise a la terre';
COMMENT ON COLUMN "elec"."support"."type_balise" IS 'Titre mobile: Type Balise | Liste de choix non enforcee en CHECK: Ballon, Encrage, Arrêt, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type balise';
COMMENT ON COLUMN "elec"."support"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';
