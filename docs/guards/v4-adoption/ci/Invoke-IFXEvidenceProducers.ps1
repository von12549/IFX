# IFX I2-B amendment A2 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle): produce and stage the 0.5.1 evidence locks;
# successor of candidates/ifx-i2b-050a/Invoke-IFX050EvidenceProducers.ps1 (unchanged). The solution, assembly, frontend,
# database and type producers are the relocated ones in docs/guards/v4-adoption/producers (rulings R6-R9); the graph
# producer is unchanged. -Phase Produce runs the six consumed producers on the Target in C6 chain order (the one-hour locks last) and
# records their lock paths; -Phase Stage copies each consumed run into EvidenceRoot/locks/<gate>/ and writes
# EvidenceRoot/locks/staging.json, which the 0.5.0-a lock consumers read instead of a Profile lock path and hash.
# The type run's assembly-manifest.json and DLLs are also staged at the EvidenceRoot root, where the built-in
# architecture-conformance module and ifx-c1-type-provenance read them. From 0.5.0-b the trusted-base workflow runs
# this script before stage run --stage post.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Produce', 'Stage')][string]$Phase,
    [Parameter(Mandatory)][string]$TargetRoot,
    [string]$RunRecordPath,
    [string]$EvidenceRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-PinSha256([string]$Path) {
    # Ruling R5: script identity by UTF-8 text with LF line endings, so a Windows and a Linux checkout agree.
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")))).ToLowerInvariant()
}
function Write-Json([string]$Path, $Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 30).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
$target = [IO.Path]::GetFullPath($TargetRoot)
if (-not [IO.Directory]::Exists((Join-Path $target '.git'))) { throw "TargetRoot is not a Git checkout: $target" }
$candidates = 'docs/guards/candidates'; $relocated = 'docs/guards/v4-adoption/producers'
# Gate -> producer, in C6 chain order. 'generated' is recorded for lineage; no 0.5.0-a module consumes it.
$producers = [ordered]@{
    solution = [ordered]@{ id = 'ifx-v4a-solution-v1'; script = "$relocated/solution/Invoke-IFXSolutionEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/solution-runs/' }
    assembly = [ordered]@{ id = 'ifx-v4a-assembly-v1'; script = "$relocated/assembly/Invoke-IFXAssemblyEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/assembly-runs/' }
    frontend = [ordered]@{ id = 'ifx-v4a-frontend-v1'; script = "$relocated/frontend/Invoke-IFXFrontendEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/frontend-runs/' }
    database = [ordered]@{ id = 'ifx-v4a-database-v1'; script = "$relocated/database/Invoke-IFXDatabaseEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/database-runs/' }
    graph = [ordered]@{ id = 'ifx-c1-r2b-controlled-v1'; script = "$candidates/ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1"; prefix = 'artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/' }
    type = [ordered]@{ id = 'ifx-v4a-type-v1'; script = "$relocated/type/Invoke-IFXCompiledTypeEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/type-runs/' }
}

if ($Phase -ceq 'Produce') {
    if (-not $RunRecordPath) { throw 'RunRecordPath is required for Produce.' }
    $commit = (& git -C $target rev-parse HEAD).Trim()
    $ids = @{}; foreach ($g in $producers.Keys) { $ids[$g] = [guid]::NewGuid().ToString('N') }
    $lockOf = @{}; foreach ($g in $producers.Keys) { $lockOf[$g] = "$($producers[$g].prefix)$($ids[$g])/evidence-lock.json" }
    $producerArgs = @{
        solution = @('-RunId', $ids.solution); assembly = @('-SolutionLockPath', $lockOf.solution, '-RunId', $ids.assembly)
        frontend = @('-RunId', $ids.frontend); database = @('-RunId', $ids.database); graph = @('-RunId', $ids.graph)
        type = @('-SolutionLockPath', $lockOf.solution, '-AssemblyLockPath', $lockOf.assembly, '-RunId', $ids.type)
    }
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($g in @('solution', 'assembly', 'frontend', 'database', 'graph', 'type')) {
        $t = [Diagnostics.Stopwatch]::StartNew()
        # The relocated producers never derive the repository from their own location (A2-3): pass the Target explicitly.
        $out = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $target $producers[$g].script) -TargetRoot $target @($producerArgs[$g]) 2>&1)
        $exit = $LASTEXITCODE
        $rows.Add([ordered]@{ gate = $g; exitCode = $exit; seconds = [math]::Round($t.Elapsed.TotalSeconds, 1); lockPath = $lockOf[$g]; tail = @($out | Select-Object -Last 3 | ForEach-Object { [string]$_ }) })
        if ($exit -ne 0 -or -not [IO.File]::Exists((Join-Path $target $lockOf[$g]))) { Write-Json $RunRecordPath ([ordered]@{ formatVersion = 1; kind = 'ifx-050a-evidence-production'; status = 'fail'; targetCommit = $commit; failedGate = $g; runs = @($rows.ToArray()) }); throw "Producer $g failed ($exit): $($out | Select-Object -Last 5)" }
    }
    Write-Json $RunRecordPath ([ordered]@{ formatVersion = 1; kind = 'ifx-050a-evidence-production'; status = 'pass'; targetCommit = $commit; runs = @($rows.ToArray()) })
    "produced $($rows.Count) locks at $commit -> $RunRecordPath"
    exit 0
}

# Stage.
if (-not $RunRecordPath -or -not $EvidenceRoot) { throw 'RunRecordPath and EvidenceRoot are required for Stage.' }
$record = Get-Content -LiteralPath $RunRecordPath -Raw | ConvertFrom-Json -Depth 20
if ($record.kind -cne 'ifx-050a-evidence-production' -or $record.status -cne 'pass') { throw 'The production record did not pass.' }
$evidence = [IO.Path]::GetFullPath($EvidenceRoot)
$locksRoot = Join-Path $evidence 'locks'
if (Test-Path -LiteralPath $locksRoot) { throw "EvidenceRoot already holds staged locks: $locksRoot" }
$gates = [Collections.Generic.List[object]]::new()
foreach ($run in $record.runs) {
    $g = [string]$run.gate; $p = $producers[$g]
    $lockRelative = [string]$run.lockPath
    if (-not $lockRelative.StartsWith($p.prefix, [StringComparison]::Ordinal)) { throw "Lock path outside the producer prefix: $lockRelative" }
    $runPrefix = $lockRelative.Substring(0, $lockRelative.Length - 'evidence-lock.json'.Length)
    $source = Join-Path $target $runPrefix
    $dest = Join-Path $locksRoot $g
    [void][IO.Directory]::CreateDirectory($dest)
    Copy-Item -Path (Join-Path $source '*') -Destination $dest -Recurse
    $scriptFull = Join-Path $target $p.script
    $gates.Add([ordered]@{
        gate = $g; prefix = $runPrefix; stagedRoot = "locks/$g"; lockPath = $lockRelative; lockSha256 = Hash (Join-Path $dest 'evidence-lock.json')
        producer = [ordered]@{ id = $p.id; script = $p.script; scriptSha256 = Get-PinSha256 $scriptFull }
    })
    if ($g -ceq 'type') {
        # The external copy read by architecture-conformance and ifx-c1-type-provenance.
        Copy-Item -LiteralPath (Join-Path $dest 'assembly-manifest.json') -Destination (Join-Path $evidence 'assembly-manifest.json')
        Copy-Item -LiteralPath (Join-Path $dest 'assemblies') -Destination (Join-Path $evidence 'assemblies') -Recurse
    }
}
Write-Json (Join-Path $locksRoot 'staging.json') ([ordered]@{ formatVersion = 1; kind = 'ifx-050a-evidence-staging'; targetCommit = $record.targetCommit; stagedAt = [DateTimeOffset]::UtcNow.ToString('o'); gates = @($gates.ToArray()) })
"staged $($gates.Count) gates into $locksRoot"
