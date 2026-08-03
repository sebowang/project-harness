$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$config = Get-Content -LiteralPath (Join-Path $repositoryRoot 'harness.config.json') -Raw | ConvertFrom-Json
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

foreach ($relativePath in $config.requiredPaths) {
    $path = Get-CheckedRepositoryPath -RelativePath ([string]$relativePath)
    if ($null -eq $path) {
        continue
    }
    if ((Test-Path -LiteralPath $path -PathType Leaf) -and ([IO.Path]::GetExtension($path) -in @('.md', '.json'))) {
        $content = Get-Content -LiteralPath $path -Raw
        if ($content -match '\{\{[A-Z0-9_]+\}\}') {
            $errors.Add("Unresolved template placeholder: $relativePath")
        }
    }
}

foreach ($check in @($config.driftChecks)) {
    $path = Get-CheckedRepositoryPath -RelativePath ([string]$check.path)
    if ($null -eq $path) {
        $errors.Add("Drift check path escapes the repository: $($check.path)")
        continue
    } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
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
