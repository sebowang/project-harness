[CmdletBinding()]
param(
    [switch]$Staged
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$errors = New-Object System.Collections.Generic.List[string]
$git = $null
$stagedPaths = @()

function Get-GitCommand {
    if ($null -eq $script:git) {
        $script:git = Get-Command git -ErrorAction SilentlyContinue
        if ($null -eq $script:git) {
            throw 'Git is required for staged document drift checks.'
        }
    }
    return $script:git
}

function Get-CheckedContent {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    if (-not $Staged) {
        $path = Join-Path $repositoryRoot $RelativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            return $null
        }
        return Get-Content -LiteralPath $path -Raw
    }

    $gitCommand = Get-GitCommand
    $content = & $gitCommand.Source -C $repositoryRoot show (':' + $RelativePath) 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return [string]::Join("`n", @($content))
}

function Get-StagedPaths {
    $gitCommand = Get-GitCommand
    $output = & $gitCommand.Source -C $repositoryRoot diff --cached --name-only --diff-filter=ACMR
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read staged Git paths.'
    }
    return @($output | ForEach-Object { ([string]$_).Replace('\', '/') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-CheckedRepositoryPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $rootPrefix = $repositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
    if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    return $candidate
}

$configContent = Get-CheckedContent -RelativePath 'harness.config.json'
if ([string]::IsNullOrWhiteSpace($configContent)) {
    if ($Staged) {
        throw 'Missing staged harness.config.json.'
    }
    throw 'Missing harness.config.json.'
}

try {
    $config = $configContent | ConvertFrom-Json
} catch {
    throw "Invalid harness.config.json: $($_.Exception.Message)"
}

$driftChecks = @($config.driftChecks)
if ($Staged) {
    $stagedPaths = @(Get-StagedPaths)
    $fixedPaths = @('harness.config.json', 'scripts/check-doc-drift.ps1')
    $relevantPaths = @($fixedPaths) + @($driftChecks | ForEach-Object { ([string]$_.path).Replace('\', '/') })
    if (-not @($stagedPaths | Where-Object { $_ -in $relevantPaths })) {
        Write-Host 'SKIP  No staged paths affect document drift checks.'
        exit 0
    }
}

foreach ($relativePath in $config.requiredPaths) {
    if ($Staged -and ([string]$relativePath).Replace('\', '/') -notin $stagedPaths) {
        continue
    }
    $resolvedPath = Get-CheckedRepositoryPath -RelativePath ([string]$relativePath)
    if ($null -eq $resolvedPath) {
        continue
    }
    if ([IO.Path]::GetExtension($resolvedPath) -in @('.md', '.json')) {
        $content = Get-CheckedContent -RelativePath ([string]$relativePath)
        if ($null -eq $content) {
            continue
        }
        if ($content -match '\{\{[A-Z0-9_]+\}\}') {
            $errors.Add("Unresolved template placeholder: $relativePath")
        }
    }
}

foreach ($check in $driftChecks) {
    $path = Get-CheckedRepositoryPath -RelativePath ([string]$check.path)
    if ($null -eq $path) {
        $errors.Add("Drift check path escapes the repository: $($check.path)")
        continue
    }

    $content = Get-CheckedContent -RelativePath ([string]$check.path)
    if ($null -eq $content) {
        $scope = if ($Staged) { 'staged ' } else { '' }
        $errors.Add("Drift check path does not exist: $scope$($check.path)")
        continue
    }

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
