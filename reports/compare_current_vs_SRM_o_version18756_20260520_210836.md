# Comparaison BD actuelle vs SRM_o_version18756.backup

- Date: 2026-05-20T21:08:39
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
