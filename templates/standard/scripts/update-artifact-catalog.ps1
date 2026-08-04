[CmdletBinding()]
param(
    [switch]$Check,
    [switch]$Staged
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repositoryRoot 'harness.config.json'
$beginMarker = '<!-- PROJECT-HARNESS:CATALOG:BEGIN -->'
$endMarker = '<!-- PROJECT-HARNESS:CATALOG:END -->'

function Get-CheckedRepositoryPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $rootPrefix = $repositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
    if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Artifact catalog path escapes the repository: $RelativePath"
    }
    return $candidate
}

function Get-NormalizedRelativePath {
    param([Parameter(Mandatory = $true)][string]$FullPath)

    return $FullPath.Substring($repositoryRoot.Length).TrimStart('\', '/').Replace('\', '/')
}

function Get-StagedPaths {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($null -eq $git) {
        throw 'Git is required for staged artifact catalog checks.'
    }

    $output = & $git.Source -C $repositoryRoot diff --cached --name-only --diff-filter=ACMR
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read staged Git paths.'
    }
    return @($output | ForEach-Object { ([string]$_).Replace('\', '/') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Test-StagedCheckRelevant {
    param(
        [Parameter(Mandatory = $true)][object[]]$Catalogs,
        [Parameter(Mandatory = $true)][string[]]$ChangedPaths
    )

    $fixedPaths = @(
        'harness.config.json',
        'scripts/check-artifact-catalog.ps1',
        'scripts/update-artifact-catalog.ps1'
    )
    foreach ($changedPath in $ChangedPaths) {
        if ($changedPath -in $fixedPaths) {
            return $true
        }
        foreach ($catalog in $Catalogs) {
            $directory = ([string]$catalog.directory).TrimEnd('/', '\').Replace('\', '/')
            $indexPath = ([string]$catalog.indexPath).Replace('\', '/')
            if ($changedPath -eq $indexPath -or $changedPath.StartsWith($directory + '/', [StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
    }
    return $false
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw 'Missing harness.config.json.'
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$catalogProperty = $config.PSObject.Properties['artifactCatalogs']
if ($null -eq $catalogProperty -or $catalogProperty.Value -isnot [System.Array]) {
    if ($null -eq $catalogProperty) {
        Write-Host 'SKIP  No artifactCatalogs are configured.'
        exit 0
    }
    throw 'Configuration property must be an array: artifactCatalogs'
}
$catalogs = @($catalogProperty.Value)

if ($Staged) {
    $stagedPaths = @(Get-StagedPaths)
    if (-not (Test-StagedCheckRelevant -Catalogs $catalogs -ChangedPaths $stagedPaths)) {
        Write-Host 'SKIP  No staged paths affect artifact catalogs.'
        exit 0
    }
}

$hasDifference = $false
foreach ($catalog in $catalogs) {
    foreach ($propertyName in @('name', 'directory', 'include', 'indexPath')) {
        if ([string]::IsNullOrWhiteSpace([string]$catalog.$propertyName)) {
            throw "Artifact catalog is missing $propertyName."
        }
    }

    $include = [string]$catalog.include
    if ($include.IndexOfAny(@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) -ge 0) {
        throw "Artifact catalog include must be a file-name pattern: $include"
    }

    $directoryPath = Get-CheckedRepositoryPath -RelativePath ([string]$catalog.directory)
    $indexPath = Get-CheckedRepositoryPath -RelativePath ([string]$catalog.indexPath)
    if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
        throw "Artifact catalog directory does not exist: $($catalog.directory)"
    }
    if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
        throw "Artifact catalog index does not exist: $($catalog.indexPath)"
    }

    $content = [IO.File]::ReadAllText($indexPath)
    $beginCount = ([regex]::Matches($content, [regex]::Escape($beginMarker))).Count
    $endCount = ([regex]::Matches($content, [regex]::Escape($endMarker))).Count
    if ($beginCount -ne 1 -or $endCount -ne 1) {
        throw "Artifact catalog index must contain exactly one complete managed block: $($catalog.indexPath)"
    }

    $beginIndex = $content.IndexOf($beginMarker, [StringComparison]::Ordinal)
    $endIndex = $content.IndexOf($endMarker, [StringComparison]::Ordinal)
    if ($endIndex -lt $beginIndex) {
        throw "Artifact catalog markers are out of order: $($catalog.indexPath)"
    }

    [string[]]$entries = @(
        Get-ChildItem -LiteralPath $directoryPath -Filter $include -File |
            Where-Object { $_.FullName -ne $indexPath } |
            ForEach-Object { Get-NormalizedRelativePath -FullPath $_.FullName }
    )
    [Array]::Sort($entries, [StringComparer]::Ordinal)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($beginMarker)
    $lines.Add("### $([string]$catalog.name)")
    if ($entries.Count -eq 0) {
        $lines.Add('No matching files.')
    } else {
        foreach ($entry in $entries) {
            $lines.Add(('- ' + [char]96 + $entry + [char]96))
        }
    }
    $lines.Add($endMarker)
    $lineEnding = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $expectedBlock = [string]::Join($lineEnding, $lines)

    $blockLength = ($endIndex + $endMarker.Length) - $beginIndex
    $currentBlock = $content.Substring($beginIndex, $blockLength)
    if ($currentBlock -eq $expectedBlock) {
        Write-Host "PASS  Artifact catalog is current: $($catalog.indexPath)" -ForegroundColor Green
        continue
    }

    $hasDifference = $true
    if ($Check) {
        Write-Host "FAIL  Artifact catalog is stale: $($catalog.indexPath)" -ForegroundColor Red
        continue
    }

    $updatedContent = $content.Substring(0, $beginIndex) + $expectedBlock + $content.Substring($beginIndex + $blockLength)
    [IO.File]::WriteAllText($indexPath, $updatedContent, (New-Object Text.UTF8Encoding($false)))
    Write-Host "UPDATE $($catalog.indexPath)" -ForegroundColor Green
}

if ($Check -and $hasDifference) {
    Write-Host 'Run scripts/update-artifact-catalog.ps1 and stage the updated index.' -ForegroundColor Yellow
    exit 1
}

if ($Staged) {
    $indexPaths = @($catalogs | ForEach-Object { ([string]$_.indexPath).Replace('\', '/') })
    $unstagedIndexChanges = @(& git -C $repositoryRoot diff --name-only -- @indexPaths)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to check artifact catalog index staging state.'
    }
    if ($unstagedIndexChanges.Count -gt 0) {
        Write-Host 'FAIL  Artifact catalog index has unstaged changes:' -ForegroundColor Red
        $unstagedIndexChanges | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
        exit 1
    }
}

if ($Check) {
    Write-Host 'PASS  Configured artifact catalogs are current.' -ForegroundColor Green
}
