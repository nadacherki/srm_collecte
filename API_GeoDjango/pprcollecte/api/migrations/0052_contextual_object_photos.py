from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0051_align_asst_statistique_model_state'),
    ]

    operations = [
        migrations.RunSQL(
            sql=r'''
            ALTER TABLE public.objet_photo
                ADD COLUMN IF NOT EXISTS contexte_photo varchar(40),
                ADD COLUMN IF NOT EXISTS id_intervention_anomalie integer;

            UPDATE public.objet_photo
            SET contexte_photo = 'collecte_initiale'
            WHERE contexte_photo IS NULL OR btrim(contexte_photo) = '';

            UPDATE public.objet_photo
            SET id_intervention_anomalie = 0
            WHERE id_intervention_anomalie IS NULL;

            ALTER TABLE public.objet_photo
                ALTER COLUMN contexte_photo SET DEFAULT 'collecte_initiale',
                ALTER COLUMN contexte_photo SET NOT NULL,
                ALTER COLUMN id_intervention_anomalie SET DEFAULT 0,
                ALTER COLUMN id_intervention_anomalie SET NOT NULL;

            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_constraint
                    WHERE conname = 'objet_photo_context_check'
                ) THEN
                    ALTER TABLE public.objet_photo
                        ADD CONSTRAINT objet_photo_context_check
                        CHECK (
                            contexte_photo IN (
                                'collecte_initiale',
                                'anomalie_avant',
                                'retour_terrain_apres',
                                'incomplet_initial',
                                'incomplet_complement'
                            )
                        );
                END IF;
            END $$;

            ALTER TABLE public.objet_photo
                DROP CONSTRAINT IF EXISTS objet_photo_nom_schema_nom_table_uuid_objet_num_photo_key;
            DROP INDEX IF EXISTS public.objet_photo_nom_schema_nom_table_uuid_objet_num_photo_key;
            CREATE UNIQUE INDEX IF NOT EXISTS objet_photo_context_slot_key
                ON public.objet_photo (
                    nom_schema,
                    nom_table,
                    uuid_objet,
                    contexte_photo,
                    id_intervention_anomalie,
                    num_photo
                );

            ALTER TABLE public.sync_session_attachment
                ADD COLUMN IF NOT EXISTS photo_context varchar(40),
                ADD COLUMN IF NOT EXISTS id_intervention_anomalie integer;

            UPDATE public.sync_session_attachment
            SET photo_context = 'collecte_initiale'
            WHERE photo_context IS NULL OR btrim(photo_context) = '';

            UPDATE public.sync_session_attachment
            SET id_intervention_anomalie = 0
            WHERE id_intervention_anomalie IS NULL;

            ALTER TABLE public.sync_session_attachment
                ALTER COLUMN photo_context SET DEFAULT 'collecte_initiale',
                ALTER COLUMN photo_context SET NOT NULL,
                ALTER COLUMN id_intervention_anomalie SET DEFAULT 0,
                ALTER COLUMN id_intervention_anomalie SET NOT NULL;

            ALTER TABLE public.sync_session_attachment
                DROP CONSTRAINT IF EXISTS uq_sync_session_attachment_object;

            DO $$
            BEGIN
                IF NOT EXISTS (
                    SELECT 1
                    FROM pg_constraint
                    WHERE conname = 'uq_sync_session_attachment_object_context'
                ) THEN
                    ALTER TABLE public.sync_session_attachment
                        ADD CONSTRAINT uq_sync_session_attachment_object_context
                        UNIQUE (
                            id_sync_session,
                            nom_schema,
                            nom_table,
                            uuid_objet,
                            photo_context,
                            id_intervention_anomalie,
                            photo_slot
                        );
                END IF;
            END $$;

            CREATE INDEX IF NOT EXISTS sync_session_attachment_object_context_idx
                ON public.sync_session_attachment (
                    nom_schema,
                    nom_table,
                    uuid_objet,
                    photo_context,
                    id_intervention_anomalie,
                    photo_slot
                );
            ''',
            reverse_sql=r'''
            ALTER TABLE public.sync_session_attachment
                DROP CONSTRAINT IF EXISTS uq_sync_session_attachment_object_context;

            ALTER TABLE public.sync_session_attachment
                ADD CONSTRAINT uq_sync_session_attachment_object
                UNIQUE (id_sync_session, nom_schema, nom_table, uuid_objet, photo_slot);

            DROP INDEX IF EXISTS public.sync_session_attachment_object_context_idx;
            DROP INDEX IF EXISTS public.objet_photo_context_slot_key;

            CREATE UNIQUE INDEX IF NOT EXISTS
                objet_photo_nom_schema_nom_table_uuid_objet_num_photo_key
                ON public.objet_photo (
                    nom_schema,
                    nom_table,
                    uuid_objet,
                    num_photo
                );
            ''',
        ),
    ]
