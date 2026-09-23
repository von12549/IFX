[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c2c2/test-runs',
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
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-g03-snapshots'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'; $policyPath = Join-Path $moduleRoot 'policy.json'
$manifestPath = Join-Path $moduleRoot 'module.json'; $resultSchemaPath = Join-Path $moduleRoot 'result.schema.json'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 50
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json -Depth 50
$rulePlan = Get-Content (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 50
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $repoRoot 'docs/guards/V4/core/contracts/module.schema.json') -ErrorAction SilentlyContinue) 'Module manifest schema failed.'
Assert ($manifest.id -ceq 'ifx-g03-snapshots' -and ($manifest.stages -join ',') -ceq 'post' -and
    ($manifest.capabilities.readRoots -join ',') -ceq 'PackageRoot,TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and
    ($manifest.capabilities.processes -join ',') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false -and
    $manifest.capabilities.timeoutSeconds -eq 60) 'Module identity or capabilities drift.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256 -and
    (Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Adapter or dependency hash drift.'
foreach ($authority in $manifest.authorities) { Assert ((Hash (Join-Path $candidateRoot $authority.path)) -ceq $authority.sha256) "Authority hash drift: $($authority.id)." }
foreach ($source in $policy.sourceScripts) { Assert ((Hash (Join-Path $repoRoot $source.path)) -ceq $source.sha256) "V3 source hash drift: $($source.path)." }
foreach ($pair in @(@($policy.catalogPath,$policy.sourceCatalogSha256),@($policy.apiSnapshotPath,$policy.sourceApiSnapshotSha256),@($policy.serializationSnapshotPath,$policy.sourceSerializationSnapshotSha256))) {
    Assert ((Hash (Join-Path $repoRoot $pair[0])) -ceq $pair[1]) "Current G03 authority hash drift: $($pair[0])."
}
Assert ($rulePlan.moduleId -ceq $manifest.id -and $rulePlan.matrixSha256 -ceq (Hash $policyPath) -and
    @($rulePlan.rules).Count -eq 2 -and @($rulePlan.rules | Where-Object stage -eq 'post').Count -eq 2) 'Rule execution plan drift.'
$claims = @('IFX.C2.G03_SYNC_API_SNAPSHOT','IFX.C2.G03_SERIALIZATION_SNAPSHOT')
$baseConfig = [ordered]@{
    enabledClaims = $claims; policySha256 = Hash $policyPath
    catalogSha256 = Hash (Join-Path $repoRoot $policy.catalogPath)
    apiSnapshotSha256 = Hash (Join-Path $repoRoot $policy.apiSnapshotPath)
    serializationSnapshotSha256 = Hash (Join-Path $repoRoot $policy.serializationSnapshotPath)
}
Assert (Test-Json -Json ($baseConfig | ConvertTo-Json -Depth 10 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction SilentlyContinue) 'Config schema failed.'
$evidence = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repoRoot $EvidenceRoot }
$runRoot = Join-Path $evidence ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)
$catalog = Get-Content (Join-Path $repoRoot $policy.catalogPath) -Raw | ConvertFrom-Json -Depth 100
$sourceFiles = [Collections.Generic.List[string]]::new()
foreach ($protocol in @($catalog.protocols | Where-Object kind -eq 'sync')) {
    $typeFile = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Recurse -File -Filter "$($protocol.source.type).cs" | Where-Object {
        $_.FullName -notmatch '[\\/](bin|obj)[\\/]' -and $_.FullName -like "*$($protocol.source.project)*"
    })
    Assert ($typeFile.Count -eq 1) "Cannot identify sync type source: $($protocol.identity)."
    $sourceFiles.Add($typeFile[0].FullName)
    $project = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'src') -Recurse -File -Filter "$($protocol.source.project).csproj" | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' })
    Assert ($project.Count -eq 1) "Cannot identify sync project: $($protocol.identity)."
    $sourceFiles.Add($project[0].FullName)
}
$baseSource = Join-Path $runRoot 'base-source'
foreach ($file in @($sourceFiles.ToArray() | Sort-Object -Unique)) {
    $destination = Join-Path $baseSource ([IO.Path]::GetRelativePath($repoRoot, $file))
    [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($destination)))
    Copy-Item -LiteralPath $file -Destination $destination
}
function Invoke-Adapter([string] $Target, $Selection) {
    $payload = [ordered]@{
        formatVersion = 1; stage = 'post'; targetRoot = $Target; packageRoot = $candidateRoot
        stateRoot = Join-Path $runRoot 'state'; evidenceRoot = Join-Path $runRoot 'evidence'
        projectId = 'ifx'; relativeRoots = @('src','docs'); config = $Selection
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
    [void][IO.Directory]::CreateDirectory($target)
    if ($Mutation -eq 'zero-source') { [void][IO.Directory]::CreateDirectory((Join-Path $target 'src')) }
    else { Copy-Item -LiteralPath (Join-Path $baseSource 'src') -Destination (Join-Path $target 'src') -Recurse }
    foreach ($path in @($policy.catalogPath,$policy.apiSnapshotPath,$policy.serializationSnapshotPath)) {
        $destination = Join-Path $target $path
        [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($destination)))
        Copy-Item -LiteralPath (Join-Path $repoRoot $path) -Destination $destination
    }
    $catalogPath = Join-Path $target $policy.catalogPath
    $apiPath = Join-Path $target $policy.apiSnapshotPath
    $serializationPath = Join-Path $target $policy.serializationSnapshotPath
    switch ($Mutation) {
        'none' { }
        'generated-ignored' { Write-Text (Join-Path $target 'src/Modules/Fake/obj/Poison.cs') 'public interface Poison { Task<int> PingAsync(); }' }
        'signature-drift' {
            $path = Join-Path $target ([IO.Path]::GetRelativePath($repoRoot, $sourceFiles[0]))
            Write-Text $path ([IO.File]::ReadAllText($path).Replace('Task<','Task<Drift'))
        }
        'api-field-drift' { $value = Get-Content $apiPath -Raw | ConvertFrom-Json -Depth 100; $value.protocols[0].fields[0].name = 'tampered'; Write-Json $apiPath $value }
        'serialization-field-drift' { $value = Get-Content $serializationPath -Raw | ConvertFrom-Json -Depth 100; $value.schemas[0].fields[0].name = 'tampered'; Write-Json $serializationPath $value }
        'catalog-lifecycle-drift' { $value = Get-Content $catalogPath -Raw | ConvertFrom-Json -Depth 100; $value.protocols[0].lifecycle = 'Drift'; Write-Json $catalogPath $value }
        'missing-sync-source' { $path = Join-Path $target ([IO.Path]::GetRelativePath($repoRoot, $sourceFiles[0])); Write-Text $path '// declaration intentionally absent' }
        'zero-source' { }
        'zero-protocol' { $value = Get-Content $catalogPath -Raw | ConvertFrom-Json -Depth 100; $value.protocols = @(); Write-Json $catalogPath $value }
        'zero-sync' { $value = Get-Content $catalogPath -Raw | ConvertFrom-Json -Depth 100; $value.protocols = @($value.protocols | Where-Object kind -eq 'event'); Write-Json $catalogPath $value }
        'missing-catalog' { [IO.File]::Delete($catalogPath) }
        'missing-api' { [IO.File]::Delete($apiPath) }
        'missing-serialization' { [IO.File]::Delete($serializationPath) }
        'malformed-catalog' { Write-Text $catalogPath '{' }
        'malformed-api' { Write-Text $apiPath '{' }
        'malformed-serialization' { Write-Text $serializationPath '{' }
        default { throw "Unknown mutation: $Mutation" }
    }
    $config = [ordered]@{ enabledClaims = $claims; policySha256 = Hash $policyPath
        catalogSha256 = $baseConfig.catalogSha256; apiSnapshotSha256 = $baseConfig.apiSnapshotSha256
        serializationSnapshotSha256 = $baseConfig.serializationSnapshotSha256 }
    if ([IO.File]::Exists($catalogPath)) { $config.catalogSha256 = Hash $catalogPath }
    if ([IO.File]::Exists($apiPath)) { $config.apiSnapshotSha256 = Hash $apiPath }
    if ([IO.File]::Exists($serializationPath)) { $config.serializationSnapshotSha256 = Hash $serializationPath }
    return [pscustomobject]@{ target = $target; config = $config }
}
$fixtures = Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 30
Assert ($fixtures.formatVersion -eq 1 -and @($fixtures.cases).Count -eq 16) 'Fixture catalog drift.'
foreach ($case in $fixtures.cases) {
    $fixture = Create-Case $case.id $case.mutation
    $before = Inventory $fixture.target
    $result = Invoke-Adapter $fixture.target $fixture.config
    Assert ((Inventory $fixture.target) -ceq $before) "TargetRoot changed: $($case.id)."
    Assert ($result.status -ceq $case.status) "Fixture status mismatch $($case.id): $($result | ConvertTo-Json -Depth 10 -Compress)"
    if ($null -ne $case.PSObject.Properties['category']) { Assert ($result.exitCategory -ceq $case.category) "Fixture category mismatch: $($case.id)." }
    if ($null -ne $case.PSObject.Properties['code']) { Assert (@($result.findings | Where-Object { $_.subject -like "$($case.code):*" }).Count -gt 0) "Expected $($case.code): $($case.id)." }
    if ($case.id -in @('clean','generated-ignored','signature-drift')) {
        $repeat = Invoke-Adapter $fixture.target $fixture.config
        Assert (($repeat | ConvertTo-Json -Depth 50 -Compress) -ceq ($result | ConvertTo-Json -Depth 50 -Compress)) "Nondeterministic result: $($case.id)."
    }
}
foreach ($key in @('policySha256','catalogSha256','apiSnapshotSha256','serializationSnapshotSha256')) {
    $fixture = Create-Case "hash-drift-$key" 'none'
    $fixture.config[$key] = '0' * 64
    $drift = Invoke-Adapter $fixture.target $fixture.config
    Assert ($drift.status -ceq 'error' -and $drift.exitCategory -ceq 'integrity-failure') "Hash drift did not block: $key."
}
$linkedTarget = Join-Path $runRoot 'linked-source'
[void][IO.Directory]::CreateDirectory($linkedTarget)
foreach ($path in @($policy.catalogPath,$policy.apiSnapshotPath,$policy.serializationSnapshotPath)) {
    $destination = Join-Path $linkedTarget $path
    [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($destination)))
    Copy-Item -LiteralPath (Join-Path $repoRoot $path) -Destination $destination
}
if ($IsWindows) { [void](New-Item -ItemType Junction -Path (Join-Path $linkedTarget 'src') -Target (Join-Path $repoRoot 'src')) }
else { [void](New-Item -ItemType SymbolicLink -Path (Join-Path $linkedTarget 'src') -Target (Join-Path $repoRoot 'src')) }
$unsafe = Invoke-Adapter $linkedTarget $baseConfig
Assert ($unsafe.status -ceq 'error' -and $unsafe.exitCategory -ceq 'unsafe-path') 'Linked source did not block.'
$beforeReal = Inventory (Join-Path $repoRoot 'src')
$real = Invoke-Adapter $repoRoot $baseConfig
Assert ($real.status -ceq 'pass' -and @($real.coverage | Where-Object { $_.matched -gt 0 }).Count -eq 2 -and
    (Inventory (Join-Path $repoRoot 'src')) -ceq $beforeReal) 'Real IFX scan failed or changed TargetRoot.'

$provided = @($BaseInstallRoot, $BaseReceiptPath, $BaseArchivePath | Where-Object { $_ })
Assert ($provided.Count -eq 0 -or $provided.Count -eq 3) 'Provide all three published-base paths or none.'
if ($provided.Count -eq 3) {
    $baseCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repoRoot 'docs/guards/candidates/ifx-gate-coverage-c1i/Test-PublishedV4Base.ps1') -ArchivePath $BaseArchivePath -ReceiptPath $BaseReceiptPath -InstallRoot $BaseInstallRoot | ConvertFrom-Json
    Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass') 'Published base identity check failed.'
    $hostFixture = Create-Case 'host-clean' 'none'
    $bundleRoot = Join-Path $runRoot 'bundle'; $bundlePackage = Join-Path $bundleRoot 'package'
    $bundleModuleRoot = Join-Path $bundlePackage 'modules/ifx-g03-snapshots'
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModuleRoot))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModuleRoot -Recurse
    $profileId = 'ifx_c2c2_fixture'; $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    Write-Json $profilePath ([ordered]@{
        formatVersion = 1; id = $profileId; version = '0.1.0'
        projectIdentity = [ordered]@{ id = 'ifx-c2c2-fixture'; relativeRoots = @('src','docs') }
        moduleSelections = @([ordered]@{ id = 'ifx-g03-snapshots'; versionRange = '>=0.1.0 <1.0.0'; config = $hostFixture.config })
        stageConfiguration = [ordered]@{
            bootstrap = [ordered]@{ enabled = $false; modules = @() }
            analysis = [ordered]@{ enabled = $false; modules = @() }
            pre = [ordered]@{ enabled = $false; modules = @() }
            post = [ordered]@{ enabled = $true; modules = @('ifx-g03-snapshots') }
        }
        rules = @('G03-SYNC-API-SNAPSHOT','G03-SERIALIZATION-SNAPSHOT'); baselineRefs = @()
    })
    $bundleFiles = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\','/'); sha256 = Hash $_.FullName; size = $_.Length }
    })
    $ceiling = [ordered]@{ readRoots = @('PackageRoot','TargetRoot'); writeRoots = @(); processes = @('pwsh'); network = $false; maxTimeoutSeconds = 60 }
    $bundleManifestPath = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-Json $bundleManifestPath ([ordered]@{
        formatVersion = 1; id = 'ifx-c2c2-synthetic-extension'; version = '0.1.0'; compatibleApi = '1.x'; baseVersion = '1.1.2'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = 'ifx-g03-snapshots'; version = '0.1.0'; manifestPath = 'modules/ifx-g03-snapshots/module.json'; manifestSha256 = Hash (Join-Path $bundleModuleRoot 'module.json'); allowedCapabilities = $ceiling })
        files = $bundleFiles
    })
    $reviewPath = Join-Path $runRoot 'synthetic-review.json'
    Write-Json $reviewPath ([ordered]@{
        formatVersion = 1; id = '20260924-ifx-c2c2-synthetic-fixture'; scope = 'synthetic-test-only'; decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-c2c2-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $bundleManifestPath; baseArchiveSha256 = $baseCheck.archiveSha256
        moduleCeilings = @([ordered]@{ moduleId = 'ifx-g03-snapshots'; allowedCapabilities = $ceiling })
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
        @($hostResult.coverage | Where-Object { $_.matched -gt 0 }).Count -eq 2 -and
        (Inventory $hostFixture.target) -ceq $beforeHost) "Host Post mismatch: $($hostOutput -join "`n")"
}
Write-Output "IFX C2c2 passed $(@($fixtures.cases).Count) fixtures and controls; real G03 snapshot parity passed. Evidence: $runRoot"
