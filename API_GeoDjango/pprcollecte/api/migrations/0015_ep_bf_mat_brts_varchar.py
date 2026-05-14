from django.db import migrations, models


CONFIG_SQL = """
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ep'
          AND table_name = 'ep_bf'
          AND column_name = 'mat_brts'
    ) THEN
        ALTER TABLE ep.ep_bf
            ALTER COLUMN mat_brts TYPE varchar(400)
            USING mat_brts::varchar(400);
    END IF;
END $$;

UPDATE public.attribut_config_mobile
SET visible = false
WHERE lower(nom_champ) = 'ep_conform';

UPDATE public.attribut_config_mobile
SET type_champ = 'character varying(400)'
WHERE nom_metier = 'ep'
  AND nom_table = 'ep_bf'
  AND nom_champ = 'mat_brts';
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0014_ep_minimal_location_forms"),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunSQL(CONFIG_SQL, reverse_sql=migrations.RunSQL.noop),
            ],
            state_operations=[
                migrations.AddField(
                    model_name="epbornefontaine",
                    name="mat_brts",
                    field=models.CharField(blank=True, max_length=400, null=True),
                ),
            ],
        ),
    ]
