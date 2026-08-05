[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetPath,

    [ValidateSet('Light', 'Standard')]
    [string]$Profile = 'Standard',

    [string]$ProjectName,

    [switch]$Force,

    [switch]$MergeProjectRules,

    [switch]$Update,

    [switch]$Prune
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
        [Parameter(Mandatory = $true)][bool]$Overwrite,
        [string[]]$ProjectOwnedPaths = @(),
        [string]$HarnessRulesBlock = ''
    )

    if (-not (Test-Path -LiteralPath $LayerPath -PathType Container)) {
        throw "Template layer not found: $LayerPath"
    }

    foreach ($sourceFile in Get-ChildItem -LiteralPath $LayerPath -Recurse -File -Force) {
        $relativePath = Get-RelativePath -BasePath $LayerPath -ChildPath $sourceFile.FullName
        $destinationPath = Join-Path $DestinationRoot $relativePath
        $destinationDirectory = Split-Path -Parent $destinationPath

        $normalizedRelativePath = $relativePath.Replace('\', '/')
        if ((Test-Path -LiteralPath $destinationPath) -and ($normalizedRelativePath -in $ProjectOwnedPaths)) {
            Write-Host "SKIP   $relativePath (project-owned; -Force does not overwrite project files)"
            continue
        }

        if ((Test-Path -LiteralPath $destinationPath) -and -not $Overwrite) {
            Write-Host "SKIP   $relativePath"
            continue
        }

        if ($PSCmdlet.ShouldProcess($destinationPath, 'Install harness template')) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
            $content = [IO.File]::ReadAllText($sourceFile.FullName)
            $content = $content.Replace('{{PROJECT_NAME}}', $ResolvedProjectName)
            if ($normalizedRelativePath -eq 'AGENTS.md') {
                $content = $content.Replace('{{HARNESS_RULES_BLOCK}}', $HarnessRulesBlock)
            }
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

function Get-FileContentHash {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '')
    } finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Write-Utf8NoBom {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Content)

    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false)))
}

function Merge-HarnessRulesBlock {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RulesBlock
    )

    $begin = '<!-- PROJECT-HARNESS:BEGIN -->'
    $end = '<!-- PROJECT-HARNESS:END -->'
    $content = [IO.File]::ReadAllText($Path)
    $beginCount = ([regex]::Matches($content, [regex]::Escape($begin))).Count
    $endCount = ([regex]::Matches($content, [regex]::Escape($end))).Count
    if ($beginCount -ne $endCount -or $beginCount -gt 1) {
        throw "Cannot merge Harness rules into ${Path}: expected zero or one complete managed block."
    }

    $block = $RulesBlock.TrimEnd() + [Environment]::NewLine
    if ($beginCount -eq 1) {
        $pattern = '(?s)<!-- PROJECT-HARNESS:BEGIN -->.*?<!-- PROJECT-HARNESS:END -->\s*'
        $managedMatch = [regex]::Match($content, $pattern)
        $normalizedCurrentBlock = $managedMatch.Value.TrimEnd().Replace("`r`n", "`n")
        $normalizedExpectedBlock = $block.TrimEnd().Replace("`r`n", "`n")
        if ($normalizedCurrentBlock -eq $normalizedExpectedBlock) {
            return $content
        }
        return [regex]::Replace($content, $pattern, $block)
    }

    return $content.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block
}

$target = [IO.Path]::GetFullPath($TargetPath)
if ($Update -and -not (Test-Path -LiteralPath $target -PathType Container)) {
    throw 'Cannot update a missing target directory; run a fresh installation first.'
}
if ($Update -and ($Force -or $PSBoundParameters.ContainsKey('Profile') -or $PSBoundParameters.ContainsKey('ProjectName'))) {
    throw '-Update uses profile and project name from harness.lock.json and cannot be combined with -Force, -Profile, or -ProjectName.'
}
if ($Update -and $MergeProjectRules) {
    throw '-MergeProjectRules is only supported during fresh installation; run it without -Update.'
}
if ($Prune -and -not $Update) {
    throw '-Prune is only valid together with -Update.'
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
$harnessRulesPath = Join-Path $templatesRoot 'partials\agents-harness-block.md'
$harnessRulesBlock = if (Test-Path -LiteralPath $harnessRulesPath -PathType Leaf) {
    [IO.File]::ReadAllText($harnessRulesPath)
} else {
    throw "Harness rules partial not found: $harnessRulesPath"
}

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
    $unmanaged = @()
    $orphans = @()
    $prunes = @()
    $nextManagedFiles = @()
    $lockStateChanged = $false
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
        $localHash = Get-FileContentHash -Path $destinationPath
        $baseHash = [string]$entry.baselineHash
        if ([string]::IsNullOrWhiteSpace($baseHash)) {
            if ($localHash -eq $upstreamHash) { $lockStateChanged = $true }
            else { $unmanaged += $relativePath }
        } elseif ($localHash -eq $upstreamHash) {
            if ($baseHash -ne $upstreamHash) { $lockStateChanged = $true }
        } elseif ($localHash -ne $baseHash -and $upstreamHash -ne $baseHash) {
            $conflicts += "$relativePath (local and upstream changes overlap)"
        } elseif ($localHash -eq $baseHash -and $upstreamHash -ne $baseHash) {
            $changes += [pscustomobject]@{ Path = $relativePath; Destination = $destinationPath; Content = $content; Hash = $upstreamHash; NewFile = $false }
        }
        $nextManagedFiles += [ordered]@{ path = $relativePath; ownership = 'managed'; baselineHash = if ($localHash -eq $upstreamHash -or $localHash -eq $baseHash) { $upstreamHash } elseif ([string]::IsNullOrWhiteSpace($baseHash)) { $null } else { $baseHash } }
    }
    foreach ($entry in @($lock.managedFiles)) {
        if ([string]$entry.path -notin $managedManifestPaths) {
            $previousManifestFile = $manifestByPath[[string]$entry.path]
            if ($null -ne $previousManifestFile -and $previousManifestFile.ownership -eq 'project') {
                $lockStateChanged = $true
            } else {
                $relativePath = [string]$entry.path
                $destinationPath = Join-Path $target $relativePath
                if (-not (Test-Path -LiteralPath $destinationPath)) {
                    $lockStateChanged = $true
                    continue
                }
                if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
                    if ($Prune) { $conflicts += "$relativePath (orphaned path is not a regular file)" }
                    else {
                        $orphans += $relativePath
                        $nextManagedFiles += $entry
                    }
                    continue
                }

                $baseHash = [string]$entry.baselineHash
                $localHash = Get-FileContentHash -Path $destinationPath
                if (-not $Prune) {
                    $orphans += $relativePath
                    $nextManagedFiles += $entry
                } elseif ([string]::IsNullOrWhiteSpace($baseHash)) {
                    $conflicts += "$relativePath (orphaned file has no trusted baseline)"
                } elseif ($localHash -ne $baseHash) {
                    $conflicts += "$relativePath (orphaned file was modified locally)"
                } else {
                    $prunes += [pscustomobject]@{ Path = $relativePath; Destination = $destinationPath }
                }
            }
        }
    }
    $lockMetadataChanged = $lockStateChanged -or ([string]$lock.harnessVersion -ne [string]$manifest.harnessVersion)
    Write-Host "Update plan: $($changes.Count) file update(s), $($prunes.Count) orphan prune(s), $($orphans.Count) orphaned file(s), $($unmanaged.Count) unmanaged skip(s), $($conflicts.Count) conflict(s)."
    foreach ($change in $changes) { Write-Host "UPDATE   $($change.Path)" }
    foreach ($prunePlan in $prunes) { Write-Host "PRUNE    $($prunePlan.Path)" -ForegroundColor Yellow }
    foreach ($relativePath in $orphans) { Write-Host "ORPHANED $relativePath (retained; run -Update -Prune to remove an unmodified file)" -ForegroundColor Yellow }
    foreach ($relativePath in $unmanaged) { Write-Host "SKIP     $relativePath (no trusted baseline)" -ForegroundColor Yellow }
    if ($lockMetadataChanged) { Write-Host "UPDATE   harness.lock.json ($($lock.harnessVersion) -> $($manifest.harnessVersion))" }
    foreach ($conflict in $conflicts) { Write-Host "CONFLICT $conflict" -ForegroundColor Red }
    if ($conflicts.Count -gt 0) { exit 1 }
    if ($changes.Count -eq 0 -and $prunes.Count -eq 0 -and -not $lockMetadataChanged) { Write-Host 'No managed file updates are required.'; exit 0 }
    $backupRoot = Join-Path $target (Join-Path '.harness-backup' (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
    $written = New-Object System.Collections.Generic.List[object]
    $removed = New-Object System.Collections.Generic.List[object]
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
        foreach ($prunePlan in $prunes) {
            if ($PSCmdlet.ShouldProcess($prunePlan.Destination, 'Remove orphaned managed Harness file')) {
                $backupPath = Join-Path $backupRoot $prunePlan.Path
                New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
                Copy-Item -LiteralPath $prunePlan.Destination -Destination $backupPath -Force
                $removed.Add($prunePlan)
                Remove-Item -LiteralPath $prunePlan.Destination -Force
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
        foreach ($prunePlan in $removed) {
            $backupPath = Join-Path $backupRoot $prunePlan.Path
            if (Test-Path -LiteralPath $backupPath -PathType Leaf) { Copy-Item -LiteralPath $backupPath -Destination $prunePlan.Destination -Force }
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

$forceBackupRoot = $null
if ($Force) {
    $existingManagedFiles = @($selectedFiles | Where-Object {
        $_.ownership -eq 'managed' -and $preExistingPaths[[string]$_.path]
    })
    if ($existingManagedFiles.Count -gt 0) {
        $forceBackupRoot = Join-Path $target ('.harness-backup\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        if ($WhatIfPreference) {
            Write-Host "What if: backing up $($existingManagedFiles.Count) existing managed file(s) to $forceBackupRoot."
        } elseif ($PSCmdlet.ShouldProcess($forceBackupRoot, 'Back up existing managed Harness files')) {
            foreach ($file in $existingManagedFiles) {
                $relativePath = ([string]$file.path).Replace('/', '\')
                $sourcePath = Join-Path $target $relativePath
                $backupPath = Join-Path $forceBackupRoot $relativePath
                New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
                Copy-Item -LiteralPath $sourcePath -Destination $backupPath -Force
            }
            Write-Host "BACKUP $forceBackupRoot"
        }
    }
}

Write-Host "Project Harness initialization"
Write-Host "Target : $target"
Write-Host "Profile: $Profile"
Write-Host "Project: $ProjectName"

$projectOwnedPaths = @($selectedFiles | Where-Object { $_.ownership -eq 'project' } | ForEach-Object { [string]$_.path })
Install-TemplateLayer -LayerPath (Join-Path $templatesRoot 'base') -DestinationRoot $target -ResolvedProjectName $ProjectName -Overwrite $Force.IsPresent -ProjectOwnedPaths $projectOwnedPaths -HarnessRulesBlock $harnessRulesBlock
if ($Profile -eq 'Standard') {
    Install-TemplateLayer -LayerPath (Join-Path $templatesRoot 'standard') -DestinationRoot $target -ResolvedProjectName $ProjectName -Overwrite $Force.IsPresent -ProjectOwnedPaths $projectOwnedPaths -HarnessRulesBlock $harnessRulesBlock
}

$agentsPath = Join-Path $target 'AGENTS.md'
if ($MergeProjectRules -and (Test-Path -LiteralPath $agentsPath -PathType Leaf)) {
    $mergedRules = Merge-HarnessRulesBlock -Path $agentsPath -RulesBlock $harnessRulesBlock
    $currentRules = [IO.File]::ReadAllText($agentsPath)
    if ($mergedRules -ne $currentRules) {
        $mergeBackupRoot = Join-Path $target ('.harness-backup\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        $mergeBackupPath = Join-Path $mergeBackupRoot 'AGENTS.md'
        if ($WhatIfPreference) {
            Write-Host "What if: merging Harness rules into AGENTS.md (backup: $mergeBackupPath)."
        } elseif ($PSCmdlet.ShouldProcess($agentsPath, 'Merge Harness rules into project AGENTS.md')) {
            New-Item -ItemType Directory -Path $mergeBackupRoot -Force | Out-Null
            Copy-Item -LiteralPath $agentsPath -Destination $mergeBackupPath -Force
            Write-Utf8NoBom -Path $agentsPath -Content $mergedRules
            Write-Host 'MERGE  AGENTS.md (Harness rules block)'
            Write-Host "BACKUP $mergeBackupRoot"
        }
    } else {
        Write-Host 'SKIP   AGENTS.md (Harness rules block already up to date)'
    }
}

$requiredPaths = @('harness.config.json', 'harness.lock.json') + @(
    $manifest.files |
        Where-Object { $_.layer -in $selectedLayers } |
        ForEach-Object { [string]$_.path }
)

$configPath = Join-Path $target 'harness.config.json'
if (-not (Test-Path -LiteralPath $configPath)) {
    $artifactCatalogs = @()
    if ($Profile -eq 'Standard') {
        $artifactCatalogs += [ordered]@{
            name = 'Harness checks'
            directory = 'tests/harness'
            include = '*.ps1'
            indexPath = 'tests/harness/README.md'
        }
    }
    $config = [ordered]@{
        schemaVersion = 1
        harnessVersion = [string]$manifest.harnessVersion
        profile = $Profile
        projectName = $ProjectName
        requiredPaths = $requiredPaths
        projectValidation = @()
        driftChecks = @()
        artifactCatalogs = $artifactCatalogs
        capabilities = @()
        readiness = [ordered]@{
            requireProjectValidation = ($Profile -eq 'Standard')
            requiredValidationKinds = @()
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
if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
    $managedFiles = @()
    foreach ($file in $selectedFiles | Where-Object { $_.ownership -eq 'managed' }) {
        $relativePath = [string]$file.path
        $destinationPath = Join-Path $target $relativePath
        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            continue
        }

        $hash = Get-FileContentHash -Path $destinationPath
        $templateLayer = [string]$file.layer
        $templatePath = Join-Path (Join-Path $templatesRoot $templateLayer) ([string]$file.path)
        $templateContent = [IO.File]::ReadAllText($templatePath)
        $templateContent = $templateContent.Replace('{{PROJECT_NAME}}', $ProjectName)
        $matchesTemplate = $hash -eq (Get-TextHash -Content $templateContent)
        $managedFiles += [ordered]@{
            path = $relativePath
            ownership = 'managed'
            baselineHash = if (-not $preExistingPaths[$relativePath] -or $Force -or $matchesTemplate) { $hash } else { $null }
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
    if ($Force) {
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        $refreshedManagedFiles = @()
        foreach ($file in $selectedFiles | Where-Object { $_.ownership -eq 'managed' }) {
            $relativePath = [string]$file.path
            $destinationPath = Join-Path $target $relativePath
            if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
                $refreshedManagedFiles += [ordered]@{
                    path = $relativePath
                    ownership = 'managed'
                    baselineHash = Get-FileContentHash -Path $destinationPath
                }
            }
        }
        $lock.managedFiles = @($refreshedManagedFiles)
        $lock.harnessVersion = [string]$manifest.harnessVersion
        if ($PSCmdlet.ShouldProcess($lockPath, 'Refresh Harness lock after managed migration')) {
            Write-Utf8NoBom -Path $lockPath -Content (($lock | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
            Write-Host 'UPDATE harness.lock.json (managed migration baselines refreshed)'
        }
    }
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
if ($Profile -eq 'Standard') {
    Write-Host '5. Optional: enable the local catalog pre-commit hook after review:'
    Write-Host '   powershell -ExecutionPolicy Bypass -File scripts/install-git-hooks.ps1'
}
Write-Host ''
if ($WhatIfPreference) {
    Write-Host 'Status: preview only; no files were written.' -ForegroundColor Yellow
} else {
    Write-Host 'Status: installed; project configuration is not ready until Scope All passes.' -ForegroundColor Yellow
}
