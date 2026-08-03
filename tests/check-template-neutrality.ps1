$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$forwardSlash = [char]47
$backwardSlash = [char]92
$eitherSlashPattern = '[\\' + $forwardSlash + ']'
$absolutePathPatterns = @(
    @{ Pattern = '(?<![A-Za-z0-9_])[A-Za-z]:' + $eitherSlashPattern + '[^\s"''`<>|]+'; Description = 'Windows absolute path' },
    @{ Pattern = '(?<![:/A-Za-z0-9_.-])' + $forwardSlash + '(?!' + $forwardSlash + ')' + '[^\s"''`<>|' + $forwardSlash + ']+(?:' + $forwardSlash + '[^\s"''`<>|' + $forwardSlash + ']+)+'; Description = 'Unix absolute path' }
)
$allowedPlaceholderPatterns = @(
    ('^[A-Za-z]:' + $eitherSlashPattern + 'path' + $eitherSlashPattern + 'to' + $eitherSlashPattern + '(?:your-)?repository$'),
    ('^' + $forwardSlash + 'path' + $forwardSlash + 'to' + $forwardSlash + '(?:your-)?repository$')
)
$textExtensions = @('.json', '.md', '.ps1', '.txt', '.yml', '.yaml')
$violations = New-Object System.Collections.Generic.List[string]

function Get-DisallowedAbsolutePaths {
    param([string]$Text)

    $contentWithoutUrls = $Text -replace 'https?://[^\s)>]+', ''
    foreach ($absolutePath in $absolutePathPatterns) {
        foreach ($match in [regex]::Matches($contentWithoutUrls, $absolutePath.Pattern)) {
            $isAllowedPlaceholder = $false
            foreach ($allowedPattern in $allowedPlaceholderPatterns) {
                if ($match.Value -match $allowedPattern) {
                    $isAllowedPlaceholder = $true
                    break
                }
            }
            if (-not $isAllowedPlaceholder) {
                [pscustomobject]@{ Value = $match.Value; Description = $absolutePath.Description }
            }
        }
    }
}

$requiredDetectionSamples = @(
    ('D:' + $backwardSlash + 'dev' + $backwardSlash + 'myproject')
    ('C:' + $backwardSlash + 'Projects' + $backwardSlash + 'foo')
    ($forwardSlash + 'home' + $forwardSlash + 'alice' + $forwardSlash + 'code')
    ($forwardSlash + 'Users' + $forwardSlash + 'alice' + $forwardSlash + 'code')
)
foreach ($sample in $requiredDetectionSamples) {
    if (@(Get-DisallowedAbsolutePaths -Text $sample).Count -eq 0) {
        throw "Absolute path regression sample was not detected: $sample"
    }
}

$allowedPlaceholderSamples = @(
    ('C:' + $backwardSlash + 'path' + $backwardSlash + 'to' + $backwardSlash + 'repository')
    ($forwardSlash + 'path' + $forwardSlash + 'to' + $forwardSlash + 'repository')
)
foreach ($sample in $allowedPlaceholderSamples) {
    if (@(Get-DisallowedAbsolutePaths -Text $sample).Count -ne 0) {
        throw "Generic path placeholder was rejected: $sample"
    }
}

foreach ($relativePath in @(git -C $repositoryRoot ls-files)) {
    $extension = [IO.Path]::GetExtension($relativePath).ToLowerInvariant()
    if ($extension -notin $textExtensions) {
        continue
    }

    $path = Join-Path $repositoryRoot $relativePath
    $lineNumber = 0
    foreach ($line in [IO.File]::ReadLines($path)) {
        $lineNumber++
        foreach ($match in @(Get-DisallowedAbsolutePaths -Text $line)) {
            $violations.Add("$relativePath`:$lineNumber contains $($match.Description): $($match.Value)")
        }
    }
}

if ($violations.Count -gt 0) {
    $violations | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host 'Template neutrality check passed.'
