$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repositoryRoot 'harness.config.json'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

foreach ($relativePath in @($config.requiredPaths)) {
    $path = Join-Path $repositoryRoot ([string]$relativePath)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        continue
    }

    if ([IO.Path]::GetExtension($path) -eq '.md') {
        $content = Get-Content -LiteralPath $path -Raw
        if ($content -match 'TODO\(HARNESS\)') {
            $errors.Add("Unresolved TODO(HARNESS): $relativePath")
        }
    }
}

$checks = @($config.projectValidation)
$requiresProjectValidation = [bool]$config.readiness.requireProjectValidation
$waiver = [string]$config.readiness.projectValidationWaiver

if ($checks.Count -eq 0 -and $requiresProjectValidation) {
    if ([string]::IsNullOrWhiteSpace($waiver)) {
        $errors.Add('No project validation commands are configured and no readiness waiver is recorded.')
    } else {
        $warnings.Add("Project validation waiver: $waiver")
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Host "FAIL  $message" -ForegroundColor Red
    }
    exit 1
}

foreach ($message in $warnings) {
    Write-Host "WARN  $message" -ForegroundColor Yellow
}

if ($warnings.Count -gt 0) {
    Write-Host 'PASS  Project Harness is ready with a documented waiver.' -ForegroundColor Green
} else {
    Write-Host 'PASS  Project Harness readiness requirements are satisfied.' -ForegroundColor Green
}
