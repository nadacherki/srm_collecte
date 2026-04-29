import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0005_sync_ep_unmanaged_columns'),
    ]

    operations = [
        migrations.RunSQL(
            sql=r'''
            CREATE TABLE IF NOT EXISTS public.sync_session (
                id_sync_session bigserial PRIMARY KEY,
                sync_uuid varchar(64) NOT NULL UNIQUE,
                id_agent integer,
                id_projet integer,
                id_mission integer,
                device_id varchar(128),
                app_version varchar(64),
                statut varchar(30) NOT NULL DEFAULT 'manifest_received',
                total_items integer NOT NULL DEFAULT 0,
                total_attachments integer NOT NULL DEFAULT 0,
                received_items integer NOT NULL DEFAULT 0,
                received_attachments integer NOT NULL DEFAULT 0,
                failed_items integer NOT NULL DEFAULT 0,
                started_at timestamptz,
                last_activity_at timestamptz,
                completed_at timestamptz,
                metadata_json jsonb,
                last_error text
            );

            CREATE TABLE IF NOT EXISTS public.sync_session_item (
                id_sync_item bigserial PRIMARY KEY,
                id_sync_session bigint NOT NULL
                    REFERENCES public.sync_session(id_sync_session)
                    ON DELETE CASCADE,
                client_item_uuid varchar(128),
                nom_schema varchar(30) NOT NULL,
                nom_table varchar(100) NOT NULL,
                uuid_objet varchar(254) NOT NULL,
                local_id bigint,
                operation varchar(30) NOT NULL DEFAULT 'upsert',
                payload_hash varchar(64),
                statut varchar(30) NOT NULL DEFAULT 'pending',
                attempts integer NOT NULL DEFAULT 0,
                last_error text,
                received_at timestamptz,
                last_activity_at timestamptz,
                response_pk varchar(128),
                response_uuid varchar(254),
                payload_summary_json jsonb,
                CONSTRAINT uq_sync_session_item_object
                    UNIQUE (id_sync_session, nom_schema, nom_table, uuid_objet)
            );

            CREATE TABLE IF NOT EXISTS public.sync_session_attachment (
                id_sync_attachment bigserial PRIMARY KEY,
                id_sync_session bigint NOT NULL
                    REFERENCES public.sync_session(id_sync_session)
                    ON DELETE CASCADE,
                nom_schema varchar(30) NOT NULL,
                nom_table varchar(100) NOT NULL,
                uuid_objet varchar(254) NOT NULL,
                photo_slot smallint NOT NULL,
                local_path text,
                sha256 varchar(64),
                taille_octets bigint,
                statut varchar(30) NOT NULL DEFAULT 'pending',
                attempts integer NOT NULL DEFAULT 0,
                last_error text,
                received_at timestamptz,
                last_activity_at timestamptz,
                remote_path text,
                CONSTRAINT uq_sync_session_attachment_object
                    UNIQUE (id_sync_session, nom_schema, nom_table, uuid_objet, photo_slot)
            );

            CREATE INDEX IF NOT EXISTS sync_session_agent_status_idx
                ON public.sync_session (id_agent, statut, started_at DESC);
            CREATE INDEX IF NOT EXISTS sync_session_item_status_idx
                ON public.sync_session_item (id_sync_session, statut);
            CREATE INDEX IF NOT EXISTS sync_session_item_object_idx
                ON public.sync_session_item (nom_schema, nom_table, uuid_objet);
            CREATE INDEX IF NOT EXISTS sync_session_attachment_status_idx
                ON public.sync_session_attachment (id_sync_session, statut);
            CREATE INDEX IF NOT EXISTS sync_session_attachment_object_idx
                ON public.sync_session_attachment (nom_schema, nom_table, uuid_objet, photo_slot);
            ''',
            reverse_sql=r'''
            DROP TABLE IF EXISTS public.sync_session_attachment;
            DROP TABLE IF EXISTS public.sync_session_item;
            DROP TABLE IF EXISTS public.sync_session;
            ''',
            state_operations=[
                migrations.CreateModel(
                    name='SyncSession',
                    fields=[
                        ('id_sync_session', models.BigAutoField(primary_key=True, serialize=False)),
                        ('sync_uuid', models.CharField(max_length=64, unique=True)),
                        ('id_agent', models.IntegerField(blank=True, null=True)),
                        ('id_projet', models.IntegerField(blank=True, null=True)),
                        ('id_mission', models.IntegerField(blank=True, null=True)),
                        ('device_id', models.CharField(blank=True, max_length=128, null=True)),
                        ('app_version', models.CharField(blank=True, max_length=64, null=True)),
                        ('statut', models.CharField(default='manifest_received', max_length=30)),
                        ('total_items', models.IntegerField(default=0)),
                        ('total_attachments', models.IntegerField(default=0)),
                        ('received_items', models.IntegerField(default=0)),
                        ('received_attachments', models.IntegerField(default=0)),
                        ('failed_items', models.IntegerField(default=0)),
                        ('started_at', models.DateTimeField(blank=True, null=True)),
                        ('last_activity_at', models.DateTimeField(blank=True, null=True)),
                        ('completed_at', models.DateTimeField(blank=True, null=True)),
                        ('metadata_json', models.JSONField(blank=True, null=True)),
                        ('last_error', models.TextField(blank=True, null=True)),
                    ],
                    options={
                        'db_table': 'sync_session',
                        'managed': False,
                    },
                ),
                migrations.CreateModel(
                    name='SyncSessionItem',
                    fields=[
                        ('id_sync_item', models.BigAutoField(primary_key=True, serialize=False)),
                        ('client_item_uuid', models.CharField(blank=True, max_length=128, null=True)),
                        ('nom_schema', models.CharField(max_length=30)),
                        ('nom_table', models.CharField(max_length=100)),
                        ('uuid_objet', models.CharField(max_length=254)),
                        ('local_id', models.BigIntegerField(blank=True, null=True)),
                        ('operation', models.CharField(default='upsert', max_length=30)),
                        ('payload_hash', models.CharField(blank=True, max_length=64, null=True)),
                        ('statut', models.CharField(default='pending', max_length=30)),
                        ('attempts', models.IntegerField(default=0)),
                        ('last_error', models.TextField(blank=True, null=True)),
                        ('received_at', models.DateTimeField(blank=True, null=True)),
                        ('last_activity_at', models.DateTimeField(blank=True, null=True)),
                        ('response_pk', models.CharField(blank=True, max_length=128, null=True)),
                        ('response_uuid', models.CharField(blank=True, max_length=254, null=True)),
                        ('payload_summary_json', models.JSONField(blank=True, null=True)),
                        (
                            'sync_session',
                            models.ForeignKey(
                                db_column='id_sync_session',
                                on_delete=django.db.models.deletion.CASCADE,
                                related_name='items',
                                to='api.syncsession',
                            ),
                        ),
                    ],
                    options={
                        'db_table': 'sync_session_item',
                        'managed': False,
                    },
                ),
                migrations.CreateModel(
                    name='SyncSessionAttachment',
                    fields=[
                        ('id_sync_attachment', models.BigAutoField(primary_key=True, serialize=False)),
                        ('nom_schema', models.CharField(max_length=30)),
                        ('nom_table', models.CharField(max_length=100)),
                        ('uuid_objet', models.CharField(max_length=254)),
                        ('photo_slot', models.SmallIntegerField()),
                        ('local_path', models.TextField(blank=True, null=True)),
                        ('sha256', models.CharField(blank=True, max_length=64, null=True)),
                        ('taille_octets', models.BigIntegerField(blank=True, null=True)),
                        ('statut', models.CharField(default='pending', max_length=30)),
                        ('attempts', models.IntegerField(default=0)),
                        ('last_error', models.TextField(blank=True, null=True)),
                        ('received_at', models.DateTimeField(blank=True, null=True)),
                        ('last_activity_at', models.DateTimeField(blank=True, null=True)),
                        ('remote_path', models.TextField(blank=True, null=True)),
                        (
                            'sync_session',
                            models.ForeignKey(
                                db_column='id_sync_session',
                                on_delete=django.db.models.deletion.CASCADE,
                                related_name='attachments',
                                to='api.syncsession',
                            ),
                        ),
                    ],
                    options={
                        'db_table': 'sync_session_attachment',
                        'managed': False,
                    },
                ),
            ],
        ),
    ]
