# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: the module/claim inventory of
# ifx_profile 0.5.0-a, successor of docs/guards/candidates/ifx-gate-coverage-c6b0/Test-IFXC6ModuleInventory.ps1 (which
# stays unchanged as historical authority). The 25 modules changed by the A1-2 specification come from
# candidates/ifx-i2b-050a/modules; the 12 unchanged modules keep their accepted 0.4.4 sources. Rules, claims and
# ownership are unchanged: 37 modules, 83 rules, 79 claims.
[CmdletBinding()]
param(
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-i2b/formal-inventory',
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$ExpectedBaseVersion = '1.1.6',
    [string]$ExpectedArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$ExpectedPackageHash = 'a09469f77956190fbffa827ff5b7da2a63b615d66bf47a86ad0d17c7207bc825',
    [string]$PredecessorInventoryPath = 'docs/guards/candidates/ifx-i2b-050a/baseline-044/authority-map.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$Path, $Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$package = Join-Path $BaseInstallRoot 'package'
$receipt = Get-Content $BaseReceiptPath -Raw | ConvertFrom-Json -Depth 100
Assert ($receipt.status -ceq 'installed' -and $receipt.version -ceq $ExpectedBaseVersion -and $receipt.archiveSha256 -ceq $ExpectedArchiveSha256) "Published $ExpectedBaseVersion receipt drift."
$baseCheck = & pwsh -NoProfile -File (Join-Path $package 'core/runtime/Test-V4Package.ps1') -PackageRoot $package | ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass' -and $baseCheck.packageHash -ceq $ExpectedPackageHash) 'Published Package drift.'
$spec = Get-Content (Join-Path $PSScriptRoot 'change-spec.json') -Raw | ConvertFrom-Json -Depth 50
if (-not [IO.Path]::IsPathFullyQualified($PredecessorInventoryPath)) { $PredecessorInventoryPath = Join-Path $repo $PredecessorInventoryPath }
$predecessor = Get-Content $PredecessorInventoryPath -Raw | ConvertFrom-Json -Depth 100
Assert ($predecessor.status -ceq 'pass' -and @($predecessor.modules).Count -eq 37 -and $predecessor.baseVersion -ceq $ExpectedBaseVersion) '0.4.4 predecessor inventory drift.'
$g04 = Get-Content (Join-Path $repo 'docs/architecture/review/evidence/gates/G04/G04-phase12-status.json') -Raw | ConvertFrom-Json -Depth 100
Assert ($g04.status -ceq 'PRE-READY' -and @($g04.blockers).Count -eq 7 -and -not $g04.gateClosed -and -not $g04.approvalGranted) 'G04 governance status drift.'

$modules = [Collections.Generic.List[object]]::new(); $rules = [Collections.Generic.List[object]]::new()
foreach ($old in @($predecessor.modules | Sort-Object ordinal)) {
    $id = [string]$old.id; $ordinal = [int]$old.ordinal; $stage = [string]$old.stage
    if ($id -ceq 'architecture-conformance') {
        $builtinPath = Join-Path $package 'modules/architecture-conformance/module.json'; $builtin = Get-Content $builtinPath -Raw | ConvertFrom-Json -Depth 100
        Assert ($builtin.id -ceq 'architecture-conformance' -and 'post' -in @($builtin.stages)) 'Built-in module drift.'
        $modules.Add([ordered]@{ ordinal = $ordinal; id = $id; tranche = "published-$ExpectedBaseVersion"; stage = 'post'; disposition = 'unchanged'; sourcePath = 'modules/architecture-conformance'; version = $builtin.version; manifestSha256 = Hash $builtinPath; adapterSha256 = $null; dependencyLockSha256 = $null; rulePlanSha256 = Hash (Join-Path $package 'modules/architecture-conformance/rule-execution-plan.json'); authorities = @(); prerequisites = @($builtin.prerequisites); capabilities = $builtin.capabilities })
        $rules.Add([ordered]@{ ordinal = 0; moduleOrdinal = $ordinal; moduleId = $id; stage = 'post'; ruleId = 'ARCH.TYPE_DEPENDENCY'; claimId = 'ARCH.TYPE_DEPENDENCY'; severity = 'blocking'; minimumMatches = 1 })
        continue
    }
    $row = @($spec.modules | Where-Object { $_.id -ceq $id }); Assert ($row.Count -eq 1) "Module not in the change specification: $id"
    $changed = $row[0].disposition -notcontains 'unchanged'
    $moduleRoot = if ($changed) { Join-Path $PSScriptRoot "modules/$id" } else { Join-Path $repo ([string]$old.sourcePath) }
    $packageRoot = [IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($moduleRoot))
    $manifestPath = Join-Path $moduleRoot 'module.json'
    Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $package 'core/contracts/module.schema.json') -ErrorAction Stop) "Module schema failed: $id"
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 100
    Assert ($manifest.id -ceq $id -and (@($manifest.stages) -join '|') -ceq $stage) "Module ID/Stage drift: $id"
    Assert ($manifest.version -ceq [string]$row[0].newVersion) "Module version differs from the specification: $id"
    if (-not $changed) { Assert ((Hash $manifestPath) -ceq [string]$old.manifestSha256) "Unchanged module drifted from 0.4.4: $id" }
    $adapterPath = Join-Path $moduleRoot 'adapter.ps1'; $dependencyPath = Join-Path $moduleRoot 'dependencies.lock.json'
    Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256 -and (Hash $dependencyPath) -ceq $manifest.dependencyLock.sha256) "Module executable/lock drift: $id"
    $authorityRows = @(foreach ($authority in $manifest.authorities) { $path = Join-Path $packageRoot $authority.path; Assert ((Hash $path) -ceq $authority.sha256) "Module authority drift: $id/$($authority.id)"; [ordered]@{ id = $authority.id; path = $authority.path; sha256 = $authority.sha256 } })
    $readRoots = @($manifest.capabilities.readRoots); $writeRoots = @($manifest.capabilities.writeRoots); $processes = @($manifest.capabilities.processes)
    Assert (@($readRoots | Where-Object { $_ -notin @('PackageRoot', 'TargetRoot', 'EvidenceRoot') }).Count -eq 0 -and $writeRoots.Count -eq 0 -and @($processes | Where-Object { $_ -notin @('pwsh', 'git', 'dotnet') }).Count -eq 0 -and -not $manifest.capabilities.network) "Capability ceiling drift: $id"
    Assert ([int]$manifest.capabilities.timeoutSeconds -gt 0 -and [int]$manifest.capabilities.timeoutSeconds -le 180) "Timeout ceiling drift: $id"
    $planPath = Join-Path $moduleRoot 'rule-execution-plan.json'; $plan = Get-Content $planPath -Raw | ConvertFrom-Json -Depth 100
    Assert ((Hash $planPath) -ceq [string]$old.rulePlanSha256) "Rule plan changed (0.5.0-a keeps rules and claims): $id"
    foreach ($rule in $plan.rules) {
        Assert ($rule.stage -ceq $stage -and [int]$rule.minimumMatches -ge 1 -and $null -eq $rule.baseline -and $rule.severity -in @('blocking', 'advisory')) "Rule drift: $id/$($rule.ruleId)"
        $rules.Add([ordered]@{ ordinal = 0; moduleOrdinal = $ordinal; moduleId = $id; stage = $stage; ruleId = $rule.ruleId; claimId = $rule.claimId; severity = $rule.severity; minimumMatches = [int]$rule.minimumMatches })
    }
    $modules.Add([ordered]@{ ordinal = $ordinal; id = $id; tranche = $(if ($changed) { 'i2b-050a' } else { [string]$old.tranche }); stage = $stage; disposition = $(if ($changed) { 'changed' } else { 'unchanged' })
        sourcePath = [IO.Path]::GetRelativePath($repo, $moduleRoot).Replace('\', '/'); version = $manifest.version; manifestSha256 = Hash $manifestPath; adapterSha256 = Hash $adapterPath; dependencyLockSha256 = Hash $dependencyPath; rulePlanSha256 = Hash $planPath
        authorities = $authorityRows; prerequisites = @($manifest.prerequisites); capabilities = [ordered]@{ readRoots = $readRoots; writeRoots = $writeRoots; processes = $processes; network = [bool]$manifest.capabilities.network; maxTimeoutSeconds = [int]$manifest.capabilities.timeoutSeconds } })
}
$ordered = @($rules | Sort-Object -Stable { [int]$_['moduleOrdinal'] }); $rules.Clear(); foreach ($r in $ordered) { $r.ordinal = $rules.Count + 1; $rules.Add($r) }
# The rule order within a module follows the 0.4.4 inventory exactly.
$oldRules = @($predecessor.rules | Sort-Object ordinal | ForEach-Object { "$($_.moduleId)|$($_.ruleId)|$($_.claimId)|$($_.severity)" }) -join "`n"
$newRules = @($rules | ForEach-Object { "$($_.moduleId)|$($_.ruleId)|$($_.claimId)|$($_.severity)" }) -join "`n"
if ($oldRules -cne $newRules) { $a=$oldRules -split "`n"; $b=$newRules -split "`n"; for($i=0;$i -lt [Math]::Max($a.Count,$b.Count);$i++){ if($a[$i] -cne $b[$i]){ Write-Host "first diff at $i : $($a[$i]) vs $($b[$i])"; break } }; throw 'Rule inventory differs from 0.4.4.' }
$claimIds = @($rules | ForEach-Object { $_.claimId } | Sort-Object -Unique)
Assert ($modules.Count -eq 37 -and $rules.Count -eq 83 -and $claimIds.Count -eq 79) "Module/rule/claim inventory count drift: $($modules.Count)/$($rules.Count)/$($claimIds.Count)."
foreach ($claim in $claimIds) { Assert (@($rules | Where-Object { $_.claimId -ceq $claim -and $_.severity -ceq 'blocking' } | ForEach-Object { $_.moduleId } | Sort-Object -Unique).Count -eq 1) "Claim has no unique blocking module owner: $claim" }
$overlap = @($rules | Group-Object { $_['ruleId'] } | Where-Object Count -gt 1 | Sort-Object Name)

$runId = [Guid]::NewGuid().ToString('N')
$root = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repo $EvidenceRoot }
$report = Join-Path $root $runId; $inventoryPath = Join-Path $report 'ordinal-inventory.json'
$sourceCommit = (& git -C $repo rev-parse HEAD).Trim(); Assert ($LASTEXITCODE -eq 0) 'Source commit unavailable.'
Write-Json $inventoryPath ([ordered]@{ formatVersion = 1; status = 'pass'; scope = 'ifx-050a-source-module-claim-inventory'; sourceCommit = $sourceCommit; baseVersion = $ExpectedBaseVersion; baseArchiveSha256 = $receipt.archiveSha256; basePackageHash = $baseCheck.packageHash; receiptSha256 = Hash $BaseReceiptPath
    predecessorInventorySha256 = Hash $PredecessorInventoryPath; changeSpecSha256 = Hash (Join-Path $PSScriptRoot 'change-spec.json'); g04Status = 'PRE-READY'; g04BlockerCount = 7
    modules = @($modules.ToArray()); rules = @($rules.ToArray()); claimCount = $claimIds.Count; overlappingCanonicalRuleIds = @($overlap | ForEach-Object Name)
    deferred = @('G05-Phase9-eight', 'v3-pre-diff', 'v3-cross-platform-ubuntu-latest', 'v3-cross-platform-windows-latest') })
Write-Json (Join-Path $report 'summary.json') ([ordered]@{ formatVersion = 1; status = 'pass'; baseVersion = $ExpectedBaseVersion; moduleCount = $modules.Count; changedModuleCount = @($modules | Where-Object { $_.disposition -ceq 'changed' }).Count; ruleCount = $rules.Count; claimCount = $claimIds.Count; inventoryPath = [IO.Path]::GetRelativePath($repo, $inventoryPath).Replace('\', '/'); inventorySha256 = Hash $inventoryPath; sourceCommit = $sourceCommit })
Write-Output "IFX 0.5.0-a module/claim inventory passed: $inventoryPath"
