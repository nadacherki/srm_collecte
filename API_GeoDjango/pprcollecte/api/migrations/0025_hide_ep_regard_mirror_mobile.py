from django.db import migrations


CONFIG_SQL = """
UPDATE public.formulaire_config_mobile
SET visible = false,
    download_mobile = true
WHERE nom_metier = 'ep'
  AND nom_table = 'ep_regard';
"""


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0024_mobile_download_manifest"),
    ]

    operations = [
        migrations.RunSQL(CONFIG_SQL, reverse_sql=migrations.RunSQL.noop),
    ]
