param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$Branch = "main",

    [string]$RequiredCheck = "Flutter analyze and tests",

    [switch]$EnforceAdmins
)

$ErrorActionPreference = "Stop"

$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    $fallback = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $fallback) {
        $ghPath = $fallback
    } else {
        throw "GitHub CLI introuvable. Installez GitHub.cli puis relancez."
    }
} else {
    $ghPath = $gh.Source
}

$proxyVars = @(
    "HTTP_PROXY",
    "HTTPS_PROXY",
    "ALL_PROXY",
    "NO_PROXY",
    "http_proxy",
    "https_proxy",
    "all_proxy",
    "no_proxy"
)
foreach ($name in $proxyVars) {
    Remove-Item "Env:$name" -ErrorAction SilentlyContinue
}

$repoInfo = & $ghPath repo view $Repo --json nameWithOwner,viewerPermission,defaultBranchRef | ConvertFrom-Json
Write-Host "Repo: $($repoInfo.nameWithOwner)"
Write-Host "Permission: $($repoInfo.viewerPermission)"
Write-Host "Default branch: $($repoInfo.defaultBranchRef.name)"

if ($repoInfo.viewerPermission -ne "ADMIN" -and $repoInfo.viewerPermission -ne "MAINTAIN") {
    throw "Protection non appliquee: le compte gh courant doit avoir ADMIN ou MAINTAIN sur $Repo."
}

$body = @{
    required_status_checks = @{
        strict = $true
        contexts = @($RequiredCheck)
    }
    enforce_admins = [bool]$EnforceAdmins
    required_pull_request_reviews = $null
    restrictions = $null
} | ConvertTo-Json -Depth 5

$body | & $ghPath api --method PUT "repos/$Repo/branches/$Branch/protection" --input - | Out-Null
Write-Host "Protection appliquee sur $Repo/$Branch avec check requis: $RequiredCheck"
