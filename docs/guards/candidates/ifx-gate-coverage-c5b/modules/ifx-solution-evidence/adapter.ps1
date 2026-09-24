Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$claim='IFX.C5.SOLUTION_QUALITY';$rule='SOLUTION-LOCKED-QUALITY';$detector='ifx-solution-evidence'
$findings=[Collections.Generic.List[object]]::new();$matched=0
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Text-Hash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Parse-Time($Value){if($Value -is [DateTime]){return [DateTimeOffset]$Value};return [DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)}
function Tree-Lines([string]$Root){
    $files=@(foreach($relative in @('src','tests','tools')){
        $folder=Join-Path $Root $relative
        if(-not [IO.Directory]::Exists($folder)){return @()}
        Get-ChildItem -LiteralPath $folder -File -Recurse -Force |
            Where-Object { $_.Extension -in '.cs','.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]' }
    })
    $solution=Join-Path $Root 'IFX.sln';if(-not [IO.File]::Exists($solution)){return @()}
    $files+=Get-Item -LiteralPath $solution
    return @($files|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})
}
function Emit([string]$Status,[string]$Category,[string]$Message=''){
    $result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@([ordered]@{claimId=$claim;matched=[int]$matched;minimum=4})}
    if($Message){$result.message=$Message}
    [Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 50 -Compress))
}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Record([string]$Subject,[string]$Kind,[bool]$Pass){$script:matched++;if(-not $Pass){$findings.Add([ordered]@{ruleId=$rule;subject=$Subject;evidenceKind=$Kind;detectorId=$detector;severity='blocking'})}}
function Is-Under([string]$Path,[string]$Root){$relative=[IO.Path]::GetRelativePath($Root,$Path);$relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Resolve-Locked([string]$Relative,[string]$Expected){
    if([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or $Expected -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'invalid-input' 'Invalid evidence path or hash.'}
    $full=[IO.Path]::GetFullPath((Join-Path $target $Relative));if(-not(Is-Under $full $target)){Stop-Adapter 'unsafe-path' 'Evidence escapes TargetRoot.'}
    $cursor=$full
    while(Is-Under $cursor $target){
        if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked evidence: $Relative"}}
        if($cursor -ceq $target){break};$cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing evidence: $Relative"}
    if((Hash $full) -cne $Expected){Stop-Adapter 'integrity-failure' "Altered evidence: $Relative"}
    return $full
}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Malformed stage input.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'src' -or @($inputObject.relativeRoots) -notcontains 'tests'){Stop-Adapter 'invalid-input' 'Stage or claim selection invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'invalid-input' 'TargetRoot must be absolute.'}
$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot missing.'}
$policyFile=Join-Path $PSScriptRoot 'policy.json'
if(-not [IO.File]::Exists($policyFile) -or (Hash $policyFile) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Solution policy drift.'}
try{$policy=Get-Content $policyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed Solution policy.'}
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-solution-evidence-c5b' -or $policy.expectedProjectCount -ne 81 -or @($policy.checkIds).Count -ne 4){Stop-Adapter 'integrity-failure' 'Solution policy shape drift.'}
$lockFile=Resolve-Locked ([string]$inputObject.config.evidenceLockPath) ([string]$inputObject.config.evidenceLockSha256)
try{$lock=Get-Content $lockFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed Solution lock.'}
if($lock.formatVersion -ne 1 -or $lock.gate -cne 'Solution' -or $lock.producer -cne 'ifx-c5b-controlled-v1' -or $lock.result -cne 'passed' -or $lock.targetCommit -cnotmatch '^[a-f0-9]{40}$' -or $lock.projectCount -ne 81 -or $lock.testRunCount -lt 1 -or $lock.totalTests -lt 1){Stop-Adapter 'integrity-failure' 'Incomplete Solution lock.'}
if($lock.authorityHashes.quality -cne $policy.authorityHashes.quality -or $lock.authorityHashes.audit -cne $policy.authorityHashes.audit){Stop-Adapter 'integrity-failure' 'Quality authority drift.'}
try{$started=Parse-Time $lock.startedAt;$completed=Parse-Time $lock.completedAt}catch{Stop-Adapter 'integrity-failure' 'Invalid Solution evidence time.'}
$now=[DateTimeOffset]::UtcNow
if($completed -lt $started -or $completed -gt $now.AddMinutes(5) -or $completed -lt $now.AddHours(-24)){Stop-Adapter 'integrity-failure' 'Solution evidence stale or future-dated.'}
$sourceLines=@(Tree-Lines $target)
if($sourceLines.Count -lt 81 -or $sourceLines.Count -ne $lock.sourceFileCount -or (Text-Hash ($sourceLines -join "`n")) -cne $lock.sourceTreeSha256){Stop-Adapter 'integrity-failure' 'Solution source tree drift.'}
$prefix=[string]$lock.evidencePrefix
if($prefix -cnotmatch '^artifacts/guards/p10-ifx-c5b/solution-runs/[a-f0-9]{32}/$'){Stop-Adapter 'unsafe-path' 'Uncontrolled Solution evidence prefix.'}
$evidence=@{};$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach($entry in $lock.files){
    $relative=[string]$entry.path
    if(-not $relative.StartsWith($prefix+'quality/',[StringComparison]::Ordinal) -or -not $seen.Add($relative)){Stop-Adapter 'integrity-failure' 'Duplicate or out-of-scope evidence.'}
    $evidence[$relative]=Resolve-Locked $relative ([string]$entry.sha256)
}
$summaryPath=$prefix+'quality/summary.json';$auditPath=$prefix+'quality/nuget-audit.json'
if(-not $evidence.ContainsKey($summaryPath) -or -not $evidence.ContainsKey($auditPath)){Stop-Adapter 'prerequisite-missing' 'Summary or NuGet audit not locked.'}
$trxPaths=@($evidence.Keys|Where-Object{$_ -cmatch '^artifacts/guards/p10-ifx-c5b/solution-runs/[a-f0-9]{32}/quality/solution-test-results/[^/]+\.trx$'})
if($trxPaths.Count -ne $lock.testRunCount -or $evidence.Count -ne $trxPaths.Count+2){Stop-Adapter 'integrity-failure' 'TRX evidence count drift.'}
try{$summary=Get-Content $evidence[$summaryPath] -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$audit=Get-Content $evidence[$auditPath] -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed quality summary or audit.'}
$total=0;$testPass=$true
foreach($path in $trxPaths){
    try{[xml]$xml=Get-Content -LiteralPath $evidence[$path] -Raw;$counters=$xml.SelectSingleNode("//*[local-name()='Counters']");if($null -eq $counters -or [int]$counters.total -lt 1 -or [int]$counters.failed -ne 0 -or [int]$counters.error -ne 0){$testPass=$false}else{$total+=[int]$counters.total}}catch{$testPass=$false}
}
Record 'controlledSolutionPassed' 'quality-summary' ($summary.status -ceq 'pass' -and @($summary.checks|Where-Object{$_.id -ceq 'Solution' -and $_.status -ceq 'pass'}).Count -eq 1)
Record 'nugetDirectTransitiveAudit' 'nuget-audit' ($audit.status -ceq 'pass' -and $audit.projectCount -eq 81 -and @($audit.audit.projects).Count -eq 81 -and $audit.auditMode -ceq 'all' -and @($audit.findings).Count -eq 0 -and @($audit.blockingSeverities) -contains 'high' -and @($audit.blockingSeverities) -contains 'critical')
Record 'nonVacuousSolutionTests' 'test-results' ($testPass -and $trxPaths.Count -gt 0 -and $total -eq $lock.totalTests -and $total -gt 0)
Record 'freshLockedSource' 'source-inventory' $true
if((@($policy.checkIds)-join '|') -cne (@('controlledSolutionPassed','nugetDirectTransitiveAudit','nonVacuousSolutionTests','freshLockedSource')-join '|')){Stop-Adapter 'integrity-failure' 'Solution check mapping drift.'}
if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
