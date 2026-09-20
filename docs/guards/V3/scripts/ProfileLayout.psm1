Set-StrictMode -Version Latest

function Resolve-V3ProfileLayout {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $TargetRoot,
        [string] $ProfileRepositoryRoot,
        [string] $ProfileDirectory,
        [string] $ProfileLayoutPath,
        [Parameter(Mandatory)][string] $SchemaPath
    )

    $hasDirectory = -not [string]::IsNullOrWhiteSpace($ProfileDirectory)
    $hasLayout = -not [string]::IsNullOrWhiteSpace($ProfileLayoutPath)
    if ($hasDirectory -eq $hasLayout) { throw 'Supply exactly one of ProfileDirectory or ProfileLayoutPath.' }

    $root = [IO.Path]::GetFullPath($TargetRoot)
    if (-not [IO.Directory]::Exists($root)) { throw "TargetRoot does not exist: $root" }
    $authorityRoot = [IO.Path]::GetFullPath($(if ($ProfileRepositoryRoot) { $ProfileRepositoryRoot } else { $root }))
    if (-not [IO.Directory]::Exists($authorityRoot)) { throw "ProfileRepositoryRoot does not exist: $authorityRoot" }
    $authorityPrefix = $authorityRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    function Resolve-RepositoryPath([string] $value) {
        $normalized = $value.Replace('\', '/')
        if ([string]::IsNullOrWhiteSpace($normalized) -or $normalized.StartsWith('/') -or $normalized -match '^[A-Za-z]:' -or
            $normalized -match '[*?]' -or @($normalized -split '/' | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
            throw "Unsafe repository-relative profile layout path: $value"
        }
        $full = [IO.Path]::GetFullPath((Join-Path $authorityRoot $normalized))
        if (-not $full.StartsWith($authorityPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Profile layout path escapes ProfileRepositoryRoot: $value" }
        return $full
    }

    if ($hasDirectory) {
        $profileRoot = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ProfileDirectory)) { $ProfileDirectory } else { Join-Path $authorityRoot $ProfileDirectory }))
        if ($profileRoot -ne $authorityRoot -and -not $profileRoot.StartsWith($authorityPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "ProfileDirectory must stay under ProfileRepositoryRoot: $ProfileDirectory" }
        if (-not [IO.Directory]::Exists($profileRoot)) { throw "ProfileDirectory does not exist: $profileRoot" }
        $resolved = [ordered]@{
            Mode = 'directory'
            Profile = Join-Path $profileRoot 'profile.json'
            ProjectMap = Join-Path $profileRoot 'project-map.json'
            TechStack = Join-Path $profileRoot 'tech-stack.json'
            RulesDirectory = Join-Path $profileRoot 'rules'
            ViewsDirectory = Join-Path $profileRoot 'views'
        }
    }
    else {
        $layoutPath = if ([IO.Path]::IsPathRooted($ProfileLayoutPath)) {
            $candidate = [IO.Path]::GetFullPath($ProfileLayoutPath)
            if ($candidate -ne $authorityRoot -and -not $candidate.StartsWith($authorityPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "ProfileLayoutPath must stay under ProfileRepositoryRoot: $ProfileLayoutPath" }
            $candidate
        } else { Resolve-RepositoryPath $ProfileLayoutPath }
        if (-not [IO.File]::Exists($layoutPath)) { throw "ProfileLayoutPath does not exist: $layoutPath" }
        if (-not [IO.File]::Exists($SchemaPath) -or -not (Test-Json -Path $layoutPath -SchemaFile $SchemaPath -ErrorAction Stop)) {
            throw "Invalid profile layout JSON: $layoutPath"
        }
        $layout = Get-Content -LiteralPath $layoutPath -Raw | ConvertFrom-Json -AsHashtable -Depth 20
        $resolved = [ordered]@{
            Mode = 'layout'
            Profile = Resolve-RepositoryPath ([string] $layout.profile)
            ProjectMap = Resolve-RepositoryPath ([string] $layout.projectMap)
            TechStack = Resolve-RepositoryPath ([string] $layout.techStack)
            RulesDirectory = Resolve-RepositoryPath ([string] $layout.rulesDirectory)
            ViewsDirectory = Resolve-RepositoryPath ([string] $layout.viewsDirectory)
        }
    }

    foreach ($name in @('Profile', 'ProjectMap', 'TechStack')) {
        if (-not [IO.File]::Exists($resolved[$name])) { throw "Profile layout file does not exist ($name): $($resolved[$name])" }
    }
    if (-not [IO.Directory]::Exists($resolved.RulesDirectory)) { throw "Profile layout rules directory does not exist: $($resolved.RulesDirectory)" }
    $sourcePaths = @($resolved.Profile, $resolved.ProjectMap, $resolved.TechStack, $resolved.RulesDirectory)
    if (@($sourcePaths | Sort-Object -Unique).Count -ne $sourcePaths.Count) { throw 'Profile layout authority paths must be distinct.' }
    return [pscustomobject] $resolved
}

Export-ModuleMember -Function Resolve-V3ProfileLayout
