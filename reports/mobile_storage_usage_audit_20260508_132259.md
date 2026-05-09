# Audit stockage mobile et role de SrmConfig

- Genere le: 2026-05-08 13:22:59
- Base Django: `SRM_bureau`
- Tables SQLite statiques detectees: `17`
- Entites metier SrmConfig detectees: `47`
- Endpoints mobiles API detectes: `52`

## Verdict

`SrmConfig` reste un registre technique critique cote mobile: il cree les tables SQLite metier, sert a la legende/carte, aux formulaires, au sync et au lien entre noms mobiles et tables physiques. Il ne faut donc pas le supprimer brutalement.

En revanche, il ne doit plus etre la source metier principale pour l'ordre, la visibilite, les libelles et les listes: ces elements doivent venir de `formulaire_config_mobile`, `attribut_config_mobile` et `liste_choix`, avec un fallback strictement synchronise.

## Resume
| Source | Nombre |
| --- | --- |
| SrmConfig ep/asst/elec | {'ep': 30, 'asst': 17} |
| Endpoints API | 52 |
| Static SQLite | 17 |

## Tables physiques serveur
| Schema | Tables |
| --- | --- |
| asst | 26 |
| elec | 11 |
| ep | 35 |
| public | 33 |

## Tables SQLite locales declarees
| Table locale | Origine |
| --- | --- |
| app_metadata | statique DatabaseHelper |
| attribut_config_mobile_local | statique DatabaseHelper |
| commune_oriental_local | statique DatabaseHelper |
| conduite_sync_queue | statique DatabaseHelper |
| formulaire_config_mobile_local | statique DatabaseHelper |
| historique_local_attribut | statique DatabaseHelper |
| historique_local_evenement | statique DatabaseHelper |
| intervention_anomalie | statique DatabaseHelper |
| objet_incomplet | statique DatabaseHelper |
| onep_db | statique DatabaseHelper |
| photo_sync_queue | statique DatabaseHelper |
| regional_basemap_state | statique DatabaseHelper |
| srm_field_option_local | statique DatabaseHelper |
| srm_session | statique DatabaseHelper |
| utilisateur_local | statique DatabaseHelper |
| zone_local | statique DatabaseHelper |
| zone_utilisateur_local | statique DatabaseHelper |
| ASS_BORGNE | SrmConfig -> asst.ASS_BORGNE / Point |
| ASS_BOUCHE | SrmConfig -> asst.ASS_BOUCHE / Point |
| ASS_CANIVEAU | SrmConfig -> asst.ASS_CANIVEAU / LineString |
| ASS_CANIV_BRANCHE | SrmConfig -> asst.ASS_CANIV_BRANCHE / LineString |
| ASS_COL_BOUCHE | SrmConfig -> asst.ASS_COL_BOUCHE / LineString |
| ASS_DEVERSOIR | SrmConfig -> asst.ASS_DEVERSOIR / Point |
| ASS_STA_EPUR | SrmConfig -> asst.ASS_STA_EPUR / Point |
| ASS__EXUTOIRE | SrmConfig -> asst.ASS__EXUTOIRE / Point |
| asst_bassin | SrmConfig -> asst.ASS_BASSIN_VERSANT / Point |
| asst_branchement | SrmConfig -> asst.ASS_BRANCHEMENT / LineString |
| asst_canalisation | SrmConfig -> asst.ASS_COLLECTEUR / LineString |
| asst_canalisation_reutilisation | SrmConfig -> asst.ASS_REFOULEMENTR / LineString |
| asst_equipement | SrmConfig -> asst.ASS_POMPE / Point |
| asst_ouvrage | SrmConfig -> asst.ASS_OUV_TRAVERSEE / Point |
| asst_regard | SrmConfig -> asst.ASS_REGARD / Point |
| asst_regard_branchement | SrmConfig -> asst.ASS_REGARD_FACADE / Point |
| asst_station | SrmConfig -> asst.ASS_STA_POMP / Point |
| anomalie_conduite | SrmConfig -> ep.anomalie_conduite / Point |
| autre_objet | SrmConfig -> ep.autre_objet / Point |
| borne_fontaine | SrmConfig -> ep.ep_bf / Point |
| borne_onep | SrmConfig -> ep.borne_onep / Point |
| bouche_a_cles | SrmConfig -> ep.bouche_a_cles / Point |
| bouche_darrosage | SrmConfig -> ep.ep_bouche_arro / Point |
| branchement | SrmConfig -> ep.ep_branchement / LineString |
| centre_tampon | SrmConfig -> ep.centre_tampon / Point |
| compteur_abonne | SrmConfig -> ep.ep_brc_pt / Point |
| compteur_reseau | SrmConfig -> ep.ep_compteur_i / Point |
| conduite_terrain | SrmConfig -> ep.conduite_terrain / LineString |
| cone_de_reduction | SrmConfig -> ep.ep_cone_reduc / Point |
| ep_bache | SrmConfig -> ep.ep_bache / Point |
| ep_regard_point | SrmConfig -> ep.ep_regard_point / Point |
| forage | SrmConfig -> ep.ep_forage / Point |
| hydrant | SrmConfig -> ep.ep_hydrant / Point |
| noeud | SrmConfig -> ep.ep_noeud / Point |
| obturateur | SrmConfig -> ep.ep_obturateur / Point |
| planche | SrmConfig -> ep.planche / Polygon |
| pompe | SrmConfig -> ep.ep_pompe / Point |
| puit | SrmConfig -> ep.ep_puit / Point |
| reducteur_de_pression | SrmConfig -> ep.ep_reduc_pres / Point |
| reservoir | SrmConfig -> ep.ep_reservoir / Point |
| station_de_pompage | SrmConfig -> ep.ep_station_pompage / Point |
| tn | SrmConfig -> ep.tn / Point |
| traverse | SrmConfig -> ep.ep_traversee / LineString |
| vanne | SrmConfig -> ep.ep_vanne / Point |
| vanne_de_vidange | SrmConfig -> ep.ep_vidange / Point |
| ventouse | SrmConfig -> ep.ep_ventouse / Point |
| voie | SrmConfig -> ep.voie / LineString |

## Formulaires config serveur vs mobile
| Table physique | Titre | Ordre | Visible | Download | Champs visibles/total | Table locale SrmConfig | Endpoint |
| --- | --- | --- | --- | --- | --- | --- | --- |
| asst.ASS_REGARD | Regards de visite | 1 | true | true | 18/68 | asst_regard | yes |
| asst.ASS_REGARD_FACADE | Regards Façade | 2 | true | true | 3/59 | asst_regard_branchement | yes |
| asst.ASS_BORGNE | Regards Borgnes | 3 | true | true | 3/66 | ASS_BORGNE | yes |
| asst.ASS_BOUCHE | Bouches d'égout | 4 | true | true | 3/52 | ASS_BOUCHE | yes |
| asst.ASS_DEVERSOIR | Déversoirs d'orage | 5 | true | true | 3/73 | ASS_DEVERSOIR | yes |
| asst.ASS__EXUTOIRE | Exutoires | 6 | true | true | 3/61 | ASS__EXUTOIRE | yes |
| asst.ASS_STA_POMP | Stations de pompage | 7 | true | true | 3/56 | asst_station | yes |
| asst.ASS_COLLECTEUR | Collecteurs | 8 | true | true | 12/71 | asst_canalisation | yes |
| asst.ASS_BRANCHEMENT | Branchements collecteur | 9 | true | true | 9/49 | asst_branchement | yes |
| asst.ASS_CANIVEAU | Caniveaux | 10 | true | true | 0/51 | ASS_CANIVEAU | yes |
| asst.ASS_CANIV_BRANCHE | Caniveau branchement | 11 | true | true | 0/49 | ASS_CANIV_BRANCHE | yes |
| asst.ASS_COL_BOUCHE | Collecteur bouche d'égout | 12 | true | true | 0/71 | ASS_COL_BOUCHE | yes |
| asst.ASS_BASSIN_VERSANT | Bassins versants | 13 | false | false | 0/32 | asst_bassin | yes |
| asst.ASS_STA_EPUR | Stations d'épuration | 14 | true | true | 14/55 | ASS_STA_EPUR | yes |
| asst.ASS_BASSIN_RET | Bassins de rétention | 15 | false | false | 3/56 | - | no |
| asst.ASS_BASSIN_RET_L | Bassins de rétention (ligne) | 16 | false | false | 0/32 | - | no |
| asst.ASS_ECOULEMENT | Écoulement | 17 | false | false | 0/26 | - | no |
| asst.ASS_FOSSE_SEPT | Fosses septiques | 18 | false | false | 3/57 | - | no |
| asst.ASS_OUED | Oued | 19 | false | false | 0/22 | - | no |
| asst.ASS_OUV_TRAVERSEE | Ouvrages de traversée | 20 | false | false | 0/66 | asst_ouvrage | yes |
| asst.ASS_POINTS-NOIRS | Points noirs | 21 | false | false | 3/65 | - | no |
| asst.ASS_POMPE | Pompes | 22 | false | false | 0/44 | asst_equipement | yes |
| asst.ASS_REFOULEMENTR | Refoulement réutilisation | 23 | false | false | 0/68 | asst_canalisation_reutilisation | yes |
| asst.ASS_SECTEUR_ASS | Secteurs assainissement | 24 | false | false | 0/31 | - | no |
| asst.ASS_STA_EPUR_L | Stations d'épuration (ligne) | 25 | false | false | 3/43 | - | no |
| asst.ASS_STA_POMP_S | Stations de pompage (surface) | 26 | false | false | 3/54 | - | no |
| ep.ep_regard_point | Regard | 1 | true | true | 19/68 | ep_regard_point | yes |
| ep.conduite_terrain | Conduite terrain | 2 | true | true | 2/53 | conduite_terrain | yes |
| ep.ep_conduite | Conduite bureau | 3 | false | false | 3/83 | - | yes |
| ep.ep_brc_pt | Compteur abonné | 4 | true | true | 18/62 | compteur_abonne | yes |
| ep.ep_bf | Borne fontaine | 5 | true | true | 20/70 | borne_fontaine | yes |
| ep.ep_traversee | Traversée | 6 | true | true | 13/59 | traverse | yes |
| ep.ep_cone_reduc | Cône de réduction | 7 | true | true | 11/55 | cone_de_reduction | yes |
| ep.ep_compteur_i | Compteur réseau | 8 | true | true | 13/64 | compteur_reseau | yes |
| ep.ep_hydrant | Hydrant | 9 | true | true | 20/69 | hydrant | yes |
| ep.ep_vanne | Vanne | 10 | true | true | 18/63 | vanne | yes |
| ep.ep_obturateur | Obturateur | 11 | true | true | 8/44 | obturateur | yes |
| ep.ep_branchement | Branchement | 12 | false | false | 7/43 | branchement | yes |
| ep.ep_bache | Bâche | 13 | true | true | 12/51 | ep_bache | yes |
| ep.ep_bouche_arro | Bouche d'arrosage | 14 | false | false | 7/51 | bouche_darrosage | yes |
| ep.ep_vidange | Vanne de vidange | 15 | true | true | 16/58 | vanne_de_vidange | yes |
| ep.ep_ventouse | Ventouse | 16 | true | true | 14/57 | ventouse | yes |
| ep.ep_reduc_pres | Réducteur de pression | 17 | true | true | 11/62 | reducteur_de_pression | yes |
| ep.voie | Voie | 18 | true | true | 1/17 | voie | yes |
| ep.centre_tampon | Centre tampon | 19 | false | false | 5/26 | centre_tampon | yes |
| ep.ep_reservoir | Réservoir | 20 | true | true | 20/69 | reservoir | yes |
| ep.ep_forage | Forage | 21 | true | true | 18/62 | forage | yes |
| ep.ep_noeud | Noeud | 22 | false | false | 2/39 | noeud | yes |
| ep.ep_pompe | Pompe | 23 | true | true | 14/51 | pompe | yes |
| ep.ep_station_pompage | Station de pompage | 24 | true | true | 13/61 | station_de_pompage | yes |
| ep.ep_puit | Puits | 25 | false | false | 7/42 | puit | yes |
| ep.ep_st_demineralisation | Station de déminéralisation | 26 | false | false | 14/54 | - | no |
| ep.tn | TN | 27 | true | true | 3/19 | tn | yes |
| ep.anomalie_conduite | Anomalie conduite | 28 | true | true | 1/21 | anomalie_conduite | yes |
| ep.ep_regard | Regard (polygone) | 29 | false | true | 3/73 | - | yes |
| ep.borne_onep | Borne ONEP | 30 | true | true | 3/26 | borne_onep | yes |
| ep.bouche_a_cles | Bouche à clé | 31 | true | true | 3/28 | bouche_a_cles | yes |
| ep.onep_db | ONEP DB | 32 | false | true | 0/15 | - | no |
| ep.autre_objet | Autre objet EP | 33 | true | true | 4/21 | autre_objet | yes |
| ep.statistique_conduite | Statistique conduite | 34 | false | false | 0/7 | - | no |
| ep.statistique_conduite_segment | Segment statistique conduite | 35 | false | false | 0/10 | - | no |

## Formulaires visibles avec gap technique
Aucun gap detecte: chaque formulaire visible a une entree SrmConfig et un endpoint API.

## Endpoints mobiles
| Endpoint | Table physique | Usage |
| --- | --- | --- |
| ass/bassins | asst.ASS_BASSIN_VERSANT | sync mobile |
| ass/bassins-versants | asst.ASS_BASSIN_VERSANT | sync mobile |
| ass/bouches | asst.ASS_BOUCHE | sync mobile |
| ass/branchements | asst.ASS_BRANCHEMENT | sync mobile |
| ass/canalisations | asst.ASS_COLLECTEUR | sync mobile |
| ass/canalisations-reutilisation | asst.ASS_REFOULEMENTR | sync mobile |
| ass/caniveaux | asst.ASS_CANIVEAU | sync mobile |
| ass/caniveaux-branchement | asst.ASS_CANIV_BRANCHE | sync mobile |
| ass/collecteurs | asst.ASS_COLLECTEUR | sync mobile |
| ass/collecteurs-bouche | asst.ASS_COL_BOUCHE | sync mobile |
| ass/deversoirs | asst.ASS_DEVERSOIR | sync mobile |
| ass/equipements | asst.ASS_POMPE | sync mobile |
| ass/exutoires | asst.ASS__EXUTOIRE | sync mobile |
| ass/ouvrages | asst.ASS_OUV_TRAVERSEE | sync mobile |
| ass/regards | asst.ASS_REGARD | sync mobile |
| ass/regards-borgnes | asst.ASS_BORGNE | sync mobile |
| ass/regards-branchement | asst.ASS_REGARD_FACADE | sync mobile |
| ass/regards-facade | asst.ASS_REGARD_FACADE | sync mobile |
| ass/stations | asst.ASS_STA_POMP | sync mobile |
| ass/stations-epuration | asst.ASS_STA_EPUR | sync mobile |
| ass/stations-pompage | asst.ASS_STA_POMP | sync mobile |
| ep/anomalies-conduite | ep.anomalie_conduite | sync mobile |
| ep/autres-objets | ep.autre_objet | sync mobile |
| ep/baches | ep.ep_bache | sync mobile |
| ep/bornes-fontaine | ep.ep_bf | sync mobile |
| ep/bornes-onep | ep.borne_onep | sync mobile |
| ep/bouches-arrosage | ep.ep_bouche_arro | sync mobile |
| ep/bouches-cles | ep.bouche_a_cles | sync mobile |
| ep/branchements | ep.ep_branchement | sync mobile |
| ep/centres-tampon | ep.centre_tampon | sync mobile |
| ep/compteurs-abonne | ep.ep_brc_pt | sync mobile |
| ep/compteurs-reseau | ep.ep_compteur_i | sync mobile |
| ep/conduites-bureau | ep.ep_conduite | API only |
| ep/conduites-terrain | ep.conduite_terrain | sync mobile |
| ep/cones-reduction | ep.ep_cone_reduc | sync mobile |
| ep/forages | ep.ep_forage | sync mobile |
| ep/hydrants | ep.ep_hydrant | sync mobile |
| ep/noeuds | ep.ep_noeud | sync mobile |
| ep/obturateurs | ep.ep_obturateur | sync mobile |
| ep/pompes | ep.ep_pompe | sync mobile |
| ep/puits | ep.ep_puit | sync mobile |
| ep/reducteurs-pression | ep.ep_reduc_pres | sync mobile |
| ep/regards | ep.ep_regard_point | sync mobile |
| ep/regards-miroir | ep.ep_regard | API only |
| ep/reservoirs | ep.ep_reservoir | sync mobile |
| ep/stations-pompage | ep.ep_station_pompage | sync mobile |
| ep/tn | ep.tn | sync mobile |
| ep/traverses | ep.ep_traversee | sync mobile |
| ep/vannes | ep.ep_vanne | sync mobile |
| ep/vannes-vidange | ep.ep_vidange | sync mobile |
| ep/ventouses | ep.ep_ventouse | sync mobile |
| ep/voies | ep.voie | sync mobile |

## Tables serveur sans usage mobile direct detecte
| Table | Diagnostic |
| --- | --- |
| elec.cellule | elec restored on server; no current mobile config/SrmConfig |
| elec.coffret_bt | elec restored on server; no current mobile config/SrmConfig |
| elec.depart_bt | elec restored on server; no current mobile config/SrmConfig |
| elec.depart_hta | elec restored on server; no current mobile config/SrmConfig |
| elec.noeud_raccord | elec restored on server; no current mobile config/SrmConfig |
| elec.point_desserte | elec restored on server; no current mobile config/SrmConfig |
| elec.poste | elec restored on server; no current mobile config/SrmConfig |
| elec.support | elec restored on server; no current mobile config/SrmConfig |
| elec.transformateur | elec restored on server; no current mobile config/SrmConfig |
| elec.troncon_bt | elec restored on server; no current mobile config/SrmConfig |
| elec.troncon_hta | elec restored on server; no current mobile config/SrmConfig |

## Recommandation de trajectoire

1. Court terme: garder `SrmConfig` comme registre technique et fallback.
2. Continuer a brancher ordre/visibilite/libelles/champs/listes sur les tables serveur.
3. Ajouter plus tard cote serveur les metadonnees encore absentes: `table_mobile`, type geometrie, endpoint, icone/couleur, max photos.
4. Quand ces metadonnees serveur existent, reduire `SrmConfig` a un fallback minimal ou le generer automatiquement.
