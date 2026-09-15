[CmdletBinding()]
param([string] $OutputPath = 'docs/guards/V3_ifx/history/manifest.json')

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$paths = @(
    'mcp/LayerGuard/baselines/b0.5.json',
    'mcp/LayerGuard/baselines/b1.json',
    'mcp/LayerGuard/baselines/b2.json',
    'mcp/LayerGuard/baselines/b3.json',
    'mcp/LayerGuard/baselines/b4.json',
    'mcp/LayerGuard/baselines/plan05.json',
    'mcp/LayerGuard/baselines/plan06.json',
    'mcp/LayerGuard/baselines/plan07.json',
    'docs/architecture/review/evidence/plan00-prerequisite-release-status.json',
    'docs/architecture/review/evidence/03-a1-layerguard-policy-binding-status.json',
    'docs/architecture/review/evidence/layerguard/B1-report.json',
    'docs/architecture/review/evidence/layerguard/B4-report.json',
    'docs/architecture/review/evidence/layerguard/B4-validation-status.json',
    'docs/architecture/review/evidence/plan04/phase0-baseline-status.json',
    'docs/architecture/review/evidence/plan04/phase2-audit-status.json'
)
function Hash-CanonicalText([string] $path) {
    $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n")
    ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))).ToLowerInvariant()
}
$entries = foreach ($relative in $paths) {
    $full = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Historical file is missing: $relative" }
    $document = Get-Content -Raw -LiteralPath $full | ConvertFrom-Json -Depth 100
    [ordered]@{
        path = $relative
        purpose = if ($relative -like 'mcp/LayerGuard/baselines/*') { 'historical-layerguard-baseline' } else { 'historical-review-evidence' }
        formatVersion = $document.formatVersion
        summary = [ordered]@{
            result = if ($document.PSObject.Properties.Name -contains 'result') { $document.result } else { $null }
            gate = if ($document.PSObject.Properties.Name -contains 'gate') { $document.gate } else { $null }
            plan = if ($document.PSObject.Properties.Name -contains 'plan') { $document.plan } else { $null }
        }
        sha256 = Hash-CanonicalText $full
        changePolicy = 'explicit-history-manifest-regeneration-after-review'
    }
}
$manifest = [ordered]@{
    formatVersion = 1
    status = 'historical-integrity-only'
    authority = 'tracked historical evidence; never interpreted as current readiness'
    entries = @($entries)
    references = @(
        [ordered]@{ source = 'docs/architecture/review/evidence/plan00-prerequisite-release-status.json'; target = 'docs/architecture/review/evidence/plan00-prerequisite-release.md' },
        [ordered]@{ source = 'docs/architecture/review/evidence/layerguard/B4-validation-status.json'; target = 'docs/architecture/review/evidence/layerguard/B1-report.json' },
        [ordered]@{ source = 'docs/architecture/review/evidence/layerguard/B4-validation-status.json'; target = 'docs/architecture/review/evidence/layerguard/B4-report.json' }
    )
}
$resolved = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $root $OutputPath }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolved) | Out-Null
[IO.File]::WriteAllText($resolved, (($manifest | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
Write-Host "IFX history manifest generated: $resolved"
