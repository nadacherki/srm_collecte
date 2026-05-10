param(
    [switch]$SkipBackendChecks
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$FlutterRunner = Join-Path $RepoRoot "srmenv\Scripts\python.exe"

Push-Location $RepoRoot
try {
    & $FlutterRunner "tools\codex_dart_flutter.py" --cwd "PPRCollecte_Flutter" --timeout 120 dart analyze
    & $FlutterRunner "tools\codex_dart_flutter.py" --cwd "PPRCollecte_Flutter" --timeout 240 flutter test

    $skipBackend = $SkipBackendChecks -or ($env:SRM_SKIP_BACKEND_CHECKS -eq "1")
    if (-not $skipBackend) {
        & $FlutterRunner "tools\audit_mobile_config_schema_coherence.py"
        & $FlutterRunner "tools\audit_mobile_form_mapping.py"
        & $FlutterRunner "API_GeoDjango\pprcollecte\manage.py" check
    }
} finally {
    Pop-Location
}
