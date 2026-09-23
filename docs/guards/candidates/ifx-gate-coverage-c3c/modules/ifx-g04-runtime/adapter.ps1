Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$detector='ifx-g04-runtime'
$families=@('role','startup','worker','drain','health','backpressure','inbound')
$claims=@('IFX.C3.G04_ROLE','IFX.C3.G04_STARTUP','IFX.C3.G04_WORKER','IFX.C3.G04_DRAIN','IFX.C3.G04_HEALTH','IFX.C3.G04_BACKPRESSURE','IFX.C3.G04_INBOUND')
$rules=@('G04-ROLE','G04-STARTUP','G04-WORKER','G04-DRAIN','G04-HEALTH','G04-BACKPRESSURE','G04-INBOUND')
$matched=@(0,0,0,0,0,0,0)
$findings=[Collections.Generic.List[object]]::new()
function Emit([string]$Status,[string]$Category,[string]$Message='') {
    $coverage=for($n=0;$n -lt 7;$n++){[ordered]@{claimId=$claims[$n];matched=[int]$matched[$n];minimum=1}}
    $result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@($coverage)}
    if($Message){$result.message=$Message}
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Is-Under([string]$Path,[string]$Root){
    $rel=[IO.Path]::GetRelativePath($Root,$Path)
    return $rel -ne '..' -and -not [IO.Path]::IsPathRooted($rel) -and -not $rel.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)
}
function Assert-NoLink([string]$Path,[string]$Root){
    $cursor=[IO.Path]::GetFullPath($Path)
    while(Is-Under $cursor $Root){
        if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){
            $item=Get-Item -LiteralPath $cursor -Force
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked G04 authority: $Path"}
        }
        if($cursor -ceq $Root){break}
        $parent=[IO.Path]::GetDirectoryName($cursor);if(-not $parent -or $parent -ceq $cursor){break};$cursor=$parent
    }
}
function Read-Authority([string]$Root,[string]$Relative,[string]$ExpectedHash){
    if([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or $Relative -match '[*?]'){Stop-Adapter 'integrity-failure' "Unsafe authority path: $Relative"}
    $full=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if(-not(Is-Under $full $Root)){Stop-Adapter 'integrity-failure' "Authority escapes TargetRoot: $Relative"}
    Assert-NoLink $full $Root
    if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing authority: $Relative"}
    if((Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash.ToLowerInvariant() -cne $ExpectedHash){Stop-Adapter 'integrity-failure' "Stale authority: $Relative"}
    return [IO.File]::ReadAllText($full)
}
function Regex-Match([string]$Value,[string]$Pattern){
    return [Regex]::IsMatch($Value,$Pattern,[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1))
}
function Test-Clause($Clause,[hashtable]$Texts){
    if(-not $Texts.ContainsKey([string]$Clause.alias)){return $false}
    $value=[string]$Texts[[string]$Clause.alias]
    if($Clause.ContainsKey('exists') -and $Clause.exists -eq $true){return -not [string]::IsNullOrWhiteSpace($value)}
    if($Clause.ContainsKey('all')){foreach($pattern in @($Clause.all)){if(-not(Regex-Match $value ([string]$pattern))){return $false}}}
    if($Clause.ContainsKey('none')){foreach($pattern in @($Clause.none)){if(Regex-Match $value ([string]$pattern)){return $false}}}
    if($Clause.ContainsKey('order')){
        $previous=-1
        foreach($token in @($Clause.order)){$index=$value.IndexOf([string]$token,$previous+1,[StringComparison]::Ordinal);if($index -lt 0 -or $index -le $previous){return $false};$previous=$index}
    }
    if($Clause.ContainsKey('jsonArrayAtLeast')){
        try{$document=$value | ConvertFrom-Json -AsHashtable -Depth 100;$items=@($document[[string]$Clause.jsonArrayAtLeast.path]);if($items.Count -lt [int]$Clause.jsonArrayAtLeast.count){return $false}}
        catch{return $false}
    }
    return $true
}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Stage input is malformed.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims) -join '|') -cne ($claims -join '|') -or @($inputObject.relativeRoots) -notcontains 'src'){Stop-Adapter 'invalid-input' 'Stage or claims are invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'}
$targetRoot=[IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if(-not [IO.Directory]::Exists($targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.'}
Assert-NoLink $targetRoot $targetRoot
$policyPath=Join-Path $PSScriptRoot 'policy.json'
if(-not [IO.File]::Exists($policyPath)){Stop-Adapter 'integrity-failure' 'Candidate policy is missing.'}
if((Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.'}
try{$policy=Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.'}
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g04-runtime-c3c' -or (@($policy.families) -join '|') -cne ($families -join '|') -or @($policy.authorities).Count -ne 20 -or @($policy.predicates).Count -ne 47){Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.'}
$locks=@($inputObject.config.authorityHashes)
if($locks.Count -ne 20){Stop-Adapter 'invalid-input' 'Authority lock count mismatch.'}
$texts=@{}
for($n=0;$n -lt 20;$n++){
    $a=$policy.authorities[$n];$lock=$locks[$n]
    if($a.id -cne $lock.id -or [string]$lock.sha256 -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'invalid-input' "Authority lock mismatch: $n"}
    $texts[[string]$a.id]=Read-Authority $targetRoot ([string]$a.path) ([string]$lock.sha256)
}
try{
    foreach($predicate in @($policy.predicates)){
        $family=[Array]::IndexOf($families,[string]$predicate.family)
        if($family -lt 0 -or [string]::IsNullOrWhiteSpace([string]$predicate.id) -or @($predicate.clauses).Count -eq 0){Stop-Adapter 'integrity-failure' 'Predicate identity drift.'}
        $ok=$true;$nonempty=$false
        foreach($clause in @($predicate.clauses)){
            if(-not $texts.ContainsKey([string]$clause.alias)){Stop-Adapter 'integrity-failure' "Unknown authority alias: $($clause.alias)"}
            if(-not [string]::IsNullOrWhiteSpace([string]$texts[[string]$clause.alias])){$nonempty=$true}
            if(-not(Test-Clause $clause $texts)){$ok=$false}
        }
        if($nonempty){$matched[$family]++}
        if(-not $ok){$findings.Add([ordered]@{ruleId=$rules[$family];subject=[string]$predicate.id;evidenceKind='runtime-source';detectorId=$detector;severity='blocking'})}
    }
    for($n=0;$n -lt 7;$n++){if($matched[$n] -lt 1){$findings.Add([ordered]@{ruleId=$rules[$n];subject='zero-subject';evidenceKind='coverage';detectorId=$detector;severity='blocking'})}}
    if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
}catch{Stop-Adapter 'integrity-failure' "Invalid G04 predicate structure: $($_.Exception.Message)"}
