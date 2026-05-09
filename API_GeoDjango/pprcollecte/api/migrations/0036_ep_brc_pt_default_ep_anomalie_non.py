from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0035_ep_brc_pt_default_conf_plan"),
    ]

    operations = [
        migrations.RunSQL(
            sql="""
                UPDATE public.attribut_config_mobile
                   SET valeur_par_defaut = 'Non'
                 WHERE id = 1721
                   AND nom_metier = 'ep'
                   AND nom_table = 'ep_brc_pt'
                   AND nom_champ = 'ep_anomalie'
            """,
            reverse_sql="""
                UPDATE public.attribut_config_mobile
                   SET valeur_par_defaut = NULL
                 WHERE id = 1721
                   AND nom_metier = 'ep'
                   AND nom_table = 'ep_brc_pt'
                   AND nom_champ = 'ep_anomalie'
                   AND valeur_par_defaut = 'Non'
            """,
        ),
    ]
