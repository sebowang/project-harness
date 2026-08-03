$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$lockPath = Join-Path $repositoryRoot 'harness.lock.json'
$configPath = Join-Path $repositoryRoot 'harness.config.json'

$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$counts = @{ Clean = 0; Modified = 0; Missing = 0; Unmanaged = 0 }

Write-Host "Harness version : $($lock.harnessVersion)"
Write-Host "Profile         : $($lock.profile)"
Write-Host "Project         : $($lock.projectName)"
Write-Host ''

foreach ($file in @($lock.managedFiles) | Sort-Object path) {
    $path = Join-Path $repositoryRoot ([string]$file.path)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Write-Host "MISSING    $($file.path)" -ForegroundColor Red
        $counts.Missing++
        continue
    }

    if ([string]::IsNullOrWhiteSpace([string]$file.baselineHash)) {
        Write-Host "UNMANAGED  $($file.path)" -ForegroundColor Yellow
        $counts.Unmanaged++
        continue
    }

    $currentHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($currentHash -eq [string]$file.baselineHash) {
        Write-Host "CLEAN      $($file.path)"
        $counts.Clean++
    } else {
        Write-Host "MODIFIED   $($file.path)" -ForegroundColor Yellow
        $counts.Modified++
    }
}

Write-Host ''
Write-Host "Managed files: clean=$($counts.Clean) modified=$($counts.Modified) missing=$($counts.Missing) unmanaged=$($counts.Unmanaged)"
Write-Host "Configured validation commands: $(@($config.projectValidation).Count)"

if ($counts.Missing -gt 0) {
    exit 1
}
