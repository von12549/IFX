# V4-TODO-008 T7 (Plan 20260928-v4-todo-008-t7-ifx-consumer-rebinding) step R3 orchestrator.
# Runs the accepted C6 chain for ifx-profile-candidate 0.4.3 on V4 Guards 1.1.5 in one continuous
# workflow: module inventory, contract handshake, seven fresh evidence locks, two deterministic
# candidates, focused qualification, readiness and the single authorized C6c. Every output path must
# be absent; nothing is repaired or rerun in place.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][switch]$AuthorizeT7C6c,
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-115',
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.5',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.5.install.json',
    [string]$CandidateVersion = '0.4.3'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Rel([string]$Path) { [IO.Path]::GetRelativePath($repo, $Path).Replace('\','/') }
function WriteJson([string]$Path,$Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n") + "`n"),[Text.UTF8Encoding]::new($false)) }
function NewRunId { [guid]::NewGuid().ToString('N') }
function Step([string]$Id,[string]$Script,[string[]]$Arguments) {
    $log = Join-Path $logRoot "$Id.log"
    $started = [DateTimeOffset]::UtcNow
    $lines = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1)
    $code = $LASTEXITCODE
    $completed = [DateTimeOffset]::UtcNow
    [IO.File]::WriteAllLines($log, @($lines | ForEach-Object { $_.ToString() }), [Text.UTF8Encoding]::new($false))
    $row = [ordered]@{ id = $Id; script = Rel $Script; exitCode = $code; startedAt = $started.ToString('o'); completedAt = $completed.ToString('o'); elapsedSeconds = [math]::Round(($completed - $started).TotalSeconds, 3); log = Rel $log; logSha256 = Hash $log }
    $steps.Add($row)
    WriteJson $chainReport ([ordered]@{ formatVersion = 1; status = 'running'; targetCommit = $commit; steps = @($steps.ToArray()) })
    Assert ($code -eq 0) "Step $Id failed with exit $code; see $log"
    return $lines
}
function OnlyChild([string]$Root) {
    $dirs = @(Get-ChildItem -LiteralPath (Full $Root) -Directory)
    Assert ($dirs.Count -eq 1) "Expected exactly one run directory below $Root"
    return $dirs[0].FullName
}

Assert $AuthorizeT7C6c.IsPresent 'The T7 C6 chain requires the explicit -AuthorizeT7C6c switch.'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$candidates = Join-Path $repo 'docs/guards/candidates'
$commit = (& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
Assert ($LASTEXITCODE -eq 0 -and $commit -cmatch '^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked = @(& git -C $repo status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and -not $tracked) 'The T7 C6 chain requires a clean tracked target.'

$root = Full $EvidenceRoot
$archive = Join-Path $root 'base-archive/v4-guards-1.1.5.zip'
Assert ([IO.File]::Exists($archive) -and (Hash $archive) -ceq '74c371ebca73186d5ef636669a226960982c5c28b13532bc5972cbcdffee3976') '1.1.5 base archive missing or drifted.'
Assert ((Hash $BaseReceiptPath) -ceq '622f3d0cb8e8fc8ead33444931605bc81e23e9cc3628a84384bb4379bb839b31') '1.1.5 receipt drift.'
$absent = @('formal-inventory','contract-preflight','generated-runs','formal-candidate-a','formal-candidate-b','focused-qualification-043','readiness','c6c-full','c6c-attempt.json','c6c-decision.json','chain','r3-chain.json')
foreach ($name in $absent) { Assert (-not (Test-Path -LiteralPath (Join-Path $root $name))) "Output already exists: $name" }
$logRoot = Join-Path $root 'chain'; [void][IO.Directory]::CreateDirectory($logRoot)
$chainReport = Join-Path $root 'r3-chain.json'
$steps = [Collections.Generic.List[object]]::new()
$chainStarted = [DateTimeOffset]::UtcNow

try {
    # 1. Module/claim inventory against the 1.1.5 base.
    [void](Step 'inventory' (Join-Path $candidates 'ifx-gate-coverage-c6b0/Test-IFXC6ModuleInventory.ps1') @(
        '-EvidenceRoot', "$EvidenceRoot/formal-inventory", '-BaseInstallRoot', $BaseInstallRoot, '-BaseReceiptPath', $BaseReceiptPath,
        '-ExpectedBaseVersion', '1.1.5', '-ExpectedArchiveSha256', '74c371ebca73186d5ef636669a226960982c5c28b13532bc5972cbcdffee3976',
        '-ExpectedPackageHash', 'e8cd32697709e8ca155b051ddbf731e12b65bad42858eafd92cddb0ee4dbf733'))
    $inventory = Join-Path (OnlyChild "$EvidenceRoot/formal-inventory") 'ordinal-inventory.json'

    # 2. Contract handshake and inheritance from the accepted 1.1.4 inventory.
    [void](Step 'contract' (Join-Path $PSScriptRoot 'Test-IFX115ContractCompatibility.ps1') @('-EvidenceRoot', "$EvidenceRoot/contract-preflight"))
    $contract = Join-Path (OnlyChild "$EvidenceRoot/contract-preflight") 'summary.json'

    # 3. Seven fresh evidence locks at the Target commit; the one-hour locks are produced last.
    $solutionId = NewRunId; $assemblyId = NewRunId; $frontendId = NewRunId; $databaseId = NewRunId; $graphId = NewRunId; $typeId = NewRunId
    [void](Step 'lock-solution' (Join-Path $candidates 'ifx-gate-coverage-c5b/Invoke-IFXSolutionEvidenceProducer.ps1') @('-RunId', $solutionId))
    $solutionLock = "artifacts/guards/p10-ifx-c5b/solution-runs/$solutionId/evidence-lock.json"
    [void](Step 'lock-assembly' (Join-Path $candidates 'ifx-gate-coverage-c5c/Invoke-IFXAssemblyEvidenceProducer.ps1') @('-SolutionLockPath', $solutionLock, '-RunId', $assemblyId))
    $assemblyLock = "artifacts/guards/p10-ifx-c5c/assembly-runs/$assemblyId/evidence-lock.json"
    [void](Step 'lock-frontend' (Join-Path $candidates 'ifx-gate-coverage-c5d/Invoke-IFXFrontendEvidenceProducer.ps1') @('-RunId', $frontendId))
    $frontendLock = "artifacts/guards/p10-ifx-c5d/frontend-runs/$frontendId/evidence-lock.json"
    [void](Step 'lock-database' (Join-Path $candidates 'ifx-gate-coverage-c4b/Invoke-IFXDatabaseEvidenceProducer.ps1') @('-RunId', $databaseId))
    $databaseLock = "artifacts/guards/p10-ifx-c4b/database-runs/$databaseId/evidence-lock.json"
    [void](Step 'lock-graph' (Join-Path $candidates 'ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1') @('-RunId', $graphId))
    $graphLock = "artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/$graphId/evidence-lock.json"
    [void](Step 'lock-generated' (Join-Path $candidates 'ifx-gate-coverage-c1r2c/Test-IFXGeneratedInputDisposition.ps1') @('-SolutionLockPath', $solutionLock, '-EvidenceRoot', "$EvidenceRoot/generated-runs"))
    $generatedLock = Rel (Join-Path (OnlyChild "$EvidenceRoot/generated-runs") 'evidence-lock.json')
    [void](Step 'lock-type' (Join-Path $candidates 'ifx-gate-coverage-c1r1b/Invoke-IFXCompiledTypeEvidenceProducer.ps1') @('-SolutionLockPath', $solutionLock, '-AssemblyLockPath', $assemblyLock, '-RunId', $typeId))
    $typeLock = "artifacts/guards/p10-ifx-c1-r1b/type-runs/$typeId/evidence-lock.json"
    foreach ($lock in @($solutionLock,$assemblyLock,$frontendLock,$databaseLock,$graphLock,$generatedLock,$typeLock)) { Assert ([IO.File]::Exists((Full $lock))) "Evidence lock missing: $lock" }

    # 4. Two independent deterministic candidates (A with Host validation, B composition only).
    $bundleArgs = @('-InventoryPath', $inventory, '-SolutionLockPath', $solutionLock, '-AssemblyLockPath', $assemblyLock, '-FrontendLockPath', $frontendLock,
        '-DatabaseLockPath', $databaseLock, '-TypeLockPath', $typeLock, '-GraphLockPath', $graphLock, '-GeneratedLockPath', $generatedLock,
        '-BaseInstallRoot', $BaseInstallRoot, '-BaseReceiptPath', $BaseReceiptPath, '-BaseArchivePath', $archive, '-ExpectedBaseVersion', '1.1.5',
        '-ExpectedArchiveSha256', '74c371ebca73186d5ef636669a226960982c5c28b13532bc5972cbcdffee3976', '-CandidateVersion', $CandidateVersion, '-EnableWorkspaceEvidence')
    [void](Step 'candidate-a' (Join-Path $candidates 'ifx-gate-coverage-c6b1/Test-IFXC6DraftBundle.ps1') ($bundleArgs + @('-EvidenceRoot', "$EvidenceRoot/formal-candidate-a")))
    [void](Step 'candidate-b' (Join-Path $candidates 'ifx-gate-coverage-c6b1/Test-IFXC6DraftBundle.ps1') ($bundleArgs + @('-EvidenceRoot', "$EvidenceRoot/formal-candidate-b", '-SkipHost')))
    $candidateA = OnlyChild "$EvidenceRoot/formal-candidate-a"; $candidateB = OnlyChild "$EvidenceRoot/formal-candidate-b"
    $bundle = Join-Path $candidateA 'bundle'

    # 5. Focused requalification of the seven workspace-evidence consumers on the 1.1.5 Host.
    [void](Step 'focused' (Join-Path $PSScriptRoot 'Test-IFX115FocusedQualification.ps1') @('-BundleRoot', $bundle, '-EvidenceRoot', "$EvidenceRoot/focused-qualification-043"))
    $focused = Join-Path (OnlyChild "$EvidenceRoot/focused-qualification-043") 'summary.json'

    # 6. Readiness, then the single authorized C6c.
    [void](Step 'c6c' (Join-Path $PSScriptRoot 'Invoke-IFX115C6c.ps1') @('-InventoryPath', $inventory, '-BundleRoot', $bundle,
        '-ReviewRecordPath', (Join-Path $candidateA 'synthetic-review.json'), '-WindowsCandidateSummaryPath', (Join-Path $candidateA 'summary.json'),
        '-SecondCandidateSummaryPath', (Join-Path $candidateB 'summary.json'), '-ContractSummaryPath', $contract, '-FocusedSummaryPath', $focused, '-AuthorizeT7C6c'))
    $decision = Full "$EvidenceRoot/c6c-decision.json"
    $status = 'pass'; $failure = $null
} catch {
    $status = 'failed'; $failure = $_.Exception.Message
}

$chainCompleted = [DateTimeOffset]::UtcNow
$report = [ordered]@{
    formatVersion = 1; status = $status; step = 'T7-R3'; targetCommit = $commit; baseVersion = '1.1.5'; candidateVersion = $CandidateVersion
    startedAt = $chainStarted.ToString('o'); completedAt = $chainCompleted.ToString('o'); elapsedSeconds = [math]::Round(($chainCompleted - $chainStarted).TotalSeconds, 3)
    failure = $failure; steps = @($steps.ToArray())
}
if ($status -ceq 'pass') {
    $report.outputs = [ordered]@{
        inventory = [ordered]@{ path = Rel $inventory; sha256 = Hash $inventory }
        contract = [ordered]@{ path = Rel $contract; sha256 = Hash $contract }
        locks = @($solutionLock,$assemblyLock,$frontendLock,$databaseLock,$graphLock,$generatedLock,$typeLock | ForEach-Object { [ordered]@{ path = $_; sha256 = Hash (Full $_) } })
        candidateA = Rel $candidateA; candidateB = Rel $candidateB
        bundleManifestSha256 = Hash (Join-Path $bundle 'bundle-manifest.json')
        focused = [ordered]@{ path = Rel $focused; sha256 = Hash $focused }
        decision = [ordered]@{ path = Rel $decision; sha256 = Hash $decision }
    }
}
WriteJson $chainReport $report
Write-Output "T7 R3 C6 chain $status`: $chainReport"
if ($status -cne 'pass') { exit 1 }
