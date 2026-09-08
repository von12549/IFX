[CmdletBinding()]
param(
    [string] $ReportPath,
    [switch] $SkipTests
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$toolProject = Join-Path $repositoryRoot 'mcp/LayerGuard/src/LayerGuard/LayerGuard.csproj'
$toolSolution = Join-Path $repositoryRoot 'mcp/LayerGuard/LayerGuard.slnx'
$sourceRoot = Join-Path $repositoryRoot 'src'
$policy = Join-Path $sourceRoot 'layerguard.json'
$baseline = Join-Path $repositoryRoot 'mcp/LayerGuard/baselines/b1.json'

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $repositoryRoot 'artifacts/layerguard/b1-latest.json'
}
elseif (-not [System.IO.Path]::IsPathRooted($ReportPath)) {
    $ReportPath = Join-Path $repositoryRoot $ReportPath
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null

if (-not $SkipTests) {
    dotnet test $toolSolution
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

dotnet run --no-restore --project $toolProject -- check $sourceRoot --config $policy --baseline $baseline --format json --report $ReportPath --quiet
$checkExitCode = $LASTEXITCODE
if ($checkExitCode -eq 0) {
    Write-Host "LayerGuard 03-A1 policy gate passed. Report: $ReportPath"
}
else {
    Write-Error "LayerGuard found a new/stale violation or invalid baseline. Report: $ReportPath"
}
exit $checkExitCode
