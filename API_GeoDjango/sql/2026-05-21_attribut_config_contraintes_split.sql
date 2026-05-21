-- 2026-05-21 : Split `public.attribut_config_mobile.contraintes` en deux
-- colonnes a semantique distincte.
--
-- AVANT : `contraintes` (text) melangeait :
--   1. Documentation metier en texte libre francais (~340 lignes sur 415) :
--      annotations sur l'historique des champs ("table speciale/orpheline
--      conservee pour audit", "compatibilite backend/mobile existant",
--      "champ legacy ..."). Aucune semantique executable.
--   2. Vraies regles metier (~7 lignes sur 415, toutes sur ep_regard_point) :
--      conditions de masquage/verrouillage de champs, alertes de seuil,
--      alertes sur calcul croise. Ecrites en francais libre, jamais
--      interpretees par le mobile.
--
-- APRES : deux colonnes :
--   - `contraintes_doc` (text) : documentation pure, jamais evaluee.
--   - `contraintes_regles` (jsonb) : array de regles structurees evaluees
--     par le mobile (et re-evaluees serveur pour les actions "error").
--
-- Schema JSON d'une regle :
--   {
--     "id":        "kebab-case-unique",
--     "when":      <condition>,
--     "requires_fields": ["field", ...] (optionnel : skip regle si l'un null),
--     "action":    "warn" | "error" | "disable_others" | "disable_and_clear",
--     "fields":    [...] (pour disable_and_clear et highlight des warn),
--     "except_fields": [...] (pour disable_others),
--     "side_effects": [{"set_field": "...", "value": ...}] (optionnel),
--     "message":   "string avec interpolation {{field}}"
--   }
--
--   <condition> peut etre :
--     {"field": "f", "eq": "v"}              # egalite
--     {"field": "f", "in": ["v1", "v2"]}     # appartenance
--     {"field": "f", ">": n}                 # ou <, >=, <=, !=
--     {"expr": "expression arithmetique"}    # operateurs +-*/, ()
--     {"all": [<c>, ...]}                    # AND
--     {"any": [<c>, ...]}                    # OR
--     {"not": <c>}                           # NOT
--
-- Idempotent : reexecutable sans erreur.

BEGIN;

-- ──────────────────────────────────────────────────────────────────
-- 1. Ajout des deux nouvelles colonnes (idempotent).
-- ──────────────────────────────────────────────────────────────────
ALTER TABLE public.attribut_config_mobile
    ADD COLUMN IF NOT EXISTS contraintes_doc text;

ALTER TABLE public.attribut_config_mobile
    ADD COLUMN IF NOT EXISTS contraintes_regles jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.attribut_config_mobile.contraintes_doc IS
    'Annotations documentaires en texte libre (jamais evaluees).';
COMMENT ON COLUMN public.attribut_config_mobile.contraintes_regles IS
    'Regles metier structurees evaluees par le mobile (cf. 2026-05-21_attribut_config_contraintes_split.sql).';

-- ──────────────────────────────────────────────────────────────────
-- 2. Migration des donnees existantes : tout l'ancien `contraintes`
--    bascule dans `contraintes_doc` (par defaut, c'est de la doc).
--    Reexecutable : on n'ecrase pas si contraintes_doc deja peuplee.
-- ──────────────────────────────────────────────────────────────────
UPDATE public.attribut_config_mobile
SET    contraintes_doc = contraintes
WHERE  contraintes IS NOT NULL
  AND  contraintes <> ''
  AND  (contraintes_doc IS NULL OR contraintes_doc = '');

-- ──────────────────────────────────────────────────────────────────
-- 3. Encodage des 4 regles metier identifiees sur ep.ep_regard_point.
--    Le doc historique est conserve dans contraintes_doc pour audit.
--    Reexecutable : on ne re-set que si contraintes_regles est vide.
-- ──────────────────────────────────────────────────────────────────

-- Regle 1 : si anomalie_regard ∈ {Inaccessible, Regards Enterres},
-- desactivation de tous les autres champs metier (le collecteur localise
-- juste le regard, aucune mesure possible).
UPDATE public.attribut_config_mobile
SET    contraintes_regles = '[
  {
    "id": "regard_non_visualisable_disable_all",
    "when": { "field": "anomalie_regard", "in": ["Inaccessible", "Regards Enterrés"] },
    "action": "disable_others",
    "except_fields": ["anomalie_regard", "geom", "ep_coor_x", "ep_coor_y", "ep_coor_z", "retour_terrain", "anomalie", "type_anomalie"],
    "message": "Regard non visualisable : aucune mesure possible."
  }
]'::jsonb
WHERE  nom_metier = 'ep'
  AND  nom_table = 'ep_regard_point'
  AND  nom_champ = 'anomalie_regard'
  AND  contraintes_regles = '[]'::jsonb;

-- Regle 2 : si anomalie_tamp = Tampons Scelles, masquage de ep_profondeur
-- et generatrice_supp (impossible a mesurer). Effet de bord : retour_terrain
-- est auto-positionne a true (le bureau doit traiter ce point).
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
  AND  nom_champ = 'anomalie_tamp'
  AND  contraintes_regles = '[]'::jsonb;

-- Regle 3 : alerte si l'ecart profondeur - generatrice_supp est HORS [0,1]
-- (la contrainte metier est que l'ecart DOIT etre dans cet intervalle).
-- Skip si l'un des deux champs est null.
UPDATE public.attribut_config_mobile
SET    contraintes_regles = '[
  {
    "id": "profondeur_vs_generatrice_out_of_range",
    "when": { "expr": "(ep_profondeur - generatrice_supp) < 0 || (ep_profondeur - generatrice_supp) > 1" },
    "requires_fields": ["ep_profondeur", "generatrice_supp"],
    "action": "warn",
    "fields": ["ep_profondeur", "generatrice_supp"],
    "message": "Écart profondeur − génératrice = {{ep_profondeur - generatrice_supp}} m, hors seuil métier [0 m ; 1 m]. À vérifier."
  }
]'::jsonb
WHERE  nom_metier = 'ep'
  AND  nom_table = 'ep_regard_point'
  AND  nom_champ IN ('ep_profondeur', 'generatrice_supp')
  AND  contraintes_regles = '[]'::jsonb;

-- Regle 4 : alerte si largeur >= 5 m (inclusif).
UPDATE public.attribut_config_mobile
SET    contraintes_regles = '[
  {
    "id": "largeur_gte_5",
    "when": { "field": "largeur", ">=": 5 },
    "action": "warn",
    "fields": ["largeur"],
    "message": "Largeur ≥ 5 m ({{largeur}} m). À vérifier."
  }
]'::jsonb
WHERE  nom_metier = 'ep'
  AND  nom_table = 'ep_regard_point'
  AND  nom_champ = 'largeur'
  AND  contraintes_regles = '[]'::jsonb;

-- Regle 4bis : alerte si longueur >= 5 m (inclusif).
UPDATE public.attribut_config_mobile
SET    contraintes_regles = '[
  {
    "id": "longueur_gte_5",
    "when": { "field": "longueur", ">=": 5 },
    "action": "warn",
    "fields": ["longueur"],
    "message": "Longueur ≥ 5 m ({{longueur}} m). À vérifier."
  }
]'::jsonb
WHERE  nom_metier = 'ep'
  AND  nom_table = 'ep_regard_point'
  AND  nom_champ = 'longueur'
  AND  contraintes_regles = '[]'::jsonb;

COMMIT;

-- ──────────────────────────────────────────────────────────────────
-- 4. Suppression de l'ancienne colonne `contraintes` + index.
--    Bloc separe car le DROP COLUMN doit s'executer apres COMMIT du bloc
--    de UPDATE, sinon les triggers d'audit en attente (pending trigger
--    events) bloquent le DDL ("cannot ALTER TABLE ... because it has
--    pending trigger events").
--    Note : si tu veux garder une periode de transition, commenter ce DROP
--    et le supprimer dans une migration ulterieure.
-- ──────────────────────────────────────────────────────────────────
BEGIN;

ALTER TABLE public.attribut_config_mobile
    DROP COLUMN IF EXISTS contraintes;

CREATE INDEX IF NOT EXISTS idx_acm_contraintes_regles_gin
    ON public.attribut_config_mobile USING gin (contraintes_regles);

COMMIT;

-- ──────────────────────────────────────────────────────────────────
-- Verifications post-migration (a executer manuellement).
-- ──────────────────────────────────────────────────────────────────
--
-- 1. Compter les regles encodees :
--   SELECT COUNT(*) FROM attribut_config_mobile WHERE contraintes_regles <> '[]'::jsonb;
--   (attendu : 5 lignes — anomalie_regard, anomalie_tamp, ep_profondeur,
--    generatrice_supp, largeur, longueur — soit 6 lignes, attention)
--
-- 2. Lister les regles d'un champ :
--   SELECT nom_champ, contraintes_regles
--   FROM attribut_config_mobile
--   WHERE nom_metier='ep' AND nom_table='ep_regard_point'
--     AND contraintes_regles <> '[]'::jsonb;
--
-- 3. Verifier que les doc sont preservees :
--   SELECT COUNT(*) FROM attribut_config_mobile
--   WHERE contraintes_doc IS NOT NULL AND contraintes_doc <> '';
--   (attendu : ~415, l'ancien nombre)
