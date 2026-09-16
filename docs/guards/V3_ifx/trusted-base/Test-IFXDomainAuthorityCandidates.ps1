[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $TargetRoot,
    [string] $BaseRepository,
    [string] $ReportPath = 'artifacts/guards/v3-ifx/trusted-base/domain-authorities.json'
)

# Plan 06 §12.6 (D18): compare head candidate domain authorities with base by registered role.
#  - target-declaration, derived-projection and evidence content may change (their gates validate it);
#  - governing-policy content must stay equal, except fields that arrive or leave with a whole declared element;
#  - exception-authorization content may only shrink.
# No monotonicity comparator exists yet (D13 zero-comparator start) and weaken-policy authorization arrives in P4,
# so every other change fails closed.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'TrustedBase.psm1') -Force
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$base = if ($BaseRepository) { Get-GuardFullPath $BaseRepository } else { Get-GuardFullPath (Join-Path $packageRoot '../../..') }
$target = Get-GuardFullPath $TargetRoot
$report = if ([IO.Path]::IsPathRooted($ReportPath)) { [IO.Path]::GetFullPath($ReportPath) } else { [IO.Path]::GetFullPath((Join-Path $target $ReportPath)) }
if (-not (Test-GuardPathWithin $report $target)) { throw 'ReportPath must stay under TargetRoot.' }
$registry = Get-Content -LiteralPath (Join-Path $packageRoot 'policy/authorities.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100

$script:Absent = [object]::new()
$script:findings = $null
$script:templates = $null
$script:arrayKeys = $null
$script:defaultRole = $null

function Test-Absent([object] $Value) { return [object]::ReferenceEquals($Value, $script:Absent) }
function Test-List([object] $Value) { return ($Value -is [Collections.IList]) -and ($Value -isnot [string]) }
function Test-Empty([object] $Value) {
    if ((Test-Absent $Value) -or $null -eq $Value) { return $true }
    if ($Value -is [Collections.IDictionary]) { return $Value.Count -eq 0 }
    if (Test-List $Value) { return $Value.Count -eq 0 }
    return $false
}
function Get-Canonical([object] $Value) { if (Test-Absent $Value) { return '<absent>' }; return ConvertTo-GuardCanonicalJson $Value }
function Format-Pointer([string[]] $Segments) {
    if ($Segments.Count -eq 0) { return '' }
    return '/' + (($Segments | ForEach-Object { $_.Replace('~', '~0').Replace('/', '~1') }) -join '/')
}

function Get-RoleAt([string[]] $Segments) {
    $role = $script:defaultRole
    $bestLength = -1
    $bestWildcards = [int]::MaxValue
    foreach ($template in $script:templates) {
        if (-not (Test-GuardTemplatePrefix $template.Segments $Segments)) { continue }
        $wildcards = @($template.Segments | Where-Object { $_ -eq '*' }).Count
        if ($template.Segments.Count -gt $bestLength -or ($template.Segments.Count -eq $bestLength -and $wildcards -lt $bestWildcards)) {
            $role = $template.Role; $bestLength = $template.Segments.Count; $bestWildcards = $wildcards
        }
    }
    return $role
}

function Test-Uniform([string[]] $Segments) {
    # A node is uniform when no role template reaches strictly below it.
    foreach ($template in $script:templates) {
        if ($template.Segments.Count -le $Segments.Count) { continue }
        if (Test-GuardTemplatePrefix ([string[]]@($template.Segments | Select-Object -First $Segments.Count)) $Segments) { return $false }
    }
    return $true
}

function Get-ArrayKey([string[]] $Segments) {
    foreach ($entry in $script:arrayKeys) {
        if ($entry.Segments.Count -eq $Segments.Count -and (Test-GuardTemplatePrefix $entry.Segments $Segments)) { return $entry.Key }
    }
    return $null
}

function Add-Finding([string] $Pointer, [string] $Role, [string] $Change, [bool] $Blocking, [string] $Message) {
    $script:findings.Add([ordered]@{ pointer = $Pointer; role = $Role; change = $Change; blocking = $Blocking; message = $Message })
}

function Test-Subset([object] $Head, [object] $Base) {
    if ((Get-Canonical $Head) -ceq (Get-Canonical $Base)) { return $true }
    if ((Test-List $Head) -and (Test-List $Base)) {
        $baseItems = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($item in $Base) { [void]$baseItems.Add((Get-Canonical $item)) }
        foreach ($item in $Head) { if (-not $baseItems.Contains((Get-Canonical $item))) { return $false } }
        return $true
    }
    if ($Head -is [Collections.IDictionary] -and $Base -is [Collections.IDictionary]) {
        foreach ($key in $Head.Keys) { if (-not $Base.Contains($key) -or -not (Test-Subset $Head[$key] $Base[$key])) { return $false } }
        foreach ($key in $Base.Keys) {
            # Dropping a whole collection narrows the exception; dropping a scalar changes its meaning.
            if (-not $Head.Contains($key) -and -not ((Test-List $Base[$key]) -or $Base[$key] -is [Collections.IDictionary])) { return $false }
        }
        return $true
    }
    return $false
}

function Test-Node([string] $Role, [object] $Base, [object] $Head, [string[]] $Segments, [string] $Context) {
    $pointer = Format-Pointer $Segments
    if ((Get-Canonical $Base) -ceq (Get-Canonical $Head)) { return }
    switch ($Role) {
        'governing-policy' {
            if ($Context -eq 'added') { Add-Finding $pointer $Role 'declared-with-new-element' $false 'Governing field arrives with a newly declared element.'; break }
            if ($Context -eq 'removed') { Add-Finding $pointer $Role 'removed-with-element' $false 'Governing field leaves with a removed element.'; break }
            Add-Finding $pointer $Role 'governing-policy-change' $true 'Governing policy changed; no comparator proves it tightening or equivalent, and weaken-policy authorization is unavailable before Plan 06 P4.'
        }
        'exception-authorization' {
            if ($Context -eq 'removed' -or (Test-Absent $Head)) { Add-Finding $pointer $Role 'exception-removed' $false 'Exception removed.'; break }
            if ($Context -eq 'added' -or (Test-Absent $Base)) {
                if (Test-Empty $Head) { break }
                Add-Finding $pointer $Role 'exception-expansion' $true 'New exception content requires weaken-policy authorization, which is unavailable before Plan 06 P4.'
                break
            }
            if (Test-Subset $Head $Base) { Add-Finding $pointer $Role 'exception-narrowed' $false 'Exception content only shrank.'; break }
            Add-Finding $pointer $Role 'exception-expansion' $true 'Exception content added or changed; requires weaken-policy authorization, which is unavailable before Plan 06 P4.'
        }
        default { Add-Finding $pointer $Role 'content-change' $false "Content with role $Role changed; the gate that consumes it validates the candidate." }
    }
}

function Test-Tree([object] $Base, [object] $Head, [string[]] $Segments, [string] $Context) {
    $role = Get-RoleAt $Segments
    if ((Test-Uniform $Segments) -or (Get-Canonical $Base) -ceq (Get-Canonical $Head)) { Test-Node $role $Base $Head $Segments $Context; return }
    $baseIsMap = $Base -is [Collections.IDictionary]
    $headIsMap = $Head -is [Collections.IDictionary]
    $baseIsList = Test-List $Base
    $headIsList = Test-List $Head
    if (($baseIsMap -or (Test-Absent $Base)) -and ($headIsMap -or (Test-Absent $Head)) -and ($baseIsMap -or $headIsMap)) {
        $keys = [Collections.Generic.List[string]]::new()
        if ($baseIsMap) { foreach ($key in $Base.Keys) { $keys.Add($key) } }
        if ($headIsMap) { foreach ($key in $Head.Keys) { if (-not $keys.Contains($key)) { $keys.Add($key) } } }
        foreach ($key in $keys) {
            # The leading commas stop PowerShell from unrolling list values.
            $baseChild = if ($baseIsMap -and $Base.Contains($key)) { , $Base[$key] } else { $script:Absent }
            $headChild = if ($headIsMap -and $Head.Contains($key)) { , $Head[$key] } else { $script:Absent }
            Test-Tree $baseChild $headChild ([string[]]@($Segments + $key)) $Context
        }
        return
    }
    if (($baseIsList -or (Test-Absent $Base)) -and ($headIsList -or (Test-Absent $Head)) -and ($baseIsList -or $headIsList)) {
        [object[]] $baseItems = @(if ($baseIsList) { $Base })
        [object[]] $headItems = @(if ($headIsList) { $Head })
        $key = Get-ArrayKey $Segments
        if ($key) {
            $baseById = [ordered]@{}
            $headById = [ordered]@{}
            foreach ($pair in @(@($baseItems, $baseById), @($headItems, $headById))) {
                foreach ($item in $pair[0]) {
                    if ($item -isnot [Collections.IDictionary] -or -not $item.Contains($key) -or $item[$key] -isnot [string] -or $pair[1].Contains($item[$key])) {
                        Add-Finding (Format-Pointer $Segments) $role 'identity-invalid' $true "Array elements must have a unique string '$key'."
                        return
                    }
                    $pair[1][$item[$key]] = $item
                }
            }
            $ids = [Collections.Generic.List[string]]::new()
            foreach ($id in $baseById.Keys) { $ids.Add($id) }
            foreach ($id in $headById.Keys) { if (-not $ids.Contains($id)) { $ids.Add($id) } }
            foreach ($id in $ids) {
                $inBase = $baseById.Contains($id); $inHead = $headById.Contains($id)
                $childContext = if ($Context -ne 'common') { $Context } elseif ($inBase -and $inHead) { 'common' } elseif ($inHead) { 'added' } else { 'removed' }
                $baseChild = if ($inBase) { , $baseById[$id] } else { $script:Absent }
                $headChild = if ($inHead) { , $headById[$id] } else { $script:Absent }
                Test-Tree $baseChild $headChild ([string[]]@($Segments + $id)) $childContext
            }
            return
        }
        # Without a declared identity key elements are compared by position, so insertions fail closed on governed fields.
        $count = [Math]::Max($baseItems.Count, $headItems.Count)
        for ($i = 0; $i -lt $count; $i++) {
            $inBase = $i -lt $baseItems.Count; $inHead = $i -lt $headItems.Count
            $childContext = if ($Context -ne 'common') { $Context } elseif ($inBase -and $inHead) { 'common' } elseif ($inHead) { 'added' } else { 'removed' }
            $baseChild = if ($inBase) { , $baseItems[$i] } else { $script:Absent }
            $headChild = if ($inHead) { , $headItems[$i] } else { $script:Absent }
            Test-Tree $baseChild $headChild ([string[]]@($Segments + [string]$i)) $childContext
        }
        return
    }
    # A structural type change above governed fields cannot be compared field by field.
    Add-Finding (Format-Pointer $Segments) $role 'structure-change' $true 'The structure above role-governed fields changed; requires weaken-policy authorization, which is unavailable before Plan 06 P4.'
}

$results = [Collections.Generic.List[object]]::new()
foreach ($authority in @($registry.domainAuthorities)) {
    $script:findings = [Collections.Generic.List[object]]::new()
    $script:defaultRole = $authority.defaultRole
    $script:templates = @(@($(if ($authority.ContainsKey('pointerRoles')) { $authority.pointerRoles } else { @() })) | ForEach-Object { [pscustomobject]@{ Segments = (Split-GuardPointer $_.pointer); Role = $_.role } })
    $script:arrayKeys = @(@($(if ($authority.ContainsKey('arrayKeys')) { $authority.arrayKeys } else { @() })) | ForEach-Object { [pscustomobject]@{ Segments = (Split-GuardPointer $_.pointer); Key = $_.key } })
    $baseFile = Join-Path $base $authority.path
    $headFile = Join-Path $target $authority.path
    $status = 'unchanged'
    if (-not [IO.File]::Exists($baseFile)) {
        Add-Finding '' $authority.defaultRole 'base-missing' $true 'The base registry names an authority that base does not contain.'
    }
    elseif (-not [IO.File]::Exists($headFile)) {
        $governed = $authority.defaultRole -in @('governing-policy', 'exception-authorization') -or @($script:templates | Where-Object { $_.Role -in @('governing-policy', 'exception-authorization') }).Count -gt 0
        Add-Finding '' $authority.defaultRole 'authority-removed' $governed 'The head candidate removes the authority file.'
    }
    else {
        $baseText = [IO.File]::ReadAllText($baseFile).Replace("`r`n", "`n")
        $headText = [IO.File]::ReadAllText($headFile).Replace("`r`n", "`n")
        if ($baseText -cne $headText) {
            try { $baseDocument = ConvertFrom-GuardJsonText $baseText; $headDocument = ConvertFrom-GuardJsonText $headText }
            catch { $baseDocument = $null; $headDocument = $null; Add-Finding '' $authority.defaultRole 'invalid-json' $true "Authority is not valid JSON: $($_.Exception.Message)" }
            if ($null -ne $baseDocument -and $null -ne $headDocument) { Test-Tree $baseDocument $headDocument ([string[]]@()) 'common' }
            $status = 'changed'
        }
    }
    $blocking = @($script:findings | Where-Object { $_.blocking })
    if ($blocking.Count -gt 0) { $status = 'fail' }
    $results.Add([ordered]@{ id = $authority.id; path = $authority.path; status = $status; findings = @($script:findings) })
}

$failed = @($results | Where-Object { $_.status -eq 'fail' })
$summary = [ordered]@{
    formatVersion = 1
    check = 'domain-authority-candidates'
    status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    baseRepository = $base
    targetRoot = $target
    authorities = @($results)
}
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($report))
[IO.File]::WriteAllText($report, ($summary | ConvertTo-Json -Depth 20) + "`n", [Text.UTF8Encoding]::new($false))
if ($failed.Count -gt 0) {
    foreach ($authority in $failed) {
        foreach ($finding in @($authority.findings | Where-Object { $_.blocking })) { Write-Host "FAIL $($authority.id)$($finding.pointer) [$($finding.role)] $($finding.change): $($finding.message)" }
    }
    Write-Host "Domain authority candidates failed: $report"
    exit 1
}
Write-Host "Domain authority candidates passed ($(@($results | Where-Object status -eq 'changed').Count) changed): $report"
