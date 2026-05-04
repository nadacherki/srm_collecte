# Nettoyage BD - 2026-05-01

Bases concernees:

- `SRM`
- `SRM_bureau`

## Schemas supprimes

Les schemas suivants ont ete supprimes dans les deux bases:

- `ogr_system_tables`
- `topology`
- `elec`

Les schemas suivants ont ensuite ete supprimes lorsqu'ils existaient:

- `asst_marrakech`
- `minute`

L'extension PostgreSQL `postgis_topology` a aussi ete supprimee dans les deux bases, car elle possedait/protegeait le schema `topology`.

## Impact constate

### SRM

La suppression du schema `elec` a supprime en cascade plusieurs vues `public.vw_*` qui incluaient les donnees electriques.

Les vues applicatives/metriques ont ensuite ete reconstruites avec:

- `API_GeoDjango/sql/2026-04-14_metrics_collecte_views.sql`
- `API_GeoDjango/sql/2026-04-14_metrics_dashboard_views.sql`

Etat final verifie:

- `ogr_system_tables`: absent
- `topology`: absent
- `elec`: absent
- `asst_marrakech`: absent
- `minute`: absent
- `postgis_topology`: absent
- vues metriques `public.vw_*`: presentes

### SRM_bureau

Les schemas ont ete supprimes correctement.

La reconstruction des vues metriques n'a pas ete appliquee, car `SRM_bureau` ne contient pas encore certaines tables applicatives `public` attendues, par exemple `public.objet_photo`.

Etat final verifie:

- `ogr_system_tables`: absent
- `topology`: absent
- `elec`: absent
- `asst_marrakech`: absent
- `minute`: absent
- `postgis_topology`: absent

## Remarque

Le code backend contient encore des modeles Django `managed = False` pointant vers le schema `elec`.
Ils ne bloquent pas le demarrage tant qu'ils ne sont pas interroges, mais ils devront etre retires ou ignores dans une phase de nettoyage applicatif si le metier electricite est definitivement hors perimetre.
