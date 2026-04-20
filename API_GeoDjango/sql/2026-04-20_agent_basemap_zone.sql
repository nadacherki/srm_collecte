BEGIN;

CREATE TABLE IF NOT EXISTS public.agent_basemap_zone (
    id_agent_basemap_zone BIGSERIAL PRIMARY KEY,
    id_user INTEGER NOT NULL
        REFERENCES public.utilisateur(id_user)
        ON DELETE CASCADE,
    zone_id VARCHAR(100) NOT NULL
        REFERENCES public.basemap_zone(zone_id)
        ON DELETE CASCADE,
    actif BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_by INTEGER NULL
        REFERENCES public.utilisateur(id_user)
        ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata_json JSONB,
    CONSTRAINT agent_basemap_zone_user_zone_key UNIQUE (id_user, zone_id)
);

CREATE INDEX IF NOT EXISTS agent_basemap_zone_user_idx
    ON public.agent_basemap_zone (id_user, actif);

CREATE INDEX IF NOT EXISTS agent_basemap_zone_zone_idx
    ON public.agent_basemap_zone (zone_id, actif);

COMMIT;
