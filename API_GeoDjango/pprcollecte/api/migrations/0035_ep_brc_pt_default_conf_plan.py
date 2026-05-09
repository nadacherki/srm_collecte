from django.db import migrations


DEFAULT_VALUE = "Objet d\u00e9couvert sur le terrain"


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0034_normalize_mobile_titre_app_labels"),
    ]

    operations = [
        migrations.RunSQL(
            sql=[
                (
                    """
                    UPDATE public.attribut_config_mobile
                       SET valeur_par_defaut = %s
                     WHERE id = 57
                       AND nom_metier = 'ep'
                       AND nom_table = 'ep_brc_pt'
                       AND nom_champ = 'ep_conf_plan'
                    """,
                    [DEFAULT_VALUE],
                ),
            ],
            reverse_sql=[
                (
                    """
                    UPDATE public.attribut_config_mobile
                       SET valeur_par_defaut = NULL
                     WHERE id = 57
                       AND nom_metier = 'ep'
                       AND nom_table = 'ep_brc_pt'
                       AND nom_champ = 'ep_conf_plan'
                       AND valeur_par_defaut = %s
                    """,
                    [DEFAULT_VALUE],
                ),
            ],
        ),
    ]
