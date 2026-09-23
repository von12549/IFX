[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c1j/test-runs',
    [string] $BaseInstallRoot = '',
    [string] $BaseReceiptPath = '',
    [string] $BaseArchivePath = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Text([string] $Path, [string] $Text) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}
function Write-Json([string] $Path, $Value) { Write-Text $Path (($Value | ConvertTo-Json -Depth 50).Replace("`r`n", "`n") + "`n") }
function Inventory([string] $Root) {
    @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/'))|$(Hash $_.FullName)"
    }) -join "`n"
}

$candidateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-project-name'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'
$policyPath = Join-Path $moduleRoot 'policy.json'
$manifestPath = Join-Path $moduleRoot 'module.json'
$rulePlanPath = Join-Path $moduleRoot 'rule-execution-plan.json'
$resultSchemaPath = Join-Path $moduleRoot 'result.schema.json'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 30
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json -Depth 30
$rulePlan = Get-Content $rulePlanPath -Raw | ConvertFrom-Json -Depth 30
$source = Get-Content (Join-Path $repoRoot $policy.sourcePolicy.path) -Raw | ConvertFrom-Json -Depth 40
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) 'Module manifest schema failed.'
Assert ($manifest.id -ceq 'ifx-project-name' -and $manifest.stages -join ',' -ceq 'pre' -and
    $manifest.capabilities.readRoots -join ',' -ceq 'PackageRoot,TargetRoot' -and
    @($manifest.capabilities.writeRoots).Count -eq 0 -and $manifest.capabilities.processes -join ',' -ceq 'pwsh' -and
    $manifest.capabilities.network -eq $false -and $manifest.capabilities.timeoutSeconds -eq 30) 'Module identity or capability drift.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256 -and
    (Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Adapter or lock hash drift.'
foreach ($authority in $manifest.authorities) {
    Assert ((Hash (Join-Path $candidateRoot $authority.path)) -ceq $authority.sha256) "Authority hash drift: $($authority.id)."
}
Assert ((Hash (Join-Path $repoRoot $policy.sourcePolicy.path)) -ceq $policy.sourcePolicy.sha256 -and
    (Hash (Join-Path $repoRoot $policy.sourceRule.path)) -ceq $policy.sourceRule.sha256) 'V3 authority hash drift.'
Assert (($policy.rings | ConvertTo-Json -Depth 20 -Compress) -ceq ($source.rings | ConvertTo-Json -Depth 20 -Compress) -and
    ($policy.forbiddenProjectNames | ConvertTo-Json -Compress) -ceq ($source.forbiddenProjectNames | ConvertTo-Json -Compress) -and
    $policy.sourceSeverity -ceq $source.severities.'PROJECT-NAME-FORBIDDEN') 'V3 policy projection drift.'
Assert ($rulePlan.moduleId -ceq $manifest.id -and $rulePlan.matrixSha256 -ceq (Hash $policyPath) -and
    @($rulePlan.rules).Count -eq 1 -and $rulePlan.rules[0].ruleId -ceq $policy.ruleId -and
    $rulePlan.rules[0].claimId -ceq $policy.claimId -and $rulePlan.rules[0].minimumMatches -eq 1) 'Rule plan drift.'
$config = [ordered]@{ enabledClaims = @($policy.claimId); policySha256 = Hash $policyPath }
Assert (Test-Json -Json ($config | ConvertTo-Json -Depth 8 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction SilentlyContinue) 'Config schema failed.'
$absoluteEvidenceRoot = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repoRoot $EvidenceRoot }
$runRoot = Join-Path $absoluteEvidenceRoot ([Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)

function Invoke-Adapter([string] $TargetRoot, $Config) {
    $payload = [ordered]@{
        formatVersion = 1; stage = 'pre'; targetRoot = $TargetRoot; packageRoot = $candidateRoot
        stateRoot = Join-Path $runRoot 'state'; evidenceRoot = Join-Path $runRoot 'evidence'
        projectId = 'ifx'; relativeRoots = @('src'); config = $Config
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
    $raw | ConvertFrom-Json -Depth 20
}

$catalog = Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 20
Assert ($catalog.formatVersion -eq 1 -and @($catalog.cases).Count -eq 7) 'Fixture catalog drift.'
foreach ($case in $catalog.cases) {
    $target = Join-Path $runRoot $case.id
    [void][IO.Directory]::CreateDirectory($target)
    foreach ($relative in $case.projects) {
        $body = if ($null -ne $case.PSObject.Properties['malformed'] -and $case.malformed) { '<Project><' } else { '<Project Sdk="Microsoft.NET.Sdk" />' }
        Write-Text (Join-Path $target $relative) $body
    }
    $before = Inventory $target
    $result = Invoke-Adapter $target $config
    Assert ((Inventory $target) -ceq $before) "TargetRoot changed: $($case.id)."
    Assert ($result.status -ceq $case.expectedStatus -and $result.exitCategory -ceq $case.expectedCategory -and
        $result.coverage[0].matched -eq $case.matched -and @($result.findings).Count -eq $case.findings) "Fixture result mismatch: $($case.id): $($result | ConvertTo-Json -Compress -Depth 10)."
    foreach ($finding in $result.findings) {
        Assert ($finding.ruleId -ceq $policy.ruleId -and $finding.detectorId -ceq $manifest.id -and
            $finding.severity -ceq 'blocking') "Finding identity drift: $($case.id)."
    }
    if ($case.id -ceq 'clean') {
        $repeat = Invoke-Adapter $target $config
        Assert (($repeat | ConvertTo-Json -Depth 20 -Compress) -ceq ($result | ConvertTo-Json -Depth 20 -Compress)) 'Clean result is not deterministic.'
    }
}
$cleanTarget = Join-Path $runRoot 'clean'
$drift = Invoke-Adapter $cleanTarget ([ordered]@{ enabledClaims = @($policy.claimId); policySha256 = ('0' * 64) })
Assert ($drift.status -ceq 'error' -and $drift.exitCategory -ceq 'integrity-failure') 'Policy hash drift was not blocked.'
$linked = Join-Path $runRoot 'linked-path'
Write-Text (Join-Path $linked 'src/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj') '<Project />'
if ($IsWindows) { [void](New-Item -ItemType Junction -Path (Join-Path $linked 'src/linked') -Target (Join-Path $linked 'src/IFX.Modules.CRM.Domain')) }
else { [void](New-Item -ItemType SymbolicLink -Path (Join-Path $linked 'src/linked') -Target (Join-Path $linked 'src/IFX.Modules.CRM.Domain')) }
$unsafe = Invoke-Adapter $linked $config
Assert ($unsafe.status -ceq 'error' -and $unsafe.exitCategory -ceq 'unsafe-path') 'Linked source directory was not blocked.'
$realBefore = Inventory (Join-Path $repoRoot 'src')
$real = Invoke-Adapter $repoRoot $config
Assert ($real.status -ceq 'pass' -and $real.coverage[0].matched -gt 0 -and
    @($real.findings).Count -eq 0 -and (Inventory (Join-Path $repoRoot 'src')) -ceq $realBefore) 'Real IFX scan failed, vacuous or mutated source.'

$provided = @($BaseInstallRoot, $BaseReceiptPath, $BaseArchivePath | Where-Object { $_ })
Assert ($provided.Count -eq 0 -or $provided.Count -eq 3) 'Provide all three published-base paths or none.'
if ($provided.Count -eq 3) {
    $baseCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repoRoot 'docs/guards/candidates/ifx-gate-coverage-c1i/Test-PublishedV4Base.ps1') -ArchivePath $BaseArchivePath -ReceiptPath $BaseReceiptPath -InstallRoot $BaseInstallRoot | ConvertFrom-Json
    Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass') 'Published base identity check failed.'
    $bundleRoot = Join-Path $runRoot 'bundle'
    $bundlePackage = Join-Path $bundleRoot 'package'
    $bundleModuleRoot = Join-Path $bundlePackage 'modules/ifx-project-name'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModuleRoot))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModuleRoot -Recurse
    $profileId = 'ifx_c1j_fixture'
    $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    Write-Json $profilePath ([ordered]@{
        formatVersion = 1; id = $profileId; version = '0.1.0'
        projectIdentity = [ordered]@{ id = 'ifx-c1j-fixture'; relativeRoots = @('src') }
        moduleSelections = @([ordered]@{ id = 'ifx-project-name'; versionRange = '>=0.1.0 <1.0.0'; config = $config })
        stageConfiguration = [ordered]@{
            bootstrap = [ordered]@{ enabled = $false; modules = @() }
            analysis = [ordered]@{ enabled = $false; modules = @() }
            pre = [ordered]@{ enabled = $true; modules = @('ifx-project-name') }
            post = [ordered]@{ enabled = $false; modules = @() }
        }
        rules = @($policy.ruleId); baselineRefs = @()
    })
    $bundleFiles = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\','/'); sha256 = Hash $_.FullName; size = $_.Length }
    })
    $ceiling = [ordered]@{ readRoots = @('PackageRoot','TargetRoot'); writeRoots = @(); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 30 }
    $manifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $manifestPath ([ordered]@{
        formatVersion = 1; id = 'ifx-c1j-synthetic-extension'; version = '0.1.0'; compatibleApi = '1.x'; baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = 'ifx-project-name'; version = '0.1.0'; manifestPath = 'modules/ifx-project-name/module.json'; manifestSha256 = Hash (Join-Path $bundleModuleRoot 'module.json'); allowedCapabilities = $ceiling })
        files = $bundleFiles
    })
    $reviewPath = Join-Path $runRoot 'synthetic-review.json'
    Write-Json $reviewPath ([ordered]@{
        formatVersion = 1; id = '20260924-ifx-c1j-synthetic-fixture'; scope = 'synthetic-test-only'; decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-c1j-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $manifestPath; baseArchiveSha256 = $baseCheck.archiveSha256
        moduleCeilings = @([ordered]@{ moduleId = 'ifx-project-name'; allowedCapabilities = $ceiling })
    })
    $composed = Join-Path $runRoot 'composed'
    $compositionReceipt = Join-Path $runRoot 'composition.receipt.json'
    $composeState = Join-Path $runRoot 'state'
    $composeEvidence = Join-Path $runRoot 'evidence'
    [void][IO.Directory]::CreateDirectory($composeState)
    [void][IO.Directory]::CreateDirectory($composeEvidence)
    $composeOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot $cleanTarget -StateRoot $composeState -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($composeOutput -join "`n")"
    $verifyOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $compositionReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (($verifyOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Composition receipt failed: $($verifyOutput -join "`n")"
    foreach ($case in @($catalog.cases | Where-Object id -in @('clean','forbidden-in-scope','zero-in-scope'))) {
        $target = Join-Path $runRoot $case.id
        $state = Join-Path $runRoot "host-state-$($case.id)"
        $evidence = Join-Path $runRoot "host-evidence-$($case.id)"
        [void][IO.Directory]::CreateDirectory($state)
        [void][IO.Directory]::CreateDirectory($evidence)
        $before = Inventory $target
        $hostOutput = @(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage pre --package-root (Join-Path $composed 'package') --target-root $target --state-root $state --evidence-root $evidence --profile $profileId 2>&1)
        $result = ($hostOutput -join "`n") | ConvertFrom-Json -Depth 30
        Assert ($result.status -ceq $case.expectedStatus -and $result.exitCategory -ceq $case.expectedCategory -and
            $result.coverage[0].matched -eq $case.matched -and (Inventory $target) -ceq $before) "Host Pre mismatch: $($case.id): $($hostOutput -join "`n")"
    }
}
Write-Output "IFX C1j candidate passed seven fixtures, drift/link controls and real IFX scan ($($real.coverage[0].matched) projects). Evidence root: $runRoot"
