# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) steps A1-5 and A1-6: the C6 chain of
# ifx_profile 0.5.0; successor of candidates/ifx-rebind-116/Invoke-IFX116C6Chain.ps1 (unchanged). Every output must be
# absent; nothing is repaired or rerun in place. Steps: 0.5.0-a inventory; contract handshake against 0.4.4; one
# evidence production on a clean clone of HEAD (for the candidate's Host runs and the focused qualification); two
# deterministic candidates; focused qualification; then readiness and the single C6c (Invoke-IFX050C6c.ps1), which
# produces its own evidence. -ReadinessOnly stops after the readiness report (A1-5) and needs no authorization.
[CmdletBinding()]
param(
    [switch]$AuthorizeA16C6c,
    [switch]$ReadinessOnly,
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-i2b',
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath = 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$CandidateVersion = '0.5.0'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Rel([string]$Path) { [IO.Path]::GetRelativePath($repo, $Path).Replace('\', '/') }
function WriteJson([string]$Path, $Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }
function Step([string]$Id, [string]$Script, [string[]]$Arguments) {
    $log = Join-Path $logRoot "$Id.log"; $started = [DateTimeOffset]::UtcNow
    $lines = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1); $code = $LASTEXITCODE; $completed = [DateTimeOffset]::UtcNow
    [IO.File]::WriteAllLines($log, @($lines | ForEach-Object { $_.ToString() }), [Text.UTF8Encoding]::new($false))
    $steps.Add([ordered]@{ id = $Id; script = Rel $Script; exitCode = $code; startedAt = $started.ToString('o'); completedAt = $completed.ToString('o'); elapsedSeconds = [math]::Round(($completed - $started).TotalSeconds, 3); log = Rel $log; logSha256 = Hash $log })
    WriteJson $chainReport ([ordered]@{ formatVersion = 1; status = 'running'; targetCommit = $commit; steps = @($steps.ToArray()) })
    Assert ($code -eq 0) "Step $Id failed with exit $code; see $log"
}
function OnlyChild([string]$Root) { $dirs = @(Get-ChildItem -LiteralPath (Full $Root) -Directory); Assert ($dirs.Count -eq 1) "Expected exactly one run directory below $Root"; $dirs[0].FullName }

Assert ($ReadinessOnly.IsPresent -or $AuthorizeA16C6c.IsPresent) 'The full chain requires -AuthorizeA16C6c; use -ReadinessOnly for A1-5.'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit = (& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant(); Assert ($LASTEXITCODE -eq 0 -and $commit -cmatch '^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked = @(& git -C $repo status --porcelain --untracked-files=no); Assert ($LASTEXITCODE -eq 0 -and -not $tracked) 'The C6 chain requires a clean tracked target.'
$root = Full $EvidenceRoot; $archive = Full $BaseArchivePath
Assert ([IO.File]::Exists($archive) -and (Hash $archive) -ceq '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8') '1.1.6 base archive missing or drifted.'
Assert ((Hash $BaseReceiptPath) -ceq 'a5c47ac809d3bd29815f94d6f6481ddb59952c0435fc908c9ab3e71e9359e497') '1.1.6 receipt drift.'
$absent = @('formal-inventory', 'contract-preflight', 'chain-production', 'formal-candidate-a', 'formal-candidate-b', 'focused-qualification-050', 'readiness', 'c6c-full', 'c6c-attempt.json', 'c6c-decision.json', 'chain', 'a1-chain.json')
foreach ($name in $absent) { Assert (-not (Test-Path -LiteralPath (Join-Path $root $name))) "Output already exists: $name" }
$logRoot = Join-Path $root 'chain'; [void][IO.Directory]::CreateDirectory($logRoot)
$chainReport = Join-Path $root 'a1-chain.json'; $steps = [Collections.Generic.List[object]]::new(); $chainStarted = [DateTimeOffset]::UtcNow
try {
    # 1. Inventory; 2. contract handshake and inheritance from 0.4.4.
    Step 'inventory' (Join-Path $PSScriptRoot 'Test-IFX050ModuleInventory.ps1') @('-EvidenceRoot', "$EvidenceRoot/formal-inventory", '-BaseInstallRoot', $BaseInstallRoot, '-BaseReceiptPath', $BaseReceiptPath)
    $inventory = Join-Path (OnlyChild "$EvidenceRoot/formal-inventory") 'ordinal-inventory.json'
    Step 'contract' (Join-Path $PSScriptRoot 'Test-IFX050ContractCompatibility.ps1') @('-InventoryPath', $inventory, '-EvidenceRoot', "$EvidenceRoot/contract-preflight")
    $contract = Join-Path (OnlyChild "$EvidenceRoot/contract-preflight") 'summary.json'

    # 3. One production at HEAD on a clean clone (the candidate's Host runs and the focused qualification stage it).
    $target = Join-Path ([IO.Path]::GetTempPath()) "ifx-050-chain-target-$([guid]::NewGuid().ToString('N'))"
    $o = @(& git clone --no-local --quiet $repo $target 2>&1); Assert ($LASTEXITCODE -eq 0) "Chain target clone failed: $($o -join ' ')"
    $production = Join-Path $root 'chain-production/production.json'; [void][IO.Directory]::CreateDirectory((Split-Path -Parent $production))
    Step 'production' (Join-Path $PSScriptRoot 'Invoke-IFX050EvidenceProducers.ps1') @('-Phase', 'Produce', '-TargetRoot', $target, '-RunRecordPath', $production)

    # 4. Two independent deterministic candidates (A with Host validation, B composition only).
    $bundleArgs = @('-InventoryPath', $inventory, '-ProductionRecord', $production, '-TargetRoot', $target, '-BaseInstallRoot', $BaseInstallRoot, '-BaseReceiptPath', $BaseReceiptPath, '-BaseArchivePath', $archive, '-CandidateVersion', $CandidateVersion)
    Step 'candidate-a' (Join-Path $PSScriptRoot 'New-IFX050DraftBundle.ps1') ($bundleArgs + @('-EvidenceRoot', "$EvidenceRoot/formal-candidate-a"))
    Step 'candidate-b' (Join-Path $PSScriptRoot 'New-IFX050DraftBundle.ps1') ($bundleArgs + @('-EvidenceRoot', "$EvidenceRoot/formal-candidate-b", '-SkipHost'))
    $candidateA = OnlyChild "$EvidenceRoot/formal-candidate-a"; $candidateB = OnlyChild "$EvidenceRoot/formal-candidate-b"; $bundle = Join-Path $candidateA 'bundle'

    # 5. Focused requalification of the seven workspace-evidence consumers on the 1.1.6 Host.
    Step 'focused' (Join-Path $PSScriptRoot 'Test-IFX050FocusedQualification.ps1') @('-BundleRoot', $bundle, '-TargetRoot', $target, '-ProductionRecord', $production, '-EvidenceRoot', "$EvidenceRoot/focused-qualification-050")
    $focused = Join-Path (OnlyChild "$EvidenceRoot/focused-qualification-050") 'summary.json'
    $c6cArgs = @('-InventoryPath', $inventory, '-WindowsCandidateSummaryPath', (Join-Path $candidateA 'summary.json'), '-SecondCandidateSummaryPath', (Join-Path $candidateB 'summary.json'), '-ContractSummaryPath', $contract, '-FocusedSummaryPath', $focused)

    # 6. Readiness only (A1-5), or readiness and the single authorized C6c (A1-6).
    if ($ReadinessOnly) { Step 'readiness' (Join-Path $PSScriptRoot 'Test-IFX050C6cReadiness.ps1') ($c6cArgs + @('-ReportPath', "$EvidenceRoot/readiness/summary.json")); $decision = $null }
    else {
        Step 'c6c' (Join-Path $PSScriptRoot 'Invoke-IFX050C6c.ps1') ($c6cArgs + @('-BundleRoot', $bundle, '-ReviewRecordPath', (Join-Path $candidateA 'synthetic-review.json'), '-AuthorizeA16C6c'))
        $decision = Full "$EvidenceRoot/c6c-decision.json"
    }
    $status = 'pass'; $failure = $null
} catch { $status = 'failed'; $failure = $_.Exception.Message }
$chainCompleted = [DateTimeOffset]::UtcNow
$report = [ordered]@{ formatVersion = 1; status = $status; step = $(if ($ReadinessOnly) { 'A1-5' } else { 'A1-6' }); targetCommit = $commit; baseVersion = '1.1.6'; candidateVersion = $CandidateVersion
    startedAt = $chainStarted.ToString('o'); completedAt = $chainCompleted.ToString('o'); elapsedSeconds = [math]::Round(($chainCompleted - $chainStarted).TotalSeconds, 3); failure = $failure; steps = @($steps.ToArray()) }
if ($status -ceq 'pass') {
    $report.outputs = [ordered]@{ inventory = [ordered]@{ path = Rel $inventory; sha256 = Hash $inventory }; contract = [ordered]@{ path = Rel $contract; sha256 = Hash $contract }; production = [ordered]@{ path = Rel $production; sha256 = Hash $production }
        candidateA = Rel $candidateA; candidateB = Rel $candidateB; bundleManifestSha256 = Hash (Join-Path $bundle 'bundle-manifest.json'); focused = [ordered]@{ path = Rel $focused; sha256 = Hash $focused }
        decision = $(if ($decision) { [ordered]@{ path = Rel $decision; sha256 = Hash $decision } } else { $null }) }
}
WriteJson $chainReport $report
Write-Output "IFX 0.5.0-a C6 chain ($($report.step)) $status`: $chainReport"
if ($status -cne 'pass') { exit 1 }
