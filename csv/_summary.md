# Mobile CSV summary

- Workbook: `C:\Users\ANASDA~1\AppData\Local\Temp\branch-xlsx-to-mobile-csvs-yk9tplxs\srm-sheet-2026-04-22.xlsx`
- Output folder: `C:\Users\AnasDahou\Desktop\srm_collecte\csv`
- Sheet prefixes: `ep_`, `asst_`, `elec_`
- Sheets processed: 50

## By sheet

### `ep_regard`

- Table: `ep_regard`
- Format: `dictionary`
- CSV rows kept: 43
- Color stats seen: `{'green': 12, 'red': 3, 'yellow': 20, 'pink': 8, 'none': 14}`
- Ignored examples: none: ep_num, ep_num_regard, num_regard, ep_croquis, ep_detail
- Kept fields preview: emplacement (row 10, FF92D050), ep_ref_rue (row 11, FF92D050), ep_section (row 12, FFFF0000), ep_tampon (row 13, FF92D050), ep_conf_plan (row 14, FF92D050), ep_observation (row 15, FF92D050), ep_anomalie (row 16, FF92D050), mode_localisation (row 17, FFFF0000)

### `ep_regard_pret`

- Table: `ep_regard_pret`
- Format: `simple`
- CSV rows kept: 42
- Color stats seen: `{}`
- Kept fields preview: ep_agent (row 2, simple), ep_sect_com (row 3, simple), ep_statut (row 4, simple), ep_adresse (row 5, simple), ep_agent_crea (row 6, simple), sec_com (row 7, simple), sect_hydr (row 8, simple), zone (row 9, simple)

### `ep_conduite_terrain`

- Table: `conduite_terrain`
- Format: `dictionary`
- CSV rows kept: 16
- Color stats seen: `{'green': 3, 'yellow': 13}`
- Kept fields preview: ep_diam (row 10, FF92D050), ep_mat (row 11, FF92D050), fid (row 12, FFFFFFCC), uuid (row 13, FFFFFFCC), geom (row 14, FFFFFFCC), id_commune (row 15, FFFFFFCC), id_province (row 16, FFFFFFCC), id_user_creat (row 17, FFFFFFCC)

### `ep_conduite_bureau`

- Table: `ep_conduite`
- Format: `dictionary`
- CSV rows kept: 47
- Color stats seen: `{'green': 12, 'yellow': 25, 'pink': 10, 'none': 23}`
- Ignored examples: none: ep_num, ep_code_ter, ep_date_pose, ep_entreprise, ep_ref_marche
- Kept fields preview: ep_type (row 10, FFC6EFCE), ep_diam (row 11, FFC6EFCE), ep_mat (row 12, FFC6EFCE), ep_profondeur (row 13, FFC6EFCE), ep_classe_conduite (row 14, FFC6EFCE), emplacement (row 15, FFC6EFCE), ep_ref_rue (row 16, FF92D050), ep_observ (row 17, FFC6EFCE)

### `ep_traversee`

- Table: `ep_traversee`
- Format: `dictionary`
- CSV rows kept: 35
- Color stats seen: `{'green': 11, 'red': 2, 'yellow': 16, 'pink': 6, 'none': 13}`
- Ignored examples: none: ep_num, ep_code_ter, ep_date_pose, ep_entreprise, ep_ref_marche
- Kept fields preview: type_traver (row 10, FFC6EFCE), ep_diam (row 11, FFC6EFCE), ep_mat (row 12, FFC6EFCE), ep_profondeur (row 13, FFC6EFCE), ep_classe_conduite (row 14, FFC6EFCE), ep_ref_rue (row 15, FF92D050), ep_observ (row 16, FFC6EFCE), ep_conf_plan (row 17, FFC6EFCE)

### `ep_brc_pt`

- Table: `ep_brc_pt`
- Format: `dictionary`
- CSV rows kept: 41
- Color stats seen: `{'green': 11, 'red': 3, 'yellow': 21, 'pink': 6, 'none': 7}`
- Ignored examples: none: tour, date_pose, date_releve, consommation, cin
- Kept fields preview: abon (row 10, FF92D050), nom (row 11, FF92D050), num_contrat (row 12, FF92D050), num_compteur (row 13, FFFF0000), type_cpt (row 14, FF00FF00), diametre (row 15, FF92D050), ep_conf_plan (row 16, FFFF0000), ep_observation (row 17, FF00FF00)

### `ep_cone_reduc`

- Table: `ep_cone_reduc`
- Format: `dictionary`
- CSV rows kept: 37
- Color stats seen: `{'green': 6, 'yellow': 21, 'red': 1, 'pink': 9, 'none': 9}`
- Ignored examples: none: ep_num, ep_code_ter, ep_ref, ep_dtae_pose, ep_entreprise
- Kept fields preview: ep_diam_in (row 10, FFC6EFCE), ep_diam_out (row 11, FFC6EFCE), emplacement (row 12, FFFFFF00), ep_conf_plan (row 13, FFC6EFCE), ep_observation (row 14, FFC6EFCE), ep_anomalie (row 15, FFC6EFCE), type_anomalie (row 16, FFC6EFCE), mode_localisation (row 17, FFFF0000)

### `ep_compteur_i`

- Table: `ep_compteur_i`
- Format: `dictionary`
- CSV rows kept: 42
- Color stats seen: `{'green': 10, 'red': 2, 'yellow': 21, 'pink': 9, 'none': 13}`
- Ignored examples: none: ep_num, ep_code_ter, ep_releve, ep_res_deserv, ep_ref
- Kept fields preview: ep_type (row 10, FF92D050), ep_modele (row 11, FF92D050), ep_calibre (row 12, FF92D050), ep_sourc_alim (row 13, FFFF0000), ep_ref_regard (row 14, FFC6EFCE), ep_n_serie (row 15, FF92D050), ep_marque (row 16, FFFFFF00), ep_compt_fonction (row 17, FFFF0000)

### `ep_bf`

- Table: `ep_bf`
- Format: `dictionary`
- CSV rows kept: 44
- Color stats seen: `{'green': 17, 'yellow': 18, 'pink': 9, 'none': 9}`
- Ignored examples: none: ep_num, ep_code_ter, ep_conform, ep_ref, ep_date_pose
- Kept fields preview: ep_type_bf (row 10, FFC6EFCE), ep_etat (row 11, FFC6EFCE), ep_ref_rue (row 12, FF92D050), statut (row 13, FFC6EFCE), diam_brts (row 14, FFC6EFCE), conform (row 15, FFC6EFCE), ep_fonct (row 16, FFC6EFCE), vanne (row 17, FFC6EFCE)

### `ep_hydrant`

- Table: `ep_hydrant`
- Format: `dictionary`
- CSV rows kept: 47
- Color stats seen: `{'green': 18, 'yellow': 19, 'pink': 10, 'none': 10}`
- Ignored examples: none: ep_num, ep_code_ter, ep_ref, ep_date_pose, ep_ref_marche
- Kept fields preview: ep_type (row 10, FF92D050), ep_etat (row 11, FFC6EFCE), ep_conform (row 12, FFC6EFCE), statut (row 13, FFC6EFCE), type (row 14, FFC6EFCE), marque (row 15, FFC6EFCE), diametre (row 16, FFC6EFCE), diamcond (row 17, FFC6EFCE)

### `ep_obturateur`

- Table: `ep_obturateur`
- Format: `dictionary`
- CSV rows kept: 29
- Color stats seen: `{'green': 5, 'yellow': 18, 'pink': 6, 'none': 5}`
- Ignored examples: none: ep_num, etage_aqua, ep_code_ter, secteur_aqua, ep_tf
- Kept fields preview: ep_diam (row 10, FFC6EFCE), ep_conf_plan (row 11, FFC6EFCE), ep_observation (row 12, FFC6EFCE), ep_anomalie (row 13, FFC6EFCE), mode_localisation (row 14, FFC6EFCE), fid (row 15, FFFFFFCC), uuid (row 16, FFFFFFCC), ep_date_insertion (row 17, FFFFFFCC)

### `ep_vanne`

- Table: `ep_vanne`
- Format: `dictionary`
- CSV rows kept: 44
- Color stats seen: `{'green': 14, 'yellow': 21, 'pink': 9, 'none': 9}`
- Ignored examples: none: ep_num, ep_code_ter, ep_ref, ep_date_pose, ep_entreprise
- Kept fields preview: ep_type (row 10, FFC6EFCE), ep_modele (row 11, FF92D050), ep_diam (row 12, FF92D050), ep_ref_regard (row 13, FFC6EFCE), ep_sens_ferm (row 14, FFC6EFCE), ep_manoeuvre (row 15, FFC6EFCE), ep_etat (row 16, FFC6EFCE), ep_sectionnement (row 17, FFC6EFCE)

### `ep_branchement`

- Table: `ep_branchement`
- Format: `dictionary`
- CSV rows kept: 31
- Color stats seen: `{'green': 7, 'yellow': 17, 'pink': 7, 'none': 6}`
- Ignored examples: none: ep_num, ep_code_ter, ep_ref, ep_date_pose, ep_entreprise
- Kept fields preview: ep_type (row 10, FFC6EFCE), ep_diam (row 11, FF92D050), ep_mat (row 12, FFC6EFCE), ep_observation (row 13, FFC6EFCE), ep_conf_plan (row 14, FFC6EFCE), ep_anomalie (row 15, FFC6EFCE), mode_localisation (row 16, FFC6EFCE), fid (row 17, FFFFFFCC)

### `ep_bache`

- Table: `ep_bache`
- Format: `dictionary`
- CSV rows kept: 35
- Color stats seen: `{'green': 9, 'yellow': 20, 'pink': 6, 'none': 7}`
- Ignored examples: none: ep_num, ep_code_ter, ep_date_pose, ep_entreprise, ep_ref_marche
- Kept fields preview: ep_section (row 10, FFC6EFCE), ep_capacite (row 11, FF92D050), ep_prof (row 12, FF92D050), ep_ref_rue (row 13, FF92D050), emplacement (row 14, FFC6EFCE), ep_conf_plan (row 15, FFC6EFCE), ep_observation (row 16, FFC6EFCE), ep_anomalie (row 17, FFC6EFCE)

### `ep_bouche_arro`

- Table: `ep_bouche_arro`
- Format: `dictionary`
- CSV rows kept: 34
- Color stats seen: `{'green': 5, 'yellow': 18, 'red': 2, 'pink': 9, 'none': 8}`
- Ignored examples: none: ep_num, ep_type, ep_code_ter, ep_ref, ep_date_pose
- Kept fields preview: ep_conform (row 10, FFC6EFCE), ep_conf_plan (row 11, FFC6EFCE), ep_observation (row 12, FFC6EFCE), ep_anomalie (row 13, FFC6EFCE), mode_localisation (row 14, FFC6EFCE), fid (row 15, FFFFFFCC), uuid (row 16, FFFFFFCC), ep_alti (row 17, FFFFFFCC)

### `ep_vidange`

- Table: `ep_vidange`
- Format: `dictionary`
- CSV rows kept: 40
- Color stats seen: `{'green': 12, 'yellow': 20, 'pink': 8, 'none': 8}`
- Ignored examples: none: ep_num, ep_code_ter, ep_ref, ep_date_pose, ep_entreprise
- Kept fields preview: ep_type (row 10, FF92D050), ep_modele (row 11, FF92D050), ep_point_vid (row 12, FFC6EFCE), ep_diam (row 13, FFC6EFCE), ep_ref_regard (row 14, FFC6EFCE), ep_etat (row 15, FFC6EFCE), ep_conf_plan (row 16, FFC6EFCE), ep_observation (row 17, FFC6EFCE)

### `ep_ventouse`

- Table: `ep_ventouse`
- Format: `dictionary`
- CSV rows kept: 39
- Color stats seen: `{'green': 10, 'yellow': 20, 'pink': 9, 'none': 8}`
- Ignored examples: none: ep_num, ep_code_ter, ep_ref, ep_date_pose, ep_entreprise
- Kept fields preview: ep_type (row 10, FFC6EFCE), ep_modele (row 11, FF92D050), ep_diam (row 12, FFC6EFCE), ep_ref_regard (row 13, FFC6EFCE), ep_etat (row 14, FF92D050), ep_conf_plan (row 15, FFC6EFCE), ep_observation (row 16, FFC6EFCE), ep_anomalie (row 17, FFC6EFCE)

### `ep_reduc_pres`

- Table: `ep_reduc_pres`
- Format: `dictionary`
- CSV rows kept: 38
- Color stats seen: `{'green': 8, 'yellow': 19, 'pink': 9, 'red': 2, 'none': 14}`
- Ignored examples: none: ep_num, ep_num_exploitation, ep_code_ter, ep_etat, ep_ref_
- Kept fields preview: emplacement (row 10, FFC6EFCE), ep_marque (row 11, FF92D050), ep_diam (row 12, FF92D050), ep_classe_tampon (row 13, FF92D050), ep_conf_plan (row 14, FFC6EFCE), ep_observation (row 15, FFC6EFCE), ep_anomalie (row 16, FFC6EFCE), mode_localisation (row 17, FFC6EFCE)

### `ep_voie`

- Table: `voie`
- Format: `dictionary`
- CSV rows kept: 14
- Color stats seen: `{'green': 1, 'yellow': 13}`
- Kept fields preview: type (row 10, FF92D050), fid (row 11, FFFFFFCC), uuid (row 12, FFFFFFCC), geom (row 13, FFFFFFCC), id_commune (row 14, FFFFFFCC), id_province (row 15, FFFFFFCC), id_user_creat (row 16, FFFFFFCC), id_user_modif (row 17, FFFFFFCC)

### `ep_centre_tampon`

- Table: `centre_tampon`
- Format: `dictionary`
- CSV rows kept: 16
- Color stats seen: `{'yellow': 16}`
- Kept fields preview: fid (row 10, FFFFFFCC), uuid (row 11, FFFFFFCC), ep_coor_x (row 12, FFFFFFCC), ep_coor_y (row 13, FFFFFFCC), ep_coor_z (row 14, FFFFFFCC), geom (row 15, FFFFFFCC), id_commune (row 16, FFFFFFCC), id_province (row 17, FFFFFFCC)

### `ep_reservoir`

- Table: `ep_reservoir`
- Format: `dictionary`
- CSV rows kept: 45
- Color stats seen: `{'green': 17, 'yellow': 21, 'pink': 7, 'none': 14}`
- Ignored examples: none: ep_num, ep_code_ter, ass_coor_x, ass_coor_y, ep_secteur_com
- Kept fields preview: ep_nom (row 10, FF92D050), ep_type (row 11, FFC6EFCE), ep_forme (row 12, FF92D050), ep_etat_s (row 13, FFC6EFCE), ep_ref_rue (row 14, FF92D050), ep_date_constr (row 15, FF92D050), ep_date_rehab (row 16, FF92D050), ep_type_cap (row 17, FF92D050)

### `ep_forage`

- Table: `ep_forage`
- Format: `dictionary`
- CSV rows kept: 41
- Color stats seen: `{'green': 15, 'yellow': 18, 'pink': 8, 'none': 11}`
- Ignored examples: none: ep_num, ep_code_ter, ep_entreprise, ep_dern_intervention, ass_coor_x
- Kept fields preview: ep_nom (row 10, FF92D050), ep_ire_forage (row 11, FF92D050), ep_type (row 12, FF92D050), ep_date_for (row 13, FF92D050), ep_profond (row 14, FF92D050), ep_etat_s (row 15, FF92D050), ep_hmt (row 16, FF92D050), ep_debit_equip (row 17, FF92D050)

### `ep_noeud`

- Table: `ep_noeud`
- Format: `dictionary`
- CSV rows kept: 11
- Color stats seen: `{'yellow': 11, 'none': 21}`
- Ignored examples: none: fid, uuid, ep_num, ep_ref_rue, ep_alti
- Kept fields preview: geom (row 10, FFFFFFCC), id_commune (row 11, FFFFFFCC), id_province (row 12, FFFFFFCC), id_user_creat (row 13, FFFFFFCC), id_user_modif (row 14, FFFFFFCC), date_creation (row 15, FFFFFFCC), date_modif (row 16, FFFFFFCC), is_deleted (row 17, FFFFFFCC)

### `ep_pompe`

- Table: `ep_pompe`
- Format: `dictionary`
- CSV rows kept: 34
- Color stats seen: `{'green': 11, 'yellow': 18, 'pink': 5, 'none': 8}`
- Ignored examples: none: ep_num, ep_code_ter, ep_entreprise, ep_date_pose, ep_date_interv
- Kept fields preview: ep_pompe_modele (row 10, FF92D050), ep_pompe_ref (row 11, FF92D050), ep_pompe_puissance (row 12, FF92D050), ep_pompe_debit_fo (row 13, FF92D050), ep_hmt (row 14, FF92D050), ep_etat_s (row 15, FF92D050), ep_statut (row 16, FF92D050), ep_conf_plan (row 17, FFC6EFCE)

### `ep_station_pompage`

- Table: `ep_station_pompage`
- Format: `dictionary`
- CSV rows kept: 38
- Color stats seen: `{'green': 10, 'yellow': 19, 'pink': 9, 'none': 13}`
- Ignored examples: none: ep_num, ep_code_ter, ep_date_pose, ep_date_interv, ass_coor_x
- Kept fields preview: ep_nom (row 10, FF92D050), ep_etat_s (row 11, FF92D050), ep_res_deserv (row 12, FF92D050), puissance_installee (row 13, FF92D050), ep_nombre_de_groupe (row 14, FF92D050), ep_debit_global (row 15, FF92D050), ep_conf_plan (row 16, FFC6EFCE), ep_observation (row 17, FFC6EFCE)

### `ep_puit`

- Table: `ep_puit`
- Format: `dictionary`
- CSV rows kept: 28
- Color stats seen: `{'green': 4, 'yellow': 18, 'pink': 6, 'none': 5}`
- Ignored examples: none: ep_num, etage_aqua, ep_code_ter, secteur_aqua, ep_tf
- Kept fields preview: ep_conf_plan (row 10, FFC6EFCE), ep_observation (row 11, FFC6EFCE), ep_anomalie (row 12, FFC6EFCE), mode_localisation (row 13, FFC6EFCE), fid (row 14, FFFFFFCC), uuid (row 15, FFFFFFCC), ep_date_insertion (row 16, FFFFFFCC), altitute (row 17, FFFFFFCC)

### `ep_st_demineralisation`

- Table: `ep_st_demineralisation`
- Format: `dictionary`
- CSV rows kept: 0
- Color stats seen: `{'none': 45}`
- Ignored examples: none: fid, uuid, ep_num, ep_nom, ep_code_ter

### `ep_tn`

- Table: `tn`
- Format: `dictionary`
- CSV rows kept: 16
- Color stats seen: `{'yellow': 16}`
- Kept fields preview: fid (row 10, FFFFFFCC), uuid (row 11, FFFFFFCC), ep_coor_x (row 12, FFFFFFCC), ep_coor_y (row 13, FFFFFFCC), ep_coor_z (row 14, FFFFFFCC), geom (row 15, FFFFFFCC), id_commune (row 16, FFFFFFCC), id_province (row 17, FFFFFFCC)

### `ep_anomalie_conduite`

- Table: `anomalie_conduite`
- Format: `dictionary`
- CSV rows kept: 14
- Color stats seen: `{'green': 1, 'yellow': 13}`
- Kept fields preview: type_anomalie (row 10, FF92D050), fid (row 11, FFFFFFCC), uuid (row 12, FFFFFFCC), geom (row 13, FFFFFFCC), id_commune (row 14, FFFFFFCC), id_province (row 15, FFFFFFCC), id_user_creat (row 16, FFFFFFCC), id_user_modif (row 17, FFFFFFCC)

### `asst_bassin`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 3
- Color stats seen: `{'none': 39, 'pink': 3}`
- Ignored examples: none: fid, objectid, uuid, etat, diametre_amont
- Kept fields preview: conformite_plan (row 13, FFE2EFDA), type_bassin (row 15, FFE2EFDA), anomalie (row 37, FFE2EFDA)

### `asst_branchement`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 6
- Color stats seen: `{'none': 30, 'pink': 6}`
- Ignored examples: none: fid, objectid, uuid, classe, date_pose
- Kept fields preview: conformite_plan (row 13, FFE2EFDA), etat (row 15, FFE2EFDA), typereseau (row 19, FFE2EFDA), rehabilitation (row 21, FFE2EFDA), type_activite (row 25, FFE2EFDA), anomalie (row 33, FFE2EFDA)

### `asst_canalisation_bureau`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 5
- Color stats seen: `{'none': 33, 'pink': 5}`
- Ignored examples: none: fid, geom, objectid, uuid, conformite_plan
- Kept fields preview: classe (row 15, FFE2EFDA), nature (row 19, FFE2EFDA), type_ecoulement (row 29, FFE2EFDA), type_conduite (row 31, FFE2EFDA), protection_anticorrosion (row 33, FFE2EFDA)

### `asst_canalisation_reutilisation`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 3
- Color stats seen: `{'none': 38, 'pink': 3}`
- Ignored examples: none: fid, objectid, uuid, classe, date_pose
- Kept fields preview: conformite_plan (row 13, FFE2EFDA), etat (row 15, FFE2EFDA), type_ecoulement (row 27, FFE2EFDA)

### `asst_canalisation_terrain`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 7
- Color stats seen: `{'none': 34, 'pink': 7}`
- Ignored examples: none: fid, objectid, uuid, classe, date_pose
- Kept fields preview: conformite_plan (row 13, FFE2EFDA), etat (row 15, FFE2EFDA), typereseau (row 19, FFE2EFDA), rehabilitation (row 21, FFE2EFDA), emplacement (row 27, FFE2EFDA), type_section (row 29, FFE2EFDA), type_rehabilitation (row 31, FFE2EFDA)

### `asst_equipement`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 4
- Color stats seen: `{'none': 34, 'pink': 4}`
- Ignored examples: none: fid, objectid, uuid, etat, date_pose
- Kept fields preview: conformite_plan (row 13, FFE2EFDA), typereseau (row 17, FFE2EFDA), situation_equipement (row 19, FFE2EFDA), anomalie (row 33, FFE2EFDA)

### `asst_ouvrage`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 3
- Color stats seen: `{'none': 36, 'pink': 3}`
- Ignored examples: none: fid, objectid, uuid, etat, capacite
- Kept fields preview: conformite_plan (row 13, FFE2EFDA), type_ouvrage (row 15, FFE2EFDA), pretraitement (row 23, FFE2EFDA)

### `asst_regard`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 9
- Color stats seen: `{'none': 37, 'pink': 9}`
- Ignored examples: none: fid, objectid, uuid, etat, type_tampon
- Kept fields preview: conformite_plan (row 13, FFE2EFDA), type_regard (row 15, FFE2EFDA), typereseau (row 17, FFE2EFDA), forme (row 19, FFE2EFDA), verrouille (row 21, FFE2EFDA), rehabilitation (row 23, FFE2EFDA), nature_corps (row 25, FFE2EFDA), chute (row 29, FFE2EFDA)

### `asst_regard_branchement`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 7
- Color stats seen: `{'none': 37, 'pink': 7}`
- Ignored examples: none: fid, objectid, uuid, etat, typereseau
- Kept fields preview: conformite_plan (row 13, FFE2EFDA), type_tampon (row 15, FFE2EFDA), classe_tampon (row 17, FFE2EFDA), accessibilite (row 21, FFE2EFDA), rehabilitation (row 23, FFE2EFDA), nature_corps (row 25, FFE2EFDA), anomalie (row 39, FFE2EFDA)

### `asst_station`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 4
- Color stats seen: `{'none': 36, 'pink': 4}`
- Ignored examples: none: fid, objectid, uuid, nom, type_station
- Kept fields preview: conformite_plan (row 13, FFE2EFDA), etat (row 15, FFE2EFDA), sortie (row 25, FFE2EFDA), anomalie (row 35, FFE2EFDA)

### `elec_cellule`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 2
- Color stats seen: `{'none': 25, 'pink': 2}`
- Ignored examples: none: fid, objectid, uuid, id_poste, id_transfo
- Kept fields preview: fonction (row 23, FFE2EFDA), type_commande (row 25, FFE2EFDA)

### `elec_coffret_bt`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 4
- Color stats seen: `{'none': 38, 'pink': 4}`
- Ignored examples: none: fid, objectid, uuid, id_poste, id_depart_bt
- Kept fields preview: type_coffret (row 15, FFE2EFDA), statut_coffret (row 19, FFE2EFDA), enveloppe_coffret (row 29, FFE2EFDA), anomalie (row 37, FFE2EFDA)

### `elec_depart_bt`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 2
- Color stats seen: `{'none': 24, 'pink': 2}`
- Ignored examples: none: fid, objectid, uuid, id_poste, id_transfo
- Kept fields preview: tension_bt (row 17, FFE2EFDA), anomalie (row 29, FFE2EFDA)

### `elec_depart_hta`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 1
- Color stats seen: `{'none': 20, 'pink': 1}`
- Ignored examples: none: fid, objectid, uuid, id_poste, nom_depart
- Kept fields preview: tension_hta (row 15, FFE2EFDA)

### `elec_noeud_raccord`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 2
- Color stats seen: `{'none': 33, 'pink': 2}`
- Ignored examples: none: fid, objectid, uuid, id_troncon_bt, id_depart_bt
- Kept fields preview: type_raccord (row 15, FFE2EFDA), conformite_plan (row 25, FFE2EFDA)

### `elec_point_desserte`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 3
- Color stats seen: `{'none': 37, 'pink': 3}`
- Ignored examples: none: fid, objectid, uuid, id_poste, id_coffret_bt
- Kept fields preview: boite_coupure (row 19, FFE2EFDA), conformite_plan (row 29, FFE2EFDA), anomalie (row 35, FFE2EFDA)

### `elec_poste`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 7
- Color stats seen: `{'none': 50, 'pink': 7}`
- Ignored examples: none: fid, objectid, uuid, nom_poste, type_poste
- Kept fields preview: nature_poste (row 15, FFE2EFDA), etat_service (row 19, FFE2EFDA), tableau_ep (row 21, FFE2EFDA), support_communication (row 27, FFE2EFDA), presence_ild (row 31, FFE2EFDA), tableau_bt (row 33, FFE2EFDA), conformite_plan (row 47, FFE2EFDA)

### `elec_support`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 7
- Color stats seen: `{'none': 37, 'pink': 7}`
- Ignored examples: none: fid, objectid, uuid, id_depart_hta, id_depart_bt
- Kept fields preview: type_support (row 15, FFE2EFDA), etat_support (row 19, FFE2EFDA), type_assemblage (row 21, FFE2EFDA), type_protection (row 23, FFE2EFDA), mise_a_la_terre (row 25, FFE2EFDA), type_balise (row 31, FFE2EFDA), anomalie (row 39, FFE2EFDA)

### `elec_transformateur`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 3
- Color stats seen: `{'none': 33, 'pink': 3}`
- Ignored examples: none: fid, objectid, uuid, id_poste, id_cellule
- Kept fields preview: puiss_transfo (row 17, FFE2EFDA), regleur_en_charge (row 35, FFE2EFDA), anomalie (row 39, FFE2EFDA)

### `elec_troncon_bt`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 4
- Color stats seen: `{'none': 37, 'pink': 4}`
- Ignored examples: none: fid, objectid, uuid, id_poste, id_depart_bt
- Kept fields preview: techcable (row 15, FFE2EFDA), status_troncon (row 19, FFE2EFDA), nu (row 27, FFE2EFDA), arme (row 29, FFE2EFDA)

### `elec_troncon_hta`

- Table: ``
- Format: `dictionary`
- CSV rows kept: 4
- Color stats seen: `{'none': 39, 'pink': 4}`
- Ignored examples: none: fid, objectid, uuid, id_depart_hta, id_noeud_raccord
- Kept fields preview: status_troncon (row 15, FFE2EFDA), metal_conduct (row 19, FFE2EFDA), type_mise_terre (row 25, FFE2EFDA), tension (row 27, FFE2EFDA)
