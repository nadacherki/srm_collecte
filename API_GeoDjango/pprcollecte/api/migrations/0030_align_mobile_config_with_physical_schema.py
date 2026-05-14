from django.db import migrations


TECHNICAL_AUTRE_OBJET_FIELDS = (
    ("id_province", "integer", 13, "id_province", True, "public.province.fid"),
    ("id_zone", "integer", 14, "id_zone", True, "public.zone.id_zone"),
    ("id_mission", "integer", 15, "id_mission", True, None),
    ("id_user_creat", "integer", 16, "id_user_creat", True, "public.utilisateur.id_user"),
    ("id_user_modif", "integer", 17, "id_user_modif", True, "public.utilisateur.id_user"),
    (
        "date_creation",
        "timestamp without time zone",
        18,
        "date_creation",
        False,
        None,
    ),
    ("date_modif", "timestamp without time zone", 19, "date_modif", False, None),
    ("is_deleted", "boolean", 20, "is_deleted", False, None),
    ("is_validated", "boolean", 21, "is_validated", False, None),
    ("id_user_valid", "integer", 22, "id_user_valid", True, "public.utilisateur.id_user"),
    (
        "date_validation",
        "timestamp without time zone",
        23,
        "date_validation",
        False,
        None,
    ),
)


def align_mobile_config(apps, schema_editor):
    with schema_editor.connection.cursor() as cursor:
        cursor.execute(
            """
            WITH form_tables AS (
                SELECT nom_metier, nom_table
                FROM public.formulaire_config_mobile
                WHERE nom_metier IN ('ep', 'asst')
            ),
            obsolete AS (
                SELECT acm.id
                FROM public.attribut_config_mobile acm
                JOIN form_tables f
                  ON f.nom_metier = acm.nom_metier
                 AND f.nom_table = acm.nom_table
                LEFT JOIN information_schema.columns c
                  ON c.table_schema = acm.nom_metier
                 AND c.table_name = acm.nom_table
                 AND c.column_name = acm.nom_champ
                WHERE c.column_name IS NULL
            )
            DELETE FROM public.liste_choix lc
            USING obsolete
            WHERE lc.attribut_config_mobile_id = obsolete.id
            """
        )
        cursor.execute(
            """
            WITH form_tables AS (
                SELECT nom_metier, nom_table
                FROM public.formulaire_config_mobile
                WHERE nom_metier IN ('ep', 'asst')
            ),
            obsolete AS (
                SELECT acm.id
                FROM public.attribut_config_mobile acm
                JOIN form_tables f
                  ON f.nom_metier = acm.nom_metier
                 AND f.nom_table = acm.nom_table
                LEFT JOIN information_schema.columns c
                  ON c.table_schema = acm.nom_metier
                 AND c.table_name = acm.nom_table
                 AND c.column_name = acm.nom_champ
                WHERE c.column_name IS NULL
            )
            DELETE FROM public.attribut_config_mobile acm
            USING obsolete
            WHERE acm.id = obsolete.id
            """
        )

        cursor.executemany(
            """
            INSERT INTO public.attribut_config_mobile (
                nom_metier,
                nom_table,
                nom_champ,
                type_champ,
                primary_key,
                foreign_key,
                ordre,
                titre_app,
                visible,
                contraintes,
                nullable,
                valeur_par_defaut,
                valeur_min,
                valeur_max,
                reference_fk
            )
            VALUES (
                'ep',
                'autre_objet',
                %s,
                %s,
                false,
                %s,
                %s,
                %s,
                false,
                NULL,
                true,
                NULL,
                NULL,
                NULL,
                %s
            )
            ON CONFLICT (nom_metier, nom_table, nom_champ) DO UPDATE
            SET type_champ = EXCLUDED.type_champ,
                primary_key = EXCLUDED.primary_key,
                foreign_key = EXCLUDED.foreign_key,
                ordre = EXCLUDED.ordre,
                titre_app = EXCLUDED.titre_app,
                visible = false,
                nullable = EXCLUDED.nullable,
                reference_fk = EXCLUDED.reference_fk
            """,
            [
                (field, type_champ, foreign_key, ordre, title, reference_fk)
                for field, type_champ, ordre, title, foreign_key, reference_fk
                in TECHNICAL_AUTRE_OBJET_FIELDS
            ],
        )


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0029_fix_mobile_config_mojibake"),
    ]

    operations = [
        migrations.RunPython(align_mobile_config, migrations.RunPython.noop),
    ]
