from django.db import migrations


SYNC_STRUCTURE_SQL = r'''
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sync_session_statut_check'
          AND conrelid = 'public.sync_session'::regclass
    ) THEN
        ALTER TABLE public.sync_session
            ADD CONSTRAINT sync_session_statut_check
            CHECK (statut IN ('manifest_received', 'partial', 'completed', 'failed', 'cancelled'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sync_session_counters_nonnegative_check'
          AND conrelid = 'public.sync_session'::regclass
    ) THEN
        ALTER TABLE public.sync_session
            ADD CONSTRAINT sync_session_counters_nonnegative_check
            CHECK (
                total_items >= 0
                AND total_attachments >= 0
                AND received_items >= 0
                AND received_attachments >= 0
                AND failed_items >= 0
            );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sync_session_id_agent_fkey'
          AND conrelid = 'public.sync_session'::regclass
    ) THEN
        ALTER TABLE public.sync_session
            ADD CONSTRAINT sync_session_id_agent_fkey
            FOREIGN KEY (id_agent)
            REFERENCES public.utilisateur(id_user)
            ON UPDATE CASCADE
            ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sync_session_item_statut_check'
          AND conrelid = 'public.sync_session_item'::regclass
    ) THEN
        ALTER TABLE public.sync_session_item
            ADD CONSTRAINT sync_session_item_statut_check
            CHECK (statut IN ('pending', 'received', 'validated', 'duplicate', 'rejected', 'failed'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sync_session_item_operation_check'
          AND conrelid = 'public.sync_session_item'::regclass
    ) THEN
        ALTER TABLE public.sync_session_item
            ADD CONSTRAINT sync_session_item_operation_check
            CHECK (operation IN ('upsert', 'validate', 'delete'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sync_session_item_attempts_nonnegative_check'
          AND conrelid = 'public.sync_session_item'::regclass
    ) THEN
        ALTER TABLE public.sync_session_item
            ADD CONSTRAINT sync_session_item_attempts_nonnegative_check
            CHECK (attempts >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sync_session_attachment_statut_check'
          AND conrelid = 'public.sync_session_attachment'::regclass
    ) THEN
        ALTER TABLE public.sync_session_attachment
            ADD CONSTRAINT sync_session_attachment_statut_check
            CHECK (statut IN ('pending', 'received', 'rejected', 'failed'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sync_session_attachment_photo_slot_check'
          AND conrelid = 'public.sync_session_attachment'::regclass
    ) THEN
        ALTER TABLE public.sync_session_attachment
            ADD CONSTRAINT sync_session_attachment_photo_slot_check
            CHECK (photo_slot BETWEEN 1 AND 4);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'sync_session_attachment_attempts_nonnegative_check'
          AND conrelid = 'public.sync_session_attachment'::regclass
    ) THEN
        ALTER TABLE public.sync_session_attachment
            ADD CONSTRAINT sync_session_attachment_attempts_nonnegative_check
            CHECK (attempts >= 0);
    END IF;
END $$;
'''


REVERSE_SQL = r'''
ALTER TABLE IF EXISTS public.sync_session_attachment
    DROP CONSTRAINT IF EXISTS sync_session_attachment_attempts_nonnegative_check,
    DROP CONSTRAINT IF EXISTS sync_session_attachment_photo_slot_check,
    DROP CONSTRAINT IF EXISTS sync_session_attachment_statut_check;

ALTER TABLE IF EXISTS public.sync_session_item
    DROP CONSTRAINT IF EXISTS sync_session_item_attempts_nonnegative_check,
    DROP CONSTRAINT IF EXISTS sync_session_item_operation_check,
    DROP CONSTRAINT IF EXISTS sync_session_item_statut_check;

ALTER TABLE IF EXISTS public.sync_session
    DROP CONSTRAINT IF EXISTS sync_session_id_agent_fkey,
    DROP CONSTRAINT IF EXISTS sync_session_counters_nonnegative_check,
    DROP CONSTRAINT IF EXISTS sync_session_statut_check;
'''


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0006_sync_manifest_log'),
    ]

    operations = [
        migrations.RunSQL(
            sql=SYNC_STRUCTURE_SQL,
            reverse_sql=REVERSE_SQL,
        ),
    ]
