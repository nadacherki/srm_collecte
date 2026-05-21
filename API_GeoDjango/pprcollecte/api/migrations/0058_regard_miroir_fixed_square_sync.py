from django.db import migrations


REGARD_MIROIR_FIXED_SQUARE_SQL = r"""
CREATE OR REPLACE FUNCTION public.regard_miroir_square_size_m()
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT 4.0::double precision
$$;

CREATE OR REPLACE FUNCTION public.build_regard_miroir_geom(
    p_center geometry,
    p_longueur double precision DEFAULT NULL,
    p_largeur double precision DEFAULT NULL
)
RETURNS geometry
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_point geometry;
    v_srid integer;
    v_x double precision;
    v_y double precision;
    v_z double precision;
    v_size double precision;
BEGIN
    IF p_center IS NULL OR ST_IsEmpty(p_center) THEN
        RETURN NULL;
    END IF;

    IF ST_GeometryType(p_center) = 'ST_Point' THEN
        v_point := p_center;
    ELSE
        v_point := ST_PointOnSurface(p_center);
    END IF;

    v_srid := NULLIF(ST_SRID(v_point), 0);
    v_x := ST_X(v_point);
    v_y := ST_Y(v_point);
    v_z := COALESCE(ST_Z(v_point), 0.0);
    v_size := GREATEST(public.regard_miroir_square_size_m(), 0.1);

    RETURN ST_SetSRID(
        ST_MakePolygon(
            ST_MakeLine(ARRAY[
                ST_MakePoint(v_x - (v_size / 2.0), v_y - (v_size / 2.0), v_z),
                ST_MakePoint(v_x + (v_size / 2.0), v_y - (v_size / 2.0), v_z),
                ST_MakePoint(v_x + (v_size / 2.0), v_y + (v_size / 2.0), v_z),
                ST_MakePoint(v_x - (v_size / 2.0), v_y + (v_size / 2.0), v_z),
                ST_MakePoint(v_x - (v_size / 2.0), v_y - (v_size / 2.0), v_z)
            ])
        ),
        COALESCE(v_srid, 26191)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_ep_regard_miroir_from_point()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_payload jsonb;
    v_geom geometry;
    v_center geometry;
    v_existing_geom geometry;
    v_common_cols text;
    v_common_select text;
    v_common_set text;
    v_rows integer;
BEGIN
    IF pg_trigger_depth() > 1 THEN
        IF TG_OP = 'DELETE' THEN
            RETURN OLD;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_OP = 'DELETE' THEN
        UPDATE ep.ep_regard
           SET is_deleted = true,
               miroir_updated_at = now()
         WHERE fid_regard_source = OLD.fid
            OR (OLD.uuid IS NOT NULL AND uuid = OLD.uuid);
        RETURN OLD;
    END IF;

    SELECT string_agg(format('%I', mirror.column_name), ', ' ORDER BY mirror.ordinal_position),
           string_agg(format('src.%I', mirror.column_name), ', ' ORDER BY mirror.ordinal_position),
           string_agg(format('%1$I = src.%1$I', mirror.column_name), ', ' ORDER BY mirror.ordinal_position)
      INTO v_common_cols, v_common_select, v_common_set
      FROM information_schema.columns AS mirror
      JOIN information_schema.columns AS point
        ON point.table_schema = 'ep'
       AND point.table_name = 'ep_regard_point'
       AND point.column_name = mirror.column_name
     WHERE mirror.table_schema = 'ep'
       AND mirror.table_name = 'ep_regard'
       AND mirror.column_name NOT IN (
            'fid',
            'geom',
            'fid_regard_source',
            'miroir_source_table',
            'miroir_source_fid',
            'miroir_created_at',
            'miroir_updated_at'
       );

    IF v_common_cols IS NULL THEN
        RAISE EXCEPTION 'Aucune colonne commune exploitable entre ep_regard_point et ep_regard';
    END IF;

    SELECT geom
      INTO v_existing_geom
      FROM ep.ep_regard
     WHERE fid_regard_source = NEW.fid
        OR (NEW.uuid IS NOT NULL AND uuid = NEW.uuid)
     ORDER BY fid_regard_source NULLS LAST, fid
     LIMIT 1;

    IF NEW.geom IS NOT NULL AND NOT ST_IsEmpty(NEW.geom) THEN
        v_center := NEW.geom;
    ELSIF NEW.ep_coor_x IS NOT NULL AND NEW.ep_coor_y IS NOT NULL THEN
        v_center := ST_SetSRID(
            ST_MakePoint(NEW.ep_coor_x, NEW.ep_coor_y, COALESCE(NEW.ep_coor_z, 0.0)),
            26191
        );
    ELSE
        v_center := NULL;
    END IF;

    IF v_center IS NULL THEN
        v_geom := v_existing_geom;
    ELSE
        v_geom := public.build_regard_miroir_geom(v_center, NULL, NULL);
    END IF;

    v_payload := to_jsonb(NEW) - 'fid' - 'geom';

    EXECUTE format(
        'UPDATE ep.ep_regard AS dst
            SET %s,
                geom = $1,
                fid_regard_source = $2,
                miroir_source_table = ''ep_regard_point'',
                miroir_source_fid = $2,
                miroir_updated_at = now()
           FROM jsonb_populate_record(NULL::ep.ep_regard, $3) AS src
          WHERE dst.fid_regard_source = $2
             OR ($4 IS NOT NULL AND dst.uuid = $4)',
        v_common_set
    )
    USING v_geom, NEW.fid, v_payload, NEW.uuid;

    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows = 0 THEN
        EXECUTE format(
            'INSERT INTO ep.ep_regard (
                 %s,
                 geom,
                 fid_regard_source,
                 miroir_source_table,
                 miroir_source_fid,
                 miroir_created_at,
                 miroir_updated_at
             )
             SELECT
                 %s,
                 $1,
                 $2,
                 ''ep_regard_point'',
                 $2,
                 now(),
                 now()
             FROM jsonb_populate_record(NULL::ep.ep_regard, $3) AS src
             ON CONFLICT DO NOTHING',
            v_common_cols,
            v_common_select
        )
        USING v_geom, NEW.fid, v_payload;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION ep.sync_ep_regard_point_mirror()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    v_payload jsonb;
    v_point_geom geometry;
    v_square_geom geometry;
    v_common_cols text;
    v_common_select text;
    v_common_set text;
    v_rows integer;
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'DELETE' THEN
        -- ep.ep_regard is a visual mirror. Deleting the visual polygon must
        -- not delete the business point.
        RETURN OLD;
    END IF;

    SELECT string_agg(format('%I', point.column_name), ', ' ORDER BY point.ordinal_position),
           string_agg(format('src.%I', point.column_name), ', ' ORDER BY point.ordinal_position),
           string_agg(
               format('%1$I = COALESCE(src.%1$I, dst.%1$I)', point.column_name),
               ', ' ORDER BY point.ordinal_position
           )
      INTO v_common_cols, v_common_select, v_common_set
      FROM information_schema.columns AS point
      JOIN information_schema.columns AS mirror
        ON mirror.table_schema = 'ep'
       AND mirror.table_name = 'ep_regard'
       AND mirror.column_name = point.column_name
     WHERE point.table_schema = 'ep'
       AND point.table_name = 'ep_regard_point'
       AND point.column_name NOT IN (
            'fid',
            'geom'
       );

    IF v_common_cols IS NULL THEN
        RAISE EXCEPTION 'Aucune colonne commune exploitable entre ep_regard et ep_regard_point';
    END IF;

    IF NEW.geom IS NOT NULL AND NOT ST_IsEmpty(NEW.geom) THEN
        v_point_geom := ST_Force3D(ST_PointOnSurface(NEW.geom));
    ELSIF NEW.ep_coor_x IS NOT NULL AND NEW.ep_coor_y IS NOT NULL THEN
        v_point_geom := ST_SetSRID(
            ST_MakePoint(NEW.ep_coor_x, NEW.ep_coor_y, COALESCE(NEW.ep_coor_z, 0.0)),
            26191
        );
    ELSE
        v_point_geom := NULL;
    END IF;
    v_square_geom := public.build_regard_miroir_geom(v_point_geom, NULL, NULL);

    v_payload := to_jsonb(NEW)
        - 'fid'
        - 'geom'
        - 'fid_regard_source'
        - 'miroir_source_table'
        - 'miroir_source_fid'
        - 'miroir_created_at'
        - 'miroir_updated_at';

    BEGIN
        EXECUTE format(
            'UPDATE ep.ep_regard_point AS dst
                SET %s,
                    geom = COALESCE($1, dst.geom)
               FROM jsonb_populate_record(NULL::ep.ep_regard_point, $2) AS src
              WHERE ($3 IS NOT NULL AND dst.uuid = $3)
                 OR ($4 IS NOT NULL AND dst.fid = $4)',
            v_common_set
        )
        USING v_point_geom, v_payload, NEW.uuid, NEW.fid_regard_source;

        GET DIAGNOSTICS v_rows = ROW_COUNT;
    EXCEPTION
        WHEN check_violation OR not_null_violation OR foreign_key_violation THEN
            -- Le miroir est visuel. Une ancienne ligne point qui viole deja
            -- une contrainte ne doit pas bloquer l'affichage du miroir.
            RETURN NEW;
    END;

    IF v_square_geom IS NOT NULL THEN
        UPDATE ep.ep_regard AS mirror
           SET geom = v_square_geom,
               miroir_updated_at = now()
         WHERE mirror.fid = NEW.fid
           AND (
               mirror.geom IS NULL
               OR NOT ST_Equals(mirror.geom, v_square_geom)
           );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_ep_regard_miroir ON ep.ep_regard_point;
CREATE TRIGGER trg_sync_ep_regard_miroir
AFTER INSERT OR UPDATE OR DELETE ON ep.ep_regard_point
FOR EACH ROW
EXECUTE FUNCTION public.sync_ep_regard_miroir_from_point();

DROP TRIGGER IF EXISTS trg_sync_ep_regard_point_mirror ON ep.ep_regard;

UPDATE ep.ep_regard AS regard_poly
SET geom = public.build_regard_miroir_geom(
    CASE
        WHEN source.geom IS NOT NULL AND NOT ST_IsEmpty(source.geom) THEN source.geom
        WHEN source.ep_coor_x IS NOT NULL AND source.ep_coor_y IS NOT NULL
            THEN ST_SetSRID(
                ST_MakePoint(
                    source.ep_coor_x,
                    source.ep_coor_y,
                    COALESCE(source.ep_coor_z, 0.0)
                ),
                26191
            )
        ELSE NULL
    END,
    NULL,
    NULL
),
miroir_updated_at = now()
FROM ep.ep_regard_point AS source
WHERE regard_poly.fid_regard_source = source.fid
  AND (
      source.geom IS NOT NULL
      OR (
          source.ep_coor_x IS NOT NULL
          AND source.ep_coor_y IS NOT NULL
      )
  );

CREATE TRIGGER trg_sync_ep_regard_point_mirror
AFTER INSERT OR UPDATE ON ep.ep_regard
FOR EACH ROW
EXECUTE FUNCTION ep.sync_ep_regard_point_mirror();
"""


REVERSE_SQL = r"""
DROP TRIGGER IF EXISTS trg_sync_ep_regard_point_mirror ON ep.ep_regard;
DROP FUNCTION IF EXISTS ep.sync_ep_regard_point_mirror();
"""


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0057_object_geom_by_id_helper'),
    ]

    operations = [
        migrations.RunSQL(sql=REGARD_MIROIR_FIXED_SQUARE_SQL, reverse_sql=REVERSE_SQL),
    ]
