# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: the C6c certification controls of
# the ifx_profile 0.5.0 candidate; successor of candidates/ifx-gate-coverage-c6c5/Test-IFXC6CertificationControls.ps1
# (unchanged). The capability (180) and root controls are transcribed. The 0.4.4 lock controls bound Profile lock
# paths and hashes, which 0.5.0 no longer has; they become staged-evidence controls: each of the six lock consumers
# runs the candidate adapter on a clean checkout of HEAD holding the C6c production (IFX050.Production.psm1) with
# evidence staged per case (current, missing staging, forged producer, altered lock, stale, wrong commit, and a Target
# change after production): 42 controls.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$BaseInstallRoot,
    [Parameter(Mandatory)][string]$BaseReceiptPath,
    [Parameter(Mandatory)][string]$BaseArchivePath,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [Parameter(Mandatory)][string]$ReportPath,
    [Parameter(Mandatory)][string]$ProductionSnapshotRoot,
    [string]$CandidateVersion='0.5.0'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Text-Hash([string]$Value) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))).ToLowerInvariant() }
function Test-Field($Value,[string]$Name) {
    if ($Value -is [Collections.IDictionary]) { return $Value.Contains($Name) }
    $Value.PSObject.Properties.Name -contains $Name
}
function Write-Json([string]$Path,$Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n") + "`n"),[Text.UTF8Encoding]::new($false))
}
function Clone-Object($Value) { ($Value | ConvertTo-Json -Depth 100) | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String }
function Fingerprint([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root)) { return '<absent>' }
    @((Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"
    })) -join "`n"
}
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Bind-File($Bundle,[string]$Relative,[string]$Path) {
    $entry = @($Bundle.files | Where-Object { $_.path -ceq $Relative })
    Assert ($entry.Count -eq 1) "Bundle file entry missing: $Relative"
    $entry[0].sha256 = Hash $Path; $entry[0].size = (Get-Item -LiteralPath $Path).Length
}
function Invoke-ComposeReject([string]$Id,[string]$Bundle,[string]$Review,[string]$Expected) {
    $caseRoot = Join-Path $workRoot "compose-rejections/$Id"
    [void][IO.Directory]::CreateDirectory($caseRoot)
    $state = Join-Path $caseRoot 'state'; $evidence = Join-Path $caseRoot 'evidence'
    [void][IO.Directory]::CreateDirectory($state); [void][IO.Directory]::CreateDirectory($evidence)
    $lines = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $composeScript `
        -BaseInstallRoot $baseInstall -BaseReceiptPath $baseReceipt -BaseArchivePath $archive `
        -BundleRoot $Bundle -ReviewRecordPath $Review -OutputInstallRoot (Join-Path $caseRoot 'install') `
        -CompositionReceiptPath (Join-Path $caseRoot 'receipt.json') -TargetRoot $repo -StateRoot $state `
        -EvidenceRoot $evidence -AllowSyntheticFixture 2>&1)
    $raw = $lines -join "`n"
    Assert ($LASTEXITCODE -ne 0 -and $raw -match [regex]::Escape($Expected) -and -not (Test-Path -LiteralPath (Join-Path $caseRoot 'install'))) "Composition control did not fail closed ($Id): $raw"
    [ordered]@{id=$Id;status='blocked';phase='pre-install';expected=$Expected;outputSha256=Text-Hash $raw}
}
function Invoke-Adapter([string]$ModuleId,$Configuration,[string]$Target,[string]$AdapterEvidence) {
    $adapter = Join-Path $bundlePackage "modules/$ModuleId/adapter.ps1"
    $schema = Join-Path $bundlePackage "modules/$ModuleId/result.schema.json"
    Assert ([IO.File]::Exists($adapter) -and [IO.File]::Exists($schema)) "Adapter or result schema missing: $ModuleId"
    $payload = [ordered]@{formatVersion=1;stage='post';targetRoot=$Target;packageRoot=$bundlePackage;stateRoot=(Join-Path $workRoot 'adapter-state');evidenceRoot=$AdapterEvidence;projectId='ifx';runId=[guid]::NewGuid().ToString('N');relativeRoots=@('src','tests','tools','deployment','docs','mcp','artifacts');config=$Configuration}
    $prior = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $payload | ConvertTo-Json -Depth 100 -Compress
        $lines = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1); $code = $LASTEXITCODE
    } finally { $env:V4_STAGE_INPUT_JSON = $prior }
    $raw = $lines -join "`n"
    Assert ($code -eq 0) "Adapter process failed ($ModuleId): $raw"
    Assert (Test-Json -Json $raw -SchemaFile $schema -ErrorAction SilentlyContinue) "Adapter result schema failed ($ModuleId): $raw"
    $raw | ConvertFrom-Json -Depth 100
}
function Assert-AdapterCase([string]$LockId,[string]$ModuleId,[string]$CaseId,$Configuration,[string]$Target,[string]$AdapterEvidence,[string]$Status,[string]$Category) {
    $result = Invoke-Adapter $ModuleId $Configuration $Target $AdapterEvidence
    Assert ($result.status -ceq $Status -and $result.exitCategory -ceq $Category) "Lock control mismatch: $LockId/$CaseId => $($result.status)/$($result.exitCategory)"
    $lockCases.Add([ordered]@{id="$LockId/$CaseId";lockId=$LockId;detectorId=$ModuleId;status=[string]$result.status;exitCategory=[string]$result.exitCategory;findingCount=@($result.findings).Count;resultSha256=Text-Hash ($result | ConvertTo-Json -Depth 100 -Compress)})
}
function Select-AssemblySourcePath($Assembly) {
    if (Test-Field $Assembly 'sourcePath') { return [string]$Assembly.sourcePath }
    if (Test-Field $Assembly 'path') { return [string]$Assembly.path }
    throw 'Assembly entry has no source path.'
}
function Select-PostProductionPath($Lock,[string]$Target) {
    $relative = $null
    if ((Test-Field $Lock 'files') -and @($Lock.files).Count -gt 0) { $relative = [string]$Lock.files[0].path }
    elseif ((Test-Field $Lock 'sourceFiles') -and @($Lock.sourceFiles).Count -gt 0) { $relative = [string]$Lock.sourceFiles[0].path }
    elseif ((Test-Field $Lock 'assemblies') -and @($Lock.assemblies).Count -gt 0) { $relative = Select-AssemblySourcePath $Lock.assemblies[0] }
    elseif ((Test-Field $Lock 'inputs') -and @($Lock.inputs).Count -gt 0) { $relative = [string]$Lock.inputs[0].path }
    Assert (-not [string]::IsNullOrWhiteSpace($relative)) 'No post-production mutation subject is available.'
    $full = if ([IO.Path]::IsPathFullyQualified($relative)) { $relative } else { Join-Path $Target $relative }
    Assert ([IO.File]::Exists($full)) "Post-production mutation subject missing: $relative"
    $full
}
function Test-GeneratedLock($Document,[string]$ExpectedHash,[string]$ActualPath,[string]$Target,[string]$ExpectedCommit) {
    if (-not [IO.File]::Exists($ActualPath)) { return 'prerequisite-missing' }
    if ((Hash $ActualPath) -cne $ExpectedHash) { return 'integrity-failure' }
    if ($Document.gate -cne 'C1GeneratedInputDisposition' -or $Document.producer -cne 'ifx-c1-r2c-controlled-v1' -or $Document.result -cne 'passed' -or $Document.targetCommit -cne $ExpectedCommit) { return 'integrity-failure' }
    try { $created=[DateTimeOffset]::Parse([string]$Document.createdAt); $expires=[DateTimeOffset]::Parse([string]$Document.expiresAt) } catch { return 'integrity-failure' }
    $now=[DateTimeOffset]::UtcNow
    if ($created -gt $now.AddMinutes(5) -or $created -lt $now.AddHours(-1) -or $expires -le $now -or $expires -gt $created.AddHours(1)) { return 'integrity-failure' }
    if ($Document.generatedFileCount -ne 179 -or $Document.generatorOutputCount -ne 4 -or $Document.applicableGeneratedSyntaxSubjectCount -ne 0) { return 'integrity-failure' }
    foreach ($file in $Document.generatedFiles) { $path=Join-Path $Target ([string]$file.path); if (-not [IO.File]::Exists($path) -or (Hash $path) -cne [string]$file.sha256) { return 'integrity-failure' } }
    'success'
}

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit = (& git -C $repo rev-parse HEAD).Trim()
Assert ($LASTEXITCODE -eq 0 -and $commit.Length -eq 40) 'Git commit unavailable.'
$trackedBefore = @(& git -C $repo status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and ($trackedBefore -join '').Trim().Length -eq 0) 'Tracked source must be clean.'
$inventoryFull=Full $InventoryPath; $bundle=Full $BundleRoot; $reviewFull=Full $ReviewRecordPath
$baseInstall=Full $BaseInstallRoot; $baseReceipt=Full $BaseReceiptPath; $archive=Full $BaseArchivePath
$runRoot=Full $EvidenceRoot; $report=Full $ReportPath
foreach ($path in @($inventoryFull,$bundle,$reviewFull,$baseInstall,$baseReceipt,$archive)) { Assert (Test-Path -LiteralPath $path) "Required control input missing: $path" }
Assert (-not (Test-Path -LiteralPath $runRoot)) 'Control EvidenceRoot must be absent.'
[void][IO.Directory]::CreateDirectory($runRoot)
$workRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx050-c-$([guid]::NewGuid().ToString('N').Substring(0,8))"
Assert (-not (Test-Path -LiteralPath $workRoot)) 'Control WorkRoot must be absent.'
[void][IO.Directory]::CreateDirectory($workRoot)
[void][IO.Directory]::CreateDirectory((Join-Path $workRoot 'adapter-state'))
$inventory=Get-Content $inventoryFull -Raw | ConvertFrom-Json -Depth 100
Assert ($inventory.status -ceq 'pass' -and $inventory.scope -ceq 'ifx-050a-source-module-claim-inventory' -and $inventory.sourceCommit -ceq $commit -and @($inventory.modules).Count -eq 37) 'Fresh 0.5.0-a inventory is invalid.'
$bundleManifestPath=Join-Path $bundle 'bundle-manifest.json'; $bundlePackage=Join-Path $bundle 'package'
$bundleManifest=Get-Content $bundleManifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$review=Get-Content $reviewFull -Raw | ConvertFrom-Json -AsHashtable -Depth 100
Assert ($bundleManifest.version -ceq $CandidateVersion -and @($bundleManifest.modules).Count -eq 36 -and $review.bundleManifestSha256 -ceq (Hash $bundleManifestPath)) 'Candidate bundle/review invalid.'
$bundleBefore=Fingerprint $bundle
$lineagePath=Join-Path $bundlePackage 'profiles/catalog/ifx_profile/evidence-lineage.json'
$profilePath=Join-Path $bundlePackage 'profiles/catalog/ifx_profile/profile.json'
$lineage=Get-Content $lineagePath -Raw | ConvertFrom-Json -Depth 100
$profile=Get-Content $profilePath -Raw | ConvertFrom-Json -Depth 100
Assert ($lineage.sourceCommit -ceq $commit -and $lineage.evidenceModel -ceq 'staged-by-workflow' -and @($lineage.producers).Count -eq 6) 'Staged-evidence lineage invalid.'
Assert ([IO.File]::ReadAllText($profilePath) -notmatch 'evidenceLock(Path|Sha256)') 'The 0.5.0 Profile names an evidence lock.'
$snapshot=Full $ProductionSnapshotRoot; $snapshotBefore=Fingerprint $snapshot

# Compose the exact candidate once for root-confinement controls.
$composeScript=Join-Path $baseInstall 'package/core/distribution/Compose-V4Extension.ps1'
$positiveRoot=Join-Path $workRoot 'positive-composition'; $positiveBundle=Join-Path $positiveRoot 'bundle'; $positiveReview=Join-Path $positiveRoot 'review.json'
$positiveState=Join-Path $positiveRoot 'state'; $positiveEvidence=Join-Path $positiveRoot 'evidence'
[void][IO.Directory]::CreateDirectory($positiveRoot)
Copy-Item -LiteralPath $bundle -Destination $positiveBundle -Recurse
Copy-Item -LiteralPath $reviewFull -Destination $positiveReview
[void][IO.Directory]::CreateDirectory($positiveState); [void][IO.Directory]::CreateDirectory($positiveEvidence)
$composed=Join-Path $positiveRoot 'install'; $compositionReceipt=Join-Path $positiveRoot 'receipt.json'
$composeOutput=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $composeScript -BaseInstallRoot $baseInstall -BaseReceiptPath $baseReceipt -BaseArchivePath $archive -BundleRoot $positiveBundle -ReviewRecordPath $positiveReview -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot $repo -StateRoot $positiveState -EvidenceRoot $positiveEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Exact candidate composition failed: $($composeOutput -join "`n")"
$packageBefore=Fingerprint (Join-Path $composed 'package')

# All 36 modules independently exceed each of five reviewed capability dimensions.
$variantRoot=Join-Path $workRoot 'capability-work'; $variantBundle=Join-Path $variantRoot 'bundle'; $variantReview=Join-Path $variantRoot 'review.json'
[void][IO.Directory]::CreateDirectory($variantRoot); Copy-Item -LiteralPath $bundle -Destination $variantBundle -Recurse; Copy-Item -LiteralPath $reviewFull -Destination $variantReview
$capabilityCases=[Collections.Generic.List[object]]::new()
foreach ($moduleEntry in @($bundleManifest.modules | Sort-Object id)) {
    $id=[string]$moduleEntry.id; $originalModule=Join-Path $bundlePackage ([string]$moduleEntry.manifestPath); $variantModule=Join-Path (Join-Path $variantBundle 'package') ([string]$moduleEntry.manifestPath)
    $ceiling=@($review.moduleCeilings | Where-Object moduleId -CEQ $id); Assert ($ceiling.Count -eq 1) "Reviewed ceiling missing: $id"
    foreach ($dimension in @('read-root','write-root','process','network','timeout')) {
        Copy-Item -LiteralPath $originalModule -Destination $variantModule -Force
        Copy-Item -LiteralPath $bundleManifestPath -Destination (Join-Path $variantBundle 'bundle-manifest.json') -Force
        Copy-Item -LiteralPath $reviewFull -Destination $variantReview -Force
        $moduleDocument=Get-Content $variantModule -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        switch ($dimension) {
            'read-root' { $moduleDocument.capabilities.readRoots=@($moduleDocument.capabilities.readRoots)+@('StateRoot') }
            'write-root' { $moduleDocument.capabilities.writeRoots=@('StateRoot') }
            'process' { $moduleDocument.capabilities.processes=@($moduleDocument.capabilities.processes)+@('cmd') }
            'network' { $moduleDocument.capabilities.network=$true }
            'timeout' { $moduleDocument.capabilities.timeoutSeconds=[int]$ceiling[0].allowedCapabilities.maxTimeoutSeconds+1 }
        }
        Write-Json $variantModule $moduleDocument
        Assert (Test-Json -LiteralPath $variantModule -SchemaFile (Join-Path $baseInstall 'package/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) "Capability variant is not schema-valid: $id/$dimension"
        $variantManifest=Get-Content (Join-Path $variantBundle 'bundle-manifest.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $variantEntry=@($variantManifest.modules | Where-Object id -CEQ $id); Assert ($variantEntry.Count -eq 1) "Variant module entry missing: $id"
        $variantEntry[0].manifestSha256=Hash $variantModule; Bind-File $variantManifest ([string]$moduleEntry.manifestPath) $variantModule
        Write-Json (Join-Path $variantBundle 'bundle-manifest.json') $variantManifest
        $variantReviewDocument=Get-Content $variantReview -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $variantReviewDocument.bundleManifestSha256=Hash (Join-Path $variantBundle 'bundle-manifest.json'); Write-Json $variantReview $variantReviewDocument
        $capabilityCases.Add((Invoke-ComposeReject "$id-$dimension" $variantBundle $variantReview 'Module capabilities exceed or differ from reviewed ceiling'))
    }
    Copy-Item -LiteralPath $originalModule -Destination $variantModule -Force
}
Assert ($capabilityCases.Count -eq 180) 'Capability control cardinality drift.'

# Root overlap, normalized traversal and link controls use the exact composed candidate.
$rootCases=[Collections.Generic.List[object]]::new(); $hostPath=Join-Path $composed 'host/v4-guards.dll'; $package=Join-Path $composed 'package'
function Invoke-RootReject([string]$Id,[string]$State,[string]$Evidence) {
    $lines=@(& dotnet $hostPath stage run --stage pre --package-root $package --target-root $repo --state-root $State --evidence-root $Evidence --profile ifx_profile 2>&1); $raw=$lines-join"`n"
    Assert ($LASTEXITCODE -eq 11 -and $raw -match 'unsafe-path') "Root control did not fail closed ($Id): $raw"
    $rootCases.Add([ordered]@{id=$Id;status='blocked';exitCode=11;exitCategory='unsafe-path';outputSha256=Text-Hash $raw})
}
$rootScratch=Join-Path $workRoot 'root-controls'; $safeState=Join-Path $rootScratch 'state'; $safeEvidence=Join-Path $rootScratch 'evidence'; [void][IO.Directory]::CreateDirectory($safeState); [void][IO.Directory]::CreateDirectory($safeEvidence)
Invoke-RootReject 'state-inside-package' (Join-Path $package 'modules') $safeEvidence
Invoke-RootReject 'evidence-inside-target' $safeState (Join-Path $repo 'artifacts')
[void][IO.Directory]::CreateDirectory((Join-Path $safeState 'nested'))
Invoke-RootReject 'mutable-overlap' $safeState (Join-Path $safeState 'nested')
Invoke-RootReject 'normalized-traversal-to-target' $safeState (Join-Path $repo 'src/../')
$actualLink=Join-Path $rootScratch 'actual-link-state'; [void][IO.Directory]::CreateDirectory($actualLink); $link=Join-Path $rootScratch 'linked-state'; $linkStatus='unsupported'
try { $linkType=if($IsWindows){'Junction'}else{'SymbolicLink'}; New-Item -ItemType $linkType -Path $link -Target $actualLink -ErrorAction Stop | Out-Null; Invoke-RootReject 'linked-state-root' $link $safeEvidence; $linkStatus='blocked' } catch { if (Test-Path -LiteralPath $link) { throw }; $rootCases.Add([ordered]@{id='linked-state-root';status='unsupported';reason=$_.Exception.Message}) }

# Forbidden immutable-root write declarations are rejected by schema before adapter launch.
foreach ($writeRoot in @('PackageRoot','TargetRoot')) {
    Copy-Item -LiteralPath $bundle -Destination (Join-Path $workRoot "write-$writeRoot-bundle") -Recurse
    $writeBundle=Join-Path $workRoot "write-$writeRoot-bundle"; $writeReview=Join-Path $workRoot "write-$writeRoot-review.json"; Copy-Item $reviewFull $writeReview
    $first=$bundleManifest.modules[0]; $writeModule=Join-Path (Join-Path $writeBundle 'package') ([string]$first.manifestPath); $doc=Get-Content $writeModule -Raw|ConvertFrom-Json -AsHashtable -Depth 100; $doc.capabilities.writeRoots=@($writeRoot); Write-Json $writeModule $doc
    $manifestDoc=Get-Content (Join-Path $writeBundle 'bundle-manifest.json') -Raw|ConvertFrom-Json -AsHashtable -Depth 100; $entry=@($manifestDoc.modules|Where-Object id -CEQ $first.id)[0]; $entry.manifestSha256=Hash $writeModule; Bind-File $manifestDoc ([string]$first.manifestPath) $writeModule; Write-Json (Join-Path $writeBundle 'bundle-manifest.json') $manifestDoc
    $reviewDoc=Get-Content $writeReview -Raw|ConvertFrom-Json -AsHashtable -Depth 100; $reviewDoc.bundleManifestSha256=Hash (Join-Path $writeBundle 'bundle-manifest.json'); Write-Json $writeReview $reviewDoc
    $rootCases.Add((Invoke-ComposeReject "declared-$($writeRoot.ToLowerInvariant())-write" $writeBundle $writeReview 'module schema validation failed'))
}

# Staged-evidence controls. One clean checkout of HEAD holds the C6c production; every case stages it afresh.
Import-Module (Join-Path $PSScriptRoot 'IFX050.Production.psm1') -Force
$shadow=Join-Path $workRoot 'shadow'
$clone=@(& git clone --no-local --quiet -c core.longpaths=true $repo $shadow 2>&1); Assert ($LASTEXITCODE -eq 0) "Evidence shadow clone failed: $($clone -join ' ')"
Assert ((& git -C $shadow rev-parse HEAD).Trim() -ceq $commit) 'Evidence shadow commit drift.'
$imported=Import-IFX050Production -SnapshotRoot $snapshot -TargetRoot $shadow; $productionRecord=[string]$imported.productionRecord
$production=Get-Content $productionRecord -Raw | ConvertFrom-Json -Depth 20
Assert ($production.status -ceq 'pass' -and $production.targetCommit -ceq $commit) 'The C6c production is not at HEAD.'
$stageScript=Join-Path $PSScriptRoot 'Invoke-IFX050EvidenceProducers.ps1'
function Stage-Case([string]$Name) {
    $dir=Join-Path $workRoot "staged/$Name"
    $o=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $stageScript -Phase Stage -TargetRoot $shadow -RunRecordPath $productionRecord -EvidenceRoot $dir 2>&1); Assert ($LASTEXITCODE -eq 0) "Staging failed ($Name): $($o -join ' ')"
    $dir
}
function Edit-Staging([string]$Dir,[scriptblock]$Change) { $p=Join-Path $Dir 'locks/staging.json'; $j=Get-Content $p -Raw | ConvertFrom-Json -AsHashtable -Depth 30 -DateKind String; & $Change $j; Write-Json $p $j }
function Reseal([string]$Dir,[string]$Gate) { $sha=Hash (Join-Path $Dir "locks/$Gate/evidence-lock.json"); Edit-Staging $Dir { param($j) foreach ($g in $j.gates) { if ($g.gate -ceq $Gate) { $g.lockSha256=$sha } } }.GetNewClosure() }
function Select-TargetSubject([string]$Gate,$Lock) {
    # A Target file the consumer re-reads after production.
    if (Test-Field $Lock 'sourceFiles') { return [string]$Lock.sourceFiles[0].path }
    if (Test-Field $Lock 'inputs') { return [string]$Lock.inputs[0].path }
    if ($Gate -ceq 'assembly') { return [string]$Lock.assemblies[0].path }
    if ($Gate -ceq 'frontend') { return 'src/Frontend/IFX.FrontEnd/package.json' }
    $first=@(& git -C $shadow -c core.quotePath=false ls-files -- 'src/*.cs' | Select-Object -First 1)
    Assert ($first.Count -eq 1) "No source subject for $Gate."; [string]$first[0]
}
$moduleMap=[ordered]@{solution='ifx-solution-evidence';assembly='ifx-assembly-evidence';frontend='ifx-frontend-evidence';database='ifx-database-evidence';graph='ifx-c1-evaluated-reference';type='ifx-c1-type-provenance'}
$lockCases=[Collections.Generic.List[object]]::new()
foreach ($gate in $moduleMap.Keys) {
    $moduleId=[string]$moduleMap[$gate]; $selection=@($profile.moduleSelections|Where-Object id -CEQ $moduleId); Assert ($selection.Count -eq 1) "Profile lock consumer missing: $gate"
    $config=Clone-Object $selection[0].config; Assert (-not ($config.Contains('evidenceLockPath') -or $config.Contains('evidenceLockSha256'))) "Profile config names a lock: $moduleId"
    $current=Stage-Case "$gate-current"; Assert-AdapterCase $gate $moduleId 'current' $config $shadow $current 'pass' 'success'
    $dir=Stage-Case "$gate-missing-staging"; [IO.File]::Delete((Join-Path $dir 'locks/staging.json')); Assert-AdapterCase $gate $moduleId 'missing-staging' $config $shadow $dir 'error' 'prerequisite-missing'
    $dir=Stage-Case "$gate-forged-producer"; Edit-Staging $dir { param($j) foreach ($g in $j.gates) { if ($g.gate -ceq $gate) { $g.producer.scriptSha256='0'*64 } } }.GetNewClosure(); Assert-AdapterCase $gate $moduleId 'forged-producer' $config $shadow $dir 'error' 'integrity-failure'
    $dir=Stage-Case "$gate-altered"; [IO.File]::AppendAllText((Join-Path $dir "locks/$gate/evidence-lock.json"),"`n"); Assert-AdapterCase $gate $moduleId 'altered' $config $shadow $dir 'error' 'integrity-failure'
    $dir=Stage-Case "$gate-stale"; $lockPath=Join-Path $dir "locks/$gate/evidence-lock.json"; $stale=Get-Content $lockPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
    if ($stale.Contains('createdAt')) { $stale.createdAt=[DateTimeOffset]::UtcNow.AddHours(-3).ToString('o'); $stale.expiresAt=[DateTimeOffset]::UtcNow.AddHours(-2).ToString('o') } else { $stale.startedAt=[DateTimeOffset]::UtcNow.AddHours(-48).ToString('o'); $stale.completedAt=[DateTimeOffset]::UtcNow.AddHours(-47).ToString('o') }
    Write-Json $lockPath $stale; Reseal $dir $gate; Assert-AdapterCase $gate $moduleId 'stale' $config $shadow $dir 'error' 'integrity-failure'
    $dir=Stage-Case "$gate-wrong-commit"; $lockPath=Join-Path $dir "locks/$gate/evidence-lock.json"; $wrong=Get-Content $lockPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String; $wrong.targetCommit='0'*40; Write-Json $lockPath $wrong; Reseal $dir $gate
    Assert-AdapterCase $gate $moduleId 'wrong-commit' $config $shadow $dir 'error' 'integrity-failure'
    $subject=Join-Path $shadow (Select-TargetSubject $gate (Get-Content (Join-Path $current "locks/$gate/evidence-lock.json") -Raw | ConvertFrom-Json -Depth 100)); $subjectBytes=[IO.File]::ReadAllBytes($subject)
    try { [IO.File]::WriteAllBytes($subject,($subjectBytes+[byte]10)); Assert-AdapterCase $gate $moduleId 'post-production-change' $config $shadow $current 'error' 'integrity-failure' } finally { [IO.File]::WriteAllBytes($subject,$subjectBytes) }
}
Assert ($lockCases.Count -eq 42) "Staged-evidence control cardinality drift: $($lockCases.Count)"
Assert (@(& git -C $shadow status --porcelain --untracked-files=all).Count -eq 0) 'Evidence shadow was not restored.'

Assert ((Fingerprint $bundle) -ceq $bundleBefore) 'Original bundle changed during controls.'
Assert ((Fingerprint (Join-Path $composed 'package')) -ceq $packageBefore) 'Composed PackageRoot changed during controls.'
Assert ((Fingerprint $snapshot) -ceq $snapshotBefore) 'Production snapshot changed during controls.'
$trackedAfter=@(& git -C $repo status --porcelain --untracked-files=no); Assert ($LASTEXITCODE -eq 0 -and ($trackedAfter-join"`n") -ceq ($trackedBefore-join"`n")) 'Tracked TargetRoot changed during controls.'

Write-Json $report ([ordered]@{
    formatVersion=1;status='pass';scope='ifx-050a-certification-controls';sourceCommit=$commit
    inventorySha256=Hash $inventoryFull;bundleManifestSha256=Hash $bundleManifestPath;reviewRecordSha256=Hash $reviewFull;productionSnapshotManifestSha256=Hash (Join-Path $snapshot 'manifest.json')
    lockControlCount=$lockCases.Count;lockCases=@($lockCases.ToArray())
    capabilityVariantCount=$capabilityCases.Count;capabilityCases=@($capabilityCases.ToArray())
    rootControlCount=$rootCases.Count;rootCases=@($rootCases.ToArray());linkControlStatus=$linkStatus
    invariants=[ordered]@{originalBundle='unchanged';composedPackage='unchanged';productionSnapshot='unchanged';trackedTarget='unchanged'}
})
Write-Output "IFX 0.5.0-a certification controls passed: $report"
