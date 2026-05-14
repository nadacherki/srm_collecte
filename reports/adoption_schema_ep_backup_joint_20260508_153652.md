# Adoption schema ep depuis backup joint

- Genere: `2026-05-08T15:40:08`
- BD actuelle: `SRM_bureau`
- Reference backup: `codex_cmp_srm_vf_web_20260508_1521`
- Statut: `OK`

## Resume schema
| Section | + actuelle | + backup | modifies |
|---|---:|---:|---:|
| relations | 0 | 0 | 0 |
| columns | 0 | 0 | 0 |
| constraints | 1 | 0 | 0 |
| indexes | 0 | 0 | 0 |
| triggers | 0 | 0 | 0 |
| routines | 0 | 0 | 0 |
| sequences | 0 | 0 | 0 |

## Difference conservee volontairement
- `ep.autre_objet.fk_autre_objet_agent` conservee sur `id_user_creat -> public.utilisateur(id_user)`.

## Lignes EP apres migration
| Table | Lignes |
|---|---:|
| `ep.anomalie_conduite` | 0 |
| `ep.autre_objet` | 0 |
| `ep.borne_onep` | 0 |
| `ep.bouche_a_cles` | 0 |
| `ep.centre_tampon` | 0 |
| `ep.conduite_terrain` | 0 |
| `ep.ep_bache` | 0 |
| `ep.ep_bf` | 267 |
| `ep.ep_bouche_arro` | 0 |
| `ep.ep_branchement` | 1989 |
| `ep.ep_brc_pt` | 2156 |
| `ep.ep_compteur_i` | 37 |
| `ep.ep_conduite` | 1626 |
| `ep.ep_cone_reduc` | 53 |
| `ep.ep_forage` | 2 |
| `ep.ep_hydrant` | 19 |
| `ep.ep_noeud` | 227 |
| `ep.ep_obturateur` | 442 |
| `ep.ep_pompe` | 1 |
| `ep.ep_puit` | 0 |
| `ep.ep_reduc_pres` | 1 |
| `ep.ep_regard` | 1439 |
| `ep.ep_regard_point` | 0 |
| `ep.ep_reservoir` | 32 |
| `ep.ep_st_demineralisation` | 5 |
| `ep.ep_station_pompage` | 5 |
| `ep.ep_traversee` | 102 |
| `ep.ep_vanne` | 511 |
| `ep.ep_ventouse` | 442 |
| `ep.ep_vidange` | 356 |
| `ep.onep_db` | 10580 |
| `ep.statistique_conduite` | 302 |
| `ep.statistique_conduite_segment` | 0 |
| `ep.tn` | 0 |
| `ep.voie` | 0 |