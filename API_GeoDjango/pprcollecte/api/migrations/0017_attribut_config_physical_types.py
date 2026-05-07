from django.db import migrations


CONFIG_SQL = """
WITH geometry_types AS (
    SELECT
        f_table_schema,
        f_table_name,
        f_geometry_column,
        'geometry(' ||
        CASE upper(type)
            WHEN 'POINT' THEN CASE WHEN coord_dimension = 3 THEN 'PointZ' ELSE 'Point' END
            WHEN 'POINTZ' THEN 'PointZ'
            WHEN 'LINESTRING' THEN CASE WHEN coord_dimension = 3 THEN 'LineStringZ' ELSE 'LineString' END
            WHEN 'LINESTRINGZ' THEN 'LineStringZ'
            WHEN 'POLYGON' THEN CASE WHEN coord_dimension = 3 THEN 'PolygonZ' ELSE 'Polygon' END
            WHEN 'POLYGONZ' THEN 'PolygonZ'
            WHEN 'MULTILINESTRING' THEN CASE WHEN coord_dimension = 3 THEN 'MultiLineStringZ' ELSE 'MultiLineString' END
            WHEN 'MULTILINESTRINGZ' THEN 'MultiLineStringZ'
            WHEN 'MULTIPOLYGON' THEN CASE WHEN coord_dimension = 3 THEN 'MultiPolygonZ' ELSE 'MultiPolygon' END
            WHEN 'MULTIPOLYGONZ' THEN 'MultiPolygonZ'
            WHEN 'MULTICURVE' THEN CASE WHEN coord_dimension = 3 THEN 'MultiCurveZ' ELSE 'MultiCurve' END
            WHEN 'MULTICURVEZ' THEN 'MultiCurveZ'
            ELSE type
        END || ',' || srid || ')' AS physical_type
    FROM public.geometry_columns
),
physical_types AS (
    SELECT
        c.table_schema,
        c.table_name,
        c.column_name,
        CASE
            WHEN g.physical_type IS NOT NULL THEN g.physical_type
            WHEN c.data_type = 'character varying' AND c.character_maximum_length IS NOT NULL
                THEN 'character varying(' || c.character_maximum_length || ')'
            WHEN c.data_type = 'character' AND c.character_maximum_length IS NOT NULL
                THEN 'character(' || c.character_maximum_length || ')'
            WHEN c.data_type = 'numeric'
                 AND c.numeric_precision IS NOT NULL
                 AND c.numeric_scale IS NOT NULL
                THEN 'numeric(' || c.numeric_precision || ',' || c.numeric_scale || ')'
            WHEN c.data_type = 'numeric'
                 AND c.numeric_precision IS NOT NULL
                THEN 'numeric(' || c.numeric_precision || ')'
            WHEN c.data_type = 'USER-DEFINED'
                THEN c.udt_name
            WHEN c.data_type = 'ARRAY'
                THEN 'ARRAY'
            ELSE c.data_type
        END AS physical_type
    FROM information_schema.columns c
    LEFT JOIN geometry_types g
      ON g.f_table_schema = c.table_schema
     AND g.f_table_name = c.table_name
     AND g.f_geometry_column = c.column_name
    WHERE c.table_schema IN ('ep', 'asst', 'public')
)
UPDATE public.attribut_config_mobile a
SET type_champ = p.physical_type
FROM physical_types p
WHERE p.table_schema = a.nom_metier
  AND p.table_name = a.nom_table
  AND p.column_name = a.nom_champ
  AND a.nom_metier IN ('ep', 'asst', 'public')
  AND a.type_champ IS DISTINCT FROM p.physical_type;
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0016_conduite_terrain_visibility"),
    ]

    operations = [
        migrations.RunSQL(CONFIG_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
