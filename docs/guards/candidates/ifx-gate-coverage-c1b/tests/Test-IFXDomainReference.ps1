[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c1b/test-runs',
    [string] $BaseInstallRoot = '',
    [string] $BaseReceiptPath = '',
    [string] $BaseArchivePath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}
function Hash([string] $Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 80).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
function Inventory([string] $Root) {
    @(
        Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName |
            ForEach-Object { "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/'))|$(Hash $_.FullName)" }
    ) -join "`n"
}

$candidateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-domain-reference'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'
$manifestPath = Join-Path $moduleRoot 'module.json'
$configSchemaPath = Join-Path $moduleRoot 'config.schema.json'
$resultSchemaPath = Join-Path $moduleRoot 'result.schema.json'
$policyPath = Join-Path $moduleRoot 'policy.json'
$rulePlanPath = Join-Path $moduleRoot 'rule-execution-plan.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 30
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 30
$rulePlan = Get-Content -LiteralPath $rulePlanPath -Raw | ConvertFrom-Json -Depth 30
$manifestSchema = Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json'
Assert (Test-Json -Json (Get-Content -LiteralPath $manifestPath -Raw) -SchemaFile $manifestSchema -ErrorAction SilentlyContinue) 'Module manifest fails published V4 schema.'
Assert ($manifest.id -ceq 'ifx-domain-reference' -and @($manifest.stages) -join ',' -ceq 'pre') 'Module identity/Stage drift.'
Assert ($manifest.capabilities.readRoots -join ',' -ceq 'PackageRoot,TargetRoot' -and
    @($manifest.capabilities.writeRoots).Count -eq 0 -and
    $manifest.capabilities.processes -join ',' -ceq 'pwsh' -and
    $manifest.capabilities.network -eq $false -and $manifest.capabilities.timeoutSeconds -eq 30) 'Module exceeds read-only capability ceiling.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256) 'Adapter hash drift.'
Assert ((Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Dependency lock hash drift.'
foreach ($authority in $manifest.authorities) {
    $path = Join-Path $candidateRoot $authority.path
    Assert ((Hash $path) -ceq $authority.sha256) "Authority hash drift: $($authority.id)."
}
Assert ((Hash (Join-Path $repoRoot $policy.sourcePolicy.path)) -ceq $policy.sourcePolicy.sha256) 'V3 IFX policy source drift.'
Assert ((Hash (Join-Path $repoRoot $policy.sourceRule.path)) -ceq $policy.sourceRule.sha256) 'V3 L2.2 source rule drift.'
Assert ($rulePlan.moduleId -ceq $manifest.id -and $rulePlan.matrixSha256 -ceq (Hash $policyPath) -and
    @($rulePlan.rules).Count -eq 1 -and $rulePlan.rules[0].ruleId -ceq 'RING-DIRECTION' -and
    $rulePlan.rules[0].claimId -ceq $policy.claimId -and $rulePlan.rules[0].minimumMatches -eq 1) 'Rule execution plan drift.'

$config = [ordered]@{ enabledClaims = @($policy.claimId); policySha256 = Hash $policyPath }
Assert (Test-Json -Json ($config | ConvertTo-Json -Depth 10 -Compress) -SchemaFile $configSchemaPath -ErrorAction SilentlyContinue) 'Candidate Profile config fails schema.'
$absoluteEvidenceRoot = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repoRoot $EvidenceRoot }
$runRoot = Join-Path $absoluteEvidenceRoot ([Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)

function Invoke-Adapter([string] $TargetRoot, $Config) {
    $payload = [ordered]@{
        formatVersion = 1
        stage = 'pre'
        targetRoot = $TargetRoot
        packageRoot = $candidateRoot
        stateRoot = Join-Path $runRoot 'state'
        evidenceRoot = Join-Path $runRoot 'evidence'
        projectId = 'ifx'
        relativeRoots = @('src', 'tests')
        config = $Config
    }
    $previous = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $payload | ConvertTo-Json -Depth 30 -Compress
        $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapterPath 2>&1)
        $exitCode = $LASTEXITCODE
    } finally { $env:V4_STAGE_INPUT_JSON = $previous }
    Assert ($exitCode -eq 0) "Adapter process failed: $($output -join "`n")"
    $raw = $output -join "`n"
    Assert (Test-Json -Json $raw -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) "Adapter result fails schema: $raw"
    $raw | ConvertFrom-Json -Depth 30
}

$fixturesRoot = Join-Path $candidateRoot 'fixtures'
$fixtureIds = @('clean', 'forbidden-reference', 'missing-root', 'zero-domain', 'unsafe-reference')
foreach ($id in $fixtureIds) {
    $fixture = Get-Content -LiteralPath (Join-Path $fixturesRoot "$id/fixture.json") -Raw | ConvertFrom-Json -Depth 20
    Assert ($fixture.formatVersion -eq 1 -and $fixture.id -ceq $id) "Fixture identity drift: $id"
    $target = Join-Path $runRoot $id
    [void][IO.Directory]::CreateDirectory($target)
    foreach ($file in $fixture.files) {
        $path = [IO.Path]::GetFullPath((Join-Path $target $file.path))
        Assert ([IO.Path]::GetRelativePath($target, $path) -notmatch '^\.\.') "Unsafe fixture path: $id"
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
        [IO.File]::WriteAllText($path, [string]$file.content, [Text.UTF8Encoding]::new($false))
    }
    $before = Inventory $target
    $result = Invoke-Adapter $target $config
    $after = Inventory $target
    Assert ($before -ceq $after) "TargetRoot bytes changed: $id"
    Assert ($result.status -ceq $fixture.expectedStatus) "Status mismatch: $id -> $($result.status)"
    Assert ($result.exitCategory -ceq $fixture.expectedExitCategory) "Exit category mismatch: $id"
    Assert (@($result.coverage).Count -eq 1 -and $result.coverage[0].claimId -ceq $policy.claimId -and
        $result.coverage[0].matched -eq $fixture.expectedMatches -and $result.coverage[0].minimum -eq 1) "Coverage mismatch: $id"
    Assert (@($result.findings).Count -eq $fixture.expectedFindingCount) "Finding count mismatch: $id"
    foreach ($finding in $result.findings) {
        Assert ($finding.ruleId -ceq 'RING-DIRECTION' -and $finding.detectorId -ceq 'ifx-domain-reference' -and
            $finding.severity -ceq 'blocking') "Finding identity mismatch: $id"
    }
    if ($id -eq 'forbidden-reference') {
        $subjects = @($result.findings | ForEach-Object subject)
        Assert (($subjects -join "`n") -ceq (@($subjects | Sort-Object) -join "`n")) 'Finding order is not deterministic.'
        Assert ($result.findings[0].evidenceKind -ceq 'project-model-raw' -and
            $result.findings[0].subject -ceq 'src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj -> src/Modules/CRM/IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj') 'Direct-reference subject drift.'
    }
}

$cleanTarget = Join-Path $runRoot 'clean'
$driftedConfig = [ordered]@{ enabledClaims = @($policy.claimId); policySha256 = ('0' * 64) }
$drifted = Invoke-Adapter $cleanTarget $driftedConfig
Assert ($drifted.status -ceq 'error' -and $drifted.exitCategory -ceq 'integrity-failure') 'Policy hash drift did not fail closed.'

$providedBasePaths = @($BaseInstallRoot, $BaseReceiptPath, $BaseArchivePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
Assert ($providedBasePaths.Count -eq 0 -or $providedBasePaths.Count -eq 3) 'Provide all three published-base paths or none.'
if ($providedBasePaths.Count -eq 3) {
    $baseReceipt = Get-Content -LiteralPath $BaseReceiptPath -Raw | ConvertFrom-Json -Depth 40
    Assert ($baseReceipt.status -ceq 'installed' -and $baseReceipt.version -ceq '1.1.2' -and
        $baseReceipt.archiveSha256 -ceq '12270a26f923a86f49be4ee0d003f5493b2562891fd1484a4fac079f02b73c95' -and
        (Hash $BaseArchivePath) -ceq $baseReceipt.archiveSha256) 'Published base receipt/archive identity drift.'
    $basePackageCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package') | ConvertFrom-Json
    Assert ($LASTEXITCODE -eq 0 -and $basePackageCheck.status -ceq 'pass' -and
        $basePackageCheck.packageHash -ceq '922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d') 'Published base Package hash drift.'

    $bundleRoot = Join-Path $runRoot 'bundle'
    $bundlePackage = Join-Path $bundleRoot 'package'
    $bundleModuleRoot = Join-Path $bundlePackage 'modules/ifx-domain-reference'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModuleRoot))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModuleRoot -Recurse
    $profileId = 'ifx_c1b_fixture'
    $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    $profile = [ordered]@{
        formatVersion = 1
        id = $profileId
        version = '0.1.0'
        projectIdentity = [ordered]@{ id = 'ifx-c1b-fixture'; relativeRoots = @('src') }
        moduleSelections = @([ordered]@{ id = 'ifx-domain-reference'; versionRange = '>=0.1.0 <1.0.0'; config = $config })
        stageConfiguration = [ordered]@{
            bootstrap = [ordered]@{ enabled = $false; modules = @() }
            analysis = [ordered]@{ enabled = $false; modules = @() }
            pre = [ordered]@{ enabled = $true; modules = @('ifx-domain-reference') }
            post = [ordered]@{ enabled = $false; modules = @() }
        }
        rules = @('RING-DIRECTION')
        baselineRefs = @()
    }
    Write-Json $profilePath $profile
    $bundleFiles = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\', '/')
            sha256 = Hash $_.FullName
            size = $_.Length
        }
    })
    $capabilities = [ordered]@{ readRoots = @('PackageRoot', 'TargetRoot'); writeRoots = @(); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 30 }
    $bundleManifest = [ordered]@{
        formatVersion = 1
        id = 'ifx-c1b-synthetic-extension'
        version = '0.1.0'
        compatibleApi = '1.x'
        baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = 'ifx-domain-reference'; version = '0.1.0'; manifestPath = 'modules/ifx-domain-reference/module.json'; manifestSha256 = Hash (Join-Path $bundleModuleRoot 'module.json'); allowedCapabilities = $capabilities })
        files = $bundleFiles
    }
    $bundleManifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $bundleManifestPath $bundleManifest
    $reviewPath = Join-Path $runRoot 'synthetic-review.json'
    $review = [ordered]@{
        formatVersion = 1
        id = '20260923-ifx-c1b-synthetic-fixture'
        scope = 'synthetic-test-only'
        decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-c1b-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $bundleManifestPath
        baseArchiveSha256 = $baseReceipt.archiveSha256
        moduleCeilings = @([ordered]@{ moduleId = 'ifx-domain-reference'; allowedCapabilities = $capabilities })
    }
    Write-Json $reviewPath $review
    $composed = Join-Path $runRoot 'composed'
    $compositionReceiptPath = Join-Path $runRoot 'composition.receipt.json'
    $composer = Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1'
    $verifier = Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1'
    $stateRoot = Join-Path $runRoot 'host-state-clean'
    $evidenceRoot = Join-Path $runRoot 'host-evidence-clean'
    foreach ($path in @($stateRoot, $evidenceRoot)) { [void][IO.Directory]::CreateDirectory($path) }
    $composeOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $composer -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceiptPath -TargetRoot $cleanTarget -StateRoot $stateRoot -EvidenceRoot $evidenceRoot -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($composeOutput -join "`n")"
    $composedResult = ($composeOutput -join "`n") | ConvertFrom-Json -Depth 30
    Assert ($composedResult.status -ceq 'pass') 'Synthetic composition did not pass.'
    $verifyOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $verifier -InstallRoot $composed -ReceiptPath $compositionReceiptPath -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (($verifyOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Synthetic composition receipt verification failed: $($verifyOutput -join "`n")"
    $hostDll = Join-Path $composed 'host/v4-guards.dll'
    foreach ($case in @(
        [ordered]@{ id = 'clean'; expectedCategory = 'success'; expectedStatus = 'pass'; expectedMatched = 2 },
        [ordered]@{ id = 'forbidden-reference'; expectedCategory = 'findings-blocking'; expectedStatus = 'fail'; expectedMatched = 1 },
        [ordered]@{ id = 'zero-domain'; expectedCategory = 'findings-blocking'; expectedStatus = 'fail'; expectedMatched = 0 }
    )) {
        $target = Join-Path $runRoot $case.id
        $state = Join-Path $runRoot "host-state-$($case.id)"
        $evidence = Join-Path $runRoot "host-evidence-$($case.id)"
        foreach ($path in @($state, $evidence)) { [void][IO.Directory]::CreateDirectory($path) }
        $before = Inventory $target
        $hostOutput = @(& dotnet $hostDll stage run --stage pre --package-root (Join-Path $composed 'package') --target-root $target --state-root $state --evidence-root $evidence --profile $profileId 2>&1)
        $hostExitCode = $LASTEXITCODE
        $raw = $hostOutput -join "`n"
        $hostResult = $raw | ConvertFrom-Json -Depth 30
        Assert ($hostResult.status -ceq $case.expectedStatus -and $hostResult.exitCategory -ceq $case.expectedCategory) "Synthetic Host result mismatch: $($case.id), exit $hostExitCode, $raw"
        Assert ($hostResult.coverage[0].claimId -ceq $policy.claimId -and $hostResult.coverage[0].matched -eq $case.expectedMatched) "Synthetic Host coverage mismatch: $($case.id)"
        Assert ((Inventory $target) -ceq $before) "Synthetic Host changed TargetRoot: $($case.id)"
    }
    Write-Output "Published-base synthetic composition and Host Pre clean/violation/zero-domain cases passed. Composition receipt: $compositionReceiptPath"
}
Write-Output "IFX C1b direct-domain-reference candidate passed five fixtures, hash drift, V4 schema/authority checks and target immutability. Evidence root: $runRoot"
