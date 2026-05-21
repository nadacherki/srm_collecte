# Mobile Config Schema Coherence Audit

- Generated at: `2026-05-20T21:56:12`
- Schemas: `ep, asst`

## Summary

- `form_tables`: 61
- `physical_tables_checked`: 61
- `attributes_checked`: 2864
- `choices_checked`: 928
- `missing_physical_tables`: 0
- `type_mismatches`: 0
- `nullable_mismatches`: 3
- `attributes_without_physical_column`: 0
- `physical_columns_without_attribute`: 0
- `choices_without_attribute`: 0
- `choices_without_physical_column`: 0
- `choice_attribute_link_mismatches`: 0
- `choice_default_mismatches`: 0

## missing_physical_tables

OK

## type_mismatches

OK

## nullable_mismatches

| attribute_id | column | configured_nullable | physical_not_null | schema | table |
| --- | --- | --- | --- | --- | --- |
| 1473 | ep_agent | False | False | ep | ep_regard_point |
| 3093 | generatrice_supp | False | False | ep | ep_regard_point |
| 3098 | retour_terrain | False | False | ep | ep_regard_point |

## attributes_without_physical_column

OK

## physical_columns_without_attribute

OK

## choices_without_attribute

OK

## choices_without_physical_column

OK

## choice_attribute_link_mismatches

OK

## choice_default_mismatches

OK
