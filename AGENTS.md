# Global Codex Instructions

## Dart/Flutter Commands On Windows

- For this workspace, do not invoke `dart` or `flutter` directly from Codex shell commands.
- Use the safe wrapper instead: `C:\Users\AnasDahou\Desktop\srm_collecte\srmenv\Scripts\python.exe tools\codex_dart_flutter.py --cwd PPRCollecte_Flutter --timeout 30 dart ...` or `... flutter ...`.
- The wrapper normalizes duplicated `Path`/`PATH`, disables Dart/Flutter analytics, sets non-interactive flags, and kills the process tree on timeout.
- Run Dart/Flutter commands one at a time, never in parallel.
- Run Flutter commands with escalated sandbox permissions, because Flutter touches SDK cache/AppData outside the workspace even for `flutter analyze`.
- If a Dart/Flutter command is interrupted, inspect and stop stale `dart`, `dartvm`, or `flutter` processes before retrying.

## EP/ASST Mobile Config Governance

- Do not change the physical structure of schemas `ep` or `asst` for mobile form behavior unless the user explicitly approves a physical server schema change.
- Mobile form changes must pass through `public.formulaire_config_mobile`, `public.attribut_config_mobile`, and `public.liste_choix` as needed.
- For visibility, order, labels, required flags, choices, field details, and mobile download behavior, update config tables and fallbacks instead of `ALTER TABLE ep.*` or `ALTER TABLE asst.*`.
- Physical EP/ASST changes driven by `public.attribut_config_mobile` are allowed only through the safe-auto PostgreSQL trigger, which applies no-loss operations and blocks risky ones.
- If a physical EP/ASST schema change is explicitly approved, update `attribut_config_mobile`, `liste_choix` when needed, and mobile fallbacks in the same change.
- Before final delivery after any EP/ASST mobile config work, run:
  - `srmenv\Scripts\python.exe tools\audit_mobile_config_schema_coherence.py`
  - `srmenv\Scripts\python.exe tools\audit_mobile_form_mapping.py`
