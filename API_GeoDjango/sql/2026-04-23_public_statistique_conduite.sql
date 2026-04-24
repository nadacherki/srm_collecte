BEGIN;

CREATE TABLE IF NOT EXISTS public.statistique_conduite (
    id_statistique_conduite BIGSERIAL PRIMARY KEY,
    id_agent INTEGER NOT NULL
        REFERENCES public.utilisateur(id_user)
        ON DELETE RESTRICT,
    jour DATE NOT NULL,
    geom geometry(MultiLineStringZ, 26191),
    longueur_conduite_m DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT statistique_conduite_longueur_chk
        CHECK (longueur_conduite_m >= 0.0),
    CONSTRAINT statistique_conduite_agent_jour_key
        UNIQUE (id_agent, jour)
);

ALTER TABLE IF EXISTS public.statistique_conduite
    ADD COLUMN IF NOT EXISTS geom geometry(MultiLineStringZ, 26191);

ALTER TABLE public.statistique_conduite
    ALTER COLUMN geom
    TYPE geometry(MultiLineStringZ, 26191)
    USING CASE
        WHEN geom IS NULL THEN NULL
        ELSE ST_Multi(geom)::geometry(MultiLineStringZ, 26191)
    END;

CREATE INDEX IF NOT EXISTS statistique_conduite_agent_idx
    ON public.statistique_conduite (id_agent, jour DESC);

CREATE INDEX IF NOT EXISTS statistique_conduite_jour_idx
    ON public.statistique_conduite (jour DESC);

CREATE INDEX IF NOT EXISTS statistique_conduite_geom_gix
    ON public.statistique_conduite
    USING GIST (geom);

CREATE TABLE IF NOT EXISTS public.statistique_conduite_segment (
    id_statistique_conduite_segment BIGSERIAL PRIMARY KEY,
    id_statistique_conduite BIGINT NOT NULL
        REFERENCES public.statistique_conduite(id_statistique_conduite)
        ON DELETE CASCADE,
    fid_regard_a INTEGER NOT NULL
        REFERENCES ep.regard(fid)
        ON DELETE RESTRICT,
    fid_regard_b INTEGER NOT NULL
        REFERENCES ep.regard(fid)
        ON DELETE RESTRICT,
    fid_regard_min INTEGER GENERATED ALWAYS AS (LEAST(fid_regard_a, fid_regard_b)) STORED,
    fid_regard_max INTEGER GENERATED ALWAYS AS (GREATEST(fid_regard_a, fid_regard_b)) STORED,
    geom geometry(LineStringZ, 26191) NOT NULL,
    longueur_segment_m DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT statistique_conduite_segment_no_loop_chk
        CHECK (fid_regard_a <> fid_regard_b),
    CONSTRAINT statistique_conduite_segment_longueur_chk
        CHECK (longueur_segment_m >= 0.0),
    CONSTRAINT statistique_conduite_segment_unique_pair_key
        UNIQUE (id_statistique_conduite, fid_regard_min, fid_regard_max)
);

CREATE INDEX IF NOT EXISTS statistique_conduite_segment_parent_idx
    ON public.statistique_conduite_segment (id_statistique_conduite);

CREATE INDEX IF NOT EXISTS statistique_conduite_segment_regard_a_idx
    ON public.statistique_conduite_segment (fid_regard_a);

CREATE INDEX IF NOT EXISTS statistique_conduite_segment_regard_b_idx
    ON public.statistique_conduite_segment (fid_regard_b);

CREATE INDEX IF NOT EXISTS statistique_conduite_segment_geom_gix
    ON public.statistique_conduite_segment
    USING GIST (geom);

CREATE OR REPLACE FUNCTION public.refresh_statistique_conduite_from_segments(
    p_id_statistique_conduite BIGINT
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_geom geometry(MultiLineStringZ, 26191);
    v_longueur DOUBLE PRECISION;
BEGIN
    SELECT
        CASE
            WHEN COUNT(*) = 0 THEN NULL
            ELSE ST_Multi(ST_Collect(s.geom))::geometry(MultiLineStringZ, 26191)
        END,
        COALESCE(SUM(s.longueur_segment_m), 0.0)
    INTO v_geom, v_longueur
    FROM public.statistique_conduite_segment s
    WHERE s.id_statistique_conduite = p_id_statistique_conduite;

    UPDATE public.statistique_conduite
       SET geom = v_geom,
           longueur_conduite_m = v_longueur,
           updated_at = NOW()
     WHERE id_statistique_conduite = p_id_statistique_conduite;
END;
$$;

CREATE OR REPLACE FUNCTION public.statistique_conduite_segment_before_write()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.longueur_segment_m := COALESCE(ST_Length(ST_Force2D(NEW.geom)), 0.0);
    NEW.updated_at := NOW();

    IF TG_OP = 'INSERT' AND NEW.created_at IS NULL THEN
        NEW.created_at := NOW();
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.statistique_conduite_segment_after_write()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_target_id BIGINT;
BEGIN
    v_target_id := COALESCE(NEW.id_statistique_conduite, OLD.id_statistique_conduite);
    PERFORM public.refresh_statistique_conduite_from_segments(v_target_id);
    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_statistique_conduite_segment_before_write
    ON public.statistique_conduite_segment;

CREATE TRIGGER trg_statistique_conduite_segment_before_write
BEFORE INSERT OR UPDATE
ON public.statistique_conduite_segment
FOR EACH ROW
EXECUTE FUNCTION public.statistique_conduite_segment_before_write();

DROP TRIGGER IF EXISTS trg_statistique_conduite_segment_after_write
    ON public.statistique_conduite_segment;

CREATE TRIGGER trg_statistique_conduite_segment_after_write
AFTER INSERT OR UPDATE OR DELETE
ON public.statistique_conduite_segment
FOR EACH ROW
EXECUTE FUNCTION public.statistique_conduite_segment_after_write();

COMMENT ON TABLE public.statistique_conduite IS
'Statistique journaliere agregée de conduite dessinee par agent. La geometrie est une MultiLineString de segments uniques.';

COMMENT ON COLUMN public.statistique_conduite.geom IS
'Geometrie agregee des segments uniques de conduite pour l''agent et le jour donnes.';

COMMENT ON COLUMN public.statistique_conduite.longueur_conduite_m IS
'Longueur totale en metres des segments uniques de conduite pour l''agent et le jour donnes.';

COMMENT ON TABLE public.statistique_conduite_segment IS
'Segments uniques de conduite dessines entre deux regards pour une statistique journaliere donnee.';

COMMENT ON COLUMN public.statistique_conduite_segment.longueur_segment_m IS
'Longueur 2D en metres du segment unique entre deux regards.';

COMMIT;
