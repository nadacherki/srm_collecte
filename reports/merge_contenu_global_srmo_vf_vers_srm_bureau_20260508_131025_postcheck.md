# Post-check merge contenu global - 2026-05-08 13:15

## Operation

- Source : `codex_cmp_srmo_vf_20260508` restauree depuis `C:\Users\AnasDahou\Downloads\srmo_vf_ .backup`
- Cible : `SRM_bureau`
- Sauvegarde avant merge : `backups/SRM_bureau_before_full_content_merge_20260508_130416.backup`
- Mode applique : insertion-only, sans update, sans delete applicatif.
- Contrainte photo elargie : `public.objet_photo.num_photo >= 1` via `API_GeoDjango/sql/2026-05-08_objet_photo_allow_more_slots.sql`.

## Resultat final des tables prioritaires

| Table | Lignes finales |
|---|---:|
| `public.historique_action` | 51 854 |
| `public.objet_photo` | 7 003 |
| `ep.ep_branchement` | 1 806 |
| `ep.ep_brc_pt` | 2 553 |
| `ep.ep_regard` | 1 349 |
| `ep.onep_db` | 10 580 |
| `public.planche` | 2 204 |

Le merge a ajoute 24 131 lignes, puis 2 204 doublons exacts de `public.planche` ont ete retires car cette table n'a pas de cle primaire. Gain net conserve : 21 927 lignes.

## Photos

`public.objet_photo` accepte maintenant les slots photo au-dela de 4. Repartition finale :

| num_photo | Lignes |
|---:|---:|
| 1 | 2 048 |
| 2 | 1 961 |
| 3 | 1 449 |
| 4 | 745 |
| 5 | 512 |
| 6 | 159 |
| 7 | 68 |
| 8 | 33 |
| 9 | 20 |
| 10 | 8 |

## Lignes source encore non inserees par identifiant

Ces lignes n'ont pas ete inserees car la BD actuelle possede deja une contrainte/cle naturelle equivalente ou un identifiant metier different. Aucune suppression ni overwrite n'a ete fait.

| Controle | Restant |
|---|---:|
| `public.historique_action` manquant par `id` | 0 |
| `public.objet_photo` manquant par `id_photo` | 4 131 |
| `ep.ep_branchement` manquant par `fid` | 183 |
| `ep.ep_regard` manquant par `fid` | 90 |
| `ep.ep_brc_pt` manquant par `fid` | 0 |

## Diagnostic `ep.onep_db`

`ep.onep_db` n'a pas recu de nouvelles lignes car les 10 580 `id` de la source existent deja dans `SRM_bureau`.

L'ecart detecte vient de :

- `uuid` different sur 10 580 lignes ;
- `adresse postale client payeur` differente sur 1 ligne.

Donc le probleme `onep_db` n'est pas un manque de lignes : c'est une difference de valeurs sur des lignes deja presentes, surtout des UUID regeneres.

## Verification

- `python manage.py check` : OK
