// lib/core/config/srm_config.dart
// Configuration centrale des entités SRM (Eau Potable, Assainissement, Électricité)
// Configuration centrale des entites SRM
// Chaque entité correspond à une table PostGIS (schéma ep, ass, elec)
//
// ── SPRINT 6 — Modifications ──
//  • uuid retiré de tous les fields (généré automatiquement par Uuid().v4())
//  • requiredFields ajouté par entité (champs marqués * dans le formulaire)
//  • isRequiredField() méthode utilitaire ajoutée
//  • Les coordonnées coor_x / coor_y sont auto (GPS) → pas dans requiredFields
//    mais le formulaire les affiche en readOnly avec suffixe GPS

class SrmConfig {
  static const Map<String, Map<String, dynamic>> config = {
    // ── EAU POTABLE (schéma ep) ──
    "Eau Potable": {
      "icon": "water_drop",
      "color": 0xFF2196F3,
      "schema": "ep",
      "entities": {
        "Vanne": {
          "tableName": "vanne", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": ["Vanne de sectionnement", "Vanne de régulation", "Vanne papillon", "Vanne à opercule", "Autre"],
          // uuid retiré — généré automatiquement
          "fields": ["ep_num","ep_type","ep_modele","ep_marque","ep_diam","ep_ref_regard","ep_sens_ferm","ep_manoeuvre","ep_etat","ep_sectionnement","emplacement","ep_ref","ref_rue","ep_entreprise","ep_ref_marche","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_type","ep_etat","conformite_plan"],
        },
        "Vanne de Vidange": {
          "tableName": "vanne_de_vidange", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_modele","ep_marque","ep_diam","ep_etat","emplacement","ep_ref","ref_rue","ep_entreprise","ep_ref_marche","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_etat","conformite_plan"],
        },
        "Ventouse": {
          "tableName": "ventouse", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_modele","ep_marque","ep_diam","ep_ref_regard","emplacement","ep_ref","ref_rue","ep_entreprise","ep_ref_marche","ep_date_interv","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_type","conformite_plan"],
        },
        "Hydrant": {
          "tableName": "hydrant", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": ["Poteau d'incendie", "Bouche d'incendie"],
          "fields": ["ep_num","ep_type","marque","ep_diam","ep_etat","emplacement","ep_ref","ref_rue","ep_entreprise","ep_ref_marche","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_type","ep_etat","conformite_plan"],
        },
        "Borne Fontaine": {
          "tableName": "borne_fontaine", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","marque","ep_etat","ep_diam","ep_ref","ref_rue","emplacement","ep_entreprise","ep_ref_marche","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_etat","conformite_plan"],
        },
        "Borne ONEP": {
          "tableName": "borne_onep", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 0,
          "typeField": null, "typeOptions": [],
          "fields": ["observation","date_leve","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["conformite_plan"],
        },
        "Bouche à Clé": {
          "tableName": "bouche_cles", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 0,
          "typeField": null, "typeOptions": [],
          "fields": ["date_leve","observation","ep_coor_z","conformite_plan"],
          "requiredFields": ["conformite_plan"],
        },
        "Bouche d'Arrosage": {
          "tableName": "bouche_darrosage", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_marque","ep_etat","ep_ref","ref_rue","emplacement","ep_entreprise","ep_ref_marche","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_etat","conformite_plan"],
        },
        "Compteur Réseau": {
          "tableName": "compteur_reseau", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_modele","ep_marque","ep_calibre","ep_sourc_alim","ep_ref_regard","ep_releve","ep_res_deserv","ep_n_serie","ep_compt_fonction","ep_ref","ref_rue","ep_entreprise","ep_ref_marche","etage_aqua","secteur_aqua","ep_statut","ep_ref_mm","ep_mm","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_type","conformite_plan"],
        },
        "Compteur Abonné": {
          "tableName": "compteur_abonne", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": null, "typeOptions": [],
          "fields": ["ref","sect","tour","abon","nom","cin","adresse","num_contrat","num_compteur","type_cpt","ep_diam","type_abonnement","etat_abonnement","consommation","date_pose","date_releve","anne_fabr_compt","anomalie_rdo","observation","emplacement","ep_coor_x","ep_coor_y","ep_coor_z","date_leve","ref_rue","diametre_calibre_terrain","diametre_conduite","ancienne_police","conformite_plan"],
          "requiredFields": ["conformite_plan"],
        },
        "Cône de Réduction": {
          "tableName": "cone_de_reduction", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": null, "typeOptions": [],
          "fields": ["ep_num","ep_diam_in","ep_diam_out","ep_ref","ref_rue","ep_dtae_pose","ep_entreprise","ep_ref_marche","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_diam_in","ep_diam_out","conformite_plan"],
        },
        "Centre Tampon": {
          "tableName": "centre_tampon", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_etat","conformite_plan"],
        },
        "Obturateur": {
          "tableName": "obturateur", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_diam","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_etat","conformite_plan"],
        },
        "Réducteur de Pression": {
          "tableName": "reducteur_de_pression", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_diam","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_etat","conformite_plan"],
        },
        "Noeud": {
          "tableName": "noeud", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_num","conformite_plan"],
        },
        "Réservoir": {
          "tableName": "reservoir", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_capacite","ep_cote_radier","ep_cote_trop_plein","ep_cote_tn","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_type","ep_capacite","ep_etat","conformite_plan"],
        },
        "Station de Pompage": {
          "tableName": "station_de_pompage", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_nb_pompes","ep_capacite","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_type","ep_nb_pompes","ep_etat","conformite_plan"],
        },
        "Forage": {
          "tableName": "forage", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_profondeur","ep_debit","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_profondeur","ep_etat","conformite_plan"],
        },
        "Puit": {
          "tableName": "puit", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_profondeur","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_profondeur","ep_etat","conformite_plan"],
        },
        "Pompe": {
          "tableName": "pompe", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_puissance","ep_debit","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z","conformite_plan"],
          "requiredFields": ["ep_type","ep_etat","conformite_plan"],
        },
        "Regard": {
          "tableName": "regard", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": null, "typeOptions": [],
          "fields": [
            "ep_sect_com","ep_adresse","sec_com","sect_hydr","zone",
            "ep_date_insertion",
            "ep_agent_crea","ep_agent","id_user_creat","date_creation",
            "id_user_modif","date_modif",
            "z_radier","z_surf","ep_coor_x","ep_coor_y","ep_coor_z",
            "id_commune","id_province",
            "mode_localisation","ep_statut","GENRATRICE_SUP","ep_profondeur",
            "emplacement","ep_ref_rue","ep_section","ep_tampon",
            "echelon","ep_conf_plan","ep_anomalie","anomalie_tamp",
            "anomalie_regard","ep_observation"
          ],
          "requiredFields": [],
          "readOnlyFields": [
            "ep_agent","ep_sect_com","ep_adresse","ep_agent_crea","sec_com",
            "sect_hydr","zone","z_radier","z_surf","ep_date_insertion",
            "ep_coor_x","ep_coor_y","ep_coor_z","id_commune","id_province",
            "id_user_creat","date_creation","id_user_modif","date_modif"
          ],
          "fieldLabels": {
            "ep_agent": "Dernier intervenant SIG",
            "ep_sect_com": "Secteur commercial",
            "ep_statut": "Statut",
            "ep_adresse": "Adresse",
            "ep_agent_crea": "Agent de création SIG",
            "sec_com": "SEC_COM",
            "sect_hydr": "Secteur hydraulique",
            "zone": "Zone hydraulique",
            "z_radier": "Côte radier",
            "z_surf": "Côte surface",
            "ep_date_insertion": "Date d'insertion Elyx",
            "ep_coor_x": "Coordonnée X",
            "ep_coor_y": "Coordonnée Y",
            "ep_coor_z": "Coordonnée Z",
            "id_commune": "Commune",
            "id_province": "Province",
            "id_user_creat": "Utilisateur créateur",
            "id_user_modif": "Dernier utilisateur modificateur",
            "date_creation": "Date de création",
            "date_modif": "Date de modification",
            "is_deleted": "Suppression logique",
            "is_validated": "Validation exploitant",
            "id_user_valid": "Utilisateur validateur",
            "date_validation": "Date de validation",
            "emplacement": "Emplacement du regard",
            "ep_ref_rue": "Référence rue / Douar",
            "ep_section": "Section du regard",
            "ep_tampon": "Type de tampon",
            "ep_conf_plan": "Conformité au plan",
            "ep_observation": "Observation",
            "ep_anomalie": "Anomalie",
            "mode_localisation": "Mode de localisation",
            "echelon": "Existence échelon",
            "anomalie_tamp": "Anomalie tampon",
            "anomalie_regard": "Anomalie regard",
            "GENRATRICE_SUP": "Génératrice supérieure",
            "ep_profondeur": "Profondeur"
          },
        },
        "Conduite Terrain": {
          "tableName": "ep_conduite_terrain", "schema": "ep",
          "geometryType": "LineString", "hasZ": false, "isLine": true, "maxPhotos": 2,
          "typeField": "ep_type",
          "typeOptions": ["Adduction", "Distribution", "Branchement"],
          "fields": ["ep_num","ep_type","ep_diam","ep_mat","ep_long_c","ep_long_r","ep_profondeur","ep_classe_conduite","emplacement","zamont","zaval","pente","zalerte","ref_rue","ep_entreprise","ep_ref_marche","ep_sect_hydro","ep_etage_p","etage_aqua","secteur_aqua","ep_statut","conformite_plan"],
          "requiredFields": ["ep_type","ep_diam","ep_mat","conformite_plan"],
        },
        "Branchement EP": {
          "tableName": "branchement", "schema": "ep",
          "geometryType": "LineString", "hasZ": false, "isLine": true, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_diam","ep_mat","ep_long","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","conformite_plan"],
          "requiredFields": ["ep_diam","ep_etat","conformite_plan"],
        },
        "Traverse": {
          "tableName": "traverse", "schema": "ep",
          "geometryType": "LineString", "hasZ": false, "isLine": true, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_long","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","conformite_plan"],
          "requiredFields": ["ep_etat","conformite_plan"],
        },
        "Planche": {
          "tableName": "planche", "schema": "ep",
          "geometryType": "Polygon", "hasZ": false, "isPolygon": true, "maxPhotos": 0,
          "typeField": null, "typeOptions": [],
          "fields": ["nom","code"],
          "requiredFields": ["nom","code"],
        },
        "Autre Objet EP": {
          "tableName": "autre_objet", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_objet", "typeOptions": [],
          "fields": ["type_objet","ep_diam","ref_rue","date_leve","observation","ep_coor_z","conformite_plan"],
          "requiredFields": ["type_objet","conformite_plan"],
        },
      },
    },
    // ── ASSAINISSEMENT (schéma ass) ──
    "Assainissement": {
      "icon": "plumbing",
      "color": 0xFF4CAF50,
      "schema": "ass",
      "entities": {
        "Regard ASS": {
          "tableName": "asst_regard", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_regard",
          "typeOptions": ["Regard de visite","Regard de chute","Regard de jonction","Regard borgne","Autre"],
          // uuid retiré — généré automatiquement
          "fields": ["conformite_plan","etat","type_regard","type_tampon","typereseau","classe_tampon","forme","date_pose","verrouille","accessibilite","rehabilitation","date_rehabilitation","nature_corps","presence_cunette","cote_tampon","cote_radier","chute","profondeur_radier","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
          "requiredFields": ["etat","type_regard","conformite_plan"],
        },
        "Regard Branchement": {
          "tableName": "asst_regard_branchement", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_tampon", "typeOptions": [],
          // uuid retiré
          "fields": ["conformite_plan","etat","type_tampon","typereseau","classe_tampon","forme","date_pose","verrouille","accessibilite","emplacement","rehabilitation","date_rehabilitation","nature_corps","presence_cunette","cote_tampon","cote_radier","profondeur_radier","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
          "requiredFields": ["etat","conformite_plan"],
        },
        "Canalisation ASS": {
          "tableName": "asst_canalisation", "schema": "ass",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 2,
          "typeField": "type_conduite",
          "typeOptions": ["Gravitaire","Refoulement","Autre"],
          // uuid retiré
          "fields": ["conformite_plan","classe","etat","date_pose","longueur","nature","typereseau","reference","rehabilitation","date_rehabilitation","diametre","largeur_base","profondeur_aval","profondeur_amont","emplacement","type_ecoulement","type_section","type_conduite","type_rehabilitation","protection_anticorrosion","centre","commentaire"],
          "requiredFields": ["etat","type_conduite","diametre","conformite_plan"],
        },
        "Canalisation Réutilisation": {
          "tableName": "asst_canalisation_reutilisation", "schema": "ass",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 4,
          "typeField": null, "typeOptions": [],
          // uuid retiré
          "fields": ["conformite_plan","classe","etat","date_pose","longueur","nature","reference","rehabilitation","date_rehabilitation","type_rehabilitation","diametre","profondeur_aval","profondeur_amont","emplacement","type_ecoulement","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
          "requiredFields": ["etat","diametre","conformite_plan"],
        },
        "Branchement ASS": {
          "tableName": "asst_branchement", "schema": "ass",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 2,
          "typeField": "type_activite", "typeOptions": [],
          // uuid retiré
          "fields": ["conformite_plan","classe","etat","date_pose","longueur","nature","typereseau","reference","rehabilitation","date_rehabilitation","diametre","emplacement","type_activite","centre","commentaire"],
          "requiredFields": ["etat","diametre","conformite_plan"],
        },
        "Bassin": {
          "tableName": "asst_bassin", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_bassin", "typeOptions": [],
          // uuid retiré
          "fields": ["conformite_plan","etat","type_bassin","diametre_amont","diametre_aval","capacite","date_construction","forme_bassin","longueur","largeur","hauteur","cote_arrivee","cote_depart","cote_trop_plein","cote_radier","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
          "requiredFields": ["etat","type_bassin","conformite_plan"],
        },
        "Ouvrage ASS": {
          "tableName": "asst_ouvrage", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_ouvrage", "typeOptions": [],
          // uuid retiré
          "fields": ["conformite_plan","etat","type_ouvrage","capacite","date_construction","accessibilite","longueur","largeur","hauteur","cote_arrivee","pretraitement","sortie","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
          "requiredFields": ["etat","type_ouvrage","conformite_plan"],
        },
        "Équipement ASS": {
          "tableName": "asst_equipement", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type", "typeOptions": [],
          // uuid retiré
          "fields": ["conformite_plan","etat","date_pose","type","typereseau","marque","situation_equipement","profondeur","cote_tn","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
          "requiredFields": ["etat","type","conformite_plan"],
        },
        "Station ASS": {
          "tableName": "asst_station", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_station",
          "typeOptions": ["Station de pompage","Station d'épuration","Station de relevage","Autre"],
          // uuid retiré
          "fields": ["conformite_plan","nom","etat","type_station","capacite","debit_nominal","date_construction","longueur","largeur","nombre_pompes","cote_arrivee","pretraitement","sortie","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
          "requiredFields": ["etat","type_station","conformite_plan"],
        },
      },
    },
    // ── ÉLECTRICITÉ (schéma elec) ──
    "Électricité": {
      "icon": "bolt",
      "color": 0xFFFF9800,
      "schema": "elec",
      "entities": {
        "Support": {
          "tableName": "support", "schema": "elec",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_support",
          "typeOptions": ["Béton","Bois","Métallique","Tubulaire","Autre"],
          // uuid retiré
          "fields": ["type_support","console","etat_support","materiel_supp","type_assemblage","type_armement","type_protection","status","mise_a_la_terre","type_isolateur","code_support","lumineux","hauteur_supp","type_mise_a_la_terre","type_balise","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
          "requiredFields": ["type_support","etat_support","conformite_plan"],
        },
        "Poste": {
          "tableName": "poste", "schema": "elec",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_poste",
          "typeOptions": ["Poste source","Poste de distribution","Poste de transformation","Poste cabine","Poste sur poteau","Autre"],
          // uuid retiré
          "fields": ["nom_poste","type_poste","nature_poste","etat_service","tension","tableau_ep","code_poste","nouveau_code_poste","type_aeration","depart","telecommande","support_communication","nb_rames","nb_depart_mt_dispo","nb_depart_mt_en_service","presence_ild","detec_extinc_incendie","tableau_bt","nb_arrivees_ht","nb_transfo_install","compensation_energie","date_mst","puissance_garantie_ligne","nb_travee_ligne","nb_travee_transfo","nb_emplacement_transfo","compteur_ht","compteur_mt","compteur_bt","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
          "requiredFields": ["nom_poste","type_poste","etat_service","conformite_plan"],
        },
        "Coffret BT": {
          "tableName": "coffret_bt", "schema": "elec",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_coffret", "typeOptions": [],
          // uuid retiré
          "fields": ["type_coffret","miseterre_neutre","statut_coffret","date_pose","marque","num_coffret","code_depart","code_poste","num_transfo","nbr_depart","nbr_arrivees","protection","enveloppe_coffret","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
          "requiredFields": ["type_coffret","conformite_plan"],
        },
        "Noeud Raccord": {
          "tableName": "noeud_raccord", "schema": "elec",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_raccord", "typeOptions": [],
          // uuid retiré
          "fields": ["type_raccord","marque_raccord","modele_raccord","date_pose","num_serie","mise_a_terre","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
          "requiredFields": ["type_raccord","conformite_plan"],
        },
        "Point de Desserte": {
          "tableName": "point_desserte", "schema": "elec",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": null, "typeOptions": [],
          // uuid retiré
          "fields": ["nom","boite_coupure","type_protection","code_poste","num_transfo","tournee","code_depart","coffret","position","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
          "requiredFields": ["nom","conformite_plan"],
        },
        "Tronçon BT": {
          "tableName": "troncon_bt", "schema": "elec",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 2,
          "typeField": "type_liaison",
          "typeOptions": ["Aérien nu","Aérien torsadé","Souterrain","Autre"],
          // uuid retiré
          "fields": ["techcable","type_liaison","section_conducteur","mode_pose","status_troncon","longueur","date_mise_service","code_poste","num_transfo","codedepart","nbphases","section_neutre","nu","section_phase","arme","cable_unipolaire","marque","centre","commentaire","conformite_plan"],
          "requiredFields": ["type_liaison","section_conducteur","conformite_plan"],
        },
        "Tronçon HTA": {
          "tableName": "troncon_hta", "schema": "elec",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 2,
          "typeField": "type_troncon",
          "typeOptions": ["Aérien nu","Aérien torsadé","Souterrain","Autre"],
          // uuid retiré
          "fields": ["status_troncon","type_troncon","section_conduct","type_cable","metal_conduct","phasage_segment","caracteristique","technologie_utilisee","neutre","section_neutre","type_mise_terre","section_mise_terre","tension","postesource","date_mise_en_service","date_pose","marque","depart","long_troncon","centre","commentaire","conformite_plan"],
          "requiredFields": ["type_troncon","section_conduct","conformite_plan"],
        },
      },
    },
  };

  // ── MÉTHODES UTILITAIRES ──
  static List<String> getMetiers() => config.keys.toList();
  static Map<String, dynamic>? getMetierConfig(String metier) => config[metier];

  static List<String> getEntitiesForMetier(String metier) {
    final mc = getMetierConfig(metier);
    if (mc != null) {
      final entities = mc['entities'] as Map<String, dynamic>?;
      return entities?.keys.toList() ?? [];
    }
    return [];
  }

  static Map<String, dynamic>? getEntityConfig(String metier, String entity) {
    final mc = getMetierConfig(metier);
    if (mc != null) {
      final entities = mc['entities'] as Map<String, dynamic>?;
      return entities?[entity];
    }
    return null;
  }

  static int getMetierColor(String metier) =>
      getMetierConfig(metier)?['color'] ?? 0xFF757575;
  static String getMetierIcon(String metier) =>
      getMetierConfig(metier)?['icon'] ?? 'help';

  static List<String> getTypeOptions(String metier, String entity) {
    final ec = getEntityConfig(metier, entity);
    return ec != null ? List<String>.from(ec['typeOptions'] ?? []) : [];
  }

  static String? getTableName(String metier, String entity) =>
      getEntityConfig(metier, entity)?['tableName'];
  static String? getSchema(String metier, String entity) =>
      getEntityConfig(metier, entity)?['schema'];
  static bool isLineEntity(String metier, String entity) =>
      getEntityConfig(metier, entity)?['isLine'] == true;
  static bool isPolygonEntity(String metier, String entity) =>
      getEntityConfig(metier, entity)?['isPolygon'] == true;
  static bool hasAltitudeZ(String metier, String entity) =>
      getEntityConfig(metier, entity)?['hasZ'] == true;
  static int getMaxPhotos(String metier, String entity) =>
      getEntityConfig(metier, entity)?['maxPhotos'] ?? 0;

  static List<String> getFields(String metier, String entity) {
    final ec = getEntityConfig(metier, entity);
    return ec != null ? List<String>.from(ec['fields'] ?? []) : [];
  }

  static List<String> getReadOnlyFields(String metier, String entity) {
    final ec = getEntityConfig(metier, entity);
    return ec != null ? List<String>.from(ec['readOnlyFields'] ?? []) : [];
  }

  static String getFieldLabel(String metier, String entity, String field) {
    final ec = getEntityConfig(metier, entity);
    final labels = ec?['fieldLabels'];
    if (labels is Map && labels[field] != null) {
      return labels[field].toString();
    }
    return field.replaceAll('_', ' ');
  }

  /// ── NOUVEAU : retourne la liste des champs obligatoires ──
  /// Les champs de coordonnées (coor_x / coor_y) ne sont pas inclus ici
  /// car ils sont toujours remplis automatiquement par le GPS.
  static List<String> getRequiredFields(String metier, String entity) {
    final ec = getEntityConfig(metier, entity);
    return ec != null ? List<String>.from(ec['requiredFields'] ?? []) : [];
  }

  /// ── NOUVEAU : retourne true si le champ est obligatoire ──
  static bool isRequiredField(String metier, String entity, String field) {
    return getRequiredFields(metier, entity).contains(field);
  }

  static List<String> getPointEntities(String metier) {
    return getEntitiesForMetier(metier).where((e) {
      final c = getEntityConfig(metier, e);
      return c != null && c['isLine'] != true && c['isPolygon'] != true;
    }).toList();
  }

  static List<String> getLineEntities(String metier) =>
      getEntitiesForMetier(metier)
          .where((e) => isLineEntity(metier, e))
          .toList();

  static List<String> getPolygonEntities(String metier) =>
      getEntitiesForMetier(metier)
          .where((e) => isPolygonEntity(metier, e))
          .toList();

  static const Set<String> _doubleFieldHints = {
    'accuracy', 'altitude', 'amont', 'aval', 'capacite', 'chute', 'cote',
    'debit', 'diam', 'distance', 'hauteur', 'largeur', 'long', 'pente',
    'pression', 'profondeur', 'puissance', 'section', 'tension', 'x_', 'y_',
    'z_', 'rayon', 'genratrice',
  };

  static const Set<String> _integerFields = {
    'nb_arrivees_ht', 'nb_depart_mt_dispo', 'nb_depart_mt_en_service',
    'nb_emplacement_transfo', 'nb_points', 'nb_pompes', 'nb_rames',
    'nb_transfo_install', 'nbr_arrivees', 'nbr_depart', 'num_transfo',
    'id_commune', 'id_province', 'id_user_creat', 'id_user_modif',
    'id_user_valid',
  };

  static const Set<String> _dateFields = {
    'date_collecte', 'date_construction', 'date_mise_en_service',
    'date_mise_service', 'date_mst', 'date_pose', 'date_rehabilitation',
    'date_leve', 'ep_date_insertion', 'date_creation', 'date_modif',
    'date_validation',
  };

  static const Set<String> _longTextFields = {
    'commentaire', 'observation', 'type_anomalie',
  };

  static const Set<String> _mediumTextFields = {
    'emplacement', 'nom', 'nom_poste', 'observation', 'ref_rue',
    'ep_observation', 'ep_adresse', 'ep_agent', 'ep_agent_crea',
    'ep_ref_rue', 'ep_section', 'ep_sect_com', 'sec_com', 'sect_hydr',
    'zone',
  };

  static const Set<String> _uuidFields = {
    'uuid',
  };

  static const Set<String> _booleanLikeFields = {
    'accessibilite', 'anomalie', 'boite_coupure', 'compensation_energie',
    'compteur_bt', 'compteur_ht', 'compteur_mt', 'detec_extinc_incendie',
    'lumineux', 'mise_a_la_terre', 'presence_cunette', 'presence_ild',
    'rehabilitation', 'telecommande', 'verrouille', 'ep_anomalie',
    'is_deleted', 'is_validated',
  };

  static const Set<String> _shortCodeHints = {
    'code', 'depart', 'num', 'numero', 'reference', 'ref_', 'status', 'statut',
    'tournee', 'type_',
  };

  /// Champs FK communs à tous les objets SRM — gérés automatiquement dans _save()
  /// `uuid` est généré automatiquement et ne doit pas apparaître dans `fields`.
  static const List<String> commonFkFields = [
    'uuid', 'id_projet', 'id_agent_crea', 'id_mission',
    'id_planche', 'id_commune', 'mode_localisation',
    'anomalie', 'type_anomalie',
    'objet_incomplet', 'raison_incomplet',
  ];

  static SrmFieldRule getFieldRule(String metier, String entity, String field) {
    final entityConfig = getEntityConfig(metier, entity) ?? const {};
    final typeField = entityConfig['typeField']?.toString();
    final typeOptions = getTypeOptions(metier, entity);

    if (field == typeField && typeOptions.isNotEmpty) {
      return SrmFieldRule(
        kind: SrmFieldKind.enumValue,
        maxLength: 100,
        required: true,
        allowedValues: typeOptions,
      );
    }

    if (_uuidFields.contains(field)) {
      return const SrmFieldRule(
        kind: SrmFieldKind.uuid,
        maxLength: 36,
        readOnly: true,
      );
    }

    if (_dateFields.contains(field) || field.startsWith('date_')) {
      return const SrmFieldRule(
        kind: SrmFieldKind.date,
        maxLength: 10,
      );
    }

    if (_booleanLikeFields.contains(field)) {
      return const SrmFieldRule(
        kind: SrmFieldKind.booleanLike,
        maxLength: 5,
      );
    }

    if (_isIntegerField(field)) {
      return const SrmFieldRule(
        kind: SrmFieldKind.integer,
        maxLength: 10,
      );
    }

    if (_isDoubleField(field)) {
      return const SrmFieldRule(
        kind: SrmFieldKind.decimal,
        maxLength: 20,
      );
    }

    if (_longTextFields.contains(field)) {
      return const SrmFieldRule(
        kind: SrmFieldKind.text,
        maxLength: 500,
        multiline: true,
      );
    }

    if (_mediumTextFields.contains(field)) {
      return const SrmFieldRule(
        kind: SrmFieldKind.text,
        maxLength: 150,
      );
    }

    if (_hasAnyHint(field, _shortCodeHints)) {
      return const SrmFieldRule(
        kind: SrmFieldKind.text,
        maxLength: 100,
      );
    }

    return const SrmFieldRule(
      kind: SrmFieldKind.text,
      maxLength: 254,
    );
  }

  static bool _isIntegerField(String field) {
    return field.startsWith('nb_') ||
        field.startsWith('nbr_') ||
        _integerFields.contains(field);
  }

  static bool _isDoubleField(String field) {
    if (field.endsWith('_coor_x') ||
        field.endsWith('_coor_y') ||
        field.endsWith('_coor_z') ||
        field.startsWith('x_') ||
        field.startsWith('y_') ||
        field.startsWith('z_') ||
        field.startsWith('lat_') ||
        field.startsWith('lon_')) {
      return true;
    }
    return _hasAnyHint(field, _doubleFieldHints);
  }

  static bool _hasAnyHint(String field, Set<String> hints) {
    final normalizedField = field.toLowerCase();
    for (final hint in hints) {
      if (normalizedField.contains(hint.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}

enum SrmFieldKind {
  text,
  integer,
  decimal,
  date,
  uuid,
  enumValue,
  booleanLike,
}

class SrmFieldRule {
  final SrmFieldKind kind;
  final int? maxLength;
  final bool required;
  final bool multiline;
  final bool readOnly;
  final List<String> allowedValues;

  const SrmFieldRule({
    required this.kind,
    this.maxLength,
    this.required = false,
    this.multiline = false,
    this.readOnly = false,
    this.allowedValues = const [],
  });

  bool get isNumeric =>
      kind == SrmFieldKind.integer || kind == SrmFieldKind.decimal;
}
