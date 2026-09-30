# IFX I2-B amendment A2 step A2-3: static controls of the relocated producers in docs/guards/v4-adoption/producers.
# Positive: no PowerShell or JSON file (origins.json excepted) names a path under docs/guards/V3 or V3_ifx (any case) or
# the lab tree docs/guards/candidates, except the one provenance header line; every Join-Path $PSScriptRoot reference
# stays inside the producer package; every script parses; every entry point refuses to run without an explicit Target
# root; the relocation inventory re-derives equal and the origins show no drift. Negative: each rule is re-run on a
# mutated temporary copy of the package and must reject it.
[CmdletBinding()]
param(
    [string]$ProducerRoot,
    [string]$ReportPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$package = if ($ProducerRoot) { [IO.Path]::GetFullPath($ProducerRoot) } else { Join-Path $repo 'docs/guards/v4-adoption/producers' }
$forbidden = [regex]'(?i)docs[\\/]+guards[\\/]+(V3_ifx|V3|candidates)([\\/''"]|$)'
$joinScript = [regex]'Join-Path\s+\$PSScriptRoot\s+(?<q>[''"])(?<lit>[^''"]+)\k<q>'

function Get-Violations([string]$Root) {
    $v = [Collections.Generic.List[string]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Where-Object { $_.Extension -in '.ps1', '.json' -and $_.Name -cne 'origins.json' })) {
        $rel = [IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\', '/')
        $lines = [IO.File]::ReadAllLines($file.FullName)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $isHeader = ($i -eq 0 -and $file.Extension -ceq '.ps1' -and $lines[0].StartsWith('# Relocated from docs/guards/', [StringComparison]::Ordinal))
            if (-not $isHeader -and $forbidden.IsMatch($lines[$i])) { $v.Add("forbidden-path: ${rel}:$($i + 1)") }
        }
        if ($file.Extension -ceq '.ps1') {
            $tokens = $null; $errors = $null; [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
            if (@($errors).Count) { $v.Add("parse-error: $rel") }
            foreach ($m in $joinScript.Matches([IO.File]::ReadAllText($file.FullName))) {
                $target = [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $m.Groups['lit'].Value))
                $inside = [IO.Path]::GetRelativePath($Root, $target)
                if ($inside.StartsWith('..') -or [IO.Path]::IsPathRooted($inside)) { $v.Add("escapes-package: ${rel} -> $($m.Groups['lit'].Value)") }
            }
        }
    }
    , $v
}

$results = [ordered]@{}
$positive = Get-Violations $package
$results.staticClean = [ordered]@{ pass = ($positive.Count -eq 0); violations = @($positive) }

# Entry points without a Target root must refuse before doing any work.
$entries = [ordered]@{
    'solution/Invoke-IFXSolutionEvidenceProducer.ps1' = @(); 'assembly/Invoke-IFXAssemblyEvidenceProducer.ps1' = @('-SolutionLockPath', 'x')
    'frontend/Invoke-IFXFrontendEvidenceProducer.ps1' = @(); 'database/Invoke-IFXDatabaseEvidenceProducer.ps1' = @()
    'type/Invoke-IFXCompiledTypeEvidenceProducer.ps1' = @('-SolutionLockPath', 'x', '-AssemblyLockPath', 'y')
    'quality/Invoke-IFXQuality.ps1' = @('-Target', 'Solution'); 'database/Invoke-IFXSpecialized.ps1' = @()
}
$refusals = foreach ($e in $entries.Keys) {
    $saved = $env:GUARD_TARGET_ROOT; $env:GUARD_TARGET_ROOT = $null
    try { $out = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $package $e) @($entries[$e]) 2>&1) -join "`n"; $code = $LASTEXITCODE } finally { $env:GUARD_TARGET_ROOT = $saved }
    [ordered]@{ entry = $e; exitCode = $code; refused = ($code -ne 0 -and $out -match 'An explicit Target root is required') }
}
$results.refuseWithoutTargetRoot = [ordered]@{ pass = (@($refusals | Where-Object { -not $_.refused }).Count -eq 0); entries = @($refusals) }

if (-not $ProducerRoot) {
    & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'New-IFX051RelocationInventory.ps1') -Check *> $null
    $results.inventoryRederived = [ordered]@{ pass = ($LASTEXITCODE -eq 0) }
    $drift = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Copy-IFX051Producers.ps1') -Check 2>&1) -join "`n"
    $results.originsNoDrift = [ordered]@{ pass = ($LASTEXITCODE -eq 0); report = ($drift | ConvertFrom-Json) }
}

# Negative controls on a temporary copy of the package.
$negatives = [Collections.Generic.List[object]]::new()
$mutations = @(
    @{ id = 'v3-path-literal'; file = 'solution/Invoke-IFXSolutionEvidenceProducer.ps1'; append = "`n# docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1`n" }
    @{ id = 'v3-path-other-case'; file = 'quality/Invoke-IFXQuality.ps1'; append = "`n`$x = 'DOCS/GUARDS/v3_IFX/stages/post/policy/layerguard.json'`n" }
    @{ id = 'lab-tree-read'; file = 'type/Invoke-IFXCompiledTypeEvidenceProducer.ps1'; append = "`n`$x = Join-Path `$repo 'docs/guards/candidates/ifx-gate-coverage-c1r1b/modules/ifx-c1-type-provenance/policy.json'`n" }
    @{ id = 'escape-package'; file = 'database/Invoke-IFXSpecialized.ps1'; append = "`n`$x = Join-Path `$PSScriptRoot '../../../V3_ifx_copy/x.ps1'`n" }
    @{ id = 'parse-error'; file = 'frontend/Invoke-IFXFrontendEvidenceProducer.ps1'; append = "`nif (`n" }
)
foreach ($m in $mutations) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "ifx051-neg-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    Copy-Item -LiteralPath $package -Destination $tmp -Recurse
    try {
        [IO.File]::AppendAllText((Join-Path $tmp $m.file), $m.append)
        $found = Get-Violations $tmp
        $negatives.Add([ordered]@{ id = $m.id; rejected = ($found.Count -gt 0); violations = @($found) })
    } finally { foreach ($f in @(Get-ChildItem -LiteralPath $tmp -File -Recurse -Force)) { [IO.File]::Delete($f.FullName) }; foreach ($d in @(Get-ChildItem -LiteralPath $tmp -Directory -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending)) { [IO.Directory]::Delete($d.FullName) }; [IO.Directory]::Delete($tmp) }
}
$results.negativeControls = [ordered]@{ pass = (@($negatives | Where-Object { -not $_.rejected }).Count -eq 0); controls = @($negatives) }

$status = if (@($results.Values | Where-Object { -not $_.pass }).Count -eq 0) { 'pass' } else { 'fail' }
$report = [ordered]@{ formatVersion = 1; kind = 'ifx-051-producer-controls'; step = 'A2-3'; status = $status; producerRoot = [IO.Path]::GetRelativePath($repo, $package).Replace('\', '/'); results = $results }
if ($ReportPath) { [IO.File]::WriteAllText($ReportPath, (($report | ConvertTo-Json -Depth 12).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }
Write-Output "A2-3 producer controls $status`: static $($results.staticClean.pass), refusals $($results.refuseWithoutTargetRoot.pass), negatives $(@($negatives | Where-Object rejected).Count)/$($negatives.Count)"
if ($status -cne 'pass') { $report | ConvertTo-Json -Depth 12 | Write-Warning; exit 1 }
