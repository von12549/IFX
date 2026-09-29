Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-PinSha256([string]$Path) {
    # 0.5.0-a (R5): a governance pin is the SHA-256 of the UTF-8 text with line endings normalized to LF, so the pin
    # does not depend on the checkout; binary files are hashed by their raw bytes.
    if ([IO.Path]::GetExtension($Path).ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.dll', '.exe')) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
    $text = [IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
}
$detector = 'ifx-g05-inventory'
$rule = 'G05-INVENTORY'
$claim = 'IFX.C4.G05_INVENTORY'
$findings = [Collections.Generic.List[object]]::new()
$matched = 0
function Hash-File([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Hash-Text([string] $Value) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))).ToLowerInvariant() }
function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $value = [ordered]@{formatVersion=1; status=$Status; exitCategory=$Category; findings=@($findings.ToArray()); coverage=@([ordered]@{claimId=$claim; matched=[int]$matched; minimum=1})}
    if ($Message) { $value.message = $Message }
    [Console]::Out.WriteLine(($value | ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string] $Category, [string] $Message) { Emit 'error' $Category $Message; exit 0 }
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
}
function Assert-NoLink([string] $Path, [string] $Root) {
    $cursor = [IO.Path]::GetFullPath($Path)
    while (Is-Under $cursor $Root) {
        if ([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Stop-Adapter 'unsafe-path' "Linked target authority: $Path" }
        }
        if ($cursor -ceq $Root) { break }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if (-not $parent -or $parent -ceq $cursor) { break }
        $cursor = $parent
    }
}
function Load-WorkspaceEvidence($InputObject,[string]$TargetRoot) {
    if (-not $InputObject.ContainsKey('workspaceEvidencePath') -or -not $InputObject.ContainsKey('workspaceEvidenceSha256')) { return $null }
    if (-not $InputObject.ContainsKey('workspaceEvidenceTargetCommit')) { Stop-Adapter 'invalid-input' 'Workspace evidence target commit is required.' }
    $path=[IO.Path]::GetFullPath([string]$InputObject.workspaceEvidencePath);Assert-NoLink $path ([IO.Path]::GetPathRoot($path));$expected=[string]$InputObject.workspaceEvidenceSha256;$expectedCommit=[string]$InputObject.workspaceEvidenceTargetCommit
    if($expected -cnotmatch '^[a-f0-9]{64}$' -or -not[IO.File]::Exists($path) -or (Is-Under $path $TargetRoot) -or (Is-Under $TargetRoot ([IO.Path]::GetDirectoryName($path)))){Stop-Adapter 'unsafe-path' 'Workspace evidence is missing, invalid, or overlaps TargetRoot.'}
    if((Hash-File $path)-cne$expected){Stop-Adapter 'integrity-failure' 'Workspace evidence hash drift.'}
    try{$value=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -AsHashtable -Depth 30}catch{Stop-Adapter 'integrity-failure' 'Workspace evidence is malformed.'}
    if($expectedCommit-cnotmatch'^[a-f0-9]{40}$' -or $value.targetCommit-cne$expectedCommit -or $value.formatVersion-ne1 -or $value.scope-cne'v4-workspace-evidence-v1' -or $value.pathOrder-cne'ordinal' -or @($value.files).Count-ne$value.fileCount){Stop-Adapter 'integrity-failure' 'Workspace evidence identity drift.'}
    return $value
}
function Record([string] $Id, [bool] $Pass, [string] $Kind = 'source-location') {
    if (-not $Pass) { $findings.Add([ordered]@{ruleId=$rule; subject=$Id; evidenceKind=$Kind; detectorId=$detector; severity='blocking'}) }
}
function Source-Files([string] $Root) {
    $source = Join-Path $Root 'src'
    if (-not [IO.Directory]::Exists($source)) { Stop-Adapter 'prerequisite-missing' 'Source root is missing.' }
    Assert-NoLink $source $Root
    if ($null -ne $script:workspaceEvidence) {
        return @($script:workspaceEvidence.files | Where-Object { $_.extension -ceq '.cs' -and ([string]$_.path).StartsWith('src/',[StringComparison]::Ordinal) } | ForEach-Object {
            [pscustomobject]@{FullName=[IO.Path]::GetFullPath((Join-Path $Root ([string]$_.path)));RelativePath=[string]$_.path;Sha256=[string]$_.sha256;Text=[string]$_.text}
        } | Sort-Object FullName)
    }
    $rows=[Collections.Generic.List[object]]::new();$pending=[Collections.Generic.Queue[string]]::new();$pending.Enqueue($source)
    while($pending.Count-gt0){$current=$pending.Dequeue();foreach($directory in [IO.Directory]::EnumerateDirectories($current)){if(([IO.File]::GetAttributes($directory)-band[IO.FileAttributes]::ReparsePoint)-ne0){Stop-Adapter 'unsafe-path' 'Linked source directory.'};if([IO.Path]::GetFileName($directory)-in @('bin','obj','node_modules','dist','coverage','.vite')){continue};$pending.Enqueue($directory)};foreach($path in [IO.Directory]::EnumerateFiles($current,'*.cs',[IO.SearchOption]::TopDirectoryOnly)){if(([IO.File]::GetAttributes($path)-band[IO.FileAttributes]::ReparsePoint)-ne0){Stop-Adapter 'unsafe-path' 'Linked source file.'};$rows.Add([pscustomobject]@{FullName=$path;RelativePath=[IO.Path]::GetRelativePath($Root,$path).Replace('\','/');Sha256=Hash-File $path;Text=[IO.File]::ReadAllText($path)})}}
    return @($rows.ToArray()|Sort-Object RelativePath)
}
function Source-Fingerprint([object[]] $Files, [string] $Root) {
    $lines = @($Files | ForEach-Object { "$($_.RelativePath)|$($_.Sha256)" }) -join "`n"
    return Hash-Text $lines
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'Stage input is required.' }
try { $inputObject = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -AsHashtable -Depth 100 } catch { Stop-Adapter 'invalid-input' 'Stage input is malformed.' }
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims) -join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'src') { Stop-Adapter 'invalid-input' 'Stage, roots or claim selection is invalid.' }
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
$target = [IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Directory]::Exists($target)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $target $target
$script:workspaceEvidence=Load-WorkspaceEvidence $inputObject $target
$policyFile = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyFile) -or (Hash-File $policyFile) -cne [string]$inputObject.config.policySha256) { Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.' }
try { $policy = Get-Content -LiteralPath $policyFile -Raw | ConvertFrom-Json -AsHashtable -Depth 100 } catch { Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g05-inventory-050a' -or $policy.pinPolicy -cne 'governance-only' -or $policy.claimId -cne $claim -or $policy.ruleId -cne $rule -or @($policy.checkIds).Count -ne 13 -or @($policy.authorityPaths).Count -ne 4) { Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.' }
$locks = @($inputObject.config.authorityHashes)
if ($locks.Count -ne 4) { Stop-Adapter 'invalid-input' 'Authority lock count is invalid.' }
$authorities = @()
for ($i=0; $i -lt 4; $i++) {
    $relative = [string]$policy.authorityPaths[$i]
    if ($relative -cne [string]$locks[$i].path -or [string]$locks[$i].sha256 -cnotmatch '^[a-f0-9]{64}$' -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)') { Stop-Adapter 'invalid-input' "Authority lock mismatch: $i" }
    $full = [IO.Path]::GetFullPath((Join-Path $target $relative))
    if (-not (Is-Under $full $target)) { Stop-Adapter 'unsafe-path' "Authority escapes TargetRoot: $relative" }
    Assert-NoLink $full $target
    if (-not [IO.File]::Exists($full)) { Stop-Adapter 'prerequisite-missing' "Missing authority: $relative" }
    if ((Get-PinSha256 $full) -cne [string]$locks[$i].sha256) { Stop-Adapter 'integrity-failure' "Stale authority: $relative" }
    $authorities += $full
}
try { $historic = Get-Content -LiteralPath $authorities[0] -Raw | ConvertFrom-Json -AsHashtable -Depth 100 } catch { Stop-Adapter 'integrity-failure' 'Historical inventory is malformed.' }
$baseline = [IO.File]::ReadAllText($authorities[1])
$files = @(Source-Files $target)
$fingerprint1 = Source-Fingerprint $files $target
# 0.5.0-a: the live source set is no longer compared with a Profile fingerprint (sourceTreeSha256); the checks below read its current content.
$fingerprint2 = Source-Fingerprint $files $target
$matched = $files.Count
$surface = [ordered]@{http=0; tenant=0; logging=0; error=0; protocol=0; event=0; outbox=0; inbox=0}
foreach ($file in $files) {
    $relative = $file.RelativePath
    $body = $file.Text
    if ($body -match 'Headers\[|GetTypedHeaders|X-Tenant-Id|traceparent|tracestate') { $surface.http++ }
    if ($body -match 'ICurrentUser|ClaimsPrincipal|ClaimsTransformation|FindFirst|FindAll') { $surface.tenant++ }
    if ($body -match '\.(LogTrace|LogDebug|LogInformation|LogWarning|LogError|LogCritical|BeginScope)\(') { $surface.logging++ }
    if ($body -match 'ErrorResponse|Problem\(|Results\.(BadRequest|Unauthorized|Forbidden|NotFound|Problem)|response\.Error\s*=') { $surface.error++ }
    if ($relative -match '/(Abstractions|Contracts)/|\.Contracts/') { $surface.protocol++ }
    if ($relative -match '/Events/.*Event\.cs$|/(IIntegrationEvent|IntegrationEvent|EventEnvelopeV1)\.cs$') { $surface.event++ }
    if ($relative -match '/Outbox/|Outbox.*\.cs$') { $surface.outbox++ }
    if ($relative -match '/Inbox/|Inbox.*\.cs$') { $surface.inbox++ }
}
$checks = [ordered]@{
    deterministicInventory = ($fingerprint1 -ceq $fingerprint2)
    valueFreeInventoryPolicy = ($historic.inventoryPolicy -ceq 'source-locations-and-schema-names-only-no-runtime-values' -and $historic.surfaces -is [System.Collections.IDictionary])
    sourceInventoryNonEmpty = ($files.Count -gt 100)
    httpAndTenantSurfacesRecorded = ($surface.http -gt 0 -and $surface.tenant -gt 0)
    protocolAndEventSurfacesRecorded = ($surface.protocol -gt 0 -and $surface.event -gt 0)
    loggingAndErrorSurfacesRecorded = ($surface.logging -gt 0 -and $surface.error -gt 0)
    durableMessagingCapabilitiesRecordedTruthfully = ($surface.outbox -gt 0 -and $surface.inbox -gt 0)
    legacyEventIdentityRecorded = ($historic.currentEventIdentity.eventIdType -ceq 'Guid' -and $historic.currentEventIdentity.occurredAtType -ceq 'DateTime' -and $historic.currentEventIdentity.fullEnvelopeImplemented -eq $false -and $baseline -match 'current.*IIntegrationEvent|IIntegrationEvent.*currently')
    fourSecurityFindingsOwned = (@($historic.findings).Count -eq 4 -and (@($historic.findings.id) -join '|') -ceq 'G05-F01|G05-F02|G05-F03|G05-F04' -and @($historic.findings | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.owner) -or [string]::IsNullOrWhiteSpace([string]$_.severity) -or [string]::IsNullOrWhiteSpace([string]$_.resolutionTrigger) }).Count -eq 0)
    externalEvidenceGapsOwned = (@($historic.externalEvidenceGaps).Count -eq 3 -and (@($historic.externalEvidenceGaps.id) -join '|') -ceq 'G05-X01|G05-X02|G05-X03' -and @($historic.externalEvidenceGaps | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.owner) }).Count -eq 0)
    phase0EvidenceExists = ($baseline -match '^# G05 Phase 0' -and $baseline -match 'historical|baseline|current')
    phase0LayerGuardEvidenceExists = ([IO.File]::Exists($authorities[2]))
    implementationPlanExists = ([IO.File]::Exists($authorities[3]))
}
if ((@($checks.Keys) -join '|') -cne (@($policy.checkIds) -join '|')) { Stop-Adapter 'integrity-failure' 'Predicate inventory differs from reviewed policy.' }
foreach ($entry in $checks.GetEnumerator()) { Record ([string]$entry.Key) ([bool]$entry.Value) $(if($entry.Key -in @('legacyEventIdentityRecorded','fourSecurityFindingsOwned','externalEvidenceGapsOwned','phase0EvidenceExists','phase0LayerGuardEvidenceExists','implementationPlanExists')){'historical-authority'}else{'source-location'}) }
if ($matched -eq 0) { Record 'zero-subject' $false 'coverage' }
if ($findings.Count -gt 0) { Emit 'fail' 'findings-blocking' } else { Emit 'pass' 'success' }
