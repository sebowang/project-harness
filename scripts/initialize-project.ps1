[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [ValidateSet('Light', 'Standard')]
    [string]$Profile = 'Standard',

    [string]$ProjectName,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$ChildPath
    )

    $baseUri = New-Object System.Uri(($BasePath.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar))
    $childUri = New-Object System.Uri($ChildPath)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($childUri).ToString()).Replace('/', [IO.Path]::DirectorySeparatorChar)
}

function Install-TemplateLayer {
    param(
        [Parameter(Mandatory = $true)][string]$LayerPath,
        [Parameter(Mandatory = $true)][string]$DestinationRoot,
        [Parameter(Mandatory = $true)][string]$ResolvedProjectName,
        [Parameter(Mandatory = $true)][bool]$Overwrite
    )

    if (-not (Test-Path -LiteralPath $LayerPath -PathType Container)) {
        throw "Template layer not found: $LayerPath"
    }

    foreach ($sourceFile in Get-ChildItem -LiteralPath $LayerPath -Recurse -File) {
        $relativePath = Get-RelativePath -BasePath $LayerPath -ChildPath $sourceFile.FullName
        $destinationPath = Join-Path $DestinationRoot $relativePath
        $destinationDirectory = Split-Path -Parent $destinationPath

        if ((Test-Path -LiteralPath $destinationPath) -and -not $Overwrite) {
            Write-Host "SKIP   $relativePath"
            continue
        }

        if ($PSCmdlet.ShouldProcess($destinationPath, 'Install harness template')) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
            $content = [IO.File]::ReadAllText($sourceFile.FullName)
            $content = $content.Replace('{{PROJECT_NAME}}', $ResolvedProjectName)
            [IO.File]::WriteAllText($destinationPath, $content, (New-Object Text.UTF8Encoding($false)))
            Write-Host "WRITE  $relativePath"
        }
    }
}

function Get-RepositorySignals {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

    $signals = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $RepositoryRoot -PathType Container)) {
        $signals.Add('Target directory is not present during preview; inspect repository signals after installation')
        return $signals
    }

    $signalFiles = [ordered]@{
        'package.json' = 'Node.js / JavaScript / TypeScript'
        'pyproject.toml' = 'Python'
        'requirements.txt' = 'Python'
        'Cargo.toml' = 'Rust'
        'go.mod' = 'Go'
        'pom.xml' = 'Maven / Java'
        'build.gradle' = 'Gradle / JVM'
        'Makefile' = 'Make-based build'
    }

    foreach ($entry in $signalFiles.GetEnumerator()) {
        if (Test-Path -LiteralPath (Join-Path $RepositoryRoot $entry.Key)) {
            $signals.Add($entry.Value)
        }
    }

    if (Get-ChildItem -LiteralPath $RepositoryRoot -Filter '*.sln' -File -ErrorAction SilentlyContinue | Select-Object -First 1) {
        $signals.Add('.NET solution')
    }

    if ($signals.Count -eq 0) {
        $signals.Add('No common build signal detected; inspect the repository manually')
    }

    return $signals | Select-Object -Unique
}

$target = [IO.Path]::GetFullPath($TargetPath)
if (-not (Test-Path -LiteralPath $target)) {
    if ($PSCmdlet.ShouldProcess($target, 'Create target directory')) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }
}

if (-not $ProjectName) {
    $ProjectName = Split-Path -Leaf $target
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$templatesRoot = Join-Path $repositoryRoot 'templates'
$manifestPath = Join-Path $templatesRoot 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ($manifest.schemaVersion -ne 1) {
    throw "Unsupported template manifest schemaVersion: $($manifest.schemaVersion)"
}

$selectedLayers = @('base')
if ($Profile -eq 'Standard') {
    $selectedLayers += 'standard'
}
$selectedFiles = @($manifest.files | Where-Object { $_.layer -in $selectedLayers })
$preExistingPaths = @{}
foreach ($file in $selectedFiles) {
    $destinationPath = Join-Path $target ([string]$file.path)
    $preExistingPaths[[string]$file.path] = Test-Path -LiteralPath $destinationPath -PathType Leaf
}

Write-Host "Project Harness initialization"
Write-Host "Target : $target"
Write-Host "Profile: $Profile"
Write-Host "Project: $ProjectName"

Install-TemplateLayer -LayerPath (Join-Path $templatesRoot 'base') -DestinationRoot $target -ResolvedProjectName $ProjectName -Overwrite $Force.IsPresent
if ($Profile -eq 'Standard') {
    Install-TemplateLayer -LayerPath (Join-Path $templatesRoot 'standard') -DestinationRoot $target -ResolvedProjectName $ProjectName -Overwrite $Force.IsPresent
}

$requiredPaths = @('harness.config.json', 'harness.lock.json') + @(
    $manifest.files |
        Where-Object { $_.layer -in $selectedLayers } |
        ForEach-Object { [string]$_.path }
)

$configPath = Join-Path $target 'harness.config.json'
if ((-not (Test-Path -LiteralPath $configPath)) -or $Force) {
    $config = [ordered]@{
        schemaVersion = 1
        harnessVersion = [string]$manifest.harnessVersion
        profile = $Profile
        projectName = $ProjectName
        requiredPaths = $requiredPaths
        projectValidation = @()
        driftChecks = @()
        readiness = [ordered]@{
            requireProjectValidation = ($Profile -eq 'Standard')
            projectValidationWaiver = $null
        }
    }
    $json = $config | ConvertTo-Json -Depth 8
    if ($PSCmdlet.ShouldProcess($configPath, 'Install harness configuration')) {
        [IO.File]::WriteAllText($configPath, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        Write-Host 'WRITE  harness.config.json'
    }
} else {
    Write-Host 'SKIP   harness.config.json'
}

$lockPath = Join-Path $target 'harness.lock.json'
if ((-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) -or $Force) {
    $managedFiles = @()
    foreach ($file in $selectedFiles | Where-Object { $_.ownership -eq 'managed' }) {
        $relativePath = [string]$file.path
        $destinationPath = Join-Path $target $relativePath
        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            continue
        }

        $hash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
        $managedFiles += [ordered]@{
            path = $relativePath
            ownership = 'managed'
            baselineHash = if ($preExistingPaths[$relativePath]) { $null } else { $hash }
        }
    }

    $lock = [ordered]@{
        schemaVersion = 1
        harnessVersion = [string]$manifest.harnessVersion
        profile = $Profile
        projectName = $ProjectName
        managedFiles = $managedFiles
    }
    $lockJson = $lock | ConvertTo-Json -Depth 8
    if ($PSCmdlet.ShouldProcess($lockPath, 'Install Harness lock')) {
        [IO.File]::WriteAllText($lockPath, $lockJson + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        Write-Host 'WRITE  harness.lock.json'
    }
} else {
    Write-Host 'SKIP   harness.lock.json'
}

Write-Host ''
Write-Host 'Detected repository signals:'
foreach ($signal in Get-RepositorySignals -RepositoryRoot $target) {
    Write-Host "- $signal"
}

Write-Host ''
Write-Host 'Next steps:'
Write-Host '1. Fill docs/project-map.md with verified repository facts.'
Write-Host '2. Add real project checks to harness.config.json.'
Write-Host '3. Remove TODO(HARNESS) markers after review.'
Write-Host '4. Run scripts/verify.ps1 -Scope All.'
Write-Host ''
if ($WhatIfPreference) {
    Write-Host 'Status: preview only; no files were written.' -ForegroundColor Yellow
} else {
    Write-Host 'Status: installed; project configuration is not ready until Scope All passes.' -ForegroundColor Yellow
}
