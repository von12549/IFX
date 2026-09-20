[CmdletBinding()]
param()

# Stage-oriented test group: Post.
$ErrorActionPreference = 'Stop'
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not [IO.File]::Exists((Join-Path $package 'guard-system.json'))) { $package = [IO.Path]::GetFullPath((Join-Path $package '..')) }
if (-not [IO.File]::Exists((Join-Path $package 'guard-system.json'))) { throw 'Cannot resolve the IFX guard package root.' }
$root = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$legacyHistory = Join-Path $root 'docs/guards/V3_ifx/history'
$stageHistory = Join-Path $root 'docs/guards/V3_ifx/stages/post/gates/historical-integrity'
$legacyComplete = [IO.File]::Exists((Join-Path $legacyHistory 'Invoke-IFXHistoricalIntegrity.ps1')) -and [IO.File]::Exists((Join-Path $legacyHistory 'manifest.json'))
$stageComplete = [IO.File]::Exists((Join-Path $stageHistory 'Invoke-IFXHistoricalIntegrity.ps1')) -and [IO.File]::Exists((Join-Path $stageHistory 'manifest.json'))
if ($legacyComplete -eq $stageComplete) { throw 'Historical Integrity must have exactly one complete legacy or stage-owned layout.' }
$historyRoot = if ($stageComplete) { $stageHistory } else { $legacyHistory }
$runner = Join-Path $historyRoot 'Invoke-IFXHistoricalIntegrity.ps1'
$maintenance = Join-Path $root 'docs/guards/V3_ifx/maintenance/New-IFXHistoryManifest.ps1'
$fixtureRoot = Join-Path $root "artifacts/guards/v3-ifx/history-fixture-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null
try {
    & $maintenance -Mode Check
    $trackedManifest = Join-Path $historyRoot 'manifest.json'
    $trackedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $trackedManifest).Hash
    $preview = Join-Path $fixtureRoot 'preview.json'
    & $maintenance -Mode Preview -PreviewPath ([IO.Path]::GetRelativePath($root, $preview).Replace('\','/'))
    if (-not (Test-Path -LiteralPath $preview -PathType Leaf)) { throw 'History Preview produced no candidate.' }
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $trackedManifest).Hash -cne $trackedHash) { throw 'History Preview changed the tracked manifest.' }
    $applied = Join-Path $fixtureRoot 'applied.json'
    $rejected = @(& pwsh -NoProfile -File $maintenance -Mode Apply -OutputPath ([IO.Path]::GetRelativePath($root, $applied).Replace('\','/')) 2>&1)
    if ($LASTEXITCODE -eq 0 -or (Test-Path -LiteralPath $applied)) { throw "History Apply without acceptance did not fail closed: $($rejected -join ' | ')" }
    & $maintenance -Mode Apply -AcceptMaintenance -OutputPath ([IO.Path]::GetRelativePath($root, $applied).Replace('\','/'))
    & $maintenance -Mode Check -OutputPath ([IO.Path]::GetRelativePath($root, $applied).Replace('\','/'))
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $preview).Hash -cne (Get-FileHash -Algorithm SHA256 -LiteralPath $applied).Hash) { throw 'History Preview and Apply candidates differ.' }
    & $runner -ReportPath ([IO.Path]::GetRelativePath($root, (Join-Path $fixtureRoot 'positive.json')).Replace('\','/'))
    $manifest = Get-Content -Raw $trackedManifest | ConvertFrom-Json -Depth 100
    $manifest.entries[0].sha256 = '0' * 64
    $tamperedManifest = Join-Path $fixtureRoot 'manifest.json'
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tamperedManifest -Encoding utf8NoBOM
    $output = @(& pwsh -NoProfile -File $runner -RepositoryRoot $root -ManifestPath ([IO.Path]::GetRelativePath($root, $tamperedManifest).Replace('\','/')) -ReportPath ([IO.Path]::GetRelativePath($root, (Join-Path $fixtureRoot 'negative.json')).Replace('\','/')) 2>&1)
    if ($LASTEXITCODE -eq 0) { throw "Tampered history manifest unexpectedly passed: $($output -join ' | ')" }
    $negative = Get-Content -Raw (Join-Path $fixtureRoot 'negative.json') | ConvertFrom-Json -Depth 20
    if ($negative.status -ne 'fail' -or @($negative.checks | Where-Object hashMatches -eq $false).Count -eq 0) { throw 'Tamper negative case did not report a hash mismatch.' }
    $manifest.entries[0].sha256 = (Get-Content -Raw $trackedManifest | ConvertFrom-Json -Depth 100).entries[0].sha256
    $manifest.references[0].target = 'docs/architecture/review/evidence/missing-history-target.md'
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tamperedManifest -Encoding utf8NoBOM
    $output = @(& pwsh -NoProfile -File $runner -RepositoryRoot $root -ManifestPath ([IO.Path]::GetRelativePath($root, $tamperedManifest).Replace('\','/')) -ReportPath ([IO.Path]::GetRelativePath($root, (Join-Path $fixtureRoot 'dangling.json')).Replace('\','/')) 2>&1)
    if ($LASTEXITCODE -eq 0) { throw "Dangling history reference unexpectedly passed: $($output -join ' | ')" }
    Write-Host 'IFX historical integrity positive, tamper and dangling-reference tests passed.'
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
$global:LASTEXITCODE = 0
