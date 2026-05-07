"""Audit SRM mobile form mapping against PostgreSQL configuration.

Checks the current public.formulaire_config_mobile, public.attribut_config_mobile
and public.liste_choix data against the Flutter mapping layer. The report is
intended for the srm-mobile-form-config skill.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
API_ROOT = REPO / "API_GeoDjango" / "pprcollecte"
FLUTTER_ROOT = REPO / "PPRCollecte_Flutter"

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "pprcollecte.settings")
sys.path.insert(0, str(API_ROOT))

import django  # noqa: E402

django.setup()

from django.db import connection  # noqa: E402


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def _parse_dart_map(text: str, name: str) -> dict[str, str]:
    pattern = (
        r"static const Map<String, String>\s+"
        + re.escape(name)
        + r"\s*=\s*\{(.*?)\};"
    )
    match = re.search(pattern, text, re.S)
    if not match:
        return {}
    return {
        key: value
        for key, value in re.findall(r"'([^']+)'\s*:\s*'([^']+)'", match.group(1))
    }


def _parse_endpoint_map(text: str) -> set[str]:
    match = re.search(r"endpointMap = <String, String>\{(.+?)\};", text, re.S)
    if not match:
        return set()
    return {
        key
        for key, _value in re.findall(r"'([^']+)'\s*:\s*'([^']+)'", match.group(1))
    }


def _mobile_table_for_config_table(
    nom_metier: str,
    nom_table: str,
    ep_map: dict[str, str],
    asst_map: dict[str, str],
) -> str:
    if nom_metier == "ep":
        return ep_map.get(nom_table, nom_table)
    if nom_metier == "asst":
        return asst_map.get(nom_table, nom_table)
    return nom_table


def _fetchall(query: str, params: list[object] | None = None) -> list[tuple]:
    with connection.cursor() as cursor:
        cursor.execute(query, params or [])
        return list(cursor.fetchall())


def main() -> int:
    srm_config = _read(FLUTTER_ROOT / "lib" / "core" / "config" / "srm_config.dart")
    mapping_service = _read(
        FLUTTER_ROOT / "lib" / "services" / "attribut_config_mobile_service.dart"
    )
    sync_service = _read(FLUTTER_ROOT / "lib" / "services" / "sync_service.dart")

    srm_config_tables = set(re.findall(r'"tableName"\s*:\s*"([^"]+)"', srm_config))
    ep_mobile_map = _parse_dart_map(mapping_service, "_epMobileTableByConfigTable")
    asst_mobile_map = _parse_dart_map(mapping_service, "_asstMobileTableByConfigTable")
    sync_endpoint_keys = _parse_endpoint_map(sync_service)

    form_counts = _fetchall(
        """
        SELECT nom_metier,
               count(*) AS total,
               count(*) FILTER (WHERE COALESCE(visible,false)) AS visible,
               count(*) FILTER (WHERE NOT COALESCE(visible,false)) AS hidden
        FROM public.formulaire_config_mobile
        GROUP BY nom_metier
        ORDER BY nom_metier
        """
    )

    choice_counts = _fetchall(
        """
        SELECT nom_metier,
               count(*) AS total,
               count(*) FILTER (WHERE COALESCE(liste_choix_actif,true)) AS active,
               count(DISTINCT nom_table) AS tables,
               count(DISTINCT nom_table || '.' || nom_champ) AS fields
        FROM public.liste_choix
        GROUP BY nom_metier
        ORDER BY nom_metier
        """
    )

    form_rows = _fetchall(
        """
        WITH fields AS (
          SELECT nom_metier,
                 nom_table,
                 count(*) AS total_fields,
                 count(*) FILTER (
                   WHERE COALESCE(visible,false)
                     AND NOT COALESCE(primary_key,false)
                     AND lower(nom_champ) <> 'geom'
                 ) AS visible_fields,
                 max(type_champ) FILTER (WHERE lower(nom_champ) = 'geom') AS geom_type
          FROM public.attribut_config_mobile
          GROUP BY nom_metier, nom_table
        ), choices AS (
          SELECT nom_metier, nom_table, nom_champ, count(*) AS choice_count
          FROM public.liste_choix
          WHERE COALESCE(liste_choix_actif,true)
          GROUP BY nom_metier, nom_table, nom_champ
        ), choice_fields AS (
          SELECT a.nom_metier,
                 a.nom_table,
                 count(DISTINCT a.nom_champ) AS visible_choice_fields,
                 COALESCE(sum(c.choice_count),0) AS active_choice_rows
          FROM public.attribut_config_mobile a
          JOIN choices c
            ON c.nom_metier = a.nom_metier
           AND c.nom_table = a.nom_table
           AND c.nom_champ = a.nom_champ
          WHERE COALESCE(a.visible,false)
            AND NOT COALESCE(a.primary_key,false)
            AND lower(a.nom_champ) <> 'geom'
          GROUP BY a.nom_metier, a.nom_table
        )
        SELECT f.nom_metier,
               f.nom_table,
               f.titre_app,
               f.ordre,
               COALESCE(f.visible,false),
               COALESCE(fields.total_fields,0),
               COALESCE(fields.visible_fields,0),
               COALESCE(choice_fields.visible_choice_fields,0),
               COALESCE(choice_fields.active_choice_rows,0),
               fields.geom_type
        FROM public.formulaire_config_mobile f
        LEFT JOIN fields
          ON fields.nom_metier = f.nom_metier
         AND fields.nom_table = f.nom_table
        LEFT JOIN choice_fields
          ON choice_fields.nom_metier = f.nom_metier
         AND choice_fields.nom_table = f.nom_table
        WHERE f.nom_metier IN ('ep', 'asst')
        ORDER BY f.nom_metier, COALESCE(f.ordre,999999), f.id
        """
    )

    hydrant_vanne = _fetchall(
        """
        SELECT liste_choix_valeur, liste_choix_alias, liste_choix_ordre
        FROM public.liste_choix
        WHERE nom_metier='ep'
          AND nom_table='ep_hydrant'
          AND nom_champ='vanne'
          AND COALESCE(liste_choix_actif,true)
        ORDER BY liste_choix_ordre, liste_choix_valeur
        """
    )

    cross_metier_hidden_coords = _fetchall(
        """
        SELECT nom_metier, nom_table, nom_champ, COALESCE(visible,false), ordre
        FROM public.attribut_config_mobile
        WHERE (
              nom_metier = 'ep'
              AND nom_champ IN ('ass_coor_x', 'ass_coor_y', 'ass_coor_z')
            )
           OR (
              nom_metier IN ('asst', 'ass')
              AND nom_champ IN ('ep_coor_x', 'ep_coor_y', 'ep_coor_z')
            )
        ORDER BY nom_metier, nom_table, ordre, nom_champ
        """
    )

    print("FORMULAIRE_CONFIG_COUNTS")
    for row in form_counts:
        print(f"  {row[0]}: total={row[1]} visible={row[2]} hidden={row[3]}")

    print("\nLISTE_CHOIX_COUNTS")
    for row in choice_counts:
        print(f"  {row[0]}: total={row[1]} active={row[2]} tables={row[3]} fields={row[4]}")

    print("\nVISIBLE_FORM_GAPS")
    gaps = 0
    for nom_metier, nom_table, titre, ordre, visible, total, visible_fields, choice_fields, choices, geom_type in form_rows:
        if not visible:
            continue
        mobile_table = _mobile_table_for_config_table(
            nom_metier, nom_table, ep_mobile_map, asst_mobile_map
        )
        schema_key = f"{nom_metier}/{mobile_table}"
        has_srm_entity = mobile_table in srm_config_tables
        has_sync_endpoint = schema_key in sync_endpoint_keys
        if not has_srm_entity or not has_sync_endpoint or visible_fields == 0:
            gaps += 1
            print(
                "  "
                f"{nom_metier}.{nom_table} -> {mobile_table} | "
                f"ordre={ordre} | fields={visible_fields}/{total} | "
                f"choices={choice_fields}/{choices} | geom={geom_type or '-'} | "
                f"srm_config={has_srm_entity} sync_endpoint={has_sync_endpoint} | "
                f"{titre}"
            )
    if gaps == 0:
        print("  none")

    print("\nVISIBLE_FORM_SUMMARY")
    for nom_metier, nom_table, titre, ordre, visible, total, visible_fields, choice_fields, choices, geom_type in form_rows:
        if not visible:
            continue
        mobile_table = _mobile_table_for_config_table(
            nom_metier, nom_table, ep_mobile_map, asst_mobile_map
        )
        print(
            "  "
            f"{nom_metier}.{nom_table} -> {mobile_table} | "
            f"ordre={ordre} | fields={visible_fields}/{total} | "
            f"choice_fields={choice_fields} choices={choices} | "
            f"geom={geom_type or '-'} | {titre}"
        )

    print("\nREGRESSION_EP_HYDRANT_VANNE")
    print("  " + ", ".join(f"{value}:{alias}" for value, alias, _order in hydrant_vanne))
    labels = {alias for _value, alias, _order in hydrant_vanne}
    if labels != {"Oui", "Non"} or len(hydrant_vanne) != 2:
        print("ERROR: ep.ep_hydrant.vanne must expose exactly Oui and Non.")
        return 1

    print("\nCROSS_METIER_COORD_FIELDS")
    if not cross_metier_hidden_coords:
        print("  none")
    for nom_metier, nom_table, nom_champ, visible, ordre in cross_metier_hidden_coords:
        visibility = "visible" if visible else "hidden"
        print(f"  {nom_metier}.{nom_table}.{nom_champ} | {visibility} | ordre={ordre}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
