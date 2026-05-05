# Rapport homogenisation public - SRM vs SRM_bureau

Date: 2026-05-01

## Regle de travail

Pour chaque table traitee, documenter:

- mismatch observe
- decision retenue
- modification effectuee sur `SRM_bureau`
- verification apres modification

## Inventaire initial

### SRM

| Objet public | Type | Lignes | Colonnes |
| --- | --- | ---: | ---: |
| `agent_basemap_zone` | BASE TABLE | 2 | 8 |
| `api_login` | BASE TABLE | 0 | 6 |
| `auth_group` | BASE TABLE | 0 | 2 |
| `auth_group_permissions` | BASE TABLE | 0 | 3 |
| `auth_permission` | BASE TABLE | 124 | 4 |
| `auth_user` | BASE TABLE | 0 | 11 |
| `auth_user_groups` | BASE TABLE | 0 | 3 |
| `auth_user_user_permissions` | BASE TABLE | 0 | 3 |
| `basemap_package` | BASE TABLE | 7 | 21 |
| `basemap_zone` | BASE TABLE | 12 | 16 |
| `commune` | BASE TABLE | 11 | 5 |
| `django_admin_log` | BASE TABLE | 0 | 8 |
| `django_content_type` | BASE TABLE | 31 | 3 |
| `django_migrations` | BASE TABLE | 24 | 4 |
| `django_session` | BASE TABLE | 0 | 3 |
| `evaluation_agent` | BASE TABLE | 0 | 11 |
| `fond_de_plan` | BASE TABLE | 0 | 7 |
| `historique_attribut` | BASE TABLE | 7573 | 14 |
| `historique_mobile` | BASE TABLE | 15540 | 20 |
| `mission` | BASE TABLE | 1 | 11 |
| `objet_incomplet` | BASE TABLE | 0 | 14 |
| `objet_photo` | BASE TABLE | 15 | 16 |
| `projet` | BASE TABLE | 1 | 10 |
| `spatial_ref_sys` | BASE TABLE | 8500 | 5 |
| `srm_field_option` | BASE TABLE | 76 | 9 |
| `statistique_conduite` | BASE TABLE | 0 | 7 |
| `statistique_conduite_segment` | BASE TABLE | 0 | 10 |
| `sync_session` | BASE TABLE | 1 | 18 |
| `sync_session_attachment` | BASE TABLE | 0 | 15 |
| `sync_session_item` | BASE TABLE | 1 | 17 |
| `utilisateur` | BASE TABLE | 3 | 10 |
| `geography_columns` | VIEW |  | 7 |
| `geometry_columns` | VIEW |  | 7 |
| `vw_metrics_agent_jour` | VIEW |  | 27 |
| `vw_metrics_agent_mois` | VIEW |  | 29 |
| `vw_metrics_agent_public_jour` | VIEW |  | 35 |
| `vw_metrics_agent_public_mois` | VIEW |  | 37 |
| `vw_metrics_agent_public_resume` | VIEW |  | 32 |
| `vw_metrics_agent_public_semaine` | VIEW |  | 38 |
| `vw_metrics_agent_semaine` | VIEW |  | 30 |
| `vw_metrics_projet_jour` | VIEW |  | 36 |
| `vw_metrics_projet_mois` | VIEW |  | 31 |
| `vw_metrics_projet_resume` | VIEW |  | 33 |
| `vw_metrics_projet_semaine` | VIEW |  | 32 |
| `vw_srm_historique_fact` | VIEW |  | 21 |
| `vw_srm_historique_mobile_fact` | VIEW |  | 27 |
| `vw_srm_incomplet_fact` | VIEW |  | 21 |
| `vw_srm_mission_fact` | VIEW |  | 15 |
| `vw_srm_objet_dates` | VIEW |  | 29 |
| `vw_srm_objet_fact` | VIEW |  | 18 |
| `vw_srm_photo_fact` | VIEW |  | 25 |

### SRM_bureau

| Objet public | Type | Lignes | Colonnes |
| --- | --- | ---: | ---: |
| `_stg_split_anomalies_20260430_194633` | BASE TABLE | 5 | 20 |
| `attribut_config` | BASE TABLE | 1216 | 9 |
| `attribut_config_mobile` | BASE TABLE | 2047 | 16 |
| `commune` | BASE TABLE | 1505 | 7 |
| `evaluation_agent` | BASE TABLE | 0 | 11 |
| `fond_plan` | BASE TABLE | 18957 | 21 |
| `historique_action` | BASE TABLE | 84 | 10 |
| `intervention_anomalie` | BASE TABLE | 329 | 20 |
| `intervention_log` | BASE TABLE | 11 | 8 |
| `liste_choix` | BASE TABLE | 1830 | 10 |
| `liste_choix_backup_avant_defaut_choix_20260428_1349` | BASE TABLE | 3353 | 20 |
| `liste_choix_backup_avant_eclatement_20260428_134013` | BASE TABLE | 1989 | 14 |
| `liste_choix_backup_avant_ep_regard_maj2_20260428_1425` | BASE TABLE | 3339 | 20 |
| `liste_choix_backup_avant_ep_regard_maj3_20260428_1438` | BASE TABLE | 3335 | 20 |
| `liste_choix_backup_avant_ep_regard_maj_20260428_1415` | BASE TABLE | 3353 | 20 |
| `liste_choix_backup_avant_ep_regard_nouveaux_champs_20260428_151` | BASE TABLE | 3334 | 20 |
| `liste_choix_backup_avant_ep_regard_ordre_20260428_1447` | BASE TABLE | 3334 | 20 |
| `liste_choix_backup_avant_ep_regard_ordre_front_20260428_1455` | BASE TABLE | 3334 | 20 |
| `liste_choix_backup_avant_split_20260430_194633` | BASE TABLE | 3090 | 20 |
| `liste_choix_old_20260430_194633` | BASE TABLE | 3090 | 20 |
| `mission_livraison` | BASE TABLE | 0 | 13 |
| `mission_objet` | BASE TABLE | 0 | 10 |
| `objet_incomplet` | BASE TABLE | 0 | 10 |
| `permission` | BASE TABLE | 18 | 3 |
| `planche` | BASE TABLE | 2204 | 3 |
| `province` | BASE TABLE | 77 | 5 |
| `spatial_ref_sys` | BASE TABLE | 8500 | 5 |
| `utilisateur` | BASE TABLE | 8 | 11 |
| `utilisateur_permission` | BASE TABLE | 25 | 3 |
| `zone` | BASE TABLE | 21 | 8 |
| `zone_utilisateur` | BASE TABLE | 23 | 5 |
| `geography_columns` | VIEW |  | 7 |
| `geometry_columns` | VIEW |  | 7 |

## Comparaison initiale

Objets communs:

Uniquement dans `SRM`: `api_login`, `auth_group`, `auth_group_permissions`, `auth_permission`, `auth_user`, `auth_user_groups`, `auth_user_user_permissions`, `historique_attribut`, `historique_mobile`, `mission`, `objet_photo`, `projet`, `srm_field_option`, `statistique_conduite`, `statistique_conduite_segment`, `sync_session`, `sync_session_attachment`, `sync_session_item`, `vw_metrics_agent_jour`, `vw_metrics_agent_mois`, `vw_metrics_agent_public_jour`, `vw_metrics_agent_public_mois`, `vw_metrics_agent_public_resume`, `vw_metrics_agent_public_semaine`, `vw_metrics_agent_semaine`, `vw_metrics_projet_jour`, `vw_metrics_projet_mois`, `vw_metrics_projet_resume`, `vw_metrics_projet_semaine`, `vw_srm_historique_fact`, `vw_srm_historique_mobile_fact`, `vw_srm_incomplet_fact`, `vw_srm_mission_fact`, `vw_srm_objet_dates`, `vw_srm_objet_fact`, `vw_srm_photo_fact`

Uniquement dans `SRM_bureau`:  `attribut_config`, `attribut_config_mobile`, `fond_plan`, `historique_action`, `intervention_anomalie`, `intervention_log`, `liste_choix`,

## Traitement table par table

### `public.commune`

Statut: mismatch confirme, table intermediaire creee dans `SRM_bureau`.

Observation structure:

- `SRM.public.commune`: 5 colonnes
  - `id_commune`
  - `nom_commune`
  - `nom_province`
  - `nom_region`
  - `geom`
- `SRM_bureau.public.commune`: 7 colonnes
  - `fid`
  - `geom`
  - `code_provi`
  - `code_regio`
  - `nom`
  - `nom_arabe`
  - `id_province`

Observation contenu:

- `SRM`: 11 lignes, limitees aux communes du projet Oujda-Angad.
- `SRM_bureau`: 1505 lignes, referentiel national plus large.
- Les geometries sont du meme type general: `ST_MultiPolygon`.
- Le SRID est coherent des deux cotes: `26191`.
- Les 11 communes Oujda-Angad de `SRM` existent dans `SRM_bureau`, mais avec une nomenclature differente, par exemple:
  - `OUJDA` vs `Commune d'Oujda`
  - `AHL ANGAD` vs `Commune d'Ahl Angad`
  - `SIDI MOUSSA LEMHAYA` vs `Commune de Sidi Moussa Lemhaya`

Decision initiale:

- Ne pas remplacer immediatement `SRM_bureau.public.commune`.
- Garder la structure de `SRM_bureau.public.commune`.
- Reduire seulement le contenu au perimetre Oujda-Angad apres validation de la strategie d'extraction.

Modification effectuee sur `SRM_bureau`:

- Creation de `public.commune_oujda_intermediaire`.
- Objectif: tester un extrait Oujda-Angad en conservant strictement la structure de `SRM_bureau.public.commune`.
- Critere utilise pour ce premier extrait:
  - `id_province = 15`
  - ou `code_provi = '02.411.'`
- La table contient 11 lignes.
- Colonnes creees:
  - `fid`
  - `geom`
  - `code_provi`
  - `code_regio`
  - `nom`
  - `nom_arabe`
  - `id_province`

Strategie d'extraction a discuter:

- Option 1 - extraction administrative par province: utiliser `id_province = 15` / `code_provi = '02.411.'`.
  - Avantage: simple, reproductible, stable si le referentiel province est fiable.
  - Risque: depend de la qualite des codes administratifs.
- Option 2 - extraction spatiale: selectionner les communes qui intersectent une emprise projet ou les objets metier Oujda.
  - Avantage: utile si le perimetre projet ne suit pas exactement les limites administratives.
  - Risque: plus complexe; peut inclure des communes voisines si les objets/emprises debordent.
- Option 3 - extraction par liste blanche des 11 communes attendues.
  - Avantage: controle maximal pour ce projet Oujda.
  - Risque: moins generalisable et plus manuel.

Proposition actuelle:

- Garder la structure de `SRM_bureau`.
- Choisir explicitement une strategie d'extraction avant de remplacer ou filtrer `SRM_bureau.public.commune`.
- L'extraction administrative (`id_province = 15` / `code_provi = '02.411.'`) retourne exactement 11 communes pour ce premier test.

Decision appliquee ensuite:

- La structure `SRM_bureau.public.commune` est retenue comme structure cible.
- La strategie d'extraction retenue pour ce passage est administrative:
  - `id_province = 15`
  - ou `code_provi = '02.411.'`
- `SRM.public.commune` a ete remplacee par les 11 communes Oujda-Angad dans la structure `SRM_bureau`:
  - `fid`
  - `geom`
  - `code_provi`
  - `code_regio`
  - `nom`
  - `nom_arabe`
  - `id_province`
- Sauvegarde creee avant remplacement:
  - `public.commune_backup_before_srm_bureau_structure_20260501`
- Les anciennes references `id_commune` des tables `ep` et `ass` ont ete remappees vers les nouveaux `fid`.
- Les contraintes FK ont ete recreees vers `public.commune(fid)`.
- La table intermediaire `SRM_bureau.public.commune_oujda_intermediaire` a ete supprimee apres migration.

Corrections applicatives:

- `API_GeoDjango/pprcollecte/api/models.py`
  - `Commune` utilise maintenant `fid`, `nom`, `nom_arabe`, `code_provi`, `code_regio`, `id_province`.
- `API_GeoDjango/pprcollecte/api/serializers.py`
  - `CommuneSerializer` expose les champs `SRM_bureau`.
  - Il expose aussi les alias compatibles mobile:
    - `id_commune = fid`
    - `nom_commune = nom`
    - `nom_province = Préfecture d'Oujda-Angad` pour `code_provi = '02.411.'`
    - `nom_region = Oriental` pour `code_regio = '02.'`
- `API_GeoDjango/pprcollecte/api/views.py`
  - `CommuneViewSet` trie maintenant par `fid`.
- `PPRCollecte_Flutter/lib/data/local/database_helper.dart`
  - le cache local accepte `fid`/`nom` en fallback si `id_commune`/`nom_commune` ne sont pas fournis.
- Comme `public.evaluation_agent` a ete supprimee, l'endpoint `/api/evaluations/` et ses references directes ont ete retires.

Verification:

- Mismatch structure: confirme.
- Mismatch volume/contenu: confirme.
- Modification `SRM_bureau`: `public.commune_oujda_intermediaire` creee.
- La table intermediaire contient 11 lignes.
- La table intermediaire conserve la structure de `SRM_bureau.public.commune`.
- Toutes les geometries intermediaires ont le SRID `26191`.
- Toutes les geometries intermediaires sont de type `ST_MultiPolygon`.
- `SRM.public.commune` contient maintenant 11 lignes.
- `SRM.public.commune` contient les colonnes cibles `fid`, `geom`, `code_provi`, `code_regio`, `nom`, `nom_arabe`, `id_province`.
- Les 11 geometries de `SRM.public.commune` ont le SRID `26191`.
- Les 11 geometries de `SRM.public.commune` sont de type `ST_MultiPolygon`.
- 35 contraintes FK pointent maintenant vers `public.commune(fid)`.
- `/api/communes/` retourne 11 communes avec statut HTTP 200.
- `manage.py check`: OK.

### `public.evaluation_agent`

Statut: supprimee.

Observation structure:

- Les deux bases ont 11 colonnes identiques:
  - `id_eval`
  - `id_agent`
  - `periode`
  - `nb_objets_collectes`
  - `nb_objets_corriges_bo`
  - `nb_objets_incomplets`
  - `taux_qualite`
  - `taux_completion`
  - `commentaire`
  - `id_evaluateur`
  - `date_evaluation`

Observation contenu:

- `SRM`: 0 ligne.
- `SRM_bureau`: 0 ligne.

Decision initiale:

- Structure et contenu equivalentes pour ce premier passage.
- Table vide, non prioritaire pour le perimetre actuel.

Modification effectuee:

- `public.evaluation_agent` supprimee dans `SRM`.
- `public.evaluation_agent` supprimee dans `SRM_bureau`.

Verification:

- Suppression effectuee dans les deux bases.

### `public.geography_columns`

Statut: conservee, suppression refusee par PostgreSQL/PostGIS.

Observation:

- Il s'agit d'une vue systeme PostGIS, pas d'une table metier.
- Les deux bases ont la meme structure avec 7 colonnes:
  - `f_table_catalog`
  - `f_table_schema`
  - `f_table_name`
  - `f_geography_column`
  - `coord_dimension`
  - `srid`
  - `type`

Observation contenu:

- `SRM`: 0 ligne.
- `SRM_bureau`: 0 ligne.

Decision:

- Tentative de suppression effectuee.
- PostgreSQL refuse la suppression car `public.geography_columns` est requis par l'extension `postgis`.
- Ne pas supprimer l'extension `postgis`, car les geometries du projet en dependent.

Verification:

- Suppression non effectuee.
- Raison: `cannot drop view geography_columns because extension postgis requires it`.

### `public.geometry_columns`

Statut: vue PostGIS conservee, aucune modification effectuee.

Observation structure:

- Les deux bases ont la meme structure avec 7 colonnes:
  - `f_table_catalog`
  - `f_table_schema`
  - `f_table_name`
  - `f_geometry_column`
  - `coord_dimension`
  - `srid`
  - `type`

Observation contenu:

- `SRM`: 44 lignes.
- `SRM_bureau`: 62 lignes.
- L'ecart de contenu est attendu, car `geometry_columns` est une vue derivee des tables geometriques presentes dans la base.
- Repartition observee:
  - `SRM`: `ass` 9, `ep` 29, `public` 6.
  - `SRM_bureau`: `asst` 26, `ep` 30, `public` 6.

Decision:

- Ne pas modifier ni supprimer.
- Ne pas traiter comme table metier.
- Les differences seront resolues indirectement lorsque les schemas metier `ass/asst`, `ep` et `public` seront homogenises.

Verification:

- Structure identique: oui.
- Contenu identique: non, attendu.
- Modification `SRM_bureau`: aucune.

### `public.objet_incomplet`

Statut: structure cible confirmee et appliquee sur les deux bases.

Observation structure:

- `SRM.public.objet_incomplet`: 14 colonnes, structure utilisee par le backend/mobile actuel:
  - `id_incomplet`
  - `id_objet`
  - `nom_classe`
  - `metier`
  - `raison`
  - `detail_raison`
  - `date_signalement`
  - `id_agent_signal`
  - `statut`
  - `date_planification`
  - `id_agent_retour`
  - `date_completion`
  - `id_mission`
  - `id_projet`
- `SRM_bureau.public.objet_incomplet`: 10 colonnes, structure differente:
  - `id`
  - `nom_table`
  - `id_objet`
  - `id_user`
  - `date_signalement`
  - `raison`
  - `commentaire`
  - `statut`
  - `type`
  - `date_cloture`

Observation contenu:

- `SRM`: 0 ligne.
- `SRM_bureau`: 0 ligne.
- Les contenus sont donc equivalently vides, mais les structures ne sont pas compatibles.

Usages applicatifs constates:

- Backend Django:
  - modele `ObjetIncomplet`
  - serializer `ObjetIncompletSerializer`
  - endpoint `/api/objets-incomplets/`
  - vues metriques SQL `vw_srm_incomplet_fact` et `vw_metrics_*`
- Flutter:
  - table locale `objet_incomplet`
  - creation/mise a jour d'objets incomplets depuis les formulaires
  - synchronisation via `sync_service`

Decision proposee initiale:

- Pour l'application actuelle, la structure `SRM` est la structure cible fonctionnelle.
- `SRM_bureau.public.objet_incomplet` devra probablement etre remplacee ou migree vers la structure `SRM` avant bascule applicative.
- Aucune modification effectuee pendant ce passage, car cette table touche la synchronisation mobile et les metriques.

Decision finale validee:

- Remplacer la structure des deux bases par une structure commune simplifiee:
  - `id_incomplet serial primary key`
  - `nom_table varchar not null`
  - `id_objet integer not null`
  - `detail_raison text`
  - `date_signalement timestamp default now()`
  - `id_agent_incomplet integer`
  - `statut varchar default 'A_COMPLETER'`
  - `date_completion timestamp`
  - `id_agent_completement integer`
- Convention retenue pour `nom_table`: format `schema.table`.

Modifications effectuees:

- `SRM.public.objet_incomplet` recreee avec la structure validee.
- `SRM_bureau.public.objet_incomplet` recreee avec la structure validee.
- Sauvegardes creees avant remplacement:
  - `public.objet_incomplet_backup_before_common_structure_20260501` dans `SRM`.
  - `public.objet_incomplet_backup_before_common_structure_20260501` dans `SRM_bureau`.
- Index ajoutes:
  - `(nom_table, id_objet)`
  - `statut`
  - `date_signalement DESC`
  - `date_completion DESC`
- Backend Django:
  - `ObjetIncomplet` aligne sur la nouvelle structure.
- Flutter local:
  - table locale `objet_incomplet` alignee sur la nouvelle structure.
  - recherche locale des incomplets par `nom_table` + `id_objet`.
  - `id_agent_incomplet` et `id_agent_completement` remplacent les anciens champs agent.
- Scripts metriques:
  - `API_GeoDjango/sql/2026-04-14_metrics_collecte_views.sql` adapte pour lire `nom_table`, `id_agent_incomplet`, `id_agent_completement`.
  - Les vues metriques `SRM` ont ete reconstruites apres le `DROP TABLE ... CASCADE`.

Verification:

- Mismatch structure: confirme.
- Nombre de lignes identique: oui, 0 dans les deux bases.
- Structure finale identique dans `SRM` et `SRM_bureau`: oui.
- Nombre de lignes final: 0 dans les deux bases.
- `manage.py check`: OK.
- `ObjetIncomplet.objects.count()`: OK, 0 ligne.
- Vues metriques `SRM`: reconstruites.
- `public.vw_srm_incomplet_fact`: accessible, 0 ligne.

### Workflow `objet_incomplet` finalise - 2026-05-04

Objectif valide:

- Le workflow reste terrain/mobile uniquement.
- Il n'implique ni exploitant ni bureau.
- Un objet reste `A_COMPLETER` jusqu'a ce qu'un agent complete le metier.
- La completion passe la ligne liee a `COMPLETE`.

Flow retenu:

1. L'agent cree ou modifie un objet metier.
2. Il active `Objet incomplet`.
3. Le mobile sauvegarde l'objet metier avec `objet_incomplet = 1`.
4. Le mobile cree/met a jour une ligne locale `objet_incomplet`:
   - `nom_table` au format `schema.table`;
   - `id_objet`;
   - `detail_raison`;
   - `date_signalement`;
   - `id_agent_incomplet`;
   - `statut = A_COMPLETER`.
5. Lorsqu'un agent complete l'objet metier, le mobile:
   - remet `objet_incomplet = 0` sur l'objet metier;
   - passe la ligne liee a `COMPLETE`;
   - renseigne `date_completion`;
   - renseigne `id_agent_completement`.

Decision sur les champs deja remplis:

- Les donnees metier saisies avant de cocher `Objet incomplet` sont conservees.
- Le formulaire ne bloque pas sur les champs obligatoires manquants quand `Objet incomplet` est actif.
- La raison d'incompletion reste obligatoire.

Modifications mobile:

- Les formulaires point, ligne et polygone sauvegardent les champs deja renseignes meme si l'objet est incomplet.
- `objet_incomplet.nom_table` est normalise en `schema.table`.
- Les anciennes lignes locales avec un `nom_table` sans schema sont normalisees defensivement.
- `objet_incomplet` est ajoute au flux de synchronisation comme table speciale `public`.
- Endpoint de sync: `/api/objets-incomplets/`.
- La synchro garde l'ordre: objets metier d'abord, puis `objet_incomplet`.
- Pendant la meme session de sync, le mobile tente de remplacer l'id local par l'id serveur de l'objet metier quand la reponse serveur le fournit.

Modifications backend/API:

- `ObjetIncompletViewSet` devient un workflow dedie.
- Filtres disponibles:
  - `nom_table`
  - `id_objet`
  - `statut`
  - `id_agent_incomplet`
  - `id_agent_completement`
  - `open_only=true`
- POST sur une ligne deja ouverte fait un upsert au lieu de creer un doublon.
- POST avec `statut = COMPLETE` complete la ligne ouverte existante.
- Statuts acceptes par serializer:
  - `A_COMPLETER`
  - `COMPLETE`

Durcissement BD applique sur `SRM` et `SRM_bureau`:

- Script ajoute:
  - `API_GeoDjango/sql/2026-05-04_objet_incomplet_workflow.sql`
- CHECK `statut IN ('A_COMPLETER', 'COMPLETE')`.
- CHECK format `nom_table = schema.table`.
- FK `id_agent_incomplet -> public.utilisateur(id_user)`.
- FK `id_agent_completement -> public.utilisateur(id_user)`.
- Index conserve/assures:
  - `(nom_table, id_objet)`
  - `statut`
  - `date_signalement DESC`
  - `date_completion DESC`
- Index unique partiel:
  - une seule ligne `A_COMPLETER` par `(nom_table, id_objet)`.
- Trigger d'audit ajoute:
  - `trg_audit_objet_incomplet`
  - fonction `public.capture_historique_attribut('id_incomplet')`.

Verification:

- Structure, contraintes, index et triggers `public.objet_incomplet` identiques entre `SRM` et `SRM_bureau`.
- Nombre de lignes: 0 dans les deux bases.
- Test API rollback:
  - creation `A_COMPLETER`: HTTP 201;
  - deuxieme signalement du meme objet: HTTP 200, pas de doublon ouvert;
  - completion: HTTP 200, `A_COMPLETER` devient `COMPLETE`.
- `python manage.py check`: OK.
- `dart format` via wrapper Codex: OK.
- `flutter analyze` via wrapper Codex: termine sans blocage; uniquement des infos lint existantes.

### `public.spatial_ref_sys`

Statut: similaire, aucune modification necessaire.

Observation structure:

- Les deux bases ont la meme structure avec 5 colonnes:
  - `srid`
  - `auth_name`
  - `auth_srid`
  - `srtext`
  - `proj4text`

Observation contenu:

- `SRM`: 8500 lignes.
- `SRM_bureau`: 8500 lignes.
- Checksum identique sur les deux bases.

Decision:

- Ne pas modifier.
- C'est une table de reference PostGIS, pas une table metier.

Verification:

- Structure identique: oui.
- Nombre de lignes identique: oui.
- Contenu identique: oui.
- Modification `SRM_bureau`: aucune.

### `public.utilisateur`

Statut: structure alignee et contenus unifies.

Observation structure:

- `SRM.public.utilisateur`: 10 colonnes
  - `id_user`
  - `login`
  - `mot_de_passe`
  - `nom_prenom`
  - `actif`
  - `date_creation`
  - `dernier_login`
  - `nb_objets_collectes_total`
  - `id_projet_actif`
  - `role`
- `SRM_bureau.public.utilisateur`: 11 colonnes
  - `id_user`
  - `login`
  - `mot_de_passe_hash`
  - `nom_prenom`
  - `actif`
  - `date_creation`
  - `dernier_login`
  - `nb_objets_collectes_total`
  - `id_projet_actif`
  - `role`
  - `is_deleted`

Observation contenu:

- `SRM`: 3 utilisateurs.
- `SRM_bureau`: 8 utilisateurs.
- Les deux bases utilisent `id_user` comme PK et `login` comme unique.
- `SRM` a une FK `id_projet_actif -> public.projet(id_projet)`.
- `SRM_bureau` n'a pas cette FK.

Usages applicatifs constates:

- Backend Django:
  - modele `Utilisateur`.
  - endpoint `/api/login/`.
  - le login lit actuellement `user.mot_de_passe`.
  - verification via `check_password`, donc la valeur doit etre un hash Django (`argon2`, `pbkdf2`, `bcrypt`).
  - mise a jour de `dernier_login`.
  - controle de `actif` et `role`.
- Flutter:
  - envoie `{ login, mot_de_passe }` a `/api/login/`.
  - consomme `id_user`, `role`, `id_projet_actif`.
  - garde un cache local `utilisateur_local`.

Mismatch principal:

- Nom du champ mot de passe:
  - `SRM`: `mot_de_passe`
  - `SRM_bureau`: `mot_de_passe_hash`
- Suppression logique:
  - uniquement dans `SRM_bureau`: `is_deleted`.

Decision retenue:

- Structure cible: garder la structure `SRM_bureau`, car elle est plus explicite:
  - `mot_de_passe_hash` clarifie que le mot de passe stocke est hashe.
  - `is_deleted` permet la suppression logique.
- Supprimer la FK `id_projet_actif -> public.projet(id_projet)`.
- Adapter le backend:
  - modele `Utilisateur`: remplacer `mot_de_passe` par `mot_de_passe_hash`, ajouter `is_deleted`.
  - login: verifier `user.mot_de_passe_hash`.
  - login: refuser aussi `is_deleted = true`.
  - serializer: ne pas exposer le hash dans les reponses API.

Modifications effectuees:

- `SRM.public.utilisateur`:
  - sauvegarde creee: `public.utilisateur_backup_before_srm_bureau_structure_20260501`.
  - FK `utilisateur_id_projet_actif_fkey` supprimee.
  - colonne `mot_de_passe` renommee en `mot_de_passe_hash`.
  - colonne `is_deleted boolean default false` ajoutee.
  - contrainte `utilisateur_role_check` elargie pour accepter les roles des deux bases:
    - `admin`
    - `project_manager`
    - `editeur_terrain`
    - `editeur_bureau`
    - `viewer_mobile`
    - `viewer`
    - `superadmin`
    - `exploitant_srm`
- `SRM_bureau.public.utilisateur`:
  - sauvegarde creee: `public.utilisateur_backup_before_union_20260501`.
- Fusion du contenu:
  - les comptes de `SRM_bureau` absents de `SRM` ont ete ajoutes dans `SRM`.
  - les comptes de `SRM` absents de `SRM_bureau` ont ete ajoutes dans `SRM_bureau`.
  - la fusion s'est faite par `login`, pas par `id_user`, pour eviter les collisions d'identifiants.
- Backend Django:
  - modele `Utilisateur` aligne sur `mot_de_passe_hash` et `is_deleted`.
  - `login_view` utilise `mot_de_passe_hash`.
  - `login_view` refuse `is_deleted = true`.
  - `UtilisateurSerializer` exclut `mot_de_passe_hash`.

Verification:

- Mismatch structure: confirme.
- Mismatch contenu: confirme.
- Structure finale identique dans les deux bases: oui.
- Les deux bases contiennent le meme ensemble de 11 logins:
  - `abdelhak`
  - `anas`
  - `anasd@etafat.ma`
  - `badr`
  - `driss`
  - `exploitant`
  - `fouad`
  - `hakim`
  - `nada`
  - `salma`
  - `yassine`
- FK `id_projet_actif`: absente dans les deux bases.
- `manage.py check`: OK.
- `UtilisateurSerializer`: ne contient pas `mot_de_passe_hash`.

Mise a jour mots de passe:

- Un hash Argon2 a ete genere avec:
  - `python manage.py generate_srm_password_hash "MonMotDePasse"`
- Le hash genere a ete applique dans `SRM` et `SRM_bureau` sur `mot_de_passe_hash` pour:
  - `yassine`
  - `fouad`
  - `abdelhak`
  - `badr`
  - `hakim`
  - `driss`
  - `salma`
  - `exploitant`
- Verification:
  - 8 lignes mises a jour dans `SRM`.
  - 8 lignes mises a jour dans `SRM_bureau`.
  - les 8 comptes ont bien un hash `argon2`.

### Nettoyage tables intermediaires `liste_choix`

Statut: supprimees de `SRM_bureau`.

Tables confirmees comme intermediaires/backups:

- `liste_choix_backup_avant_defaut_choix_20260428_1349`
- `liste_choix_backup_avant_eclatement_20260428_134013`
- `liste_choix_backup_avant_ep_regard_maj2_20260428_1425`
- `liste_choix_backup_avant_ep_regard_maj3_20260428_1438`
- `liste_choix_backup_avant_ep_regard_maj_20260428_1415`
- `liste_choix_backup_avant_ep_regard_nouveaux_champs_20260428_151`
- `liste_choix_backup_avant_ep_regard_ordre_20260428_1447`
- `liste_choix_backup_avant_ep_regard_ordre_front_20260428_1455`
- `liste_choix_backup_avant_split_20260430_194633`
- `liste_choix_old_20260430_194633`

Verification avant suppression:

- Les 10 tables existaient dans `SRM_bureau`.
- Aucune dependance de vue detectee.
- Aucune contrainte entrante/sortante detectee.

Modification:

- Les 10 tables ont ete supprimees de `SRM_bureau`.

Verification apres suppression:

- Aucune des 10 tables ne reste dans `SRM_bureau.public`.

### Nettoyage accents / mojibake

Statut: verifie et nettoye sur `SRM` et `SRM_bureau`.

Perimetre:

- Scan des colonnes texte des tables physiques des deux bases.
- Motifs recherches:
  - caractere de remplacement `�`
  - prefixes mojibake `Ã`, `Â`, `â€`
  - prefixes frequents d'arabe mal decode `Ø`, `Ù`

Resultat du scan mojibake:

- `SRM`: aucun cas.
- `SRM_bureau`: aucun cas.
- Encodage serveur/client verifie: `UTF8`.

Residus `?` detectes puis corriges:

- `SRM.ep.vanne`
  - `fid = 321`
  - `ep_etat`: `.?` -> `NULL`
- `SRM.public.historique_attribut`
  - `id_historique = 6952`
  - `nouvelle_valeur`: `.?` -> `NULL`
- `SRM.public.historique_attribut`
  - `id_historique = 7574`
  - `ancienne_valeur`: `.?` -> `NULL`
- `SRM.public.historique_mobile`
  - `id_historique_mobile = 6962`
  - `nouvelle_valeur`: `.?` -> `NULL`
- `SRM.public.historique_mobile`
  - `id_historique_mobile = 13499`
  - `nouvelle_valeur`: `.?` -> `NULL`
- `SRM_bureau.ep.ep_regard`
  - `fid = 105`
  - `ep_observation`: `Puisard construit côte haut ??` -> `Puisard construit côte haut`
- `SRM_bureau.ep.onep_db`
  - `id = 7902`
  - `adresse postale client payeur`: `ISLY null APP 19? IMM K CITE DU 6°G.M.` -> `ISLY null APP 19 IMM K CITE DU 6°G.M.`

Verification apres correction:

- Aucun motif mojibake restant dans les deux bases.
- Aucun `?` restant dans les colonnes texte scannees des tables physiques des deux bases.
- Traces detaillees:
  - `docs/accent_mojibake_true_scan_2026-05-04.json`
  - `docs/accent_cleanup_changes_2026-05-04.json`
  - `docs/accent_final_scan_2026-05-04.json`

### Passage rapide tables communes

Statut: controle effectue entre `SRM` et `SRM_bureau`.

Perimetre:

- Tables physiques communes par nom qualifie `schema.table`.
- Comparaison structure:
  - colonnes
  - types
  - nullabilite
  - defaults
  - contraintes
  - index
- Comparaison contenu:
  - nombre de lignes
  - empreinte hash order-independent des lignes

Synthese:

- Tables communes detectees: 9.
- Tables uniquement dans `SRM`: 61.
- Tables uniquement dans `SRM_bureau`: 67.
- Mismatches structure: 5.
- Mismatches contenu: 5.

Tables communes OK structure + contenu:

- `public.objet_incomplet`
- `public.spatial_ref_sys`
- `public.zone`

Tables communes a regarder:

- `ep.borne_onep`
  - structure differente.
  - contenu different: `SRM` = 2 lignes, `SRM_bureau` = 0 ligne.
- `ep.centre_tampon`
  - structure differente.
  - contenu different: `SRM` = 946 lignes, `SRM_bureau` = 0 ligne.
- `public.commune`
  - structure presque identique mais `SRM_bureau` garde une FK vers `province`.
  - contenu different attendu: `SRM` = 11 communes Oujda, `SRM_bureau` = 1505 communes.
- `public.objet_incomplet_backup_before_common_structure_20260501`
  - backup technique, structure differente, contenu vide des deux cotes.
- `public.utilisateur`
  - structure differente seulement sur la contrainte `role`.
  - contenu different malgre 11 lignes de chaque cote.
  - verification par `login`: les hashes `mot_de_passe_hash` sont identiques dans les deux bases.
  - le mismatch contenu vient principalement des `id_user` differents entre les deux bases.
  - Etat apres remappage global des `id_user`: contenu identique; seule la contrainte `role` reste differente.
- `public.zone_utilisateur`
  - structure identique.
  - contenu different avec 23 lignes de chaque cote si on compare les `id_user` bruts.
  - contenu logique identique si on compare par `login + id_zone + actif`.
  - l'ecart est attendu car les `id_user` ont ete remappes par `login` dans `SRM`.
  - Etat apres remappage global des `id_user`: contenu brut identique.

Traces detaillees:

- `docs/common_tables_compare_2026-05-04.md`
- `docs/common_tables_compare_2026-05-04.json`

### Nettoyage backup `objet_incomplet_backup_before_common_structure_20260501`

Statut: supprimee des deux bases.

Verification avant suppression:

- `SRM.public.objet_incomplet_backup_before_common_structure_20260501`: existait avec 0 ligne.
- `SRM_bureau.public.objet_incomplet_backup_before_common_structure_20260501`: existait avec 0 ligne.

Modification:

- `DROP TABLE public.objet_incomplet_backup_before_common_structure_20260501` dans `SRM`.
- `DROP TABLE public.objet_incomplet_backup_before_common_structure_20260501` dans `SRM_bureau`.

Verification apres suppression:

- La table backup n'existe plus dans `SRM.public`.
- La table backup n'existe plus dans `SRM_bureau.public`.

### Fusion `zone_utilisateur` avec priorite `SRM_bureau`

Statut: applique sur `SRM`.

Clarification:

- `public.utilisateur` n'a pas de colonne `uuid`.
- Le champ different entre les deux bases est `id_user`.
- Les `mot_de_passe_hash` sont identiques par `login`.
- Les differences de hash global de table venaient des `id_user` differents, pas d'Argon2.

Strategie:

- `SRM_bureau.public.zone_utilisateur` est la source de verite.
- Les affectations sont reprises dans `SRM.public.zone_utilisateur`.
- Les `id_user` de `SRM_bureau` sont traduits par:
  - `SRM_bureau.zone_utilisateur.id_user`
  - `SRM_bureau.utilisateur.login`
  - `SRM.utilisateur.id_user`

Modification:

- Sauvegarde creee dans `SRM`:
  - `public.zone_utilisateur_backup_before_srm_bureau_priority_20260504`
- Remplacement du contenu de `SRM.public.zone_utilisateur`.
- 23 affectations inserees depuis `SRM_bureau`.
- Sequence `public.zone_utilisateur_id_seq` remise a jour.

Verification:

- `SRM.public.zone_utilisateur`: 23 lignes.
- `SRM_bureau.public.zone_utilisateur`: 23 lignes.
- Comparaison logique `id + id_zone + login + actif + date_affectation`: identique.
- Point remplace par le remappage global ci-dessous: les `id_user` sont maintenant homogenises entre les deux bases.

### Homogeneisation des `id_user` utilisateur

Statut: applique sur `SRM` et `SRM_bureau`.

Decision:

- Les comptes provenant de `SRM` gardent leur `id_user`:
  - `nada` = 2
  - `anas` = 3
  - `anasd@etafat.ma` = 4
- Pour liberer le `2`, `yassine` est deplace vers un nouvel identifiant commun:
  - `yassine` = 20
- Les autres comptes bureau gardent les identifiants bureau:
  - `fouad` = 7
  - `abdelhak` = 8
  - `badr` = 10
  - `hakim` = 13
  - `driss` = 14
  - `salma` = 15
  - `exploitant` = 16

Modifications appliquees:

- `SRM.public.utilisateur`:
  - `yassine`: 6 -> 20
  - `badr`: 9 -> 10
  - `hakim`: 10 -> 13
  - `driss`: 11 -> 14
  - `salma`: 12 -> 15
  - `exploitant`: 13 -> 16
- `SRM_bureau.public.utilisateur`:
  - `yassine`: 2 -> 20
  - `nada`: 17 -> 2
  - `anas`: 18 -> 3
  - `anasd@etafat.ma`: 19 -> 4

Propagation:

- Les references FK vers `public.utilisateur` ont ete mises a jour.
- Les colonnes metier de type utilisateur ont aussi ete traitees:
  - `id_user`
  - `id_user_*`
  - `id_agent_incomplet`
  - `id_agent_completement`
- Dans `SRM`, 40 colonnes FK et 51 colonnes utilisateur potentielles ont ete controlees.
- Dans `SRM_bureau`, 98 colonnes FK et 179 colonnes utilisateur potentielles ont ete controlees.

Sauvegardes creees:

- `public.utilisateur_backup_before_user_id_homog_20260504`
- `public.zone_utilisateur_backup_before_user_id_homog_20260504`
- `public.utilisateur_id_homog_20260504`

Verification:

- `SRM.public.utilisateur`: 11 lignes, `max(id_user)` = 20.
- `SRM_bureau.public.utilisateur`: 11 lignes, `max(id_user)` = 20.
- Les sequences `public.utilisateur_id_user_seq` sont recalees a 20 dans les deux bases.
- Le contenu de `public.utilisateur` est identique entre `SRM` et `SRM_bureau`.
- Le contenu de `public.zone_utilisateur` est identique entre `SRM` et `SRM_bureau` avec 23 lignes de chaque cote.
- Point restant cote structure: la contrainte `utilisateur_role_check` reste differente entre les deux bases.
- Aucune reference FK orpheline vers `public.utilisateur` apres remappage.

### Note sur la contrainte `role`

Statut: ecart conserve.

Constat:

- Les valeurs `role` actuellement presentes dans les deux bases sont identiques:
  - `admin`
  - `editeur_terrain`
  - `editeur_bureau`
  - `viewer`
  - `superadmin`
  - `exploitant_srm`
- La contrainte `SRM.public.utilisateur.utilisateur_role_check` accepte en plus:
  - `project_manager`
- La contrainte cote `SRM_bureau` n'accepte pas `project_manager`.

Decision:

- L'ecart est conserve car `project_manager` correspond a un role applicatif cote projet/web.
- Aucun compte actuel n'utilise `project_manager`.

Impact mobile:

- Le backend mobile verifie explicitement les roles autorises au login:
  - `admin`
  - `project_manager`
  - `editeur_terrain`
  - `editeur_bureau`
  - `superadmin`
- Le mobile recupere ensuite le `role` pour le cache local et l'affichage du profil.
- La difference de contrainte DB n'affecte donc pas le mobile tant que les comptes mobiles restent sur les roles autorises.
- Les roles `viewer` et `exploitant_srm` existent dans la table mais ne sont pas autorises par le `login_view` mobile.

### Placeholder mobile `intervention_anomalie`

Statut: applique sur `SRM_bureau`.

Decision:

- La table metier `public.intervention_anomalie` n'a pas ete modifiee.
- Un placeholder de configuration a ete ajoute dans:
  - `public.attribut_config_mobile`
  - `public.liste_choix`
- `nom_metier` est utilise comme nom du schema.
- Pour cette table, la valeur retenue est donc:
  - `nom_metier = 'public'`
  - `nom_table = 'intervention_anomalie'`

Ajouts dans `public.attribut_config_mobile`:

- 20 champs ajoutes, IDs `2095` a `2114`.
- Tous les champs sont en `visible = false` pour eviter toute exposition applicative tant que le workflow n'est pas fixe.
- Les FK utilisateur sont referencees vers `public.utilisateur.id_user`:
  - `id_user_exploitant`
  - `id_user_terrain`
  - `id_user_bureau`

Ajouts dans `public.liste_choix`:

- 10 choix ajoutes, IDs `1849` a `1858`.
- Les choix sont limites aux valeurs observees ou aux defaults existants, sans valeurs fictives:
  - `retour_terrain`: `false`, `true`
  - `statut`: `signale`, `exploitant_traite`
  - `responsable_actuel`: `exploitant`, `terrain`
  - `etat_exploitant`: `en_attente`, `traite`
  - `etat_terrain`: `en_attente`
  - `etat_bureau`: `en_attente`

Colonnes ambigues:

- `id_objet`: reference dynamique vers un objet metier, dependante de `nom_classe`; pas de FK directe declaree dans `attribut_config_mobile`.
- `nom_classe`: aucune liste de choix ajoutee; la valeur observee est `ep_regard`, mais la figer comme choix serait trop restrictif pour un placeholder.

Verification:

- `SRM_bureau.public.attribut_config_mobile`: 20 lignes pour `public.intervention_anomalie`.
- `SRM_bureau.public.liste_choix`: 10 lignes pour `public.intervention_anomalie`.
- Aucun `?` introduit dans les alias ou valeurs de ces choix.

### Flux de synchronisation mobile

Statut: structure gelee et appliquee sur `SRM` et `SRM_bureau`.

Tables concernees:

- `public.sync_session`
- `public.sync_session_item`
- `public.sync_session_attachment`

Etat avant application:

- Les trois tables existaient dans `SRM`.
- Les trois tables etaient absentes de `SRM_bureau`.
- La structure initiale venait de la migration Django `0006_sync_manifest_log.py`.
- Donnees presentes dans `SRM` avant gel:
  - `sync_session`: 1 ligne.
  - `sync_session_item`: 1 ligne.
  - `sync_session_attachment`: 0 ligne.

Flux applicatif:

1. Le mobile collecte les lignes locales non synchronisees.
2. Le mobile cree un manifeste via `POST /api/sync/manifest/`.
3. Le serveur cree ou met a jour une ligne `sync_session`.
4. Le serveur cree les lignes attendues dans:
   - `sync_session_item` pour les objets metier.
   - `sync_session_attachment` pour les photos.
5. Chaque POST objet mobile porte `_sync_session_uuid` et `_sync_client_item_uuid`.
6. Apres creation ou mise a jour de l'objet, le backend marque l'item comme `received`.
7. Chaque upload photo porte `sync_session_uuid`.
8. Apres upload photo, le backend marque l'attachment comme `received`.
9. Le backend recalcule les compteurs de `sync_session`.

Valeurs utilisees par le code:

- `sync_session.statut`:
  - `manifest_received`
  - `partial`
  - `completed`
- `sync_session_item.statut`:
  - `pending`
  - `received`
  - `validated`
  - `duplicate`
  - `rejected`
  - `failed`
- `sync_session_attachment.statut`:
  - `pending`
  - `received`
- `sync_session_item.operation`:
  - `upsert`
  - `validate`

Structure actuelle jugee saine:

- `sync_session.sync_uuid` est unique.
- `sync_session_item` reference `sync_session` avec `ON DELETE CASCADE`.
- `sync_session_attachment` reference `sync_session` avec `ON DELETE CASCADE`.
- Unicite item:
  - `(id_sync_session, nom_schema, nom_table, uuid_objet)`
- Unicite attachment:
  - `(id_sync_session, nom_schema, nom_table, uuid_objet, photo_slot)`
- Index utiles deja presents:
  - session par agent/statut/date.
  - item par session/statut et par objet.
  - attachment par session/statut et par objet/photo.

Points fixes:

- `id_agent` represente en pratique `public.utilisateur.id_user`.
  - Nom conserve recommande cote code, car le mobile et l'API utilisent deja `id_agent`.
  - Documente comme alias fonctionnel de `id_user`.
  - FK ajoutee vers `public.utilisateur(id_user)`.
- `id_projet` et `id_mission` restent sans FK pour l'instant.
  - Ces tables ne sont pas encore communes entre `SRM` et `SRM_bureau`.
- Contraintes de gel ajoutees:
  - `sync_session.statut in ('manifest_received', 'partial', 'completed', 'failed', 'cancelled')`
  - `sync_session_item.statut in ('pending', 'received', 'validated', 'duplicate', 'rejected', 'failed')`
  - `sync_session_attachment.statut in ('pending', 'received', 'rejected', 'failed')`
  - `sync_session_item.operation in ('upsert', 'validate', 'delete')`
  - `sync_session_attachment.photo_slot between 1 and 4`
  - compteurs et `attempts` superieurs ou egaux a 0

Application:

- `SRM_bureau`: creation des tables `sync_session`, `sync_session_item`, `sync_session_attachment`.
- `SRM`: renforcement des trois tables existantes.
- `SRM` et `SRM_bureau`: memes colonnes, memes contraintes, memes index.
- Script SQL ajoute:
  - `API_GeoDjango/sql/2026-05-04_sync_session_structure_freeze.sql`
- Migration Django ajoutee:
  - `API_GeoDjango/pprcollecte/api/migrations/0007_sync_manifest_constraints.py`

Verification apres application:

- `SRM.public.sync_session`: 1 ligne.
- `SRM.public.sync_session_item`: 1 ligne.
- `SRM.public.sync_session_attachment`: 0 ligne.
- `SRM_bureau.public.sync_session`: 0 ligne.
- `SRM_bureau.public.sync_session_item`: 0 ligne.
- `SRM_bureau.public.sync_session_attachment`: 0 ligne.
- Aucune reference orpheline `sync_session.id_agent`.
- Structure identique entre les deux bases pour:
  - colonnes
  - contraintes
  - index

### Table unique d'historicite

Statut: applique sur `SRM` et `SRM_bureau`.

Tables remplacees:

- `public.historique_action`
- `public.historique_attribut`
- `public.historique_mobile`

Decision:

- Une seule table active est conservee: `public.historique_action`.
- L'historique mobile detaille n'est pas migre, car il n'est pas utile pour la cible.
- Les donnees bureau existantes sont conservees.
- Pour `source = 'mobile'`, les actions autorisees sont limitees a:
  - `insert`
  - `update`
  - `validate`
- Pour `source = 'bureau'`, les actions restent libres pour garder la souplesse du back-office.

Structure gelee:

- `id serial primary key`
- `nom_table varchar(100) not null`
- `id_objet integer not null`
- `action varchar(50) not null`
- `source varchar(20) not null default 'bureau'`
- `id_user integer`
- `nom_user varchar(255)`
- `date_action timestamptz not null default now()`
- `old_data jsonb`
- `new_data jsonb`

Contraintes et index:

- `source in ('bureau', 'mobile')`
- `source <> 'mobile' OR lower(action) in ('insert', 'update', 'validate')`
- FK `id_user -> public.utilisateur(id_user)` avec `ON UPDATE CASCADE ON DELETE SET NULL`
- Index:
  - `(nom_table, id_objet, date_action desc)`
  - `(source, date_action desc)`
  - `(id_user, date_action desc)`

Application sur `SRM`:

- Creation de `public.historique_action` vide.
- Suppression des tables actives:
  - `public.historique_attribut`
  - `public.historique_mobile`
- Sauvegardes conservees:
  - `public.historique_attribut_backup_before_unified_20260504`: 7574 lignes.
  - `public.historique_mobile_backup_before_unified_20260504`: 15540 lignes.
- Les vues metriques ont ete regenerees pour lire `public.historique_action`.
- `vw_srm_historique_mobile_fact` a ensuite ete supprimee lors du nettoyage final des metriques; l'historique mobile passe uniquement par `public.historique_action`.
- Les triggers existants `trg_audit_*` sont conserves.
- La fonction `public.capture_historique_attribut()` est remplacee pour alimenter `public.historique_action`.
- Un test en transaction rollback confirme qu'un update sur `ep.planche` ajoute 1 ligne dans `public.historique_action`.

Application sur `SRM_bureau`:

- Les 84 lignes existantes de `public.historique_action` sont conservees.
- Sauvegarde creee:
  - `public.historique_action_backup_before_unified_20260504`: 84 lignes.
- Normalisation effectuee:
  - `source` normalisee vers `bureau` / `mobile`.
  - `nom_table` normalise au format `schema.table`.
  - Exemple: `"ep"."planche"` devient `ep.planche`.
- Aucun `id_user` orphelin detecte apres ajout de la FK.

Code applicatif:

- Modele Django actif: `HistoriqueAction`.
- Serializer actif: `HistoriqueActionSerializer`.
- Endpoint actif: `/api/historique-actions/`, lecture de la table unifiee.
- Endpoints retires:
  - `/api/historique/`
  - `/api/historique-mobile/`
  - `/api/historique-mobile/upload/`
- Upload d'historique mobile separe: supprime. Le mobile ne pousse plus de journal historique local distinct.

Scripts:

- Script de reference ajoute:
  - `API_GeoDjango/sql/2026-05-04_historique_action_unified.sql`
- Scripts anciens marques obsoletes:
  - `API_GeoDjango/sql/2026-04-13_historique_attribut_audit.sql`
  - `API_GeoDjango/sql/2026-04-14_historique_mobile_journal.sql`: tombstone qui sauvegarde si besoin puis droppe `public.historique_mobile`.

Verification apres application:

- Structure `public.historique_action` identique entre `SRM` et `SRM_bureau`:
  - colonnes
  - contraintes
  - index
- `SRM.public.historique_action`: 0 ligne.
- `SRM_bureau.public.historique_action`: 84 lignes.
- `SRM_bureau.public.historique_action.source`: 84 lignes `bureau`.
- Actions observees cote `SRM_bureau`:
  - `delete`: 3
  - `insert`: 29
  - `traitement`: 30
  - `update`: 13
  - `validate`: 9
- Aucun `nom_table` avec guillemets residuels.
- Aucun `id_user` orphelin.

## Decommissionnement `public.projet` et `public.mission` - 2026-05-04

Objectif:

- Retirer les tables `public.projet` et `public.mission` du modele applicatif et des deux bases.
- Supprimer les usages et affichages projet/mission cote backend Django et application mobile.

Application cote code:

- Backend:
  - Suppression des serializers, viewsets et routes `/api/projets/`, `/api/missions/`.
  - Suppression des viewsets metriques projet.
  - `login_view` ne renvoie plus `id_projet_actif` ni `projet_actif`.
  - Les payloads de synchronisation et photo ne manipulent plus `id_projet` / `id_mission`.
  - Les champs `id_projet` / `id_mission` restent masques dans les serializers metier si les colonnes existent encore physiquement.
- Mobile:
  - Suppression du contexte `currentProjet*` / `currentMissionId`.
  - Suppression des appels API projets/missions.
  - Suppression des affichages projet/mission.
  - Suppression des caches SQLite `projet_local` / `mission_local` pour les nouvelles installations.
  - Nettoyage des payloads pour ignorer `id_projet` / `id_mission` avant envoi.

Application cote base:

- `SRM_bureau`:
  - `public.projet`: deja absent.
  - `public.mission`: deja absent.
- `SRM`:
  - 71 contraintes FK vers `public.projet` / `public.mission` supprimees.
  - `public.mission` supprimee.
  - `public.projet` supprimee.

Verification:

- `SRM`: `public.projet = absent`, `public.mission = absent`, `fk_refs = 0`.
- `SRM_bureau`: `public.projet = absent`, `public.mission = absent`, `fk_refs = 0`.
- Aucune vue publique active avec un nom contenant `projet` ou `mission` dans les deux bases.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

## `public.utilisateur` - separation nom / prenom - 2026-05-04

Decision:

- Remplacer le champ unique `nom_prenom` par deux champs explicites:
  - `nom varchar(200)`
  - `prenom varchar(200)`
- Appliquer la meme structure sur `SRM` et `SRM_bureau`.
- Le nom complet d'affichage est reconstruit applicativement avec `prenom || ' ' || nom`.

Application BD:

- Script ajoute:
  - `API_GeoDjango/sql/2026-05-04_utilisateur_nom_prenom_split.sql`
- Sauvegarde creee dans les deux bases:
  - `public.utilisateur_backup_before_nom_prenom_split_20260504`: 11 lignes.
- Migration appliquee sur `SRM` et `SRM_bureau`:
  - ajout de `nom`;
  - ajout de `prenom`;
  - reprise des anciennes valeurs de `nom_prenom` par separation au premier espace;
  - suppression de `nom_prenom` de la table active.
- Fonction d'audit mise a jour:
  - `public.capture_historique_attribut()` utilise maintenant `concat_ws(' ', prenom, nom)`.

Application code:

- Modele Django `Utilisateur` aligne sur `nom` / `prenom`.
- `login_view` renvoie:
  - `nom`
  - `prenom`
  - `nom_complet`
- `UtilisateurSerializer` continue d'exclure `mot_de_passe_hash`.
- Mobile Flutter:
  - `ApiService` lit `nom` / `prenom` et calcule le nom complet;
  - `utilisateur_local` cree les colonnes `nom` / `prenom`;
  - migration locale defensive depuis l'ancien `nom_prenom` si une base SQLite existante le contient encore;
  - affichages profil/home/offline bases sur le nom complet reconstruit.

Verification:

- `SRM.public.utilisateur` et `SRM_bureau.public.utilisateur` ont les memes colonnes actives.
- La difference connue de contrainte `utilisateur_role_check` reste inchangee et documentee: elle concerne les profils web/bureau, sans impact sur le login mobile tant que les roles mobiles autorises restent presents.
- `nom_prenom` n'existe plus sur `public.utilisateur` actif dans les deux bases.
- Aucune vue/fonction active ne reference `nom_prenom`.
- References restantes a `nom_prenom`: uniquement tables de backup et migration locale defensive Flutter.
- `python manage.py check` avec `srmenv`: OK, 0 issue.
- `dart format` via wrapper Codex: OK.
- `flutter analyze` via wrapper Codex: termine sans blocage; uniquement des infos lint existantes.

Corrections metier appliquees apres separation automatique:

- `abdelhak`: `prenom = Abdelhak`, `nom = Boutrak`.
- `badr`: `prenom = Badr`, `nom = Elguareh`.
- Verification post-correction: les lignes `abdelhak` et `badr` sont identiques entre `SRM` et `SRM_bureau`.
- `flutter analyze`: aucune erreur bloquante; uniquement des infos existantes (`avoid_print`, deprecations, `prefer_const`, etc.).

Scripts:

- `API_GeoDjango/sql/2026-04-14_metrics_dashboard_views.sql` remplace par un script no-op/tombstone qui droppe seulement les anciennes vues projet/mission si elles existent.
- `API_GeoDjango/sql/2026-05-04_historique_action_unified.sql` contient deja les `DROP VIEW IF EXISTS` des anciennes vues projet/mission.

Suite - suppression physique des colonnes historiques:

- Colonnes supprimees dans `SRM`:
  - `id_projet`
  - `id_mission`
  - `id_projet_actif`
- Colonnes supprimees dans `SRM_bureau`:
  - `id_projet`
  - `id_mission`
  - `id_projet_actif`
- Perimetre:
  - tables metier actives
  - `public.objet_photo`
  - `public.sync_session`
  - `public.utilisateur`
  - tables de backup contenant encore `id_projet_actif`
- Les vues de faits et metriques ont ete regenerees sans contexte projet/mission:
  - `vw_srm_objet_fact`
  - `vw_srm_objet_dates`
  - `vw_srm_photo_fact`
  - `vw_srm_incomplet_fact`
  - `vw_srm_historique_fact`
  - `vw_srm_historique_mobile_fact`
  - `vw_metrics_agent_jour`
  - `vw_metrics_agent_semaine`
  - `vw_metrics_agent_mois`
  - `vw_metrics_agent_public_jour`
  - `vw_metrics_agent_public_semaine`
  - `vw_metrics_agent_public_mois`
  - `vw_metrics_agent_public_resume`

Verification apres suppression physique:

- `SRM`: 0 colonne restante nommee `id_projet`, `id_mission`, `id_projet_actif`.
- `SRM_bureau`: 0 colonne restante nommee `id_projet`, `id_mission`, `id_projet_actif`.
- Lecture des 13 vues regenerees: OK sur les deux bases.
- Volumetrie de controle:
  - `SRM.vw_srm_objet_fact`: 7659 lignes.
  - `SRM_bureau.vw_srm_objet_fact`: 5145 lignes.
  - `SRM.vw_metrics_agent_public_resume`: 4 lignes.
  - `SRM_bureau.vw_metrics_agent_public_resume`: 3 lignes.
- `python manage.py check` avec `srmenv`: OK, 0 issue.
- Code Django:
  - champs `id_projet`, `id_mission`, `id_projet_actif` retires des modeles actifs.
  - logique de masquage serializer devenue inutile et retiree.
- Scripts:
  - `API_GeoDjango/sql/2026-04-14_metrics_collecte_views.sql` marque obsolete/no-op car l'ancien script dependait de `id_projet/id_mission`.
  - `API_GeoDjango/sql/2026-05-04_sync_session_structure_freeze.sql` aligne sur la structure sans `id_projet/id_mission`.

## Statistiques de conduite EP/ASS - 2026-05-04

Objectif:

- Homogeneiser le stockage des conduites dessinees par regards.
- Remplacer les noms provisoires/legacy par deux tables metier:
  - `ep.statistique_conduite`
  - `ep.statistique_conduite_segment`
  - `ass.statistique_conduite`
  - `ass.statistique_conduite_segment`

Decision:

- Le nom de table reste identique entre les metiers.
- Le schema porte le metier: `ep` pour eau potable, `ass` pour assainissement.
- Les endpoints mobiles restent inchanges:
  - `/api/statistiques-conduite/jour/`
  - `/api/statistiques-conduite/valider/`
- `metier=ep` cible `ep.statistique_conduite`.
- `metier=ass` ou `metier=asst` cible `ass.statistique_conduite`.
- Une valeur absente ou `legacy` est redirigee vers `ep` pour compatibilite.

Structure appliquee sur les deux bases:

- Table principale:
  - `id_statistique_conduite` bigint auto-incremente, PK.
  - `id_agent` integer, FK vers `public.utilisateur(id_user)`.
  - `jour` date.
  - `geom` `MultiLineStringZ, 26191`.
  - `longueur_conduite_m` double precision, `>= 0`.
  - `created_at`, `updated_at`.
  - unicite `(id_agent, jour)` par metier.
- Table segment:
  - `id_statistique_conduite_segment` bigint auto-incremente, PK.
  - `id_statistique_conduite` FK vers la table principale du meme schema.
  - `fid_regard_a`, `fid_regard_b`: ordre reel du dessin.
  - `fid_regard_min`, `fid_regard_max`: paire normalisee pour empecher les doublons A-B / B-A.
  - `geom` `LineStringZ, 26191`.
  - `longueur_segment_m` double precision, `>= 0`.
  - unicite `(id_statistique_conduite, fid_regard_min, fid_regard_max)`.

Application cote base:

- `SRM`:
  - anciennes tables publiques vides supprimees:
    - `public.statistique_conduite`
    - `public.statistique_conduite_segment`
  - tables finales creees sous `ep` et `ass`.
- `SRM_bureau`:
  - tables finales creees sous `ep` et `ass`.

Application cote code:

- Modeles Django actifs:
  - `EpStatistiqueConduite`
  - `EpStatistiqueConduiteSegment`
  - `AssStatistiqueConduite`
  - `AssStatistiqueConduiteSegment`
- La configuration backend de validation/snapshot conduit vers les schemas `ep` et `ass`.
- Le manifeste de synchronisation mobile envoie maintenant:
  - `nom_schema = ep|ass`
  - `nom_table = statistique_conduite`

Scripts:

- Ancien script public marque obsolete:
  - `API_GeoDjango/sql/2026-04-23_public_statistique_conduite.sql`
- Script de reference ajoute:
  - `API_GeoDjango/sql/2026-05-04_statistique_conduite_ep_ass.sql`

Verification:

- `SRM` et `SRM_bureau`:
  - `ep.statistique_conduite`: 7 colonnes, 0 ligne.
  - `ep.statistique_conduite_segment`: 10 colonnes, 0 ligne.
  - `ass.statistique_conduite`: 7 colonnes, 0 ligne.
  - `ass.statistique_conduite_segment`: 10 colonnes, 0 ligne.
- Anciennes tables publiques/provisoires: 0 restante.
- Structure normalisee identique entre `SRM` et `SRM_bureau`.
- Seuls les noms internes de contraintes `NOT NULL` generes par PostgreSQL/PostGIS different; la definition structurelle est identique.
- Tests backend:
  - `python manage.py check` avec `srmenv`: OK, 0 issue.
  - Lecture endpoint jour OK pour `ep`, `ass`, `legacy` et metier absent.

## Centralisation `public.objet_photo` - 2026-05-04

Objectif:

- Centraliser la gestion photo dans `public.objet_photo`.
- Ne plus utiliser les colonnes metier `photo_1` a `photo_4` comme source serveur.
- Utiliser `public.objet_photo` comme table centrale des photos uploadees ou deja referencees.

Constat avant application:

- `SRM` contenait deja `public.objet_photo` avec 15 lignes.
- `SRM_bureau` ne contenait pas `public.objet_photo`.
- `SRM_bureau` portait les anciennes references photo directement dans les tables metier.
- Les seules references photo remplies trouvees dans `SRM_bureau` etaient sur `ep.ep_regard`:
  - `photo_1`: 1307 valeurs.
  - `photo_2`: 1274 valeurs.
  - `photo_3`: 892 valeurs.
  - `photo_4`: 689 valeurs.
- La colonne `ep.ep_regard.ep_photo` contient aussi 915 valeurs, mais elle n'a pas ete migree: son contenu ressemble plutot a une ancienne reference/codification qu'a un chemin fichier homogene.

Application sur `SRM_bureau`:

- Creation de `public.objet_photo` avec la structure SRM:
  - `id_photo`
  - `uuid_objet`
  - `nom_schema`
  - `nom_table`
  - `num_photo`
  - `nom_fichier`
  - `chemin_relatif`
  - `hash_sha256`
  - `mime_type`
  - `taille_octets`
  - `id_agent_crea`
  - `date_upload`
  - `actif`
  - `date_prise_reelle`
- Contraintes appliquees:
  - PK sur `id_photo`.
  - `CHECK (num_photo BETWEEN 1 AND 4)`.
  - unicite `(nom_schema, nom_table, uuid_objet, num_photo)`.
- Index ajoutes:
  - `uuid_objet`.
  - `(nom_schema, nom_table, uuid_objet)`.
  - `date_upload`.
  - `date_prise_reelle` quand renseignee.

Migration effectuee:

- Source: `SRM_bureau.ep.ep_regard.photo_1` a `photo_4`.
- Cible:
  - `nom_schema = 'ep'`
  - `nom_table = 'ep_regard'`
  - `uuid_objet = ep.ep_regard.uuid`
  - `num_photo = 1..4`
  - `chemin_relatif = valeur photo source`
  - `nom_fichier = nom de fichier extrait du chemin`
  - `id_agent_crea = ep.ep_regard.id_user_creat`
  - `date_upload = COALESCE(date_modif, date_creation, now())`
- Les colonnes source `photo_1` a `photo_4` ont ensuite ete sauvegardees puis videes.

Verification:

- `SRM.public.objet_photo`: 99 lignes apres migration complete et nettoyage des orphelins.
- `SRM_bureau.public.objet_photo`: 4162 lignes.
- Repartition:
  - `num_photo=1`: 1307 lignes.
  - `num_photo=2`: 1274 lignes.
  - `num_photo=3`: 892 lignes.
  - `num_photo=4`: 689 lignes.
- Doublons `(nom_schema, nom_table, uuid_objet, num_photo)`: 0.
- Lignes sans chemin ou nom de fichier: 0.
- `public.vw_srm_photo_fact` remplacee pour lire `public.objet_photo`.
- `SRM_bureau.public.vw_srm_photo_fact`: 4162 lignes.
- Photos orphelines dans la vue, sans jointure vers `vw_srm_objet_fact`: 0.
- Structure fonctionnelle de `public.objet_photo` identique entre `SRM` et `SRM_bureau`.
- References actives restantes dans les colonnes metier `photo_1` a `photo_4`: 0 dans les deux bases.
- References actives restantes dans les colonnes legacy de type `*_photo`: 0 dans les deux bases.
- Sauvegardes creees:
  - `public.objet_photo_source_column_backup_20260504`
    - `SRM`: 99 lignes.
    - `SRM_bureau`: 4162 lignes.
  - `public.objet_photo_legacy_reference_backup_20260504`
    - `SRM`: 0 ligne.
    - `SRM_bureau`: 915 lignes issues de `ep.ep_regard.ep_photo`.
- `ep.ep_regard.ep_photo` n'a pas ete inseree dans `objet_photo`: ses valeurs sont des references legacy de type `./1014R1`, sans extension fichier ni slot photo exploitable.
- Une ancienne ligne orpheline `elec.support` a ete supprimee de `SRM.public.objet_photo`, car le projet ne conserve plus le schema electricite.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

Application cote code:

- `photo_upload_view` n'ecrit plus dans les colonnes metier `photo_1` a `photo_4`.
- Les uploads creent/mettent a jour uniquement `public.objet_photo`.
- Les serializers metier n'acceptent plus de valeurs directes `photo_1` a `photo_4`; ils demandent `/api/photos/upload/`.
- Les serializers metier n'exposent plus `photo_1` a `photo_4` en lecture.
- Route de lecture centralisee ajoutee:
  - `/api/objets-photos/`
  - filtres: `nom_schema`, `nom_table`, `uuid_objet`.

Script:

- Script de reference ajoute:
  - `API_GeoDjango/sql/2026-05-04_objet_photo_centralisation.sql`

## Durcissement `intervention_anomalie` / `intervention_log` - 2026-05-04

Objectif:

- Garder `public.intervention_anomalie` comme table metier des anomalies d'intervention.
- Garder `public.intervention_log` comme journal append-only des changements d'etat.
- Faire en sorte que le log soit alimente automatiquement par la base, et non seulement par la couche applicative.
- Aligner la structure sur `SRM` et `SRM_bureau`.

Constat initial:

- `SRM`: tables absentes.
- `SRM_bureau`:
  - `public.intervention_anomalie`: 329 lignes.
  - `public.intervention_log`: 11 lignes.
- Aucun trigger PostgreSQL ne reliait les deux tables.
- 319 interventions n'avaient pas de log initial.
- Les statuts observes etaient principalement:
  - `signale`
  - `exploitant_traite`

Application:

- Creation/alignment des deux tables dans `SRM` et `SRM_bureau`.
- Ajout des colonnes de consolidation:
  - `nom_table`: format `schema.table`.
  - `uuid_objet`: identifiant stable de l'objet concerne quand disponible.
  - `created_at`
  - `updated_at`
- Normalisation de `ep_regard` vers `ep.ep_regard`.
- Backfill de `uuid_objet` depuis `ep.ep_regard.uuid` dans `SRM_bureau`.
- Remplacement de l'unicite globale historique par une unicite partielle:
  - `(nom_table, id_objet)` unique seulement pour les interventions non cloturees/non annulees.
- Ajout de contraintes `CHECK` sur:
  - `statut`
  - `responsable_actuel`
  - `etat_exploitant`
  - `etat_terrain`
  - `etat_bureau`
  - `intervention_log.action`
  - `intervention_log.de_statut`
  - `intervention_log.a_statut`
- Ajout d'index sur:
  - objet concerne
  - `nom_table, id_objet`
  - `uuid_objet`
  - responsable
  - statut
  - intervention/date du log
- Ajout des triggers:
  - `trg_intervention_anomalie_before_write`: normalisation, valeurs par defaut et transitions coherentes.
  - `trg_intervention_anomalie_after_write_log`: creation automatique du log sur insert/update.
  - `trg_intervention_log_prevent_update`: journal append-only, update/delete bloques sauf override explicite de maintenance.
- Backfill des logs manquants:
  - log initial `signale`.
  - log du statut courant quand il differe de `signale`.

Regles de workflow retenues:

- `signale`: responsable `exploitant`.
- `exploitant_traite`: responsable `terrain`, `etat_exploitant = traite`.
- `terrain_traite`: responsable `bureau`, `etat_terrain = traite`.
- `bureau_traite` ou `cloture`: responsable `cloture`, `etat_bureau = valide`, `date_cloture` renseignee si absente.
- `annule`: responsable `cloture`, `date_cloture` renseignee si absente.
- `retour_terrain`: responsable `terrain`, `retour_terrain = true`, `etat_bureau = a_corriger`.

Verification:

- Structure de `public.intervention_anomalie` identique entre `SRM` et `SRM_bureau`.
- Structure de `public.intervention_log` identique entre `SRM` et `SRM_bureau`.
- `SRM`:
  - `intervention_anomalie`: 0 ligne.
  - `intervention_log`: 0 ligne.
- `SRM_bureau`:
  - `intervention_anomalie`: 329 lignes.
  - `intervention_log`: 339 lignes.
- Interventions sans log initial `signale`: 0.
- Logs orphelins: 0.
- Mismatch entre dernier log chronologique et statut courant: 0.
- Test transactionnel rollback OK:
  - insertion d'une anomalie cree un log `signale`;
  - passage a `exploitant_traite` cree un log de transition;
  - modification directe de `intervention_log` bloquee.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

Sauvegardes:

- `public.intervention_anomalie_backup_before_hardening_20260504`
- `public.intervention_log_backup_before_hardening_20260504`

Script:

- Script de reference ajoute et rejoue avec succes sur les deux bases:
  - `API_GeoDjango/sql/2026-05-04_intervention_workflow_hardening.sql`

Point d'attention:

- Pour consulter le dernier etat journalise, trier `intervention_log` par `date_action DESC, id DESC`, et non par `id DESC` seul. Les logs initiaux ajoutes par backfill peuvent avoir ete inseres apres des transitions existantes tout en portant une date d'action plus ancienne.

## Raccord mobile `intervention_anomalie` terrain-only - 2026-05-04

Decision workflow:

- Apres signalement d'une anomalie, l'intervention devient visible cote terrain:
  - `statut = signale`
  - `responsable_actuel = terrain`
  - `etat_terrain = en_attente`
- Le mobile ne modifie que la partie terrain:
  - `etat_terrain`
  - `commentaire_terrain`
  - `id_user_terrain`
- Quand le terrain marque l'anomalie comme traitee:
  - `etat_terrain = traite`
  - `statut = terrain_traite`
  - `responsable_actuel = exploitant`
- La resolution finale/cloture reste cote exploitant/web.

Application cote base:

- Le script `API_GeoDjango/sql/2026-05-04_intervention_workflow_hardening.sql` a ete ajuste:
  - defaut `responsable_actuel = terrain`;
  - `signale` force `terrain/en_attente`;
  - `terrain_traite` renvoie vers `exploitant`;
  - `retour_terrain` renvoie vers `terrain/en_attente`.
- Backfill applique sur `SRM_bureau`:
  - `signale / terrain / en_attente`: 319 lignes.
  - `exploitant_traite / terrain / en_attente`: 10 lignes.
- Logs orphelins: 0.

Application cote backend:

- Modeles ajoutes:
  - `InterventionAnomalie`
  - `InterventionLog`
- Endpoint ajoute:
  - `/api/interventions-anomalies-terrain/`
- L'endpoint expose les anomalies actives affectees au terrain par defaut.
- L'endpoint refuse toute modification mobile hors colonnes terrain.
- Lorsqu'un objet metier est synchronise avec un flag anomalie (`anomalie` ou `ep_anomalie`), le backend cree/met a jour une ligne ouverte dans `public.intervention_anomalie`.
- Les colonnes exploitant/bureau ne sont pas exposées en ecriture mobile.

Application cote Flutter:

- Table SQLite locale ajoutee:
  - `intervention_anomalie`
- La table locale ne contient que le miroir utile au terrain, plus les colonnes de sync locale.
- Le telechargement mobile recupere les anomalies terrain via `/api/interventions-anomalies-terrain/`.
- La synchronisation mobile envoie seulement les updates terrain vers cet endpoint.
- Le manifeste de sync reference ces updates comme:
  - `nom_schema = public`
  - `nom_table = intervention_anomalie`
  - `operation = terrain_update`

Verification:

- `python manage.py check` avec `srmenv`: OK, 0 issue.
- Test API rollback OK:
  - creation d'un `ep.regard` avec `ep_anomalie = true` cree `public.intervention_anomalie`;
  - l'etat initial est `signale / terrain / en_attente`;
  - PATCH mobile `etat_terrain = traite` produit `terrain_traite / exploitant`;
  - PATCH mobile d'un champ exploitant est refuse avec HTTP 400.
- `flutter analyze` cible sur les 3 fichiers modifies:
  - pas d'erreur bloquante;
  - seulement des `info` deja presents principalement `avoid_print`, `recursive_getters`, `prefer_const_constructors`.

## Neutralisation Django admin/auth natif - 2026-05-04

Objectif:

- Supprimer les tables Django natives inutilisees par le workflow SRM.
- Eviter que le backend reclame encore `auth_user`, `auth_permission` ou l'admin Django.
- Conserver uniquement les hashers Django, car ils servent encore pour les mots de passe de `public.utilisateur`.

Constat pre-drop:

- `SRM_bureau`: tables deja absentes.
- `SRM`:
  - `api_login`: 0 ligne.
  - `auth_group`: 0 ligne.
  - `auth_group_permissions`: 0 ligne.
  - `auth_permission`: 124 lignes generees par Django.
  - `auth_user`: 0 ligne.
  - `auth_user_groups`: 0 ligne.
  - `auth_user_user_permissions`: 0 ligne.
  - `django_admin_log`: 0 ligne.
  - `django_session`: 0 ligne.
  - `django_content_type`: 31 lignes generees par Django.
- Aucune vue, fonction ou trigger ne reference ces tables.
- Le login applicatif utilise `public.utilisateur`, pas `auth_user`.

Application cote Django:

- Retire de `INSTALLED_APPS`:
  - `django.contrib.admin`
  - `django.contrib.auth`
  - `django.contrib.contenttypes`
  - `django.contrib.sessions`
  - `django.contrib.messages`
- Retire des middlewares:
  - `SessionMiddleware`
  - `AuthenticationMiddleware`
  - `MessageMiddleware`
- Retire les context processors auth/messages.
- Retire la route `/admin/`.
- Configure DRF sans authentification Django native:
  - `DEFAULT_AUTHENTICATION_CLASSES = []`
  - `UNAUTHENTICATED_USER = None`
- `AUTH_PASSWORD_VALIDATORS` vide, car la gestion des comptes passe par `public.utilisateur`.
- Les hashers restent disponibles:
  - `make_password`
  - `check_password`

Application cote base:

- Tables supprimees sur `SRM`; script rejoue sans effet sur `SRM_bureau`:
  - `public.django_admin_log`
  - `public.auth_user_user_permissions`
  - `public.auth_user_groups`
  - `public.auth_group_permissions`
  - `public.auth_permission`
  - `public.auth_group`
  - `public.auth_user`
  - `public.api_login`
  - `public.django_session`
  - `public.django_content_type`

Verification:

- Tables ci-dessus absentes dans `SRM` et `SRM_bureau`.
- FK restantes vers ces tables: 0.
- References code restantes a `django.contrib.auth`: uniquement les hashers (`make_password`, `check_password`).
- `python manage.py check` avec `srmenv`: OK, 0 issue.
- Generation de hash Argon2 OK.
- Verification `check_password` OK.

Script:

- Script de reference ajoute:
  - `API_GeoDjango/sql/2026-05-04_drop_django_auth_admin.sql`

Point d'attention:

- La table `django_migrations` n'est pas une table metier ni une table auth active. Elle reste dans `SRM` comme ledger historique de migrations appliquees; elle n'est pas necessaire au runtime et n'existe pas dans `SRM_bureau`.

## Metriques agents - structure canonique - 2026-05-04

Objectif:

- Partir des vues fonctionnelles de `SRM_bureau`.
- Supprimer la repetition logique entre jour/semaine/mois.
- Garder une structure simple pour une future reecriture mobile.
- Ne pas casser immediatement les endpoints mobiles existants.

Decision:

- Les vues projet/mission restent supprimees:
  - `vw_metrics_projet_jour`
  - `vw_metrics_projet_semaine`
  - `vw_metrics_projet_mois`
  - `vw_metrics_projet_resume`
  - `vw_srm_mission_fact`
- `vw_srm_historique_mobile_fact` est supprimee: l'historique mobile est absorbe par `public.historique_action`.
- Les photos sont comptees depuis `public.objet_photo` via `vw_srm_photo_fact`, pas depuis les anciennes colonnes `photo_1..photo_4`.
- Les jours metier sont figes avec le fuseau `Africa/Casablanca` pour eviter des resultats differents entre Django et une session SQL brute.

Nouvelle couche factuelle:

- `vw_srm_objet_activity_fact`: vue objet/date enrichie avec le compteur photo centralise.
- `vw_srm_intervention_fact`: vue de lecture des anomalies/interventions pour les metriques.

Nouvelle couche canonique:

- `vw_metrics_agent_table_day`: base journaliere detaillee par agent/table/metier.
- `vw_metrics_agent_table_period`: detail par agent/table/metier avec `grain = jour|semaine|mois`.
- `vw_metrics_agent_period`: resume par agent et periode.
- `vw_metrics_agent_resume`: resume global par agent.

Compatibilite conservee:

- Les vues existantes sont reconstruites comme wrappers:
  - `vw_metrics_agent_jour`
  - `vw_metrics_agent_semaine`
  - `vw_metrics_agent_mois`
  - `vw_metrics_agent_public_jour`
  - `vw_metrics_agent_public_semaine`
  - `vw_metrics_agent_public_mois`
  - `vw_metrics_agent_public_resume`
- Le mobile peut donc continuer a lire les anciens endpoints pendant la transition.

Backend:

- Nouveaux modeles Django non managed:
  - `MetricAgentTablePeriod`
  - `MetricAgentPeriod`
  - `MetricAgentResume`
- Nouveaux endpoints API:
  - `/api/metrics-agent-table-period/`
  - `/api/metrics-agent-period/`
  - `/api/metrics-agent-resume/`

Verification:

- Script applique sur `SRM_bureau` et `SRM`:
  - `API_GeoDjango/sql/2026-05-04_metrics_canonical_periods.sql`
- `SRM_bureau`:
  - `vw_srm_objet_activity_fact`: 5145 lignes.
  - `vw_srm_intervention_fact`: 329 lignes.
  - `vw_metrics_agent_table_period`: 114 lignes.
  - `vw_metrics_agent_period`: 63 lignes.
  - `vw_metrics_agent_resume`: 6 lignes.
  - `vw_metrics_agent_public_resume`: 6 lignes.
- `SRM`:
  - `vw_srm_objet_activity_fact`: 7659 lignes.
  - `vw_srm_intervention_fact`: 0 ligne.
  - `vw_metrics_agent_table_period`: 164 lignes.
  - `vw_metrics_agent_period`: 40 lignes.
  - `vw_metrics_agent_resume`: 4 lignes.
  - `vw_metrics_agent_public_resume`: 4 lignes.
- Vues legacy projet/mission/historique mobile: absentes dans les deux bases.
- `python manage.py check` avec `srmenv`: OK, 0 issue.
- Tests API rapides:
  - `MetricAgentPeriodViewSet`: HTTP 200.
  - `MetricAgentTablePeriodViewSet`: HTTP 200.
  - `MetricAgentResumeViewSet`: HTTP 200.
  - wrappers existants `MetricAgentPublicResumeViewSet` et `MetricAgentPublicJourViewSet`: HTTP 200.

## Nettoyage final du bloc metriques/public - 2026-05-04

Nettoyages appliques:

- `API_GeoDjango/sql/2026-04-14_historique_mobile_journal.sql` transforme en tombstone:
  - ne recree plus `public.historique_mobile`;
  - sauvegarde la table si elle existe encore et contient des lignes;
  - droppe ensuite `public.historique_mobile`.
- `API_GeoDjango/pprcollecte/api/migrations/0006_sync_manifest_log.py` alignee sur la structure actuelle:
  - retrait de `id_projet`;
  - retrait de `id_mission`;
  - la table `sync_session` garde uniquement le contexte utilisateur/appareil/synchro.

Neutralisation complete des anciens noms:

- Endpoint `/api/historique-mobile/upload/`: supprime.
- Endpoint `/api/historique-mobile/`: supprime.
- Endpoint `/api/historique/`: supprime.
- Endpoint canonique conserve: `/api/historique-actions/`.
- Le mobile n'appelle plus `uploadLocalHistory` et ne pousse plus de payload d'historique local separe.
- Les payloads actifs ne contiennent plus `id_projet` / `id_mission`.

Verification:

- `SRM_bureau`:
  - tables `public.historique_mobile`, `public.mission`, `public.projet`: absentes.
  - vues `vw_metrics_projet_*`, `vw_srm_mission_fact`, `vw_srm_historique_mobile_fact`: absentes.
  - colonnes `id_projet`, `id_mission`, `id_projet_actif`: absentes.
- `SRM`:
  - tables `public.historique_mobile`, `public.mission`, `public.projet`: absentes.
  - vues `vw_metrics_projet_*`, `vw_srm_mission_fact`, `vw_srm_historique_mobile_fact`: absentes.
  - colonnes `id_projet`, `id_mission`, `id_projet_actif`: absentes.
- Code backend actif:
  - aucun `MetricProjet`;
  - aucun `ProjectMetric`;
  - aucun `ProjetMission`;
  - aucun champ actif `id_projet` / `id_mission`.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

## Configuration mobile `ep_regard.ep_section` - 2026-05-04

Modification appliquee sur `SRM_bureau.public.attribut_config_mobile`.

- Metier: `ep`.
- Table: `ep_regard`.
- Champ: `ep_section`.
- Type configure: `varchar(400)`.
- Titre mobile: `Section du regard`.
- Visibilite mobile: `false`.
- Nullable: `true`.
- Valeur par defaut / formule metier: `longueur x largeur`.
- Ordre: `48`, apres `longueur`, `largeur`, `existence_s` et `type_regard`.
- `primary_key`: `false`.
- `foreign_key`: `false`.
- Pas de contrainte min/max ni de reference FK.

Verification:

- Le champ existe dans `SRM_bureau.ep.ep_regard`.
- Une seule ligne `ep / ep_regard / ep_section` existe dans `attribut_config_mobile`.
- Aucun doublon d'ordre sur la configuration `ep_regard`.

## Couverture historicite des processus - 2026-05-04

Objectif: utiliser `public.historique_action` comme journal canonique pour les modifications metier, sans revenir aux anciennes tables `historique_attribut` / `historique_mobile`.

SQL ajoute et applique:

- `API_GeoDjango/sql/2026-05-04_historique_process_coverage.sql`.
- Remplacement de `public.capture_historique_attribut()`:
  - reconnaissance de `id_agent_*`, `id_user_*`, `id_user_terrain`, `id_user_exploitant`, `id_user_bureau`;
  - alimentation de `id_user` et `nom_user` depuis `public.utilisateur`;
  - support explicite de `app.history_source` (`bureau` / `mobile`);
  - support explicite de `app.history_action`;
  - exclusion des champs sensibles `mot_de_passe`, `mot_de_passe_hash`, `password`.
- Triggers d'audit poses sur les tables metier avec PK simple:
  - tous les objets des schemas `ep`, `ass`, `elec` presents dans chaque base;
  - `public.objet_incomplet`;
  - `public.objet_photo`;
  - `public.intervention_anomalie`;
  - `public.zone`, `public.zone_utilisateur`;
  - tables de configuration/fonctionnement presentes: `attribut_config`, `attribut_config_mobile`, `liste_choix`, `srm_field_option`, `permission`, `utilisateur_permission`, `basemap_package`.
- `public.intervention_log` reste le journal workflow append-only declenche par `intervention_anomalie`; il n'est pas re-journalise dans `historique_action` pour eviter une double historicite artificielle.

Backend:

- Les endpoints metier posent maintenant le contexte d'audit avant sauvegarde:
  - `app.current_user_id`;
  - `app.history_source`;
  - `app.history_action`.
- La synchronisation mobile est marquee `source = mobile` lorsqu'un `sync_session_uuid` est present.
- Les validations mobiles utilisent `action = validate` lorsque `is_validated` est envoye.
- Les objets incomplets, interventions terrain et uploads photo posent aussi le contexte d'audit.

Verification:

- `SRM`: 49 tables cibles, 49 avec trigger d'audit.
- `SRM_bureau`: 45 tables cibles, 45 avec trigger d'audit.
- Test rollback `objet_incomplet`:
  - insertion historisee dans `public.historique_action`;
  - `source = mobile`;
  - `id_user` et `nom_user` recuperes correctement.
- Test rollback `intervention_anomalie`:
  - insertion historisee dans `public.historique_action`;
  - creation automatique d'une ligne `public.intervention_log`;
  - aucune donnee de test conservee apres rollback.
- Comptes apres rollback:
  - `SRM.public.historique_action`: 199 lignes.
  - `SRM_bureau.public.historique_action`: 84 lignes.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

## Durcissement telechargement mobile - 2026-05-04

Objectif: arreter le flux de telechargement des donnees mobiles des la coupure Internet et ne plus afficher d'erreurs techniques Flutter a l'utilisateur.

Modifications Flutter:

- `SyncService.downloadAllData()`:
  - detecte les erreurs reseau/timeout pendant le telechargement;
  - arrete immediatement le flux au lieu de continuer table par table;
  - conserve le statut de reprise de la table en cours (`failed`, `next_page`, `downloaded_count`, `updated_after`);
  - retourne un `SyncResult.interrupted` avec un message utilisateur propre.
- `BasemapCatalogService` et `OfflineBasemapService`:
  - arret du telechargement des cartes offline au premier echec reseau;
  - stockage d'un message lisible au lieu du `SocketException` brut.
- `ApiService`:
  - messages reseau normalises en texte utilisateur (`Erreur reseau ...`) pour eviter les details Flutter.
- `home_page_app_actions.dart` et `home_page_dialogs.dart`:
  - snackbar/dialog dedies au telechargement interrompu;
  - masquage des erreurs techniques lorsque l'erreur est reseau;
  - message de reprise: les donnees deja recues sont conservees et le telechargement peut etre relance.

Verification:

- `dart format` via `tools/codex_dart_flutter.py`: OK.
- `flutter analyze` cible via `tools/codex_dart_flutter.py`: aucune erreur Dart; uniquement les infos existantes (`avoid_print`, `prefer_const_constructors`).

## Nettoyage infos Flutter - 2026-05-04

Objectif: corriger les infos connues de l'analyse Flutter sans changer le comportement metier mobile.

Modifications:

- Remplacement des `print(...)` par `debugPrint(...)`.
- Correction de la boucle d'initialisation SQLite dans `DatabaseHelper.database` pour supprimer le getter recursif.
- Remplacement des `withOpacity(...)` par `withValues(alpha: ...)`.
- Application des corrections automatiques `dart fix --apply`:
  - `initialValue` a la place de `value` dans le formulaire ligne speciale;
  - accolades de flux de controle;
  - `const` manquants;
  - imports inutiles.
- Remplacement des icones FontAwesome depreciees:
  - `save` -> `floppyDisk`;
  - `sync` -> `arrowsRotate`.
- Declaration directe des dependances cartographiques deja presentes en transitif:
  - `pmtiles`;
  - `vector_tile`;
  - `vector_tile_renderer`.
- Suppression/neutralisation des derniers avertissements:
  - checks `mounted` apres les `await` avant usage de `BuildContext`;
  - accolades manquantes dans les branches simples;
  - ignore cible sur l'import interne Protomaps conserve pour ne pas modifier le rendu de la carte.

Verification:

- `dart fix --apply` via `tools/codex_dart_flutter.py`: OK.
- `dart format lib` via `tools/codex_dart_flutter.py`: OK.
- `dart pub get --offline` via `tools/codex_dart_flutter.py`: OK.
- `flutter pub get` lance en terminal utilisateur: OK.
- `flutter analyze` via `tools/codex_dart_flutter.py`: OK, `No issues found`.

## Cloture zoning et basemap - 2026-05-04

Objectif: confirmer que le zoning agent et les cartes offline reposent sur `public.zone` / `public.zone_utilisateur`, et non plus sur `public.commune` ni sur les anciennes tables intermediaires.

Modifications appliquees:

- Creation de `SRM_bureau.public.basemap_package` avec la structure cible de `API_GeoDjango/sql/2026-04-14_basemap_zones_catalog.sql`.
- Re-creation de `SRM.public.basemap_package` car la table etait vide et sans dependance externe, afin d'aligner strictement l'ordre physique des colonnes avec `SRM_bureau`.
- Ajout du trigger d'audit `trg_audit_basemap_package` sur `public.basemap_package` dans les deux bases.

Etat final verifie:

- `public.agent_basemap_zone`: absente dans `SRM` et `SRM_bureau`.
- `public.basemap_zone`: absente dans `SRM` et `SRM_bureau`.
- `public.zone`: 21 lignes dans chaque base.
- `public.zone_utilisateur`: 23 lignes dans chaque base.
- `public.basemap_package`: 0 ligne dans chaque base.
- `public.basemap_package` est identique entre les deux bases:
  - 21 colonnes dans le meme ordre;
  - 3 contraintes identiques;
  - 5 index identiques;
  - 1 trigger d'audit identique.

Conclusion:

- L'affectation agent se fait via `public.zone_utilisateur(id_user, id_zone)`.
- Le catalogue basemap se rattache directement a `public.basemap_package.id_zone -> public.zone(id_zone)`.
- `public.commune` reste un referentiel administratif/geographique, mais ne pilote plus les affectations ni les basemaps offline.

## Filtrage Oriental de `public.commune` - 2026-05-04

Objectif: limiter `public.commune` aux communes utiles au projet sur la region Oriental, avec les provinces/prefecture suivantes:

- Province de Nador: `code_provi = 02.381.`, `id_province = 14`.
- Prefecture d'Oujda-Angad: `code_provi = 02.411.`, `id_province = 15`.

Sauvegarde:

- Backup cree dans les deux bases: `public.commune_backup_before_oriental_filter_20260504_174454`.

Modifications appliquees:

- `SRM_bureau.public.commune`:
  - suppression des communes hors `02.381.` / `02.411.`;
  - 1471 lignes supprimees;
  - aucune FK metier ne pointait vers les communes supprimees.
- `SRM.public.commune`:
  - ajout des 23 communes de Nador depuis `SRM_bureau`;
  - les 11 communes d'Oujda-Angad existantes ont ete conservees/alignees.
- Backend Django:
  - `CommuneSerializer.get_nom_province()` retourne maintenant aussi `Province de Nador` pour `code_provi = 02.381.`.

Etat final verifie:

- `SRM.public.commune`: 34 lignes.
- `SRM_bureau.public.commune`: 34 lignes.
- Contenu strictement identique entre les deux bases.
- Repartition finale:
  - `02.381.` / Nador: 23 communes;
  - `02.411.` / Oujda-Angad: 11 communes.
- Aucune commune hors perimetre Oriental cible dans les deux bases.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

## Nettoyage des tables backup publiques - 2026-05-04

Objectif: supprimer les tables de sauvegarde/intermediaires du schema `public` apres avoir cree un dump complet de chaque base.

Dumps complets crees:

- `backups/postgres/SRM_full_before_public_backup_cleanup_20260504_175024.dump`.
- `backups/postgres/SRM_bureau_full_before_public_backup_cleanup_20260504_175024.dump`.

Tables backup supprimees:

- `SRM`: 13 tables `public.*backup*` supprimees.
- `SRM_bureau`: 10 tables `public.*backup*` supprimees.

Etat final verifie:

- `SRM.public`: 0 table backup restante.
- `SRM_bureau.public`: 0 table backup restante.
- Ecart public restant hors PostGIS/backups:
  - uniquement `SRM`: `django_migrations`, `srm_field_option`;
  - uniquement `SRM_bureau`: `attribut_config`, `attribut_config_mobile`, `fond_plan`, `liste_choix`, `permission`, `planche`, `province`, `utilisateur_permission`.

Decision:

- `django_migrations` est une table systeme Django et sera traitee comme objet technique a ignorer pour l'homogeneite metier.
- Les autres tables restantes sont fonctionnelles et doivent etre propagees pour stabiliser le schema `public`.

## Propagation des tables fonctionnelles `public` - 2026-05-04

Objectif: rendre le socle fonctionnel du schema `public` disponible dans les deux bases, hors objets systeme/PostGIS.

Tables propagees de `SRM_bureau` vers `SRM`:

- `province`
- `attribut_config`
- `attribut_config_mobile`
- `liste_choix`
- `permission`
- `utilisateur_permission`
- `planche`
- `fond_plan`

Table propagee de `SRM` vers `SRM_bureau`:

- `srm_field_option`

Corrections structurelles appliquees:

- `SRM.public.commune` alignee sur la structure de `SRM_bureau.public.commune`:
  - sequence/default `communes_maroc_fid_seq`;
  - FK `id_province -> public.province(fid)`;
  - noms de contrainte/index alignes.
- Contrainte `public.utilisateur_role_check` harmonisee dans les deux bases avec les roles:
  - `admin`
  - `project_manager`
  - `editeur_terrain`
  - `editeur_bureau`
  - `viewer_mobile`
  - `viewer`
  - `superadmin`
  - `exploitant_srm`
- Table temporaire `public.utilisateur_id_homog_20260504` supprimee dans les deux bases.

Etat final du socle `public`:

- 40 objets fonctionnels dans `SRM`.
- 40 objets fonctionnels dans `SRM_bureau`.
- Aucun objet fonctionnel manquant d'un cote ou de l'autre.
- Aucune difference de type d'objet.
- Les structures des tables fonctionnelles sont alignees.
- Vues encore differentes et differees au bloc `ep` / `ass`:
  - `public.vw_srm_objet_fact`;
  - `public.vw_srm_photo_fact`.

Note:

- Les contenus des tables operationnelles (`historique_action`, `intervention_anomalie`, `intervention_log`, `objet_photo`, `sync_session*`) ne sont pas forces a etre identiques, car ils representent des historiques, sessions ou donnees metier propres a chaque base. Leur fusion eventuelle doit etre traitee explicitement, table par table.

## Completion `attribut_config_mobile` pour `public` - 2026-05-04

Objectif: couvrir toutes les tables fonctionnelles du schema `public` dans `public.attribut_config_mobile`, sans rendre ces champs visibles dans le mobile par defaut.

Sauvegarde cible:

- Dumps SQL crees dans `backups/postgres/attribut_config_mobile_before_public_completion_20260504_180108`.

Regles appliquees aux nouvelles lignes:

- `nom_metier = public`.
- `visible = false` par defaut.
- `titre_app` derive du nom technique de colonne.
- `type_champ`, `primary_key`, `foreign_key`, `nullable`, `valeur_par_defaut`, `reference_fk` renseignes depuis les metadonnees PostgreSQL.
- Aucune donnee fictive ajoutee dans les tables metier.

Etat final verifie:

- `SRM.public.attribut_config_mobile`: 244 lignes pour `nom_metier = public`.
- `SRM_bureau.public.attribut_config_mobile`: 244 lignes pour `nom_metier = public`.
- 22 tables `public` couvertes.
- 0 colonne `public` manquante dans la configuration mobile.
- Hash du contenu `public` de `attribut_config_mobile` identique entre les deux bases.

## Inventaire initial `ep` / `ass` avant application structurelle - 2026-05-04

Objectif: distinguer les tables vides des tables avec donnees avant toute operation structurelle sur les schemas metier.

Schema `ep`:

- `SRM`: 31 tables.
- `SRM_bureau`: 33 tables.
- Tables communes vides des deux cotes:
  - `statistique_conduite`
  - `statistique_conduite_segment`
- Tables communes avec donnees uniquement dans `SRM`:
  - `borne_onep`: 2 lignes dans `SRM`, 0 dans `SRM_bureau`
  - `centre_tampon`: 946 lignes dans `SRM`, 0 dans `SRM_bureau`
- Tables uniquement dans `SRM`, avec donnees:
  - `autre_objet`: 578
  - `borne_fontaine`: 79
  - `bouche_cles`: 352
  - `branchement`: 199
  - `compteur_abonne`: 1240
  - `compteur_reseau`: 22
  - `cone_de_reduction`: 28
  - `ep_conduite_bureau`: 551
  - `ep_conduite_terrain`: 563
  - `forage`: 2
  - `hydrant`: 12
  - `noeud`: 232
  - `obturateur`: 173
  - `planche`: 2204
  - `pompe`: 1
  - `reducteur_de_pression`: 1
  - `regard`: 11
  - `regard_miroir`: 11
  - `reservoir`: 11
  - `station_de_pompage`: 5
  - `traverse`: 20
  - `vanne`: 188
  - `vanne_de_vidange`: 96
  - `ventouse`: 128
- Tables uniquement dans `SRM`, vides:
  - `bouche_darrosage`
  - `puit`
  - `regard_ep`
- Tables uniquement dans `SRM_bureau`, avec donnees:
  - `ep_bf`: 384
  - `ep_brc_pt`: 1313
  - `ep_compteur_i`: 24
  - `ep_conduite`: 998
  - `ep_cone_reduc`: 33
  - `ep_obturateur`: 245
  - `ep_regard`: 1333
  - `ep_st_demineralisation`: 5
  - `ep_vanne`: 333
  - `ep_ventouse`: 271
  - `ep_vidange`: 206
  - `onep_db`: 10580
- Tables uniquement dans `SRM_bureau`, vides:
  - `anomalie_conduite`
  - `bouche_a_cles`
  - `conduite_terrain`
  - `ep_bache`
  - `ep_bouche_arro`
  - `ep_branchement`
  - `ep_forage`
  - `ep_hydrant`
  - `ep_noeud`
  - `ep_pompe`
  - `ep_puit`
  - `ep_reduc_pres`
  - `ep_reservoir`
  - `ep_station_pompage`
  - `ep_traversee`
  - `tn`
  - `voie`

Schema `ass`:

- `SRM`: 11 tables.
- `SRM_bureau`: 2 tables.
- Tables communes vides des deux cotes:
  - `statistique_conduite`
  - `statistique_conduite_segment`
- Tables uniquement dans `SRM`, avec donnees:
  - `asst_branchement`: 1
  - `asst_canalisation`: 1
  - `asst_ouvrage`: 1
  - `asst_regard_branchement`: 1
- Tables uniquement dans `SRM`, vides:
  - `asst_bassin`
  - `asst_canalisation_reutilisation`
  - `asst_equipement`
  - `asst_regard`
  - `asst_station`

Decision:

- Commencer par les tables vides et/ou absentes sans donnees.
- Les tables contenant des donnees doivent etre rapprochees par mapping explicite, avec sauvegarde et strategie de migration dediee.

## Creation non destructive des tables cibles `ep` / `ass` - 2026-05-04

Objectif: faire exister dans les deux bases toutes les tables cibles declarees dans `public.attribut_config_mobile`, sans migrer ni supprimer de donnees existantes.

Sauvegarde de schema:

- `backups/postgres/ep_ass_schema_before_config_targets_20260504_181646/SRM_ep_ass_schema.sql`
- `backups/postgres/ep_ass_schema_before_config_targets_20260504_181646/SRM_bureau_ep_ass_schema.sql`

Regle appliquee:

- Si la table cible existait dans une seule BD, son schema a ete copie vers l'autre BD, sans donnees.
- Si la table cible n'existait dans aucune BD, elle a ete generee depuis `attribut_config_mobile`.
- Aucune ancienne table porteuse de donnees n'a ete supprimee ou renommee.
- Aucune migration de contenu n'a ete effectuee dans cette passe.

Correction technique:

- `SRM_bureau.public.set_updated_at()` a ete creee, car certains schemas copies depuis `SRM` l'utilisent pour les triggers `updated_at`.
- Trigger `trg_ep_ep_conduite_bureau_updated_at` ajoute sur `SRM_bureau.ep.ep_conduite_bureau`.
- FK manquantes ajoutees sur `SRM_bureau.ep.ep_conduite_bureau` pour aligner la structure avec `SRM`:
  - `id_commune -> public.commune(fid) ON DELETE SET NULL`
  - `id_agent_crea -> public.utilisateur(id_user) ON DELETE SET NULL`

Etat final verifie:

- 51 tables cibles `ep` / `ass` declarees dans `attribut_config_mobile`.
- 51 tables existent dans `SRM`.
- 51 tables existent dans `SRM_bureau`.
- 0 table cible manquante.
- 0 difference structurelle sur les tables cibles:
  - colonnes;
  - contraintes;
  - index;
  - triggers.

Tables cibles avec donnees restant a traiter au cas par cas:

- `ep.ep_bf`: `SRM = 0`, `SRM_bureau = 384`
- `ep.ep_brc_pt`: `SRM = 0`, `SRM_bureau = 1313`
- `ep.ep_compteur_i`: `SRM = 0`, `SRM_bureau = 24`
- `ep.ep_conduite_bureau`: `SRM = 551`, `SRM_bureau = 0`
- `ep.ep_conduite_terrain`: `SRM = 563`, `SRM_bureau = 0`
- `ep.ep_cone_reduc`: `SRM = 0`, `SRM_bureau = 33`
- `ep.ep_obturateur`: `SRM = 0`, `SRM_bureau = 245`
- `ep.ep_st_demineralisation`: `SRM = 0`, `SRM_bureau = 5`
- `ep.ep_vanne`: `SRM = 0`, `SRM_bureau = 333`
- `ep.ep_ventouse`: `SRM = 0`, `SRM_bureau = 271`
- `ep.ep_vidange`: `SRM = 0`, `SRM_bureau = 206`

Note:

- Les tables `ass` cibles sont maintenant structurellement presentes des deux cotes, mais restent vides. Les anciennes tables `asst_*` de `SRM` portent encore certaines donnees et doivent etre migrees par mapping explicite.

## Plan global de wrapping des deux BDs - 2026-05-04

Objectif final: rapprocher `SRM` et `SRM_bureau` jusqu'a obtenir une base projet propre, homogene, et exploitable par le backend Django, le mobile et le frontend.

Plan directeur valide:

1. Nettoyer le schema `public` pour qu'il devienne identique entre `SRM` et `SRM_bureau`, en ignorant les objets systeme/PostGIS quand ils ne portent pas de metier projet.
2. Completer `public.attribut_config_mobile` avec les tables manquantes du schema `public`, uniquement comme configuration utile et sans ajouter de donnees fictives.
3. Appliquer progressivement la structure de reference issue de `attribut_config_mobile` sur les schemas metier `ep` et `ass`:
   - commencer par les tables sans donnees;
   - isoler les tables contenant des donnees;
   - traiter les tables avec donnees au cas par cas pour ne perdre aucune information.

Regle de securite:

- Toute operation destructive ou structurelle sur une table contenant des donnees doit etre precedee d'un inventaire, d'une sauvegarde et d'une validation explicite du cas traite.

## Traitement `ep.ep_regard` - point central et miroir polygonal - 2026-05-04

Decision metier validee:

- `ep.ep_regard` devient la table metier centrale des regards EP.
- Sa geometrie est un `PointZ` SRID 26191.
- Pour les donnees polygonales existantes, le point central est calcule depuis le centroide.
- Les polygones sont conserves dans `ep.ep_regard_miroir`.
- `ep.ep_regard_miroir` est une table miroir technique: elle porte la geometrie polygonale et garde le lien `fid_regard_source -> ep.ep_regard(fid)`.

Sauvegardes ciblees avant transformation:

- `backups/postgres/ep_regard_before_point_mirror_20260504_184443/SRM_ep_regard_related.dump`
- `backups/postgres/ep_regard_before_point_mirror_20260504_184443/SRM_bureau_ep_regard_related.dump`

Inventaire avant traitement:

- `SRM.ep.ep_regard`: 0 ligne, geometrie cible initiale polygonale.
- `SRM.ep.regard`: 11 lignes, geometrie `POINT`.
- `SRM.ep.regard_miroir`: 11 lignes, geometrie `POLYGON`, derivee de `ep.regard`.
- `SRM_bureau.ep.ep_regard`: 1333 lignes, geometrie `POLYGON`.
- Recouvrement UUID entre `SRM.ep.regard` et `SRM_bureau.ep.ep_regard`: 0.
- Les `fid` de `SRM.ep.regard` chevauchent ceux de `SRM_bureau.ep.ep_regard`; les `fid` de `SRM_bureau` n'ont donc pas ete ecrases.

Actions appliquees:

- Creation de `ep.ep_regard_miroir` dans les deux bases.
- Conservation des 1333 polygones existants de `SRM_bureau.ep.ep_regard` dans `SRM_bureau.ep.ep_regard_miroir`.
- Conversion de `ep.ep_regard.geom` en `geometry(PointZ, 26191)` dans les deux bases.
- Synchronisation de `ep_coor_x`, `ep_coor_y`, `ep_coor_z` avec la geometrie point centrale.
- Les anciennes coordonnees attributaires des polygones bureau restent conservees dans `ep.ep_regard_miroir`.
- Migration des 11 regards mobiles de `SRM.ep.regard` vers:
  - `SRM.ep.ep_regard`, avec conservation du `fid` source;
  - `SRM_bureau.ep.ep_regard`, avec nouveaux `fid` `1334` a `1344`.
- Migration des 11 miroirs polygonaux correspondants vers `ep.ep_regard_miroir` dans les deux bases.
- `source = 'mobile'` pour les 11 regards issus de `SRM`.
- `source = 'web'` pour les 1333 regards historiques de `SRM_bureau`.

Etat final verifie:

- `SRM.ep.ep_regard`: 11 lignes, toutes en `ST_Point`, SRID 26191, dimension 3.
- `SRM.ep.ep_regard_miroir`: 11 lignes, toutes en `ST_Polygon`, SRID 26191, dimension 3.
- `SRM_bureau.ep.ep_regard`: 1344 lignes, toutes en `ST_Point`, SRID 26191, dimension 3.
- `SRM_bureau.ep.ep_regard_miroir`: 1344 lignes, toutes en `ST_Polygon`, SRID 26191, dimension 3.
- Les 11 UUID mobiles de `SRM.ep.regard` existent dans `SRM_bureau.ep.ep_regard`.
- Aucun doublon UUID non nul dans `ep.ep_regard`.
- Aucun objet central sans miroir.
- Aucun miroir sans objet central.
- Aucun ecart entre `ep_coor_x/y/z` et `ST_X/Y/Z(geom)` dans `ep.ep_regard`.
- Structures identiques entre `SRM` et `SRM_bureau` pour:
  - colonnes de `ep.ep_regard`;
  - contraintes de `ep.ep_regard`;
  - index de `ep.ep_regard`;
  - colonnes de `ep.ep_regard_miroir`;
  - contraintes de `ep.ep_regard_miroir`;
  - index de `ep.ep_regard_miroir`.

Point d'attention:

- Les anciennes tables `ep.regard` et `ep.regard_miroir` de `SRM` n'ont pas ete supprimees dans cette passe.
- Le code backend/mobile contient encore des references historiques a `ep.regard` / `regard`.
- Le basculement applicatif vers la table canonique `ep.ep_regard` devra etre traite dans une passe dediee, pour eviter de melanger migration BD et changement de workflow mobile.

## Snapshot apres `ep_regard` et tables `ep` restantes - 2026-05-04

Objectif: memoriser l'etat courant apres traitement de `ep.ep_regard`, avant de continuer les migrations des autres tables contenant des donnees.

Backups complets de cet etat:

- `backups/postgres/state_after_ep_regard_20260504_185443/SRM_full_after_ep_regard.dump`
- `backups/postgres/state_after_ep_regard_20260504_185443/SRM_bureau_full_after_ep_regard.dump`

Bundle compatible PostgreSQL 16:

- `backups/postgres/state_after_ep_regard_pg16_bundle_20260504_230334/SRM_full_after_ep_regard_pg16_compat.sql`
- `backups/postgres/state_after_ep_regard_pg16_bundle_20260504_230334/SRM_bureau_full_after_ep_regard_pg16_compat.sql`
- `backups/postgres/state_after_ep_regard_pg16_bundle_20260504_230334/SRM_full_after_ep_regard.backup`
- `backups/postgres/state_after_ep_regard_pg16_bundle_20260504_230334/SRM_bureau_full_after_ep_regard.backup`

Notes de compatibilite:

- Les fichiers `.sql` sont le format prioritaire pour restauration PostgreSQL 16 via `psql`.
- Ils sont generes en SQL texte, UTF-8, sans owner, sans privileges.
- La ligne PostgreSQL 17 `SET transaction_timeout = 0;` a ete retiree pour eviter l'erreur sur PostgreSQL 16.
- Les fichiers `.backup` sont des archives custom creees avec le `pg_dump` disponible localement, version 17.8.
- Leur catalogue a ete verifie avec `pg_restore`, mais pour une restauration PostgreSQL 16 stricte il faut preferer les `.sql`, ou restaurer les `.backup` avec un `pg_restore` compatible avec l'archive.

Tables `ep` deja traitees:

- `ep.ep_regard`: table centrale en `PointZ`.
- `ep.ep_regard_miroir`: table miroir polygonale.

Tables cibles `ep_*` contenant encore des donnees a rapprocher:

- Donnees uniquement dans `SRM`:
  - `ep.ep_conduite_bureau`: 551 lignes.
  - `ep.ep_conduite_terrain`: 563 lignes.
- Donnees uniquement dans `SRM_bureau`:
  - `ep.ep_bf`: 384 lignes.
  - `ep.ep_brc_pt`: 1313 lignes.
  - `ep.ep_compteur_i`: 24 lignes.
  - `ep.ep_conduite`: 998 lignes.
  - `ep.ep_cone_reduc`: 33 lignes.
  - `ep.ep_obturateur`: 245 lignes.
  - `ep.ep_st_demineralisation`: 5 lignes.
  - `ep.ep_vanne`: 333 lignes.
  - `ep.ep_ventouse`: 271 lignes.
  - `ep.ep_vidange`: 206 lignes.

Anciennes tables source de `SRM` avec donnees, a mapper ou neutraliser au cas par cas:

- `ep.autre_objet`: 578 lignes.
- `ep.borne_fontaine`: 79 lignes.
- `ep.borne_onep`: 2 lignes.
- `ep.bouche_cles`: 352 lignes.
- `ep.branchement`: 199 lignes.
- `ep.centre_tampon`: 946 lignes.
- `ep.compteur_abonne`: 1240 lignes.
- `ep.compteur_reseau`: 22 lignes.
- `ep.cone_de_reduction`: 28 lignes.
- `ep.forage`: 2 lignes.
- `ep.hydrant`: 12 lignes.
- `ep.noeud`: 232 lignes.
- `ep.obturateur`: 173 lignes.
- `ep.planche`: 2204 lignes.
- `ep.pompe`: 1 ligne.
- `ep.reducteur_de_pression`: 1 ligne.
- `ep.reservoir`: 11 lignes.
- `ep.station_de_pompage`: 5 lignes.
- `ep.traverse`: 20 lignes.
- `ep.vanne`: 188 lignes.
- `ep.vanne_de_vidange`: 96 lignes.
- `ep.ventouse`: 128 lignes.

Tables legacy de regards a conserver temporairement:

- `SRM.ep.regard`: 11 lignes, deja migrees vers `ep.ep_regard`.
- `SRM.ep.regard_miroir`: 11 lignes, deja migrees vers `ep.ep_regard_miroir`.
- Ces deux tables ne sont plus des sources a migrer, mais restent en place jusqu'au basculement applicatif complet.

Table speciale a analyser avant decision:

- `SRM_bureau.ep.onep_db`: 10580 lignes.
- Cette table ressemble a une source/reference brute et ne doit pas etre integree ou supprimee sans analyse metier.

Tables cibles vides et structurellement presentes dans les deux bases:

- `ep.ep_anomalie_conduite`
- `ep.ep_bache`
- `ep.ep_bouche_arro`
- `ep.ep_branchement`
- `ep.ep_centre_tampon`
- `ep.ep_forage`
- `ep.ep_hydrant`
- `ep.ep_noeud`
- `ep.ep_pompe`
- `ep.ep_puit`
- `ep.ep_reduc_pres`
- `ep.ep_reservoir`
- `ep.ep_station_pompage`
- `ep.ep_tn`
- `ep.ep_traversee`
- `ep.ep_voie`
- `ep.statistique_conduite`
- `ep.statistique_conduite_segment`

Regle pour la suite:

- Chaque table restante doit etre traitee avec:
  - inventaire source/cible;
  - verification des UUID/fid et references;
  - backup cible si donnees porteuses;
  - migration sans suppression immediate des anciennes tables;
  - controle final des comptes, geometries, contraintes et doublons.

## Migration organes ponctuels EP - 2026-05-04

Bloc traite:

- `SRM.ep.vanne` -> `ep.ep_vanne`
- `SRM.ep.vanne_de_vidange` -> `ep.ep_vidange`
- `SRM.ep.ventouse` -> `ep.ep_ventouse`
- `SRM.ep.obturateur` -> `ep.ep_obturateur`
- `SRM.ep.cone_de_reduction` -> `ep.ep_cone_reduc`

Objectif:

- Utiliser les tables cibles `ep_*` comme structures canoniques issues de `attribut_config_mobile`.
- Integrer les donnees mobiles/terrain de `SRM` dans les deux bases.
- Conserver les donnees historiques de `SRM_bureau`.
- Ne perdre aucun champ existant dans les anciennes tables source.

Backups cibles avant migration:

- `backups/postgres/ep_point_organs_before_migration_20260504_234110/SRM_ep_point_organs_before_migration_pg16_compat.sql`
- `backups/postgres/ep_point_organs_before_migration_20260504_234110/SRM_bureau_ep_point_organs_before_migration_pg16_compat.sql`
- `backups/postgres/ep_point_organs_before_migration_20260504_234110/SRM_ep_point_organs_before_migration.backup`
- `backups/postgres/ep_point_organs_before_migration_20260504_234110/SRM_bureau_ep_point_organs_before_migration.backup`

Inventaire avant migration:

- `SRM.ep.vanne`: 188 lignes; `SRM_bureau.ep.ep_vanne`: 333 lignes; recouvrement UUID: 0.
- `SRM.ep.vanne_de_vidange`: 96 lignes; `SRM_bureau.ep.ep_vidange`: 206 lignes; recouvrement UUID: 0.
- `SRM.ep.ventouse`: 128 lignes; `SRM_bureau.ep.ep_ventouse`: 271 lignes; recouvrement UUID: 0.
- `SRM.ep.obturateur`: 173 lignes; `SRM_bureau.ep.ep_obturateur`: 245 lignes; recouvrement UUID: 0.
- `SRM.ep.cone_de_reduction`: 28 lignes; `SRM_bureau.ep.ep_cone_reduc`: 33 lignes; recouvrement UUID: 0.
- Les colonnes `photo_1..photo_4` sont vides dans les 5 anciennes tables source; aucune ligne `objet_photo` supplementaire n'a donc ete creee pour ce bloc.

Colonnes de tracabilite ajoutees aux 5 tables cibles:

- `legacy_source_table text`
- `legacy_source_fid integer`
- `donnees_legacy jsonb`

Ces colonnes ont ete ajoutees aussi dans `public.attribut_config_mobile` pour chaque table cible, avec `visible = false`.

Regle de mapping:

- Les colonnes communes sont mappees directement.
- `ref_rue` -> `ep_ref_rue`.
- `observation` -> `ep_observation`.
- `conformite_plan` -> `ep_conf_plan`.
- `anomalie` -> `ep_anomalie` avec valeurs `Oui` / `Non`.
- `id_agent_crea` -> `id_user_creat` quand la reference utilisateur existe.
- `updated_at` -> `date_creation` et `date_modif`.
- `source = mobile` pour les lignes issues de `SRM`.
- `source = web` pour les lignes historiques deja presentes dans `SRM_bureau`.
- Les champs non canoniques et/ou sans cible directe sont conserves dans `donnees_legacy`.

Etat final:

- `SRM.ep.ep_vanne`: 188 lignes, toutes `mobile`.
- `SRM_bureau.ep.ep_vanne`: 521 lignes = 333 `web` + 188 `mobile`.
- `SRM.ep.ep_vidange`: 96 lignes, toutes `mobile`.
- `SRM_bureau.ep.ep_vidange`: 302 lignes = 206 `web` + 96 `mobile`.
- `SRM.ep.ep_ventouse`: 128 lignes, toutes `mobile`.
- `SRM_bureau.ep.ep_ventouse`: 399 lignes = 271 `web` + 128 `mobile`.
- `SRM.ep.ep_obturateur`: 173 lignes, toutes `mobile`.
- `SRM_bureau.ep.ep_obturateur`: 418 lignes = 245 `web` + 173 `mobile`.
- `SRM.ep.ep_cone_reduc`: 28 lignes, toutes `mobile`.
- `SRM_bureau.ep.ep_cone_reduc`: 61 lignes = 33 `web` + 28 `mobile`.

Verifications:

- Tous les objets ont une geometrie `ST_Point`, SRID 26191.
- 0 geometrie nulle sur les 5 tables cibles.
- 0 doublon UUID non nul dans les 5 tables cibles.
- Les UUID source de `SRM` sont presents dans les tables cibles de `SRM_bureau`.
- Les lignes `mobile` sont identiques entre `SRM` et `SRM_bureau` par hash de contenu, hors `fid`.
- Les structures des 5 tables cibles sont identiques entre `SRM` et `SRM_bureau`:
  - colonnes;
  - contraintes;
  - index.
- `public.attribut_config_mobile` contient les 3 colonnes de tracabilite pour chacune des 5 tables dans les deux bases.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

Point d'attention:

- Les anciennes tables source (`vanne`, `vanne_de_vidange`, `ventouse`, `obturateur`, `cone_de_reduction`) ne sont pas encore supprimees.
- Les champs `ep_coor_x/y/z` ont ete conserves comme valeurs attributaires existantes. Ils n'ont pas ete forces depuis `ST_X/Y/Z(geom)`, afin de ne pas alterer des valeurs terrain/historiques potentiellement distinctes.

## Source de verite `attribut_config_mobile` - `ep_regard_miroir` et analyse `ep_conduite` - 2026-05-04

Principe confirme:

- `public.attribut_config_mobile` est la source de verite de structure.
- Une table metier qui doit rester dans le schema cible doit etre declaree dans `attribut_config_mobile`.
- Une table source/intermediaire a migrer puis neutraliser ne doit pas forcement devenir une table config cible.

Backups avant modification/analyse:

- `backups/postgres/ep_config_regard_miroir_conduite_analysis_20260504_235543/SRM_ep_config_regard_miroir_conduite_pg16_compat.sql`
- `backups/postgres/ep_config_regard_miroir_conduite_analysis_20260504_235543/SRM_bureau_ep_config_regard_miroir_conduite_pg16_compat.sql`
- `backups/postgres/ep_config_regard_miroir_conduite_analysis_20260504_235543/SRM_ep_config_regard_miroir_conduite.backup`
- `backups/postgres/ep_config_regard_miroir_conduite_analysis_20260504_235543/SRM_bureau_ep_config_regard_miroir_conduite.backup`

Action appliquee sur `ep_regard_miroir`:

- Ajout de `ep_regard_miroir` dans `public.attribut_config_mobile` des deux bases.
- 72 lignes de configuration creees/actualisees pour 72 colonnes physiques.
- `visible = false` pour toutes les colonnes, car il s'agit d'une table miroir technique et non d'un formulaire mobile.
- Hash de configuration identique entre `SRM` et `SRM_bureau`.

Analyse `SRM_bureau.ep.ep_conduite`:

- `ep_conduite` contient 998 lignes.
- Geometrie: `LINESTRING`, SRID 26191, dimension 3.
- UUID: 998 UUID non nuls, 0 doublon.
- `source` est encore nul sur les 998 lignes.
- Valeurs dominantes:
  - `ep_statut = Existant`: 990 lignes.
  - `ep_type = Distribution`: 960 lignes.
  - `ep_classe_conduite = PN16`: 955 lignes.

Comparaison avec les tables cibles:

- `ep_conduite` vs `ep_conduite_bureau`:
  - 30 colonnes physiques communes avec la structure legacy actuelle;
  - 45 colonnes communes avec la configuration `attribut_config_mobile.ep_conduite_bureau`.
- `ep_conduite` vs `ep_conduite_terrain`:
  - 30 colonnes physiques communes avec la structure legacy actuelle;
  - seulement 15 colonnes communes avec la configuration `attribut_config_mobile.ep_conduite_terrain`.
- `ep_conduite_bureau` et `ep_conduite_terrain` ont actuellement une structure physique legacy identique, mais leurs roles metier sont differents.

Conclusion:

- `SRM_bureau.ep.ep_conduite` correspond a `ep.ep_conduite_bureau`.
- Ce n'est pas la table terrain.
- Justification:
  - `docs/audit_srm_dictionary.py` mappe deja `ep_conduite` vers `ep_conduite_bureau`.
  - Le mobile utilise `ep_conduite_terrain` pour la collecte terrain.
  - Les commentaires de table distinguent explicitement:
    - `ep_conduite_bureau`: conduites bureau / origine bureau;
    - `ep_conduite_terrain`: conduites terrain / origine terrain.
  - Les colonnes de `ep_conduite` sont plus proches de la structure cible configuree pour `ep_conduite_bureau`.

Decision pour la suite:

- Ne pas creer `ep_conduite` comme table cible dans `attribut_config_mobile`.
- Traiter `ep_conduite` comme table source bureau a migrer vers `ep_conduite_bureau`.
- Avant migration, appliquer la structure cible declaree par `attribut_config_mobile.ep_conduite_bureau` sur la table physique `ep.ep_conduite_bureau` dans les deux bases.
- Migrer ensuite:
  - `SRM_bureau.ep.ep_conduite` -> `ep.ep_conduite_bureau` avec `source = web`;
  - `SRM.ep.ep_conduite_bureau` -> `ep.ep_conduite_bureau` avec `source = mobile` ou une source precise a confirmer selon le workflow;
  - `SRM.ep.ep_conduite_terrain` -> `ep.ep_conduite_terrain` avec `source = mobile`.
- Les anciennes tables source ne seront pas supprimees avant validation finale des comptes, UUID, longueurs, geometries et references.

## Alignement et migration des conduites EP - 2026-05-05

Bloc traite:

- `ep.ep_conduite_bureau`
- `ep.ep_conduite_terrain`
- source bureau historique: `SRM_bureau.ep.ep_conduite`

Backup avant modification:

- `backups/postgres/ep_conduites_before_alignment_20260505_000037/SRM_ep_conduites_before_alignment_pg16_compat.sql`
- `backups/postgres/ep_conduites_before_alignment_20260505_000037/SRM_bureau_ep_conduites_before_alignment_pg16_compat.sql`
- `backups/postgres/ep_conduites_before_alignment_20260505_000037/SRM_ep_conduites_before_alignment.backup`
- `backups/postgres/ep_conduites_before_alignment_20260505_000037/SRM_bureau_ep_conduites_before_alignment.backup`

Structure appliquee:

- `ep_conduite_bureau`: 70 colonnes physiques et 70 lignes dans `attribut_config_mobile`.
- `ep_conduite_terrain`: 52 colonnes physiques et 52 lignes dans `attribut_config_mobile`.
- Les structures physiques sont identiques entre `SRM` et `SRM_bureau`.
- Les configurations `attribut_config_mobile` sont identiques entre `SRM` et `SRM_bureau`.
- Les colonnes legacy conservees pour compatibilite backend/mobile sont ajoutees dans `attribut_config_mobile` avec `visible = false`.
- Les colonnes de tracabilite suivantes sont presentes sur les deux tables:
  - `source text`
  - `legacy_source_table text`
  - `legacy_source_fid integer`
  - `donnees_legacy jsonb`

Regle de migration:

- `SRM_bureau.ep.ep_conduite` alimente `SRM_bureau.ep.ep_conduite_bureau` avec `source = web`.
- `SRM.ep.ep_conduite_bureau` reste dans `SRM` et est aussi copiee dans `SRM_bureau.ep.ep_conduite_bureau` avec `source = mobile`.
- `SRM.ep.ep_conduite_terrain` reste dans `SRM` et est aussi copiee dans `SRM_bureau.ep.ep_conduite_terrain` avec `source = mobile`.
- Les champs sans cible canonique directe sont conserves dans `donnees_legacy`.
- `altitute` de la source bureau est mappe vers `altitude`.
- Les anciennes colonnes `photo_1`, `photo_2` et `ep_photo` sont vides sur ce bloc; aucune ligne `objet_photo` supplementaire n'a ete creee.

Etat final:

- `SRM.ep.ep_conduite_bureau`: 551 lignes, toutes `mobile`.
- `SRM.ep.ep_conduite_terrain`: 563 lignes, toutes `mobile`.
- `SRM_bureau.ep.ep_conduite_bureau`: 1549 lignes = 998 `web` + 551 `mobile`.
- `SRM_bureau.ep.ep_conduite_terrain`: 563 lignes, toutes `mobile`.
- `SRM_bureau.ep.ep_conduite`: 998 lignes, conservee temporairement comme table source historique non encore supprimee.

Verifications:

- 0 UUID nul et 0 doublon UUID dans les deux tables cibles des deux bases.
- Geometrie cible: `LINESTRING`, SRID 26191, dimension 3.
- Toutes les lignes ciblees ont `donnees_legacy` renseigne.
- Les 998 `fid` de `SRM_bureau.ep.ep_conduite` sont presents dans `SRM_bureau.ep.ep_conduite_bureau`.
- Les lignes `mobile` importees depuis `SRM` sont identiques dans `SRM_bureau` par hash de contenu hors `fid`, `geom` binaire et `updated_at`.
- `updated_at` a ete remis a l'heure de migration par les triggers `set_updated_at()`; l'ancienne valeur reste conservee dans `date_creation`, `date_modif` et `donnees_legacy`.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

Point d'attention:

- La table source `SRM_bureau.ep.ep_conduite` peut etre neutralisee/droppee apres validation metier finale, mais elle n'a pas ete supprimee dans ce passage.

## Alignement et migration EP - BF, branchements particuliers et compteurs - 2026-05-05

Bloc traite:

- `ep.ep_bf`
- `ep.ep_brc_pt`
- `ep.ep_compteur_i`

Sources SRM:

- `SRM.ep.borne_fontaine` -> `ep.ep_bf`
- `SRM.ep.compteur_abonne` -> `ep.ep_brc_pt`
- `SRM.ep.compteur_reseau` -> `ep.ep_compteur_i`

Backup avant modification:

- `backups/postgres/ep_bf_brc_compteurs_before_migration_20260505_083404/SRM_ep_bf_brc_compteurs_before_migration_pg16_compat.sql`
- `backups/postgres/ep_bf_brc_compteurs_before_migration_20260505_083404/SRM_bureau_ep_bf_brc_compteurs_before_migration_pg16_compat.sql`
- `backups/postgres/ep_bf_brc_compteurs_before_migration_20260505_083404/SRM_ep_bf_brc_compteurs_before_migration.backup`
- `backups/postgres/ep_bf_brc_compteurs_before_migration_20260505_083404/SRM_bureau_ep_bf_brc_compteurs_before_migration.backup`

Actions structurelles:

- Ajout des colonnes de tracabilite sur les trois tables:
  - `legacy_source_table text`
  - `legacy_source_fid integer`
  - `donnees_legacy jsonb`
- Correction de `attribut_config_mobile.ep_brc_pt.ep_coor_Z` vers `ep_coor_z`.
- Ajout physique de `ep_brc_pt.type_anomalie`.
- Ajout physique de `ep_compteur_i.altitude`, avec conservation de l'ancienne colonne `altitute`.
- Correction de `ep_bf.mat_brts` de `int4` vers `varchar(400)`, car la liste de choix EP contient des valeurs texte comme `PEHD`.
- `public.attribut_config_mobile` reflete maintenant toutes les colonnes physiques des trois tables dans les deux bases.

Regle de migration:

- Dans `SRM`, les anciennes sources ont ete inserees dans les tables cibles vides en conservant les `fid`.
- Dans `SRM_bureau`, les lignes deja presentes ont ete marquees `source = web`.
- Les lignes SRM ont ete ajoutees dans `SRM_bureau` avec `source = mobile` et de nouveaux `fid`.
- Les champs non mappes directement restent conserves dans `donnees_legacy`.
- Les colonnes `photo_1..photo_4` sont vides dans les sources et les cibles; aucune ligne `public.objet_photo` supplementaire n'a ete creee.

Etat final:

- `SRM.ep.ep_bf`: 79 lignes `mobile`.
- `SRM_bureau.ep.ep_bf`: 463 lignes = 384 `web` + 79 `mobile`.
- `SRM.ep.ep_brc_pt`: 1240 lignes `mobile`.
- `SRM_bureau.ep.ep_brc_pt`: 2553 lignes = 1313 `web` + 1240 `mobile`.
- `SRM.ep.ep_compteur_i`: 22 lignes `mobile`.
- `SRM_bureau.ep.ep_compteur_i`: 46 lignes = 24 `web` + 22 `mobile`.

Verifications:

- Structures physiques identiques entre `SRM` et `SRM_bureau` pour les trois tables.
- Configurations `attribut_config_mobile` identiques entre `SRM` et `SRM_bureau`.
- 0 colonne physique absente de `attribut_config_mobile`.
- 0 champ config absent physiquement.
- 0 doublon de champ dans la config.
- 0 UUID nul et 0 doublon UUID dans les trois tables cibles des deux bases.
- Geometrie cible: `POINT`, SRID 26191, dimension 3.
- `ep_bf` et `ep_brc_pt`: 0 geometrie nulle.
- `ep_compteur_i`: 1 geometrie nulle, heritee de `SRM.ep.compteur_reseau`; elle n'a pas ete inventee.
- Les lignes `mobile` sont identiques entre `SRM` et `SRM_bureau` par hash de contenu hors `fid`.
- `ep_bf.mat_brts = PEHD` restaure pour 56 lignes mobiles dans les deux bases.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

Point d'attention:

- Les anciennes sources `borne_fontaine`, `compteur_abonne` et `compteur_reseau` restent conservees temporairement dans `SRM` jusqu'a validation metier finale avant neutralisation/drop.

## Alignement et migration EP - branchements, centres tampon, noeuds et hydrants - 2026-05-05

Bloc traite:

- `ep.ep_branchement`
- `ep.ep_centre_tampon`
- `ep.ep_noeud`
- `ep.ep_hydrant`

Sources SRM:

- `SRM.ep.branchement` -> `ep.ep_branchement`
- `SRM.ep.centre_tampon` -> `ep.ep_centre_tampon`
- `SRM.ep.noeud` -> `ep.ep_noeud`
- `SRM.ep.hydrant` -> `ep.ep_hydrant`

Backup avant modification:

- `backups/postgres/ep_branch_tampon_noeud_hydrant_before_migration_20260505_084623/SRM_ep_branch_tampon_noeud_hydrant_before_migration_pg16_compat.sql`
- `backups/postgres/ep_branch_tampon_noeud_hydrant_before_migration_20260505_084623/SRM_bureau_ep_branch_tampon_noeud_hydrant_before_migration_pg16_compat.sql`
- `backups/postgres/ep_branch_tampon_noeud_hydrant_before_migration_20260505_084623/SRM_ep_branch_tampon_noeud_hydrant_before_migration.backup`
- `backups/postgres/ep_branch_tampon_noeud_hydrant_before_migration_20260505_084623/SRM_bureau_ep_branch_tampon_noeud_hydrant_before_migration.backup`

Actions structurelles:

- Ajout des colonnes de tracabilite sur les quatre tables:
  - `legacy_source_table text`
  - `legacy_source_fid integer`
  - `donnees_legacy jsonb`
- Ajout de `source text` sur `ep_centre_tampon`.
- Ajout de `altitude float8` sur `ep_noeud`, en conservant la colonne existante `altitute`.
- Correction de la geometrie de `ep_centre_tampon` vers `geometry(PointZ, 26191)` dans les deux bases.
- `public.attribut_config_mobile` reflete maintenant toutes les colonnes physiques des quatre tables dans les deux bases.

Regle de migration:

- Dans `SRM`, les anciennes sources ont ete inserees dans les tables cibles vides en conservant les `fid`.
- Dans `SRM_bureau`, les lignes SRM ont ete copiees dans les tables cibles, egalement avec les memes `fid`, car aucune ligne cible bureau n'existait pour ce bloc.
- `source = mobile` pour toutes les lignes migrees.
- Les champs non mappes directement restent conserves dans `donnees_legacy`.
- Les colonnes `photo_1..photo_4` sont vides dans les sources et les cibles; aucune ligne `public.objet_photo` supplementaire n'a ete creee.
- Les UUID source avec accolades `{...}` ont ete convertis proprement vers le type UUID quand la table cible l'exigeait.

Etat final:

- `SRM.ep.ep_branchement`: 199 lignes `mobile`.
- `SRM_bureau.ep.ep_branchement`: 199 lignes `mobile`.
- `SRM.ep.ep_centre_tampon`: 946 lignes `mobile`.
- `SRM_bureau.ep.ep_centre_tampon`: 946 lignes `mobile`.
- `SRM.ep.ep_noeud`: 232 lignes `mobile`.
- `SRM_bureau.ep.ep_noeud`: 232 lignes `mobile`.
- `SRM.ep.ep_hydrant`: 12 lignes `mobile`.
- `SRM_bureau.ep.ep_hydrant`: 12 lignes `mobile`.

Verifications:

- Structures physiques identiques entre `SRM` et `SRM_bureau` pour les quatre tables.
- Configurations `attribut_config_mobile` identiques entre `SRM` et `SRM_bureau`.
- 0 colonne physique absente de `attribut_config_mobile`.
- 0 champ config absent physiquement.
- 0 UUID nul et 0 doublon UUID dans les quatre tables cibles des deux bases.
- Geometries:
  - `ep_branchement`: `LINESTRING`, SRID 26191, dimension 3.
  - `ep_centre_tampon`: `POINT`, SRID 26191, dimension 3.
  - `ep_noeud`: `POINT`, SRID 26191, dimension 3.
  - `ep_hydrant`: `POINT`, SRID 26191, dimension 3.
- `ep_branchement`, `ep_centre_tampon`, `ep_noeud`: 0 geometrie nulle.
- `ep_hydrant`: 7 geometries nulles, heritees de `SRM.ep.hydrant`; elles n'ont pas ete inventees.
- Les lignes `mobile` sont identiques entre `SRM` et `SRM_bureau` par hash de contenu hors `fid`.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

Point d'attention:

- Les anciennes sources `branchement`, `centre_tampon`, `noeud` et `hydrant` restent conservees temporairement dans `SRM` jusqu'a validation metier finale avant neutralisation/drop.

## Alignement et migration EP - petits objets avec donnees SRM - 2026-05-05

Bloc traite:

- `ep.ep_forage`
- `ep.ep_pompe`
- `ep.ep_reduc_pres`
- `ep.ep_reservoir`
- `ep.ep_station_pompage`
- `ep.ep_traversee`

Sources SRM:

- `SRM.ep.forage` -> `ep.ep_forage`
- `SRM.ep.pompe` -> `ep.ep_pompe`
- `SRM.ep.reducteur_de_pression` -> `ep.ep_reduc_pres`
- `SRM.ep.reservoir` -> `ep.ep_reservoir`
- `SRM.ep.station_de_pompage` -> `ep.ep_station_pompage`
- `SRM.ep.traverse` -> `ep.ep_traversee`

Backup avant modification:

- `backups/postgres/ep_small_objects_before_migration_20260505_090427/SRM_ep_small_objects_before_migration_pg16_compat.sql`
- `backups/postgres/ep_small_objects_before_migration_20260505_090427/SRM_bureau_ep_small_objects_before_migration_pg16_compat.sql`
- `backups/postgres/ep_small_objects_before_migration_20260505_090427/SRM_ep_small_objects_before_migration.backup`
- `backups/postgres/ep_small_objects_before_migration_20260505_090427/SRM_bureau_ep_small_objects_before_migration.backup`

Actions structurelles:

- Ajout des colonnes de tracabilite sur les six tables:
  - `legacy_source_table text`
  - `legacy_source_fid integer`
  - `donnees_legacy jsonb`
- Ajout de `altitude float8` sur les tables ou la configuration cible contenait deja `altitude`:
  - `ep_forage`
  - `ep_pompe`
  - `ep_reduc_pres`
  - `ep_reservoir`
  - `ep_station_pompage`
- Conservation des colonnes existantes `altitute` pour compatibilite et non-perte.
- `public.attribut_config_mobile` reflete maintenant toutes les colonnes physiques des six tables dans les deux bases.

Regle de migration:

- Dans `SRM`, les anciennes sources ont ete inserees dans les tables cibles vides en conservant les `fid`.
- Dans `SRM_bureau`, les lignes SRM ont ete copiees dans les tables cibles, egalement avec les memes `fid`, car aucune ligne cible bureau n'existait pour ce bloc.
- `source = mobile` pour toutes les lignes migrees.
- Les champs non mappes directement restent conserves dans `donnees_legacy`.
- Les colonnes `photo_1..photo_4` et `ep_photo` sont vides dans les sources et les cibles; aucune ligne `public.objet_photo` supplementaire n'a ete creee.

Etat final:

- `SRM.ep.ep_forage`: 2 lignes `mobile`.
- `SRM_bureau.ep.ep_forage`: 2 lignes `mobile`.
- `SRM.ep.ep_pompe`: 1 ligne `mobile`.
- `SRM_bureau.ep.ep_pompe`: 1 ligne `mobile`.
- `SRM.ep.ep_reduc_pres`: 1 ligne `mobile`.
- `SRM_bureau.ep.ep_reduc_pres`: 1 ligne `mobile`.
- `SRM.ep.ep_reservoir`: 11 lignes `mobile`.
- `SRM_bureau.ep.ep_reservoir`: 11 lignes `mobile`.
- `SRM.ep.ep_station_pompage`: 5 lignes `mobile`.
- `SRM_bureau.ep.ep_station_pompage`: 5 lignes `mobile`.
- `SRM.ep.ep_traversee`: 20 lignes `mobile`.
- `SRM_bureau.ep.ep_traversee`: 20 lignes `mobile`.

Verifications:

- Structures physiques identiques entre `SRM` et `SRM_bureau` pour les six tables.
- Configurations `attribut_config_mobile` identiques entre `SRM` et `SRM_bureau`.
- 0 colonne physique absente de `attribut_config_mobile`.
- 0 champ config absent physiquement.
- 0 UUID nul et 0 doublon UUID dans les six tables cibles des deux bases.
- 0 geometrie nulle.
- Geometries:
  - `ep_forage`, `ep_pompe`, `ep_reduc_pres`, `ep_reservoir`, `ep_station_pompage`: `POINT`, SRID 26191, dimension 3.
  - `ep_traversee`: `LINESTRING`, SRID 26191, dimension 3.
- Les lignes `mobile` sont identiques entre `SRM` et `SRM_bureau` par hash de contenu hors `fid`.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

Point d'attention:

- Les anciennes sources `forage`, `pompe`, `reducteur_de_pression`, `reservoir`, `station_de_pompage` et `traverse` restent conservees temporairement dans `SRM` jusqu'a validation metier finale avant neutralisation/drop.

## Verrouillage des tables EP vides - 2026-05-05

Bloc traite:

- `ep.ep_anomalie_conduite`
- `ep.ep_bache`
- `ep.ep_bouche_arro`
- `ep.ep_puit`
- `ep.ep_tn`
- `ep.ep_voie`

Backup avant verrouillage:

- `backups/postgres/ep_empty_tables_before_lock_20260505_090944/SRM_ep_empty_tables_before_lock_pg16_compat.sql`
- `backups/postgres/ep_empty_tables_before_lock_20260505_090944/SRM_bureau_ep_empty_tables_before_lock_pg16_compat.sql`
- `backups/postgres/ep_empty_tables_before_lock_20260505_090944/SRM_ep_empty_tables_before_lock.backup`
- `backups/postgres/ep_empty_tables_before_lock_20260505_090944/SRM_bureau_ep_empty_tables_before_lock.backup`

Objectif:

- Garder ces tables vides, mais verrouiller leur structure pour que les deux bases restent identiques.
- Faire en sorte que `public.attribut_config_mobile` reflete toutes les colonnes physiques existantes.
- Ne pas inventer de donnees.

Actions appliquees:

- Ajout des champs techniques manquants sur les six tables:
  - `source text`
  - `legacy_source_table text`
  - `legacy_source_fid integer`
  - `donnees_legacy jsonb`
- Ajout de `altitude float8` sur:
  - `ep_bache`
  - `ep_puit`
- Conservation des colonnes existantes `altitute` pour compatibilite et non-perte.
- Completion de `public.attribut_config_mobile` pour toutes les colonnes physiques existantes.
- `source` est declaree dans `attribut_config_mobile` avec:
  - `type_champ = text`
  - `visible = false`
  - contrainte: `champ technique: origine fonctionnelle web/mobile`

Geometries:

- `ep_bache`, `ep_bouche_arro`, `ep_puit`: `POINT`, SRID 26191, dimension 3.
- `ep_anomalie_conduite`: `POINT`, SRID 26191, dimension 3.
- `ep_tn`: `POINT`, SRID 26191, dimension 3.
- `ep_voie`: `LINESTRING`, SRID 26191, dimension 3.
- Ces trois derniers types ont ete fixes apres confirmation metier:
  - `ep_anomalie_conduite` et `ep_tn` sont des points;
  - `ep_voie` est un lineaire.

Etat final:

- Les six tables contiennent 0 ligne dans `SRM`.
- Les six tables contiennent 0 ligne dans `SRM_bureau`.
- Structures physiques identiques entre `SRM` et `SRM_bureau`.
- Configurations `attribut_config_mobile` identiques entre `SRM` et `SRM_bureau`.

Verifications:

- 0 colonne physique absente de `attribut_config_mobile`.
- 0 champ config absent physiquement.
- 0 doublon de champ dans la configuration.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

## Rectification `attribut_config_mobile` comme source de verite EP - 2026-05-05

Objectif:

- Corriger les ecarts ou une colonne declaree dans `public.attribut_config_mobile` n'existait pas physiquement.
- Garder `public.attribut_config_mobile` comme contrat de structure mobile.
- Sortir les photos du contrat de structure metier: la source centrale des photos est `public.objet_photo`.

Backup avant correction:

- `backups/postgres/ep_config_source_truth_before_fix_20260505_092453/SRM.ep_config_source_truth_before_fix.pg16.sql`
- `backups/postgres/ep_config_source_truth_before_fix_20260505_092453/SRM_bureau.ep_config_source_truth_before_fix.pg16.sql`
- `backups/postgres/ep_config_source_truth_before_fix_20260505_092453/SRM.ep_config_source_truth_before_fix.backup`
- `backups/postgres/ep_config_source_truth_before_fix_20260505_092453/SRM_bureau.ep_config_source_truth_before_fix.backup`

Tables verifiees et corrigees:

- `ep.ep_regard`
- `ep.ep_vanne`
- `ep.ep_vidange`
- `ep.ep_ventouse`
- `ep.ep_obturateur`
- `ep.ep_cone_reduc`
- `ep.ep_st_demineralisation`

Corrections appliquees dans les deux bases:

- Ajout de `ep_regard."GENRATRICE_SUP" float8`, avec recopie depuis `generatrice_supp` quand la valeur existait.
- Ajout de `altitude float8` sur:
  - `ep_vanne`
  - `ep_obturateur`
  - `ep_cone_reduc`
  - `ep_st_demineralisation`
- Recopie des valeurs existantes de `altitute` vers `altitude`.
- Ajout de `type_anomalie varchar(400)` sur:
  - `ep_vanne`
  - `ep_cone_reduc`
- Passage de `attribut_config_mobile.ep_regard.GENRATRICE_SUP.nullable` a `true`, car les donnees existantes contiennent des valeurs nulles.
- Suppression des champs photo de `public.attribut_config_mobile` pour le metier `ep`:
  - `ep_photo`
  - `photo_1`
  - `photo_2`
  - `photo_3`
  - `photo_4`

Regle photo confirmee:

- Les photos ne doivent plus etre configurees comme colonnes metier mobiles.
- Les uploads et references photo passent par `public.objet_photo`.
- Les anciennes colonnes physiques photo, quand elles existent encore, ne sont plus considerees comme source de verite.

Verifications:

- `SRM.public.attribut_config_mobile` et `SRM_bureau.public.attribut_config_mobile`: 1369 lignes EP chacun, contenu identique.
- Structures physiques des tables configurees EP: identiques entre `SRM` et `SRM_bureau`.
- 0 colonne declaree dans `attribut_config_mobile` absente physiquement pour le metier `ep`.
- 0 doublon `(nom_table, nom_champ)` dans `attribut_config_mobile` pour le metier `ep`.
- 0 ligne photo restante dans `attribut_config_mobile` pour le metier `ep`.
- 0 divergence entre `altitude` et `altitute` lorsque `altitute` contient une valeur.
- 0 divergence entre `"GENRATRICE_SUP"` et `generatrice_supp` lorsque `generatrice_supp` contient une valeur.
- Compteurs conserves:
  - `SRM.ep.ep_regard`: 11 lignes; `SRM_bureau.ep.ep_regard`: 1344 lignes.
  - `SRM.ep.ep_vanne`: 188 lignes; `SRM_bureau.ep.ep_vanne`: 521 lignes.
  - `SRM.ep.ep_vidange`: 96 lignes; `SRM_bureau.ep.ep_vidange`: 302 lignes.
  - `SRM.ep.ep_ventouse`: 128 lignes; `SRM_bureau.ep.ep_ventouse`: 399 lignes.
  - `SRM.ep.ep_obturateur`: 173 lignes; `SRM_bureau.ep.ep_obturateur`: 418 lignes.
  - `SRM.ep.ep_cone_reduc`: 28 lignes; `SRM_bureau.ep.ep_cone_reduc`: 61 lignes.
  - `SRM.ep.ep_st_demineralisation`: 0 ligne; `SRM_bureau.ep.ep_st_demineralisation`: 5 lignes.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

## Ajout des champs techniques/legacy EP dans `attribut_config_mobile` - 2026-05-05

Objectif:

- Couvrir dans `public.attribut_config_mobile` les colonnes physiques encore absentes de la configuration mobile.
- Garder ces colonnes hors formulaire mobile par defaut.
- Conserver leur role de tracabilite/compatibilite sans les utiliser comme source fonctionnelle principale.

Backup avant modification:

- `backups/postgres/attribut_config_ep_legacy_cols_before_add_20260505_093718/SRM.attribut_config_mobile_before_ep_legacy_cols.pg16.sql`
- `backups/postgres/attribut_config_ep_legacy_cols_before_add_20260505_093718/SRM_bureau.attribut_config_mobile_before_ep_legacy_cols.pg16.sql`
- `backups/postgres/attribut_config_ep_legacy_cols_before_add_20260505_093718/SRM.attribut_config_mobile_before_ep_legacy_cols.backup`
- `backups/postgres/attribut_config_ep_legacy_cols_before_add_20260505_093718/SRM_bureau.attribut_config_mobile_before_ep_legacy_cols.backup`

Colonnes ajoutees quand elles existaient physiquement:

- `source`
- `id_zone`
- `province`
- `commune`
- `ep_num`
- `ep_code_ter`

Tables concernees:

- `ep_cone_reduc`
- `ep_obturateur`
- `ep_regard`
- `ep_st_demineralisation`
- `ep_vanne`
- `ep_ventouse`
- `ep_vidange`

Regle appliquee:

- `visible = false` pour toutes les lignes ajoutees.
- `primary_key = false`.
- `foreign_key = false`.
- `nullable` reprend l'etat reel de la colonne physique.
- `type_champ` reprend le type physique.
- `contraintes` explicite le role:
  - `source`: origine fonctionnelle web/mobile.
  - `id_zone`: identifiant zone source conserve pour tracabilite, sans piloter le zoning agent.
  - `province` et `commune`: libelles administratifs source conserves pour tracabilite.
  - `ep_num` et `ep_code_ter`: references legacy conservees pour rapprochement/audit.

Resultat:

- 39 lignes ajoutees dans `SRM.public.attribut_config_mobile`.
- 39 lignes ajoutees dans `SRM_bureau.public.attribut_config_mobile`.
- Les deux configurations EP contiennent maintenant 1408 lignes chacune.
- Les configurations EP sont identiques entre `SRM` et `SRM_bureau`.
- Toutes les lignes ajoutees sont `visible = false`.
- 0 colonne physique demandee sans ligne de configuration.
- 0 colonne declaree dans `attribut_config_mobile` absente physiquement pour le metier `ep`.
- 0 doublon `(nom_table, nom_champ)` dans `attribut_config_mobile` pour le metier `ep`.
- `python manage.py check` avec `srmenv`: OK, 0 issue.

## Cas speciaux/orphelins EP - 2026-05-05

Objectif:

- Traiter les tables EP presentes hors `attribut_config_mobile`.
- Ne pas perdre les donnees existantes.
- Creer la configuration mobile uniquement comme couverture technique, avec `visible = false`.
- Supprimer le doublon physique `ep.planche` apres confirmation que son contenu geographique est couvert par `public.planche`.

Tables traitees:

- `ep.autre_objet`
- `ep.bouche_cles`
- `ep.borne_onep`
- `ep.onep_db`
- `ep.planche`

Etat initial:

- `SRM.ep.autre_objet`: 578 lignes; absente de `SRM_bureau`.
- `SRM.ep.bouche_cles`: 352 lignes; absente de `SRM_bureau`.
- `SRM.ep.borne_onep`: 2 lignes; `SRM_bureau.ep.borne_onep`: 0 ligne.
- `SRM_bureau.ep.onep_db`: 10580 lignes; absente de `SRM`.
- `SRM.ep.planche`: 2204 lignes; `public.planche`: 2204 lignes dans les deux bases.

Backups avant modification:

- Donnees et structures explicites:
  - `backups/postgres/ep_special_orphans_explicit_before_alignment_20260505_094817/SRM.ep_special_orphans_explicit_before_alignment.pg16.sql`
  - `backups/postgres/ep_special_orphans_explicit_before_alignment_20260505_094817/SRM_bureau.ep_special_orphans_explicit_before_alignment.pg16.sql`
  - `backups/postgres/ep_special_orphans_explicit_before_alignment_20260505_094817/SRM.ep_special_orphans_explicit_before_alignment.backup`
  - `backups/postgres/ep_special_orphans_explicit_before_alignment_20260505_094817/SRM_bureau.ep_special_orphans_explicit_before_alignment.backup`
- Definitions des vues metriques et `vw_srm_*` avant reconstruction:
  - `backups/postgres/ep_special_orphans_views_before_alignment_20260505_100149/SRM.metric_view_definitions_before_alignment.sql`
  - `backups/postgres/ep_special_orphans_views_before_alignment_20260505_100149/SRM_bureau.metric_view_definitions_before_alignment.sql`

Actions appliquees:

- Reconstruction temporaire des 18 vues `public.vw_srm_*` / `public.vw_metrics_*` pour liberer les dependances sur les tables EP.
- Creation de `ep.autre_objet` dans `SRM_bureau`, puis copie des 578 lignes depuis `SRM`.
- Creation de `ep.bouche_cles` dans `SRM_bureau`, puis copie des 352 lignes depuis `SRM`.
- Alignement de `ep.borne_onep` dans les deux bases sur une structure commune compatible avec le modele Django et les champs web:
  - conservation des 2 lignes SRM;
  - copie des 2 lignes vers `SRM_bureau`;
  - ajout des champs web de suivi (`id_zone`, `id_user_creat`, `is_deleted`, `is_validated`, etc.).
- Creation de `ep.onep_db` dans `SRM`, puis copie des 10580 lignes depuis `SRM_bureau`.
- Remplacement de `ep.planche` par une vue de compatibilite basee sur `public.planche`:
  - la table physique redondante `ep.planche` est supprimee;
  - `ep.planche` reste disponible comme vue pour ne pas casser les appels backend existants.
- Re-creation des vues metriques et `vw_srm_*`.
- Ajout dans `public.attribut_config_mobile` des tables:
  - `ep / autre_objet`
  - `ep / bouche_cles`
  - `ep / borne_onep`
  - `ep / onep_db`
- Toutes les lignes de configuration ajoutees ont `visible = false`.
- Les colonnes photo `photo_1..photo_4` de `autre_objet` restent hors `attribut_config_mobile`; les photos passent par `public.objet_photo`.

Confirmation `planche`:

- `ep.planche` initial et `public.planche` avaient les memes `numero`.
- Les geometries sont equivalentes apres normalisation `ST_Force2D + ST_Multi`.
- Apres remplacement, `ep.planche` est une vue (`relkind = v`) de 2204 lignes.
- `ep.planche` et `public.planche`: 0 difference geometrique.

Etat final:

- `SRM.ep.autre_objet`: 578 lignes; `SRM_bureau.ep.autre_objet`: 578 lignes.
- `SRM.ep.bouche_cles`: 352 lignes; `SRM_bureau.ep.bouche_cles`: 352 lignes.
- `SRM.ep.borne_onep`: 2 lignes; `SRM_bureau.ep.borne_onep`: 2 lignes.
- `SRM.ep.onep_db`: 10580 lignes; `SRM_bureau.ep.onep_db`: 10580 lignes.
- `SRM.ep.planche`: vue de 2204 lignes; `SRM_bureau.ep.planche`: vue de 2204 lignes.
- Configurations EP:
  - `SRM.public.attribut_config_mobile`: 1481 lignes EP.
  - `SRM_bureau.public.attribut_config_mobile`: 1481 lignes EP.
  - contenu identique entre les deux bases.

Verifications:

- 0 champ visible pour les 4 tables speciales ajoutees dans `attribut_config_mobile`.
- Structures physiques des tables speciales identiques par nom/type entre `SRM` et `SRM_bureau`.
- 0 colonne declaree dans `attribut_config_mobile` absente physiquement pour le metier `ep`.
- 0 doublon `(nom_table, nom_champ)` dans `attribut_config_mobile` pour le metier `ep`.
- Les vues suivantes repondent dans les deux bases:
  - `vw_srm_objet_fact`
  - `vw_srm_objet_dates`
  - `vw_srm_photo_fact`
  - `vw_srm_objet_activity_fact`
  - `vw_metrics_agent_table_day`
  - `vw_metrics_agent_jour`
  - `vw_metrics_agent_semaine`
  - `vw_metrics_agent_mois`
  - `vw_metrics_agent_resume`
- Tests ORM Django sur `SRM`:
  - `EpAutreObjet.objects.count() = 578`
  - `EpBoucheCles.objects.count() = 352`
  - `EpBorneOnep.objects.count() = 2`
  - `EpPlanche.objects.count() = 2204`
- `python manage.py check` avec `srmenv`: OK, 0 issue.

## Suppression definitive de `ep.planche` - 2026-05-05

Decision:

- `ep.planche` ne porte pas de donnees metier EP.
- La couche de decoupage cartographique reste `public.planche`.
- Les objets metier peuvent conserver un champ `id_planche`, mais celui-ci reference le decoupage/cartographie, pas une table metier `ep.planche`.

Actions appliquees:

- Backup de `ep.planche` et `public.planche` avant suppression:
  - `backups/postgres/ep_planche_view_before_drop_20260505_101141/SRM.ep_planche_view_before_drop.pg16.sql`
  - `backups/postgres/ep_planche_view_before_drop_20260505_101141/SRM_bureau.ep_planche_view_before_drop.pg16.sql`
  - `backups/postgres/ep_planche_view_before_drop_20260505_101141/SRM.ep_planche_view_before_drop.backup`
  - `backups/postgres/ep_planche_view_before_drop_20260505_101141/SRM_bureau.ep_planche_view_before_drop.backup`
- Backup des vues metriques avant retrait de la branche `ep.planche`:
  - `backups/postgres/ep_planche_drop_views_20260505_101324/SRM.views_before_ep_planche_drop.sql`
  - `backups/postgres/ep_planche_drop_views_20260505_101324/SRM_bureau.views_before_ep_planche_drop.sql`
- Retrait de la branche `ep.planche` de `public.vw_srm_objet_fact`.
- Reconstruction des vues dependantes.
- Drop de la vue `ep.planche` dans les deux bases.
- Suppression des references applicatives:
  - modele Django `EpPlanche`;
  - serializer `EpPlancheSerializer`;
  - viewset `EpPlancheViewSet`;
  - route `/api/ep/planches/`;
  - mapping mobile `ep/planche -> ep/planches`.

Etat final:

- `ep.planche`: absent dans `SRM`.
- `ep.planche`: absent dans `SRM_bureau`.
- `public.planche`: 2204 lignes dans `SRM`.
- `public.planche`: 2204 lignes dans `SRM_bureau`.
- `attribut_config_mobile` ne contient aucune configuration `ep / planche`.
- `public.vw_srm_objet_fact` ne reference plus `ep.planche`.

Verifications:

- Vues `vw_srm_*` et `vw_metrics_*` recreees et executables.
- `python manage.py check` avec `srmenv`: OK, 0 issue.
- `dart format` via wrapper Codex sur `PPRCollecte_Flutter/lib/services/sync_service.dart`: OK.

## Colonnes de tracabilite `source` et `donnees_legacy`

Role:

- `source`: origine fonctionnelle de la ligne (`mobile`, `web`, ou autre contexte controle selon la table).
- `legacy_source_table`: nom de la table source utilisee lors d'une migration.
- `legacy_source_fid`: identifiant source dans l'ancienne table.
- `donnees_legacy`: snapshot JSONB des champs source non portes directement par la structure cible.

Localisation:

- Ces colonnes sont physiques dans les tables metier `ep` concernees.
- Elles sont aussi declarees dans `public.attribut_config_mobile` avec `visible = false`.
- Elles ne sont pas des champs de saisie mobile.
- Elles servent a garantir la non-perte de donnees et l'audit de migration.

Tables EP avec le bloc complet `source` + `legacy_source_table` + `legacy_source_fid` + `donnees_legacy`:

- `ep_anomalie_conduite`
- `ep_bache`
- `ep_bf`
- `ep_bouche_arro`
- `ep_branchement`
- `ep_brc_pt`
- `ep_centre_tampon`
- `ep_compteur_i`
- `ep_conduite_bureau`
- `ep_conduite_terrain`
- `ep_cone_reduc`
- `ep_forage`
- `ep_hydrant`
- `ep_noeud`
- `ep_obturateur`
- `ep_pompe`
- `ep_puit`
- `ep_reduc_pres`
- `ep_reservoir`
- `ep_station_pompage`
- `ep_tn`
- `ep_traversee`
- `ep_vanne`
- `ep_ventouse`
- `ep_vidange`
- `ep_voie`

Tables avec seulement `source` pour ce bloc:

- `borne_onep`
- `ep_regard`
- `ep_regard_miroir`
- `ep_st_demineralisation`
- `onep_db`

## Resolution partielle des donnees `donnees_legacy` EP - 2026-05-05

Objectif:

- Sortir de `donnees_legacy` les donnees qui correspondent a des colonnes metier claires.
- Ne supprimer aucune donnee du JSON source.
- Ne pas ecraser une colonne cible deja renseignee avec une valeur differente sans arbitrage.
- Creer les colonnes manquantes dans les deux bases et les declarer dans `public.attribut_config_mobile` avec `visible = false`.

Backup avant application:

- `backups/postgres/ep_legacy_resolution_before_apply_20260505_103059/SRM.ep_legacy_resolution_before_apply.pg16.sql`
- `backups/postgres/ep_legacy_resolution_before_apply_20260505_103059/SRM_bureau.ep_legacy_resolution_before_apply.pg16.sql`
- `backups/postgres/ep_legacy_resolution_before_apply_20260505_103059/SRM.ep_legacy_resolution_before_apply.backup`
- `backups/postgres/ep_legacy_resolution_before_apply_20260505_103059/SRM_bureau.ep_legacy_resolution_before_apply.backup`

Mappings valides et appliques quand la colonne cible etait vide:

- `observation` -> `ep_observation`
- `ref_rue` -> `ep_ref_rue`
- `mode de localisation` -> `mode_localisation`
- `id_agent_crea` -> `id_user_creat`
- `ep_etat` -> `ep_etat_s`
- `ep_longueur` -> `ep_long_r`
- `anomalie` -> `ep_anomalie`
- `commune` -> `commune`
- `province` -> `province`
- `id_zone` -> `id_zone`
- `altitute` -> `altitude`
- `updated_at` -> `updated_at`
- `date_leve` -> `date_leve`
- `emplacement` -> `emplacement`
- `ep_interv` -> `ep_interv`
- `ep_code_ter` -> `ep_code_ter`

Normalisation appliquee:

- Les valeurs boolean de `anomalie` sont converties vers `ep_anomalie` en texte metier:
  - `false` -> `Non`
  - `true` -> `Oui`
- Cela garde `ep_anomalie` en `varchar`, afin de permettre d'autres valeurs metier plus tard.

Colonnes creees:

- `SRM`: 35 colonnes creees dans les tables EP concernees.
- `SRM_bureau`: 40 colonnes creees dans les tables EP concernees.
- Les 5 colonnes creees uniquement cote `SRM_bureau` sur `ep_conduite_bureau` ont ensuite ete ajoutees cote `SRM` pour garder les deux structures homogenes:
  - `commune`
  - `province`
  - `id_zone`
  - `ep_interv`
  - `ep_code_ter`

Lignes `attribut_config_mobile`:

- `SRM`: 40 lignes ajoutees au total pour couvrir les nouvelles colonnes EP.
- `SRM_bureau`: 40 lignes ajoutees au total pour couvrir les nouvelles colonnes EP.
- Toutes les lignes creees sont `visible = false`.

Mises a jour de donnees:

- `SRM`: 9696 valeurs copiees depuis `donnees_legacy` vers des colonnes cibles vides, puis normalisation des anomalies boolean creees.
- `SRM_bureau`: 14733 valeurs copiees depuis `donnees_legacy` vers des colonnes cibles vides, puis normalisation des anomalies boolean creees.
- `donnees_legacy` est conserve intact.

Arbitrages restants:

- `mode de localisation` -> `mode_localisation`:
  - Les colonnes cibles contiennent deja `gnss`.
  - Les valeurs legacy contiennent `Leve topo`.
  - Arbitrage valide ensuite: reprendre la valeur legacy `Leve topo`.
- `updated_at` -> `updated_at`:
  - Les tables `ep_conduite_bureau` et `ep_conduite_terrain` avaient deja un `updated_at` renseigne avec une date de migration recente.
  - La valeur legacy contient l'ancienne date source.
  - Arbitrage valide ensuite: reprendre la date legacy.

Application des arbitrages valides:

- Backup complementaire avant arbitrage final:
  - `backups/postgres/ep_legacy_final_arbitrage_before_apply_20260505_103725/SRM.ep_legacy_final_arbitrage_before_apply.pg16.sql`
  - `backups/postgres/ep_legacy_final_arbitrage_before_apply_20260505_103725/SRM_bureau.ep_legacy_final_arbitrage_before_apply.pg16.sql`
  - `backups/postgres/ep_legacy_final_arbitrage_before_apply_20260505_103725/SRM.ep_legacy_final_arbitrage_before_apply.backup`
  - `backups/postgres/ep_legacy_final_arbitrage_before_apply_20260505_103725/SRM_bureau.ep_legacy_final_arbitrage_before_apply.backup`
- Backup des vues avant reconstruction:
  - `backups/postgres/ep_legacy_final_arbitrage_views_20260505_103940/SRM.metric_view_definitions_before_final_legacy_arbitrage.sql`
  - `backups/postgres/ep_legacy_final_arbitrage_views_20260505_103940/SRM_bureau.metric_view_definitions_before_final_legacy_arbitrage.sql`
- `mode_localisation` de `ep_conduite_bureau` et `ep_conduite_terrain` etait physiquement en enum `mode_localisation_enum`, alors que `Leve topo` n'etait pas une valeur autorisee (`gnss`, `dessin`, `georadar` seulement).
- Decision technique appliquee: convertir ces deux colonnes en `varchar(400)` dans les deux bases, puis aligner `attribut_config_mobile`.
- Les vues metriques dependantes ont ete deposees temporairement puis recreees apres changement de type.
- `mode_localisation` a ete remplace par la valeur legacy dans les tables concernees:
  - 2155 lignes modifiees dans `SRM`.
  - 2155 lignes modifiees dans `SRM_bureau`.
- `updated_at` des deux conduites a ete remplace par la date legacy:
  - 1114 lignes modifiees dans `SRM`.
  - 1114 lignes modifiees dans `SRM_bureau`.
- Le trigger `set_updated_at()` des deux conduites a ete temporairement desactive puis reactive, car il remettait automatiquement la date de migration pendant l'update.

Verifications:

- `public.attribut_config_mobile` EP est identique entre `SRM` et `SRM_bureau`: 1521 lignes dans chaque base.
- 0 colonne declaree dans `attribut_config_mobile` absente physiquement.
- Les colonnes physiques des tables configurees EP sont identiques entre les deux bases par nom/type/nullabilite.
- Les colonnes photo restent volontairement hors `attribut_config_mobile`, car la source centrale photo est `public.objet_photo`.
- `anomalie` -> `ep_anomalie`: 0 conflit restant apres normalisation `Oui/Non`.
- `mode de localisation` -> `mode_localisation`: 0 conflit restant.
- `updated_at` conduite -> `updated_at` legacy: 0 conflit restant.
- `mode_localisation` des deux conduites est maintenant `varchar(400)` dans les deux bases.
- Les vues `vw_srm_*` et `vw_metrics_*` ont ete recreees et restent executables.

## Cloture des cles legacy EP restantes - 2026-05-05

Objectif:

- Traiter les dernieres cles utiles encore uniquement presentes dans `donnees_legacy`.
- Garder `donnees_legacy` comme archive/audit, sans suppression.
- Ne pas exposer les colonnes nouvellement creees dans le formulaire mobile.

Backup avant application:

- `backups/postgres/ep_legacy_remaining_before_apply_20260505_105021/SRM.ep_legacy_remaining_before_apply.pg16.sql`
- `backups/postgres/ep_legacy_remaining_before_apply_20260505_105021/SRM_bureau.ep_legacy_remaining_before_apply.pg16.sql`
- `backups/postgres/ep_legacy_remaining_before_apply_20260505_105021/SRM.ep_legacy_remaining_before_apply.backup`
- `backups/postgres/ep_legacy_remaining_before_apply_20260505_105021/SRM_bureau.ep_legacy_remaining_before_apply.backup`

Arbitrages appliques:

- `conformite_plan` -> `ep_conf_plan`.
- La resolution `mode_localisation` suit l'arbitrage precedent:
  - la valeur fonctionnelle cible est `Leve topo`;
  - l'ancienne valeur technique `gnss` reste seulement dans `donnees_legacy` comme trace.
- Les autres cles restantes sont creees physiquement avec `visible = false`.

Colonnes creees dans les deux bases:

- `ep_centre_tampon.mode_localisation`
- `ep_noeud.mode_localisation`
- `ep_bf.diamcond`
- `ep_bf.ep_diam`
- `ep_bf.existence_compteur_global`
- `ep_bf.existence_compteurs_prives`
- `ep_bf.fonctionnelle`
- `ep_bf.nombre_robinets`
- `ep_brc_pt.diametre_calibre_terrain`
- `ep_brc_pt.diametre_conduite`
- `ep_brc_pt.ep_diam`
- `ep_forage.ep_statut`
- `ep_hydrant.ep_diam`
- `ep_hydrant.type_anomalie`
- `ep_traversee.ep_long_c`
- `ep_traversee.ep_type`
- `ep_ventouse.type_anomalie`

Mises a jour:

- `SRM`: 3750 valeurs copiees depuis `donnees_legacy`.
- `SRM_bureau`: 3750 valeurs copiees depuis `donnees_legacy`.
- 17 lignes `attribut_config_mobile` ajoutees dans chaque base.
- Toutes les lignes ajoutees sont `visible = false`.

Verification finale EP:

- 0 cle legacy utile non promue selon le contrat d'alias metier.
- 0 colonne declaree dans `attribut_config_mobile` absente physiquement.
- `public.attribut_config_mobile` EP est identique dans `SRM` et `SRM_bureau`: 1538 lignes.
- Les structures physiques des tables EP configurees sont identiques entre `SRM` et `SRM_bureau`.
- Les donnees brutes de `donnees_legacy` sont conservees uniquement pour audit/non-perte.

## Wrap public + EP et nettoyage des residus - 2026-05-05

Objectif:

- Obtenir les schemas `public` et `ep` identiques entre `SRM` et `SRM_bureau`.
- Supprimer les anciennes tables physiques apres confirmation de couverture par les tables cibles.
- Garder `attribut_config_mobile` comme source de verite pour toutes les tables metier `public` et `ep`.
- Ne perdre aucune donnee: les traces non migrables restent conservees dans l'historique.

Backups avant nettoyage:

- `backups/postgres/public_ep_wrap_before_cleanup_20260505_105725/SRM.public_ep_before_cleanup.pg16_style.sql`
- `backups/postgres/public_ep_wrap_before_cleanup_20260505_105725/SRM_bureau.public_ep_before_cleanup.pg16_style.sql`
- `backups/postgres/public_ep_wrap_before_cleanup_20260505_105725/SRM.public_ep_before_cleanup.backup`
- `backups/postgres/public_ep_wrap_before_cleanup_20260505_105725/SRM_bureau.public_ep_before_cleanup.backup`

Backups techniques des vues et SQL applique:

- `backups/postgres/public_ep_wrap_cleanup_views_20260505_apply/SRM.views_before_cleanup.sql`
- `backups/postgres/public_ep_wrap_cleanup_views_20260505_apply/SRM_bureau.views_before_cleanup.sql`
- `backups/postgres/public_ep_wrap_cleanup_views_20260505_apply/vw_srm_objet_fact_after_cleanup.sql`
- `backups/postgres/public_ep_wrap_cleanup_views_20260505_apply/all_metric_views_canonical_from_SRM.sql`
- `backups/postgres/public_ep_wrap_cleanup_views_20260505_apply/canonical_constraints_public_ep.sql`
- `backups/postgres/public_ep_wrap_cleanup_views_20260505_apply/cleanup_report.tsv`

Nettoyage applique:

- Rebuild canonique des vues `vw_srm_*` et `vw_metrics_*`.
- `vw_srm_objet_fact` ne depend plus des anciennes tables EP; elle pointe vers les tables cible configurees.
- Creation/copie de `public.django_migrations` dans `SRM_bureau` pour aligner le schema `public`.
- Suppression des lignes `elec` dans `public.attribut_config_mobile` et `public.liste_choix`.
- Migration de la FK `ep.bouche_cles.id_compteur_abonne` vers `ep.ep_brc_pt(fid)`.
- Harmonisation des contraintes FK/check restantes entre les deux bases.
- Remapping des pointeurs publics connus:
  - `objet_photo`: anciennes tables EP vers tables cible.
  - `historique_action`: anciennes tables EP mappables vers tables cible.
  - `srm_field_option`: `regard` / `regard_ep` vers `ep_regard`.
  - `attribut_config`: `ep_conduite` vers `ep_conduite_bureau`.

Tables EP physiques supprimees apres couverture par les tables cible:

- Dans `SRM`: `borne_fontaine`, `bouche_darrosage`, `branchement`, `compteur_abonne`, `compteur_reseau`, `cone_de_reduction`, `forage`, `hydrant`, `noeud`, `obturateur`, `pompe`, `puit`, `reducteur_de_pression`, `regard`, `regard_ep`, `regard_miroir`, `reservoir`, `station_de_pompage`, `traverse`, `vanne`, `vanne_de_vidange`, `ventouse`.
- Dans `SRM_bureau`: `anomalie_conduite`, `bouche_a_cles`, `conduite_terrain`, `ep_conduite`, `tn`, `voie`.
- Dans les deux bases: `centre_tampon`, couvert par `ep.ep_centre_tampon`.

Mise a jour `attribut_config_mobile`:

- Ajout des tables statistiques EP:
  - `statistique_conduite`
  - `statistique_conduite_segment`
- Ajout de toutes les colonnes physiques encore absentes de la config, avec `visible = false`.
- Les colonnes `photo_1..photo_4` sont maintenant configurees mais restent masquees; la gestion fonctionnelle des photos reste centralisee dans `public.objet_photo`.

Etat final verifie:

- Objets `public` + `ep`: 0 difference entre `SRM` et `SRM_bureau`.
- Colonnes `public` + `ep`: 0 difference par nom/type/nullabilite/default.
- Contraintes `public` + `ep`: 0 difference.
- Vues `public` + `ep`: 0 difference de definition.
- `attribut_config_mobile` logique pour `public` + `ep`: 0 difference.
- `attribut_config_mobile`: 0 colonne configuree absente physiquement.
- Tables configurees `public` + `ep`: 0 colonne physique absente de la config.
- `elec`: 0 ligne restante dans `attribut_config_mobile`, 0 ligne restante dans `liste_choix`.
- `public.objet_photo`: 0 reference vers une table absente.
- `manage.py check`: OK, 0 issue.

Comptages finaux:

- `attribut_config_mobile`:
  - `ass`: 678 lignes / 23 tables.
  - `ep`: 1698 lignes / 35 tables.
  - `public`: 244 lignes / 22 tables.
- `ep`: 35 tables physiques dans chaque base.
- `vw_srm_objet_fact`:
  - `SRM`: 5451 lignes.
  - `SRM_bureau`: 11929 lignes.
- `vw_srm_photo_fact`:
  - `SRM`: 99 lignes.
  - `SRM_bureau`: 4162 lignes.

Trace historique conservee:

- `SRM_bureau.public.historique_action` conserve 5 lignes d'audit `elec.*` sans table cible active:
  - `elec.depart_hta`: 1 ligne.
  - `elec.poste`: 2 lignes.
  - `elec.transformateur`: 2 lignes.
- Ces lignes ne sont plus liees a une structure active/configuree, mais elles sont conservees pour respecter la regle de non-perte des donnees d'historique.

## Retour aux noms client et backups finaux - 2026-05-05

Objectif:

- Revenir aux noms exacts issus du vocabulaire client/SRM_bureau, meme lorsqu'ils contiennent une faute historique.
- Mettre `public.attribut_config_mobile` en coherence stricte avec les colonnes physiques.
- Supprimer l'historique residuel `elec.*`.
- Produire deux backups finaux complets.

Backup de securite avant renommage:

- `backups/postgres/client_field_names_before_apply_20260505_114102/SRM.public_ep_before_client_field_names.backup`
- `backups/postgres/client_field_names_before_apply_20260505_114102/SRM_bureau.public_ep_before_client_field_names.backup`

Changements de noms annules/revenus au client:

- `altitude` -> `altitute` lorsque les deux colonnes coexistaient.
- `GENRATRICE_SUP` -> `generatrice_supp` sur `ep.ep_regard`.

Tables concernees par `altitude` -> `altitute`:

- `ep.ep_bache`
- `ep.ep_compteur_i`
- `ep.ep_cone_reduc`
- `ep.ep_forage`
- `ep.ep_noeud`
- `ep.ep_obturateur`
- `ep.ep_pompe`
- `ep.ep_puit`
- `ep.ep_reduc_pres`
- `ep.ep_reservoir`
- `ep.ep_st_demineralisation`
- `ep.ep_station_pompage`
- `ep.ep_vanne`

Donnees preservees:

- Avant suppression de `altitude`, les valeurs non nulles ont ete copiees vers `altitute` quand `altitute` etait vide.
- 0 conflit de valeur detecte entre `altitude` et `altitute`.
- `ep.ep_compteur_i`: 19 valeurs copiees dans `SRM` et 19 valeurs copiees dans `SRM_bureau`.
- `GENRATRICE_SUP` et `generatrice_supp`: 0 conflit detecte; aucune valeur additionnelle a copier.

Mise a jour config:

- Les lignes `attribut_config_mobile` des colonnes techniques supprimees ont ete supprimees:
  - `altitude` sur les tables listees ci-dessus.
  - `GENRATRICE_SUP` sur `ep.ep_regard`.
- Les lignes client conservees restent:
  - `altitute`.
  - `generatrice_supp`.
- `public.liste_choix` ne contient plus de reference aux champs supprimes.

Nettoyage historique:

- Suppression de `public.historique_action` pour `nom_table like 'elec.%'`.
- Lignes supprimees:
  - `SRM`: 0.
  - `SRM_bureau`: 5.

Etat final verifie:

- Objets `public` + `ep`: 0 difference entre `SRM` et `SRM_bureau`.
- Colonnes `public` + `ep`: 0 difference.
- Contraintes `public` + `ep`: 0 difference.
- Vues `public` + `ep`: 0 difference.
- `attribut_config_mobile` logique pour `public` + `ep`: 0 difference.
- `attribut_config_mobile`: 0 colonne configuree absente physiquement.
- Tables configurees `public` + `ep`: 0 colonne physique absente de la config.
- Historique `elec.*`: 0 ligne dans les deux bases.
- `python manage.py check` avec `srmenv`: OK, 0 issue.
- Code backend: suppression des references restantes a `GENRATRICE_SUP` dans les modeles Django.

Comptages finaux:

- `attribut_config_mobile`:
  - `ass`: 678 lignes / 23 tables.
  - `ep`: 1684 lignes / 35 tables.
  - `public`: 244 lignes / 22 tables.

Backups finaux complets:

- `backups/postgres/final_SRM_SRM_bureau_public_ep_clean_20260505_114314/SRM.final_public_ep_clean.backup`
- `backups/postgres/final_SRM_SRM_bureau_public_ep_clean_20260505_114314/SRM_bureau.final_public_ep_clean.backup`

Backups finaux compatibles PostgreSQL 16:

- `backups/postgres/final_SRM_SRM_bureau_pg16_compat_20260505_114611/SRM.final_pg16_compat.sql`
- `backups/postgres/final_SRM_SRM_bureau_pg16_compat_20260505_114611/SRM_bureau.final_pg16_compat.sql`

Notes de compatibilite PostgreSQL 16:

- Format SQL texte, a restaurer avec `psql`.
- Suppression de `SET transaction_timeout = 0;`, specifique PostgreSQL 17.
- Suppression des lignes `\restrict` / `\unrestrict`, emises par `pg_dump` 17 et non necessaires pour la restauration PostgreSQL 16.
- Les fichiers `.backup` custom restent des backups locaux PostgreSQL 17; pour PostgreSQL 16, utiliser les fichiers `.sql` ci-dessus.

## Bloc ASS - schema unique `ass`

Objectif:

- Conserver un seul schema metier `ass`.
- Aligner `ass` entre `SRM` et `SRM_bureau`.
- Garder `public.attribut_config_mobile` comme source de verite.
- Ne pas perdre les donnees existantes.
- Ne pas corriger les noms physiques client par preference orthographique; si un nom client est volontaire ou deja livre, la config doit suivre le nom physique.

Backup avant traitement ASS:

- `backups/postgres/ass_pre_wrap_20260505_122144/SRM.ass_pre_wrap.backup`
- `backups/postgres/ass_pre_wrap_20260505_122144/SRM.ass_pre_wrap.pg16.sql`
- `backups/postgres/ass_pre_wrap_20260505_122144/SRM_bureau.ass_pre_wrap.backup`
- `backups/postgres/ass_pre_wrap_20260505_122144/SRM_bureau.ass_pre_wrap.pg16.sql`

Backup final apres traitement ASS:

- `backups/postgres/ass_final_clean_20260505_122735/SRM.ass_final_clean.backup`
- `backups/postgres/ass_final_clean_20260505_122735/SRM.ass_final_clean.pg16.sql`
- `backups/postgres/ass_final_clean_20260505_122735/SRM_bureau.ass_final_clean.backup`
- `backups/postgres/ass_final_clean_20260505_122735/SRM_bureau.ass_final_clean.pg16.sql`

Constat initial:

- `SRM` avait uniquement le schema `ass`, mais contenait encore des tables residuelles `ass.asst_*`.
- `SRM_bureau` avait deux schemas: `ass` et `asst`.
- Le schema `asst` de `SRM_bureau` etait vide.
- Les tables residuelles `ass.asst_*` de `SRM` etaient vides sauf:
  - `ass.asst_branchement`: 1 ligne.
  - `ass.asst_canalisation`: 1 ligne.
  - `ass.asst_ouvrage`: 1 ligne.
  - `ass.asst_regard_branchement`: 1 ligne.

Mappings de preservation des donnees:

- `ass.asst_branchement` -> `ass.branchement`.
- `ass.asst_canalisation` -> `ass.canalisation_terrain`.
- `ass.asst_ouvrage` -> `ass.ouvrage`.
- `ass.asst_regard_branchement` -> `ass.regard_branchement`.

Mappings de colonnes appliques:

- `id_agent_crea` -> `id_user_creat` et `id_user_modif`.
- `updated_at` -> `date_creation` et `date_modif`.
- `uuid varchar` -> `uuid uuid` par cast.
- `id_planche` conserve comme nouvelle colonne cachee.
- `mode_localisation` conserve comme nouvelle colonne cachee.

Changements structurels ASS:

- Ajout de `id_planche integer` sur:
  - `ass.branchement`
  - `ass.canalisation_terrain`
  - `ass.ouvrage`
  - `ass.regard_branchement`
- Ajout de `mode_localisation public.mode_localisation_enum default 'gnss'` sur les memes tables.
- Ajout des lignes correspondantes dans `public.attribut_config_mobile` avec `visible=false`.
- Passage de `emplacement` en nullable sur:
  - `ass.branchement`
  - `ass.canalisation_terrain`
  - `ass.regard_branchement`
- Mise a jour de `attribut_config_mobile.nullable=true` pour ces champs `emplacement`.
- Ajout de la config cachee pour:
  - `ass.statistique_conduite`
  - `ass.statistique_conduite_segment`

Nettoyage applique:

- Migration des 4 lignes residuelles de `SRM` vers leurs tables cibles.
- Recopie des 4 lignes migrees vers `SRM_bureau`.
- Suppression des anciennes tables `ass.asst_*` dans `SRM`.
- Suppression du schema vide `asst` dans `SRM_bureau`.

Etat verifie apres traitement:

- Schemas presents:
  - `SRM`: `ass`.
  - `SRM_bureau`: `ass`.
- Tables `ass`: 25 dans chaque base.
- Colonnes `ass`: 703 dans chaque base, 0 difference.
- `attribut_config_mobile` pour `ass`: 703 lignes dans chaque base, 0 difference.
- Couverture config/physique: 0 colonne configuree absente physiquement, 0 colonne physique absente de la config.
- Comptages preserves:
  - `ass.branchement`: 1 ligne dans chaque base.
  - `ass.canalisation_terrain`: 1 ligne dans chaque base.
  - `ass.ouvrage`: 1 ligne dans chaque base.
  - `ass.regard_branchement`: 1 ligne dans chaque base.
  - `ass.statistique_conduite`: 0 ligne.
  - `ass.statistique_conduite_segment`: 0 ligne.

Point a clarifier:

- La config actuelle contient 25 tables `ass` apres ajout des deux tables statistiques.
- Parmi elles, 13 tables sont prefixees `ass_*`.
- La mention fonctionnelle "14 tables ASS utiles" doit encore etre reconciliee avec la liste physique/config actuelle avant de masquer ou reclasser d'autres tables visibles.

## Bloc ASS - cadrage des 14 tables utiles

Decision fonctionnelle:

- Le metier assainissement doit s'appuyer sur 14 tables utiles.
- On garde un seul schema physique: `ass`.
- Les anciennes references `asst."ASS_*"` sont traduites vers des tables `ass.ass_*`.
- Les autres tables ASS restent conservees si elles portent ou peuvent porter des donnees, mais elles sont masquees dans `attribut_config_mobile` (`visible=false`).

Mapping retenu:

| # | Nom UI | Ancienne reference | Table unique actuelle |
| ---: | --- | --- | --- |
| 1 | Regards de visite | `asst."ASS_REGARD"` | `ass.ass_regard` |
| 2 | Regards Facade | `asst."ASS_REGARD_FACADE"` | `ass.ass_regard_facade` |
| 3 | Regards Borgnes | `asst."ASS_BORGNE"` | `ass.ass_borgne` |
| 4 | Bouches d'egout | `asst."ASS_BOUCHE"` | `ass.ass_bouche` |
| 5 | Deversoirs d'orage | `asst."ASS_DEVERSOIR"` | `ass.ass_deversoir` |
| 6 | Exutoires | `asst."ASS__EXUTOIRE"` | `ass.ass_exutoire` |
| 7 | Stations de pompage | `asst."ASS_STA_POMP"` | `ass.ass_sta_pomp` |
| 8 | Collecteurs | `asst."ASS_COLLECTEUR"` | `ass.ass_collecteur` |
| 9 | Branchements collecteur | `asst."ASS_BRANCHEMENT"` | `ass.ass_branchement` |
| 10 | Caniveaux | `asst."ASS_CANIVEAU"` | `ass.ass_caniveau` |
| 11 | Caniveau branchement | `asst."ASS_CANIV_BRANCHE"` | `ass.ass_caniv_branche` |
| 12 | Collecteur bouche d'egout | `asst."ASS_COL_BOUCHE"` | `ass.ass_col_bouche` |
| 13 | Bassins versants | `asst."ASS_BASSIN_VERSANT"` | `ass.ass_bassin_versant` |
| 14 | Stations d'epuration | `asst."ASS_STA_EPUR"` | `ass.ass_sta_epur` |

Changements appliques:

- Creation de `ass.ass_bassin_versant` dans `SRM` et `SRM_bureau`.
- Structure reprise depuis l'ancien `asst."ASS_BASSIN_VERSANT"` du backup pre-nettoyage.
- Utilisation de `public.gen_random_uuid()` comme default UUID commun aux deux bases.
- Ajout de 31 lignes `attribut_config_mobile` pour `ass.ass_bassin_versant`, toutes en `visible=false` en attendant un parametrage UI explicite.
- Passage de toutes les tables ASS hors liste utile a `visible=false` dans `attribut_config_mobile`.

Etat verifie:

- Schemas presents:
  - `SRM`: `ass`.
  - `SRM_bureau`: `ass`.
- Tables `ass`: 26 dans chaque base.
- Tables utiles presentes: 14/14 dans chaque base.
- `attribut_config_mobile` pour `ass`: 734 lignes / 26 tables dans chaque base.
- Colonnes `ass`: 734 dans chaque base, 0 difference.
- Config ASS: 734 lignes dans chaque base, 0 difference.
- Couverture config/physique: 0 ecart.
- Tables hors perimetre utile avec champs visibles: 0.

Backups ASS 14 tables:

- Avant cadrage 14 tables:
  - `backups/postgres/ass_14_tables_pre_20260505_123156/SRM.ass_14_tables_pre.backup`
  - `backups/postgres/ass_14_tables_pre_20260505_123156/SRM.ass_14_tables_pre.pg16.sql`
  - `backups/postgres/ass_14_tables_pre_20260505_123156/SRM_bureau.ass_14_tables_pre.backup`
  - `backups/postgres/ass_14_tables_pre_20260505_123156/SRM_bureau.ass_14_tables_pre.pg16.sql`
- Apres cadrage 14 tables:
  - `backups/postgres/ass_14_tables_final_20260505_123444/SRM.ass_14_tables_final.backup`
  - `backups/postgres/ass_14_tables_final_20260505_123444/SRM.ass_14_tables_final.pg16.sql`
  - `backups/postgres/ass_14_tables_final_20260505_123444/SRM_bureau.ass_14_tables_final.backup`
  - `backups/postgres/ass_14_tables_final_20260505_123444/SRM_bureau.ass_14_tables_final.pg16.sql`

## Fusion controlee des donnees vers `SRM_bureau`

Decision:

- `SRM_bureau` reste la base prioritaire et future base projet.
- On ne reecrit pas les FID de `SRM_bureau`.
- La fusion se fait par cle logique (`uuid` metier quand disponible), pas par `fid`.
- Les tables historiques ne sont pas fusionnees en bloc, car leurs `id_objet` peuvent pointer vers les anciens FID de `SRM` et produire des doublons trompeurs.

Audit avant fusion:

- Les grosses tables EP de `SRM` sont deja presentes dans `SRM_bureau` par `uuid`.
- Les differences communes EP observees sont principalement des differences de `fid`, pas des attributs metier.
- Tables operationnelles absentes de `SRM_bureau`:
  - `public.sync_session`: 1 session.
  - `public.sync_session_item`: 1 item.
- Photos centrales:
  - `public.objet_photo`: 99 references logiques de `SRM` absentes de `SRM_bureau`.
  - Les IDs numeriques `id_photo` ne sont pas fiables pour fusionner, car deja reutilises differemment.

Fusion appliquee vers `SRM_bureau`:

- Insertion de 99 lignes `public.objet_photo` depuis `SRM`, avec nouveaux `id_photo`.
- Insertion de 1 ligne `public.sync_session` depuis `SRM`.
- Insertion de 1 ligne `public.sync_session_item` depuis `SRM`.
- Recalage de `sync_session_item.response_pk` sur le `fid` de `SRM_bureau` pour `ep.ep_conduite_terrain:e216b312-ef9a-4593-886f-2f0c0b04cc8e`.

Verification apres fusion:

- `sync_session` par `sync_uuid`: 0 element de `SRM` absent de `SRM_bureau`.
- `sync_session_item` par `client_item_uuid`: 0 element de `SRM` absent de `SRM_bureau`.
- `objet_photo` par cle logique normalisee (`uuid_objet`, schema, table, slot, chemin, hash): 0 element de `SRM` absent de `SRM_bureau`.
- Comptages:
  - `SRM.public.objet_photo`: 99.
  - `SRM_bureau.public.objet_photo`: 4261.
  - `SRM.public.sync_session`: 1.
  - `SRM_bureau.public.sync_session`: 1.
  - `SRM.public.sync_session_item`: 1.
  - `SRM_bureau.public.sync_session_item`: 1.

Backups fusion donnees:

- Avant fusion:
  - `backups/postgres/data_fusion_pre_20260505_124222/SRM.data_fusion_pre.backup`
  - `backups/postgres/data_fusion_pre_20260505_124222/SRM.data_fusion_pre.pg16.sql`
  - `backups/postgres/data_fusion_pre_20260505_124222/SRM_bureau.data_fusion_pre.backup`
  - `backups/postgres/data_fusion_pre_20260505_124222/SRM_bureau.data_fusion_pre.pg16.sql`
- Apres fusion:
  - `backups/postgres/data_fusion_final_20260505_124404/SRM.data_fusion_final.backup`
  - `backups/postgres/data_fusion_final_20260505_124404/SRM.data_fusion_final.pg16.sql`
  - `backups/postgres/data_fusion_final_20260505_124404/SRM_bureau.data_fusion_final.backup`
  - `backups/postgres/data_fusion_final_20260505_124404/SRM_bureau.data_fusion_final.pg16.sql`

Conclusion:

- `SRM_bureau` contient maintenant la structure/config commune et les donnees utiles detectees dans `SRM`.
- `SRM` et `SRM_bureau` ne sont pas des clones stricts au niveau contenu: `SRM_bureau` garde davantage de donnees metier et ses propres FID.
- La base cible pour le projet est donc `SRM_bureau`, pas une egalite brute par dump entre les deux bases.

## Backups finaux apres bascule vers `SRM_bureau`

Etat applicatif:

- Le backend Django pointe maintenant vers `SRM_bureau` via `API_GeoDjango/pprcollecte/.env`.
- Verification Django:
  - `manage.py check`: OK.
  - `current_database()`: `SRM_bureau`.

Backups finaux:

- `backups/postgres/final_two_databases_20260505_124717/SRM.final.backup`
- `backups/postgres/final_two_databases_20260505_124717/SRM_bureau.final.backup`

SQL finaux compatibles PostgreSQL 16:

- `backups/postgres/final_two_databases_20260505_124717/SRM.final.pg16_compatible.sql`
- `backups/postgres/final_two_databases_20260505_124717/SRM_bureau.final.pg16_compatible.sql`

Verification compatibilite SQL:

- Suppression de `SET transaction_timeout = 0;`.
- Suppression de `\restrict`.
- Suppression de `\unrestrict`.
- Verification finale: 0 occurrence restante de ces directives dans les deux fichiers SQL.

## Correctif API mobile apres bascule `SRM_bureau`

Constat:

- Le mobile ne reference plus le metier electricite, mais certains endpoints EP/ASS du backend pointaient encore vers les anciennes tables Django (`ep.vanne`, `ass.asst_ouvrage`, etc.).
- Depuis `SRM_bureau`, ces anciennes tables ne sont plus les tables physiques ciblees, ce qui provoquait des erreurs 500 pendant le telechargement mobile.

Correctif applique:

- Ajout d'une couche de routes mobiles EP/ASS qui conserve les URLs consommees par l'application, mais lit les tables physiques existantes de `SRM_bureau`.
- Neutralisation des routes API electricite dans `api/urls.py`.
- Exemple de mapping:
  - `/api/ep/vannes/` -> `ep.ep_vanne`.
  - `/api/ep/vannes-vidange/` -> `ep.ep_vidange`.
  - `/api/ass/ouvrages/` -> `ass.ouvrage`.
  - `/api/ass/equipements/` -> `ass.equipement`.

Verification:

- `manage.py check`: OK.
- Tous les endpoints mobiles EP/ASS verifies repondent en `200`.
- Aucun endpoint mobile EP/ASS teste ne retourne une erreur 500 de type `relation does not exist`.

## Affectation zones pour basemaps offline

Constat:

- Le flux basemap offline filtre les zones par `public.zone_utilisateur`.
- Les comptes `nada` et `anasd@etafat.ma` existaient, mais n'avaient aucune zone active affectee.

Action appliquee sur `SRM_bureau`:

- Affectation/activation de toutes les zones actives du projet pour:
  - `nada` (`id_user = 2`).
  - `anasd@etafat.ma` (`id_user = 4`).

Verification:

- Zones actives projet: 21.
- `nada`: 21 zones actives affectees.
- `anasd@etafat.ma`: 21 zones actives affectees.
- `/api/basemaps/catalog/?id_user=2&active_only=true`: 21 zones.
- `/api/basemaps/catalog/?id_user=4&active_only=true`: 21 zones.
- `public.basemap_package` est encore vide; le premier appel `/api/basemaps/prepare-agent/` doit donc generer les packages serveur par zone avant leur telechargement mobile.

## Verrouillage structure mobile SQLite

Constat:

- `public.attribut_config_mobile` couvre toutes les tables physiques de `public`, `ep` et `ass`, hors tables systeme ignorees (`public.django_migrations`, `public.spatial_ref_sys`).
- Controle effectue sur `SRM_bureau`: `missing_count = 0`, `extra_count = 0`.
- Le mobile ajoutait encore automatiquement des colonnes SQLite sur les tables miroir via `ALTER TABLE ... ADD COLUMN`.

Correctif applique:

- Suppression du pouvoir d'ajout automatique de colonnes sur les tables miroir SRM cote mobile.
- Les tables SQLite neuves sont creees avec la structure connue; une table locale existante mais obsolete provoque maintenant une erreur explicite de structure incompatible.
- Le flux `objet_incomplet`, `intervention_anomalie`, les tables metier EP/ASS et les queues locales ne font plus de `ALTER TABLE ... ADD COLUMN` automatique.

Verification:

- Recherche mobile: 0 occurrence restante de `ALTER TABLE ... ADD COLUMN` dans `PPRCollecte_Flutter/lib`.
- Recherche mobile: 0 occurrence restante de `ALTER TABLE` dans `PPRCollecte_Flutter/lib`.
- La migration locale `line_storage_helper.dart` a ete reecrite sans `ALTER TABLE`, via copie temporaire transactionnelle puis recreation controlee.
- `dart format lib\data\local\database_helper.dart`: OK.
- `dart format lib\data\local\line_storage_helper.dart`: OK.
- `flutter analyze lib\data\local\database_helper.dart lib\data\local\line_storage_helper.dart`: OK.
