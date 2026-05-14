from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0050_required_fields_allow_anomalie_incomplete"),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[],
            state_operations=[
                migrations.AlterModelTable(
                    name="assstatistiqueconduite",
                    table='"asst"."statistique_conduite"',
                ),
                migrations.AlterModelTable(
                    name="assstatistiqueconduitesegment",
                    table='"asst"."statistique_conduite_segment"',
                ),
            ],
        ),
    ]
