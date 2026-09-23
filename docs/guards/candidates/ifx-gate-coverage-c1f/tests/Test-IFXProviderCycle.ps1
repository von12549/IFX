[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c1f/test-runs',
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
function Inventory([string] $Root) {
    @(
        Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName |
            ForEach-Object { "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/'))|$(Hash $_.FullName)" }
    ) -join "`n"
}
function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 80).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}

$candidateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-provider-cycle'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'
$policyPath = Join-Path $moduleRoot 'policy.json'
$manifestPath = Join-Path $moduleRoot 'module.json'
$configSchemaPath = Join-Path $moduleRoot 'config.schema.json'
$resultSchemaPath = Join-Path $moduleRoot 'result.schema.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 30
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 30
$g03 = Get-Content -LiteralPath (Join-Path $repoRoot $policy.sourceG03.path) -Raw | ConvertFrom-Json -Depth 40
$rulePlan = Get-Content -LiteralPath (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 30

Assert (Test-Json -Json (Get-Content -LiteralPath $manifestPath -Raw) -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) 'V4 module schema failed.'
Assert ($manifest.id -ceq 'ifx-provider-cycle' -and @($manifest.stages) -join ',' -ceq 'pre') 'Module identity/Stage drift.'
Assert ($manifest.capabilities.readRoots -join ',' -ceq 'PackageRoot' -and
    @($manifest.capabilities.writeRoots).Count -eq 0 -and
    $manifest.capabilities.processes -join ',' -ceq 'pwsh' -and
    $manifest.capabilities.network -eq $false -and $manifest.capabilities.timeoutSeconds -eq 30) 'Capability ceiling drift.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256) 'Adapter hash drift.'
Assert ((Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Dependency lock hash drift.'
foreach ($authority in $manifest.authorities) {
    Assert ((Hash (Join-Path $candidateRoot $authority.path)) -ceq $authority.sha256) "Authority hash drift: $($authority.id)."
}
foreach ($record in @($policy.sourcePolicy, $policy.sourceG03, $policy.sourceRule)) {
    Assert ((Hash (Join-Path $repoRoot $record.path)) -ceq $record.sha256) "V3 authority hash drift: $($record.path)."
}
Assert (($policy.providerContracts | ConvertTo-Json -Depth 20 -Compress) -ceq
    ($g03.providerContracts | ConvertTo-Json -Depth 20 -Compress)) 'Provider graph projection differs from G03.'
Assert ($rulePlan.moduleId -ceq $manifest.id -and $rulePlan.matrixSha256 -ceq (Hash $policyPath) -and
    @($rulePlan.rules).Count -eq 1 -and $rulePlan.rules[0].ruleId -ceq 'PROVIDER-CYCLE' -and
    $rulePlan.rules[0].claimId -ceq $policy.claimId) 'Rule execution plan drift.'
$config = [ordered]@{ enabledClaims = @($policy.claimId); policySha256 = Hash $policyPath }
Assert (Test-Json -Json ($config | ConvertTo-Json -Depth 20 -Compress) -SchemaFile $configSchemaPath -ErrorAction SilentlyContinue) 'Config schema failed.'
$absoluteEvidenceRoot = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repoRoot $EvidenceRoot }
$runRoot = Join-Path $absoluteEvidenceRoot ([Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)
$targetRoot = Join-Path $runRoot 'target'
[void][IO.Directory]::CreateDirectory($targetRoot)
[IO.File]::WriteAllText((Join-Path $targetRoot 'unchanged.txt'), 'target bytes must remain unchanged', [Text.UTF8Encoding]::new($false))

function Invoke-Adapter([string] $ScriptPath, $Config) {
    $payload = [ordered]@{
        formatVersion = 1
        stage = 'pre'
        targetRoot = $targetRoot
        packageRoot = $candidateRoot
        stateRoot = Join-Path $runRoot 'state'
        evidenceRoot = Join-Path $runRoot 'evidence'
        projectId = 'ifx'
        relativeRoots = @('src')
        config = $Config
    }
    $previous = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $payload | ConvertTo-Json -Depth 30 -Compress
        $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $ScriptPath 2>&1)
        $exitCode = $LASTEXITCODE
    } finally { $env:V4_STAGE_INPUT_JSON = $previous }
    Assert ($exitCode -eq 0) "Adapter process failed: $($output -join "`n")"
    $raw = $output -join "`n"
    Assert (Test-Json -Json $raw -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) "Result schema failed: $raw"
    $raw | ConvertFrom-Json -Depth 30
}

$fixtures = Get-Content -LiteralPath (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 30
Assert ($fixtures.formatVersion -eq 1 -and @($fixtures.cases).Count -eq 11) 'Fixture identity drift.'
$before = Inventory $targetRoot
foreach ($case in $fixtures.cases) {
    $caseRoot = Join-Path $runRoot "cases/$($case.id)"
    [void][IO.Directory]::CreateDirectory($caseRoot)
    $caseAdapter = Join-Path $caseRoot 'adapter.ps1'
    Copy-Item -LiteralPath $adapterPath -Destination $caseAdapter
    $casePolicyPath = Join-Path $caseRoot 'policy.json'
    if ($case.PSObject.Properties.Name -notcontains 'omitPolicy') {
        $casePolicy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 30
        if ($case.PSObject.Properties.Name -contains 'graph') { $casePolicy.providerContracts = $case.graph }
        if ($case.PSObject.Properties.Name -contains 'addEdges') {
            foreach ($edge in $case.addEdges) {
                $current = @($casePolicy.providerContracts.PSObject.Properties[$edge.consumer].Value)
                $casePolicy.providerContracts.PSObject.Properties[$edge.consumer].Value = @($current + @([string]$edge.provider))
            }
        }
        if ($case.PSObject.Properties.Name -contains 'sourceG03Path') { $casePolicy.sourceG03.path = [string]$case.sourceG03Path }
        if ($case.PSObject.Properties.Name -contains 'rawPolicy') {
            [IO.File]::WriteAllText($casePolicyPath, [string]$case.rawPolicy, [Text.UTF8Encoding]::new($false))
        } else { Write-Json $casePolicyPath $casePolicy }
    }
    $caseHash = if ([IO.File]::Exists($casePolicyPath)) { Hash $casePolicyPath } else { $config.policySha256 }
    if ($case.PSObject.Properties.Name -contains 'badConfigHash') { $caseHash = '0' * 64 }
    $result = Invoke-Adapter $caseAdapter ([ordered]@{ enabledClaims = @($policy.claimId); policySha256 = $caseHash })
    Assert ($result.status -ceq $case.expectedStatus -and $result.exitCategory -ceq $case.expectedCategory) "Status/category mismatch: $($case.id): $($result | ConvertTo-Json -Depth 10 -Compress)"
    Assert ($result.coverage[0].matched -eq $case.expectedMatches -and $result.coverage[0].claimId -ceq $policy.claimId) "Coverage mismatch: $($case.id)."
    $subjects = @($result.findings | ForEach-Object subject)
    Assert (($subjects -join "`n") -ceq ($case.expectedSubjects -join "`n")) "Cycle subjects mismatch: $($case.id): $($subjects -join ', ')."
    foreach ($finding in $result.findings) {
        Assert ($finding.ruleId -ceq 'PROVIDER-CYCLE' -and $finding.detectorId -ceq 'ifx-provider-cycle' -and
            $finding.severity -ceq 'blocking') "Finding identity mismatch: $($case.id)."
    }
    Assert ((Inventory $targetRoot) -ceq $before) "TargetRoot bytes changed: $($case.id)."
}
$realResult = Invoke-Adapter $adapterPath $config
Assert ($realResult.status -ceq 'pass' -and $realResult.exitCategory -ceq 'success' -and
    $realResult.coverage[0].matched -eq 10 -and @($realResult.findings).Count -eq 0) 'Frozen G03 provider graph did not pass.'

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
    $bundleModuleRoot = Join-Path $bundlePackage 'modules/ifx-provider-cycle'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModuleRoot))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModuleRoot -Recurse
    $profileId = 'ifx_c1f_fixture'
    $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    $profile = [ordered]@{
        formatVersion = 1
        id = $profileId
        version = '0.1.0'
        projectIdentity = [ordered]@{ id = 'ifx-c1f-fixture'; relativeRoots = @('src') }
        moduleSelections = @([ordered]@{ id = 'ifx-provider-cycle'; versionRange = '>=0.1.0 <1.0.0'; config = $config })
        stageConfiguration = [ordered]@{
            bootstrap = [ordered]@{ enabled = $false; modules = @() }
            analysis = [ordered]@{ enabled = $false; modules = @() }
            pre = [ordered]@{ enabled = $true; modules = @('ifx-provider-cycle') }
            post = [ordered]@{ enabled = $false; modules = @() }
        }
        rules = @('PROVIDER-CYCLE')
        baselineRefs = @()
    }
    Write-Json $profilePath $profile
    $bundleFiles = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\', '/'); sha256 = Hash $_.FullName; size = $_.Length }
    })
    $capabilities = [ordered]@{ readRoots = @('PackageRoot'); writeRoots = @(); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 30 }
    $bundleManifest = [ordered]@{
        formatVersion = 1
        id = 'ifx-c1f-synthetic-extension'
        version = '0.1.0'
        compatibleApi = '1.x'
        baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = 'ifx-provider-cycle'; version = '0.1.0'; manifestPath = 'modules/ifx-provider-cycle/module.json'; manifestSha256 = Hash (Join-Path $bundleModuleRoot 'module.json'); allowedCapabilities = $capabilities })
        files = $bundleFiles
    }
    $bundleManifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $bundleManifestPath $bundleManifest
    $reviewPath = Join-Path $runRoot 'synthetic-review.json'
    $review = [ordered]@{
        formatVersion = 1
        id = '20260923-ifx-c1f-synthetic-fixture'
        scope = 'synthetic-test-only'
        decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-c1f-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $bundleManifestPath
        baseArchiveSha256 = $baseReceipt.archiveSha256
        moduleCeilings = @([ordered]@{ moduleId = 'ifx-provider-cycle'; allowedCapabilities = $capabilities })
    }
    Write-Json $reviewPath $review
    $composed = Join-Path $runRoot 'composed'
    $compositionReceiptPath = Join-Path $runRoot 'composition.receipt.json'
    $composer = Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1'
    $verifier = Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1'
    $stateRoot = Join-Path $runRoot 'host-state'
    $evidenceRoot = Join-Path $runRoot 'host-evidence'
    foreach ($path in @($stateRoot, $evidenceRoot)) { [void][IO.Directory]::CreateDirectory($path) }
    $composeOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $composer -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceiptPath -TargetRoot $targetRoot -StateRoot $stateRoot -EvidenceRoot $evidenceRoot -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($composeOutput -join "`n")"
    Assert ((($composeOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') 'Synthetic composition did not pass.'
    $verifyOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $verifier -InstallRoot $composed -ReceiptPath $compositionReceiptPath -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (($verifyOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Synthetic receipt verification failed: $($verifyOutput -join "`n")"
    $hostDll = Join-Path $composed 'host/v4-guards.dll'
    $hostOutput = @(& dotnet $hostDll stage run --stage pre --package-root (Join-Path $composed 'package') --target-root $targetRoot --state-root $stateRoot --evidence-root $evidenceRoot --profile $profileId 2>&1)
    $hostExitCode = $LASTEXITCODE
    $raw = $hostOutput -join "`n"
    $hostResult = $raw | ConvertFrom-Json -Depth 30
    Assert ($hostResult.status -ceq 'pass' -and $hostResult.exitCategory -ceq 'success' -and
        $hostResult.coverage[0].matched -eq 10) "Synthetic Host result mismatch: exit $hostExitCode, $raw"
    Assert ((Inventory $targetRoot) -ceq $before) 'Synthetic Host changed TargetRoot.'
    Write-Output "Published-base synthetic composition and Host Pre passed. Composition receipt: $compositionReceiptPath"
}
Write-Output "IFX C1f provider-cycle candidate passed eleven fixtures and frozen G03 graph. Evidence root: $runRoot"
