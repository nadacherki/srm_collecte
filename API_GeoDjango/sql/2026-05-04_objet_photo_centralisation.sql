BEGIN;

CREATE TABLE IF NOT EXISTS public.objet_photo (
    id_photo BIGSERIAL PRIMARY KEY,
    uuid_objet VARCHAR(254) NOT NULL,
    nom_schema VARCHAR(20) NOT NULL,
    nom_table VARCHAR(100) NOT NULL,
    num_photo SMALLINT NOT NULL,
    nom_fichier VARCHAR(255) NOT NULL,
    chemin_relatif TEXT NOT NULL,
    hash_sha256 CHAR(64),
    mime_type VARCHAR(100),
    taille_octets BIGINT,
    id_agent_crea INTEGER,
    date_upload TIMESTAMPTZ NOT NULL DEFAULT now(),
    actif BOOLEAN NOT NULL DEFAULT true,
    date_prise_reelle TIMESTAMPTZ,
    CONSTRAINT objet_photo_num_photo_check CHECK (num_photo BETWEEN 1 AND 4),
    CONSTRAINT objet_photo_nom_schema_nom_table_uuid_objet_num_photo_key
        UNIQUE (nom_schema, nom_table, uuid_objet, num_photo)
);

CREATE INDEX IF NOT EXISTS objet_photo_uuid_objet_idx
    ON public.objet_photo (uuid_objet);

CREATE INDEX IF NOT EXISTS objet_photo_schema_table_uuid_idx
    ON public.objet_photo (nom_schema, nom_table, uuid_objet);

CREATE INDEX IF NOT EXISTS objet_photo_table_uuid_idx
    ON public.objet_photo (nom_schema, nom_table, uuid_objet);

CREATE INDEX IF NOT EXISTS objet_photo_date_upload_idx
    ON public.objet_photo (date_upload DESC);

CREATE INDEX IF NOT EXISTS objet_photo_date_prise_reelle_idx
    ON public.objet_photo (date_prise_reelle DESC)
    WHERE date_prise_reelle IS NOT NULL;

DO $$
DECLARE
    r RECORD;
    v_slot SMALLINT;
    v_agent_expr TEXT;
    v_date_expr TEXT;
BEGIN
    FOR r IN
        SELECT table_schema, table_name, column_name
        FROM information_schema.columns
        WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'public')
          AND column_name ~* '^photo_[1-4]$'
        ORDER BY table_schema, table_name, column_name
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = r.table_schema
              AND table_name = r.table_name
              AND column_name = 'uuid'
        ) THEN
            CONTINUE;
        END IF;

        v_slot := split_part(r.column_name, '_', 2)::SMALLINT;

        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = r.table_schema
              AND table_name = r.table_name
              AND column_name = 'id_agent_crea'
        ) THEN
            v_agent_expr := 'id_agent_crea';
        ELSIF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = r.table_schema
              AND table_name = r.table_name
              AND column_name = 'id_user_creat'
        ) THEN
            v_agent_expr := 'id_user_creat';
        ELSE
            v_agent_expr := 'NULL';
        END IF;

        v_date_expr := 'now()';
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = r.table_schema
              AND table_name = r.table_name
              AND column_name = 'date_modif'
        ) THEN
            v_date_expr := 'COALESCE(date_modif, now())';
        ELSIF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = r.table_schema
              AND table_name = r.table_name
              AND column_name = 'updated_at'
        ) THEN
            v_date_expr := 'COALESCE(updated_at, now())';
        ELSIF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = r.table_schema
              AND table_name = r.table_name
              AND column_name = 'date_creation'
        ) THEN
            v_date_expr := 'COALESCE(date_creation, now())';
        ELSIF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = r.table_schema
              AND table_name = r.table_name
              AND column_name = 'created_at'
        ) THEN
            v_date_expr := 'COALESCE(created_at, now())';
        END IF;

        EXECUTE format(
            $SQL$
            WITH src AS (
                SELECT
                    uuid::text AS uuid_objet,
                    btrim(%1$I::text) AS chemin_relatif,
                    %2$s AS id_agent_crea,
                    %3$s AS date_upload
                FROM %4$I.%5$I
                WHERE %1$I IS NOT NULL
                  AND btrim(%1$I::text) <> ''
                  AND uuid IS NOT NULL
                  AND btrim(uuid::text) <> ''
            )
            INSERT INTO public.objet_photo (
                uuid_objet,
                nom_schema,
                nom_table,
                num_photo,
                nom_fichier,
                chemin_relatif,
                id_agent_crea,
                date_upload,
                actif
            )
            SELECT
                uuid_objet,
                %6$L,
                %7$L,
                %8$L::SMALLINT,
                LEFT(COALESCE(NULLIF(regexp_replace(chemin_relatif, '^.*[\\/]', ''), ''), chemin_relatif), 255),
                chemin_relatif,
                id_agent_crea,
                date_upload,
                true
            FROM src
            ON CONFLICT (nom_schema, nom_table, uuid_objet, num_photo)
            DO UPDATE SET
                nom_fichier = EXCLUDED.nom_fichier,
                chemin_relatif = EXCLUDED.chemin_relatif,
                id_agent_crea = EXCLUDED.id_agent_crea,
                date_upload = EXCLUDED.date_upload,
                actif = true
            $SQL$,
            r.column_name,
            v_agent_expr,
            v_date_expr,
            r.table_schema,
            r.table_name,
            r.table_schema,
            r.table_name,
            v_slot
        );
    END LOOP;
END $$;

CREATE TABLE IF NOT EXISTS public.objet_photo_source_column_backup_20260504 (
    id_backup BIGSERIAL PRIMARY KEY,
    nom_schema VARCHAR(30) NOT NULL,
    nom_table VARCHAR(100) NOT NULL,
    uuid_objet VARCHAR(254) NOT NULL,
    source_column VARCHAR(30) NOT NULL,
    source_value TEXT NOT NULL,
    backed_up_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (nom_schema, nom_table, uuid_objet, source_column, source_value)
);

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT table_schema, table_name, column_name
        FROM information_schema.columns
        WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'public')
          AND column_name ~* '^photo_[1-4]$'
        ORDER BY table_schema, table_name, column_name
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = r.table_schema
              AND table_name = r.table_name
              AND column_name = 'uuid'
        ) THEN
            CONTINUE;
        END IF;

        EXECUTE format(
            $SQL$
            WITH src AS (
                SELECT uuid::text AS uuid_objet, btrim(%1$I::text) AS source_value
                FROM %2$I.%3$I
                WHERE %1$I IS NOT NULL
                  AND btrim(%1$I::text) <> ''
                  AND uuid IS NOT NULL
                  AND btrim(uuid::text) <> ''
            )
            INSERT INTO public.objet_photo_source_column_backup_20260504 (
                nom_schema, nom_table, uuid_objet, source_column, source_value
            )
            SELECT %4$L, %5$L, uuid_objet, %6$L, source_value
            FROM src
            ON CONFLICT DO NOTHING
            $SQL$,
            r.column_name,
            r.table_schema,
            r.table_name,
            r.table_schema,
            r.table_name,
            r.column_name
        );

        EXECUTE format(
            'UPDATE %1$I.%2$I SET %3$I = NULL WHERE %3$I IS NOT NULL AND btrim(%3$I::text) <> ''''',
            r.table_schema,
            r.table_name,
            r.column_name
        );
    END LOOP;
END $$;

CREATE TABLE IF NOT EXISTS public.objet_photo_legacy_reference_backup_20260504 (
    id_backup BIGSERIAL PRIMARY KEY,
    nom_schema VARCHAR(30) NOT NULL,
    nom_table VARCHAR(100) NOT NULL,
    uuid_objet VARCHAR(254),
    source_column VARCHAR(100) NOT NULL,
    source_value TEXT NOT NULL,
    backed_up_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS objet_photo_legacy_reference_backup_20260504_uniq
    ON public.objet_photo_legacy_reference_backup_20260504 (
        nom_schema,
        nom_table,
        COALESCE(uuid_objet, ''),
        source_column,
        source_value
    );

DO $$
DECLARE
    r RECORD;
    v_uuid_expr TEXT;
BEGIN
    FOR r IN
        SELECT table_schema, table_name, column_name
        FROM information_schema.columns
        WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'public')
          AND column_name ~* '(^|_)photo$'
          AND column_name !~* '^photo_[1-4]$'
        ORDER BY table_schema, table_name, column_name
    LOOP
        IF EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = r.table_schema
              AND table_name = r.table_name
              AND column_name = 'uuid'
        ) THEN
            v_uuid_expr := 'uuid::text';
        ELSE
            v_uuid_expr := 'NULL';
        END IF;

        EXECUTE format(
            $SQL$
            WITH src AS (
                SELECT %1$s AS uuid_objet, btrim(%2$I::text) AS source_value
                FROM %3$I.%4$I
                WHERE %2$I IS NOT NULL
                  AND btrim(%2$I::text) <> ''
            )
            INSERT INTO public.objet_photo_legacy_reference_backup_20260504 (
                nom_schema, nom_table, uuid_objet, source_column, source_value
            )
            SELECT %5$L, %6$L, uuid_objet, %7$L, source_value
            FROM src
            ON CONFLICT DO NOTHING
            $SQL$,
            v_uuid_expr,
            r.column_name,
            r.table_schema,
            r.table_name,
            r.table_schema,
            r.table_name,
            r.column_name
        );

        EXECUTE format(
            'UPDATE %1$I.%2$I SET %3$I = NULL WHERE %3$I IS NOT NULL AND btrim(%3$I::text) <> ''''',
            r.table_schema,
            r.table_name,
            r.column_name
        );
    END LOOP;
END $$;

DO $$
DECLARE
    v_nom_schema_len INTEGER;
BEGIN
    SELECT character_maximum_length
    INTO v_nom_schema_len
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'vw_srm_photo_fact'
      AND column_name = 'nom_schema';

    v_nom_schema_len := COALESCE(v_nom_schema_len, 20);

    EXECUTE format(
        $SQL$
        CREATE OR REPLACE VIEW public.vw_srm_photo_fact AS
        SELECT
            md5(concat_ws('|', 'photo', p.id_photo::text, COALESCE(p.uuid_objet, ''))) AS photo_uid,
            p.id_photo,
            o.id_objet,
            p.uuid_objet::varchar(254) AS uuid_objet,
            p.nom_schema::varchar(%1$s) AS nom_schema,
            p.nom_table::varchar(100) AS nom_table,
            (p.nom_schema || '.' || p.nom_table)::varchar(100) AS nom_classe,
            COALESCE(o.metier, p.nom_schema)::varchar(10) AS metier,
            COALESCE(p.id_agent_crea, o.id_agent_crea) AS id_agent,
            o.type_geometrie,
            o.famille_geometrie,
            p.num_photo,
            p.nom_fichier,
            p.chemin_relatif,
            p.hash_sha256,
            p.mime_type,
            p.taille_octets,
            p.actif,
            p.date_prise_reelle,
            p.date_upload,
            p.date_upload::date AS jour_upload,
            COALESCE(p.date_prise_reelle, p.date_upload) AS date_photo_reference,
            COALESCE(p.date_prise_reelle, p.date_upload)::date AS jour_photo
        FROM public.objet_photo p
        LEFT JOIN public.vw_srm_objet_fact o
          ON o.nom_schema::text = p.nom_schema::text
         AND o.nom_table::text = p.nom_table::text
         AND o.uuid_objet::text = p.uuid_objet::text
        $SQL$,
        v_nom_schema_len
    );
END $$;

DELETE FROM public.objet_photo p
WHERE NOT EXISTS (
    SELECT 1
    FROM public.vw_srm_objet_fact o
    WHERE o.nom_schema::text = p.nom_schema::text
      AND o.nom_table::text = p.nom_table::text
      AND o.uuid_objet::text = p.uuid_objet::text
);

COMMIT;
