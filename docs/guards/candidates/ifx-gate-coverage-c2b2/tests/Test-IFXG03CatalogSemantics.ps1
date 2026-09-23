[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c2b2/test-runs',
    [string] $BaseInstallRoot = '',
    [string] $BaseReceiptPath = '',
    [string] $BaseArchivePath = ''
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
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-g03-catalog-semantics'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'; $policyPath = Join-Path $moduleRoot 'policy.json'
$manifestPath = Join-Path $moduleRoot 'module.json'; $resultSchemaPath = Join-Path $moduleRoot 'result.schema.json'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 50
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json -Depth 50
$rulePlan = Get-Content (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 50
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) 'Module manifest schema failed.'
Assert ($manifest.id -ceq 'ifx-g03-catalog-semantics' -and ($manifest.stages -join ',') -ceq 'post' -and
    ($manifest.capabilities.readRoots -join ',') -ceq 'PackageRoot,TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and
    ($manifest.capabilities.processes -join ',') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false -and
    $manifest.capabilities.timeoutSeconds -eq 30) 'Module identity or capabilities drift.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256 -and
    (Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Adapter or dependency hash drift.'
foreach ($authority in $manifest.authorities) { Assert ((Hash (Join-Path $candidateRoot $authority.path)) -ceq $authority.sha256) "Authority hash drift: $($authority.id)." }
Assert ((Hash (Join-Path $repoRoot $policy.sourceScript.path)) -ceq $policy.sourceScript.sha256 -and
    (Hash (Join-Path $repoRoot $policy.catalogPath)) -ceq $policy.sourceCatalogSha256) 'V3 source/catalog hash drift.'
Assert ($rulePlan.moduleId -ceq $manifest.id -and $rulePlan.matrixSha256 -ceq (Hash $policyPath) -and
    @($rulePlan.rules).Count -eq 4 -and @($rulePlan.rules | Where-Object stage -eq 'post').Count -eq 4) 'Rule execution plan drift.'
$claimMatrix = Get-Content (Join-Path $repoRoot 'docs/guards/inventories/20260924-ifx-c2-g03-claim-matrix.json') -Raw | ConvertFrom-Json -Depth 100
$c2bCodes = @($claimMatrix.catalogErrorCodes | Where-Object destination -eq 'C2b' | ForEach-Object code | Sort-Object -Unique)
$b1Source = Get-Content (Join-Path $repoRoot 'docs/guards/candidates/ifx-gate-coverage-c2b1/modules/ifx-g03-governance-core/adapter.ps1') -Raw
$b2Source = Get-Content $adapterPath -Raw
$unmapped = @($c2bCodes | Where-Object { $_ -ne 'self-test' -and ($b1Source + $b2Source) -notmatch ("'" + [regex]::Escape($_) + "'") })
Assert ($c2bCodes.Count -eq 63 -and $unmapped.Count -eq 0) "C2b error-code mapping drift: $($unmapped -join ',')."
$claims = @('IFX.C2.G03_PROTOCOL_LIFECYCLE','IFX.C2.G03_FIELD_GOVERNANCE','IFX.C2.G03_LEGACY_SURFACE','IFX.C2.G03_CHANGE_CONTROL')
$baseConfig = [ordered]@{ enabledClaims = $claims; policySha256 = Hash $policyPath; catalogSha256 = Hash (Join-Path $repoRoot $policy.catalogPath) }
Assert (Test-Json -Json ($baseConfig | ConvertTo-Json -Depth 10 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction SilentlyContinue) 'Config schema failed.'
$evidence = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repoRoot $EvidenceRoot }
$runRoot = Join-Path $evidence ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)

function Invoke-Adapter([string] $Target, $Selection) {
    $payload = [ordered]@{
        formatVersion = 1; stage = 'post'; targetRoot = $Target; packageRoot = $candidateRoot
        stateRoot = Join-Path $runRoot 'state'; evidenceRoot = Join-Path $runRoot 'evidence'
        projectId = 'ifx'; relativeRoots = @('docs'); config = $Selection
    }
    $previous = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $payload | ConvertTo-Json -Depth 30 -Compress
        $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapterPath 2>&1)
        $exitCode = $LASTEXITCODE
    } finally { $env:V4_STAGE_INPUT_JSON = $previous }
    $raw = $output -join "`n"
    Assert ($exitCode -eq 0) "Adapter process failed: $raw"
    Assert (Test-Json -Json $raw -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) "Result schema failed: $raw"
    return ($raw | ConvertFrom-Json -Depth 50)
}
function Create-Case([string] $Id, [string] $Mutation) {
    $target = Join-Path $runRoot $Id
    $catalogPath = Join-Path $target $policy.catalogPath
    $source = Get-Content (Join-Path $repoRoot $policy.catalogPath) -Raw | ConvertFrom-Json -Depth 100
    switch ($Mutation) {
        'none' { }
        'zero-protocol' { $source.protocols = @() }
        'zero-surface' { $source.publicSurface = @() }
        'zero-change' { $source.changeRecords = @() }
        'zero-field' { $source.fieldSurfaces = @(); $source.sensitiveUsePolicies = @() }
        'missing-node' { $source.fieldGovernance = $null }
        'policy-node' { $source.sourcePolicy.identity = $null }
        'reviewer-policy' { $source.approvalPolicy.reviewers.New = @() }
        'approval-policy' { $source.approvalPolicy.externalConfirmation = '' }
        'identity-format' { $source.protocols[0].identity = 'Bad.Identity.v1' }
        'lifecycle' { $source.protocols[0].lifecycle = 'Invalid' }
        'active-admission' { $source.protocols[0].admissionEvidence.source = @() }
        'protocol-metadata' { $source.protocols[0].businessUse = '' }
        'protocol-evidence' { $source.protocols[0].tests = @() }
        'infrastructure-owner' { $source.infrastructureProtocols[0].provider = 'unknown' }
        'infrastructure-boundary' { $source.infrastructureProtocols[0].durable = $true }
        'infrastructure-field' { $source.infrastructureProtocols[0].fields[0].purpose = '' }
        'legacy-lifecycle' { $source.publicSurface[0].lifecycle = 'Invalid' }
        'legacy-retirement' { $source.publicSurface[0].migrationEvidence = '' }
        'legacy-disposition' { $source.publicSurface[0].disposition = 'Invalid' }
        'legacy-expiry' { $source.publicSurface[0].expiresAt = '2027-01-01' }
        'legacy-metadata' { $source.publicSurface[0].linkedPlan = '' }
        'replacement-target' { $source.publicSurface[0] | Add-Member -NotePropertyName member -NotePropertyValue 'Test' -Force; $source.publicSurface[0] | Add-Member -NotePropertyName targetIdentity -NotePropertyValue '' -Force }
        'legacy-protocol-reference' { $source.publicSurface[0] | Add-Member -NotePropertyName targetIdentity -NotePropertyValue 'unknown.v1' -Force }
        'duplicate-surface' { $source.publicSurface = @($source.publicSurface) + @($source.publicSurface[0]) }
        'classification-policy' { $source.fieldGovernance.classifications.C3 = '' }
        'c4-denylist' { $source.fieldGovernance.c4Denylist = @($source.fieldGovernance.c4Denylist | Where-Object { $_ -ne 'private key' }) }
        'secret-forbidden' { $source.protocols[0].fields[0].classification = 'C4' }
        'field-classification' { $source.protocols[0].fields[0].classification = 'X' }
        'field-metadata' { $source.protocols[0].fields[0].purpose = '' }
        'field-surface-missing' { $source.fieldSurfaces = @($source.fieldSurfaces | Where-Object id -ne $source.protocols[0].identity) }
        'field-surface-empty' { $source.protocols[0].fields = @() }
        'field-surface-metadata' { $source.fieldSurfaces[0].consumers = @() }
        'field-exception' { $source.protocols[0].fields[2].exceptionRef = '' }
        'field-exception-reference' { $source.fieldExceptions[0].fieldRefs = @('unknown/field') }
        'field-exception-metadata' { $source.fieldExceptions[0].approverRole = '' }
        'field-exception-approval' { $source.fieldExceptions[0].approvalEvidence = '' }
        'field-exception-expired' { $source.fieldExceptions[0].expiresAt = '2026-09-01' }
        'sensitive-use-metadata' { $source.sensitiveUsePolicies[0].encryption = '' }
        'sensitive-use-reference' { $source.sensitiveUsePolicies[0].fieldRefs = @('unknown/field') }
        'minimization-evidence' { $source.eventMinimizationReviews = @() }
        'change-record-metadata' { $source.changeRecords[0].summary = '' }
        'change-record-consumer' { $source.changeRecords[0].affectedConsumers = @() }
        'change-record-protocol' { $source.changeRecords[0].identity = 'unknown.v1' }
        'missing-catalog' { }
        'malformed-catalog' { }
        default { throw "Unknown mutation: $Mutation" }
    }
    if ($Mutation -ne 'missing-catalog') {
        if ($Mutation -eq 'malformed-catalog') { Write-Text $catalogPath '{' }
        else { Write-Json $catalogPath $source }
    } else { [void][IO.Directory]::CreateDirectory((Join-Path $target 'docs')) }
    $config = [ordered]@{ enabledClaims = $claims; policySha256 = Hash $policyPath; catalogSha256 = $baseConfig.catalogSha256 }
    if ([IO.File]::Exists($catalogPath)) { $config.catalogSha256 = Hash $catalogPath }
    return [pscustomobject]@{ target = $target; config = $config }
}

$fixtures = Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 30
Assert ($fixtures.formatVersion -eq 1 -and @($fixtures.cases).Count -eq 46) 'Fixture catalog drift.'
foreach ($case in $fixtures.cases) {
    $fixture = Create-Case $case.id $case.mutation
    $before = Inventory $fixture.target
    $result = Invoke-Adapter $fixture.target $fixture.config
    Assert ((Inventory $fixture.target) -ceq $before) "TargetRoot changed: $($case.id)."
    Assert ($result.status -ceq $case.status) "Fixture status mismatch $($case.id): $($result | ConvertTo-Json -Depth 10 -Compress)"
    if ($null -ne $case.PSObject.Properties['category']) { Assert ($result.exitCategory -ceq $case.category) "Fixture category mismatch: $($case.id)." }
    if ($null -ne $case.PSObject.Properties['code']) { Assert (@($result.findings | Where-Object { $_.subject -like "$($case.code):*" }).Count -gt 0) "Expected $($case.code): $($case.id)." }
    if ($case.id -in @('clean','zero-protocol','field-exception-expired')) {
        $repeat = Invoke-Adapter $fixture.target $fixture.config
        Assert (($repeat | ConvertTo-Json -Depth 50 -Compress) -ceq ($result | ConvertTo-Json -Depth 50 -Compress)) "Nondeterministic result: $($case.id)."
    }
}
$clean = Create-Case 'hash-drift' 'none'
$wrong = [ordered]@{ enabledClaims = $claims; policySha256 = Hash $policyPath; catalogSha256 = ('0' * 64) }
$drift = Invoke-Adapter $clean.target $wrong
Assert ($drift.status -ceq 'error' -and $drift.exitCategory -ceq 'integrity-failure') 'Catalog hash drift did not block.'
$wrong.policySha256 = '0' * 64
$policyDrift = Invoke-Adapter $clean.target $wrong
Assert ($policyDrift.status -ceq 'error' -and $policyDrift.exitCategory -ceq 'integrity-failure') 'Policy hash drift did not block.'
$linkedTarget = Join-Path $runRoot 'linked-catalog'
$linkParent = Join-Path $linkedTarget 'docs/architecture/review/gates'
[void][IO.Directory]::CreateDirectory($linkParent)
if ($IsWindows) { [void](New-Item -ItemType Junction -Path (Join-Path $linkParent 'G03') -Target (Join-Path $repoRoot 'docs/architecture/review/gates/G03')) }
else { [void](New-Item -ItemType SymbolicLink -Path (Join-Path $linkParent 'G03') -Target (Join-Path $repoRoot 'docs/architecture/review/gates/G03')) }
$unsafe = Invoke-Adapter $linkedTarget $baseConfig
Assert ($unsafe.status -ceq 'error' -and $unsafe.exitCategory -ceq 'unsafe-path') 'Linked catalog did not block.'
$beforeReal = Inventory (Join-Path $repoRoot 'docs/architecture/review/gates/G03')
$real = Invoke-Adapter $repoRoot $baseConfig
Assert ($real.status -ceq 'pass' -and @($real.coverage | Where-Object matched -eq 1).Count -eq 4 -and
    (Inventory (Join-Path $repoRoot 'docs/architecture/review/gates/G03')) -ceq $beforeReal) 'Real IFX scan failed or changed TargetRoot.'

$provided = @($BaseInstallRoot, $BaseReceiptPath, $BaseArchivePath | Where-Object { $_ })
Assert ($provided.Count -eq 0 -or $provided.Count -eq 3) 'Provide all three published-base paths or none.'
if ($provided.Count -eq 3) {
    $baseCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repoRoot 'docs/guards/candidates/ifx-gate-coverage-c1i/Test-PublishedV4Base.ps1') -ArchivePath $BaseArchivePath -ReceiptPath $BaseReceiptPath -InstallRoot $BaseInstallRoot | ConvertFrom-Json
    Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass') 'Published base identity check failed.'
    $hostFixture = Create-Case 'host-clean' 'none'
    $bundleRoot = Join-Path $runRoot 'bundle'; $bundlePackage = Join-Path $bundleRoot 'package'
    $bundleModuleRoot = Join-Path $bundlePackage 'modules/ifx-g03-catalog-semantics'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModuleRoot))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModuleRoot -Recurse
    $profileId = 'ifx_c2b2_fixture'; $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    Write-Json $profilePath ([ordered]@{
        formatVersion = 1; id = $profileId; version = '0.1.0'
        projectIdentity = [ordered]@{ id = 'ifx-c2b2-fixture'; relativeRoots = @('docs') }
        moduleSelections = @([ordered]@{ id = 'ifx-g03-catalog-semantics'; versionRange = '>=0.1.0 <1.0.0'; config = $hostFixture.config })
        stageConfiguration = [ordered]@{
            bootstrap = [ordered]@{ enabled = $false; modules = @() }
            analysis = [ordered]@{ enabled = $false; modules = @() }
            pre = [ordered]@{ enabled = $false; modules = @() }
            post = [ordered]@{ enabled = $true; modules = @('ifx-g03-catalog-semantics') }
        }
        rules = @('G03-PROTOCOL-LIFECYCLE','G03-FIELD-GOVERNANCE','G03-LEGACY-SURFACE','G03-CHANGE-CONTROL'); baselineRefs = @()
    })
    $bundleFiles = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\','/'); sha256 = Hash $_.FullName; size = $_.Length }
    })
    $ceiling = [ordered]@{ readRoots = @('PackageRoot','TargetRoot'); writeRoots = @(); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 30 }
    $bundleManifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $bundleManifestPath ([ordered]@{
        formatVersion = 1; id = 'ifx-c2b2-synthetic-extension'; version = '0.1.0'; compatibleApi = '1.x'; baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = 'ifx-g03-catalog-semantics'; version = '0.1.0'; manifestPath = 'modules/ifx-g03-catalog-semantics/module.json'; manifestSha256 = Hash (Join-Path $bundleModuleRoot 'module.json'); allowedCapabilities = $ceiling })
        files = $bundleFiles
    })
    $reviewPath = Join-Path $runRoot 'synthetic-review.json'
    Write-Json $reviewPath ([ordered]@{
        formatVersion = 1; id = '20260924-ifx-c2b2-synthetic-fixture'; scope = 'synthetic-test-only'; decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-c2b2-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $bundleManifestPath; baseArchiveSha256 = $baseCheck.archiveSha256
        moduleCeilings = @([ordered]@{ moduleId = 'ifx-g03-catalog-semantics'; allowedCapabilities = $ceiling })
    })
    $composed = Join-Path $runRoot 'composed'; $compositionReceipt = Join-Path $runRoot 'composition.receipt.json'
    $composeState = Join-Path $runRoot 'state'; $composeEvidence = Join-Path $runRoot 'evidence'
    [void][IO.Directory]::CreateDirectory($composeState); [void][IO.Directory]::CreateDirectory($composeEvidence)
    $composeOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot $hostFixture.target -StateRoot $composeState -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($composeOutput -join "`n")"
    $verifyOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $compositionReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (($verifyOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Composition receipt failed: $($verifyOutput -join "`n")"
    $state = Join-Path $runRoot 'host-state'; $hostEvidence = Join-Path $runRoot 'host-evidence'
    [void][IO.Directory]::CreateDirectory($state); [void][IO.Directory]::CreateDirectory($hostEvidence)
    $beforeHost = Inventory $hostFixture.target
    $hostOutput = @(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $hostFixture.target --state-root $state --evidence-root $hostEvidence --profile $profileId 2>&1)
    $hostResult = ($hostOutput -join "`n") | ConvertFrom-Json -Depth 50
    Assert ($hostResult.status -ceq 'pass' -and $hostResult.exitCategory -ceq 'success' -and
        @($hostResult.coverage | Where-Object matched -eq 1).Count -eq 4 -and
        (Inventory $hostFixture.target) -ceq $beforeHost) "Host Post mismatch: $($hostOutput -join "`n")"
}
Write-Output "IFX C2b2 passed $(@($fixtures.cases).Count) fixtures and controls; real G03 catalog semantics passed. Evidence: $runRoot"
