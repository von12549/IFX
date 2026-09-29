Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-PinSha256([string]$Path) {
    # 0.5.0-a (R5): a governance pin is the SHA-256 of the UTF-8 text with line endings normalized to LF, so the pin
    # does not depend on the checkout; binary files are hashed by their raw bytes.
    if ([IO.Path]::GetExtension($Path).ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.dll', '.exe')) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
    $text = [IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
}
$detector = 'ifx-g05-carriers'
$claims = @('IFX.C4.G05_CONTRACT_CARRIER','IFX.C4.G05_EVENT_CARRIER')
$rules = @('G05-CONTRACT-CARRIER','G05-EVENT-CARRIER')
$matched = @(0,0)
$findings = [Collections.Generic.List[object]]::new()
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Emit([string] $Status,[string] $Category,[string] $Message = '') {
    $coverage = for ($i=0;$i -lt 2;$i++) { [ordered]@{claimId=$claims[$i];matched=[int]$matched[$i];minimum=1} }
    $result = [ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@($coverage)}
    if ($Message) { $result.message=$Message }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string] $Category,[string] $Message) { Emit 'error' $Category $Message; exit 0 }
function Is-Under([string] $Path,[string] $Root) {
    $relative=[IO.Path]::GetRelativePath($Root,$Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)
}
function Assert-NoLink([string] $Path,[string] $Root) {
    $cursor=[IO.Path]::GetFullPath($Path)
    while (Is-Under $cursor $Root) {
        if ([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)) {
            $item=Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Stop-Adapter 'unsafe-path' "Linked carrier authority: $Path" }
        }
        if ($cursor -ceq $Root) { break }
        $parent=[IO.Path]::GetDirectoryName($cursor)
        if (-not $parent -or $parent -ceq $cursor) { break }
        $cursor=$parent
    }
}
function Json-Value($Document,[string] $Path) {
    $current=$Document
    foreach ($part in $Path.Split('.')) {
        if ($null -eq $current -or $current -isnot [System.Collections.IDictionary] -or -not $current.Contains($part)) { return $null }
        $current=$current[$part]
    }
    return $current
}
function Regex-Has([string] $Text,[string] $Pattern) {
    try { [Regex]::IsMatch($Text,$Pattern,[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1)) }
    catch { return $false }
}
function Test-Clause($Clause,[hashtable] $Texts,[hashtable] $Documents) {
    $alias=[string]$Clause.alias
    if (-not $Texts.ContainsKey($alias)) { return $false }
    $body=[string]$Texts[$alias]
    switch ([string]$Clause.op) {
        'exists' { return -not [string]::IsNullOrWhiteSpace($body) }
        'all' { foreach ($pattern in @($Clause.patterns)) { if (-not (Regex-Has $body ([string]$pattern))) { return $false } }; return $true }
        'none' { foreach ($pattern in @($Clause.patterns)) { if (Regex-Has $body ([string]$pattern)) { return $false } }; return $true }
        'jsonEquals' { $actual=Json-Value $Documents[$alias] ([string]$Clause.path); return $null -ne $actual -and $actual -ceq $Clause.value }
        'jsonRegex' { $actual=Json-Value $Documents[$alias] ([string]$Clause.path); return $null -ne $actual -and (Regex-Has ([string]$actual) ([string]$Clause.pattern)) }
        'arrayLength' { $actual=Json-Value $Documents[$alias] ([string]$Clause.path); return $null -ne $actual -and @($actual).Count -eq [int]$Clause.count }
        'arrayEquals' { $actual=Json-Value $Documents[$alias] ([string]$Clause.path); return $null -ne $actual -and (@($actual) -join '|') -ceq (@($Clause.values) -join '|') }
        'arrayIncludes' { $actual=Json-Value $Documents[$alias] ([string]$Clause.path); if ($null -eq $actual) { return $false }; foreach ($required in @($Clause.values)) { if ($required -cnotin @($actual)) { return $false } }; return $true }
        default { return $false }
    }
}
if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'Stage input is required.' }
try { $inputObject=$env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -AsHashtable -Depth 100 } catch { Stop-Adapter 'invalid-input' 'Stage input is malformed.' }
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims) -join '|') -cne ($claims -join '|') -or @($inputObject.relativeRoots) -notcontains 'src') { Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.' }
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Directory]::Exists($target)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $target $target
$policyPath=Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath) -or (Hash $policyPath) -cne [string]$inputObject.config.policySha256) { Stop-Adapter 'integrity-failure' 'Carrier policy hash drift.' }
try { $policy=Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100 } catch { Stop-Adapter 'integrity-failure' 'Carrier policy is malformed.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g05-carriers-050a' -or $policy.pinPolicy -cne 'governance-only' -or @($policy.authorities).Count -ne 13 -or @($policy.predicates).Count -ne 19) { Stop-Adapter 'integrity-failure' 'Carrier policy identity drift.' }
# 0.5.0-a: governance authorities keep their Profile pins; each live authority is bound to its current bytes, so the
# unchanged loop below verifies pins only where the policy marks a governance authority (pinned).
$pinned=@($policy.authorities | Where-Object { $_.pinned -eq $true })
$configLocks=@($inputObject.config.authorityHashes)
if($pinned.Count -ne 10 -or $configLocks.Count -ne $pinned.Count){Stop-Adapter 'invalid-input' 'Governance authority lock count mismatch.'}
for($k=0;$k -lt $pinned.Count;$k++){if($pinned[$k].id -cne $configLocks[$k].id){Stop-Adapter 'invalid-input' "Governance authority lock mismatch: $k"}}
$locks=@(foreach($pa in @($policy.authorities)){
    if($pa.pinned -eq $true){@($configLocks | Where-Object { $_.id -ceq $pa.id })[0]}
    else{
        $liveRelative=[string]$pa.path;$liveFull=[IO.Path]::GetFullPath((Join-Path $target $liveRelative))
        $liveSafe=-not [IO.Path]::IsPathRooted($liveRelative) -and $liveRelative -notmatch '(^|[\\/])\.\.([\\/]|$)' -and (Is-Under $liveFull $target) -and [IO.File]::Exists($liveFull) -and ((Get-Item -LiteralPath $liveFull -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0
        [ordered]@{id=[string]$pa.id;sha256=$(if($liveSafe){(Get-PinSha256 $liveFull)}else{'0'*64})}
    }
})
if($locks.Count -ne 13){Stop-Adapter 'invalid-input' 'Authority lock count mismatch.'}
$texts=@{};$documents=@{}
for ($i=0;$i -lt 13;$i++) {
    $authority=$policy.authorities[$i];$lock=$locks[$i];$relative=[string]$authority.path
    if ($authority.id -cne $lock.id -or [string]$lock.sha256 -cnotmatch '^[a-f0-9]{64}$' -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)') { Stop-Adapter 'invalid-input' "Authority lock mismatch: $i" }
    $full=[IO.Path]::GetFullPath((Join-Path $target $relative))
    if (-not (Is-Under $full $target)) { Stop-Adapter 'unsafe-path' "Authority escapes TargetRoot: $relative" }
    Assert-NoLink $full $target
    if (-not [IO.File]::Exists($full)) { Stop-Adapter 'prerequisite-missing' "Missing authority: $relative" }
    if ((Get-PinSha256 $full) -cne [string]$lock.sha256) { Stop-Adapter 'integrity-failure' "Stale authority: $relative" }
    $body=[IO.File]::ReadAllText($full);$texts[[string]$authority.id]=$body
    if ($authority.kind -ceq 'json' -and -not [string]::IsNullOrWhiteSpace($body)) {
        try { $documents[[string]$authority.id]=$body | ConvertFrom-Json -AsHashtable -Depth 100 } catch { Stop-Adapter 'integrity-failure' "Malformed JSON authority: $relative" }
    }
}
foreach ($predicate in @($policy.predicates)) {
    $phase=[int]$predicate.phase;$index=if($phase -eq 4){0}elseif($phase -eq 5){1}else{-1}
    if ($index -lt 0 -or [string]::IsNullOrWhiteSpace([string]$predicate.id) -or @($predicate.clauses).Count -eq 0) { Stop-Adapter 'integrity-failure' 'Predicate identity drift.' }
    $present=$false;$passed=$true
    foreach ($clause in @($predicate.clauses)) {
        $alias=[string]$clause.alias
        if (-not $texts.ContainsKey($alias)) { Stop-Adapter 'integrity-failure' "Unknown carrier authority alias: $alias" }
        if (-not [string]::IsNullOrWhiteSpace([string]$texts[$alias])) { $present=$true }
        if (-not (Test-Clause $clause $texts $documents)) { $passed=$false }
    }
    if ($present) { $matched[$index]++ }
    if (-not $passed) { $findings.Add([ordered]@{ruleId=$rules[$index];subject=[string]$predicate.id;evidenceKind='carrier-conformance';detectorId=$detector;severity='blocking'}) }
}
for ($i=0;$i -lt 2;$i++) { if ($matched[$i] -lt 1) { $findings.Add([ordered]@{ruleId=$rules[$i];subject='zero-subject';evidenceKind='coverage';detectorId=$detector;severity='blocking'}) } }
if ($findings.Count -gt 0) { Emit 'fail' 'findings-blocking' } else { Emit 'pass' 'success' }
