from django.db import migrations


FORWARD_SQL = r"""
CREATE TABLE IF NOT EXISTS asst.statistique_conduite (
    id_statistique_conduite BIGSERIAL PRIMARY KEY,
    id_agent INTEGER NOT NULL REFERENCES public.utilisateur(id_user) ON DELETE RESTRICT,
    jour DATE NOT NULL,
    geom geometry(MultiLineStringZ, 26191),
    longueur_conduite_m DOUBLE PRECISION NOT NULL DEFAULT 0.0
        CHECK (longueur_conduite_m >= 0.0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    uuid UUID DEFAULT uuid_generate_v4(),
    CONSTRAINT statistique_conduite_asst_agent_jour_key UNIQUE (id_agent, jour)
);

CREATE INDEX IF NOT EXISTS statistique_conduite_asst_agent_idx
    ON asst.statistique_conduite (id_agent, jour DESC);
CREATE INDEX IF NOT EXISTS statistique_conduite_asst_jour_idx
    ON asst.statistique_conduite (jour DESC);
CREATE INDEX IF NOT EXISTS statistique_conduite_asst_geom_gix
    ON asst.statistique_conduite USING gist (geom);

CREATE TABLE IF NOT EXISTS asst.statistique_conduite_segment (
    id_statistique_conduite_segment BIGSERIAL PRIMARY KEY,
    id_statistique_conduite BIGINT NOT NULL
        REFERENCES asst.statistique_conduite(id_statistique_conduite) ON DELETE CASCADE,
    fid_regard_a INTEGER NOT NULL,
    fid_regard_b INTEGER NOT NULL,
    fid_regard_min INTEGER,
    fid_regard_max INTEGER,
    geom geometry(LineStringZ, 26191) NOT NULL,
    longueur_segment_m DOUBLE PRECISION NOT NULL DEFAULT 0.0
        CHECK (longueur_segment_m >= 0.0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ,
    uuid UUID DEFAULT uuid_generate_v4(),
    CONSTRAINT statistique_conduite_segment_asst_no_loop_chk
        CHECK (fid_regard_a <> fid_regard_b),
    CONSTRAINT statistique_conduite_segment_asst_unique_pair_key
        UNIQUE (id_statistique_conduite, fid_regard_min, fid_regard_max)
);

CREATE INDEX IF NOT EXISTS statistique_conduite_segment_asst_parent_idx
    ON asst.statistique_conduite_segment (id_statistique_conduite);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_asst_regard_a_idx
    ON asst.statistique_conduite_segment (fid_regard_a);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_asst_regard_b_idx
    ON asst.statistique_conduite_segment (fid_regard_b);
CREATE INDEX IF NOT EXISTS statistique_conduite_segment_asst_geom_gix
    ON asst.statistique_conduite_segment USING gist (geom);
"""


REVERSE_SQL = r"""
DROP TABLE IF EXISTS asst.statistique_conduite_segment;
DROP TABLE IF EXISTS asst.statistique_conduite;
"""


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0041_fix_remaining_encoding_artifacts'),
    ]

    operations = [
        migrations.RunSQL(sql=FORWARD_SQL, reverse_sql=REVERSE_SQL),
    ]
