from django.db import migrations


CONFIG_SQL = """
UPDATE public.formulaire_config_mobile
SET visible = true
WHERE nom_metier = 'ep'
  AND nom_table = 'conduite_terrain';

UPDATE public.formulaire_config_mobile
SET visible = false
WHERE nom_metier = 'ep'
  AND nom_table IN ('ep_conduite', 'ep_conduite_bureau');

UPDATE public.attribut_config_mobile
SET visible = false
WHERE nom_metier = 'ep'
  AND nom_table = 'conduite_terrain';

UPDATE public.attribut_config_mobile
SET visible = true
WHERE nom_metier = 'ep'
  AND nom_table = 'conduite_terrain'
  AND nom_champ IN ('ep_diam', 'ep_mat');

UPDATE public.attribut_config_mobile
SET visible = false
WHERE nom_metier = 'ep'
  AND nom_table = 'conduite_terrain'
  AND nom_champ = 'ep_classe_conduite';
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0015_ep_bf_mat_brts_varchar"),
    ]

    operations = [
        migrations.RunSQL(CONFIG_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
