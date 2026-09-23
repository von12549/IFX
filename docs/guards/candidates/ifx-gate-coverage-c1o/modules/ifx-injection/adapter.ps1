Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$detector = 'ifx-injection'
$claims = @('IFX.C1.FORBIDDEN_DEPENDENCY_SOURCE','IFX.C1.FORBIDDEN_DEPENDENCY_ORIGIN_SOURCE')
$nameMatches = 0; $originMatches = 0; $infrastructureDeclarations = 0
$findings = [Collections.Generic.List[object]]::new()

function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $result = [ordered]@{
        formatVersion = 1; status = $Status; exitCategory = $Category
        findings = @($findings.ToArray())
        coverage = @(
            [ordered]@{ claimId = $claims[0]; matched = $nameMatches; minimum = 1 },
            [ordered]@{ claimId = $claims[1]; matched = $originMatches; minimum = 1 }
        )
    }
    if ($Message) { $result.message = $Message }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 20 -Compress))
}
function Stop-Adapter([string] $Category, [string] $Message) { Emit 'error' $Category $Message; exit 0 }
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current -and ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current))) {
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
    $expression = '^' + [regex]::Escape($Pattern).Replace('\*','.*') + '$'
    [regex]::IsMatch($Name, $expression, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
function Ring-Of([string] $Name) {
    foreach ($entry in $policy.rings.PSObject.Properties) {
        if (@($entry.Value | Where-Object { Matches $Name ([string]$_) }).Count -gt 0) { return $entry.Name }
    }
    return 'Outside'
}
function Is-Excluded([string] $Path) {
    $relative = [IO.Path]::GetRelativePath($sourceRoot, $Path).Replace('\','/')
    if ($relative -match '(^|/)(guard|guards|bin|obj)(/|$)') { return $true }
    $name = [IO.Path]::GetFileName($Path)
    return $name.EndsWith('.g.cs', [StringComparison]::OrdinalIgnoreCase) -or
        $name.EndsWith('.generated.cs', [StringComparison]::OrdinalIgnoreCase) -or
        $name.EndsWith('.designer.cs', [StringComparison]::OrdinalIgnoreCase)
}
function Load-Roslyn {
    if ($null -eq (Get-Command dotnet -ErrorAction SilentlyContinue)) { return $false }
    $sdks = [Collections.Generic.List[object]]::new()
    foreach ($line in @(& dotnet --list-sdks 2>&1)) {
        if ([string]$line -match '^([^\s]+)\s+\[(.+)\]$') {
            $version = $null
            if ([version]::TryParse($Matches[1].Split('-')[0], [ref]$version) -and $version.Major -eq 10) {
                $root = Join-Path (Join-Path $Matches[2] $Matches[1]) 'Roslyn/bincore'
                if ([IO.File]::Exists((Join-Path $root 'Microsoft.CodeAnalysis.dll')) -and
                    [IO.File]::Exists((Join-Path $root 'Microsoft.CodeAnalysis.CSharp.dll'))) {
                    $sdks.Add([pscustomobject]@{ version = $version; root = $root })
                }
            }
        }
    }
    foreach ($item in @($sdks | Sort-Object version -Descending)) {
        try {
            [void][Reflection.Assembly]::LoadFrom((Join-Path $item.root 'Microsoft.CodeAnalysis.dll'))
            [void][Reflection.Assembly]::LoadFrom((Join-Path $item.root 'Microsoft.CodeAnalysis.CSharp.dll'))
            return $true
        }
        catch { continue }
    }
    $common = Join-Path $PSHOME 'Microsoft.CodeAnalysis.dll'
    $csharp = Join-Path $PSHOME 'Microsoft.CodeAnalysis.CSharp.dll'
    if ([IO.File]::Exists($common) -and [IO.File]::Exists($csharp)) {
        try { [void][Reflection.Assembly]::LoadFrom($common); [void][Reflection.Assembly]::LoadFrom($csharp); return $true }
        catch { }
    }
    return $false
}
function Add-Finding([string] $Rule, [string] $Subject, [string] $Kind = 'source-parameter') {
    $findings.Add([ordered]@{ ruleId = $Rule; subject = $Subject; evidenceKind = $Kind; detectorId = $detector; severity = 'blocking' })
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.' }
try { $inputObject = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'pre' -or
    (@($inputObject.config.enabledClaims) -join '|') -cne ($claims -join '|') -or
    @($inputObject.relativeRoots) -notcontains 'src') { Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.' }
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
$targetRoot = [IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Directory]::Exists($targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
if ((Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256) {
    Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.'
}
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-injection-c1o' -or $policy.scanRoot -cne 'src' -or
    (@($policy.claims | ForEach-Object claimId) -join '|') -cne ($claims -join '|')) {
    Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.'
}
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'src'))
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot
$items = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force)
foreach ($item in $items) { Assert-NoLink $item.FullName }
$projects = [Collections.Generic.List[object]]::new()
foreach ($item in @($items | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.csproj' -and -not (Is-Excluded $_.FullName) } | Sort-Object FullName)) {
    try {
        $settings = [Xml.XmlReaderSettings]::new(); $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit; $settings.XmlResolver = $null
        $reader = [Xml.XmlReader]::Create($item.FullName, $settings)
        try { $xml = [xml]::new(); $xml.Load($reader); if ($xml.DocumentElement.LocalName -cne 'Project') { throw 'Root is not Project.' } }
        finally { $reader.Dispose() }
    }
    catch { Stop-Adapter 'invalid-input' "Project XML is invalid: $($item.Name)." }
    $name = [IO.Path]::GetFileNameWithoutExtension($item.FullName)
    $projects.Add([pscustomobject]@{ name = $name; ring = (Ring-Of $name); directory = [IO.Path]::GetDirectoryName($item.FullName) })
}
if (@($projects | Where-Object ring -ne 'Outside').Count -eq 0) { Stop-Adapter 'prerequisite-missing' 'No in-scope projects under src.' }
if (-not (Load-Roslyn)) { Stop-Adapter 'prerequisite-missing' 'Installed .NET 10 Roslyn is required.' }
$units = [Collections.Generic.List[object]]::new()
$index = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
foreach ($file in @($items | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.cs' -and -not (Is-Excluded $_.FullName) } | Sort-Object FullName)) {
    $owners = @($projects | Where-Object { Is-Under $file.FullName $_.directory } | Sort-Object @{ Expression = { $_.directory.Length }; Descending = $true })
    if ($owners.Count -eq 0 -or $owners[0].ring -ceq 'Outside') { continue }
    try {
        $tree = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText([IO.File]::ReadAllText($file.FullName), $null, $file.FullName)
        if (@($tree.GetDiagnostics() | Where-Object { $_.Severity -eq [Microsoft.CodeAnalysis.DiagnosticSeverity]::Error }).Count -gt 0) {
            Stop-Adapter 'invalid-input' "C# syntax is invalid: $($file.Name)."
        }
        $root = $tree.GetRoot()
    }
    catch { Stop-Adapter 'invalid-input' "C# source cannot be parsed: $($file.Name)." }
    $owner = $owners[0]
    $units.Add([pscustomobject]@{ project = $owner; tree = $tree; root = $root; relative = [IO.Path]::GetRelativePath($targetRoot, $file.FullName).Replace('\','/') })
    foreach ($declaration in @($root.DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.BaseTypeDeclarationSyntax] })) {
        $name = $declaration.Identifier.Text
        if (-not $index.ContainsKey($name)) { $index.Add($name, [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)) }
        [void]$index[$name].Add($owner.ring)
        if ($owner.ring -ceq 'Infrastructure') { $infrastructureDeclarations++ }
    }
}
if ($units.Count -eq 0) { Stop-Adapter 'prerequisite-missing' 'No in-scope C# source files under src.' }
foreach ($unit in $units) {
    if ($unit.project.ring -notin @('Presentation','Application')) { continue }
    foreach ($declaration in @($unit.root.DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.TypeDeclarationSyntax] })) {
        $parameters = [Collections.Generic.List[object]]::new()
        if ($null -ne $declaration.ParameterList) { foreach ($parameter in $declaration.ParameterList.Parameters) { $parameters.Add($parameter) } }
        foreach ($member in $declaration.Members) {
            if ($member -is [Microsoft.CodeAnalysis.CSharp.Syntax.ConstructorDeclarationSyntax] -or
                $member -is [Microsoft.CodeAnalysis.CSharp.Syntax.MethodDeclarationSyntax]) {
                foreach ($parameter in $member.ParameterList.Parameters) { $parameters.Add($parameter) }
            }
        }
        foreach ($parameter in $parameters) {
            if ($null -eq $parameter.Type) { continue }
            if ($unit.project.ring -ceq 'Presentation') { $nameMatches++ } else { $originMatches++ }
            foreach ($nameNode in @($parameter.Type.DescendantNodesAndSelf() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.SimpleNameSyntax] })) {
                $name = $nameNode.Identifier.Text
                $rule = ''
                if ($unit.project.ring -ceq 'Presentation' -and
                    @($policy.forbiddenDependencies.Presentation | Where-Object { Matches $name ([string]$_) }).Count -gt 0) {
                    $rule = 'FORBIDDEN-DEPENDENCY'
                }
                elseif ($unit.project.ring -ceq 'Application' -and $index.ContainsKey($name) -and
                    -not $index[$name].Contains('Application') -and $index[$name].Contains('Infrastructure')) {
                    $rule = 'FORBIDDEN-DEPENDENCY-ORIGIN'
                }
                if (-not $rule) { continue }
                $line = $unit.tree.GetLineSpan($parameter.Span).StartLinePosition.Line + 1
                Add-Finding $rule "$($unit.relative):${line}: $($unit.project.name) [$($declaration.Identifier.Text) -> $name]"
                break
            }
        }
    }
}
if ($nameMatches -eq 0) { Add-Finding 'FORBIDDEN-DEPENDENCY' 'src: zero Presentation parameters' 'coverage' }
if ($originMatches -eq 0 -or $infrastructureDeclarations -eq 0) {
    $reason = if ($originMatches -eq 0) { 'zero Application parameters' } else { 'zero Infrastructure declarations' }
    Add-Finding 'FORBIDDEN-DEPENDENCY-ORIGIN' "src: $reason" 'coverage'
}
$sorted = $findings.ToArray()
[Array]::Sort($sorted, [Comparison[object]]{ param($a,$b) [StringComparer]::Ordinal.Compare("$($a['ruleId'])|$($a['subject'])", "$($b['ruleId'])|$($b['subject'])") })
$findings.Clear(); foreach ($finding in $sorted) { $findings.Add($finding) }
Emit $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' }) $(if ($findings.Count -eq 0) { 'success' } else { 'findings-blocking' })
