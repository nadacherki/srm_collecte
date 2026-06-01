param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl,

    [string]$CleartextAllowedHosts = "",

    [string]$OutputName = "",

    [int]$TimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$FlutterRunner = Join-Path $RepoRoot "srmenv\Scripts\python.exe"
$ReleasesDir = Join-Path $RepoRoot "PPRCollecte_Flutter\releases"
$ReleaseApk = Join-Path $RepoRoot "PPRCollecte_Flutter\build\app\outputs\flutter-apk\app-release.apk"

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    throw "ApiBaseUrl est obligatoire pour eviter un APK release qui demarre en ecran noir."
}

$uri = $null
if (-not [System.Uri]::TryCreate($ApiBaseUrl, [System.UriKind]::Absolute, [ref]$uri)) {
    throw "ApiBaseUrl invalide: $ApiBaseUrl"
}

if ($uri.Host -in @("10.0.2.2", "localhost", "127.0.0.1")) {
    throw "ApiBaseUrl pointe vers un host de dev/emulateur interdit en release: $ApiBaseUrl"
}

if ($uri.Scheme -ne "https" -and [string]::IsNullOrWhiteSpace($CleartextAllowedHosts)) {
    throw "Backend HTTP detecte. Fournir -CleartextAllowedHosts $($uri.Host) si cette exception est voulue."
}

if ([string]::IsNullOrWhiteSpace($OutputName)) {
    $stamp = Get-Date -Format "yyyy-MM-dd-HHmm"
    $safeHost = $uri.Host.Replace(":", "-")
    $OutputName = "$stamp-$safeHost-release.apk"
}

New-Item -ItemType Directory -Force -Path $ReleasesDir | Out-Null

Push-Location $RepoRoot
try {
    $flutterArgs = @(
        "tools\codex_dart_flutter.py",
        "--cwd", "PPRCollecte_Flutter",
        "--timeout", "$TimeoutSeconds",
        "flutter", "build", "apk", "--release",
        "--dart-define=API_BASE_URL=$ApiBaseUrl"
    )

    if (-not [string]::IsNullOrWhiteSpace($CleartextAllowedHosts)) {
        $flutterArgs += "--dart-define=CLEARTEXT_ALLOWED_HOSTS=$CleartextAllowedHosts"
    }

    & $FlutterRunner @flutterArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Build Flutter release echoue avec le code $LASTEXITCODE. APK non copie."
    }

    if (-not (Test-Path -LiteralPath $ReleaseApk)) {
        throw "APK release introuvable apres build: $ReleaseApk"
    }

    $destination = Join-Path $ReleasesDir $OutputName
    Copy-Item -LiteralPath $ReleaseApk -Destination $destination -Force
    Get-Item -LiteralPath $destination | Format-List FullName,Length,LastWriteTime
} finally {
    Pop-Location
}
