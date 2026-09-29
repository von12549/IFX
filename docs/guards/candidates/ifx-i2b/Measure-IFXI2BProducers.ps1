# IFX I2-B (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step B2: time the seven 0.4.4 evidence producers on a
# fresh clone of the current commit, in the order of the I1 C6 chain (the one-hour locks last). The clone keeps the
# producers' outputs away from the working checkout. Timings are warm-cache local numbers (NuGet global packages
# and the npm cache are the developer's); the GitHub timings of the V3 contexts are recorded separately.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CloneRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [string]$SourceRepository = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function NewRunId { [guid]::NewGuid().ToString('N') }
if (Test-Path -LiteralPath $CloneRoot) { throw "CloneRoot already exists: $CloneRoot" }
if (Test-Path -LiteralPath $OutputPath) { throw "Output already exists: $OutputPath" }

$commit = (& git -C $SourceRepository rev-parse HEAD).Trim()
$clock = [Diagnostics.Stopwatch]::StartNew()
$x = @(& git -c core.longpaths=true clone --quiet --no-hardlinks $SourceRepository $CloneRoot 2>&1); if ($LASTEXITCODE -ne 0) { throw "clone failed: $($x -join '; ')" }
$x = @(& git -C $CloneRoot -c core.longpaths=true checkout --quiet --detach $commit 2>&1); if ($LASTEXITCODE -ne 0) { throw "checkout failed: $($x -join '; ')" }
& git -C $CloneRoot config core.longpaths true
$cloneSeconds = [math]::Round($clock.Elapsed.TotalSeconds, 1)
$repo = (Resolve-Path -LiteralPath $CloneRoot).Path
$candidates = Join-Path $repo 'docs/guards/candidates'
$logRoot = Join-Path ([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($OutputPath))) 'producer-logs'
[void][IO.Directory]::CreateDirectory($logRoot)

$solutionId = NewRunId; $assemblyId = NewRunId; $frontendId = NewRunId; $databaseId = NewRunId; $graphId = NewRunId; $typeId = NewRunId
$solutionLock = "artifacts/guards/p10-ifx-c5b/solution-runs/$solutionId/evidence-lock.json"
$assemblyLock = "artifacts/guards/p10-ifx-c5c/assembly-runs/$assemblyId/evidence-lock.json"
$plan = @(
    [ordered]@{ id = 'solution'; script = 'ifx-gate-coverage-c5b/Invoke-IFXSolutionEvidenceProducer.ps1'; args = @('-RunId', $solutionId); lock = $solutionLock }
    [ordered]@{ id = 'assembly'; script = 'ifx-gate-coverage-c5c/Invoke-IFXAssemblyEvidenceProducer.ps1'; args = @('-SolutionLockPath', $solutionLock, '-RunId', $assemblyId); lock = $assemblyLock }
    [ordered]@{ id = 'frontend'; script = 'ifx-gate-coverage-c5d/Invoke-IFXFrontendEvidenceProducer.ps1'; args = @('-RunId', $frontendId); lock = "artifacts/guards/p10-ifx-c5d/frontend-runs/$frontendId/evidence-lock.json" }
    [ordered]@{ id = 'database'; script = 'ifx-gate-coverage-c4b/Invoke-IFXDatabaseEvidenceProducer.ps1'; args = @('-RunId', $databaseId); lock = "artifacts/guards/p10-ifx-c4b/database-runs/$databaseId/evidence-lock.json" }
    [ordered]@{ id = 'graph'; script = 'ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1'; args = @('-RunId', $graphId); lock = "artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/$graphId/evidence-lock.json" }
    [ordered]@{ id = 'generated'; script = 'ifx-gate-coverage-c1r2c/Test-IFXGeneratedInputDisposition.ps1'; args = @('-SolutionLockPath', $solutionLock, '-EvidenceRoot', 'artifacts/guards/p10-ifx-i2b/generated-runs'); lock = $null }
    [ordered]@{ id = 'type'; script = 'ifx-gate-coverage-c1r1b/Invoke-IFXCompiledTypeEvidenceProducer.ps1'; args = @('-SolutionLockPath', $solutionLock, '-AssemblyLockPath', $assemblyLock, '-RunId', $typeId); lock = "artifacts/guards/p10-ifx-c1-r1b/type-runs/$typeId/evidence-lock.json" }
)
$rows = [Collections.Generic.List[object]]::new()
$stop = $false
foreach ($step in $plan) {
    if ($stop) { $rows.Add([ordered]@{ id = $step.id; status = 'not-run' }); continue }
    $stdout = Join-Path $logRoot "$($step.id).stdout.txt"; $stderr = Join-Path $logRoot "$($step.id).stderr.txt"
    $t = [Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath pwsh -ArgumentList (@('-NoLogo', '-NoProfile', '-NonInteractive', '-File', (Join-Path $candidates $step.script)) + $step.args) `
        -WorkingDirectory $repo -RedirectStandardOutput $stdout -RedirectStandardError $stderr -NoNewWindow -PassThru -Wait
    $seconds = [math]::Round($t.Elapsed.TotalSeconds, 1)
    $lock = $step.lock
    if ($step.id -ceq 'generated') {
        $runs = Join-Path $repo 'artifacts/guards/p10-ifx-i2b/generated-runs'
        $child = @(if (Test-Path -LiteralPath $runs) { Get-ChildItem -LiteralPath $runs -Directory })
        if ($child.Count -eq 1) { $lock = [IO.Path]::GetRelativePath($repo, (Join-Path $child[0].FullName 'evidence-lock.json')).Replace('\', '/') }
    }
    $lockFull = if ($lock) { Join-Path $repo $lock } else { $null }
    $lockPresent = $null -ne $lockFull -and (Test-Path -LiteralPath $lockFull -PathType Leaf)
    $status = if ($p.ExitCode -eq 0 -and $lockPresent) { 'pass' } else { 'fail' }
    $rows.Add([ordered]@{ id = $step.id; script = "docs/guards/candidates/$($step.script)"; status = $status; exitCode = $p.ExitCode; seconds = $seconds
        lockPath = $lock; lockSha256 = $(if ($lockPresent) { Hash $lockFull } else { $null })
        stdout = [ordered]@{ path = "producer-logs/$($step.id).stdout.txt"; sha256 = Hash $stdout }; stderr = [ordered]@{ path = "producer-logs/$($step.id).stderr.txt"; sha256 = Hash $stderr } })
    # The later producers read the solution and assembly locks; stop at the first failure.
    if ($status -cne 'pass') { $stop = $true }
}
$tools = [ordered]@{ dotnet = (& dotnet --version).Trim(); node = (& node --version).Trim(); npm = (& npm --version).Trim(); pwsh = $PSVersionTable.PSVersion.ToString() }
$all = @($rows | Where-Object { $_.status -ceq 'pass' }).Count -eq $plan.Count
$record = [ordered]@{
    formatVersion = 1; kind = 'ifx-i2b-b2-producer-timing'; status = $(if ($all) { 'pass' } else { 'fail' })
    sourceCommit = $commit; cloneRoot = $repo; cloneSeconds = $cloneSeconds; cache = 'warm (developer NuGet global packages and npm cache)'
    tools = $tools; producers = @($rows.ToArray())
    totalProducerSeconds = [math]::Round((@($rows | Where-Object { $_.Contains('seconds') } | ForEach-Object { $_.seconds }) | Measure-Object -Sum).Sum, 1)
}
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($OutputPath)))
[IO.File]::WriteAllText($OutputPath, (($record | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
$rows | ForEach-Object { "{0,-10} {1,-8} {2,8}s" -f $_.id, $_.status, $(if ($_.Contains('seconds')) { $_.seconds } else { '-' }) }
if (-not $all) { exit 1 }
