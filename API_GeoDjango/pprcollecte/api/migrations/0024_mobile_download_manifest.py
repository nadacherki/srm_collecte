from django.db import migrations


CONFIG_SQL = """
ALTER TABLE public.formulaire_config_mobile
ADD COLUMN IF NOT EXISTS download_mobile boolean NOT NULL DEFAULT false;

UPDATE public.formulaire_config_mobile
SET download_mobile = true
WHERE COALESCE(visible, false) = true;

UPDATE public.formulaire_config_mobile
SET download_mobile = true
WHERE nom_metier = 'ep'
  AND nom_table = 'onep_db';

UPDATE public.formulaire_config_mobile
SET download_mobile = false
WHERE nom_metier = 'elec';

CREATE OR REPLACE FUNCTION public.srm_formulaire_config_mobile_download_guard()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF COALESCE(NEW.visible, false) THEN
        NEW.download_mobile := true;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_srm_formulaire_config_mobile_download_guard
ON public.formulaire_config_mobile;

CREATE TRIGGER trg_srm_formulaire_config_mobile_download_guard
BEFORE INSERT OR UPDATE OF visible, download_mobile
ON public.formulaire_config_mobile
FOR EACH ROW
EXECUTE FUNCTION public.srm_formulaire_config_mobile_download_guard();
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0023_fix_ep_brc_pt_customer_link_null_client"),
    ]

    operations = [
        migrations.RunSQL(CONFIG_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
