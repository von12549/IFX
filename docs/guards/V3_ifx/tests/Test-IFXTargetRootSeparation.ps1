[CmdletBinding()]
param(
    [ValidateSet('Validate', 'Pre', 'HistoricalIntegrity', 'G03', 'G04', 'G05', 'Plan04')]
    [string[]] $Modes = @('Validate', 'Pre', 'HistoricalIntegrity', 'G03', 'G04', 'G05', 'Plan04'),
    [switch] $SkipNegativeControls
)

# Plan 06 P2 root separation: the guard package runs from a copy outside the target repository against a target
# worktree from which package code and configuration have been removed. Verdicts must equal the in-place run, and a
# detector that derives the target from its own location, or package configuration read through the target, must fail.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repository = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$legacySpecialized = Join-Path $package 'specialized'
$stageSpecialized = Join-Path $package 'stages/post/gates/specialized'
$requiredSpecializedFiles = @('Invoke-IFXSpecialized.ps1', 'contracts/detector-result.schema.json', 'contracts/fixture.schema.json', 'scripts/Test-Plan04ExtractionPolicy.ps1')
$legacySpecializedComplete = @($requiredSpecializedFiles | Where-Object { -not [IO.File]::Exists((Join-Path $legacySpecialized $_)) }).Count -eq 0
$stageSpecializedComplete = @($requiredSpecializedFiles | Where-Object { -not [IO.File]::Exists((Join-Path $stageSpecialized $_)) }).Count -eq 0
if ($legacySpecializedComplete -eq $stageSpecializedComplete) { throw 'Specialized gates must have exactly one complete legacy or stage-owned layout.' }
$specializedRelativeRoot = if ($stageSpecializedComplete) { 'docs/guards/V3_ifx/stages/post/gates/specialized' } else { 'docs/guards/V3_ifx/specialized' }
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$work = [IO.Path]::GetFullPath((Join-Path $tempRoot "ifxsep-$([Guid]::NewGuid().ToString('N').Substring(0, 8))"))
if ($work.StartsWith($repository.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'The package copy must be outside the target repository.' }
$packageCopy = Join-Path $work 'p'
$target = Join-Path $work 't'
$packageOwned = '^(docs/guards/V3_ifx/(build|ci|commands|contracts|docs|generated|history|hooks|maintenance|policy|profiles|quality|rules|scripts|shared|specialized|stages|templates|tests)/|docs/guards/V3_ifx/guard-system\.json$|docs/guards/V3/(build|commands|contracts|generated|rules|scripts|templates|tests)/)'
# Files outside the package that the manifest checker validates as trusted components or compatibility entries.
$packageRepositoryFiles = @('.github/workflows/v3-ifx-guardrails.yml', '.github/CODEOWNERS', 'Directory.Build.props', 'Directory.Packages.props', 'docs/Directory.Packages.props')
$previousTargetRoot = $env:GUARD_TARGET_ROOT
$env:GUARD_TARGET_ROOT = $null

function Copy-File([string] $root, [string] $relative) {
    $source = Join-Path $repository $relative
    if (-not [IO.File]::Exists($source)) { return }
    $destination = Join-Path $root $relative
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Copy($source, $destination, $true)
}
function Invoke-Git([string[]] $arguments) {
    $output = @(& git -C $repository @arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "git $($arguments -join ' ') failed: $($output -join ' | ')" }
    return @($output | ForEach-Object { [string]$_ } | Where-Object { -not $_.StartsWith('warning: unable to access', [StringComparison]::OrdinalIgnoreCase) })
}
function Invoke-Guardrails([string] $runner, [string] $root, [string] $mode, [string] $label) {
    $arguments = switch -Regex ($mode) {
        '^(G03|G04|G05|Plan04)$' { @('-Mode', 'Specialized', '-SpecializedGate', $mode) }
        '^Pre$' { @('-Mode', 'Pre', '-PlannedPaths', 'src/Modules/CRM/IFX.Modules.CRM.Domain/Sample.cs') }
        default { @('-Mode', $mode) }
    }
    $output = "artifacts/guards/v3-ifx-separation/$label/$($mode.ToLowerInvariant())"
    $log = @(& pwsh -NoProfile -File $runner @arguments -TargetRoot $root -OutputDirectory $output 2>&1)
    $exit = $LASTEXITCODE
    $summaryName = switch ($mode) { 'HistoricalIntegrity' { 'summary-historical-integrity.json' } { $_ -match '^(G03|G04|G05|Plan04)$' } { 'summary-specialized.json' } default { "summary-$($mode.ToLowerInvariant()).json" } }
    $summaryPath = Join-Path (Join-Path $root $output) $summaryName
    $checks = if ([IO.File]::Exists($summaryPath)) {
        @((Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json).checks | ForEach-Object { "$($_.id)=$($_.status)" })
    } else { @('summary-missing') }
    return [pscustomobject]@{ Exit = $exit; Checks = ($checks -join ','); Log = ($log | Select-Object -Last 15) -join [Environment]::NewLine }
}

$failures = [Collections.Generic.List[string]]::new()
try {
    [void][IO.Directory]::CreateDirectory($work)
    foreach ($relative in @(Invoke-Git @('ls-files', '--cached', '--others', '--exclude-standard', '--', 'docs/guards/V3', 'docs/guards/V3_ifx'))) {
        if ($relative -match '(^|/)(bin|obj)/' -or $relative.StartsWith('docs/guards/V3_ifx/analysis/ifx/refactor-baseline/ci-evidence/')) { continue }
        Copy-File $packageCopy $relative
    }
    foreach ($relative in $packageRepositoryFiles) { Copy-File $packageCopy $relative }

    # The target keeps full Git history (frozen-revision checks need it) but loses every package-owned path.
    [void](Invoke-Git @('worktree', 'add', '--detach', $target, 'HEAD'))
    foreach ($relative in @(Invoke-Git @('diff', '--name-only', 'HEAD')) + @(Invoke-Git @('ls-files', '--others', '--exclude-standard'))) {
        if ($relative -match $packageOwned) { continue }
        if ([IO.File]::Exists((Join-Path $repository $relative))) { Copy-File $target $relative }
        elseif ([IO.File]::Exists((Join-Path $target $relative))) { [IO.File]::Delete((Join-Path $target $relative)) }
    }
    foreach ($relative in @(& git -C $target ls-files)) {
        if ($relative -match $packageOwned) { [IO.File]::Delete((Join-Path $target $relative)) }
    }
    foreach ($directory in @('docs/guards/V3_ifx/scripts', 'docs/guards/V3_ifx/specialized', 'docs/guards/V3_ifx/stages/post/gates/specialized', 'docs/guards/V3/scripts')) {
        if ([IO.Directory]::Exists((Join-Path $target $directory))) { [IO.Directory]::Delete((Join-Path $target $directory), $true) }
    }

    $inPlaceRunner = Join-Path $package 'scripts/Invoke-IFXGuardrails.ps1'
    $separatedRunner = Join-Path $packageCopy 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1'
    foreach ($mode in $Modes) {
        $inPlace = Invoke-Guardrails $inPlaceRunner $repository $mode 'in-place'
        $separated = Invoke-Guardrails $separatedRunner $target $mode 'separated'
        if ($inPlace.Exit -ne 0) { $failures.Add("$mode in-place run failed, so equivalence cannot be shown: $($inPlace.Log)"); continue }
        if ($separated.Exit -ne $inPlace.Exit -or $separated.Checks -ne $inPlace.Checks) {
            $failures.Add("$mode verdict differs: in-place exit $($inPlace.Exit) [$($inPlace.Checks)], separated exit $($separated.Exit) [$($separated.Checks)]: $($separated.Log)")
            continue
        }
        Write-Host "PASS $mode separated verdict equals in-place [$($separated.Checks)]"
    }

    if (-not $SkipNegativeControls) {
        # A detector that derives the target from its own location reads the package copy and must fail.
        $detector = Join-Path $packageCopy "$specializedRelativeRoot/scripts/Test-Plan04ExtractionPolicy.ps1"
        $original = [IO.File]::ReadAllBytes($detector)
        try {
            $text = [Text.Encoding]::UTF8.GetString($original)
            $leaky = [Regex]::Replace($text, 'if \(\$env:GUARD_TARGET_ROOT\) \{ \[IO\.Path\]::GetFullPath\(\$env:GUARD_TARGET_ROOT\) \} else \{ (\[IO\.Path\]::GetFullPath\(\(Join-Path \$PSScriptRoot ''\.\./\.\./\.\./\.\./\.\.''\)\)) \}', '$1')
            if ($leaky -eq $text) { throw 'Negative control could not remove the target root from the Plan04 extraction policy detector.' }
            [IO.File]::WriteAllText($detector, $leaky, [Text.UTF8Encoding]::new($false))
            $result = Invoke-Guardrails $separatedRunner $target 'Plan04' 'negative-location'
            if ($result.Exit -eq 0) { $failures.Add('A detector deriving the target from its own location passed from a package copy outside the target.') }
            else { Write-Host 'PASS location-derived target root fails outside the target' }
        }
        finally { [IO.File]::WriteAllBytes($detector, $original) }

        # Package configuration read through the target root must fail, because the target no longer carries the package.
        $legacyHistory = Join-Path $packageCopy 'docs/guards/V3_ifx/history/Invoke-IFXHistoricalIntegrity.ps1'
        $stageHistory = Join-Path $packageCopy 'docs/guards/V3_ifx/stages/post/gates/historical-integrity/Invoke-IFXHistoricalIntegrity.ps1'
        if ([IO.File]::Exists($legacyHistory) -eq [IO.File]::Exists($stageHistory)) { throw 'Historical Integrity engine must have exactly one active package path.' }
        $history = if ([IO.File]::Exists($stageHistory)) { $stageHistory } else { $legacyHistory }
        $historyManifestPath = if ([IO.File]::Exists($stageHistory)) { 'docs/guards/V3_ifx/stages/post/gates/historical-integrity/manifest.json' } else { 'docs/guards/V3_ifx/history/manifest.json' }
        $original = [IO.File]::ReadAllBytes($history)
        try {
            $text = [Text.Encoding]::UTF8.GetString($original)
            $leaky = $text.Replace("[IO.Path]::GetFullPath((Join-Path `$PSScriptRoot 'manifest.json'))", "(Resolve-InRoot '$historyManifestPath')")
            if ($leaky -eq $text) { throw 'Negative control could not route the history manifest through the target root.' }
            [IO.File]::WriteAllText($history, $leaky, [Text.UTF8Encoding]::new($false))
            $result = Invoke-Guardrails $separatedRunner $target 'HistoricalIntegrity' 'negative-package'
            if ($result.Exit -eq 0) { $failures.Add('Package configuration read through the target root passed against a target without the package.') }
            else { Write-Host 'PASS package configuration read through the target fails' }
        }
        finally { [IO.File]::WriteAllBytes($history, $original) }
    }
}
finally {
    $env:GUARD_TARGET_ROOT = $previousTargetRoot
    if ([IO.Directory]::Exists($target)) { & git -C $repository worktree remove --force $target 2>&1 | Out-Null }
    & git -C $repository worktree prune 2>&1 | Out-Null
    if ([IO.Directory]::Exists($work)) { [IO.Directory]::Delete($work, $true) }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "FAIL $failure" }
    exit 1
}
Write-Host "IFX target-root separation tests passed: $($Modes -join ', ')."
$global:LASTEXITCODE = 0
