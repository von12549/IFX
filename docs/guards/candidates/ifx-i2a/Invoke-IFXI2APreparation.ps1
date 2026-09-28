# IFX I2-A (Plan 20260929-v4-ifx-i2a-installed-webui) steps A1 and A5: verify the frozen I1 inputs and
# record, then re-check, the inventories and Git facts of every protected root around the installed Web UI
# session. Phase Pre refuses existing outputs; Phase Post compares with the Pre record and never repairs.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Pre','Post')][string] $Phase,
    [string] $OutputRoot = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-116/i2a-webui-044',
    [string] $RuntimeRoot = 'D:/IFX-Root/guard-runtime',
    [string] $RepositoryRoot = 'D:/IFX-Root/IFX'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string] $Message) { throw $Message }
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function TextHash([string] $Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($Text))).ToLowerInvariant() }
function Write-Json([string] $Path, $Value) {
    if (Test-Path -LiteralPath $Path) { Fail "Output already exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 50).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
function Inventory([string] $Root) {
    $rows = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/'))|$($_.Length)|$(Hash $_.FullName)"
    } | Sort-Object -CaseSensitive)
    [ordered]@{ root = $Root; fileCount = $rows.Count; sha256 = TextHash (($rows -join "`n") + "`n") }
}
function GitFacts([string] $Root) {
    $head = (& git -C $Root rev-parse HEAD).Trim()
    & git -C $Root symbolic-ref -q HEAD *> $null; $detached = ($LASTEXITCODE -ne 0)
    $status = @(& git -C $Root status --porcelain=v1 --untracked-files=all)
    [ordered]@{ root = $Root; head = $head; detached = $detached; status = $status }
}

$targetCommit = '44536a6a2738004cfae5645f1d2d1206679d9b5d'
$roots = [ordered]@{
    baseInstall = "$RuntimeRoot/releases/v4-guards-1.1.6"
    composedInstall = "$RuntimeRoot/releases/v4-guards-1.1.6-ifx-0.4.4"
    cleanTarget = "$RuntimeRoot/fixtures/ifx-i1-clean-044"
    violatingTarget = "$RuntimeRoot/fixtures/ifx-i1-violating-044"
}
$stateRoot = "$RuntimeRoot/state/ifx-i2a-044-webui"
$evidenceRoot = "$RuntimeRoot/evidence/ifx-i2a-044-webui"
$baseReceipt = "$RuntimeRoot/receipts/v4-guards-1.1.6.install.json"
$composeReceipt = "$RuntimeRoot/receipts/v4-guards-1.1.6-ifx-0.4.4.compose.json"
$s7Decision = "$RepositoryRoot/artifacts/guards/p10-ifx-116/s7-044/s7-decision.json"
$fault = 'src/Modules/CRM/IFX.Modules.CRM.Domain/I1S7Fault.cs'

if ($Phase -ceq 'Pre') {
    if (Test-Path -LiteralPath $OutputRoot) { Fail "OutputRoot must be absent: $OutputRoot" }
    foreach ($p in @($stateRoot, $evidenceRoot)) { if (Test-Path -LiteralPath $p) { Fail "Session root must be absent: $p" } }
    if ((Hash $baseReceipt) -cne 'a5c47ac809d3bd29815f94d6f6481ddb59952c0435fc908c9ab3e71e9359e497') { Fail 'Base receipt drift.' }
    if ((Hash $composeReceipt) -cne 'a75e67bc7ff993968cf4906bea2568f5d306987316033c068b72c875f96047fd') { Fail 'Composition receipt drift.' }
    if ((Hash $s7Decision) -cne '77acf8ad837ed7d9aee3fd04293f926dda53fb66a961a3fdd7d282661b9218bc') { Fail 'S7 decision drift.' }
    $verifier = "$($roots.baseInstall)/package/core/distribution/Test-V4ComposedInstallation.ps1"
    $proofText = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $verifier -InstallRoot $roots.composedInstall -ReceiptPath $composeReceipt -BaseReceiptPath $baseReceipt 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { Fail "Public composition verifier failed: $proofText" }
    $proof = $proofText | ConvertFrom-Json -Depth 50
    if ($proof.status -cne 'pass' -or [string]$proof.packageHash -cne 'bea54366341289bda0d82dd9bfb9c0653864ff614ebc9ddebbeda47ff090d37a') { Fail 'Composition proof mismatch.' }
    $clean = GitFacts $roots.cleanTarget; $violating = GitFacts $roots.violatingTarget
    if ($clean.head -cne $targetCommit -or -not $clean.detached -or $clean.status.Count -ne 0) { Fail 'Clean Target is not a clean detached worktree at the Target commit.' }
    if ($violating.head -cne $targetCommit -or -not $violating.detached -or ($violating.status -join '|') -cne "?? $fault") { Fail 'Violating Target does not hold exactly the deliberate fault file.' }
    [void][IO.Directory]::CreateDirectory($OutputRoot)
    $inv = [ordered]@{}; foreach ($k in $roots.Keys) { $inv[$k] = Inventory $roots[$k] }
    Write-Json (Join-Path $OutputRoot 'pre-inventories.json') ([ordered]@{ formatVersion = 1; roots = $inv })
    Write-Json (Join-Path $OutputRoot 'pre-git-facts.json') ([ordered]@{ formatVersion = 1; clean = $clean; violating = $violating })
    Write-Json (Join-Path $OutputRoot 'composition-proof.json') $proof
    Write-Json (Join-Path $OutputRoot 'preparation-summary.json') ([ordered]@{
        formatVersion = 1; status = 'pass'; planId = '20260929-v4-ifx-i2a-installed-webui'; step = 'A1'; preparedAt = [DateTimeOffset]::UtcNow.ToString('o')
        targetCommit = $targetCommit; composedInstall = $roots.composedInstall; composeReceipt = $composeReceipt; baseReceipt = $baseReceipt
        stateRoot = $stateRoot; evidenceRoot = $evidenceRoot; packageHash = $proof.packageHash
        s7DecisionSha256 = Hash $s7Decision; preInventoriesSha256 = Hash (Join-Path $OutputRoot 'pre-inventories.json'); preGitFactsSha256 = Hash (Join-Path $OutputRoot 'pre-git-facts.json')
    })
    Write-Output "I2-A preparation passed: $OutputRoot"
} else {
    $pre = Get-Content -Raw -LiteralPath (Join-Path $OutputRoot 'pre-inventories.json') | ConvertFrom-Json -Depth 50
    $preGit = Get-Content -Raw -LiteralPath (Join-Path $OutputRoot 'pre-git-facts.json') | ConvertFrom-Json -Depth 50
    $inv = [ordered]@{}; $changed = [Collections.Generic.List[string]]::new()
    foreach ($k in $roots.Keys) { $inv[$k] = Inventory $roots[$k]; if ($inv[$k].sha256 -cne [string]$pre.roots.$k.sha256) { $changed.Add($k) } }
    $clean = GitFacts $roots.cleanTarget; $violating = GitFacts $roots.violatingTarget
    $gitSame = ($clean | ConvertTo-Json -Depth 10) -ceq ($preGit.clean | ConvertTo-Json -Depth 10) -and ($violating | ConvertTo-Json -Depth 10) -ceq ($preGit.violating | ConvertTo-Json -Depth 10)
    Write-Json (Join-Path $OutputRoot 'post-inventories.json') ([ordered]@{ formatVersion = 1; roots = $inv })
    Write-Json (Join-Path $OutputRoot 'post-git-facts.json') ([ordered]@{ formatVersion = 1; clean = $clean; violating = $violating })
    Write-Json (Join-Path $OutputRoot 'invariance.json') ([ordered]@{ formatVersion = 1; status = $(if ($changed.Count -eq 0 -and $gitSame) { 'pass' } else { 'fail' }); changedRoots = @($changed); gitFactsUnchanged = $gitSame })
    if ($changed.Count -ne 0 -or -not $gitSame) { Fail "Protected roots changed: $($changed -join ', '); Git facts unchanged: $gitSame" }
    Write-Output "I2-A post-session invariance passed: $OutputRoot"
}
