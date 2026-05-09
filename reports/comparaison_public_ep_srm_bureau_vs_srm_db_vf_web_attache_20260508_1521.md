# Comparaison BD actuelle vs backup joint

- BD actuelle: `SRM_bureau`
- Backup restaure en temporaire: `codex_cmp_srm_vf_web_20260508_1521`
- Fichier backup: `C:\Users\AnasDahou\Downloads\srm_db_vf_web  (1).backup`
- Schemas compares: `public, ep`
- Genere: `2026-05-08T15:29:48`

## Lecture rapide
- Aucun objet relationnel manque d'un cote ou de l'autre dans `public` et `ep`: memes tables, vues, sequences et index.
- `public`: la BD actuelle a `public.formulaire_config_mobile.download_mobile` en plus, 2 colonnes `public.onep_commune_alias` en `varchar(400)` contre `varchar` sans limite dans le backup, 1 contrainte unique en plus, 2 triggers/fonctions de garde en plus.
- `ep`: la BD actuelle a 106 colonnes en plus, dont `photo_1` a `photo_4` sur 25 tables. Le backup a 12 colonnes en plus, principalement sur `ep.autre_objet` plus `ep.conduite_terrain.ep_classe_conduite`.
- Les 327 colonnes `ep` marquees "definition differente" ne changent que par `ordinal_position`: les types, nullabilites et defaults des colonnes communes restent identiques.
- Contenu: 31 tables ont un checksum identique. Les vrais ecarts de lignes visibles sont `ep.statistique_conduite` (302 actuelle vs 126 backup) et, dans `public`, `attribut_config_mobile`, `conflit`, `django_migrations`, `historique_action`, `historique_traitement`. `ep.ep_branchement`, `public.liste_choix` et `public.utilisateur` ont le meme nombre de lignes mais un checksum different.

## Resume structure
| Section | + actuelle | + backup | modifies |
| --- | --- | --- | --- |
| relations | 0 | 0 | 0 |
| columns | 107 | 12 | 329 |
| constraints | 2 | 0 | 0 |
| indexes | 0 | 0 | 0 |
| triggers | 2 | 0 | 0 |
| views | 0 | 0 | 0 |
| routines | 2 | 0 | 0 |
| enums | 0 | 0 | 0 |
| sequences | 0 | 0 | 0 |

## Resume contenu tables
| Statut | Nombre |
| --- | --- |
| checksum_diff | 3 |
| checksum_skipped_structure_diff | 28 |
| row_count_diff | 6 |
| same_content | 31 |

## Tables avec ecart de contenu ou non comparees
| Table | Statut | Lignes actuelle | Lignes backup |
| --- | --- | --- | --- |
| `ep.anomalie_conduite` | checksum_skipped_structure_diff | 0 | 0 |
| `ep.autre_objet` | checksum_skipped_structure_diff | 0 | 0 |
| `ep.centre_tampon` | checksum_skipped_structure_diff | 0 | 0 |
| `ep.conduite_terrain` | checksum_skipped_structure_diff | 0 | 0 |
| `ep.ep_bache` | checksum_skipped_structure_diff | 0 | 0 |
| `ep.ep_bf` | checksum_skipped_structure_diff | 267 | 267 |
| `ep.ep_bouche_arro` | checksum_skipped_structure_diff | 0 | 0 |
| `ep.ep_branchement` | checksum_diff | 1989 | 1989 |
| `ep.ep_brc_pt` | checksum_skipped_structure_diff | 2156 | 2156 |
| `ep.ep_compteur_i` | checksum_skipped_structure_diff | 37 | 37 |
| `ep.ep_conduite` | checksum_skipped_structure_diff | 1626 | 1626 |
| `ep.ep_cone_reduc` | checksum_skipped_structure_diff | 53 | 53 |
| `ep.ep_forage` | checksum_skipped_structure_diff | 2 | 2 |
| `ep.ep_hydrant` | checksum_skipped_structure_diff | 19 | 19 |
| `ep.ep_obturateur` | checksum_skipped_structure_diff | 442 | 442 |
| `ep.ep_pompe` | checksum_skipped_structure_diff | 1 | 1 |
| `ep.ep_puit` | checksum_skipped_structure_diff | 0 | 0 |
| `ep.ep_reduc_pres` | checksum_skipped_structure_diff | 1 | 1 |
| `ep.ep_regard` | checksum_skipped_structure_diff | 1439 | 1439 |
| `ep.ep_regard_point` | checksum_skipped_structure_diff | 0 | 0 |
| `ep.ep_reservoir` | checksum_skipped_structure_diff | 32 | 32 |
| `ep.ep_st_demineralisation` | checksum_skipped_structure_diff | 5 | 5 |
| `ep.ep_station_pompage` | checksum_skipped_structure_diff | 5 | 5 |
| `ep.ep_traversee` | checksum_skipped_structure_diff | 102 | 102 |
| `ep.ep_vanne` | checksum_skipped_structure_diff | 511 | 511 |
| `ep.ep_ventouse` | checksum_skipped_structure_diff | 442 | 442 |
| `ep.ep_vidange` | checksum_skipped_structure_diff | 356 | 356 |
| `ep.statistique_conduite` | row_count_diff | 302 | 126 |
| `public.attribut_config_mobile` | row_count_diff | 3351 | 3357 |
| `public.conflit` | row_count_diff | 1 | 7 |
| `public.django_migrations` | row_count_diff | 45 | 31 |
| `public.formulaire_config_mobile` | checksum_skipped_structure_diff | 61 | 61 |
| `public.historique_action` | row_count_diff | 47546 | 51724 |
| `public.historique_traitement` | row_count_diff | 5 | 6 |
| `public.liste_choix` | checksum_diff | 935 | 935 |
| `public.onep_commune_alias` | checksum_skipped_structure_diff | 1 | 1 |
| `public.utilisateur` | checksum_diff | 13 | 13 |

## columns
### Present seulement dans la BD actuelle
| Objet |
| --- |
| `ep.anomalie_conduite.photo_1` |
| `ep.anomalie_conduite.photo_2` |
| `ep.anomalie_conduite.photo_3` |
| `ep.anomalie_conduite.photo_4` |
| `ep.autre_objet.anomalie` |
| `ep.autre_objet.conformite_plan` |
| `ep.autre_objet.date_leve` |
| `ep.autre_objet.id_agent_crea` |
| `ep.autre_objet.mode_localisation` |
| `ep.autre_objet.photo_1` |
| `ep.autre_objet.photo_2` |
| `ep.autre_objet.photo_3` |
| `ep.autre_objet.photo_4` |
| `ep.autre_objet.type_anomalie` |
| `ep.centre_tampon.photo_1` |
| `ep.centre_tampon.photo_2` |
| `ep.centre_tampon.photo_3` |
| `ep.centre_tampon.photo_4` |
| `ep.conduite_terrain.photo_1` |
| `ep.conduite_terrain.photo_2` |
| `ep.conduite_terrain.photo_3` |
| `ep.conduite_terrain.photo_4` |
| `ep.ep_bache.photo_1` |
| `ep.ep_bache.photo_2` |
| `ep.ep_bache.photo_3` |
| `ep.ep_bache.photo_4` |
| `ep.ep_bf.photo_1` |
| `ep.ep_bf.photo_2` |
| `ep.ep_bf.photo_3` |
| `ep.ep_bf.photo_4` |
| `ep.ep_bouche_arro.photo_1` |
| `ep.ep_bouche_arro.photo_2` |
| `ep.ep_bouche_arro.photo_3` |
| `ep.ep_bouche_arro.photo_4` |
| `ep.ep_brc_pt.photo_1` |
| `ep.ep_brc_pt.photo_2` |
| `ep.ep_brc_pt.photo_3` |
| `ep.ep_brc_pt.photo_4` |
| `ep.ep_compteur_i.photo_1` |
| `ep.ep_compteur_i.photo_2` |
| `ep.ep_compteur_i.photo_3` |
| `ep.ep_compteur_i.photo_4` |
| `ep.ep_cone_reduc.photo_1` |
| `ep.ep_cone_reduc.photo_2` |
| `ep.ep_cone_reduc.photo_3` |
| `ep.ep_cone_reduc.photo_4` |
| `ep.ep_forage.photo_1` |
| `ep.ep_forage.photo_2` |
| `ep.ep_forage.photo_3` |
| `ep.ep_forage.photo_4` |
| `ep.ep_hydrant.photo_1` |
| `ep.ep_hydrant.photo_2` |
| `ep.ep_hydrant.photo_3` |
| `ep.ep_hydrant.photo_4` |
| `ep.ep_obturateur.photo_1` |
| `ep.ep_obturateur.photo_2` |
| `ep.ep_obturateur.photo_3` |
| `ep.ep_obturateur.photo_4` |
| `ep.ep_pompe.photo_1` |
| `ep.ep_pompe.photo_2` |
| `ep.ep_pompe.photo_3` |
| `ep.ep_pompe.photo_4` |
| `ep.ep_puit.photo_1` |
| `ep.ep_puit.photo_2` |
| `ep.ep_puit.photo_3` |
| `ep.ep_puit.photo_4` |
| `ep.ep_reduc_pres.photo_1` |
| `ep.ep_reduc_pres.photo_2` |
| `ep.ep_reduc_pres.photo_3` |
| `ep.ep_reduc_pres.photo_4` |
| `ep.ep_regard.photo_1` |
| `ep.ep_regard.photo_2` |
| `ep.ep_regard.photo_3` |
| `ep.ep_regard.photo_4` |
| `ep.ep_regard_point.photo_1` |
| `ep.ep_regard_point.photo_2` |
| `ep.ep_regard_point.photo_3` |
| `ep.ep_regard_point.photo_4` |
| `ep.ep_reservoir.photo_1` |
| `ep.ep_reservoir.photo_2` |
... 27 autres elements dans le JSON.

### Present seulement dans le backup
| Objet |
| --- |
| `ep.autre_objet.date_creation` |
| `ep.autre_objet.date_modif` |
| `ep.autre_objet.date_validation` |
| `ep.autre_objet.id_mission` |
| `ep.autre_objet.id_province` |
| `ep.autre_objet.id_user_creat` |
| `ep.autre_objet.id_user_modif` |
| `ep.autre_objet.id_user_valid` |
| `ep.autre_objet.id_zone` |
| `ep.autre_objet.is_deleted` |
| `ep.autre_objet.is_validated` |
| `ep.conduite_terrain.ep_classe_conduite` |

### Definition differente
| Objet | Empreinte actuelle | Empreinte backup |
| --- | --- | --- |
| `ep.anomalie_conduite.id_mission` | 613158accf | 3e788d96ce |
| `ep.anomalie_conduite.source` | f34de49d8f | 29b3589ca1 |
| `ep.autre_objet.ep_coor_x` | 05e5299d63 | c7c3eb340f |
| `ep.autre_objet.ep_coor_y` | 2b9c302fd6 | 748f970914 |
| `ep.autre_objet.ep_coor_z` | b4b91fb830 | 0e955b21b9 |
| `ep.autre_objet.geom` | 86ee1c7605 | 41144d1614 |
| `ep.autre_objet.id_commune` | d296b94ee6 | 5a788852c4 |
| `ep.autre_objet.id_planche` | e9d76428a1 | d68a6c2c77 |
| `ep.autre_objet.observation` | 8048303898 | fdc629ceff |
| `ep.autre_objet.uuid` | c74d08053e | 4dd37ea29f |
| `ep.centre_tampon.id_mission` | 14b26b4b30 | 049c62c1d3 |
| `ep.centre_tampon.source` | 441c1428a2 | c601742dbb |
| `ep.conduite_terrain.id_mission` | 90504e711a | 259b4aa25a |
| `ep.conduite_terrain.id_planche` | 14b26b4b30 | 049c62c1d3 |
| `ep.conduite_terrain.source` | ae87aba123 | b5201e6af5 |
| `ep.ep_bache.id_mission` | 3975a57a2f | 7a03524e45 |
| `ep.ep_bache.source` | b1f71f2995 | 7e42a64e52 |
| `ep.ep_bf.diamcond` | a8262b23c3 | a2a2fb6899 |
| `ep.ep_bf.emplacement` | e57523b8ba | cba076e725 |
| `ep.ep_bf.ep_diam` | 5320a967bc | 72fd5006de |
| `ep.ep_bf.ep_etat_s` | 84b954e20d | 6b75e24988 |
| `ep.ep_bf.existence_compteur_global` | 53d9300607 | 84b954e20d |
| `ep.ep_bf.existence_compteurs_prives` | 23f1ecfe2c | 78cbe9346d |
| `ep.ep_bf.fonctionnelle` | 541bcf563b | e57523b8ba |
| `ep.ep_bf.id_mission` | 5912b474f2 | 121c99bb60 |
| `ep.ep_bf.nombre_robinets` | 08b50fbf40 | fab1c3a32d |
| `ep.ep_bf.source` | c9c09687b4 | 3f0c68e912 |
| `ep.ep_bouche_arro.id_mission` | 3975a57a2f | 7a03524e45 |
| `ep.ep_bouche_arro.source` | b1f71f2995 | 7e42a64e52 |
| `ep.ep_brc_pt.id_mission` | eb66892a12 | fd58a54823 |
| `ep.ep_brc_pt.source` | 9ed6972629 | 9b4fbb8ee8 |
| `ep.ep_brc_pt.type_anomalie` | 3f0c68e912 | 903846a8a6 |
| `ep.ep_compteur_i.id_mission` | 67a41a10e9 | adff2dd94f |
| `ep.ep_compteur_i.source` | ce0122f380 | c012d1ac0c |
| `ep.ep_conduite.altitute` | 0dffdf1468 | e6f9738986 |
| `ep.ep_conduite.annee_renouv` | 188e84e9b6 | c71b7f6185 |
| `ep.ep_conduite.autocad_layer` | 28ed70af95 | 9b2ec116bf |
| `ep.ep_conduite.commune` | 2c574978a5 | ba91965d7f |
| `ep.ep_conduite.date_creation` | ab650c8d1b | bb2ac2b2f5 |
| `ep.ep_conduite.date_modif` | 6a0b029486 | ab650c8d1b |
| `ep.ep_conduite.date_validation` | d57d813176 | e0fb410c0d |
| `ep.ep_conduite.ep_agent_crea` | 92a5dc8d14 | 4fc95550bc |
| `ep.ep_conduite.ep_anomalie` | 1d65e4a5a0 | 820e63235f |
| `ep.ep_conduite.ep_conf_plan` | ce83ed8e9d | 269f011fd4 |
| `ep.ep_conduite.ep_coor_x` | f10a381711 | 69542b077a |
| `ep.ep_conduite.ep_coor_y` | f0540514f0 | f10a381711 |
| `ep.ep_conduite.ep_coor_z` | 2dea1caa3c | f0540514f0 |
| `ep.ep_conduite.ep_lien` | 9b2ec116bf | abcc42f68f |
| `ep.ep_conduite.ep_observation` | 820e63235f | ce83ed8e9d |
| `ep.ep_conduite.ep_photo` | abcc42f68f | 41699a1bb6 |
| `ep.ep_conduite.ep_qual1` | b343637ae2 | 89a92a37c7 |
| `ep.ep_conduite.ep_qual2` | c77b1a34b0 | b343637ae2 |
| `ep.ep_conduite.ep_qual3` | 3fd4fb6124 | c77b1a34b0 |
| `ep.ep_conduite.ep_statut` | f4f0e547d6 | 74c1d7bd0c |
| `ep.ep_conduite.ep_tf` | b8813a01c3 | f4f0e547d6 |
| `ep.ep_conduite.etage_aqua` | e4be843aa6 | 28ed70af95 |
| `ep.ep_conduite.geom` | 5c4f4eb120 | d5f2bef92a |
| `ep.ep_conduite.id_commune` | 72d3f14a93 | 5912b474f2 |
| `ep.ep_conduite.id_mission` | b831b96788 | 04ad2256ea |
| `ep.ep_conduite.id_planche` | 0142fb5b24 | b831b96788 |
... 269 autres elements modifies dans le JSON.

## constraints
### Present seulement dans la BD actuelle
| Objet |
| --- |
| `ep.autre_objet.fk_autre_objet_agent` |
| `public.onep_commune_alias.onep_commune_alias_onep_nom_commune_key` |

## triggers
### Present seulement dans la BD actuelle
| Objet |
| --- |
| `public.formulaire_config_mobile.trg_srm_formulaire_config_mobile_download_guard` |
| `public.objet_photo.trg_objet_photo_prevent_new_extra_slots` |

## routines
### Present seulement dans la BD actuelle
| Objet |
| --- |
| `public.objet_photo_prevent_new_extra_slots()` |
| `public.srm_formulaire_config_mobile_download_guard()` |
