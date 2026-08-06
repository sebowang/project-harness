$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repositoryRoot 'harness.config.json'
$lockPath = Join-Path $repositoryRoot 'harness.lock.json'
$errors = New-Object System.Collections.Generic.List[string]

function Get-CheckedRepositoryPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $rootPrefix = $repositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
    if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    return $candidate
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Write-Error 'Missing harness.config.json.'
    exit 1
}

if (-not (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
    Write-Error 'Missing harness.lock.json.'
    exit 1
}

try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Invalid harness.config.json: $($_.Exception.Message)"
    exit 1
}

try {
    $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Invalid harness.lock.json: $($_.Exception.Message)"
    exit 1
}

if ($lock.schemaVersion -ne 1) {
    $errors.Add("Unsupported lock schemaVersion: $($lock.schemaVersion)")
}
if ([string]::IsNullOrWhiteSpace([string]$lock.harnessVersion)) {
    $errors.Add('Missing lock harnessVersion')
}
if ($null -eq $lock.PSObject.Properties['managedFiles'] -or $lock.managedFiles -isnot [System.Array]) {
    $errors.Add('Lock managedFiles must be an array')
}

if ($config.schemaVersion -ne 1) {
    $errors.Add("Unsupported schemaVersion: $($config.schemaVersion)")
}

if ([string]::IsNullOrWhiteSpace([string]$config.harnessVersion)) {
    $errors.Add('Missing harnessVersion')
}

if ($config.profile -notin @('Light', 'Standard')) {
    $errors.Add("Unsupported profile: $($config.profile)")
}

foreach ($propertyName in @('requiredPaths', 'projectValidation', 'driftChecks')) {
    $property = $config.PSObject.Properties[$propertyName]
    if ($null -eq $property -or $null -eq $property.Value -or $property.Value -isnot [System.Array]) {
        $errors.Add("Configuration property must be an array: $propertyName")
    }
}

$readinessProperty = $config.PSObject.Properties['readiness']
if ($null -eq $readinessProperty -or $null -eq $readinessProperty.Value) {
    $errors.Add('Missing configuration object: readiness')
} else {
    $readiness = $readinessProperty.Value
    $requiredValidationProperty = $readiness.PSObject.Properties['requireProjectValidation']
    if ($null -eq $requiredValidationProperty -or $requiredValidationProperty.Value -isnot [bool]) {
        $errors.Add('readiness.requireProjectValidation must be a boolean')
    }
    $waiverProperty = $readiness.PSObject.Properties['projectValidationWaiver']
    if ($null -eq $waiverProperty -or ($null -ne $waiverProperty.Value -and $waiverProperty.Value -isnot [string])) {
        $errors.Add('readiness.projectValidationWaiver must be a string or null')
    }
    $requiredKindsProperty = $readiness.PSObject.Properties['requiredValidationKinds']
    if ($null -ne $requiredKindsProperty -and $requiredKindsProperty.Value -isnot [System.Array]) {
        $errors.Add('readiness.requiredValidationKinds must be an array when present')
    }
    if ($null -ne $requiredKindsProperty) {
        foreach ($kind in @($requiredKindsProperty.Value)) {
            if ([string]$kind -notin @('build', 'test', 'lint', 'smoke', 'custom')) {
                $errors.Add("Unsupported required validation kind: $kind")
            }
        }
    }
}

foreach ($relativePath in $config.requiredPaths) {
    $path = Get-CheckedRepositoryPath -RelativePath ([string]$relativePath)
    if ($null -eq $path) {
        $errors.Add("Required path escapes the repository: $relativePath")
    } elseif (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $errors.Add("Missing required path: $relativePath")
    }
}

$artifactCatalogProperty = $config.PSObject.Properties['artifactCatalogs']
if ($null -ne $artifactCatalogProperty -and $artifactCatalogProperty.Value -isnot [System.Array]) {
    $errors.Add('Configuration property must be an array: artifactCatalogs')
}

$agentsPath = Get-CheckedRepositoryPath -RelativePath 'AGENTS.md'
if ($null -ne $agentsPath -and (Test-Path -LiteralPath $agentsPath -PathType Leaf)) {
    $agentsContent = Get-Content -LiteralPath $agentsPath -Raw
    $agentsBeginCount = ([regex]::Matches($agentsContent, '<!-- PROJECT-HARNESS:BEGIN -->')).Count
    $agentsEndCount = ([regex]::Matches($agentsContent, '<!-- PROJECT-HARNESS:END -->')).Count
    if ($agentsBeginCount -ne 1 -or $agentsEndCount -ne 1) {
        $errors.Add('AGENTS.md is not connected to Project Harness rules; rerun initialize-project.ps1 with -MergeProjectRules')
    }
}

$claudePath = Get-CheckedRepositoryPath -RelativePath 'CLAUDE.md'
if ($null -ne $claudePath -and (Test-Path -LiteralPath $claudePath -PathType Leaf)) {
    $claudeItem = Get-Item -LiteralPath $claudePath -Force
    $claudeContent = Get-Content -LiteralPath $claudePath -Raw
    $isImportFile = $claudeContent.Trim() -eq '@AGENTS.md'
    $isAgentLink = ($claudeItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -and
        $claudeContent -eq (Get-Content -LiteralPath (Join-Path $repositoryRoot 'AGENTS.md') -Raw)
    if (-not $isImportFile -and -not $isAgentLink) {
        $errors.Add('CLAUDE.md must contain only @AGENTS.md or link to AGENTS.md so AGENTS.md remains the single rule source')
    }
}

$traePath = Get-CheckedRepositoryPath -RelativePath '.trae/rules/project-harness.md'
if ($null -ne $traePath -and (Test-Path -LiteralPath $traePath -PathType Leaf)) {
    $traeContent = Get-Content -LiteralPath $traePath -Raw
    if ($traeContent -notmatch 'AGENTS\.md' -or $traeContent -notmatch 'docs/workflows/') {
        $errors.Add('.trae/rules/project-harness.md must route to AGENTS.md and docs/workflows/')
    }
}

foreach ($check in @($config.projectValidation)) {
    if ([string]::IsNullOrWhiteSpace([string]$check.name)) {
        $errors.Add('Project validation entry is missing name')
    }
    if ([string]::IsNullOrWhiteSpace([string]$check.executable)) {
        $errors.Add("Project validation entry is missing executable: $($check.name)")
    }
    if ($null -eq $check.PSObject.Properties['arguments'] -or $check.arguments -isnot [System.Array]) {
        $errors.Add("Project validation arguments must be an array: $($check.name)")
    }
    $kindProperty = $check.PSObject.Properties['kind']
    if ($null -ne $kindProperty -and [string]$kindProperty.Value -notin @('build', 'test', 'lint', 'smoke', 'custom')) {
        $errors.Add("Unsupported project validation kind: $($check.kind)")
    }
    $workingDirectoryProperty = $check.PSObject.Properties['workingDirectory']
    if ($null -ne $workingDirectoryProperty) {
        $workingDirectory = $workingDirectoryProperty.Value
        if ($workingDirectory -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$workingDirectory) -or [IO.Path]::IsPathRooted([string]$workingDirectory)) {
            $errors.Add("Project validation workingDirectory must be a nonempty repository-relative path: $($check.name)")
        } else {
            $candidate = [IO.Path]::GetFullPath((Join-Path $repositoryRoot ([string]$workingDirectory)))
            $rootPrefix = $repositoryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $candidate -PathType Container)) {
                $errors.Add("Project validation workingDirectory does not exist inside the repository: $($check.name)")
            }
        }
    }
    $environmentProperty = $check.PSObject.Properties['environment']
    if ($null -ne $environmentProperty) {
        $environment = $environmentProperty.Value
        if ($null -eq $environment -or $environment -is [System.Array] -or $environment -is [string]) {
            $errors.Add("Project validation environment must be an object: $($check.name)")
        } else {
            foreach ($entry in $environment.PSObject.Properties) {
                if ($entry.Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $entry.Value -isnot [string]) {
                    $errors.Add("Project validation environment must contain string variable names and values: $($check.name)")
                    break
                }
            }
        }
    }
    $timeoutProperty = $check.PSObject.Properties['timeoutSeconds']
    if ($null -ne $timeoutProperty) {
        try {
            $timeout = [int]$timeoutProperty.Value
            if ($timeout -lt 1) { throw 'timeout must be positive' }
        } catch {
            $errors.Add("Project validation timeoutSeconds must be a positive integer: $($check.name)")
        }
    }
}

foreach ($check in @($config.driftChecks)) {
    foreach ($propertyName in @('description', 'path', 'pattern')) {
        if ([string]::IsNullOrWhiteSpace([string]$check.$propertyName)) {
            $errors.Add("Drift check is missing $propertyName")
        }
    }
    if ($null -eq $check.PSObject.Properties['expectMatch'] -or $check.expectMatch -isnot [bool]) {
        $errors.Add("Drift check expectMatch must be a boolean: $($check.description)")
    }
    try {
        [void][regex]::new([string]$check.pattern)
    } catch {
        $errors.Add("Drift check pattern is invalid: $($check.description)")
    }
}

foreach ($catalog in @($(if ($null -ne $artifactCatalogProperty) { $artifactCatalogProperty.Value }))) {
    foreach ($propertyName in @('name', 'directory', 'include', 'indexPath')) {
        if ([string]::IsNullOrWhiteSpace([string]$catalog.$propertyName)) {
            $errors.Add("Artifact catalog is missing $propertyName")
        }
    }

    $include = [string]$catalog.include
    if ($include.IndexOfAny(@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) -ge 0) {
        $errors.Add("Artifact catalog include must be a file-name pattern: $include")
    }

    foreach ($pathProperty in @('directory', 'indexPath')) {
        $relativePath = [string]$catalog.$pathProperty
        if (-not [string]::IsNullOrWhiteSpace($relativePath) -and $null -eq (Get-CheckedRepositoryPath -RelativePath $relativePath)) {
            $errors.Add("Artifact catalog $pathProperty escapes the repository: $relativePath")
        }
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

function Get-NormalizedSkillContent {
    param([Parameter(Mandatory = $true)][string]$Path)

    return ((Get-Content -LiteralPath $Path -Raw) -replace "`r`n?", "`n").TrimEnd()
}

$managedFilesByPath = @{}
foreach ($managedFile in @($lock.managedFiles)) {
    $managedFilesByPath[([string]$managedFile.path).Replace('\', '/')] = [string]$managedFile.ownership
}

foreach ($codexManagedPath in @($managedFilesByPath.Keys | Where-Object {
    $managedFilesByPath[$_] -eq 'managed' -and $_ -like '.agents/skills/*/SKILL.md'
})) {
    $claudeManagedPath = $codexManagedPath -replace '^\.agents/skills/', '.claude/skills/'
    if (-not $managedFilesByPath.ContainsKey($claudeManagedPath) -or $managedFilesByPath[$claudeManagedPath] -ne 'managed') {
        continue
    }

    $codexSkillPath = Get-CheckedRepositoryPath -RelativePath $codexManagedPath
    $claudeSkillPath = Get-CheckedRepositoryPath -RelativePath $claudeManagedPath
    if ($null -eq $codexSkillPath -or $null -eq $claudeSkillPath -or
        -not (Test-Path -LiteralPath $codexSkillPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $claudeSkillPath -PathType Leaf)) {
        $errors.Add("Harness-managed Skill wrapper is missing: $codexManagedPath or $claudeManagedPath")
        continue
    }

    if ((Get-NormalizedSkillContent -Path $codexSkillPath) -ne (Get-NormalizedSkillContent -Path $claudeSkillPath)) {
        $errors.Add("Harness-managed Skill wrappers differ: $codexManagedPath and $claudeManagedPath")
    }
}

if ($errors.Count -gt 0) {
    foreach ($message in $errors) {
        Write-Host "FAIL  $message" -ForegroundColor Red
    }
    exit 1
}

Write-Host 'PASS  Harness structure and configuration are valid.' -ForegroundColor Green
