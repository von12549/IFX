Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$detector = 'ifx-reference-cycle'
$claims = @('IFX.C1.RING_REFERENCE_RAW', 'IFX.C1.CONTRACT_CYCLE_RAW')
$referenceMatches = 0
$contractMatches = 0
$findings = [Collections.Generic.List[object]]::new()

function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $result = [ordered]@{
        formatVersion = 1; status = $Status; exitCategory = $Category
        findings = @($findings.ToArray())
        coverage = @(
            [ordered]@{ claimId = $claims[0]; matched = $referenceMatches; minimum = 1 },
            [ordered]@{ claimId = $claims[1]; matched = $contractMatches; minimum = 1 }
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
            Stop-Adapter 'unsafe-path' 'Project path or ancestor is linked.'
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Matches([string] $Name, [string] $Pattern) {
    $expression = '^' + [regex]::Escape($Pattern).Replace('\*', '.*') + '$'
    return [regex]::IsMatch($Name, $expression, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
function Ring-Of([string] $Name) {
    foreach ($entry in $policy.rings.PSObject.Properties) {
        if (@($entry.Value | Where-Object { Matches $Name ([string]$_) }).Count -gt 0) { return $entry.Name }
    }
    return 'Outside'
}
function Read-Project([string] $Path) {
    if (-not [IO.File]::Exists($Path)) { Stop-Adapter 'prerequisite-missing' 'ProjectReference target is missing.' }
    Assert-NoLink $Path
    try {
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [Xml.XmlReader]::Create($Path, $settings)
        try {
            $xml = [xml]::new(); $xml.Load($reader)
            if ($xml.DocumentElement.LocalName -cne 'Project') { throw 'Root is not Project.' }
        }
        finally { $reader.Dispose() }
    }
    catch { Stop-Adapter 'invalid-input' "Project XML is invalid: $([IO.Path]::GetFileName($Path))." }
    $refs = [Collections.Generic.List[string]]::new()
    foreach ($reference in @($xml.SelectNodes("//*[local-name()='ProjectReference']"))) {
        $include = [string]$reference.GetAttribute('Include')
        if (-not $include) { continue }
        if ([IO.Path]::IsPathRooted($include) -or $include -match '^[A-Za-z]:') { Stop-Adapter 'unsafe-path' 'Absolute ProjectReference is forbidden.' }
        try { $to = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($Path)) ($include.Replace('\', [IO.Path]::DirectorySeparatorChar).Replace('/', [IO.Path]::DirectorySeparatorChar)))) }
        catch { Stop-Adapter 'invalid-input' 'ProjectReference path is invalid.' }
        if (-not (Is-Under $to $targetRoot)) { Stop-Adapter 'unsafe-path' 'ProjectReference escapes TargetRoot.' }
        if ([IO.Path]::GetRelativePath($targetRoot, $to).Replace('\', '/') -match '(^|/)(guard|guards)(/|$)') {
            Stop-Adapter 'unsafe-path' 'ProjectReference enters guard source.'
        }
        if ([IO.Path]::GetExtension($to) -ine '.csproj') { Stop-Adapter 'invalid-input' 'ProjectReference must target a csproj.' }
        if (-not [IO.File]::Exists($to)) { Stop-Adapter 'prerequisite-missing' 'ProjectReference target is missing.' }
        Assert-NoLink $to
        $refs.Add($to)
    }
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    return [pscustomobject]@{ path = $Path; name = $name; ring = (Ring-Of $name); refs = @($refs.ToArray()) }
}
function Add-Finding([string] $Rule, [string] $Subject, [string] $Kind) {
    $findings.Add([ordered]@{ ruleId = $Rule; subject = $Subject; evidenceKind = $Kind; detectorId = $detector; severity = 'blocking' })
}
function Visit-Cycles([string] $Name, [string[]] $Path, [Collections.Generic.HashSet[string]] $Active) {
    if ($Active.Contains($Name)) {
        $start = [Array]::FindIndex($Path, [Predicate[string]]{ param($part) [StringComparer]::OrdinalIgnoreCase.Equals($part, $Name) })
        if ($start -ge 0) {
            $cycle = @($Path[$start..($Path.Length - 1)]) + @($Name)
            $members = @($cycle[0..($cycle.Count - 2)] | Sort-Object -Unique)
            $key = ($members | ForEach-Object ToLowerInvariant) -join '|'
            if ($emittedCycles.Add($key)) { Add-Finding 'CONTRACT-CYCLE' ($cycle -join ' -> ') 'contracts-project-cycle-raw' }
        }
        return
    }
    [void]$Active.Add($Name)
    $nextPath = @($Path) + @($Name)
    foreach ($target in @($contractGraph[$Name])) { Visit-Cycles $target $nextPath $Active }
    [void]$Active.Remove($Name)
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
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-reference-cycle-c1n' -or $policy.scanRoot -cne 'src' -or
    (@($policy.claims | ForEach-Object claimId) -join '|') -cne ($claims -join '|')) {
    Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.'
}
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'src'))
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot
$stack = [Collections.Generic.Stack[string]]::new(); $stack.Push($sourceRoot)
$entries = [Collections.Generic.List[string]]::new()
while ($stack.Count -gt 0) {
    $dir = $stack.Pop()
    foreach ($item in @(Get-ChildItem -LiteralPath $dir -Force | Sort-Object Name)) {
        if ($item.PSIsContainer) {
            if ($item.Name -in @('guard','guards','generated','obj','bin','.git')) { continue }
            Assert-NoLink $item.FullName
            $stack.Push($item.FullName)
        }
        elseif ($item.Name.EndsWith('.csproj', [StringComparison]::OrdinalIgnoreCase)) {
            Assert-NoLink $item.FullName
            $entries.Add($item.FullName)
        }
    }
}
$nodes = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
$pending = [Collections.Generic.Queue[string]]::new()
foreach ($entry in $entries) { $pending.Enqueue($entry) }
while ($pending.Count -gt 0) {
    $path = $pending.Dequeue()
    if ($nodes.ContainsKey($path)) { continue }
    $node = Read-Project $path
    $nodes.Add($path, $node)
    foreach ($to in $node.refs) { $pending.Enqueue($to) }
}
foreach ($entry in @($entries.ToArray() | Sort-Object)) {
    $node = $nodes[$entry]
    if ($node.ring -ceq 'Outside') { continue }
    $allowed = @($policy.allowedReferences.PSObject.Properties[$node.ring].Value)
    foreach ($to in $node.refs) {
        $referenceMatches++
        $target = $nodes[$to]
        $targetName = $target.name
        if (@($allowed | Where-Object { Matches $targetName ([string]$_) }).Count -gt 0) { continue }
        $shared = $node.ring -notin @('Domain','Outside') -and
            @($policy.sharedPrimitiveProjects) -inotcontains $node.name -and
            @($policy.sharedPrimitiveProjects) -icontains $targetName
        if ($shared) { continue }
        $directions = @($policy.allowedDependencies.PSObject.Properties[$node.ring].Value)
        if ($target.ring -cne 'Outside' -and $target.ring -cne $node.ring -and $directions -notcontains $target.ring) { continue }
        $fromRel = [IO.Path]::GetRelativePath($targetRoot, $entry).Replace('\','/')
        $toRel = [IO.Path]::GetRelativePath($targetRoot, $to).Replace('\','/')
        Add-Finding 'RING-REFERENCE' "$fromRel -> $toRel" 'project-reference-raw'
    }
}
$contractGraph = [Collections.Generic.Dictionary[string,string[]]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($node in $nodes.Values) {
    if ($node.ring -cne 'Contracts') { continue }
    if ($contractGraph.ContainsKey($node.name)) { Stop-Adapter 'invalid-input' 'Duplicate Contracts project name.' }
    $contractMatches++
    $targets = @($node.refs | Where-Object { $nodes[$_].ring -ceq 'Contracts' } | ForEach-Object { $nodes[$_].name })
    $contractGraph.Add($node.name, [string[]]$targets)
}
$emittedCycles = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($name in @($contractGraph.Keys | Sort-Object)) {
    Visit-Cycles $name @() ([Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase))
}
if ($referenceMatches -eq 0) { Add-Finding 'RING-REFERENCE' 'src: zero direct references in configured rings' 'coverage' }
if ($contractMatches -eq 0) { Add-Finding 'CONTRACT-CYCLE' 'src: zero Contracts projects' 'coverage' }
$sorted = $findings.ToArray()
[Array]::Sort($sorted, [Comparison[object]]{ param($a,$b) [StringComparer]::Ordinal.Compare("$($a['ruleId'])|$($a['subject'])", "$($b['ruleId'])|$($b['subject'])") })
$findings.Clear(); foreach ($finding in $sorted) { $findings.Add($finding) }
Emit $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' }) $(if ($findings.Count -eq 0) { 'success' } else { 'findings-blocking' })
