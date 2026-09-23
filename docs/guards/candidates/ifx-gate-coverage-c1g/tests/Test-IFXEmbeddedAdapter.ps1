[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c1g/test-runs',
    [string] $BaseInstallRoot = '',
    [string] $BaseReceiptPath = '',
    [string] $BaseArchivePath = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Inventory([string] $Root) {
    @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/'))|$(Hash $_.FullName)"
    }) -join "`n"
}
function Write-Text([string] $Path, [string] $Value) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($false))
}
function Write-Json([string] $Path, $Value) { Write-Text $Path (($Value | ConvertTo-Json -Depth 80).Replace("`r`n", "`n") + "`n") }
function Has-Flag($Case, [string] $Name) { return $null -ne $Case.PSObject.Properties[$Name] -and [bool]$Case.PSObject.Properties[$Name].Value }

$candidateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-embedded-adapter'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'
$policyPath = Join-Path $moduleRoot 'policy.json'
$manifestPath = Join-Path $moduleRoot 'module.json'
$schemaPath = Join-Path $moduleRoot 'result.schema.json'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 30
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json -Depth 40
$rulePlan = Get-Content (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 30
$source = Get-Content (Join-Path $repoRoot $policy.sourcePolicy.path) -Raw | ConvertFrom-Json -Depth 50
$g03 = Get-Content (Join-Path $repoRoot $policy.sourceG03.path) -Raw | ConvertFrom-Json -Depth 40
Assert (Test-Json -Json (Get-Content $manifestPath -Raw) -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) 'Module schema failed.'
Assert ($manifest.id -ceq 'ifx-embedded-adapter' -and $manifest.capabilities.readRoots -join ',' -ceq 'PackageRoot,TargetRoot' -and
    @($manifest.capabilities.writeRoots).Count -eq 0 -and $manifest.capabilities.processes -join ',' -ceq 'pwsh,dotnet' -and
    $manifest.capabilities.network -eq $false -and $manifest.capabilities.timeoutSeconds -eq 30) 'Module ceiling drift.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256) 'Adapter hash drift.'
Assert ((Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Dependency lock drift.'
foreach ($authority in $manifest.authorities) { Assert ((Hash (Join-Path $candidateRoot $authority.path)) -ceq $authority.sha256) "Authority drift: $($authority.id)." }
foreach ($record in @($policy.sourcePolicy, $policy.sourceG03, $policy.sourceRule, $policy.sourceImplementation)) {
    Assert ((Hash (Join-Path $repoRoot $record.path)) -ceq $record.sha256) "Source authority drift: $($record.path)."
}
foreach ($field in @('rings','ownership','embeddedAdapterNamespaces')) {
    Assert (($policy.$field | ConvertTo-Json -Depth 40 -Compress) -ceq ($source.$field | ConvertTo-Json -Depth 40 -Compress)) "V3 policy projection drift: $field."
}
foreach ($field in @('providerContracts','sharedPrimitiveProjects')) {
    Assert (($policy.$field | ConvertTo-Json -Depth 40 -Compress) -ceq ($g03.$field | ConvertTo-Json -Depth 40 -Compress)) "G03 projection drift: $field."
}
Assert ($rulePlan.matrixSha256 -ceq (Hash $policyPath) -and @($rulePlan.rules).Count -eq 2) 'Rule plan drift.'
$config = [ordered]@{ enabledClaims = @($policy.claims); policySha256 = Hash $policyPath }
Assert (Test-Json -Json ($config | ConvertTo-Json -Depth 10 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction SilentlyContinue) 'Config schema failed.'
$absoluteEvidenceRoot = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repoRoot $EvidenceRoot }
$runRoot = Join-Path $absoluteEvidenceRoot ([Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)
function Invoke-Adapter([string] $TargetRoot, $Config) {
    $payload = [ordered]@{ formatVersion = 1; stage = 'pre'; targetRoot = $TargetRoot; packageRoot = $candidateRoot
        stateRoot = Join-Path $runRoot 'state'; evidenceRoot = Join-Path $runRoot 'evidence'; projectId = 'ifx'
        relativeRoots = @('src'); config = $Config }
    $previous = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $payload | ConvertTo-Json -Depth 20 -Compress
        $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapterPath 2>&1)
        $exitCode = $LASTEXITCODE
    } finally { $env:V4_STAGE_INPUT_JSON = $previous }
    $raw = $output -join "`n"
    Assert ($exitCode -eq 0) "Adapter process failed: $raw"
    Assert (Test-Json -Json $raw -SchemaFile $schemaPath -ErrorAction SilentlyContinue) "Result schema failed: $raw"
    $raw | ConvertFrom-Json -Depth 30
}
function Make-Fixture([string] $Root, $Case) {
    [void][IO.Directory]::CreateDirectory($Root)
    if (Has-Flag $Case 'missingSrc') { return }
    foreach ($name in @('IFX.Modules.CRM.Infrastructure','IFX.Modules.CRM.Contracts','IFX.Modules.IAM.Contracts',
        'IFX.Modules.Registry.Contracts','IFX.Platform.Context.Contracts')) {
        $projectPath = Join-Path $Root "src/$name/$name.csproj"
        $body = if ((Has-Flag $Case 'malformedProject') -and $name -ceq 'IFX.Modules.CRM.Infrastructure') { '<Project><' } else { '<Project Sdk="Microsoft.NET.Sdk" />' }
        Write-Text $projectPath $body
    }
    $names = @($Case.target)
    if ($null -ne $Case.PSObject.Properties['extra']) { $names += @($Case.extra) }
    $uses = @($names | ForEach-Object { "using $_;" }) -join "`n"
    $text = if (Has-Flag $Case 'malformedSource') { "$uses`nnamespace $($Case.namespace) { class X {" } else {
        "$uses`nnamespace $($Case.namespace) { class X {} }"
    }
    $filename = if (Has-Flag $Case 'generatedOnly') { 'Adapter.g.cs' } else { 'Adapter.cs' }
    Write-Text (Join-Path $Root "src/IFX.Modules.CRM.Infrastructure/$filename") $text
    if (Has-Flag $Case 'nestedProject') {
        $nested = 'src/IFX.Modules.CRM.Infrastructure/Nested/IFX.Modules.CRM.Application'
        Write-Text (Join-Path $Root "$nested/IFX.Modules.CRM.Application.csproj") '<Project Sdk="Microsoft.NET.Sdk" />'
        Write-Text (Join-Path $Root "$nested/Foreign.cs") 'using IFX.Modules.Registry.Contracts; namespace IFX.Modules.CRM.Infrastructure.Services { class Foreign {} }'
    }
    if (Has-Flag $Case 'guardSubtree') {
        $guardPath = 'src/guard/IFX.Modules.Registry.Infrastructure'
        Write-Text (Join-Path $Root "$guardPath/IFX.Modules.Registry.Infrastructure.csproj") '<Project Sdk="Microsoft.NET.Sdk" />'
        Write-Text (Join-Path $Root "$guardPath/Foreign.cs") 'using IFX.Modules.CRM.Contracts; namespace IFX.Modules.Registry.Infrastructure.Services { class Foreign {} }'
    }
}

$fixtures = Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 30
Assert ($fixtures.formatVersion -eq 1 -and @($fixtures.cases).Count -eq 12) 'Fixture catalog drift.'
foreach ($case in $fixtures.cases) {
    $target = Join-Path $runRoot $case.id
    Make-Fixture $target $case
    $before = Inventory $target
    $result = Invoke-Adapter $target $config
    Assert ($result.status -ceq $case.status) "Fixture status mismatch: $($case.id): $($result | ConvertTo-Json -Compress)."
    if ($null -ne $case.PSObject.Properties['category']) { Assert ($result.exitCategory -ceq $case.category) "Fixture category mismatch: $($case.id)." }
    if ($null -ne $case.PSObject.Properties['rules']) {
        $actual = @($result.findings | ForEach-Object ruleId)
        Assert (($actual -join ',') -ceq (@($case.rules) -join ',')) "Fixture rule mismatch: $($case.id): $($actual -join ',')."
        Assert (($result.coverage | ForEach-Object matched | Select-Object -Unique) -join ',' -ceq $(if ($case.id -eq 'zero-foreign') { '0' } else { '1' })) "Fixture coverage mismatch: $($case.id)."
    }
    Assert ((Inventory $target) -ceq $before) "Adapter changed TargetRoot: $($case.id)."
}
$unsafe = Join-Path $runRoot 'unsafe-link'
Make-Fixture $unsafe $fixtures.cases[0]
$link = Join-Path $unsafe 'src/linked-project'
$linkTarget = Join-Path $unsafe 'src/IFX.Modules.IAM.Contracts'
if ($IsWindows) { [void](New-Item -ItemType Junction -Path $link -Target $linkTarget) }
else { [void](New-Item -ItemType SymbolicLink -Path $link -Target $linkTarget) }
$unsafeBefore = Inventory $unsafe
$unsafeResult = Invoke-Adapter $unsafe $config
Assert ($unsafeResult.status -ceq 'error' -and $unsafeResult.exitCategory -ceq 'unsafe-path') 'Linked source inventory was not blocked.'
Assert ((Inventory $unsafe) -ceq $unsafeBefore) 'Unsafe-path test changed TargetRoot.'
$clean = Join-Path $runRoot 'clean'
$drift = Invoke-Adapter $clean ([ordered]@{ enabledClaims = @($policy.claims); policySha256 = ('0' * 64) })
Assert ($drift.status -ceq 'error' -and $drift.exitCategory -ceq 'integrity-failure') 'Policy hash drift was not blocked.'
$realBefore = Inventory (Join-Path $repoRoot 'src')
$missing = Invoke-Adapter $repoRoot $config
$realAfter = Inventory (Join-Path $repoRoot 'src')
Assert ($realBefore -ceq $realAfter -and $missing.status -in @('pass','fail') -and
    @($missing.coverage | Where-Object matched -lt 1).Count -eq 0) 'Real IFX scan is vacuous, mutating or errored.'
if ($BaseInstallRoot -or $BaseReceiptPath -or $BaseArchivePath) {
    Assert ($BaseInstallRoot -and $BaseReceiptPath -and $BaseArchivePath) 'Provide all three published-base paths.'
    $baseReceipt = Get-Content $BaseReceiptPath -Raw | ConvertFrom-Json -Depth 40
    Assert ($baseReceipt.status -ceq 'installed' -and $baseReceipt.version -ceq '1.1.2' -and
        $baseReceipt.archiveSha256 -ceq '12270a26f923a86f49be4ee0d003f5493b2562891fd1484a4fac079f02b73c95' -and
        (Hash $BaseArchivePath) -ceq $baseReceipt.archiveSha256) 'Published receipt/archive identity drift.'
    $baseCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package') | ConvertFrom-Json
    Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass' -and
        $baseCheck.packageHash -ceq '922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d') 'Published Package hash drift.'
    $bundleRoot = Join-Path $runRoot 'bundle'
    $bundlePackage = Join-Path $bundleRoot 'package'
    $bundleModuleRoot = Join-Path $bundlePackage 'modules/ifx-embedded-adapter'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModuleRoot))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModuleRoot -Recurse
    $profileId = 'ifx_c1g_fixture'
    $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    $profile = [ordered]@{
        formatVersion = 1; id = $profileId; version = '0.1.0'
        projectIdentity = [ordered]@{ id = 'ifx-c1g-fixture'; relativeRoots = @('src') }
        moduleSelections = @([ordered]@{ id = 'ifx-embedded-adapter'; versionRange = '>=0.1.0 <1.0.0'; config = $config })
        stageConfiguration = [ordered]@{
            bootstrap = [ordered]@{ enabled = $false; modules = @() }
            analysis = [ordered]@{ enabled = $false; modules = @() }
            pre = [ordered]@{ enabled = $true; modules = @('ifx-embedded-adapter') }
            post = [ordered]@{ enabled = $false; modules = @() }
        }
        rules = @('EMBEDDED-ADAPTER-LOCATION', 'EMBEDDED-ADAPTER-PROVIDER')
        baselineRefs = @()
    }
    Write-Json $profilePath $profile
    $bundleFiles = @(Get-ChildItem $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\','/'); sha256 = Hash $_.FullName; size = $_.Length }
    })
    $ceiling = [ordered]@{ readRoots = @('PackageRoot','TargetRoot'); writeRoots = @(); processes = @('pwsh','dotnet'); network = $false; maxTimeoutSeconds = 30 }
    $bundleManifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $bundleManifestPath ([ordered]@{
        formatVersion = 1; id = 'ifx-c1g-synthetic-extension'; version = '0.1.0'; compatibleApi = '1.x'; baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = 'ifx-embedded-adapter'; version = '0.1.0'; manifestPath = 'modules/ifx-embedded-adapter/module.json'; manifestSha256 = Hash (Join-Path $bundleModuleRoot 'module.json'); allowedCapabilities = $ceiling })
        files = $bundleFiles
    })
    $reviewPath = Join-Path $runRoot 'synthetic-review.json'
    Write-Json $reviewPath ([ordered]@{
        formatVersion = 1; id = '20260924-ifx-c1g-synthetic-fixture'; scope = 'synthetic-test-only'; decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-c1g-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $bundleManifestPath; baseArchiveSha256 = $baseReceipt.archiveSha256
        moduleCeilings = @([ordered]@{ moduleId = 'ifx-embedded-adapter'; allowedCapabilities = $ceiling })
    })
    $composed = Join-Path $runRoot 'composed'
    $compositionReceiptPath = Join-Path $runRoot 'composition.receipt.json'
    $stateRoot = Join-Path $runRoot 'host-state-clean'
    $evidenceRoot = Join-Path $runRoot 'host-evidence-clean'
    foreach ($path in @($stateRoot,$evidenceRoot)) { [void][IO.Directory]::CreateDirectory($path) }
    $composer = Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1'
    $composeOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $composer -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceiptPath -TargetRoot (Join-Path $runRoot 'clean') -StateRoot $stateRoot -EvidenceRoot $evidenceRoot -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Synthetic composition process failed: $($composeOutput -join "`n")"
    Assert ((($composeOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Synthetic composition failed: $($composeOutput -join "`n")"
    $verifier = Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1'
    $verifyOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $verifier -InstallRoot $composed -ReceiptPath $compositionReceiptPath -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (($verifyOutput -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Synthetic receipt failed: $($verifyOutput -join "`n")"
    $hostDll = Join-Path $composed 'host/v4-guards.dll'
    foreach ($hostCase in @(
        [ordered]@{ id = 'clean'; status = 'pass'; matched = 1 },
        [ordered]@{ id = 'wrong-location'; status = 'fail'; matched = 1 },
        [ordered]@{ id = 'unapproved-provider'; status = 'fail'; matched = 1 },
        [ordered]@{ id = 'zero-foreign'; status = 'fail'; matched = 0 }
    )) {
        $target = Join-Path $runRoot $hostCase.id
        $state = Join-Path $runRoot "host-state-$($hostCase.id)"
        $evidence = Join-Path $runRoot "host-evidence-$($hostCase.id)"
        foreach ($path in @($state,$evidence)) { [void][IO.Directory]::CreateDirectory($path) }
        $before = Inventory $target
        $hostOutput = @(& dotnet $hostDll stage run --stage pre --package-root (Join-Path $composed 'package') --target-root $target --state-root $state --evidence-root $evidence --profile $profileId 2>&1)
        $raw = $hostOutput -join "`n"
        $hostResult = $raw | ConvertFrom-Json -Depth 30
        Assert ($hostResult.status -ceq $hostCase.status -and $hostResult.coverage[0].matched -eq $hostCase.matched -and
            $hostResult.coverage[1].matched -eq $hostCase.matched) "Synthetic Host mismatch: $($hostCase.id): $raw"
        Assert ((Inventory $target) -ceq $before) "Synthetic Host changed TargetRoot: $($hostCase.id)."
    }
    Write-Output "Published Host synthetic composition and four Pre cases passed. Receipt: $compositionReceiptPath"
}
Write-Output "C1g fixtures and real IFX scan passed; real matched=$($missing.coverage[0].matched), findings=$(@($missing.findings).Count). Evidence: $runRoot"
