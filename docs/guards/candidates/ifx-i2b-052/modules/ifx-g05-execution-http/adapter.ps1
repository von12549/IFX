Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-PinSha256([string]$Path) {
    # 0.5.0-a (R5): a governance pin is the SHA-256 of the UTF-8 text with line endings normalized to LF, so the pin
    # does not depend on the checkout; binary files are hashed by their raw bytes.
    if ([IO.Path]::GetExtension($Path).ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.dll', '.exe')) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
    $text = [IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
}
$detector='ifx-g05-execution-http'
$families=@('execution','http')
$claims=@('IFX.C4.G05_EXECUTION','IFX.C4.G05_HTTP')
$rules=@('G05-EXECUTION','G05-HTTP')
$matched=@(0,0)
$findings=[Collections.Generic.List[object]]::new()
function Emit([string]$Status,[string]$Category,[string]$Message='') {
    $coverage=for($n=0;$n -lt 2;$n++){[ordered]@{claimId=$claims[$n];matched=[int]$matched[$n];minimum=1}}
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
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked G05 authority: $Path"}
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
    if((Get-PinSha256 $full) -cne $ExpectedHash){Stop-Adapter 'integrity-failure' "Stale authority: $Relative"}
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
    if($Clause.ContainsKey('jsonArrayIncludes')){
        try{$document=$value | ConvertFrom-Json -AsHashtable -Depth 100;$items=@($document[[string]$Clause.jsonArrayIncludes.path]);foreach($required in @($Clause.jsonArrayIncludes.values)){if($required -cnotin $items){return $false}}}
        catch{return $false}
    }
    if($Clause.ContainsKey('regexCount')){
        $count=([Regex]::Matches($value,[string]$Clause.regexCount.pattern)).Count
        if($count -ne [int]$Clause.regexCount.count){return $false}
    }
    if($Clause.ContainsKey('jsonBooleanEquals')){
        try{$doc=$value | ConvertFrom-Json -AsHashtable -Depth 100;$item=$doc;foreach($segment in ([string]$Clause.jsonBooleanEquals.path).Split('.')){$item=$item[$segment]};if($item -isnot [bool] -or $item -ne [bool]$Clause.jsonBooleanEquals.value){return $false}}catch{return $false}
    }
    if($Clause.ContainsKey('jsonArrayObjectsRequired')){
        try{$doc=$value | ConvertFrom-Json -AsHashtable -Depth 100;$items=@($doc[[string]$Clause.jsonArrayObjectsRequired.path]);if($items.Count -ne [int]$Clause.jsonArrayObjectsRequired.count){return $false};foreach($item in $items){foreach($field in @($Clause.jsonArrayObjectsRequired.fields)){if([string]::IsNullOrWhiteSpace([string]$item[[string]$field])){return $false}}}}catch{return $false}
    }
    if($Clause.ContainsKey('presentationScopeBalanced')){
        $groups=([Regex]::Matches($value,'MapGroup\(')).Count
        $scopes=([Regex]::Matches($value,'WithMetadata\(ExecutionScopeRequirement\.(Tenant|Platform|Public)\)')).Count
        if($groups -le 10 -or $groups -ne $scopes){return $false}
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
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g05-execution-http-050a' -or $policy.pinPolicy -cne 'governance-only' -or (@($policy.families) -join '|') -cne ($families -join '|') -or @($policy.authorities).Count -ne 20 -or @($policy.predicates).Count -ne 19){Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.'}
# 0.5.0-a: governance authorities keep their Profile pins; each live authority is bound to its current bytes, so the
# unchanged loop below verifies pins only where the policy marks a governance authority (pinned).
$pinned=@($policy.authorities | Where-Object { $_.pinned -eq $true })
$configLocks=@($inputObject.config.authorityHashes)
if($pinned.Count -ne 5 -or $configLocks.Count -ne $pinned.Count){Stop-Adapter 'invalid-input' 'Governance authority lock count mismatch.'}
for($k=0;$k -lt $pinned.Count;$k++){if($pinned[$k].id -cne $configLocks[$k].id){Stop-Adapter 'invalid-input' "Governance authority lock mismatch: $k"}}
$locks=@(foreach($pa in @($policy.authorities)){
    if($pa.pinned -eq $true){@($configLocks | Where-Object { $_.id -ceq $pa.id })[0]}
    else{
        $liveRelative=[string]$pa.path;$liveFull=[IO.Path]::GetFullPath((Join-Path $targetRoot $liveRelative))
        $liveSafe=-not [IO.Path]::IsPathRooted($liveRelative) -and $liveRelative -notmatch '(^|[\\/])\.\.([\\/]|$)' -and (Is-Under $liveFull $targetRoot) -and [IO.File]::Exists($liveFull) -and ((Get-Item -LiteralPath $liveFull -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0
        [ordered]@{id=[string]$pa.id;sha256=$(if($liveSafe){(Get-PinSha256 $liveFull)}else{'0'*64})}
    }
})
if($locks.Count -ne 20){Stop-Adapter 'invalid-input' 'Authority lock count mismatch.'}
$texts=@{}
for($n=0;$n -lt 20;$n++){
    $a=$policy.authorities[$n];$lock=$locks[$n]
    if($a.id -cne $lock.id -or [string]$lock.sha256 -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'invalid-input' "Authority lock mismatch: $n"}
    $texts[[string]$a.id]=Read-Authority $targetRoot ([string]$a.path) ([string]$lock.sha256)
}
$presentationRoot=[IO.Path]::GetFullPath((Join-Path $targetRoot ([string]$policy.presentationRoot)))
if(-not(Is-Under $presentationRoot $targetRoot) -or -not [IO.Directory]::Exists($presentationRoot)){Stop-Adapter 'prerequisite-missing' 'Presentation source root is missing.'}
Assert-NoLink $presentationRoot $targetRoot
$presentationFiles=@(Get-ChildItem -LiteralPath $presentationRoot -Recurse -File -Filter '*.cs' | Where-Object {$_.FullName -match '\.Presentation' -and $_.FullName -notmatch '[\\/](bin|obj)[\\/]'} | Sort-Object FullName)
if($presentationFiles.Count -le 10){Stop-Adapter 'prerequisite-missing' 'Presentation source set is empty or incomplete.'}
foreach($file in $presentationFiles){Assert-NoLink $file.FullName $targetRoot}
$sourceSet=@($presentationFiles | ForEach-Object {"$([IO.Path]::GetRelativePath($targetRoot,$_.FullName).Replace('\','/'))|$((Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant())"}) -join "`n"
$sourceSetHash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($sourceSet))).ToLowerInvariant()
# 0.5.0-a: the live source set is no longer compared with a Profile fingerprint (presentationSha256); the checks below read its current content.
$texts['presentation']=@($presentationFiles | ForEach-Object {[IO.File]::ReadAllText($_.FullName)}) -join "`n"
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
    for($n=0;$n -lt 2;$n++){if($matched[$n] -lt 1){$findings.Add([ordered]@{ruleId=$rules[$n];subject='zero-subject';evidenceKind='coverage';detectorId=$detector;severity='blocking'})}}
    if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
}catch{Stop-Adapter 'integrity-failure' "Invalid G05 predicate structure: $($_.Exception.Message)"}
