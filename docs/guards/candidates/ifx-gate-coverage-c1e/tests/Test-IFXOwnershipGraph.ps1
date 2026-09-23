[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c1e/test-runs',
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
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-ownership-graph'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'
$policyPath = Join-Path $moduleRoot 'policy.json'
$manifestPath = Join-Path $moduleRoot 'module.json'
$resultSchemaPath = Join-Path $moduleRoot 'result.schema.json'
$configSchemaPath = Join-Path $moduleRoot 'config.schema.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -Depth 30
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 40
$rulePlan = Get-Content -LiteralPath (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 30
$source = Get-Content -LiteralPath (Join-Path $repoRoot $policy.sourcePolicy.path) -Raw | ConvertFrom-Json -Depth 40
$g03 = Get-Content -LiteralPath (Join-Path $repoRoot $policy.sourceG03.path) -Raw | ConvertFrom-Json -Depth 40

Assert (Test-Json -Json (Get-Content -LiteralPath $manifestPath -Raw) -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) 'V4 module schema failed.'
Assert ($manifest.id -ceq 'ifx-ownership-graph' -and @($manifest.stages) -join ',' -ceq 'pre') 'Module identity/Stage drift.'
Assert ($manifest.capabilities.readRoots -join ',' -ceq 'PackageRoot,TargetRoot' -and
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
foreach ($field in @('rings', 'allowedDependencies', 'ownership', 'referenceScopes', 'transitiveBoundaryRoles')) {
    Assert (($policy.$field | ConvertTo-Json -Depth 40 -Compress) -ceq
        ($source.$field | ConvertTo-Json -Depth 40 -Compress)) "Frozen $field projection differs from V3 policy."
}
Assert (($policy.sharedPrimitiveProjects | ConvertTo-Json -Depth 20 -Compress) -ceq
    ($g03.sharedPrimitiveProjects | ConvertTo-Json -Depth 20 -Compress)) 'Shared primitive projection differs from G03.'
Assert ($rulePlan.moduleId -ceq $manifest.id -and $rulePlan.matrixSha256 -ceq (Hash $policyPath) -and
    @($rulePlan.rules).Count -eq 1 -and $rulePlan.rules[0].ruleId -ceq 'OWNERSHIP-REFERENCE' -and
    $rulePlan.rules[0].claimId -ceq $policy.claimId) 'Rule execution plan drift.'
$config = [ordered]@{ enabledClaims = @($policy.claimId); policySha256 = Hash $policyPath }
Assert (Test-Json -Json ($config | ConvertTo-Json -Depth 20 -Compress) -SchemaFile $configSchemaPath -ErrorAction SilentlyContinue) 'Config schema failed.'
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
    Assert (Test-Json -Json $raw -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) "Result schema failed: $raw"
    $raw | ConvertFrom-Json -Depth 30
}

$fixtures = Get-Content -LiteralPath (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 30
Assert ($fixtures.formatVersion -eq 1 -and @($fixtures.cases).Count -eq 19) 'Fixture identity drift.'
foreach ($case in $fixtures.cases) {
    $target = Join-Path $runRoot $case.id
    [void][IO.Directory]::CreateDirectory($target)
    $available = @($fixtures.baseProjects | Where-Object { @($case.omit) -notcontains $_.id })
    foreach ($project in $available) {
        $path = [IO.Path]::GetFullPath((Join-Path $target $project.path))
        Assert ([IO.Path]::GetRelativePath($target, $path) -notmatch '^\.\.') 'Fixture path escapes target.'
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $path))
        $references = [Collections.Generic.List[string]]::new()
        foreach ($edge in @($case.edges | Where-Object from -eq $project.id)) {
            $include = if ($edge.PSObject.Properties.Name -contains 'literalInclude') {
                [string]$edge.literalInclude
            } else {
                $targetProject = @($fixtures.baseProjects | Where-Object id -eq $edge.to)
                Assert ($targetProject.Count -eq 1) "Unknown fixture edge target: $($edge.to)."
                [IO.Path]::GetRelativePath((Split-Path -Parent $path), (Join-Path $target $targetProject[0].path))
            }
            $private = if ($edge.PSObject.Properties.Name -contains 'privateAssets') { [string]$edge.privateAssets } else { '' }
            $form = if ($edge.PSObject.Properties.Name -contains 'privateAssetsForm') { [string]$edge.privateAssetsForm } else { '' }
            if ($form -ceq 'attribute') {
                $references.Add("<ProjectReference Include=`"$include`" PrivateAssets=`"$private`" />")
            } elseif ($form -ceq 'child') {
                $references.Add("<ProjectReference Include=`"$include`"><PrivateAssets>$private</PrivateAssets></ProjectReference>")
            } else {
                $references.Add("<ProjectReference Include=`"$include`" />")
            }
        }
        $disabled = if ($case.PSObject.Properties.Name -contains 'disableTransitive' -and
            @($case.disableTransitive) -contains $project.id) {
            '<PropertyGroup><DisableTransitiveProjectReferences>true</DisableTransitiveProjectReferences></PropertyGroup>'
        } else { '' }
        $content = if ($case.PSObject.Properties.Name -contains 'invalidXml' -and $case.invalidXml -ceq $project.id) {
            '<Project><ItemGroup>'
        } else {
            "<Project>$disabled<ItemGroup>$($references -join '')</ItemGroup></Project>"
        }
        [IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new($false))
    }
    if ($case.id -ceq 'clean-own') {
        $poison = Join-Path $target 'guard/IFX.Modules.CRM.Application/IFX.Modules.CRM.Application.csproj'
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $poison))
        [IO.File]::WriteAllText($poison, '<Project><ItemGroup>', [Text.UTF8Encoding]::new($false))
    }
    $before = Inventory $target
    $result = Invoke-Adapter $target $config
    $after = Inventory $target
    Assert ($before -ceq $after) "TargetRoot bytes changed: $($case.id)."
    Assert ($result.status -ceq $case.expectedStatus -and $result.exitCategory -ceq $case.expectedCategory) "Status/category mismatch: $($case.id): $($result | ConvertTo-Json -Depth 10 -Compress)"
    Assert ($result.coverage[0].matched -eq $case.expectedMatches -and
        $result.coverage[0].claimId -ceq $policy.claimId) "Coverage mismatch: $($case.id)."
    Assert (@($result.findings).Count -eq $case.expectedFindings) "Finding count mismatch: $($case.id): $($result | ConvertTo-Json -Depth 10 -Compress)"
    foreach ($finding in $result.findings) {
        Assert ($finding.ruleId -ceq 'OWNERSHIP-REFERENCE' -and $finding.detectorId -ceq 'ifx-ownership-graph' -and
            $finding.severity -ceq 'blocking') "Finding identity mismatch: $($case.id)."
    }
    $subjects = @($result.findings | ForEach-Object subject)
    Assert (($subjects -join "`n") -ceq (@($subjects | Sort-Object -CaseSensitive) -join "`n")) "Finding order drift: $($case.id)."
    if ($case.PSObject.Properties.Name -contains 'expectedKind') {
        Assert (([string]$result.findings[0].subject).Contains("[$($case.expectedKind):")) "Direct/transitive path kind mismatch: $($case.id)."
    }
}
$drifted = Invoke-Adapter (Join-Path $runRoot 'clean-own') ([ordered]@{ enabledClaims = @($policy.claimId); policySha256 = ('0' * 64) })
Assert ($drifted.status -ceq 'error' -and $drifted.exitCategory -ceq 'integrity-failure') 'Policy hash drift did not block.'
$realBefore = Inventory (Join-Path $repoRoot 'src')
$realResult = Invoke-Adapter $repoRoot $config
$realAfter = Inventory (Join-Path $repoRoot 'src')
Assert ($realBefore -ceq $realAfter -and $realResult.status -in @('pass', 'fail') -and
    $realResult.coverage[0].matched -gt 0) 'Real IFX ownership candidate could not be evaluated safely.'

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
    $bundleModuleRoot = Join-Path $bundlePackage 'modules/ifx-ownership-graph'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModuleRoot))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModuleRoot -Recurse
    $profileId = 'ifx_c1e_fixture'
    $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    $profile = [ordered]@{
        formatVersion = 1
        id = $profileId
        version = '0.1.0'
        projectIdentity = [ordered]@{ id = 'ifx-c1e-fixture'; relativeRoots = @('src') }
        moduleSelections = @([ordered]@{ id = 'ifx-ownership-graph'; versionRange = '>=0.1.0 <1.0.0'; config = $config })
        stageConfiguration = [ordered]@{
            bootstrap = [ordered]@{ enabled = $false; modules = @() }
            analysis = [ordered]@{ enabled = $false; modules = @() }
            pre = [ordered]@{ enabled = $true; modules = @('ifx-ownership-graph') }
            post = [ordered]@{ enabled = $false; modules = @() }
        }
        rules = @('OWNERSHIP-REFERENCE')
        baselineRefs = @()
    }
    Write-Json $profilePath $profile
    $bundleFiles = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\', '/'); sha256 = Hash $_.FullName; size = $_.Length }
    })
    $capabilities = [ordered]@{ readRoots = @('PackageRoot', 'TargetRoot'); writeRoots = @(); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 30 }
    $bundleManifest = [ordered]@{
        formatVersion = 1
        id = 'ifx-c1e-synthetic-extension'
        version = '0.1.0'
        compatibleApi = '1.x'
        baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = 'ifx-ownership-graph'; version = '0.1.0'; manifestPath = 'modules/ifx-ownership-graph/module.json'; manifestSha256 = Hash (Join-Path $bundleModuleRoot 'module.json'); allowedCapabilities = $capabilities })
        files = $bundleFiles
    }
    $bundleManifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $bundleManifestPath $bundleManifest
    $reviewPath = Join-Path $runRoot 'synthetic-review.json'
    $review = [ordered]@{
        formatVersion = 1
        id = '20260923-ifx-c1e-synthetic-fixture'
        scope = 'synthetic-test-only'
        decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-c1e-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $bundleManifestPath
        baseArchiveSha256 = $baseReceipt.archiveSha256
        moduleCeilings = @([ordered]@{ moduleId = 'ifx-ownership-graph'; allowedCapabilities = $capabilities })
    }
    Write-Json $reviewPath $review
    $composed = Join-Path $runRoot 'composed'
    $compositionReceiptPath = Join-Path $runRoot 'composition.receipt.json'
    $composer = Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1'
    $verifier = Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1'
    $stateRoot = Join-Path $runRoot 'host-state-clean'
    $evidenceRoot = Join-Path $runRoot 'host-evidence-clean'
    foreach ($path in @($stateRoot, $evidenceRoot)) { [void][IO.Directory]::CreateDirectory($path) }
    $composeOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $composer -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceiptPath -TargetRoot (Join-Path $runRoot 'clean-own') -StateRoot $stateRoot -EvidenceRoot $evidenceRoot -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($composeOutput -join "`n")"
    Assert ((($composeOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') 'Synthetic composition did not pass.'
    $verifyOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $verifier -InstallRoot $composed -ReceiptPath $compositionReceiptPath -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (($verifyOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Synthetic receipt verification failed: $($verifyOutput -join "`n")"
    $hostDll = Join-Path $composed 'host/v4-guards.dll'
    foreach ($case in @(
        [ordered]@{ id = 'clean-own'; status = 'pass'; category = 'success'; matched = 11 },
        [ordered]@{ id = 'own-contract-forbidden'; status = 'fail'; category = 'findings-blocking'; matched = 11 },
        [ordered]@{ id = 'transitive'; status = 'fail'; category = 'findings-blocking'; matched = 11 },
        [ordered]@{ id = 'zero-application'; status = 'fail'; category = 'findings-blocking'; matched = 9 }
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
        Assert ($hostResult.status -ceq $case.status -and $hostResult.exitCategory -ceq $case.category) "Synthetic Host result mismatch: $($case.id), exit $hostExitCode, $raw"
        Assert ($hostResult.coverage[0].matched -eq $case.matched) "Synthetic Host coverage mismatch: $($case.id)"
        Assert ((Inventory $target) -ceq $before) "Synthetic Host changed TargetRoot: $($case.id)"
    }
    Write-Output "Published-base synthetic composition and Host Pre cases passed. Composition receipt: $compositionReceiptPath"
}
Write-Output "IFX C1e ownership candidate passed nineteen fixtures and real IFX scan ($($realResult.status), $(@($realResult.findings).Count) findings). Evidence root: $runRoot"
