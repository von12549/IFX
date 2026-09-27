[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$module = Join-Path $PSScriptRoot '../IFX.C6c25.Readiness.psm1'
Import-Module $module -Force

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$Path,$Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 20).Replace("`r`n","`n") + "`n"),[Text.UTF8Encoding]::new($false)) }
function Expect-Failure([scriptblock]$Action,[string]$Pattern) {
    $message = $null
    try { & $Action | Out-Null } catch { $message = $_.Exception.Message }
    Assert (-not [string]::IsNullOrWhiteSpace($message) -and $message -like "*$Pattern*") "Expected failure containing '$Pattern'; actual: $message"
}

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$runId = [guid]::NewGuid().ToString('N')
$rootRelative = "artifacts/guards/p10-ifx-114/c6c25-tests/$runId"
$root = Join-Path $repo $rootRelative
$commit = ('a' * 40) -join ''
$otherCommit = ('b' * 40) -join ''
$now = [DateTimeOffset]'2026-09-27T00:00:00+00:00'
$ids = @('assembly','database','frontend','generated','graph','solution','type')
$entries = [Collections.Generic.List[object]]::new()

foreach ($id in $ids) {
    $relative = "$rootRelative/$id/evidence-lock.json"
    $full = Join-Path $repo $relative
    $lock = [ordered]@{formatVersion=1;gate=$id;result='passed';targetCommit=$commit}
    if ($id -ceq 'type') {
        $lock.createdAt = $now.ToString('o')
        $lock.expiresAt = $now.AddMinutes(50).ToString('o')
    }
    Write-Json $full $lock
    $entries.Add([pscustomobject]@{id=$id;path=$relative;sha256=Hash $full})
}

$passed = @(Assert-IFX114EvidenceLocks -RepositoryRoot $repo -Locks @($entries.ToArray()) -ExpectedIds $ids -TargetCommit $commit -Now $now -MinimumRemainingSeconds 2700)
Assert ($passed.Count -eq 7) 'Valid seven-lock readiness fixture did not pass.'
$duplicate = @($entries.ToArray()) + $entries[0]
Expect-Failure { Assert-IFX114EvidenceLocks -RepositoryRoot $repo -Locks $duplicate -ExpectedIds $ids -TargetCommit $commit -Now $now -MinimumRemainingSeconds 2700 } 'seven required locks'
$typeRow = @($entries | Where-Object id -CEQ 'type')[0]
$typePath = Join-Path $repo $typeRow.path

$stale = Get-Content -LiteralPath $typePath -Raw | ConvertFrom-Json -Depth 20 -DateKind String
$stale.expiresAt = $now.AddMinutes(44).ToString('o')
Write-Json $typePath $stale
$typeRow.sha256 = Hash $typePath
Expect-Failure { Assert-IFX114EvidenceLocks -RepositoryRoot $repo -Locks @($entries.ToArray()) -ExpectedIds $ids -TargetCommit $commit -Now $now -MinimumRemainingSeconds 2700 } 'remaining lifetime'

$wrongCommit = Get-Content -LiteralPath $typePath -Raw | ConvertFrom-Json -Depth 20 -DateKind String
$wrongCommit.expiresAt = $now.AddMinutes(50).ToString('o')
$wrongCommit.targetCommit = $otherCommit
Write-Json $typePath $wrongCommit
$typeRow.sha256 = Hash $typePath
Expect-Failure { Assert-IFX114EvidenceLocks -RepositoryRoot $repo -Locks @($entries.ToArray()) -ExpectedIds $ids -TargetCommit $commit -Now $now -MinimumRemainingSeconds 2700 } 'Target commit mismatch'

$wrongCommit.targetCommit = $commit
Write-Json $typePath $wrongCommit
$typeRow.sha256 = ('0' * 64) -join ''
Expect-Failure { Assert-IFX114EvidenceLocks -RepositoryRoot $repo -Locks @($entries.ToArray()) -ExpectedIds $ids -TargetCommit $commit -Now $now -MinimumRemainingSeconds 2700 } 'hash mismatch'

$wrapper = Get-Command (Join-Path $PSScriptRoot '../Invoke-IFX114RecoveredSingleC6c.ps1')
$authorization = @($wrapper.Parameters['AuthorizeRecoveredC6c'].Attributes | Where-Object { $_ -is [Management.Automation.ParameterAttribute] })
Assert ($authorization.Count -eq 1 -and $authorization[0].Mandatory) 'Recovered C6c authorization switch must remain mandatory.'

$summary = [ordered]@{
    formatVersion = 1
    status = 'pass'
    scope = 'ifx-114-c6c25-readiness-tests'
    cases = @('valid-seven-lock-set','duplicate-lock-id','minimum-remaining-lifetime','target-commit-mismatch','hash-mismatch','mandatory-authorization-switch')
}
$summaryPath = Join-Path $root 'summary.json'
Write-Json $summaryPath $summary
Write-Output "IFX 1.1.4 C6c25 readiness tests passed: $summaryPath"
