[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c1n/test-runs',
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
function Write-Json([string] $Path, $Value) { Write-Text $Path (($Value | ConvertTo-Json -Depth 50).Replace("`r`n", "`n") + "`n") }
function Inventory([string] $Root) {
    @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/'))|$(Hash $_.FullName)"
    }) -join "`n"
}

$candidateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-reference-cycle'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'
$policyPath = Join-Path $moduleRoot 'policy.json'
$manifestPath = Join-Path $moduleRoot 'module.json'
$rulePlanPath = Join-Path $moduleRoot 'rule-execution-plan.json'
$resultSchemaPath = Join-Path $moduleRoot 'result.schema.json'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 40
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json -Depth 40
$rulePlan = Get-Content $rulePlanPath -Raw | ConvertFrom-Json -Depth 40
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) 'Module manifest schema failed.'
Assert ($manifest.id -ceq 'ifx-reference-cycle' -and ($manifest.stages -join ',') -ceq 'pre' -and
    ($manifest.capabilities.readRoots -join ',') -ceq 'PackageRoot,TargetRoot' -and
    @($manifest.capabilities.writeRoots).Count -eq 0 -and ($manifest.capabilities.processes -join ',') -ceq 'pwsh' -and
    $manifest.capabilities.network -eq $false -and $manifest.capabilities.timeoutSeconds -eq 30) 'Module identity or capabilities drift.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256 -and
    (Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Adapter or dependency lock hash drift.'
foreach ($authority in $manifest.authorities) {
    Assert ((Hash (Join-Path $candidateRoot $authority.path)) -ceq $authority.sha256) "Module authority hash drift: $($authority.id)."
}
foreach ($source in @($policy.sourcePolicy, $policy.sourceG03) + @($policy.sourceImplementations)) {
    Assert ((Hash (Join-Path $repoRoot $source.path)) -ceq $source.sha256) "V3 source hash drift: $($source.path)."
}
$sourcePolicy = Get-Content (Join-Path $repoRoot $policy.sourcePolicy.path) -Raw | ConvertFrom-Json -Depth 40
$sourceG03 = Get-Content (Join-Path $repoRoot $policy.sourceG03.path) -Raw | ConvertFrom-Json -Depth 40
foreach ($field in @('rings','allowedDependencies','allowedReferences')) {
    Assert (($policy.$field | ConvertTo-Json -Depth 30 -Compress) -ceq ($sourcePolicy.$field | ConvertTo-Json -Depth 30 -Compress)) "Policy projection drift: $field."
}
Assert ((@($policy.sharedPrimitiveProjects) -join '|') -ceq (@($sourceG03.sharedPrimitiveProjects) -join '|')) 'Shared primitive projection drift.'
Assert ($rulePlan.moduleId -ceq $manifest.id -and $rulePlan.matrixSha256 -ceq (Hash $policyPath) -and
    @($rulePlan.rules).Count -eq 2 -and $rulePlan.rules[0].ruleId -ceq 'RING-REFERENCE' -and
    $rulePlan.rules[1].ruleId -ceq 'CONTRACT-CYCLE' -and
    @($rulePlan.rules | Where-Object minimumMatches -ne 1).Count -eq 0) 'Rule execution plan drift.'
$config = [ordered]@{ enabledClaims = @('IFX.C1.RING_REFERENCE_RAW','IFX.C1.CONTRACT_CYCLE_RAW'); policySha256 = Hash $policyPath }
Assert (Test-Json -Json ($config | ConvertTo-Json -Depth 8 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction SilentlyContinue) 'Config schema failed.'
$evidence = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repoRoot $EvidenceRoot }
$runRoot = Join-Path $evidence ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)

function Invoke-Adapter([string] $Target, $Selection) {
    $payload = [ordered]@{
        formatVersion = 1; stage = 'pre'; targetRoot = $Target; packageRoot = $candidateRoot
        stateRoot = Join-Path $runRoot 'state'; evidenceRoot = Join-Path $runRoot 'evidence'
        projectId = 'ifx'; relativeRoots = @('src'); config = $Selection
    }
    $previous = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $payload | ConvertTo-Json -Depth 20 -Compress
        $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapterPath 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally { $env:V4_STAGE_INPUT_JSON = $previous }
    $raw = $output -join "`n"
    Assert ($exitCode -eq 0) "Adapter process failed: $raw"
    Assert (Test-Json -Json $raw -SchemaFile $resultSchemaPath -ErrorAction SilentlyContinue) "Result schema failed: $raw"
    return ($raw | ConvertFrom-Json -Depth 30)
}

$catalog = Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 30
Assert ($catalog.formatVersion -eq 1 -and @($catalog.cases).Count -eq 13) 'Fixture catalog drift.'
foreach ($case in $catalog.cases) {
    $target = Join-Path $runRoot $case.id
    [void][IO.Directory]::CreateDirectory((Join-Path $target 'src'))
    foreach ($project in @($case.projects)) {
        $path = Join-Path $target ([string]$project.path)
        $body = if ($null -ne $project.PSObject.Properties['malformed'] -and $project.malformed) { '<Project><' }
        else {
            $references = [Collections.Generic.List[string]]::new()
            $declaredReferences = if ($null -ne $project.PSObject.Properties['references']) { @($project.references) } else { @() }
            foreach ($relative in $declaredReferences) {
                if (-not $relative) { continue }
                $targetPath = Join-Path $target ([string]$relative)
                $include = [IO.Path]::GetRelativePath(([IO.Path]::GetDirectoryName($path)), $targetPath).Replace('/', '\')
                $references.Add("<ProjectReference Include=`"$include`" />")
            }
            if ($null -ne $project.PSObject.Properties['rawInclude'] -and $project.rawInclude) {
                $references.Add("<ProjectReference Include=`"$($project.rawInclude)`" />")
            }
            '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup>' + ($references -join '') + '</ItemGroup></Project>'
        }
        Write-Text $path $body
    }
    $before = Inventory $target
    $result = Invoke-Adapter $target $config
    Assert ((Inventory $target) -ceq $before) "TargetRoot changed: $($case.id)."
    $rings = @($result.findings | Where-Object ruleId -eq 'RING-REFERENCE')
    $cycles = @($result.findings | Where-Object ruleId -eq 'CONTRACT-CYCLE')
    Assert ($result.status -ceq $case.status -and $result.exitCategory -ceq $case.category -and
        $result.coverage[0].matched -eq $case.referenceMatches -and $result.coverage[1].matched -eq $case.contractMatches -and
        $rings.Count -eq $case.ringFindings -and $cycles.Count -eq $case.cycleFindings) "Fixture mismatch: $($case.id): $($result | ConvertTo-Json -Depth 12 -Compress)."
    if ($case.id -in @('clean','cycle-two','cycle-three')) {
        $repeat = Invoke-Adapter $target $config
        Assert (($repeat | ConvertTo-Json -Depth 30 -Compress) -ceq ($result | ConvertTo-Json -Depth 30 -Compress)) "Nondeterministic result: $($case.id)."
    }
}
$drift = Invoke-Adapter (Join-Path $runRoot 'clean') ([ordered]@{ enabledClaims = $config.enabledClaims; policySha256 = ('0' * 64) })
Assert ($drift.status -ceq 'error' -and $drift.exitCategory -ceq 'integrity-failure') 'Policy hash drift did not block.'
$linked = Join-Path $runRoot 'linked-path'
Write-Text (Join-Path $linked 'src/Modules/A/IFX.Modules.A.Contracts/IFX.Modules.A.Contracts.csproj') '<Project />'
if ($IsWindows) { [void](New-Item -ItemType Junction -Path (Join-Path $linked 'src/linked') -Target (Join-Path $linked 'src/Modules/A')) }
else { [void](New-Item -ItemType SymbolicLink -Path (Join-Path $linked 'src/linked') -Target (Join-Path $linked 'src/Modules/A')) }
$unsafe = Invoke-Adapter $linked $config
Assert ($unsafe.status -ceq 'error' -and $unsafe.exitCategory -ceq 'unsafe-path') 'Linked source directory did not block.'
$beforeReal = Inventory (Join-Path $repoRoot 'src')
$real = Invoke-Adapter $repoRoot $config
Assert ($real.status -ceq 'pass' -and $real.coverage[0].matched -gt 0 -and $real.coverage[1].matched -gt 0 -and
    (Inventory (Join-Path $repoRoot 'src')) -ceq $beforeReal) 'Real IFX scan failed or changed TargetRoot.'

$provided = @($BaseInstallRoot, $BaseReceiptPath, $BaseArchivePath | Where-Object { $_ })
Assert ($provided.Count -eq 0 -or $provided.Count -eq 3) 'Provide all three published-base paths or none.'
if ($provided.Count -eq 3) {
    $baseCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repoRoot 'docs/guards/candidates/ifx-gate-coverage-c1i/Test-PublishedV4Base.ps1') -ArchivePath $BaseArchivePath -ReceiptPath $BaseReceiptPath -InstallRoot $BaseInstallRoot | ConvertFrom-Json
    Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass') 'Published base identity check failed.'
    $bundleRoot = Join-Path $runRoot 'bundle'
    $bundlePackage = Join-Path $bundleRoot 'package'
    $bundleModuleRoot = Join-Path $bundlePackage 'modules/ifx-reference-cycle'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModuleRoot))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModuleRoot -Recurse
    $profileId = 'ifx_c1n_fixture'
    $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    Write-Json $profilePath ([ordered]@{
        formatVersion = 1; id = $profileId; version = '0.1.0'
        projectIdentity = [ordered]@{ id = 'ifx-c1n-fixture'; relativeRoots = @('src') }
        moduleSelections = @([ordered]@{ id = 'ifx-reference-cycle'; versionRange = '>=0.1.0 <1.0.0'; config = $config })
        stageConfiguration = [ordered]@{
            bootstrap = [ordered]@{ enabled = $false; modules = @() }
            analysis = [ordered]@{ enabled = $false; modules = @() }
            pre = [ordered]@{ enabled = $true; modules = @('ifx-reference-cycle') }
            post = [ordered]@{ enabled = $false; modules = @() }
        }
        rules = @('RING-REFERENCE','CONTRACT-CYCLE'); baselineRefs = @()
    })
    $bundleFiles = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\','/'); sha256 = Hash $_.FullName; size = $_.Length }
    })
    $ceiling = [ordered]@{ readRoots = @('PackageRoot','TargetRoot'); writeRoots = @(); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 30 }
    $manifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $manifestPath ([ordered]@{
        formatVersion = 1; id = 'ifx-c1n-synthetic-extension'; version = '0.1.0'; compatibleApi = '1.x'; baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = 'ifx-reference-cycle'; version = '0.1.0'; manifestPath = 'modules/ifx-reference-cycle/module.json'; manifestSha256 = Hash (Join-Path $bundleModuleRoot 'module.json'); allowedCapabilities = $ceiling })
        files = $bundleFiles
    })
    $reviewPath = Join-Path $runRoot 'synthetic-review.json'
    Write-Json $reviewPath ([ordered]@{
        formatVersion = 1; id = '20260924-ifx-c1n-synthetic-fixture'; scope = 'synthetic-test-only'; decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-c1n-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $manifestPath; baseArchiveSha256 = $baseCheck.archiveSha256
        moduleCeilings = @([ordered]@{ moduleId = 'ifx-reference-cycle'; allowedCapabilities = $ceiling })
    })
    $composed = Join-Path $runRoot 'composed'
    $compositionReceipt = Join-Path $runRoot 'composition.receipt.json'
    $composeState = Join-Path $runRoot 'state'
    $composeEvidence = Join-Path $runRoot 'evidence'
    [void][IO.Directory]::CreateDirectory($composeState)
    [void][IO.Directory]::CreateDirectory($composeEvidence)
    $composeOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot (Join-Path $runRoot 'clean') -StateRoot $composeState -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($composeOutput -join "`n")"
    $verifyOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $compositionReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (($verifyOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Composition receipt failed: $($verifyOutput -join "`n")"
    foreach ($case in @($catalog.cases | Where-Object id -in @('clean','off-list','cycle-two','zero-projects'))) {
        $target = Join-Path $runRoot $case.id
        $state = Join-Path $runRoot "host-state-$($case.id)"
        $hostEvidence = Join-Path $runRoot "host-evidence-$($case.id)"
        [void][IO.Directory]::CreateDirectory($state)
        [void][IO.Directory]::CreateDirectory($hostEvidence)
        $before = Inventory $target
        $hostOutput = @(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage pre --package-root (Join-Path $composed 'package') --target-root $target --state-root $state --evidence-root $hostEvidence --profile $profileId 2>&1)
        $result = ($hostOutput -join "`n") | ConvertFrom-Json -Depth 30
        Assert ($result.status -ceq $case.status -and $result.exitCategory -ceq $case.category -and
            $result.coverage[0].matched -eq $case.referenceMatches -and $result.coverage[1].matched -eq $case.contractMatches -and
            (Inventory $target) -ceq $before) "Host Pre mismatch: $($case.id): $($hostOutput -join "`n")"
    }
}
Write-Output "IFX C1n passed 13 fixtures and controls; real IFX $($real.coverage[0].matched) direct references, $($real.coverage[1].matched) Contracts projects. Evidence: $runRoot"
