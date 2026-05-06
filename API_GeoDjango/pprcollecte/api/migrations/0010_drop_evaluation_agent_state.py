# Generated manually after confirming public.evaluation_agent is not part of the project schema.

from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0009_commune_oriental_state'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[],
            state_operations=[
                migrations.DeleteModel(
                    name='EvaluationAgent',
                ),
            ],
        ),
    ]
