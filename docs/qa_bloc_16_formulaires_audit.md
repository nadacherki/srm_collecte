# QA bloc 16 - Audit du module formulaires

Date : 2026-06-01

## Verdict court

Le module formulaire est structurellement cohérent : les tables physiques EP/ASST, `formulaire_config_mobile`, `attribut_config_mobile` et `liste_choix` sont alignées sur les contrôles de base.

Le point à ne pas masquer avant production est la dette de validation des champs obligatoires : 209 contraintes requises sont posées en `NOT VALID`. Elles protègent les nouvelles écritures, mais elles ne prouvent pas que l'historique déjà présent en base respecte le contrat.

## Audits exécutés

- `srmenv\Scripts\python.exe tools\audit_mobile_config_schema_coherence.py --no-fail`
- `srmenv\Scripts\python.exe tools\audit_mobile_form_mapping.py`

Rapport principal généré :

- `reports/mobile_config_schema_coherence_audit_20260601_132808.md`
- `reports/mobile_config_schema_coherence_audit_20260601_132808.json`

## Cohérence configuration / tables physiques

Résultat renforcé :

- Tables formulaire vérifiées : 61
- Tables physiques vérifiées : 61
- Attributs vérifiés : 2909
- Choix vérifiés : 928
- Tables physiques manquantes : 0
- Mismatches de type : 0
- Mismatches `nullable` : 0
- Attributs sans colonne physique : 0
- Colonnes physiques sans attribut config : 0
- Choix sans attribut : 0
- Choix sans colonne physique : 0
- Défauts hors liste de choix : 0

Conclusion : le mapping structurel est bon.

## Point prod critique : contraintes obligatoires NOT VALID

Le premier audit donnait un faux vert, car il considérait les contraintes `srm_req_*` / `srm_nn_*` comme équivalentes à `NOT NULL` sans vérifier si elles étaient validées. Le script a été renforcé pour remonter `not_valid_required_constraints`.

Résultat :

- Contraintes requises `NOT VALID` : 209
- Champs avec violations historiques existantes : 122

Tables les plus concernées par les valeurs historiques manquantes :

| Table | Champs requis NOT VALID | Champs avec violations | Violations historiques |
| --- | ---: | ---: | ---: |
| `ep.ep_brc_pt` | 11 | 11 | 10126 |
| `ep.ep_regard_point` | 12 | 12 | 4585 |
| `ep.ep_bf` | 14 | 13 | 821 |
| `ep.ep_ventouse` | 8 | 3 | 627 |
| `ep.ep_vanne` | 10 | 5 | 515 |
| `ep.ep_reservoir` | 14 | 14 | 381 |
| `ep.ep_vidange` | 10 | 1 | 356 |
| `ep.ep_noeud` | 1 | 1 | 227 |
| `ep.ep_traversee` | 9 | 9 | 83 |
| `ep.ep_hydrant` | 13 | 3 | 57 |
| `asst.ASS_REGARD` | 13 | 13 | 52 |

Interprétation :

- Pour les nouvelles données, les contraintes `NOT VALID` restent appliquées par PostgreSQL.
- Pour les anciennes données, la base contient encore des lignes qui ne respectent pas le contrat mobile actuel.
- Avant une certification production complète, il faut soit backfiller ces valeurs, soit relaxer la configuration si certains champs ne doivent finalement pas être obligatoires.
- Les contraintes sans violation historique peuvent être validées.

## Présentation mobile des formulaires

Résultat `audit_mobile_form_mapping.py` :

- EP : 35 formulaires, 24 visibles, 11 cachés.
- ASST : 26 formulaires, 14 visibles, 12 cachés.
- Le fallback `formulaire_config_mobile` correspond aux lignes DB.
- Aucun formulaire visible sans couverture technique bloquante.
- Les lignes `download_mobile` sont couvertes.

Nuance à valider métier :

- Les formulaires ASST visibles ont actuellement `choice_fields=0`. Si des listes déroulantes métier sont attendues en ASST, elles ne sont pas encore configurées dans `liste_choix`.
- Certains formulaires visibles sont volontairement très légers ou location-only : `ASS_CANIVEAU`, `ASS_CANIV_BRANCHE`, `ASS_COL_BOUCHE`, `ASS_BASSIN_VERSANT`, `borne_onep`, `bouche_a_cles`.

## Contraintes, valeurs par défaut, min/max

Constat configuration :

- Les valeurs par défaut sont chargées dans le cache mobile et appliquées à la création.
- Les champs obligatoires côté mobile viennent de `nullable=false`.
- Les bornes `valeur_min` / `valeur_max` sont appliquées dans les formulaires point, ligne et regard EP.
- Les règles JSON `contraintes_regles` actuelles sont uniquement sur `ep.ep_regard_point`.

Nuance :

- Le moteur de règles avancées est pleinement branché sur le formulaire point et revalidé côté serveur pour les règles `action=error`.
- Les formulaires ligne/polygone couvrent les requis/min/max, mais pas tout le moteur JSON avancé. Ce n'est pas bloquant aujourd'hui puisque les règles JSON actuelles concernent `ep_regard_point`. Si demain on ajoute des règles JSON sur lignes/polygones, il faudra brancher le même moteur.

## Regard point / regard miroir

Le modèle actuel n'est pas une interchangeabilité stricte.

- `ep_regard_point` est l'objet métier.
- `ep_regard` est un miroir polygone visuel.
- Les insert/update sont synchronisés sur les colonnes communes.
- La suppression est volontairement asymétrique : supprimer le point marque le miroir supprimé ; supprimer le miroir ne supprime pas le point.
- Côté mobile, le miroir est traité comme une couche read-only liée au regard point.

Conclusion : c'est cohérent si le métier accepte que le point soit la source de vérité et que le polygone soit seulement une représentation. Si le métier demande deux objets réellement interchangeables, il faudra changer le design.

## Statut production

Vert :

- Mapping configuration / tables physiques.
- Rendu mobile depuis configuration.
- Listes de choix EP et défauts contrôlés.
- Regard miroir non éditable directement.
- Revalidation serveur des règles bloquantes.

Orange :

- 209 contraintes requises `NOT VALID`.
- 122 champs ont encore des violations historiques.
- Listes de choix ASST à confirmer métier.
- Moteur JSON avancé à étendre seulement si des règles sont ajoutées aux lignes/polygones.

Décision recommandée avant lancement :

1. Backfiller ou relaxer les champs requis avec violations historiques.
2. Valider les contraintes `srm_req_*` / `srm_nn_*` après nettoyage.
3. Confirmer avec le métier les listes de choix ASST.
4. Garder `ep_regard_point` comme source de vérité, sauf demande explicite d'un redesign miroir.
