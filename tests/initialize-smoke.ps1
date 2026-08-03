$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$initializer = Join-Path $repositoryRoot 'scripts\initialize-project.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-' + [Guid]::NewGuid().ToString('N'))
$lightRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-light-' + [Guid]::NewGuid().ToString('N'))
$whatIfRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-whatif-' + [Guid]::NewGuid().ToString('N'))
$updateSourceRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-update-source-' + [Guid]::NewGuid().ToString('N'))
$powerShellExecutable = if (Test-Path -LiteralPath (Join-Path $PSHOME 'powershell.exe')) {
    Join-Path $PSHOME 'powershell.exe'
} elseif (Test-Path -LiteralPath (Join-Path $PSHOME 'pwsh.exe')) {
    Join-Path $PSHOME 'pwsh.exe'
} else {
    Join-Path $PSHOME 'pwsh'
}

function Assert-ScriptFails {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$Arguments = @()
    )

    & $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
    if ($LASTEXITCODE -eq 0) {
        throw "Expected script to fail: $Path $($Arguments -join ' ')"
    }
}

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $existingAgents = Join-Path $testRoot 'AGENTS.md'
    [IO.File]::WriteAllText($existingAgents, "# Existing rules`r`n", (New-Object Text.UTF8Encoding($false)))
    $existingManaged = Join-Path $testRoot 'docs\harness-configuration.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $existingManaged) -Force | Out-Null
    [IO.File]::WriteAllText($existingManaged, "# Existing managed-path content`n", (New-Object Text.UTF8Encoding($false)))

    & $initializer -TargetPath $testRoot -Profile Standard -ProjectName 'Smoke Test Project'

    $expectedPaths = @(
        'AGENTS.md',
        'CLAUDE.md',
        '.trae\rules\project-harness.md',
        'harness.config.json',
        'harness.lock.json',
        'docs\project-map.md',
        'docs\verification.md',
        'docs\decisions\README.md',
        'docs\agent-compatibility.md',
        'docs\workflows\project-start.md',
        '.agents\skills\project-start\SKILL.md',
        '.claude\skills\project-start\SKILL.md',
        'scripts\check-readiness.ps1',
        'scripts\harness-status.ps1',
        'scripts\harness-doctor.ps1',
        'scripts\verify.ps1',
        'tests\harness\README.md'
    )

    foreach ($relativePath in $expectedPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $testRoot $relativePath))) {
            throw "Missing generated path: $relativePath"
        }
    }

    if ([IO.File]::ReadAllText($existingAgents) -ne "# Existing rules`r`n") {
        throw 'Existing AGENTS.md was overwritten without -Force.'
    }

    $claudeEntry = [IO.File]::ReadAllText((Join-Path $testRoot 'CLAUDE.md')).Trim()
    if ($claudeEntry -ne '@AGENTS.md') {
        throw 'CLAUDE.md does not import AGENTS.md.'
    }

    $traeEntry = [IO.File]::ReadAllText((Join-Path $testRoot '.trae\rules\project-harness.md'))
    if ($traeEntry -notmatch 'AGENTS\.md' -or $traeEntry -notmatch 'docs/workflows/') {
        throw 'Trae project rule does not route to AGENTS.md and public workflows.'
    }

    $workflowNames = @('project-start', 'project-onboarding', 'change-plan', 'adversarial-review', 'harness-authoring', 'project-handoff', 'testing', 'systematic-debugging', 'durable-plan')
    foreach ($workflowName in $workflowNames) {
        $workflowPath = Join-Path $testRoot "docs\workflows\$workflowName.md"
        $codexSkillPath = Join-Path $testRoot ".agents\skills\$workflowName\SKILL.md"
        $claudeSkillPath = Join-Path $testRoot ".claude\skills\$workflowName\SKILL.md"
        foreach ($path in @($workflowPath, $codexSkillPath, $claudeSkillPath)) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "Missing cross-agent workflow path: $path"
            }
        }

        foreach ($skillPath in @($codexSkillPath, $claudeSkillPath)) {
            $skillContent = Get-Content -LiteralPath $skillPath -Raw
            if ($skillContent -notmatch [regex]::Escape("docs/workflows/$workflowName.md")) {
                throw "Skill does not reference canonical workflow: $skillPath"
            }
        }
    }

    $projectMap = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\project-map.md'))
    if ($projectMap -notmatch 'Smoke Test Project') {
        throw 'Project name placeholder was not replaced.'
    }

    & (Join-Path $testRoot 'scripts\verify.ps1') -Scope Harness
    if (-not $?) {
        throw 'Generated harness verification failed.'
    }

    & (Join-Path $testRoot 'scripts\harness-status.ps1')
    if (-not $?) {
        throw 'Clean Harness status failed.'
    }

    $statusScript = Join-Path $testRoot 'scripts\harness-status.ps1'
    $statusBytes = [IO.File]::ReadAllBytes($statusScript)
    Add-Content -LiteralPath $statusScript -Value "`n# Local smoke modification"
    $statusOutput = (& $powerShellExecutable -NoProfile -ExecutionPolicy Bypass -File $statusScript 2>&1 | Out-String)
    if ($statusOutput -notmatch 'MODIFIED\s+scripts/harness-status\.ps1') {
        throw 'Harness status did not report a modified managed file.'
    }
    [IO.File]::WriteAllBytes($statusScript, $statusBytes)

    Assert-ScriptFails -Path (Join-Path $testRoot 'scripts\verify.ps1') -Arguments @('-Scope', 'All')
    Assert-ScriptFails -Path (Join-Path $testRoot 'scripts\harness-doctor.ps1')

    $configPath = Join-Path $testRoot 'harness.config.json'
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

    $templateFilePaths = @()
    foreach ($layerName in @('base', 'standard')) {
        $layerRoot = Join-Path $repositoryRoot "templates\$layerName"
        foreach ($file in Get-ChildItem -LiteralPath $layerRoot -Recurse -File) {
            $relativePath = $file.FullName.Substring($layerRoot.Length).TrimStart('\', '/').Replace('\', '/')
            $templateFilePaths += $relativePath
        }
    }
    $manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'templates\manifest.json') -Raw | ConvertFrom-Json
    $manifestPaths = @($manifest.files | ForEach-Object { [string]$_.path })
    $manifestDifferences = @(Compare-Object -ReferenceObject @($templateFilePaths | Sort-Object -Unique) -DifferenceObject @($manifestPaths | Sort-Object -Unique))
    if ($manifestDifferences.Count -gt 0) {
        throw "Template files and manifest differ: $($manifestDifferences | Out-String)"
    }
    $templatePaths = @('harness.config.json', 'harness.lock.json') + $templateFilePaths
    $pathDifferences = @(Compare-Object -ReferenceObject @($templatePaths | Sort-Object -Unique) -DifferenceObject @($config.requiredPaths | Sort-Object -Unique))
    if ($pathDifferences.Count -gt 0) {
        throw "Template files and requiredPaths differ: $($pathDifferences | Out-String)"
    }
    if (@($config.requiredPaths).Count -ne @($config.requiredPaths | Sort-Object -Unique).Count) {
        throw 'requiredPaths contains duplicate entries.'
    }
    $goldenPath = Join-Path $repositoryRoot 'tests\golden\standard-required-paths.txt'
    $goldenPaths = @(Get-Content -LiteralPath $goldenPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim().Replace('/', '\\') })
    $actualStandardPaths = @($config.requiredPaths | ForEach-Object { ([string]$_).Replace('/', '\\') } | Sort-Object)
    if ([string]::Join("`n", $goldenPaths) -ne [string]::Join("`n", $actualStandardPaths)) {
        throw 'Standard requiredPaths differ from tests/golden/standard-required-paths.txt.'
    }

    $config.projectValidation = @(
        [pscustomobject]@{
            name = 'Smoke project command'
            executable = 'powershell'
            arguments = @('-NoProfile', '-Command', "Write-Output 'Project validation passed.'")
        }
    )
    $config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8

    foreach ($markdownFile in Get-ChildItem -LiteralPath $testRoot -Filter '*.md' -Recurse -File) {
        $content = Get-Content -LiteralPath $markdownFile.FullName -Raw
        if ($content -match 'TODO\(HARNESS\)') {
            $content.Replace('TODO(HARNESS)', 'Configured for smoke test') | Set-Content -LiteralPath $markdownFile.FullName -Encoding UTF8
        }
    }

    & (Join-Path $testRoot 'scripts\verify.ps1') -Scope All
    if (-not $?) {
        throw 'Ready harness verification failed.'
    }
    & (Join-Path $testRoot 'scripts\harness-doctor.ps1')
    if (-not $?) {
        throw 'Doctor failed for a ready Harness.'
    }

    New-Item -ItemType Directory -Path $updateSourceRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'scripts') -Destination $updateSourceRoot -Recurse
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'templates') -Destination $updateSourceRoot -Recurse
    $upstreamStatus = Join-Path $updateSourceRoot 'templates\base\scripts\harness-status.ps1'
    Add-Content -LiteralPath $upstreamStatus -Value "`n# Upstream smoke update"
    $targetStatus = Join-Path $testRoot 'scripts\harness-status.ps1'
    $beforeDryRun = [IO.File]::ReadAllBytes($targetStatus)
    $updateInitializer = Join-Path $updateSourceRoot 'scripts\initialize-project.ps1'
    & $updateInitializer -TargetPath $testRoot -Update -WhatIf
    if (-not $?) { throw 'Managed update dry-run failed.' }
    if ([Convert]::ToBase64String($beforeDryRun) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($targetStatus))) {
        throw 'Managed update dry-run changed a target file.'
    }
    & $updateInitializer -TargetPath $testRoot -Update
    if (-not $?) { throw 'Managed update failed.' }
    if ([IO.File]::ReadAllText($existingManaged) -ne "# Existing managed-path content`n") {
        throw 'Update changed a pre-existing managed path without a trusted baseline.'
    }
    $unmanagedEntry = (Get-Content -LiteralPath (Join-Path $testRoot 'harness.lock.json') -Raw | ConvertFrom-Json).managedFiles | Where-Object { $_.path -eq 'docs/harness-configuration.md' } | Select-Object -First 1
    if ($null -ne $unmanagedEntry.baselineHash) {
        throw 'An unmanaged pre-existing path received a false lock baseline.'
    }
    if ((Get-Content -LiteralPath $targetStatus -Raw) -notmatch 'Upstream smoke update') {
        throw 'Managed update did not install upstream content.'
    }

    $configBeforeForce = [IO.File]::ReadAllText($configPath)
    & $initializer -TargetPath $testRoot -Profile Standard -ProjectName 'Changed By Force' -Force
    if ([IO.File]::ReadAllText($existingAgents) -ne "# Existing rules`r`n") {
        throw '-Force overwrote a project-owned AGENTS.md.'
    }
    if ([IO.File]::ReadAllText($configPath) -ne $configBeforeForce) {
        throw '-Force overwrote project-owned harness.config.json.'
    }
    if (-not (Get-ChildItem -LiteralPath (Join-Path $testRoot '.harness-backup') -Recurse -Filter 'harness-status.ps1' -File | Select-Object -First 1)) {
        throw 'Managed update did not create a backup.'
    }

    $updateManifestPath = Join-Path $updateSourceRoot 'templates\manifest.json'
    $updateManifest = Get-Content -LiteralPath $updateManifestPath -Raw | ConvertFrom-Json
    $updateManifest.harnessVersion = '0.2.1-test'
    $updateManifest.files += [pscustomobject]@{ path = 'docs/new-managed.md'; layer = 'base'; ownership = 'managed' }
    $updateManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $updateManifestPath -Encoding UTF8
    $newManagedSource = Join-Path $updateSourceRoot 'templates\base\docs\new-managed.md'
    [IO.File]::WriteAllText($newManagedSource, "# New managed file`n", (New-Object Text.UTF8Encoding($false)))
    & $updateInitializer -TargetPath $testRoot -Update
    if (-not $?) { throw 'Update with a new managed file failed.' }
    if (-not (Test-Path -LiteralPath (Join-Path $testRoot 'docs\new-managed.md') -PathType Leaf)) {
        throw 'Update did not install a new managed file.'
    }
    $updatedLock = Get-Content -LiteralPath (Join-Path $testRoot 'harness.lock.json') -Raw | ConvertFrom-Json
    if ($updatedLock.harnessVersion -ne '0.2.1-test' -or 'docs/new-managed.md' -notin @($updatedLock.managedFiles.path)) {
        throw 'Update did not record the new managed file and version in the lock.'
    }

    Add-Content -LiteralPath $upstreamStatus -Value "`n# Converged upstream update"
    Copy-Item -LiteralPath $upstreamStatus -Destination $targetStatus -Force
    & $updateInitializer -TargetPath $testRoot -Update
    if (-not $?) { throw 'Update rejected a local file already equal to upstream.' }
    $convergedLock = Get-Content -LiteralPath (Join-Path $testRoot 'harness.lock.json') -Raw | ConvertFrom-Json
    $convergedEntry = $convergedLock.managedFiles | Where-Object { $_.path -eq 'scripts/harness-status.ps1' } | Select-Object -First 1
    if ($convergedEntry.baselineHash -ne (Get-FileHash -LiteralPath $targetStatus -Algorithm SHA256).Hash) {
        throw 'Update did not advance the baseline for converged local and upstream content.'
    }

    ($updateManifest.files | Where-Object { $_.path -eq 'docs/new-managed.md' }).ownership = 'project'
    $updateManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $updateManifestPath -Encoding UTF8
    & $updateInitializer -TargetPath $testRoot -Update
    if (-not $?) { throw 'Managed-to-project ownership transition failed.' }
    $ownershipLock = Get-Content -LiteralPath (Join-Path $testRoot 'harness.lock.json') -Raw | ConvertFrom-Json
    if ('docs/new-managed.md' -in @($ownershipLock.managedFiles.path)) {
        throw 'Managed-to-project ownership transition retained a managed lock entry.'
    }

    $retiredRelativePath = 'docs/retired-managed.md'
    $retiredContent = "# Retired managed file`n"
    $updateManifest.files += [pscustomobject]@{ path = $retiredRelativePath; layer = 'base'; ownership = 'managed' }
    $updateManifest.harnessVersion = '0.2.2-test'
    $updateManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $updateManifestPath -Encoding UTF8
    $retiredSource = Join-Path $updateSourceRoot 'templates\base\docs\retired-managed.md'
    [IO.File]::WriteAllText($retiredSource, $retiredContent, (New-Object Text.UTF8Encoding($false)))
    & $updateInitializer -TargetPath $testRoot -Update
    if (-not $?) { throw 'Update did not install the soon-to-be-retired managed file.' }

    $updateManifest.files = @($updateManifest.files | Where-Object { $_.path -ne $retiredRelativePath })
    $updateManifest.harnessVersion = '0.2.3-test'
    $updateManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $updateManifestPath -Encoding UTF8
    Remove-Item -LiteralPath $retiredSource -Force
    & $updateInitializer -TargetPath $testRoot -Update
    if (-not $?) { throw 'An orphaned managed file blocked an otherwise safe update.' }
    $retiredTarget = Join-Path $testRoot $retiredRelativePath
    $orphanLock = Get-Content -LiteralPath (Join-Path $testRoot 'harness.lock.json') -Raw | ConvertFrom-Json
    if (-not (Test-Path -LiteralPath $retiredTarget -PathType Leaf) -or $retiredRelativePath -notin @($orphanLock.managedFiles.path)) {
        throw 'Default update did not preserve the orphaned file and lock entry.'
    }

    Add-Content -LiteralPath $retiredTarget -Value '# Local orphan modification'
    Assert-ScriptFails -Path $updateInitializer -Arguments @('-TargetPath', $testRoot, '-Update', '-Prune')
    if (-not (Test-Path -LiteralPath $retiredTarget -PathType Leaf)) {
        throw 'Prune removed a locally modified orphaned file.'
    }

    [IO.File]::WriteAllText($retiredTarget, $retiredContent, (New-Object Text.UTF8Encoding($false)))
    & $updateInitializer -TargetPath $testRoot -Update -Prune
    if (-not $?) { throw 'Prune rejected an unmodified orphaned file.' }
    $prunedLock = Get-Content -LiteralPath (Join-Path $testRoot 'harness.lock.json') -Raw | ConvertFrom-Json
    if ((Test-Path -LiteralPath $retiredTarget) -or $retiredRelativePath -in @($prunedLock.managedFiles.path)) {
        throw 'Prune retained an unmodified orphaned file or lock entry.'
    }
    if (-not (Get-ChildItem -LiteralPath (Join-Path $testRoot '.harness-backup') -Recurse -Filter 'retired-managed.md' -File | Select-Object -First 1)) {
        throw 'Prune did not back up the orphaned file before removal.'
    }

    Add-Content -LiteralPath $targetStatus -Value "`n# Local conflicting update"
    Add-Content -LiteralPath $upstreamStatus -Value "`n# Second upstream update"
    $conflictBytes = [IO.File]::ReadAllBytes($targetStatus)
    $lockBytes = [IO.File]::ReadAllBytes((Join-Path $testRoot 'harness.lock.json'))
    Assert-ScriptFails -Path $updateInitializer -Arguments @('-TargetPath', $testRoot, '-Update')
    if ([Convert]::ToBase64String($conflictBytes) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($targetStatus))) {
        throw 'Conflicting update changed the local file.'
    }
    if ([Convert]::ToBase64String($lockBytes) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $testRoot 'harness.lock.json')))) {
        throw 'Conflicting update changed the lock file.'
    }

    $validConfig = Get-Content -LiteralPath $configPath -Raw
    $brokenConfig = $validConfig | ConvertFrom-Json
    $brokenConfig.requiredPaths = 'AGENTS.md'
    $brokenConfig | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8
    Assert-ScriptFails -Path (Join-Path $testRoot 'scripts\check-harness.ps1')
    [IO.File]::WriteAllText($configPath, $validConfig, (New-Object Text.UTF8Encoding($false)))

    $escapeConfig = $validConfig | ConvertFrom-Json
    $escapeConfig.requiredPaths = @($escapeConfig.requiredPaths) + '../outside.md'
    $escapeConfig | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8
    Assert-ScriptFails -Path (Join-Path $testRoot 'scripts\check-harness.ps1')
    [IO.File]::WriteAllText($configPath, $validConfig, (New-Object Text.UTF8Encoding($false)))

    $readinessScript = Join-Path $testRoot 'scripts\check-readiness.ps1'
    $readinessBackup = Join-Path $testRoot 'scripts\check-readiness.ps1.bak'
    Move-Item -LiteralPath $readinessScript -Destination $readinessBackup
    New-Item -ItemType Directory -Path $readinessScript | Out-Null
    Assert-ScriptFails -Path (Join-Path $testRoot 'scripts\check-harness.ps1')
    Remove-Item -LiteralPath $readinessScript -Recurse -Force
    Move-Item -LiteralPath $readinessBackup -Destination $readinessScript

    & $initializer -TargetPath $lightRoot -Profile Light -ProjectName 'Light Project'
    if (Test-Path -LiteralPath (Join-Path $lightRoot 'docs\decisions\README.md')) {
        throw 'Light profile unexpectedly installed Standard files.'
    }
    if ((Get-Content -LiteralPath (Join-Path $lightRoot 'CLAUDE.md') -Raw).Trim() -ne '@AGENTS.md') {
        throw 'Light profile did not create the Claude Code entrypoint.'
    }
    & (Join-Path $lightRoot 'scripts\verify.ps1') -Scope Harness
    if (-not $?) {
        throw 'Light harness verification failed.'
    }

    & $initializer -TargetPath $whatIfRoot -Profile Standard -ProjectName 'WhatIf Project' -WhatIf
    if (-not $?) {
        throw 'Initializer -WhatIf failed for a new target directory.'
    }
    if (Test-Path -LiteralPath $whatIfRoot) {
        throw 'Initializer -WhatIf unexpectedly created the target directory.'
    }

    Write-Host 'Initialization smoke test passed.'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $lightRoot) {
        Remove-Item -LiteralPath $lightRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $updateSourceRoot) {
        Remove-Item -LiteralPath $updateSourceRoot -Recurse -Force
    }
}
