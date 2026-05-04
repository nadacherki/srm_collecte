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
