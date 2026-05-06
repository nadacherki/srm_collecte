# Generated manually after renaming public.commune to public.commune_oriental.

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0008_assbassin_assbranchement_asscanalisation_and_more'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[],
            state_operations=[
                migrations.AlterModelTable(
                    name='commune',
                    table='commune_oriental',
                ),
            ],
        ),
    ]
