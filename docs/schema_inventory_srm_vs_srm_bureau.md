# Inventaire des schemas PostgreSQL - SRM vs SRM_bureau

Date: 2026-05-01

## Contexte

La configuration locale Django charge `API_GeoDjango/pprcollecte/.env`.
La base actuellement configuree pour le projet est `SRM`.
La base cible a homogeniser est `SRM_bureau`.

Requete utilisee en lecture seule sur chaque base:

```sql
SELECT
    n.nspname AS schema_name,
    pg_catalog.pg_get_userbyid(n.nspowner) AS owner,
    COUNT(c.oid) FILTER (WHERE c.relkind IN ('r','p')) AS tables,
    COUNT(c.oid) FILTER (WHERE c.relkind = 'v') AS views,
    COUNT(c.oid) FILTER (WHERE c.relkind = 'm') AS matviews,
    COUNT(c.oid) FILTER (WHERE c.relkind = 'S') AS sequences,
    COUNT(c.oid) FILTER (WHERE c.relkind = 'f') AS foreign_tables
FROM pg_namespace n
LEFT JOIN pg_class c ON c.relnamespace = n.oid
GROUP BY n.nspname, n.nspowner
ORDER BY
    CASE WHEN n.nspname LIKE 'pg_%' OR n.nspname = 'information_schema' THEN 1 ELSE 0 END,
    n.nspname;
```

## Schemas applicatifs / metier

Les schemas systeme PostgreSQL (`pg_%`, `pg_toast%`, `information_schema`) sont exclus de cette synthese.

| Schema | SRM | SRM_bureau | Observation |
| --- | ---: | ---: | --- |
| ass | 9 tables, 9 sequences | absent | Present uniquement dans `SRM` |
| asst | absent | 26 tables, 26 sequences | Present uniquement dans `SRM_bureau`; probable equivalent/cible de `ass` |
| asst_marrakech | absent | 10 tables, 10 sequences | Present uniquement dans `SRM_bureau` |
| elec | 11 tables, 11 sequences | 11 tables, 11 sequences | Commun |
| ep | 29 tables, 29 sequences | 31 tables, 31 sequences | Commun, mais volume structurel different |
| minute | absent | 16 tables, 16 sequences | Present uniquement dans `SRM_bureau` |
| ogr_system_tables | 1 table, 1 sequence | 1 table, 1 sequence | Commun, probablement technique/import OGR |
| public | 31 tables, 20 views, 28 sequences | 31 tables, 2 views, 19 sequences | Commun, mais vues/sequences differentes |
| topology | 2 tables, 1 sequence | 2 tables, 1 sequence | Commun, extension PostGIS Topology |

## Schemas communs

- `elec`
- `ep`
- `ogr_system_tables`
- `public`
- `topology`

## Presents uniquement dans SRM

- `ass`

## Presents uniquement dans SRM_bureau

- `asst`
- `asst_marrakech`
- `minute`

## Point d'attention

Le schema `ass` de `SRM` et le schema `asst` de `SRM_bureau` semblent etre le premier ecart a clarifier: soit il s'agit d'un renommage metier, soit de deux structures differentes. Avant toute modification, il faudra comparer les tables et colonnes de ces deux schemas.
