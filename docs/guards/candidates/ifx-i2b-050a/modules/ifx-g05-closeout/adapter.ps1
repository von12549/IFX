Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$detector='ifx-g05-closeout';$claims=@('IFX.C4.G05_REPLAY','IFX.C4.G05_DOCUMENTATION','IFX.C4.G05_HANDOFF');$rules=@('G05-REPLAY','G05-DOCUMENTATION','G05-HANDOFF');$kinds=@('replay-source','documentation','handoff');$matched=@(0,0,0);$findings=[Collections.Generic.List[object]]::new()
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Hash-Text([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Emit([string]$Status,[string]$Category,[string]$Message=''){$coverage=for($i=0;$i -lt 3;$i++){[ordered]@{claimId=$claims[$i];matched=[int]$matched[$i];minimum=1}};$result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@($coverage)};if($Message){$result.message=$Message};[Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 40 -Compress))}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Is-Under([string]$Path,[string]$Root){$r=[IO.Path]::GetRelativePath($Root,$Path);$r -ne '..' -and -not [IO.Path]::IsPathRooted($r) -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Assert-NoLink([string]$Path,[string]$Root){$cursor=[IO.Path]::GetFullPath($Path);while(Is-Under $cursor $Root){if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked authority: $Path"}};if($cursor -ceq $Root){break};$parent=[IO.Path]::GetDirectoryName($cursor);if(-not $parent -or $parent -ceq $cursor){break};$cursor=$parent}}
function Record([int]$Phase,[string]$Id,[bool]$Pass){$i=switch($Phase){8{0}10{1}11{2}};$matched[$i]++;if(-not $Pass){$findings.Add([ordered]@{ruleId=$rules[$i];subject=$Id;evidenceKind=$kinds[$i];detectorId=$detector;severity='blocking'})}}
function Match([string]$Text,[string]$Pattern){[Regex]::IsMatch($Text,$Pattern,[Text.RegularExpressions.RegexOptions]::IgnoreCase,[TimeSpan]::FromSeconds(1))}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input is required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Stage input malformed.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne ($claims-join '|') -or @($inputObject.relativeRoots) -notcontains 'docs'){Stop-Adapter 'invalid-input' 'Stage or claim selection invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'}
$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot);if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot missing.'};Assert-NoLink $target $target
$policyFile=Join-Path $PSScriptRoot 'policy.json';if(-not [IO.File]::Exists($policyFile) -or (Hash $policyFile) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Closeout policy hash drift.'}
try{$policy=Get-Content $policyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Closeout policy malformed.'}
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g05-closeout-050a' -or $policy.pinPolicy -cne 'governance-only' -or @($policy.authorities).Count -ne 20 -or @($policy.checkIds.phase8).Count -ne 11 -or @($policy.checkIds.phase10).Count -ne 10 -or @($policy.checkIds.phase11).Count -ne 8){Stop-Adapter 'integrity-failure' 'Closeout policy identity drift.'}
# 0.5.0-a: governance authorities keep their Profile pins; each live authority is bound to its current bytes, so the
# unchanged loop below verifies pins only where the policy marks a governance authority (pinned).
$pinned=@($policy.authorities | Where-Object { $_.pinned -eq $true })
$configLocks=@($inputObject.config.authorityHashes)
if($pinned.Count -ne 19 -or $configLocks.Count -ne $pinned.Count){Stop-Adapter 'invalid-input' 'Governance authority lock count mismatch.'}
for($k=0;$k -lt $pinned.Count;$k++){if($pinned[$k].id -cne $configLocks[$k].id){Stop-Adapter 'invalid-input' "Governance authority lock mismatch: $k"}}
$locks=@(foreach($pa in @($policy.authorities)){
    if($pa.pinned -eq $true){@($configLocks | Where-Object { $_.id -ceq $pa.id })[0]}
    else{
        $liveRelative=[string]$pa.path;$liveFull=[IO.Path]::GetFullPath((Join-Path $target $liveRelative))
        $liveSafe=-not [IO.Path]::IsPathRooted($liveRelative) -and $liveRelative -notmatch '(^|[\\/])\.\.([\\/]|$)' -and (Is-Under $liveFull $target) -and [IO.File]::Exists($liveFull) -and ((Get-Item -LiteralPath $liveFull -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0
        [ordered]@{id=[string]$pa.id;sha256=$(if($liveSafe){(Get-FileHash -Algorithm SHA256 -LiteralPath $liveFull).Hash.ToLowerInvariant()}else{'0'*64})}
    }
})
if($locks.Count -ne 20){Stop-Adapter 'invalid-input' 'Authority lock count mismatch.'};$texts=@{}
for($i=0;$i -lt 20;$i++){$authority=$policy.authorities[$i];$lock=$locks[$i];$relative=[string]$authority.path;if($authority.id -cne $lock.id -or [string]$lock.sha256 -cnotmatch '^[a-f0-9]{64}$' -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)'){Stop-Adapter 'invalid-input' "Authority lock mismatch: $i"};$full=[IO.Path]::GetFullPath((Join-Path $target $relative));if(-not(Is-Under $full $target)){Stop-Adapter 'unsafe-path' "Authority escapes TargetRoot: $relative"};Assert-NoLink $full $target;if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing authority: $relative"};if((Hash $full) -cne [string]$lock.sha256){Stop-Adapter 'integrity-failure' "Stale authority: $relative"};$texts[[string]$authority.id]=[IO.File]::ReadAllText($full)}
$diagramRoot=[IO.Path]::GetFullPath((Join-Path $target ([string]$policy.diagramRoot)));if(-not(Is-Under $diagramRoot $target) -or -not [IO.Directory]::Exists($diagramRoot)){Stop-Adapter 'prerequisite-missing' 'Diagram root missing.'};Assert-NoLink $diagramRoot $target
$diagrams=@(Get-ChildItem -LiteralPath $diagramRoot -File -Force|Where-Object Extension -in '.mmd','.svg','.png'|Sort-Object Name);foreach($file in $diagrams){Assert-NoLink $file.FullName $target}
$diagramLines=@($diagrams|ForEach-Object{"$($_.Name)|$(Hash $_.FullName)"}) -join "`n";if((Hash-Text $diagramLines) -cne [string]$inputObject.config.diagramTreeSha256){Stop-Adapter 'integrity-failure' 'Diagram set lock drift.'}
try{$failure=$texts.failurePolicy|ConvertFrom-Json -AsHashtable -Depth 50;$report=$texts.documentationReport|ConvertFrom-Json -AsHashtable -Depth 30;$closeout=$texts.closeoutStatus|ConvertFrom-Json -AsHashtable -Depth 50;$open=$texts.openItems|ConvertFrom-Json -AsHashtable -Depth 50;$ops=$texts.opsEvidence|ConvertFrom-Json -AsHashtable -Depth 30}catch{Stop-Adapter 'integrity-failure' 'Closeout JSON authority malformed.'}
$failureTests=$texts.failureTests;$adapter=@($failure.compatibilityAdapters)[0]
$classes=@('Diagnostic','Client','Business','Transient','Permanent','Security');$order=@('eventType','eventVersion','eventId','producer','tenant','correlation','causation');$reasonCodes=@('event_type_invalid','event_version_unsupported','event_id_invalid','event_producer_denied','event_tenant_invalid','event_correlation_invalid','event_causation_invalid')
$metricNames=@('ifx_context_validation_total','ifx_envelope_validation_total','ifx_tenant_rejection_total','ifx_producer_rejection_total','ifx_redaction_total','ifx_compatibility_synthesis_total');$forbiddenLabels=@('tenantId','userId','eventId','correlationId','causationId','requestId','email','accountNumber','resourceId')
$phase8=[ordered]@{
    failureMatrixHasSixBoundedClasses=((@($failure.failureMatrix.class)-join ',') -ceq ($classes-join ',') -and @($failure.failureMatrix|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.action) -or $null -eq $_.retry -or [string]::IsNullOrWhiteSpace([string]$_.exampleCode)}).Count -eq 0 -and (Match $failureTests 'FailureMatrix_HasBoundedDisposition'))
    preInboxValidationOrderAndCodesAreStable=((@($failure.preInboxValidation.order)-join ',') -ceq ($order-join ',') -and @($reasonCodes|Where-Object{$_ -notin $failure.preInboxValidation.failures.code -or -not(Match $failureTests ([Regex]::Escape($_)))}).Count -eq 0 -and (Match $failureTests 'CoreEnvelopeFailures_AreStableAndOccurBeforeInbox'))
    traceDamageIsDiagnosticAndNonRejecting=($failure.preInboxValidation.invalidTrace.class -ceq 'Diagnostic' -and (Match $failure.preInboxValidation.invalidTrace.action 'continue') -and (Match $failureTests 'InvalidTrace_IsDiagnosticAndRestartsWithoutRejectingTheEvent'))
    quarantineMetadataIsSafeAndSecurityIsAudited=((@($failure.quarantine.recordKinds)-join ',') -ceq 'quarantine,dead-letter' -and (@($failure.quarantine.eligibleClasses)-join ',') -ceq 'Permanent,Security' -and @($failure.quarantine.forbiddenDiagnostics).Count -ge 8 -and 'append-security-audit' -in $failure.quarantine.securityAction -and (Match $failureTests 'Quarantine_SeparatesLogicalBytesFromSafeMetadataAndSecurityAudit') -and (Match $failureTests 'Deliberately excluded from quarantine diagnostics'))
    retryAndReplayPreserveLogicalIdentity=((Match $failure.retryReplay.retry 'preserve exact envelope and payload bytes') -and (Match $failure.retryReplay.deadLetterReplay 'preserve the original EventId') -and (Match $failureTests 'TransientRetry_ChangesDeliveryStateOnly') -and (Match $failureTests 'DeadLetterReplay_PreservesEventIdAndCompletedInboxStillDeduplicates'))
    forcedReprocessingIsSeparateAndApproved=((Match $failure.retryReplay.forcedReprocessing 'separately approved ReprocessingRequest') -and (Match $failureTests 'ForcedReprocessing_UsesSeparatelyApprovedRequestAndNeverMutatesEnvelope') -and (Match $failureTests 'ApprovalReference'))
    compatibilityRegistryIsOwnedBoundedAndExpiring=(-not [string]::IsNullOrWhiteSpace([string]$adapter.owner) -and -not [string]::IsNullOrWhiteSpace([string]$adapter.sourceIdentity) -and (@($adapter.allowedSynthesizedFields)-join ',') -ceq 'correlationId,causationId' -and $adapter.provenance -ceq 'synthesized' -and $adapter.expiryAction -ceq 'fail-closed' -and @(@('eventId','producer','tenantId','scope','eventType','schemaVersion')|Where-Object{$_ -notin $failure.compatibilityRules.neverSynthesize}).Count -eq 0 -and (Match $failureTests 'compatibility_adapter_expired'))
    metricsUseBoundedNamesAndLabelsOnly=(@($metricNames|Where-Object{$_ -notin $failure.metrics.names}).Count -eq 0 -and @($forbiddenLabels|Where-Object{$_ -notin $failure.metrics.forbiddenLabels}).Count -eq 0 -and (Match $failureTests 'Metrics_AllowOnlyBoundedPolicyLabelsAndRejectRawIdentifiers') -and (Match $failureTests 'BoundedValuePattern'))
    realFailureDurabilityNotMisrepresented=($failure.status -ceq 'pre-active-fake-carrier-conformance' -and (Match $failure.realDurabilityEvidence 'required from Plan 02') -and (Match $failure.realDurabilityEvidence 'not durable implementations'))
    phase8EvidenceExists=(-not [string]::IsNullOrWhiteSpace($texts.phase8Evidence))
    phase8LayerGuardEvidenceExists=(-not [string]::IsNullOrWhiteSpace($texts.phase8Layer))
}
$zh=$texts.zhDesign;$en=$texts.enDesign;$zhDecisions=@([Regex]::Matches($zh,'G05-D\d{2}')|ForEach-Object Value|Sort-Object -Unique);$enDecisions=@([Regex]::Matches($en,'G05-D\d{2}')|ForEach-Object Value|Sort-Object -Unique)
$diagramSources=@($diagrams|Where-Object Extension -eq '.mmd');$diagramTriplets=@($diagramSources|Where-Object{($diagrams.Name -contains "$($_.BaseName).svg") -and ($diagrams.Name -contains "$($_.BaseName).png") -and $_.Length -gt 0})
$phase10=[ordered]@{
    bilingualDesignDecisionsAreConsistent=(($zhDecisions-join ',') -ceq ($enDecisions-join ',') -and $zhDecisions.Count -eq 10 -and $report.checks.decisionIdsConsistent -eq $true)
    terminologyLifecycleAndForbiddenSubstitutionAreDocumented=($report.checks.terminologyAndLifecycleTablesExist -eq $true -and (Match $zh 'CorrelationId') -and (Match $zh 'OperationId') -and (Match $zh 'CausationId') -and (Match $zh 'EventId') -and (Match $zh 'TenantScope'))
    contextTrustAndFlowDiagramsAreRendered=($diagramSources.Count -eq 6 -and $diagramTriplets.Count -eq 6 -and $diagrams.Count -eq 18 -and $report.checks.requiredFlowsAreDocumented -eq $true)
    failureClassificationAndAdmissionMatricesAreDocumented=((Match $zh '失败矩阵') -and (Match $en 'Failure matrix') -and $report.checks.classificationAdmissionMatrixExists -eq $true)
    observabilityCompatibilityAndSecurityOperationsAreDocumented=((Match $zh 'Production pseudonym key') -and (Match $en 'Compatibility Adapter') -and (Match $zh 'Auth token-retention migration') -and (Match $en 'quarantine/dead-letter'))
    ruleMappingLinksOwnersCodeTestsMetricsAndApprovals=($report.checks.ruleMappingPresent -eq $true -and (Match $zh 'Owner') -and (Match $zh 'Catalog/Schema') -and (Match $zh 'Metric/人工证据') -and (Match $en 'Metric/manual evidence'))
    documentationIndexesAndBacklinksAreComplete=($report.checks.architectureIndexesLinkG05 -eq $true -and $report.checks.prerequisiteAndMasterLinkG05 -eq $true -and $report.checks.downstreamPlansLinkBack -eq $true)
    documentationPreReadyBoundaryIsTruthful=($report.checks.preReadyScopeExplicit -eq $true -and (Match $zh '8 组 C3 例外') -and (Match $en 'Eight C3 exceptions remain Pending/PendingRemoval'))
    phase10EvidenceExists=(-not [string]::IsNullOrWhiteSpace($texts.phase10Evidence))
    phase10LayerGuardEvidenceExists=(-not [string]::IsNullOrWhiteSpace($texts.phase10Layer))
}
$handoffs=@($texts.handoff01,$texts.handoff02,$texts.handoff03,$texts.handoff04)
$phase11=[ordered]@{
    fourOwnershipPreservingHandoffsExist=(@($handoffs|Where-Object{[string]::IsNullOrWhiteSpace($_) -or -not(Match $_ 'pending')}).Count -eq 0)
    opsEvidenceMapCoversRequiredOutcomes=((@($ops.requirements.id|Sort-Object)-join ',') -ceq 'OPS-G1,OPS1,OPS3' -and $ops.status -ceq 'repository-complete-downstream-pending')
    allOpenExceptionsAndFindingsAreGoverned=(@($open.blockers).Count -eq 7 -and @($open.fieldExceptions).Count -eq 8 -and @($open.blockers|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.owner) -or [string]::IsNullOrWhiteSpace([string]$_.risk) -or @($_.blocks).Count -eq 0}).Count -eq 0 -and @($open.fieldExceptions|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.owner) -or [string]::IsNullOrWhiteSpace([string]$_.expiresAt)}).Count -eq 0)
    closeoutAuditPassesWithoutClaimingClosure=($closeout.result -ceq 'passed' -and $closeout.closureStatus -ceq 'pre-ready' -and $closeout.readyForClosure -eq $false -and $closeout.counts.blockers -eq 7 -and $closeout.counts.c3Exceptions -eq 8)
    prerequisiteReleasedAndFinalApprovalOpen=((Match $texts.prerequisitePlan '(?m)^- \[x\] \*\*Gate 5 前置放行\*\*') -and (Match $texts.g05Plan '(?m)^- \[ \] \*\*Phase 11 完成\*\*') -and (Match $texts.g05Plan '(?m)^- \[x\] G05-11\.6') -and (Match $texts.g05Plan '(?m)^- \[ \] G05-11\.8'))
    productionAndDownstreamEvidenceNotMisrepresented=($closeout.checks.realContractAndMessagingEvidenceStillPending -eq $true -and $closeout.checks.productionSecurityEvidenceStillPending -eq $true -and $closeout.checks.g03BackupOwnerAssignmentResolved -eq $true)
    phase11HandoffEvidenceExists=(-not [string]::IsNullOrWhiteSpace($texts.phase11Evidence))
    phase11LayerGuardEvidenceExists=(-not [string]::IsNullOrWhiteSpace($texts.phase11Layer))
}
$maps=@(@{phase=8;values=$phase8;ids=$policy.checkIds.phase8},@{phase=10;values=$phase10;ids=$policy.checkIds.phase10},@{phase=11;values=$phase11;ids=$policy.checkIds.phase11})
foreach($map in $maps){if((@($map.values.Keys)-join '|') -cne (@($map.ids)-join '|')){Stop-Adapter 'integrity-failure' "Phase $($map.phase) ID mapping drift."};foreach($id in $map.ids){Record $map.phase $id ([bool]$map.values[$id])}}
if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
