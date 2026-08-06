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

function Get-ProjectValidationDirectory {
    param(
        [Parameter(Mandatory = $true)][object]$Check,
        [Parameter(Mandatory = $true)][string]$RepositoryRoot
    )

    $property = $Check.PSObject.Properties['workingDirectory']
    if ($null -eq $property) {
        return $RepositoryRoot
    }

    $relativePath = [string]$property.Value
    if ([string]::IsNullOrWhiteSpace($relativePath) -or [IO.Path]::IsPathRooted($relativePath)) {
        throw "workingDirectory must be a nonempty repository-relative path: $($Check.name)"
    }

    $candidate = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $relativePath))
    $rootPrefix = $RepositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "workingDirectory escapes the repository: $($Check.name)"
    }
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        throw "workingDirectory does not exist: $relativePath ($($Check.name))"
    }
    return $candidate
}

function Get-ProjectValidationEnvironment {
    param([Parameter(Mandatory = $true)][object]$Check)

    $environment = @{}
    $property = $Check.PSObject.Properties['environment']
    if ($null -eq $property) {
        return $environment
    }

    if ($null -eq $property.Value -or $property.Value -is [System.Array] -or $property.Value -is [string]) {
        throw "environment must be an object: $($Check.name)"
    }

    foreach ($entry in $property.Value.PSObject.Properties) {
        if ($entry.Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $entry.Value -isnot [string]) {
            throw "environment must contain string variable names and values: $($Check.name)"
        }
        $environment[$entry.Name] = [string]$entry.Value
    }
    return $environment
}

function Get-ProjectValidationTimeout {
    param([Parameter(Mandatory = $true)][object]$Check)

    $property = $Check.PSObject.Properties['timeoutSeconds']
    if ($null -eq $property) {
        return 0
    }
    try {
        $timeout = [int]$property.Value
    } catch {
        throw "timeoutSeconds must be a positive integer: $($Check.name)"
    }
    if ($timeout -lt 1) {
        throw "timeoutSeconds must be a positive integer: $($Check.name)"
    }
    return $timeout
}

function Invoke-ProjectValidation {
    param(
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][hashtable]$Environment,
        [int]$TimeoutSeconds
    )

    if ($TimeoutSeconds -eq 0) {
        $previousEnvironment = @{}
        foreach ($entry in $Environment.GetEnumerator()) {
            $existing = Get-Item -LiteralPath ("Env:" + $entry.Key) -ErrorAction SilentlyContinue
            $previousEnvironment[$entry.Key] = if ($null -eq $existing) { $null } else { [string]$existing.Value }
            Set-Item -LiteralPath ("Env:" + $entry.Key) -Value $entry.Value
        }

        Push-Location $WorkingDirectory
        try {
            # Native stderr must not turn an otherwise reported exit code into a terminating PowerShell 5.1 error.
            $ErrorActionPreference = 'Continue'
            & $Executable @Arguments | Out-Default
            return [pscustomobject]@{ TimedOut = $false; ExitCode = $LASTEXITCODE }
        } finally {
            Pop-Location
            foreach ($entry in $previousEnvironment.GetEnumerator()) {
                if ($null -eq $entry.Value) {
                    Remove-Item -LiteralPath ("Env:" + $entry.Key) -ErrorAction SilentlyContinue
                } else {
                    Set-Item -LiteralPath ("Env:" + $entry.Key) -Value $entry.Value
                }
            }
        }
    }

    $job = Start-Job -ScriptBlock {
        param($JobWorkingDirectory, $JobExecutable, $JobArguments, $JobEnvironment)

        $ErrorActionPreference = 'Continue'
        Push-Location $JobWorkingDirectory
        try {
            foreach ($entry in $JobEnvironment.GetEnumerator()) {
                Set-Item -LiteralPath ("Env:" + $entry.Key) -Value $entry.Value
            }
            & $JobExecutable @JobArguments | Out-Default
            [pscustomobject]@{ ProjectHarnessValidationResult = $true; ExitCode = $LASTEXITCODE }
        } finally {
            Pop-Location
        }
    } -ArgumentList $WorkingDirectory, $Executable, (, $Arguments), $Environment

    try {
        if ($null -eq (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
            Stop-Job -Job $job | Out-Null
            Receive-Job -Job $job -ErrorAction Continue | Out-Default
            return [pscustomobject]@{ TimedOut = $true; ExitCode = $null }
        }

        $output = @(Receive-Job -Job $job -ErrorAction Continue)
        $result = @($output | Where-Object {
            $marker = $_.PSObject.Properties['ProjectHarnessValidationResult']
            $null -ne $marker -and [bool]$marker.Value
        } | Select-Object -Last 1)
        @($output | Where-Object {
            $marker = $_.PSObject.Properties['ProjectHarnessValidationResult']
            $null -eq $marker -or -not [bool]$marker.Value
        }) | Out-Default
        if ($result.Count -ne 1) {
            throw 'Timed project validation did not return an exit code.'
        }
        return [pscustomobject]@{ TimedOut = $false; ExitCode = [int]$result[0].ExitCode }
    } finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

if ($Scope -in @('Harness', 'All')) {
    Invoke-CheckedScript -Path (Join-Path $PSScriptRoot 'check-harness.ps1')

    $driftScript = Join-Path $PSScriptRoot 'check-doc-drift.ps1'
    if (Test-Path -LiteralPath $driftScript -PathType Leaf) {
        Invoke-CheckedScript -Path $driftScript
    }

    $catalogScript = Join-Path $PSScriptRoot 'check-artifact-catalog.ps1'
    if (Test-Path -LiteralPath $catalogScript -PathType Leaf) {
        Invoke-CheckedScript -Path $catalogScript
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
            foreach ($check in $checks) {
                    $executable = [string]$check.executable
                    $arguments = @($check.arguments | ForEach-Object { [string]$_ })
                    if (-not (Get-Command $executable -ErrorAction SilentlyContinue)) {
                        Write-Host "FAIL  $($check.name): executable not found: $executable" -ForegroundColor Red
                        $hasFailure = $true
                        continue
                    }

                    try {
                        $workingDirectory = Get-ProjectValidationDirectory -Check $check -RepositoryRoot $repositoryRoot
                        $environment = Get-ProjectValidationEnvironment -Check $check
                        $timeoutSeconds = Get-ProjectValidationTimeout -Check $check
                        Write-Host "RUN   $($check.name)"
                        $result = Invoke-ProjectValidation -WorkingDirectory $workingDirectory -Executable $executable -Arguments $arguments -Environment $environment -TimeoutSeconds $timeoutSeconds
                    } catch {
                        Write-Host "FAIL  $($check.name): $($_.Exception.Message)" -ForegroundColor Red
                        $hasFailure = $true
                        continue
                    }

                    if ($result.TimedOut) {
                        Write-Host "FAIL  $($check.name) timed out after $timeoutSeconds seconds" -ForegroundColor Red
                        $hasFailure = $true
                    } elseif ($result.ExitCode -ne 0) {
                        Write-Host "FAIL  $($check.name) exited with code $($result.ExitCode)" -ForegroundColor Red
                        $hasFailure = $true
                    } else {
                        Write-Host "PASS  $($check.name)" -ForegroundColor Green
                    }
                }
        }
    }
}

if ($hasFailure) {
    exit 1
}

Write-Host "Verification scope '$Scope' completed." -ForegroundColor Green
