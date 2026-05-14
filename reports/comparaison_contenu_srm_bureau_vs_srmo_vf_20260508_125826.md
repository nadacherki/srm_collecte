# Comparaison contenu SRM_bureau vs srmo_vf backup - 2026-05-08T12:58:32

- BD actuelle : `SRM_bureau`
- Backup restaure : `codex_cmp_srmo_vf_20260508` depuis `C:\Users\AnasDahou\Downloads\srmo_vf_ .backup`
- Schemas compares : `public, ep, asst, elec`
- Table systeme exclue du bilan applicatif : `public.spatial_ref_sys`
- Methode contenu : comparaison des nombres de lignes et checksum MD5 des valeurs texte des colonnes communes, ligne par ligne, ordre ignore.

## Synthese

| Indicateur | Valeur |
|---|---:|
| Tables actuelles | 106 |
| Tables backup | 103 |
| Tables communes | 103 |
| Tables seulement actuelle | 3 |
| Tables seulement backup | 0 |
| Tables communes identiques | 50 |
| Tables avec nombre de lignes different | 42 |
| Tables meme nombre de lignes mais contenu different | 11 |
| Tables avec erreur checksum | 0 |
| Lignes totales actuelle (hors spatial_ref_sys) | 96939 |
| Lignes totales backup (hors spatial_ref_sys) | 111963 |

## Tables seulement dans la BD actuelle

| Table | Lignes |
|---|---:|
| `public.intervention_log_backup_before_bureau_workflow_20260508` | 658 |
| `public.intervention_anomalie_backup_before_bureau_workflow_20260508` | 329 |
| `public.onep_commune_alias` | 1 |

## Tables seulement dans le backup

Aucune.

## Principaux ecarts de contenu sur tables communes

| Table | Statut | Actuelle | Backup | Delta | Cles actuelles seules | Cles backup seules | Cles modifiees | Colonnes actuelle seules | Colonnes backup seules |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `public.historique_action` | nb_lignes_different | 37996 | 46010 | -8014 | 5844 | 13858 | 2522 | 0 | 0 |
| `public.objet_photo` | nb_lignes_different | 4269 | 11134 | -6865 | 0 | 6865 | 4269 | 0 | 0 |
| `ep.onep_db` | contenu_different | 10580 | 10580 | 0 | 0 | 0 | 10580 | 0 | 0 |
| `ep.ep_branchement` | nb_lignes_different | 199 | 1989 | -1790 | 0 | 1790 | 199 | 1 | 0 |
| `public.old_liste_choix` | nb_lignes_different | 0 | 1804 | -1804 | 0 | 1804 | 0 | 0 | 0 |
| `ep.ep_brc_pt` | nb_lignes_different | 2553 | 2156 | 397 | 397 | 0 | 2156 | 5 | 0 |
| `ep.ep_regard_point` | nb_lignes_different | 1344 | 0 | 1344 | 1344 | 0 | 0 | 0 | 0 |
| `ep.centre_tampon` | nb_lignes_different | 946 | 0 | 946 | 946 | 0 | 0 | 3 | 0 |
| `ep.ep_conduite` | nb_lignes_different | 1549 | 1626 | -77 | 0 | 77 | 1549 | 8 | 0 |
| `public.mission_objet` | nb_lignes_different | 0 | 792 | -792 | 0 | 792 | 0 | 0 | 0 |
| `ep.ep_regard` | nb_lignes_different | 1344 | 1439 | -95 | 0 | 95 | 1344 | 0 | 0 |
| `ep.autre_objet` | nb_lignes_different | 578 | 0 | 578 | 578 | 0 | 0 | 2 | 1 |
| `ep.conduite_terrain` | nb_lignes_different | 568 | 0 | 568 | 568 | 0 | 0 | 31 | 0 |
| `public.intervention_log` | nb_lignes_different | 658 | 1066 | -408 | 0 | 408 | 0 | 0 | 0 |
| `ep.bouche_a_cles` | nb_lignes_different | 352 | 0 | 352 | 352 | 0 | 0 | 9 | 0 |
| `ep.ep_bf` | nb_lignes_different | 464 | 267 | 197 | 197 | 0 | 267 | 0 | 1 |
| `ep.statistique_conduite` | nb_lignes_different | 0 | 302 | -302 | 0 | 302 | 0 | 0 | 1 |
| `public.attribut_config_mobile` | contenu_different | 3351 | 3351 | 0 | 0 | 0 | 544 | 0 | 0 |
| `ep.ep_vanne` | nb_lignes_different | 525 | 511 | 14 | 14 | 0 | 511 | 1 | 0 |
| `ep.ep_ventouse` | nb_lignes_different | 399 | 442 | -43 | 0 | 43 | 399 | 0 | 0 |
| `ep.ep_obturateur` | nb_lignes_different | 418 | 442 | -24 | 0 | 24 | 418 | 1 | 0 |
| `public.intervention_anomalie` | nb_lignes_different | 329 | 392 | -63 | 0 | 63 | 320 | 0 | 0 |
| `ep.ep_vidange` | nb_lignes_different | 302 | 356 | -54 | 0 | 54 | 302 | 1 | 0 |
| `public.attribut_config` | nb_lignes_different | 1216 | 1273 | -57 | 61 | 118 | 74 | 0 | 0 |
| `ep.ep_noeud` | nb_lignes_different | 232 | 227 | 5 | 17 | 12 | 215 | 2 | 0 |
| `ep.ep_traversee` | nb_lignes_different | 20 | 102 | -82 | 0 | 82 | 20 | 2 | 0 |
| `public.liste_choix` | contenu_different | 935 | 935 | 0 | 0 | 0 | 176 | 0 | 0 |
| `public.zone_utilisateur` | nb_lignes_different | 65 | 25 | 40 | 40 | 0 | 23 | 0 | 0 |
| `ep.ep_cone_reduc` | nb_lignes_different | 61 | 53 | 8 | 8 | 0 | 53 | 0 | 0 |
| `ep.ep_compteur_i` | nb_lignes_different | 46 | 37 | 9 | 9 | 0 | 37 | 0 | 0 |
| `ep.ep_reservoir` | nb_lignes_different | 11 | 32 | -21 | 0 | 21 | 11 | 1 | 0 |
| `public.utilisateur_permission` | nb_lignes_different | 25 | 33 | -8 | 17 | 25 | 0 | 0 | 0 |
| `public.formulaire_config_mobile` | contenu_different | 61 | 61 | 0 | 0 | 0 | 46 | 1 | 0 |
| `public.basemap_package` | nb_lignes_different | 21 | 0 | 21 | 21 | 0 | 0 | 0 | 0 |
| `public.srm_field_option` | contenu_different | 38 | 38 | 0 | 0 | 0 | 38 | 0 | 0 |
| `ep.ep_hydrant` | nb_lignes_different | 14 | 19 | -5 | 6 | 11 | 8 | 2 | 0 |
| `public.django_migrations` | nb_lignes_different | 42 | 31 | 11 | 11 | 0 | 0 | 0 | 0 |
| `public.utilisateur` | nb_lignes_different | 11 | 13 | -2 | 2 | 4 | 6 | 0 | 0 |
| `public.sync_session_attachment` | nb_lignes_different | 6 | 0 | 6 | 6 | 0 | 0 | 0 | 0 |
| `public.sync_session_item` | nb_lignes_different | 5 | 0 | 5 | 5 | 0 | 0 | 0 | 0 |
| `public.historique_traitement` | nb_lignes_different | 0 | 5 | -5 | 0 | 5 | 0 | 0 | 0 |
| `public.permission` | nb_lignes_different | 18 | 22 | -4 | 0 | 4 | 0 | 0 | 0 |
| `public.sync_session` | nb_lignes_different | 3 | 0 | 3 | 3 | 0 | 0 | 0 | 0 |
| `public.fond_plan` | contenu_different | 18957 | 18957 | 0 | 0 | 0 | 5 | 0 | 0 |
| `ep.ep_station_pompage` | contenu_different | 5 | 5 | 0 | 0 | 0 | 5 | 1 | 0 |
| `ep.ep_st_demineralisation` | contenu_different | 5 | 5 | 0 | 0 | 0 | 5 | 0 | 0 |
| `ep.borne_onep` | nb_lignes_different | 2 | 0 | 2 | 2 | 0 | 0 | 7 | 0 |
| `public.mission_livraison` | nb_lignes_different | 0 | 1 | -1 | 0 | 1 | 0 | 0 | 0 |
| `public.dashboard_stats_cache` | nb_lignes_different | 0 | 1 | -1 | 0 | 1 | 0 | 0 | 0 |
| `public.conflit` | nb_lignes_different | 0 | 1 | -1 | 0 | 1 | 0 | 0 | 0 |
| `ep.ep_forage` | contenu_different | 2 | 2 | 0 | 0 | 0 | 2 | 1 | 0 |
| `ep.ep_reduc_pres` | contenu_different | 1 | 1 | 0 | 0 | 0 | 1 | 1 | 0 |
| `ep.ep_pompe` | contenu_different | 1 | 1 | 0 | 0 | 0 | 1 | 0 | 0 |

## Echantillons de differences par cle primaire

### `ep.autre_objet`

- PK : `fid`
- Cles seulement actuelle : 578
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.borne_onep`

- PK : `fid`
- Cles seulement actuelle : 2
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[1], [2]`

### `ep.bouche_a_cles`

- PK : `fid`
- Cles seulement actuelle : 352
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.centre_tampon`

- PK : `fid`
- Cles seulement actuelle : 946
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.conduite_terrain`

- PK : `fid`
- Cles seulement actuelle : 568
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.ep_bf`

- PK : `fid`
- Cles seulement actuelle : 197
- Cles seulement backup : 0
- Cles communes modifiees : 267
- Exemples cles actuelle seules : `[268], [269], [270], [271], [272], [273], [274], [275], [276], [277]`
- Exemples cles modifiees : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.ep_branchement`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 1790
- Cles communes modifiees : 199
- Exemples cles backup seules : `[1000], [1001], [1002], [1003], [1004], [1005], [1006], [1007], [1008], [1009]`
- Exemples cles modifiees : `[100], [107], [108], [10], [112], [116], [11], [123], [125], [126]`

### `ep.ep_brc_pt`

- PK : `fid`
- Cles seulement actuelle : 397
- Cles seulement backup : 0
- Cles communes modifiees : 2156
- Exemples cles actuelle seules : `[2157], [2158], [2159], [2160], [2161], [2162], [2163], [2164], [2165], [2166]`
- Exemples cles modifiees : `[1000], [1001], [1002], [1003], [1004], [1005], [1006], [1007], [1008], [1009]`

### `ep.ep_compteur_i`

- PK : `fid`
- Cles seulement actuelle : 9
- Cles seulement backup : 0
- Cles communes modifiees : 37
- Exemples cles actuelle seules : `[38], [39], [40], [41], [42], [43], [44], [45], [46]`
- Exemples cles modifiees : `[10], [11], [12], [13], [14], [15], [16], [17], [18], [19]`

### `ep.ep_conduite`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 77
- Cles communes modifiees : 1549
- Exemples cles backup seules : `[1550], [1551], [1552], [1553], [1554], [1555], [1556], [1557], [1558], [1559]`
- Exemples cles modifiees : `[1000], [1001], [1002], [1003], [1004], [1005], [1006], [1007], [1008], [1009]`

### `ep.ep_cone_reduc`

- PK : `fid`
- Cles seulement actuelle : 8
- Cles seulement backup : 0
- Cles communes modifiees : 53
- Exemples cles actuelle seules : `[54], [55], [56], [57], [58], [59], [60], [61]`
- Exemples cles modifiees : `[10], [11], [12], [13], [14], [15], [16], [17], [18], [19]`

### `ep.ep_forage`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 2
- Exemples cles modifiees : `[1], [2]`

### `ep.ep_hydrant`

- PK : `fid`
- Cles seulement actuelle : 6
- Cles seulement backup : 11
- Cles communes modifiees : 8
- Exemples cles actuelle seules : `[20], [21], [22], [23], [24], [25]`
- Exemples cles backup seules : `[10], [11], [12], [13], [16], [4], [5], [6], [7], [8]`
- Exemples cles modifiees : `[14], [15], [17], [18], [19], [1], [2], [3]`

### `ep.ep_noeud`

- PK : `fid`
- Cles seulement actuelle : 17
- Cles seulement backup : 12
- Cles communes modifiees : 215
- Exemples cles actuelle seules : `[228], [229], [231], [232], [233], [234], [235], [236], [237], [239]`
- Exemples cles backup seules : `[150], [152], [157], [173], [181], [183], [191], [198], [65], [66]`
- Exemples cles modifiees : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.ep_obturateur`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 24
- Cles communes modifiees : 418
- Exemples cles backup seules : `[419], [420], [421], [422], [423], [424], [425], [426], [427], [428]`
- Exemples cles modifiees : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.ep_pompe`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 1
- Exemples cles modifiees : `[1]`

### `ep.ep_reduc_pres`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 1
- Exemples cles modifiees : `[1]`

### `ep.ep_regard`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 95
- Cles communes modifiees : 1344
- Exemples cles backup seules : `[1345], [1346], [1347], [1348], [1349], [1350], [1351], [1352], [1353], [1354]`
- Exemples cles modifiees : `[1000], [1001], [1002], [1003], [1004], [1005], [1006], [1007], [1008], [1009]`

### `ep.ep_regard_point`

- PK : `fid`
- Cles seulement actuelle : 1344
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[1000], [1001], [1002], [1003], [1004], [1005], [1006], [1007], [1008], [1009]`

### `ep.ep_reservoir`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 21
- Cles communes modifiees : 11
- Exemples cles backup seules : `[11], [14], [15], [16], [17], [18], [19], [20], [21], [22]`
- Exemples cles modifiees : `[10], [12], [13], [1], [2], [3], [4], [5], [6], [7]`

### `ep.ep_st_demineralisation`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 5
- Exemples cles modifiees : `[1], [2], [3], [4], [5]`

### `ep.ep_station_pompage`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 5
- Exemples cles modifiees : `[1], [2], [3], [4], [5]`

### `ep.ep_traversee`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 82
- Cles communes modifiees : 20
- Exemples cles backup seules : `[100], [101], [102], [14], [19], [20], [21], [22], [26], [27]`
- Exemples cles modifiees : `[10], [11], [12], [13], [15], [16], [17], [18], [1], [23]`

### `ep.ep_vanne`

- PK : `fid`
- Cles seulement actuelle : 14
- Cles seulement backup : 0
- Cles communes modifiees : 511
- Exemples cles actuelle seules : `[512], [513], [514], [515], [516], [517], [518], [519], [520], [521]`
- Exemples cles modifiees : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.ep_ventouse`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 43
- Cles communes modifiees : 399
- Exemples cles backup seules : `[400], [401], [402], [403], [404], [405], [406], [407], [408], [409]`
- Exemples cles modifiees : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.ep_vidange`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 54
- Cles communes modifiees : 302
- Exemples cles backup seules : `[303], [304], [305], [306], [307], [308], [309], [310], [311], [312]`
- Exemples cles modifiees : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `ep.onep_db`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 10580
- Exemples cles modifiees : `[10000], [10001], [10002], [10003], [10004], [10005], [10006], [10007], [10008], [10009]`

### `ep.statistique_conduite`

- PK : `id_statistique_conduite`
- Cles seulement actuelle : 0
- Cles seulement backup : 302
- Cles communes modifiees : 0
- Exemples cles backup seules : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `public.attribut_config`

- PK : `fid`
- Cles seulement actuelle : 61
- Cles seulement backup : 118
- Cles communes modifiees : 74
- Exemples cles actuelle seules : `[245], [246], [247], [248], [249], [250], [251], [252], [253], [254]`
- Exemples cles backup seules : `[1649], [1650], [1651], [1652], [1653], [1654], [1655], [1656], [1657], [1658]`
- Exemples cles modifiees : `[1441], [379], [380], [381], [382], [383], [384], [385], [386], [387]`

### `public.attribut_config_mobile`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 544
- Exemples cles modifiees : `[100], [103], [10], [1102], [1103], [1106], [1109], [1115], [1116], [111]`

### `public.basemap_package`

- PK : `id_package`
- Cles seulement actuelle : 21
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[10], [11], [12], [13], [14], [15], [16], [17], [18], [19]`

### `public.conflit`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 1
- Cles communes modifiees : 0
- Exemples cles backup seules : `[1]`

### `public.dashboard_stats_cache`

- PK : `cache_key`
- Cles seulement actuelle : 0
- Cles seulement backup : 1
- Cles communes modifiees : 0
- Exemples cles backup seules : `["ep:progress=0:spatial=0"]`

### `public.django_migrations`

- PK : `id`
- Cles seulement actuelle : 11
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[32], [33], [34], [35], [36], [37], [38], [39], [40], [41]`

### `public.fond_plan`

- PK : `fid`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 5
- Exemples cles modifiees : `[55834], [55835], [55844], [55971], [56564]`

### `public.formulaire_config_mobile`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 46
- Exemples cles modifiees : `[106], [107], [108], [10], [111], [114], [116], [11], [13], [14]`

### `public.historique_action`

- PK : `id`
- Cles seulement actuelle : 5844
- Cles seulement backup : 13858
- Cles communes modifiees : 2522
- Exemples cles actuelle seules : `[31000], [31001], [31002], [31003], [31004], [31005], [31006], [31007], [31008], [31009]`
- Exemples cles backup seules : `[38871], [38872], [38873], [38874], [38875], [38876], [38877], [38878], [38879], [38880]`
- Exemples cles modifiees : `[10894], [10895], [10896], [10897], [10898], [13147], [13148], [21426], [21427], [21428]`

### `public.historique_traitement`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 5
- Cles communes modifiees : 0
- Exemples cles backup seules : `[1], [2], [3], [4], [5]`

### `public.intervention_anomalie`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 63
- Cles communes modifiees : 320
- Exemples cles backup seules : `[340], [341], [342], [343], [344], [345], [346], [347], [348], [349]`
- Exemples cles modifiees : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `public.intervention_log`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 408
- Cles communes modifiees : 0
- Exemples cles backup seules : `[1010], [1011], [1012], [1013], [1014], [1015], [1016], [1017], [1018], [1019]`

### `public.liste_choix`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 176
- Exemples cles modifiees : `[1005], [1012], [1026], [1065], [1072], [1296], [1301], [1308], [1357], [1358]`

### `public.mission_livraison`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 1
- Cles communes modifiees : 0
- Exemples cles backup seules : `[24]`

### `public.mission_objet`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 792
- Cles communes modifiees : 0
- Exemples cles backup seules : `[1500], [1501], [1502], [1503], [1504], [1505], [1506], [1507], [1508], [1509]`

### `public.objet_photo`

- PK : `id_photo`
- Cles seulement actuelle : 0
- Cles seulement backup : 6865
- Cles communes modifiees : 4269
- Exemples cles backup seules : `[10000], [10001], [10002], [10003], [10004], [10005], [10006], [10007], [10008], [10009]`
- Exemples cles modifiees : `[1000], [1001], [1002], [1003], [1004], [1005], [1006], [1007], [1008], [1009]`

### `public.old_liste_choix`

- PK : `id`
- Cles seulement actuelle : 0
- Cles seulement backup : 1804
- Cles communes modifiees : 0
- Exemples cles backup seules : `[100], [101], [102], [103], [104], [105], [106], [107], [108], [109]`

### `public.permission`

- PK : `id_permission`
- Cles seulement actuelle : 0
- Cles seulement backup : 4
- Cles communes modifiees : 0
- Exemples cles backup seules : `[26], [27], [28], [29]`

### `public.srm_field_option`

- PK : `id_option`
- Cles seulement actuelle : 0
- Cles seulement backup : 0
- Cles communes modifiees : 38
- Exemples cles modifiees : `[153], [154], [155], [156], [157], [158], [159], [160], [161], [162]`

### `public.sync_session`

- PK : `id_sync_session`
- Cles seulement actuelle : 3
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[2], [3], [4]`

### `public.sync_session_attachment`

- PK : `id_sync_attachment`
- Cles seulement actuelle : 6
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[1], [2], [3], [4], [5], [6]`

### `public.sync_session_item`

- PK : `id_sync_item`
- Cles seulement actuelle : 5
- Cles seulement backup : 0
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[2], [3], [4], [5], [6]`

### `public.utilisateur`

- PK : `id_user`
- Cles seulement actuelle : 2
- Cles seulement backup : 4
- Cles communes modifiees : 6
- Exemples cles actuelle seules : `[3], [4]`
- Exemples cles backup seules : `[17], [18], [19], [21]`
- Exemples cles modifiees : `[10], [16], [20], [2], [7], [8]`

### `public.utilisateur_permission`

- PK : `id`
- Cles seulement actuelle : 17
- Cles seulement backup : 25
- Cles communes modifiees : 0
- Exemples cles actuelle seules : `[254], [255], [256], [257], [258], [259], [260], [261], [262], [263]`
- Exemples cles backup seules : `[499], [500], [501], [502], [503], [504], [505], [506], [507], [508]`

### `public.zone_utilisateur`

- PK : `id`
- Cles seulement actuelle : 40
- Cles seulement backup : 0
- Cles communes modifiees : 23
- Exemples cles actuelle seules : `[28], [29], [30], [31], [32], [33], [34], [35], [36], [37]`
- Exemples cles modifiees : `[10], [11], [12], [13], [14], [15], [16], [17], [18], [19]`


## Fichiers

- JSON detaille : `reports/comparaison_contenu_srm_bureau_vs_srmo_vf_20260508_125826.json`
- Rapport Markdown : `reports/comparaison_contenu_srm_bureau_vs_srmo_vf_20260508_125826.md`
