[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c4p0/test-runs',
    [string] $BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string] $BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string] $BaseArchivePath = 'artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Text([string] $Path, [string] $Body) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path,$Body,[Text.UTF8Encoding]::new($false)) }
function Write-Json([string] $Path, $Value) { Write-Text $Path (($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n") }
function Inventory([string] $Root) { @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object { "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)" }) -join "`n" }
function Source-Files([string] $Root) { @(Get-ChildItem -LiteralPath (Join-Path $Root 'src') -File -Filter '*.cs' -Recurse -Force | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } | Sort-Object FullName) }
function Source-Hash([string] $Root) {
    $lines = @(Source-Files $Root | ForEach-Object { "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)" }) -join "`n"
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lines))).ToLowerInvariant()
}
$candidateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repo = [IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-g05-inventory'
$adapter = Join-Path $moduleRoot 'adapter.ps1'
$manifestPath = Join-Path $moduleRoot 'module.json'
$policyPath = Join-Path $moduleRoot 'policy.json'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 100
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json -Depth 100
$matrix = Get-Content (Join-Path $repo 'docs/guards/inventories/20260924-ifx-c4-g05-claim-matrix.json') -Raw | ConvertFrom-Json -Depth 100
$mapped = @($matrix.claims | Where-Object { $_.source -ceq 'G05 Phase 11' -and $_.phase -eq 0 } | ForEach-Object id)
Assert ($mapped.Count -eq 13 -and ($mapped -join '|') -ceq (@($policy.checkIds) -join '|')) 'Phase 0 matrix mapping drift.'
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/module.schema.json') -ErrorAction Stop) 'Module schema failed.'
Assert ($manifest.id -ceq 'ifx-g05-inventory' -and (@($manifest.stages) -join '|') -ceq 'post' -and (@($manifest.capabilities.readRoots) -join '|') -ceq 'PackageRoot|TargetRoot|EvidenceRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and (@($manifest.capabilities.processes) -join '|') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false) 'Module capability drift.'
Assert ((Hash $adapter) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Module byte lock drift.'
foreach ($authority in $manifest.authorities) { Assert ((Hash (Join-Path $candidateRoot $authority.path)) -ceq $authority.sha256) "Module authority drift: $($authority.id)" }
$plan = Get-Content (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 50
Assert ($plan.moduleId -ceq $manifest.id -and @($plan.rules).Count -eq 1 -and $plan.rules[0].ruleId -ceq 'G05-INVENTORY' -and $plan.rules[0].claimId -ceq $policy.claimId -and $plan.rules[0].minimumMatches -eq 1 -and $null -eq $plan.rules[0].baseline) 'Blocking rule drift.'
$archive = if ([IO.Path]::IsPathFullyQualified($BaseArchivePath)) { $BaseArchivePath } else { Join-Path $repo $BaseArchivePath }
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive hash drift.'
Assert ((Get-Content $BaseReceiptPath -Raw | ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$baseCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package') | ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$out = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repo $EvidenceRoot }
$run = Join-Path $out ([guid]::NewGuid().ToString('N')); [void][IO.Directory]::CreateDirectory($run)
function Config([string] $Root) { [ordered]@{ enabledClaims=@($policy.claimId); policySha256=Hash $policyPath; authorityHashes=@($policy.authorityPaths | ForEach-Object { [ordered]@{path=$_;sha256=Hash (Join-Path $Root $_)} }); sourceTreeSha256=Source-Hash $Root } }
function Invoke-Adapter([string] $Root, $Configuration) {
    $env:V4_STAGE_INPUT_JSON = [ordered]@{formatVersion=1;stage='post';targetRoot=$Root;relativeRoots=@('src','docs');config=$Configuration} | ConvertTo-Json -Depth 50 -Compress
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Adapter process failed: $($output -join "`n")"
    return (($output -join "`n") | ConvertFrom-Json -Depth 100)
}
$realConfig = Config $repo
Assert (Test-Json -Json ($realConfig | ConvertTo-Json -Depth 40 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'
$realBefore = @($policy.authorityPaths | ForEach-Object { "$_|$(Hash (Join-Path $repo $_))" }) -join "`n"
$real = Invoke-Adapter $repo $realConfig
Assert ($real.status -ceq 'pass' -and $real.exitCategory -ceq 'success' -and $real.coverage[0].matched -gt 100) "Real IFX Phase 0 scan failed: $($real | ConvertTo-Json -Compress -Depth 30)"
Assert ($realBefore -ceq (@($policy.authorityPaths | ForEach-Object { "$_|$(Hash (Join-Path $repo $_))" }) -join "`n")) 'Real target authority changed.'
function New-Target([string] $Name, [bool] $CopySources) {
    $root = Join-Path $run "target-$Name"; [void][IO.Directory]::CreateDirectory((Join-Path $root 'src'))
    foreach ($relative in $policy.authorityPaths) { $to=Join-Path $root $relative; [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to)); [IO.File]::WriteAllBytes($to,[IO.File]::ReadAllBytes((Join-Path $repo $relative))) }
    if ($CopySources) { foreach ($file in (Source-Files $repo)) { $to=Join-Path $root ([IO.Path]::GetRelativePath($repo,$file.FullName)); [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to)); [IO.File]::WriteAllBytes($to,[IO.File]::ReadAllBytes($file.FullName)) } }
    return $root
}
$cases = [Collections.Generic.List[object]]::new()
$cleanTarget = New-Target 'clean' $true
$cleanConfig = Config $cleanTarget
$before = Inventory $cleanTarget
$result = Invoke-Adapter $cleanTarget $cleanConfig
Assert ($result.status -ceq 'pass' -and $result.exitCategory -ceq 'success' -and (Inventory $cleanTarget) -ceq $before) 'Clean fixture failed.'
    Assert (Test-Json -Json ($result | ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $moduleRoot 'result.schema.json') -ErrorAction Stop) 'Result schema failed.'
$again=Invoke-Adapter $cleanTarget $cleanConfig
Assert (($again | ConvertTo-Json -Compress -Depth 30) -ceq ($result | ConvertTo-Json -Compress -Depth 30)) 'Clean result is nondeterministic.'
$cases.Add([ordered]@{id='clean';status=$result.status;category=$result.exitCategory})
$outboxTarget = New-Target 'no-outbox' $true
foreach ($file in @(Source-Files $outboxTarget | Where-Object { $_.FullName -match '[\\/]Outbox[\\/]|Outbox.*\.cs$' })) { [IO.File]::Delete($file.FullName) }
$outboxResult = Invoke-Adapter $outboxTarget (Config $outboxTarget)
Assert ($outboxResult.status -ceq 'fail' -and @($outboxResult.findings.subject) -contains 'durableMessagingCapabilitiesRecordedTruthfully') 'Outbox negative did not block.'
$cases.Add([ordered]@{id='no-outbox';status=$outboxResult.status;category=$outboxResult.exitCategory})
$zeroTarget = New-Target 'zero' $false
$zeroResult = Invoke-Adapter $zeroTarget (Config $zeroTarget)
Assert ($zeroResult.status -ceq 'fail' -and $zeroResult.coverage[0].matched -eq 0 -and @($zeroResult.findings.subject) -contains 'zero-subject') 'Zero-source control did not block.'
$cases.Add([ordered]@{id='zero-source';status=$zeroResult.status;category=$zeroResult.exitCategory})
$missingTarget = New-Target 'missing' $true
[IO.File]::Delete((Join-Path $missingTarget $policy.authorityPaths[0]))
$missingConfig = $cleanConfig | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable -Depth 50
$missingResult = Invoke-Adapter $missingTarget $missingConfig
Assert ($missingResult.status -ceq 'error' -and $missingResult.exitCategory -ceq 'prerequisite-missing') 'Missing authority did not block.'
$cases.Add([ordered]@{id='missing-authority';status=$missingResult.status;category=$missingResult.exitCategory})
$staleTarget = New-Target 'stale' $true
[IO.File]::AppendAllText((Join-Path $staleTarget $policy.authorityPaths[0]),' ')
$staleResult = Invoke-Adapter $staleTarget $cleanConfig
Assert ($staleResult.status -ceq 'error' -and $staleResult.exitCategory -ceq 'integrity-failure') 'Stale authority did not block.'
$cases.Add([ordered]@{id='stale-authority';status=$staleResult.status;category=$staleResult.exitCategory})

$bundleRoot=Join-Path $run 'bundle';$bundlePackage=Join-Path $bundleRoot 'package';$bundleModule=Join-Path $bundlePackage 'modules/ifx-g05-inventory'
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bundleModule));Copy-Item -LiteralPath $moduleRoot -Destination $bundleModule -Recurse
$profileId='ifx_c4p0_fixture';$profilePath=Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
Write-Json $profilePath ([ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx-c4p0-fixture';relativeRoots=@('src','docs')};moduleSelections=@([ordered]@{id='ifx-g05-inventory';versionRange='>=0.1.0 <1.0.0';config=$cleanConfig});stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@('ifx-g05-inventory')}};rules=@('G05-INVENTORY');baselineRefs=@()})
$bundleFiles=@(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {[ordered]@{path=[IO.Path]::GetRelativePath($bundlePackage,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot','EvidenceRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=60}
$bundleManifest=Join-Path $bundleRoot 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c4p0-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@([ordered]@{id='ifx-g05-inventory';version='0.1.0';manifestPath='modules/ifx-g05-inventory/module.json';manifestSha256=Hash (Join-Path $bundleModule 'module.json');allowedCapabilities=$ceiling});files=$bundleFiles})
$review=Join-Path $run 'synthetic-review.json'
Write-Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c4p0-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c4p0-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@([ordered]@{moduleId='ifx-g05-inventory';allowedCapabilities=$ceiling})})
$composed=Join-Path $run 'composed';$receipt=Join-Path $run 'composition.receipt.json';$state=Join-Path $run 'compose-state';$evidence=Join-Path $run 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidence)
$composeOutput=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundleRoot -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $cleanTarget -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Published Host composition failed: $($composeOutput -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n") | ConvertFrom-Json).status -ceq 'pass') 'Composed receipt check failed.'
$hostState=Join-Path $run 'host-state';$hostEvidence=Join-Path $run 'host-evidence';[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
$packageBefore=Inventory (Join-Path $composed 'package');$targetBefore=Inventory $cleanTarget
$hostOutput=@(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $cleanTarget --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
$hostResult=($hostOutput -join "`n") | ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $hostResult.status -ceq 'pass' -and $hostResult.exitCategory -ceq 'success' -and @($hostResult.coverage | Where-Object matched -gt 100).Count -eq 1) "Host Post failed: $($hostOutput -join "`n")"
Assert ((Inventory (Join-Path $composed 'package')) -ceq $packageBefore -and (Inventory $cleanTarget) -ceq $targetBefore) 'Host modified an immutable root.'
Write-Json (Join-Path $run 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-c4p0';baseVersion='1.1.3';mappedChecks=13;cases=@($cases);realCoverage=@($real.coverage);hostCoverage=@($hostResult.coverage);hostComposition='synthetic-only-pass'})
Write-Output "IFX C4p0 13-check inventory and published Host Post passed. Evidence: $run"
