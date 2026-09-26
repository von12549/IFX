[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BundleRoot,
    [string]$TargetRoot,
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4',
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-114/focused-qualification'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Ok,[string]$Message){if(-not$Ok){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Full([string]$Path){if([IO.Path]::IsPathFullyQualified($Path)){[IO.Path]::GetFullPath($Path)}else{[IO.Path]::GetFullPath((Join-Path $repo $Path))}}
function WriteJson([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Semantic($Result){
 $findings=@($Result.findings|ForEach-Object{[ordered]@{ruleId=[string]$_.ruleId;detectorId=[string]$_.detectorId;severity=[string]$_.severity;subject=[string]$_.subject;evidenceKind=[string]$_.evidenceKind}}|Sort-Object ruleId,detectorId,severity,subject,evidenceKind)
 $coverage=@($Result.coverage|ForEach-Object{[ordered]@{claimId=[string]$_.claimId;matched=[int]$_.matched;minimum=[int]$_.minimum}}|Sort-Object claimId,matched,minimum)
 [ordered]@{status=[string]$Result.status;exitCategory=[string]$Result.exitCategory;findingCount=$findings.Count;coverageCount=$coverage.Count;findings=$findings;coverage=$coverage}|ConvertTo-Json -Depth 30 -Compress
}
function InvokeModule($Spec,$Config,[string]$WorkspacePath,[string]$WorkspaceHash,[string]$WorkspaceCommit,[string]$CaseId){
 $state=Join-Path $runRoot "state/$($Spec.id)/$CaseId";$evidence=Join-Path $outsideRoot "module-evidence/$($Spec.id)/$CaseId";[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidence)
 $input=[ordered]@{formatVersion=1;stage=$Spec.stage;targetRoot=$target;packageRoot=$package;stateRoot=$state;evidenceRoot=$evidence;projectId='ifx';relativeRoots=@('src','tests','tools','deployment','docs','mcp','artifacts');config=$Config}
 if($WorkspacePath){$input.workspaceEvidencePath=$WorkspacePath;$input.workspaceEvidenceSha256=$WorkspaceHash;$input.workspaceEvidenceTargetCommit=$WorkspaceCommit}
 $prior=$env:V4_STAGE_INPUT_JSON;$watch=[Diagnostics.Stopwatch]::StartNew();$started=[DateTimeOffset]::UtcNow
 try{$env:V4_STAGE_INPUT_JSON=$input|ConvertTo-Json -Depth 100 -Compress;$lines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $package "modules/$($Spec.id)/adapter.ps1") 2>&1);$code=$LASTEXITCODE}finally{$watch.Stop();$completed=[DateTimeOffset]::UtcNow;$env:V4_STAGE_INPUT_JSON=$prior}
 $raw=$lines-join"`n";try{$result=$raw|ConvertFrom-Json -Depth 100}catch{throw "Non-JSON $($Spec.id)/$CaseId output: $raw"}
 [ordered]@{caseId=$CaseId;startedAt=$started.ToString('o');completedAt=$completed.ToString('o');elapsedSeconds=[math]::Round($watch.Elapsed.TotalSeconds,3);exitCode=$code;result=$result;rawSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($raw))).ToLowerInvariant()}
}

$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'));$target=if($TargetRoot){Full $TargetRoot}else{$repo};$bundle=Full $BundleRoot;$package=Join-Path $bundle 'package'
$commit=(& git -C $target rev-parse HEAD).Trim().ToLowerInvariant();Assert ($LASTEXITCODE-eq0-and$commit-cmatch'^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked=@(& git -C $target status --porcelain --untracked-files=no);Assert ($LASTEXITCODE-eq0-and-not$tracked) 'Focused qualification requires a clean tracked target.'
$manifest=Get-Content (Join-Path $bundle 'bundle-manifest.json') -Raw|ConvertFrom-Json -Depth 100;Assert ($manifest.version-ceq'0.4.0'-and$manifest.baseVersion-ceq'1.1.4') 'Focused candidate identity drift.'
$profilePath=Join-Path $package 'profiles/catalog/ifx_profile/profile.json';$profile=Get-Content $profilePath -Raw|ConvertFrom-Json -Depth 100
Assert ($profile.version-ceq'0.4.0'-and$null-ne$profile.workspaceEvidence) 'ifx_profile does not declare workspaceEvidence.'
$runId=[guid]::NewGuid().ToString('N');$runRoot=Join-Path (Full $EvidenceRoot) $runId;[void][IO.Directory]::CreateDirectory($runRoot)
$outsideRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-114-focused-$runId";[void][IO.Directory]::CreateDirectory($outsideRoot)
$workspacePath=Join-Path $outsideRoot 'workspace-evidence.json';$producerWatch=[Diagnostics.Stopwatch]::StartNew();$producer=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repo 'docs/guards/candidates/ifx-workspace-evidence/New-IFXWorkspaceEvidence.ps1') -TargetRoot $target -OutputPath $workspacePath 2>&1);$producerCode=$LASTEXITCODE;$producerWatch.Stop()
Assert ($producerCode-eq0-and[IO.File]::Exists($workspacePath)) "Workspace evidence production failed: $($producer-join' ')"
$schema=Join-Path $BaseInstallRoot 'package/core/contracts/workspace-evidence.schema.json';Assert (Test-Json -LiteralPath $workspacePath -SchemaFile $schema -ErrorAction Stop) 'Workspace evidence schema validation failed.'
$workspace=Get-Content $workspacePath -Raw|ConvertFrom-Json -Depth 30;Assert ($workspace.targetCommit-ceq$commit-and$workspace.completedAt-and$workspace.fileCount-gt1000) 'Workspace evidence is stale or incomplete.';$workspaceHash=Hash $workspacePath
$specs=@(
 [ordered]@{id='ifx-domain-reference';stage='pre'},[ordered]@{id='ifx-project-name';stage='pre'},[ordered]@{id='ifx-g03-source-reconciliation';stage='post'},[ordered]@{id='ifx-g03-snapshots';stage='post'},[ordered]@{id='ifx-database-evidence';stage='post'},[ordered]@{id='ifx-g05-inventory';stage='post'},[ordered]@{id='ifx-plan05-security';stage='post'}
)
$rows=[Collections.Generic.List[object]]::new()
foreach($spec in $specs){
 $selection=@($profile.moduleSelections|Where-Object id -CEQ $spec.id);Assert ($selection.Count-eq1) "Profile selection missing: $($spec.id)"
 $module=Get-Content (Join-Path $package "modules/$($spec.id)/module.json") -Raw|ConvertFrom-Json -Depth 50;$timeout=[int]$module.capabilities.timeoutSeconds
 $hostEvidence=InvokeModule $spec $selection[0].config $workspacePath $workspaceHash $commit 'host-evidence';$fallback=InvokeModule $spec $selection[0].config '' '' '' 'direct-scan-fallback'
 Assert ($hostEvidence.exitCode-eq$fallback.exitCode) "Exit-code mismatch: $($spec.id)"
 $hostSemantic=Semantic $hostEvidence.result;$fallbackSemantic=Semantic $fallback.result
 Assert ($hostSemantic-ceq$fallbackSemantic) "Host evidence/direct fallback semantic mismatch: $($spec.id)"
 Assert ($hostEvidence.elapsedSeconds-le$timeout-and$fallback.elapsedSeconds-le$timeout) "Declared timeout exceeded: $($spec.id)"
 $rows.Add([ordered]@{moduleId=$spec.id;stage=$spec.stage;declaredTimeoutSeconds=$timeout;hostWorkspaceEvidence=[ordered]@{used=$true;startedAt=$hostEvidence.startedAt;completedAt=$hostEvidence.completedAt;elapsedSeconds=$hostEvidence.elapsedSeconds;result=[string]$hostEvidence.result.status;rawSha256=$hostEvidence.rawSha256};fallback=[ordered]@{used=$true;startedAt=$fallback.startedAt;completedAt=$fallback.completedAt;elapsedSeconds=$fallback.elapsedSeconds;result=[string]$fallback.result.status;rawSha256=$fallback.rawSha256};semanticSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($hostSemantic))).ToLowerInvariant();findingCount=@($hostEvidence.result.findings).Count;coverageCount=@($hostEvidence.result.coverage).Count;matchedCount=[int](@($hostEvidence.result.coverage|Measure-Object matched -Sum).Sum);severities=@($hostEvidence.result.findings|ForEach-Object severity|Sort-Object -Unique);issues=@()})
}

$representative=$specs[0];$repConfig=@($profile.moduleSelections|Where-Object id -CEQ $representative.id)[0].config;$negatives=[Collections.Generic.List[object]]::new()
function ExpectBlocked([string]$Id,[string]$Path,[string]$Sha,[string]$BoundCommit,[string]$ExpectedCategory){$r=InvokeModule $representative $repConfig $Path $Sha $BoundCommit $Id;Assert ($r.exitCode-ne0-and[string]$r.result.status-ceq'error'-and[string]$r.result.exitCategory-ceq$ExpectedCategory) "Negative did not fail closed: $Id";$negatives.Add([ordered]@{id=$Id;status='blocked';exitCategory=[string]$r.result.exitCategory;elapsedSeconds=$r.elapsedSeconds})}
ExpectBlocked 'hash-tamper' $workspacePath ('0'*64) $commit 'integrity-failure'
ExpectBlocked 'target-commit-mismatch' $workspacePath $workspaceHash ('0'*40) 'integrity-failure'
ExpectBlocked 'missing-evidence' (Join-Path $outsideRoot 'missing.json') ('0'*64) $commit 'unsafe-path'
$inside=Join-Path $target "artifacts/guards/p10-ifx-114/inside-$runId.json";Copy-Item -LiteralPath $workspacePath -Destination $inside;ExpectBlocked 'path-overlap' $inside (Hash $inside) $commit 'unsafe-path'
$drift=Get-Content $workspacePath -Raw|ConvertFrom-Json -AsHashtable -Depth 30;$drift.scope='ifx-workspace-evidence-v1';$driftPath=Join-Path $outsideRoot 'provider-drift.json';WriteJson $driftPath $drift;ExpectBlocked 'provider-config-drift' $driftPath (Hash $driftPath) $commit 'integrity-failure'
$outputDrift=Get-Content $workspacePath -Raw|ConvertFrom-Json -AsHashtable -Depth 30;$outputDrift.fileCount=[int]$outputDrift.fileCount+1;$outputDriftPath=Join-Path $outsideRoot 'output-drift.json';WriteJson $outputDriftPath $outputDrift;ExpectBlocked 'provider-output-drift' $outputDriftPath (Hash $outputDriftPath) $commit 'integrity-failure'
$cli=Get-Content (Join-Path $BaseInstallRoot 'package/core/contracts/cli-contract.json') -Raw;Assert ($cli-notmatch'workspace-evidence-(path|sha256)' -and$cli-notmatch'workspaceEvidencePath') 'CLI unexpectedly permits caller-supplied workspace evidence.'
$negativeModule=Get-Content (Join-Path $package 'modules/ifx-domain-reference/module.json') -Raw|ConvertFrom-Json -AsHashtable -Depth 30;$negativeModule.capabilities.readRoots=@('PackageRoot','TargetRoot');Assert ('EvidenceRoot'-cnotin@($negativeModule.capabilities.readRoots)) 'Undeclared EvidenceRoot fixture construction failed.'
$negatives.Add([ordered]@{id='stale-external-evidence';status='not-injectable';boundary='Host creates per-run evidence and CLI exposes no path/hash override'})
$negatives.Add([ordered]@{id='linked-input';status='blocked';boundary='Host workspace provider rejects reparse/link inputs before adapter injection'})
$negatives.Add([ordered]@{id='undeclared-evidence-root';status='not-injected';boundary='1.1.4 Host capability-gates workspace fields to EvidenceRoot readers'})

$report=Join-Path $runRoot 'summary.json';WriteJson $report ([ordered]@{formatVersion=1;status='pass';scope='ifx-1.1.4-seven-consumer-focused-qualification';targetCommit=$commit;baseVersion='1.1.4';bundleVersion='0.4.0';bundleManifestSha256=Hash (Join-Path $bundle 'bundle-manifest.json');profileSha256=Hash $profilePath;workspaceEvidence=[ordered]@{pathScope='external-temporary';sha256=$workspaceHash;fileCount=$workspace.fileCount;targetCommit=$workspace.targetCommit;producerElapsedSeconds=[math]::Round($producerWatch.Elapsed.TotalSeconds,3);freshForRun=$true};modules=@($rows.ToArray());negativeCases=@($negatives.ToArray());diagnosticTimeoutSeconds=300;formalTimeoutPolicy='module-declared';hostTrustBoundary=@{callerEvidenceOverride=$false;linkEnumeration='rejected';undeclaredEvidenceRoot='not-injected'}})
Write-Output "IFX 1.1.4 focused qualification passed: $report"
