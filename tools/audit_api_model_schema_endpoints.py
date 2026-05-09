"""
Audit API/table compatibility for SRM backend.

Checks:
- mobile SRM endpoints exposed through views.mobile_srm_table_view
- DRF router endpoints smoke status
- Django model fields versus real database columns

The mobile routes are registered before the DRF router and therefore shadow
same-path ViewSets. A stale ViewSet model on a shadowed mobile path is reported
as a warning, while real mobile route failures are hard failures.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DJANGO_ROOT = ROOT / "API_GeoDjango" / "pprcollecte"
sys.path.insert(0, str(DJANGO_ROOT))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "pprcollecte.settings")

import django  # noqa: E402

django.setup()

from django.db import connection  # noqa: E402
from rest_framework.test import APIClient  # noqa: E402

from api.urls import router  # noqa: E402
from api import views  # noqa: E402


def parse_db_table(db_table: str) -> tuple[str, str]:
    quoted = re.findall(r'"([^"]+)"', db_table or "")
    if len(quoted) >= 2:
        return quoted[-2], quoted[-1]

    raw = (db_table or "").replace('"', "")
    if "." in raw:
        schema, table = raw.split(".", 1)
        return schema, table
    return "public", raw


def db_columns(schema: str, table: str) -> list[str]:
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = %s
              AND table_name = %s
            ORDER BY ordinal_position
            """,
            [schema, table],
        )
        return [row[0] for row in cursor.fetchall()]


def table_exists(schema: str, table: str) -> bool:
    with connection.cursor() as cursor:
        cursor.execute("SELECT to_regclass(%s)", [f"{schema}.{table}"])
        row = cursor.fetchone()
    return bool(row and row[0])


def get_viewset_model(viewset: type) -> Any | None:
    serializer = getattr(viewset, "serializer_class", None)
    if serializer is not None:
        meta = getattr(serializer, "Meta", None)
        model = getattr(meta, "model", None)
        if model is not None:
            return model

    queryset = getattr(viewset, "queryset", None)
    return getattr(queryset, "model", None) if queryset is not None else None


def get_json(response) -> Any:
    try:
        return response.json()
    except Exception:
        return None


def summarize_mobile_payload(data: Any) -> dict[str, Any]:
    if not isinstance(data, dict):
        return {"shape": type(data).__name__}

    result: dict[str, Any] = {
        "shape": "dict",
        "keys": sorted(data.keys()),
        "count": data.get("count"),
        "has_next": bool(data.get("next")),
    }
    results = data.get("results")
    if isinstance(results, list):
        result["page_items"] = len(results)
        first = results[0] if results else None
    else:
        first = None

    if isinstance(first, dict):
        result["first_has_geometry_geojson"] = bool(first.get("geometry_geojson"))
        result["first_keys"] = sorted(first.keys())[:25]

    return result


def audit_mobile_endpoints(client: APIClient) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    failures: list[dict[str, Any]] = []
    rows: list[dict[str, Any]] = []

    endpoint_map = {
        **views.MOBILE_SRM_TABLE_ENDPOINTS,
        **getattr(views, "MOBILE_REFERENCE_TABLE_ENDPOINTS", {}),
    }

    for endpoint, (schema, table) in sorted(endpoint_map.items()):
        columns = db_columns(schema, table)
        row: dict[str, Any] = {
            "endpoint": endpoint,
            "table": f"{schema}.{table}",
            "table_exists": bool(columns),
            "column_count": len(columns),
            "has_geom": "geom" in columns,
        }

        if not columns:
            failures.append(
                {
                    "kind": "mobile_table_missing",
                    "endpoint": endpoint,
                    "table": f"{schema}.{table}",
                }
            )
            rows.append(row)
            continue

        response = client.get(f"/api/{endpoint}/?page_size=1")
        row["status"] = response.status_code
        payload = get_json(response)
        row["payload"] = summarize_mobile_payload(payload)

        if response.status_code >= 500:
            failures.append(
                {
                    "kind": "mobile_endpoint_5xx",
                    "endpoint": endpoint,
                    "status": response.status_code,
                    "body": response.content[:500].decode("utf-8", errors="replace"),
                }
            )
        elif response.status_code != 200:
            failures.append(
                {
                    "kind": "mobile_endpoint_non_200",
                    "endpoint": endpoint,
                    "status": response.status_code,
                }
            )
        elif not isinstance(payload, dict) or "results" not in payload:
            failures.append(
                {
                    "kind": "mobile_endpoint_bad_shape",
                    "endpoint": endpoint,
                    "payload_type": type(payload).__name__,
                }
            )

        rows.append(row)

    return rows, failures


def audit_router_viewsets(
    client: APIClient,
    *,
    strict_models: bool,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    failures: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    rows: list[dict[str, Any]] = []
    shadowed_prefixes = set(views.MOBILE_SRM_TABLE_ENDPOINTS) | set(
        getattr(views, "MOBILE_REFERENCE_TABLE_ENDPOINTS", {})
    )

    for prefix, viewset, basename in router.registry:
        model = get_viewset_model(viewset)
        row: dict[str, Any] = {
            "prefix": prefix,
            "basename": basename,
            "viewset": viewset.__name__,
            "shadowed_by_mobile_route": prefix in shadowed_prefixes,
        }

        if model is not None:
            schema, table = parse_db_table(model._meta.db_table)
            columns = db_columns(schema, table)
            model_columns = [field.column for field in model._meta.fields]
            missing = sorted(set(model_columns) - set(columns))
            extra = sorted(set(columns) - set(model_columns))
            row.update(
                {
                    "model": model.__name__,
                    "table": f"{schema}.{table}",
                    "table_exists": bool(columns),
                    "model_missing_db_columns": missing,
                    "db_columns_not_in_model_count": len(extra),
                }
            )
            if not columns:
                failures.append(
                    {
                        "kind": "router_model_table_missing",
                        "prefix": prefix,
                        "model": model.__name__,
                        "table": f"{schema}.{table}",
                    }
                )
            elif missing:
                issue = {
                    "kind": "router_model_missing_db_columns",
                    "prefix": prefix,
                    "model": model.__name__,
                    "table": f"{schema}.{table}",
                    "columns": missing,
                    "shadowed_by_mobile_route": prefix in shadowed_prefixes,
                }
                if strict_models or prefix not in shadowed_prefixes:
                    failures.append(issue)
                else:
                    warnings.append(issue)

        response = client.get(f"/api/{prefix}/?page_size=1")
        row["status"] = response.status_code
        if response.status_code >= 500 and prefix not in shadowed_prefixes:
            failures.append(
                {
                    "kind": "router_endpoint_5xx",
                    "prefix": prefix,
                    "status": response.status_code,
                    "body": response.content[:500].decode("utf-8", errors="replace"),
                }
            )
        rows.append(row)

    return rows, failures, warnings


def write_report(report: dict[str, Any]) -> tuple[Path, Path]:
    reports_dir = ROOT / "reports"
    reports_dir.mkdir(exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    json_path = reports_dir / f"api_model_endpoint_audit_{stamp}.json"
    md_path = reports_dir / f"api_model_endpoint_audit_{stamp}.md"

    json_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    lines = [
        "# API model/endpoint audit",
        "",
        f"- generated_at: `{report['generated_at']}`",
        f"- mobile_endpoints: `{len(report['mobile_endpoints'])}`",
        f"- router_viewsets: `{len(report['router_viewsets'])}`",
        f"- failures: `{len(report['failures'])}`",
        f"- warnings: `{len(report['warnings'])}`",
        "",
    ]

    if report["failures"]:
        lines.append("## Failures")
        for item in report["failures"]:
            lines.append(f"- `{item.get('kind')}` {json.dumps(item, ensure_ascii=False)}")
        lines.append("")

    if report["warnings"]:
        lines.append("## Warnings")
        for item in report["warnings"]:
            columns = item.get("columns") or []
            lines.append(
                f"- `{item.get('prefix')}` `{item.get('model')}` -> "
                f"`{item.get('table')}` missing {len(columns)} column(s): "
                f"{', '.join(columns[:20])}"
            )
        lines.append("")

    lines.append("## Mobile Endpoints")
    for row in report["mobile_endpoints"]:
        payload = row.get("payload") or {}
        lines.append(
            f"- `/api/{row['endpoint']}/` -> `{row.get('status')}` "
            f"`{row['table']}` columns={row['column_count']} "
            f"items={payload.get('page_items')} count={payload.get('count')}"
        )

    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return md_path, json_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--strict-models",
        action="store_true",
        help="Fail on missing model columns even when a mobile raw route shadows the ViewSet.",
    )
    args = parser.parse_args()

    client = APIClient()
    mobile_rows, mobile_failures = audit_mobile_endpoints(client)
    router_rows, router_failures, router_warnings = audit_router_viewsets(
        client,
        strict_models=args.strict_models,
    )

    report = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "strict_models": args.strict_models,
        "mobile_endpoints": mobile_rows,
        "router_viewsets": router_rows,
        "failures": mobile_failures + router_failures,
        "warnings": router_warnings,
    }
    md_path, json_path = write_report(report)

    print("API model/endpoint audit")
    print(f"Report: {md_path}")
    print(f"JSON: {json_path}")
    print(f"Failures: {len(report['failures'])}")
    print(f"Warnings: {len(report['warnings'])}")
    return 1 if report["failures"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
