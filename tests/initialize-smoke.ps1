$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$initializer = Join-Path $repositoryRoot 'scripts\initialize-project.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-' + [Guid]::NewGuid().ToString('N'))
$lightRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-light-' + [Guid]::NewGuid().ToString('N'))
$whatIfRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-whatif-' + [Guid]::NewGuid().ToString('N'))
$migrationRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-migration-' + [Guid]::NewGuid().ToString('N'))
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

    $initializationOutput = (& $initializer -TargetPath $testRoot -Profile Standard -ProjectName 'Smoke Test Project' -MergeProjectRules 6>&1 | Out-String)
    if (-not $?) {
        throw 'Standard initialization failed.'
    }
    if ($initializationOutput -notmatch [regex]::Escape('scripts/install-git-hooks.ps1')) {
        throw 'Standard initialization did not disclose the optional Git Hook command.'
    }

    $expectedPaths = @(
        'AGENTS.md',
        'CLAUDE.md',
        '.trae\rules\project-harness.md',
        'harness.config.json',
        'harness.lock.json',
        'docs\project-map.md',
        'docs\verification.md',
        'docs\decisions\README.md',
        'docs\lessons\README.md',
        'docs\agent-compatibility.md',
        'docs\workflows\project-start.md',
        '.agents\skills\project-start\SKILL.md',
        '.claude\skills\project-start\SKILL.md',
        'scripts\check-readiness.ps1',
        'scripts\harness-status.ps1',
        'scripts\harness-doctor.ps1',
        'scripts\check-artifact-catalog.ps1',
        'scripts\update-artifact-catalog.ps1',
        'scripts\install-git-hooks.ps1',
        'scripts\verify.ps1',
        '.githooks\pre-commit',
        'tests\harness\README.md'
    )

    foreach ($relativePath in $expectedPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $testRoot $relativePath))) {
            throw "Missing generated path: $relativePath"
        }
    }

    $mergedExistingAgents = [IO.File]::ReadAllText($existingAgents)
    if ($mergedExistingAgents -notmatch [regex]::Escape('# Existing rules') -or $mergedExistingAgents -notmatch '<!-- PROJECT-HARNESS:BEGIN -->') {
        throw 'Existing AGENTS.md was not preserved and connected through the Harness block.'
    }
    $managedBlockMatches = [regex]::Matches($mergedExistingAgents, '(?s)<!-- PROJECT-HARNESS:BEGIN -->.*?<!-- PROJECT-HARNESS:END -->')
    $expectedManagedBlock = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'templates\partials\agents-harness-block.md')).TrimEnd().Replace("`r`n", "`n")
    if ($managedBlockMatches.Count -ne 1 -or $managedBlockMatches[0].Value.TrimEnd().Replace("`r`n", "`n") -ne $expectedManagedBlock) {
        throw 'Merged AGENTS.md does not contain exactly the current Harness managed block.'
    }

    $claudeEntry = [IO.File]::ReadAllText((Join-Path $testRoot 'CLAUDE.md')).Trim()
    if ($claudeEntry -ne '@AGENTS.md') {
        throw 'CLAUDE.md does not import AGENTS.md.'
    }

    $traeEntry = [IO.File]::ReadAllText((Join-Path $testRoot '.trae\rules\project-harness.md'))
    if ($traeEntry -notmatch 'AGENTS\.md' -or $traeEntry -notmatch 'docs/workflows/') {
        throw 'Trae project rule does not route to AGENTS.md and public workflows.'
    }

    $workflowNames = @('project-start', 'project-onboarding', 'change-plan', 'adversarial-review', 'harness-authoring', 'project-handoff', 'testing', 'systematic-debugging', 'durable-plan', 'knowledge-capture')
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

    $customSkillPath = Join-Path $testRoot '.agents\skills\project-specific\SKILL.md'
    New-Item -ItemType Directory -Path (Split-Path -Parent $customSkillPath) -Force | Out-Null
    [IO.File]::WriteAllText($customSkillPath, "---`nname: project-specific`ndescription: Project-owned Codex-only workflow.`n---`n", (New-Object Text.UTF8Encoding($false)))
    & (Join-Path $testRoot 'scripts\check-harness.ps1')
    if (-not $?) {
        throw 'Harness check rejected a project-owned single-tool Skill.'
    }
    Remove-Item -LiteralPath (Split-Path -Parent $customSkillPath) -Recurse -Force

    $pairedSkillPath = Join-Path $testRoot '.claude\skills\project-start\SKILL.md'
    $pairedSkillBytes = [IO.File]::ReadAllBytes($pairedSkillPath)
    [IO.File]::WriteAllText($pairedSkillPath, "---`nname: project-start`ndescription: Drifted wrapper.`n---`n", (New-Object Text.UTF8Encoding($false)))
    Assert-ScriptFails -Path (Join-Path $testRoot 'scripts\check-harness.ps1')
    [IO.File]::WriteAllBytes($pairedSkillPath, $pairedSkillBytes)

    $projectMap = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\project-map.md'))
    if ($projectMap -notmatch 'Smoke Test Project') {
        throw 'Project name placeholder was not replaced.'
    }
    if ($projectMap -notmatch [regex]::Escape('Project-owned layout')) {
        throw 'Generated project map does not explain project-owned directory layouts.'
    }

    & (Join-Path $testRoot 'scripts\verify.ps1') -Scope Harness
    if (-not $?) {
        throw 'Generated harness verification failed.'
    }

    $catalogCheck = Join-Path $testRoot 'scripts\check-artifact-catalog.ps1'
    $catalogUpdate = Join-Path $testRoot 'scripts\update-artifact-catalog.ps1'
    $catalogIndex = Join-Path $testRoot 'tests\harness\README.md'
    $catalogScript = Join-Path $testRoot 'tests\harness\sample-check.ps1'
    [IO.File]::WriteAllText($catalogScript, "Write-Host 'sample'`n", (New-Object Text.UTF8Encoding($false)))
    Assert-ScriptFails -Path $catalogCheck
    & $catalogUpdate
    if (-not $?) {
        throw 'Artifact catalog update failed.'
    }
    & $catalogCheck
    if (-not $?) {
        throw 'Updated artifact catalog did not pass verification.'
    }
    $catalogBytes = [IO.File]::ReadAllBytes($catalogIndex)
    & $catalogUpdate
    if ([Convert]::ToBase64String($catalogBytes) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes($catalogIndex))) {
        throw 'Repeated artifact catalog generation was not byte-identical.'
    }

    $catalogContent = [IO.File]::ReadAllText($catalogIndex)
    [IO.File]::WriteAllText($catalogIndex, $catalogContent.Replace('<!-- PROJECT-HARNESS:CATALOG:END -->', '<!-- BROKEN -->'), (New-Object Text.UTF8Encoding($false)))
    Assert-ScriptFails -Path $catalogCheck
    [IO.File]::WriteAllBytes($catalogIndex, $catalogBytes)

    & git -C $testRoot init --quiet
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to initialize temporary Git repository for Hook checks.'
    }
    & git -C $testRoot add -- 'tests/harness/sample-check.ps1' 'tests/harness/README.md'
    $catalogSecondScript = Join-Path $testRoot 'tests\harness\second-check.ps1'
    [IO.File]::WriteAllText($catalogSecondScript, "Write-Host 'second'`n", (New-Object Text.UTF8Encoding($false)))
    & git -C $testRoot add -- 'tests/harness/second-check.ps1'
    Assert-ScriptFails -Path $catalogCheck -Arguments @('-Staged')
    & $catalogUpdate
    Assert-ScriptFails -Path $catalogCheck -Arguments @('-Staged')
    & git -C $testRoot add -- 'tests/harness/README.md'
    & $catalogCheck -Staged
    if (-not $?) {
        throw 'Staged artifact catalog check rejected a synchronized index.'
    }

    $hookInstaller = Join-Path $testRoot 'scripts\install-git-hooks.ps1'
    & git -C $testRoot config --local core.hooksPath existing-hooks
    Assert-ScriptFails -Path $hookInstaller
    Assert-ScriptFails -Path $hookInstaller -Arguments @('-Uninstall')
    & git -C $testRoot config --local --unset core.hooksPath
    & $hookInstaller
    if ((& git -C $testRoot config --local --get core.hooksPath) -ne '.githooks') {
        throw 'Hook installer did not configure .githooks.'
    }
    & $hookInstaller -Uninstall
    $hooksAfterUninstall = (& git -C $testRoot config --local --get core.hooksPath 2>$null)
    if ($LASTEXITCODE -eq 0 -or -not [string]::IsNullOrWhiteSpace([string]$hooksAfterUninstall)) {
        throw 'Hook uninstall did not remove the local Project Harness hooks path.'
    }

    Remove-Item -LiteralPath $catalogScript, $catalogSecondScript -Force
    & $catalogUpdate
    & $catalogCheck
    if (-not $?) {
        throw 'Artifact catalog did not return to a clean empty state.'
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
        foreach ($file in Get-ChildItem -LiteralPath $layerRoot -Recurse -File -Force) {
            $relativePath = $file.FullName.Substring($layerRoot.Length).TrimStart('\', '/').Replace('\', '/')
            $templateFilePaths += $relativePath
        }
    }

    $onboardingWorkflow = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\workflows\project-onboarding.md'))
    if ($onboardingWorkflow -notmatch [regex]::Escape('.gitlab-ci.yml') -or $onboardingWorkflow -notmatch [regex]::Escape('.cnb.yml')) {
        throw 'Project onboarding does not identify GitLab CI and CNB configuration files.'
    }
    if ($onboardingWorkflow -notmatch [regex]::Escape('scripts/install-git-hooks.ps1') -or $onboardingWorkflow -notmatch [regex]::Escape('core.hooksPath')) {
        throw 'Project onboarding does not surface the optional Git Hook decision.'
    }
    $ciCompatibility = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\ci-platform-compatibility.md'))
    if ($ciCompatibility -notmatch 'GitLab CI' -or $ciCompatibility -notmatch 'CNB') {
        throw 'Generated CI platform compatibility guidance is incomplete.'
    }
    if ($ciCompatibility -notmatch [regex]::Escape('examples/ci/') -or $ciCompatibility -notmatch [regex]::Escape('templates/manifest.json')) {
        throw 'Generated CI guidance does not explain that examples are outside initializer management.'
    }
    $verificationGuidance = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\verification.md'))
    if ($verificationGuidance -notmatch [regex]::Escape('harness-status.ps1') -or $verificationGuidance -notmatch [regex]::Escape('harness.lock.json')) {
        throw 'Generated verification guidance does not distinguish managed-file status from verification.'
    }
    $testingWorkflow = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\workflows\testing.md'))
    if ($testingWorkflow -notmatch [regex]::Escape('docs/verification.md') -or $testingWorkflow -notmatch 'schema' -or $testingWorkflow -notmatch [regex]::Escape('dry-run/preview')) {
        throw 'Generated testing workflow does not enforce risk-based verification escalation.'
    }
    $reviewWorkflow = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\workflows\adversarial-review.md'))
    if ($reviewWorkflow -notmatch 'lock') {
        throw 'Generated adversarial review does not cover dependency impact.'
    }
    $changePlanWorkflow = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\workflows\change-plan.md'))
    if ($changePlanWorkflow -notmatch [regex]::Escape('expected output') -or $changePlanWorkflow -notmatch [regex]::Escape('unacceptable behavior')) {
        throw 'Generated change plan does not define observable behavior and scope expansion.'
    }
    $durablePlanWorkflow = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\workflows\durable-plan.md'))
    if ($durablePlanWorkflow -notmatch [regex]::Escape('docs/active-plan.md') -or $durablePlanWorkflow -notmatch [regex]::Escape('Active | Blocked | Complete') -or $durablePlanWorkflow -notmatch [regex]::Escape('durable-plan')) {
        throw 'Generated durable plan workflow does not define mandatory long-task triggers.'
    }
    $handoffWorkflow = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\workflows\project-handoff.md'))
    $projectStartWorkflow = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\workflows\project-start.md'))
    if ($handoffWorkflow -notmatch [regex]::Escape('docs/handoff.md') -or $projectStartWorkflow -notmatch [regex]::Escape('docs/handoff.md')) {
        throw 'Generated workflows do not provide a fixed handoff discovery path.'
    }
    $knowledgeWorkflow = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\workflows\knowledge-capture.md'))
    if ($knowledgeWorkflow -notmatch [regex]::Escape('docs/lessons/') -or $knowledgeWorkflow -notmatch [regex]::Escape('AGENTS.md') -or $knowledgeWorkflow -notmatch [regex]::Escape('Skill') -or $knowledgeWorkflow -notmatch [regex]::Escape('accessible-context') -or $knowledgeWorkflow -notmatch [regex]::Escape('discovery-only')) {
        throw 'Generated knowledge capture workflow does not route durable knowledge and Skill promotion.'
    }
    $decisionReadme = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\decisions\README.md'))
    foreach ($decisionMarker in @('Decision Record', 'DECISION-NNN', 'System Invariant', 'Architecture Decision')) {
        if ($decisionReadme -notmatch [regex]::Escape($decisionMarker)) {
            throw "Generated decision guide is missing marker: $decisionMarker"
        }
    }
    $readmeGuides = @(
        @{ Path = (Join-Path $repositoryRoot 'README.md'); Markers = @('docs/usage-guide.md', '-MergeProjectRules', 'code/') },
        @{ Path = (Join-Path $repositoryRoot 'README.en.md'); Markers = @('How to Use It After Installation', 'docs/usage-guide.en.md', 'code/') },
        @{ Path = (Join-Path $repositoryRoot 'docs/usage-guide.md'); Markers = @('docs/active-plan.md', 'System Invariant', 'harness.config.json.projectValidation') },
        @{ Path = (Join-Path $repositoryRoot 'docs/usage-guide.en.md'); Markers = @('The Agent Workflow', 'System Invariant', 'harness.config.json.projectValidation') }
    )
    foreach ($readmeGuide in $readmeGuides) {
        $readmeContent = [IO.File]::ReadAllText($readmeGuide.Path)
        foreach ($readmeMarker in $readmeGuide.Markers) {
            if ($readmeContent -notmatch [regex]::Escape($readmeMarker)) {
                throw "Public README is missing user guidance marker '$readmeMarker': $($readmeGuide.Path)"
            }
        }
    }
    $onboardingWorkflow = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\workflows\project-onboarding.md'))
    foreach ($projectOwnedDirectory in @('code/', 'src/', 'assets/', 'notes/')) {
        if ($onboardingWorkflow -notmatch [regex]::Escape($projectOwnedDirectory)) {
            throw "Generated onboarding workflow does not preserve project-owned directory: $projectOwnedDirectory"
        }
    }
    if ($onboardingWorkflow -notmatch [regex]::Escape('harness.config.json')) {
        throw 'Generated onboarding workflow does not preserve project-owned source layouts.'
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
            executable = [IO.Path]::GetFileNameWithoutExtension($powerShellExecutable)
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
    if ([IO.File]::ReadAllText($existingAgents) -ne $mergedExistingAgents) {
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

    $catalogEscapeConfig = $validConfig | ConvertFrom-Json
    $catalogEscapeConfig.artifactCatalogs[0].directory = '../outside'
    $catalogEscapeConfig | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8
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
    $lightConfig = Get-Content -LiteralPath (Join-Path $lightRoot 'harness.config.json') -Raw | ConvertFrom-Json
    if (@($lightConfig.artifactCatalogs).Count -ne 0 -or (Test-Path -LiteralPath (Join-Path $lightRoot 'scripts\check-artifact-catalog.ps1'))) {
        throw 'Light profile unexpectedly enabled artifact catalogs.'
    }
    & (Join-Path $lightRoot 'scripts\verify.ps1') -Scope Harness
    if (-not $?) {
        throw 'Light harness verification failed.'
    }

    New-Item -ItemType Directory -Path $migrationRoot -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $migrationRoot 'AGENTS.md'), "# Existing rules`n", (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $migrationRoot 'CLAUDE.md'), "# Legacy duplicated rules`n", (New-Object Text.UTF8Encoding($false)))
    & $initializer -TargetPath $migrationRoot -Profile Light -ProjectName 'Migration Project'
    & (Join-Path $migrationRoot 'scripts\check-harness.ps1')
    if ($LASTEXITCODE -eq 0) {
        throw 'Harness check accepted an invalid pre-existing CLAUDE.md entrypoint.'
    }
    & $initializer -TargetPath $migrationRoot -Profile Light -ProjectName 'Migration Project' -Force
    if (-not $?) {
        throw 'Explicit managed-file migration failed.'
    }
    if ((Get-Content -LiteralPath (Join-Path $migrationRoot 'CLAUDE.md') -Raw).Trim() -ne '@AGENTS.md') {
        throw 'Managed-file migration did not repair CLAUDE.md.'
    }
    $migrationLock = Get-Content -LiteralPath (Join-Path $migrationRoot 'harness.lock.json') -Raw | ConvertFrom-Json
    $migrationClaude = $migrationLock.managedFiles | Where-Object { $_.path -eq 'CLAUDE.md' } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace([string]$migrationClaude.baselineHash)) {
        throw 'Managed-file migration did not establish a trusted CLAUDE.md baseline.'
    }
    if (-not (Get-ChildItem -LiteralPath (Join-Path $migrationRoot '.harness-backup') -Recurse -Filter 'CLAUDE.md' -File | Select-Object -First 1)) {
        throw 'Managed-file migration did not back up the previous CLAUDE.md.'
    }
    & $initializer -TargetPath $migrationRoot -Profile Light -ProjectName 'Migration Project' -MergeProjectRules
    if (-not $?) {
        throw 'Explicit project-rules merge failed.'
    }
    $mergedAgents = Get-Content -LiteralPath (Join-Path $migrationRoot 'AGENTS.md') -Raw
    if ($mergedAgents -notmatch [regex]::Escape('# Existing rules') -or $mergedAgents -notmatch '<!-- PROJECT-HARNESS:BEGIN -->') {
        throw 'Project-rules merge did not preserve existing rules and append the Harness block.'
    }
    $mergedAgentsBytes = [IO.File]::ReadAllBytes((Join-Path $migrationRoot 'AGENTS.md'))
    & $initializer -TargetPath $migrationRoot -Profile Light -ProjectName 'Migration Project' -MergeProjectRules
    if (-not $?) {
        throw 'Repeated project-rules merge failed.'
    }
    $remergedAgents = Get-Content -LiteralPath (Join-Path $migrationRoot 'AGENTS.md') -Raw
    if (([regex]::Matches($remergedAgents, '<!-- PROJECT-HARNESS:BEGIN -->')).Count -ne 1) {
        throw 'Repeated project-rules merge duplicated the Harness block.'
    }
    if ([Convert]::ToBase64String($mergedAgentsBytes) -ne [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $migrationRoot 'AGENTS.md')))) {
        throw 'Repeated project-rules merge rewrote an already current AGENTS.md.'
    }
    if (-not (Get-ChildItem -LiteralPath (Join-Path $migrationRoot '.harness-backup') -Recurse -Filter 'AGENTS.md' -File | Select-Object -First 1)) {
        throw 'Project-rules merge did not back up the previous AGENTS.md.'
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
    if (Test-Path -LiteralPath $migrationRoot) {
        Remove-Item -LiteralPath $migrationRoot -Recurse -Force
    }
}

exit 0
