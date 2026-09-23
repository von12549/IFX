[CmdletBinding()]
param(
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c3b/test-runs',
    [string] $BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string] $BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string] $BaseArchivePath = 'artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Write-Text([string] $Path, [string] $Body) {
    [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($Path)))
    [IO.File]::WriteAllText($Path, $Body, [Text.UTF8Encoding]::new($false))
}
function Write-Json([string] $Path, $Value) { Write-Text $Path (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n") }
function Inventory([string] $Root) {
    return (@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"
    }) -join "`n")
}
$candidateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$moduleRoot = Join-Path $candidateRoot 'modules/ifx-g04-manifests'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'
$policyPath = Join-Path $moduleRoot 'policy.json'
$manifestPath = Join-Path $moduleRoot 'module.json'
$policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -AsHashtable -Depth 100
$basePackage = Join-Path $BaseInstallRoot 'package'
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $basePackage 'core/contracts/module.schema.json') -ErrorAction SilentlyContinue) 'Module schema failure.'
Assert ($manifest.id -ceq 'ifx-g04-manifests' -and ($manifest.stages -join ',') -ceq 'post' -and
    ($manifest.capabilities.readRoots -join ',') -ceq 'PackageRoot,TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and
    ($manifest.capabilities.processes -join ',') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false -and
    $manifest.capabilities.timeoutSeconds -eq 45) 'Module identity/capability drift.'
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256) 'Adapter hash drift.'
Assert ((Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Dependency hash drift.'
foreach ($authority in $manifest.authorities) { Assert ((Hash (Join-Path $candidateRoot $authority.path)) -ceq $authority.sha256) "Module authority drift: $($authority.id)" }
$rulePlan = Get-Content (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
Assert ($rulePlan.moduleId -ceq $manifest.id -and @($rulePlan.rules).Count -eq 4 -and @($rulePlan.rules | Where-Object { $_.stage -eq 'post' -and $_.severity -eq 'blocking' -and $_.minimumMatches -eq 1 }).Count -eq 4) 'Rule Plan drift.'
$baseCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage | ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass' -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published 1.1.3 Package identity drift.'
Assert ((Get-Content $BaseReceiptPath -Raw | ConvertFrom-Json).version -ceq '1.1.3') 'Installed receipt version drift.'
$archivePath = if ([IO.Path]::IsPathFullyQualified($BaseArchivePath)) { $BaseArchivePath } else { Join-Path $repoRoot $BaseArchivePath }
Assert ([IO.File]::Exists($archivePath) -and (Hash $archivePath) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive digest drift.'
Assert ((Get-Content $BaseReceiptPath -Raw | ConvertFrom-Json).archiveSha256 -ceq (Hash $archivePath)) 'Receipt/archive digest mismatch.'

$runRoot = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repoRoot $EvidenceRoot }
$runRoot = Join-Path $runRoot ([Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)
$config = [ordered]@{
    enabledClaims = @($policy.claims)
    policySha256 = Hash $policyPath
    authorityHashes = @($policy.authorities | ForEach-Object { [ordered]@{ id=$_.id; sha256=Hash (Join-Path $repoRoot $_.path) } })
}
Assert (Test-Json -Json ($config | ConvertTo-Json -Depth 20 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction Stop) 'Config schema failure.'
function Invoke-Adapter([string] $Target, $Configuration) {
    $request = [ordered]@{ formatVersion=1; stage='post'; targetRoot=$Target; relativeRoots=@('src','deployment','docs'); config=$Configuration }
    $env:V4_STAGE_INPUT_JSON = $request | ConvertTo-Json -Depth 30 -Compress
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapterPath 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Adapter process failed: $($output -join "`n")"
    return (($output -join "`n") | ConvertFrom-Json -Depth 100)
}
function New-Case([string] $Id, [string] $Mutation) {
    $target = Join-Path $runRoot "target-$Id"
    [void][IO.Directory]::CreateDirectory($target)
    foreach ($authority in $policy.authorities) {
        $destination = Join-Path $target $authority.path
        [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($destination)))
        [IO.File]::WriteAllBytes($destination, [IO.File]::ReadAllBytes((Join-Path $repoRoot $authority.path)))
    }
    $localConfig = $config | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
    $selected = $null
    switch ($Mutation) {
        'none' {}
        'stale-release' { $selected='runtime-release'; $path=Join-Path $target 'deployment/g04/release-runtime-manifest.json'; [IO.File]::AppendAllText($path,' ') }
        'missing-release' { Remove-Item -LiteralPath (Join-Path $target 'deployment/g04/release-runtime-manifest.json') }
        'malformed-release' { $selected='runtime-release'; Write-Text (Join-Path $target 'deployment/g04/release-runtime-manifest.json') '{' }
        'zero-modules' { $selected='module-manifest'; $j=Get-Content (Join-Path $target 'deployment/g04/module-manifest.json') -Raw | ConvertFrom-Json -AsHashtable; $j.modules=@(); Write-Json (Join-Path $target 'deployment/g04/module-manifest.json') $j }
        'duplicate-module' { $selected='module-manifest'; $j=Get-Content (Join-Path $target 'deployment/g04/module-manifest.json') -Raw | ConvertFrom-Json -AsHashtable; $j.modules=@($j.modules)+@($j.modules[0]); Write-Json (Join-Path $target 'deployment/g04/module-manifest.json') $j }
        'zero-units' { $selected='deployment-units'; $j=Get-Content (Join-Path $target 'deployment/g04/deployment-unit-catalog.json') -Raw | ConvertFrom-Json -AsHashtable; $j.units=@(); Write-Json (Join-Path $target 'deployment/g04/deployment-unit-catalog.json') $j }
        'split-artifact' { $selected='deployment-units'; $j=Get-Content (Join-Path $target 'deployment/g04/deployment-unit-catalog.json') -Raw | ConvertFrom-Json -AsHashtable; (@($j.units | Where-Object unitId -eq 'ifx-worker'))[0].artifact='different-host'; Write-Json (Join-Path $target 'deployment/g04/deployment-unit-catalog.json') $j }
        'wrong-binding-hash' { $selected='runtime-release'; $j=Get-Content (Join-Path $target 'deployment/g04/release-runtime-manifest.json') -Raw | ConvertFrom-Json -AsHashtable; $j.bindings.moduleManifest.sha256='0'*64; Write-Json (Join-Path $target 'deployment/g04/release-runtime-manifest.json') $j }
        'missing-binding' { $selected='runtime-release'; $j=Get-Content (Join-Path $target 'deployment/g04/release-runtime-manifest.json') -Raw | ConvertFrom-Json -AsHashtable; [void]$j.bindings.Remove('failureMatrix'); Write-Json (Join-Path $target 'deployment/g04/release-runtime-manifest.json') $j }
        'schema-contract' { $selected='runtime-release'; $j=Get-Content (Join-Path $target 'deployment/g04/release-runtime-manifest.json') -Raw | ConvertFrom-Json -AsHashtable; $j.schemaCompatibility.policy='unsafe'; Write-Json (Join-Path $target 'deployment/g04/release-runtime-manifest.json') $j }
        'bad-stage-order' { $selected='release-orchestration'; $j=Get-Content (Join-Path $target 'deployment/g04/release-orchestration.json') -Raw | ConvertFrom-Json -AsHashtable; $j.stages=@($j.stages | Sort-Object stageId -Descending); Write-Json (Join-Path $target 'deployment/g04/release-orchestration.json') $j }
        'bad-threshold' { $selected='backpressure-policy'; $j=Get-Content (Join-Path $target 'deployment/g04/backpressure-policy.json') -Raw | ConvertFrom-Json -AsHashtable; $j.thresholds.warningCount=99999; Write-Json (Join-Path $target 'deployment/g04/backpressure-policy.json') $j }
        'auto-down' { $selected='failure-matrix'; $j=Get-Content (Join-Path $target 'deployment/g04/failure-matrix.json') -Raw | ConvertFrom-Json -AsHashtable; foreach($s in $j.scenarios){$s.prohibitions=@($s.prohibitions | Where-Object { $_ -ne 'automatic-down' })}; Write-Json (Join-Path $target 'deployment/g04/failure-matrix.json') $j }
        'zero-scenarios' { $selected='failure-matrix'; $j=Get-Content (Join-Path $target 'deployment/g04/failure-matrix.json') -Raw | ConvertFrom-Json -AsHashtable; $j.scenarios=@(); Write-Json (Join-Path $target 'deployment/g04/failure-matrix.json') $j }
        'missing-business-module' { $selected='source-program'; $path=Join-Path $target 'src/ApiHost/IFX.ApiHost/Program.cs'; $body=[IO.File]::ReadAllText($path).Replace('AddCrmModule','AddMissingModule'); Write-Text $path $body }
        default { throw "Unknown fixture mutation: $Mutation" }
    }
    if ($selected -and $Mutation -notin @('stale-release','missing-release')) {
        $authority = $policy.authorities | Where-Object id -eq $selected | Select-Object -First 1
        ($localConfig.authorityHashes | Where-Object id -eq $selected | Select-Object -First 1).sha256 = Hash (Join-Path $target $authority.path)
    }
    return [pscustomobject]@{ target=$target; config=$localConfig }
}
$fixtures = Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 30
Assert ($fixtures.formatVersion -eq 1 -and @($fixtures.cases).Count -eq 16) 'Fixture catalog drift.'
$results = @()
foreach ($case in $fixtures.cases) {
    $fixture = New-Case $case.id $case.mutation
    $before = Inventory $fixture.target
    $result = Invoke-Adapter $fixture.target $fixture.config
    Assert ((Inventory $fixture.target) -ceq $before) "TargetRoot changed: $($case.id)"
    Assert ($result.status -ceq $case.status -and $result.exitCategory -ceq $case.category) "Fixture mismatch $($case.id): $($result | ConvertTo-Json -Depth 15 -Compress)"
    Assert (Test-Json -Json ($result | ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $moduleRoot 'result.schema.json') -ErrorAction Stop) "Result schema failed: $($case.id)"
    if ($case.id -in @('clean','zero-modules','bad-stage-order')) {
        $repeat = Invoke-Adapter $fixture.target $fixture.config
        Assert (($repeat | ConvertTo-Json -Depth 50 -Compress) -ceq ($result | ConvertTo-Json -Depth 50 -Compress)) "Nondeterministic result: $($case.id)"
    }
    if ($case.status -ceq 'pass') { Assert (@($result.coverage | Where-Object { $_.matched -lt 1 }).Count -eq 0) 'Clean fixture has zero-match claim.' }
    $results += [ordered]@{ id=$case.id; status=$result.status; category=$result.exitCategory }
}
$beforeReal = @($policy.authorities | ForEach-Object { "$($_.id)|$(Hash (Join-Path $repoRoot $_.path))" }) -join "`n"
$real = Invoke-Adapter $repoRoot $config
$afterReal = @($policy.authorities | ForEach-Object { "$($_.id)|$(Hash (Join-Path $repoRoot $_.path))" }) -join "`n"
Assert ($real.status -ceq 'pass' -and $real.exitCategory -ceq 'success' -and $beforeReal -ceq $afterReal) 'Real IFX direct candidate or TargetRoot invariant failed.'
$hostFixture = New-Case 'host-clean' 'none'
$bundleRoot = Join-Path $runRoot 'bundle'; $bundlePackage = Join-Path $bundleRoot 'package'
$bundleModule = Join-Path $bundlePackage 'modules/ifx-g04-manifests'
[void][IO.Directory]::CreateDirectory((Split-Path -Parent $bundleModule))
Copy-Item -LiteralPath $moduleRoot -Destination $bundleModule -Recurse
$profileId = 'ifx_c3b_fixture'
$profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
Write-Json $profilePath ([ordered]@{
    formatVersion=1; id=$profileId; version='0.1.0'
    projectIdentity=[ordered]@{ id='ifx-c3b-fixture'; relativeRoots=@('src','deployment','docs') }
    moduleSelections=@([ordered]@{ id='ifx-g04-manifests'; versionRange='>=0.1.0 <1.0.0'; config=$hostFixture.config })
    stageConfiguration=[ordered]@{
        bootstrap=[ordered]@{ enabled=$false; modules=@() }; analysis=[ordered]@{ enabled=$false; modules=@() }
        pre=[ordered]@{ enabled=$false; modules=@() }; post=[ordered]@{ enabled=$true; modules=@('ifx-g04-manifests') }
    }
    rules=@('G04-INVENTORY','G04-MANIFEST','G04-ORCHESTRATION','G04-FAILURE-POLICY'); baselineRefs=@()
})
$bundleFiles = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path=[IO.Path]::GetRelativePath($bundlePackage,$_.FullName).Replace('\','/'); sha256=Hash $_.FullName; size=$_.Length }
})
$ceiling = [ordered]@{ readRoots=@('PackageRoot','TargetRoot'); writeRoots=@(); processes=@('pwsh'); network=$false; maxTimeoutSeconds=45 }
$bundleManifest = Join-Path $bundleRoot 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{
    formatVersion=1; id='ifx-c3b-synthetic-extension'; version='0.1.0'; compatibleApi='1.x'; baseVersion='1.1.3'
    profiles=@([ordered]@{ id=$profileId; version='0.1.0'; path="profiles/catalog/$profileId/profile.json"; sha256=Hash $profilePath })
    modules=@([ordered]@{ id='ifx-g04-manifests'; version='0.1.0'; manifestPath='modules/ifx-g04-manifests/module.json'; manifestSha256=Hash (Join-Path $bundleModule 'module.json'); allowedCapabilities=$ceiling })
    files=$bundleFiles
})
$reviewPath = Join-Path $runRoot 'synthetic-review.json'
Write-Json $reviewPath ([ordered]@{
    formatVersion=1; id='20260924-ifx-c3b-synthetic-fixture'; scope='synthetic-test-only'; decision='accepted'
    acceptedBy=[ordered]@{ authorityType='test-fixture'; authorityId='ifx-c3b-synthetic-fixture'; candidateHostVerdictAllowed=$false }
    bundleManifestSha256=Hash $bundleManifest; baseArchiveSha256=Hash $archivePath
    moduleCeilings=@([ordered]@{ moduleId='ifx-g04-manifests'; allowedCapabilities=$ceiling })
})
$composed = Join-Path $runRoot 'composed'; $receipt=Join-Path $runRoot 'composition.receipt.json'
$composeState=Join-Path $runRoot 'compose-state'; $composeEvidence=Join-Path $runRoot 'compose-evidence'
[void][IO.Directory]::CreateDirectory($composeState); [void][IO.Directory]::CreateDirectory($composeEvidence)
$composeOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archivePath -BundleRoot $bundleRoot -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $hostFixture.target -StateRoot $composeState -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($composeOutput -join "`n")"
$verify = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Synthetic receipt failed: $($verify -join "`n")"
$hostState=Join-Path $runRoot 'host-state'; $hostEvidence=Join-Path $runRoot 'host-evidence'
[void][IO.Directory]::CreateDirectory($hostState); [void][IO.Directory]::CreateDirectory($hostEvidence)
$beforeHost = Inventory $hostFixture.target
$beforePackage = Inventory (Join-Path $composed 'package')
$hostOutput = @(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $hostFixture.target --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
$hostResult = ($hostOutput -join "`n") | ConvertFrom-Json -Depth 100
Assert ($hostResult.status -ceq 'pass' -and $hostResult.exitCategory -ceq 'success' -and
    @($hostResult.coverage | Where-Object { $_.matched -ge 1 }).Count -eq 4 -and
    (Inventory $hostFixture.target) -ceq $beforeHost -and
    (Inventory (Join-Path $composed 'package')) -ceq $beforePackage) "Published 1.1.3 Host Post or immutable-root mismatch: $($hostOutput -join "`n")"
$baseAfter = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage | ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $baseAfter.packageHash -ceq $baseCheck.packageHash) 'Published Package changed during candidate run.'
Write-Json (Join-Path $runRoot 'summary.json') ([ordered]@{ formatVersion=1; status='pass'; scope='candidate-c3b'; baseVersion='1.1.3'; archiveSha256=Hash $archivePath; cases=$results; realCoverage=@($real.coverage); hostCoverage=@($hostResult.coverage); hostComposition='synthetic-only-pass' })
Write-Output "IFX C3b candidate passed $(@($results).Count) fixtures, real TargetRoot and published 1.1.3 Host Post. Evidence: $runRoot"
