# Audit coherence config mobile vs schemas

- Date: 2026-05-08T23:59:55
- Formulaires contr?l?s: 61 (38 visibles, 40 download_mobile)
- Tables physiques manquantes: 0
- Types diff?rents attribut_config_mobile vs schema: 0
- Nullable diff?rents: 0
- Attributs config sans colonne physique: 177
- Colonnes physiques sans attribut config: 11
- Choix sans attribut config: 0
- Choix sans colonne physique: 0
- Choix avec FK attribut_config_mobile incoh?rente: 0

## Types ? examiner avant correction

Aucun ?cart.

## Attributs config sans colonne physique

Affichage des 120 premiers sur 177. Voir JSON pour la liste compl?te.

| id | nom_metier | nom_table | nom_champ | type_champ | visible | ordre | titre_app |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3284 | ep | anomalie_conduite | photo_1 | character varying(400) | False | 20 | photo_1 |
| 3224 | ep | anomalie_conduite | photo_2 | character varying(400) | False | 21 | photo_2 |
| 3253 | ep | anomalie_conduite | photo_3 | character varying(400) | False | 22 | photo_3 |
| 3279 | ep | anomalie_conduite | photo_4 | character varying(400) | False | 23 | photo_4 |
| 3014 | ep | autre_objet | photo_1 | character varying | False | 5 | Photo 1 |
| 3015 | ep | autre_objet | photo_2 | character varying | False | 6 | Photo 2 |
| 3016 | ep | autre_objet | photo_3 | character varying | False | 7 | Photo 3 |
| 3017 | ep | autre_objet | photo_4 | character varying | False | 8 | Photo 4 |
| 2871 | ep | autre_objet | date_leve | timestamp with time zone | False | 9 | date_leve |
| 2875 | ep | autre_objet | id_agent_crea | integer | False | 13 | id_agent_crea |
| 2878 | ep | autre_objet | mode_localisation | mode_localisation_enum | False | 16 | mode_localisation |
| 2879 | ep | autre_objet | anomalie | boolean | False | 17 | anomalie |
| 2882 | ep | autre_objet | conformite_plan | text | False | 20 | conformite_plan |
| 2918 | ep | borne_onep | observation | text | False | 19 | observation |
| 2919 | ep | borne_onep | date_leve | date | False | 20 | date_leve |
| 2921 | ep | borne_onep | id_agent_crea | integer | False | 22 | id_agent_crea |
| 2922 | ep | borne_onep | mode_localisation | mode_localisation_enum | False | 23 | mode_localisation |
| 2923 | ep | borne_onep | anomalie | boolean | False | 24 | anomalie |
| 2925 | ep | borne_onep | conformite_plan | text | False | 26 | conformite_plan |
| 2885 | ep | bouche_a_cles | date_leve | timestamp with time zone | False | 2 | date_leve |
| 2886 | ep | bouche_a_cles | observation | character varying | False | 3 | observation |
| 2889 | ep | bouche_a_cles | id_agent_crea | integer | False | 6 | id_agent_crea |
| 2892 | ep | bouche_a_cles | mode_localisation | mode_localisation_enum | False | 9 | mode_localisation |
| 2893 | ep | bouche_a_cles | anomalie | boolean | False | 10 | anomalie |
| 2896 | ep | bouche_a_cles | id_compteur_abonne | integer | False | 13 | id_compteur_abonne |
| 2897 | ep | bouche_a_cles | id_conduite | integer | False | 14 | id_conduite |
| 2898 | ep | bouche_a_cles | conformite_plan | text | False | 15 | conformite_plan |
| 2948 | ep | centre_tampon | ep_anomalie | character varying(400) | True | 21 | ep_anomalie |
| 2950 | ep | centre_tampon | date_leve | timestamp with time zone | False | 23 | date_leve |
| 2980 | ep | centre_tampon | mode_localisation | character varying(400) | True | 24 | mode_localisation |
| 3264 | ep | centre_tampon | photo_1 | character varying(400) | False | 26 | photo_1 |
| 3220 | ep | centre_tampon | photo_2 | character varying(400) | False | 27 | photo_2 |
| 3249 | ep | centre_tampon | photo_3 | character varying(400) | False | 28 | photo_3 |
| 3276 | ep | centre_tampon | photo_4 | character varying(400) | False | 29 | photo_4 |
| 2463 | ep | conduite_terrain | ep_num | character varying | False | 3 | Compatibilite legacy - ep_num |
| 2464 | ep | conduite_terrain | ep_type | character varying | False | 4 | Compatibilite legacy - ep_type |
| 2465 | ep | conduite_terrain | ep_long_c | double precision | False | 7 | Compatibilite legacy - ep_long_c |
| 2466 | ep | conduite_terrain | ep_long_r | double precision | False | 8 | Compatibilite legacy - ep_long_r |
| 2467 | ep | conduite_terrain | ep_profondeur | double precision | False | 9 | Compatibilite legacy - ep_profondeur |
| 2469 | ep | conduite_terrain | emplacement | character varying | False | 11 | Compatibilite legacy - emplacement |
| 2470 | ep | conduite_terrain | zamont | double precision | False | 12 | Compatibilite legacy - zamont |
| 2471 | ep | conduite_terrain | zaval | double precision | False | 13 | Compatibilite legacy - zaval |
| 2472 | ep | conduite_terrain | pente | double precision | False | 14 | Compatibilite legacy - pente |
| 2473 | ep | conduite_terrain | zalerte | double precision | False | 15 | Compatibilite legacy - zalerte |
| 2474 | ep | conduite_terrain | ref_rue | character varying | False | 16 | Compatibilite legacy - ref_rue |
| 2475 | ep | conduite_terrain | ep_entreprise | character varying | False | 17 | Compatibilite legacy - ep_entreprise |
| 2476 | ep | conduite_terrain | ep_ref_marche | character varying | False | 18 | Compatibilite legacy - ep_ref_marche |
| 2477 | ep | conduite_terrain | ep_sect_hydro | character varying | False | 19 | Compatibilite legacy - ep_sect_hydro |
| 2478 | ep | conduite_terrain | ep_etage_p | character varying | False | 20 | Compatibilite legacy - ep_etage_p |
| 2479 | ep | conduite_terrain | etage_aqua | character varying | False | 21 | Compatibilite legacy - etage_aqua |
| 2480 | ep | conduite_terrain | secteur_aqua | character varying | False | 22 | Compatibilite legacy - secteur_aqua |
| 2481 | ep | conduite_terrain | ep_statut | character varying | False | 23 | Compatibilite legacy - ep_statut |
| 2482 | ep | conduite_terrain | ep_date_interv | date | False | 24 | Compatibilite legacy - ep_date_interv |
| 2483 | ep | conduite_terrain | ep_croquis | character varying | False | 25 | Compatibilite legacy - ep_croquis |
| 2484 | ep | conduite_terrain | ep_dxf_dwg | character varying | False | 26 | Compatibilite legacy - ep_dxf_dwg |
| 2485 | ep | conduite_terrain | ep_detail | character varying | False | 27 | Compatibilite legacy - ep_detail |
| 2486 | ep | conduite_terrain | ep_lien | character varying | False | 28 | Compatibilite legacy - ep_lien |
| 2487 | ep | conduite_terrain | id_agent_crea | integer | False | 30 | Compatibilite legacy - id_agent_crea |
| 2489 | ep | conduite_terrain | mode_localisation | character varying(400) | False | 33 | Compatibilite legacy - mode_localisation |
| 2490 | ep | conduite_terrain | anomalie | boolean | False | 34 | Compatibilite legacy - anomalie |
| 3040 | ep | conduite_terrain | photo_1 | character varying(400) | False | 36 | Photo 1 |
| 3041 | ep | conduite_terrain | photo_2 | character varying(400) | False | 37 | Photo 2 |
| 2494 | ep | conduite_terrain | conformite_plan | text | False | 38 | Compatibilite legacy - conformite_plan |
| 2957 | ep | conduite_terrain | ep_ref_rue | character varying(400) | False | 53 | ep_ref_rue |
| 2958 | ep | conduite_terrain | ep_anomalie | character varying(400) | False | 54 | ep_anomalie |
| 3215 | ep | conduite_terrain | photo_3 | character varying(400) | False | 56 | photo_3 |
| 3227 | ep | conduite_terrain | photo_4 | character varying(400) | False | 57 | photo_4 |
| 3018 | ep | ep_bache | photo_1 | character varying(400) | False | 46 | Photo 1 |
| 3019 | ep | ep_bache | photo_2 | character varying(400) | False | 47 | Photo 2 |
| 3020 | ep | ep_bache | photo_3 | character varying(400) | False | 48 | Photo 3 |
| 3021 | ep | ep_bache | photo_4 | character varying(400) | False | 49 | Photo 4 |
| 3022 | ep | ep_bf | photo_1 | character varying(400) | False | 57 | Photo 1 |
| 3023 | ep | ep_bf | photo_2 | character varying(400) | False | 58 | Photo 2 |
| 3024 | ep | ep_bf | photo_3 | character varying(400) | False | 59 | Photo 3 |
| 3025 | ep | ep_bf | photo_4 | character varying(400) | False | 60 | Photo 4 |
| 3026 | ep | ep_bouche_arro | photo_1 | character varying(400) | False | 46 | Photo 1 |
| 3027 | ep | ep_bouche_arro | photo_2 | character varying(400) | False | 47 | Photo 2 |
| 3028 | ep | ep_bouche_arro | photo_3 | character varying(400) | False | 48 | Photo 3 |
| 3029 | ep | ep_bouche_arro | photo_4 | character varying(400) | False | 49 | Photo 4 |
| 2944 | ep | ep_branchement | emplacement | character varying(400) | False | 46 | emplacement |
| 3030 | ep | ep_brc_pt | photo_1 | character varying(400) | False | 51 | Photo 1 |
| 3031 | ep | ep_brc_pt | photo_2 | character varying(400) | False | 52 | Photo 2 |
| 3032 | ep | ep_brc_pt | photo_3 | character varying(400) | False | 53 | Photo 3 |
| 3033 | ep | ep_brc_pt | photo_4 | character varying(400) | False | 54 | Photo 4 |
| 2945 | ep | ep_brc_pt | ep_ref_rue | character varying(400) | False | 60 | ep_ref_rue |
| 2947 | ep | ep_brc_pt | date_leve | timestamp with time zone | False | 62 | date_leve |
| 2988 | ep | ep_brc_pt | diametre_calibre_terrain | character varying(400) | False | 63 | diametre_calibre_terrain |
| 2989 | ep | ep_brc_pt | diametre_conduite | character varying(400) | False | 64 | diametre_conduite |
| 2990 | ep | ep_brc_pt | ep_diam | character varying(400) | False | 65 | ep_diam |
| 3034 | ep | ep_compteur_i | photo_1 | character varying(400) | False | 59 | Photo 1 |
| 3035 | ep | ep_compteur_i | photo_2 | character varying(400) | False | 60 | Photo 2 |
| 3036 | ep | ep_compteur_i | photo_3 | character varying(400) | False | 61 | Photo 3 |
| 3037 | ep | ep_compteur_i | photo_4 | character varying(400) | False | 62 | Photo 4 |
| 2440 | ep | ep_conduite | ref_rue | character varying | False | 16 | Compatibilite legacy - ref_rue |
| 2451 | ep | ep_conduite | id_agent_crea | integer | False | 30 | Compatibilite legacy - id_agent_crea |
| 2453 | ep | ep_conduite | anomalie | boolean | False | 34 | Compatibilite legacy - anomalie |
| 3038 | ep | ep_conduite | photo_1 | text | False | 36 | Photo 1 |
| 3039 | ep | ep_conduite | photo_2 | text | False | 37 | Photo 2 |
| 2457 | ep | ep_conduite | conformite_plan | text | False | 38 | Compatibilite legacy - conformite_plan |
| 80 | ep | ep_conduite | altitude | double precision | False | 47 | Altitude |
| 3050 | ep | ep_cone_reduc | photo_1 | character varying(400) | False | 49 | Photo 1 |
| 3051 | ep | ep_cone_reduc | photo_2 | character varying(400) | False | 50 | Photo 2 |
| 3052 | ep | ep_cone_reduc | photo_3 | character varying(400) | False | 51 | Photo 3 |
| 3053 | ep | ep_cone_reduc | photo_4 | character varying(400) | False | 52 | Photo 4 |
| 3054 | ep | ep_forage | photo_1 | character varying(400) | False | 56 | Photo 1 |
| 3055 | ep | ep_forage | photo_2 | character varying(400) | False | 57 | Photo 2 |
| 3056 | ep | ep_forage | photo_3 | character varying(400) | False | 58 | Photo 3 |
| 3057 | ep | ep_forage | photo_4 | character varying(400) | False | 59 | Photo 4 |
| 2991 | ep | ep_forage | ep_statut | character varying(400) | False | 66 | ep_statut |
| 3058 | ep | ep_hydrant | photo_1 | character varying(400) | False | 61 | Photo 1 |
| 3059 | ep | ep_hydrant | photo_2 | character varying(400) | False | 62 | Photo 2 |
| 3060 | ep | ep_hydrant | photo_3 | character varying(400) | False | 63 | Photo 3 |
| 3061 | ep | ep_hydrant | photo_4 | character varying(400) | False | 64 | Photo 4 |
| 2961 | ep | ep_hydrant | ep_etat_s | character varying(400) | False | 69 | ep_etat_s |
| 2992 | ep | ep_hydrant | ep_diam | character varying(400) | False | 71 | ep_diam |
| 2963 | ep | ep_noeud | ep_anomalie | character varying(400) | False | 41 | ep_anomalie |
| 2981 | ep | ep_noeud | mode_localisation | character varying(400) | False | 43 | mode_localisation |
| 3066 | ep | ep_obturateur | photo_1 | character varying(400) | False | 38 | Photo 1 |
| 3067 | ep | ep_obturateur | photo_2 | character varying(400) | False | 39 | Photo 2 |
| 3068 | ep | ep_obturateur | photo_3 | character varying(400) | False | 40 | Photo 3 |

## Colonnes physiques sans attribut config

| nom_metier | nom_table | nom_champ | physical_type | nullable | form_visible | download_mobile |
| --- | --- | --- | --- | --- | --- | --- |
| ep | autre_objet | id_province | integer | True | True | True |
| ep | autre_objet | id_zone | integer | True | True | True |
| ep | autre_objet | id_mission | integer | True | True | True |
| ep | autre_objet | id_user_creat | integer | True | True | True |
| ep | autre_objet | id_user_modif | integer | True | True | True |
| ep | autre_objet | date_creation | timestamp without time zone | True | True | True |
| ep | autre_objet | date_modif | timestamp without time zone | True | True | True |
| ep | autre_objet | is_deleted | boolean | True | True | True |
| ep | autre_objet | is_validated | boolean | True | True | True |
| ep | autre_objet | id_user_valid | integer | True | True | True |
| ep | autre_objet | date_validation | timestamp without time zone | True | True | True |

## Liste choix sans attribut config

Aucun ?cart.

## Liste choix sans colonne physique

Aucun ?cart.

## Liste choix FK incoh?rente

Aucun ?cart.

