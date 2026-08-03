$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$blockedPatterns = @(
    @{ Pattern = 'EasyBIM'; Description = 'private example project name' },
    @{ Pattern = 'Bow-Lin-project-harness'; Description = 'retired reference project name' },
    @{ Pattern = '[A-Za-z]:\\(?:Users|Work Space)\\'; Description = 'absolute user or workspace path' }
)
$textExtensions = @('.json', '.md', '.ps1', '.txt', '.yml', '.yaml')
$violations = New-Object System.Collections.Generic.List[string]

foreach ($relativePath in @(git -C $repositoryRoot ls-files)) {
    $extension = [IO.Path]::GetExtension($relativePath).ToLowerInvariant()
    if ($extension -notin $textExtensions) {
        continue
    }

    $path = Join-Path $repositoryRoot $relativePath
    $content = [IO.File]::ReadAllText($path)
    foreach ($blocked in $blockedPatterns) {
        if ($content -match $blocked.Pattern) {
            $violations.Add("$relativePath contains $($blocked.Description): $($blocked.Pattern)")
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Template neutrality check passed.'
