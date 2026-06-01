# Mobile Config Schema Coherence Audit

- Generated at: `2026-06-01T13:28:08`
- Schemas: `ep, asst`

## Summary

- `form_tables`: 61
- `physical_tables_checked`: 61
- `attributes_checked`: 2909
- `choices_checked`: 928
- `missing_physical_tables`: 0
- `type_mismatches`: 0
- `nullable_mismatches`: 0
- `not_valid_required_constraints`: 209
- `attributes_without_physical_column`: 0
- `physical_columns_without_attribute`: 0
- `choices_without_attribute`: 0
- `choices_without_physical_column`: 0
- `choice_attribute_link_mismatches`: 0
- `choice_default_mismatches`: 0

## missing_physical_tables

OK

## type_mismatches

OK

## nullable_mismatches

OK

## not_valid_required_constraints

| attribute_id | column | configured_nullable | constraint_names | existing_violations | physical_not_null | schema | table |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3546 | ASS_CONF_PLAN | False | srm_req_a663eebf09212843 | 0 | False | asst | ASS_BRANCHEMENT |
| 3534 | ASS_DIAM | False | srm_req_6910f0af0789c30c | 0 | False | asst | ASS_BRANCHEMENT |
| 3539 | ASS_LONG_R | False | srm_req_8e91f4090027fd38 | 0 | False | asst | ASS_BRANCHEMENT |
| 3535 | ASS_MAT | False | srm_req_1105062c8ceafc34 | 0 | False | asst | ASS_BRANCHEMENT |
| 3540 | ASS_REGARD_FAC | False | srm_req_7fa400d9e8fccff7 | 0 | False | asst | ASS_BRANCHEMENT |
| 3536 | ASS_TYPE_RESEAU | False | srm_req_2fda582855a33011 | 0 | False | asst | ASS_BRANCHEMENT |
| 3537 | EMPLACEMENT | False | srm_req_159b8accf7b07cd9 | 0 | False | asst | ASS_BRANCHEMENT |
| 3706 | ASS_CONF_PLAN | False | srm_req_a663eebf09212843 | 0 | False | asst | ASS_COLLECTEUR |
| 3687 | ASS_DATE_INSERTION | False | srm_req_8940c55a9b08cbe5 | 0 | False | asst | ASS_COLLECTEUR |
| 3679 | ASS_DIAM | False | srm_req_6910f0af0789c30c | 0 | False | asst | ASS_COLLECTEUR |
| 3696 | ASS_LONG_R | False | srm_req_8e91f4090027fd38 | 0 | False | asst | ASS_COLLECTEUR |
| 3680 | ASS_MAT | False | srm_req_1105062c8ceafc34 | 0 | False | asst | ASS_COLLECTEUR |
| 3697 | ASS_PROF_AMONT | False | srm_req_7a667b0d5d839d3b | 0 | False | asst | ASS_COLLECTEUR |
| 3698 | ASS_PROF_AVAL | False | srm_req_ba898acc72ba2ac4 | 0 | False | asst | ASS_COLLECTEUR |
| 3681 | ASS_SECTION | False | srm_req_f4ec70c443eb1351 | 0 | False | asst | ASS_COLLECTEUR |
| 3682 | ASS_TYPE_RESEAU | False | srm_req_2fda582855a33011 | 0 | False | asst | ASS_COLLECTEUR |
| 3685 | EMPLACEMENT | False | srm_req_159b8accf7b07cd9 | 0 | False | asst | ASS_COLLECTEUR |
| 3723 | MATERIAU | False | srm_req_211426826e8b83a3 | 0 | False | asst | ASS_COLLECTEUR |
| 4251 | ASS_CHUTE | False | srm_req_d8486a1ffe244111 | 4 | False | asst | ASS_REGARD |
| 4271 | ASS_CONF_PLAN | False | srm_req_a663eebf09212843 | 4 | False | asst | ASS_REGARD |
| 4272 | ASS_DEPOT | False | srm_req_aaa0eccbd437d47a | 4 | False | asst | ASS_REGARD |
| 4250 | ASS_ECHLONS | False | srm_req_02b012f9971f4f27 | 4 | False | asst | ASS_REGARD |
| 4252 | ASS_FONCTION_REGARD | False | srm_req_56c0f62103a65290 | 4 | False | asst | ASS_REGARD |
| 4277 | ASS_PHOTO | False | srm_req_502802859b7a4248 | 4 | False | asst | ASS_REGARD |
| 4268 | ASS_PROFONDEUR | False | srm_req_d26655d09221b248 | 4 | False | asst | ASS_REGARD |
| 4247 | ASS_SECTION | False | srm_req_f4ec70c443eb1351 | 4 | False | asst | ASS_REGARD |
| 4249 | ASS_TAMPON | False | srm_req_31caa38b0404e201 | 4 | False | asst | ASS_REGARD |
| 4246 | ASS_TYPE | False | srm_req_531151f63f311f7c | 4 | False | asst | ASS_REGARD |
| 4253 | ASS_TYPE_RESEAU | False | srm_req_2fda582855a33011 | 4 | False | asst | ASS_REGARD |
| 4248 | EMPLACEMENT | False | srm_req_159b8accf7b07cd9 | 4 | False | asst | ASS_REGARD |
| 4265 | ZSURF | False | srm_req_63d7c2f29636dd91 | 4 | False | asst | ASS_REGARD |
| 4418 | ASS_CONF_PLAN | False | srm_req_a663eebf09212843 | 0 | False | asst | ASS_STA_EPUR |
| 4406 | ASS_DATE_INSERTION | False | srm_req_8940c55a9b08cbe5 | 0 | False | asst | ASS_STA_EPUR |
| 4404 | ASS_DIMENSION | False | srm_req_13a7aa88a6e53b6d | 0 | False | asst | ASS_STA_EPUR |
| 4403 | ASS_NB_COMPA | False | srm_req_e40108d652674d40 | 0 | False | asst | ASS_STA_EPUR |
| 4399 | ASS_NOM | False | srm_req_8696c527e09ad847 | 0 | False | asst | ASS_STA_EPUR |
| 4424 | ASS_PHOTO | False | srm_req_502802859b7a4248 | 0 | False | asst | ASS_STA_EPUR |
| 4405 | ASS_VOLUME | False | srm_req_2e4ecb397aacf825 | 0 | False | asst | ASS_STA_EPUR |
| 4412 | RADIER | False | srm_req_d3701d7c06041d54 | 0 | False | asst | ASS_STA_EPUR |
| 4411 | ZSURF | False | srm_req_63d7c2f29636dd91 | 0 | False | asst | ASS_STA_EPUR |
| 17 | ep_diam | False | srm_req_421b2a713aa2a7e3 | 0 | False | ep | conduite_terrain |
| 18 | ep_mat | False | srm_req_5f0fd8cf54fd1f82 | 0 | False | ep | conduite_terrain |
| 1678 | emplacement | False | srm_req_ccc1f9f50bf6f51b | 0 | False | ep | ep_bache |
| 121 | ep_capacite | False | srm_req_74e47095999dad73 | 0 | False | ep | ep_bache |
| 128 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_bache |
| 122 | ep_prof | False | srm_req_1255df8cd9a55517 | 0 | False | ep | ep_bache |
| 123 | ep_ref_rue | False | srm_req_af41a9e77b0e3e82 | 0 | False | ep | ep_bache |
| 120 | ep_section | False | srm_req_46a8ddfe9cb6b0a5 | 0 | False | ep | ep_bache |
| 42 | compt_g | False | srm_req_003e238982c6b1aa | 0 | False | ep | ep_bf |
| 34 | conform | False | srm_req_15d8d6673c820eee | 76 | False | ep | ep_bf |
| 847 | diam_brts | False | srm_req_0cc7f49672bb374e | 125 | False | ep | ep_bf |
| 836 | diam_comp | False | srm_req_843072940b984b99 | 1 | False | ep | ep_bf |
| 39 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 1 | False | ep | ep_bf |
| 845 | ep_etat | False | srm_req_79fdcb521bb1ca80 | 1 | False | ep | ep_bf |
| 35 | ep_fonct | False | srm_req_bd0a544f9165e97b | 1 | False | ep | ep_bf |
| 33 | ep_ref_rue | False | srm_req_af41a9e77b0e3e82 | 1 | False | ep | ep_bf |
| 43 | ep_service | False | srm_req_b238ab3f8802f93d | 267 | False | ep | ep_bf |
| 844 | ep_type_bf | False | srm_req_1f055f7f547dba20 | 3 | False | ep | ep_bf |
| 848 | mat_brts | False | srm_req_6cddb036dc253343 | 267 | False | ep | ep_bf |
| 41 | nb_robinets | False | srm_req_cf001232de8fe4c4 | 2 | False | ep | ep_bf |
| 846 | statut | False | srm_req_d099aae5c339fa40 | 1 | False | ep | ep_bf |
| 36 | vanne | False | srm_req_4963c81120e6e803 | 75 | False | ep | ep_bf |
| 135 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_bouche_arro |
| 69 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_branchement |
| 63 | ep_diam | False | srm_req_421b2a713aa2a7e3 | 0 | False | ep | ep_branchement |
| 1716 | ep_mat | False | srm_req_5f0fd8cf54fd1f82 | 0 | False | ep | ep_branchement |
| 62 | ep_type | False | srm_req_8b57dcc48771402d | 0 | False | ep | ep_branchement |
| 46 | abon | False | srm_req_02fde227fdc7b3aa | 718 | False | ep | ep_brc_pt |
| 49 | adresse | False | srm_req_4bef6bece607e237 | 715 | False | ep | ep_brc_pt |
| 59 | ancien_ref_sap | False | srm_req_d5ca9878f00c3ec0 | 715 | False | ep | ep_brc_pt |
| 61 | ancienne_police | False | srm_req_59f100c54eef6520 | 715 | False | ep | ep_brc_pt |
| 55 | diametre | False | srm_req_be46010c9818dd87 | 233 | False | ep | ep_brc_pt |
| 57 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 2156 | False | ep | ep_brc_pt |
| 53 | etat_abonnement | False | srm_req_e0fb9d14788889bd | 715 | False | ep | ep_brc_pt |
| 60 | id_geo | False | srm_req_116f5d0a0856a13f | 715 | False | ep | ep_brc_pt |
| 48 | nom | False | srm_req_aee37c30f5d091a4 | 644 | False | ep | ep_brc_pt |
| 51 | num_contrat | False | srm_req_03f82ea0e39bf8df | 642 | False | ep | ep_brc_pt |
| 54 | type_cpt | False | srm_req_7ff46fde2d3bb873 | 2158 | False | ep | ep_brc_pt |
| 1683 | emplacement | False | srm_req_ccc1f9f50bf6f51b | 38 | False | ep | ep_compteur_i |
| 88 | ep_calibre | False | srm_req_e8d49c72862ac394 | 0 | False | ep | ep_compteur_i |
| 97 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_compteur_i |
| 87 | ep_modele | False | srm_req_2c17f0121384b0ae | 0 | False | ep | ep_compteur_i |
| 93 | ep_n_serie | False | srm_req_fc7b524b64b8ce7f | 35 | False | ep | ep_compteur_i |
| 90 | ep_ref_regard | False | srm_req_d406add43c0ab4ef | 0 | False | ep | ep_compteur_i |
| 1763 | ep_type | False | srm_req_8b57dcc48771402d | 0 | False | ep | ep_compteur_i |
| 1688 | emplacement | False | srm_req_ccc1f9f50bf6f51b | 54 | False | ep | ep_cone_reduc |
| 103 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_cone_reduc |
| 1765 | ep_diam_in | False | srm_req_8962282713900819 | 0 | False | ep | ep_cone_reduc |
| 1766 | ep_diam_out | False | srm_req_5085f2b5d851ab23 | 0 | False | ep | ep_cone_reduc |
| 118 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 2 | False | ep | ep_forage |
| 108 | ep_date_for | False | srm_req_dba605a54d9d4930 | 2 | False | ep | ep_forage |
| 112 | ep_debit_equip | False | srm_req_a640ce7b614e8eae | 2 | False | ep | ep_forage |
| 114 | ep_debit_fo | False | srm_req_f469141346876188 | 2 | False | ep | ep_forage |
| 117 | ep_diam | False | srm_req_421b2a713aa2a7e3 | 1 | False | ep | ep_forage |
| 110 | ep_etat_s | False | srm_req_fca5852a04882fe5 | 2 | False | ep | ep_forage |
| 111 | ep_hmt | False | srm_req_c49ce0900c7029c0 | 2 | False | ep | ep_forage |
| 106 | ep_ire_forage | False | srm_req_b7c4208aac9c59ab | 2 | False | ep | ep_forage |
| 105 | ep_nom | False | srm_req_b22511839b9b557c | 2 | False | ep | ep_forage |
| 113 | ep_pompe_puissance | False | srm_req_b27363a837569dff | 2 | False | ep | ep_forage |
| 109 | ep_profond | False | srm_req_2a9fd99a4192f0a9 | 2 | False | ep | ep_forage |
| 107 | ep_type | False | srm_req_8b57dcc48771402d | 2 | False | ep | ep_forage |
| 147 | conform | False | srm_req_15d8d6673c820eee | 19 | False | ep | ep_hydrant |
| 146 | diamcond | False | srm_req_f00d44f641f23b01 | 0 | False | ep | ep_hydrant |
| 145 | diametre | False | srm_req_be46010c9818dd87 | 0 | False | ep | ep_hydrant |
| 148 | dispo | False | srm_req_6e0b39336bfa1045 | 19 | False | ep | ep_hydrant |
| 1693 | emplacement | False | srm_req_ccc1f9f50bf6f51b | 0 | False | ep | ep_hydrant |
| 153 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_hydrant |
| 139 | ep_etat | False | srm_req_79fdcb521bb1ca80 | 0 | False | ep | ep_hydrant |
| 155 | ep_ref_regard | False | srm_req_d406add43c0ab4ef | 19 | False | ep | ep_hydrant |
| 137 | ep_type | False | srm_req_8b57dcc48771402d | 0 | False | ep | ep_hydrant |
| 144 | marque | False | srm_req_949740fcae1ae698 | 0 | False | ep | ep_hydrant |
| 142 | statut | False | srm_req_d099aae5c339fa40 | 0 | False | ep | ep_hydrant |
| 143 | type | False | srm_req_599dcce2998a6b40 | 0 | False | ep | ep_hydrant |
| 149 | vanne | False | srm_req_4963c81120e6e803 | 0 | False | ep | ep_hydrant |
| 160 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 227 | False | ep | ep_noeud |
| 164 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_obturateur |
| 1768 | ep_diam | False | srm_req_421b2a713aa2a7e3 | 0 | False | ep | ep_obturateur |
| 174 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 1 | False | ep | ep_pompe |
| 171 | ep_etat_s | False | srm_req_fca5852a04882fe5 | 0 | False | ep | ep_pompe |
| 170 | ep_hmt | False | srm_req_c49ce0900c7029c0 | 1 | False | ep | ep_pompe |
| 169 | ep_pompe_debit_fo | False | srm_req_5bcb229af6414e5a | 1 | False | ep | ep_pompe |
| 166 | ep_pompe_modele | False | srm_req_13188a9366089bac | 1 | False | ep | ep_pompe |
| 168 | ep_pompe_puissance | False | srm_req_b27363a837569dff | 1 | False | ep | ep_pompe |
| 167 | ep_pompe_ref | False | srm_req_7a59cc8d2ef98794 | 1 | False | ep | ep_pompe |
| 1412 | ep_statut | False | srm_req_dc20ca73ac72f796 | 0 | False | ep | ep_pompe |
| 178 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_puit |
| 1698 | emplacement | False | srm_req_ccc1f9f50bf6f51b | 0 | False | ep | ep_reduc_pres |
| 182 | ep_classe_tampon | False | srm_req_dadfb7c5cdb0678f | 1 | False | ep | ep_reduc_pres |
| 189 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 1 | False | ep | ep_reduc_pres |
| 181 | ep_diam | False | srm_req_421b2a713aa2a7e3 | 0 | False | ep | ep_reduc_pres |
| 180 | ep_marque | False | srm_req_90befa185cac4d45 | 1 | False | ep | ep_reduc_pres |
| 12 | echelon | False | srm_req_71579009f1de0b9e | 59 | False | ep | ep_regard_point |
| 1701 | emplacement | False | srm_req_ccc1f9f50bf6f51b | 2 | False | ep | ep_regard_point |
| 1473 | ep_agent | False | srm_nn_8884bbcc54df019e | 10 | False | ep | ep_regard_point |
| 10 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 1 | False | ep | ep_regard_point |
| 16 | ep_profondeur | False | srm_req_d7e18f1829c67bbf | 80 | False | ep | ep_regard_point |
| 3 | ep_ref_rue | False | srm_req_af41a9e77b0e3e82 | 3 | False | ep | ep_regard_point |
| 5 | ep_tampon | False | srm_req_6d7635f7bedb68ec | 1 | False | ep | ep_regard_point |
| 841 | existence_s | False | srm_req_ee72116e03b1ead2 | 3 | False | ep | ep_regard_point |
| 3093 | generatrice_supp | False | srm_nn_bab851c546748e18 | 101 | False | ep | ep_regard_point |
| 840 | largeur | False | srm_req_02c6f47decde3ed4 | 1442 | False | ep | ep_regard_point |
| 839 | longueur | False | srm_req_a4f237aac8427fb3 | 1442 | False | ep | ep_regard_point |
| 842 | type_regard | False | srm_req_c35dc7b065e664dc | 1441 | False | ep | ep_regard_point |
| 205 | ep_capacite | False | srm_req_74e47095999dad73 | 32 | False | ep | ep_reservoir |
| 208 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 19 | False | ep | ep_reservoir |
| 196 | ep_date_constr | False | srm_req_740d39c8b489dcef | 32 | False | ep | ep_reservoir |
| 197 | ep_date_rehab | False | srm_req_29c53df7fc17e27b | 32 | False | ep | ep_reservoir |
| 202 | ep_diam_in | False | srm_req_8962282713900819 | 31 | False | ep | ep_reservoir |
| 203 | ep_diam_out | False | srm_req_5085f2b5d851ab23 | 31 | False | ep | ep_reservoir |
| 194 | ep_etat_s | False | srm_req_fca5852a04882fe5 | 19 | False | ep | ep_reservoir |
| 193 | ep_forme | False | srm_req_1b4a43319dacc5a5 | 20 | False | ep | ep_reservoir |
| 204 | ep_hr | False | srm_req_de023a319c5d384d | 31 | False | ep | ep_reservoir |
| 191 | ep_nom | False | srm_req_b22511839b9b557c | 30 | False | ep | ep_reservoir |
| 195 | ep_ref_rue | False | srm_req_af41a9e77b0e3e82 | 19 | False | ep | ep_reservoir |
| 199 | ep_surf_clot | False | srm_req_5e4f5288869cdbbe | 32 | False | ep | ep_reservoir |
| 192 | ep_type | False | srm_req_8b57dcc48771402d | 21 | False | ep | ep_reservoir |
| 198 | ep_type_cap | False | srm_req_0243e84f421007b6 | 32 | False | ep | ep_reservoir |
| 229 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 5 | False | ep | ep_st_demineralisation |
| 220 | ep_etat_s | False | srm_req_fca5852a04882fe5 | 5 | False | ep | ep_st_demineralisation |
| 216 | ep_hmt | False | srm_req_c49ce0900c7029c0 | 0 | False | ep | ep_st_demineralisation |
| 211 | ep_nom | False | srm_req_b22511839b9b557c | 5 | False | ep | ep_st_demineralisation |
| 215 | ep_pompe_debit_fo | False | srm_req_5bcb229af6414e5a | 5 | False | ep | ep_st_demineralisation |
| 214 | ep_pompe_puissance | False | srm_req_b27363a837569dff | 5 | False | ep | ep_st_demineralisation |
| 213 | ep_pompe_ref | False | srm_req_7a59cc8d2ef98794 | 5 | False | ep | ep_st_demineralisation |
| 239 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 4 | False | ep | ep_station_pompage |
| 238 | ep_debit_global | False | srm_req_1777764c8038e3a7 | 5 | False | ep | ep_station_pompage |
| 232 | ep_etat_s | False | srm_req_fca5852a04882fe5 | 5 | False | ep | ep_station_pompage |
| 231 | ep_nom | False | srm_req_b22511839b9b557c | 5 | False | ep | ep_station_pompage |
| 237 | ep_nombre_de_groupe | False | srm_req_0491791635dc0084 | 5 | False | ep | ep_station_pompage |
| 233 | ep_res_deserv | False | srm_req_1b368ae78de86de1 | 5 | False | ep | ep_station_pompage |
| 236 | puissance_installee | False | srm_req_5f2bf18b3d82a38f | 5 | False | ep | ep_station_pompage |
| 23 | ep_classe_conduite | False | srm_req_44ebc192da17f8cc | 1 | False | ep | ep_traversee |
| 28 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 72 | False | ep | ep_traversee |
| 837 | ep_diam | False | srm_req_421b2a713aa2a7e3 | 1 | False | ep | ep_traversee |
| 843 | ep_mat | False | srm_req_5f0fd8cf54fd1f82 | 1 | False | ep | ep_traversee |
| 22 | ep_profondeur | False | srm_req_d7e18f1829c67bbf | 2 | False | ep | ep_traversee |
| 24 | ep_ref_rue | False | srm_req_af41a9e77b0e3e82 | 2 | False | ep | ep_traversee |
| 30 | nom_obstac | False | srm_req_8c4eff3fbc825c08 | 2 | False | ep | ep_traversee |
| 31 | type_prot | False | srm_req_7739f58725ebb84f | 1 | False | ep | ep_traversee |
| 19 | type_traver | False | srm_req_c2c4fbfceade6fe5 | 1 | False | ep | ep_traversee |
| 1705 | emplacement | False | srm_req_ccc1f9f50bf6f51b | 1 | False | ep | ep_vanne |
| 254 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 1 | False | ep | ep_vanne |
| 243 | ep_diam | False | srm_req_421b2a713aa2a7e3 | 0 | False | ep | ep_vanne |
| 248 | ep_etat | False | srm_req_79fdcb521bb1ca80 | 0 | False | ep | ep_vanne |
| 246 | ep_manoeuvre | False | srm_req_a66044fded3e1319 | 0 | False | ep | ep_vanne |
| 255 | ep_marque | False | srm_req_90befa185cac4d45 | 1 | False | ep | ep_vanne |
| 244 | ep_ref_regard | False | srm_req_d406add43c0ab4ef | 0 | False | ep | ep_vanne |
| 250 | ep_sectionnement | False | srm_req_cc9ec6f55453d97c | 1 | False | ep | ep_vanne |
| 245 | ep_sens_ferm | False | srm_req_0033baa5679a4261 | 511 | False | ep | ep_vanne |
| 241 | ep_type | False | srm_req_8b57dcc48771402d | 0 | False | ep | ep_vanne |
| 1708 | emplacement | False | srm_req_ccc1f9f50bf6f51b | 173 | False | ep | ep_ventouse |
| 274 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_ventouse |
| 1772 | ep_diam | False | srm_req_421b2a713aa2a7e3 | 0 | False | ep | ep_ventouse |
| 271 | ep_etat | False | srm_req_79fdcb521bb1ca80 | 442 | False | ep | ep_ventouse |
| 276 | ep_marque | False | srm_req_90befa185cac4d45 | 0 | False | ep | ep_ventouse |
| 268 | ep_modele | False | srm_req_2c17f0121384b0ae | 0 | False | ep | ep_ventouse |
| 269 | ep_ref_regard | False | srm_req_d406add43c0ab4ef | 0 | False | ep | ep_ventouse |
| 1771 | ep_type | False | srm_req_8b57dcc48771402d | 12 | False | ep | ep_ventouse |
| 1711 | emplacement | False | srm_req_ccc1f9f50bf6f51b | 0 | False | ep | ep_vidange |
| 264 | ep_conf_plan | False | srm_req_6ffcd68d98ecb4df | 0 | False | ep | ep_vidange |
| 1770 | ep_diam | False | srm_req_421b2a713aa2a7e3 | 0 | False | ep | ep_vidange |
| 261 | ep_etat | False | srm_req_79fdcb521bb1ca80 | 0 | False | ep | ep_vidange |
| 266 | ep_marque | False | srm_req_90befa185cac4d45 | 0 | False | ep | ep_vidange |
| 257 | ep_modele | False | srm_req_2c17f0121384b0ae | 0 | False | ep | ep_vidange |
| 258 | ep_point_vid | False | srm_req_24f1d53964637693 | 0 | False | ep | ep_vidange |
| 259 | ep_ref_regard | False | srm_req_d406add43c0ab4ef | 0 | False | ep | ep_vidange |
| 267 | ep_sectionnement | False | srm_req_cc9ec6f55453d97c | 356 | False | ep | ep_vidange |
| 256 | ep_type | False | srm_req_8b57dcc48771402d | 0 | False | ep | ep_vidange |
| 1773 | type | False | srm_req_599dcce2998a6b40 | 0 | False | ep | voie |

## attributes_without_physical_column

OK

## physical_columns_without_attribute

OK

## choices_without_attribute

OK

## choices_without_physical_column

OK

## choice_attribute_link_mismatches

OK

## choice_default_mismatches

OK
