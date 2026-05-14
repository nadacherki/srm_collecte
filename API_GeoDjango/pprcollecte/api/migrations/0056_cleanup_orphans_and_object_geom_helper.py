from django.db import migrations


# Cette migration traite les "nuances de telechargement" residuelles :
#
#   1) Nettoyage des 8 lignes orphelines `geom IS NULL` non-recuperables par
#      les migrations 0054/0055 (table buffer ou saisie cassee sans coords).
#      On les marque `is_deleted = true` pour qu'elles disparaissent des
#      vues mobile (le filtre WHERE NOT is_deleted s'applique cote serveur).
#
#   2) Ajout de la fonction public.srm_object_geom(nom_table text, uuid uuid)
#      qui resout dynamiquement la geometrie d'un objet metier a partir de
#      sa reference (schema.table + uuid). Utilisee par les vues
#      `interventions-anomalies-terrain` et `objets-incomplets` pour
#      filtrer les references par zone affectee de l'agent appelant - ces
#      deux tables n'ont pas de geom propre, elles pointent vers un objet
#      metier zone-able via (nom_table, uuid).


CLEANUP_SQL = r"""
-- Drop temporaire des CHECK srm_req_* (re-evaluees sur UPDATE meme si la
-- colonne touchee n'est pas concernee), execution des marquages
-- is_deleted=true, puis re-creation a l'identique des contraintes.
DO $do$
DECLARE
    rec    RECORD;
    ddl    TEXT;
    saved  TEXT[] := ARRAY[]::TEXT[];
    target_tables TEXT[] := ARRAY['conduite_terrain','ep_traversee','ep_ventouse'];
BEGIN
    FOR rec IN
        SELECT
            nsp.nspname AS sch,
            cls.relname AS tbl,
            con.conname AS cname,
            pg_get_constraintdef(con.oid) AS cdef
        FROM pg_constraint con
        JOIN pg_class cls ON cls.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = cls.relnamespace
        WHERE nsp.nspname = 'ep'
          AND cls.relname = ANY(target_tables)
          AND con.conname LIKE 'srm_req_%'
    LOOP
        saved := saved || format(
            'ALTER TABLE %I.%I ADD CONSTRAINT %I %s',
            rec.sch, rec.tbl, rec.cname, rec.cdef
        );
        EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I',
                       rec.sch, rec.tbl, rec.cname);
    END LOOP;

    UPDATE ep.conduite_terrain SET is_deleted = true WHERE geom IS NULL;
    UPDATE ep.ep_traversee     SET is_deleted = true WHERE geom IS NULL;
    UPDATE ep.ep_ventouse      SET is_deleted = true WHERE geom IS NULL;

    FOREACH ddl IN ARRAY saved LOOP
        EXECUTE ddl;
    END LOOP;
END
$do$;
"""


CLEANUP_REVERSE_SQL = r"""
DO $do$
DECLARE
    rec    RECORD;
    ddl    TEXT;
    saved  TEXT[] := ARRAY[]::TEXT[];
    target_tables TEXT[] := ARRAY['conduite_terrain','ep_traversee','ep_ventouse'];
BEGIN
    FOR rec IN
        SELECT nsp.nspname AS sch, cls.relname AS tbl, con.conname AS cname,
               pg_get_constraintdef(con.oid) AS cdef
        FROM pg_constraint con
        JOIN pg_class cls ON cls.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = cls.relnamespace
        WHERE nsp.nspname = 'ep' AND cls.relname = ANY(target_tables)
          AND con.conname LIKE 'srm_req_%'
    LOOP
        saved := saved || format('ALTER TABLE %I.%I ADD CONSTRAINT %I %s',
                                  rec.sch, rec.tbl, rec.cname, rec.cdef);
        EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I',
                       rec.sch, rec.tbl, rec.cname);
    END LOOP;

    UPDATE ep.conduite_terrain SET is_deleted = false WHERE geom IS NULL;
    UPDATE ep.ep_traversee     SET is_deleted = false WHERE geom IS NULL;
    UPDATE ep.ep_ventouse      SET is_deleted = false WHERE geom IS NULL;

    FOREACH ddl IN ARRAY saved LOOP
        EXECUTE ddl;
    END LOOP;
END
$do$;
"""


OBJECT_GEOM_FN_SQL = r"""
-- Resout la geometrie d'un objet metier a partir de (nom_table, uuid).
-- nom_table accepte les formes "schema.table" ou "table" (default schema ep).
-- Retourne NULL si la table n'existe pas, n'a pas de colonne geom, ou si
-- l'uuid n'est pas trouve. STABLE car pas d'effet de bord.
CREATE OR REPLACE FUNCTION public.srm_object_geom(p_table text, p_uuid uuid)
RETURNS geometry
LANGUAGE plpgsql
STABLE
AS $fn$
DECLARE
    sch text;
    tbl text;
    g   geometry;
BEGIN
    IF p_table IS NULL OR p_uuid IS NULL THEN
        RETURN NULL;
    END IF;

    IF position('.' in p_table) > 0 THEN
        sch := split_part(p_table, '.', 1);
        tbl := split_part(p_table, '.', 2);
    ELSE
        sch := 'ep';
        tbl := p_table;
    END IF;

    IF sch = '' OR tbl = '' THEN
        RETURN NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = sch
          AND table_name   = tbl
          AND column_name  = 'geom'
    ) THEN
        RETURN NULL;
    END IF;

    BEGIN
        EXECUTE format('SELECT geom FROM %I.%I WHERE uuid = $1 LIMIT 1', sch, tbl)
        INTO g
        USING p_uuid;
    EXCEPTION WHEN others THEN
        RETURN NULL;
    END;

    RETURN g;
END
$fn$;
"""


OBJECT_GEOM_FN_REVERSE_SQL = r"""
DROP FUNCTION IF EXISTS public.srm_object_geom(text, uuid);
"""


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0055_backfill_orphan_geoms_from_coords'),
    ]

    operations = [
        migrations.RunSQL(sql=CLEANUP_SQL, reverse_sql=CLEANUP_REVERSE_SQL),
        migrations.RunSQL(sql=OBJECT_GEOM_FN_SQL, reverse_sql=OBJECT_GEOM_FN_REVERSE_SQL),
    ]
