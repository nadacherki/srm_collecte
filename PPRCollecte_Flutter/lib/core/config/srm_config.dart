// lib/core/config/srm_config.dart
// Configuration centrale des entités SRM (Eau Potable, Assainissement, Électricité)
// Remplace infrastructure_config.dart de GeoDNGR
// Chaque entité correspond à une table PostGIS (schéma ep, ass, elec)

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
          "fields": ["ep_num","ep_type","ep_modele","ep_marque","ep_diam","ep_ref_regard","ep_sens_ferm","ep_manoeuvre","ep_etat","ep_sectionnement","emplacement","ep_ref","ref_rue","ep_entreprise","ep_ref_marche","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Vanne de Vidange": {
          "tableName": "vanne_de_vidange", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_modele","ep_marque","ep_diam","ep_etat","emplacement","ep_ref","ref_rue","ep_entreprise","ep_ref_marche","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Ventouse": {
          "tableName": "ventouse", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_modele","ep_marque","ep_diam","ep_etat","emplacement","ep_ref","ref_rue","ep_entreprise","ep_ref_marche","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Hydrant": {
          "tableName": "hydrant", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": ["Poteau d'incendie", "Bouche d'incendie"],
          "fields": ["ep_num","ep_type","ep_modele","ep_marque","ep_diam","ep_pression","ep_etat","emplacement","ep_ref","ref_rue","ep_entreprise","ep_ref_marche","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Borne Fontaine": {
          "tableName": "borne_fontaine", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_etat","ep_diam","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Borne ONEP": {
          "tableName": "borne_onep", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Bouche à Clé": {
          "tableName": "bouche_cles", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Bouche d'Arrosage": {
          "tableName": "bouche_darrosage", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Compteur Réseau": {
          "tableName": "compteur_reseau", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_calibre","ep_numero","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Compteur Abonné": {
          "tableName": "compteur_abonne", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_calibre","ep_numero","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Cône de Réduction": {
          "tableName": "cone_de_reduction", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": null, "typeOptions": [],
          "fields": ["ep_num","ep_diam_amont","ep_diam_aval","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Centre Tampon": {
          "tableName": "centre_tampon", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Obturateur": {
          "tableName": "obturateur", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_diam","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Réducteur de Pression": {
          "tableName": "reducteur_de_pression", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_diam","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Noeud": {
          "tableName": "noeud", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Réservoir": {
          "tableName": "reservoir", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_capacite","ep_cote_radier","ep_cote_trop_plein","ep_cote_tn","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Station de Pompage": {
          "tableName": "station_de_pompage", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_nb_pompes","ep_capacite","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Forage": {
          "tableName": "forage", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_profondeur","ep_debit","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Puit": {
          "tableName": "puit", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_profondeur","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Pompe": {
          "tableName": "pompe", "schema": "ep",
          "geometryType": "Point", "hasZ": false, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_puissance","ep_debit","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Regard EP": {
          "tableName": "regard_ep", "schema": "ep",
          "geometryType": "Polygon", "hasZ": true, "isPolygon": true, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_forme","ep_longueur","ep_largeur","ep_cote_tampon","ep_cote_radier","ep_cote_fil_eau","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation","ep_coor_x","ep_coor_y","ep_coor_z", "conformite_plan"],
        },
        "Conduite Terrain": {
          "tableName": "ep_conduite_terrain", "schema": "ep",
          "geometryType": "LineString", "hasZ": false, "isLine": true, "maxPhotos": 2,
          "typeField": "ep_type",
          "typeOptions": ["Adduction", "Distribution", "Branchement"],
          "fields": ["ep_num","ep_type","ep_diam","ep_mat","ep_long_c","ep_long_r","ep_profondeur","ep_classe_conduite","emplacement","zamont","zaval","pente","zalerte","ref_rue","ep_entreprise","ep_ref_marche","ep_sect_hydro","ep_etage_p","etage_aqua","secteur_aqua","ep_statut", "conformite_plan"],
        },
        "Branchement EP": {
          "tableName": "branchement", "schema": "ep",
          "geometryType": "LineString", "hasZ": false, "isLine": true, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_diam","ep_mat","ep_long","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation", "conformite_plan"],
        },
        "Traverse": {
          "tableName": "traverse", "schema": "ep",
          "geometryType": "LineString", "hasZ": false, "isLine": true, "maxPhotos": 4,
          "typeField": "ep_type", "typeOptions": [],
          "fields": ["ep_num","ep_type","ep_long","ep_etat","emplacement","ref_rue","etage_aqua","secteur_aqua","ep_statut","observation", "conformite_plan"],
        },
        "Planche": {
          "tableName": "planche", "schema": "ep",
          "geometryType": "Polygon", "hasZ": false, "isPolygon": true, "maxPhotos": 0,
          "typeField": null, "typeOptions": [],
          "fields": ["nom","code"],
        },
        "Autre Objet EP": {
          "tableName": "autre_objet", "schema": "ep",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_objet", "typeOptions": [],
          "fields": ["type_objet","ep_diam","ref_rue","observation","ep_coor_z", "conformite_plan"],
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
          "fields": ["uuid","conformite_plan","etat","type_regard","type_tampon","typereseau","classe_tampon","forme","date_pose","verrouille","accessibilite","rehabilitation","date_rehabilitation","nature_corps","presence_cunette","cote_tampon","cote_radier","chute","profondeur_radier","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
        },
        "Regard Branchement": {
          "tableName": "asst_regard_branchement", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_tampon", "typeOptions": [],
          "fields": ["uuid","conformite_plan","etat","type_tampon","typereseau","classe_tampon","forme","date_pose","verrouille","accessibilite","emplacement","rehabilitation","date_rehabilitation","nature_corps","presence_cunette","cote_tampon","cote_radier","profondeur_radier","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
        },
        "Canalisation ASS": {
          "tableName": "asst_canalisation", "schema": "ass",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 2,
          "typeField": "type_conduite",
          "typeOptions": ["Gravitaire","Refoulement","Autre"],
          "fields": ["uuid","conformite_plan","classe","etat","date_pose","longueur","nature","typereseau","reference","rehabilitation","date_rehabilitation","diametre","largeur_base","profondeur_aval","profondeur_amont","emplacement","type_ecoulement","type_section","type_conduite","type_rehabilitation","protection_anticorrosion","centre","commentaire"],
        },
        "Canalisation Réutilisation": {
          "tableName": "asst_canalisation_reutilisation", "schema": "ass",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 4,
          "typeField": null, "typeOptions": [],
          "fields": ["uuid","conformite_plan","classe","etat","date_pose","longueur","nature","reference","rehabilitation","date_rehabilitation","type_rehabilitation","diametre","profondeur_aval","profondeur_amont","emplacement","type_ecoulement","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
        },
        "Branchement ASS": {
          "tableName": "asst_branchement", "schema": "ass",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 2,
          "typeField": "type_activite", "typeOptions": [],
          "fields": ["uuid","conformite_plan","classe","etat","date_pose","longueur","nature","typereseau","reference","rehabilitation","date_rehabilitation","diametre","emplacement","type_activite","centre","commentaire"],
        },
        "Bassin": {
          "tableName": "asst_bassin", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_bassin", "typeOptions": [],
          "fields": ["uuid","conformite_plan","etat","type_bassin","diametre_amont","diametre_aval","capacite","date_construction","forme_bassin","longueur","largeur","hauteur","cote_arrivee","cote_depart","cote_trop_plein","cote_radier","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
        },
        "Ouvrage ASS": {
          "tableName": "asst_ouvrage", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_ouvrage", "typeOptions": [],
          "fields": ["uuid","conformite_plan","etat","type_ouvrage","capacite","date_construction","accessibilite","longueur","largeur","hauteur","cote_arrivee","pretraitement","sortie","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
        },
        "Équipement ASS": {
          "tableName": "asst_equipement", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type", "typeOptions": [],
          "fields": ["uuid","conformite_plan","etat","date_pose","type","typereseau","marque","situation_equipement","profondeur","cote_tn","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
        },
        "Station ASS": {
          "tableName": "asst_station", "schema": "ass",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_station",
          "typeOptions": ["Station de pompage","Station d'épuration","Station de relevage","Autre"],
          "fields": ["uuid","conformite_plan","nom","etat","type_station","capacite","debit_nominal","date_construction","longueur","largeur","nombre_pompes","cote_arrivee","pretraitement","sortie","ass_coor_x","ass_coor_y","ass_coor_z","centre","commentaire"],
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
          "fields": ["uuid","type_support","console","etat_support","materiel_supp","type_assemblage","type_armement","type_protection","status","mise_a_la_terre","type_isolateur","code_support","lumineux","hauteur_supp","type_mise_a_la_terre","type_balise","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
        },
        "Poste": {
          "tableName": "poste", "schema": "elec",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_poste",
          "typeOptions": ["Poste source","Poste de distribution","Poste de transformation","Poste cabine","Poste sur poteau","Autre"],
          "fields": ["uuid","nom_poste","type_poste","nature_poste","etat_service","tension","tableau_ep","code_poste","nouveau_code_poste","type_aeration","depart","telecommande","support_communication","nb_rames","nb_depart_mt_dispo","nb_depart_mt_en_service","presence_ild","detec_extinc_incendie","tableau_bt","nb_arrivees_ht","nb_transfo_install","compensation_energie","date_mst","puissance_garantie_ligne","nb_travee_ligne","nb_travee_transfo","nb_emplacement_transfo","compteur_ht","compteur_mt","compteur_bt","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
        },
        "Coffret BT": {
          "tableName": "coffret_bt", "schema": "elec",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_coffret", "typeOptions": [],
          "fields": ["uuid","type_coffret","miseterre_neutre","statut_coffret","date_pose","marque","num_coffret","code_depart","code_poste","num_transfo","nbr_depart","nbr_arrivees","protection","enveloppe_coffret","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
        },
        "Noeud Raccord": {
          "tableName": "noeud_raccord", "schema": "elec",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_raccord", "typeOptions": [],
          "fields": ["uuid","type_raccord","marque_raccord","modele_raccord","date_pose","num_serie","mise_a_terre","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
        },
        "Point de Desserte": {
          "tableName": "point_desserte", "schema": "elec",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": null, "typeOptions": [],
          "fields": ["uuid","nom","boite_coupure","type_protection","code_poste","num_transfo","tournee","code_depart","coffret","position","elec_coor_x","elec_coor_y","elec_coor_z","centre","commentaire","conformite_plan"],
        },
        "Tronçon BT": {
          "tableName": "troncon_bt", "schema": "elec",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 2,
          "typeField": "type_liaison",
          "typeOptions": ["Aérien nu","Aérien torsadé","Souterrain","Autre"],
          "fields": ["uuid","techcable","type_liaison","section_conducteur","mode_pose","status_troncon","longueur","date_mise_service","code_poste","num_transfo","codedepart","nbphases","section_neutre","nu","section_phase","arme","cable_unipolaire","marque","centre","commentaire","conformite_plan"],
        },
        "Tronçon HTA": {
          "tableName": "troncon_hta", "schema": "elec",
          "geometryType": "LineString", "hasZ": true, "isLine": true, "maxPhotos": 2,
          "typeField": "type_troncon",
          "typeOptions": ["Aérien nu","Aérien torsadé","Souterrain","Autre"],
          "fields": ["uuid","status_troncon","type_troncon","section_conduct","type_cable","metal_conduct","phasage_segment","caracteristique","technologie_utilisee","neutre","section_neutre","type_mise_terre","section_mise_terre","tension","postesource","date_mise_en_service","date_pose","marque","depart","long_troncon","centre","commentaire","conformite_plan"],
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

  static int getMetierColor(String metier) => getMetierConfig(metier)?['color'] ?? 0xFF757575;
  static String getMetierIcon(String metier) => getMetierConfig(metier)?['icon'] ?? 'help';

  static List<String> getTypeOptions(String metier, String entity) {
    final ec = getEntityConfig(metier, entity);
    return ec != null ? List<String>.from(ec['typeOptions'] ?? []) : [];
  }

  static String? getTableName(String metier, String entity) => getEntityConfig(metier, entity)?['tableName'];
  static String? getSchema(String metier, String entity) => getEntityConfig(metier, entity)?['schema'];
  static bool isLineEntity(String metier, String entity) => getEntityConfig(metier, entity)?['isLine'] == true;
  static bool isPolygonEntity(String metier, String entity) => getEntityConfig(metier, entity)?['isPolygon'] == true;
  static bool hasAltitudeZ(String metier, String entity) => getEntityConfig(metier, entity)?['hasZ'] == true;
  static int getMaxPhotos(String metier, String entity) => getEntityConfig(metier, entity)?['maxPhotos'] ?? 0;

  static List<String> getFields(String metier, String entity) {
    final ec = getEntityConfig(metier, entity);
    return ec != null ? List<String>.from(ec['fields'] ?? []) : [];
  }

  static List<String> getPointEntities(String metier) {
    return getEntitiesForMetier(metier).where((e) {
      final c = getEntityConfig(metier, e);
      return c != null && c['isLine'] != true && c['isPolygon'] != true;
    }).toList();
  }

  static List<String> getLineEntities(String metier) =>
      getEntitiesForMetier(metier).where((e) => isLineEntity(metier, e)).toList();

  static List<String> getPolygonEntities(String metier) =>
      getEntitiesForMetier(metier).where((e) => isPolygonEntity(metier, e)).toList();

  /// Champs FK communs à tous les objets SRM
  static const List<String> commonFkFields = [
    'uuid', 'id_projet', 'id_agent_crea', 'id_mission',
    'id_planche', 'id_commune', 'mode_localisation',
    'anomalie', 'type_anomalie',
  ];
}
