BEGIN;

DROP TABLE IF EXISTS public.statistique_conduite_segment CASCADE;
DROP TABLE IF EXISTS public.statistique_conduite CASCADE;
DROP TABLE IF EXISTS public.conduite_statistique_ep_segment CASCADE;
DROP TABLE IF EXISTS public.conduite_statistique_ep CASCADE;
DROP TABLE IF EXISTS public.conduite_statique_asst_segment CASCADE;
DROP TABLE IF EXISTS public.conduite_statique_asst CASCADE;

CREATE SCHEMA IF NOT EXISTS ep;
CREATE SCHEMA IF NOT EXISTS ass;

CREATE TABLE IF NOT EXISTS ep.statistique_conduite (
    id_statistique_conduite BIGSERIAL PRIMARY KEY,
    id_agent INTEGER NOT NULL
        REFERENCES public.utilisateur(id_user)
        ON DELETE RESTRICT,
    jour DATE NOT NULL,
    geom geometry(MultiLineStringZ, 26191),
    longueur_conduite_m DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT statistique_conduite_agent_jour_key UNIQUE (id_agent, jour),
    CONSTRAINT statistique_conduite_longueur_chk CHECK (longueur_conduite_m >= 0.0)
);

CREATE TABLE IF NOT EXISTS ep.statistique_conduite_segment (
    id_statistique_conduite_segment BIGSERIAL PRIMARY KEY,
    id_statistique_conduite BIGINT NOT NULL
        REFERENCES ep.statistique_conduite(id_statistique_conduite)
        ON DELETE CASCADE,
    fid_regard_a INTEGER NOT NULL,
    fid_regard_b INTEGER NOT NULL,
    fid_regard_min INTEGER GENERATED ALWAYS AS (LEAST(fid_regard_a, fid_regard_b)) STORED,
    fid_regard_max INTEGER GENERATED ALWAYS AS (GREATEST(fid_regard_a, fid_regard_b)) STORED,
    geom geometry(LineStringZ, 26191) NOT NULL,
    longueur_segment_m DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT statistique_conduite_segment_no_loop_chk CHECK (fid_regard_a <> fid_regard_b),
    CONSTRAINT statistique_conduite_segment_longueur_chk CHECK (longueur_segment_m >= 0.0),
    CONSTRAINT statistique_conduite_segment_unique_pair_key
        UNIQUE (id_statistique_conduite, fid_regard_min, fid_regard_max)
);

CREATE TABLE IF NOT EXISTS ass.statistique_conduite (
    id_statistique_conduite BIGSERIAL PRIMARY KEY,
    id_agent INTEGER NOT NULL
        REFERENCES public.utilisateur(id_user)
        ON DELETE RESTRICT,
    jour DATE NOT NULL,
    geom geometry(MultiLineStringZ, 26191),
    longueur_conduite_m DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT statistique_conduite_agent_jour_key UNIQUE (id_agent, jour),
    CONSTRAINT statistique_conduite_longueur_chk CHECK (longueur_conduite_m >= 0.0)
);

CREATE TABLE IF NOT EXISTS ass.statistique_conduite_segment (
    id_statistique_conduite_segment BIGSERIAL PRIMARY KEY,
    id_statistique_conduite BIGINT NOT NULL
        REFERENCES ass.statistique_conduite(id_statistique_conduite)
        ON DELETE CASCADE,
    fid_regard_a INTEGER NOT NULL,
    fid_regard_b INTEGER NOT NULL,
    fid_regard_min INTEGER GENERATED ALWAYS AS (LEAST(fid_regard_a, fid_regard_b)) STORED,
    fid_regard_max INTEGER GENERATED ALWAYS AS (GREATEST(fid_regard_a, fid_regard_b)) STORED,
    geom geometry(LineStringZ, 26191) NOT NULL,
    longueur_segment_m DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT statistique_conduite_segment_no_loop_chk CHECK (fid_regard_a <> fid_regard_b),
    CONSTRAINT statistique_conduite_segment_longueur_chk CHECK (longueur_segment_m >= 0.0),
    CONSTRAINT statistique_conduite_segment_unique_pair_key
        UNIQUE (id_statistique_conduite, fid_regard_min, fid_regard_max)
);

CREATE INDEX IF NOT EXISTS statistique_conduite_agent_idx
    ON ep.statistique_conduite (id_agent, jour DESC);
CREATE INDEX IF NOT EXISTS statistique_conduite_jour_idx
    ON ep.statistique_conduite (jour DESC);
CREATE INDEX IF NOT EXISTS statistique_conduite_geom_gix
    ON ep.statistique_conduite USING GIST (geom);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_parent_idx
    ON ep.statistique_conduite_segment (id_statistique_conduite);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_regard_a_idx
    ON ep.statistique_conduite_segment (fid_regard_a);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_regard_b_idx
    ON ep.statistique_conduite_segment (fid_regard_b);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_geom_gix
    ON ep.statistique_conduite_segment USING GIST (geom);

CREATE INDEX IF NOT EXISTS statistique_conduite_agent_idx
    ON ass.statistique_conduite (id_agent, jour DESC);
CREATE INDEX IF NOT EXISTS statistique_conduite_jour_idx
    ON ass.statistique_conduite (jour DESC);
CREATE INDEX IF NOT EXISTS statistique_conduite_geom_gix
    ON ass.statistique_conduite USING GIST (geom);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_parent_idx
    ON ass.statistique_conduite_segment (id_statistique_conduite);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_regard_a_idx
    ON ass.statistique_conduite_segment (fid_regard_a);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_regard_b_idx
    ON ass.statistique_conduite_segment (fid_regard_b);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_geom_gix
    ON ass.statistique_conduite_segment USING GIST (geom);

COMMENT ON TABLE ep.statistique_conduite IS
'EP daily conduite statistics drawn by agent.';
COMMENT ON TABLE ep.statistique_conduite_segment IS
'EP unique conduite segments between two regards for a daily statistic.';
COMMENT ON TABLE ass.statistique_conduite IS
'ASS daily conduite statistics drawn by agent.';
COMMENT ON TABLE ass.statistique_conduite_segment IS
'ASS unique conduite segments between two regards for a daily statistic.';

COMMIT;
