$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repositoryRoot 'harness.config.json'
$errors = New-Object System.Collections.Generic.List[string]

function Get-CheckedRepositoryPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $rootPrefix = $repositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
    if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    return $candidate
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Write-Error 'Missing harness.config.json.'
    exit 1
}

try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Invalid harness.config.json: $($_.Exception.Message)"
    exit 1
}

if ($config.schemaVersion -ne 1) {
    $errors.Add("Unsupported schemaVersion: $($config.schemaVersion)")
}

if ([string]::IsNullOrWhiteSpace([string]$config.harnessVersion)) {
    $errors.Add('Missing harnessVersion')
}

if ($config.profile -notin @('Light', 'Standard')) {
    $errors.Add("Unsupported profile: $($config.profile)")
}

foreach ($propertyName in @('requiredPaths', 'projectValidation', 'driftChecks')) {
    $property = $config.PSObject.Properties[$propertyName]
    if ($null -eq $property -or $null -eq $property.Value -or $property.Value -isnot [System.Array]) {
        $errors.Add("Configuration property must be an array: $propertyName")
    }
}

$readinessProperty = $config.PSObject.Properties['readiness']
if ($null -eq $readinessProperty -or $null -eq $readinessProperty.Value) {
    $errors.Add('Missing configuration object: readiness')
} else {
    $readiness = $readinessProperty.Value
    $requiredValidationProperty = $readiness.PSObject.Properties['requireProjectValidation']
    if ($null -eq $requiredValidationProperty -or $requiredValidationProperty.Value -isnot [bool]) {
        $errors.Add('readiness.requireProjectValidation must be a boolean')
    }
    $waiverProperty = $readiness.PSObject.Properties['projectValidationWaiver']
    if ($null -eq $waiverProperty -or ($null -ne $waiverProperty.Value -and $waiverProperty.Value -isnot [string])) {
        $errors.Add('readiness.projectValidationWaiver must be a string or null')
    }
}

foreach ($relativePath in $config.requiredPaths) {
    $path = Get-CheckedRepositoryPath -RelativePath ([string]$relativePath)
    if ($null -eq $path) {
        $errors.Add("Required path escapes the repository: $relativePath")
    } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Missing required path: $relativePath")
    }
}

foreach ($check in @($config.projectValidation)) {
    if ([string]::IsNullOrWhiteSpace([string]$check.name)) {
        $errors.Add('Project validation entry is missing name')
    }
    if ([string]::IsNullOrWhiteSpace([string]$check.executable)) {
        $errors.Add("Project validation entry is missing executable: $($check.name)")
    }
    if ($null -eq $check.PSObject.Properties['arguments'] -or $check.arguments -isnot [System.Array]) {
        $errors.Add("Project validation arguments must be an array: $($check.name)")
    }
}

foreach ($check in @($config.driftChecks)) {
    foreach ($propertyName in @('description', 'path', 'pattern')) {
        if ([string]::IsNullOrWhiteSpace([string]$check.$propertyName)) {
            $errors.Add("Drift check is missing $propertyName")
        }
    }
    if ($null -eq $check.PSObject.Properties['expectMatch'] -or $check.expectMatch -isnot [bool]) {
        $errors.Add("Drift check expectMatch must be a boolean: $($check.description)")
    }
    try {
        [void][regex]::new([string]$check.pattern)
    } catch {
        $errors.Add("Drift check pattern is invalid: $($check.description)")
    }
}

$skillRoots = @('.agents/skills', '.claude/skills')
foreach ($relativeSkillRoot in $skillRoots) {
    $skillRoot = Join-Path $repositoryRoot $relativeSkillRoot
    if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) {
        continue
    }

    foreach ($skillFile in Get-ChildItem -LiteralPath $skillRoot -Filter 'SKILL.md' -Recurse -File) {
        $content = Get-Content -LiteralPath $skillFile.FullName -Raw
        $relativePath = $skillFile.FullName.Substring($repositoryRoot.Length).TrimStart('\', '/')
        if ($content -notmatch '(?m)^name:\s*\S+') {
            $errors.Add("Skill is missing frontmatter name: $relativePath")
        }
        if ($content -notmatch '(?m)^description:\s*.+$') {
            $errors.Add("Skill is missing frontmatter description: $relativePath")
        }
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Host "FAIL  $message" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'PASS  Harness structure and configuration are valid.' -ForegroundColor Green
