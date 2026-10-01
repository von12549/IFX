# IFX I2-B amendment A3 step A3-10b: the installed-Host outcomes of the 0.5.2 composition (A3-10a) against those of the
# accepted 0.5.1 composition (A2-10a). Every case (clean Pre, deliberate fault, staged Post, dependency run, unstaged Post)
# must agree in status, exit category, executed stages, module and coverage counts, failing modules and finding rules;
# only the fault file name, paths, run identities and the Profile/package identity may differ.
[CmdletBinding()]
param(
    [string]$PredecessorPath = 'artifacts/guards/p10-ifx-i2b/a2-051/a210-c6e/host-verification.json',
    [string]$CurrentPath = 'artifacts/guards/p10-ifx-i2b/a3-052/a310-c6e/host-verification.json',
    [Parameter(Mandatory)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
$old = Get-Content (Full $PredecessorPath) -Raw | ConvertFrom-Json -AsHashtable -Depth 50; $new = Get-Content (Full $CurrentPath) -Raw | ConvertFrom-Json -AsHashtable -Depth 50
if ($old.status -cne 'pass' -or $new.status -cne 'pass') { throw 'Both host verifications must pass.' }
function Outcome($c) { [ordered]@{ hostExitCode = $c.hostExitCode; status = $c.status; exitCategory = $c.exitCategory; executedStages = @($c.executedStages); moduleCount = $c.moduleCount; passedModuleCount = $c.passedModuleCount
    coverageClaimCount = $c.coverageClaimCount; allCoverageNonVacuous = $c.allCoverageNonVacuous; failedModules = @($c.failedModules | ForEach-Object { "$($_.moduleId)|$($_.status)" })
    findings = @($c.findings | ForEach-Object { "$($_.ruleId)|$($_.detectorId)|$($_.severity)" } | Sort-Object) } }
$rows = foreach ($id in @($old.cases.Keys)) {
    if (-not $new.cases.Contains($id)) { [ordered]@{ case = $id; equal = $false; difference = 'missing in 0.5.2' }; continue }
    $a = (Outcome $old.cases[$id]) | ConvertTo-Json -Compress -Depth 5; $b = (Outcome $new.cases[$id]) | ConvertTo-Json -Compress -Depth 5
    [ordered]@{ case = $id; equal = ($a -ceq $b); v051 = $a; v052 = $b }
}
$checksEqual = (($old.checks | ConvertTo-Json -Compress) -ceq ($new.checks | ConvertTo-Json -Compress))
$status = if (@($rows | Where-Object { -not $_.equal }).Count -eq 0 -and @($old.cases.Keys).Count -eq @($new.cases.Keys).Count -and $checksEqual) { 'pass' } else { 'fail' }
Write-IFX050Json (Full $OutputPath) ([ordered]@{ formatVersion = 1; kind = 'ifx-052-host-outcomes-against-051'; step = 'A3-10b'; status = $status
    predecessor = [ordered]@{ path = $PredecessorPath; sha256 = Get-IFX050Sha256 (Full $PredecessorPath); profileSha256 = $old.installedRuntime.profileSha256; packageHash = $old.installedRuntime.packageHash }
    current = [ordered]@{ path = $CurrentPath; sha256 = Get-IFX050Sha256 (Full $CurrentPath); profileSha256 = $new.installedRuntime.profileSha256; packageHash = $new.installedRuntime.packageHash }
    checksEqual = $checksEqual; cases = @($rows) })
Write-Output "A3-10b host outcomes against 0.5.1 $status`: $(@($rows | Where-Object equal).Count)/$(@($rows).Count) cases equal, checks equal $checksEqual"
if ($status -cne 'pass') { exit 1 }
