[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $TargetRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $BaseSha,
    [string] $HeadRevision = 'HEAD',
    [string] $PlanPath,
    [string] $ReportPath = 'artifacts/guards/v3-ifx/trusted-base/protected-changes.json'
)

# Plan 06 §12.3 protected change verifier (CP06a, D22, D23), run from the base worktree against a committed head:
#  1. the changed set is the NUL-separated raw diff without rename detection from the verified merge base to head;
#  2. the change creates obligations: each removal of a protected path, one for any trusted component change, and one for
#     each semantic change of a registered policy or configuration file (D24, zero comparators), and each D18 domain
#     authority with blocking findings for the explicit head commit (D25);
#  3. the candidate authorizations are the schema-valid base records that head deletes, and each obligation must be
#     covered by exactly one of them, while every candidate must cover at least one obligation;
#  4. a change that only deletes schema-valid base records and writes its own plan pair revokes them (D22);
#  5. gitlinks in the protected scope, unregistered policy or configuration files and changed records fail.
# The report binds base, merge base, head and the hashes of the Diff protection configuration, the policy registry and
# the authorization schema; only a passing report lets the
# generated Diff test exempt its allowedDeletions.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'TrustedBase.psm1') -Force
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$baseRepository = Get-GuardFullPath (Join-Path $packageRoot '../../..')
$target = Get-GuardFullPath $TargetRoot
$report = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $target $ReportPath }))
$manifestPath = 'docs/guards/V3_ifx/shared/trusted-components.json'
$authorizationSchema = Join-Path $packageRoot 'contracts/authorization.schema.json'
$pathOperations = @('delete', 'move', 'case-rename')
$failures = [Collections.Generic.List[string]]::new()
$obligations = [Collections.Generic.List[object]]::new()
$candidates = [Collections.Generic.List[object]]::new()
$result = [ordered]@{
    formatVersion = 1
    check = 'protected-changes'
    status = 'fail'
    baseSha = $BaseSha
    mergeBase = $null
    headSha = $null
    protectionSha256 = $null
    policyRegistrySha256 = $null
    authorizationSchemaSha256 = $null
    planPath = if ($PlanPath) { $PlanPath.Replace('\', '/') } else { $null }
    revocation = $false
    obligations = @()
    authorizations = @()
    allowedDeletions = @()
    failures = @()
}

function Test-Under([string] $Path, [string] $Root) { return $Path -ceq $Root -or $Path.StartsWith("$Root/", [StringComparison]::Ordinal) }

function Test-PathRecord([object] $Candidate, [object[]] $Entries, [string] $MergeBase, [string] $Head, [Collections.Generic.HashSet[string]] $HeadPaths) {
    $record = $Candidate.Record
    $problems = [Collections.Generic.List[string]]::new()
    $source = [string]$record.source.path
    if (-not (Test-GuardTupleEqual $record.source.base (Get-GuardTreeEntry $target $MergeBase $source))) { $problems.Add("source $source does not match its base tree entry") }
    if ($null -ne (Get-GuardTreeEntry $target $Head $source)) { $problems.Add("source $source still exists in head") }
    $roots = @($source)
    if ($record.operation -eq 'delete') {
        foreach ($path in $HeadPaths) {
            if ($path.Equals($source, [StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith("$source/", [StringComparison]::OrdinalIgnoreCase)) { $problems.Add("head still contains $path, which differs from $source only in case; declare a case-rename"); break }
        }
    }
    else {
        $destination = [string]$record.destination.path
        $roots += $destination
        if (-not (Test-GuardTupleEqual $record.destination.base (Get-GuardTreeEntry $target $MergeBase $destination))) { $problems.Add("destination $destination does not match its recorded base state") }
        if (-not (Test-GuardTupleEqual $record.destination.head (Get-GuardTreeEntry $target $Head $destination))) { $problems.Add("destination $destination does not match its expected head tree entry") }
        $caseOnly = $source.Equals($destination, [StringComparison]::OrdinalIgnoreCase)
        if ($record.operation -eq 'move' -and $caseOnly) { $problems.Add("$source -> $destination differs only in case; declare a case-rename") }
        if ($record.operation -eq 'case-rename' -and -not $caseOnly) { $problems.Add("case-rename $source -> $destination changes more than letter case") }
        if (-not $caseOnly -and ((Test-Under $destination $source) -or (Test-Under $source $destination))) { $problems.Add("source and destination overlap: $source, $destination") }
    }
    $claimed = @($Entries | Where-Object { $entry = $_; @($roots | Where-Object { Test-Under $entry.Path $_ }).Count -gt 0 })
    $actualPaths = [string[]]@($claimed | ForEach-Object { $_.Path } | Sort-Object -Unique -CaseSensitive)
    $recordPaths = [string[]]@($record.changedPaths | Sort-Object -Unique -CaseSensitive)
    if (($actualPaths -join "`n") -cne ($recordPaths -join "`n")) { $problems.Add("changed paths differ from the authorization. Actual: $($actualPaths -join ', '); authorized: $($recordPaths -join ', ')") }
    foreach ($entry in $claimed) {
        $recorded = @($record.entries | Where-Object { $_.path -ceq $entry.Path })
        if ($recorded.Count -ne 1) { $problems.Add("no single entry for $($entry.Path)"); continue }
        if (-not (Test-GuardTupleEqual $recorded[0].base $entry.Base) -or -not (Test-GuardTupleEqual $recorded[0].head $entry.Head)) { $problems.Add("tuples of $($entry.Path) differ from the authorization") }
    }
    if (@($record.entries).Count -ne $claimed.Count) { $problems.Add('entries list paths outside the changed set') }
    foreach ($failure in (Test-GuardAuthorizationReferences $target $Head $record)) { $problems.Add($failure) }
    return [string[]]@($problems)
}

function Test-PolicyRecord([object] $Record, [object[]] $Obligations, [string] $Head) {
    # weaken-policy (D24): every listed policy must be an actual semantic change of this pull request, with the same base and
    # head blob hashes, head tree entry, registered schema or format and exactly the changed pointers.
    $problems = [Collections.Generic.List[string]]::new()
    $items = @($Record.policies)
    $itemPaths = [string[]]@($items | ForEach-Object { [string]$_.path } | Sort-Object -Unique -CaseSensitive)
    $recordPaths = [string[]]@($Record.changedPaths | Sort-Object -Unique -CaseSensitive)
    if ($itemPaths.Count -ne $items.Count) { $problems.Add('policies list a path more than once') }
    if (($itemPaths -join "`n") -cne ($recordPaths -join "`n")) { $problems.Add("changedPaths differ from the policies: $($recordPaths -join ', ')") }
    foreach ($item in $items) {
        $obligation = @($Obligations | Where-Object { $_.kind -eq 'policy-weakening' -and $_.paths[0] -ceq [string]$item.path })
        if ($obligation.Count -ne 1) { $problems.Add("$($item.path) has no semantic policy change in this pull request"); continue }
        $change = $obligation[0].change
        if ([string]$item.baseSha256 -cne [string]$change.BaseSha256 -or [string]$item.headSha256 -cne [string]$change.HeadSha256) { $problems.Add("blob hashes of $($item.path) differ from the authorization") }
        if (-not (Test-GuardTupleEqual $item.head $change.Head)) { $problems.Add("head tuple of $($item.path) differs from the authorization") }
        if ([string]$item.schema -cne $change.Schema) { $problems.Add("$($item.path) is registered with $($change.Schema), not $($item.schema)") }
        $pointers = [string[]]@(@($item.pointers) | Sort-Object -Unique -CaseSensitive)
        if (($pointers -join "`n") -cne ($change.Pointers -join "`n")) { $problems.Add("changed pointers of $($item.path) differ from the authorization. Actual: $($change.Pointers -join ', '); authorized: $($pointers -join ', ')") }
    }
    foreach ($failure in (Test-GuardAuthorizationReferences $target $Head $Record)) { $problems.Add($failure) }
    return [string[]]@($problems)
}

try {
    $packageHead = @(Invoke-GuardGit $baseRepository @('rev-parse', 'HEAD'))
    if ($packageHead.Count -ne 1 -or $packageHead[0] -ne $BaseSha) { throw "The verifier must run from the base commit $BaseSha, not $($packageHead -join '')." }
    if ((Resolve-GuardCommit $target $BaseSha) -ne $BaseSha) { throw "Target repository does not contain base commit $BaseSha." }
    $headSha = Resolve-GuardCommit $target $HeadRevision
    $result.headSha = $headSha
    $mergeBase = @(Invoke-GuardGit $target @('merge-base', $BaseSha, $headSha) -AllowFailure)
    if ($LASTEXITCODE -ne 0 -or $mergeBase.Count -ne 1 -or $mergeBase[0] -notmatch '^[0-9a-f]{40}$') { throw 'Base and head have no single merge base; fetch complete history.' }
    $mergeBase = $mergeBase[0]
    $result.mergeBase = $mergeBase

    $protection = Read-GuardProtection $packageRoot
    $result.protectionSha256 = $protection.Sha256
    $registry = Read-GuardPolicyRegistry $packageRoot
    $candidateRegistry = Read-GuardCandidatePolicyRegistry $target $headSha
    $candidateAuthorities = Read-GuardCandidateAuthorityRegistry $target $headSha
    $result.policyRegistrySha256 = $registry.sha256
    $result.authorizationSchemaSha256 = Get-GuardSha256 ([IO.File]::ReadAllBytes($authorizationSchema))
    $authorities = Get-Content -LiteralPath (Join-Path $packageRoot 'policy/authorities.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $projectionTargets = Get-GuardProjectionTargets $authorities
    $directory = $protection.AuthorizationDirectory
    if ($directory -and $directory -cne $AuthorizationDirectory) { throw "The Diff protection authorizationDirectory $directory differs from the trusted base protocol directory $AuthorizationDirectory." }

    $entries = @(Get-GuardChangedEntries $target $mergeBase $headSha)
    if ($entries.Count -eq 0) { throw 'The changed set is empty; base/head inputs may be wrong or history may be incomplete.' }
    $headPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($path in @(Invoke-GuardGitNul $target @('ls-tree', '-r', '-z', '--name-only', '--full-tree', $headSha))) { [void]$headPaths.Add($path) }
    $baseManifest = Get-Content -LiteralPath (Join-Path $baseRepository $manifestPath) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $headManifest = Read-GuardJsonBlob $target $headSha $manifestPath
    $tcb = Get-GuardTcbChanges $target $mergeBase $headSha $baseManifest $headManifest
    foreach ($gitlink in $tcb.Gitlinks) { $failures.Add("Gitlink (mode 160000) in the protected scope: $gitlink") }

    $planPair = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    if ($result.planPath) {
        [void]$planPair.Add($result.planPath)
        if ($result.planPath.EndsWith('.plan.json', [StringComparison]::Ordinal)) { [void]$planPair.Add($result.planPath.Substring(0, $result.planPath.Length - '.plan.json'.Length) + '.md') }
    }

    # ---- changed set: hard failures, candidate authorizations and obligations
    $removals = [Collections.Generic.List[object]]::new()
    foreach ($entry in $entries) {
        $isGitlink = ($null -ne $entry.Base -and $entry.Base.mode -eq '160000') -or ($null -ne $entry.Head -and $entry.Head.mode -eq '160000')
        if ($isGitlink -and (Test-GuardProtectedPath $protection $entry.Path) -and $entry.Path -notin $tcb.Gitlinks) { $failures.Add("Gitlink (mode 160000) in the protected scope: $($entry.Path)") }
        $isRecord = $directory -and $entry.Path.StartsWith($directory, [StringComparison]::Ordinal) -and $entry.Path.IndexOf('/', $directory.Length) -lt 0 -and $entry.Path.EndsWith('.json', [StringComparison]::Ordinal)
        if ($isRecord) {
            if ($null -ne $entry.Base -and $null -ne $entry.Head) { $failures.Add("Authorization records are immutable; revoke and add a new record instead of changing $($entry.Path).") }
            elseif ($null -eq $entry.Base) {
                $text = Get-GuardBlobText $target $headSha $entry.Path
                $name = $entry.Path.Substring($directory.Length)
                if (-not (Test-GuardJsonSchema -Schema $authorizationSchema -Json $text)) { $failures.Add("Added authorization does not match its schema: $($entry.Path)") }
                elseif ("$((ConvertFrom-Json $text -AsHashtable -Depth 50).id).json" -cne $name) { $failures.Add("Authorization file name must equal its id: $($entry.Path)") }
            }
            else { $candidates.Add([pscustomobject]@{ Path = $entry.Path; Entry = $entry; Record = $null; Covers = [Collections.Generic.List[string]]::new(); Problems = [Collections.Generic.List[string]]::new(); Status = 'rejected' }) }
            continue
        }
        if ($null -eq $entry.Head -and (Test-GuardProtectedPath $protection $entry.Path)) { $removals.Add($entry) }
    }
    foreach ($removal in $removals) { $obligations.Add([pscustomobject]@{ id = "protected-removal:$($removal.Path)"; kind = 'protected-removal'; paths = @($removal.Path); pointers = @(); change = $null; coveredBy = [Collections.Generic.List[string]]::new() }) }
    if ($tcb.Components.Count -gt 0) {
        $obligations.Add([pscustomobject]@{ id = "trusted-component-change:$($tcb.Components -join ',')"; kind = 'trusted-component-change'; paths = @($tcb.Changes | ForEach-Object { $_.Path } | Sort-Object -Unique -CaseSensitive); pointers = @(); change = $null; coveredBy = [Collections.Generic.List[string]]::new() })
    }
    # D24: with zero comparators every semantic policy or configuration change is a potential weakening, orthogonal to
    # any trusted component obligation of the same path.
    $policy = Get-GuardPolicyChanges $target $mergeBase $headSha $registry $projectionTargets $entries -HeadRegistry $candidateRegistry -HeadProjectionTargets (Get-GuardProjectionTargets $candidateAuthorities.Document)
    foreach ($path in $policy.Unregistered) { $failures.Add("Unregistered policy or configuration file: $path; register it in shared/policy-config.json or keep it outside the registry roots.") }
    foreach ($change in $policy.Changes) {
        $obligations.Add([pscustomobject]@{ id = "policy-weakening:$($change.Path)"; kind = 'policy-weakening'; paths = @($change.Path); pointers = @($change.Pointers); change = $change; coveredBy = [Collections.Generic.List[string]]::new() })
    }
    # D25: D18 blocking findings (governing-policy changes, exception widening) of the explicit head commit are
    # policy-weakening obligations on the authority file, with the blocking pointers and schema domain-authority:<id>.
    $authorityReport = Join-Path $target 'artifacts/guards/v3-ifx/trusted-base/domain-authorities-protected-changes.json'
    $authorityRun = Invoke-GuardIsolatedPwsh (Join-Path $PSScriptRoot 'Test-IFXDomainAuthorityCandidates.ps1') @('-TargetRoot', $target, '-BaseRevision', $mergeBase, '-HeadRevision', $headSha, '-ReportPath', $authorityReport)
    if (-not [IO.File]::Exists($authorityReport)) { throw "The domain authority comparison returned exit code $($authorityRun.ExitCode) without a report." }
    foreach ($authority in @((Get-Content -LiteralPath $authorityReport -Raw | ConvertFrom-Json).authorities | Where-Object { @($_.blockingPointers).Count -gt 0 })) {
        if (@($authority.findings | Where-Object { $_.change -eq 'base-missing' }).Count -gt 0) { $failures.Add("Domain authority $($authority.id) is missing at the merge base: $($authority.path)"); continue }
        $entry = @($entries | Where-Object { $_.Path -ceq [string]$authority.path })
        $change = [pscustomobject]@{
            Path = [string]$authority.path
            Schema = "domain-authority:$($authority.id)"
            Base = if ($entry.Count -eq 1) { $entry[0].Base } else { $null }
            Head = if ($entry.Count -eq 1) { $entry[0].Head } else { $null }
            BaseSha256 = $authority.baseSha256
            HeadSha256 = $authority.headSha256
            Pointers = [string[]]@($authority.blockingPointers | Sort-Object -Unique -CaseSensitive)
        }
        $obligations.Add([pscustomobject]@{ id = "policy-weakening:$($change.Path)"; kind = 'policy-weakening'; paths = @($change.Path); pointers = @($change.Pointers); change = $change; coveredBy = [Collections.Generic.List[string]]::new() })
    }

    # ---- candidates: base records deleted by head
    foreach ($candidate in $candidates) {
        $baseFile = Join-Path $baseRepository $candidate.Path
        if (-not [IO.File]::Exists($baseFile)) { $candidate.Problems.Add('the record is not in the base commit (already consumed or revoked)'); continue }
        $baseEntry = Get-GuardTreeEntry $baseRepository $BaseSha $candidate.Path
        if (-not (Test-GuardTupleEqual $baseEntry $candidate.Entry.Base)) { $candidate.Problems.Add('the base record differs from the record at the merge base'); continue }
        if (-not (Test-GuardJsonSchema -Schema $authorizationSchema -Path $baseFile)) { $candidate.Problems.Add('the base record does not match its schema'); continue }
        $candidate.Record = Get-Content -LiteralPath $baseFile -Raw | ConvertFrom-Json -AsHashtable -Depth 50
        if ("$($candidate.Record.id).json" -cne $candidate.Path.Substring($directory.Length)) { $candidate.Problems.Add('the file name does not equal the record id'); continue }
    }

    $candidatePaths = [Collections.Generic.HashSet[string]]::new([string[]]@($candidates | ForEach-Object { $_.Path }), [StringComparer]::Ordinal)
    $otherChanges = @($entries | Where-Object { -not $candidatePaths.Contains($_.Path) })
    $revocation = $candidates.Count -gt 0 -and $obligations.Count -eq 0 -and $failures.Count -eq 0 -and @($candidates | Where-Object { $_.Problems.Count -gt 0 }).Count -eq 0 -and
        @($otherChanges | Where-Object { -not $planPair.Contains($_.Path) -or $null -eq $_.Head }).Count -eq 0
    if ($revocation) {
        # D22: deleting authorizations only narrows what base allows, when nothing else changes.
        $result.revocation = $true
        foreach ($candidate in $candidates) { $candidate.Status = 'revoked' }
    }
    else {
        foreach ($candidate in @($candidates | Where-Object { $_.Problems.Count -eq 0 })) {
            $record = $candidate.Record
            $problems = @()
            switch ($record.operation) {
                'change-trusted-base' {
                    $trusted = @($obligations | Where-Object { $_.kind -eq 'trusted-component-change' })
                    $recordComponents = [string[]]@($record.components | Sort-Object -Unique -CaseSensitive)
                    if ($trusted.Count -eq 1 -and ($recordComponents -join "`n") -cne ($tcb.Components -join "`n")) { $problems = @("components $($recordComponents -join ', ') differ from the changed components $($tcb.Components -join ', ')") }
                    elseif ($trusted.Count -eq 1) {
                        $problems = @(Test-GuardTrustedBaseRecord $target $headSha $record $tcb $baseManifest $headManifest)
                        if ($problems.Count -eq 0) { $candidate.Covers.Add($trusted[0].id) }
                    }
                }
                { $_ -in $pathOperations } {
                    $source = [string]$record.source.path
                    $covered = @($obligations | Where-Object { $_.kind -eq 'protected-removal' -and (Test-Under $_.paths[0] $source) })
                    if ($covered.Count -gt 0) {
                        $problems = @(Test-PathRecord $candidate $entries $mergeBase $headSha $headPaths)
                        if ($problems.Count -eq 0) { foreach ($obligation in $covered) { $candidate.Covers.Add($obligation.id) } }
                    }
                }
                'weaken-policy' {
                    $problems = @(Test-PolicyRecord $record $obligations $headSha)
                    if ($problems.Count -eq 0) { foreach ($item in @($record.policies)) { $candidate.Covers.Add("policy-weakening:$($item.path)") } }
                }
                default { $problems = @("operation $($record.operation) is not enabled by this base; consuming it fails closed (D23)") }
            }
            foreach ($problem in $problems) { $candidate.Problems.Add($problem) }
            if ($candidate.Problems.Count -eq 0 -and $candidate.Covers.Count -eq 0) { $candidate.Problems.Add('the record covers no protected change of this pull request; an unused authorization may only be revoked on its own (D22)') }
            if ($candidate.Problems.Count -eq 0) { $candidate.Status = 'consumed' }
        }
        foreach ($candidate in @($candidates | Where-Object { $_.Status -eq 'consumed' })) {
            foreach ($id in $candidate.Covers) { @($obligations | Where-Object { $_.id -ceq $id })[0].coveredBy.Add($candidate.Path) }
        }
        foreach ($obligation in $obligations) {
            if ($obligation.coveredBy.Count -eq 0) { $failures.Add("Uncovered $($obligation.kind) needs a base authorization that this change deletes: $($obligation.paths -join ', ')") }
            elseif ($obligation.coveredBy.Count -gt 1) { $failures.Add("$($obligation.id) is covered by more than one authorization: $($obligation.coveredBy -join ', ')") }
        }
    }
    foreach ($candidate in @($candidates | Where-Object { $_.Status -eq 'rejected' })) { $failures.Add("Authorization $($candidate.Path) is rejected: $($candidate.Problems -join '; ')") }
}
catch {
    $failures.Add($_.Exception.Message)
}

$result.obligations = @($obligations | ForEach-Object { [ordered]@{ id = $_.id; kind = $_.kind; paths = @($_.paths); pointers = @($_.pointers); coveredBy = @($_.coveredBy) } })
$result.authorizations = @($candidates | ForEach-Object { [ordered]@{ path = $_.Path; id = if ($_.Record) { [string]$_.Record.id } else { $null }; operation = if ($_.Record) { [string]$_.Record.operation } else { $null }; covers = @($_.Covers); status = $_.Status } })
$result.failures = @($failures)
if ($failures.Count -eq 0) {
    $result.status = 'pass'
    $allowed = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    foreach ($candidate in $candidates) { [void]$allowed.Add($candidate.Path) }
    foreach ($obligation in @($obligations | Where-Object { $_.kind -eq 'protected-removal' })) { [void]$allowed.Add($obligation.paths[0]) }
    $result.allowedDeletions = @($allowed)
}
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($report))
[IO.File]::WriteAllText($report, ($result | ConvertTo-Json -Depth 10) + "`n", [Text.UTF8Encoding]::new($false))
if (-not (Test-GuardJsonSchema -Schema (Join-Path $packageRoot 'contracts/protected-change-report.schema.json') -Path $report)) { throw "Protected change report does not match its schema: $report" }
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "FAIL $failure" }
    Write-Host "Protected change verification failed: $report"
    exit 1
}
$state = if ($result.revocation) { "revocation of $($candidates.Count) authorization(s)" } elseif ($obligations.Count -eq 0) { 'no protected changes' } else { "$($obligations.Count) obligation(s) covered by $(@($candidates).Count) authorization(s)" }
Write-Host "Protected change verification passed ($state): $report"
