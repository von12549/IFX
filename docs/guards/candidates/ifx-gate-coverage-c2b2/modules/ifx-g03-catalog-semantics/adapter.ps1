$ErrorActionPreference = 'Stop'
$detector = 'ifx-g03-catalog-semantics'
$claims = @('IFX.C2.G03_PROTOCOL_LIFECYCLE','IFX.C2.G03_FIELD_GOVERNANCE','IFX.C2.G03_LEGACY_SURFACE','IFX.C2.G03_CHANGE_CONTROL')
$rules = @{ protocol = 'G03-PROTOCOL-LIFECYCLE'; field = 'G03-FIELD-GOVERNANCE'; legacy = 'G03-LEGACY-SURFACE'; change = 'G03-CHANGE-CONTROL' }
$matched = @(0,0,0,0)
$findings = [Collections.Generic.List[object]]::new()
function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $coverage = for ($i = 0; $i -lt $claims.Count; $i++) { [ordered]@{ claimId = $claims[$i]; matched = $matched[$i]; minimum = 1 } }
    $result = [ordered]@{ formatVersion = 1; status = $Status; exitCategory = $Category; findings = @($findings.ToArray()); coverage = @($coverage) }
    if ($Message) { $result.message = $Message }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string] $Category, [string] $Message) { Emit 'error' $Category $Message; exit 0 }
function Add-Finding([string] $Group, [string] $Code, [string] $Path, [string] $Kind = 'catalog-semantics') {
    $findings.Add([ordered]@{ ruleId = $rules[$Group]; subject = "${Code}:${Path}"; evidenceKind = $Kind; detectorId = $detector; severity = 'blocking' })
}
function Require-Unique($Items, [string] $Key, [string] $Path, [string] $Group) {
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in @($Items | Where-Object { $null -ne $_ })) {
        $id = [string]$item.$Key
        if ([string]::IsNullOrWhiteSpace($id)) { Add-Finding $Group 'missing-id' $Path; continue }
        if (-not $seen.Add($id)) { Add-Finding $Group 'duplicate-id' "$Path.$id" }
    }
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current -and ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current))) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Stop-Adapter 'unsafe-path' 'Catalog path crosses a link.' }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Parse-Date([string] $Text, [string] $Path, [string] $Group) {
    $date = [DateOnly]::MinValue
    if (-not [DateOnly]::TryParse($Text, [ref]$date)) { Add-Finding $Group 'invalid-date' $Path }
    return $date
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.' }
try { $inputObject = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or
    (@($inputObject.config.enabledClaims) -join '|') -cne ($claims -join '|') -or
    @($inputObject.relativeRoots) -notcontains 'docs') { Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.' }
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
$targetRoot = [IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Directory]::Exists($targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
if ((Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256) { Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.' }
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g03-catalog-semantics-c2b2' -or
    (@($policy.claims | ForEach-Object claimId) -join '|') -cne ($claims -join '|') -or
    $policy.catalogPath -cne 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') { Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.' }
$catalogPath = [IO.Path]::GetFullPath((Join-Path $targetRoot $policy.catalogPath))
if (-not $catalogPath.StartsWith($targetRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { Stop-Adapter 'integrity-failure' 'Catalog path escapes TargetRoot.' }
Assert-NoLink $catalogPath
if (-not [IO.File]::Exists($catalogPath)) { Stop-Adapter 'prerequisite-missing' 'G03 catalog is missing.' }
if ((Get-FileHash -LiteralPath $catalogPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.catalogSha256) { Stop-Adapter 'integrity-failure' 'G03 catalog hash drift.' }
try { $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -Depth 100 }
catch { Stop-Adapter 'invalid-input' 'G03 catalog must be JSON-compatible YAML.' }
if ($catalog -isnot [pscustomobject]) { Stop-Adapter 'invalid-input' 'G03 catalog must be an object.' }

if ($catalog.formatVersion -ne 1) { Add-Finding protocol 'format-version' 'formatVersion' }
if ($catalog.mode -notin @('baseline','migration','strict')) { Add-Finding protocol 'mode' 'mode' }
foreach ($key in @('identity','compatibility','dtoPolicy','breakingChange','baseline','deprecation')) {
    if ($null -eq $catalog.sourcePolicy.$key) { Add-Finding protocol 'policy-node' "sourcePolicy.$key" }
}
foreach ($key in @('sourcePolicy','owners','modules','consumers','approvalPolicy','protocols','publicSurface','fieldGovernance','fieldSurfaces','fieldExceptions','sensitiveUsePolicies','migrationRecommendations','eventMinimizationReviews','changeRecords','infrastructureProtocols')) {
    if ($null -eq $catalog.$key) { Add-Finding protocol 'required-node' $key }
}
if ($null -eq $catalog.sourcePolicy -or $null -eq $catalog.approvalPolicy -or $null -eq $catalog.fieldGovernance) {
    Emit 'fail' 'findings-blocking'; exit 0
}
$owners = @($catalog.owners | Where-Object { $null -ne $_ }); $modules = @($catalog.modules | Where-Object { $null -ne $_ })
$consumers = @($catalog.consumers | Where-Object { $null -ne $_ }); $protocols = @($catalog.protocols | Where-Object { $null -ne $_ })
$infrastructure = @($catalog.infrastructureProtocols | Where-Object { $null -ne $_ })
$surfaces = @($catalog.publicSurface | Where-Object { $null -ne $_ }); $fieldSurfaces = @($catalog.fieldSurfaces | Where-Object { $null -ne $_ })
$exceptions = @($catalog.fieldExceptions | Where-Object { $null -ne $_ }); $sensitive = @($catalog.sensitiveUsePolicies | Where-Object { $null -ne $_ })
$changes = @($catalog.changeRecords | Where-Object { $null -ne $_ })
$ownerIds = @($owners | ForEach-Object id); $moduleIds = @($modules | ForEach-Object id); $consumerIds = @($consumers | ForEach-Object id)
$protocolIds = @($protocols | ForEach-Object identity)
if ($protocols.Count -eq 0) { Add-Finding protocol 'zero-protocol' 'protocols' 'coverage' } else { $matched[0] = 1 }
if ($surfaces.Count -eq 0) { Add-Finding legacy 'zero-public-surface' 'publicSurface' 'coverage' } else { $matched[2] = 1 }
if ($changes.Count -eq 0) { Add-Finding change 'zero-change-record' 'changeRecords' 'coverage' } else { $matched[3] = 1 }
if ($fieldSurfaces.Count -eq 0 -or $sensitive.Count -eq 0) { Add-Finding field 'zero-field-governance' 'fieldSurfaces/sensitiveUsePolicies' 'coverage' }
else { $matched[1] = 1 }
Require-Unique $surfaces 'id' 'publicSurface' 'legacy'
Require-Unique $fieldSurfaces 'id' 'fieldSurfaces' 'field'
Require-Unique $exceptions 'id' 'fieldExceptions' 'field'
Require-Unique $changes 'id' 'changeRecords' 'change'

foreach ($changeClass in @('New','Compatible','Conditional','Breaking','SharedPrimitiveOrEnvelope','Deprecated','Retired')) {
    if (@($catalog.approvalPolicy.reviewers.$changeClass).Count -eq 0) { Add-Finding protocol 'reviewer-policy' "approvalPolicy.reviewers.$changeClass" }
}
if ([string]::IsNullOrWhiteSpace($catalog.approvalPolicy.externalConfirmation) -or [string]::IsNullOrWhiteSpace($catalog.approvalPolicy.emergency)) { Add-Finding protocol 'approval-policy' 'approvalPolicy' }
foreach ($protocol in $protocols) {
    $path = "protocols.$($protocol.identity)"
    if ($protocol.identity -cnotmatch '^[a-z][a-z0-9.-]+\.v[1-9][0-9]*$') { Add-Finding protocol 'identity-format' "$path.identity" }
    if ($protocol.lifecycle -notin @('Proposed','Active','Deprecated','Retired')) { Add-Finding protocol 'lifecycle' "$path.lifecycle" }
    foreach ($key in @('businessUse','executionScope','authorization','freshness')) {
        if ([string]::IsNullOrWhiteSpace($protocol.$key)) { Add-Finding protocol 'protocol-metadata' "$path.$key" }
    }
    if (@($protocol.failureSemantics).Count -eq 0 -or @($protocol.tests).Count -eq 0) { Add-Finding protocol 'protocol-evidence' $path }
    if ($protocol.lifecycle -eq 'Active') {
        foreach ($key in @('source','apiOrSchemaSnapshot','providerContractTests','consumerCompatibilityTests','providerApproval','consumerApprovals')) {
            if (@($protocol.admissionEvidence.$key).Count -eq 0) { Add-Finding protocol 'active-admission' "$path.admissionEvidence.$key" }
        }
    }
    if (@($protocol.fields).Count -eq 0) { Add-Finding field 'field-surface-empty' "$path.fields" }
    foreach ($field in @($protocol.fields)) {
        $fieldPath = "$path.fields.$($field.name)"
        if ($field.classification -notin @('C0','C1','C2','C3','C4')) { Add-Finding field 'field-classification' $fieldPath }
        if ($field.classification -eq 'C4') { Add-Finding field 'secret-forbidden' $fieldPath }
        foreach ($key in @('purpose','retention','logPolicy')) { if ([string]::IsNullOrWhiteSpace($field.$key)) { Add-Finding field 'field-metadata' "$fieldPath.$key" } }
        if ($field.classification -eq 'C3' -and [string]::IsNullOrWhiteSpace($field.exceptionRef)) { Add-Finding field 'field-exception' "$fieldPath.exceptionRef" }
    }
}
foreach ($protocol in $infrastructure) {
    $path = "infrastructureProtocols.$($protocol.identity)"
    if ($protocol.provider -notin $moduleIds -or $protocol.owner -notin $ownerIds -or @($protocol.consumers).Count -eq 0 -or
        @($protocol.consumers | Where-Object { $_ -notin $consumerIds }).Count -gt 0) { Add-Finding protocol 'infrastructure-owner' $path }
    if ($protocol.kind -cne 'in-process-sensitive' -or $protocol.retention -cne 'request-or-login-transaction' -or
        $protocol.durable -ne $false -or $protocol.logPolicy -cne 'never' -or @($protocol.tests).Count -eq 0 -or
        @($protocol.fields).Count -eq 0 -or [string]::IsNullOrWhiteSpace($protocol.purpose)) { Add-Finding protocol 'infrastructure-sensitive-boundary' $path }
    foreach ($field in @($protocol.fields)) {
        if ($field.classification -notin @('C0','C1','C2','C3','C4') -or [string]::IsNullOrWhiteSpace($field.purpose)) { Add-Finding field 'infrastructure-field' "$path.fields.$($field.name)" }
    }
}

$deadline = Parse-Date ([string]$catalog.sourcePolicy.legacyDeadline) 'sourcePolicy.legacyDeadline' 'legacy'
foreach ($surface in $surfaces) {
    $path = "publicSurface.$($surface.id)"
    if ($surface.owner -notin $ownerIds) { Add-Finding legacy 'owner-reference' "$path.owner" }
    if ($surface.lifecycle -notin @('LegacyPendingMigration','Retired')) { Add-Finding legacy 'legacy-lifecycle' "$path.lifecycle" }
    if ($surface.lifecycle -eq 'Retired' -and [string]::IsNullOrWhiteSpace($surface.migrationEvidence)) { Add-Finding legacy 'legacy-retirement-evidence' "$path.migrationEvidence" }
    if ($surface.disposition -notin @('Internalize','Replace','Remove')) { Add-Finding legacy 'legacy-disposition' "$path.disposition" }
    foreach ($key in @('project','type','linkedPlan','expiresAt','removalCondition')) { if ([string]::IsNullOrWhiteSpace($surface.$key)) { Add-Finding legacy 'legacy-metadata' "$path.$key" } }
    if ($surface.expiresAt) {
        $expiry = Parse-Date ([string]$surface.expiresAt) "$path.expiresAt" 'legacy'
        if ($deadline -ne [DateOnly]::MinValue -and $expiry -ne [DateOnly]::MinValue -and $expiry -gt $deadline) { Add-Finding legacy 'legacy-expiry' "$path.expiresAt" }
    }
    if ($surface.disposition -eq 'Replace' -and $surface.member -and [string]::IsNullOrWhiteSpace($surface.targetIdentity)) { Add-Finding legacy 'replacement-target' "$path.targetIdentity" }
    if ($surface.targetIdentity -and $surface.targetIdentity -notin $protocolIds) { Add-Finding legacy 'protocol-reference' "$path.targetIdentity" }
}

$classes = @('C0','C1','C2','C3','C4')
foreach ($class in $classes) {
    if ([string]::IsNullOrWhiteSpace($catalog.fieldGovernance.classifications.$class) -or
        [string]::IsNullOrWhiteSpace($catalog.fieldGovernance.logPolicyByClassification.$class)) { Add-Finding field 'classification-policy' "fieldGovernance.$class" }
}
$denyText = @($catalog.fieldGovernance.c4Denylist) -join '|'
foreach ($semantic in @('password','token','authorization','cookie','otp','api secret','client secret','private key','connection string')) {
    if ($denyText -notmatch [regex]::Escape($semantic)) { Add-Finding field 'c4-denylist' "fieldGovernance.c4Denylist.$semantic" }
}
$fieldSurfaceIds = @($fieldSurfaces | ForEach-Object id)
foreach ($surface in @($surfaces | Where-Object kind -in @('dto','integration-event'))) {
    if ($surface.id -notin $fieldSurfaceIds) { Add-Finding field 'field-surface-missing' "fieldSurfaces.$($surface.id)" }
}
foreach ($protocol in $protocols) {
    $surface = $fieldSurfaces | Where-Object id -eq $protocol.identity | Select-Object -First 1
    if ($null -eq $surface -or -not $surface.fieldsFromProtocol) { Add-Finding field 'field-surface-missing' "fieldSurfaces.$($protocol.identity)" }
}
$allFieldRefs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$c3Refs = [Collections.Generic.List[object]]::new()
$fieldCount = 0
foreach ($surface in $fieldSurfaces) {
    $path = "fieldSurfaces.$($surface.id)"
    if (@($surface.consumers).Count -eq 0 -or [string]::IsNullOrWhiteSpace($surface.retention)) { Add-Finding field 'field-surface-metadata' $path }
    if ($surface.fieldsFromProtocol) {
        $protocol = $protocols | Where-Object identity -eq $surface.id | Select-Object -First 1
        $fields = @($protocol.fields | Where-Object { $null -ne $_ })
    } else { $fields = @($surface.fields | Where-Object { $null -ne $_ }) }
    if ($fields.Count -eq 0) { Add-Finding field 'field-surface-empty' "$path.fields" }
    $fieldCount += $fields.Count
    Require-Unique $fields 'name' "$path.fields" 'field'
    foreach ($field in $fields) {
        $fieldPath = "$path.fields.$($field.name)"; $fieldRef = "$($surface.id)/$($field.name)"
        [void]$allFieldRefs.Add($fieldRef)
        if ($field.classification -notin $classes) { Add-Finding field 'field-classification' $fieldPath }
        if ($field.classification -eq 'C4') { Add-Finding field 'secret-forbidden' $fieldPath }
        if ([string]::IsNullOrWhiteSpace($field.purpose) -or $field.required -isnot [bool]) { Add-Finding field 'field-metadata' $fieldPath }
        $logPolicy = if ([string]::IsNullOrWhiteSpace($field.logPolicy)) { $catalog.fieldGovernance.logPolicyByClassification.($field.classification) } else { $field.logPolicy }
        if ([string]::IsNullOrWhiteSpace($logPolicy)) { Add-Finding field 'field-metadata' "$fieldPath.logPolicy" }
        if ($field.classification -eq 'C3') {
            if ([string]::IsNullOrWhiteSpace($field.exceptionRef)) { Add-Finding field 'field-exception' "$fieldPath.exceptionRef" }
            $c3Refs.Add([ordered]@{ fieldRef = $fieldRef; exceptionRef = $field.exceptionRef })
        }
    }
}
if ($fieldCount -eq 0) { Add-Finding field 'zero-field' 'fieldSurfaces.fields' 'coverage' }
$exceptionIds = @($exceptions | ForEach-Object id)
foreach ($item in $c3Refs) {
    if ($item.exceptionRef -notin $exceptionIds) { Add-Finding field 'field-exception-reference' $item.fieldRef; continue }
    $exception = $exceptions | Where-Object id -eq $item.exceptionRef | Select-Object -First 1
    if ($item.fieldRef -notin @($exception.fieldRefs)) { Add-Finding field 'field-exception-reference' $item.fieldRef }
}
$asOf = Parse-Date ([string]$catalog.asOf) 'asOf' 'change'
foreach ($exception in $exceptions) {
    $path = "fieldExceptions.$($exception.id)"
    if ($exception.owner -notin $ownerIds) { Add-Finding field 'owner-reference' "$path.owner" }
    foreach ($key in @('approverRole','approvalStatus','expiresAt','revocationCondition')) { if ([string]::IsNullOrWhiteSpace($exception.$key)) { Add-Finding field 'field-exception-metadata' "$path.$key" } }
    if (@($exception.compensatingControls).Count -eq 0) { Add-Finding field 'field-exception-metadata' "$path.compensatingControls" }
    foreach ($ref in @($exception.fieldRefs)) { if (-not $allFieldRefs.Contains([string]$ref)) { Add-Finding field 'field-exception-reference' "$path.fieldRefs" } }
    if ($exception.approvalStatus -eq 'Approved' -and [string]::IsNullOrWhiteSpace($exception.approvalEvidence)) { Add-Finding field 'field-exception-approval' "$path.approvalEvidence" }
    if ($exception.expiresAt) {
        $expiry = Parse-Date ([string]$exception.expiresAt) "$path.expiresAt" 'field'
        if ($asOf -ne [DateOnly]::MinValue -and $expiry -ne [DateOnly]::MinValue -and $expiry -lt $asOf) { Add-Finding field 'field-exception-expired' "$path.expiresAt" }
    }
}
foreach ($policy in $sensitive) {
    $path = "sensitiveUsePolicies.$($policy.id)"
    foreach ($key in @('purpose','encryption','access','retention','deletion','replay')) { if ([string]::IsNullOrWhiteSpace($policy.$key)) { Add-Finding field 'sensitive-use-metadata' "$path.$key" } }
    if (@($policy.consumers).Count -eq 0) { Add-Finding field 'sensitive-use-metadata' "$path.consumers" }
    foreach ($ref in @($policy.fieldRefs)) { if (-not $allFieldRefs.Contains([string]$ref)) { Add-Finding field 'sensitive-use-reference' "$path.fieldRefs" } }
}
if (@($catalog.migrationRecommendations).Count -lt 2 -or @($catalog.eventMinimizationReviews).Count -lt 5) { Add-Finding field 'minimization-evidence' 'migrationRecommendations' }
foreach ($record in $changes) {
    $path = "changeRecords.$($record.id)"
    if ($record.identity -notin $protocolIds) { Add-Finding change 'protocol-reference' "$path.identity" }
    if ($record.providerOwner -notin $ownerIds) { Add-Finding change 'owner-reference' "$path.providerOwner" }
    foreach ($key in @('classification','summary','compatibilityEvidence','releaseOrder','rollback','status')) { if ([string]::IsNullOrWhiteSpace($record.$key)) { Add-Finding change 'change-record-metadata' "$path.$key" } }
    if (@($record.affectedConsumers).Count -eq 0) { Add-Finding change 'change-record-consumer' "$path.affectedConsumers" }
}
if ($findings.Count -eq 0) { Emit 'pass' 'success' }
else { Emit 'fail' 'findings-blocking' }
