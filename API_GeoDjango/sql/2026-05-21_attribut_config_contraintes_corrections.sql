-- 2026-05-21 : Corrections post-migration 2026-05-21_attribut_config_contraintes_split.sql.
--
-- Decouverte apres execution initiale : la colonne `public.liste_choix.contraintes`
-- (que la migration initiale n'avait pas vue) contenait 3 lignes avec des regles
-- metier specifiques par VALEUR de liste de choix (pas seulement par CHAMP) :
--
--   anomalie_regard = "Inaccessible"      : "bloquer tous les champs"
--   anomalie_regard = "Regards Enterrés"  : "bloquer ep_profondeur et generatrice_supp,
--                                            lancer le traitement de l'anomalie"
--   anomalie_tamp   = "Tampons Scellés"   : idem
--
-- Decision (validation Anas, 2026-05-21) :
--   1. Centraliser TOUTES les regles dans attribut_config_mobile.contraintes_regles
--      (avec when.eq pour conditionner par valeur). Supprimer liste_choix.contraintes.
--   2. Le side-effect "anomalie=true" est redondant : les champs anomalie_regard,
--      anomalie_tamp et retour_terrain ne sont visibles QUE SI anomalie=true
--      (impose par le widget Flutter, _hasAnomalie). Pas besoin de l'auto-set.
--   3. La regle 1 initiale fusionnait "Inaccessible" + "Regards Enterrés" dans un
--      meme disable_others, ce qui etait incorrect : "Regards Enterrés" doit
--      seulement bloquer ep_profondeur + generatrice_supp (pas tous les champs).
--
-- Idempotent : reexecutable sans erreur.

BEGIN;

-- ──────────────────────────────────────────────────────────────────
-- 1. Correction regle anomalie_regard : 2 cas distincts.
-- ──────────────────────────────────────────────────────────────────
--
-- Cas "Inaccessible" seul : disable_others (large, tous les champs metier).
-- Cas "Regards Enterrés" : disable_and_clear sur 2 champs uniquement.
--
-- Les deux regles vivent dans l'attribut anomalie_regard (le champ pivot).
-- Le moteur d'evaluation les declenche selon la valeur courante.

UPDATE public.attribut_config_mobile
SET    contraintes_regles = '[
  {
    "id": "regard_inaccessible_disable_all",
    "when": { "field": "anomalie_regard", "eq": "Inaccessible" },
    "action": "disable_others",
    "except_fields": ["anomalie_regard", "anomalie_tamp", "anomalie", "type_anomalie", "retour_terrain", "geom", "ep_coor_x", "ep_coor_y", "ep_coor_z"],
    "message": "Regard inaccessible : aucune mesure possible."
  },
  {
    "id": "regards_enterres_mask_depth",
    "when": { "field": "anomalie_regard", "eq": "Regards Enterrés" },
    "action": "disable_and_clear",
    "fields": ["ep_profondeur", "generatrice_supp"],
    "message": "Regards enterrés : profondeur et génératrice non mesurables."
  }
]'::jsonb
WHERE  nom_metier = 'ep'
  AND  nom_table = 'ep_regard_point'
  AND  nom_champ = 'anomalie_regard';

-- ──────────────────────────────────────────────────────────────────
-- 2. Conservation de la regle anomalie_tamp = Tampons Scellés.
--    Le side-effect "anomalie=true" est retire (redondant).
--    Le side-effect "retour_terrain=true" est conserve (validation Anas :
--    tampon scelle implique toujours retour terrain).
-- ──────────────────────────────────────────────────────────────────
UPDATE public.attribut_config_mobile
SET    contraintes_regles = '[
  {
    "id": "tampon_scelle_mask_depth",
    "when": { "field": "anomalie_tamp", "eq": "Tampons Scellés" },
    "action": "disable_and_clear",
    "fields": ["ep_profondeur", "generatrice_supp"],
    "side_effects": [
      { "set_field": "retour_terrain", "value": true }
    ],
    "message": "Tampon scellé : profondeur et génératrice non mesurables."
  }
]'::jsonb
WHERE  nom_metier = 'ep'
  AND  nom_table = 'ep_regard_point'
  AND  nom_champ = 'anomalie_tamp';

COMMIT;

-- ──────────────────────────────────────────────────────────────────
-- 3. Suppression de la colonne public.liste_choix.contraintes.
--    Bloc separe (pending trigger events).
--    Note : les 3 textes presents avant suppression sont reproduits
--    en commentaire de cette migration et resteront accessibles via
--    git log si besoin d'audit historique.
-- ──────────────────────────────────────────────────────────────────
BEGIN;

ALTER TABLE public.liste_choix
    DROP COLUMN IF EXISTS contraintes;

COMMIT;

-- ──────────────────────────────────────────────────────────────────
-- Verifications post-correction :
--
--   SELECT nom_champ, jsonb_array_length(contraintes_regles) AS n_regles
--   FROM   attribut_config_mobile
--   WHERE  nom_metier='ep' AND nom_table='ep_regard_point'
--     AND  contraintes_regles <> '[]'::jsonb
--   ORDER BY nom_champ;
--
--   Attendu :
--     anomalie_regard  | 2  (Inaccessible + Regards Enterrés)
--     anomalie_tamp    | 1  (Tampons Scellés)
--     ep_profondeur    | 1  (out of range warn)
--     generatrice_supp | 1  (out of range warn)
--     largeur          | 1  (>= 5m warn)
--     longueur         | 1  (>= 5m warn)
--   Total = 7 regles encodees.
-- ──────────────────────────────────────────────────────────────────
