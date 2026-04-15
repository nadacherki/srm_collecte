BEGIN;

CREATE TABLE IF NOT EXISTS public.basemap_zone (
    zone_id VARCHAR(100) PRIMARY KEY,
    city_slug VARCHAR(100) NOT NULL,
    nom VARCHAR(200) NOT NULL,
    geom geometry(MultiPolygon, 4326),
    bbox_west DOUBLE PRECISION NOT NULL,
    bbox_south DOUBLE PRECISION NOT NULL,
    bbox_east DOUBLE PRECISION NOT NULL,
    bbox_north DOUBLE PRECISION NOT NULL,
    center_latitude DOUBLE PRECISION NOT NULL,
    center_longitude DOUBLE PRECISION NOT NULL,
    min_zoom INTEGER NOT NULL DEFAULT 11,
    max_zoom INTEGER NOT NULL DEFAULT 19,
    actif BOOLEAN NOT NULL DEFAULT TRUE,
    metadata_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS basemap_zone_city_slug_idx
    ON public.basemap_zone (city_slug, actif);

CREATE INDEX IF NOT EXISTS basemap_zone_nom_idx
    ON public.basemap_zone (nom);

CREATE INDEX IF NOT EXISTS basemap_zone_geom_gist
    ON public.basemap_zone USING GIST (geom);

CREATE TABLE IF NOT EXISTS public.basemap_package (
    id_package BIGSERIAL PRIMARY KEY,
    zone_id VARCHAR(100) NOT NULL REFERENCES public.basemap_zone(zone_id) ON DELETE CASCADE,
    city_slug VARCHAR(100) NOT NULL,
    style VARCHAR(30) NOT NULL,
    format VARCHAR(20) NOT NULL,
    version VARCHAR(100) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    relative_path TEXT NOT NULL,
    size_bytes BIGINT,
    sha256 VARCHAR(64),
    min_zoom INTEGER,
    max_zoom INTEGER,
    generated_at TIMESTAMPTZ,
    source_name VARCHAR(255),
    attribution TEXT,
    tile_count BIGINT,
    metadata_json JSONB,
    actif BOOLEAN NOT NULL DEFAULT TRUE,
    requires_wifi BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT basemap_package_zone_style_version_key UNIQUE (zone_id, style, version)
);

CREATE INDEX IF NOT EXISTS basemap_package_city_style_idx
    ON public.basemap_package (city_slug, style, actif);

CREATE INDEX IF NOT EXISTS basemap_package_zone_idx
    ON public.basemap_package (zone_id, style, version);

CREATE INDEX IF NOT EXISTS basemap_package_relative_path_idx
    ON public.basemap_package (relative_path);

COMMIT;
