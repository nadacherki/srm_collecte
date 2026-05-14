from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0020_hide_ep_hydrant_conform_fields"),
    ]

    operations = [
        migrations.RunSQL(
            sql="""
            UPDATE public.attribut_config_mobile
            SET visible = false
            WHERE nom_metier = 'ep'
              AND nom_champ = 'ep_conform';

            UPDATE public.attribut_config_mobile
            SET visible = true
            WHERE nom_metier = 'ep'
              AND nom_table = 'ep_hydrant'
              AND nom_champ IN ('conform', 'ep_conf_plan');
            """,
            reverse_sql=migrations.RunSQL.noop,
        ),
    ]
