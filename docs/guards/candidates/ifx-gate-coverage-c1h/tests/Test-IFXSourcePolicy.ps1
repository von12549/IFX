[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c1h/test-runs',
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
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-source-policy'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'
$policyPath = Join-Path $moduleRoot 'policy.json'
$manifestPath = Join-Path $moduleRoot 'module.json'
$schemaPath = Join-Path $moduleRoot 'result.schema.json'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 30
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json -Depth 50
$rulePlan = Get-Content (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 30
$source = Get-Content (Join-Path $repoRoot $policy.sourcePolicy.path) -Raw | ConvertFrom-Json -Depth 50
$g03 = Get-Content (Join-Path $repoRoot $policy.sourceG03.path) -Raw | ConvertFrom-Json -Depth 40
Assert (Test-Json -Json (Get-Content $manifestPath -Raw) -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) 'Module schema failed.'
Assert ($manifest.id -ceq 'ifx-source-policy' -and $manifest.capabilities.readRoots -join ',' -ceq 'PackageRoot,TargetRoot' -and
    @($manifest.capabilities.writeRoots).Count -eq 0 -and $manifest.capabilities.processes -join ',' -ceq 'pwsh,dotnet' -and
    $manifest.capabilities.network -eq $false -and $manifest.capabilities.timeoutSeconds -eq 180) 'Module ceiling drift.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256) 'Adapter hash drift.'
Assert ((Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Dependency lock drift.'
foreach ($authority in $manifest.authorities) { Assert ((Hash (Join-Path $candidateRoot $authority.path)) -ceq $authority.sha256) "Authority drift: $($authority.id)." }
foreach ($record in @($policy.sourcePolicy, $policy.sourceG03) + @($policy.sourceRules) + @($policy.sourceImplementations)) {
    Assert ((Hash (Join-Path $repoRoot $record.path)) -ceq $record.sha256) "Source authority drift: $($record.path)."
}
foreach ($field in @('rings','ownership','allowedDependencies','referenceScopes','allowedPackages','forbiddenPackages',
    'declarationNamespaces','forbiddenDeclarations','forbiddenNamespaces','forbiddenSymbols','forbiddenText','payloads','declarations','severities')) {
    Assert (($policy.$field | ConvertTo-Json -Depth 50 -Compress) -ceq ($source.$field | ConvertTo-Json -Depth 50 -Compress)) "V3 policy projection drift: $field."
}
Assert (($policy.sharedPrimitiveProjects | ConvertTo-Json -Depth 20 -Compress) -ceq
    ($g03.sharedPrimitiveProjects | ConvertTo-Json -Depth 20 -Compress)) 'G03 primitive projection drift.'
Assert ($rulePlan.moduleId -ceq $manifest.id -and $rulePlan.matrixSha256 -ceq (Hash $policyPath) -and
    @($rulePlan.rules).Count -eq 12 -and @($rulePlan.rules | Where-Object { $_.stage -cne 'pre' -or $_.detectors -notcontains $manifest.id }).Count -eq 0) 'Rule plan drift.'
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
    $raw | ConvertFrom-Json -Depth 40
}
function Make-Fixture([string] $Root, $Case) {
    [void][IO.Directory]::CreateDirectory($Root)
    if (Has-Flag $Case 'missingSrc') { return }
    foreach ($name in @('IFX.Modules.CRM.Domain','IFX.Modules.CRM.Application','IFX.Modules.CRM.Infrastructure','IFX.Modules.CRM.Contracts')) {
        $body = if ((Has-Flag $Case 'malformedProject') -and $name -ceq 'IFX.Modules.CRM.Domain') { '<Project><' } else { '<Project Sdk="Microsoft.NET.Sdk" />' }
        Write-Text (Join-Path $Root "src/$name/$name.csproj") $body
    }
    if (Has-Flag $Case 'zeroSource') { return }
    if (Has-Flag $Case 'zeroClaim') {
        Write-Text (Join-Path $Root 'src/IFX.Modules.CRM.Application/Only.cs') 'namespace IFX.Modules.CRM.Application { class Only {} }'
        return
    }
    $baseFiles = [ordered]@{
        'src/IFX.Modules.CRM.Domain/IAccountRepository.cs' = 'namespace IFX.Modules.CRM.Domain { public interface IAccountRepository {} }'
        'src/IFX.Modules.CRM.Application/IAccountPort.cs' = 'using IFX.Modules.CRM.Domain; using MediatR; namespace IFX.Modules.CRM.Application.Ports { public interface IAccountPort {} }'
        'src/IFX.Modules.CRM.Infrastructure/AccountRepository.cs' = 'using IFX.Modules.CRM.Domain; namespace IFX.Modules.CRM.Infrastructure { public class AccountRepository : IAccountRepository {} }'
        'src/IFX.Modules.CRM.Contracts/IAccountContract.cs' = 'namespace IFX.Modules.CRM.Contracts { public interface IAccountContract {} }'
        'src/IFX.Modules.CRM.Contracts/AccountIntegrationEvent.cs' = 'namespace IFX.Modules.CRM.Contracts.Events { public record AccountIntegrationEvent(Guid Id); }'
    }
    foreach ($entry in $baseFiles.GetEnumerator()) { Write-Text (Join-Path $Root $entry.Key) $entry.Value }
    if ($null -ne $Case.PSObject.Properties['projects']) {
        foreach ($relative in $Case.projects) { Write-Text (Join-Path $Root $relative) '<Project Sdk="Microsoft.NET.Sdk" />' }
    }
    if ($null -ne $Case.PSObject.Properties['files']) {
        foreach ($file in $Case.files) { Write-Text (Join-Path $Root $file.path) $file.text }
    }
}

$fixtures = Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 40
Assert ($fixtures.formatVersion -eq 1 -and @($fixtures.cases).Count -eq 24) 'Fixture catalog drift.'
foreach ($case in $fixtures.cases) {
    $target = Join-Path $runRoot $case.id
    Make-Fixture $target $case
    $before = Inventory $target
    $result = Invoke-Adapter $target $config
    $expectedStatus = if ($null -ne $case.PSObject.Properties['expectedStatus']) { $case.expectedStatus } elseif (@($case.expectedRules | Where-Object { $_ -notmatch 'ADVISORY|RING-PACKAGE-IMPORT' }).Count -gt 0) { 'fail' } else { 'pass' }
    Assert ($result.status -ceq $expectedStatus) "Fixture status mismatch: $($case.id): $($result | ConvertTo-Json -Compress -Depth 8)."
    if ($null -ne $case.PSObject.Properties['expectedCategory']) {
        Assert ($result.exitCategory -ceq $case.expectedCategory) "Fixture category mismatch: $($case.id)."
    }
    if ($null -ne $case.PSObject.Properties['expectedRules']) {
        $actualRules = @($result.findings | ForEach-Object ruleId | Sort-Object -Unique)
        $expectedRules = @($case.expectedRules | Sort-Object -Unique)
        Assert (($actualRules -join ',') -ceq ($expectedRules -join ',')) "Fixture rule mismatch: $($case.id): $($actualRules -join ',')."
        Assert (@($result.coverage | Where-Object matched -lt 1).Count -eq 0) "Fixture vacuous coverage: $($case.id)."
    }
    if ($case.id -ceq 'clean') {
        $repeat = Invoke-Adapter $target $config
        Assert (($repeat | ConvertTo-Json -Depth 40 -Compress) -ceq ($result | ConvertTo-Json -Depth 40 -Compress)) 'Clean fixture result is not deterministic.'
    }
    Assert ((Inventory $target) -ceq $before) "Adapter changed TargetRoot: $($case.id)."
}
$unsafe = Join-Path $runRoot 'unsafe-link'
Make-Fixture $unsafe $fixtures.cases[0]
$link = Join-Path $unsafe 'src/linked-project'
$linkTarget = Join-Path $unsafe 'src/IFX.Modules.CRM.Contracts'
if ($IsWindows) { [void](New-Item -ItemType Junction -Path $link -Target $linkTarget) }
else { [void](New-Item -ItemType SymbolicLink -Path $link -Target $linkTarget) }
$unsafeBefore = Inventory $unsafe
$unsafeResult = Invoke-Adapter $unsafe $config
Assert ($unsafeResult.status -ceq 'error' -and $unsafeResult.exitCategory -ceq 'unsafe-path') 'Linked source inventory was not blocked.'
Assert ((Inventory $unsafe) -ceq $unsafeBefore) 'Unsafe-path test changed TargetRoot.'
$drift = Invoke-Adapter (Join-Path $runRoot 'clean') ([ordered]@{ enabledClaims = @($policy.claims); policySha256 = ('0' * 64) })
Assert ($drift.status -ceq 'error' -and $drift.exitCategory -ceq 'integrity-failure') 'Policy hash drift was not blocked.'
$realBefore = Inventory (Join-Path $repoRoot 'src')
$real = Invoke-Adapter $repoRoot $config
$realAfter = Inventory (Join-Path $repoRoot 'src')
Assert ($realBefore -ceq $realAfter -and $real.status -in @('pass','fail') -and
    @($real.coverage | Where-Object matched -lt 1).Count -eq 0) 'Real IFX scan is vacuous, mutating or errored.'
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
    $bundleModuleRoot = Join-Path $bundlePackage 'modules/ifx-source-policy'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModuleRoot))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModuleRoot -Recurse
    $profileId = 'ifx_c1h_fixture'
    $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    $profile = [ordered]@{
        formatVersion = 1; id = $profileId; version = '0.1.0'
        projectIdentity = [ordered]@{ id = 'ifx-c1h-fixture'; relativeRoots = @('src') }
        moduleSelections = @([ordered]@{ id = 'ifx-source-policy'; versionRange = '>=0.1.0 <1.0.0'; config = $config })
        stageConfiguration = [ordered]@{
            bootstrap = [ordered]@{ enabled = $false; modules = @() }
            analysis = [ordered]@{ enabled = $false; modules = @() }
            pre = [ordered]@{ enabled = $true; modules = @('ifx-source-policy') }
            post = [ordered]@{ enabled = $false; modules = @() }
        }
        rules = @($rulePlan.rules | ForEach-Object ruleId)
        baselineRefs = @()
    }
    Write-Json $profilePath $profile
    $bundleFiles = @(Get-ChildItem $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\','/'); sha256 = Hash $_.FullName; size = $_.Length }
    })
    $ceiling = [ordered]@{ readRoots = @('PackageRoot','TargetRoot'); writeRoots = @(); processes = @('pwsh','dotnet'); network = $false; maxTimeoutSeconds = 180 }
    $bundleManifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $bundleManifestPath ([ordered]@{
        formatVersion = 1; id = 'ifx-c1h-synthetic-extension'; version = '0.1.0'; compatibleApi = '1.x'; baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = 'ifx-source-policy'; version = '0.1.0'; manifestPath = 'modules/ifx-source-policy/module.json'; manifestSha256 = Hash (Join-Path $bundleModuleRoot 'module.json'); allowedCapabilities = $ceiling })
        files = $bundleFiles
    })
    $reviewPath = Join-Path $runRoot 'synthetic-review.json'
    Write-Json $reviewPath ([ordered]@{
        formatVersion = 1; id = '20260924-ifx-c1h-synthetic-fixture'; scope = 'synthetic-test-only'; decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-c1h-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $bundleManifestPath; baseArchiveSha256 = $baseReceipt.archiveSha256
        moduleCeilings = @([ordered]@{ moduleId = 'ifx-source-policy'; allowedCapabilities = $ceiling })
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
        [ordered]@{ id = 'clean'; status = 'pass' },
        [ordered]@{ id = 'import-direction'; status = 'fail' },
        [ordered]@{ id = 'package-forbidden'; status = 'fail' },
        [ordered]@{ id = 'package-advisory'; status = 'advisory' },
        [ordered]@{ id = 'declaration-namespace'; status = 'fail' },
        [ordered]@{ id = 'declaration-implements'; status = 'advisory' },
        [ordered]@{ id = 'symbol-name'; status = 'fail' },
        [ordered]@{ id = 'payload-forbidden'; status = 'fail' },
        [ordered]@{ id = 'zero-claim'; status = 'fail' }
    )) {
        $target = Join-Path $runRoot $hostCase.id
        $state = Join-Path $runRoot "host-state-$($hostCase.id)"
        $evidence = Join-Path $runRoot "host-evidence-$($hostCase.id)"
        foreach ($path in @($state,$evidence)) { [void][IO.Directory]::CreateDirectory($path) }
        $before = Inventory $target
        $hostOutput = @(& dotnet $hostDll stage run --stage pre --package-root (Join-Path $composed 'package') --target-root $target --state-root $state --evidence-root $evidence --profile $profileId 2>&1)
        $raw = $hostOutput -join "`n"
        $hostResult = $raw | ConvertFrom-Json -Depth 40
        Assert ($hostResult.status -ceq $hostCase.status) "Synthetic Host mismatch: $($hostCase.id): $raw"
        Assert ((Inventory $target) -ceq $before) "Synthetic Host changed TargetRoot: $($hostCase.id)."
    }
    Write-Output "Published Host synthetic composition and nine Pre cases passed. Receipt: $compositionReceiptPath"
}
Write-Output "C1h fixtures and real IFX scan passed; real status=$($real.status), findings=$(@($real.findings).Count). Evidence: $runRoot"
