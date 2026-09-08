[CmdletBinding()]
param(
    [string] $ReportPath,
    [string] $BaselinePath = 'mcp/LayerGuard/baselines/b4.json',
    [switch] $SkipTests
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$toolProject = Join-Path $repositoryRoot 'mcp/LayerGuard/src/LayerGuard/LayerGuard.csproj'
$toolSolution = Join-Path $repositoryRoot 'mcp/LayerGuard/LayerGuard.slnx'
$sourceRoot = Join-Path $repositoryRoot 'src'
$policy = Join-Path $sourceRoot 'layerguard.json'
$baseline = if ([IO.Path]::IsPathRooted($BaselinePath)) { $BaselinePath } else { Join-Path $repositoryRoot $BaselinePath }

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $repositoryRoot 'artifacts/layerguard/b4-latest.json'
}
elseif (-not [System.IO.Path]::IsPathRooted($ReportPath)) {
    $ReportPath = Join-Path $repositoryRoot $ReportPath
}

$reportDirectory = Split-Path -Parent $ReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null

if (-not $SkipTests) {
    dotnet test $toolSolution --no-restore
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

dotnet run --no-restore --project $toolProject -- check $sourceRoot --config $policy --baseline $baseline --format json --report $ReportPath --quiet
$checkExitCode = $LASTEXITCODE
if ($checkExitCode -eq 0) {
    Write-Host "LayerGuard B4 strict policy gate passed. Report: $ReportPath"
}
else {
    Write-Error "LayerGuard found a new/stale violation or invalid baseline. Report: $ReportPath"
}
exit $checkExitCode
