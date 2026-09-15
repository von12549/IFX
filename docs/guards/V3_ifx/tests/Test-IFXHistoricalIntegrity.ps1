[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$runner = Join-Path $root 'docs/guards/V3_ifx/history/Invoke-IFXHistoricalIntegrity.ps1'
$fixtureRoot = Join-Path $root "artifacts/guards/v3-ifx/history-fixture-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixtureRoot | Out-Null
try {
    & $runner -ReportPath ([IO.Path]::GetRelativePath($root, (Join-Path $fixtureRoot 'positive.json')).Replace('\','/'))
    $manifest = Get-Content -Raw (Join-Path $root 'docs/guards/V3_ifx/history/manifest.json') | ConvertFrom-Json -Depth 100
    $manifest.entries[0].sha256 = '0' * 64
    $tamperedManifest = Join-Path $fixtureRoot 'manifest.json'
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tamperedManifest -Encoding utf8NoBOM
    $output = @(& pwsh -NoProfile -File $runner -RepositoryRoot $root -ManifestPath ([IO.Path]::GetRelativePath($root, $tamperedManifest).Replace('\','/')) -ReportPath ([IO.Path]::GetRelativePath($root, (Join-Path $fixtureRoot 'negative.json')).Replace('\','/')) 2>&1)
    if ($LASTEXITCODE -eq 0) { throw "Tampered history manifest unexpectedly passed: $($output -join ' | ')" }
    $negative = Get-Content -Raw (Join-Path $fixtureRoot 'negative.json') | ConvertFrom-Json -Depth 20
    if ($negative.status -ne 'fail' -or @($negative.checks | Where-Object hashMatches -eq $false).Count -eq 0) { throw 'Tamper negative case did not report a hash mismatch.' }
    $manifest.entries[0].sha256 = (Get-Content -Raw (Join-Path $root 'docs/guards/V3_ifx/history/manifest.json') | ConvertFrom-Json -Depth 100).entries[0].sha256
    $manifest.references[0].target = 'docs/architecture/review/evidence/missing-history-target.md'
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $tamperedManifest -Encoding utf8NoBOM
    $output = @(& pwsh -NoProfile -File $runner -RepositoryRoot $root -ManifestPath ([IO.Path]::GetRelativePath($root, $tamperedManifest).Replace('\','/')) -ReportPath ([IO.Path]::GetRelativePath($root, (Join-Path $fixtureRoot 'dangling.json')).Replace('\','/')) 2>&1)
    if ($LASTEXITCODE -eq 0) { throw "Dangling history reference unexpectedly passed: $($output -join ' | ')" }
    Write-Host 'IFX historical integrity positive, tamper and dangling-reference tests passed.'
} finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
$global:LASTEXITCODE = 0
