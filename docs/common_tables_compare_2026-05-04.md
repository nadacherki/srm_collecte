# Comparaison tables communes SRM vs SRM_bureau - 2026-05-04

- Tables communes: 9
- Tables uniquement SRM: 61
- Tables uniquement SRM_bureau: 67
- Mismatches structure: 5
- Mismatches contenu: 5

## Tables communes

| Schema | Table | Structure | Contenu | SRM rows | SRM_bureau rows |
|---|---|---:|---:|---:|---:|
| `ep` | `borne_onep` | MISMATCH | MISMATCH | 2 | 0 |
| `ep` | `centre_tampon` | MISMATCH | MISMATCH | 946 | 0 |
| `public` | `commune` | MISMATCH | MISMATCH | 11 | 1505 |
| `public` | `objet_incomplet` | OK | OK | 0 | 0 |
| `public` | `objet_incomplet_backup_before_common_structure_20260501` | MISMATCH | OK | 0 | 0 |
| `public` | `spatial_ref_sys` | OK | OK | 8500 | 8500 |
| `public` | `utilisateur` | MISMATCH | MISMATCH | 11 | 11 |
| `public` | `zone` | OK | OK | 21 | 21 |
| `public` | `zone_utilisateur` | OK | MISMATCH | 23 | 23 |

## Mismatches structure

- `ep.borne_onep`
- `ep.centre_tampon`
- `public.commune`
- `public.objet_incomplet_backup_before_common_structure_20260501`
- `public.utilisateur`

## Mismatches contenu

- `ep.borne_onep`: SRM rows=2, SRM_bureau rows=0
- `ep.centre_tampon`: SRM rows=946, SRM_bureau rows=0
- `public.commune`: SRM rows=11, SRM_bureau rows=1505
- `public.utilisateur`: SRM rows=11, SRM_bureau rows=11
- `public.zone_utilisateur`: SRM rows=23, SRM_bureau rows=23
