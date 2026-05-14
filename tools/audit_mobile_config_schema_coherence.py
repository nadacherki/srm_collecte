#!/usr/bin/env python
"""Audit mobile config coherence with physical EP/ASST schemas.

The mobile contract is:
- physical server schemas stay stable unless explicitly approved;
- mobile-facing changes go through public.formulaire_config_mobile,
  public.attribut_config_mobile, and public.liste_choix;
- if a physical column exists for a mobile form table, the field metadata must
  exist in attribut_config_mobile, even when hidden.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DJANGO_DIR = ROOT / "API_GeoDjango" / "pprcollecte"


def setup_django() -> None:
    sys.path.insert(0, str(DJANGO_DIR))
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "pprcollecte.settings")
    import django

    django.setup()


def norm_type(value: str | None) -> str:
    if not value:
        return ""
    t = value.strip().lower()
    t = re.sub(r"\s+", " ", t)
    t = t.replace("varchar", "character varying")
    t = t.replace("timestamp with time zone", "timestamp with time zone")
    t = t.replace("timestamp without time zone", "timestamp without time zone")
    return t


def bool_from_db(value: Any) -> bool | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"true", "t", "1", "yes", "y"}
    return bool(value)


def clean_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def fetch_rows(sql: str, params: list[Any] | None = None) -> list[dict[str, Any]]:
    from django.db import connection

    with connection.cursor() as cursor:
        cursor.execute(sql, params or [])
        columns = [col[0] for col in cursor.description]
        return [dict(zip(columns, row)) for row in cursor.fetchall()]


def collect_physical_columns(schemas: list[str]) -> dict[tuple[str, str], dict[str, dict[str, Any]]]:
    rows = fetch_rows(
        """
        SELECT
            n.nspname AS schema_name,
            c.relname AS table_name,
            a.attname AS column_name,
            pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
            a.attnotnull AS not_null,
            (
                a.attnotnull OR EXISTS (
                    SELECT 1
                    FROM pg_catalog.pg_constraint con
                    WHERE con.conrelid = c.oid
                      AND con.contype = 'c'
                      AND (
                        con.conname = ('srm_nn_' || substr(md5(a.attname), 1, 16))
                        OR con.conname = ('srm_req_' || substr(md5(a.attname), 1, 16))
                      )
                )
            ) AS not_null_enforced,
            a.attnum AS ordinal_position
        FROM pg_catalog.pg_attribute a
        JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = ANY(%s)
          AND c.relkind IN ('r', 'p')
          AND a.attnum > 0
          AND NOT a.attisdropped
        ORDER BY n.nspname, c.relname, a.attnum
        """,
        [schemas],
    )
    physical: dict[tuple[str, str], dict[str, dict[str, Any]]] = defaultdict(dict)
    for row in rows:
        key = (row["schema_name"], row["table_name"])
        physical[key][row["column_name"]] = row
    return dict(physical)


def collect_form_tables(schemas: list[str]) -> dict[tuple[str, str], dict[str, Any]]:
    rows = fetch_rows(
        """
        SELECT
            id,
            nom_metier,
            nom_table,
            titre_app,
            visible,
            COALESCE(download_mobile, false) AS download_mobile
        FROM public.formulaire_config_mobile
        WHERE nom_metier = ANY(%s)
        ORDER BY nom_metier, nom_table
        """,
        [schemas],
    )
    return {(row["nom_metier"], row["nom_table"]): row for row in rows}


def collect_attributes(schemas: list[str]) -> dict[tuple[str, str, str], dict[str, Any]]:
    rows = fetch_rows(
        """
        SELECT
            id,
            nom_metier,
            nom_table,
            nom_champ,
            type_champ,
            nullable,
            visible,
            ordre,
            titre_app,
            primary_key,
            foreign_key,
            valeur_par_defaut
        FROM public.attribut_config_mobile
        WHERE nom_metier = ANY(%s)
        ORDER BY nom_metier, nom_table, nom_champ, id
        """,
        [schemas],
    )
    return {
        (row["nom_metier"], row["nom_table"], row["nom_champ"]): row
        for row in rows
    }


def collect_choices(schemas: list[str]) -> list[dict[str, Any]]:
    return fetch_rows(
        """
        SELECT
            lc.id,
            lc.nom_metier,
            lc.nom_table,
            lc.nom_champ,
            lc.attribut_config_mobile_id,
            lc.liste_choix_valeur,
            lc.liste_choix_alias,
            lc.liste_choix_actif,
            lc.liste_choix_ordre,
            acm.id AS acm_id,
            acm.nom_metier AS acm_metier,
            acm.nom_table AS acm_table,
            acm.nom_champ AS acm_champ
        FROM public.liste_choix lc
        LEFT JOIN public.attribut_config_mobile acm
          ON acm.id = lc.attribut_config_mobile_id
        WHERE lc.nom_metier = ANY(%s)
        ORDER BY lc.nom_metier, lc.nom_table, lc.nom_champ, lc.liste_choix_ordre, lc.id
        """,
        [schemas],
    )


def add_issue(target: list[dict[str, Any]], **kwargs: Any) -> None:
    target.append(kwargs)


def build_audit(schemas: list[str]) -> dict[str, Any]:
    physical = collect_physical_columns(schemas)
    forms = collect_form_tables(schemas)
    attrs = collect_attributes(schemas)
    choices = collect_choices(schemas)

    issues: dict[str, list[dict[str, Any]]] = {
        "missing_physical_tables": [],
        "type_mismatches": [],
        "nullable_mismatches": [],
        "attributes_without_physical_column": [],
        "physical_columns_without_attribute": [],
        "choices_without_attribute": [],
        "choices_without_physical_column": [],
        "choice_attribute_link_mismatches": [],
        "choice_default_mismatches": [],
    }

    form_keys = set(forms)
    physical_form_keys = set(physical) & form_keys

    for key, form in forms.items():
        if key not in physical:
            add_issue(
                issues["missing_physical_tables"],
                schema=key[0],
                table=key[1],
                titre_app=form.get("titre_app"),
                visible=bool_from_db(form.get("visible")),
                download_mobile=bool_from_db(form.get("download_mobile")),
            )

    for key in physical_form_keys:
        phys_cols = physical.get(key, {})
        attr_cols = {
            champ: row
            for (schema, table, champ), row in attrs.items()
            if (schema, table) == key
        }

        for column_name, physical_row in phys_cols.items():
            attr = attr_cols.get(column_name)
            if not attr:
                add_issue(
                    issues["physical_columns_without_attribute"],
                    schema=key[0],
                    table=key[1],
                    column=column_name,
                    physical_type=physical_row["data_type"],
                    nullable=not bool_from_db(physical_row["not_null"]),
                )
                continue

            physical_type = norm_type(physical_row["data_type"])
            configured_type = norm_type(attr.get("type_champ"))
            if physical_type != configured_type:
                add_issue(
                    issues["type_mismatches"],
                    schema=key[0],
                    table=key[1],
                    column=column_name,
                    physical_type=physical_row["data_type"],
                    configured_type=attr.get("type_champ"),
                    attribute_id=attr.get("id"),
                )

            physical_required = bool_from_db(
                physical_row.get("not_null_enforced", physical_row["not_null"])
            )
            configured_nullable = bool_from_db(attr.get("nullable"))
            if configured_nullable is not None and physical_required == configured_nullable:
                add_issue(
                    issues["nullable_mismatches"],
                    schema=key[0],
                    table=key[1],
                    column=column_name,
                    physical_not_null=physical_required,
                    configured_nullable=configured_nullable,
                    attribute_id=attr.get("id"),
                )

        for column_name, attr in attr_cols.items():
            if column_name not in phys_cols:
                add_issue(
                    issues["attributes_without_physical_column"],
                    schema=key[0],
                    table=key[1],
                    column=column_name,
                    attribute_id=attr.get("id"),
                    visible=bool_from_db(attr.get("visible")),
                    configured_type=attr.get("type_champ"),
                )

    for (schema, table, column), attr in attrs.items():
        if (schema, table) not in form_keys:
            continue
        if (schema, table) not in physical:
            continue
        if column not in physical[(schema, table)]:
            add_issue(
                issues["attributes_without_physical_column"],
                schema=schema,
                table=table,
                column=column,
                attribute_id=attr.get("id"),
                visible=bool_from_db(attr.get("visible")),
                configured_type=attr.get("type_champ"),
            )

    seen_attr_without_physical = {
        (i["schema"], i["table"], i["column"], i["attribute_id"])
        for i in issues["attributes_without_physical_column"]
    }
    issues["attributes_without_physical_column"] = [
        dict(schema=s, table=t, column=c, attribute_id=i, visible=v, configured_type=ty)
        for s, t, c, i, v, ty in sorted(
            {
                (
                    item["schema"],
                    item["table"],
                    item["column"],
                    item["attribute_id"],
                    item.get("visible"),
                    item.get("configured_type"),
                )
                for item in issues["attributes_without_physical_column"]
            }
        )
        if (s, t, c, i) in seen_attr_without_physical
    ]

    active_choice_values: dict[tuple[str, str, str], set[str]] = defaultdict(set)

    for choice in choices:
        key = (choice["nom_metier"], choice["nom_table"], choice["nom_champ"])
        table_key = (choice["nom_metier"], choice["nom_table"])
        if bool_from_db(choice.get("liste_choix_actif")) is not False:
            active_choice_values[key].add(clean_text(choice.get("liste_choix_valeur")))
        if table_key in form_keys and key not in attrs:
            add_issue(
                issues["choices_without_attribute"],
                schema=key[0],
                table=key[1],
                column=key[2],
                choice_id=choice["id"],
                value=choice.get("liste_choix_valeur"),
                alias=choice.get("liste_choix_alias"),
            )
        if table_key in physical and key[2] not in physical[table_key]:
            add_issue(
                issues["choices_without_physical_column"],
                schema=key[0],
                table=key[1],
                column=key[2],
                choice_id=choice["id"],
                value=choice.get("liste_choix_valeur"),
                alias=choice.get("liste_choix_alias"),
            )
        linked = (
            choice.get("acm_metier"),
            choice.get("acm_table"),
            choice.get("acm_champ"),
        )
        if any(linked) and linked != key:
            add_issue(
                issues["choice_attribute_link_mismatches"],
                schema=key[0],
                table=key[1],
                column=key[2],
                choice_id=choice["id"],
                attribute_config_mobile_id=choice.get("attribut_config_mobile_id"),
                linked_schema=linked[0],
                linked_table=linked[1],
                linked_column=linked[2],
            )
        if choice.get("attribut_config_mobile_id") and not any(linked):
            add_issue(
                issues["choice_attribute_link_mismatches"],
                schema=key[0],
                table=key[1],
                column=key[2],
                choice_id=choice["id"],
                attribute_config_mobile_id=choice.get("attribut_config_mobile_id"),
                linked_schema=None,
                linked_table=None,
                linked_column=None,
            )

    for key, attr in attrs.items():
        table_key = (key[0], key[1])
        if table_key not in form_keys:
            continue
        default_value = clean_text(attr.get("valeur_par_defaut"))
        if not default_value:
            continue
        values = active_choice_values.get(key) or set()
        if values and default_value not in values:
            add_issue(
                issues["choice_default_mismatches"],
                schema=key[0],
                table=key[1],
                column=key[2],
                attribute_id=attr.get("id"),
                default_value=default_value,
                active_choice_values=", ".join(sorted(v for v in values if v)),
            )

    for key in issues:
        issues[key] = sorted(
            issues[key],
            key=lambda row: (
                str(row.get("schema", "")),
                str(row.get("table", "")),
                str(row.get("column", "")),
                str(row.get("choice_id", "")),
                str(row.get("attribute_id", "")),
            ),
        )

    return {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "schemas": schemas,
        "summary": {
            "form_tables": len(forms),
            "physical_tables_checked": len(physical_form_keys),
            "attributes_checked": len(
                [
                    1
                    for (schema, table, _column) in attrs
                    if (schema, table) in form_keys
                ]
            ),
            "choices_checked": len(choices),
            **{name: len(rows) for name, rows in issues.items()},
        },
        "issues": issues,
    }


def render_markdown(audit: dict[str, Any]) -> str:
    lines = [
        "# Mobile Config Schema Coherence Audit",
        "",
        f"- Generated at: `{audit['generated_at']}`",
        f"- Schemas: `{', '.join(audit['schemas'])}`",
        "",
        "## Summary",
        "",
    ]
    for key, value in audit["summary"].items():
        lines.append(f"- `{key}`: {value}")
    lines.append("")

    for issue_name, rows in audit["issues"].items():
        lines.extend([f"## {issue_name}", ""])
        if not rows:
            lines.extend(["OK", ""])
            continue
        headers = sorted({key for row in rows for key in row})
        lines.append("| " + " | ".join(headers) + " |")
        lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
        for row in rows:
            values = []
            for header in headers:
                value = row.get(header)
                text = "" if value is None else str(value)
                text = text.replace("|", "\\|")
                values.append(text)
            lines.append("| " + " | ".join(values) + " |")
        lines.append("")
    return "\n".join(lines)


def default_report_path() -> Path:
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return ROOT / "reports" / f"mobile_config_schema_coherence_audit_{stamp}.md"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Check that EP/ASST mobile form tables are coherent with "
            "attribut_config_mobile and liste_choix."
        )
    )
    parser.add_argument(
        "--schemas",
        default="ep,asst",
        help="Comma-separated schemas to audit. Default: ep,asst",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=None,
        help="Markdown report path. Default: reports/mobile_config_schema_coherence_audit_TIMESTAMP.md",
    )
    parser.add_argument(
        "--json",
        dest="json_path",
        type=Path,
        default=None,
        help="Optional JSON report path.",
    )
    parser.add_argument(
        "--no-fail",
        action="store_true",
        help="Write the report but return exit code 0 even when issues exist.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    schemas = [schema.strip() for schema in args.schemas.split(",") if schema.strip()]
    if not schemas:
        raise SystemExit("No schemas provided.")

    setup_django()
    audit = build_audit(schemas)

    report_path = args.report or default_report_path()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(render_markdown(audit), encoding="utf-8")

    json_path = args.json_path
    if json_path is None:
        json_path = report_path.with_suffix(".json")
    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(
        json.dumps(audit, ensure_ascii=False, indent=2, default=str),
        encoding="utf-8",
    )

    issue_count = sum(len(rows) for rows in audit["issues"].values())
    print("Mobile config schema coherence audit")
    print(f"Report: {report_path}")
    print(f"JSON: {json_path}")
    print(f"Issues: {issue_count}")
    for name, rows in audit["issues"].items():
        print(f"- {name}: {len(rows)}")

    if issue_count and not args.no_fail:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
