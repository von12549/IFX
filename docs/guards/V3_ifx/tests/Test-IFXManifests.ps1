[CmdletBinding()]
param()

# Positive and negative fixtures for scripts/Invoke-IFXManifestCheck.ps1 (Plan 06 P1.5).

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repository = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$artifacts = [IO.Path]::GetFullPath((Join-Path $repository 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $artifacts "v3-ifx-manifests-$([Guid]::NewGuid().ToString('N'))"))
if (-not $fixture.StartsWith($artifacts + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
$checker = Join-Path $package 'scripts/Invoke-IFXManifestCheck.ps1'
$utf8 = [Text.UTF8Encoding]::new($false)

function Copy-Into([string] $source, [string] $relative) {
    $destination = Join-Path $fixture $relative
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Copy($source, $destination, $true)
}

function Invoke-Case([string] $label, [int] $expected, [string] $relative, [scriptblock] $mutate, [string] $expectText) {
    $path = if ($relative) { Join-Path $fixture $relative } else { $null }
    $original = if ($path -and [IO.File]::Exists($path)) { [IO.File]::ReadAllBytes($path) } else { $null }
    try {
        if ($mutate) {
            if ($path -and $relative.EndsWith('.json') -and [IO.File]::Exists($path)) {
                $document = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 50
                & $mutate $document
                [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 50) + "`n", $utf8)
            } else { & $mutate $path }
        }
        $output = @(& pwsh -NoProfile -File $checker -TargetRoot $fixture 2>&1) -join ' | '
        if ($LASTEXITCODE -ne $expected) { throw "$label expected exit $expected, got ${LASTEXITCODE}: $output" }
        if ($expectText -and -not $output.Contains($expectText, [StringComparison]::Ordinal)) { throw "$label did not report '$expectText': $output" }
        Write-Host "PASS $label"
    }
    finally {
        if ($path) {
            if ($null -ne $original) { [IO.File]::WriteAllBytes($path, $original) } elseif ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
        }
    }
}

try {
    foreach ($file in Get-ChildItem -LiteralPath $package -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($package, $file.FullName).Replace('\', '/')
        if ($relative -match '(^|/)(bin|obj)/' -or $relative.StartsWith('analysis/ifx/refactor-baseline/ci-evidence/')) { continue }
        Copy-Into $file.FullName "docs/guards/V3_ifx/$relative"
    }
    Copy-Into (Join-Path $repository '.github/workflows/v3-ifx-guardrails.yml') '.github/workflows/v3-ifx-guardrails.yml'
    Copy-Into (Join-Path $repository '.github/CODEOWNERS') '.github/CODEOWNERS'
    foreach ($relative in @('Directory.Build.props', 'Directory.Packages.props', 'docs/Directory.Packages.props', 'docs/guards/V3_backup/README.md')) { Copy-Into (Join-Path $repository $relative) $relative }
    foreach ($root in @('docs/guards/V3/build', 'docs/guards/V3/tests')) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repository $root) -Recurse -File) {
            $relative = [IO.Path]::GetRelativePath($repository, $file.FullName).Replace([IO.Path]::DirectorySeparatorChar, '/')
            if ($relative -match '(^|/)(bin|obj)/') { continue }
            Copy-Into $file.FullName $relative
        }
    }

    $stagePost = 'docs/guards/V3_ifx/stages/post/stage.json'
    $commands = 'docs/guards/V3_ifx/shared/commands.json'
    $tcb = 'docs/guards/V3_ifx/shared/trusted-components.json'
    $system = 'docs/guards/V3_ifx/guard-system.json'

    Invoke-Case 'current manifests pass' 0
    Invoke-Case 'stage declaring a command-owned field fails' 1 $stagePost { param($d) $d['entryPoint'] = 'docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1' } "command-owned field 'entryPoint'"
    Invoke-Case 'command declaring a stage-owned field fails' 1 $commands { param($d) $d.commands[0]['dependencies'] = @('pre') } "stage-owned field 'dependencies'"
    Invoke-Case 'stage referencing an unknown command fails' 1 $stagePost { param($d) $d.commands += 'ifx-missing-command' } "unknown command 'ifx-missing-command'"
    Invoke-Case 'command claiming an unlisted stage fails' 1 $commands { param($d) ($d.commands | Where-Object { $_.id -eq 'ifx-quality' }).stages += 'diff' } "claims stage 'diff'"
    Invoke-Case 'missing gate for a required check fails' 1 $stagePost { param($d) $d.gates = @($d.gates | Where-Object { $_.id -ne 'v3-quality-frontend' }) } "Required check 'v3-quality-frontend'"
    Invoke-Case 'duplicate gate fails' 1 $stagePost { param($d) $d.gates += ($d.gates | Where-Object { $_.id -eq 'v3-architecture' }) } "Required check 'v3-architecture' must be declared by exactly one stage gate (found 2)"
    Invoke-Case 'gate that is not a required check fails' 1 $stagePost { param($d) $extra = ($d.gates[0] | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable); $extra.id = 'v3-extra'; $d.gates += $extra } "Stage gate 'v3-extra' is not a required check"
    Invoke-Case 'invalid trust contract type fails schema' 1 $stagePost { param($d) $d.gates[0].trustContract.type = 'trusted' } 'Schema validation failed'
    Invoke-Case 'verdict-chain script outside TCB fails' 1 $tcb { param($d) ($d.components | Where-Object { $_.id -eq 'tcb.engine.quality' }).paths = @('docs/guards/V3_ifx/quality/Invoke-IFXQuality.ps1') } 'Verdict-chain script is outside the trusted component manifest: docs/guards/V3_ifx/quality/Invoke-IFXAssemblyGuard.ps1'
    Invoke-Case 'manifest removing itself from protection fails' 1 $tcb { param($d) ($d.components | Where-Object { $_.id -eq 'tcb.manifest' }).paths = @('docs/guards/V3_ifx/stages/') } 'not self-protecting'
    Invoke-Case 'overlapping components fail' 1 $tcb { param($d) ($d.components | Where-Object { $_.id -eq 'tcb.engine.quality' }).paths += 'docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1' } 'overlap'
    Invoke-Case 'planned component claiming paths fails' 1 $tcb { param($d) $d.components += [ordered]@{ id = 'tcb.future-component'; type = 'future'; status = 'planned'; paths = @('Directory.Build.props'); validationSuite = @('future'); parityContract = 'future'; allowedChange = 'change-trusted-base' } } "Planned component 'tcb.future-component'"
    Invoke-Case 'workflow script added outside TCB fails' 1 '.github/workflows/v3-ifx-guardrails.yml' { param($p) [IO.File]::AppendAllText($p, "      - run: ./docs/guards/V3_ifx/scripts/Invoke-V3Setup.ps1`n") } 'Verdict-chain script is outside the trusted component manifest: docs/guards/V3_ifx/scripts/Invoke-V3Setup.ps1'
    Invoke-Case 'stage listed without manifest fails' 1 $system { param($d) $d.stages = @($d.stages | Where-Object { $_ -ne 'diff' }) } "Stage manifest 'diff' is not listed"
    Invoke-Case 'compatibility entry for a missing path fails' 1 $system { param($d) $d.compatibility.entries[0].legacyPath = 'docs/guards/V3_ifx/scripts/Missing.ps1' } 'missing legacy path'
    Write-Host 'IFX manifest tests passed.'
}
finally {
    if ([IO.Directory]::Exists($fixture)) { [IO.Directory]::Delete($fixture, $true) }
}
