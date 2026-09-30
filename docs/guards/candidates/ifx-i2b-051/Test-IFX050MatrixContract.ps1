# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: verify the 0.5.0-a independent
# matrix contract and fixture specification; successor of candidates/ifx-rebind-116/Test-IFX116MatrixContract.ps1
# (unchanged). Every I1 contract check is kept. In addition the contract must be exactly what New-IFX050MatrixContract
# derives from the accepted I1 contract and this inventory, and the fixture specification must be exactly what
# New-IFX050FixtureSpec derives from the current catalogs and supplemental fixtures. With -CaptureDirectory the
# captures are reclassified offline (IFX050.Matrix.psm1); that report is diagnostic only.
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path,
    [Parameter(Mandatory)][string]$BaseInstallRoot,
    [Parameter(Mandatory)][string]$InventoryPath,
    [string]$ContractPath = 'docs/guards/candidates/ifx-i2b-050a/matrix-contract-050.json',
    [string]$FixtureSpecPath = 'docs/guards/candidates/ifx-i2b-050a/fixture-spec-050.json',
    [string]$ReportPath = 'artifacts/guards/p10-ifx-i2b/matrix-contract/summary.json',
    [string]$CaptureDirectory,
    [string]$DiagnosticReportPath = 'artifacts/guards/p10-ifx-i2b/matrix-contract/reclassification.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../ifx-rebind-116/IFX116.V4Reference.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'IFX050.Matrix.psm1') -Force
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

$inventoryFull = Full $InventoryPath; $contractFull = Full $ContractPath; $fixtureSpecFull = Full $FixtureSpecPath
foreach ($p in @($inventoryFull, $contractFull, $fixtureSpecFull)) { Assert ([IO.File]::Exists($p)) "Matrix contract input missing: $p" }
$inventory = Get-Content -Raw -LiteralPath $inventoryFull | ConvertFrom-Json -Depth 100
$contract = Get-Content -Raw -LiteralPath $contractFull | ConvertFrom-Json -Depth 100
$fixtureSpec = Get-Content -Raw -LiteralPath $fixtureSpecFull | ConvertFrom-Json -Depth 100
Assert ($inventory.scope -ceq 'ifx-050a-source-module-claim-inventory') 'Not a 0.5.0-a inventory.'
Assert ($contract.formatVersion -eq 1 -and $contract.id -ceq 'ifx-050a-independent-matrix-contract') 'Matrix contract identity drift.'

# The contract and the fixture specification are re-derived and compared byte for byte (text, LF).
$scratch = Join-Path ([IO.Path]::GetTempPath()) ("ifx-050-contract-" + [guid]::NewGuid().ToString('N')); [void][IO.Directory]::CreateDirectory($scratch)
try {
    $derivedContract = Join-Path $scratch 'matrix-contract-050.json'
    $o = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'New-IFX050MatrixContract.ps1') -InventoryPath $inventoryFull -OutputPath $derivedContract 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Contract derivation failed: $($o -join ' ')"
    Assert ((Get-IFX050PinSha256 $derivedContract) -ceq (Get-IFX050PinSha256 $contractFull)) 'Matrix contract differs from its derivation (New-IFX050MatrixContract).'
    $derivedSpec = Join-Path $scratch 'fixture-spec-050.json'
    $o = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'New-IFX050FixtureSpec.ps1') -ContractPath $contractFull -OutputPath $derivedSpec 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Fixture specification derivation failed: $($o -join ' ')"
    Assert ((Get-IFX050PinSha256 $derivedSpec) -ceq (Get-IFX050PinSha256 $fixtureSpecFull)) 'Fixture specification differs from its derivation (New-IFX050FixtureSpec).'
} finally { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }

$inventoryProjection = [ordered]@{
    modules = @($inventory.modules | Sort-Object ordinal | ForEach-Object { [ordered]@{ ordinal = $_.ordinal; id = $_.id; stage = $_.stage; sourcePath = $_.sourcePath; adapterSha256 = $_.adapterSha256 } })
    rules = @($inventory.rules | Sort-Object ordinal | ForEach-Object { [ordered]@{ ordinal = $_.ordinal; moduleOrdinal = $_.moduleOrdinal; moduleId = $_.moduleId; stage = $_.stage; ruleId = $_.ruleId; claimId = $_.claimId; severity = $_.severity; minimumMatches = $_.minimumMatches } })
}
$inventoryProjectionSha256 = Get-IFX050Sha256Text (($inventoryProjection | ConvertTo-Json -Depth 20 -Compress).Replace("`r`n", "`n"))
Assert ($inventoryProjectionSha256 -ceq $contract.inventoryProjectionSha256) 'Matrix contract inventory projection drift.'
$blocking = @($inventory.rules | Where-Object severity -CEQ 'blocking'); $advisory = @($inventory.rules | Where-Object severity -CEQ 'advisory')
Assert (@($inventory.modules).Count -eq $contract.moduleCount -and $contract.moduleCount -eq 37) 'Module count drift.'
Assert ($blocking.Count -eq $contract.blockingRuleCount -and $contract.blockingRuleCount -eq 80) 'Blocking-rule count drift.'
Assert ($advisory.Count -eq $contract.advisoryRuleCount -and $contract.advisoryRuleCount -eq 3) 'Advisory-rule count drift.'
Assert (@($contract.modules).Count -eq 37 -and @($contract.modules.id | Sort-Object -Unique).Count -eq 37) 'Module contract cardinality drift.'
$allowedZero = @('enumerated-zero', 'fixed-checklist-zero', 'integrity-zero')
foreach ($module in @($inventory.modules | Sort-Object ordinal)) {
    $entry = @($contract.modules | Where-Object id -CEQ $module.id); Assert ($entry.Count -eq 1) "Module contract missing: $($module.id)"; $entry = $entry[0]
    Assert ($entry.ordinal -eq $module.ordinal) "Module ordinal drift: $($module.id)"
    Assert ($entry.zeroStrategy -cin $allowedZero) "Unknown zero strategy: $($module.id)"
    Assert (-not [string]::IsNullOrWhiteSpace([string]$entry.sourceFact)) "Source fact missing: $($module.id)"
    $adapter = Resolve-IFX116V4Path -Path ([string]$entry.adapterPath) -RepositoryRoot $repo -BaseInstallRoot $BaseInstallRoot
    Assert ([IO.File]::Exists($adapter) -and (Hash $adapter) -ceq [string]$entry.adapterSha256) "Adapter path or hash drift: $($module.id)"
    if ($module.id -cne 'architecture-conformance') { Assert ([string]$module.adapterSha256 -ceq [string]$entry.adapterSha256) "Inventory adapter hash drift: $($module.id)" }
    if ($module.disposition -ceq 'changed') { Assert ([string]$entry.adapterPath -ceq "$($module.sourcePath)/adapter.ps1") "Changed module is not bound to its 0.5.0-a adapter: $($module.id)" }
    if ($entry.zeroStrategy -ceq 'fixed-checklist-zero') {
        $finding = $entry.zeroFinding
        Assert ($null -ne $finding -and -not [string]::IsNullOrWhiteSpace([string]$finding.subject) -and -not [string]::IsNullOrWhiteSpace([string]$finding.evidenceKind)) "Fixed-checklist finding missing: $($module.id)"
        Assert (@($blocking | Where-Object { $_.moduleId -ceq $module.id -and $_.ruleId -ceq $finding.ruleId }).Count -eq 1) "Fixed-checklist rule is not owned: $($module.id)"
    }
    if ($entry.zeroStrategy -ceq 'integrity-zero') { Assert ($entry.zeroExitCategory -ceq 'integrity-failure') "Integrity-zero category drift: $($module.id)" }
}
Assert ($contract.defaultRuleContract.outcome -ceq 'findings-blocking' -and $contract.defaultRuleContract.allowedRuleSet -ceq 'isolated' -and $contract.defaultRuleContract.coverage -ceq 'nonzero') 'Default rule contract drift.'
$seenOverrides = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($override in @($contract.ruleOverrides)) {
    $key = "$($override.moduleId)/$($override.ruleId)"; Assert ($seenOverrides.Add($key)) "Duplicate rule override: $key"
    Assert (@($blocking | Where-Object { $_.moduleId -ceq $override.moduleId -and $_.ruleId -ceq $override.ruleId }).Count -eq 1) "Unknown rule override: $key"
    Assert ($override.outcome -cin @('findings-blocking', 'integrity-failure')) "Unknown rule outcome: $key"
    Assert ($override.coverage -cin @('nonzero', 'finding-proves-evaluation', 'integrity-progress')) "Unknown coverage contract: $key"
    if ($override.outcome -ceq 'findings-blocking') {
        Assert (@($override.allowedRuleIds).Count -gt 0 -and @($override.allowedRuleIds) -ccontains [string]$override.ruleId) "Rule override omits its target: $key"
        foreach ($allowed in @($override.allowedRuleIds)) { Assert (@($blocking | Where-Object { $_.moduleId -ceq $override.moduleId -and $_.ruleId -ceq $allowed }).Count -eq 1) "Cross-module or unknown coupled rule: $key -> $allowed" }
    } else { Assert (@($override.allowedRuleIds).Count -eq 0 -and $override.coverage -ceq 'integrity-progress') "Integrity outcome contract drift: $key" }
}
$expectedAdvisory = @($advisory | ForEach-Object { "$($_.moduleId)/$($_.ruleId)/$($_.claimId)" } | Sort-Object)
$actualAdvisory = @($contract.advisoryRules | ForEach-Object { "$($_.moduleId)/$($_.ruleId)/$($_.claimId)" } | Sort-Object)
Assert (($expectedAdvisory -join "`n") -ceq ($actualAdvisory -join "`n")) 'Advisory-rule contract drift.'

Assert ($fixtureSpec.formatVersion -eq 1 -and $fixtureSpec.id -ceq 'ifx-050a-matrix-fixtures' -and $fixtureSpec.status -ceq 'complete') 'Fixture specification identity drift.'
Assert ($fixtureSpec.matrixContractSha256 -ceq (Get-IFX050PinSha256 $contractFull) -and $fixtureSpec.requiredCoreCases -eq 191) 'Fixture specification contract binding drift.'
Assert (@($fixtureSpec.cases).Count -eq ($fixtureSpec.supplementalCaseCount + $fixtureSpec.suiteMatrixCaseCount) -and @($fixtureSpec.cases.id | Sort-Object -Unique).Count -eq @($fixtureSpec.cases).Count) 'Fixture case cardinality or uniqueness drift.'
foreach ($p in $fixtureSpec.sources.PSObject.Properties) { $f = Full ([string]$p.Value.path); Assert ([IO.File]::Exists($f) -and (Get-IFX050PinSha256 $f) -ceq [string]$p.Value.sha256) "Fixture source drift: $($p.Name)" }
foreach ($case in $fixtureSpec.cases) { Assert (-not [string]::IsNullOrWhiteSpace([string]$case.recipe) -and $null -ne $fixtureSpec.sources.PSObject.Properties[[string]$case.source]) "Fixture recipe or source missing: $($case.id)" }
$changedIds = @($inventory.modules | Where-Object disposition -CEQ 'changed' | ForEach-Object id)
foreach ($case in @($fixtureSpec.cases | Where-Object source -CEQ 'supplemental')) { Assert ($changedIds -cnotcontains ([string]$case.id).Split('/')[0]) "A supplemental fixture targets a changed module: $($case.id)" }

$reportFull = Full $ReportPath
Write-IFX050Json $reportFull ([ordered]@{
    formatVersion = 1; status = 'pass'; scope = 'ifx-050a-matrix-contract'; v4Reference = 'base-package and repository paths (IFX-V4-004)'
    inventorySha256 = Hash $inventoryFull; inventoryProjectionSha256 = $inventoryProjectionSha256; contractSha256 = Get-IFX050PinSha256 $contractFull; fixtureSpecSha256 = Get-IFX050PinSha256 $fixtureSpecFull
    moduleCount = 37; changedModuleCount = $changedIds.Count; blockingRuleCount = 80; advisoryRuleCount = 3
    zeroStrategies = [ordered]@{ enumerated = @($contract.modules | Where-Object zeroStrategy -CEQ 'enumerated-zero').Count; fixedChecklist = @($contract.modules | Where-Object zeroStrategy -CEQ 'fixed-checklist-zero').Count; integrity = @($contract.modules | Where-Object zeroStrategy -CEQ 'integrity-zero').Count }
    ruleOverrideCount = @($contract.ruleOverrides).Count; fixtureCaseCount = @($fixtureSpec.cases).Count })
Write-Output "IFX 0.5.0-a matrix contract passed: $reportFull"

if (-not [string]::IsNullOrWhiteSpace($CaptureDirectory)) {
    $captureFull = Full $CaptureDirectory; Assert ([IO.Directory]::Exists($captureFull)) 'Capture directory is missing.'
    $captures = Read-IFX050Captures @(Get-ChildItem -LiteralPath $captureFull -File -Filter '*.jsonl' | Sort-Object Name | ForEach-Object FullName)
    $r = Get-IFX050MatrixCases -Inventory $inventory -Contract $contract -Captures $captures
    $diagnostic = [ordered]@{ formatVersion = 1; status = $(if (@($r.gaps).Count -eq 0 -and @($r.cases).Count -eq 191) { 'pass' } else { 'blocked' }); scope = 'ifx-050a-offline-reclassification'; source = 'captures-diagnostic-only'
        contractSha256 = Get-IFX050PinSha256 $contractFull; captureCount = $captures.Count; requiredCoreCases = 191; provenCoreCases = @($r.cases).Count; gaps = @($r.gaps); cases = @($r.cases) }
    Write-IFX050Json (Full $DiagnosticReportPath) $diagnostic
    Write-Output "IFX 0.5.0-a offline reclassification $($diagnostic.status): $($diagnostic.provenCoreCases)/191 rows; report: $(Full $DiagnosticReportPath)"
}
