# Generated manually after migrating the basemap pipeline to a single regional .pmtiles file.
# The legacy basemap_package table is left untouched in the database so that
# operators can drop it manually once they are sure no external job depends on it.

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0010_drop_evaluation_agent_state'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[],
            state_operations=[
                migrations.DeleteModel(
                    name='BasemapPackage',
                ),
            ],
        ),
    ]
