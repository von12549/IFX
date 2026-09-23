Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$detectorId = 'ifx-source-policy'
$claimRules = [ordered]@{
    'IFX.C1.IMPORT_DIRECTION_SOURCE' = 'IMPORT-DIRECTION'
    'IFX.C1.IMPORT_OWNERSHIP_SOURCE' = 'OWNERSHIP-REFERENCE'
    'IFX.C1.IMPORT_PACKAGE_SOURCE' = 'RING-PACKAGE-FORBIDDEN'
    'IFX.C1.DECLARATION_NAMESPACE_SOURCE' = 'DECLARATION-NAMESPACE'
    'IFX.C1.DECLARATION_FORBIDDEN_SOURCE' = 'DECLARATION-FORBIDDEN'
    'IFX.C1.DECLARATION_PLACEMENT_SOURCE' = 'DECLARATION-PLACEMENT'
    'IFX.C1.DECLARATION_IMPLEMENTS_SOURCE' = 'DECLARATION-IMPLEMENTS'
    'IFX.C1.SYMBOL_FORBIDDEN_SOURCE' = 'SYMBOL-FORBIDDEN'
    'IFX.C1.PAYLOAD_TYPE_SOURCE' = 'PAYLOAD-TYPE-FORBIDDEN'
}
$counts = @{}
foreach ($claim in $claimRules.Keys) { $counts[$claim] = 0 }
$findings = [Collections.Generic.List[object]]::new()
function Write-Result([string] $Status, [string] $Category, [string] $Message = '') {
    $coverage = @($claimRules.Keys | ForEach-Object {
        [ordered]@{ claimId = $_; matched = [int]$counts[$_]; minimum = 1 }
    })
    $result = [ordered]@{ formatVersion = 1; status = $Status; exitCategory = $Category
        findings = @($findings.ToArray()); coverage = $coverage }
    if ($Message) { $result.message = $Message }
    $result | ConvertTo-Json -Depth 20 -Compress
}
function Stop-Adapter([string] $Category, [string] $Message) { Write-Result 'error' $Category $Message; exit 0 }
function Add-Finding([string] $RuleId, [string] $Subject, [string] $Kind, [string] $Severity = 'blocking') {
    $findings.Add([ordered]@{ ruleId = $RuleId; subject = $Subject; evidenceKind = $Kind
        detectorId = $detectorId; severity = $Severity })
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
function Any-Match([string] $Name, $Patterns) {
    foreach ($pattern in @($Patterns)) { if (Matches $Name ([string]$pattern)) { return $true } }
    return $false
}
function Ring-Of([string] $Name) {
    $found = [Collections.Generic.List[string]]::new()
    foreach ($ring in $policy.rings.PSObject.Properties.Name) {
        if (Any-Match $Name $policy.rings.PSObject.Properties[$ring].Value) { $found.Add($ring) }
    }
    if ($found.Count -gt 1) { Stop-Adapter 'integrity-failure' "Project has ambiguous ring: $Name." }
    if ($found.Count -eq 0) { return 'Outside' }
    return $found[0]
}
function Module-Of([string] $Name, [string] $Directory, [string] $Ring) {
    foreach ($pattern in $policy.ownership.modulePatterns) {
        $expression = '^' + [Regex]::Escape([string]$pattern).Replace('\{module}', '(?<module>[^.]+)').Replace('\*', '.*') + '$'
        $match = [Regex]::Match($Name, $expression, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) { return $match.Groups['module'].Value }
    }
    if ($Ring -in @('RuntimeHost','Test')) { return $null }
    return [IO.Path]::GetFileName([IO.Path]::GetDirectoryName($Directory))
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
    $common = Join-Path $PSHOME 'Microsoft.CodeAnalysis.dll'
    $csharp = Join-Path $PSHOME 'Microsoft.CodeAnalysis.CSharp.dll'
    if ([IO.File]::Exists($common) -and [IO.File]::Exists($csharp)) {
        try { [void][Reflection.Assembly]::LoadFrom($common); [void][Reflection.Assembly]::LoadFrom($csharp); return $true }
        catch { }
    }
    return $false
}
function Is-Excluded([string] $Path) {
    $relative = [IO.Path]::GetRelativePath($sourceRoot, $Path).Replace('\','/')
    if ($relative -match '(^|/)(guard|guards|bin|obj)(/|$)') { return $true }
    $name = [IO.Path]::GetFileName($Path)
    return $name.EndsWith('.g.cs', [StringComparison]::OrdinalIgnoreCase) -or
        $name.EndsWith('.generated.cs', [StringComparison]::OrdinalIgnoreCase) -or
        $name.EndsWith('.designer.cs', [StringComparison]::OrdinalIgnoreCase)
}
function Resolve-Project([string] $Text) {
    foreach ($project in $script:byLongestName) {
        if ($Text.Equals($project.name, [StringComparison]::Ordinal) -or
            $Text.StartsWith($project.name + '.', [StringComparison]::Ordinal)) { return $project }
    }
    return $null
}
function Kind-Of($Declaration) {
    if ($Declaration -is [Microsoft.CodeAnalysis.CSharp.Syntax.ClassDeclarationSyntax]) { return 'class' }
    if ($Declaration -is [Microsoft.CodeAnalysis.CSharp.Syntax.InterfaceDeclarationSyntax]) { return 'interface' }
    if ($Declaration -is [Microsoft.CodeAnalysis.CSharp.Syntax.RecordDeclarationSyntax]) { return 'record' }
    if ($Declaration -is [Microsoft.CodeAnalysis.CSharp.Syntax.StructDeclarationSyntax]) { return 'struct' }
    if ($Declaration -is [Microsoft.CodeAnalysis.CSharp.Syntax.EnumDeclarationSyntax]) { return 'enum' }
    return 'type'
}
function Simple([string] $Name) { return $Name.Split('.')[-1].Split('<')[0].TrimEnd('?') }
function Has-Property($Object, [string] $Name) { return $null -ne $Object.PSObject.Properties[$Name] }
function Applies([string] $Name, [string] $Kind, $Rule) {
    if (-not (Matches $Name ([string]$Rule.match))) { return $false }
    if ((Has-Property $Rule 'kind') -and -not $Kind.Equals([string]$Rule.kind, [StringComparison]::OrdinalIgnoreCase)) { return $false }
    if ((Has-Property $Rule 'exceptions') -and (Any-Match $Name $Rule.exceptions)) { return $false }
    return $true
}
function Implements($Declaration, [string] $RequiredRing, [string] $RequiredModule = '') {
    if ($null -eq $Declaration.BaseList) { return $false }
    foreach ($baseType in $Declaration.BaseList.Types) {
        $simpleName = Simple ($baseType.Type.ToString())
        if (-not $script:declarationIndex.ContainsKey($simpleName)) { continue }
        foreach ($site in $script:declarationIndex[$simpleName]) {
            if ($site.ring -ceq $RequiredRing -and
                (-not $RequiredModule -or $site.module.Equals($RequiredModule, [StringComparison]::OrdinalIgnoreCase))) { return $true }
        }
    }
    return $false
}
function Source-Subject($Unit, $Node, [string] $Detail) {
    $line = $Unit.tree.GetLineSpan($Node.Span).StartLinePosition.Line + 1
    return "$($Unit.relative):${line}: $($Unit.project.name) [$Detail]"
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.' }
try { $payload = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($payload.formatVersion -ne 1 -or $payload.stage -cne 'pre' -or @($payload.relativeRoots) -notcontains 'src' -or
    @($payload.config.enabledClaims).Count -ne $claimRules.Count -or
    ((@($payload.config.enabledClaims | Sort-Object) -join ',') -cne (@($claimRules.Keys | Sort-Object) -join ','))) {
    Stop-Adapter 'invalid-input' 'Stage, roots or enabled claims are invalid.'
}
if (-not [IO.Path]::IsPathFullyQualified([string]$payload.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
try { $targetRoot = [IO.Path]::GetFullPath([string]$payload.targetRoot) }
catch { Stop-Adapter 'invalid-input' 'TargetRoot is invalid.' }
if (-not [IO.Directory]::Exists($targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
$policyHash = (Get-FileHash $policyPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($policyHash -cne [string]$payload.config.policySha256) { Stop-Adapter 'integrity-failure' 'Candidate policy hash differs from Profile configuration.' }
try { $policy = Get-Content $policyPath -Raw | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is invalid.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-source-policy-c1h' -or $policy.scanRoot -cne 'src' -or
    (@($policy.claims) -join ',') -cne (@($claimRules.Keys) -join ',')) { Stop-Adapter 'integrity-failure' 'Candidate policy identity is invalid.' }
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'src'))
if (-not (Is-Under $sourceRoot $targetRoot)) { Stop-Adapter 'unsafe-path' 'Source root escapes TargetRoot.' }
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot
$items = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force)
foreach ($item in $items) { Assert-NoLink $item.FullName }
$projects = [Collections.Generic.List[object]]::new()
foreach ($item in @($items | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.csproj' -and -not (Is-Excluded $_.FullName) } | Sort-Object FullName)) {
    try {
        $settings = [Xml.XmlReaderSettings]::new(); $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit; $settings.XmlResolver = $null
        $reader = [Xml.XmlReader]::Create($item.FullName, $settings)
        try { $document = [xml]::new(); $document.Load($reader) } finally { $reader.Dispose() }
    } catch { Stop-Adapter 'invalid-input' "Project XML is invalid: $($item.Name)." }
    $name = [IO.Path]::GetFileNameWithoutExtension($item.FullName)
    $ring = Ring-Of $name
    $directory = [IO.Path]::GetDirectoryName($item.FullName)
    $projects.Add([pscustomobject]@{ name = $name; ring = $ring; module = Module-Of $name $directory $ring
        directory = $directory; path = $item.FullName })
}
if (@($projects | Where-Object ring -ne 'Outside').Count -eq 0) { Stop-Adapter 'prerequisite-missing' 'No in-scope projects under src.' }
$script:byLongestName = @($projects | Sort-Object @{ Expression = { $_.name.Length }; Descending = $true }, name)
if (-not (Load-Roslyn)) { Stop-Adapter 'prerequisite-missing' 'Compatible Roslyn and installed .NET 10 SDK are required.' }
$units = [Collections.Generic.List[object]]::new()
$script:declarationIndex = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
foreach ($source in @($items | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.cs' -and -not (Is-Excluded $_.FullName) } | Sort-Object FullName)) {
    $owners = @($projects | Where-Object { Is-Under $source.FullName $_.directory } | Sort-Object @{ Expression = { $_.directory.Length }; Descending = $true })
    if ($owners.Count -eq 0) { continue }
    $owner = $owners[0]
    if ($owner.ring -ceq 'Outside') { continue }
    try {
        $tree = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText([IO.File]::ReadAllText($source.FullName), $null, $source.FullName)
        $root = $tree.GetRoot()
        if (@($tree.GetDiagnostics() | Where-Object { $_.Severity -eq [Microsoft.CodeAnalysis.DiagnosticSeverity]::Error }).Count -gt 0) {
            Stop-Adapter 'invalid-input' "C# syntax is invalid: $($source.Name)."
        }
    } catch { Stop-Adapter 'invalid-input' "C# source cannot be parsed: $($source.Name)." }
    $unit = [pscustomobject]@{ project = $owner; tree = $tree; root = $root
        relative = [IO.Path]::GetRelativePath($targetRoot, $source.FullName).Replace('\','/') }
    $units.Add($unit)
    foreach ($declaration in @($root.DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.BaseTypeDeclarationSyntax] })) {
        $name = $declaration.Identifier.Text
        if (-not $script:declarationIndex.ContainsKey($name)) { $script:declarationIndex.Add($name, [Collections.Generic.List[object]]::new()) }
        $script:declarationIndex[$name].Add([pscustomobject]@{ ring = $owner.ring; module = $owner.module })
    }
}
if ($units.Count -eq 0) { Stop-Adapter 'prerequisite-missing' 'No in-scope C# source files under src.' }

function Judge-Import($Unit, $Directive, [int] $Line, [bool] $Inactive) {
    if ($null -eq $Directive.NamespaceOrType) { return }
    $targetText = $Directive.NamespaceOrType.ToString()
    if ($targetText -ceq 'System' -or $targetText.StartsWith('System.', [StringComparison]::Ordinal)) { return }
    $branch = if ($Inactive) { ' inactive' } else { '' }
    $subject = "$($Unit.relative):${Line}: $($Unit.project.name) -> $targetText$branch"
    $declaring = Resolve-Project $targetText
    if ($null -ne $declaring) {
        if ($declaring.ring -ceq 'Outside' -or $declaring.path -ceq $Unit.project.path) { return }
        if ($Unit.project.ring -notin @('Domain','Outside') -and
            @($policy.sharedPrimitiveProjects) -notcontains $Unit.project.name -and
            @($policy.sharedPrimitiveProjects) -contains $declaring.name) { return }
        $counts['IFX.C1.IMPORT_DIRECTION_SOURCE']++
        $allowed = $Unit.project.ring -ceq $declaring.ring -or
            @($policy.allowedDependencies.PSObject.Properties[$Unit.project.ring].Value) -contains $declaring.ring
        $scopes = @($policy.referenceScopes | Where-Object { $_.from -ceq $Unit.project.ring -and $_.to -ceq $declaring.ring })
        if ($scopes.Count -gt 0) { $counts['IFX.C1.IMPORT_OWNERSHIP_SOURCE']++ }
        $relationship = if ($Unit.project.module -and $declaring.module -and
            $Unit.project.module.Equals($declaring.module, [StringComparison]::OrdinalIgnoreCase)) { 'own' } else { 'foreign' }
        $ownershipAllowed = $scopes.Count -eq 0 -or @($scopes | Where-Object { $_.ownership -in @('any',$relationship) }).Count -gt 0
        if (-not $allowed) { Add-Finding 'IMPORT-DIRECTION' $subject 'source-import' }
        elseif (-not $ownershipAllowed) { Add-Finding 'OWNERSHIP-REFERENCE' $subject 'source-import' }
        return
    }
    $forbiddenEntry = $policy.forbiddenPackages.PSObject.Properties[$Unit.project.ring]
    $allowedEntry = $policy.allowedPackages.PSObject.Properties[$Unit.project.ring]
    if ($null -eq $forbiddenEntry -and $null -eq $allowedEntry) { return }
    $counts['IFX.C1.IMPORT_PACKAGE_SOURCE']++
    if ($null -ne $forbiddenEntry -and (Any-Match $targetText $forbiddenEntry.Value)) {
        Add-Finding 'RING-PACKAGE-FORBIDDEN' $subject 'source-import'
    } elseif ($null -ne $allowedEntry -and -not (Any-Match $targetText $allowedEntry.Value)) {
        Add-Finding 'RING-PACKAGE-IMPORT' $subject 'source-import' 'advisory'
    }
}
function Judge-Source($Unit) {
    $root = $Unit.root
    $owner = $Unit.project
    $activeImports = @($root.DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.UsingDirectiveSyntax] })
    foreach ($directive in $activeImports) {
        $line = $Unit.tree.GetLineSpan($directive.Span).StartLinePosition.Line + 1
        Judge-Import $Unit $directive $line $false
    }
    foreach ($region in @($root.DescendantTrivia() | Where-Object { $_.RawKind -eq [int][Microsoft.CodeAnalysis.CSharp.SyntaxKind]::DisabledTextTrivia })) {
        $regionStart = $Unit.tree.GetLineSpan($region.Span).StartLinePosition.Line
        $fragment = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText($region.ToFullString())
        foreach ($directive in @($fragment.GetRoot().DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.UsingDirectiveSyntax] })) {
            $line = $regionStart + $fragment.GetLineSpan($directive.Span).StartLinePosition.Line + 1
            Judge-Import $Unit $directive $line $true
        }
    }
    $namespacePatterns = $policy.forbiddenNamespaces.PSObject.Properties[$owner.ring]
    $symbolPatterns = $policy.forbiddenSymbols.PSObject.Properties[$owner.ring]
    $textPatterns = $policy.forbiddenText.PSObject.Properties[$owner.ring]
    if ($null -ne $namespacePatterns -or $null -ne $symbolPatterns -or $null -ne $textPatterns) {
        $counts['IFX.C1.SYMBOL_FORBIDDEN_SOURCE']++
        if ($null -ne $namespacePatterns) {
            foreach ($directive in $activeImports) {
                if ($null -eq $directive.NamespaceOrType) { continue }
                $targetText = $directive.NamespaceOrType.ToString()
                if (Any-Match $targetText $namespacePatterns.Value) {
                    Add-Finding 'SYMBOL-FORBIDDEN' (Source-Subject $Unit $directive $targetText) 'source-symbol'
                }
            }
        }
        if ($null -ne $symbolPatterns) {
            foreach ($name in @($root.DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.NameSyntax] })) {
                $text = $name.ToString()
                if (-not ((Any-Match $text $symbolPatterns.Value) -or (Any-Match (Simple $text) $symbolPatterns.Value))) { continue }
                if ($name.Parent -is [Microsoft.CodeAnalysis.CSharp.Syntax.NameSyntax] -and
                    $name.Parent.ToString().Contains($text, [StringComparison]::Ordinal)) { continue }
                Add-Finding 'SYMBOL-FORBIDDEN' (Source-Subject $Unit $name $text) 'source-symbol'
            }
        }
        if ($null -ne $textPatterns) {
            foreach ($literal in @($root.DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.LiteralExpressionSyntax] })) {
                $value = $literal.Token.ValueText
                if (Any-Match $value $textPatterns.Value) {
                    Add-Finding 'SYMBOL-FORBIDDEN' (Source-Subject $Unit $literal $value) 'source-symbol'
                }
            }
        }
    }
    foreach ($declaration in @($root.DescendantNodes() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.BaseTypeDeclarationSyntax] })) {
        $name = $declaration.Identifier.Text
        $kind = Kind-Of $declaration
        $namespaceNodes = @($declaration.Ancestors() | Where-Object { $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.BaseNamespaceDeclarationSyntax] } | Select-Object -First 1)
        $declaredNamespace = if ($namespaceNodes.Count -gt 0) { $namespaceNodes[0].Name.ToString() } else { '' }
        foreach ($rule in $policy.declarationNamespaces) {
            if (-not (Applies $name $kind $rule)) { continue }
            $counts['IFX.C1.DECLARATION_NAMESPACE_SOURCE']++
            $requiredModule = if ((Has-Property $rule 'mustImplementOwn') -and $rule.mustImplementOwn) { [string]$owner.module } else { '' }
            $implementsRequired = -not (Has-Property $rule 'mustImplement') -or
                (Implements $declaration ([string]$rule.mustImplement) $requiredModule)
            if (@($rule.mustLiveIn) -notcontains $owner.ring -or
                -not (Matches $declaredNamespace ([string]$rule.namespace)) -or -not $implementsRequired) {
                Add-Finding 'DECLARATION-NAMESPACE' (Source-Subject $Unit $declaration "$kind $name in $declaredNamespace") 'source-declaration'
            }
            break
        }
        if ($owner.ring -ceq 'Contracts') {
            $counts['IFX.C1.DECLARATION_FORBIDDEN_SOURCE']++
            foreach ($rule in $policy.forbiddenDeclarations) {
                if ($rule.in -cne $owner.ring -or -not (Applies $name $kind $rule)) { continue }
                Add-Finding 'DECLARATION-FORBIDDEN' (Source-Subject $Unit $declaration "$kind $name") 'source-declaration'
                break
            }
        }
        foreach ($rule in $policy.declarations) {
            if (-not (Applies $name $kind $rule)) { continue }
            $counts['IFX.C1.DECLARATION_PLACEMENT_SOURCE']++
            $advisory = (Has-Property $rule 'severity') -and $rule.severity -ceq 'bends'
            $suffix = if ($advisory) { '-ADVISORY' } else { '' }
            $severity = if ($advisory) { 'advisory' } else { 'blocking' }
            if ((Has-Property $rule 'mustImplement')) {
                $counts['IFX.C1.DECLARATION_IMPLEMENTS_SOURCE']++
                if (-not (Implements $declaration ([string]$rule.mustImplement))) {
                    Add-Finding "DECLARATION-IMPLEMENTS$suffix" (Source-Subject $Unit $declaration "$kind $name") 'source-declaration' $severity
                }
            }
            if ($owner.ring -cne $rule.mustLiveIn) {
                Add-Finding "DECLARATION-PLACEMENT$suffix" (Source-Subject $Unit $declaration "$kind $name") 'source-declaration' $severity
            }
        }
        foreach ($rule in $policy.payloads) {
            if (-not (Matches $name ([string]$rule.match)) -or
                ((Has-Property $rule 'exceptions') -and (Any-Match $name $rule.exceptions))) { continue }
            foreach ($type in @($declaration.DescendantNodes() | Where-Object {
                $_ -is [Microsoft.CodeAnalysis.CSharp.Syntax.TypeSyntax] -and
                ($_.Parent -is [Microsoft.CodeAnalysis.CSharp.Syntax.ParameterSyntax] -or
                    $_.Parent -is [Microsoft.CodeAnalysis.CSharp.Syntax.PropertyDeclarationSyntax] -or
                    $_.Parent -is [Microsoft.CodeAnalysis.CSharp.Syntax.FieldDeclarationSyntax])
            })) {
                $counts['IFX.C1.PAYLOAD_TYPE_SOURCE']++
                $text = $type.ToString()
                $simple = Simple $text
                $forbidden = (Has-Property $rule 'forbiddenTypes') -and
                    ((Any-Match $text $rule.forbiddenTypes) -or (Any-Match $simple $rule.forbiddenTypes))
                $offAllowList = (Has-Property $rule 'allowedTypes') -and
                    -not ((Any-Match $text $rule.allowedTypes) -or (Any-Match $simple $rule.allowedTypes))
                if ($forbidden -or $offAllowList) {
                    Add-Finding 'PAYLOAD-TYPE-FORBIDDEN' (Source-Subject $Unit $type "$name payload $text") 'source-payload'
                }
            }
        }
    }
}

foreach ($unit in $units) { Judge-Source $unit }
foreach ($claim in $claimRules.Keys) {
    if ($counts[$claim] -eq 0) { Add-Finding $claimRules[$claim] "$($policy.scanRoot): zero matches for $claim" 'coverage' }
}
$sorted = @($findings.ToArray() | Sort-Object ruleId, subject)
$findings.Clear()
foreach ($finding in $sorted) { $findings.Add($finding) }
if (@($findings | Where-Object severity -eq 'blocking').Count -gt 0) {
    Write-Result 'fail' 'findings-blocking'
} else { Write-Result 'pass' 'success' }
