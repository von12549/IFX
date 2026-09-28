# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) successor of
# docs/guards/candidates/ifx-rebind-115/Invoke-IFX115C6Chain.ps1.
# Derived by exact literal substitution for V4 Guards 1.1.6 from von12549/Guard and
# ifx-profile-candidate 0.4.4 (step S5 orchestrator). The accepted script stays unchanged as historical authority.
# be absent; nothing is repaired or rerun in place.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][switch]$AuthorizeI1C6c,
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-116',
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$CandidateVersion = '0.4.4'
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

Assert $AuthorizeI1C6c.IsPresent 'The I1 C6 chain requires the explicit -AuthorizeI1C6c switch.'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$candidates = Join-Path $repo 'docs/guards/candidates'
$commit = (& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
Assert ($LASTEXITCODE -eq 0 -and $commit -cmatch '^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked = @(& git -C $repo status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and -not $tracked) 'The I1 C6 chain requires a clean tracked target.'

$root = Full $EvidenceRoot
$archive = Join-Path $root 'base-archive/v4-guards-1.1.6.zip'
Assert ([IO.File]::Exists($archive) -and (Hash $archive) -ceq '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8') '1.1.6 base archive missing or drifted.'
Assert ((Hash $BaseReceiptPath) -ceq 'a5c47ac809d3bd29815f94d6f6481ddb59952c0435fc908c9ab3e71e9359e497') '1.1.6 receipt drift.'
$absent = @('formal-inventory','contract-preflight','generated-runs','formal-candidate-a','formal-candidate-b','focused-qualification-044','readiness','c6c-full','c6c-attempt.json','c6c-decision.json','chain','r3-chain.json')
foreach ($name in $absent) { Assert (-not (Test-Path -LiteralPath (Join-Path $root $name))) "Output already exists: $name" }
$logRoot = Join-Path $root 'chain'; [void][IO.Directory]::CreateDirectory($logRoot)
$chainReport = Join-Path $root 'r3-chain.json'
$steps = [Collections.Generic.List[object]]::new()
$chainStarted = [DateTimeOffset]::UtcNow

try {
    # 1. Module/claim inventory against the 1.1.6 base.
    [void](Step 'inventory' (Join-Path $candidates 'ifx-gate-coverage-c6b0/Test-IFXC6ModuleInventory.ps1') @(
        '-EvidenceRoot', "$EvidenceRoot/formal-inventory", '-BaseInstallRoot', $BaseInstallRoot, '-BaseReceiptPath', $BaseReceiptPath,
        '-ExpectedBaseVersion', '1.1.6', '-ExpectedArchiveSha256', '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
        '-ExpectedPackageHash', 'a09469f77956190fbffa827ff5b7da2a63b615d66bf47a86ad0d17c7207bc825'))
    $inventory = Join-Path (OnlyChild "$EvidenceRoot/formal-inventory") 'ordinal-inventory.json'

    # 2. Contract handshake and inheritance from the accepted T7 1.1.5 inventory.
    [void](Step 'contract' (Join-Path $PSScriptRoot 'Test-IFX116ContractCompatibility.ps1') @('-EvidenceRoot', "$EvidenceRoot/contract-preflight"))
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
        '-BaseInstallRoot', $BaseInstallRoot, '-BaseReceiptPath', $BaseReceiptPath, '-BaseArchivePath', $archive, '-ExpectedBaseVersion', '1.1.6',
        '-ExpectedArchiveSha256', '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8', '-CandidateVersion', $CandidateVersion, '-EnableWorkspaceEvidence')
    [void](Step 'candidate-a' (Join-Path $candidates 'ifx-gate-coverage-c6b1/Test-IFXC6DraftBundle.ps1') ($bundleArgs + @('-EvidenceRoot', "$EvidenceRoot/formal-candidate-a")))
    [void](Step 'candidate-b' (Join-Path $candidates 'ifx-gate-coverage-c6b1/Test-IFXC6DraftBundle.ps1') ($bundleArgs + @('-EvidenceRoot', "$EvidenceRoot/formal-candidate-b", '-SkipHost')))
    $candidateA = OnlyChild "$EvidenceRoot/formal-candidate-a"; $candidateB = OnlyChild "$EvidenceRoot/formal-candidate-b"
    $bundle = Join-Path $candidateA 'bundle'

    # 5. Focused requalification of the seven workspace-evidence consumers on the 1.1.6 Host.
    [void](Step 'focused' (Join-Path $PSScriptRoot 'Test-IFX116FocusedQualification.ps1') @('-BundleRoot', $bundle, '-EvidenceRoot', "$EvidenceRoot/focused-qualification-044"))
    $focused = Join-Path (OnlyChild "$EvidenceRoot/focused-qualification-044") 'summary.json'

    # 6. Readiness, then the single authorized C6c.
    [void](Step 'c6c' (Join-Path $PSScriptRoot 'Invoke-IFX116C6c.ps1') @('-InventoryPath', $inventory, '-BundleRoot', $bundle,
        '-ReviewRecordPath', (Join-Path $candidateA 'synthetic-review.json'), '-WindowsCandidateSummaryPath', (Join-Path $candidateA 'summary.json'),
        '-SecondCandidateSummaryPath', (Join-Path $candidateB 'summary.json'), '-ContractSummaryPath', $contract, '-FocusedSummaryPath', $focused, '-AuthorizeI1C6c'))
    $decision = Full "$EvidenceRoot/c6c-decision.json"
    $status = 'pass'; $failure = $null
} catch {
    $status = 'failed'; $failure = $_.Exception.Message
}

$chainCompleted = [DateTimeOffset]::UtcNow
$report = [ordered]@{
    formatVersion = 1; status = $status; step = 'I1-S5'; targetCommit = $commit; baseVersion = '1.1.6'; candidateVersion = $CandidateVersion
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
Write-Output "I1 S5 C6 chain $status`: $chainReport"
if ($status -cne 'pass') { exit 1 }
