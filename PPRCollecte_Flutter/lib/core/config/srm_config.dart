// lib/core/config/srm_config.dart
// Configuration centrale des entités SRM (Eau Potable, Assainissement)
// Configuration centrale des entites SRM
// Chaque entité correspond à une table PostGIS (schéma ep, ass)
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
          "typeOptions": [
            "Vanne de sectionnement",
            "Vanne de régulation",
            "Vanne papillon",
            "Vanne à opercule",
            "Autre"
          ],
          // uuid retiré — généré automatiquement
          "fields": [
            "ep_num",
            "ep_type",
            "ep_modele",
            "ep_marque",
            "ep_diam",
            "ep_ref_regard",
            "ep_sens_ferm",
            "ep_manoeuvre",
            "ep_etat",
            "ep_sectionnement",
            "emplacement",
            "ep_ref",
            "ref_rue",
            "ep_entreprise",
            "ep_ref_marche",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_type", "ep_etat", "conformite_plan"],
        },
        "Vanne de Vidange": {
          "tableName": "vanne_de_vidange",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_modele",
            "ep_marque",
            "ep_diam",
            "ep_etat",
            "emplacement",
            "ep_ref",
            "ref_rue",
            "ep_entreprise",
            "ep_ref_marche",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_etat", "conformite_plan"],
        },
        "Ventouse": {
          "tableName": "ventouse",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_modele",
            "ep_marque",
            "ep_diam",
            "ep_ref_regard",
            "emplacement",
            "ep_ref",
            "ref_rue",
            "ep_entreprise",
            "ep_ref_marche",
            "ep_date_interv",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_type", "conformite_plan"],
        },
        "Hydrant": {
          "tableName": "hydrant",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": ["Poteau d'incendie", "Bouche d'incendie"],
          "fields": [
            "ep_num",
            "ep_type",
            "marque",
            "ep_diam",
            "ep_etat",
            "emplacement",
            "ep_ref",
            "ref_rue",
            "ep_entreprise",
            "ep_ref_marche",
            "conform",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "ep_conf_plan"
          ],
          "requiredFields": ["ep_type", "ep_etat"],
          "fieldLabels": {
            "conform": "Conformité",
            "ep_conf_plan": "Conformité des plans",
          },
        },
        "Borne Fontaine": {
          "tableName": "borne_fontaine",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "marque",
            "ep_etat",
            "ep_diam",
            "mat_brts",
            "ep_ref",
            "ref_rue",
            "emplacement",
            "ep_entreprise",
            "ep_ref_marche",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_etat", "conformite_plan"],
          "fieldLabels": {
            "mat_brts": "Matériau branchement",
          },
        },
        "Borne ONEP": {
          "tableName": "borne_onep",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 0,
          "typeField": null,
          "typeOptions": [],
          "fields": ["ep_coor_x", "ep_coor_y", "ep_coor_z"],
          "requiredFields": [],
          "fieldLabels": {
            "ep_coor_x": "X",
            "ep_coor_y": "Y",
            "ep_coor_z": "Z",
          },
        },
        "Bouche à Clé": {
          "tableName": "bouche_a_cles",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 0,
          "typeField": null,
          "typeOptions": [],
          "fields": ["ep_coor_x", "ep_coor_y", "ep_coor_z"],
          "requiredFields": [],
          "fieldLabels": {
            "ep_coor_x": "X",
            "ep_coor_y": "Y",
            "ep_coor_z": "Z",
          },
        },
        "Bouche d'Arrosage": {
          "tableName": "bouche_darrosage",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_marque",
            "ep_etat",
            "ep_ref",
            "ref_rue",
            "emplacement",
            "ep_entreprise",
            "ep_ref_marche",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_etat", "conformite_plan"],
        },
        "Compteur Réseau": {
          "tableName": "compteur_reseau",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_modele",
            "ep_marque",
            "ep_calibre",
            "ep_sourc_alim",
            "ep_ref_regard",
            "ep_releve",
            "ep_res_deserv",
            "ep_n_serie",
            "ep_compt_fonction",
            "ep_ref",
            "ref_rue",
            "ep_entreprise",
            "ep_ref_marche",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "ep_ref_mm",
            "ep_mm",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_type", "conformite_plan"],
        },
        "Compteur Abonné": {
          "tableName": "compteur_abonne",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "type_cpt",
            "diametre",
            "ep_observation",
            "ep_anomalie",
            "type_anomalie",
            "num_contrat",
            "ancienne_police",
            "abon",
            "nom",
            "adresse",
            "etat_abonnement",
            "ancien_ref_sap",
            "id_geo",
            "ep_conf_plan",
            "mode_localisation"
          ],
          "requiredFields": [],
          "readOnlyFields": [
            "abon",
            "nom",
            "adresse",
            "etat_abonnement",
            "ancien_ref_sap",
            "id_geo"
          ],
        },
        "Cône de Réduction": {
          "tableName": "cone_de_reduction",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_diam_in",
            "ep_diam_out",
            "ep_ref",
            "ref_rue",
            "ep_dtae_pose",
            "ep_entreprise",
            "ep_ref_marche",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_diam_in", "ep_diam_out", "conformite_plan"],
        },
        "Centre Tampon": {
          "tableName": "centre_tampon",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_etat", "conformite_plan"],
        },
        "Obturateur": {
          "tableName": "obturateur",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_diam",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_etat", "conformite_plan"],
        },
        "Réducteur de Pression": {
          "tableName": "reducteur_de_pression",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_diam",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_etat", "conformite_plan"],
        },
        "Noeud": {
          "tableName": "noeud",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_num", "conformite_plan"],
        },
        "Réservoir": {
          "tableName": "reservoir",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_capacite",
            "ep_cote_radier",
            "ep_cote_trop_plein",
            "ep_cote_tn",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": [
            "ep_type",
            "ep_capacite",
            "ep_etat",
            "conformite_plan"
          ],
        },
        "Station de Pompage": {
          "tableName": "station_de_pompage",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_nb_pompes",
            "ep_capacite",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": [
            "ep_type",
            "ep_nb_pompes",
            "ep_etat",
            "conformite_plan"
          ],
        },
        "Forage": {
          "tableName": "forage",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_profondeur",
            "ep_debit",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_profondeur", "ep_etat", "conformite_plan"],
        },
        "Puit": {
          "tableName": "puit",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_profondeur",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_profondeur", "ep_etat", "conformite_plan"],
        },
        "Pompe": {
          "tableName": "pompe",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": false,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_puissance",
            "ep_debit",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "conformite_plan"
          ],
          "requiredFields": ["ep_type", "ep_etat", "conformite_plan"],
        },
        "Bache": {
          "tableName": "ep_bache",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "ep_section",
            "ep_capacite",
            "ep_prof",
            "ref_rue",
            "emplacement",
            "conformite_plan",
            "observation",
            "anomalie",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "mode_localisation"
          ],
          "requiredFields": [],
          "fieldLabels": {
            "ep_section": "Section",
            "ep_capacite": "Capacite",
            "ep_prof": "Profondeur",
            "ref_rue": "Reference rue",
            "emplacement": "Emplacement",
            "conformite_plan": "Conformite plan",
            "observation": "Observation",
            "anomalie": "Anomalie",
            "ep_coor_x": "X",
            "ep_coor_y": "Y",
            "ep_coor_z": "Z",
            "mode_localisation": "Mode de localisation",
          },
        },
        "Regard": {
          "tableName": "ep_regard_point",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "ep_sect_com",
            "ep_adresse",
            "sec_com",
            "sect_hydr",
            "zone",
            "ep_date_insertion",
            "ep_agent_crea",
            "ep_agent",
            "id_user_creat",
            "date_creation",
            "id_user_modif",
            "date_modif",
            "z_radier",
            "z_surf",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "id_commune",
            "id_province",
            "mode_localisation",
            "ep_statut",
            "GENRATRICE_SUP",
            "ep_profondeur",
            "emplacement",
            "ep_ref_rue",
            "ep_section",
            "ep_tampon",
            "echelon",
            "ep_conf_plan",
            "ep_anomalie",
            "anomalie_tamp",
            "anomalie_regard",
            "ep_observation"
          ],
          "requiredFields": [],
          "readOnlyFields": [
            "ep_agent",
            "ep_sect_com",
            "ep_adresse",
            "ep_agent_crea",
            "sec_com",
            "sect_hydr",
            "zone",
            "z_radier",
            "z_surf",
            "ep_date_insertion",
            "ep_coor_x",
            "ep_coor_y",
            "ep_coor_z",
            "id_commune",
            "id_province",
            "id_user_creat",
            "date_creation",
            "id_user_modif",
            "date_modif"
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
        "Anomalie Conduite": {
          "tableName": "anomalie_conduite",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": "type_anomalie",
          "typeOptions": [],
          "fields": ["type_anomalie"],
          "requiredFields": [],
        },
        "TN": {
          "tableName": "tn",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 0,
          "typeField": null,
          "typeOptions": [],
          "fields": ["ep_coor_x", "ep_coor_y", "ep_coor_z"],
          "requiredFields": [],
          "fieldLabels": {
            "ep_coor_x": "X",
            "ep_coor_y": "Y",
            "ep_coor_z": "Z",
          },
        },
        "Voie": {
          "tableName": "voie",
          "schema": "ep",
          "geometryType": "LineString",
          "hasZ": true,
          "isLine": true,
          "maxPhotos": 0,
          "typeField": "type",
          "typeOptions": [],
          "fields": ["type"],
          "requiredFields": [],
        },
        "Conduite Terrain": {
          "tableName": "conduite_terrain",
          "schema": "ep",
          "geometryType": "LineString",
          "hasZ": false,
          "isLine": true,
          "maxPhotos": 0,
          "typeField": null,
          "typeOptions": [],
          "fields": ["ep_diam", "ep_mat"],
          "requiredFields": ["ep_diam", "ep_mat"],
        },
        "Branchement EP": {
          "tableName": "branchement",
          "schema": "ep",
          "geometryType": "LineString",
          "hasZ": false,
          "isLine": true,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_diam",
            "ep_mat",
            "ep_long",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "conformite_plan"
          ],
          "requiredFields": ["ep_diam", "ep_etat", "conformite_plan"],
        },
        "Traverse": {
          "tableName": "traverse",
          "schema": "ep",
          "geometryType": "LineString",
          "hasZ": false,
          "isLine": true,
          "maxPhotos": 4,
          "typeField": "ep_type",
          "typeOptions": [],
          "fields": [
            "ep_num",
            "ep_type",
            "ep_long",
            "ep_etat",
            "emplacement",
            "ref_rue",
            "etage_aqua",
            "secteur_aqua",
            "ep_statut",
            "observation",
            "conformite_plan"
          ],
          "requiredFields": ["ep_etat", "conformite_plan"],
        },
        "Planche": {
          "tableName": "planche",
          "schema": "ep",
          "geometryType": "Polygon",
          "hasZ": false,
          "isPolygon": true,
          "maxPhotos": 0,
          "typeField": null,
          "typeOptions": [],
          "fields": ["nom", "code"],
          "requiredFields": ["nom", "code"],
        },
        "Autre Objet EP": {
          "tableName": "autre_objet",
          "schema": "ep",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 0,
          "typeField": null,
          "typeOptions": [],
          "fields": ["ep_coor_x", "ep_coor_y", "ep_coor_z", "observation"],
          "requiredFields": [],
          "fieldLabels": {
            "ep_coor_x": "X",
            "ep_coor_y": "Y",
            "ep_coor_z": "Z",
            "observation": "Commentaire",
          },
        },
      },
    },
    // ── ASSAINISSEMENT (schéma ass) ──
    "Assainissement": {
      "icon": "plumbing",
      "color": 0xFF4CAF50,
      "schema": "asst",
      "entities": {
        "Regard ASS": {
          "tableName": "asst_regard", "schema": "asst",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_regard",
          "typeOptions": [
            "Regard de visite",
            "Regard de chute",
            "Regard de jonction",
            "Regard borgne",
            "Autre"
          ],
          // uuid retiré — généré automatiquement
          "fields": [
            "conformite_plan",
            "etat",
            "type_regard",
            "type_tampon",
            "typereseau",
            "classe_tampon",
            "forme",
            "date_pose",
            "verrouille",
            "accessibilite",
            "rehabilitation",
            "date_rehabilitation",
            "nature_corps",
            "presence_cunette",
            "cote_tampon",
            "cote_radier",
            "chute",
            "profondeur_radier",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["etat", "type_regard", "conformite_plan"],
        },
        "Regard Branchement": {
          "tableName": "asst_regard_branchement", "schema": "asst",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_tampon", "typeOptions": [],
          // uuid retiré
          "fields": [
            "conformite_plan",
            "etat",
            "type_tampon",
            "typereseau",
            "classe_tampon",
            "forme",
            "date_pose",
            "verrouille",
            "accessibilite",
            "emplacement",
            "rehabilitation",
            "date_rehabilitation",
            "nature_corps",
            "presence_cunette",
            "cote_tampon",
            "cote_radier",
            "profondeur_radier",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["etat", "conformite_plan"],
        },
        "Regards Borgnes": {
          "tableName": "ASS_BORGNE",
          "schema": "asst",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "conformite_plan",
            "etat",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["conformite_plan"],
        },
        "Bouches d'égout": {
          "tableName": "ASS_BOUCHE",
          "schema": "asst",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "conformite_plan",
            "etat",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["conformite_plan"],
        },
        "Déversoirs d'orage": {
          "tableName": "ASS_DEVERSOIR",
          "schema": "asst",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "conformite_plan",
            "etat",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["conformite_plan"],
        },
        "Exutoires": {
          "tableName": "ASS__EXUTOIRE",
          "schema": "asst",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "conformite_plan",
            "etat",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["conformite_plan"],
        },
        "Canalisation ASS": {
          "tableName": "asst_canalisation", "schema": "asst",
          "geometryType": "LineString", "hasZ": true, "isLine": true,
          "maxPhotos": 2,
          "typeField": "type_conduite",
          "typeOptions": ["Gravitaire", "Refoulement", "Autre"],
          // uuid retiré
          "fields": [
            "conformite_plan",
            "classe",
            "etat",
            "date_pose",
            "longueur",
            "nature",
            "typereseau",
            "reference",
            "rehabilitation",
            "date_rehabilitation",
            "diametre",
            "largeur_base",
            "profondeur_aval",
            "profondeur_amont",
            "emplacement",
            "type_ecoulement",
            "type_section",
            "type_conduite",
            "type_rehabilitation",
            "protection_anticorrosion",
            "centre",
            "commentaire"
          ],
          "requiredFields": [
            "etat",
            "type_conduite",
            "diametre",
            "conformite_plan"
          ],
        },
        "Canalisation Réutilisation": {
          "tableName": "asst_canalisation_reutilisation", "schema": "asst",
          "geometryType": "LineString", "hasZ": true, "isLine": true,
          "maxPhotos": 4,
          "typeField": null, "typeOptions": [],
          // uuid retiré
          "fields": [
            "conformite_plan",
            "classe",
            "etat",
            "date_pose",
            "longueur",
            "nature",
            "reference",
            "rehabilitation",
            "date_rehabilitation",
            "type_rehabilitation",
            "diametre",
            "profondeur_aval",
            "profondeur_amont",
            "emplacement",
            "type_ecoulement",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["etat", "diametre", "conformite_plan"],
        },
        "Branchement ASS": {
          "tableName": "asst_branchement", "schema": "asst",
          "geometryType": "LineString", "hasZ": true, "isLine": true,
          "maxPhotos": 2,
          "typeField": "type_activite", "typeOptions": [],
          // uuid retiré
          "fields": [
            "conformite_plan",
            "classe",
            "etat",
            "date_pose",
            "longueur",
            "nature",
            "typereseau",
            "reference",
            "rehabilitation",
            "date_rehabilitation",
            "diametre",
            "emplacement",
            "type_activite",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["etat", "diametre", "conformite_plan"],
        },
        "Caniveaux": {
          "tableName": "ASS_CANIVEAU",
          "schema": "asst",
          "geometryType": "LineString",
          "hasZ": true,
          "isLine": true,
          "maxPhotos": 2,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "conformite_plan",
            "etat",
            "longueur",
            "nature",
            "reference",
            "emplacement",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["conformite_plan"],
        },
        "Caniveau branchement": {
          "tableName": "ASS_CANIV_BRANCHE",
          "schema": "asst",
          "geometryType": "LineString",
          "hasZ": true,
          "isLine": true,
          "maxPhotos": 2,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "conformite_plan",
            "etat",
            "longueur",
            "nature",
            "reference",
            "emplacement",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["conformite_plan"],
        },
        "Collecteur bouche d'égout": {
          "tableName": "ASS_COL_BOUCHE",
          "schema": "asst",
          "geometryType": "LineString",
          "hasZ": true,
          "isLine": true,
          "maxPhotos": 2,
          "typeField": null,
          "typeOptions": [],
          "fields": [
            "conformite_plan",
            "etat",
            "longueur",
            "nature",
            "reference",
            "emplacement",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["conformite_plan"],
        },
        "Bassin": {
          "tableName": "asst_bassin", "schema": "asst",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_bassin", "typeOptions": [],
          // uuid retiré
          "fields": [
            "conformite_plan",
            "etat",
            "type_bassin",
            "diametre_amont",
            "diametre_aval",
            "capacite",
            "date_construction",
            "forme_bassin",
            "longueur",
            "largeur",
            "hauteur",
            "cote_arrivee",
            "cote_depart",
            "cote_trop_plein",
            "cote_radier",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["etat", "type_bassin", "conformite_plan"],
        },
        "Ouvrage ASS": {
          "tableName": "asst_ouvrage", "schema": "asst",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_ouvrage", "typeOptions": [],
          // uuid retiré
          "fields": [
            "conformite_plan",
            "etat",
            "type_ouvrage",
            "capacite",
            "date_construction",
            "accessibilite",
            "longueur",
            "largeur",
            "hauteur",
            "cote_arrivee",
            "pretraitement",
            "sortie",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["etat", "type_ouvrage", "conformite_plan"],
        },
        "Équipement ASS": {
          "tableName": "asst_equipement", "schema": "asst",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type", "typeOptions": [],
          // uuid retiré
          "fields": [
            "conformite_plan",
            "etat",
            "date_pose",
            "type",
            "typereseau",
            "marque",
            "situation_equipement",
            "profondeur",
            "cote_tn",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["etat", "type", "conformite_plan"],
        },
        "Station ASS": {
          "tableName": "asst_station", "schema": "asst",
          "geometryType": "Point", "hasZ": true, "maxPhotos": 4,
          "typeField": "type_station",
          "typeOptions": [
            "Station de pompage",
            "Station d'épuration",
            "Station de relevage",
            "Autre"
          ],
          // uuid retiré
          "fields": [
            "conformite_plan",
            "nom",
            "etat",
            "type_station",
            "capacite",
            "debit_nominal",
            "date_construction",
            "longueur",
            "largeur",
            "nombre_pompes",
            "cote_arrivee",
            "pretraitement",
            "sortie",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["etat", "type_station", "conformite_plan"],
        },
        "Stations d'épuration": {
          "tableName": "ASS_STA_EPUR",
          "schema": "asst",
          "geometryType": "Point",
          "hasZ": true,
          "maxPhotos": 4,
          "typeField": "type_station",
          "typeOptions": ["Station d'épuration"],
          "fields": [
            "conformite_plan",
            "nom",
            "etat",
            "type_station",
            "capacite",
            "debit_nominal",
            "date_construction",
            "longueur",
            "largeur",
            "nombre_pompes",
            "cote_arrivee",
            "pretraitement",
            "sortie",
            "ass_coor_x",
            "ass_coor_y",
            "ass_coor_z",
            "centre",
            "commentaire"
          ],
          "requiredFields": ["etat", "type_station", "conformite_plan"],
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
    'accuracy',
    'altitude',
    'amont',
    'aval',
    'capacite',
    'chute',
    'cote',
    'debit',
    'diam',
    'distance',
    'hauteur',
    'largeur',
    'long',
    'pente',
    'pression',
    'profondeur',
    'puissance',
    'section',
    'x_',
    'y_',
    'z_',
    'rayon',
    'genratrice',
  };

  static const Set<String> _integerFields = {
    'nb_points',
    'nb_pompes',
    'nb_rames',
    'nbr_arrivees',
    'id_commune',
    'id_province',
    'id_user_creat',
    'id_user_modif',
    'id_user_valid',
  };

  static const Set<String> _dateFields = {
    'date_collecte',
    'date_construction',
    'date_mise_en_service',
    'date_mise_service',
    'date_pose',
    'date_rehabilitation',
    'date_leve',
    'ep_date_insertion',
    'date_creation',
    'date_modif',
    'date_validation',
  };

  static const Set<String> _longTextFields = {
    'commentaire',
    'observation',
    'type_anomalie',
  };

  static const Set<String> _mediumTextFields = {
    'emplacement',
    'nom',
    'observation',
    'ref_rue',
    'ep_observation',
    'ep_adresse',
    'ep_agent',
    'ep_agent_crea',
    'ep_ref_rue',
    'ep_section',
    'ep_sect_com',
    'sec_com',
    'sect_hydr',
    'zone',
  };

  static const Set<String> _varchar400Fields = {
    'abon',
    'adresse',
    'ancien_ref_sap',
    'ancienne_police',
    'diametre',
    'etat_abonnement',
    'id_geo',
    'mat_brts',
    'nom',
    'num_contrat',
    'ref',
    'type_cpt',
  };

  static const Set<String> _uuidFields = {
    'uuid',
  };

  static const Set<String> _booleanLikeFields = {
    'accessibilite',
    'anomalie',
    'boite_coupure',
    'detec_extinc_incendie',
    'lumineux',
    'presence_cunette',
    'presence_ild',
    'rehabilitation',
    'verrouille',
    'ep_anomalie',
    'is_deleted',
    'is_validated',
  };

  static const Set<String> _shortCodeHints = {
    'code',
    'depart',
    'num',
    'numero',
    'reference',
    'ref_',
    'status',
    'statut',
    'tournee',
    'type_',
  };

  /// Champs communs à tous les objets SRM — gérés automatiquement dans _save()
  /// `uuid` est généré automatiquement et ne doit pas apparaître dans `fields`.
  static const List<String> commonFkFields = [
    'uuid',
    'id_agent_crea',
    'id_planche',
    'id_commune',
    'mode_localisation',
    'anomalie',
    'type_anomalie',
    'objet_incomplet',
    'raison_incomplet',
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

    if (_varchar400Fields.contains(field)) {
      return const SrmFieldRule(
        kind: SrmFieldKind.text,
        maxLength: 400,
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
    final normalizedField = field.toLowerCase();
    if (normalizedField.endsWith('_coor_x') ||
        normalizedField.endsWith('_coor_y') ||
        normalizedField.endsWith('_coor_z') ||
        normalizedField.startsWith('x_') ||
        normalizedField.startsWith('y_') ||
        normalizedField.startsWith('z_') ||
        normalizedField.startsWith('lat_') ||
        normalizedField.startsWith('lon_')) {
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
