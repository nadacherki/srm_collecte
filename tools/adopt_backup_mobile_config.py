from __future__ import annotations

import argparse
import os
import pathlib
import subprocess
import uuid
from typing import Any

import psycopg2
from psycopg2.extras import RealDictCursor


ROOT = pathlib.Path(__file__).resolve().parents[1]
SETTINGS_ENV = ROOT / "API_GeoDjango" / "pprcollecte" / ".env"
PG_BIN = pathlib.Path(r"C:\Program Files\PostgreSQL\17\bin")
FLUTTER_FALLBACK_FILE = (
    ROOT
    / "PPRCollecte_Flutter"
    / "lib"
    / "services"
    / "formulaire_config_mobile_service.dart"
)

CONFIG_TABLES = (
    "formulaire_config_mobile",
    "attribut_config_mobile",
    "liste_choix",
)


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
        "dbname": dbname or os.environ.get("DB_NAME", "SRM_bureau"),
        "user": os.environ.get("DB_USER", "postgres"),
        "password": os.environ.get("DB_PASSWORD", "postgres"),
        "host": os.environ.get("DB_HOST", "127.0.0.1"),
        "port": os.environ.get("DB_PORT", "5432"),
    }


def connect(dbname: str | None = None):
    conn = psycopg2.connect(**db_params(dbname))
    conn.autocommit = True
    return conn


def terminate_and_drop_db(dbname: str) -> None:
    conn = connect("postgres")
    try:
        with conn.cursor() as cur:
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
    finally:
        conn.close()


def create_temp_db(dbname: str) -> None:
    conn = connect("postgres")
    try:
        with conn.cursor() as cur:
            cur.execute(f'CREATE DATABASE "{dbname}"')
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


def get_table_columns(conn, table_name: str) -> list[str]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = %s
            ORDER BY ordinal_position
            """,
            (table_name,),
        )
        return [row[0] for row in cur.fetchall()]


def fetch_table_rows(conn, table_name: str) -> list[dict[str, Any]]:
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(f'SELECT * FROM public."{table_name}" ORDER BY id')
        return [dict(row) for row in cur.fetchall()]


def build_constraint_map(conn) -> dict[tuple[str, str, str], str]:
    rows = fetch_table_rows(conn, "attribut_config_mobile")
    mapping: dict[tuple[str, str, str], str] = {}
    for row in rows:
        value = (row.get("contraintes") or "").strip()
        if not value:
            continue
        key = (
            str(row.get("nom_metier") or "").strip(),
            str(row.get("nom_table") or "").strip(),
            str(row.get("nom_champ") or "").strip(),
        )
        mapping[key] = value
    return mapping


def merge_attribut_rows(
    backup_rows: list[dict[str, Any]],
    current_constraints: dict[tuple[str, str, str], str],
) -> tuple[list[dict[str, Any]], int]:
    preserved = 0
    merged: list[dict[str, Any]] = []
    for row in backup_rows:
        new_row = dict(row)
        key = (
            str(row.get("nom_metier") or "").strip(),
            str(row.get("nom_table") or "").strip(),
            str(row.get("nom_champ") or "").strip(),
        )
        current_constraint = current_constraints.get(key, "").strip()
        if current_constraint:
            backup_constraint = str(row.get("contraintes") or "").strip()
            if backup_constraint != current_constraint:
                new_row["contraintes"] = current_constraint
                preserved += 1
        if key[0].lower() == "ep" and key[2].lower() == "ep_anomalie":
            new_row["nullable"] = False
            new_row["valeur_par_defaut"] = "Non"
        merged.append(new_row)
    return merged, preserved


def insert_rows(conn, table_name: str, columns: list[str], rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    placeholders = ", ".join(["%s"] * len(columns))
    column_sql = ", ".join(f'"{col}"' for col in columns)
    sql = f'INSERT INTO public."{table_name}" ({column_sql}) VALUES ({placeholders})'
    values = [[row.get(col) for col in columns] for row in rows]
    with conn.cursor() as cur:
        cur.executemany(sql, values)


def set_sequence_to_max_id(conn, table_name: str) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT pg_get_serial_sequence(%s, 'id')",
            (f"public.{table_name}",),
        )
        seq = cur.fetchone()[0]
        if not seq:
            return
        cur.execute(f'SELECT COALESCE(MAX(id), 1) FROM public."{table_name}"')
        max_id = cur.fetchone()[0] or 1
        cur.execute("SELECT setval(%s, %s, true)", (seq, max_id))


def replace_mobile_config_tables(
    current_conn,
    formulaire_rows: list[dict[str, Any]],
    attribut_rows: list[dict[str, Any]],
    liste_rows: list[dict[str, Any]],
) -> None:
    columns = {table: get_table_columns(current_conn, table) for table in CONFIG_TABLES}
    old_autocommit = current_conn.autocommit
    current_conn.autocommit = False
    try:
        with current_conn.cursor() as cur:
            for table in CONFIG_TABLES:
                cur.execute(f'ALTER TABLE public."{table}" DISABLE TRIGGER ALL')
            cur.execute('DELETE FROM public."liste_choix"')
            cur.execute('DELETE FROM public."attribut_config_mobile"')
            cur.execute('DELETE FROM public."formulaire_config_mobile"')
        insert_rows(current_conn, "formulaire_config_mobile", columns["formulaire_config_mobile"], formulaire_rows)
        insert_rows(current_conn, "attribut_config_mobile", columns["attribut_config_mobile"], attribut_rows)
        insert_rows(current_conn, "liste_choix", columns["liste_choix"], liste_rows)
        with current_conn.cursor() as cur:
            for table in CONFIG_TABLES:
                set_sequence_to_max_id(current_conn, table)
            for table in reversed(CONFIG_TABLES):
                cur.execute(f'ALTER TABLE public."{table}" ENABLE TRIGGER ALL')
        current_conn.commit()
    except Exception:
        current_conn.rollback()
        raise
    finally:
        current_conn.autocommit = old_autocommit


def ensure_ep_anomalie_non_choices(conn) -> int:
    inserted = 0
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            WITH ep_anom AS (
              SELECT id AS attribut_config_mobile_id,
                     nom_metier,
                     nom_table,
                     nom_champ
              FROM public.attribut_config_mobile
              WHERE lower(nom_metier) = 'ep'
                AND lower(nom_champ) = 'ep_anomalie'
            ),
            choice_status AS (
              SELECT
                  e.attribut_config_mobile_id,
                  e.nom_metier,
                  e.nom_table,
                  e.nom_champ,
                  count(*) FILTER (WHERE COALESCE(lc.liste_choix_actif, true)) AS active_count,
                  bool_or(
                      COALESCE(lc.liste_choix_actif, true)
                      AND lower(COALESCE(lc.liste_choix_valeur, '')) = 'non'
                  ) AS has_non,
                  min(lc.liste_choix_ordre) FILTER (
                      WHERE COALESCE(lc.liste_choix_actif, true)
                  ) AS min_active_order
              FROM ep_anom e
              LEFT JOIN public.liste_choix lc
                ON lc.nom_metier = e.nom_metier
               AND lc.nom_table = e.nom_table
               AND lc.nom_champ = e.nom_champ
              GROUP BY
                  e.attribut_config_mobile_id,
                  e.nom_metier,
                  e.nom_table,
                  e.nom_champ
            )
            SELECT *
            FROM choice_status
            WHERE active_count > 0
              AND NOT COALESCE(has_non, false)
            ORDER BY nom_table
            """
        )
        missing = [dict(row) for row in cur.fetchall()]

    for row in missing:
        target_order = row["min_active_order"] - 1 if row["min_active_order"] and row["min_active_order"] > 1 else 1
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO public.liste_choix (
                    attribut_config_mobile_id,
                    nom_metier,
                    nom_table,
                    nom_champ,
                    liste_choix_alias,
                    liste_choix_valeur,
                    liste_choix_ordre,
                    liste_choix_actif,
                    contraintes
                )
                VALUES (%s, %s, %s, %s, %s, %s, %s, true, NULL)
                """,
                (
                    row["attribut_config_mobile_id"],
                    row["nom_metier"],
                    row["nom_table"],
                    row["nom_champ"],
                    "Non",
                    "Non",
                    target_order,
                ),
            )
        inserted += 1
    return inserted


def enforce_ep_anomalie_not_null(conn) -> list[str]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT table_name
            FROM information_schema.columns
            WHERE table_schema = 'ep'
              AND column_name = 'ep_anomalie'
            ORDER BY table_name
            """
        )
        tables = [row[0] for row in cur.fetchall()]

    applied: list[str] = []
    for table_name in tables:
        old_autocommit = conn.autocommit
        conn.autocommit = False
        filled_non = 0
        filled_oui = 0
        try:
            with conn.cursor() as cur:
                cur.execute(f'SELECT ctid::text FROM ep."{table_name}" WHERE ep_anomalie IS NULL')
                row_ctids = [row[0] for row in cur.fetchall()]

            for ctid in row_ctids:
                with conn.cursor() as cur:
                    cur.execute("SAVEPOINT ep_anom_fill")
                    try:
                        cur.execute(
                            f'UPDATE ep."{table_name}" SET ep_anomalie = %s WHERE ctid = %s::tid',
                            ("Non", ctid),
                        )
                        filled_non += cur.rowcount
                        cur.execute("RELEASE SAVEPOINT ep_anom_fill")
                    except Exception:
                        cur.execute("ROLLBACK TO SAVEPOINT ep_anom_fill")
                        cur.execute(
                            f'UPDATE ep."{table_name}" SET ep_anomalie = %s WHERE ctid = %s::tid',
                            ("Oui", ctid),
                        )
                        filled_oui += cur.rowcount
                        cur.execute("RELEASE SAVEPOINT ep_anom_fill")

            with conn.cursor() as cur:
                cur.execute(f'ALTER TABLE ep."{table_name}" ALTER COLUMN ep_anomalie SET DEFAULT \'Non\'')
                cur.execute(f'ALTER TABLE ep."{table_name}" ALTER COLUMN ep_anomalie SET NOT NULL')
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.autocommit = old_autocommit
        applied.append(f"{table_name}(Non={filled_non},Oui={filled_oui})")
    return applied


def rewrite_formulaire_fallbacks(conn) -> None:
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT id, nom_metier, nom_table, titre_app, ordre, visible, download_mobile
            FROM public.formulaire_config_mobile
            WHERE nom_metier IN ('ep', 'asst')
            ORDER BY nom_metier, id
            """
        )
        rows = [dict(row) for row in cur.fetchall()]

    by_metier = {"ep": [], "asst": []}
    for row in rows:
        by_metier[row["nom_metier"]].append(row)

    def dart_bool(value: Any) -> str:
        return "true" if bool(value) else "false"

    def dart_string(value: str) -> str:
        parts: list[str] = []
        for ch in value:
            code = ord(ch)
            if ch == "\\":
                parts.append("\\\\")
            elif ch == "'":
                parts.append("\\'")
            elif 32 <= code <= 126:
                parts.append(ch)
            elif code <= 0xFFFF:
                parts.append(f"\\u{code:04x}")
            else:
                parts.append(f"\\u{{{code:x}}}")
        return "".join(parts)

    def render_list(var_name: str, metier_rows: list[dict[str, Any]]) -> str:
        lines = [f"  static const List<FormulaireConfigMobileItem> {var_name} = ["]
        for row in metier_rows:
            title = dart_string(str(row.get("titre_app") or ""))
            nom_metier = str(row.get("nom_metier") or "")
            nom_table = str(row.get("nom_table") or "")
            lines.extend(
                [
                    "    FormulaireConfigMobileItem(",
                    f"      id: {int(row['id'])},",
                    f"      nomMetier: '{nom_metier}',",
                    f"      nomTable: '{nom_table}',",
                    f"      titreApp: '{title}',",
                    f"      ordre: {int(row['ordre'] or 0)},",
                    f"      visible: {dart_bool(row.get('visible'))},",
                    f"      downloadMobile: {dart_bool(row.get('download_mobile'))},",
                    "      createdAt: '',",
                    "      updatedAt: '',",
                    "    ),",
                ]
            )
        lines.append("  ];")
        return "\n".join(lines)

    ep_block = render_list("_fallbackEpFormulaires", by_metier["ep"])
    asst_block = render_list("_fallbackAsstFormulaires", by_metier["asst"])

    text = FLUTTER_FALLBACK_FILE.read_text(encoding="utf-8-sig")
    ep_start = text.index("  static const List<FormulaireConfigMobileItem> _fallbackEpFormulaires = [")
    asst_start = text.index("  static const List<FormulaireConfigMobileItem> _fallbackAsstFormulaires = [")
    tail_start = text.rfind("\n}")
    if tail_start == -1:
        raise ValueError("Impossible de trouver la fin de classe dans formulaire_config_mobile_service.dart")
    new_text = text[:ep_start] + ep_block + "\n\n" + asst_block + "\n\n" + text[tail_start:]
    FLUTTER_FALLBACK_FILE.write_text(new_text, encoding="utf-8")


def refresh_ep_anomalie_config(conn) -> int:
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE public.attribut_config_mobile
               SET nullable = false,
                   valeur_par_defaut = 'Non'
             WHERE lower(nom_metier) = 'ep'
               AND lower(nom_champ) = 'ep_anomalie'
            """
        )
        return cur.rowcount


def apply_known_config_realignments(conn) -> int:
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE public.attribut_config_mobile
               SET nullable = false
             WHERE nom_metier = 'ep'
               AND nom_table = 'ep_vanne'
               AND nom_champ = 'ep_modele'
               AND COALESCE(nullable, true) = true
            """
        )
        return cur.rowcount


def run_regenerate_server_columns() -> None:
    script = ROOT / "srmenv" / "Scripts" / "python.exe"
    target = ROOT / "tools" / "regenerate_srm_server_columns.py"
    completed = subprocess.run(
        [str(script), str(target)],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError(
            "regenerate_srm_server_columns.py a echoue.\n"
            f"stdout:\n{completed.stdout}\n"
            f"stderr:\n{completed.stderr}"
        )
    if completed.stdout.strip():
        print(completed.stdout.strip())


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Adopte les tables de config mobile depuis un backup, avec conservation ciblee des contraintes actuelles."
    )
    parser.add_argument("backup", type=pathlib.Path, help="Chemin du fichier .backup source")
    args = parser.parse_args()

    backup_path = args.backup.expanduser().resolve()
    if not backup_path.exists():
        raise FileNotFoundError(f"Backup introuvable: {backup_path}")

    temp_db = f"codex_cfg_{uuid.uuid4().hex[:8]}"
    current_conn = connect()
    backup_conn = None
    try:
        print(f"[INFO] Restauration du backup temporaire {backup_path.name} ...")
        create_temp_db(temp_db)
        run_pg_restore(backup_path, temp_db)
        backup_conn = connect(temp_db)

        current_constraints = build_constraint_map(current_conn)
        formulaire_rows = fetch_table_rows(backup_conn, "formulaire_config_mobile")
        backup_attribut_rows = fetch_table_rows(backup_conn, "attribut_config_mobile")
        attribut_rows, preserved_count = merge_attribut_rows(backup_attribut_rows, current_constraints)
        liste_rows = fetch_table_rows(backup_conn, "liste_choix")

        print(
            f"[INFO] Import backup -> formulaire={len(formulaire_rows)}, "
            f"attribut={len(attribut_rows)}, liste_choix={len(liste_rows)}, "
            f"contraintes conservees={preserved_count}"
        )

        replace_mobile_config_tables(current_conn, formulaire_rows, attribut_rows, liste_rows)
        inserted_non_choices = ensure_ep_anomalie_non_choices(current_conn)
        hardened_tables = enforce_ep_anomalie_not_null(current_conn)
        updated_config_rows = refresh_ep_anomalie_config(current_conn)
        realigned_rows = apply_known_config_realignments(current_conn)
        rewrite_formulaire_fallbacks(current_conn)
        run_regenerate_server_columns()

        print(f"[OK] choix 'Non' ajoutes sur {inserted_non_choices} champ(s) ep_anomalie avec liste existante.")
        print(f"[OK] attribut_config_mobile.ep_anomalie realigne sur {updated_config_rows} ligne(s).")
        print(f"[OK] realignements config supplementaires: {realigned_rows} ligne(s).")
        print(f"[OK] ep_anomalie durci sur {len(hardened_tables)} table(s) EP: {', '.join(hardened_tables)}")
        print(f"[OK] Fallback Flutter realigne: {FLUTTER_FALLBACK_FILE.relative_to(ROOT)}")
        return 0
    finally:
        if backup_conn is not None:
            backup_conn.close()
        current_conn.close()
        try:
            terminate_and_drop_db(temp_db)
        except Exception:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
