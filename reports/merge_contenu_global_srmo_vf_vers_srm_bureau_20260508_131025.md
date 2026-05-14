# Merge contenu global srmo_vf -> SRM_bureau - 2026-05-08T13:10:27

- Source restauree : `codex_cmp_srmo_vf_20260508`
- Cible : `SRM_bureau`
- Sauvegarde avant merge : `backups/SRM_bureau_before_full_content_merge_20260508_130416.backup`
- Mode : insertion-only, sans update, sans delete, `ON CONFLICT DO NOTHING`.
- Contrainte `public.objet_photo.num_photo` elargie via `API_GeoDjango/sql/2026-05-08_objet_photo_allow_more_slots.sql`.
- Triggers utilisateur temporairement desactives pendant l insertion, puis reactives, pour eviter les audits artificiels.

## Synthese

| Indicateur | Valeur |
|---|---:|
| Tables communes traitees | 103 |
| Tables avec insertions | 26 |
| Lignes inserees | 24131 |
| Tables seulement source | 0 |
| Tables seulement cible | 3 |

## Insertions par table

| Table | Avant | Source | Inserees | Apres | PK |
|---|---:|---:|---:|---:|---|
| `public.historique_action` | 37996 | 46010 | 13858 | 51854 | `id` |
| `public.objet_photo` | 4269 | 11134 | 2734 | 7003 | `id_photo` |
| `public.planche` | 2204 | 2204 | 2204 | 4408 | `sans PK` |
| `public.old_liste_choix` | 0 | 1804 | 1804 | 1804 | `id` |
| `ep.ep_branchement` | 199 | 1989 | 1607 | 1806 | `fid` |
| `public.mission_objet` | 0 | 792 | 792 | 792 | `id` |
| `public.intervention_log` | 658 | 1066 | 408 | 1066 | `id` |
| `ep.statistique_conduite` | 0 | 302 | 302 | 302 | `id_statistique_conduite` |
| `ep.ep_traversee` | 20 | 102 | 67 | 87 | `fid` |
| `public.intervention_anomalie` | 329 | 392 | 63 | 392 | `id` |
| `ep.ep_conduite` | 1549 | 1626 | 60 | 1609 | `fid` |
| `public.attribut_config` | 1216 | 1273 | 57 | 1273 | `fid` |
| `ep.ep_ventouse` | 399 | 442 | 40 | 439 | `fid` |
| `ep.ep_vidange` | 302 | 356 | 39 | 341 | `fid` |
| `public.utilisateur_permission` | 25 | 33 | 25 | 50 | `id` |
| `ep.ep_obturateur` | 418 | 442 | 16 | 434 | `fid` |
| `ep.ep_reservoir` | 11 | 32 | 16 | 27 | `fid` |
| `ep.ep_noeud` | 232 | 227 | 12 | 244 | `fid` |
| `ep.ep_hydrant` | 14 | 19 | 9 | 23 | `fid` |
| `ep.ep_regard` | 1344 | 1439 | 5 | 1349 | `fid` |
| `public.historique_traitement` | 0 | 5 | 5 | 5 | `id` |
| `public.permission` | 18 | 22 | 4 | 22 | `id_permission` |
| `public.conflit` | 0 | 1 | 1 | 1 | `id` |
| `public.dashboard_stats_cache` | 0 | 1 | 1 | 1 | `cache_key` |
| `public.mission_livraison` | 0 | 1 | 1 | 1 | `id` |
| `public.utilisateur` | 11 | 13 | 1 | 12 | `id_user` |

## Tables demandees initialement

| Table | Avant | Source | Inserees | Apres |
|---|---:|---:|---:|---:|
| `public.historique_action` | 37996 | 46010 | 13858 | 51854 |
| `public.objet_photo` | 4269 | 11134 | 2734 | 7003 |
| `ep.ep_branchement` | 199 | 1989 | 1607 | 1806 |
| `ep.ep_brc_pt` | 2553 | 2156 | 0 | 2553 |
| `ep.ep_regard` | 1344 | 1439 | 5 | 1349 |
| `ep.onep_db` | 10580 | 10580 | 0 | 10580 |

## Fichiers

- JSON detaille : `reports/merge_contenu_global_srmo_vf_vers_srm_bureau_20260508_131025.json`
- Rapport Markdown : `reports/merge_contenu_global_srmo_vf_vers_srm_bureau_20260508_131025.md`
