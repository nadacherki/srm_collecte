from django.db import migrations


CONFIG_SQL = """
UPDATE public.formulaire_config_mobile
SET visible = true,
    download_mobile = true
WHERE nom_metier = 'asst'
  AND nom_table = 'ASS_BASSIN_VERSANT';
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0026_fix_formulaire_config_title_encoding"),
    ]

    operations = [
        migrations.RunSQL(CONFIG_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
