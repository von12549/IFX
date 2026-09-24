Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$claim='IFX.C5.ASSEMBLY_QUALITY';$rule='ASSEMBLY-COMPILED-REFERENCES';$detector='ifx-assembly-evidence'
$findings=[Collections.Generic.List[object]]::new();$matched=0
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Text-Hash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Parse-Time($Value){if($Value -is [DateTime]){return [DateTimeOffset]$Value};return [DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)}
function Tree-Lines([string]$Root){
    $files=@(foreach($relative in @('src','tests','tools')){$folder=Join-Path $Root $relative;if(-not [IO.Directory]::Exists($folder)){return @()};Get-ChildItem -LiteralPath $folder -File -Recurse -Force|Where-Object{$_.Extension -in '.cs','.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]' }})
    $solution=Join-Path $Root 'IFX.sln';if(-not [IO.File]::Exists($solution)){return @()};$files+=Get-Item -LiteralPath $solution
    return @($files|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})
}
function Emit([string]$Status,[string]$Category,[string]$Message=''){$r=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@([ordered]@{claimId=$claim;matched=[int]$matched;minimum=7})};if($Message){$r.message=$Message};[Console]::Out.WriteLine(($r|ConvertTo-Json -Depth 50 -Compress))}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Record([string]$Subject,[string]$Kind,[bool]$Pass){$script:matched++;if(-not $Pass){$findings.Add([ordered]@{ruleId=$rule;subject=$Subject;evidenceKind=$Kind;detectorId=$detector;severity='blocking'})}}
function Is-Under([string]$Path,[string]$Root){$relative=[IO.Path]::GetRelativePath($Root,$Path);$relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Resolve-Locked([string]$Relative,[string]$Expected){
    if([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or $Expected -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'invalid-input' 'Invalid locked path or hash.'}
    $full=[IO.Path]::GetFullPath((Join-Path $target $Relative));if(-not(Is-Under $full $target)){Stop-Adapter 'unsafe-path' 'Path escapes TargetRoot.'}
    $cursor=$full;while(Is-Under $cursor $target){if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked input: $Relative"}};if($cursor -ceq $target){break};$cursor=[IO.Path]::GetDirectoryName($cursor)}
    if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing input: $Relative"}
    if((Hash $full) -cne $Expected){Stop-Adapter 'integrity-failure' "Altered input: $Relative"}
    return $full
}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Malformed stage input.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'src' -or @($inputObject.relativeRoots) -notcontains 'tests'){Stop-Adapter 'invalid-input' 'Stage or claim selection invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'invalid-input' 'TargetRoot must be absolute.'};$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot missing.'}
$policyFile=Join-Path $PSScriptRoot 'policy.json';if(-not [IO.File]::Exists($policyFile) -or (Hash $policyFile) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Assembly policy drift.'}
try{$policy=Get-Content $policyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed Assembly policy.'}
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-assembly-evidence-c5c' -or @($policy.assemblies).Count -ne 5 -or (@($policy.allowedDomainReferences)-join '|') -cne 'IFX.BuildingBlocks.Domain'){Stop-Adapter 'integrity-failure' 'Assembly policy shape drift.'}
$lockFile=Resolve-Locked ([string]$inputObject.config.evidenceLockPath) ([string]$inputObject.config.evidenceLockSha256)
try{$lock=Get-Content $lockFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed Assembly lock.'}
if($lock.formatVersion -ne 1 -or $lock.gate -cne 'Assembly' -or $lock.producer -cne 'ifx-c5c-controlled-v1' -or $lock.result -cne 'passed' -or $lock.targetCommit -cnotmatch '^[a-f0-9]{40}$' -or @($lock.assemblies).Count -ne 5){Stop-Adapter 'integrity-failure' 'Incomplete Assembly lock.'}
if($lock.authorityHashes.assembly -cne $policy.authorityHashes.assembly -or $lock.authorityHashes.domainPolicy -cne $policy.authorityHashes.domainPolicy){Stop-Adapter 'integrity-failure' 'Assembly authority drift.'}
try{$started=Parse-Time $lock.startedAt;$completed=Parse-Time $lock.completedAt}catch{Stop-Adapter 'integrity-failure' 'Invalid Assembly time.'}
$now=[DateTimeOffset]::UtcNow;if($completed -lt $started -or $completed -gt $now.AddMinutes(5) -or $completed -lt $now.AddHours(-24)){Stop-Adapter 'integrity-failure' 'Assembly evidence stale or future-dated.'}
$source=@(Tree-Lines $target);if($source.Count -lt 81 -or $source.Count -ne $lock.sourceFileCount -or (Text-Hash ($source -join "`n")) -cne $lock.sourceTreeSha256){Stop-Adapter 'integrity-failure' 'Assembly source tree drift.'}
$solutionFile=Resolve-Locked ([string]$lock.solutionLockPath) ([string]$lock.solutionLockSha256)
try{$solution=Get-Content $solutionFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$solutionCompleted=Parse-Time $solution.completedAt}catch{Stop-Adapter 'integrity-failure' 'Malformed Solution build provenance.'}
$solutionOkay=$solution.gate -ceq 'Solution' -and $solution.producer -ceq 'ifx-c5b-controlled-v1' -and $solution.result -ceq 'passed' -and $solution.sourceTreeSha256 -ceq $lock.sourceTreeSha256 -and $solution.sourceFileCount -eq $lock.sourceFileCount -and $solutionCompleted -ge $now.AddHours(-24) -and $solutionCompleted -le $completed
$prefix=[string]$lock.evidencePrefix;if($prefix -cnotmatch '^artifacts/guards/p10-ifx-c5c/assembly-runs/[a-f0-9]{32}/$'){Stop-Adapter 'unsafe-path' 'Uncontrolled Assembly evidence prefix.'}
$reportFile=Resolve-Locked ($prefix+'quality/assembly.json') ([string]$lock.reportSha256)
$summaryFile=Resolve-Locked ($prefix+'quality/summary.json') ([string]$lock.summarySha256)
try{$report=Get-Content $reportFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$summary=Get-Content $summaryFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed Assembly report.'}
Record 'freshSolutionBuild' 'solution-provenance' $solutionOkay
Record 'controlledAssemblyReport' 'assembly-report' ($report.status -ceq 'pass' -and $summary.status -ceq 'pass' -and @($summary.checks|Where-Object{$_.id -ceq 'Assembly' -and $_.status -ceq 'pass'}).Count -eq 1 -and @($report.checks).Count -eq 5)
$trusted=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($path in ([string][AppContext]::GetData('TRUSTED_PLATFORM_ASSEMBLIES')).Split([IO.Path]::PathSeparator)){[void]$trusted.Add([IO.Path]::GetFileNameWithoutExtension($path))}
$actualNames=@($lock.assemblies|ForEach-Object id|Sort-Object);$expectedNames=@($policy.assemblies|ForEach-Object id|Sort-Object)
if(($actualNames -join '|') -cne ($expectedNames -join '|')){Stop-Adapter 'integrity-failure' 'Domain assembly set drift.'}
foreach($expected in $policy.assemblies){
    $row=@($lock.assemblies|Where-Object id -CEQ $expected.id);$reportRow=@($report.checks|Where-Object id -CEQ $expected.id)
    if($row.Count -ne 1 -or $reportRow.Count -ne 1 -or $row[0].path -cne $expected.path -or $reportRow[0].assemblyPath -cne $expected.path){Stop-Adapter 'integrity-failure' "Assembly identity drift: $($expected.id)"}
    $dll=Resolve-Locked ([string]$expected.path) ([string]$row[0].sha256)
    $projectRoot=[IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($dll))))
    $newest=Get-ChildItem -LiteralPath $projectRoot -File -Recurse -Force|Where-Object{$_.FullName -notmatch '[\\/](bin|obj)[\\/]'}|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 1
    $stale=$null -eq $newest -or $newest.LastWriteTimeUtc -gt (Get-Item -LiteralPath $dll).LastWriteTimeUtc
    try{$references=@([Reflection.Assembly]::LoadFrom($dll).GetReferencedAssemblies().Name|Sort-Object -Unique);$forbidden=@($references|Where-Object{$reference=$_;-not $trusted.Contains($reference) -and @($policy.allowedDomainReferences|Where-Object{$reference -like $_}).Count -eq 0})}catch{Stop-Adapter 'integrity-failure' "Unreadable compiled assembly: $($expected.id)"}
    $reportRefs=@($reportRow[0].referencedAssemblies|Sort-Object)
    Record ([string]$expected.id) 'compiled-assembly' (-not $stale -and $reportRow[0].status -ceq 'pass' -and $reportRow[0].stale -eq $false -and @($reportRow[0].forbiddenReferences).Count -eq 0 -and $forbidden.Count -eq 0 -and ($references -join '|') -ceq ($reportRefs -join '|'))
}
if($matched -ne 7){Stop-Adapter 'integrity-failure' 'Assembly coverage drift.'}
if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
