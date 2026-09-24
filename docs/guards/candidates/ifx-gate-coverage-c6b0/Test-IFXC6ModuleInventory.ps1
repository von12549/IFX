[CmdletBinding()]
param(
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-c6b0/inventory-runs',
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3'
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
$receiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json'
$receipt = Get-Content $receiptPath -Raw | ConvertFrom-Json -Depth 100
Assert ($receipt.status -ceq 'installed' -and $receipt.version -ceq '1.1.3' -and @($receipt.files).Count -eq 137) 'Published 1.1.3 receipt drift.'
Assert ($receipt.archiveSha256 -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
$baseCheck = & pwsh -NoProfile -File (Join-Path $package 'core/runtime/Test-V4Package.ps1') -PackageRoot $package | ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass' -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$r3Path = Join-Path $repo 'artifacts/guards/p10-ifx-c1-r3/test-runs/e5dec30036424e0e89d1f5278b3b70c9/summary.json'
$c5Path = Join-Path $repo 'artifacts/guards/p10-ifx-c5f/test-runs/2ed76a91a7c9432fa35f0d59dd5a5f78/summary.json'
$decisionPath = Join-Path $repo 'docs/guards/inventories/20260924-ifx-c1-applicability-decisions.json'
Assert ((Hash $r3Path) -ceq '9ec0f8fd047f3e2fd8af96849f3d8e1844677e3b1f1e064ee0e9365dea7be159' -and (Hash $c5Path) -ceq '6ad95f76cce837a9efc02fa941c2f8f60e470657a5698ee87415309acc3387cc' -and (Hash $decisionPath) -ceq 'e3a95670c96992b53438e47c6176ca3c1d6cf111cf4568a90c542cd846218b3d') 'Prior authority hash drift.'
$r3 = Get-Content $r3Path -Raw | ConvertFrom-Json -Depth 100
$c5 = Get-Content $c5Path -Raw | ConvertFrom-Json -Depth 100
Assert ($r3.status -ceq 'pass' -and $r3.claimCount -eq 25 -and $r3.boundedApplicabilityCount -eq 2 -and $c5.status -ceq 'pass' -and $c5.moduleCount -eq 24 -and $c5.claimCount -eq 54) 'Prior C1/C5 result drift.'
$g04Path = Join-Path $repo 'docs/architecture/review/evidence/gates/G04/G04-phase12-status.json'
$g04 = Get-Content $g04Path -Raw | ConvertFrom-Json -Depth 100
Assert ($g04.status -ceq 'PRE-READY' -and @($g04.blockers).Count -eq 7 -and -not $g04.gateClosed -and -not $g04.approvalGranted) 'G04 governance status drift.'

$map = [ordered]@{
    'ifx-domain-reference'='c1b'; 'ifx-package-reference'='c1c'; 'ifx-ring-graph'='c1d'; 'ifx-ownership-graph'='c1e'; 'ifx-provider-cycle'='c1f'; 'ifx-embedded-adapter'='c1g'; 'ifx-source-policy'='c1h'; 'ifx-project-name'='c1j'; 'ifx-reference-cycle'='c1n'; 'ifx-injection'='c1o'
    'ifx-c1-type-provenance'='c1r1b'; 'ifx-c1-evaluated-reference'='c1r2b'
    'ifx-g03-governance-core'='c2b1'; 'ifx-g03-catalog-semantics'='c2b2'; 'ifx-g03-source-reconciliation'='c2c1'; 'ifx-g03-snapshots'='c2c2'; 'ifx-g03-docs-closeout'='c2d'
    'ifx-g04-manifests'='c3b'; 'ifx-g04-runtime'='c3c'; 'ifx-g04-closeout'='c3d'
    'ifx-plan04-extraction'='c4a1'; 'ifx-plan04-tenant'='c4a2'; 'ifx-plan04-projection'='c4a3'; 'ifx-plan04-abstractions'='c4a4'; 'ifx-database-evidence'='c4b'
    'ifx-g05-inventory'='c4p0'; 'ifx-g05-protocol'='c4p1'; 'ifx-g05-execution-http'='c4p2'; 'ifx-g05-carriers'='c4p4p5'; 'ifx-g05-governance'='c4p6p7'; 'ifx-g05-closeout'='c4p8p11'; 'ifx-plan05-security'='c4s'
    'ifx-solution-evidence'='c5b'; 'ifx-assembly-evidence'='c5c'; 'ifx-frontend-evidence'='c5d'; 'ifx-history-integrity'='c5h'
}
Assert ($map.Count -eq 36) 'External module inventory count drift.'
$modules = [Collections.Generic.List[object]]::new()
$rules = [Collections.Generic.List[object]]::new()
$ordinal = 0
foreach ($id in $map.Keys) {
    $ordinal++
    $tranche = $map[$id]
    $candidate = Join-Path $repo "docs/guards/candidates/ifx-gate-coverage-$tranche"
    $moduleRoot = Join-Path $candidate "modules/$id"
    $manifestPath = Join-Path $moduleRoot 'module.json'
    Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $package 'core/contracts/module.schema.json') -ErrorAction Stop) "Module schema failed: $id"
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 100
    $stage = if ($ordinal -le 10) { 'pre' } else { 'post' }
    Assert ($manifest.id -ceq $id -and (@($manifest.stages) -join '|') -ceq $stage) "Module ID/Stage drift: $id"
    $adapterPath = Join-Path $moduleRoot 'adapter.ps1'
    $dependencyPath = Join-Path $moduleRoot 'dependencies.lock.json'
    Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256 -and (Hash $dependencyPath) -ceq $manifest.dependencyLock.sha256) "Module executable/lock drift: $id"
    $authorityRows = @(
        foreach ($authority in $manifest.authorities) {
            $path = Join-Path $candidate $authority.path
            Assert ((Hash $path) -ceq $authority.sha256) "Module authority drift: $id/$($authority.id)"
            [ordered]@{ id=$authority.id; path=$authority.path; sha256=$authority.sha256 }
        }
    )
    $readRoots = @($manifest.capabilities.readRoots)
    $writeRoots = @($manifest.capabilities.writeRoots)
    $processes = @($manifest.capabilities.processes)
    Assert (@($readRoots | Where-Object { $_ -notin @('PackageRoot','TargetRoot','EvidenceRoot') }).Count -eq 0 -and $writeRoots.Count -eq 0 -and @($processes | Where-Object { $_ -notin @('pwsh','git','dotnet') }).Count -eq 0 -and -not $manifest.capabilities.network) "Capability ceiling drift: $id"
    Assert ([int]$manifest.capabilities.timeoutSeconds -gt 0 -and [int]$manifest.capabilities.timeoutSeconds -le 180) "Timeout ceiling drift: $id"
    $planPath = Join-Path $moduleRoot 'rule-execution-plan.json'
    $plan = Get-Content $planPath -Raw | ConvertFrom-Json -Depth 100
    foreach ($rule in $plan.rules) {
        Assert ($rule.stage -ceq $stage -and [int]$rule.minimumMatches -ge 1 -and $null -eq $rule.baseline) "Rule Stage/minimum/baseline drift: $id/$($rule.ruleId)"
        Assert ($rule.severity -in @('blocking','advisory')) "Rule severity drift: $id/$($rule.ruleId)"
        $rules.Add([ordered]@{ ordinal=$rules.Count + 1; moduleOrdinal=$ordinal; moduleId=$id; stage=$stage; ruleId=$rule.ruleId; claimId=$rule.claimId; severity=$rule.severity; minimumMatches=[int]$rule.minimumMatches })
    }
    $modules.Add([ordered]@{ ordinal=$ordinal; id=$id; tranche=$tranche; stage=$stage; sourcePath=[IO.Path]::GetRelativePath($repo,$moduleRoot).Replace('\','/'); version=$manifest.version; manifestSha256=Hash $manifestPath; adapterSha256=Hash $adapterPath; dependencyLockSha256=Hash $dependencyPath; rulePlanSha256=Hash $planPath; authorities=$authorityRows; prerequisites=@($manifest.prerequisites); capabilities=[ordered]@{readRoots=$readRoots;writeRoots=$writeRoots;processes=$processes;network=[bool]$manifest.capabilities.network;maxTimeoutSeconds=[int]$manifest.capabilities.timeoutSeconds} })
}
$builtinPath = Join-Path $package 'modules/architecture-conformance/module.json'
$builtin = Get-Content $builtinPath -Raw | ConvertFrom-Json -Depth 100
Assert ($builtin.id -ceq 'architecture-conformance' -and 'post' -in @($builtin.stages)) 'Built-in module drift.'
$modules.Insert(10, [ordered]@{ordinal=11;id='architecture-conformance';tranche='published-1.1.3';stage='post';sourcePath='modules/architecture-conformance';version=$builtin.version;manifestSha256=Hash $builtinPath;adapterSha256=$null;dependencyLockSha256=$null;rulePlanSha256=Hash (Join-Path $package 'modules/architecture-conformance/rule-execution-plan.json');authorities=@();prerequisites=@($builtin.prerequisites);capabilities=$builtin.capabilities})
for ($i=11; $i -lt $modules.Count; $i++) { $modules[$i].ordinal = $i + 1 }
$rules.Add([ordered]@{ordinal=$rules.Count + 1;moduleOrdinal=11;moduleId='architecture-conformance';stage='post';ruleId='ARCH.TYPE_DEPENDENCY';claimId='ARCH.TYPE_DEPENDENCY';severity='blocking';minimumMatches=1})
foreach ($rule in $rules) { if ($rule.moduleId -cne 'architecture-conformance' -and $rule.moduleOrdinal -gt 10) { $rule.moduleOrdinal++ } }
$orderedRules = @($rules | Sort-Object { [int]$_['moduleOrdinal'] }, { [int]$_['ordinal'] })
$rules.Clear()
foreach ($row in $orderedRules) { $row.ordinal = $rules.Count + 1; $rules.Add($row) }
$claimIds = @($rules | ForEach-Object claimId | Sort-Object -Unique)
$advisory = @($rules | Where-Object severity -CEQ 'advisory')
$expectedAdvisory = @('DECLARATION-IMPLEMENTS-ADVISORY','DECLARATION-PLACEMENT-ADVISORY','RING-PACKAGE-IMPORT')
Assert ((@($advisory.ruleId | Sort-Object) -join '|') -ceq ($expectedAdvisory -join '|')) 'Supplementary advisory identity drift.'
Assert ($modules.Count -eq 37 -and $rules.Count -eq 83 -and $claimIds.Count -eq 79) "Module/rule/claim inventory count drift: $($modules.Count)/$($rules.Count)/$($claimIds.Count)."
Assert (@($modules | ForEach-Object id | Sort-Object -Unique).Count -eq 37) 'Duplicate module ID.'
foreach ($claim in $claimIds) {
    $owners = @($rules | Where-Object { $_.claimId -ceq $claim -and $_.severity -ceq 'blocking' } | ForEach-Object moduleId | Sort-Object -Unique)
    Assert ($owners.Count -eq 1) "Claim has no unique blocking module owner: $claim"
}
$overlap = @($rules | Group-Object { $_['ruleId'] } | Where-Object Count -gt 1 | Sort-Object Name)
Assert (($overlap.Name -join '|') -ceq 'OWNERSHIP-REFERENCE|RING-DIRECTION|RING-PACKAGE-FORBIDDEN') 'Canonical rule overlap drift.'
foreach ($group in $overlap) { Assert (@($group.Group | ForEach-Object claimId | Sort-Object -Unique).Count -eq 2 -and @($group.Group | ForEach-Object moduleId | Sort-Object -Unique).Count -eq 2) "Overlap ownership drift: $($group.Name)" }
$c1 = @($claimIds | Where-Object { $_ -eq 'ARCH.TYPE_DEPENDENCY' -or $_ -like 'IFX.C1.*' -or $_ -like 'IFX.L2.2.*' })
Assert ($c1.Count -eq 25 -and ($claimIds.Count - $c1.Count) -eq 54) 'C1/C2-C5 claim split drift.'

$runId = [Guid]::NewGuid().ToString('N')
$root = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { $EvidenceRoot } else { Join-Path $repo $EvidenceRoot }
$report = Join-Path $root $runId
$inventoryPath = Join-Path $report 'ordinal-inventory.json'
$sourceCommit = (& git -C $repo rev-parse HEAD).Trim()
Assert ($LASTEXITCODE -eq 0) 'Source commit unavailable.'
Write-Json $inventoryPath ([ordered]@{formatVersion=1;status='pass';scope='c6b0-source-module-claim-inventory';sourceCommit=$sourceCommit;baseVersion='1.1.3';baseArchiveSha256=$receipt.archiveSha256;basePackageHash=$baseCheck.packageHash;receiptSha256=Hash $receiptPath;c1R3SummarySha256=Hash $r3Path;c5fSummarySha256=Hash $c5Path;c1mDecisionSha256=Hash $decisionPath;g04Status='PRE-READY';g04BlockerCount=7;modules=@($modules.ToArray());rules=@($rules.ToArray());claimCount=$claimIds.Count;boundedDecisionCount=2;overlappingCanonicalRuleIds=@($overlap | ForEach-Object Name);deferred=@('G05-Phase9-eight','v3-pre-diff','v3-cross-platform-ubuntu-latest','v3-cross-platform-windows-latest')})
Write-Json (Join-Path $report 'summary.json') ([ordered]@{formatVersion=1;status='pass';baseVersion='1.1.3';moduleCount=$modules.Count;externalModuleCount=$map.Count;ruleCount=$rules.Count;claimCount=$claimIds.Count;blockingRuleCount=@($rules | Where-Object severity -CEQ 'blocking').Count;advisoryRuleCount=$advisory.Count;boundedDecisionCount=2;inventoryPath=[IO.Path]::GetRelativePath($repo,$inventoryPath).Replace('\','/');inventorySha256=Hash $inventoryPath;sourceCommit=$sourceCommit;limitations=@('No final bundle, combined Host result or human review is claimed.','Expiring evidence locks must be refreshed for C6b1/C6c.')})
Write-Output "IFX C6b0 module/claim inventory passed: $report"
