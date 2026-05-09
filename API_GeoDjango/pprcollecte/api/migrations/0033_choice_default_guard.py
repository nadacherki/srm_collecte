from django.db import migrations


CONFIG_SQL = r"""
CREATE OR REPLACE FUNCTION public.srm_assert_choice_default_guard(
    p_nom_metier text,
    p_nom_table text,
    p_nom_champ text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    default_value text;
    active_choice_count integer;
    has_default_choice boolean;
BEGIN
    SELECT nullif(btrim(acm.valeur_par_defaut), '')
      INTO default_value
      FROM public.attribut_config_mobile acm
     WHERE acm.nom_metier = p_nom_metier
       AND acm.nom_table = p_nom_table
       AND acm.nom_champ = p_nom_champ
     ORDER BY acm.id
     LIMIT 1;

    IF default_value IS NULL THEN
        RETURN;
    END IF;

    SELECT
        count(*),
        bool_or(btrim(coalesce(lc.liste_choix_valeur, '')) = default_value)
      INTO active_choice_count, has_default_choice
      FROM public.liste_choix lc
     WHERE lc.nom_metier = p_nom_metier
       AND lc.nom_table = p_nom_table
       AND lc.nom_champ = p_nom_champ
       AND coalesce(lc.liste_choix_actif, true);

    IF active_choice_count > 0 AND NOT coalesce(has_default_choice, false) THEN
        RAISE EXCEPTION
            'Valeur par defaut invalide pour %.%.%: "%" doit exister dans public.liste_choix.liste_choix_valeur active.',
            p_nom_metier, p_nom_table, p_nom_champ, default_value
            USING ERRCODE = '23514',
                  HINT = 'Ajoutez ou reactivez le choix correspondant, ou videz valeur_par_defaut.';
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_attribut_config_choice_default_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    PERFORM public.srm_assert_choice_default_guard(
        NEW.nom_metier,
        NEW.nom_table,
        NEW.nom_champ
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.srm_liste_choix_default_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        PERFORM public.srm_assert_choice_default_guard(
            OLD.nom_metier,
            OLD.nom_table,
            OLD.nom_champ
        );
    END IF;

    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        IF TG_OP = 'INSERT'
           OR (OLD.nom_metier, OLD.nom_table, OLD.nom_champ)
              IS DISTINCT FROM
              (NEW.nom_metier, NEW.nom_table, NEW.nom_champ) THEN
            PERFORM public.srm_assert_choice_default_guard(
                NEW.nom_metier,
                NEW.nom_table,
                NEW.nom_champ
            );
        ELSE
            PERFORM public.srm_assert_choice_default_guard(
                NEW.nom_metier,
                NEW.nom_table,
                NEW.nom_champ
            );
        END IF;
    END IF;

    RETURN coalesce(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_srm_attribut_config_choice_default_guard
ON public.attribut_config_mobile;

CREATE CONSTRAINT TRIGGER trg_srm_attribut_config_choice_default_guard
AFTER INSERT OR UPDATE
ON public.attribut_config_mobile
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.srm_attribut_config_choice_default_guard();

DROP TRIGGER IF EXISTS trg_srm_liste_choix_default_guard
ON public.liste_choix;

CREATE CONSTRAINT TRIGGER trg_srm_liste_choix_default_guard
AFTER INSERT OR UPDATE OR DELETE
ON public.liste_choix
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.srm_liste_choix_default_guard();
"""


REVERSE_SQL = r"""
DROP TRIGGER IF EXISTS trg_srm_liste_choix_default_guard
ON public.liste_choix;

DROP TRIGGER IF EXISTS trg_srm_attribut_config_choice_default_guard
ON public.attribut_config_mobile;

DROP FUNCTION IF EXISTS public.srm_liste_choix_default_guard();
DROP FUNCTION IF EXISTS public.srm_attribut_config_choice_default_guard();
DROP FUNCTION IF EXISTS public.srm_assert_choice_default_guard(text, text, text);
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0032_schema_guard_preview"),
    ]

    operations = [
        migrations.RunSQL(CONFIG_SQL, reverse_sql=REVERSE_SQL),
    ]
