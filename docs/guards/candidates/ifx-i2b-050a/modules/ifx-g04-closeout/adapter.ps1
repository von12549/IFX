Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Get-PinSha256([string]$Path) {
    # 0.5.0-a (R5): a governance pin is the SHA-256 of the UTF-8 text with line endings normalized to LF, so the pin
    # does not depend on the checkout; binary files are hashed by their raw bytes.
    if ([IO.Path]::GetExtension($Path).ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.dll', '.exe')) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
    $text = [IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
}
$detector='ifx-g04-closeout'
$claims=@('IFX.C3.G04_EVIDENCE','IFX.C3.G04_DOCUMENTATION','IFX.C3.G04_CLOSEOUT','IFX.C3.G04_INBOUND_CLOSEOUT')
$rules=@('G04-EVIDENCE','G04-DOCUMENTATION','G04-CLOSEOUT','G04-INBOUND-CLOSEOUT')
$matched=@(0,0,0,0);$findings=[Collections.Generic.List[object]]::new();$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
function Emit([string]$Status,[string]$Category,[string]$Message=''){
    $coverage=for($n=0;$n -lt 4;$n++){[ordered]@{claimId=$claims[$n];matched=[int]$matched[$n];minimum=1}}
    $result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@($coverage)}
    if($Message){$result.message=$Message};[Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Check([string]$Id,[int]$Family,[bool]$Condition,[int]$Subjects=1){
    if(-not $seen.Add($Id)){Stop-Adapter 'integrity-failure' "Duplicate predicate: $Id"}
    $matched[$Family]+=[Math]::Max(0,$Subjects)
    if(-not $Condition){$findings.Add([ordered]@{ruleId=$rules[$Family];subject=$Id;evidenceKind='closeout-evidence';detectorId=$detector;severity='blocking'})}
}
function Is-Under([string]$Path,[string]$Root){$r=[IO.Path]::GetRelativePath($Root,$Path);return $r -ne '..' -and -not [IO.Path]::IsPathRooted($r) -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Assert-NoLink([string]$Path,[string]$Root){
    $current=[IO.Path]::GetFullPath($Path)
    while(Is-Under $current $Root){
        if([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)){$item=Get-Item -LiteralPath $current -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked authority: $Path"}}
        if($current -ceq $Root){break};$parent=[IO.Path]::GetDirectoryName($current);if(-not $parent -or $parent -ceq $current){break};$current=$parent
    }
}
function Read-Authority([string]$Root,[string]$Relative,[string]$ExpectedHash){
    if([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or $Relative -match '[*?]'){Stop-Adapter 'integrity-failure' "Unsafe authority path: $Relative"}
    $full=[IO.Path]::GetFullPath((Join-Path $Root $Relative));if(-not(Is-Under $full $Root)){Stop-Adapter 'integrity-failure' "Escaping authority: $Relative"}
    Assert-NoLink $full $Root
    if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing authority: $Relative"}
    # 0.5.0-a: only governance authorities are pinned (ExpectedHash); live sources are read as they are.
    if($ExpectedHash -and (Get-PinSha256 $full) -cne $ExpectedHash){Stop-Adapter 'integrity-failure' "Stale governance authority: $Relative"}
    return $full
}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Stage input is malformed.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims) -join '|') -cne ($claims -join '|') -or @($inputObject.relativeRoots) -notcontains 'docs'){Stop-Adapter 'invalid-input' 'Stage or claims are invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'}
$targetRoot=[IO.Path]::GetFullPath([string]$inputObject.targetRoot);if(-not [IO.Directory]::Exists($targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.'};Assert-NoLink $targetRoot $targetRoot
$policyPath=Join-Path $PSScriptRoot 'policy.json';if(-not [IO.File]::Exists($policyPath)){Stop-Adapter 'integrity-failure' 'Candidate policy is missing.'}
if((Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.'}
try{$policy=Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.'}
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g04-closeout-050a' -or $policy.pinPolicy -cne 'governance-only' -or @($policy.authorities).Count -ne 43 -or @($policy.activeCheckIds).Count -ne 20 -or @($policy.deferredCheckIds).Count -ne 3){Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.'}
$pinned=@($policy.authorities | Where-Object { $_.pinned -eq $true })
$locks=@($inputObject.config.authorityHashes);if($pinned.Count -ne 42 -or $locks.Count -ne $pinned.Count){Stop-Adapter 'invalid-input' 'Governance authority lock count mismatch.'}
for($n=0;$n -lt $pinned.Count;$n++){if($pinned[$n].id -cne $locks[$n].id -or [string]$locks[$n].sha256 -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'invalid-input' "Governance authority lock mismatch: $n"}}
$texts=@{};$sizes=@{}
foreach($a in @($policy.authorities)){
    $expected=if($a.pinned -eq $true){[string](@($locks | Where-Object { $_.id -ceq $a.id })[0].sha256)}else{''}
    $path=Read-Authority $targetRoot ([string]$a.path) $expected
    $sizes[[string]$a.id]=([IO.FileInfo]$path).Length
    if($a.path -notlike '*.png'){$texts[[string]$a.id]=[IO.File]::ReadAllText($path)}
}
try{
    $evidence=@(
        @('phaseBaselineExists','phase0'),@('leaseConformanceDocumented','leaseEvidence'),@('phase5EvidenceExists','phase5'),
        @('phase6EvidenceExists','phase6'),@('recoveryRunbookExists','recoveryRunbook'),@('phase7EvidenceExists','phase7'),
        @('phase8EvidenceTemplateExists','releaseTemplate'),@('phase8EvidenceExists','phase8'),@('failureRunbookExists','failureRunbook'),
        @('phase9EvidenceExists','phase9'),@('phase10EvidenceExists','phase10'),@('phase11EvidenceExists','phase11'),
        @('phase12EvidenceExists','phase12Handoff')
    )
    foreach($pair in $evidence){Check $pair[0] 0 ($sizes[$pair[1]] -gt 0)}
    $zh=[string]$texts['zh'];$en=[string]$texts['en']
    $zhIds=@([Regex]::Matches($zh,'G04-D\d{2}') | ForEach-Object Value | Sort-Object -Unique)
    $enIds=@([Regex]::Matches($en,'G04-D\d{2}') | ForEach-Object Value | Sort-Object -Unique)
    $diagrams=$true
    foreach($base in @($policy.diagramBases)){
        foreach($ext in @('mmd','svg','png')){if($sizes["diagram-$base-$ext"] -le $(if($ext -eq 'mmd'){0}else{1000})){$diagrams=$false}}
    }
    $downstream=$true
    foreach($id in @('downstreamG02','downstreamPlan01','downstreamPlan02','downstreamLayerGuard')){if($texts[$id] -notmatch 'G04 反向链接'){$downstream=$false}}
    $docsValid=$zhIds.Count -eq 9 -and ($zhIds -join '|') -ceq ($enIds -join '|') -and $diagrams -and
        $zh -match '规则到验证机制' -and $en -match 'Rule-to-verification mapping' -and
        $zh -match 'PRE-READY' -and $en -match 'PRE-READY' -and $en -match 'E3/E4/E6' -and
        $texts['architectureIndex'] -match 'deployment-runtime-boundary\.zh-CN\.md' -and
        $texts['prerequisites'] -match 'deployment-runtime-boundary\.zh-CN\.md' -and $downstream
    Check 'documentationValidated' 1 $docsValid ($zhIds.Count + $enIds.Count + @($policy.diagramBases).Count)
    $status=$texts['g04Status'] | ConvertFrom-Json -AsHashtable -Depth 100
    $blockers=@($status.blockers);$ids=@($blockers | ForEach-Object id | Sort-Object)
    $expectedIds=@(1..7 | ForEach-Object {"G04-B0$_"})
    $deps=@($blockers | ForEach-Object dependency)
    $owned=@($blockers | Where-Object {-not $_.owner -or -not $_.revisitTrigger -or @($_.requiredEvidence).Count -eq 0}).Count -eq 0
    $parameters=@($status.productionParameters)
    $parameterOwned=$parameters.Count -ge 4 -and @($parameters | Where-Object {-not $_.owner -or -not $_.dueBy -or -not $_.validationEnvironment}).Count -eq 0
    $verification=$status.verification
    $verified=$verification.closeoutValidator -ceq 'passed' -and $verification.phase12Guard -ceq 'passed' -and
        $verification.layerGuard.passed -eq 189 -and $verification.layerGuard.failed -eq 0 -and
        $verification.solutionBuild.errors -eq 0 -and $verification.solutionTests.passed -eq 1091 -and $verification.solutionTests.failed -eq 0
    $b05=$blockers | Where-Object id -eq 'G04-B05' | Select-Object -First 1
    $handoff=[string]$texts['phase12Handoff'];$plan=[string]$texts['g04Plan'];$prerequisite=[string]$texts['prerequisites']
    $handoffComplete=@($ids | Where-Object {$handoff -notmatch [Regex]::Escape($_)}).Count -eq 0
    $closeoutValid=$status.status -ceq 'PRE-READY' -and $status.gateClosed -eq $false -and $status.approvalGranted -eq $false -and
        $ids.Count -eq 7 -and ($ids -join '|') -ceq ($expectedIds -join '|') -and
        @($policy.blockerDependencies | Where-Object {$_ -notin $deps}).Count -eq 0 -and $owned -and $parameterOwned -and $verified -and
        $b05.state -ceq 'closed-repository-evidence-complete' -and @($b05.evidence).Count -ge 3 -and $handoffComplete -and
        $plan -match '- \[ \] \*\*Phase 12 PRE-READY' -and $plan -notmatch '- \[x\] \*\*Phase 12' -and
        $plan -match '- \[ \] G04-12\.8' -and $prerequisite -match '- \[x\] \*\*Gate 4 前置放行\*\*' -and
        $plan -match 'G04-phase12-handoff\.md' -and $plan -match 'G04-phase12-status\.json'
    Check 'closeoutValidated' 2 $closeoutValid $blockers.Count
    Check 'closeoutRemainsPreReady' 2 ($status.status -ceq 'PRE-READY' -and $status.gateClosed -eq $false) $blockers.Count
    Check 'closeoutApprovalNotClaimed' 2 ($status.approvalGranted -eq $false) $blockers.Count
    $inboundPlan=[string]$texts['downstreamPlan02']
    $inboundStatus=$texts['inboundStatus'] | ConvertFrom-Json -AsHashtable -Depth 100
    $readiness=$texts['readiness'] | ConvertFrom-Json -AsHashtable -Depth 100
    Check 'checklistClosed' 3 ($inboundPlan -match '- \[x\] \*\*Phase 4 完成' -and $inboundPlan -match '- \[x\] E4\.9') 1
    Check 'evidenceRecorded' 3 ($inboundStatus.result -ceq 'passed' -and $inboundStatus.verification.solutionTests.passed -eq 1085 -and $inboundStatus.verification.solutionTests.failed -eq 0 -and $inboundStatus.verification.layerGuard.findings -eq 0) 1
    Check 'readinessAdvancedOnlyOneSlice' 3 ('P02-C1/E4.9' -in @($readiness.plan02.closedSlices) -and 'E4.9' -notin @($readiness.plan02.openChecklistItems) -and (@($readiness.plan02.phaseCompletionBoxesOpen) -join ',') -ceq '5,6,7,8') 1
    if($seen.Count -ne 20 -or (@($policy.activeCheckIds | Where-Object {-not $seen.Contains([string]$_)})).Count -gt 0){Stop-Adapter 'integrity-failure' 'Active C3d check mapping drift.'}
    for($n=0;$n -lt 4;$n++){if($matched[$n] -lt 1){$findings.Add([ordered]@{ruleId=$rules[$n];subject='zero-subject';evidenceKind='coverage';detectorId=$detector;severity='blocking'})}}
    if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
}catch{Stop-Adapter 'integrity-failure' "Invalid G04 closeout structure: $($_.Exception.Message)"}
