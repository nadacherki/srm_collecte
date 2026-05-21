-- 2026-05-21 : Backfill du passif ep.ep_regard_point post-Bloc-5bis.
--
-- Avant la migration `2026-05-21_ep_regard_point_annotations_to_doc.sql` +
-- la logique Flutter d'auto-resolution Bloc 5bis, les 1449 regards
-- historiques etaient inserees sans logique systematique de calcul ni
-- de resolution geom-based. Resultat (compte du 2026-05-21) :
--   - 27 rows null sur commune / sec_com / sect_hydr / zone
--   - 10 rows null sur province
--   - 413 rows null sur ep_sect_com (le moins peuple historiquement)
--   - 23 rows null sur ep_section
--   - 30 / 89 rows null sur z_surf / z_radier
--   - 10 rows null sur ep_adresse
--   - 1441 rows sans id_commune (la resolution geom-based etait recente)
--
-- Pattern emprunte a la migration 0054_ep_regard_point_mirror_sync :
-- les CHECK constraints `srm_req_*` (NOT VALID) sont re-evaluees par
-- PostgreSQL sur tout UPDATE, meme si les colonnes contraintes ne sont
-- pas touchees. On les drop temporairement, on fait les UPDATEs, puis
-- on les recree NOT VALID avec les memes definitions (deterministes :
-- meme conname + meme predicat).
--
-- Ce script ne touche QUE les rows ou la valeur est actuellement NULL.
-- Une vraie valeur entree par un agent reste intouchee.
--
-- Idempotent : reexecutable sans erreur (le pattern drop/recreate
-- accepte la repetition tant que toutes les constraints existent
-- avant le drop).

BEGIN;

-- ──────────────────────────────────────────────────────────────────
-- 0. Drop temporaire des CHECK NOT VALID applicatives sur ep_regard_point.
-- ──────────────────────────────────────────────────────────────────
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'ep.ep_regard_point'::regclass
          AND contype = 'c'
          AND conname LIKE 'srm_req_%'
    LOOP
        EXECUTE format('ALTER TABLE ep.ep_regard_point DROP CONSTRAINT %I', r.conname);
    END LOOP;
END$$;

-- ──────────────────────────────────────────────────────────────────
-- 1. Resolution geom-based : pour chaque regard, identifier la commune
--    et la province dont le polygone contient sa geom.
-- ──────────────────────────────────────────────────────────────────
CREATE TEMP TABLE _regard_geo_context AS
SELECT DISTINCT ON (r.fid)
       r.fid                        AS regard_fid,
       c.fid                        AS commune_fid,
       c.nom                        AS commune_nom,
       c.id_province                AS province_fid_via_commune,
       p.nom                        AS province_nom
FROM   ep.ep_regard_point  r
LEFT JOIN public.commune_oriental c
       ON  r.geom IS NOT NULL
       AND ST_Intersects(r.geom, c.geom)
LEFT JOIN public.province         p
       ON  p.fid = c.id_province
ORDER BY r.fid, c.fid;

-- ──────────────────────────────────────────────────────────────────
-- 2. Backfill des FK id_commune, id_province sur les rows manquants.
-- ──────────────────────────────────────────────────────────────────
UPDATE ep.ep_regard_point r
SET    id_commune = ctx.commune_fid
FROM   _regard_geo_context ctx
WHERE  r.fid = ctx.regard_fid
  AND  r.id_commune IS NULL
  AND  ctx.commune_fid IS NOT NULL;

UPDATE ep.ep_regard_point r
SET    id_province = ctx.province_fid_via_commune
FROM   _regard_geo_context ctx
WHERE  r.fid = ctx.regard_fid
  AND  r.id_province IS NULL
  AND  ctx.province_fid_via_commune IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────
-- 3. Backfill des 5 champs string commune-related.
-- ──────────────────────────────────────────────────────────────────
UPDATE ep.ep_regard_point r
SET    commune = ctx.commune_nom
FROM   _regard_geo_context ctx
WHERE  r.fid = ctx.regard_fid
  AND  (r.commune IS NULL OR r.commune = '')
  AND  ctx.commune_nom IS NOT NULL;

UPDATE ep.ep_regard_point r
SET    sec_com = ctx.commune_nom
FROM   _regard_geo_context ctx
WHERE  r.fid = ctx.regard_fid
  AND  (r.sec_com IS NULL OR r.sec_com = '')
  AND  ctx.commune_nom IS NOT NULL;

UPDATE ep.ep_regard_point r
SET    ep_sect_com = ctx.commune_nom
FROM   _regard_geo_context ctx
WHERE  r.fid = ctx.regard_fid
  AND  (r.ep_sect_com IS NULL OR r.ep_sect_com = '')
  AND  ctx.commune_nom IS NOT NULL;

UPDATE ep.ep_regard_point r
SET    sect_hydr = ctx.commune_nom
FROM   _regard_geo_context ctx
WHERE  r.fid = ctx.regard_fid
  AND  (r.sect_hydr IS NULL OR r.sect_hydr = '')
  AND  ctx.commune_nom IS NOT NULL;

UPDATE ep.ep_regard_point r
SET    zone = ctx.commune_nom
FROM   _regard_geo_context ctx
WHERE  r.fid = ctx.regard_fid
  AND  (r.zone IS NULL OR r.zone = '')
  AND  ctx.commune_nom IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────
-- 4. Backfill du nom province.
-- ──────────────────────────────────────────────────────────────────
UPDATE ep.ep_regard_point r
SET    province = ctx.province_nom
FROM   _regard_geo_context ctx
WHERE  r.fid = ctx.regard_fid
  AND  (r.province IS NULL OR r.province = '')
  AND  ctx.province_nom IS NOT NULL;

DROP TABLE _regard_geo_context;

-- ──────────────────────────────────────────────────────────────────
-- 5. Backfill ep_adresse depuis ep_ref_rue (si ep_ref_rue non vide).
-- ──────────────────────────────────────────────────────────────────
UPDATE ep.ep_regard_point
SET    ep_adresse = TRIM(ep_ref_rue)
WHERE  (ep_adresse IS NULL OR ep_adresse = '')
  AND  ep_ref_rue IS NOT NULL
  AND  TRIM(ep_ref_rue) <> '';

-- ──────────────────────────────────────────────────────────────────
-- 6. Recalcul z_surf = ep_coor_z.
-- ──────────────────────────────────────────────────────────────────
UPDATE ep.ep_regard_point
SET    z_surf = ep_coor_z
WHERE  z_surf IS NULL
  AND  ep_coor_z IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────
-- 7. Recalcul z_radier = ep_coor_z - ep_profondeur.
-- ──────────────────────────────────────────────────────────────────
UPDATE ep.ep_regard_point
SET    z_radier = ep_coor_z - ep_profondeur
WHERE  z_radier IS NULL
  AND  ep_coor_z IS NOT NULL
  AND  ep_profondeur IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────
-- 8. Recalcul ep_section = largeur * longueur (varchar : ::text cast).
-- ──────────────────────────────────────────────────────────────────
UPDATE ep.ep_regard_point
SET    ep_section = (largeur * longueur)::text
WHERE  (ep_section IS NULL OR ep_section = '')
  AND  largeur IS NOT NULL
  AND  longueur IS NOT NULL;

-- ──────────────────────────────────────────────────────────────────
-- 9. Recreation des CHECK NOT VALID applicatives (memes noms,
--    memes predicats que ceux dropes en 0). Pattern aligne avec
--    migration 0054_ep_regard_point_mirror_sync.
-- ──────────────────────────────────────────────────────────────────
ALTER TABLE ep.ep_regard_point
    ADD CONSTRAINT srm_req_02c6f47decde3ed4 CHECK (
        largeur IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_6d7635f7bedb68ec CHECK (
        ep_tampon IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_6ffcd68d98ecb4df CHECK (
        ep_conf_plan IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_71579009f1de0b9e CHECK (
        echelon IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_a4f237aac8427fb3 CHECK (
        longueur IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_af41a9e77b0e3e82 CHECK (
        ep_ref_rue IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_c35dc7b065e664dc CHECK (
        type_regard IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_ccc1f9f50bf6f51b CHECK (
        emplacement IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_d7e18f1829c67bbf CHECK (
        ep_profondeur IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID,
    ADD CONSTRAINT srm_req_ee72116e03b1ead2 CHECK (
        existence_s IS NOT NULL
        OR lower(btrim(COALESCE(ep_anomalie::text, ''))) <> ALL (ARRAY[
            '', '0', 'false', 'f', 'no', 'non', 'n'
        ])
    ) NOT VALID;

COMMIT;

-- ──────────────────────────────────────────────────────────────────
-- Verifications post-backfill (a executer manuellement) :
--
-- SELECT
--   SUM(CASE WHEN commune IS NULL THEN 1 ELSE 0 END)     AS null_commune,
--   SUM(CASE WHEN sec_com IS NULL THEN 1 ELSE 0 END)     AS null_sec_com,
--   SUM(CASE WHEN ep_sect_com IS NULL THEN 1 ELSE 0 END) AS null_ep_sect_com,
--   SUM(CASE WHEN sect_hydr IS NULL THEN 1 ELSE 0 END)   AS null_sect_hydr,
--   SUM(CASE WHEN zone IS NULL THEN 1 ELSE 0 END)        AS null_zone,
--   SUM(CASE WHEN province IS NULL THEN 1 ELSE 0 END)    AS null_province,
--   SUM(CASE WHEN ep_adresse IS NULL THEN 1 ELSE 0 END)  AS null_ep_adresse,
--   SUM(CASE WHEN ep_section IS NULL THEN 1 ELSE 0 END)  AS null_ep_section,
--   SUM(CASE WHEN z_surf IS NULL THEN 1 ELSE 0 END)      AS null_z_surf,
--   SUM(CASE WHEN z_radier IS NULL THEN 1 ELSE 0 END)    AS null_z_radier,
--   SUM(CASE WHEN id_commune IS NULL THEN 1 ELSE 0 END)  AS null_id_commune
-- FROM ep.ep_regard_point;
--
-- Reliquat attendu :
--   - Lignes ou le geom ne tombe DANS AUCUN polygone commune_oriental
--     (geom pres de la frontiere, donnee test, etc.) : restent null.
--   - z_surf null si ep_coor_z null (regards sans Z).
--   - z_radier null si ep_coor_z OU ep_profondeur null.
--   - ep_adresse null si ep_ref_rue null/vide.
--   - ep_section null si largeur OU longueur null.
