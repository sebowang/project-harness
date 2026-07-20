$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$initializer = Join-Path $repositoryRoot 'scripts\initialize-project.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-' + [Guid]::NewGuid().ToString('N'))
$lightRoot = Join-Path ([IO.Path]::GetTempPath()) ('project-harness-light-' + [Guid]::NewGuid().ToString('N'))

try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $existingAgents = Join-Path $testRoot 'AGENTS.md'
    [IO.File]::WriteAllText($existingAgents, "# Existing rules`r`n", (New-Object Text.UTF8Encoding($false)))

    & $initializer -TargetPath $testRoot -Profile Standard -ProjectName 'Smoke Test Project'

    $expectedPaths = @(
        'AGENTS.md',
        'harness.config.json',
        'docs\project-map.md',
        'docs\verification.md',
        'docs\decisions\README.md',
        '.agents\skills\project-start\SKILL.md',
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

    $projectMap = [IO.File]::ReadAllText((Join-Path $testRoot 'docs\project-map.md'))
    if ($projectMap -notmatch 'Smoke Test Project') {
        throw 'Project name placeholder was not replaced.'
    }

    & (Join-Path $testRoot 'scripts\verify.ps1') -Scope Harness
    if (-not $?) {
        throw 'Generated harness verification failed.'
    }

    $configPath = Join-Path $testRoot 'harness.config.json'
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $config.projectValidation = @(
        [pscustomobject]@{
            name = 'Smoke project command'
            executable = 'powershell'
            arguments = @('-NoProfile', '-Command', "Write-Output 'Project validation passed.'")
        }
    )
    $config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8

    & (Join-Path $testRoot 'scripts\verify.ps1') -Scope Project
    if (-not $?) {
        throw 'Structured project validation failed.'
    }

    & $initializer -TargetPath $lightRoot -Profile Light -ProjectName 'Light Project'
    if (Test-Path -LiteralPath (Join-Path $lightRoot 'docs\decisions\README.md')) {
        throw 'Light profile unexpectedly installed Standard files.'
    }
    & (Join-Path $lightRoot 'scripts\verify.ps1') -Scope Harness
    if (-not $?) {
        throw 'Light harness verification failed.'
    }

    Write-Host 'Initialization smoke test passed.'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
    if (Test-Path -LiteralPath $lightRoot) {
        Remove-Item -LiteralPath $lightRoot -Recurse -Force
    }
}
