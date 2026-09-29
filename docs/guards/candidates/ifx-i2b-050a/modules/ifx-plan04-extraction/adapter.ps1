Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
function Get-PinSha256([string]$Path){
    # 0.5.0-a (R5): a governance pin is the SHA-256 of the UTF-8 text with line endings normalized to LF; binary files by raw bytes.
    if([IO.Path]::GetExtension($Path).ToLowerInvariant() -in @('.png','.jpg','.jpeg','.gif','.ico','.pdf','.zip','.dll','.exe')){return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()}
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")))).ToLowerInvariant()
}
$rule='PLAN04-EXTRACTION';$claim='IFX.C4A.PLAN04_EXTRACTION';$detector='ifx-plan04-extraction';$findings=[Collections.Generic.List[object]]::new();$matched=0
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Hash-Text([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Emit([string]$Status,[string]$Category,[string]$Message=''){$result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@([ordered]@{claimId=$claim;matched=[int]$matched;minimum=1})};if($Message){$result.message=$Message};[Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 40 -Compress))}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Is-Under([string]$Path,[string]$Root){$r=[IO.Path]::GetRelativePath($Root,$Path);$r -ne '..' -and -not [IO.Path]::IsPathRooted($r) -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Assert-NoLink([string]$Path,[string]$Root){$cursor=[IO.Path]::GetFullPath($Path);while(Is-Under $cursor $Root){if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked authority: $Path"}};if($cursor -ceq $Root){break};$parent=[IO.Path]::GetDirectoryName($cursor);if(-not $parent -or $parent -ceq $cursor){break};$cursor=$parent}}
function Resolve-Authority([string]$Relative,[string]$Expected){if([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or ($Expected -and $Expected -cnotmatch '^[a-f0-9]{64}$')){Stop-Adapter 'invalid-input' 'Authority path or hash invalid.'};$full=[IO.Path]::GetFullPath((Join-Path $target $Relative));if(-not(Is-Under $full $target)){Stop-Adapter 'unsafe-path' "Authority escapes TargetRoot: $Relative"};Assert-NoLink $full $target;if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing authority: $Relative"};if($Expected -and (Get-PinSha256 $full) -cne $Expected){Stop-Adapter 'integrity-failure' "Stale governance authority: $Relative"};return $full}
function Present($Value){-not [string]::IsNullOrWhiteSpace([string]$Value)}
function Equal-Set([object[]]$Left,[object[]]$Right){(@($Left|Sort-Object)-join "`n") -ceq (@($Right|Sort-Object)-join "`n")}
function Record([string]$Id,[bool]$Pass){$script:matched++;if(-not $Pass){$findings.Add([ordered]@{ruleId=$rule;subject=$Id;evidenceKind='extraction-policy';detectorId=$detector;severity='blocking'})}}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Stage input malformed.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'docs'){Stop-Adapter 'invalid-input' 'Stage or claim selection invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'};$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot);if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot missing.'};Assert-NoLink $target $target
$policyFile=Join-Path $PSScriptRoot 'policy.json';if(-not [IO.File]::Exists($policyFile) -or (Hash $policyFile) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Extraction module policy drift.'}
try{$settings=Get-Content $policyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Extraction module policy malformed.'}
if($settings.formatVersion -ne 1 -or $settings.id -cne 'ifx-plan04-extraction-050a' -or $settings.pinPolicy -cne 'governance-only' -or @($settings.checkIds).Count -ne 9){Stop-Adapter 'integrity-failure' 'Extraction module identity drift.'}
$extractionFile=Resolve-Authority ([string]$settings.policyPath) ([string]$inputObject.config.extractionPolicySha256);$schemaFile=Resolve-Authority ([string]$settings.schemaPath) ([string]$inputObject.config.schemaSha256)
try{$extraction=Get-Content $extractionFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$schema=Get-Content $schemaFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Extraction policy or schema malformed.'}
$fixtureRoot=[IO.Path]::GetFullPath((Join-Path $target ([string]$settings.fixtureRoot)));if(-not(Is-Under $fixtureRoot $target) -or -not [IO.Directory]::Exists($fixtureRoot)){Stop-Adapter 'prerequisite-missing' 'Fixture root missing.'};Assert-NoLink $fixtureRoot $target
$fixtures=@(Get-ChildItem -LiteralPath $fixtureRoot -File -Filter 'extraction-*.json' -Force|Sort-Object Name);foreach($file in $fixtures){Assert-NoLink $file.FullName $target}
$fixtureLines=@($fixtures|ForEach-Object{"$($_.Name)|$(Hash $_.FullName)"}) -join "`n";<# 0.5.0-a: live tree; no Profile fingerprint #>
$hardGateIds=@($extraction.hardGates.id);$scoreIds=@($extraction.evidenceDimensions.id)
function Validate-Record($record){
    $errors=[Collections.Generic.HashSet[string]]::new()
    if(-not(Present $record.businessOwner) -or -not(Present $record.dataOwner) -or -not(Present $record.operationsOwner)){[void]$errors.Add('owner-missing')}
    if(-not(Equal-Set $hardGateIds @($record.hardGates|ForEach-Object{$_['id']}))){[void]$errors.Add('hard-gates-incomplete')}
    $failedGates=@($record.hardGates|Where-Object passed -ne $true);if($failedGates.Count -gt 0){[void]$errors.Add('hard-gate-failed');if($record.targetState -in @('candidate','approved','executing','extracted')){[void]$errors.Add('score-cannot-override-hard-gate')}}
    if(-not(Equal-Set $scoreIds @($record.evidenceScores|ForEach-Object{$_['id']})) -or @($record.evidenceScores|Where-Object{$_.value -lt 0 -or $_.value -gt 5 -or -not(Present $_.evidence)}).Count -gt 0){[void]$errors.Add('scores-incomplete')}
    if(@($extraction.applicationRequirements|Where-Object{-not(Present $record[$_])}).Count -gt 0){[void]$errors.Add('application-evidence-incomplete')}
    $transition=@($extraction.transitions|Where-Object{$_.from -eq $record.currentState -and $_.to -eq $record.targetState})
    if($transition.Count -ne 1){[void]$errors.Add('invalid-state-transition')}else{$approved=@($record.approvals|Where-Object{$_.status -eq 'approved' -and (Present $_.approver) -and (Present $_.evidence)}|ForEach-Object role);if(-not(Equal-Set @($transition[0].approvals) $approved)){[void]$errors.Add('transition-approvals-incomplete')}}
    return @($errors|Sort-Object)
}
$fixtureResults=@(foreach($file in $fixtures){try{$record=Get-Content $file.FullName -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$actual=@(Validate-Record $record);$expected=@($record['expectedErrors']|Sort-Object);[ordered]@{name=$file.Name;passed=Equal-Set $expected $actual;positive=$actual.Count -eq 0;expected=$expected;actual=$actual}}catch{[ordered]@{name=$file.Name;passed=$false;positive=$false;error=$_.Exception.Message}}})
$requiredHard=@('HG1','HG2','HG3','HG4','HG5','HG6','HG7');$requiredDimensions=@('team-autonomy','scaling-difference','release-frequency','failure-isolation-benefit','data-migration-complexity','latency-availability-fit','compliance-requirement');$requiredStates=@('retain','observe','candidate','approved','executing','extracted')
$checks=[ordered]@{
    schemaDeclaresRequiredRecord=($schema.properties.formatVersion.const -eq 1 -and @(@('businessOwner','dataOwner','operationsOwner','hardGates','evidenceScores','rollbackPath','modularMonolithAlternative')|Where-Object{$_ -notin @($schema.required)}).Count -eq 0)
    exactHardGates=((Equal-Set $requiredHard $hardGateIds) -and @($extraction.hardGates|Where-Object required -ne $true).Count -eq 0)
    exactEvidenceDimensions=(Equal-Set $requiredDimensions $scoreIds)
    scoreCannotOverrideHardGate=($extraction.scorePolicy.mayOverrideHardGate -eq $false -and $null -eq $extraction.scorePolicy.approvalThreshold)
    exactStateMachine=((Equal-Set $requiredStates @($extraction.states)) -and @($extraction.transitions|Where-Object{$_.from -notin $requiredStates -or $_.to -notin $requiredStates -or @($_.approvals).Count -eq 0}).Count -eq 0)
    approvedStateRequiredBeforeExecution=($extraction.executionPrerequisites.requiredState -ceq 'approved' -and (Equal-Set @('DP8-runtime-resilience','DP9-package-cadence') @($extraction.executionPrerequisites.handoffs)) -and @($extraction.executionPrerequisites.mustExistBeforeExecuting).Count -ge 6)
    completeApplicationEvidenceRequired=(@($extraction.applicationRequirements).Count -eq 7 -and 'rollbackPath' -in @($extraction.applicationRequirements) -and 'modularMonolithAlternative' -in @($extraction.applicationRequirements))
    positiveAndNegativeFixturesPass=($fixtureResults.Count -ge 5 -and @($fixtureResults|Where-Object passed -ne $true).Count -eq 0 -and @($fixtureResults|Where-Object positive -eq $true).Count -eq 1)
    defaultRemainsModularMonolith=($extraction.defaultDeployment -ceq 'modular-monolith' -and $extraction.rollbackRule -match 'modular monolith')
}
if((@($checks.Keys)-join '|') -cne (@($settings.checkIds)-join '|')){Stop-Adapter 'integrity-failure' 'Extraction check-ID mapping drift.'}
foreach($id in $settings.checkIds){Record $id ([bool]$checks[$id])}
if($findings.Count -gt 0){Emit 'fail' 'findings-blocking' (($fixtureResults|ConvertTo-Json -Depth 10 -Compress))}else{Emit 'pass' 'success'}
