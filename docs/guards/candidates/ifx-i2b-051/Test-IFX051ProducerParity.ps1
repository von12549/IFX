# IFX I2-B amendment A2 step A2-4: V3/V4 producer parity (ruling R11). On one clean clone of HEAD the current lab producers
# (which run the V3 gates) and the relocated producers in docs/guards/v4-adoption/producers run on the same commit; their
# evidence is compared semantically per gate. Run paths and timestamps are excluded; test outcomes come from the TRX files;
# SQL scripts and DLLs compare by bytes. The expected identity changes (producer id, run prefix, authority hashes of the
# adapted scripts, the relocated database inventory root) are listed apart and are not semantic differences. Negative
# parity: a committed mutation per gate (a failing test, a lint error, an unsafe migration policy) must make both sides
# fail at the same gate check with the same message. Every semantic difference is listed and must be zero.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkRoot,
    [Parameter(Mandatory)][string]$ReportPath,
    [string[]]$Negative = @('frontend', 'database', 'solution'),
    # Reuses the clone and the positive producer runs of an earlier invocation (one run per gate and side).
    [switch]$ReuseClone
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$work = [IO.Path]::GetFullPath($WorkRoot); if ((Test-Path -LiteralPath $work) -ne [bool]$ReuseClone) { throw "WorkRoot must be absent (or present with -ReuseClone): $work" }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$Path, $Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 30).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }
function Canon($v) { $v | ConvertTo-Json -Depth 30 -Compress }

$candidates = 'docs/guards/candidates'; $producers = 'docs/guards/v4-adoption/producers'
$sides = [ordered]@{
    v3 = [ordered]@{
        solution = [ordered]@{ script = "$candidates/ifx-gate-coverage-c5b/Invoke-IFXSolutionEvidenceProducer.ps1"; prefix = 'artifacts/guards/p10-ifx-c5b/solution-runs' }
        assembly = [ordered]@{ script = "$candidates/ifx-gate-coverage-c5c/Invoke-IFXAssemblyEvidenceProducer.ps1"; prefix = 'artifacts/guards/p10-ifx-c5c/assembly-runs' }
        type = [ordered]@{ script = "$candidates/ifx-gate-coverage-c1r1b/Invoke-IFXCompiledTypeEvidenceProducer.ps1"; prefix = 'artifacts/guards/p10-ifx-c1-r1b/type-runs' }
        frontend = [ordered]@{ script = "$candidates/ifx-gate-coverage-c5d/Invoke-IFXFrontendEvidenceProducer.ps1"; prefix = 'artifacts/guards/p10-ifx-c5d/frontend-runs' }
        database = [ordered]@{ script = "$candidates/ifx-gate-coverage-c4b/Invoke-IFXDatabaseEvidenceProducer.ps1"; prefix = 'artifacts/guards/p10-ifx-c4b/database-runs' } }
    v4 = [ordered]@{
        solution = [ordered]@{ script = "$producers/solution/Invoke-IFXSolutionEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/solution-runs' }
        assembly = [ordered]@{ script = "$producers/assembly/Invoke-IFXAssemblyEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/assembly-runs' }
        type = [ordered]@{ script = "$producers/type/Invoke-IFXCompiledTypeEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/type-runs' }
        frontend = [ordered]@{ script = "$producers/frontend/Invoke-IFXFrontendEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/frontend-runs' }
        database = [ordered]@{ script = "$producers/database/Invoke-IFXDatabaseEvidenceProducer.ps1"; prefix = 'artifacts/guards/v4a-producers/database-runs' } }
}
$logRoot = Join-Path $work 'logs'
function Invoke-Producer([string]$Target, [string]$Side, [string]$Gate, [hashtable]$Locks, [string]$Label) {
    $spec = $sides[$Side][$Gate]; $id = [guid]::NewGuid().ToString('N')
    $producerArgs = @('-TargetRoot', $Target, '-RunId', $id)
    if ($Gate -ceq 'assembly') { $producerArgs += @('-SolutionLockPath', $Locks['solution']) }
    if ($Gate -ceq 'type') { $producerArgs += @('-SolutionLockPath', $Locks['solution'], '-AssemblyLockPath', $Locks['assembly']) }
    $t = [Diagnostics.Stopwatch]::StartNew()
    $out = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $Target $spec.script) @producerArgs 2>&1); $code = $LASTEXITCODE
    $log = Join-Path $logRoot "$Label-$Side-$Gate.log"; [void][IO.Directory]::CreateDirectory($logRoot); [IO.File]::WriteAllLines($log, @($out | ForEach-Object { [string]$_ }), [Text.UTF8Encoding]::new($false))
    [ordered]@{ side = $Side; gate = $Gate; exitCode = $code; seconds = [math]::Round($t.Elapsed.TotalSeconds, 1); run = "$($spec.prefix)/$id"; lock = "$($spec.prefix)/$id/evidence-lock.json"; log = $log }
}

# Volatile keys (times, durations) and the run-directory prefixes are excluded before a semantic comparison.
$volatileKey = [regex]'(?i)(At|Time|Timestamp|Duration|Elapsed|generated|date)$'
function Normalize($Value, [string[]]$Prefixes) {
    if ($Value -is [Collections.IDictionary]) { $o = [ordered]@{}; foreach ($k in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) { if (-not $volatileKey.IsMatch($k)) { $o[$k] = Normalize $Value[$k] $Prefixes } }; return $o }
    if ($Value -is [Collections.IList]) { return @(foreach ($x in $Value) { Normalize $x $Prefixes }) }
    if ($Value -is [string]) { $s = $Value.Replace('\', '/'); foreach ($p in $Prefixes) { $s = $s.Replace($p, '<run>') }; return $s }
    return $Value
}
function Read-Trx([string]$Path) {
    [xml]$x = Get-Content -LiteralPath $Path -Raw
    $c = $x.SelectSingleNode("//*[local-name()='Counters']")
    [ordered]@{ total = [int]$c.total; passed = [int]$c.passed; failed = [int]$c.failed
        outcomes = @($x.SelectNodes("//*[local-name()='UnitTestResult']") | ForEach-Object { "$($_.testName)|$($_.outcome)" } | Sort-Object -CaseSensitive) }
}
function Compare-Gate([string]$Target, [string]$Gate, $A, $B, [string]$Kind) {
    $diffs = [Collections.Generic.List[object]]::new(); $identity = [Collections.Generic.List[object]]::new()
    $ra = Join-Path $Target $A.run; $rb = Join-Path $Target $B.run
    $prefixes = @("$($Target.Replace('\', '/'))/", "$($A.run)/", "$($B.run)/", $A.run, $B.run, "$($sides.v3[$Gate].prefix)/", "$($sides.v4[$Gate].prefix)/")
    $skip = @('evidence-lock.json', 'frontend-run.log')
    $fa = @(Get-ChildItem -LiteralPath $ra -File -Recurse -Force | ForEach-Object { [IO.Path]::GetRelativePath($ra, $_.FullName).Replace('\', '/') } | Where-Object { $skip -notcontains $_ -and $_ -notmatch '(^|/)npm-cache/' })
    $fb = @(Get-ChildItem -LiteralPath $rb -File -Recurse -Force | ForEach-Object { [IO.Path]::GetRelativePath($rb, $_.FullName).Replace('\', '/') } | Where-Object { $skip -notcontains $_ -and $_ -notmatch '(^|/)npm-cache/' })
    $trxA = @($fa | Where-Object { $_ -like '*.trx' }); $trxB = @($fb | Where-Object { $_ -like '*.trx' })
    $plainA = @($fa | Where-Object { $_ -notlike '*.trx' }); $plainB = @($fb | Where-Object { $_ -notlike '*.trx' })
    # The V3 facade (Invoke-IFXGuardrails.ps1) also writes summary-<mode>.json at the run root; the relocated producers call the
    # gate scripts directly, and no lock lists that file. It is an identity change, not evidence.
    foreach ($f in @($plainA | Where-Object { $plainB -notcontains $_ })) { if ($f -match '^summary-(quality|specialized)\.json$') { $identity.Add([ordered]@{ gate = $Gate; field = "facade file $f"; v3 = 'written by Invoke-IFXGuardrails.ps1'; v4 = 'not written' }) } else { $diffs.Add([ordered]@{ gate = $Gate; file = $f; difference = 'only-in-v3' }) } }
    foreach ($f in @($plainB | Where-Object { $plainA -notcontains $_ })) { $diffs.Add([ordered]@{ gate = $Gate; file = $f; difference = 'only-in-v4' }) }
    foreach ($f in @($plainA | Where-Object { $plainB -contains $_ })) {
        $pa = Join-Path $ra $f; $pb = Join-Path $rb $f
        if ($f -like '*.json') {
            $na = Canon (Normalize (Get-Content -LiteralPath $pa -Raw | ConvertFrom-Json -AsHashtable -Depth 50) $prefixes); $nb = Canon (Normalize (Get-Content -LiteralPath $pb -Raw | ConvertFrom-Json -AsHashtable -Depth 50) $prefixes)
            if ($na -cne $nb) { $diffs.Add([ordered]@{ gate = $Gate; file = $f; difference = 'json-semantic'; v3 = $na.Substring(0, [Math]::Min(600, $na.Length)); v4 = $nb.Substring(0, [Math]::Min(600, $nb.Length)) }) }
        } elseif ($f -like '*.log') { continue }
        elseif ((Hash $pa) -cne (Hash $pb)) { $diffs.Add([ordered]@{ gate = $Gate; file = $f; difference = 'bytes'; v3 = Hash $pa; v4 = Hash $pb }) }
    }
    if ($trxA.Count -ne $trxB.Count) { $diffs.Add([ordered]@{ gate = $Gate; file = '*.trx'; difference = 'trx-count'; v3 = $trxA.Count; v4 = $trxB.Count }) }
    if ($trxA.Count) {
        $ta = @($trxA | ForEach-Object { Read-Trx (Join-Path $ra $_) }); $tb = @($trxB | ForEach-Object { Read-Trx (Join-Path $rb $_) })
        $oa = @($ta | ForEach-Object { $_.outcomes } | Sort-Object -CaseSensitive); $ob = @($tb | ForEach-Object { $_.outcomes } | Sort-Object -CaseSensitive)
        if (($oa -join "`n") -cne ($ob -join "`n")) { $diffs.Add([ordered]@{ gate = $Gate; file = '*.trx'; difference = 'test-outcomes'; v3 = $oa.Count; v4 = $ob.Count }) }
    }
    if ($Kind -ceq 'positive') {
        $la = Get-Content -LiteralPath (Join-Path $Target $A.lock) -Raw | ConvertFrom-Json -AsHashtable -Depth 50; $lb = Get-Content -LiteralPath (Join-Path $Target $B.lock) -Raw | ConvertFrom-Json -AsHashtable -Depth 50
        $identityKeys = @('producer', 'evidencePrefix', 'authorityHashes', 'files', 'solutionLockPath', 'solutionLockSha256', 'assemblyLockPath', 'assemblyLockSha256', 'manifestPath', 'manifestSha256', 'reportSha256', 'summarySha256', 'sourceInventoryId', 'sourceInventorySha256', 'sourceFiles', 'sourceFileCount', 'sourceTreeSha256', 'assemblies', 'policySha256', 'v3TypeRuleSha256', 'v3LayerPolicySha256')
        foreach ($k in @($la.Keys + $lb.Keys | Sort-Object -Unique)) {
            $va = if ($la.Contains($k)) { $la[$k] } else { '<absent>' }; $vb = if ($lb.Contains($k)) { $lb[$k] } else { '<absent>' }
            if ($volatileKey.IsMatch($k) -or $identityKeys -contains $k) { continue }
            if ((Canon (Normalize $va $prefixes)) -cne (Canon (Normalize $vb $prefixes))) { $diffs.Add([ordered]@{ gate = $Gate; file = 'evidence-lock.json'; difference = "lock:$k"; v3 = $va; v4 = $vb }) }
        }
        foreach ($k in @('producer', 'authorityHashes', 'sourceInventoryId')) { if ($la.Contains($k) -and (Canon $la[$k]) -cne (Canon $lb[$k])) { $identity.Add([ordered]@{ gate = $Gate; field = $k; v3 = $la[$k]; v4 = $lb[$k] }) } }
        foreach ($k in @('policySha256', 'v3TypeRuleSha256', 'v3LayerPolicySha256')) { if ($la.Contains($k) -and $la[$k] -cne $lb[$k]) { $diffs.Add([ordered]@{ gate = $Gate; file = 'evidence-lock.json'; difference = "lock:$k (policy copies must be byte-identical)"; v3 = $la[$k]; v4 = $lb[$k] }) } }
        if ($la.Contains('sourceFiles')) {
            # Database: the inventory differs only by the relocated root (V3_ifx specialized -> producers/database).
            $moved = @('docs/guards/V3_ifx/stages/post/gates/specialized/', 'docs/guards/v4-adoption/producers/database/')
            $sa = @($la.sourceFiles | Where-Object { -not ([string]$_.path).StartsWith($moved[0], [StringComparison]::Ordinal) } | ForEach-Object { "$($_.path)|$($_.sha256)" })
            $sb = @($lb.sourceFiles | Where-Object { -not ([string]$_.path).StartsWith($moved[1], [StringComparison]::Ordinal) } | ForEach-Object { "$($_.path)|$($_.sha256)" })
            if (($sa -join "`n") -cne ($sb -join "`n")) { $diffs.Add([ordered]@{ gate = $Gate; file = 'evidence-lock.json'; difference = 'lock:sourceFiles outside the relocated root' }) }
            $identity.Add([ordered]@{ gate = $Gate; field = 'sourceFiles relocated root'; v3 = @($la.sourceFiles | Where-Object { ([string]$_.path).StartsWith($moved[0], [StringComparison]::Ordinal) }).Count; v4 = @($lb.sourceFiles | Where-Object { ([string]$_.path).StartsWith($moved[1], [StringComparison]::Ordinal) }).Count })
        } elseif ($la.Contains('sourceTreeSha256') -and $la.sourceTreeSha256 -cne $lb.sourceTreeSha256) { $diffs.Add([ordered]@{ gate = $Gate; file = 'evidence-lock.json'; difference = 'lock:sourceTreeSha256'; v3 = $la.sourceTreeSha256; v4 = $lb.sourceTreeSha256 }) }
        if ($la.Contains('assemblies')) {
            $aa = @($la.assemblies | ForEach-Object { "$(if ($_.Contains('id')) { $_.id } else { $_.name })|$($_.sha256)" } | Sort-Object); $ab = @($lb.assemblies | ForEach-Object { "$(if ($_.Contains('id')) { $_.id } else { $_.name })|$($_.sha256)" } | Sort-Object)
            if (($aa -join "`n") -cne ($ab -join "`n")) { $diffs.Add([ordered]@{ gate = $Gate; file = 'evidence-lock.json'; difference = 'lock:assemblies'; v3 = $aa; v4 = $ab }) }
        }
    }
    [ordered]@{ differences = @($diffs); identityChanges = @($identity) }
}

# 1. Positive parity on a clean clone of HEAD.
$head = (& git -C $repo rev-parse HEAD).Trim()
$target = Join-Path $work 'p'
$runs = [Collections.Generic.List[object]]::new(); $locks = @{ v3 = @{}; v4 = @{} }
if ($ReuseClone) {
    # The clone keeps the commit it was made at; the relocated and the lab producers there must equal those at HEAD.
    $cloneHead = (& git -C $target rev-parse HEAD).Trim()
    foreach ($tree in @('docs/guards/v4-adoption/producers', 'docs/guards/candidates/ifx-gate-coverage-c5b', 'docs/guards/candidates/ifx-gate-coverage-c5c', 'docs/guards/candidates/ifx-gate-coverage-c5d', 'docs/guards/candidates/ifx-gate-coverage-c4b', 'docs/guards/candidates/ifx-gate-coverage-c1r1b', 'docs/guards/V3_ifx')) {
        if ((& git -C $target rev-parse "HEAD:$tree").Trim() -cne (& git -C $repo rev-parse "HEAD:$tree").Trim()) { throw "Reused clone differs from HEAD in $tree" }
    }
    $head = $cloneHead
    foreach ($side in @('v3', 'v4')) { foreach ($gate in @('solution', 'assembly', 'type', 'frontend', 'database')) {
        $dirs = @(Get-ChildItem -LiteralPath (Join-Path $target $sides[$side][$gate].prefix) -Directory)
        if ($dirs.Count -ne 1 -or -not [IO.File]::Exists((Join-Path $dirs[0].FullName 'evidence-lock.json'))) { throw "Reuse needs exactly one locked run: $side $gate" }
        $run = "$($sides[$side][$gate].prefix)/$($dirs[0].Name)"
        $runs.Add([ordered]@{ side = $side; gate = $gate; exitCode = 0; seconds = $null; run = $run; lock = "$run/evidence-lock.json"; log = (Join-Path $logRoot "positive-$side-$gate.log"); reused = $true })
    } }
} else {
$o = @(& git clone --no-local --quiet -c core.longpaths=true $repo $target 2>&1); if ($LASTEXITCODE -ne 0) { throw "Clone failed: $o" }
foreach ($side in @('v3', 'v4')) {
    foreach ($gate in @('solution', 'assembly', 'type', 'frontend', 'database')) {
        $r = Invoke-Producer $target $side $gate $locks[$side] 'positive'; $runs.Add($r)
        if ($r.exitCode -ne 0) { throw "Positive $side $gate producer failed ($($r.exitCode)); see $($r.log)" }
        $locks[$side][$gate] = $r.lock
    }
}
}
$positive = [ordered]@{}
foreach ($gate in @('solution', 'assembly', 'type', 'frontend', 'database')) {
    $a = @($runs | Where-Object { $_.side -ceq 'v3' -and $_.gate -ceq $gate })[0]; $b = @($runs | Where-Object { $_.side -ceq 'v4' -and $_.gate -ceq $gate })[0]
    $positive[$gate] = Compare-Gate $target $gate $a $b 'positive'
}

# 2. Negative parity: one committed mutation per gate; both sides must fail at the same check with the same message.
$mutations = [ordered]@{
    frontend = @{ file = 'src/Frontend/IFX.FrontEnd/src/a2ParityLintFault.ts'; content = "export const a2ParityLintFault = 1`nvar unusedA2ParityVariable = 2`n" }
    database = @{ edit = 'deployment/migration-safety-policy.json'; json = { param($j) $j.automaticDownAllowed = $true } }
    solution = @{ file = 'tests/IFX.IntegrationTests/A2ParityFailingTest.cs'; content = "namespace IFX.IntegrationTests;`n`npublic sealed class A2ParityFailingTest`n{`n    [Fact]`n    public void DeliberateParityFailure() => throw new InvalidOperationException(`"A2-4 negative parity`");`n}`n" }
}
$negative = [ordered]@{}
foreach ($gate in $Negative) {
    $m = $mutations[$gate]
    & git -C $target checkout --quiet --detach $head; & git -C $target clean -fdq -e artifacts/
    if ($m.ContainsKey('file')) { [IO.File]::WriteAllText((Join-Path $target $m.file), $m.content, [Text.UTF8Encoding]::new($false)) }
    else { $p = Join-Path $target $m.edit; $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json; & $m.json $j; [IO.File]::WriteAllText($p, (($j | ConvertTo-Json -Depth 20) + "`n"), [Text.UTF8Encoding]::new($false)) }
    & git -C $target add -A -- src tests deployment; & git -C $target -c user.name=a2-parity -c user.email=a2@parity.invalid commit --quiet -m "A2-4 negative parity: $gate"
    $a = Invoke-Producer $target 'v3' $gate @{} "negative-$gate"; $b = Invoke-Producer $target 'v4' $gate @{} "negative-$gate"
    $summaryOf = { param($r) $s = @(Get-ChildItem -LiteralPath (Join-Path $target $r.run) -Recurse -File -Filter 'summary.json' -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -First 1); if ($s.Count) { Normalize (Get-Content -LiteralPath $s[0].FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 20) @("$($target.Replace('\', '/'))/", "$($r.run)/", $r.run) } else { $null } }
    $sa = & $summaryOf $a; $sb = & $summaryOf $b
    $failedChecks = { param($s) if ($null -eq $s) { '<no summary>' } else { Canon @($s.checks | Where-Object { $_.status -cne 'pass' }) } }
    $same = ($a.exitCode -ne 0 -and $b.exitCode -ne 0 -and (& $failedChecks $sa) -ceq (& $failedChecks $sb) -and (& $failedChecks $sa) -cne '[]')
    $negative[$gate] = [ordered]@{ mutation = $(if ($m.ContainsKey('file')) { "add $($m.file)" } else { "edit $($m.edit)" }); v3ExitCode = $a.exitCode; v4ExitCode = $b.exitCode
        v3FailedChecks = (& $failedChecks $sa); v4FailedChecks = (& $failedChecks $sb); sameFailure = $same }
}
& git -C $target checkout --quiet --detach $head

$semantic = @($positive.Values | ForEach-Object { $_.differences })
$negativeMismatch = @($negative.Values | Where-Object { -not $_.sameFailure })
$status = if ($semantic.Count -eq 0 -and $negativeMismatch.Count -eq 0) { 'pass' } else { 'fail' }
Write-Json $ReportPath ([ordered]@{ formatVersion = 1; kind = 'ifx-051-producer-parity'; step = 'A2-4'; status = $status; commit = $head; workRoot = $work
    rule = 'semantic equality with zero listed differences (R11); identity changes are listed apart'
    runs = @($runs); positive = $positive; negative = $negative; semanticDifferenceCount = $semantic.Count; negativeMismatchCount = $negativeMismatch.Count })
Write-Output "A2-4 producer parity $status`: semantic differences $($semantic.Count), negative mismatches $($negativeMismatch.Count) of $($negative.Count)"
if ($status -cne 'pass') { exit 1 }
