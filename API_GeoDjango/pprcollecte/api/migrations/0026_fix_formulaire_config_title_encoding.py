from django.db import migrations


TITLE_FIXES = [
    ("asst", "ASS_BASSIN_RET", "Bassins de rétention"),
    ("asst", "ASS_BASSIN_RET_L", "Bassins de rétention (ligne)"),
    ("asst", "ASS_BOUCHE", "Bouches d'égout"),
    ("asst", "ASS_COL_BOUCHE", "Collecteur bouche d'égout"),
    ("asst", "ASS_DEVERSOIR", "Déversoirs d'orage"),
    ("asst", "ASS_ECOULEMENT", "Écoulement"),
    ("asst", "ASS_OUV_TRAVERSEE", "Ouvrages de traversée"),
    ("asst", "ASS_REFOULEMENTR", "Refoulement réutilisation"),
    ("asst", "ASS_REGARD_FACADE", "Regards Façade"),
    ("asst", "ASS_STA_EPUR", "Stations d'épuration"),
    ("asst", "ASS_STA_EPUR_L", "Stations d'épuration (ligne)"),
    ("ep", "bouche_a_cles", "Bouche à clé"),
    ("ep", "ep_bache", "Bâche"),
    ("ep", "ep_brc_pt", "Compteur abonné"),
    ("ep", "ep_compteur_i", "Compteur réseau"),
    ("ep", "ep_cone_reduc", "Cône de réduction"),
    ("ep", "ep_reduc_pres", "Réducteur de pression"),
    ("ep", "ep_reservoir", "Réservoir"),
    ("ep", "ep_st_demineralisation", "Station de déminéralisation"),
    ("ep", "ep_traversee", "Traversée"),
]


def fix_titles(apps, schema_editor):
    with schema_editor.connection.cursor() as cursor:
        cursor.executemany(
            """
            UPDATE public.formulaire_config_mobile
            SET titre_app = %s
            WHERE nom_metier = %s
              AND nom_table = %s
            """,
            [(title, nom_metier, nom_table) for nom_metier, nom_table, title in TITLE_FIXES],
        )


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0025_hide_ep_regard_mirror_mobile"),
    ]

    operations = [
        migrations.RunPython(fix_titles, migrations.RunPython.noop),
    ]
