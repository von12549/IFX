$ErrorActionPreference = 'Stop'
$detector = 'ifx-g03-docs-closeout'
$claims = @('IFX.C2.G03_DOCUMENTATION','IFX.C2.G03_LEGACY_DEADLINE','IFX.C2.G03_CLOSEOUT_READINESS')
$rules = @('G03-DOCUMENTATION','G03-LEGACY-DEADLINE','G03-CLOSEOUT-READINESS')
$findings = [Collections.Generic.List[object]]::new()
$matched = @(0,0,0)
function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $coverage = for ($i = 0; $i -lt 3; $i++) { [ordered]@{ claimId = $claims[$i]; matched = $matched[$i]; minimum = 1 } }
    $result = [ordered]@{ formatVersion = 1; status = $Status; exitCategory = $Category; findings = @($findings.ToArray()); coverage = @($coverage) }
    if ($Message) { $result.message = $Message }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 50 -Compress))
}
function Stop-Adapter([string] $Category, [string] $Message) { Emit 'error' $Category $Message; exit 0 }
function Finding([int] $Index, [string] $Code, [string] $Subject) {
    $kind = @('governance-document','legacy-deadline','closeout-readiness')[$Index]
    $findings.Add([ordered]@{ ruleId = $rules[$Index]; subject = "${Code}:${Subject}"; evidenceKind = $kind; detectorId = $detector; severity = 'blocking' })
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current -and ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current))) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Stop-Adapter 'unsafe-path' 'G03 input crosses a link.' }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Resolve-Target([string] $Relative) {
    $path = [IO.Path]::GetFullPath((Join-Path $targetRoot $Relative))
    $back = [IO.Path]::GetRelativePath($targetRoot, $path).Replace('\','/')
    if ($back -eq '..' -or $back.StartsWith('../') -or [IO.Path]::IsPathFullyQualified($back)) { Stop-Adapter 'unsafe-path' "G03 input escapes TargetRoot: $Relative" }
    Assert-NoLink $path
    return $path
}
function Read-Text([string] $Relative, [string] $ExpectedHash) {
    $path = Resolve-Target $Relative
    if (-not [IO.File]::Exists($path)) { Stop-Adapter 'prerequisite-missing' "Missing G03 input: $Relative" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedHash) { Stop-Adapter 'integrity-failure' "G03 input hash drift: $Relative" }
    return [IO.File]::ReadAllText($path)
}
function Check-Links([int] $Index, [string] $Relative, [string] $Body) {
    $document = Resolve-Target $Relative
    foreach ($match in [regex]::Matches($Body, '!?' + '\[[^\]]*\]\((?<target>[^)]+)\)')) {
        $link = $match.Groups['target'].Value.Split('#')[0].Trim('<','>')
        if ([string]::IsNullOrWhiteSpace($link) -or $link -match '^(https?://|mailto:)') { continue }
        if ([IO.Path]::IsPathFullyQualified($link) -or $link -match '^[A-Za-z][A-Za-z0-9+.-]*:') { Finding $Index 'unsafe-link' $Relative; continue }
        $resolved = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($document)) $link))
        $back = [IO.Path]::GetRelativePath($targetRoot, $resolved).Replace('\','/')
        if ($back -eq '..' -or $back.StartsWith('../') -or [IO.Path]::IsPathFullyQualified($back)) { Finding $Index 'unsafe-link' "$Relative->$link"; continue }
        Assert-NoLink $resolved
        if (-not [IO.File]::Exists($resolved) -and -not [IO.Directory]::Exists($resolved)) { Finding $Index 'broken-link' "$Relative->$link" }
    }
}
function Check-Document([string] $Relative, [string] $Body) {
    foreach ($term in @('Provider Contract','Consumer Port','Integration Adapter','Composition','LayerGuard','waiver')) {
        if (-not $Body.Contains($term, [StringComparison]::Ordinal)) { Finding 0 'missing-section' "$Relative->$term" }
    }
    $block = [regex]::Match($Body, '(?s)<!-- G03-CURRENT-PROTOCOLS-START -->(.*?)<!-- G03-CURRENT-PROTOCOLS-END -->')
    if (-not $block.Success) { Finding 0 'protocol-table-missing' $Relative; return }
    $rows = @([regex]::Matches($block.Groups[1].Value, '(?m)^\|\s*`(?<identity>[^`]+)`\s*\|\s*(?<kind>sync|event)\s*\|[^|]*\|\s*(?<lifecycle>Active|Proposed|Deprecated|Retired)\s*\|') | ForEach-Object {
        "$($_.Groups['identity'].Value)|$($_.Groups['kind'].Value)|$($_.Groups['lifecycle'].Value)"
    })
    $expected = @($catalog.protocols | ForEach-Object { "$($_.identity)|$($_.kind)|$($_.lifecycle)" })
    if ($rows.Count -eq 0 -or ($rows | Sort-Object) -join "`n" -cne (($expected | Sort-Object) -join "`n")) { Finding 0 'protocol-table-drift' $Relative }
    Check-Links 0 $Relative $Body
}
function Check-Diagrams {
    foreach ($name in @($policy.diagramNames)) {
        foreach ($extension in @('mmd','svg','png')) {
            $relative = "docs/architecture/review/gates/G03/diagrams/$name.$extension"
            $path = Resolve-Target $relative
            if (-not [IO.File]::Exists($path)) { Finding 0 'missing-diagram' $relative; continue }
            if ((Get-Item -LiteralPath $path).Length -lt 100) { Finding 0 'empty-diagram' $relative; continue }
            if ($extension -eq 'svg' -and -not [IO.File]::ReadAllText($path).Contains('<svg', [StringComparison]::Ordinal)) { Finding 0 'invalid-svg' $relative }
            if ($extension -eq 'png') {
                $bytes = [IO.File]::ReadAllBytes($path)
                if ([BitConverter]::ToString($bytes[0..7]) -cne '89-50-4E-47-0D-0A-1A-0A') { Finding 0 'invalid-png' $relative }
            }
        }
    }
}
function Add-Blocker([string] $Code) { $blockers.Add($Code) }

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.' }
try { $inputObject = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'invalid-input' 'Stage input is malformed.' }
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or
    (@($inputObject.config.enabledClaims) -join '|') -cne ($claims -join '|') -or
    @($inputObject.relativeRoots) -notcontains 'docs' -or @($inputObject.relativeRoots) -notcontains 'src') { Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.' }
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
$targetRoot = [IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Directory]::Exists($targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
if ((Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256) { Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.' }
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g03-docs-closeout-c2d' -or
    (@($policy.claims | ForEach-Object claimId) -join '|') -cne ($claims -join '|')) { Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.' }
try { $catalog = (Read-Text $policy.catalogPath ([string]$inputObject.config.catalogSha256)) | ConvertFrom-Json -Depth 100 }
catch { Stop-Adapter 'invalid-input' 'G03 catalog is malformed.' }
if ($catalog -isnot [pscustomobject]) { Stop-Adapter 'invalid-input' 'G03 catalog must be an object.' }
$zh = Read-Text $policy.zhPath ([string]$inputObject.config.zhSha256)
$en = Read-Text $policy.enPath ([string]$inputObject.config.enSha256)
$closeout = Read-Text $policy.closeoutPath ([string]$inputObject.config.closeoutSha256)
$g03Plan = Read-Text $policy.g03PlanPath ([string]$inputObject.config.g03PlanSha256)
$layerPlan = Read-Text $policy.layerPlanPath ([string]$inputObject.config.layerPlanSha256)
if (@($catalog.protocols).Count -eq 0) { Finding 0 'zero-protocol' 'catalog' }
Check-Document $policy.zhPath $zh
Check-Document $policy.enPath $en
Check-Diagrams

$legacy = @($catalog.publicSurface)
if ($legacy.Count -eq 0) { Finding 1 'zero-legacy' 'catalog' }
$today = [DateOnly]::FromDateTime((Get-Date).Date)
try { $deadline = [DateOnly]::Parse([string]$catalog.sourcePolicy.legacyDeadline) }
catch { Finding 1 'invalid-deadline' 'catalog'; $deadline = $today }
foreach ($item in $legacy) {
    if ([string]::IsNullOrWhiteSpace([string]$item.disposition) -or $item.disposition -notin @('Internalize','Replace','Remove')) { Finding 1 'missing-disposition' ([string]$item.id) }
    if ($item.lifecycle -eq 'LegacyPendingMigration') {
        try {
            $expiry = [DateOnly]::Parse([string]$item.expiresAt)
            if ($expiry -gt $deadline) { Finding 1 'deadline-exceeded' ([string]$item.id) }
            if ($expiry -lt $today) { Finding 1 'overdue-legacy' ([string]$item.id) }
        } catch { Finding 1 'invalid-expiry' ([string]$item.id) }
    }
}

$handoffs = @($policy.handoffPaths)
foreach ($relative in $handoffs) {
    $path = Resolve-Target $relative
    if (-not [IO.File]::Exists($path)) { Finding 2 'missing-handoff' $relative; continue }
    Check-Links 2 $relative ([IO.File]::ReadAllText($path))
}
Check-Links 2 $policy.closeoutPath $closeout
$blockers = [Collections.Generic.List[string]]::new()
if ([string]::IsNullOrWhiteSpace([string]$catalog.approvalPolicy.backupOwner)) { Add-Blocker 'backup-owner-unassigned' }
if (@($catalog.protocols | Where-Object lifecycle -ne 'Active').Count -gt 0) { Add-Blocker 'protocols-not-active' }
if ($g03Plan -match '- \[ \] G03-6\.5' -or $g03Plan -match '- \[ \] G03-6\.6') { Add-Blocker 'behavior-tests-pending' }
foreach ($relative in @($policy.messagingProjectPaths)) {
    if (-not [IO.File]::Exists((Resolve-Target $relative))) { Add-Blocker 'messaging-contract-runtime-split-pending'; break }
}
if ($layerPlan -match '- \[ \] L5\.1') { Add-Blocker 'layerguard-direct-consumption-pending' }
if ($g03Plan -match '- \[ \] G03-9\.8') { Add-Blocker 'closure-approvals-pending' }
$expectedStatus = if ($blockers.Count -eq 0) { 'ready-for-approval' } else { 'pre-ready' }
$expectedReady = if ($blockers.Count -eq 0) { 'true' } else { 'false' }
$readinessBlock = [regex]::Match($closeout, '(?s)<!-- G03-CURRENT-READINESS-START -->(.*?)<!-- G03-CURRENT-READINESS-END -->')
if (-not $readinessBlock.Success) { Finding 2 'readiness-missing' $policy.closeoutPath }
else {
    $body = $readinessBlock.Groups[1].Value
    if ($body -notmatch "closureStatus=$([regex]::Escape($expectedStatus))\b" -or $body -notmatch "readyForClosure=$expectedReady\b") { Finding 2 'readiness-drift' $policy.closeoutPath }
    $rows = @([regex]::Matches($body, '(?m)^\|\s*`(?<code>[a-z][a-z0-9-]+)`\s*\|(?<owner>[^|]*)\|(?<revisit>[^|]*)\|') | ForEach-Object {
        [pscustomobject]@{ code = $_.Groups['code'].Value; owner = $_.Groups['owner'].Value.Trim(); revisit = $_.Groups['revisit'].Value.Trim() }
    })
    if (($rows.code | Sort-Object) -join '|' -cne (($blockers.ToArray() | Sort-Object) -join '|')) { Finding 2 'blocker-set-drift' $policy.closeoutPath }
    foreach ($row in $rows) { if ([string]::IsNullOrWhiteSpace($row.owner) -or [string]::IsNullOrWhiteSpace($row.revisit)) { Finding 2 'blocker-metadata' $row.code } }
}
for ($i = 0; $i -lt 3; $i++) {
    if (@($findings | Where-Object ruleId -eq $rules[$i]).Count -eq 0) { $matched[$i] = @(2, $legacy.Count, 1)[$i] }
}
Emit $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' }) $(if ($findings.Count -eq 0) { 'success' } else { 'findings-blocking' })
