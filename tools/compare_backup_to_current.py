from __future__ import annotations

import argparse
import collections
import datetime as dt
import json
import os
import pathlib
import subprocess
import sys
import uuid

import psycopg2
from psycopg2.extras import RealDictCursor


ROOT = pathlib.Path(__file__).resolve().parents[1]
SETTINGS_ENV = ROOT / "API_GeoDjango" / "pprcollecte" / ".env"
REPORTS_DIR = ROOT / "reports"
PG_BIN = pathlib.Path(r"C:\Program Files\PostgreSQL\17\bin")

SYSTEM_SCHEMAS = {
    "information_schema",
    "pg_catalog",
    "pg_toast",
}

SKIP_TABLES = {
    ("public", "spatial_ref_sys"),
    ("topology", "topology"),
}

DATA_EXACT_TABLES = {
    ("public", "formulaire_config_mobile"),
    ("public", "attribut_config_mobile"),
    ("public", "liste_choix"),
    ("public", "srm_field_options"),
    ("public", "zone_utilisateur"),
    ("public", "zones"),
    ("public", "onep_commune_alias"),
    ("public", "intervention_anomalie"),
    ("public", "objet_incomplet"),
}

SMALL_TABLE_THRESHOLD = 300

LOGICAL_COMPARE_COLUMNS = {
    ("public", "formulaire_config_mobile"): [
        "nom_metier",
        "nom_table",
        "titre_app",
        "ordre",
        "visible",
        "download_mobile",
    ],
    ("public", "attribut_config_mobile"): [
        "nom_metier",
        "nom_table",
        "nom_champ",
        "type_champ",
        "primary_key",
        "foreign_key",
        "ordre",
        "titre_app",
        "visible",
        "contraintes",
        "nullable",
        "valeur_par_defaut",
        "valeur_min",
        "valeur_max",
        "reference_fk",
    ],
    ("public", "liste_choix"): [
        "nom_metier",
        "nom_table",
        "nom_champ",
        "valeur",
        "alias",
        "ordre",
        "visible",
    ],
    ("ep", "ep_compteur_i"): [
        "uuid",
        "ep_num",
        "ep_coor_x",
        "ep_coor_y",
        "ep_coor_z",
        "anomalie",
        "objet_incomplet",
        "date_collecte",
    ],
}


def load_env_file(path: pathlib.Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def db_params(dbname: str | None = None) -> dict[str, str]:
    load_env_file(SETTINGS_ENV)
    return {
        "dbname": dbname or os.environ.get("DB_NAME", "sig_srm"),
        "user": os.environ.get("DB_USER", "postgres"),
        "password": os.environ.get("DB_PASSWORD", "geoinfo"),
        "host": os.environ.get("DB_HOST", "127.0.0.1"),
        "port": os.environ.get("DB_PORT", "5432"),
    }


def connect(dbname: str | None = None):
    params = db_params(dbname)
    conn = psycopg2.connect(**params)
    conn.autocommit = True
    return conn


def terminate_and_drop_db(dbname: str) -> None:
    conn = connect("postgres")
    try:
        cur = conn.cursor()
        cur.execute(
            """
            SELECT pg_terminate_backend(pid)
            FROM pg_stat_activity
            WHERE datname = %s
              AND pid <> pg_backend_pid()
            """,
            (dbname,),
        )
        cur.execute(f'DROP DATABASE IF EXISTS "{dbname}"')
        cur.close()
    finally:
        conn.close()


def create_temp_db(dbname: str) -> None:
    conn = connect("postgres")
    try:
        cur = conn.cursor()
        cur.execute(f'CREATE DATABASE "{dbname}"')
        cur.close()
    finally:
        conn.close()


def run_pg_restore(backup_path: pathlib.Path, target_db: str) -> None:
    pg_restore = PG_BIN / "pg_restore.exe"
    if not pg_restore.exists():
        raise FileNotFoundError(f"pg_restore introuvable: {pg_restore}")
    params = db_params(target_db)
    env = os.environ.copy()
    env["PGPASSWORD"] = params["password"]
    cmd = [
        str(pg_restore),
        "--no-owner",
        "--no-privileges",
        "--host",
        params["host"],
        "--port",
        params["port"],
        "--username",
        params["user"],
        "--dbname",
        target_db,
        str(backup_path),
    ]
    completed = subprocess.run(
        cmd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            "pg_restore a echoue.\n"
            f"stdout:\n{completed.stdout}\n"
            f"stderr:\n{completed.stderr}"
        )


def fetch_all(cur, sql: str, params: tuple | None = None):
    cur.execute(sql, params or ())
    return cur.fetchall()


def list_schemas(conn) -> list[str]:
    with conn.cursor() as cur:
        rows = fetch_all(
            cur,
            """
            SELECT schema_name
            FROM information_schema.schemata
            WHERE schema_name NOT LIKE %s
              AND schema_name <> 'information_schema'
            ORDER BY schema_name
            """,
            ("pg_%",),
        )
    return [r[0] for r in rows]


def list_tables(conn) -> list[tuple[str, str]]:
    with conn.cursor() as cur:
        rows = fetch_all(
            cur,
            """
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_type = 'BASE TABLE'
              AND table_schema NOT LIKE %s
              AND table_schema <> 'information_schema'
            ORDER BY table_schema, table_name
            """,
            ("pg_%",),
        )
    return [
        (schema, table)
        for schema, table in rows
        if (schema, table) not in SKIP_TABLES
    ]


def get_columns(conn, schema: str, table: str) -> list[dict]:
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
              a.attnum AS ordinal_position,
              a.attname AS column_name,
              pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
              a.attnotnull AS not_null,
              pg_get_expr(ad.adbin, ad.adrelid) AS column_default
            FROM pg_attribute a
            JOIN pg_class c ON c.oid = a.attrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            LEFT JOIN pg_attrdef ad
              ON ad.adrelid = a.attrelid AND ad.adnum = a.attnum
            WHERE n.nspname = %s
              AND c.relname = %s
              AND a.attnum > 0
              AND NOT a.attisdropped
            ORDER BY a.attnum
            """,
            (schema, table),
        )
        return [dict(row) for row in cur.fetchall()]


def get_constraints(conn, schema: str, table: str) -> list[str]:
    with conn.cursor() as cur:
        rows = fetch_all(
            cur,
            """
            SELECT pg_get_constraintdef(con.oid, true) AS definition
            FROM pg_constraint con
            JOIN pg_class rel ON rel.oid = con.conrelid
            JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
            WHERE nsp.nspname = %s
              AND rel.relname = %s
            ORDER BY 1
            """,
            (schema, table),
        )
    return [row[0] for row in rows]


def get_indexes(conn, schema: str, table: str) -> list[str]:
    with conn.cursor() as cur:
        rows = fetch_all(
            cur,
            """
            SELECT indexdef
            FROM pg_indexes
            WHERE schemaname = %s
              AND tablename = %s
            ORDER BY indexname
            """,
            (schema, table),
        )
    return [row[0] for row in rows]


def count_rows(conn, schema: str, table: str) -> int:
    with conn.cursor() as cur:
        cur.execute(f'SELECT COUNT(*) FROM "{schema}"."{table}"')
        return int(cur.fetchone()[0])


def fetch_row_json_texts(conn, schema: str, table: str) -> collections.Counter[str]:
    with conn.cursor() as cur:
        cur.execute(f'SELECT row_to_json(t)::text FROM "{schema}"."{table}" t')
        rows = cur.fetchall()
    return collections.Counter(row[0] for row in rows)


def fetch_selected_row_json_texts(
    conn,
    schema: str,
    table: str,
    columns: list[str],
) -> collections.Counter[str]:
    existing_columns = {
        row["column_name"] for row in get_columns(conn, schema, table)
    }
    filtered_columns = [column for column in columns if column in existing_columns]
    if not filtered_columns:
        return collections.Counter()
    quoted = ", ".join(f'"{column}"' for column in filtered_columns)
    sql = (
        f'SELECT row_to_json(t)::text '
        f'FROM (SELECT {quoted} FROM "{schema}"."{table}") t'
    )
    with conn.cursor() as cur:
        cur.execute(sql)
        rows = cur.fetchall()
    return collections.Counter(row[0] for row in rows)


def compare_columns(curr_cols: list[dict], backup_cols: list[dict]) -> list[str]:
    diffs: list[str] = []
    curr_by_name = {c["column_name"]: c for c in curr_cols}
    bak_by_name = {c["column_name"]: c for c in backup_cols}
    all_names = sorted(set(curr_by_name) | set(bak_by_name))
    for name in all_names:
        if name not in curr_by_name:
            diffs.append(f"colonne absente en current: {name}")
            continue
        if name not in bak_by_name:
            diffs.append(f"colonne absente en backup: {name}")
            continue
        c = curr_by_name[name]
        b = bak_by_name[name]
        if c["data_type"] != b["data_type"]:
            diffs.append(
                f"type different pour {name}: current={c['data_type']} | backup={b['data_type']}"
            )
        if bool(c["not_null"]) != bool(b["not_null"]):
            diffs.append(
                f"nullabilite differente pour {name}: current not_null={c['not_null']} | backup not_null={b['not_null']}"
            )
        if (c["column_default"] or "") != (b["column_default"] or ""):
            diffs.append(
                f"default different pour {name}: current={c['column_default']} | backup={b['column_default']}"
            )
    return diffs


def compare_definition_list(
    current_defs: list[str], backup_defs: list[str], label: str
) -> list[str]:
    diffs: list[str] = []
    current_only = sorted(set(current_defs) - set(backup_defs))
    backup_only = sorted(set(backup_defs) - set(current_defs))
    for item in current_only[:20]:
        diffs.append(f"{label} seulement en current: {item}")
    if len(current_only) > 20:
        diffs.append(f"{label} seulement en current: +{len(current_only) - 20} autres")
    for item in backup_only[:20]:
        diffs.append(f"{label} seulement en backup: {item}")
    if len(backup_only) > 20:
        diffs.append(f"{label} seulement en backup: +{len(backup_only) - 20} autres")
    return diffs


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("backup_path")
    parser.add_argument("--report", default="")
    args = parser.parse_args()

    backup_path = pathlib.Path(args.backup_path)
    if not backup_path.exists():
        raise SystemExit(f"Backup introuvable: {backup_path}")

    REPORTS_DIR.mkdir(parents=True, exist_ok=True)
    report_path = (
        pathlib.Path(args.report)
        if args.report
        else REPORTS_DIR
        / f"compare_current_vs_{backup_path.stem}_{dt.datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
    )

    temp_db = f"codex_cmp_{dt.datetime.now().strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:6]}"
    current_conn = None
    backup_conn = None
    try:
        current_conn = connect()
        create_temp_db(temp_db)
        run_pg_restore(backup_path, temp_db)
        backup_conn = connect(temp_db)

        current_tables = set(list_tables(current_conn))
        backup_tables = set(list_tables(backup_conn))
        all_tables = sorted(current_tables | backup_tables)

        lines: list[str] = []
        lines.append(f"# Comparaison BD actuelle vs {backup_path.name}")
        lines.append("")
        lines.append(f"- Date: {dt.datetime.now().isoformat(timespec='seconds')}")
        lines.append(f"- Backup comparé: `{backup_path}`")
        lines.append(f"- BD actuelle: `{db_params()['dbname']}` sur `{db_params()['host']}:{db_params()['port']}`")
        lines.append("")

        current_only_tables = sorted(current_tables - backup_tables)
        backup_only_tables = sorted(backup_tables - current_tables)
        lines.append("## Résumé structure")
        lines.append("")
        lines.append(f"- Tables seulement en BD actuelle: {len(current_only_tables)}")
        lines.append(f"- Tables seulement dans le backup: {len(backup_only_tables)}")
        lines.append(f"- Tables communes: {len(current_tables & backup_tables)}")
        lines.append("")

        if current_only_tables:
            lines.append("### Tables seulement en BD actuelle")
            for schema, table in current_only_tables:
                lines.append(f"- `{schema}.{table}`")
            lines.append("")

        if backup_only_tables:
            lines.append("### Tables seulement dans le backup")
            for schema, table in backup_only_tables:
                lines.append(f"- `{schema}.{table}`")
            lines.append("")

        structure_diffs: list[tuple[str, list[str]]] = []
        data_count_diffs: list[tuple[str, int, int]] = []
        exact_data_diffs: list[tuple[str, int, int, int]] = []
        logical_data_diffs: list[tuple[str, int, int, list[str], list[str]]] = []

        for schema, table in all_tables:
            if (schema, table) not in current_tables or (schema, table) not in backup_tables:
                continue

            diffs: list[str] = []
            diffs.extend(
                compare_columns(
                    get_columns(current_conn, schema, table),
                    get_columns(backup_conn, schema, table),
                )
            )
            diffs.extend(
                compare_definition_list(
                    get_constraints(current_conn, schema, table),
                    get_constraints(backup_conn, schema, table),
                    "contrainte",
                )
            )
            diffs.extend(
                compare_definition_list(
                    get_indexes(current_conn, schema, table),
                    get_indexes(backup_conn, schema, table),
                    "index",
                )
            )
            if diffs:
                structure_diffs.append((f"{schema}.{table}", diffs))

            curr_count = count_rows(current_conn, schema, table)
            bak_count = count_rows(backup_conn, schema, table)
            if curr_count != bak_count:
                data_count_diffs.append((f"{schema}.{table}", curr_count, bak_count))

            if (
                (schema, table) in DATA_EXACT_TABLES
                or (curr_count <= SMALL_TABLE_THRESHOLD and bak_count <= SMALL_TABLE_THRESHOLD)
            ):
                curr_rows = fetch_row_json_texts(current_conn, schema, table)
                bak_rows = fetch_row_json_texts(backup_conn, schema, table)
                if curr_rows != bak_rows:
                    only_curr = sum((curr_rows - bak_rows).values())
                    only_bak = sum((bak_rows - curr_rows).values())
                    exact_data_diffs.append(
                        (f"{schema}.{table}", curr_count, only_curr, only_bak)
                    )

            logical_columns = LOGICAL_COMPARE_COLUMNS.get((schema, table))
            if logical_columns:
                curr_rows = fetch_selected_row_json_texts(
                    current_conn,
                    schema,
                    table,
                    logical_columns,
                )
                bak_rows = fetch_selected_row_json_texts(
                    backup_conn,
                    schema,
                    table,
                    logical_columns,
                )
                if curr_rows != bak_rows:
                    curr_only_counter = curr_rows - bak_rows
                    bak_only_counter = bak_rows - curr_rows
                    logical_data_diffs.append(
                        (
                            f"{schema}.{table}",
                            sum(curr_only_counter.values()),
                            sum(bak_only_counter.values()),
                            list(curr_only_counter.keys())[:5],
                            list(bak_only_counter.keys())[:5],
                        )
                    )

        lines.append("## Écarts de structure")
        lines.append("")
        if not structure_diffs:
            lines.append("- Aucun écart de structure détecté sur les tables communes.")
            lines.append("")
        else:
            lines.append(f"- Tables avec écart de structure: {len(structure_diffs)}")
            lines.append("")
            for table_name, diffs in structure_diffs:
                lines.append(f"### `{table_name}`")
                for diff in diffs[:40]:
                    lines.append(f"- {diff}")
                if len(diffs) > 40:
                    lines.append(f"- +{len(diffs) - 40} autres écarts")
                lines.append("")

        lines.append("## Écarts de données")
        lines.append("")
        if not data_count_diffs and not exact_data_diffs:
            lines.append("- Aucun écart de données détecté avec les méthodes de comparaison retenues.")
            lines.append("")
        else:
            if data_count_diffs:
                lines.append("### Tables avec nombre de lignes différent")
                for table_name, curr_count, bak_count in data_count_diffs:
                    lines.append(
                        f"- `{table_name}`: current={curr_count} | backup={bak_count}"
                    )
                lines.append("")
            if exact_data_diffs:
                lines.append("### Tables avec contenu différent (comparaison exacte sur petites tables / tables clés)")
                for table_name, total_count, only_curr, only_bak in exact_data_diffs:
                    lines.append(
                        f"- `{table_name}`: total_current={total_count}, lignes seulement en current={only_curr}, lignes seulement en backup={only_bak}"
                    )
                lines.append("")
            if logical_data_diffs:
                lines.append("### Écarts métier ciblés (colonnes utiles, dates/audits exclus)")
                for table_name, only_curr, only_bak, curr_examples, bak_examples in logical_data_diffs:
                    lines.append(
                        f"- `{table_name}`: lignes métier seulement en current={only_curr}, seulement en backup={only_bak}"
                    )
                    for example in curr_examples:
                        lines.append(f"  - current only: `{example}`")
                    for example in bak_examples:
                        lines.append(f"  - backup only: `{example}`")
                lines.append("")

        report_path.write_text("\n".join(lines), encoding="utf-8")
        print(f"Report written to: {report_path}")
        print(f"Structure diffs: {len(structure_diffs)}")
        print(f"Row-count diffs: {len(data_count_diffs)}")
        print(f"Exact data diffs: {len(exact_data_diffs)}")
        return 0
    finally:
        if backup_conn is not None:
            backup_conn.close()
        if current_conn is not None:
            current_conn.close()
        try:
            terminate_and_drop_db(temp_db)
        except Exception:
            pass


if __name__ == "__main__":
    sys.exit(main())
