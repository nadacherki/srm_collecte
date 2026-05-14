# Adaptation intervention anomalie - guide equipe_bureau - 2026-05-08

## Source analysee

- Guide recu : `C:\Users\AnasDahou\Downloads\INTERVENTION_TRIGGER_NOTES_MOBILE.md`
- BD inspectee : `SRM_bureau` sur `127.0.0.1:5432`
- Tables ciblees : `public.intervention_anomalie`, `public.intervention_log`

## Etat avant correction

La structure et les triggers existaient deja, mais le mapping du workflow etait l'ancien :

| statut | responsable_actuel avant | attendu guide |
|---|---|---|
| `signale` | `terrain` | `exploitant` |
| `exploitant_traite` | `terrain` | `terrain` |
| `terrain_traite` | `exploitant` dans trigger | `bureau` |

Comptage avant application :

| statut | responsable_actuel | lignes |
|---|---:|---:|
| `signale` | `terrain` | 319 |
| `exploitant_traite` | `terrain` | 10 |

Ecart au mapping du guide : 319 lignes.

## Correction appliquee

Script ajoute et applique :

- `API_GeoDjango/sql/2026-05-08_intervention_anomalie_bureau_workflow.sql`

Le script :

- cree les backups `public.intervention_anomalie_backup_before_bureau_workflow_20260508` et `public.intervention_log_backup_before_bureau_workflow_20260508` ;
- met le default de `responsable_actuel` a `exploitant` ;
- remplace `intervention_anomalie_before_write()` avec le mapping du guide :
  - `signale -> exploitant`
  - `exploitant_traite -> terrain`
  - `terrain_traite -> bureau`
  - `bureau_traite -> bureau`
  - `retour_terrain -> terrain`
  - `cloture` / `annule -> cloture`
- remplace `intervention_anomalie_after_write_log()` pour ne plus journaliser un changement purement derive de `responsable_actuel` ;
- recree les triggers `trg_intervention_anomalie_before_write`, `trg_intervention_anomalie_after_write_log` et `trg_intervention_log_prevent_update` ;
- remappe les lignes existantes.

## Etat apres correction

| statut | responsable_actuel | lignes |
|---|---:|---:|
| `signale` | `exploitant` | 319 |
| `exploitant_traite` | `terrain` | 10 |

Ecart au mapping du guide : 0 ligne.

Les deux tables gardent le meme nombre de lignes apres correction :

| table | lignes |
|---|---:|
| `intervention_anomalie` | 329 |
| `intervention_log` | 658 |
| backup `intervention_anomalie` | 329 |
| backup `intervention_log` | 658 |

## Code backend aligne

Fichiers ajustes :

- `API_GeoDjango/pprcollecte/api/models.py`
- `API_GeoDjango/pprcollecte/api/views.py`

La creation automatique d'une intervention depuis un objet en anomalie renseigne maintenant `commentaire_exploitant` et `id_user_exploitant` sur le statut initial `signale`, au lieu de remplir les champs terrain.

## Verification

- `python manage.py check` : OK
- Test SQL en transaction rollback :
  - INSERT `signale` donne `responsable_actuel=exploitant`
  - UPDATE `exploitant_traite` donne `responsable_actuel=terrain`
  - UPDATE `terrain_traite` donne `responsable_actuel=bureau`
  - UPDATE `retour_terrain` donne `responsable_actuel=terrain`, `etat_terrain=en_attente`, `retour_terrain=true`
  - UPDATE `cloture` donne `responsable_actuel=cloture` et `date_cloture` non nulle

## Point restant hors tables

Le guide mentionne des endpoints web bureau/exploitant (`traiter-exploitant`, `valider-bureau`, `renvoyer-terrain`, etc.). Dans le code actuel, seul l'endpoint mobile terrain existe : `/api/interventions-anomalies-terrain/`. Cette adaptation couvre les tables/triggers et la creation automatique ; les endpoints web restent a implementer si l'equipe bureau veut piloter tout le workflow via API dediee.
