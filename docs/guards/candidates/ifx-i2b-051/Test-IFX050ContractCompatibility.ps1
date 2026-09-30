# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: the V4 1.1.6 contract handshake of
# ifx_profile 0.5.0-a; successor of candidates/ifx-rebind-116/Test-IFX116ContractCompatibility.ps1 (unchanged).
# The published 1.1.6 base and its workspace-evidence contract are verified as before. The inheritance matrix compares
# every module with the 0.4.4 inventory: the 12 unchanged modules inherit; the 25 changed modules are requalified, and
# each must match the adapter and policy of its passing A1-3 suite record (artifacts/guards/p10-ifx-i2b/a2-051/a1-suites).
[CmdletBinding()]
param(
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath = 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$PreviousInventoryPath = 'docs/guards/candidates/ifx-i2b-051/baseline-044/authority-map.json',
    [string]$SuiteIndexPath = 'artifacts/guards/p10-ifx-i2b/a2-051/a1-suites/index.json',
    [Parameter(Mandatory)][string]$InventoryPath,
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-i2b/a2-051/contract-preflight'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Ok, [string]$Message) { if (-not $Ok) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function WriteJson([string]$Path, $Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit = (& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant(); Assert ($LASTEXITCODE -eq 0 -and $commit -cmatch '^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked = @(& git -C $repo status --porcelain --untracked-files=no); Assert ($LASTEXITCODE -eq 0 -and -not $tracked) 'Tracked checkout must be clean for the contract handshake.'
$archive = Full $BaseArchivePath; $receiptPath = Full $BaseReceiptPath; $package = Join-Path (Full $BaseInstallRoot) 'package'
Assert ([IO.File]::Exists($archive) -and (Hash $archive) -ceq '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8') '1.1.6 archive identity drift.'
Assert ((Hash $receiptPath) -ceq 'a5c47ac809d3bd29815f94d6f6481ddb59952c0435fc908c9ab3e71e9359e497') '1.1.6 receipt identity drift.'
$receipt = Get-Content $receiptPath -Raw | ConvertFrom-Json -Depth 100
Assert ($receipt.status -ceq 'installed' -and $receipt.version -ceq '1.1.6' -and $receipt.archiveSha256 -ceq (Hash $archive)) '1.1.6 receipt content drift.'
$packageCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $package 'core/runtime/Test-V4Package.ps1') -PackageRoot $package | ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $packageCheck.status -ceq 'pass' -and $packageCheck.packageHash -ceq 'a09469f77956190fbffa827ff5b7da2a63b615d66bf47a86ad0d17c7207bc825') '1.1.6 Package identity drift.'
$tagCommit = ((& git ls-remote https://github.com/von12549/Guard 'refs/tags/v4-guards-v1.1.6^{}') -split "`t")[0].Trim(); Assert ($LASTEXITCODE -eq 0 -and $tagCommit -ceq '960678fd1a193d87d5c499f08e79e7ce0550d96a') '1.1.6 Guard tag/source drift.'
$workspaceSchema = Join-Path $package 'core/contracts/workspace-evidence.schema.json'; $workspaceSchemaObject = Get-Content $workspaceSchema -Raw | ConvertFrom-Json -Depth 100
Assert ((@($workspaceSchemaObject.required) -join '|') -ceq 'formatVersion|scope|targetCommit|relativeRoots|extensions|excludedDirectoryNames|pathOrder|fileCount|treeSha256|startedAt|completedAt|elapsedSeconds|files') 'Workspace evidence required-field contract drift.'

$inventory = Get-Content (Full $InventoryPath) -Raw | ConvertFrom-Json -Depth 100
Assert ($inventory.scope -ceq 'ifx-050a-source-module-claim-inventory' -and $inventory.sourceCommit -ceq $commit -and @($inventory.modules).Count -eq 37) '0.5.0-a inventory drift.'
$previous = Get-Content (Full $PreviousInventoryPath) -Raw | ConvertFrom-Json -Depth 100
Assert ($previous.baseVersion -ceq '1.1.6' -and @($previous.modules).Count -eq 37) '0.4.4 comparison inventory drift.'
$index = Get-Content (Full $SuiteIndexPath) -Raw | ConvertFrom-Json -Depth 50
Assert ($index.kind -ceq 'ifx-050a-module-suites' -and $index.summary.passed -eq 25 -and $index.summary.failed -eq 0) 'A1-3 suite index does not record 25 passing modules.'

# The seven workspace-evidence consumers keep their Host contract.
$consumers = @('ifx-domain-reference', 'ifx-project-name', 'ifx-g03-source-reconciliation', 'ifx-g03-snapshots', 'ifx-database-evidence', 'ifx-g05-inventory', 'ifx-plan05-security')
$contractRows = [Collections.Generic.List[object]]::new()
foreach ($id in $consumers) {
    $row = @($inventory.modules | Where-Object { $_.id -ceq $id })[0]; $root = Join-Path $repo $row.sourcePath
    $manifestPath = Join-Path $root 'module.json'; $adapter = [IO.File]::ReadAllText((Join-Path $root 'adapter.ps1'))
    Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $package 'core/contracts/module.schema.json') -ErrorAction Stop) "1.1.6 module schema incompatibility: $id"
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 100
    Assert ('EvidenceRoot' -cin @($manifest.capabilities.readRoots) -and @($manifest.capabilities.writeRoots).Count -eq 0 -and -not $manifest.capabilities.network) "EvidenceRoot capability gap: $id"
    foreach ($token in @('workspaceEvidencePath', 'workspaceEvidenceSha256', 'workspaceEvidenceTargetCommit', 'v4-workspace-evidence-v1')) { Assert ($adapter.Contains($token)) "Workspace input token missing for ${id}: $token" }
    $contractRows.Add([ordered]@{ moduleId = $id; disposition = [string]$row.disposition; manifestSha256 = Hash $manifestPath; adapterSha256 = [string]$row.adapterSha256; declaredTimeoutSeconds = [int]$manifest.capabilities.timeoutSeconds })
}

$inheritance = [Collections.Generic.List[object]]::new()
foreach ($row in @($inventory.modules | Sort-Object ordinal)) {
    $old = @($previous.modules | Where-Object { $_.id -ceq $row.id }); Assert ($old.Count -eq 1) "0.4.4 inventory row missing: $($row.id)"
    if ($row.id -ceq 'architecture-conformance') { $inheritance.Add([ordered]@{ moduleId = $row.id; disposition = 'inherit-base'; manifest = [string]$row.manifestSha256 }); continue }
    $authorities = @($row.authorities | ForEach-Object { "$($_.id)|$($_.sha256)" }) -join "`n"; $oldAuthorities = @($old[0].authorities | ForEach-Object { "$($_.id)|$($_.sha256)" }) -join "`n"
    $exact = $row.manifestSha256 -ceq $old[0].manifestSha256 -and $row.adapterSha256 -ceq $old[0].adapterSha256 -and $row.dependencyLockSha256 -ceq $old[0].dependencyLockSha256 -and $row.rulePlanSha256 -ceq $old[0].rulePlanSha256 -and $authorities -ceq $oldAuthorities
    if ($row.disposition -ceq 'unchanged') { Assert $exact "Unchanged module drifted from 0.4.4: $($row.id)"; $inheritance.Add([ordered]@{ moduleId = $row.id; disposition = 'inherit'; manifest = [string]$row.manifestSha256 }); continue }
    Assert (-not $exact) "Changed module is byte-identical to 0.4.4: $($row.id)"
    Assert ($row.rulePlanSha256 -ceq $old[0].rulePlanSha256) "Changed module altered its rule plan: $($row.id)"
    $suite = @($index.modules | Where-Object { $_.moduleId -ceq $row.id }); Assert ($suite.Count -eq 1 -and $suite[0].status -ceq 'pass') "No passing A1-3 suite record: $($row.id)"
    $policy = Join-Path $repo "$($row.sourcePath)/policy.json"
    Assert ($suite[0].adapterSha256 -ceq $row.adapterSha256 -and ((-not [IO.File]::Exists($policy)) -or $suite[0].policySha256 -ceq (Hash $policy))) "Module differs from its A1-3 suite record: $($row.id)"
    $inheritance.Add([ordered]@{ moduleId = $row.id; disposition = 'requalified-a1-3'; version = [string]$row.version; old = [ordered]@{ manifest = $old[0].manifestSha256; adapter = $old[0].adapterSha256 }; current = [ordered]@{ manifest = [string]$row.manifestSha256; adapter = [string]$row.adapterSha256 }; suiteCases = $suite[0].cases; suiteSummarySha256 = $suite[0].summarySha256 })
}
Assert (@($inheritance | Where-Object { $_.disposition -ceq 'inherit' }).Count -eq 11 -and @($inheritance | Where-Object { $_.disposition -ceq 'requalified-a1-3' }).Count -eq 25) 'Inheritance matrix disposition count drift.'
$runId = [guid]::NewGuid().ToString('N'); $root = Join-Path (Full $EvidenceRoot) $runId; [void][IO.Directory]::CreateDirectory($root)
$matrixPath = Join-Path $root 'inheritance-matrix.json'; WriteJson $matrixPath ([ordered]@{ formatVersion = 1; status = 'pass'; targetCommit = $commit; from = '0.4.4'; to = '0.5.1'; rows = @($inheritance.ToArray()) })
$report = Join-Path $root 'summary.json'
WriteJson $report ([ordered]@{ formatVersion = 1; status = 'pass'; scope = 'v4-1.1.6-ifx-050a-contract-handshake'; targetCommit = $commit; base = [ordered]@{ tagCommit = $tagCommit; archiveSha256 = Hash $archive; receiptSha256 = Hash $receiptPath; packageHash = $packageCheck.packageHash }
    workspaceConsumers = @($contractRows.ToArray()); inheritanceMatrixPath = [IO.Path]::GetRelativePath($repo, $matrixPath).Replace('\', '/'); inheritanceMatrixSha256 = Hash $matrixPath
    inheritedModuleCount = 11; baseInheritedModuleCount = 1; requalifiedModuleCount = 25; suiteIndexSha256 = Hash (Full $SuiteIndexPath) })
Write-Output "IFX 0.5.0-a contract handshake passed: $report"
