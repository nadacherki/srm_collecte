"""Regenere PPRCollecte_Flutter/lib/core/config/srm_server_columns.dart.

Source de verite : table public.attribut_config_mobile + schema Postgres.
Pour chaque entite Flutter (lib/core/config/srm_config.dart), on ajoute la
liste des colonnes physiques Postgres absentes des `fields` formulaire et de
la liste `_fixedSrmColumns` du DatabaseHelper. Ces colonnes seront creees
en SQLite local pour absorber le payload serveur sans ALTER TABLE a posteriori.

Usage :
    python tools/regenerate_srm_server_columns.py

Necessite : DJANGO_SETTINGS_MODULE=pprcollecte.settings et acces Postgres.
"""

from __future__ import annotations

import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'pprcollecte.settings')
sys.path.insert(0, str(REPO / 'API_GeoDjango' / 'pprcollecte'))

import django  # noqa: E402

django.setup()
from django.db import connection  # noqa: E402


SKIP_FIXED = {
    'id', 'fid', 'uuid', 'id_agent_crea', 'id_planche', 'id_commune',
    'latitude_gps', 'longitude_gps', 'altitude_gps', 'altitude_z_moy',
    'x_debut', 'y_debut', 'x_fin', 'y_fin',
    'lat_debut', 'lon_debut', 'lat_fin', 'lon_fin',
    'nb_points', 'distance_m', 'points_json',
    'anomalie', 'type_anomalie',
    'photo_1', 'photo_2', 'photo_3', 'photo_4',
    'mode_localisation', 'downloaded', 'synced',
    'date_collecte', 'date_sync', 'objet_incomplet',
}
SKIP_BINARY = {'geom'}

PG_TO_SQLITE = {
    'integer': 'INTEGER', 'bigint': 'INTEGER', 'smallint': 'INTEGER',
    'boolean': 'INTEGER',
    'character varying': 'TEXT', 'character': 'TEXT', 'text': 'TEXT',
    'date': 'TEXT', 'timestamp without time zone': 'TEXT',
    'timestamp with time zone': 'TEXT',
    'time without time zone': 'TEXT', 'time with time zone': 'TEXT',
    'double precision': 'REAL', 'real': 'REAL', 'numeric': 'REAL',
    'uuid': 'TEXT', 'json': 'TEXT', 'jsonb': 'TEXT',
}

MOBILE_OUTPUT_ALIASES = {
    'ep_ref_rue': 'ref_rue',
    'ep_observation': 'observation',
    'ep_conf_plan': 'conformite_plan',
    'ASS_CONF_PLAN': 'conformite_plan',
    'ASS_OBSERV': 'observation',
    'ASS_DATE_INTERV': 'date_leve',
    'ASS_COOR_X': 'ass_coor_x',
    'ASS_COOR_Y': 'ass_coor_y',
    'ASS_COOR_Z': 'ass_coor_z',
    'ASS_TYPE_RESEAU': 'typereseau',
    'ASS_STATUT': 'etat',
    'ASS_DIAM': 'diametre',
    'ASS_MAT': 'nature',
    'ASS_LONG_R': 'longueur',
}


def main() -> int:
    sync_text = (REPO / 'PPRCollecte_Flutter' / 'lib' / 'services' /
                 'sync_service.dart').read_text(encoding='utf-8-sig')
    m = re.search(r"endpointMap = <String, String>\{(.+?)\};", sync_text, re.S)
    flutter_to_endpoint = {}
    if m:
        for k, v in re.findall(r"'([^']+)':\s*'([^']+)'", m.group(1)):
            flutter_to_endpoint[k] = v

    views_text = (REPO / 'API_GeoDjango' / 'pprcollecte' / 'api' /
                  'views.py').read_text(encoding='utf-8-sig')
    m = re.search(r"MOBILE_SRM_TABLE_ENDPOINTS = \{(.+?)^\}",
                  views_text, re.S | re.M)
    endpoint_to_db = {}
    for line in (m.group(1).splitlines() if m else []):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        m2 = re.match(r"'([^']+)':\s*\(\s*'([^']+)',\s*'([^']+)'", line)
        if m2:
            endpoint_to_db[m2.group(1)] = (m2.group(2), m2.group(3))

    cfg_text = (REPO / 'PPRCollecte_Flutter' / 'lib' / 'core' / 'config' /
                'srm_config.dart').read_text(encoding='utf-8-sig')
    ent_blocks = re.findall(
        r'"tableName":\s*"([^"]+)",\s*"schema":\s*"([^"]+)"'
        r'(?:[^{}]|\{[^{}]*\})*?"fields":\s*\[([^\]]*)\]',
        cfg_text, re.S,
    )

    flutter_entities = []
    for table, schema, fields_block in ent_blocks:
        fields = re.findall(r'"([^"]+)"', fields_block)
        flutter_entities.append({
            'table': table, 'schema': schema, 'fields': fields,
        })

    mapping = {}
    for fl_path, ep in flutter_to_endpoint.items():
        db = endpoint_to_db.get(ep)
        if db:
            mapping[fl_path] = db

    out = defaultdict(list)
    cur = connection.cursor()
    for ent in flutter_entities:
        key = f"{ent['schema']}/{ent['table']}"
        db = mapping.get(key, (ent['schema'], ent['table']))
        schema_db, table_db = db
        cur.execute(
            """
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE lower(table_schema) = %s AND lower(table_name) = %s
            ORDER BY ordinal_position
            """,
            [schema_db.lower(), table_db.lower()],
        )
        rows = cur.fetchall()
        if not rows:
            continue
        physical_types = {
            str(col).lower(): PG_TO_SQLITE.get(dtype, 'TEXT')
            for col, dtype in rows
        }
        fields_lower = {f.lower() for f in ent['fields']}
        added_lower = set()
        for col, dtype in rows:
            cl = col.lower()
            if cl in fields_lower or cl in SKIP_FIXED or cl in SKIP_BINARY:
                continue
            sqlite_type = PG_TO_SQLITE.get(dtype, 'TEXT')
            out[ent['table']].append((cl, sqlite_type))
            added_lower.add(cl)

        local_lower = fields_lower | added_lower
        for source, target in MOBILE_OUTPUT_ALIASES.items():
            source_lower = source.lower()
            target_lower = target.lower()
            if source_lower not in local_lower:
                continue
            if target_lower in local_lower:
                continue
            if target_lower in SKIP_FIXED or target_lower in SKIP_BINARY:
                continue
            sqlite_type = physical_types.get(source_lower, 'TEXT')
            out[ent['table']].append((target_lower, sqlite_type))
            local_lower.add(target_lower)

    lines = [
        '// AUTO-GENERATED depuis public.attribut_config_mobile.',
        '// Pour regenerer : tools/regenerate_srm_server_columns.py',
        '// Ne pas editer a la main.',
        '',
        '/// Colonnes additionnelles que le serveur expose pour chaque table mobile,',
        '/// au-dela de SrmConfig.getFields(). Utilisees pour creer la table SQLite',
        '/// locale avec toutes les colonnes attendues du payload serveur, evitant',
        '/// les ALTER TABLE a posteriori.',
        'const Map<String, Map<String, String>> srmServerColumnsByTable = {',
    ]
    for table, cols in sorted(out.items()):
        lines.append(f"  '{table}': {{")
        for col, sqlite_type in cols:
            lines.append(f"    '{col}': '{sqlite_type}',")
        lines.append('  },')
    lines.append('};')
    lines.append('')

    target = (REPO / 'PPRCollecte_Flutter' / 'lib' / 'core' / 'config' /
              'srm_server_columns.dart')
    target.write_text('\n'.join(lines), encoding='utf-8')
    total_cols = sum(len(v) for v in out.values())
    print(f'Wrote {target.relative_to(REPO)} : {len(out)} tables, {total_cols} cols')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
