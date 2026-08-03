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

Write-Host 'Doctor found no Harness problems.' -ForegroundColor Green
