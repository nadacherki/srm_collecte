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

Uniquement dans `SRM`:

Uniquement dans `SRM_bureau`:  `attribut_config_mobile`,

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

Colonnes ambiguës:

- `id_objet`: reference dynamique vers un objet metier, dependante de `nom_classe`; pas de FK directe declaree dans `attribut_config_mobile`.
- `nom_classe`: aucune liste de choix ajoutee; la valeur observee est `ep_regard`, mais la figer comme choix serait trop restrictif pour un placeholder.

Verification:

- `SRM_bureau.public.attribut_config_mobile`: 20 lignes pour `public.intervention_anomalie`.
- `SRM_bureau.public.liste_choix`: 10 lignes pour `public.intervention_anomalie`.
- Aucun `?` introduit dans les alias ou valeurs de ces choix.

### Migration `ep` vers la structure VF

Statut: applique sur `SRM_bureau` uniquement.

Decision:

- VF devient la reference de structure pour le schema `ep`.
- Les colonnes deja presentes dans `SRM_bureau` sont conservees sauf:
  - `donnees_legacy`
  - `legacy_source_fid`
  - `legacy_source_table`
- Les colonnes restaurees depuis VF et absentes de la configuration mobile sont ajoutees dans `public.attribut_config_mobile` avec `visible = false`.
- Exception regard:
  - `ep.ep_regard` est maintenant la table polygonale.
  - `ep.ep_regard_point` est maintenant la table point remplie par le mobile.
  - `ep.ep_regard_miroir` n'est plus une table finale.

Renommages principaux:

- `ep.bouche_cles` -> `ep.bouche_a_cles`
- `ep.ep_anomalie_conduite` -> `ep.anomalie_conduite`
- `ep.ep_centre_tampon` -> `ep.centre_tampon`
- `ep.ep_conduite_bureau` -> `ep.ep_conduite`
- `ep.ep_conduite_terrain` -> `ep.conduite_terrain`
- `ep.ep_tn` -> `ep.tn`
- `ep.ep_voie` -> `ep.voie`
- `ep.ep_regard` -> `ep.ep_regard_point`
- `ep.ep_regard_miroir` -> `ep.ep_regard`

Verification:

- Tables finales `ep`: 35.
- `ep.ep_regard`: `POLYGON`, 1344 lignes.
- `ep.ep_regard_point`: `POINT`, 1344 lignes.
- Colonnes communes avec VF: 0 ecart de type/default/nullabilite.
- Colonnes `donnees_legacy`, `legacy_source_fid`, `legacy_source_table`: absentes.
- Toutes les colonnes physiques `ep` ont une ligne dans `public.attribut_config_mobile`.
- Vues `public.vw_*` recreees: 18.

Backups:

- Avant migration: `backups/postgres/pre_restore_ep_from_vf_20260506_103927`
- Apres migration: `backups/postgres/post_ep_vf_migration_srm_bureau_20260506_110651`

### Adoption du schema `asst` VF

Statut: applique sur `SRM_bureau` uniquement.

Decision:

- Le schema `ass` de `SRM_bureau` est abandonne.
- Le schema `asst` de la VF legacy devient la reference assainissement.
- La structure `asst` a ete importee depuis la VF dans `SRM_bureau`.
- Les anciennes 4 lignes presentes dans `ass` ont ete conservees dans le backup avant suppression.

Etat BD apres operation:

- `ass`: absent.
- `asst`: 26 tables, 26 tables geometriques, 26 sequences.
- `public.attribut_config_mobile`: 26 tables `asst`, 1377 champs, tous reinseres depuis la structure physique `asst`.
- Les anciennes lignes `nom_metier = 'ass'` ont ete supprimees de `public.attribut_config_mobile`.
- Les vues `public.vw_srm_*` et `public.vw_metrics_*` ont ete recreees sur `ep` + `asst`.

Adaptations code:

- Backend Django:
  - endpoints mobiles `/api/ass/.../` conserves comme routes applicatives stables;
  - mapping serveur vers les tables physiques `asst."ASS_*"`;
  - alias d'entree/sortie ajoutes pour accepter une partie des anciens champs mobiles en minuscules vers les colonnes VF en majuscules;
  - migration d'etat `api.0013_asst_vf_table_names_state` ajoutee/appliquee.
- Mobile Flutter:
  - le metier assainissement pointe maintenant vers le schema local/logique `asst`;
  - le mapping de synchronisation accepte `asst` et les noms VF `ASS_*` tout en gardant les anciens aliases `asst_*`.

Verification:

- `python manage.py migrate api`: OK.
- `python manage.py check`: OK.
- `python manage.py makemigrations --check --dry-run`: OK, aucun changement detecte.
- Endpoints ASS testes en 200:
  - anciens: `/api/ass/regards/`, `/api/ass/canalisations/`, `/api/ass/ouvrages/`, `/api/ass/equipements/`, etc.
  - nouveaux utiles: `/api/ass/regards-facade/`, `/api/ass/regards-borgnes/`, `/api/ass/collecteurs/`, `/api/ass/caniveaux/`, `/api/ass/bassins-versants/`, etc.
- `flutter analyze` cible sur `srm_config.dart` et `sync_service.dart`: OK.

Backups:

- Avant adoption: `backups/postgres/pre_asst_vf_adoption_20260506_112844`
- Apres adoption: `backups/postgres/post_asst_vf_adoption_20260506_114744`

### Clarification des conduites EP cote mobile

Decision:

- `ep.ep_conduite` est la couche bureau, equivalente a l'ancien `ep.ep_conduite_bureau`.
- `ep.ep_conduite` ne doit pas alimenter les formulaires metier mobiles.
- Les conduites saisies depuis les formulaires mobiles passent par `ep.conduite_terrain`.
- Les conduites dessinees entre regards passent par `ep.statistique_conduite` et `ep.statistique_conduite_segment`.

Application:

- `public.attribut_config_mobile`: tous les champs de `ep.ep_conduite` sont passes a `visible = false`.
- Mobile Flutter: suppression du mapping de telechargement direct `ep/ep_conduite -> ep/conduites-bureau`.
- Le mapping `ep/conduite_terrain -> ep/conduites-terrain` reste le flux formulaire mobile.
- Le flux de dessin par regards reste gere par les endpoints `statistiques-conduite`.

### Pilotage des formulaires par `attribut_config_mobile`

Objectif:

- `public.attribut_config_mobile` devient la source de verite des formulaires mobiles pour l'ordre, la visibilite, le titre applicatif, le type, la nullabilite et les valeurs par defaut.
- `public.liste_choix` reste la source de verite des listes de choix, exposee via l'endpoint compatible `/api/srm-field-options/`.

Application pilote:

- Backend: ajout de `/api/attribut-config-mobile/`.
- Mobile: cache local `attribut_config_mobile_local`.
- Mobile: synchronisation silencieuse de la config au login.
- Mobile: formulaires point et ligne lisent maintenant `attribut_config_mobile` quand disponible; fallback sur `SrmConfig` uniquement si la table n'a aucune configuration BD.
- Mobile: `anomalie`/`ep_anomalie`/`ass_anomalie` et `objet_incomplet` restent des blocs fonctionnels, pas des champs standards; le bouton anomalie ecrit Oui/Non dans la colonne metier et affiche les champs detail (`type_anomalie`, `anomalie_*`, etc.) seulement quand il est active.
- Mobile: `type_anomalie` est aussi pilote par `liste_choix`; s'il existe une liste active, le champ devient une liste deroulante, sinon il reste un champ texte libre.
- Mobile: quand `public.liste_choix` expose des valeurs via `/api/srm-field-options/`, les champs concernes deviennent des listes deroulantes dans les formulaires point/ligne; sinon le champ garde son rendu texte/fallback.
- Tables pilotes couvertes par mapping local -> config physique:
  - `hydrant` -> `ep_hydrant`.
  - `vanne` -> `ep_vanne`.
  - `conduite_terrain` -> `conduite_terrain`.

Verification:

- `SRM_bureau`: schema `ep` couvert dans `attribut_config_mobile` a 35/35 tables.
- `SRM_bureau`: schema `asst` couvert dans `attribut_config_mobile` a 26/26 tables.
- Endpoint `/api/attribut-config-mobile/?nom_metier=ep&nom_table=ep_hydrant`: 200, 70 champs.
- `python manage.py check`: OK.
- `flutter analyze` cible sur les fichiers modifies: OK.
