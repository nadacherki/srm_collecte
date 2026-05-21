-- 2026-05-21 : Nettoyage des annotations textuelles dans valeur_par_defaut
-- pour les 10 champs auto-remplis de ep.ep_regard_point.
--
-- AVANT : valeur_par_defaut contenait des annotations metier en francais
-- ("=nom commune", "ep_coord z-profondeur", "largeur*longuer") qui etaient
-- de facto injectees TELLES QUELLES dans le payload serveur par
-- _attributConfigByField loop (srm_point_form_widget.dart:1782).
-- Consequences :
--   - z_radier, z_surf (double precision) : cast error potentielle au POST
--     car on envoyait des strings au lieu de numerics.
--   - commune, sect_hydr, zone, ... (varchar) : enregistrement des phrases
--     d'annotation litterales au lieu des vraies valeurs metier.
--
-- APRES :
--   - Les annotations migrent vers contraintes_doc (cf. Bloc 5,
--     2026-05-21_attribut_config_contraintes_split.sql) : conservation
--     pour audit et integration BD client, sans pollution payload.
--   - valeur_par_defaut = NULL : laisse la voie libre a la logique
--     Flutter d'auto-resolution au submit (cf. srm_point_form_widget.dart
--     section "Auto-resolution Bloc 5bis : champs invisibles calcules").
--
-- Mapping client (rappel, valide par Anas) :
--   commune, sec_com, ep_sect_com, sect_hydr, zone --> nom commune (FK id_commune)
--   province                                       --> nom province (FK id_province)
--   ep_adresse                                     --> copie de ep_ref_rue
--   ep_section                                     --> largeur * longueur (numerique)
--   z_radier                                       --> ep_coor_z - ep_profondeur
--   z_surf                                         --> ep_coor_z
--
-- Idempotent : reexecutable sans erreur.

BEGIN;

-- Note : on concatene avec l'existant contraintes_doc (probablement vide pour
-- ep_regard_point) pour ne rien perdre. NULLIF pour eviter une concat sur null.
UPDATE public.attribut_config_mobile
SET    contraintes_doc = CASE
         WHEN NULLIF(contraintes_doc, '') IS NULL THEN
           'auto-fill mobile : ' || valeur_par_defaut
         ELSE
           contraintes_doc || E'\nauto-fill mobile : ' || valeur_par_defaut
       END,
       valeur_par_defaut = NULL
WHERE  nom_metier = 'ep'
  AND  nom_table  = 'ep_regard_point'
  AND  nom_champ IN (
         'z_radier', 'z_surf',
         'ep_section', 'ep_adresse',
         'commune', 'sec_com', 'ep_sect_com', 'sect_hydr', 'zone',
         'province'
       )
  AND  NULLIF(valeur_par_defaut, '') IS NOT NULL;

COMMIT;

-- Verifications :
--   SELECT nom_champ, valeur_par_defaut, contraintes_doc
--   FROM   attribut_config_mobile
--   WHERE  nom_metier='ep' AND nom_table='ep_regard_point'
--     AND  nom_champ IN ('z_radier','z_surf','ep_section','ep_adresse',
--                        'commune','sec_com','ep_sect_com','sect_hydr',
--                        'zone','province')
--   ORDER BY nom_champ;
--
-- Attendu :
--   valeur_par_defaut = NULL pour les 10 champs
--   contraintes_doc commence par "auto-fill mobile : "
