# IFX I2-B amendment A3 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A3-4: parity of the relocated closure
# (ruling R15).
#  - Graph: on one clean clone of HEAD, the lab graph producer (docs/guards/candidates/ifx-gate-coverage-c1r2b) and the
#    relocated one (docs/guards/v4-adoption/producers/graph) run on the same commit. Their evidence locks are compared
#    semantically: timestamps are excluded, and the expected identity changes (producer id; policySha256, which must equal
#    the SHA-256 of each side's own policy.json) are listed apart. Negative parity: four mutations (an unsupported MSBuild
#    construct, a project-set change, a source-policy change and a dirty tracked source) must make both sides fail with
#    the same message (paths of the side's own source policy normalized).
#  - Aggregate: the lab rehearsal's Aggregate branch and ci/Invoke-IFXV4Aggregate.ps1 must give the same exit code,
#    standard output and standard error for all 16 combinations of the two job results.
# Every difference is listed and must be zero.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WorkRoot,
    [Parameter(Mandatory)][string]$ReportPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$work = [IO.Path]::GetFullPath($WorkRoot); if (Test-Path -LiteralPath $work) { throw "WorkRoot must be absent: $work" }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Canon($v) { $v | ConvertTo-Json -Depth 30 -Compress }
function Write-Json([string]$Path, $Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 30).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }

$sides = [ordered]@{
    lab = [ordered]@{ script = 'docs/guards/candidates/ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1'; policy = 'docs/guards/candidates/ifx-gate-coverage-c1r2b/modules/ifx-c1-evaluated-reference/policy.json'; prefix = 'artifacts/guards/p10-ifx-c1-r2b/evaluation-runs'; id = 'ifx-c1-r2b-controlled-v1' }
    v4 = [ordered]@{ script = 'docs/guards/v4-adoption/producers/graph/Invoke-IFXEvaluatedGraphProducer.ps1'; policy = 'docs/guards/v4-adoption/producers/graph/policy.json'; prefix = 'artifacts/guards/v4a-producers/graph-runs'; id = 'ifx-v4a-graph-v1' }
}
$logRoot = Join-Path $work 'logs'
$target = Join-Path $work 'clone'
function Invoke-Graph([string]$Side, [string]$Label) {
    $s = $sides[$Side]; $id = [guid]::NewGuid().ToString('N')
    $t = [Diagnostics.Stopwatch]::StartNew()
    $out = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $target $s.script) -TargetRoot $target -RunId $id 2>&1); $code = $LASTEXITCODE
    $log = Join-Path $logRoot "$Label-$Side.log"; [void][IO.Directory]::CreateDirectory($logRoot); [IO.File]::WriteAllLines($log, @($out | ForEach-Object { [string]$_ }), [Text.UTF8Encoding]::new($false))
    $text = (@($out | ForEach-Object { [string]$_ }) -join "`n") -replace '\x1b\[[0-9;]*m', ''
    $m = [regex]::Match($text, '(?m)^(?:Exception|[^\r\n]*Exception):\s*(?<msg>[^\r\n]+)')
    $message = if ($m.Success) { $m.Groups['msg'].Value.Trim() } elseif ($code -ne 0) { ($text -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 1) } else { '' }
    [ordered]@{ side = $Side; exitCode = $code; seconds = [math]::Round($t.Elapsed.TotalSeconds, 1); run = "$($s.prefix)/$id"; lock = "$($s.prefix)/$id/evidence-lock.json"; message = $message; log = [IO.Path]::GetRelativePath($work, $log).Replace('\', '/') }
}
$volatileKey = [regex]'(?i)^(createdAt|expiresAt)$'
$identityKey = @('producer', 'policySha256')

[void][IO.Directory]::CreateDirectory($work)
$head = (& git -C $repo rev-parse HEAD).Trim()
& git -c core.longpaths=true clone --quiet --no-local $repo $target; if ($LASTEXITCODE -ne 0) { throw 'clone failed' }
& git -C $target config core.longpaths true
& git -C $target checkout --quiet --detach $head

# 1. Positive parity
$a = Invoke-Graph 'lab' 'positive'; $b = Invoke-Graph 'v4' 'positive'
$differences = [Collections.Generic.List[object]]::new(); $identity = [ordered]@{}
if ($a.exitCode -ne 0 -or $b.exitCode -ne 0) { $differences.Add([ordered]@{ field = 'exitCode'; lab = $a.exitCode; v4 = $b.exitCode }) }
else {
    $la = Get-Content -LiteralPath (Join-Path $target $a.lock) -Raw | ConvertFrom-Json -AsHashtable -Depth 50
    $lb = Get-Content -LiteralPath (Join-Path $target $b.lock) -Raw | ConvertFrom-Json -AsHashtable -Depth 50
    foreach ($k in @(@($la.Keys) + @($lb.Keys) | Sort-Object -CaseSensitive -Unique)) {
        if ($volatileKey.IsMatch($k)) { continue }
        if ($k -cin $identityKey) { $identity[$k] = [ordered]@{ lab = $la[$k]; v4 = $lb[$k] }; continue }
        if (-not $la.ContainsKey($k) -or -not $lb.ContainsKey($k)) { $differences.Add([ordered]@{ field = $k; lab = $la.ContainsKey($k); v4 = $lb.ContainsKey($k) }); continue }
        if ((Canon $la[$k]) -cne (Canon $lb[$k])) { $differences.Add([ordered]@{ field = $k; lab = (Canon $la[$k]).Substring(0, [Math]::Min(200, (Canon $la[$k]).Length)); v4 = (Canon $lb[$k]).Substring(0, [Math]::Min(200, (Canon $lb[$k]).Length)) }) }
    }
    # identity changes are the expected ones
    if ($identity.producer.lab -cne $sides.lab.id -or $identity.producer.v4 -cne $sides.v4.id) { $differences.Add([ordered]@{ field = 'producer'; expected = "$($sides.lab.id) / $($sides.v4.id)"; actual = "$($identity.producer.lab) / $($identity.producer.v4)" }) }
    foreach ($side in 'lab', 'v4') {
        $own = Hash (Join-Path $target $sides[$side].policy)
        if ($identity.policySha256.$side -cne $own) { $differences.Add([ordered]@{ field = "policySha256 ($side)"; expected = $own; actual = $identity.policySha256.$side }) }
    }
    $identity.sharedFields = @($la.Keys | Where-Object { -not $volatileKey.IsMatch($_) -and $_ -cnotin $identityKey } | Sort-Object -CaseSensitive)
    $identity.edges = @($la['edges']).Count; $identity.projects = @($la['projects']).Count
}
$positive = [ordered]@{ lab = $a; v4 = $b; identity = $identity; differences = @($differences) }

# 2. Negative parity
$csproj = (& git -C $target ls-files 'src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj').Trim()
$mutations = [ordered]@{
    'unsupported-construct' = @{ commit = $true; apply = { $p = Join-Path $target $csproj; $t = [IO.File]::ReadAllText($p); [IO.File]::WriteAllText($p, $t.Replace('</Project>', "  <Target Name=`"A3Parity`"><Exec Command=`"echo a3`" /></Target>`n</Project>"), [Text.UTF8Encoding]::new($false)) } }
    'project-set-drift' = @{ commit = $true; apply = { $d = Join-Path $target 'src/A3Parity/IFX.A3Parity'; [void][IO.Directory]::CreateDirectory($d); [IO.File]::WriteAllText((Join-Path $d 'IFX.A3Parity.csproj'), "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>`n", [Text.UTF8Encoding]::new($false)) } }
    'source-policy-drift' = @{ commit = $true; apply = { foreach ($p in @('docs/guards/candidates/ifx-gate-coverage-c1n/modules/ifx-reference-cycle/policy.json', 'docs/guards/v4-adoption/producers/graph/policies/ifx-reference-cycle-policy.json')) { $f = Join-Path $target $p; [IO.File]::WriteAllText($f, [IO.File]::ReadAllText($f) + ' ', [Text.UTF8Encoding]::new($false)) } } }
    'dirty-tracked-source' = @{ commit = $false; apply = { $p = Join-Path $target $csproj; [IO.File]::WriteAllText($p, [IO.File]::ReadAllText($p) + "`n", [Text.UTF8Encoding]::new($false)) } }
}
$sourcePaths = @('docs/guards/candidates/ifx-gate-coverage-c1n/modules/ifx-reference-cycle/policy.json', 'docs/guards/v4-adoption/producers/graph/policies/ifx-reference-cycle-policy.json')
$negativeResults = [ordered]@{}
foreach ($name in $mutations.Keys) {
    $m = $mutations[$name]
    & git -C $target checkout --quiet --force --detach $head; & git -C $target clean -fdq -e artifacts/
    & $m.apply
    if ($m.commit) { & git -C $target add -A -- src docs; & git -C $target -c user.name=a3-parity -c user.email=a3@parity.invalid commit --quiet -m "A3-4 negative parity: $name" }
    $na = Invoke-Graph 'lab' "negative-$name"; $nb = Invoke-Graph 'v4' "negative-$name"
    $norm = { param($msg) $x = $msg.Replace($target.Replace('\', '/'), '<target>').Replace($target, '<target>'); foreach ($p in $sourcePaths) { $x = $x.Replace($p, '<source-policy>') }; $x }
    $ma = & $norm $na.message; $mb = & $norm $nb.message
    $negativeResults[$name] = [ordered]@{ committed = $m.commit; labExitCode = $na.exitCode; v4ExitCode = $nb.exitCode; labMessage = $ma; v4Message = $mb
        sameFailure = ($na.exitCode -ne 0 -and $nb.exitCode -ne 0 -and $ma -ceq $mb -and $ma) }
}
& git -C $target checkout --quiet --force --detach $head

# 3. Aggregate parity
$results = @('success', 'failure', 'cancelled', 'skipped')
$aggregate = [Collections.Generic.List[object]]::new()
function Invoke-Capture([string]$Script, [string[]]$Arguments) {
    $info = [Diagnostics.ProcessStartInfo]::new('pwsh')
    foreach ($x in @('-NoLogo', '-NoProfile', '-NonInteractive', '-File', $Script) + $Arguments) { $info.ArgumentList.Add($x) }
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true; $info.UseShellExecute = $false
    $p = [Diagnostics.Process]::Start($info); $o = $p.StandardOutput.ReadToEndAsync(); $e = $p.StandardError.ReadToEndAsync(); $p.WaitForExit()
    [ordered]@{ exitCode = $p.ExitCode; stdout = $o.Result.Replace("`r`n", "`n"); stderr = $e.Result.Replace("`r`n", "`n") }
}
foreach ($contract in $results) {
    foreach ($windows in $results) {
        $old = Invoke-Capture (Join-Path $repo 'docs/guards/candidates/ifx-i2b-051/Test-IFX050CutoverRollback.ps1') @('-Mode', 'Aggregate', '-ContractResult', $contract, '-WindowsResult', $windows)
        $new = Invoke-Capture (Join-Path $repo 'docs/guards/v4-adoption/ci/Invoke-IFXV4Aggregate.ps1') @('-ContractResult', $contract, '-WindowsResult', $windows)
        $aggregate.Add([ordered]@{ contract = $contract; windows = $windows; exitCode = $old.exitCode; equal = ($old.exitCode -eq $new.exitCode -and $old.stdout -ceq $new.stdout -and $old.stderr -ceq $new.stderr); newExitCode = $new.exitCode })
    }
}
$aggregateDifferences = @($aggregate | Where-Object { -not $_.equal })
$negativeMismatch = @($negativeResults.Values | Where-Object { -not $_.sameFailure })
$status = if ($differences.Count -eq 0 -and $negativeMismatch.Count -eq 0 -and $aggregateDifferences.Count -eq 0 -and @($aggregate | Where-Object { $_.contract -ceq 'success' -and $_.windows -ceq 'success' -and $_.exitCode -eq 0 }).Count -eq 1 -and @($aggregate | Where-Object { $_.exitCode -eq 16 }).Count -eq 15) { 'pass' } else { 'fail' }
Write-Json $ReportPath ([ordered]@{ formatVersion = 1; kind = 'ifx-052-closure-parity'; step = 'A3-4'; status = $status; head = $head
    graph = [ordered]@{ positive = $positive; negative = $negativeResults }; aggregate = @($aggregate)
    semanticDifferenceCount = $differences.Count; negativeMismatchCount = $negativeMismatch.Count; aggregateDifferenceCount = $aggregateDifferences.Count })
Write-Output "A3-4 closure parity $status`: graph semantic differences $($differences.Count), negative mismatches $($negativeMismatch.Count) of $($negativeResults.Count), aggregate differences $($aggregateDifferences.Count) of $($aggregate.Count)"
if ($status -cne 'pass') { exit 1 }
