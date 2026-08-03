[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [ValidateSet('Light', 'Standard')]
    [string]$Profile = 'Standard',

    [string]$ProjectName,

    [switch]$Force,

    [switch]$Update
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

function Get-TextHash {
    param([Parameter(Mandatory = $true)][string]$Content)

    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Content)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
}

function Write-Utf8NoBom {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Content)

    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false)))
}

$target = [IO.Path]::GetFullPath($TargetPath)
if ($Update -and -not (Test-Path -LiteralPath $target -PathType Container)) {
    throw 'Cannot update a missing target directory; run a fresh installation first.'
}
if ($Update -and ($Force -or $PSBoundParameters.ContainsKey('Profile') -or $PSBoundParameters.ContainsKey('ProjectName'))) {
    throw '-Update uses profile and project name from harness.lock.json and cannot be combined with -Force, -Profile, or -ProjectName.'
}
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

if ($Update) {
    $lockPath = Join-Path $target 'harness.lock.json'
    if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
        throw 'Cannot update without harness.lock.json; run a fresh installation first.'
    }
    $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
    if ($lock.schemaVersion -ne 1 -or [string]::IsNullOrWhiteSpace([string]$lock.profile)) {
        throw 'Unsupported or incomplete harness.lock.json; run a fresh installation first.'
    }
    $manifestByPath = @{}
    foreach ($manifestFile in @($manifest.files)) { $manifestByPath[[string]$manifestFile.path] = $manifestFile }
    $lockByPath = @{}
    foreach ($entry in @($lock.managedFiles)) { $lockByPath[[string]$entry.path] = $entry }
    $selectedLayers = @('base')
    if ([string]$lock.profile -eq 'Standard') { $selectedLayers += 'standard' }
    elseif ([string]$lock.profile -ne 'Light') { throw "Unsupported lock profile: $($lock.profile)" }
    $managedManifestPaths = @($manifest.files | Where-Object { $_.layer -in $selectedLayers -and $_.ownership -eq 'managed' } | ForEach-Object { [string]$_.path })
    $changes = @()
    $conflicts = @()
    $nextManagedFiles = @()
    foreach ($manifestFile in @($manifest.files | Where-Object { $_.layer -in $selectedLayers -and $_.ownership -eq 'managed' })) {
        $relativePath = [string]$manifestFile.path
        $entry = $lockByPath[$relativePath]
        $manifestFile = $manifestByPath[$relativePath]
        $sourcePath = Join-Path (Join-Path $templatesRoot ([string]$manifestFile.layer)) $relativePath
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            $conflicts += "$relativePath (upstream template unavailable)"
            continue
        }
        $content = ([IO.File]::ReadAllText($sourcePath)).Replace('{{PROJECT_NAME}}', [string]$lock.projectName)
        $upstreamHash = Get-TextHash -Content $content
        $destinationPath = Join-Path $target $relativePath
        if ($null -eq $entry) {
            if (Test-Path -LiteralPath $destinationPath) {
                $conflicts += "$relativePath (new managed file collides with local path)"
                continue
            }
            $changes += [pscustomobject]@{ Path = $relativePath; Destination = $destinationPath; Content = $content; Hash = $upstreamHash; NewFile = $true }
            $nextManagedFiles += [ordered]@{ path = $relativePath; ownership = 'managed'; baselineHash = $upstreamHash }
            continue
        }
        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            $conflicts += "$relativePath (local file missing)"
            continue
        }
        $localHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
        $baseHash = [string]$entry.baselineHash
        if ([string]::IsNullOrWhiteSpace($baseHash)) {
            $conflicts += "$relativePath (missing lock baseline)"
        } elseif ($localHash -ne $baseHash -and $upstreamHash -ne $baseHash) {
            $conflicts += "$relativePath (local and upstream changes overlap)"
        } elseif ($localHash -eq $baseHash -and $upstreamHash -ne $baseHash) {
            $changes += [pscustomobject]@{ Path = $relativePath; Destination = $destinationPath; Content = $content; Hash = $upstreamHash; NewFile = $false }
        }
        $nextManagedFiles += [ordered]@{ path = $relativePath; ownership = 'managed'; baselineHash = if ($localHash -eq $baseHash) { $upstreamHash } else { $baseHash } }
    }
    foreach ($entry in @($lock.managedFiles)) {
        if ([string]$entry.path -notin $managedManifestPaths) {
            $conflicts += "$($entry.path) (managed file removed upstream)"
        }
    }
    $lockMetadataChanged = ([string]$lock.harnessVersion -ne [string]$manifest.harnessVersion)
    Write-Host "Update plan: $($changes.Count) file update(s), $($conflicts.Count) conflict(s)."
    foreach ($change in $changes) { Write-Host "UPDATE   $($change.Path)" }
    if ($lockMetadataChanged) { Write-Host "UPDATE   harness.lock.json ($($lock.harnessVersion) -> $($manifest.harnessVersion))" }
    foreach ($conflict in $conflicts) { Write-Host "CONFLICT $conflict" -ForegroundColor Red }
    if ($conflicts.Count -gt 0) { exit 1 }
    if ($changes.Count -eq 0 -and -not $lockMetadataChanged) { Write-Host 'No managed file updates are required.'; exit 0 }
    $backupRoot = Join-Path $target (Join-Path '.harness-backup' (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    $written = New-Object System.Collections.Generic.List[object]
    try {
        if (-not $WhatIfPreference) {
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            Copy-Item -LiteralPath $lockPath -Destination (Join-Path $backupRoot 'harness.lock.json') -Force
        }
        foreach ($change in $changes) {
            if ($PSCmdlet.ShouldProcess($change.Destination, 'Update managed Harness file')) {
                $backupPath = Join-Path $backupRoot $change.Path
                New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
                if (-not $change.NewFile) { Copy-Item -LiteralPath $change.Destination -Destination $backupPath -Force }
                New-Item -ItemType Directory -Path (Split-Path -Parent $change.Destination) -Force | Out-Null
                $written.Add($change)
                Write-Utf8NoBom -Path $change.Destination -Content $change.Content
            }
        }
        if (-not $WhatIfPreference) {
            $lock.managedFiles = @($nextManagedFiles)
            $lock.harnessVersion = [string]$manifest.harnessVersion
            $lock.profile = [string]$lock.profile
            $lockTemp = "$lockPath.$([Guid]::NewGuid().ToString('N')).tmp"
            Write-Utf8NoBom -Path $lockTemp -Content (($lock | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
            Move-Item -LiteralPath $lockTemp -Destination $lockPath -Force
            Write-Host "Backup   $backupRoot"
        }
    } catch {
        foreach ($change in $written) {
            $backupPath = Join-Path $backupRoot $change.Path
            if (Test-Path -LiteralPath $backupPath -PathType Leaf) { Copy-Item -LiteralPath $backupPath -Destination $change.Destination -Force }
            elseif ($change.NewFile -and (Test-Path -LiteralPath $change.Destination)) { Remove-Item -LiteralPath $change.Destination -Force }
        }
        $lockBackupPath = Join-Path $backupRoot 'harness.lock.json'
        if (Test-Path -LiteralPath $lockBackupPath -PathType Leaf) { Copy-Item -LiteralPath $lockBackupPath -Destination $lockPath -Force }
        throw
    }
    exit 0
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
        capabilities = @()
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
