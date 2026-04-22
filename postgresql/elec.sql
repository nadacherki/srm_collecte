-- PostgreSQL bundle for schema elec

-- Source: elec_cellule.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_cellule.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."cellule" (
    "fonction" varchar(254),
    "type_commande" varchar(254)
);

COMMENT ON TABLE "elec"."cellule" IS 'Generated from elec_cellule.csv';
COMMENT ON COLUMN "elec"."cellule"."fonction" IS 'Titre mobile: Fonction | Liste de choix non enforcee en CHECK: Départ, Arrivée, Couplage, Condensateur, Interrupteur, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Fonction objet';
COMMENT ON COLUMN "elec"."cellule"."type_commande" IS 'Titre mobile: Type Commande | Liste de choix non enforcee en CHECK: Cellule, Horloge, Horloge Astro., Pulsadis, Manuel, Télécommandé, Aucune | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type commande (manuelle, electrique...)';

-- Source: elec_coffret_bt.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_coffret_bt.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."coffret_bt" (
    "type_coffret" varchar(254),
    "statut_coffret" varchar(254),
    "enveloppe_coffret" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "elec"."coffret_bt" IS 'Generated from elec_coffret_bt.csv';
COMMENT ON COLUMN "elec"."coffret_bt"."type_coffret" IS 'Titre mobile: Type Coffret | Liste de choix non enforcee en CHECK: Paninter, Soclinter, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type coffret BT';
COMMENT ON COLUMN "elec"."coffret_bt"."statut_coffret" IS 'Titre mobile: Statut Coffret | Liste de choix non enforcee en CHECK: En service, Hors service, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Statut coffret';
COMMENT ON COLUMN "elec"."coffret_bt"."enveloppe_coffret" IS 'Titre mobile: Enveloppe Coffret | Liste de choix non enforcee en CHECK: Polyester, Métallique | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Enveloppe coffret';
COMMENT ON COLUMN "elec"."coffret_bt"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';

-- Source: elec_depart_bt.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_depart_bt.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."depart_bt" (
    "tension_bt" varchar(254),
    "anomalie" boolean DEFAULT false
);

COMMENT ON TABLE "elec"."depart_bt" IS 'Generated from elec_depart_bt.csv';
COMMENT ON COLUMN "elec"."depart_bt"."tension_bt" IS 'Titre mobile: Tension Bt | Liste de choix non enforcee en CHECK: B1, B2, B1/B2 | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Tension BT';
COMMENT ON COLUMN "elec"."depart_bt"."anomalie" IS 'Titre mobile: Anomalie | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Presence d''anomalie';

-- Source: elec_depart_hta.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_depart_hta.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."depart_hta" (
    "tension_hta" varchar(254)
);

COMMENT ON TABLE "elec"."depart_hta" IS 'Generated from elec_depart_hta.csv';
COMMENT ON COLUMN "elec"."depart_hta"."tension_hta" IS 'Titre mobile: Tension Hta | Liste de choix non enforcee en CHECK: 225kV, 60kV, 20kV, 11kV, 5.5kV, 400V | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Tension HTA';

-- Source: elec_noeud_raccord.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_noeud_raccord.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."noeud_raccord" (
    "type_raccord" varchar(254),
    "conformite_plan" varchar(254)
);

COMMENT ON TABLE "elec"."noeud_raccord" IS 'Generated from elec_noeud_raccord.csv';
COMMENT ON COLUMN "elec"."noeud_raccord"."type_raccord" IS 'Titre mobile: Type Raccord | Liste de choix non enforcee en CHECK: Boîte Jonction, Chgt Section, Remontée aéro-sout., Noeud Etoilement, Limite tronçon, Arrêt ligne, Pt ouverture | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Type raccordement';
COMMENT ON COLUMN "elec"."noeud_raccord"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';

-- Source: elec_point_desserte.sql
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

-- Source: elec_poste.sql
-- Source CSV: C:\Users\ANASDA~1\AppData\Local\Temp\branch-mobile-csvs-to-sql-q9ebsno3\csv\elec_poste.csv
CREATE SCHEMA IF NOT EXISTS "elec";

CREATE TABLE IF NOT EXISTS "elec"."poste" (
    "nature_poste" varchar(254),
    "etat_service" varchar(254),
    "tableau_ep" varchar(254),
    "support_communication" varchar(254),
    "presence_ild" varchar(254),
    "tableau_bt" varchar(254),
    "conformite_plan" varchar(254)
);

COMMENT ON TABLE "elec"."poste" IS 'Generated from elec_poste.csv';
COMMENT ON COLUMN "elec"."poste"."nature_poste" IS 'Titre mobile: Nature Poste | Liste de choix non enforcee en CHECK: Maçonné, Préfabriqué, Abrité, Intégré bâtiment | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Nature poste';
COMMENT ON COLUMN "elec"."poste"."etat_service" IS 'Titre mobile: Etat Service | Liste de choix non enforcee en CHECK: En service, Hors service, Abandonné | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Etat service poste';
COMMENT ON COLUMN "elec"."poste"."tableau_ep" IS 'Titre mobile: Tableau Ep | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Tableau EP (oui/non)';
COMMENT ON COLUMN "elec"."poste"."support_communication" IS 'Titre mobile: Support Communication | Liste de choix non enforcee en CHECK: GSM, LS, Radio, GPRS, LS & GSM, LS & RADIO, 4G, Autre | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Support communication (GSM, fibre...)';
COMMENT ON COLUMN "elec"."poste"."presence_ild" IS 'Titre mobile: Presence Ild | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Indicateur lumineux defaut';
COMMENT ON COLUMN "elec"."poste"."tableau_bt" IS 'Titre mobile: Tableau Bt | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Tableau BT';
COMMENT ON COLUMN "elec"."poste"."conformite_plan" IS 'Titre mobile: Conformite Plan | Liste de choix non enforcee en CHECK: Oui, Non | Mode de remplissage: pre-rempli / automatique / relation spatiale selon le code couleur source | Description: Conformite avec plans existants';

-- Source: elec_support.sql
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

-- Source: elec_transformateur.sql
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

-- Source: elec_troncon_bt.sql
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

-- Source: elec_troncon_hta.sql
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
