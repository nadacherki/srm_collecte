BEGIN;

WITH params AS (
    SELECT
        'oujda'::VARCHAR(100) AS city_slug,
        11::INTEGER AS min_zoom,
        19::INTEGER AS max_zoom
),
communes_source AS (
    SELECT
        c.id_commune,
        c.nom_commune,
        c.nom_province,
        c.nom_region,
        ST_Multi(ST_Transform(ST_Force2D(c.geom), 4326))::geometry(MultiPolygon, 4326) AS geom_4326
    FROM public.commune c
    WHERE c.geom IS NOT NULL
),
zones_source AS (
    SELECT
        'commune_' || cs.id_commune::text AS zone_id,
        p.city_slug,
        cs.nom_commune AS nom,
        cs.geom_4326 AS geom,
        ST_XMin(cs.geom_4326) AS bbox_west,
        ST_YMin(cs.geom_4326) AS bbox_south,
        ST_XMax(cs.geom_4326) AS bbox_east,
        ST_YMax(cs.geom_4326) AS bbox_north,
        ST_Y(ST_PointOnSurface(cs.geom_4326)) AS center_latitude,
        ST_X(ST_PointOnSurface(cs.geom_4326)) AS center_longitude,
        p.min_zoom,
        p.max_zoom,
        TRUE AS actif,
        jsonb_build_object(
            'source', 'public.commune',
            'id_commune', cs.id_commune,
            'nom_commune', cs.nom_commune,
            'nom_province', cs.nom_province,
            'nom_region', cs.nom_region
        ) AS metadata_json
    FROM communes_source cs
    CROSS JOIN params p
)
INSERT INTO public.basemap_zone (
    zone_id,
    city_slug,
    nom,
    geom,
    bbox_west,
    bbox_south,
    bbox_east,
    bbox_north,
    center_latitude,
    center_longitude,
    min_zoom,
    max_zoom,
    actif,
    metadata_json,
    updated_at
)
SELECT
    zs.zone_id,
    zs.city_slug,
    zs.nom,
    zs.geom,
    zs.bbox_west,
    zs.bbox_south,
    zs.bbox_east,
    zs.bbox_north,
    zs.center_latitude,
    zs.center_longitude,
    zs.min_zoom,
    zs.max_zoom,
    zs.actif,
    zs.metadata_json,
    NOW()
FROM zones_source zs
ON CONFLICT (zone_id) DO UPDATE
SET
    city_slug = EXCLUDED.city_slug,
    nom = EXCLUDED.nom,
    geom = EXCLUDED.geom,
    bbox_west = EXCLUDED.bbox_west,
    bbox_south = EXCLUDED.bbox_south,
    bbox_east = EXCLUDED.bbox_east,
    bbox_north = EXCLUDED.bbox_north,
    center_latitude = EXCLUDED.center_latitude,
    center_longitude = EXCLUDED.center_longitude,
    min_zoom = EXCLUDED.min_zoom,
    max_zoom = EXCLUDED.max_zoom,
    actif = EXCLUDED.actif,
    metadata_json = EXCLUDED.metadata_json,
    updated_at = NOW();

DELETE FROM public.basemap_zone bz
WHERE bz.zone_id LIKE 'commune_%'
  AND NOT EXISTS (
      SELECT 1
      FROM public.commune c
      WHERE bz.zone_id = 'commune_' || c.id_commune::text
  );

COMMIT;
