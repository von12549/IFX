Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$locationClaim = 'IFX.C1.EMBEDDED_ADAPTER_LOCATION_SOURCE'
$providerClaim = 'IFX.C1.EMBEDDED_ADAPTER_PROVIDER_SOURCE'
$detectorId = 'ifx-embedded-adapter'
$matched = 0
$findings = [Collections.Generic.List[object]]::new()

function Write-Result([string] $Status, [string] $Category, [string] $Message = '') {
    $result = [ordered]@{
        formatVersion = 1; status = $Status; exitCategory = $Category
        findings = @($findings.ToArray())
        coverage = @(
            [ordered]@{ claimId = $locationClaim; matched = $matched; minimum = 1 },
            [ordered]@{ claimId = $providerClaim; matched = $matched; minimum = 1 }
        )
    }
    if ($Message) { $result.message = $Message }
    $result | ConvertTo-Json -Depth 20 -Compress
}
function Stop-Adapter([string] $Category, [string] $Message) {
    Write-Result 'error' $Category $Message
    exit 0
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
            Stop-Adapter 'unsafe-path' 'Source inventory crosses a link.'
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Matches([string] $Name, [string] $Pattern) {
    [Management.Automation.WildcardPattern]::new($Pattern, [Management.Automation.WildcardOptions]::IgnoreCase).IsMatch($Name)
}
function Ring-Of([string] $Name) {
    $found = [Collections.Generic.List[string]]::new()
    foreach ($ring in $policy.rings.PSObject.Properties.Name) {
        foreach ($pattern in $policy.rings.PSObject.Properties[$ring].Value) {
            if (Matches $Name ([string]$pattern)) { $found.Add($ring); break }
        }
    }
    if ($found.Count -gt 1) { Stop-Adapter 'integrity-failure' "Project has ambiguous ring: $Name." }
    if ($found.Count -eq 0) { return 'Outside' }
    return $found[0]
}
function Module-Of([string] $Name) {
    foreach ($pattern in $policy.ownership.modulePatterns) {
        $expression = '^' + [Regex]::Escape([string]$pattern).Replace('\{module}', '(?<module>[^.]+)').Replace('\*', '.*') + '$'
        $match = [Regex]::Match($Name, $expression, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) { return $match.Groups['module'].Value }
    }
    return $null
}
function Find-RoslynRoots {
    if ($null -eq (Get-Command dotnet -ErrorAction SilentlyContinue)) { return @() }
    $candidates = [Collections.Generic.List[object]]::new()
    foreach ($line in @(& dotnet --list-sdks 2>&1)) {
        if ([string]$line -match '^([^\s]+)\s+\[(.+)\]$') {
            $version = $null
            if ([version]::TryParse($Matches[1].Split('-')[0], [ref]$version) -and $version.Major -eq 10) {
                $root = Join-Path (Join-Path $Matches[2] $Matches[1]) 'Roslyn/bincore'
                if ([IO.File]::Exists((Join-Path $root 'Microsoft.CodeAnalysis.dll')) -and
                    [IO.File]::Exists((Join-Path $root 'Microsoft.CodeAnalysis.CSharp.dll'))) {
                    $candidates.Add([pscustomobject]@{ Version = $version; Root = $root })
                }
            }
        }
    }
    return @($candidates | Sort-Object Version -Descending | ForEach-Object Root)
}
function Load-Roslyn {
    foreach ($roslynRoot in @(Find-RoslynRoots)) {
        try {
            [void][Reflection.Assembly]::LoadFrom((Join-Path $roslynRoot 'Microsoft.CodeAnalysis.dll'))
            [void][Reflection.Assembly]::LoadFrom((Join-Path $roslynRoot 'Microsoft.CodeAnalysis.CSharp.dll'))
            return $true
        } catch { continue }
    }
    $hostCommon = Join-Path $PSHOME 'Microsoft.CodeAnalysis.dll'
    $hostCSharp = Join-Path $PSHOME 'Microsoft.CodeAnalysis.CSharp.dll'
    if ([IO.File]::Exists($hostCommon) -and [IO.File]::Exists($hostCSharp)) {
        try {
            [void][Reflection.Assembly]::LoadFrom($hostCommon)
            [void][Reflection.Assembly]::LoadFrom($hostCSharp)
            return $true
        } catch { }
    }
    return $false
}
function Add-Finding([string] $RuleId, [string] $Subject, [string] $EvidenceKind) {
    $findings.Add([ordered]@{ ruleId = $RuleId; subject = $Subject; evidenceKind = $EvidenceKind; detectorId = $detectorId; severity = 'blocking' })
}
function Resolve-Project([string] $Text, $Projects) {
    foreach ($project in $Projects) {
        if ($Text.Equals($project.name, [StringComparison]::Ordinal) -or
            $Text.StartsWith($project.name + '.', [StringComparison]::Ordinal)) { return $project }
    }
    return $null
}
function Is-Generated([string] $Path) {
    $name = [IO.Path]::GetFileName($Path)
    return $name.EndsWith('.g.cs', [StringComparison]::OrdinalIgnoreCase) -or
        $name.EndsWith('.generated.cs', [StringComparison]::OrdinalIgnoreCase) -or
        $name.EndsWith('.designer.cs', [StringComparison]::OrdinalIgnoreCase) -or
        $Path -match '[/\\](bin|obj)[/\\]'
}
function Is-GuardPath([string] $Path) {
    $relative = [IO.Path]::GetRelativePath($sourceRoot, $Path).Replace('\', '/')
    return $relative -match '(^|/)(guard|guards)(/|$)'
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.' }
try { $payload = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($payload.formatVersion -ne 1 -or $payload.stage -cne 'pre' -or
    @($payload.config.enabledClaims).Count -ne 2 -or
    @($payload.config.enabledClaims) -notcontains $locationClaim -or
    @($payload.config.enabledClaims) -notcontains $providerClaim -or
    @($payload.relativeRoots) -notcontains 'src') {
    Stop-Adapter 'invalid-input' 'Stage, roots or enabled claims are invalid.'
}
if (-not [IO.Path]::IsPathFullyQualified([string]$payload.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
try { $targetRoot = [IO.Path]::GetFullPath([string]$payload.targetRoot) }
catch { Stop-Adapter 'invalid-input' 'TargetRoot is invalid.' }
if (-not [IO.Directory]::Exists($targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
$policyHash = (Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($policyHash -cne [string]$payload.config.policySha256) { Stop-Adapter 'integrity-failure' 'Candidate policy hash differs from Profile configuration.' }
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 40 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is invalid.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-embedded-adapter-c1g' -or $policy.scanRoot -cne 'src') {
    Stop-Adapter 'integrity-failure' 'Candidate policy identity is invalid.'
}
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'src'))
if (-not (Is-Under $sourceRoot $targetRoot)) { Stop-Adapter 'unsafe-path' 'Source root escapes TargetRoot.' }
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot
$items = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force)
foreach ($item in $items) { Assert-NoLink $item.FullName }
$projects = [Collections.Generic.List[object]]::new()
foreach ($item in @($items | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.csproj' -and -not (Is-GuardPath $_.FullName) } | Sort-Object FullName)) {
    try {
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [Xml.XmlReader]::Create($item.FullName, $settings)
        try { $document = [xml]::new(); $document.Load($reader) } finally { $reader.Dispose() }
    } catch { Stop-Adapter 'invalid-input' "Project XML is invalid: $($item.Name)." }
    $name = [IO.Path]::GetFileNameWithoutExtension($item.FullName)
    $projects.Add([pscustomobject]@{
        name = $name; ring = Ring-Of $name; module = Module-Of $name
        directory = [IO.Path]::GetDirectoryName($item.FullName)
    })
}
$targets = @($projects | Sort-Object @{ Expression = { $_.name.Length }; Descending = $true }, name)
$infrastructure = @($projects | Where-Object { $_.ring -ceq 'Infrastructure' -and $null -ne $_.module })
if ($infrastructure.Count -eq 0) { Stop-Adapter 'prerequisite-missing' 'No known-module Infrastructure project under src.' }
if (-not (Load-Roslyn)) { Stop-Adapter 'prerequisite-missing' 'An installed .NET 10 SDK with Roslyn is required.' }
$sourceCount = 0
foreach ($source in @($items | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.cs' -and -not (Is-Generated $_.FullName) -and -not (Is-GuardPath $_.FullName) } | Sort-Object FullName)) {
    $owners = @($projects | Where-Object { Is-Under $source.FullName $_.directory } | Sort-Object @{ Expression = { $_.directory.Length }; Descending = $true })
    if ($owners.Count -eq 0) { continue }
    $owner = $owners[0]
    if ($owner.ring -cne 'Infrastructure' -or $null -eq $owner.module) { continue }
    $sourceCount++
    try {
        $tree = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText([IO.File]::ReadAllText($source.FullName), $null, $source.FullName)
        $root = $tree.GetRoot()
        if (@($tree.GetDiagnostics() | Where-Object { $_.Severity -eq [Microsoft.CodeAnalysis.DiagnosticSeverity]::Error }).Count -gt 0) {
            Stop-Adapter 'invalid-input' "C# syntax is invalid: $($source.Name)."
        }
    } catch { Stop-Adapter 'invalid-input' "C# source cannot be parsed: $($source.Name)." }
    $rootNamespace = @($root.DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.BaseNamespaceDeclarationSyntax] } | Select-Object -First 1)
    $fallbackNamespace = if ($rootNamespace.Count -gt 0) { $rootNamespace[0].Name.ToString() } else { '' }
    foreach ($name in @($root.DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.NameSyntax] })) {
        $targetText = $name.ToString()
        $target = Resolve-Project $targetText $targets
        if ($null -eq $target -or $target.ring -cne 'Contracts' -or $null -eq $target.module -or
            $owner.module.Equals($target.module, [StringComparison]::OrdinalIgnoreCase) -or
            @($policy.sharedPrimitiveProjects) -contains $target.name) { continue }
        if ($name.Parent -is [Microsoft.CodeAnalysis.CSharp.Syntax.NameSyntax] -and
            $name.Parent.ToString().Contains($targetText, [StringComparison]::Ordinal)) { continue }
        $matched++
        $ancestors = @($name.Ancestors() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.BaseNamespaceDeclarationSyntax] } | Select-Object -First 1)
        $namespace = if ($ancestors.Count -gt 0) { $ancestors[0].Name.ToString() } else { $fallbackNamespace }
        $line = $tree.GetLineSpan($name.Span).StartLinePosition.Line + 1
        $relative = [IO.Path]::GetRelativePath($targetRoot, $source.FullName).Replace('\', '/')
        $subject = "${relative}:${line}: $($owner.name) -> $($target.name) [$targetText]"
        $inBoundary = $false
        foreach ($pattern in $policy.embeddedAdapterNamespaces) { if (Matches $namespace ([string]$pattern)) { $inBoundary = $true; break } }
        if (-not $inBoundary) { Add-Finding 'EMBEDDED-ADAPTER-LOCATION' $subject 'source-syntax' }
        $providers = $policy.providerContracts.PSObject.Properties[$owner.module]
        if ($null -eq $providers -or @($providers.Value) -notcontains $target.module) {
            Add-Finding 'EMBEDDED-ADAPTER-PROVIDER' $subject 'source-syntax'
        }
    }
}
if ($sourceCount -eq 0) { Stop-Adapter 'prerequisite-missing' 'No Infrastructure C# source files under src.' }
if ($matched -eq 0) {
    Add-Finding 'EMBEDDED-ADAPTER-LOCATION' 'src: zero foreign Contracts source uses in Infrastructure' 'coverage'
    Add-Finding 'EMBEDDED-ADAPTER-PROVIDER' 'src: zero foreign Contracts source uses in Infrastructure' 'coverage'
}
$sorted = @($findings.ToArray() | Sort-Object ruleId, subject)
$findings.Clear()
foreach ($finding in $sorted) { $findings.Add($finding) }
if ($findings.Count -gt 0) { Write-Result 'fail' 'findings-blocking' } else { Write-Result 'pass' 'success' }
