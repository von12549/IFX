[CmdletBinding()]
param(
    [ValidateSet('Generate', 'Check')][string] $Mode = 'Check',
    [string] $RepositoryRoot,
    [string] $Profile = 'ifx'
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GuardCore.psm1') -Force
$root = Get-GuardRoot $RepositoryRoot
$expected = New-GuardArtifacts $root $Profile
$directory = Resolve-GuardPath $root 'docs/guards/generated'
if ($Mode -eq 'Generate' -and -not [IO.Directory]::Exists($directory)) {
    [void] [IO.Directory]::CreateDirectory($directory)
}

$differences = [Collections.Generic.List[string]]::new()
foreach ($name in @('INDEX.md', 'COVERAGE_MATRIX.md', 'guard-manifest.json')) {
    $path = Resolve-GuardPath $root ('docs/guards/generated/' + $name)
    $content = [string] $expected[$name]
    if ($Mode -eq 'Generate') {
        Write-GuardText $path $content
    }
    elseif (-not [IO.File]::Exists($path) -or [IO.File]::ReadAllText($path) -cne $content) {
        $differences.Add($name)
    }
}
if ($Mode -eq 'Check' -and $differences.Count -gt 0) {
    $sourceChanges = [Collections.Generic.List[string]]::new()
    $currentManifest = Resolve-GuardPath $root 'docs/guards/generated/guard-manifest.json'
    if ([IO.File]::Exists($currentManifest)) {
        try {
            $actual = Get-Content -LiteralPath $currentManifest -Raw | ConvertFrom-Json -Depth 100
            $anticipated = [string] $expected['guard-manifest.json'] | ConvertFrom-Json -Depth 100
            $data = Get-GuardData $root $Profile
            foreach ($source in $anticipated.sources) {
                $old = @($actual.sources | Where-Object { $_.path -eq $source.path })
                if ($old.Count -ne 1 -or $old[0].sha256NormalizedText -ne $source.sha256NormalizedText) {
                    $ruleIds = @($data.Rules | Where-Object {
                        $_.authority.path -eq $source.path -or "docs/guards/inputs/rules/$($_.id).json" -eq $source.path
                    } | ForEach-Object { $_.id })
                    $label = if ($ruleIds.Count -gt 0) { "$($source.path) [$($ruleIds -join ', ')]" } else { [string] $source.path }
                    $sourceChanges.Add($label)
                }
            }
        }
        catch { $sourceChanges.Add('guard-manifest.json could not be parsed for source details') }
    }
    $detail = if ($sourceChanges.Count -gt 0) { " Changed sources: $($sourceChanges -join '; ')." } else { '' }
    throw "Guard generated artifacts are missing or stale: $($differences -join ', ').$detail Run -Mode Generate, review the diff, then rerun -Mode Check."
}
Write-Host "Guard regeneration $Mode passed ($($expected.Count) artifacts)."
