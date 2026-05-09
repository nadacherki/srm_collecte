from django.db import migrations


CREATE_REGARD_MIRROR_SQL = r"""
CREATE OR REPLACE FUNCTION public.regard_miroir_square_size_m()
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT 24.0::double precision
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
    v_default_size double precision;
    v_longueur double precision;
    v_largeur double precision;
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
    v_default_size := GREATEST(public.regard_miroir_square_size_m(), 0.1);
    v_longueur := CASE WHEN p_longueur IS NOT NULL AND p_longueur > 0 THEN p_longueur ELSE NULL END;
    v_largeur := CASE WHEN p_largeur IS NOT NULL AND p_largeur > 0 THEN p_largeur ELSE NULL END;

    v_longueur := COALESCE(v_longueur, v_largeur, v_default_size);
    v_largeur := COALESCE(v_largeur, v_longueur, v_default_size);

    RETURN ST_SetSRID(
        ST_MakePolygon(
            ST_MakeLine(ARRAY[
                ST_MakePoint(v_x - (v_longueur / 2.0), v_y - (v_largeur / 2.0), v_z),
                ST_MakePoint(v_x + (v_longueur / 2.0), v_y - (v_largeur / 2.0), v_z),
                ST_MakePoint(v_x + (v_longueur / 2.0), v_y + (v_largeur / 2.0), v_z),
                ST_MakePoint(v_x - (v_longueur / 2.0), v_y + (v_largeur / 2.0), v_z),
                ST_MakePoint(v_x - (v_longueur / 2.0), v_y - (v_largeur / 2.0), v_z)
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
    v_has_dimensions boolean;
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE ep.ep_regard
           SET is_deleted = true,
               miroir_updated_at = now()
         WHERE fid_regard_source = OLD.fid;
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

    v_has_dimensions := COALESCE(NEW.longueur > 0, false)
                        AND COALESCE(NEW.largeur > 0, false);

    IF v_center IS NULL THEN
        v_geom := v_existing_geom;
    ELSIF v_has_dimensions OR v_existing_geom IS NULL THEN
        v_geom := public.build_regard_miroir_geom(v_center, NEW.longueur, NEW.largeur);
    ELSE
        v_geom := v_existing_geom;
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
"""


CREATE_REGARD_MIRROR_TRIGGER_SQL = r"""
DROP TRIGGER IF EXISTS trg_sync_ep_regard_miroir ON ep.ep_regard_point;

CREATE TRIGGER trg_sync_ep_regard_miroir
AFTER INSERT OR UPDATE OR DELETE ON ep.ep_regard_point
FOR EACH ROW
EXECUTE FUNCTION public.sync_ep_regard_miroir_from_point();
"""


DROP_REGARD_MIRROR_TRIGGER_SQL = r"""
DROP TRIGGER IF EXISTS trg_sync_ep_regard_miroir ON ep.ep_regard_point;
DROP FUNCTION IF EXISTS public.sync_ep_regard_miroir_from_point();
DROP FUNCTION IF EXISTS public.build_regard_miroir_geom(geometry, double precision, double precision);
"""


def _quote_ident(identifier):
    return '"' + identifier.replace('"', '""') + '"'


def backfill_regard_points(apps, schema_editor):
    connection = schema_editor.connection
    with connection.cursor() as cursor:
        cursor.execute("SELECT to_regclass('ep.ep_regard'), to_regclass('ep.ep_regard_point')")
        regard_table, point_table = cursor.fetchone()
        if not regard_table or not point_table:
            return

        cursor.execute(
            """
            SELECT point.column_name
              FROM information_schema.columns AS point
              JOIN information_schema.columns AS poly
                ON poly.table_schema = 'ep'
               AND poly.table_name = 'ep_regard'
               AND poly.column_name = point.column_name
             WHERE point.table_schema = 'ep'
               AND point.table_name = 'ep_regard_point'
               AND point.column_name <> 'geom'
             ORDER BY point.ordinal_position
            """
        )
        columns = [row[0] for row in cursor.fetchall()]
        if not columns:
            return

        insert_columns = ", ".join(_quote_ident(column) for column in columns)
        select_columns = ", ".join(f"poly.{_quote_ident(column)}" for column in columns)

        cursor.execute(
            f"""
            INSERT INTO ep.ep_regard_point ({insert_columns}, geom)
            SELECT
                {select_columns},
                CASE
                    WHEN poly.geom IS NOT NULL AND NOT ST_IsEmpty(poly.geom) THEN
                        ST_SetSRID(
                            ST_MakePoint(
                                ST_X(ST_Centroid(poly.geom)),
                                ST_Y(ST_Centroid(poly.geom)),
                                COALESCE(poly.ep_coor_z, 0.0)
                            ),
                            26191
                        )
                    WHEN poly.ep_coor_x IS NOT NULL AND poly.ep_coor_y IS NOT NULL THEN
                        ST_SetSRID(
                            ST_MakePoint(
                                poly.ep_coor_x,
                                poly.ep_coor_y,
                                COALESCE(poly.ep_coor_z, 0.0)
                            ),
                            26191
                        )
                    ELSE NULL
                END AS geom
              FROM ep.ep_regard AS poly
             WHERE (
                    (poly.uuid IS NOT NULL AND NOT EXISTS (
                        SELECT 1 FROM ep.ep_regard_point AS point
                         WHERE point.uuid = poly.uuid
                    ))
                    OR
                    (poly.uuid IS NULL AND NOT EXISTS (
                        SELECT 1 FROM ep.ep_regard_point AS point
                         WHERE point.fid = poly.fid
                    ))
               )
               AND (
                    (poly.geom IS NOT NULL AND NOT ST_IsEmpty(poly.geom))
                    OR (poly.ep_coor_x IS NOT NULL AND poly.ep_coor_y IS NOT NULL)
               )
            """
        )

        cursor.execute(
            """
            UPDATE ep.ep_regard AS poly
               SET fid_regard_source = point.fid,
                   miroir_source_table = 'ep_regard_point',
                   miroir_source_fid = point.fid,
                   miroir_created_at = COALESCE(poly.miroir_created_at, now()),
                   miroir_updated_at = now()
              FROM ep.ep_regard_point AS point
             WHERE poly.fid_regard_source IS NULL
               AND (
                    (poly.uuid IS NOT NULL AND point.uuid = poly.uuid)
                    OR
                    (poly.uuid IS NULL AND point.fid = poly.fid)
               )
            """
        )

        cursor.execute("SELECT pg_get_serial_sequence('ep.ep_regard_point', 'fid')")
        sequence_name = cursor.fetchone()[0]
        if sequence_name:
            cursor.execute(
                f"""
                SELECT setval(
                    %s,
                    GREATEST((SELECT COALESCE(MAX(fid), 1) FROM ep.ep_regard_point), 1),
                    true
                )
                """,
                [sequence_name],
            )


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0036_ep_brc_pt_default_ep_anomalie_non"),
    ]

    operations = [
        migrations.RunSQL(
            sql=CREATE_REGARD_MIRROR_SQL,
            reverse_sql=DROP_REGARD_MIRROR_TRIGGER_SQL,
        ),
        migrations.RunPython(
            code=backfill_regard_points,
            reverse_code=migrations.RunPython.noop,
        ),
        migrations.RunSQL(
            sql=CREATE_REGARD_MIRROR_TRIGGER_SQL,
            reverse_sql="DROP TRIGGER IF EXISTS trg_sync_ep_regard_miroir ON ep.ep_regard_point;",
        ),
    ]
