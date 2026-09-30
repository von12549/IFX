# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: focused qualification of the seven
# workspace-evidence consumers in ifx_profile 0.5.0; successor of candidates/ifx-rebind-116/Test-IFX116FocusedQualification.ps1
# (unchanged). ifx-database-evidence is a 0.5.0-a lock consumer, so every one of its executions gets an EvidenceRoot staged
# from -ProductionRecord (Invoke-IFX050EvidenceProducers.ps1); the workspace-evidence cases are otherwise unchanged.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BundleRoot,
    [string]$TargetRoot,
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$CandidateVersion='0.5.1',
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-i2b/a2-051/focused-qualification-050',
    [Parameter(Mandatory)][string]$ProductionRecord
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function TextHash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Full([string]$Path){if([IO.Path]::IsPathFullyQualified($Path)){[IO.Path]::GetFullPath($Path)}else{[IO.Path]::GetFullPath((Join-Path $repo $Path))}}
function WriteJson([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Semantic($Result){
    $findings=@($Result.findings|ForEach-Object{[ordered]@{ruleId=[string]$_.ruleId;detectorId=[string]$_.detectorId;severity=[string]$_.severity;subject=[string]$_.subject;evidenceKind=[string]$_.evidenceKind}}|Sort-Object ruleId,detectorId,severity,subject,evidenceKind)
    $coverage=@($Result.coverage|ForEach-Object{[ordered]@{claimId=[string]$_.claimId;matched=[int]$_.matched;minimum=[int]$_.minimum}}|Sort-Object claimId,matched,minimum)
    [ordered]@{status=[string]$Result.status;exitCategory=[string]$Result.exitCategory;findings=$findings;coverage=$coverage}|ConvertTo-Json -Depth 30 -Compress
}
function InvokeProcess([string]$File,[string[]]$Arguments,[int]$TimeoutSeconds,[hashtable]$Environment=@{}){
    $start=[Diagnostics.ProcessStartInfo]::new($File);$start.UseShellExecute=$false;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$start.CreateNoWindow=$true
    foreach($argument in $Arguments){[void]$start.ArgumentList.Add($argument)}
    foreach($entry in $Environment.GetEnumerator()){$start.Environment[[string]$entry.Key]=[string]$entry.Value}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start;$started=[DateTimeOffset]::UtcNow;$watch=[Diagnostics.Stopwatch]::StartNew();Assert $process.Start() "Failed to start: $File"
    $stdoutTask=$process.StandardOutput.ReadToEndAsync();$stderrTask=$process.StandardError.ReadToEndAsync();$timedOut=-not $process.WaitForExit($TimeoutSeconds*1000)
    if($timedOut){try{$process.Kill($true)}catch{};$process.WaitForExit()}
    $watch.Stop();$stdout=$stdoutTask.GetAwaiter().GetResult();$stderr=$stderrTask.GetAwaiter().GetResult()
    [ordered]@{startedAt=$started.ToString('o');completedAt=[DateTimeOffset]::UtcNow.ToString('o');elapsedSeconds=[math]::Round($watch.Elapsed.TotalSeconds,3);timedOut=$timedOut;exitCode=$(if($timedOut){-1}else{$process.ExitCode});stdout=$stdout.Trim();stderr=$stderr.Trim()}
}
function InvokeModule($Spec,$Config,[string]$WorkspacePath,[string]$WorkspaceHash,[string]$WorkspaceCommit,[string]$CaseId){
    $state=Join-Path $runRoot "state/$($Spec.id)/$CaseId";$evidence=Join-Path $outsideRoot "module-evidence/$($Spec.id)/$CaseId";[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidence)
    if($Spec.id -ceq 'ifx-database-evidence'){$stageOut=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Invoke-IFX050EvidenceProducers.ps1') -Phase Stage -TargetRoot $target -RunRecordPath (Full $ProductionRecord) -EvidenceRoot $evidence 2>&1);Assert ($LASTEXITCODE -eq 0) "Evidence staging failed: $($stageOut -join ' ')"}
    $input=[ordered]@{formatVersion=1;stage=$Spec.stage;targetRoot=$target;packageRoot=$package;stateRoot=$state;evidenceRoot=$evidence;projectId='ifx';relativeRoots=@('src','tests','tools','deployment','docs','mcp','artifacts');config=$Config}
    if($WorkspacePath){$input.workspaceEvidencePath=$WorkspacePath;$input.workspaceEvidenceSha256=$WorkspaceHash;$input.workspaceEvidenceTargetCommit=$WorkspaceCommit}
    $module=Get-Content (Join-Path $package "modules/$($Spec.id)/module.json") -Raw|ConvertFrom-Json -Depth 50;$timeout=[int]$module.capabilities.timeoutSeconds
    $process=InvokeProcess 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $package "modules/$($Spec.id)/adapter.ps1")) $timeout @{V4_STAGE_INPUT_JSON=($input|ConvertTo-Json -Depth 100 -Compress)}
    Assert (-not $process.timedOut) "Declared timeout enforced: $($Spec.id)/$CaseId"
    Assert ($process.exitCode-eq0) "Adapter process failure $($Spec.id)/$CaseId`: $($process.stderr)"
    try{$result=$process.stdout|ConvertFrom-Json -Depth 100}catch{throw "Non-JSON $($Spec.id)/$CaseId`: $($process.stdout) $($process.stderr)"}
    Assert (Test-Json -Json $process.stdout -SchemaFile (Join-Path $package "modules/$($Spec.id)/result.schema.json") -ErrorAction Stop) "Result schema failed: $($Spec.id)/$CaseId"
    [ordered]@{caseId=$CaseId;startedAt=$process.startedAt;completedAt=$process.completedAt;elapsedSeconds=$process.elapsedSeconds;exitCode=$process.exitCode;result=$result;rawSha256=TextHash $process.stdout}
}
function CopyVariant([string]$Id,$Document){$path=Join-Path $outsideRoot "$Id.json";WriteJson $path $Document;[ordered]@{path=$path;sha256=Hash $path}}

$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'));$target=if($TargetRoot){Full $TargetRoot}else{$repo};$bundle=Full $BundleRoot;$package=Join-Path $bundle 'package'
$commit=(& git -C $target rev-parse HEAD).Trim().ToLowerInvariant();Assert ($LASTEXITCODE-eq0-and$commit-cmatch'^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked=@(& git -C $target status --porcelain --untracked-files=no);Assert ($LASTEXITCODE-eq0-and-not$tracked) 'Focused qualification requires a clean tracked target.'
$manifest=Get-Content (Join-Path $bundle 'bundle-manifest.json') -Raw|ConvertFrom-Json -Depth 100;Assert ($manifest.version-ceq$CandidateVersion-and$manifest.baseVersion-ceq'1.1.6') 'Focused candidate identity drift.'
$production=Get-Content (Full $ProductionRecord) -Raw|ConvertFrom-Json -Depth 20;Assert ($production.status-ceq'pass'-and$production.targetCommit-ceq$commit) 'The production record must pass at the Target commit.'
$profilePath=Join-Path $package 'profiles/catalog/ifx_profile/profile.json';$profile=Get-Content $profilePath -Raw|ConvertFrom-Json -Depth 100;Assert ($profile.version-ceq$CandidateVersion-and$null-ne$profile.workspaceEvidence) 'ifx_profile workspace evidence declaration drift.'
$runId=[guid]::NewGuid().ToString('N');$runRoot=Join-Path (Full $EvidenceRoot) $runId;$report=Join-Path $runRoot 'summary.json';[void][IO.Directory]::CreateDirectory($runRoot)
$outsideRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-050-focused-$runId";[void][IO.Directory]::CreateDirectory($outsideRoot)
$rows=[Collections.Generic.List[object]]::new();$negatives=[Collections.Generic.List[object]]::new();$currentCase='initialization';$started=[DateTimeOffset]::UtcNow
trap {
    $failure=[ordered]@{formatVersion=1;status='failed';scope='ifx-050a-seven-consumer-focused-qualification';targetCommit=$commit;baseVersion='1.1.6';bundleVersion=$CandidateVersion;startedAt=$started.ToString('o');completedAt=[DateTimeOffset]::UtcNow.ToString('o');failedCase=$currentCase;message=$_.Exception.Message;modules=@($rows.ToArray());negativeCases=@($negatives.ToArray())}
    try{WriteJson $report $failure}catch{};Write-Error "Focused qualification failed; evidence preserved at $report`: $($_.Exception.Message)" -ErrorAction Continue;exit 1
}

$currentCase='workspace-evidence-production';$workspacePath=Join-Path $outsideRoot 'workspace-evidence.json'
# 0.5.1 (A2): the workspace roots come from the composed Profile (producers/database replaces the V3_ifx specialized root).
$producer=InvokeProcess 'pwsh' (@('-NoLogo','-NoProfile','-NonInteractive','-File',(Join-Path $PSScriptRoot 'New-IFX051WorkspaceEvidence.ps1'),'-TargetRoot',$target,'-OutputPath',$workspacePath,'-RelativeRoots',(@($profile.workspaceEvidence.relativeRoots) -join ','))) 300
Assert (-not$producer.timedOut-and$producer.exitCode-eq0-and[IO.File]::Exists($workspacePath)) "Workspace evidence production failed: $($producer.stderr)"
$schema=Join-Path $BaseInstallRoot 'package/core/contracts/workspace-evidence.schema.json';Assert (Test-Json -LiteralPath $workspacePath -SchemaFile $schema -ErrorAction Stop) 'Workspace evidence schema validation failed.'
$workspace=Get-Content $workspacePath -Raw|ConvertFrom-Json -Depth 30;Assert ($workspace.targetCommit-ceq$commit-and$workspace.completedAt-and$workspace.fileCount-gt1000) 'Workspace evidence is stale or incomplete.';$workspaceHash=Hash $workspacePath
$specs=@(
    [ordered]@{id='ifx-domain-reference';stage='pre'},[ordered]@{id='ifx-project-name';stage='pre'},[ordered]@{id='ifx-g03-source-reconciliation';stage='post'},[ordered]@{id='ifx-g03-snapshots';stage='post'},[ordered]@{id='ifx-database-evidence';stage='post'},[ordered]@{id='ifx-g05-inventory';stage='post'},[ordered]@{id='ifx-plan05-security';stage='post'}
)
foreach($spec in $specs){
    $currentCase="semantic-equivalence/$($spec.id)";$selection=@($profile.moduleSelections|Where-Object id -CEQ $spec.id);Assert ($selection.Count-eq1) "Profile selection missing: $($spec.id)"
    $hostEvidence=InvokeModule $spec $selection[0].config $workspacePath $workspaceHash $commit 'host-evidence';$fallback=InvokeModule $spec $selection[0].config '' '' '' 'direct-scan-fallback'
    Assert ([string]$hostEvidence.result.status-cne'error'-and[string]$fallback.result.status-cne'error') "Positive execution rejected: $($spec.id)"
    $hostSemantic=Semantic $hostEvidence.result;$fallbackSemantic=Semantic $fallback.result;Assert ($hostSemantic-ceq$fallbackSemantic) "Workspace/fallback semantic mismatch: $($spec.id)"
    $rows.Add([ordered]@{moduleId=$spec.id;stage=$spec.stage;workspaceElapsedSeconds=$hostEvidence.elapsedSeconds;fallbackElapsedSeconds=$fallback.elapsedSeconds;semanticSha256=TextHash $hostSemantic;findingCount=@($hostEvidence.result.findings).Count;coverageCount=@($hostEvidence.result.coverage).Count})
}

$stale=Get-Content $workspacePath -Raw|ConvertFrom-Json -AsHashtable -Depth 30;$stale.targetCommit='0'*40;$staleVariant=CopyVariant 'stale-evidence' $stale
$scope=Get-Content $workspacePath -Raw|ConvertFrom-Json -AsHashtable -Depth 30;$scope.scope='ifx-workspace-evidence-v1';$scopeVariant=CopyVariant 'provider-scope-drift' $scope
$output=Get-Content $workspacePath -Raw|ConvertFrom-Json -AsHashtable -Depth 30;$output.fileCount=[int]$output.fileCount+1;$outputVariant=CopyVariant 'provider-output-drift' $output
$inside=Join-Path $target "artifacts/guards/p10-ifx-i2b/a2-051/inside-$runId.json";[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($inside));Copy-Item -LiteralPath $workspacePath -Destination $inside
$linkedSource=Join-Path $outsideRoot 'linked-source';[void][IO.Directory]::CreateDirectory($linkedSource);Copy-Item -LiteralPath $workspacePath -Destination (Join-Path $linkedSource 'workspace-evidence.json')
$linkedDirectory=Join-Path $outsideRoot 'linked-directory';[void](New-Item -ItemType Junction -Path $linkedDirectory -Target $linkedSource);$linked=Join-Path $linkedDirectory 'workspace-evidence.json'
$variants=@(
    [ordered]@{id='hash-tamper';path=$workspacePath;sha='0'*64;commit=$commit;category='integrity-failure'},
    [ordered]@{id='target-commit-mismatch';path=$workspacePath;sha=$workspaceHash;commit='0'*40;category='integrity-failure'},
    [ordered]@{id='missing-evidence';path=(Join-Path $outsideRoot 'missing.json');sha='0'*64;commit=$commit;category='unsafe-path'},
    [ordered]@{id='path-overlap';path=$inside;sha=(Hash $inside);commit=$commit;category='unsafe-path'},
    [ordered]@{id='stale-evidence';path=$staleVariant.path;sha=$staleVariant.sha256;commit=$commit;category='integrity-failure'},
    [ordered]@{id='provider-scope-drift';path=$scopeVariant.path;sha=$scopeVariant.sha256;commit=$commit;category='integrity-failure'},
    [ordered]@{id='provider-output-drift';path=$outputVariant.path;sha=$outputVariant.sha256;commit=$commit;category='integrity-failure'},
    [ordered]@{id='linked-input';path=$linked;sha=$workspaceHash;commit=$commit;category='unsafe-path'}
)
foreach($spec in $specs){
    $config=@($profile.moduleSelections|Where-Object id -CEQ $spec.id)[0].config
    foreach($variant in $variants){
        $currentCase="negative/$($spec.id)/$($variant.id)";$result=InvokeModule $spec $config $variant.path $variant.sha $variant.commit $variant.id
        Assert ([string]$result.result.status-ceq'error'-and[string]$result.result.exitCategory-ceq$variant.category) "Negative did not fail closed: $($spec.id)/$($variant.id)"
        $negatives.Add([ordered]@{moduleId=$spec.id;id=$variant.id;status='blocked';exitCategory=[string]$result.result.exitCategory;processExitCode=$result.exitCode;elapsedSeconds=$result.elapsedSeconds})
    }
}

$currentCase='host-profile-tamper';$tamperedBundle=Join-Path $outsideRoot 'tampered-bundle';Copy-Item -LiteralPath $bundle -Destination $tamperedBundle -Recurse
$tamperedProfile=Join-Path $tamperedBundle 'package/profiles/catalog/ifx_profile/profile.json';$tampered=Get-Content $tamperedProfile -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$tampered.workspaceEvidence.maximumFiles=[int]$tampered.workspaceEvidence.maximumFiles+1;WriteJson $tamperedProfile $tampered
$review=Join-Path ([IO.Path]::GetDirectoryName($bundle)) 'synthetic-review.json';Assert ([IO.File]::Exists($review)) 'Candidate synthetic review record missing.'
$compose=Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1';$tamperedCompose=InvokeProcess 'pwsh' @('-NoLogo','-NoProfile','-NonInteractive','-File',$compose,'-BaseInstallRoot',$BaseInstallRoot,'-BaseReceiptPath','D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json','-BaseArchivePath',(Full 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip'),'-BundleRoot',$tamperedBundle,'-ReviewRecordPath',$review,'-OutputInstallRoot',(Join-Path $outsideRoot 'tampered-install'),'-CompositionReceiptPath',(Join-Path $outsideRoot 'tampered-receipt.json'),'-TargetRoot',$target,'-StateRoot',(Join-Path $outsideRoot 'tampered-state'),'-EvidenceRoot',(Join-Path $outsideRoot 'tampered-evidence'),'-AllowSyntheticFixture') 300
Assert (-not$tamperedCompose.timedOut-and$tamperedCompose.exitCode-ne0) 'Host composition accepted profile/provider configuration tamper.'
$negatives.Add([ordered]@{moduleId='host';id='profile-provider-config-tamper';status='blocked';exitCategory='composition-integrity-failure';processExitCode=$tamperedCompose.exitCode;elapsedSeconds=$tamperedCompose.elapsedSeconds})

$currentCase='host-capability-gate';$hostSource=Join-Path $BaseInstallRoot 'package/core/host/V4.Guards.Host/StageRuntime.cs';$hostText=[IO.File]::ReadAllText($hostSource)
Assert ($hostText.Contains('(manifest.Capabilities.ReadRoots ?? []).Contains("EvidenceRoot", StringComparer.Ordinal)')) 'Host EvidenceRoot capability gate is absent.'
$cli=Get-Content (Join-Path $BaseInstallRoot 'package/core/contracts/cli-contract.json') -Raw;Assert ($cli-notmatch'workspace-evidence-(path|sha256)'-and$cli-notmatch'workspaceEvidencePath') 'CLI permits caller-supplied workspace evidence.'
$negatives.Add([ordered]@{moduleId='host';id='undeclared-evidence-root';status='not-injected';evidence='Host source capability gate plus CLI no-override contract'})

$currentCase='summary';$summary=[ordered]@{formatVersion=1;status='pass';scope='ifx-050a-seven-consumer-focused-qualification';targetCommit=$commit;baseVersion='1.1.6';bundleVersion=$CandidateVersion;bundleManifestSha256=Hash (Join-Path $bundle 'bundle-manifest.json');profileSha256=Hash $profilePath;startedAt=$started.ToString('o');completedAt=[DateTimeOffset]::UtcNow.ToString('o');workspaceEvidence=[ordered]@{pathScope='external-temporary';sha256=$workspaceHash;fileCount=$workspace.fileCount;targetCommit=$workspace.targetCommit;producerElapsedSeconds=$producer.elapsedSeconds;freshForRun=$true};modules=@($rows.ToArray());negativeCases=@($negatives.ToArray());negativeConsumerExecutions=@($negatives|Where-Object moduleId -ne 'host').Count;diagnosticTimeoutSeconds=300;formalTimeoutPolicy='process-kill-at-module-declared-timeout';hostTrustBoundary=[ordered]@{callerEvidenceOverride=$false;profileTamper='composition-rejected';linkedEvidence='rejected-by-all-seven-consumers';undeclaredEvidenceRoot='not-injected'}}
WriteJson $report $summary;Write-Output "IFX 0.5.0-a focused qualification passed: $report"
