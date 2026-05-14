import uuid

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0052_contextual_object_photos'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[
                migrations.RunSQL(
                    sql=r'''
                    CREATE EXTENSION IF NOT EXISTS pgcrypto;

                    ALTER TABLE public.objet_incomplet
                        ADD COLUMN IF NOT EXISTS uuid uuid;

                    UPDATE public.objet_incomplet
                    SET uuid = gen_random_uuid()
                    WHERE uuid IS NULL;

                    ALTER TABLE public.objet_incomplet
                        ALTER COLUMN uuid SET DEFAULT gen_random_uuid(),
                        ALTER COLUMN uuid SET NOT NULL;

                    CREATE UNIQUE INDEX IF NOT EXISTS objet_incomplet_uuid_key
                        ON public.objet_incomplet (uuid);
                    ''',
                    reverse_sql=r'''
                    DROP INDEX IF EXISTS public.objet_incomplet_uuid_key;

                    ALTER TABLE public.objet_incomplet
                        DROP COLUMN IF EXISTS uuid;
                    ''',
                ),
            ],
            state_operations=[
                migrations.AddField(
                    model_name='objetincomplet',
                    name='uuid',
                    field=models.UUIDField(default=uuid.uuid4, unique=True),
                ),
            ],
        ),
    ]
