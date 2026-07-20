$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repositoryRoot 'harness.config.json'
$errors = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Write-Error 'Missing harness.config.json.'
    exit 1
}

try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Invalid harness.config.json: $($_.Exception.Message)"
    exit 1
}

if ($config.schemaVersion -ne 1) {
    $errors.Add("Unsupported schemaVersion: $($config.schemaVersion)")
}

foreach ($relativePath in $config.requiredPaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath))) {
        $errors.Add("Missing required path: $relativePath")
    }
}

$skillRoots = @('.agents/skills', '.claude/skills')
foreach ($relativeSkillRoot in $skillRoots) {
    $skillRoot = Join-Path $repositoryRoot $relativeSkillRoot
    if (-not (Test-Path -LiteralPath $skillRoot -PathType Container)) {
        continue
    }

    foreach ($skillFile in Get-ChildItem -LiteralPath $skillRoot -Filter 'SKILL.md' -Recurse -File) {
        $content = Get-Content -LiteralPath $skillFile.FullName -Raw
        $relativePath = $skillFile.FullName.Substring($repositoryRoot.Length).TrimStart('\', '/')
        if ($content -notmatch '(?m)^name:\s*\S+') {
            $errors.Add("Skill is missing frontmatter name: $relativePath")
        }
        if ($content -notmatch '(?m)^description:\s*.+$') {
            $errors.Add("Skill is missing frontmatter description: $relativePath")
        }
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Host "FAIL  $message" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'PASS  Harness structure and configuration are valid.' -ForegroundColor Green
