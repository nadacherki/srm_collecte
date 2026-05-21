# Comparaison BD actuelle vs SRM_o_version18756.backup

- Date: 2026-05-20T21:11:23
- Backup comparé: `C:\Users\AnasDahou\Downloads\SRM_o_version18756.backup`
- BD actuelle: `SRM_bureau` sur `127.0.0.1:5432`

## Résumé structure

- Tables seulement en BD actuelle: 0
- Tables seulement dans le backup: 0
- Tables communes: 107

## Écarts de structure

- Tables avec écart de structure: 3

### `ep.ep_regard_point`
- nullabilite differente pour ep_anomalie: current not_null=False | backup not_null=True
- contrainte seulement en backup: CHECK (ep_agent IS NOT NULL) NOT VALID
- contrainte seulement en backup: CHECK (ep_ref_rue IS NOT NULL) NOT VALID
- contrainte seulement en backup: CHECK (generatrice_supp IS NOT NULL) NOT VALID
- contrainte seulement en backup: CHECK (retour_terrain IS NOT NULL) NOT VALID

### `ep.ep_vanne`
- contrainte seulement en backup: CHECK (ep_marque IS NOT NULL) NOT VALID

### `public.objet_photo`
- contrainte seulement en current: CHECK (contexte_photo::text = ANY (ARRAY['collecte_initiale'::character varying, 'anomalie_avant'::character varying, 'retour_terrain_apres'::character varying, 'incomplet_initial'::character varying, 'incomplet_complement'::character varying]::text[]))
- contrainte seulement en backup: CHECK (contexte_photo::text = ANY (ARRAY['collecte_initiale'::character varying::text, 'anomalie_avant'::character varying::text, 'retour_terrain_apres'::character varying::text, 'incomplet_initial'::character varying::text, 'incomplet_complement'::character varying::text]))

## Écarts de données

### Tables avec nombre de lignes différent
- `ep.ep_compteur_i`: current=38 | backup=37
- `public.attribut_config_mobile`: current=3185 | backup=3279
- `public.historique_action`: current=73420 | backup=73657
- `public.intervention_anomalie`: current=396 | backup=395
- `public.intervention_log`: current=1070 | backup=1069
- `public.liste_choix`: current=935 | backup=936
- `public.objet_photo`: current=11154 | backup=11152
- `public.srm_config_schema_ddl_log`: current=418 | backup=424
- `public.sync_session`: current=30 | backup=28
- `public.sync_session_attachment`: current=24 | backup=21
- `public.sync_session_item`: current=71 | backup=68

### Tables avec contenu différent (comparaison exacte sur petites tables / tables clés)
- `ep.ep_compteur_i`: total_current=38, lignes seulement en current=1, lignes seulement en backup=0
- `public.attribut_config_mobile`: total_current=3185, lignes seulement en current=81, lignes seulement en backup=175
- `public.formulaire_config_mobile`: total_current=61, lignes seulement en current=28, lignes seulement en backup=28
- `public.intervention_anomalie`: total_current=396, lignes seulement en current=1, lignes seulement en backup=0
- `public.liste_choix`: total_current=935, lignes seulement en current=0, lignes seulement en backup=1
- `public.sync_session`: total_current=30, lignes seulement en current=2, lignes seulement en backup=0
- `public.sync_session_attachment`: total_current=24, lignes seulement en current=3, lignes seulement en backup=0
- `public.sync_session_item`: total_current=71, lignes seulement en current=3, lignes seulement en backup=0
- `public.utilisateur`: total_current=13, lignes seulement en current=2, lignes seulement en backup=2

### Écarts métier ciblés (colonnes utiles, dates/audits exclus)
- `ep.ep_compteur_i`: lignes métier seulement en current=1, seulement en backup=0
  - current only: `{"uuid":"bb192a2e-8156-41a0-b222-9f5d0bb7169d","ep_num":null,"ep_coor_x":819605.686,"ep_coor_y":459013.134,"ep_coor_z":0}`
- `public.attribut_config_mobile`: lignes métier seulement en current=81, seulement en backup=175
  - current only: `{"nom_metier":"ep","nom_table":"ep_regard_point","nom_champ":"ep_profondeur","type_champ":"double precision","primary_key":false,"foreign_key":false,"ordre":44,"titre_app":"Profondeur","visible":true,"contraintes":"alerte si profondeur -generatrice sup entre 0 et 1","nullable":false,"valeur_par_defaut":null,"valeur_min":"0","valeur_max":null,"reference_fk":null}`
  - current only: `{"nom_metier":"ep","nom_table":"ep_vanne","nom_champ":"id_commune","type_champ":"integer","primary_key":false,"foreign_key":true,"ordre":45,"titre_app":"FK commune","visible":false,"contraintes":null,"nullable":true,"valeur_par_defaut":null,"valeur_min":null,"valeur_max":null,"reference_fk":"public.commune_oriental.fid"}`
  - current only: `{"nom_metier":"ep","nom_table":"ep_vanne","nom_champ":"id_zone","type_champ":"integer","primary_key":false,"foreign_key":true,"ordre":55,"titre_app":"ID zone source","visible":false,"contraintes":"champ legacy: identifiant zone source conserve pour tracabilite; zoning agent via public.zone et public.zone_utilisateur","nullable":true,"valeur_par_defaut":null,"valeur_min":null,"valeur_max":null,"reference_fk":"public.zone.id_zone"}`
  - current only: `{"nom_metier":"ep","nom_table":"ep_vanne","nom_champ":"ep_modele","type_champ":"character varying(400)","primary_key":false,"foreign_key":false,"ordre":6,"titre_app":"Modèle de vanne","visible":true,"contraintes":null,"nullable":false,"valeur_par_defaut":null,"valeur_min":null,"valeur_max":null,"reference_fk":null}`
  - current only: `{"nom_metier":"ep","nom_table":"ep_regard_point","nom_champ":"retour_terrain","type_champ":"character varying(100)","primary_key":false,"foreign_key":false,"ordre":62,"titre_app":"Retour terrain","visible":false,"contraintes":null,"nullable":true,"valeur_par_defaut":null,"valeur_min":null,"valeur_max":null,"reference_fk":null}`
  - backup only: `{"nom_metier":"ep","nom_table":"ep_vanne","nom_champ":"id_commune","type_champ":"integer","primary_key":false,"foreign_key":true,"ordre":46,"titre_app":"FK commune","visible":false,"contraintes":null,"nullable":true,"valeur_par_defaut":null,"valeur_min":null,"valeur_max":null,"reference_fk":"public.commune_oriental.fid"}`
  - backup only: `{"nom_metier":"ep","nom_table":"ep_bouche_a_cles","nom_champ":"fid","type_champ":"integer","primary_key":true,"foreign_key":false,"ordre":1,"titre_app":null,"visible":false,"contraintes":null,"nullable":false,"valeur_par_defaut":null,"valeur_min":null,"valeur_max":null,"reference_fk":null}`
  - backup only: `{"nom_metier":"ep","nom_table":"ep_vanne","nom_champ":"id_zone","type_champ":"integer","primary_key":false,"foreign_key":true,"ordre":56,"titre_app":"ID zone source","visible":false,"contraintes":"champ legacy: identifiant zone source conserve pour tracabilite; zoning agent via public.zone et public.zone_utilisateur","nullable":true,"valeur_par_defaut":null,"valeur_min":null,"valeur_max":null,"reference_fk":"public.zone.id_zone"}`
  - backup only: `{"nom_metier":"ep","nom_table":"ep_bouche_a_cles","nom_champ":"uuid","type_champ":"uuid","primary_key":false,"foreign_key":false,"ordre":2,"titre_app":null,"visible":false,"contraintes":null,"nullable":true,"valeur_par_defaut":null,"valeur_min":null,"valeur_max":null,"reference_fk":null}`
  - backup only: `{"nom_metier":"ep","nom_table":"ep_vanne","nom_champ":"ep_ref","type_champ":"character varying(400)","primary_key":false,"foreign_key":false,"ordre":14,"titre_app":"Ep ref","visible":false,"contraintes":null,"nullable":true,"valeur_par_defaut":"=ep_ref_rue","valeur_min":null,"valeur_max":null,"reference_fk":null}`
- `public.formulaire_config_mobile`: lignes métier seulement en current=28, seulement en backup=28
  - current only: `{"nom_metier":"ep","nom_table":"ep_noeud","titre_app":"Noeud","ordre":22,"visible":false,"download_mobile":false}`
  - current only: `{"nom_metier":"ep","nom_table":"centre_tampon","titre_app":"Centre tampon","ordre":19,"visible":false,"download_mobile":false}`
  - current only: `{"nom_metier":"ep","nom_table":"ep_branchement","titre_app":"Branchement","ordre":12,"visible":false,"download_mobile":false}`
  - current only: `{"nom_metier":"ep","nom_table":"ep_puit","titre_app":"Puits","ordre":25,"visible":false,"download_mobile":false}`
  - current only: `{"nom_metier":"ep","nom_table":"ep_conduite","titre_app":"Conduite bureau","ordre":3,"visible":false,"download_mobile":false}`
  - backup only: `{"nom_metier":"ep","nom_table":"ep_conduite","titre_app":"Conduite bureau","ordre":30,"visible":false,"download_mobile":false}`
  - backup only: `{"nom_metier":"ep","nom_table":"ep_regard_point","titre_app":"Regard","ordre":2,"visible":true,"download_mobile":true}`
  - backup only: `{"nom_metier":"ep","nom_table":"conduite_terrain","titre_app":"Conduite terrain","ordre":3,"visible":true,"download_mobile":true}`
  - backup only: `{"nom_metier":"ep","nom_table":"ep_bf","titre_app":"Borne fontaine","ordre":11,"visible":true,"download_mobile":true}`
  - backup only: `{"nom_metier":"ep","nom_table":"ep_cone_reduc","titre_app":"Cône de réduction","ordre":10,"visible":true,"download_mobile":true}`
- `public.liste_choix`: lignes métier seulement en current=0, seulement en backup=1
  - backup only: `{"nom_metier":"ep","nom_table":"ep_vanne","nom_champ":"ep_marque"}`
