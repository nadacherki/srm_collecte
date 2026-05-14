from django.db import migrations


LABEL_UPDATES = [
    (4243, "Coordonnée relevée x", "Coordonnée relevée X"),
    (4244, "Coordonnée relevée y", "Coordonnée relevée Y"),
    (4245, "Coordonnée relevée z", "Coordonnée relevée Z"),
    (4311, "ASS_COOR_X", "Coordonnée relevée X"),
    (4312, "ASS_COOR_Y", "Coordonnée relevée Y"),
    (4313, "ASS_COOR_Z", "Coordonnée relevée Z"),
    (3413, "ASS_COOR_X", "Coordonnée relevée X"),
    (3414, "ASS_COOR_Y", "Coordonnée relevée Y"),
    (3415, "ASS_COOR_Z", "Coordonnée relevée Z"),
    (3477, "ASS_COOR_X", "Coordonnée relevée X"),
    (3478, "ASS_COOR_Y", "Coordonnée relevée Y"),
    (3479, "ASS_COOR_Z", "Coordonnée relevée Z"),
    (3821, "ASS_COOR_X", "Coordonnée relevée X"),
    (3822, "ASS_COOR_Y", "Coordonnée relevée Y"),
    (3823, "ASS_COOR_Z", "Coordonnée relevée Z"),
    (4608, "ASS_COOR_X", "Coordonnée relevée X"),
    (4609, "ASS_COOR_Y", "Coordonnée relevée Y"),
    (4610, "ASS_COOR_Z", "Coordonnée relevée Z"),
    (4498, "ASS_COOR_X", "Coordonnée relevée X"),
    (4499, "ASS_COOR_Y", "Coordonnée relevée Y"),
    (4500, "ASS_COOR_Z", "Coordonnée relevée Z"),
    (4400, "Coordonnée relevée x", "Coordonnée relevée X"),
    (4401, "Coordonnée relevée y", "Coordonnée relevée Y"),
    (4402, "Coordonnée relevée z", "Coordonnée relevée Z"),
    (1475, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1476, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1477, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (14, "ANOMALIE_REGARD", "Anomalie regard"),
    (1222, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1223, "Coordonnées relevées_ Y", "Coordonnée relevée Y"),
    (47, "Coordonnees relevees_Z", "Coordonnée relevée Z"),
    (1714, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1158, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1159, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (836, "Diaméttre_compteur", "Diamètre compteur"),
    (1300, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1301, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1302, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1242, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1243, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1244, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1345, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1346, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1347, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1581, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1582, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1583, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1387, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1388, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1389, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1136, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1137, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1138, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1626, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1627, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1628, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1604, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1605, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1606, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1453, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1454, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1455, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1497, "CopieDeCoordonnées relevées_ X", "Coordonnée relevée X"),
    (1498, "CopieDeCoordonnées relevées_Y", "Coordonnée relevée Y"),
    (1499, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1323, "CopieDeCoordonnées relevées_ X", "Coordonnée relevée X"),
    (1324, "CopieDeCoordonnées relevées_Y", "Coordonnée relevée Y"),
    (1325, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1409, "Coordonnées relevées_ X", "Coordonnée relevée X"),
    (1410, "Coordonnées relevées_Y", "Coordonnée relevée Y"),
    (1411, "Coordonnées relevées_Z", "Coordonnée relevée Z"),
    (1541, None, "Coordonnée relevée X"),
    (1542, None, "Coordonnée relevée Y"),
    (1543, None, "Coordonnée relevée Z"),
    (1647, None, "Coordonnée relevée X"),
    (1648, None, "Coordonnée relevée Y"),
    (1649, None, "Coordonnée relevée Z"),
    (2902, "X", "Coordonnée relevée X"),
    (2903, "Y", "Coordonnée relevée Y"),
    (2904, "Z", "Coordonnée relevée Z"),
    (3218, "X", "Coordonnée relevée X"),
    (3285, "Y", "Coordonnée relevée Y"),
    (2895, "Z", "Coordonnée relevée Z"),
    (4748, "X", "Coordonnée relevée X"),
    (4749, "Y", "Coordonnée relevée Y"),
    (2881, "Z", "Coordonnée relevée Z"),
]


def _apply_updates(schema_editor, forward=True):
    with schema_editor.connection.cursor() as cursor:
        for attr_id, old_value, new_value in LABEL_UPDATES:
            expected_value = old_value if forward else new_value
            target_value = new_value if forward else old_value
            cursor.execute(
                """
                UPDATE public.attribut_config_mobile
                   SET titre_app = %s
                 WHERE id = %s
                   AND titre_app IS NOT DISTINCT FROM %s
                """,
                [target_value, attr_id, expected_value],
            )


def forwards(apps, schema_editor):
    _apply_updates(schema_editor, forward=True)


def backwards(apps, schema_editor):
    _apply_updates(schema_editor, forward=False)


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0033_choice_default_guard"),
    ]

    operations = [
        migrations.RunPython(forwards, backwards),
    ]
