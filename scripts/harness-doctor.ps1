$ErrorActionPreference = 'Stop'

$hasFailure = $false

foreach ($scriptName in @('check-harness.ps1', 'harness-status.ps1', 'check-readiness.ps1')) {
    Write-Host "== $scriptName =="
    & (Join-Path $PSScriptRoot $scriptName)
    if (-not $?) {
        $hasFailure = $true
    }
    Write-Host ''
}

if ($hasFailure) {
    Write-Host 'Doctor found incomplete or invalid Harness state.' -ForegroundColor Red
    exit 1
}

$hookInstaller = Join-Path $PSScriptRoot 'install-git-hooks.ps1'
if (Test-Path -LiteralPath $hookInstaller -PathType Leaf) {
    $git = Get-Command git -ErrorAction SilentlyContinue
    $hooksPath = $null
    if ($null -ne $git) {
        $hooksPath = (& $git.Source -C (Split-Path -Parent $PSScriptRoot) config --local --get core.hooksPath 2>$null)
    }
    $normalizedHooksPath = if ($null -eq $hooksPath) { '' } else { ([string]$hooksPath).Replace('\', '/') }
    if ($normalizedHooksPath -eq '.githooks') {
        Write-Host 'Git catalog Hook: enabled (.githooks).' -ForegroundColor Green
    } else {
        Write-Host 'Git catalog Hook: not enabled (optional). Run scripts/install-git-hooks.ps1 after review.' -ForegroundColor Yellow
    }
}

Write-Host 'Doctor found no Harness problems.' -ForegroundColor Green
