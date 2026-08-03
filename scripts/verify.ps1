[CmdletBinding()]
param(
    [ValidateSet('Harness', 'Project', 'All')]
    [string]$Scope = 'Harness'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repositoryRoot 'harness.config.json'
$hasFailure = $false

function Invoke-CheckedScript {
    param([Parameter(Mandatory = $true)][string]$Path)

    & $Path
    if (-not $?) {
        $script:hasFailure = $true
    }
}

if ($Scope -in @('Harness', 'All')) {
    Invoke-CheckedScript -Path (Join-Path $PSScriptRoot 'check-harness.ps1')

    $driftScript = Join-Path $PSScriptRoot 'check-doc-drift.ps1'
    if (Test-Path -LiteralPath $driftScript -PathType Leaf) {
        Invoke-CheckedScript -Path $driftScript
    }
}

if ($Scope -eq 'All') {
    Invoke-CheckedScript -Path (Join-Path $PSScriptRoot 'check-readiness.ps1')
}

if ($Scope -in @('Project', 'All')) {
    if ($Scope -eq 'All' -and $hasFailure) {
        Write-Host 'SKIP  Project validation because Harness or readiness checks failed.' -ForegroundColor Yellow
    } else {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $checks = @($config.projectValidation)

        if ($checks.Count -eq 0) {
            Write-Host 'WARN  No project validation commands are configured.' -ForegroundColor Yellow
        } else {
            Push-Location $repositoryRoot
            try {
                foreach ($check in $checks) {
                    $executable = [string]$check.executable
                    $arguments = @($check.arguments | ForEach-Object { [string]$_ })
                    if (-not (Get-Command $executable -ErrorAction SilentlyContinue)) {
                        Write-Host "FAIL  $($check.name): executable not found: $executable" -ForegroundColor Red
                        $hasFailure = $true
                        continue
                    }

                    Write-Host "RUN   $($check.name)"
                    & $executable @arguments
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "FAIL  $($check.name) exited with code $LASTEXITCODE" -ForegroundColor Red
                        $hasFailure = $true
                    } else {
                        Write-Host "PASS  $($check.name)" -ForegroundColor Green
                    }
                }
            } finally {
                Pop-Location
            }
        }
    }
}

if ($hasFailure) {
    exit 1
}

Write-Host "Verification scope '$Scope' completed." -ForegroundColor Green
