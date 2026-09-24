Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$detector='ifx-g05-governance'
$claims=@('IFX.C4.G05_FIELD_GOVERNANCE','IFX.C4.G05_OBSERVABILITY')
$rules=@('G05-FIELD-GOVERNANCE','G05-OBSERVABILITY')
$matched=@(0,0)
$findings=[Collections.Generic.List[object]]::new()
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Hash-Text([string]$Value){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))).ToLowerInvariant()}
function Emit([string]$Status,[string]$Category,[string]$Message=''){
    $coverage=for($i=0;$i -lt 2;$i++){[ordered]@{claimId=$claims[$i];matched=[int]$matched[$i];minimum=1}}
    $result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@($coverage)}
    if($Message){$result.message=$Message}
    [Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Is-Under([string]$Path,[string]$Root){$r=[IO.Path]::GetRelativePath($Root,$Path);$r -ne '..' -and -not [IO.Path]::IsPathRooted($r) -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Assert-NoLink([string]$Path,[string]$Root){
    $cursor=[IO.Path]::GetFullPath($Path)
    while(Is-Under $cursor $Root){
        if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked governance authority: $Path"}}
        if($cursor -ceq $Root){break};$parent=[IO.Path]::GetDirectoryName($cursor);if(-not $parent -or $parent -ceq $cursor){break};$cursor=$parent
    }
}
function Record([int]$Phase,[string]$Id,[bool]$Pass){
    $i=if($Phase -eq 6){0}else{1}
    $matched[$i]++
    if(-not $Pass){$findings.Add([ordered]@{ruleId=$rules[$i];subject=$Id;evidenceKind=$(if($i -eq 0){'field-catalog'}else{'observability-source'});detectorId=$detector;severity='blocking'})}
}
function Match([string]$Text,[string]$Pattern){[Regex]::IsMatch($Text,$Pattern,[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1))}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input is required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Stage input is malformed.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne ($claims-join '|') -or @($inputObject.relativeRoots) -notcontains 'src'){Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'}
$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.'};Assert-NoLink $target $target
$policyFile=Join-Path $PSScriptRoot 'policy.json'
if(-not [IO.File]::Exists($policyFile) -or (Hash $policyFile) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Governance policy hash drift.'}
try{$policy=Get-Content -LiteralPath $policyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Governance policy is malformed.'}
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g05-governance-c4p6p7' -or @($policy.authorities).Count -ne 24 -or @($policy.checkIds.phase6).Count -ne 10 -or @($policy.checkIds.phase7).Count -ne 11){Stop-Adapter 'integrity-failure' 'Governance policy identity drift.'}
$locks=@($inputObject.config.authorityHashes);if($locks.Count -ne 24){Stop-Adapter 'invalid-input' 'Authority lock count drift.'}
$texts=@{}
for($i=0;$i -lt 24;$i++){
    $a=$policy.authorities[$i];$lock=$locks[$i];$relative=[string]$a.path
    if($a.id -cne $lock.id -or [string]$lock.sha256 -cnotmatch '^[a-f0-9]{64}$' -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)'){Stop-Adapter 'invalid-input' "Authority lock mismatch: $i"}
    $full=[IO.Path]::GetFullPath((Join-Path $target $relative));if(-not(Is-Under $full $target)){Stop-Adapter 'unsafe-path' "Authority escapes TargetRoot: $relative"};Assert-NoLink $full $target
    if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing authority: $relative"}
    if((Hash $full) -cne [string]$lock.sha256){Stop-Adapter 'integrity-failure' "Stale authority: $relative"}
    $texts[[string]$a.id]=[IO.File]::ReadAllText($full)
}
$handlerRoot=[IO.Path]::GetFullPath((Join-Path $target ([string]$policy.transactionHandlersRoot)))
if(-not(Is-Under $handlerRoot $target) -or -not [IO.Directory]::Exists($handlerRoot)){Stop-Adapter 'prerequisite-missing' 'Transaction handler root is missing.'};Assert-NoLink $handlerRoot $target
$handlers=@(Get-ChildItem -LiteralPath $handlerRoot -File -Filter '*Handler.cs' -Recurse -Force|Sort-Object FullName)
if($handlers.Count -lt 5){Stop-Adapter 'prerequisite-missing' 'Transaction handler source set is incomplete.'}
foreach($file in $handlers){Assert-NoLink $file.FullName $target}
$handlerLines=@($handlers|ForEach-Object{"$([IO.Path]::GetRelativePath($target,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"
if((Hash-Text $handlerLines) -cne [string]$inputObject.config.transactionHandlersSha256){Stop-Adapter 'integrity-failure' 'Transaction handler source lock drift.'}
$texts['transactionHandlers']=@($handlers|ForEach-Object{[IO.File]::ReadAllText($_.FullName)}) -join "`n"
try{$catalog=$texts.catalog|ConvertFrom-Json -AsHashtable -Depth 100;$catalogReport=$texts.catalogReport|ConvertFrom-Json -AsHashtable -Depth 100;$layer=$texts.layerGuard|ConvertFrom-Json -AsHashtable -Depth 100;$obs=$texts.observabilityPolicy|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Governance JSON authority is malformed.'}
$fields=[Collections.Generic.List[object]]::new()
foreach($surface in @($catalog.fieldSurfaces)){
    $set=if($surface.Contains('fieldsFromProtocol') -and $surface.fieldsFromProtocol){@(($catalog.protocols|Where-Object identity -eq $surface.id|Select-Object -First 1).fields)}else{@($surface.fields)}
    foreach($field in $set){$fields.Add([ordered]@{surface=$surface.id;name=$field.name;classification=$field.classification;exceptionRef=$(if($field.Contains('exceptionRef')){$field.exceptionRef}else{$null})})}
}
$authIds=@('auth.resource-authorization.v1','authorization.policy-evaluation.v1')
$deny=@($catalog.fieldGovernance.c4Denylist) -join '|'
$phase6=[ordered]@{
    g03CatalogRemainsSoleFieldAuthority=((Match ([string]$catalog.fieldGovernance.authority) 'sole admission source') -and $catalogReport.result -ceq 'passed' -and $catalogReport.checks.sensitiveFieldGovernance -eq $true)
    allTargetLegacyAndEnvelopeFieldsAreClassified=(@($catalog.fieldSurfaces).Count -eq 34 -and @($fields|Where-Object surface -notin $authIds).Count -eq 165 -and @($fields|Where-Object surface -eq $authIds[0]).Count -eq 11 -and @($fields|Where-Object surface -eq $authIds[1]).Count -eq 24 -and @($catalog.fieldSurfaces|Where-Object kind -like 'legacy-*').Count -eq 27 -and @($catalog.publicSurface|Where-Object kind -in @('dto','integration-event')).Count -eq 27)
    noC4AndAllC3HaveGovernedExceptions=(@($fields|Where-Object classification -eq 'C4').Count -eq 0 -and @($fields|Where-Object{$_.classification -eq 'C3' -and [string]::IsNullOrWhiteSpace([string]$_.exceptionRef)}).Count -eq 0 -and @($catalog.fieldExceptions).Count -eq 8)
    c4SemanticDenylistIsComplete=(@('password','token','authorization','cookie','otp','api secret','client secret','private key','connection string'|Where-Object{$deny -notmatch [Regex]::Escape($_)}).Count -eq 0)
    capabilitySplitAndEventMinimizationAreRecorded=(@($catalog.migrationRecommendations).Count -ge 2 -and @($catalog.eventMinimizationReviews).Count -ge 5 -and 'crm.dto.investor-summary' -in @($catalog.migrationRecommendations.surfaceId))
    sensitiveFinancialAndComplianceUsesAreGoverned=(@($catalog.sensitiveUsePolicies).Count -eq 2 -and @($catalog.sensitiveUsePolicies|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.encryption) -or [string]::IsNullOrWhiteSpace([string]$_.access) -or [string]::IsNullOrWhiteSpace([string]$_.retention) -or [string]::IsNullOrWhiteSpace([string]$_.deletion) -or [string]::IsNullOrWhiteSpace([string]$_.replay)}).Count -eq 0)
    pendingSecurityApprovalIsNotMisrepresented=(@($catalog.fieldExceptions|Where-Object{$_.id -eq 'G05-C3-001' -and $_.approvalStatus -eq 'Approved' -and -not [string]::IsNullOrWhiteSpace([string]$_.approvalEvidence)}).Count -eq 1 -and @($catalog.fieldExceptions|Where-Object{$_.id -ne 'G05-C3-001' -and $_.approvalStatus -notin @('Pending','PendingRemoval')}).Count -eq 0)
    layerGuardGovernanceHashMatchesCatalog=($layer.catalogSha256 -ceq (Hash (Join-Path $target $policy.authorities[0].path)))
    phase6EvidenceExists=(-not [string]::IsNullOrWhiteSpace([string]$texts.phase6Evidence))
    phase6LayerGuardEvidenceExists=(-not [string]::IsNullOrWhiteSpace([string]$texts.phase6Layer))
}
$notifications=@($texts.noOpEmail,$texts.sendGrid,$texts.oidc) -join "`n"
$removed=@('AccessToken','RefreshToken','CognitoSessionId','TokenExpiresAt')
$removedAbsent=@($removed|Where-Object{$texts.loginEvent -match [Regex]::Escape($_) -or $texts.loginConfig -match [Regex]::Escape($_) -or $texts.authSnapshot -match [Regex]::Escape($_)}).Count -eq 0
$migrationComplete=@($removed|Where-Object{-not $texts.tokenMigration.Contains("name: `"$($_)`"")}).Count -eq 0
$auditFields=@('writers','readers','immutability','retention','deletion','query')
$phase7=[ordered]@{
    centralOperationalSinkEnforcesClassifier=((Match $texts.program 'SensitiveLogEventSink') -and (Match $texts.sink 'TelemetryValueHandling\.Drop') -and (Match $texts.sink 'exception: null') -and (Match $texts.redactor 'HMACSHA256') -and (Match $texts.redactor 'TelemetrySignal\.MetricLabel or TelemetrySignal\.Baggage'))
    productionPseudonymKeyFailsClosedAndSupportsRotation=((Match $texts.factory 'PseudonymKeyId') -and (Match $texts.factory 'PseudonymKeyBase64') -and (Match $texts.factory 'environment\.IsProduction\(\)') -and (Match $texts.factory 'Production observability pseudonym key configuration is required') -and (Match $texts.observabilityTests 'Pseudonym_key_rotation_changes_output_without_exposing_source_value'))
    rawRequestPathAndSdkPayloadsAreNotLogged=(-not (Match $texts.requestLogging 'Request\.Path') -and -not (Match $notifications '\{To\}|\{Subject\}|\{Response\}|LogError\(ex|ex\.Message'))
    externalErrorsAreStableAndSafe=($obs.externalErrors.exceptionMessages -eq $false -and $obs.externalErrors.providerBodies -eq $false -and -not (Match $texts.exception 'response\.Error = exception\.Message') -and -not (Match $texts.transactionHandlers 'Failure\(ex\.Message\)') -and (Match $texts.exception 'CorrelationId'))
    auditSinkGovernanceIsIndependentAndComplete=($obs.securityAuditSink.separateFromOperationalLogs -eq $true -and @($auditFields|Where-Object{[string]::IsNullOrWhiteSpace([string]$obs.securityAuditSink[$_])}).Count -eq 0)
    traceMetricAndBaggagePolicyIsBounded=($obs.traceAndMetrics.requestResponseBodyCapture -eq $false -and $obs.traceAndMetrics.sqlParameterCapture -eq $false -and $obs.traceAndMetrics.efSensitiveDataLogging -eq $false -and @($obs.traceAndMetrics.forbiddenLabels).Count -ge 7 -and (Match $texts.observabilityTests 'TelemetrySignal\.Baggage') -and (Match $texts.observabilityTests 'TelemetrySignal\.MetricLabel'))
    authTokenPersistenceIsRemovedInCodeAndMigration=($removedAbsent -and ([Regex]::Matches($texts.tokenMigration,'migrationBuilder\.DropColumn')).Count -eq 4 -and $migrationComplete)
    destructiveMigrationApprovalIsNotMisrepresented=($obs.authTokenPersistence.sourceStatus -ceq 'resolved' -and (Match ([string]$obs.authTokenPersistence.deploymentStatus) '^pending ') -and (Match ([string]$obs.authTokenPersistence.rollback) 'Down must never') -and $obs.productionEvidence.status -ceq 'pending')
    capturedSentinelCoverageExists=((Match $texts.observabilityTests 'Captured_sink_removes_sensitive_values_payloads_and_exception_details') -and (Match $texts.observabilityTests 'g05-sentinel@example\.invalid') -and (Match $texts.httpBoundaryTests 'Diagnostic_endpoint_does_not_echo_sensitive_query_sentinels') -and (Match $texts.endToEndTests 'secret database detail'))
    phase7EvidenceExists=(-not [string]::IsNullOrWhiteSpace([string]$texts.phase7Evidence))
    phase7LayerGuardEvidenceExists=(-not [string]::IsNullOrWhiteSpace([string]$texts.phase7Layer))
}
if((@($phase6.Keys)-join '|') -cne (@($policy.checkIds.phase6)-join '|') -or (@($phase7.Keys)-join '|') -cne (@($policy.checkIds.phase7)-join '|')){Stop-Adapter 'integrity-failure' 'Predicate ID inventory drift.'}
foreach($item in $phase6.GetEnumerator()){Record 6 ([string]$item.Key) ([bool]$item.Value)}
foreach($item in $phase7.GetEnumerator()){Record 7 ([string]$item.Key) ([bool]$item.Value)}
if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
