[CmdletBinding()]
param(
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c4p1/test-runs',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()}
function Write-Text([string]$Path,[string]$Body){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,$Body,[Text.UTF8Encoding]::new($false))}
function Write-Json([string]$Path,$Value){Write-Text $Path (($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n")}
function Inventory([string]$Root){@((Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})) -join "`n"}
$candidateRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot=[IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$moduleRoot=Join-Path $candidateRoot 'modules/ifx-g05-protocol'
$adapterPath=Join-Path $moduleRoot 'adapter.ps1';$policyPath=Join-Path $moduleRoot 'policy.json';$manifestPath=Join-Path $moduleRoot 'module.json'
$policy=Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json -AsHashtable -Depth 100
$manifest=Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -AsHashtable -Depth 100
$basePackage=Join-Path $BaseInstallRoot 'package'
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repoRoot $BaseArchivePath}
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $basePackage 'core/contracts/module.schema.json') -ErrorAction Stop) 'Module schema failed.'
Assert ($manifest.id -ceq 'ifx-g05-protocol' -and ($manifest.stages -join '|') -ceq 'post' -and
    ($manifest.capabilities.readRoots -join '|') -ceq 'PackageRoot|TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and
    ($manifest.capabilities.processes -join '|') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false -and $manifest.capabilities.timeoutSeconds -eq 60) 'Module identity or capabilities drift.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Adapter/dependency hash drift.'
foreach($a in $manifest.authorities){Assert ((Hash (Join-Path $candidateRoot $a.path)) -ceq $a.sha256) "Module authority drift: $($a.id)"}
$rulePlan=Get-Content (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
Assert ($rulePlan.moduleId -ceq $manifest.id -and @($rulePlan.rules).Count -eq 3 -and @($rulePlan.rules | Where-Object { $_.stage -eq 'post' -and $_.severity -eq 'blocking' -and $_.minimumMatches -eq 1 }).Count -eq 3) 'Rule Plan drift.'
$matrix=Get-Content (Join-Path $repoRoot 'docs/guards/inventories/20260924-ifx-c4-g05-claim-matrix.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$mapped=@($matrix.claims | Where-Object { $_.source -eq 'G05 Phase 11' -and $_.phase -eq 1 } | ForEach-Object id | Sort-Object)
$actual=@($policy.predicates | ForEach-Object id | Sort-Object)
Assert ($mapped.Count -eq 11 -and ($mapped -join '|') -ceq ($actual -join '|')) '11-check C4p1 matrix mapping drift.'
$baseCheck=& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage | ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass' -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') '1.1.3 Package check failed.'
Assert ([IO.File]::Exists($archive) -and (Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') '1.1.3 archive digest drift.'
Assert ((Get-Content $BaseReceiptPath -Raw | ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) '1.1.3 receipt/archive mismatch.'
$evidence=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repoRoot $EvidenceRoot}
$runRoot=Join-Path $evidence ([Guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($runRoot)
$claims=@('IFX.C4.G05_PROTOCOL_DEPENDENCIES','IFX.C4.G05_PROTOCOL_SHAPES','IFX.C4.G05_PROTOCOL_EVIDENCE')
$baseConfig=[ordered]@{enabledClaims=$claims;policySha256=Hash $policyPath;authorityHashes=@($policy.authorities | ForEach-Object {[ordered]@{id=$_.id;sha256=Hash (Join-Path $repoRoot $_.path)}})}
Assert (Test-Json -Json ($baseConfig | ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'
function Invoke-Adapter([string]$Target,$Config){
    $env:V4_STAGE_INPUT_JSON=[ordered]@{formatVersion=1;stage='post';targetRoot=$Target;relativeRoots=@('src','docs','tests','deployment');config=$Config} | ConvertTo-Json -Depth 40 -Compress
    $output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapterPath 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Adapter process failed: $($output -join "`n")"
    return (($output -join "`n") | ConvertFrom-Json -Depth 100)
}
function New-Case([string]$Id,[string]$Mutation){
    $target=Join-Path $runRoot "target-$Id";[void][IO.Directory]::CreateDirectory($target)
    foreach($a in $policy.authorities){$to=Join-Path $target $a.path;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to));[IO.File]::WriteAllBytes($to,[IO.File]::ReadAllBytes((Join-Path $repoRoot $a.path)))}
    $config=$baseConfig | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
    $changed=@()
    switch($Mutation){
        'none' {}
        'framework-leak' {$changed=@('identifiers');$p=Join-Path $target 'src/Platform/Context/IFX.Platform.Context.Contracts/ContextIdentifiers.cs';[IO.File]::AppendAllText($p,"`nusing Microsoft.AspNetCore.Http;`n")}
        'invalid-version' {$changed=@('protocolPolicy');$p=Join-Path $target 'docs/architecture/review/gates/G05/context-protocol-v1.json';$body=[IO.File]::ReadAllText($p);Assert ($body.Contains('"version": 1')) 'Version mutation subject absent.';Write-Text $p ($body.Replace('"version": 1','"version": 2'))}
        'missing-authority' {$p=Join-Path $target 'tests/IFX.Platform.ProtocolContracts.Tests/EventEnvelopeV1Tests.cs';[IO.File]::Delete($p)}
        'stale-authority' {$p=Join-Path $target 'src/Platform/Context/IFX.Platform.Context.Contracts/ContextIdentifiers.cs';[IO.File]::AppendAllText($p,' ')}
        'zero-subject' {$changed=@('contextProject','messagingProject','identifiers','scopes','references','contractContext','eventEnvelope','eventIdentifier','eventSchema','integrationEvent');foreach($id in $changed){$a=$policy.authorities | Where-Object id -eq $id | Select-Object -First 1;Write-Text (Join-Path $target $a.path) ''}}
        default{throw "Unknown mutation: $Mutation"}
    }
    foreach($id in $changed){$a=$policy.authorities | Where-Object id -eq $id | Select-Object -First 1;($config.authorityHashes | Where-Object id -eq $id | Select-Object -First 1).sha256=Hash (Join-Path $target $a.path)}
    return [pscustomobject]@{target=$target;config=$config}
}
$fixtures=Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 30
Assert ($fixtures.formatVersion -eq 1 -and @($fixtures.cases).Count -eq 6) 'Fixture catalog drift.'
$results=@()
foreach($case in $fixtures.cases){
    $fixture=New-Case $case.id $case.mutation;$before=Inventory $fixture.target
    $result=Invoke-Adapter $fixture.target $fixture.config
    Assert ((Inventory $fixture.target) -ceq $before) "TargetRoot changed: $($case.id)"
    Assert ($result.status -ceq $case.status -and $result.exitCategory -ceq $case.category) "Fixture mismatch $($case.id): $($result | ConvertTo-Json -Depth 20 -Compress)"
    Assert (Test-Json -Json ($result | ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $moduleRoot 'result.schema.json') -ErrorAction Stop) "Result schema failed: $($case.id)"
    if($case.id -in @('clean','zero-subject')){$again=Invoke-Adapter $fixture.target $fixture.config;Assert (($again | ConvertTo-Json -Depth 50 -Compress) -ceq ($result | ConvertTo-Json -Depth 50 -Compress)) "Nondeterminism: $($case.id)"}
    if($case.status -ceq 'pass'){Assert (@($result.coverage | Where-Object matched -lt 1).Count -eq 0) 'Clean fixture has zero coverage.'}
    $results += [ordered]@{id=$case.id;status=$result.status;category=$result.exitCategory}
}
$beforeReal=@($policy.authorities | ForEach-Object {"$($_.id)|$(Hash (Join-Path $repoRoot $_.path))"}) -join "`n"
$real=Invoke-Adapter $repoRoot $baseConfig
$afterReal=@($policy.authorities | ForEach-Object {"$($_.id)|$(Hash (Join-Path $repoRoot $_.path))"}) -join "`n"
Assert ($real.status -ceq 'pass' -and $beforeReal -ceq $afterReal) 'Real IFX direct scan or immutable TargetRoot failed.'
$hostFixture=New-Case 'host-clean' 'none';$bundleRoot=Join-Path $runRoot 'bundle';$bundlePackage=Join-Path $bundleRoot 'package'
$bundleModule=Join-Path $bundlePackage 'modules/ifx-g05-protocol';[void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModule));Copy-Item -LiteralPath $moduleRoot -Destination $bundleModule -Recurse
$profileId='ifx_c4p1_fixture';$profilePath=Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
Write-Json $profilePath ([ordered]@{
    formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx-c4p1-fixture';relativeRoots=@('src','docs','tests','deployment')}
    moduleSelections=@([ordered]@{id='ifx-g05-protocol';versionRange='>=0.1.0 <1.0.0';config=$hostFixture.config})
    stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@('ifx-g05-protocol')}}
    rules=@('G05-PROTOCOL-DEPS','G05-PROTOCOL-SHAPES','G05-PROTOCOL-EVIDENCE');baselineRefs=@()
})
$bundleFiles=@(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {[ordered]@{path=[IO.Path]::GetRelativePath($bundlePackage,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=60}
$bundleManifest=Join-Path $bundleRoot 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c4p1-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@([ordered]@{id='ifx-g05-protocol';version='0.1.0';manifestPath='modules/ifx-g05-protocol/module.json';manifestSha256=Hash (Join-Path $bundleModule 'module.json');allowedCapabilities=$ceiling});files=$bundleFiles})
$reviewPath=Join-Path $runRoot 'synthetic-review.json'
Write-Json $reviewPath ([ordered]@{formatVersion=1;id='20260924-ifx-c4p1-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c4p1-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@([ordered]@{moduleId='ifx-g05-protocol';allowedCapabilities=$ceiling})})
$composed=Join-Path $runRoot 'composed';$receipt=Join-Path $runRoot 'composition.receipt.json';$state=Join-Path $runRoot 'compose-state';$evidenceDir=Join-Path $runRoot 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidenceDir)
$composeOutput=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $hostFixture.target -StateRoot $state -EvidenceRoot $evidenceDir -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Composition failed: $($composeOutput -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Composition receipt failed: $($verify -join "`n")"
$hostState=Join-Path $runRoot 'host-state';$hostEvidence=Join-Path $runRoot 'host-evidence';[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
$targetBefore=Inventory $hostFixture.target;$packageBefore=Inventory (Join-Path $composed 'package')
$hostOutput=@(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $hostFixture.target --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
$hostResult=($hostOutput -join "`n") | ConvertFrom-Json -Depth 100
Assert ($hostResult.status -ceq 'pass' -and $hostResult.exitCategory -ceq 'success' -and @($hostResult.coverage | Where-Object matched -ge 1).Count -eq 3 -and (Inventory $hostFixture.target) -ceq $targetBefore -and (Inventory (Join-Path $composed 'package')) -ceq $packageBefore) "Host Post/invariance failed: $($hostOutput -join "`n")"
$baseAfter=& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage | ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $baseAfter.packageHash -ceq $baseCheck.packageHash) 'Published Package changed.'
Write-Json (Join-Path $runRoot 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-c4p1';baseVersion='1.1.3';predicateCount=11;cases=$results;realCoverage=@($real.coverage);hostCoverage=@($hostResult.coverage);hostComposition='synthetic-only-pass'})
Write-Output "IFX C4p1 passed 11 mapped checks, $(@($results).Count) fixtures, real IFX and published 1.1.3 Host Post. Evidence: $runRoot"
