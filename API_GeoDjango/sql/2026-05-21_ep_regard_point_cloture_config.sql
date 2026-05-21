-- 2026-05-21 : Cloture de la revue ep.ep_regard_point.
-- Corrige les 2 derniers points releves par l'audit complet :
--   1. Doublons d'ordre sur 3 champs (2 conflits UI + 1 cas benin invisible)
--   2. Typos sur 3 valeurs de liste_choix.ep_statut (valeur != alias propre)
--
-- Prerequis verifies :
--   - Aucun ep_regard_point n'a ep_statut dans {EP_A REHABI, EP_EN COURSS,
--     EP_A RESILISE} (compte = 0). Le rename est donc sans collateral.
--
-- Idempotent : reexecutable sans erreur.

BEGIN;

-- ──────────────────────────────────────────────────────────────────
-- 1. Reassignation des ordres dupliques.
--    Strategie : garder la valeur historique pour le champ "principal"
--    de chaque paire, deplacer le secondaire dans un trou libre.
-- ──────────────────────────────────────────────────────────────────

-- ordre 44 : echelon + ep_profondeur tous deux visibles.
-- On garde ep_profondeur a 44 (groupe mesures), echelon part a 58 (trou libre
-- juste apres generatrice_supp:56, avant longueur:63).
UPDATE public.attribut_config_mobile
SET    ordre = 58
WHERE  nom_metier = 'ep'
  AND  nom_table  = 'ep_regard_point'
  AND  nom_champ  = 'echelon'
  AND  ordre      = 44;

-- ordre 70 : ep_conf_plan + ep_date_pose tous deux visibles.
-- On garde ep_conf_plan a 70, ep_date_pose part a 72 (juste apres
-- ep_observation:71).
UPDATE public.attribut_config_mobile
SET    ordre = 72
WHERE  nom_metier = 'ep'
  AND  nom_table  = 'ep_regard_point'
  AND  nom_champ  = 'ep_date_pose'
  AND  ordre      = 70;

-- ordre 38 : retour_terrain (visible) + anom_regard (invisible).
-- Cas benin : anom_regard ne s'affiche pas, mais pour la proprete, on
-- l'envoie en 999 (le default des invisibles techniques).
UPDATE public.attribut_config_mobile
SET    ordre = 999
WHERE  nom_metier = 'ep'
  AND  nom_table  = 'ep_regard_point'
  AND  nom_champ  = 'anom_regard'
  AND  ordre      = 38;

-- ──────────────────────────────────────────────────────────────────
-- 2. Correction des 3 typos sur liste_choix.ep_statut.
--    Le `liste_choix_alias` etait deja le libelle propre ; on aligne
--    `liste_choix_valeur` dessus.
-- ──────────────────────────────────────────────────────────────────
UPDATE public.liste_choix
SET    liste_choix_valeur = 'EP_A REHABILITE'
WHERE  nom_metier = 'ep'
  AND  nom_table  = 'ep_regard_point'
  AND  nom_champ  = 'ep_statut'
  AND  liste_choix_valeur = 'EP_A REHABI';

UPDATE public.liste_choix
SET    liste_choix_valeur = 'EP_EN COURS'
WHERE  nom_metier = 'ep'
  AND  nom_table  = 'ep_regard_point'
  AND  nom_champ  = 'ep_statut'
  AND  liste_choix_valeur = 'EP_EN COURSS';

UPDATE public.liste_choix
SET    liste_choix_valeur = 'EP_A RESILISER'
WHERE  nom_metier = 'ep'
  AND  nom_table  = 'ep_regard_point'
  AND  nom_champ  = 'ep_statut'
  AND  liste_choix_valeur = 'EP_A RESILISE';

COMMIT;

-- ──────────────────────────────────────────────────────────────────
-- Verifications post-cloture :
--
-- 1. Aucun ordre duplique restant cote attributs visibles :
--   SELECT ordre, COUNT(*)
--   FROM   attribut_config_mobile
--   WHERE  nom_metier='ep' AND nom_table='ep_regard_point'
--     AND  visible IS TRUE
--   GROUP BY ordre HAVING COUNT(*) > 1;
--   (attendu : 0 rows)
--
-- 2. Listes choix ep_statut alignees valeur=alias :
--   SELECT liste_choix_valeur, liste_choix_alias
--   FROM   liste_choix
--   WHERE  nom_metier='ep' AND nom_table='ep_regard_point'
--     AND  nom_champ='ep_statut'
--   ORDER BY liste_choix_ordre;
--   (attendu : valeur = alias partout)
