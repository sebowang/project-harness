[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$git = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $git) {
    throw 'Git is required to configure repository hooks.'
}

$gitRoot = (& $git.Source -C $repositoryRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$gitRoot)) {
    throw 'Project Harness is not inside a Git worktree.'
}
if ([IO.Path]::GetFullPath([string]$gitRoot) -ne [IO.Path]::GetFullPath($repositoryRoot)) {
    throw 'Run the hook installer from the repository root that contains Project Harness.'
}

$currentHooksPath = (& $git.Source -C $repositoryRoot config --local --get core.hooksPath 2>$null)
if ($LASTEXITCODE -ne 0) {
    $currentHooksPath = $null
}
$currentHooksPath = ([string]$currentHooksPath).Trim()

if ($Uninstall) {
    if ([string]::IsNullOrWhiteSpace($currentHooksPath)) {
        Write-Host 'SKIP  No local core.hooksPath is configured.'
        exit 0
    }
    if ($currentHooksPath.Replace('\', '/') -ne '.githooks') {
        throw "Refusing to remove another hooks path: $currentHooksPath"
    }
    if ($PSCmdlet.ShouldProcess($repositoryRoot, 'Unset local Project Harness Git hooks path')) {
        & $git.Source -C $repositoryRoot config --local --unset core.hooksPath
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to unset local core.hooksPath.'
        }
        Write-Host 'UNINSTALL Project Harness Git hooks.' -ForegroundColor Green
    }
    exit 0
}

if (-not [string]::IsNullOrWhiteSpace($currentHooksPath) -and $currentHooksPath.Replace('\', '/') -ne '.githooks') {
    throw "Refusing to overwrite another hooks path: $currentHooksPath"
}

$hookPath = Join-Path $repositoryRoot '.githooks\pre-commit'
if (-not (Test-Path -LiteralPath $hookPath -PathType Leaf)) {
    throw 'Missing Project Harness pre-commit hook: .githooks/pre-commit'
}

if ($PSCmdlet.ShouldProcess($repositoryRoot, 'Configure local Project Harness Git hooks path')) {
    & $git.Source -C $repositoryRoot config --local core.hooksPath .githooks
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to configure local core.hooksPath.'
    }

    $chmod = Get-Command chmod -ErrorAction SilentlyContinue
    if ($null -ne $chmod) {
        & $chmod.Source '+x' $hookPath
    }
    Write-Host 'INSTALL Project Harness Git hooks.' -ForegroundColor Green
}
