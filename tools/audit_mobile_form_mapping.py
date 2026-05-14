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

LOCATION_ONLY_FORMS = {
    ("ep", "borne_onep"),
    ("ep", "bouche_a_cles"),
    ("asst", "ASS_CANIVEAU"),
    ("asst", "ASS_CANIV_BRANCHE"),
    ("asst", "ASS_COL_BOUCHE"),
    ("asst", "ASS_BASSIN_VERSANT"),
}

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


def _decode_dart_string(value: str) -> str:
    value = value.strip()
    if not value:
        return ""
    quote = value[0]
    if quote not in {"'", '"'}:
        return value
    end = value.rfind(quote)
    inner = value[1:end] if end > 0 else value[1:]
    if "\\" not in inner:
        return inner
    return inner.encode("utf-8").decode("unicode_escape")


def _parse_fallback_formulaires(text: str) -> dict[tuple[str, str], dict[str, object]]:
    result: dict[tuple[str, str], dict[str, object]] = {}
    for block in re.findall(r"FormulaireConfigMobileItem\((.*?)\),", text, re.S):
        values: dict[str, str] = {}
        for name in (
            "nomMetier",
            "nomTable",
            "titreApp",
            "ordre",
            "visible",
            "downloadMobile",
        ):
            match = re.search(
                rf"{name}:\s*(.*?)(?:,\n|,\r\n|\n\s*\))",
                block,
                re.S,
            )
            if match:
                values[name] = match.group(1).strip()
        if "nomMetier" not in values or "nomTable" not in values:
            continue
        nom_metier = _decode_dart_string(values["nomMetier"])
        nom_table = _decode_dart_string(values["nomTable"])
        visible = values.get("visible", "").lower() == "true"
        download_mobile_raw = values.get("downloadMobile")
        result[(nom_metier, nom_table)] = {
            "titre_app": _decode_dart_string(values.get("titreApp", "")),
            "ordre": int(values["ordre"]) if values.get("ordre", "").isdigit() else None,
            "visible": visible,
            "download_mobile": (
                download_mobile_raw.lower() == "true"
                if download_mobile_raw is not None
                else visible
            ),
        }
    return result


def _matching_brace_end(text: str, start: int) -> int:
    depth = 0
    in_string: str | None = None
    escaped = False
    for pos in range(start, len(text)):
        char = text[pos]
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == in_string:
                in_string = None
            continue
        if char in {"'", '"'}:
            in_string = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return pos
    return -1


def _parse_srm_config_fields(text: str) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for match in re.finditer(r'"tableName"\s*:\s*"([^"]+)"', text):
        table_name = match.group(1)
        start = text.rfind("{", 0, match.start())
        end = _matching_brace_end(text, start)
        if start < 0 or end < 0:
            continue
        block = text[start:end]
        fields_match = re.search(r'"fields"\s*:\s*\[(.*?)\]', block, re.S)
        if not fields_match:
            continue
        result[table_name] = re.findall(r'"([^"]+)"', fields_match.group(1))
    return result


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


def _is_location_only_form(nom_metier: str, nom_table: str) -> bool:
    return (nom_metier, nom_table) in LOCATION_ONLY_FORMS


def main() -> int:
    srm_config = _read(FLUTTER_ROOT / "lib" / "core" / "config" / "srm_config.dart")
    mapping_service = _read(
        FLUTTER_ROOT / "lib" / "services" / "attribut_config_mobile_service.dart"
    )
    formulaire_service = _read(
        FLUTTER_ROOT / "lib" / "services" / "formulaire_config_mobile_service.dart"
    )
    sync_service = _read(FLUTTER_ROOT / "lib" / "services" / "sync_service.dart")

    srm_config_tables = set(re.findall(r'"tableName"\s*:\s*"([^"]+)"', srm_config))
    ep_mobile_map = _parse_dart_map(mapping_service, "_epMobileTableByConfigTable")
    asst_mobile_map = _parse_dart_map(mapping_service, "_asstMobileTableByConfigTable")
    sync_endpoint_keys = _parse_endpoint_map(sync_service)
    fallback_formulaires = _parse_fallback_formulaires(formulaire_service)
    srm_config_fields = _parse_srm_config_fields(srm_config)
    has_error = False

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
                   WHERE (
                       COALESCE(visible,false)
                       OR (
                         nom_metier = 'ep'
                         AND lower(nom_champ) IN ('ep_coor_x', 'ep_coor_y', 'ep_coor_z')
                       )
                       OR (
                         nom_metier IN ('asst', 'ass')
                         AND lower(nom_champ) IN ('ass_coor_x', 'ass_coor_y', 'ass_coor_z')
                       )
                     )
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
               COALESCE(f.download_mobile,false),
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

    db_formulaires = {
        (nom_metier, nom_table): {
            "titre_app": titre,
            "ordre": ordre,
            "visible": visible,
            "download_mobile": rest[0],
        }
        for nom_metier, nom_table, titre, ordre, visible, *rest in form_rows
    }
    print("\nFORMULAIRE_FALLBACK_CHECK")
    fallback_keys = {
        key for key in fallback_formulaires if key[0] in {"ep", "asst"}
    }
    missing = sorted(set(db_formulaires) - fallback_keys)
    extra = sorted(fallback_keys - set(db_formulaires))
    for key in missing:
        has_error = True
        print(f"  missing fallback row: {key[0]}.{key[1]}")
    for key in extra:
        has_error = True
        print(f"  extra fallback row: {key[0]}.{key[1]}")
    for key in sorted(set(db_formulaires) & fallback_keys):
        db_row = db_formulaires[key]
        fallback_row = fallback_formulaires[key]
        diffs = [
            f"{field}=db:{db_row[field]!r}/fallback:{fallback_row[field]!r}"
            for field in ("titre_app", "ordre", "visible", "download_mobile")
            if db_row[field] != fallback_row[field]
        ]
        if diffs:
            has_error = True
            print(f"  mismatch {key[0]}.{key[1]} | " + "; ".join(diffs))
    if not missing and not extra and not has_error:
        print("  formulaire_config_mobile fallback matches DB rows.")

    print("\nSRM_CONFIG_FALLBACK_REGRESSIONS")
    regression_errors: list[str] = []
    exact_fields = {
        "borne_onep": ["ep_coor_x", "ep_coor_y", "ep_coor_z"],
        "bouche_a_cles": ["ep_coor_x", "ep_coor_y", "ep_coor_z"],
        "autre_objet": ["ep_coor_x", "ep_coor_y", "ep_coor_z", "observation"],
        "compteur_abonne": [
            "type_cpt",
            "diametre",
            "ep_observation",
            "ep_anomalie",
            "type_anomalie",
            "num_contrat",
            "ancienne_police",
            "abon",
            "nom",
            "adresse",
            "etat_abonnement",
            "ancien_ref_sap",
            "id_geo",
            "ep_conf_plan",
            "mode_localisation",
        ],
        "conduite_terrain": ["ep_diam", "ep_mat"],
    }
    for table_name, expected_fields in exact_fields.items():
        actual_fields = srm_config_fields.get(table_name)
        if actual_fields != expected_fields:
            regression_errors.append(
                f"{table_name} fields=db:{expected_fields!r}/fallback:{actual_fields!r}"
            )
    hydrant_fields = set(srm_config_fields.get("hydrant", []))
    hidden_hydrant_conform = {
        "ep_conform",
        "conformite_plan",
    }
    leaked_fields = sorted(hydrant_fields & hidden_hydrant_conform)
    if leaked_fields:
        regression_errors.append(
            "hydrant fallback leaks hidden conformity fields: "
            + ", ".join(leaked_fields)
        )
    required_hydrant_fields = {"conform", "ep_conf_plan"}
    missing_hydrant_fields = sorted(required_hydrant_fields - hydrant_fields)
    if missing_hydrant_fields:
        regression_errors.append(
            "hydrant fallback misses visible conformity fields: "
            + ", ".join(missing_hydrant_fields)
        )
    if regression_errors:
        has_error = True
        for error in regression_errors:
            print(f"  {error}")
    else:
        print("  targeted SrmConfig fallbacks match current mobile rules.")

    print("\nLISTE_CHOIX_COUNTS")
    for row in choice_counts:
        print(f"  {row[0]}: total={row[1]} active={row[2]} tables={row[3]} fields={row[4]}")

    print("\nMOBILE_DOWNLOAD_CHECK")
    download_gaps = 0
    for (
        nom_metier,
        nom_table,
        titre,
        ordre,
        visible,
        download_mobile,
        total,
        visible_fields,
        choice_fields,
        choices,
        geom_type,
    ) in form_rows:
        mobile_table = _mobile_table_for_config_table(
            nom_metier, nom_table, ep_mobile_map, asst_mobile_map
        )
        schema_key = f"{nom_metier}/{mobile_table}"
        has_srm_entity = mobile_table in srm_config_tables
        has_sync_endpoint = schema_key in sync_endpoint_keys
        is_onep_reference = nom_metier == "ep" and nom_table == "onep_db"
        is_ep_regard_mirror = nom_metier == "ep" and nom_table == "ep_regard"
        if visible and not download_mobile:
            has_error = True
            print(f"  ERROR visible without download_mobile: {nom_metier}.{nom_table}")
        if nom_metier == "elec" and download_mobile:
            has_error = True
            print(f"  ERROR elec exported mobile: {nom_metier}.{nom_table}")
        if is_onep_reference and (visible or not download_mobile):
            has_error = True
            print("  ERROR ep.onep_db must be visible=false and download_mobile=true")
        if download_mobile and not is_onep_reference and not is_ep_regard_mirror and (
            not has_srm_entity or not has_sync_endpoint
        ):
            download_gaps += 1
            print(
                "  "
                f"warning unsupported download row: {nom_metier}.{nom_table} -> "
                f"{mobile_table} | visible={visible} | "
                f"srm_config={has_srm_entity} sync_endpoint={has_sync_endpoint} | "
                f"{titre}"
            )
    if download_gaps == 0:
        print("  download_mobile rows are technically covered.")

    print("\nLOCATION_ONLY_FORMS")
    location_only_rows = 0
    for nom_metier, nom_table, titre, ordre, visible, download_mobile, total, visible_fields, choice_fields, choices, geom_type in form_rows:
        if not visible or not _is_location_only_form(nom_metier, nom_table):
            continue
        location_only_rows += 1
        mobile_table = _mobile_table_for_config_table(
            nom_metier, nom_table, ep_mobile_map, asst_mobile_map
        )
        schema_key = f"{nom_metier}/{mobile_table}"
        has_srm_entity = mobile_table in srm_config_tables
        has_sync_endpoint = schema_key in sync_endpoint_keys
        print(
            "  "
            f"{nom_metier}.{nom_table} -> {mobile_table} | "
            f"ordre={ordre} | fields={visible_fields}/{total} | "
            f"geom={geom_type or '-'} | "
            f"srm_config={has_srm_entity} sync_endpoint={has_sync_endpoint} | "
            f"{titre}"
        )
    if location_only_rows == 0:
        print("  none")

    print("\nVISIBLE_FORM_GAPS")
    gaps = 0
    for nom_metier, nom_table, titre, ordre, visible, download_mobile, total, visible_fields, choice_fields, choices, geom_type in form_rows:
        if not visible:
            continue
        mobile_table = _mobile_table_for_config_table(
            nom_metier, nom_table, ep_mobile_map, asst_mobile_map
        )
        schema_key = f"{nom_metier}/{mobile_table}"
        has_srm_entity = mobile_table in srm_config_tables
        has_sync_endpoint = schema_key in sync_endpoint_keys
        expected_location_only = _is_location_only_form(nom_metier, nom_table)
        has_missing_fields = visible_fields == 0 and not expected_location_only
        if not has_srm_entity or not has_sync_endpoint or has_missing_fields:
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
    for nom_metier, nom_table, titre, ordre, visible, download_mobile, total, visible_fields, choice_fields, choices, geom_type in form_rows:
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
        has_error = True

    print("\nCROSS_METIER_COORD_FIELDS")
    if not cross_metier_hidden_coords:
        print("  none")
    for nom_metier, nom_table, nom_champ, visible, ordre in cross_metier_hidden_coords:
        visibility = "visible" if visible else "hidden"
        print(f"  {nom_metier}.{nom_table}.{nom_champ} | {visibility} | ordre={ordre}")

    return 1 if has_error else 0


if __name__ == "__main__":
    raise SystemExit(main())
