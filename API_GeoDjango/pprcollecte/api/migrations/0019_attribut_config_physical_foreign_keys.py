from django.db import migrations


CONFIG_SQL = """
WITH physical_fk AS (
    SELECT kcu.table_schema,
           kcu.table_name,
           kcu.column_name,
           ref_kcu.table_schema AS ref_schema,
           ref_kcu.table_name AS ref_table,
           ref_kcu.column_name AS ref_column
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_catalog = kcu.constraint_catalog
     AND tc.constraint_schema = kcu.constraint_schema
     AND tc.constraint_name = kcu.constraint_name
     AND tc.table_schema = kcu.table_schema
     AND tc.table_name = kcu.table_name
    JOIN information_schema.referential_constraints rc
      ON rc.constraint_catalog = tc.constraint_catalog
     AND rc.constraint_schema = tc.constraint_schema
     AND rc.constraint_name = tc.constraint_name
    JOIN information_schema.key_column_usage ref_kcu
      ON ref_kcu.constraint_catalog = rc.unique_constraint_catalog
     AND ref_kcu.constraint_schema = rc.unique_constraint_schema
     AND ref_kcu.constraint_name = rc.unique_constraint_name
     AND ref_kcu.ordinal_position = kcu.position_in_unique_constraint
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND tc.table_schema IN ('ep', 'asst', 'public')
),
target_config AS (
    SELECT a.id,
           COALESCE((p.column_name IS NOT NULL), false) AS physical_foreign_key,
           CASE
               WHEN p.column_name IS NULL THEN NULL
               ELSE p.ref_schema || '.' || p.ref_table || '.' || p.ref_column
           END AS physical_reference_fk
    FROM public.attribut_config_mobile a
    LEFT JOIN physical_fk p
      ON p.table_schema = a.nom_metier
     AND p.table_name = a.nom_table
     AND p.column_name = a.nom_champ
    WHERE a.nom_metier IN ('ep', 'asst', 'public')
)
UPDATE public.attribut_config_mobile a
SET foreign_key = t.physical_foreign_key,
    reference_fk = t.physical_reference_fk
FROM target_config t
WHERE t.id = a.id
  AND (
      COALESCE(a.foreign_key, false) IS DISTINCT FROM t.physical_foreign_key
      OR a.reference_fk IS DISTINCT FROM t.physical_reference_fk
  );
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0018_drop_ep_updated_at"),
    ]

    operations = [
        migrations.RunSQL(CONFIG_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
