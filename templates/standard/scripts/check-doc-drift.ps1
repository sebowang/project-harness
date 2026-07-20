$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$config = Get-Content -LiteralPath (Join-Path $repositoryRoot 'harness.config.json') -Raw | ConvertFrom-Json
$errors = New-Object System.Collections.Generic.List[string]

foreach ($relativePath in $config.requiredPaths) {
    $path = Join-Path $repositoryRoot $relativePath
    if ((Test-Path -LiteralPath $path -PathType Leaf) -and ([IO.Path]::GetExtension($path) -in @('.md', '.json'))) {
        $content = Get-Content -LiteralPath $path -Raw
        if ($content -match '\{\{[A-Z0-9_]+\}\}') {
            $errors.Add("Unresolved template placeholder: $relativePath")
        }
    }
}

foreach ($check in @($config.driftChecks)) {
    $path = Join-Path $repositoryRoot ([string]$check.path)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Drift check path does not exist: $($check.path)")
        continue
    }

    $content = Get-Content -LiteralPath $path -Raw
    $matched = $content -match ([string]$check.pattern)
    $expectMatch = [bool]$check.expectMatch
    if ($matched -ne $expectMatch) {
        $errors.Add("Drift check failed: $($check.description) [$($check.path)]")
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Host "FAIL  $message" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'PASS  Configured document drift checks passed.' -ForegroundColor Green
