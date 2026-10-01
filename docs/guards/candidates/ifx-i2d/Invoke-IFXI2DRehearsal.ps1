# IFX I2-D (Plan 20261001-v4-ifx-i2d-publish-trusted-inputs) step D4: rehearsal of the publication pull request on main.
# In a disposable clone outside the repository the PR head is built on main with the I2-D spec (pr-spec.json), and:
#  - V3: main's own trusted runner judges the head: trusted Diff (no protected-change obligation), the trusted
#    component check (no trusted component change), Validate, the head candidate package tests (Test-CutoverPreservation
#    among them), Architecture, Historical Integrity and G03;
#  - publication: two fresh clones of the head, one with core.autocrlf=true (as hosted Windows runners) and one with
#    false, must each pass the specimen's own input checks (manifest and review hashes from the specimen's environment),
#    match every bundle file to its manifest entry, match every published file to its development-branch source blob,
#    name nothing outside docs/guards/v4-adoption, and pass Test-CutoverPreservation;
#  - composition: the published bundle and review, composed with the installed 1.1.6 base, give the A3-10a package.
# Nothing is pushed.
[CmdletBinding()]
param(
    [string] $RepositoryRoot = '.',
    [string] $WorkRoot = 'D:/IFX-Root/guard-runtime/i2d',
    [string] $OutputDirectory = 'artifacts/guards/p10-ifx-i2d/d4-rehearsal',
    [string] $ExpectedPackageHash = '0fab0676c80fdc9342b3132ca54a1c5af97980796cdb3cd303488ce7506dec42',
    [string] $RuntimeRoot = 'D:/IFX-Root/guard-runtime',
    [switch] $KeepWorkDirectory
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'IFXI2C.Common.psm1') -Force
$repositoryPath = [IO.Path]::GetFullPath($RepositoryRoot)
Import-Module (Join-Path $repositoryPath 'docs/guards/V3_ifx/trusted-base/TrustedBase.psm1') -Force
$spec = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'pr-spec.json') | ConvertFrom-Json -Depth 20
$entry = @($spec.sets)[0]
$output = [IO.Path]::GetFullPath((Join-Path $repositoryPath $OutputDirectory))
Assert-IFXI2C (-not [IO.Directory]::Exists($output)) "The rehearsal output already exists: $output"
$work = [IO.Path]::GetFullPath((Join-Path $WorkRoot "d4-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"))
Assert-IFXI2C (-not (Test-GuardPathWithin $work $repositoryPath)) 'The rehearsal must run outside the repository.'
$clone = Join-Path $work 'h'; $logs = Join-Path $output 'logs'
$tempRoot = [IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar)
$steps = [Collections.Generic.List[object]]::new(); $stepNumber = 0
function CloneGit([string[]] $Arguments) { return Invoke-IFXI2CGit $clone $Arguments }
function Set-Head([string] $Commit) { [void](CloneGit @('checkout', '-q', '-f', '--detach', $Commit)); [void](CloneGit @('clean', '-q', '-fdx')) }
function Add-Step([string] $Id, [string] $Description, [int] $Expected, [object] $Run, [string] $ExpectText) {
    $script:stepNumber++
    $text = ($Run.Output -replace '\s+', ' ')
    $ok = $Run.ExitCode -eq $Expected -and (-not $ExpectText -or $text.Contains($ExpectText, [StringComparison]::Ordinal))
    $log = Join-Path $logs ('{0:D2}-{1}.log' -f $script:stepNumber, $Id)
    [IO.File]::WriteAllText($log, $Run.Output.Replace($work, '<work>').Replace($tempRoot, '<temp>'), [Text.UTF8Encoding]::new($false))
    $steps.Add([ordered]@{ id = $Id; description = $Description; expectedExit = $Expected; expectText = $ExpectText; exit = $Run.ExitCode; asExpected = $ok; log = [IO.Path]::GetRelativePath($output, $log).Replace('\', '/') })
    Write-Host ("[{0}] {1}: exit {2} (expected {3})" -f $(if ($ok) { 'OK' } else { 'UNEXPECTED' }), $Id, $Run.ExitCode, $Expected)
}
function Fact([string] $Id, [string] $Description, [bool] $Pass, $Detail) {
    Add-Step $Id $Description 0 ([pscustomobject]@{ ExitCode = $(if ($Pass) { 0 } else { 1 }); Output = ($Detail | ConvertTo-Json -Depth 10) }) ''
}
function Trusted([string] $Script, [string[]] $Arguments) { Invoke-GuardIsolatedPwsh (Join-Path $baseTree "docs/guards/V3_ifx/trusted-base/$Script") $Arguments -WorkingDirectory $clone }
function Env-Value([string] $Workflow, [string] $Name) { $m = [regex]::Match($Workflow, "(?m)^  $([regex]::Escape($Name)):\s*(\S+)\s*\r?$"); if ($m.Success) { $m.Groups[1].Value } else { $null } }

$failed = $true
try {
    [void][IO.Directory]::CreateDirectory($work); [void][IO.Directory]::CreateDirectory($logs)
    $o = @(& git -c core.longpaths=true clone -q --no-checkout $repositoryPath $clone 2>&1); if ($LASTEXITCODE -ne 0) { throw "clone failed: $o" }
    [void](CloneGit @('config', 'core.longpaths', 'true'))
    $base = [string]$spec.initialTarget
    $baseTree = Join-Path $work 'b'; [void](CloneGit @('worktree', 'add', '-q', '--detach', $baseTree, $base))
    $text = (& pwsh -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'New-IFXI2CPullRequestHeads.ps1') -Clone $clone -Set P1 -BaseCommit $base -SpecPath (Join-Path $PSScriptRoot 'pr-spec.json') -Branch 'rehearsal/p1' 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Building the head failed: $text" }
    $built = ($text.Split("`n") | Where-Object { $_.StartsWith('{') } | Select-Object -Last 1) | ConvertFrom-Json -Depth 20
    $head = [string]$built.head

    # ---- V3 on main's own trusted runner
    Set-Head $head
    Add-Step 'diff' 'The trusted Diff passes with the formal plan and no protected obligation.' 0 (Trusted 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $base, '-Mode', 'Diff', '-PlanPath', [string]$entry.plan, '-BaseRef', $base, '-HeadRef', $head, '-GateId', 'v3-pre-diff')) 'Protected change verification passed (no protected changes)'
    Add-Step 'candidates' 'The head changes no trusted component.' 0 (Trusted 'Test-IFXTrustedBaseCandidate.ps1' @('-TargetRoot', $clone, '-BaseSha', $base, '-HeadRevision', $head)) 'no trusted component changes'
    Set-Head $head
    Add-Step 'validate' 'Validate passes for the explicit head.' 0 (Trusted 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $base, '-Mode', 'Validate', '-HeadRef', $head, '-GateId', 'v3-architecture')) 'Trusted base run passed'
    Set-Head $head
    Add-Step 'candidate-tests' 'The head candidate package tests pass (Test-CutoverPreservation among them).' 0 (Invoke-GuardIsolatedPwsh (Join-Path $clone 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1') @('-Mode', 'CandidateTests', '-CandidateSuite', 'Architecture', '-TargetRoot', $clone) -WorkingDirectory $clone) ''
    Set-Head $head
    Add-Step 'architecture' 'The production architecture scan passes.' 0 (Trusted 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $base, '-Mode', 'Architecture', '-HeadRef', $head, '-GateId', 'v3-architecture')) 'Trusted base run passed'
    Set-Head $head
    Add-Step 'historical' 'Historical Integrity passes.' 0 (Trusted 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $base, '-Mode', 'HistoricalIntegrity', '-GateId', 'v3-historical-integrity')) 'Trusted base run passed'
    Set-Head $head
    Add-Step 'g03' 'The G03 specialized gate passes.' 0 (Trusted 'Invoke-IFXTrustedBase.ps1' @('-HeadRoot', $clone, '-BaseSha', $base, '-Mode', 'Specialized', '-SpecializedGate', 'G03', '-HeadRef', $head, '-GateId', 'v3-specialized-g03')) 'Trusted base run passed'

    # ---- publication proof on fresh checkouts
    $source = [string]$spec.sourceCommit
    $published = @(@($entry.copy) + @($entry.authored) | Sort-Object -Unique)
    foreach ($crlf in 'true', 'false') {
        $checkout = Join-Path $work "co-autocrlf-$crlf"
        $o = @(& git -c core.longpaths=true -c "core.autocrlf=$crlf" clone -q --no-checkout $clone $checkout 2>&1); if ($LASTEXITCODE -ne 0) { throw "checkout clone failed: $o" }
        & git -C $checkout config core.longpaths true; & git -C $checkout config core.autocrlf $crlf
        & git -C $checkout -c advice.detachedHead=false checkout -q --detach $head; if ($LASTEXITCODE -ne 0) { throw 'checkout failed' }
        $workflow = [IO.File]::ReadAllText((Join-Path $checkout 'docs/guards/v4-adoption/integrations/github/proposed-v4-ifx-guardrails.yml'))
        $trusted = Join-Path $checkout (Env-Value $workflow 'IFX_BUNDLE_BASE_PATH')
        $manifestFile = Join-Path $trusted 'bundle/bundle-manifest.json'; $reviewFile = Join-Path $trusted 'production-extension-review.json'
        $inputs = ([IO.File]::Exists($manifestFile) -and [IO.File]::Exists($reviewFile) -and (Get-IFXI2CFileSha256 $manifestFile) -ceq (Env-Value $workflow 'IFX_BUNDLE_MANIFEST_SHA256') -and (Get-IFXI2CFileSha256 $reviewFile) -ceq (Env-Value $workflow 'IFX_PRODUCTION_REVIEW_SHA256'))
        Fact "inputs-autocrlf-$crlf" "The specimen's input checks pass on a checkout with core.autocrlf=$crlf." $inputs ([ordered]@{ manifest = (Get-IFXI2CFileSha256 $manifestFile); review = (Get-IFXI2CFileSha256 $reviewFile) })
        $manifest = Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json -Depth 50
        $badBundle = @(foreach ($e in @($manifest.files)) { $p = Join-Path $trusted "bundle/package/$($e.path)"; if (-not [IO.File]::Exists($p) -or (Get-IFXI2CFileSha256 $p) -cne [string]$e.sha256) { $e.path } })
        $extra = @(Get-ChildItem -LiteralPath (Join-Path $trusted 'bundle/package') -File -Recurse -Force).Count - @($manifest.files).Count
        Fact "bundle-autocrlf-$crlf" "Every bundle file matches its manifest entry (core.autocrlf=$crlf)." ($badBundle.Count -eq 0 -and $extra -eq 0) ([ordered]@{ files = @($manifest.files).Count; mismatches = $badBundle; undeclared = $extra })
        $badBlobs = @(foreach ($p in @($entry.copy)) {
            $want = (Invoke-IFXI2CGit $repositoryPath @('rev-parse', "${source}:$p"))[0].Trim()
            $have = (& git -C $checkout hash-object --no-filters -- (Join-Path $checkout $p)).Trim()
            if ($want -cne $have) { $p } })
        Fact "bytes-autocrlf-$crlf" "Every published file has its development-branch bytes on disk (core.autocrlf=$crlf)." ($badBlobs.Count -eq 0) ([ordered]@{ files = @($entry.copy).Count; mismatches = $badBlobs })
        $changedLines = & git -C $checkout diff --name-only $base $head
        $outside = @(foreach ($l in $changedLines) { $n = ([string]$l).Trim(); if ($n -and -not $n.StartsWith('docs/guards/v4-adoption/', [StringComparison]::Ordinal) -and $n -notin @($entry.authored)) { $n } })
        Fact "scope-autocrlf-$crlf" 'Nothing outside docs/guards/v4-adoption changes except the plan pair.' ($outside.Count -eq 0 -and @($changedLines).Count -eq $published.Count) ([ordered]@{ changed = @($changedLines).Count; planned = $published.Count; outside = $outside })
        Add-Step "cutover-preservation-autocrlf-$crlf" "Test-CutoverPreservation passes on the checkout (core.autocrlf=$crlf)." 0 (Invoke-GuardIsolatedPwsh (Join-Path $checkout 'docs/guards/V3_ifx/tests/ci/Test-CutoverPreservation.ps1') @() -WorkingDirectory $checkout) 'Cutover preservation passed'
        if ($crlf -ceq 'true') { $windowsCheckout = $checkout; $windowsTrusted = $trusted }
    }

    # ---- composition of the published bundle (Windows-style checkout)
    $base116 = Join-Path $RuntimeRoot 'releases/v4-guards-1.1.6'; $baseReceipt = Join-Path $RuntimeRoot 'receipts/v4-guards-1.1.6.install.json'
    $archive = Join-Path $repositoryPath 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip'
    $install = Join-Path $work 'composed'; $receipt = Join-Path $work 'composed.compose.json'
    foreach ($d in 'state', 'evidence') { [void][IO.Directory]::CreateDirectory((Join-Path $work $d)) }
    # As the specimen does: copy the trusted bundle directory out of the checkout (the composer refuses a bundle root
    # inside the Target) and compose from the copy.
    $inputs = Join-Path $work 'v4-ifx-inputs'; [void][IO.Directory]::CreateDirectory($inputs)
    $copied = Join-Path $inputs 'ifx-0.5.2'
    Copy-Item -LiteralPath $windowsTrusted -Destination $copied -Recurse
    $compose = Invoke-GuardIsolatedPwsh (Join-Path $base116 'package/core/distribution/Compose-V4Extension.ps1') @('-BaseInstallRoot', $base116, '-BaseReceiptPath', $baseReceipt, '-BaseArchivePath', $archive, '-BundleRoot', (Join-Path $copied 'bundle'), '-ReviewRecordPath', (Join-Path $copied 'production-extension-review.json'), '-OutputInstallRoot', $install, '-CompositionReceiptPath', $receipt, '-TargetRoot', $windowsCheckout, '-StateRoot', (Join-Path $work 'state'), '-EvidenceRoot', (Join-Path $work 'evidence')) -WorkingDirectory $work
    Add-Step 'compose' 'The published bundle composes with the 1.1.6 base under the published review.' 0 $compose ''
    $verify = Invoke-GuardIsolatedPwsh (Join-Path $base116 'package/core/distribution/Test-V4ComposedInstallation.ps1') @('-InstallRoot', $install, '-ReceiptPath', $receipt, '-BaseReceiptPath', $baseReceipt) -WorkingDirectory $work
    $proof = $null; try { $proof = $verify.Output | ConvertFrom-Json -Depth 50 } catch {}
    Fact 'composed-package' 'The composed package equals the A3-10a package.' ($verify.ExitCode -eq 0 -and $null -ne $proof -and [string]$proof.status -ceq 'pass' -and [string]$proof.scope -ceq 'production' -and [string]$proof.packageHash -ceq $ExpectedPackageHash) ([ordered]@{ packageHash = $(if ($proof) { $proof.packageHash }); expected = $ExpectedPackageHash; bundleManifestSha256 = $(if ($proof) { $proof.bundleManifestSha256 }) })

    $unexpected = @($steps | Where-Object { -not $_.asExpected })
    $failed = $unexpected.Count -gt 0
    $report = [ordered]@{ formatVersion = 1; kind = 'ifx-i2d-rehearsal'; planId = '20261001-v4-ifx-i2d-publish-trusted-inputs'; step = 'D4'; status = $(if ($failed) { 'fail' } else { 'pass' })
        createdAtUtc = [DateTime]::UtcNow.ToString('o'); repositoryHead = (Invoke-IFXI2CGit $repositoryPath @('rev-parse', 'HEAD'))[0].Trim()
        specSha256 = Get-IFXI2CFileSha256 (Join-Path $PSScriptRoot 'pr-spec.json'); sourceCommit = $source; base = $base; head = $head; build = $built
        publishedFiles = $published.Count; expectedPackageHash = $ExpectedPackageHash; steps = @($steps); unexpectedSteps = @($unexpected | ForEach-Object id)
        notRunLocally = @('v3-quality-solution', 'v3-quality-assembly', 'v3-quality-frontend', 'v3-specialized-g04', 'v3-specialized-g05', 'v3-specialized-plan04', 'v3-specialized-database', 'v3-cross-platform-ubuntu-latest', 'v3-cross-platform-windows-latest (candidate suite)')
        note = 'The rehearsal commit is local; D6 rebuilds the head on the real main head.' }
    Write-IFXI2CJson (Join-Path $output 'rehearsal.json') $report
    Write-Host "D4 rehearsal $($report.status): $(Join-Path $output 'rehearsal.json')"
}
finally {
    if (-not $KeepWorkDirectory -and [IO.Directory]::Exists($work)) {
        [void](& git -C $clone worktree remove --force (Join-Path $work 'b') 2>&1)
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if ($failed) { exit 1 }
