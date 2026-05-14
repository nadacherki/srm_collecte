# SRM dictionary audit

- Workbook: `C:\Users\AnasDahou\Downloads\srm_ep_only.xlsx`
- Django models: `C:\Users\AnasDahou\Desktop\srm_collecte\API_GeoDjango\pprcollecte\api\models.py`
- Schema audited: `ep`

## Summary

- Workbook tables: 28 | Model tables: 27
- Exact matches: 1 | Alias matches: 22
- Workbook tables without model match: 5
- Model tables without workbook match: 4
- Python runtime: 3.12.13

## Module check

- `openpyxl`: 3.1.5
- `pandas`: 3.0.1
- `numpy`: 2.3.5

## Alias matches

- `conduite_terrain` -> `ep_conduite_terrain`
- `ep_bf` -> `borne_fontaine`
- `ep_bouche_arro` -> `bouche_darrosage`
- `ep_branchement` -> `branchement`
- `ep_brc_pt` -> `compteur_abonne`
- `ep_compteur_i` -> `compteur_reseau`
- `ep_conduite` -> `ep_conduite_bureau`
- `ep_cone_reduc` -> `cone_de_reduction`
- `ep_forage` -> `forage`
- `ep_hydrant` -> `hydrant`
- `ep_noeud` -> `noeud`
- `ep_obturateur` -> `obturateur`
- `ep_pompe` -> `pompe`
- `ep_puit` -> `puit`
- `ep_reduc_pres` -> `reducteur_de_pression`
- `ep_regard` -> `regard_ep`
- `ep_reservoir` -> `reservoir`
- `ep_station_pompage` -> `station_de_pompage`
- `ep_traversee` -> `traverse`
- `ep_vanne` -> `vanne`
- `ep_ventouse` -> `ventouse`
- `ep_vidange` -> `vanne_de_vidange`

## Workbook tables without model match

- `anomalie_conduite`
- `ep_bache`
- `ep_st_demineralisation`
- `tn`
- `voie`

## Model tables without workbook match

- `autre_objet`
- `borne_onep`
- `bouche_cles`
- `planche`

## Field deltas

### `centre_tampon` -> `centre_tampon` (exact)

- Workbook fields: 16 | Model fields: 26 | Common: 7
- Workbook only (9): `date_creation`, `date_modif`, `date_validation`, `id_province`, `id_user_creat`, `id_user_modif`, `id_user_valid`, `is_deleted`, `is_validated`
- Model only (19): `anomalie`, `conformite_plan`, `emplacement`, `ep_etat`, `ep_num`, `ep_statut`, `ep_type`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `mode_localisation`

### `ep_reservoir` -> `reservoir` (alias)

- Workbook fields: 59 | Model fields: 29 | Common: 12
- Workbook only (47): `altitute`, `ass_coor_x`, `ass_coor_y`, `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_cote_rad`
- Model only (17): `anomalie`, `conformite_plan`, `emplacement`, `ep_cote_radier`, `ep_cote_trop_plein`, `ep_etat`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `observation`, `photo_1`

### `ep_conduite` -> `ep_conduite_bureau` (alias)

- Workbook fields: 70 | Model fields: 36 | Common: 26
- Workbook only (44): `altitute`, `annee_renouv`, `autocad_layer`, `date_creation`, `date_modif`, `date_validation`, `ep_adresse`, `ep_agent_crea`, `ep_agent_maj`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`
- Model only (10): `anomalie`, `conformite_plan`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `photo_1`, `photo_2`, `ref_rue`, `type_anomalie`

### `ep_forage` -> `forage` (alias)

- Workbook fields: 52 | Model fields: 28 | Common: 10
- Workbook only (42): `altitute`, `ass_coor_x`, `ass_coor_y`, `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_for`
- Model only (18): `anomalie`, `conformite_plan`, `emplacement`, `ep_debit`, `ep_etat`, `ep_profondeur`, `ep_statut`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `observation`

### `ep_station_pompage` -> `station_de_pompage` (alias)

- Workbook fields: 51 | Model fields: 28 | Common: 10
- Workbook only (41): `altitute`, `ass_coor_x`, `ass_coor_y`, `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`
- Model only (18): `anomalie`, `conformite_plan`, `emplacement`, `ep_capacite`, `ep_etat`, `ep_nb_pompes`, `ep_type`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `observation`

### `ep_traversee` -> `traverse` (alias)

- Workbook fields: 48 | Model fields: 21 | Common: 7
- Workbook only (41): `date_creation`, `date_modif`, `date_validation`, `ep_adresse`, `ep_agent_crea`, `ep_agent_maj`, `ep_anomalie`, `ep_classe_conduite`, `ep_code_ter`, `ep_conf_plan`, `ep_croquis`, `ep_date_insertion`
- Model only (14): `anomalie`, `conformite_plan`, `emplacement`, `ep_longueur`, `ep_type`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `observation`, `photo_1`, `photo_2`

### `ep_reduc_pres` -> `reducteur_de_pression` (alias)

- Workbook fields: 52 | Model fields: 29 | Common: 12
- Workbook only (40): `altitute`, `date_creation`, `date_modif`, `date_validation`, `derctrl`, `ep_adresse`, `ep_agent`, `ep_agent_crea`, `ep_alti`, `ep_anomalie`, `ep_classe_tampon`, `ep_code_ter`
- Model only (17): `anomalie`, `conformite_plan`, `ep_statut`, `ep_type`, `id_agent_crea`, `id_conduite`, `id_mission`, `id_planche`, `id_projet`, `id_regard`, `observation`, `photo_1`

### `ep_hydrant` -> `hydrant` (alias)

- Workbook fields: 57 | Model fields: 31 | Common: 17
- Workbook only (40): `adresse`, `codinsee`, `conform`, `date_creation`, `date_modif`, `date_validation`, `derctrl`, `diamcond`, `diametre`, `dispo`, `ep_agent`, `ep_agent_crea`
- Model only (14): `anomalie`, `conformite_plan`, `ep_diam`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `observation`, `photo_1`, `photo_2`, `photo_3`, `photo_4`

### `ep_bf` -> `borne_fontaine` (alias)

- Workbook fields: 53 | Model fields: 31 | Common: 14
- Workbook only (39): `adresse`, `compt_g`, `conform`, `date_creation`, `date_modif`, `date_validation`, `derctrl`, `diam_brts`, `diam_comp`, `ep_agent`, `ep_agent_crea`, `ep_alti`
- Model only (17): `anomalie`, `conformite_plan`, `emplacement`, `ep_diam`, `ep_type`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `marque`, `observation`, `photo_1`

### `ep_pompe` -> `pompe` (alias)

- Workbook fields: 42 | Model fields: 28 | Common: 10
- Workbook only (32): `altitute`, `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`, `ep_date_interv`, `ep_date_pose`
- Model only (18): `anomalie`, `conformite_plan`, `emplacement`, `ep_debit`, `ep_etat`, `ep_puissance`, `ep_type`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `observation`

### `ep_vidange` -> `vanne_de_vidange` (alias)

- Workbook fields: 48 | Model fields: 34 | Common: 17
- Workbook only (31): `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_alti`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`, `ep_date_interv`, `ep_date_pose`, `ep_entreprise`
- Model only (17): `anomalie`, `conformite_plan`, `etage_aqua`, `id_agent_crea`, `id_conduite`, `id_mission`, `id_planche`, `id_projet`, `id_regard`, `observation`, `photo_1`, `photo_2`

### `ep_compteur_i` -> `compteur_reseau` (alias)

- Workbook fields: 55 | Model fields: 42 | Common: 27
- Workbook only (28): `altitute`, `date_creation`, `date_modif`, `date_validation`, `emplacement`, `ep_agent`, `ep_agent_crea`, `ep_alti`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`
- Model only (15): `anomalie`, `conformite_plan`, `id_agent_crea`, `id_conduite`, `id_mission`, `id_planche`, `id_projet`, `id_regard`, `observation`, `photo_1`, `photo_2`, `photo_3`

### `ep_noeud` -> `noeud` (alias)

- Workbook fields: 32 | Model fields: 25 | Common: 5
- Workbook only (27): `altitute`, `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_alti`, `ep_conf_plan`, `ep_observation`, `ep_ref`, `ep_ref_rue`, `ep_secteur_com`
- Model only (20): `anomalie`, `conformite_plan`, `emplacement`, `ep_coor_x`, `ep_coor_y`, `ep_coor_z`, `ep_statut`, `ep_type`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`

### `ep_bouche_arro` -> `bouche_darrosage` (alias)

- Workbook fields: 42 | Model fields: 32 | Common: 15
- Workbook only (27): `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_alti`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_conform`, `ep_date_insertion`, `ep_date_pose`
- Model only (17): `anomalie`, `conformite_plan`, `emplacement`, `ep_marque`, `etage_aqua`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `observation`, `photo_1`, `photo_2`

### `ep_ventouse` -> `ventouse` (alias)

- Workbook fields: 47 | Model fields: 37 | Common: 20
- Workbook only (27): `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_alti`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`, `ep_date_pose`, `ep_etat`
- Model only (17): `anomalie`, `conformite_plan`, `etage_aqua`, `id_agent_crea`, `id_conduite`, `id_mission`, `id_planche`, `id_projet`, `id_regard`, `observation`, `photo_1`, `photo_2`

### `ep_vanne` -> `vanne` (alias)

- Workbook fields: 53 | Model fields: 40 | Common: 26
- Workbook only (27): `altitute`, `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_alti`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`, `ep_date_pose`
- Model only (14): `anomalie`, `conformite_plan`, `id_agent_crea`, `id_conduite`, `id_mission`, `id_planche`, `id_projet`, `id_regard`, `observation`, `photo_1`, `photo_2`, `photo_3`

### `ep_cone_reduc` -> `cone_de_reduction` (alias)

- Workbook fields: 46 | Model fields: 32 | Common: 19
- Workbook only (27): `altitute`, `date_creation`, `date_modif`, `date_validation`, `emplacement`, `ep_agent`, `ep_agent_crea`, `ep_alti`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`
- Model only (13): `anomalie`, `conformite_plan`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `id_regard`, `observation`, `photo_1`, `photo_2`, `photo_3`, `photo_4`

### `ep_branchement` -> `branchement` (alias)

- Workbook fields: 37 | Model fields: 23 | Common: 11
- Workbook only (26): `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`, `ep_date_pose`, `ep_entreprise`, `ep_long_r`
- Model only (12): `anomalie`, `conformite_plan`, `emplacement`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `observation`, `photo_1`, `photo_2`, `ref_rue`, `type_anomalie`

### `ep_brc_pt` -> `compteur_abonne` (alias)

- Workbook fields: 49 | Model fields: 44 | Common: 26
- Workbook only (23): `ancien_ref_sap`, `date_creation`, `date_modif`, `date_validation`, `diametre`, `ep_agent`, `ep_agent_crea`, `ep_anomalie`, `ep_conf_plan`, `ep_coor_Z`, `ep_date_insertion`, `ep_observation`
- Model only (18): `anomalie`, `conformite_plan`, `date_leve`, `diametre_calibre_terrain`, `diametre_conduite`, `emplacement`, `ep_coor_z`, `ep_diam`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`

### `ep_obturateur` -> `obturateur` (alias)

- Workbook fields: 34 | Model fields: 29 | Common: 11
- Workbook only (23): `altitute`, `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`, `ep_observation`, `ep_tf`
- Model only (18): `anomalie`, `conformite_plan`, `emplacement`, `ep_etat`, `ep_type`, `id_agent_crea`, `id_conduite`, `id_mission`, `id_planche`, `id_projet`, `id_regard`, `observation`

### `ep_puit` -> `puit` (alias)

- Workbook fields: 33 | Model fields: 27 | Common: 10
- Workbook only (23): `altitute`, `date_creation`, `date_modif`, `date_validation`, `ep_agent`, `ep_agent_crea`, `ep_anomalie`, `ep_code_ter`, `ep_conf_plan`, `ep_date_insertion`, `ep_observation`, `ep_tf`
- Model only (17): `anomalie`, `conformite_plan`, `emplacement`, `ep_etat`, `ep_profondeur`, `ep_type`, `id_agent_crea`, `id_mission`, `id_planche`, `id_projet`, `observation`, `photo_1`

### `ep_regard` -> `regard_ep` (alias)

- Workbook fields: 58 | Model fields: 40 | Common: 40
- Workbook only (18): `ON ajoute : nombre de vanne , nombre de ventouse , nombre de cone de reduction , nombre d obturatuer , nombre de compteur reseau`, `anom_regard`, `ep_ano_regard`, `ep_code_ter`, `ep_croquis`, `ep_date_pose`, `ep_detail`, `ep_dxf_dwg`, `ep_entreprise`, `ep_num`, `ep_num_regard`, `ep_photo`
- Model only (0): None

### `conduite_terrain` -> `ep_conduite_terrain` (alias)

- Workbook fields: 16 | Model fields: 36 | Common: 7
- Workbook only (9): `date_creation`, `date_modif`, `date_validation`, `id_province`, `id_user_creat`, `id_user_modif`, `id_user_valid`, `is_deleted`, `is_validated`
- Model only (29): `anomalie`, `conformite_plan`, `emplacement`, `ep_date_interv`, `ep_entreprise`, `ep_etage_p`, `ep_long_c`, `ep_long_r`, `ep_num`, `ep_profondeur`, `ep_ref_marche`, `ep_sect_hydro`
