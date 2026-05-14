CREATE TABLE IF NOT EXISTS public.sync_session (
    id_sync_session bigserial PRIMARY KEY,
    sync_uuid varchar(64) NOT NULL UNIQUE,
    id_agent integer,
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
