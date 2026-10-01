# IFX I2-B amendment A3 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A3-3: controls of the relocated closure in
# docs/guards/v4-adoption/producers and docs/guards/v4-adoption/ci.
# Positive:
#  - static: no PowerShell or JSON file (origins.json excepted) names docs/guards/V3, V3_ifx or candidates (any case),
#    except a first-line provenance header ("# Relocated from" / "# Extracted from");
#  - closure: every docs/guards string constant of every script (PowerShell AST, simple path variables expanded,
#    Join-Path $PSScriptRoot resolved) lies under docs/guards/v4-adoption, and the staging script runs only producers
#    that exist there;
#  - every script parses; every Join-Path $PSScriptRoot stays inside its package (producers or ci);
#  - the graph producer's sourcePolicies name files under producers/graph/policies whose SHA-256 match; those two files
#    are byte copies of lab policies kept as hashed data (ruling R13): the path rules skip them, and a control proves that
#    the producer only hashes them (one Hash (Checked ...) read, no other use of a source path);
#  - the graph producer refuses to run without an explicit Target root; the aggregate refuses missing inputs;
#  - the A2 and A3 origin drift controls report no drift; the A2 producer controls still pass on the A2 scope (the
#    producer package without graph/).
# Negative: each rule is re-run on a mutated temporary copy of v4-adoption/{producers,ci} and must reject it.
[CmdletBinding()]
param([string]$ReportPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$adoption = Join-Path $repo 'docs/guards/v4-adoption'
$forbidden = [regex]'(?i)docs[\\/]+guards[\\/]+(V3_ifx|V3|candidates)([\\/''"]|$)'
$header = [regex]'^# (Relocated|Extracted) from docs/guards/'
$joinScript = [regex]'Join-Path\s+\$PSScriptRoot\s+(?<q>[''"])(?<lit>[^''"]+)\k<q>'
$hashedData = 'producers/graph/policies/'
$sourceRead = [regex]'Hash \(Checked \(Join-Path \$repo \$source\.path\)\)'
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

function Get-StringConstants([string]$Path) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    $vars = @{}
    foreach ($a in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        if ($a.Left -is [Management.Automation.Language.VariableExpressionAst] -and $a.Right -is [Management.Automation.Language.CommandExpressionAst] -and $a.Right.Expression -is [Management.Automation.Language.StringConstantExpressionAst] -and $a.Right.Expression.Value -match '(?i)^docs/guards/') { $vars[$a.Left.VariablePath.UserPath] = $a.Right.Expression.Value }
    }
    foreach ($n in $ast.FindAll({ param($x) $x -is [Management.Automation.Language.StringConstantExpressionAst] -or $x -is [Management.Automation.Language.ExpandableStringExpressionAst] }, $true)) {
        if ($n.Parent -is [Management.Automation.Language.ExpandableStringExpressionAst]) { continue }
        $t = $n.Value
        if ($n -is [Management.Automation.Language.ExpandableStringExpressionAst]) { foreach ($k in $vars.Keys) { $t = $t.Replace("`$$k/", "$($vars[$k])/") } }
        $t
    }
}

function Get-Violations([string]$Root) {
    # $Root holds producers/ and ci/ as in docs/guards/v4-adoption.
    $v = [Collections.Generic.List[string]]::new()
    foreach ($package in 'producers', 'ci') {
        $packageRoot = Join-Path $Root $package
        foreach ($file in @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse -Force | Where-Object { $_.Extension -in '.ps1', '.json' -and $_.Name -cne 'origins.json' })) {
            $rel = "$package/" + [IO.Path]::GetRelativePath($packageRoot, $file.FullName).Replace('\', '/')
            if ($rel.StartsWith($hashedData, [StringComparison]::Ordinal)) { continue }
            $lines = [IO.File]::ReadAllLines($file.FullName)
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $isHeader = $i -eq 0 -and $file.Extension -ceq '.ps1' -and $header.IsMatch($lines[0])
                if (-not $isHeader -and $forbidden.IsMatch($lines[$i])) { $v.Add("forbidden-path: ${rel}:$($i + 1)") }
            }
            if ($file.Extension -ceq '.ps1') {
                $tokens = $null; $errors = $null; [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
                if (@($errors).Count) { $v.Add("parse-error: $rel"); continue }
                foreach ($m in $joinScript.Matches([IO.File]::ReadAllText($file.FullName))) {
                    $inside = [IO.Path]::GetRelativePath($packageRoot, [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $m.Groups['lit'].Value)))
                    if ($inside.StartsWith('..') -or [IO.Path]::IsPathRooted($inside)) { $v.Add("escapes-package: ${rel} -> $($m.Groups['lit'].Value)") }
                }
                foreach ($c in @(Get-StringConstants $file.FullName)) {
                    if ($c -match '(?i)^docs/guards/' -and -not $c.StartsWith('docs/guards/v4-adoption/', [StringComparison]::Ordinal) -and $c -cne 'docs/guards/v4-adoption') { $v.Add("closure: $rel -> $c") }
                }
            }
        }
    }
    # the staging script runs only producers that exist in the package
    $staging = Join-Path $Root 'ci/Invoke-IFXEvidenceProducers.ps1'
    foreach ($c in @(Get-StringConstants $staging | Where-Object { $_ -like 'docs/guards/v4-adoption/producers/*.ps1' })) {
        if (-not [IO.File]::Exists((Join-Path $Root ($c.Substring('docs/guards/v4-adoption/'.Length))))) { $v.Add("staging-missing-producer: $c") }
    }
    # the graph policy's sources are the relocated copies, by path and hash
    $policy = Get-Content -LiteralPath (Join-Path $Root 'producers/graph/policy.json') -Raw | ConvertFrom-Json -Depth 20
    foreach ($s in @($policy.sourcePolicies)) {
        $p = [string]$s.path
        if (-not $p.StartsWith('docs/guards/v4-adoption/producers/graph/policies/', [StringComparison]::Ordinal)) { $v.Add("policy-source-outside-package: $p"); continue }
        $full = Join-Path $Root ($p.Substring('docs/guards/v4-adoption/'.Length))
        if (-not [IO.File]::Exists($full)) { $v.Add("policy-source-missing: $p") } elseif ((Hash $full) -cne [string]$s.sha256) { $v.Add("policy-source-hash: $p") }
    }
    # the hashed-data files are only hashed by the graph producer
    $graph = [IO.File]::ReadAllLines((Join-Path $Root 'producers/graph/Invoke-IFXEvaluatedGraphProducer.ps1'))
    $sourceLines = @($graph | Where-Object { $_ -match '\$source\b' -and $_ -notmatch '^\s*foreach\(\$source in @\(\$policy\.sourcePolicies\)\)\{\s*$' })
    if ($sourceLines.Count -ne 1 -or -not $sourceRead.IsMatch($sourceLines[0])) { $v.Add('hashed-data-read: the graph producer uses a source policy other than by hash') }
    , $v
}

$results = [ordered]@{}
$positive = Get-Violations $adoption
$results.staticAndClosure = [ordered]@{ pass = ($positive.Count -eq 0); violations = @($positive) }

$saved = $env:GUARD_TARGET_ROOT; $env:GUARD_TARGET_ROOT = $null
try {
    $out = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $adoption 'producers/graph/Invoke-IFXEvaluatedGraphProducer.ps1') 2>&1) -join "`n"; $graphCode = $LASTEXITCODE
    $aggOut = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $adoption 'ci/Invoke-IFXV4Aggregate.ps1') 2>&1) -join "`n"; $aggCode = $LASTEXITCODE
} finally { $env:GUARD_TARGET_ROOT = $saved }
$results.graphRefusesWithoutTargetRoot = [ordered]@{ pass = ($graphCode -ne 0 -and $out -match 'An explicit Target root is required'); exitCode = $graphCode }
$results.aggregateRefusesMissingInputs = [ordered]@{ pass = ($aggCode -ne 0); exitCode = $aggCode }

$drift3 = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Copy-IFX052Closure.ps1') -Check 2>&1) -join "`n"
$results.a3OriginsNoDrift = [ordered]@{ pass = ($LASTEXITCODE -eq 0); report = ($drift3 | ConvertFrom-Json) }
$drift2 = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repo 'docs/guards/candidates/ifx-i2b-051/Copy-IFX051Producers.ps1') -Check 2>&1) -join "`n"
$results.allOriginsNoDrift = [ordered]@{ pass = ($LASTEXITCODE -eq 0); report = ($drift2 | ConvertFrom-Json) }
$a2Scope = Join-Path ([IO.Path]::GetTempPath()) "ifx052-a2scope-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
Copy-Item -LiteralPath (Join-Path $adoption 'producers') -Destination $a2Scope -Recurse
Remove-Item -LiteralPath (Join-Path $a2Scope 'graph') -Recurse -Force
try { $a2 = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repo 'docs/guards/candidates/ifx-i2b-051/Test-IFX051ProducerControls.ps1') -ProducerRoot $a2Scope 2>&1) -join "`n"; $a2Code = $LASTEXITCODE }
finally { Remove-Item -LiteralPath $a2Scope -Recurse -Force -ErrorAction SilentlyContinue }
$results.a2ProducerControls = [ordered]@{ pass = ($a2Code -eq 0); scope = 'producers without graph/'; summary = @($a2 -split "`n" | Where-Object { $_ -like 'A2-3*' }) }

$negatives = [Collections.Generic.List[object]]::new()
$mutations = @(
    @{ id = 'lab-path-literal'; file = 'producers/graph/Invoke-IFXEvaluatedGraphProducer.ps1'; edit = { param($t) $t + "`n`$x = 'docs/guards/candidates/ifx-gate-coverage-c1r2b/modules/ifx-c1-evaluated-reference/policy.json'`n" } }
    @{ id = 'staging-runs-lab-producer'; file = 'ci/Invoke-IFXEvidenceProducers.ps1'; edit = { param($t) $t.Replace("script = `"`$relocated/graph/Invoke-IFXEvaluatedGraphProducer.ps1`"", "script = 'docs/guards/candidates/ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1'") } }
    @{ id = 'staging-names-missing-producer'; file = 'ci/Invoke-IFXEvidenceProducers.ps1'; edit = { param($t) $t.Replace('/graph/Invoke-IFXEvaluatedGraphProducer.ps1', '/graph/Invoke-IFXMissingProducer.ps1') } }
    @{ id = 'policy-source-back-to-lab'; file = 'producers/graph/policy.json'; edit = { param($t) $t.Replace('docs/guards/v4-adoption/producers/graph/policies/ifx-reference-cycle-policy.json', 'docs/guards/candidates/ifx-gate-coverage-c1n/modules/ifx-reference-cycle/policy.json') } }
    @{ id = 'policy-source-hash-drift'; file = 'producers/graph/policies/ifx-ownership-graph-policy.json'; edit = { param($t) $t + ' ' } }
    @{ id = 'escape-package'; file = 'ci/Invoke-IFXV4Aggregate.ps1'; edit = { param($t) $t + "`n`$x = Join-Path `$PSScriptRoot '../../candidates/ifx-i2b-051/Test-IFX050CutoverRollback.ps1'`n" } }
    @{ id = 'v3-path-other-case'; file = 'ci/Invoke-IFXV4Aggregate.ps1'; edit = { param($t) $t + "`n`$x = 'DOCS/GUARDS/v3_IFX/stages/ci/required-checks.json'`n" } }
    @{ id = 'source-policy-parsed'; file = 'producers/graph/Invoke-IFXEvaluatedGraphProducer.ps1'; edit = { param($t) $t.Replace('foreach($source in @($policy.sourcePolicies)){', "foreach(`$source in @(`$policy.sourcePolicies)){`n    `$null=Get-Content (Join-Path `$repo `$source.path) -Raw|ConvertFrom-Json") } }
    @{ id = 'parse-error'; file = 'producers/graph/Invoke-IFXEvaluatedGraphProducer.ps1'; edit = { param($t) $t + "`nif (`n" } }
)
foreach ($m in $mutations) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "ifx052-neg-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    [void][IO.Directory]::CreateDirectory($tmp)
    Copy-Item -LiteralPath (Join-Path $adoption 'producers') -Destination (Join-Path $tmp 'producers') -Recurse
    Copy-Item -LiteralPath (Join-Path $adoption 'ci') -Destination (Join-Path $tmp 'ci') -Recurse
    try {
        $path = Join-Path $tmp $m.file
        $before = [IO.File]::ReadAllText($path); $after = & $m.edit $before
        if ($after -ceq $before) { throw "Mutation $($m.id) did not change $($m.file)." }
        [IO.File]::WriteAllText($path, $after, [Text.UTF8Encoding]::new($false))
        $found = Get-Violations $tmp
        $negatives.Add([ordered]@{ id = $m.id; rejected = ($found.Count -gt 0); violations = @($found) })
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
$results.negativeControls = [ordered]@{ pass = (@($negatives | Where-Object { -not $_.rejected }).Count -eq 0); controls = @($negatives) }

$status = if (@($results.Values | Where-Object { -not $_.pass }).Count -eq 0) { 'pass' } else { 'fail' }
$report = [ordered]@{ formatVersion = 1; kind = 'ifx-052-closure-controls'; step = 'A3-3'; status = $status; head = (& git -C $repo rev-parse HEAD).Trim(); results = $results }
if ($ReportPath) { [IO.File]::WriteAllText($ReportPath, (($report | ConvertTo-Json -Depth 12).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }
Write-Output "A3-3 closure controls $status`: static+closure $($results.staticAndClosure.pass), graph refusal $($results.graphRefusesWithoutTargetRoot.pass), aggregate refusal $($results.aggregateRefusesMissingInputs.pass), drift $($results.a3OriginsNoDrift.pass)/$($results.allOriginsNoDrift.pass), A2 controls $($results.a2ProducerControls.pass), negatives $(@($negatives | Where-Object rejected).Count)/$($negatives.Count)"
if ($status -cne 'pass') { $report | ConvertTo-Json -Depth 12 | Write-Warning; exit 1 }
