from django.db import migrations


# La fonction `srm_object_geom(text, uuid)` introduite par 0056 supposait que
# `objet_incomplet` / `intervention_anomalie` referencaient les objets metier
# par UUID. En realite :
#   - `intervention_anomalie.uuid_objet` est stocke avec des accolades
#     (format text non-standard) -> ne matche pas
#   - `objet_incomplet.uuid` est l'uuid du record incomplet, PAS de l'objet
#     metier reference
#
# Les deux tables exposent par contre `id_objet` (INTEGER) qui mappe vers la
# PK de la table metier. La PK varie par schema (`fid` pour ep.*, `id` pour
# asst.*). Cette migration installe donc `srm_object_geom_by_id(text,int)`
# qui detecte dynamiquement la PK via information_schema.


CREATE_FN_SQL = r"""
DROP FUNCTION IF EXISTS public.srm_object_geom(text, uuid);

CREATE OR REPLACE FUNCTION public.srm_object_geom_by_id(p_table text, p_id integer)
RETURNS geometry
LANGUAGE plpgsql
STABLE
AS $fn$
DECLARE
    sch    text;
    tbl    text;
    pk_col text;
    g      geometry;
BEGIN
    IF p_table IS NULL OR p_id IS NULL THEN
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

    -- Verifie qu'il y a bien une colonne geom
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = sch AND table_name = tbl AND column_name = 'geom'
    ) THEN
        RETURN NULL;
    END IF;

    -- Resout dynamiquement la PK de la table
    SELECT kcu.column_name
      INTO pk_col
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu
        ON kcu.constraint_name = tc.constraint_name
       AND kcu.table_schema    = tc.table_schema
     WHERE tc.table_schema    = sch
       AND tc.table_name      = tbl
       AND tc.constraint_type = 'PRIMARY KEY'
     LIMIT 1;

    IF pk_col IS NULL THEN
        RETURN NULL;
    END IF;

    BEGIN
        EXECUTE format('SELECT geom FROM %I.%I WHERE %I = $1 LIMIT 1',
                       sch, tbl, pk_col)
        INTO g
        USING p_id;
    EXCEPTION WHEN others THEN
        RETURN NULL;
    END;

    RETURN g;
END
$fn$;
"""


REVERSE_FN_SQL = r"""
DROP FUNCTION IF EXISTS public.srm_object_geom_by_id(text, integer);

CREATE OR REPLACE FUNCTION public.srm_object_geom(p_table text, p_uuid uuid)
RETURNS geometry
LANGUAGE plpgsql
STABLE
AS $fn$
DECLARE
    sch text; tbl text; g geometry;
BEGIN
    IF p_table IS NULL OR p_uuid IS NULL THEN RETURN NULL; END IF;
    IF position('.' in p_table) > 0 THEN
        sch := split_part(p_table, '.', 1);
        tbl := split_part(p_table, '.', 2);
    ELSE
        sch := 'ep'; tbl := p_table;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema=sch AND table_name=tbl AND column_name='geom') THEN
        RETURN NULL;
    END IF;
    BEGIN
        EXECUTE format('SELECT geom FROM %I.%I WHERE uuid=$1 LIMIT 1', sch, tbl)
        INTO g USING p_uuid;
    EXCEPTION WHEN others THEN
        RETURN NULL;
    END;
    RETURN g;
END $fn$;
"""


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0056_cleanup_orphans_and_object_geom_helper'),
    ]

    operations = [
        migrations.RunSQL(sql=CREATE_FN_SQL, reverse_sql=REVERSE_FN_SQL),
    ]
