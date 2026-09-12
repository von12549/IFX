[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]] $ResultsDirectories,
    [Parameter(Mandatory)][string] $OutputPath,
    [string] $Phase = 'P05-S0'
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$runs = foreach ($directory in $ResultsDirectories) {
    $files = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot $directory) -Filter *.trx)
    if ($files.Count -eq 0) { throw "Missing test results: $directory" }
    foreach ($file in $files) {
        [xml] $xml = Get-Content -Raw -LiteralPath $file.FullName
        $counter = $xml.SelectSingleNode('//*[local-name()="Counters"]')
        $definition = $xml.SelectSingleNode('//*[local-name()="TestDefinitions"]/*[local-name()="UnitTest"]')
        if ($null -eq $counter -or $null -eq $definition) { throw "Invalid test report: $($file.Name)" }
        [pscustomobject][ordered]@{
            file = [IO.Path]::GetRelativePath($repositoryRoot, $file.FullName).Replace('\','/')
            sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            project = [IO.Path]::GetFileName($definition.GetAttribute('storage'))
            finishedAt = $xml.TestRun.Times.finish
            total = [int]$counter.total; passed = [int]$counter.passed
            failed = [int]$counter.failed; notExecuted = [int]$counter.notExecuted
        }
    }
}
$latest = @($runs | Group-Object project | ForEach-Object { $_.Group | Sort-Object finishedAt | Select-Object -Last 1 })
$allPassed = @($latest | Where-Object { $_.failed -gt 0 -or $_.notExecuted -gt 0 -or $_.total -ne $_.passed }).Count -eq 0
$report = [ordered]@{
    formatVersion = 1; phase = $Phase; baselineCommit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
    checkedAt = [DateTimeOffset]::UtcNow.ToString('O'); sdk = (& dotnet --version).Trim()
    result = if ($allPassed) { 'passed-latest-runs' } else { 'failed-or-incomplete' }
    total = ($latest | Measure-Object total -Sum).Sum
    passed = ($latest | Measure-Object passed -Sum).Sum
    failed = ($latest | Measure-Object failed -Sum).Sum
    projects = $latest.Count; latestRuns = $latest; allRuns = @($runs)
    targetDataAudit = 'pending-not-inspected'; production = 'not-claimed'
}
$output = Join-Path $repositoryRoot $OutputPath
New-Item -ItemType Directory -Force -Path (Split-Path $output) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $output -Encoding utf8
Write-Host "$Phase : $($report.passed)/$($report.total) latest tests in $($report.projects) projects; all attempts retained."
if (-not $allPassed) { exit 1 }
