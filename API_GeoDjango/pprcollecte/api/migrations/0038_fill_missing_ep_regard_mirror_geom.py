from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0037_ep_regard_point_mirror_backfill"),
    ]

    operations = [
        migrations.RunSQL(
            sql="""
                UPDATE ep.ep_regard AS poly
                   SET geom = public.build_regard_miroir_geom(
                           CASE
                               WHEN point.geom IS NOT NULL
                                    AND NOT ST_IsEmpty(point.geom)
                                   THEN point.geom
                               WHEN point.ep_coor_x IS NOT NULL
                                    AND point.ep_coor_y IS NOT NULL
                                   THEN ST_SetSRID(
                                       ST_MakePoint(
                                           point.ep_coor_x,
                                           point.ep_coor_y,
                                           COALESCE(point.ep_coor_z, 0.0)
                                       ),
                                       26191
                                   )
                               ELSE NULL
                           END,
                           point.longueur,
                           point.largeur
                       ),
                       miroir_updated_at = now()
                  FROM ep.ep_regard_point AS point
                 WHERE poly.fid_regard_source = point.fid
                   AND (poly.geom IS NULL OR ST_IsEmpty(poly.geom))
                   AND (
                       (point.geom IS NOT NULL AND NOT ST_IsEmpty(point.geom))
                       OR (point.ep_coor_x IS NOT NULL AND point.ep_coor_y IS NOT NULL)
                   )
            """,
            reverse_sql=migrations.RunSQL.noop,
        ),
    ]
