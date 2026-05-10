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
        $AuditTempDir = Join-Path ([System.IO.Path]::GetTempPath()) "srm_mobile_release_checks"
        New-Item -ItemType Directory -Force -Path $AuditTempDir | Out-Null
        $SchemaReport = Join-Path $AuditTempDir "mobile_config_schema_coherence_audit.md"
        $SchemaJson = Join-Path $AuditTempDir "mobile_config_schema_coherence_audit.json"

        & $FlutterRunner "tools\audit_mobile_config_schema_coherence.py" --report $SchemaReport --json $SchemaJson
        & $FlutterRunner "tools\audit_mobile_form_mapping.py"
        & $FlutterRunner "API_GeoDjango\pprcollecte\manage.py" check
    }
} finally {
    Pop-Location
}
