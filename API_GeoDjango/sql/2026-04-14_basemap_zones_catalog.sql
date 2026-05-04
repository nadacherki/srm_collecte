BEGIN;

CREATE TABLE IF NOT EXISTS public.basemap_package (
    id_package BIGSERIAL PRIMARY KEY,
    id_zone INTEGER NOT NULL
        REFERENCES public.zone(id_zone)
        ON DELETE CASCADE,
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
    CONSTRAINT basemap_package_id_zone_style_version_key UNIQUE (id_zone, style, version)
);

CREATE INDEX IF NOT EXISTS basemap_package_city_style_idx
    ON public.basemap_package (city_slug, style, actif);

CREATE INDEX IF NOT EXISTS basemap_package_id_zone_idx
    ON public.basemap_package (id_zone, style, version);

CREATE INDEX IF NOT EXISTS basemap_package_relative_path_idx
    ON public.basemap_package (relative_path);

COMMIT;
