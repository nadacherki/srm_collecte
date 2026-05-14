"""Audit what the Flutter mobile app stores and uses locally.

The report compares:
- hard-coded SQLite/SrmConfig tables in Flutter,
- mobile API endpoint mappings in Django,
- current PostgreSQL mobile config tables.

It is intentionally read-only.
"""

from __future__ import annotations

import datetime as dt
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
API_ROOT = REPO / "API_GeoDjango" / "pprcollecte"
FLUTTER_ROOT = REPO / "PPRCollecte_Flutter"
REPORTS_DIR = REPO / "reports"

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "pprcollecte.settings")
sys.path.insert(0, str(API_ROOT))

import django  # noqa: E402

django.setup()

from django.db import connection  # noqa: E402


@dataclass(frozen=True)
class SrmEntity:
    entity: str
    schema: str
    mobile_table: str
    physical_table: str
    geometry_type: str
    fields_count: int
    max_photos: str
    has_z: str


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def _fetchall(query: str, params: list[object] | None = None) -> list[tuple]:
    with connection.cursor() as cursor:
        cursor.execute(query, params or [])
        return list(cursor.fetchall())


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


def _parse_api_mobile_endpoints(text: str) -> dict[str, tuple[str, str]]:
    match = re.search(r"MOBILE_SRM_TABLE_ENDPOINTS\s*=\s*\{(.*?)\n\}", text, re.S)
    if not match:
        return {}
    return {
        endpoint: (schema, table)
        for endpoint, schema, table in re.findall(
            r"'([^']+)'\s*:\s*\('([^']+)'\s*,\s*'([^']+)'\)",
            match.group(1),
        )
    }


def _parse_sync_endpoint_map(text: str) -> dict[str, str]:
    match = re.search(r"endpointMap\s*=\s*<String,\s*String>\{(.*?)\};", text, re.S)
    if not match:
        return {}
    return {
        key: value
        for key, value in re.findall(r"'([^']+)'\s*:\s*'([^']+)'", match.group(1))
    }


def _parse_static_sqlite_tables(text: str) -> list[str]:
    tables = sorted(
        set(
            re.findall(
                r"CREATE\s+TABLE\s+IF\s+NOT\s+EXISTS\s+([A-Za-z_][A-Za-z0-9_]*)",
                text,
                flags=re.I,
            )
        )
    )
    return tables


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


def _extract_string(block: str, key: str, default: str = "") -> str:
    match = re.search(rf'"{re.escape(key)}"\s*:\s*"([^"]*)"', block)
    return match.group(1) if match else default


def _extract_scalar(block: str, key: str, default: str = "") -> str:
    match = re.search(rf'"{re.escape(key)}"\s*:\s*([^,\n\r]+)', block)
    if not match:
        return default
    return match.group(1).strip().strip('"')


def _extract_fields_count(block: str) -> int:
    match = re.search(r'"fields"\s*:\s*\[(.*?)\]', block, re.S)
    if not match:
        return 0
    return len(re.findall(r'"([^"]+)"', match.group(1)))


def _extract_entity_name(text: str, block_start: int) -> str:
    prefix_start = max(0, block_start - 160)
    prefix = text[prefix_start:block_start]
    matches = re.findall(r'"([^"]+)"\s*:\s*$', prefix, re.S)
    if matches:
        return matches[-1]
    line_start = text.rfind("\n", 0, block_start) + 1
    line = text[line_start:block_start]
    match = re.search(r'"([^"]+)"\s*:\s*$', line)
    return match.group(1) if match else "?"


def _parse_srm_entities(
    text: str,
    ep_mobile_to_config: dict[str, str],
    asst_mobile_to_config: dict[str, str],
) -> list[SrmEntity]:
    result: list[SrmEntity] = []
    for match in re.finditer(r'"tableName"\s*:\s*"([^"]+)"', text):
        mobile_table = match.group(1)
        start = text.rfind("{", 0, match.start())
        end = _matching_brace_end(text, start)
        if start < 0 or end < 0:
            continue
        block = text[start : end + 1]
        schema = _extract_string(block, "schema", "")
        if not schema:
            schema = "asst" if mobile_table.startswith("ASS_") else "ep"
        schema_key = "asst" if schema in {"ass", "asst"} else schema
        physical_table = mobile_table
        if schema_key == "ep":
            physical_table = ep_mobile_to_config.get(mobile_table, mobile_table)
        elif schema_key == "asst":
            physical_table = asst_mobile_to_config.get(mobile_table, mobile_table)
        result.append(
            SrmEntity(
                entity=_extract_entity_name(text, start),
                schema=schema_key,
                mobile_table=mobile_table,
                physical_table=physical_table,
                geometry_type=_extract_string(block, "geometryType", "-"),
                fields_count=_extract_fields_count(block),
                max_photos=_extract_scalar(block, "maxPhotos", "-"),
                has_z=_extract_scalar(block, "hasZ", "-"),
            )
        )
    return result


def _md_table(headers: list[str], rows: list[list[object]]) -> list[str]:
    def cell(value: object) -> str:
        text = "" if value is None else str(value)
        return text.replace("\n", " ").replace("|", "\\|")

    lines = ["| " + " | ".join(headers) + " |"]
    lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
    for row in rows:
        lines.append("| " + " | ".join(cell(value) for value in row) + " |")
    return lines


def _physical_key(schema: str, table: str) -> str:
    return f"{schema}.{table}"


def main() -> int:
    mapping_service = _read(FLUTTER_ROOT / "lib" / "services" / "attribut_config_mobile_service.dart")
    srm_config_text = _read(FLUTTER_ROOT / "lib" / "core" / "config" / "srm_config.dart")
    database_helper_text = _read(FLUTTER_ROOT / "lib" / "data" / "local" / "database_helper.dart")
    sync_service_text = _read(FLUTTER_ROOT / "lib" / "services" / "sync_service.dart")
    views_text = _read(API_ROOT / "api" / "views.py")

    ep_mobile_to_config = _parse_dart_map(mapping_service, "_epConfigTableByMobileTable")
    asst_mobile_to_config = _parse_dart_map(mapping_service, "_asstConfigTableByMobileTable")
    srm_entities = _parse_srm_entities(
        srm_config_text,
        ep_mobile_to_config=ep_mobile_to_config,
        asst_mobile_to_config=asst_mobile_to_config,
    )
    static_sqlite_tables = _parse_static_sqlite_tables(database_helper_text)
    api_endpoints = _parse_api_mobile_endpoints(views_text)
    sync_endpoint_map = _parse_sync_endpoint_map(sync_service_text)

    db_name = connection.settings_dict.get("NAME")
    generated_at = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    physical_tables = _fetchall(
        """
        SELECT table_schema, table_name
        FROM information_schema.tables
        WHERE table_schema IN ('public', 'ep', 'asst', 'elec')
          AND table_type = 'BASE TABLE'
        ORDER BY table_schema, table_name
        """
    )
    config_form_rows = _fetchall(
        """
        SELECT f.nom_metier,
               f.nom_table,
               f.titre_app,
               f.ordre,
               COALESCE(f.visible,false) AS visible,
               COALESCE(f.download_mobile,false) AS download_mobile,
               count(a.id) AS fields_total,
               count(a.id) FILTER (
                 WHERE (
                     COALESCE(a.visible,false)
                     OR (
                       f.nom_metier = 'ep'
                       AND lower(a.nom_champ) IN ('ep_coor_x', 'ep_coor_y', 'ep_coor_z')
                     )
                     OR (
                       f.nom_metier IN ('asst', 'ass')
                       AND lower(a.nom_champ) IN ('ass_coor_x', 'ass_coor_y', 'ass_coor_z')
                     )
                   )
                   AND NOT COALESCE(a.primary_key,false)
                   AND lower(a.nom_champ) <> 'geom'
               ) AS fields_visible
        FROM public.formulaire_config_mobile f
        LEFT JOIN public.attribut_config_mobile a
          ON a.nom_metier = f.nom_metier
         AND a.nom_table = f.nom_table
        WHERE f.nom_metier IN ('ep', 'asst')
        GROUP BY f.nom_metier, f.nom_table, f.titre_app, f.ordre, f.visible,
                 f.download_mobile, f.id
        ORDER BY f.nom_metier, COALESCE(f.ordre,999999), f.id
        """
    )
    attribute_refs = {
        _physical_key(schema, table)
        for schema, table in _fetchall(
            """
            SELECT DISTINCT nom_metier, nom_table
            FROM public.attribut_config_mobile
            WHERE nom_metier IN ('ep', 'asst', 'elec')
            """
        )
    }
    choice_refs = {
        _physical_key(schema, table)
        for schema, table in _fetchall(
            """
            SELECT DISTINCT nom_metier, nom_table
            FROM public.liste_choix
            WHERE nom_metier IN ('ep', 'asst', 'elec')
            """
        )
    }
    form_refs = {_physical_key(row[0], row[1]) for row in config_form_rows}
    visible_form_refs = {_physical_key(row[0], row[1]) for row in config_form_rows if row[4]}
    endpoint_refs = {_physical_key(schema, table) for schema, table in api_endpoints.values()}
    srm_refs = {_physical_key(entity.schema, entity.physical_table) for entity in srm_entities}

    physical_by_schema: dict[str, list[str]] = defaultdict(list)
    for schema, table in physical_tables:
        physical_by_schema[schema].append(table)

    sqlite_local_rows: list[list[object]] = [
        [table, "statique DatabaseHelper"] for table in static_sqlite_tables
    ]
    sqlite_local_rows.extend(
        [
            entity.mobile_table,
            f"SrmConfig -> {entity.schema}.{entity.physical_table} / {entity.geometry_type}",
        ]
        for entity in sorted(srm_entities, key=lambda item: (item.schema, item.mobile_table))
    )

    endpoint_rows = [
        [endpoint, f"{schema}.{table}", "sync mobile" if endpoint in set(sync_endpoint_map.values()) else "API only"]
        for endpoint, (schema, table) in sorted(api_endpoints.items())
    ]

    form_rows = []
    for schema, table, title, order, visible, download_mobile, total, visible_count in config_form_rows:
        physical = _physical_key(schema, table)
        matching_srm = sorted(
            {
                entity.mobile_table
                for entity in srm_entities
                if _physical_key(entity.schema, entity.physical_table) == physical
            }
        )
        form_rows.append(
            [
                physical,
                title,
                order,
                "true" if visible else "false",
                "true" if download_mobile else "false",
                f"{visible_count}/{total}",
                ", ".join(matching_srm) if matching_srm else "-",
                "yes" if physical in endpoint_refs else "no",
            ]
        )

    direct_mobile_refs = form_refs | attribute_refs | choice_refs | endpoint_refs | srm_refs
    unused_candidate_rows = []
    for schema, tables in physical_by_schema.items():
        if schema not in {"ep", "asst", "elec"}:
            continue
        for table in tables:
            physical = _physical_key(schema, table)
            if physical in direct_mobile_refs:
                continue
            reason = "server-only candidate"
            if schema == "elec":
                reason = "elec restored on server; no current mobile config/SrmConfig"
            unused_candidate_rows.append([physical, reason])

    visible_without_srm_rows = []
    for schema, table, title, order, visible, download_mobile, total, visible_count in config_form_rows:
        if not visible:
            continue
        physical = _physical_key(schema, table)
        if physical not in srm_refs or physical not in endpoint_refs:
            visible_without_srm_rows.append(
                [
                    physical,
                    title,
                    order,
                    f"{visible_count}/{total}",
                    "yes" if physical in srm_refs else "no",
                    "yes" if physical in endpoint_refs else "no",
                ]
            )

    schema_counts = [
        [schema, len(tables)]
        for schema, tables in sorted(physical_by_schema.items())
    ]
    srm_counts: dict[str, int] = defaultdict(int)
    for entity in srm_entities:
        srm_counts[entity.schema] += 1

    lines: list[str] = []
    lines.append("# Audit stockage mobile et role de SrmConfig")
    lines.append("")
    lines.append(f"- Genere le: {generated_at}")
    lines.append(f"- Base Django: `{db_name}`")
    lines.append(f"- Tables SQLite statiques detectees: `{len(static_sqlite_tables)}`")
    lines.append(f"- Entites metier SrmConfig detectees: `{len(srm_entities)}`")
    lines.append(f"- Endpoints mobiles API detectes: `{len(api_endpoints)}`")
    lines.append("")
    lines.append("## Verdict")
    lines.append("")
    lines.append(
        "`SrmConfig` reste un registre technique critique cote mobile: il cree les tables SQLite metier, "
        "sert a la legende/carte, aux formulaires, au sync et au lien entre noms mobiles et tables physiques. "
        "Il ne faut donc pas le supprimer brutalement."
    )
    lines.append("")
    lines.append(
        "En revanche, il ne doit plus etre la source metier principale pour l'ordre, la visibilite, "
        "les libelles et les listes: ces elements doivent venir de `formulaire_config_mobile`, "
        "`attribut_config_mobile` et `liste_choix`, avec un fallback strictement synchronise."
    )
    lines.append("")
    lines.append("## Resume")
    lines.extend(_md_table(["Source", "Nombre"], [["SrmConfig ep/asst/elec", dict(srm_counts)], ["Endpoints API", len(api_endpoints)], ["Static SQLite", len(static_sqlite_tables)]]))
    lines.append("")
    lines.append("## Tables physiques serveur")
    lines.extend(_md_table(["Schema", "Tables"], schema_counts))
    lines.append("")
    lines.append("## Tables SQLite locales declarees")
    lines.extend(_md_table(["Table locale", "Origine"], sqlite_local_rows))
    lines.append("")
    lines.append("## Formulaires config serveur vs mobile")
    lines.extend(_md_table(["Table physique", "Titre", "Ordre", "Visible", "Download", "Champs visibles/total", "Table locale SrmConfig", "Endpoint"], form_rows))
    lines.append("")
    lines.append("## Formulaires visibles avec gap technique")
    if visible_without_srm_rows:
        lines.extend(_md_table(["Table", "Titre", "Ordre", "Champs", "SrmConfig", "Endpoint"], visible_without_srm_rows))
    else:
        lines.append("Aucun gap detecte: chaque formulaire visible a une entree SrmConfig et un endpoint API.")
    lines.append("")
    lines.append("## Endpoints mobiles")
    lines.extend(_md_table(["Endpoint", "Table physique", "Usage"], endpoint_rows))
    lines.append("")
    lines.append("## Tables serveur sans usage mobile direct detecte")
    if unused_candidate_rows:
        lines.extend(_md_table(["Table", "Diagnostic"], unused_candidate_rows))
    else:
        lines.append("Aucune table ep/asst/elec hors references mobiles directes.")
    lines.append("")
    lines.append("## Recommandation de trajectoire")
    lines.append("")
    lines.append("1. Court terme: garder `SrmConfig` comme registre technique et fallback.")
    lines.append("2. Continuer a brancher ordre/visibilite/libelles/champs/listes sur les tables serveur.")
    lines.append("3. Ajouter plus tard cote serveur les metadonnees encore absentes: `table_mobile`, type geometrie, endpoint, icone/couleur, max photos.")
    lines.append("4. Quand ces metadonnees serveur existent, reduire `SrmConfig` a un fallback minimal ou le generer automatiquement.")

    REPORTS_DIR.mkdir(exist_ok=True)
    timestamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    report_path = REPORTS_DIR / f"mobile_storage_usage_audit_{timestamp}.md"
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(report_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
