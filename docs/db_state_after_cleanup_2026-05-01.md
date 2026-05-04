# Etat actuel des bases SRM et SRM_bureau

Date: 2026-05-01

## SRM

| Schema | Owner | Tables | Vues | Vues materialisees | Sequences | Foreign tables |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| ass | postgres | 9 | 0 | 0 | 9 | 0 |
| ep | postgres | 29 | 0 | 0 | 29 | 0 |
| public | pg_database_owner | 31 | 20 | 0 | 28 | 0 |

Extensions:

- `pgcrypto` 1.3
- `plpgsql` 1.0
- `postgis` 3.6.1

## SRM_bureau

| Schema | Owner | Tables | Vues | Vues materialisees | Sequences | Foreign tables |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| asst | postgres | 26 | 0 | 0 | 26 | 0 |
| ep | postgres | 31 | 0 | 0 | 31 | 0 |
| public | pg_database_owner | 31 | 2 | 0 | 19 | 0 |

Extensions:

- `dblink` 1.2
- `pgcrypto` 1.3
- `plpgsql` 1.0
- `postgis` 3.6.1
- `uuid-ossp` 1.1

## Comparaison

Schemas communs: `ep`, `public`

Uniquement dans SRM: `ass`

Uniquement dans SRM_bureau: `asst`
