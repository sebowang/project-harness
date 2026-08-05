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
$requiredKindsProperty = $config.readiness.PSObject.Properties['requiredValidationKinds']
$requiredKinds = @()
if ($null -ne $requiredKindsProperty) {
    $requiredKinds = @($requiredKindsProperty.Value | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
$configuredKinds = @($checks | ForEach-Object {
    $kindProperty = $_.PSObject.Properties['kind']
    if ($null -eq $kindProperty -or [string]::IsNullOrWhiteSpace([string]$kindProperty.Value)) { 'custom' } else { [string]$kindProperty.Value }
})

if ($checks.Count -eq 0 -and $requiresProjectValidation) {
    if ([string]::IsNullOrWhiteSpace($waiver)) {
        $errors.Add('No project validation commands are configured and no readiness waiver is recorded.')
    } else {
        $warnings.Add("Project validation waiver: $waiver")
    }
}

$missingKinds = @($requiredKinds | Where-Object { $_ -notin $configuredKinds })
if ($missingKinds.Count -gt 0) {
    $message = "Missing required project validation evidence: $($missingKinds -join ', ')"
    if ([string]::IsNullOrWhiteSpace($waiver)) {
        $errors.Add("$message. Record a specific readiness.projectValidationWaiver until these checks are executable.")
    } else {
        $warnings.Add("$message. Project validation waiver: $waiver")
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
    Write-Host 'PASS  Project Harness is ready with a documented waiver; required evidence is not fully available.' -ForegroundColor Green
} else {
    Write-Host 'PASS  Project Harness readiness requirements are satisfied.' -ForegroundColor Green
}
