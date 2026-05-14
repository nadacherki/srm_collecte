from django.db import migrations


# Migration de retablissement geometrique pour les lignes orphelines POINT
# dont `geom IS NULL` MAIS dont `ep_coor_x` / `ep_coor_y` (et eventuellement
# `ep_coor_z`) sont renseignes. Ces lignes ont ete creees historiquement
# avec un bug : les coordonnees ponctuelles ont ete saisies, mais le
# geom 3D associe n'a jamais ete calcule -> elles disparaissaient du
# telechargement mobile (filtre `geom IS NOT NULL` cote serveur).
#
# Tables concernees apres audit :
#   ep.ep_bf, ep.ep_brc_pt, ep.ep_cone_reduc, ep.ep_hydrant, ep.ep_vanne
# Lignes restaurees : 6 au total.
#
# Tables avec orphelins NON reparables par cette migration (signal seulement) :
#   - ep.ep_traversee (2 lignes, LINESTRING sans coords extrematives)
#   - ep.ep_ventouse  (1 ligne, ni geom ni coords - probable bug mobile)
#   - ep.conduite_terrain (5/5, table buffer de transit a priori non utilisee
#     pour la cartographie cliente)
#
# La migration drop temporairement les CHECK NOT VALID applicatives
# (srm_req_*) parce qu'elles sont re-evaluees sur tout UPDATE, et les
# lignes ciblees pourraient violer une autre contrainte de la table que
# celle que l'on cherche a reparer.


BACKFILL_SQL = r"""
DO $do$
DECLARE
    rec    RECORD;
    ddl    TEXT;
    saved  TEXT[] := ARRAY[]::TEXT[];
    target_tables TEXT[] := ARRAY['ep_bf','ep_brc_pt','ep_cone_reduc','ep_hydrant','ep_vanne'];
BEGIN
    -- 1) Capture des definitions des CHECK srm_req_* sur les tables ciblees
    FOR rec IN
        SELECT
            nsp.nspname AS sch,
            cls.relname AS tbl,
            con.conname AS cname,
            pg_get_constraintdef(con.oid) AS cdef
        FROM pg_constraint con
        JOIN pg_class cls ON cls.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = cls.relnamespace
        WHERE nsp.nspname = 'ep'
          AND cls.relname = ANY(target_tables)
          AND con.conname LIKE 'srm_req_%'
    LOOP
        saved := saved || format(
            'ALTER TABLE %I.%I ADD CONSTRAINT %I %s',
            rec.sch, rec.tbl, rec.cname, rec.cdef
        );
        EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I',
                       rec.sch, rec.tbl, rec.cname);
    END LOOP;

    -- 2) Backfill : reconstitue geom 3D depuis ep_coor_x/y/z, SRID 26191
    UPDATE ep.ep_bf
       SET geom = ST_SetSRID(ST_MakePoint(ep_coor_x, ep_coor_y, COALESCE(ep_coor_z, 0)), 26191)
     WHERE geom IS NULL
       AND ep_coor_x IS NOT NULL
       AND ep_coor_y IS NOT NULL;

    UPDATE ep.ep_brc_pt
       SET geom = ST_SetSRID(ST_MakePoint(ep_coor_x, ep_coor_y, COALESCE(ep_coor_z, 0)), 26191)
     WHERE geom IS NULL
       AND ep_coor_x IS NOT NULL
       AND ep_coor_y IS NOT NULL;

    UPDATE ep.ep_cone_reduc
       SET geom = ST_SetSRID(ST_MakePoint(ep_coor_x, ep_coor_y, COALESCE(ep_coor_z, 0)), 26191)
     WHERE geom IS NULL
       AND ep_coor_x IS NOT NULL
       AND ep_coor_y IS NOT NULL;

    UPDATE ep.ep_hydrant
       SET geom = ST_SetSRID(ST_MakePoint(ep_coor_x, ep_coor_y, COALESCE(ep_coor_z, 0)), 26191)
     WHERE geom IS NULL
       AND ep_coor_x IS NOT NULL
       AND ep_coor_y IS NOT NULL;

    UPDATE ep.ep_vanne
       SET geom = ST_SetSRID(ST_MakePoint(ep_coor_x, ep_coor_y, COALESCE(ep_coor_z, 0)), 26191)
     WHERE geom IS NULL
       AND ep_coor_x IS NOT NULL
       AND ep_coor_y IS NOT NULL;

    -- 3) Recreation des CHECK NOT VALID telles qu'elles etaient
    FOREACH ddl IN ARRAY saved LOOP
        EXECUTE ddl;
    END LOOP;
END
$do$;
"""


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0054_ep_regard_point_mirror_sync'),
    ]

    operations = [
        migrations.RunSQL(sql=BACKFILL_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
