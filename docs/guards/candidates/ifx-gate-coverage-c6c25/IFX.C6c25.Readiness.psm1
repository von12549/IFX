Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-IFXCondition([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-IFXSha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-IFX114EvidenceLocks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][object[]]$Locks,
        [Parameter(Mandatory)][string[]]$ExpectedIds,
        [Parameter(Mandatory)][string]$TargetCommit,
        [Parameter(Mandatory)][DateTimeOffset]$Now,
        [ValidateRange(1,86400)][int]$MinimumRemainingSeconds = 2700
    )

    $repo = [IO.Path]::GetFullPath($RepositoryRoot)
    Assert-IFXCondition ($TargetCommit -cmatch '^[a-f0-9]{40}$') 'Invalid Target commit for evidence-lock readiness.'
    $expected = @($ExpectedIds | Sort-Object -CaseSensitive -Unique)
    $actual = @($Locks | ForEach-Object { [string]$_.id } | Sort-Object -CaseSensitive -Unique)
    Assert-IFXCondition ($Locks.Count -eq $expected.Count -and $actual.Count -eq $expected.Count -and ($actual -join "`n") -ceq ($expected -join "`n")) 'Evidence-lock set does not match the seven required locks.'

    $rows = [Collections.Generic.List[object]]::new()
    foreach ($entry in @($Locks | Sort-Object id)) {
        $id = [string]$entry.id
        $relative = ([string]$entry.path).Replace('\','/')
        Assert-IFXCondition ($relative -cmatch '^artifacts/guards/[a-zA-Z0-9._/-]+/evidence-lock\.json$' -and -not $relative.Contains('..')) "Uncontrolled evidence-lock path: $id"
        $full = [IO.Path]::GetFullPath((Join-Path $repo $relative))
        $under = [IO.Path]::GetRelativePath($repo,$full).Replace('\','/')
        Assert-IFXCondition (-not [IO.Path]::IsPathRooted($under) -and $under -ne '..' -and -not $under.StartsWith('../')) "Evidence-lock path escapes the repository: $id"
        Assert-IFXCondition ([IO.File]::Exists($full)) "Evidence lock is missing: $id"
        $sha256 = Get-IFXSha256 $full
        Assert-IFXCondition ($sha256 -ceq [string]$entry.sha256) "Evidence-lock hash mismatch: $id"
        $lock = Get-Content -LiteralPath $full -Raw | ConvertFrom-Json -Depth 100 -DateKind String
        Assert-IFXCondition ([string]$lock.targetCommit -ceq $TargetCommit) "Evidence-lock Target commit mismatch: $id"

        $expiresAt = $null
        $remainingSeconds = $null
        if ($lock.PSObject.Properties.Name -contains 'expiresAt') {
            try { $expiresAt = [DateTimeOffset]::Parse([string]$lock.expiresAt,[Globalization.CultureInfo]::InvariantCulture) }
            catch { throw "Evidence-lock expiry is invalid: $id" }
            $remainingSeconds = [math]::Floor(($expiresAt - $Now).TotalSeconds)
            Assert-IFXCondition ($remainingSeconds -ge $MinimumRemainingSeconds) "Evidence-lock remaining lifetime is below $MinimumRemainingSeconds seconds: $id ($remainingSeconds seconds)."
        }
        $rows.Add([ordered]@{
            id = $id
            path = $relative
            sha256 = $sha256
            targetCommit = [string]$lock.targetCommit
            expiresAt = $(if ($null -ne $expiresAt) { $expiresAt.ToString('o') } else { $null })
            remainingSeconds = $remainingSeconds
        })
    }
    @($rows.ToArray())
}

Export-ModuleMember -Function Assert-IFX114EvidenceLocks
