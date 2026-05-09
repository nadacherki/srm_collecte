from django.db import migrations


LIKELY_MOJIBAKE_MARKERS = (
    "\u00c3",
    "\u00c2",
    "\ufffd",
    "\u00e2\u20ac",
)

TARGET_COLUMNS = (
    ("public", "formulaire_config_mobile", "titre_app"),
    ("public", "attribut_config_mobile", "titre_app"),
    ("public", "liste_choix", "liste_choix_alias"),
    ("public", "liste_choix", "liste_choix_valeur"),
)


def _has_mojibake(value):
    return isinstance(value, str) and any(
        marker in value for marker in LIKELY_MOJIBAKE_MARKERS
    )


def _repair_mojibake(value):
    if not _has_mojibake(value):
        return value

    for encoding in ("cp1252", "latin1"):
        try:
            fixed = value.encode(encoding).decode("utf-8")
        except UnicodeError:
            continue
        if fixed != value:
            return fixed

    return value


def fix_mobile_config_mojibake(apps, schema_editor):
    with schema_editor.connection.cursor() as cursor:
        for schema, table, column in TARGET_COLUMNS:
            where_clause = " OR ".join(
                [f'"{column}" LIKE %s' for _ in LIKELY_MOJIBAKE_MARKERS]
            )
            params = [f"%{marker}%" for marker in LIKELY_MOJIBAKE_MARKERS]
            cursor.execute(
                f'SELECT id, "{column}" FROM "{schema}"."{table}" WHERE {where_clause}',
                params,
            )
            updates = []
            for row_id, value in cursor.fetchall():
                fixed = _repair_mojibake(value)
                if fixed != value:
                    updates.append((fixed, row_id))

            for fixed, row_id in updates:
                cursor.execute(
                    f'UPDATE "{schema}"."{table}" SET "{column}" = %s WHERE id = %s',
                    [fixed, row_id],
                )


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0028_restore_mobile_metrics_views"),
    ]

    operations = [
        migrations.RunPython(fix_mobile_config_mojibake, migrations.RunPython.noop),
    ]
