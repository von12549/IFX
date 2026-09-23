[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c2e/test-runs',
    [string] $BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.2',
    [string] $BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.2.install.json',
    [string] $BaseArchivePath = 'artifacts/guards/p10-ifx-c1h/base-reconstruction/v4-guards-1.1.2.zip'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Text([string] $Path, [string] $Body) {
    [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($Path)))
    [IO.File]::WriteAllText($Path, $Body, [Text.UTF8Encoding]::new($false))
}
function Write-Json([string] $Path, $Value) { Write-Text $Path (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n") }
function Inventory([string] $Root) {
    @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/'))|$(Hash $_.FullName)"
    }) -join "`n"
}
$candidateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$lock = Get-Content (Join-Path $candidateRoot 'authority-lock.json') -Raw | ConvertFrom-Json -Depth 100
$profilePath = Join-Path $candidateRoot 'profile.json'
$profile = Get-Content $profilePath -Raw | ConvertFrom-Json -Depth 100
$fixtures = Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 20
Assert ($lock.formatVersion -eq 1 -and $lock.scope -ceq 'candidate-test-only' -and
    $lock.publishedBaseVersion -ceq '1.1.2' -and $lock.v4.stage -ceq 'post' -and
    $lock.v4.moduleCount -eq 5 -and $lock.v4.claimCount -eq 16 -and
    $lock.v3.phase -eq 9 -and $lock.v3.aggregateChecks -eq 15) 'C2e lock identity drift.'
Assert (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/profile.schema.json') -ErrorAction SilentlyContinue) 'Candidate Profile schema failed.'
Assert ((Hash $profilePath) -ceq $lock.profileSha256) 'Candidate Profile hash drift.'
Assert ((Hash (Join-Path $repoRoot $lock.v3.gateScriptPath)) -ceq $lock.v3.gateScriptSha256) 'V3 G03 gate script drift.'
foreach ($authority in $lock.targetAuthorities) { Assert ((Hash (Join-Path $repoRoot $authority.path)) -ceq $authority.sha256) "Target authority hash drift: $($authority.path)." }
$moduleIds = @($lock.modules | ForEach-Object id)
Assert ($moduleIds.Count -eq 5 -and @($moduleIds | Sort-Object -Unique).Count -eq 5) 'Module lock is incomplete or duplicated.'
$ruleIds = [Collections.Generic.List[string]]::new()
$claimIds = [Collections.Generic.List[string]]::new()
foreach ($module in $lock.modules) {
    $directory = Join-Path $repoRoot $module.sourceDirectory
    Assert ((Hash (Join-Path $directory 'module.json')) -ceq $module.manifestSha256 -and
        (Hash (Join-Path $directory 'policy.json')) -ceq $module.policySha256) "Module authority drift: $($module.id)."
    $manifest = Get-Content (Join-Path $directory 'module.json') -Raw | ConvertFrom-Json -Depth 50
    Assert ($manifest.id -ceq $module.id -and ($manifest.stages -join ',') -ceq 'post' -and
        ($manifest.capabilities.readRoots -join ',') -ceq 'PackageRoot,TargetRoot' -and
        @($manifest.capabilities.writeRoots).Count -eq 0 -and $manifest.capabilities.network -eq $false) "Module capabilities drift: $($module.id)."
    Assert (Test-Json -LiteralPath (Join-Path $directory 'module.json') -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) "Module schema failed: $($module.id)."
    Assert ((Hash (Join-Path $directory 'adapter.ps1')) -ceq $manifest.adapter.sha256 -and
        (Hash (Join-Path $directory 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) "Module byte lock drift: $($module.id)."
    foreach ($authority in $manifest.authorities) { Assert ((Hash (Join-Path $repoRoot "$(Split-Path -Parent $module.sourceDirectory)/../$($authority.path)")) -ceq $authority.sha256) "Module internal authority drift: $($module.id)/$($authority.id)." }
    $plan = Get-Content (Join-Path $directory 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 50
    Assert ($plan.moduleId -ceq $module.id -and $plan.matrixSha256 -ceq $module.policySha256) "Rule plan drift: $($module.id)."
    foreach ($rule in $plan.rules) {
        Assert ($rule.stage -ceq 'post' -and $rule.severity -ceq 'blocking' -and $rule.minimumMatches -eq 1 -and $null -eq $rule.baseline) "Rule weakened: $($rule.ruleId)."
        $ruleIds.Add([string]$rule.ruleId); $claimIds.Add([string]$rule.claimId)
    }
    $selection = @($profile.moduleSelections | Where-Object id -eq $module.id)
    Assert ($selection.Count -eq 1 -and $selection[0].versionRange -ceq '>=0.1.0 <1.0.0') "Profile module selection drift: $($module.id)."
    Assert (Test-Json -Json ($selection[0].config | ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $directory 'config.schema.json') -ErrorAction SilentlyContinue) "Profile config schema failed: $($module.id)."
    Assert ($selection[0].config.policySha256 -ceq $module.policySha256 -and
        (@($selection[0].config.enabledClaims) -join '|') -ceq (@($plan.rules.claimId) -join '|')) "Profile claim/config drift: $($module.id)."
}
function Assert-Profile($Value) {
    Assert ($Value.id -ceq 'ifx_g03_c2e_candidate' -and $Value.projectIdentity.id -ceq 'ifx' -and
        (@($Value.projectIdentity.relativeRoots) -join '|') -ceq 'src|docs' -and
        @($Value.baselineRefs).Count -eq 0) 'Candidate Profile identity, roots or baselines drift.'
    Assert (@($Value.moduleSelections).Count -eq 5 -and
        (@($Value.moduleSelections.id) -join '|') -ceq ($moduleIds -join '|') -and
        (@($Value.stageConfiguration.post.modules) -join '|') -ceq ($moduleIds -join '|')) 'Candidate Profile module dependency drift.'
    Assert (-not $Value.stageConfiguration.bootstrap.enabled -and -not $Value.stageConfiguration.analysis.enabled -and
        -not $Value.stageConfiguration.pre.enabled -and $Value.stageConfiguration.post.enabled -and
        @($Value.stageConfiguration.bootstrap.modules).Count -eq 0 -and
        @($Value.stageConfiguration.analysis.modules).Count -eq 0 -and
        @($Value.stageConfiguration.pre.modules).Count -eq 0) 'Candidate Profile stage drift.'
    Assert ((@($Value.rules | Sort-Object) -join '|') -ceq (@($ruleIds.ToArray() | Sort-Object) -join '|') -and
        @($Value.rules).Count -eq 16) 'Candidate Profile rule selection drift.'
    foreach ($module in $lock.modules) {
        $selection = @($Value.moduleSelections | Where-Object id -eq $module.id)
        $plan = Get-Content (Join-Path $repoRoot "$($module.sourceDirectory)/rule-execution-plan.json") -Raw | ConvertFrom-Json -Depth 30
        Assert ($selection.Count -eq 1 -and (@($selection[0].config.enabledClaims) -join '|') -ceq (@($plan.rules.claimId) -join '|')) "Candidate Profile missing claim: $($module.id)."
    }
}
Assert-Profile $profile
Assert ($ruleIds.Count -eq 16 -and $claimIds.Count -eq 16 -and
    @($ruleIds.ToArray() | Sort-Object -Unique).Count -eq 16 -and
    @($claimIds.ToArray() | Sort-Object -Unique).Count -eq 16) 'Combined rules/claims are incomplete or duplicated.'
foreach ($authority in $lock.targetAuthorities) {
    $hash = $authority.sha256
    if ($authority.path -eq '.github/CODEOWNERS') { continue }
    $matching = @($profile.moduleSelections | Where-Object { @($_.config.PSObject.Properties.Value) -contains $hash })
    Assert ($matching.Count -gt 0) "Target authority is not Profile-bound: $($authority.path)."
}
$clone = $profile | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
$clone.moduleSelections = @($clone.moduleSelections | Select-Object -Skip 1)
try { Assert-Profile $clone; throw 'Missing-module profile unexpectedly accepted.' } catch { Assert ($_.Exception.Message -ne 'Missing-module profile unexpectedly accepted.') 'Missing-module profile unexpectedly accepted.' }
$clone = $profile | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
$clone.moduleSelections[0].config.enabledClaims = @($clone.moduleSelections[0].config.enabledClaims | Select-Object -Skip 1)
try { Assert-Profile $clone; throw 'Missing-claim profile unexpectedly accepted.' } catch { Assert ($_.Exception.Message -ne 'Missing-claim profile unexpectedly accepted.') 'Missing-claim profile unexpectedly accepted.' }
$clone = $profile | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
$clone.rules = @($clone.rules | Select-Object -Skip 1)
try { Assert-Profile $clone; throw 'Missing-rule profile unexpectedly accepted.' } catch { Assert ($_.Exception.Message -ne 'Missing-rule profile unexpectedly accepted.') 'Missing-rule profile unexpectedly accepted.' }
$clone = $profile | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
$clone.baselineRefs = @('unreviewed-waiver.json')
try { Assert-Profile $clone; throw 'Baseline-injection profile unexpectedly accepted.' } catch { Assert ($_.Exception.Message -ne 'Baseline-injection profile unexpectedly accepted.') 'Baseline-injection profile unexpectedly accepted.' }

$outputRoot = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repoRoot $EvidenceRoot }
$workRoot = Join-Path ([IO.Path]::GetTempPath()) "ifx-g03-c2e-$([guid]::NewGuid().ToString('N'))"
[void][IO.Directory]::CreateDirectory($workRoot)
Write-Output "C2e work root: $workRoot"
$baseCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repoRoot 'docs/guards/candidates/ifx-gate-coverage-c1i/Test-PublishedV4Base.ps1') -ArchivePath $BaseArchivePath -ReceiptPath $BaseReceiptPath -InstallRoot $BaseInstallRoot | ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass' -and $baseCheck.packageHash -ceq $lock.publishedPackageSha256) 'Published V4 base identity drift.'

function New-Target([string] $Id, [string] $Mutation) {
    $target = Join-Path $workRoot "target-$Id"
    [void][IO.Directory]::CreateDirectory((Join-Path $target 'docs/architecture'))
    Copy-Item -LiteralPath (Join-Path $repoRoot 'docs/architecture/review') -Destination (Join-Path $target 'docs/architecture/review') -Recurse
    $codeowners = Join-Path $target '.github/CODEOWNERS'
    [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($codeowners)))
    Copy-Item -LiteralPath (Join-Path $repoRoot '.github/CODEOWNERS') -Destination $codeowners
    foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Recurse -File | Where-Object {
        $_.Extension -in @('.cs','.csproj') -and $_.FullName -notmatch '[\\/](bin|obj)[\\/]'
    })) {
        $destination = Join-Path $target ([IO.Path]::GetRelativePath($repoRoot, $file.FullName))
        [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($destination)))
        Copy-Item -LiteralPath $file.FullName -Destination $destination
    }
    $catalogPath = Join-Path $target 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
    switch ($Mutation) {
        'stale-catalog' { $value = Get-Content $catalogPath -Raw | ConvertFrom-Json -Depth 100; $value.protocols[0].provider = 'unknown-provider'; Write-Json $catalogPath $value }
        'governance-violation' { $value = Get-Content $catalogPath -Raw | ConvertFrom-Json -Depth 100; $value.protocols[0].provider = 'unknown-provider'; Write-Json $catalogPath $value }
        'zero-protocol' { $value = Get-Content $catalogPath -Raw | ConvertFrom-Json -Depth 100; $value.protocols = @(); Write-Json $catalogPath $value }
        'missing-projection' { [IO.File]::Delete((Join-Path $target 'docs/architecture/review/gates/G03/generated/layerguard-governance-input.json')) }
        'stale-document' { $path = Join-Path $target 'docs/architecture/review/gates/G03/contract-event-governance.en.md'; Write-Text $path ([IO.File]::ReadAllText($path) + "`nUnexpected stale line.`n") }
        default { throw "Unknown mutation: $Mutation" }
    }
    return $target
}

function New-Composition([string] $Id, [string] $Target, $ProfileOverride = $null) {
    $bundleRoot = Join-Path $workRoot "bundle-$Id"
    $bundlePackage = Join-Path $bundleRoot 'package'
    [void][IO.Directory]::CreateDirectory((Join-Path $bundlePackage 'modules'))
    $bundleModules = [Collections.Generic.List[object]]::new()
    $ceiling = [ordered]@{ readRoots = @('PackageRoot','TargetRoot'); writeRoots = @(); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 60 }
    foreach ($module in $lock.modules) {
        $destination = Join-Path $bundlePackage "modules/$($module.id)"
        Copy-Item -LiteralPath (Join-Path $repoRoot $module.sourceDirectory) -Destination $destination -Recurse
        $bundleModules.Add([ordered]@{
            id = $module.id; version = '0.1.0'; manifestPath = "modules/$($module.id)/module.json"
            manifestSha256 = Hash (Join-Path $destination 'module.json'); allowedCapabilities = $ceiling
        })
    }
    $profileId = 'ifx_g03_c2e_candidate'
    $bundleProfile = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($bundleProfile)))
    if ($null -eq $ProfileOverride) { Copy-Item -LiteralPath $profilePath -Destination $bundleProfile }
    else { Write-Json $bundleProfile $ProfileOverride }
    $bundleFiles = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\','/'); sha256 = Hash $_.FullName; size = $_.Length }
    })
    $bundleManifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $bundleManifestPath ([ordered]@{
        formatVersion = 1; id = "ifx-c2e-$Id-synthetic-extension"; version = '0.1.0'; compatibleApi = '1.x'; baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $bundleProfile })
        modules = @($bundleModules.ToArray()); files = $bundleFiles
    })
    $reviewPath = Join-Path $workRoot "synthetic-review-$Id.json"
    $ceilings = @($lock.modules | ForEach-Object { [ordered]@{ moduleId = $_.id; allowedCapabilities = $ceiling } })
    Write-Json $reviewPath ([ordered]@{
        formatVersion = 1; id = "20260924-ifx-c2e-$Id-synthetic-fixture"; scope = 'synthetic-test-only'; decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = "ifx-c2e-$Id-synthetic-fixture"; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $bundleManifestPath; baseArchiveSha256 = $baseCheck.archiveSha256
        moduleCeilings = $ceilings
    })
    $composed = Join-Path $workRoot "composed-$Id"
    $receipt = Join-Path $workRoot "composition-$Id.receipt.json"
    $state = Join-Path $workRoot "compose-state-$Id"; $evidence = Join-Path $workRoot "compose-evidence-$Id"
    [void][IO.Directory]::CreateDirectory($state); [void][IO.Directory]::CreateDirectory($evidence)
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $Target -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed ($Id): $($output -join "`n")"
    $verify = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Synthetic receipt failed ($Id): $($verify -join "`n")"
    return [pscustomobject]@{ install = $composed; package = Join-Path $composed 'package'; receipt = $receipt; profileHash = Hash $bundleProfile }
}
function Invoke-Host([string] $Id, $Installation, [string] $Target, [bool] $WithDependencies) {
    $state = Join-Path $workRoot "host-state-$Id"; $evidence = Join-Path $workRoot "host-evidence-$Id"
    [void][IO.Directory]::CreateDirectory($state); [void][IO.Directory]::CreateDirectory($evidence)
    $targetBefore = if ($Target -ceq $repoRoot) {
        @($lock.targetAuthorities | ForEach-Object { "$($_.path)|$(Hash (Join-Path $Target $_.path))" }) -join "`n"
    } else { Inventory $Target }
    $packageBefore = Inventory $Installation.package
    $arguments = @((Join-Path $Installation.install 'host/v4-guards.dll'), 'stage', 'run', '--stage', 'post',
        '--package-root', $Installation.package, '--target-root', $Target, '--state-root', $state,
        '--evidence-root', $evidence, '--profile', 'ifx_g03_c2e_candidate')
    if ($WithDependencies) { $arguments += '--with-dependencies' }
    $output = @(& dotnet @arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $raw = $output -join "`n"
    try { $result = $raw | ConvertFrom-Json -Depth 100 }
    catch { throw "Host output is not JSON ($Id): $raw" }
    $targetAfter = if ($Target -ceq $repoRoot) {
        @($lock.targetAuthorities | ForEach-Object { "$($_.path)|$(Hash (Join-Path $Target $_.path))" }) -join "`n"
    } else { Inventory $Target }
    Assert ($targetAfter -ceq $targetBefore -and (Inventory $Installation.package) -ceq $packageBefore) "TargetRoot or PackageRoot changed during $Id."
    return [pscustomobject]@{ result = $result; exitCode = $exitCode; raw = $raw; evidence = $evidence }
}

$cleanInstallation = New-Composition 'clean' $repoRoot
Assert ($cleanInstallation.profileHash -ceq $lock.profileSha256) 'Composed clean Profile differs from locked candidate.'
$results = [Collections.Generic.List[object]]::new()
Assert ($fixtures.formatVersion -eq 1 -and @($fixtures.hostCases).Count -eq 7 -and
    (@($fixtures.profileRejectCases) -join '|') -ceq 'missing-module|missing-claim|missing-rule|baseline-injection') 'Integration fixture catalog drift.'
foreach ($case in $fixtures.hostCases) {
    $target = if ($case.target -ceq 'real') { $repoRoot } else { New-Target $case.id $case.mutation }
    $installation = $cleanInstallation
    if ($case.mutation -in @('governance-violation','zero-protocol')) {
        $override = $profile | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
        $catalogHash = Hash (Join-Path $target 'docs/architecture/review/gates/G03/contract-event-catalog.yaml')
        foreach ($selection in $override.moduleSelections) { $selection.config.catalogSha256 = $catalogHash }
        $installation = New-Composition $case.id $target $override
    }
    $run = Invoke-Host $case.id $installation $target ($case.mode -ceq 'dependencies')
    $result = $run.result
    Assert ($result.status -ceq $case.status -and $result.exitCategory -ceq $case.category) "Host case mismatch $($case.id): $($run.raw)"
    if ($case.status -ceq 'pass') {
        Assert ($run.exitCode -eq 0 -and @($result.moduleResults).Count -eq 5 -and
            @($result.moduleResults | Where-Object status -ne 'pass').Count -eq 0 -and
            @($result.coverage).Count -eq 16 -and @($result.findings).Count -eq 0 -and
            @($result.coverage | Where-Object { $_.matched -lt 1 -or $_.minimum -ne 1 }).Count -eq 0 -and
            @($result.coverage.claimId | Sort-Object -Unique).Count -eq 16) "Combined G03 coverage is incomplete: $($case.id)."
        $expectedStages = if ($case.mode -ceq 'dependencies') { 'bootstrap|analysis|pre|post' } else { 'post' }
        Assert ((@($result.executedStages) -join '|') -ceq $expectedStages) "Stage sequence drift: $($case.id)."
        foreach ($module in $lock.modules) {
            Assert ($result.authorityHashes."module.$($module.id)" -ceq $module.manifestSha256) "Host module authority drift: $($module.id)."
        }
        Assert (@($result.authorityHashes.PSObject.Properties.Name | Where-Object { $_ -like 'baseline.*' }).Count -eq 0) 'Unexpected baseline authority was loaded.'
    } else {
        Assert ($run.exitCode -ne 0 -and $result.status -in @('fail','error')) "Negative case did not block: $($case.id)."
        if ($case.mutation -eq 'zero-protocol') {
            Assert (@($result.findings | Where-Object { $_.subject -like 'zero-protocol:*' -or $_.subject -like '*matched 0*' }).Count -gt 0) 'Zero-protocol negative lacked non-vacuity finding.'
        }
    }
    $results.Add([ordered]@{ id = $case.id; status = $result.status; exitCategory = $result.exitCategory; modules = @($result.moduleResults).Count; claims = @($result.coverage).Count })
}

$v3Root = Join-Path $workRoot 'v3-phase9'
[void][IO.Directory]::CreateDirectory($v3Root)
$v3ReportPath = Join-Path $v3Root 'G03-phase9-guard-report.json'
$v3Output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repoRoot $lock.v3.gateScriptPath) -Phase 9 -ReportPath $v3ReportPath 2>&1)
Assert ($LASTEXITCODE -eq 0) "Fresh V3 G03 Phase 9 failed: $($v3Output -join "`n")"
$v3Report = Get-Content $v3ReportPath -Raw | ConvertFrom-Json -Depth 100
$v3Status = Get-Content (Join-Path $v3Root 'G03-phase9-status.json') -Raw | ConvertFrom-Json -Depth 100
Assert ($v3Report.result -ceq 'passed' -and @($v3Report.checks.PSObject.Properties).Count -eq $lock.v3.aggregateChecks -and
    @($v3Report.checks.PSObject.Properties | Where-Object Value -eq $false).Count -eq 0) 'Fresh V3 G03 aggregate diverged.'
Assert ($v3Status.result -ceq 'passed' -and $v3Status.counts.protocols -eq $lock.v3.protocols -and
    $v3Status.counts.activeProtocols -eq $lock.v3.activeProtocols -and
    $v3Status.counts.legacyItems -eq $lock.v3.legacyItems -and
    $v3Status.closureStatus -ceq $lock.v3.closureStatus -and
    $v3Status.readyForClosure -eq $lock.v3.readyForClosure -and
    (@($v3Status.blockers.code | Sort-Object) -join '|') -ceq (@($lock.v3.blockerCodes | Sort-Object) -join '|')) 'Fresh V3 G03 readiness diverged.'
Assert (@($results | Where-Object { $_.id -like 'real-*' -and $_.status -eq 'pass' }).Count -eq 2 -and
    $v3Status.closureStatus -ceq 'pre-ready' -and -not $v3Status.readyForClosure) 'Scoped V3/V4 clean verdict comparison failed.'

$reportRoot = Join-Path $outputRoot ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($reportRoot)
Write-Json (Join-Path $reportRoot 'summary.json') ([ordered]@{
    formatVersion = 1; status = 'pass'; scope = 'candidate-level-c2e'; publishedBaseVersion = '1.1.2'
    profileSha256 = $lock.profileSha256; v3 = [ordered]@{ result = $v3Report.result; closureStatus = $v3Status.closureStatus; blockerCodes = @($v3Status.blockers.code) }
    v4 = [ordered]@{ cleanClaimCount = 16; cleanModuleCount = 5; cases = @($results.ToArray()) }
    exclusions = @($lock.notAuthorized)
})
Write-Output "IFX C2e combined G03 passed $(@($fixtures.hostCases).Count) Host cases, four Profile rejection controls and fresh V3 Phase 9. Evidence: $reportRoot"
