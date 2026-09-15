[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$package = Join-Path $root 'docs/guards/V3_ifx'
$fixture = Join-Path $root "artifacts/guards/v3-ifx/specialized-contract-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
try {
    $resultSchema = Join-Path $package 'specialized/contracts/detector-result.schema.json'
    $fixtureSchema = Join-Path $package 'specialized/contracts/fixture.schema.json'
    $valid = Join-Path $fixture 'valid.json'; Set-Content $valid '{"formatVersion":1,"gate":"fixture","result":"passed","checks":{}}'
    $invalid = Join-Path $fixture 'invalid.json'; Set-Content $invalid '{"formatVersion":1,"gate":"fixture"}'
    $validFixture = Join-Path $fixture 'fixture.json'; Set-Content $validFixture '{"formatVersion":1,"expectedErrors":["violation"]}'
    $invalidAccepted = Test-Json -Path $invalid -SchemaFile $resultSchema -ErrorAction SilentlyContinue
    if (-not (Test-Json -Path $valid -SchemaFile $resultSchema) -or $invalidAccepted -or -not (Test-Json -Path $validFixture -SchemaFile $fixtureSchema)) { throw 'Specialized result or fixture schema behavior is incorrect.' }
    $missingPolicy = [IO.Path]::GetRelativePath($root, (Join-Path $fixture 'missing-policy.json')).Replace('\','/')
    $missingReport = [IO.Path]::GetRelativePath($root, (Join-Path $fixture 'missing-report.json')).Replace('\','/')
    $output = @(& pwsh -NoProfile -File (Join-Path $package 'specialized/scripts/Test-Plan04ExtractionPolicy.ps1') -PolicyPath $missingPolicy -StatusPath $missingReport 2>&1)
    if ($LASTEXITCODE -eq 0) { throw "Missing specialized authority unexpectedly passed: $($output -join ' | ')" }
    Write-Host 'IFX specialized result/fixture contracts and missing-authority failure passed.'
} finally {
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
