# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) successor of
# docs/guards/candidates/ifx-rebind-115/Test-IFX115ContractCompatibility.ps1.
# Derived by exact literal substitution for V4 Guards 1.1.6 from von12549/Guard and
# ifx-profile-candidate 0.4.4. The accepted script stays unchanged as historical authority.
[CmdletBinding()]
param(
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$PreviousInventoryPath='artifacts/guards/p10-ifx-116/formal-inventory/2113d50b2ba74eb49631ff0a6214aec8/ordinal-inventory.json',
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-116/contract-preflight'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Ok,[string]$Message){if(-not $Ok){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Full([string]$Path){if([IO.Path]::IsPathFullyQualified($Path)){[IO.Path]::GetFullPath($Path)}else{[IO.Path]::GetFullPath((Join-Path $repo $Path))}}
function WriteJson([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}

$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant();Assert ($LASTEXITCODE-eq0-and$commit-cmatch'^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked=@(& git -C $repo status --porcelain --untracked-files=no);Assert ($LASTEXITCODE-eq0-and-not$tracked) 'Tracked checkout must be clean for the contract handshake.'
$archive=Full $BaseArchivePath;$receiptPath=Full $BaseReceiptPath;$install=Full $BaseInstallRoot;$package=Join-Path $install 'package'
Assert ([IO.File]::Exists($archive)-and(Hash $archive)-ceq'92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8') '1.1.6 archive identity drift.'
Assert ([IO.File]::Exists($receiptPath)-and(Hash $receiptPath)-ceq'a5c47ac809d3bd29815f94d6f6481ddb59952c0435fc908c9ab3e71e9359e497') '1.1.6 receipt identity drift.'
$receipt=Get-Content $receiptPath -Raw|ConvertFrom-Json -Depth 100
Assert ($receipt.status-ceq'installed'-and$receipt.version-ceq'1.1.6'-and$receipt.archiveSha256-ceq(Hash $archive)-and$receipt.manifestSha256-ceq'37fb9073e30e57ca0e33a89ba41ed5aba46f061560c4e3ede2f2b6f569371f55') '1.1.6 receipt content drift.'
$packageCheck=& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $package 'core/runtime/Test-V4Package.ps1') -PackageRoot $package|ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE-eq0-and$packageCheck.status-ceq'pass'-and$packageCheck.packageHash-ceq'a09469f77956190fbffa827ff5b7da2a63b615d66bf47a86ad0d17c7207bc825') '1.1.6 Package identity drift.'
$tagCommit=((& git ls-remote https://github.com/von12549/Guard 'refs/tags/v4-guards-v1.1.6^{}') -split "`t")[0].Trim();Assert ($LASTEXITCODE-eq0-and$tagCommit-ceq'960678fd1a193d87d5c499f08e79e7ce0550d96a') '1.1.6 Guard tag/source drift.'

$profileSchema=Join-Path $package 'core/contracts/profile.schema.json';$workspaceSchema=Join-Path $package 'core/contracts/workspace-evidence.schema.json'
$profileSchemaObject=Get-Content $profileSchema -Raw|ConvertFrom-Json -Depth 100
$workspaceSchemaObject=Get-Content $workspaceSchema -Raw|ConvertFrom-Json -Depth 100
Assert ($null-ne$profileSchemaObject.properties.workspaceEvidence) 'Installed Profile schema lacks workspaceEvidence.'
Assert ((@($workspaceSchemaObject.required)-join'|')-ceq'formatVersion|scope|targetCommit|relativeRoots|extensions|excludedDirectoryNames|pathOrder|fileCount|treeSha256|startedAt|completedAt|elapsedSeconds|files') 'Workspace evidence required-field contract drift.'
Assert ($workspaceSchemaObject.properties.scope.const-ceq'v4-workspace-evidence-v1'-and$workspaceSchemaObject.properties.files.items.properties.normalizedSha256.pattern-ceq'^[a-f0-9]{64}$') 'Workspace evidence scope/hash contract drift.'

$map=[ordered]@{'ifx-domain-reference'='c1b';'ifx-project-name'='c1j';'ifx-g03-source-reconciliation'='c2c1';'ifx-g03-snapshots'='c2c2';'ifx-database-evidence'='c4b';'ifx-g05-inventory'='c4p0';'ifx-plan05-security'='c4s'}
$contractRows=[Collections.Generic.List[object]]::new()
foreach($id in $map.Keys){
 $root=Join-Path $repo "docs/guards/candidates/ifx-gate-coverage-$($map[$id])/modules/$id";$manifestPath=Join-Path $root 'module.json';$adapterPath=Join-Path $root 'adapter.ps1'
 Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $package 'core/contracts/module.schema.json') -ErrorAction Stop) "1.1.6 module schema incompatibility: $id"
 $manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 100;$adapter=[IO.File]::ReadAllText($adapterPath)
 Assert ('EvidenceRoot'-cin@($manifest.capabilities.readRoots)-and@($manifest.capabilities.writeRoots).Count-eq0-and-not$manifest.capabilities.network) "EvidenceRoot capability gap: $id"
 foreach($token in @('workspaceEvidencePath','workspaceEvidenceSha256','workspaceEvidenceTargetCommit','v4-workspace-evidence-v1')){Assert ($adapter.Contains($token)) "Workspace input token missing for ${id}: $token"}
 Assert ($adapter -match 'return \$null') "Direct-scan fallback is not explicit: $id"
 $contractRows.Add([ordered]@{moduleId=$id;manifestSha256=Hash $manifestPath;adapterSha256=Hash $adapterPath;declaredTimeoutSeconds=[int]$manifest.capabilities.timeoutSeconds;evidenceRootDeclared=$true;fallbackDeclared=$true})
}

$tempRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-116-contract-$([guid]::NewGuid().ToString('N'))";[void][IO.Directory]::CreateDirectory($tempRoot)
$workspacePath=Join-Path $tempRoot 'workspace-evidence.json';$watch=[Diagnostics.Stopwatch]::StartNew()
$producerOutput=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repo 'docs/guards/candidates/ifx-workspace-evidence/New-IFXWorkspaceEvidence.ps1') -TargetRoot $repo -OutputPath $workspacePath 2>&1);$producerExit=$LASTEXITCODE;$watch.Stop()
Assert ($producerExit-eq0-and[IO.File]::Exists($workspacePath)) "Workspace producer failed: $($producerOutput-join' ')"
Assert (Test-Json -LiteralPath $workspacePath -SchemaFile $workspaceSchema -ErrorAction Stop) 'Produced workspace evidence is not valid against installed 1.1.6 schema.'
$workspace=Get-Content $workspacePath -Raw|ConvertFrom-Json -Depth 30
Assert ($workspace.targetCommit-ceq$commit-and$workspace.pathOrder-ceq'ordinal'-and@($workspace.files).Count-eq$workspace.fileCount-and$workspace.fileCount-gt1000) 'Produced workspace evidence identity/cardinality drift.'
$paths=[string[]]@($workspace.files|ForEach-Object{[string]$_.path});$sorted=[string[]]$paths.Clone();[Array]::Sort($sorted,[StringComparer]::Ordinal);$unique=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($path in $paths){Assert ($unique.Add([string]$path)) "Workspace evidence path is duplicated: $path"};Assert (($paths-join"`n")-ceq($sorted-join"`n")) 'Workspace evidence is not ordinal.'

$previous=Get-Content (Full $PreviousInventoryPath) -Raw|ConvertFrom-Json -Depth 100
Assert ($previous.baseVersion-ceq'1.1.5'-and@($previous.modules).Count-eq37) 'Historical 1.1.5 comparison inventory drift.'
$moduleMap=[ordered]@{
 'ifx-domain-reference'='c1b';'ifx-package-reference'='c1c';'ifx-ring-graph'='c1d';'ifx-ownership-graph'='c1e';'ifx-provider-cycle'='c1f';'ifx-embedded-adapter'='c1g';'ifx-source-policy'='c1h';'ifx-project-name'='c1j';'ifx-reference-cycle'='c1n';'ifx-injection'='c1o';'ifx-c1-type-provenance'='c1r1b';'ifx-c1-evaluated-reference'='c1r2b';
 'ifx-g03-governance-core'='c2b1';'ifx-g03-catalog-semantics'='c2b2';'ifx-g03-source-reconciliation'='c2c1';'ifx-g03-snapshots'='c2c2';'ifx-g03-docs-closeout'='c2d';'ifx-g04-manifests'='c3b';'ifx-g04-runtime'='c3c';'ifx-g04-closeout'='c3d';'ifx-plan04-extraction'='c4a1';'ifx-plan04-tenant'='c4a2';'ifx-plan04-projection'='c4a3';'ifx-plan04-abstractions'='c4a4';'ifx-database-evidence'='c4b';
 'ifx-g05-inventory'='c4p0';'ifx-g05-protocol'='c4p1';'ifx-g05-execution-http'='c4p2';'ifx-g05-carriers'='c4p4p5';'ifx-g05-governance'='c4p6p7';'ifx-g05-closeout'='c4p8p11';'ifx-plan05-security'='c4s';'ifx-solution-evidence'='c5b';'ifx-assembly-evidence'='c5c';'ifx-frontend-evidence'='c5d';'ifx-history-integrity'='c5h'
}
$inheritance=[Collections.Generic.List[object]]::new()
foreach($id in $moduleMap.Keys){
 $old=@($previous.modules|Where-Object id -CEQ $id);Assert ($old.Count-eq1) "Historical inventory row missing: $id"
 $root=Join-Path $repo "docs/guards/candidates/ifx-gate-coverage-$($moduleMap[$id])/modules/$id";$manifestPath=Join-Path $root 'module.json';$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 100
 $authorityHash=[string](@($manifest.authorities|ForEach-Object{"$($_.id)|$($_.sha256)"})-join"`n");$oldAuthorityHash=[string](@($old[0].authorities|ForEach-Object{"$($_.id)|$($_.sha256)"})-join"`n")
 $current=[ordered]@{manifest=Hash $manifestPath;adapter=Hash (Join-Path $root 'adapter.ps1');dependencyLock=Hash (Join-Path $root 'dependencies.lock.json');rulePlan=Hash (Join-Path $root 'rule-execution-plan.json');authorities=$authorityHash}
 $exact=$current.manifest-ceq$old[0].manifestSha256-and$current.adapter-ceq$old[0].adapterSha256-and$current.dependencyLock-ceq$old[0].dependencyLockSha256-and$current.rulePlan-ceq$old[0].rulePlanSha256-and$authorityHash-ceq$oldAuthorityHash
 $disposition=if($exact){'inherit'}elseif($map.Contains($id)){'focused-requalification'}else{'unexpected-drift'}
 Assert ($disposition-cne'unexpected-drift') "Unplanned C1-C5 module drift: $id"
 $inheritance.Add([ordered]@{moduleId=$id;tranche=$moduleMap[$id];disposition=$disposition;old=[ordered]@{manifest=$old[0].manifestSha256;adapter=$old[0].adapterSha256;dependencyLock=$old[0].dependencyLockSha256;rulePlan=$old[0].rulePlanSha256;authorities=$oldAuthorityHash};current=$current})
}
$oldBuiltin=@($previous.modules|Where-Object id -CEQ 'architecture-conformance');Assert ($oldBuiltin.Count-eq1) 'Historical built-in row missing.'
$inheritance.Insert(10,[ordered]@{moduleId='architecture-conformance';tranche='published-base';disposition='base-rebind';old=[ordered]@{baseVersion='1.1.5';manifest=$oldBuiltin[0].manifestSha256};current=[ordered]@{baseVersion='1.1.6';manifest=Hash (Join-Path $package 'modules/architecture-conformance/module.json')}})
Assert (@($inheritance|Where-Object disposition -CEQ 'inherit').Count-eq36-and@($inheritance|Where-Object disposition -CEQ 'focused-requalification').Count-eq0-and@($inheritance).Count-eq37) 'Inheritance matrix disposition count drift.'

$runId=[guid]::NewGuid().ToString('N');$root=Join-Path (Full $EvidenceRoot) $runId;[void][IO.Directory]::CreateDirectory($root)
$matrixPath=Join-Path $root 'c1-c5-inheritance-matrix.json';WriteJson $matrixPath ([ordered]@{formatVersion=1;status='pass';targetCommit=$commit;historicalBaseVersion='1.1.5';currentBaseVersion='1.1.6';rows=@($inheritance.ToArray())})
$report=Join-Path $root 'summary.json';WriteJson $report ([ordered]@{formatVersion=1;status='pass';scope='v4-1.1.6-ifx-contract-handshake';targetCommit=$commit;base=[ordered]@{tagCommit=$tagCommit;archiveSha256=Hash $archive;receiptSha256=Hash $receiptPath;manifestSha256=$receipt.manifestSha256;packageHash=$packageCheck.packageHash};workspaceEvidence=[ordered]@{schemaSha256=Hash $workspaceSchema;producerElapsedSeconds=[math]::Round($watch.Elapsed.TotalSeconds,3);fileCount=$workspace.fileCount;sha256=Hash $workspacePath;targetCommit=$workspace.targetCommit};consumers=@($contractRows.ToArray());inheritanceMatrixPath=[IO.Path]::GetRelativePath($repo,$matrixPath).Replace('\','/');inheritanceMatrixSha256=Hash $matrixPath;inheritedModuleCount=36;focusedModuleCount=0;hostContractRequalifiedCount=7;baseRebindModuleCount=1})
Write-Output "IFX 1.1.6 contract handshake passed: $report"
