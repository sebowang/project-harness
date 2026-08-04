[CmdletBinding()]
param(
    [switch]$Staged
)

$ErrorActionPreference = 'Stop'

& (Join-Path $PSScriptRoot 'update-artifact-catalog.ps1') -Check -Staged:$Staged
if (-not $?) {
    exit 1
}
