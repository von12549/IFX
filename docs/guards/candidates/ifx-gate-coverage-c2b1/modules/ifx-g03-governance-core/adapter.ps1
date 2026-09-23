Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$detector = 'ifx-g03-governance-core'
$claims = @('IFX.C2.G03_OWNERSHIP','IFX.C2.G03_PROVIDER_GRAPH','IFX.C2.G03_WAIVER_POLICY','IFX.C2.G03_PROJECTION')
$matched = @(0,0,0,0)
$findings = [Collections.Generic.List[object]]::new()

function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $coverage = for ($i = 0; $i -lt $claims.Count; $i++) { [ordered]@{ claimId = $claims[$i]; matched = $matched[$i]; minimum = 1 } }
    $result = [ordered]@{ formatVersion = 1; status = $Status; exitCategory = $Category; findings = @($findings.ToArray()); coverage = @($coverage) }
    if ($Message) { $result.message = $Message }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string] $Category, [string] $Message) { Emit 'error' $Category $Message; exit 0 }
function Add-Finding([string] $Code, [string] $Path, [string] $Kind = 'catalog-governance') {
    $rule = if ($Kind -eq 'governance-projection') { 'G03-PROJECTION' }
        elseif ($Code -like 'waiver-*' -or $Code -eq 'catalog-date') { 'G03-WAIVER-POLICY' }
        elseif ($Path -match '^(protocols|infrastructureProtocols|sharedPrimitives|contractDependencyPolicy)' -or
            $Code -in @('zero-protocol','zero-edge','sync-cycle','mixed-cycle')) { 'G03-PROVIDER-GRAPH' }
        else { 'G03-OWNERSHIP' }
    $findings.Add([ordered]@{ ruleId = $rule; subject = "${Code}:${Path}"; evidenceKind = $Kind; detectorId = $detector; severity = 'blocking' })
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current -and ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current))) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
            Stop-Adapter 'unsafe-path' "Governance input crosses a link: $Path"
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Resolve-Input([string] $Root, [string] $Relative, [string] $Label) {
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)') { Stop-Adapter 'integrity-failure' "Unsafe policy path: $Label" }
    $path = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not (Is-Under $path $Root)) { Stop-Adapter 'integrity-failure' "Policy path escapes TargetRoot: $Label" }
    Assert-NoLink $path
    if (-not [IO.File]::Exists($path)) { Stop-Adapter 'prerequisite-missing' "$Label is missing." }
    return $path
}
function Required-Set($Items, [string] $Key, [string] $Path) {
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($item in @($Items | Where-Object { $null -ne $_ })) {
        $id = [string]$item.$Key
        if ([string]::IsNullOrWhiteSpace($id)) { Add-Finding 'missing-id' $Path; continue }
        if (-not $seen.Add($id)) { Add-Finding 'duplicate-id' "$Path.$id" }
    }
}
function Find-Cycles($Edges) {
    $reach = @{}
    foreach ($edge in @($Edges)) {
        if ($edge.provider -and $edge.consumer) { $reach["$($edge.provider)|$($edge.consumer)"] = $true }
    }
    $changed = $true
    while ($changed) {
        $changed = $false
        $pairs = @($reach.Keys)
        foreach ($left in $pairs) {
            $a = $left.Split('|')
            foreach ($right in $pairs) {
                $b = $right.Split('|')
                if ($a[1] -ceq $b[0]) {
                    $key = "$($a[0])|$($b[1])"
                    if (-not $reach.ContainsKey($key)) { $reach[$key] = $true; $changed = $true }
                }
            }
        }
    }
    return @($reach.Keys | Where-Object { $v = $_.Split('|'); $v[0] -ceq $v[1] } | Sort-Object)
}
function Same-Json($A, $B) {
    return ($A | ConvertTo-Json -Depth 100 -Compress) -ceq ($B | ConvertTo-Json -Depth 100 -Compress)
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
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g03-governance-core-c2b1' -or
    (@($policy.claims | ForEach-Object claimId) -join '|') -cne ($claims -join '|')) { Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.' }
$catalogPath = Resolve-Input $targetRoot ([string]$policy.catalogPath) 'G03 catalog'
$projectionPath = Resolve-Input $targetRoot ([string]$policy.projectionPath) 'G03 projection'
$codeownersPath = Resolve-Input $targetRoot ([string]$policy.codeownersPath) 'CODEOWNERS'
if ((Get-FileHash -LiteralPath $catalogPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.catalogSha256 -or
    (Get-FileHash -LiteralPath $projectionPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.projectionSha256) {
    Stop-Adapter 'integrity-failure' 'Catalog or projection hash drift.'
}
try {
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -Depth 100
    $projection = Get-Content -LiteralPath $projectionPath -Raw | ConvertFrom-Json -Depth 100
}
catch { Stop-Adapter 'invalid-input' 'G03 catalog or projection is not JSON-compatible YAML/JSON.' }
if ($catalog -isnot [pscustomobject] -or $projection -isnot [pscustomobject]) { Stop-Adapter 'invalid-input' 'G03 catalog and projection must be objects.' }
if ($catalog.formatVersion -ne 1) { Add-Finding 'format-version' 'formatVersion' }
if ($catalog.mode -notin @('baseline','migration','strict')) { Add-Finding 'mode' 'mode' }
foreach ($name in @('owners','modules','consumers','approvalPolicy','protocols','contractDependencyPolicy','sharedPrimitives','waiverPolicy','waivers','infrastructureProtocols')) {
    if ($null -eq $catalog.PSObject.Properties[$name] -or $null -eq $catalog.$name) { Add-Finding 'required-node' $name }
}
if ($findings.Count -gt 0) { Emit 'fail' 'findings-blocking'; exit 0 }
foreach ($name in @('backupOwner','backupCodeownersHandle','backupAssignmentEvidence')) {
    if ($null -eq $catalog.approvalPolicy -or $null -eq $catalog.approvalPolicy.PSObject.Properties[$name]) { Add-Finding 'required-node' "approvalPolicy.$name" }
}
foreach ($name in @('default','runtimeSeparation')) {
    if ($null -eq $catalog.contractDependencyPolicy -or $null -eq $catalog.contractDependencyPolicy.PSObject.Properties[$name]) { Add-Finding 'required-node' "contractDependencyPolicy.$name" }
}
foreach ($name in @('maximumDays','unwaivable')) {
    if ($null -eq $catalog.waiverPolicy -or $null -eq $catalog.waiverPolicy.PSObject.Properties[$name]) { Add-Finding 'required-node' "waiverPolicy.$name" }
}
if ($findings.Count -gt 0) { Emit 'fail' 'findings-blocking'; exit 0 }
$owners = @($catalog.owners | Where-Object { $null -ne $_ }); $modules = @($catalog.modules | Where-Object { $null -ne $_ })
$consumers = @($catalog.consumers | Where-Object { $null -ne $_ })
$protocols = @($catalog.protocols | Where-Object { $null -ne $_ }); $infrastructure = @($catalog.infrastructureProtocols | Where-Object { $null -ne $_ })
$allProtocols = @($protocols) + @($infrastructure)
if ($owners.Count -eq 0) { Add-Finding 'zero-owner' 'owners' 'coverage' }
if ($modules.Count -eq 0) { Add-Finding 'zero-module' 'modules' 'coverage' }
if ($consumers.Count -eq 0) { Add-Finding 'zero-consumer' 'consumers' 'coverage' }
if ($allProtocols.Count -eq 0) { Add-Finding 'zero-protocol' 'protocols' 'coverage' }
if ($owners.Count -gt 0 -and $modules.Count -gt 0 -and $consumers.Count -gt 0) { $matched[0] = 1 }
Required-Set $owners 'id' 'owners'; Required-Set $modules 'id' 'modules'; Required-Set $consumers 'id' 'consumers'
Required-Set $allProtocols 'identity' 'all-protocols'
$ownerIds = @($owners | ForEach-Object id); $moduleIds = @($modules | ForEach-Object id); $consumerIds = @($consumers | ForEach-Object id)
$moduleMap = @{}; foreach ($module in $modules) { if ($module.id -and -not $moduleMap.ContainsKey([string]$module.id)) { $moduleMap[[string]$module.id] = $module } }
$consumerMap = @{}; foreach ($consumer in $consumers) { if ($consumer.id -and -not $consumerMap.ContainsKey([string]$consumer.id)) { $consumerMap[[string]$consumer.id] = $consumer } }
foreach ($owner in $owners) {
    if ([string]::IsNullOrWhiteSpace($owner.name) -or [string]::IsNullOrWhiteSpace($owner.contact) -or [string]::IsNullOrWhiteSpace($owner.repositoryEvidence)) { Add-Finding 'owner-incomplete' "owners.$($owner.id)" }
}
$backup = [string]$catalog.approvalPolicy.backupOwner
if ([string]::IsNullOrWhiteSpace($backup) -or $backup -notin $ownerIds) { Add-Finding 'backup-owner-reference' 'approvalPolicy.backupOwner' }
if ([string]::IsNullOrWhiteSpace($catalog.approvalPolicy.backupCodeownersHandle) -or [string]::IsNullOrWhiteSpace($catalog.approvalPolicy.backupAssignmentEvidence)) {
    Add-Finding 'backup-owner-evidence' 'approvalPolicy'
} else {
    $evidenceRelative = [string]$catalog.approvalPolicy.backupAssignmentEvidence
    if ([IO.Path]::IsPathRooted($evidenceRelative) -or $evidenceRelative -match '(^|[\\/])\.\.([\\/]|$)') { Add-Finding 'backup-owner-evidence' 'approvalPolicy.backupAssignmentEvidence' }
    else {
        $evidencePath = [IO.Path]::GetFullPath((Join-Path $targetRoot $evidenceRelative))
        if (-not (Is-Under $evidencePath $targetRoot)) { Add-Finding 'backup-owner-evidence' 'approvalPolicy.backupAssignmentEvidence' }
        else { Assert-NoLink $evidencePath; if (-not [IO.File]::Exists($evidencePath)) { Add-Finding 'backup-owner-evidence' 'approvalPolicy.backupAssignmentEvidence' } }
    }
}
$codeowners = Get-Content -LiteralPath $codeownersPath -Raw
foreach ($route in @($policy.requiredCodeownerRoutes)) {
    $line = @($codeowners -split "`r?`n" | Where-Object { $_ -match ('^' + [regex]::Escape($route) + '\s') })
    if ($line.Count -ne 1 -or $line[0] -notmatch [regex]::Escape([string]$catalog.approvalPolicy.backupCodeownersHandle)) { Add-Finding 'backup-codeowners' $route }
}
foreach ($module in $modules) {
    $path = "modules.$($module.id)"
    if ($module.owner -notin $ownerIds) { Add-Finding 'owner-reference' "$path.owner" }
    if ($module.backupOwner -notin $ownerIds -or $module.backupOwner -eq $module.owner -or $module.backupOwner -ne $backup) { Add-Finding 'backup-owner-reference' "$path.backupOwner" }
    if (@($module.capabilities).Count -eq 0 -or @($module.dataFacts).Count -eq 0) { Add-Finding 'module-ownership' $path }
}
foreach ($consumer in $consumers) {
    $path = "consumers.$($consumer.id)"
    if ($consumer.owner -notin $ownerIds) { Add-Finding 'owner-reference' "$path.owner" }
    if ($consumer.kind -notin @('internal-module','external-service','external-client')) { Add-Finding 'consumer-kind' "$path.kind" }
    if ($consumer.kind -eq 'internal-module' -and $consumer.module -notin $moduleIds) { Add-Finding 'module-reference' "$path.module" }
    if ([string]::IsNullOrWhiteSpace($consumer.evidence) -or [string]::IsNullOrWhiteSpace($consumer.lastConfirmedAt)) { Add-Finding 'consumer-evidence' $path }
}
$edges = [Collections.Generic.List[object]]::new()
foreach ($protocol in $allProtocols) {
    $prefix = if ($protocol -in $protocols) { 'protocols' } else { 'infrastructureProtocols' }
    $path = "$prefix.$($protocol.identity)"
    if ($protocol.provider -notin $moduleIds) { Add-Finding 'module-reference' "$path.provider" }
    if ($protocol.owner -notin $ownerIds) { Add-Finding 'owner-reference' "$path.owner" }
    if (@($protocol.consumers).Count -eq 0) { Add-Finding 'missing-consumer' "$path.consumers" }
    foreach ($consumerId in @($protocol.consumers)) {
        if ($consumerId -notin $consumerIds) { Add-Finding 'consumer-reference' "$path.consumers"; continue }
        $consumer = $consumerMap[[string]$consumerId]
        if ($protocol.provider -in $moduleIds -and $consumer.module -in $moduleIds) {
            $edges.Add([ordered]@{ identity = $protocol.identity; kind = $protocol.kind; provider = $protocol.provider; consumer = $consumer.module; consumerId = $consumerId })
        }
    }
}
if ($edges.Count -eq 0) { Add-Finding 'zero-edge' 'protocols' 'coverage' }
else { $matched[1] = 1 }
$publicIdentities = @($protocols | ForEach-Object identity)
$businessEdges = @($edges.ToArray() | Where-Object { $_.identity -in $publicIdentities })
if (@(Find-Cycles @($businessEdges | Where-Object kind -eq 'sync')).Count -gt 0) { Add-Finding 'sync-cycle' 'protocols' }
if (@(Find-Cycles $businessEdges).Count -gt 0) { Add-Finding 'mixed-cycle' 'protocols' }
$primitives = @($catalog.sharedPrimitives | Where-Object { $null -ne $_ })
Required-Set $primitives 'id' 'sharedPrimitives'
foreach ($primitive in $primitives) {
    $path = "sharedPrimitives.$($primitive.id)"
    if ($primitive.owner -notin $ownerIds) { Add-Finding 'owner-reference' "$path.owner" }
    if ($primitive.admissionBasis -notin @('three-module-identical-semantics','uniform-infrastructure-protocol')) { Add-Finding 'primitive-admission' "$path.admissionBasis" }
    if ($primitive.admissionBasis -eq 'three-module-identical-semantics' -and @($primitive.consumers).Count -lt 3) { Add-Finding 'primitive-consumers' "$path.consumers" }
    foreach ($consumerId in @($primitive.consumers)) { if ($consumerId -notin $moduleIds) { Add-Finding 'module-reference' "$path.consumers" } }
    foreach ($key in @('project','status','semantic','serialization','compatibility','linkedPlan')) { if ([string]::IsNullOrWhiteSpace($primitive.$key)) { Add-Finding 'primitive-metadata' "$path.$key" } }
}
if ($catalog.contractDependencyPolicy.default -cne 'BCL-only' -or $catalog.contractDependencyPolicy.runtimeSeparation.mustNotBeReferencedByModuleContracts -ne $true) { Add-Finding 'contract-allowlist' 'contractDependencyPolicy' }
if ($catalog.waiverPolicy.maximumDays -ne 90 -or @($catalog.waiverPolicy.unwaivable).Count -eq 0) { Add-Finding 'waiver-policy' 'waiverPolicy' }
else { $matched[2] = 1 }
try { $asOf = [DateOnly]::Parse([string]$catalog.asOf) }
catch { Add-Finding 'catalog-date' 'asOf'; $asOf = [DateOnly]::MinValue }
$waivers = @($catalog.waivers | Where-Object { $null -ne $_ })
Required-Set $waivers 'id' 'waivers'
foreach ($waiver in $waivers) {
    $path = "waivers.$($waiver.id)"
    foreach ($key in @('owner','reason','risk','createdAt','expiresAt','removalCondition','linkedPlanItem','category')) { if ([string]::IsNullOrWhiteSpace($waiver.$key)) { Add-Finding 'waiver-metadata' "$path.$key" } }
    if ($waiver.owner -notin $ownerIds) { Add-Finding 'owner-reference' "$path.owner" }
    if ($waiver.category -in @($catalog.waiverPolicy.unwaivable)) { Add-Finding 'waiver-unwaivable' "$path.category" }
    if ($waiver.createdAt -and $waiver.expiresAt) {
        try {
            $created = [DateOnly]::Parse([string]$waiver.createdAt); $expires = [DateOnly]::Parse([string]$waiver.expiresAt)
            if ($expires.DayNumber - $created.DayNumber -gt 90 -or $expires -lt $created) { Add-Finding 'waiver-duration' "$path.expiresAt" }
            if ($asOf -ne [DateOnly]::MinValue -and $expires -lt $asOf) { Add-Finding 'waiver-expired' "$path.expiresAt" }
        } catch { Add-Finding 'waiver-date' "$path.expiresAt" }
    }
}

# Rebuild the V3 handoff semantically, without executing the V3 generator.
$providers = [ordered]@{}
foreach ($consumer in @($consumers | Sort-Object module)) {
    if ($consumer.module -notin $moduleIds) { continue }
    $names = @($allProtocols | Where-Object { $consumer.id -in @($_.consumers) -and $_.provider -in $moduleIds } |
        ForEach-Object { $moduleMap[[string]$_.provider].name } | Sort-Object -Unique)
    if ($names.Count -gt 0) { $providers[[string]$moduleMap[[string]$consumer.module].name] = $names }
}
$expectedEdges = @($allProtocols | Sort-Object identity | ForEach-Object {
    $p = $_
    foreach ($consumerId in @($p.consumers)) {
        if ($consumerMap.ContainsKey([string]$consumerId) -and $moduleMap.ContainsKey([string]$p.provider) -and $moduleMap.ContainsKey([string]$consumerMap[[string]$consumerId].module)) {
            [ordered]@{ identity = $p.identity; kind = $p.kind; consumer = $moduleMap[[string]$consumerMap[[string]$consumerId].module].name; provider = $moduleMap[[string]$p.provider].name }
        }
    }
})
$expected = [ordered]@{
    formatVersion = 1; source = $policy.catalogPath
    catalogSha256 = (Get-FileHash -LiteralPath $catalogPath -Algorithm SHA256).Hash.ToLowerInvariant()
    moduleOwnership = @($modules | Sort-Object id | ForEach-Object { [ordered]@{ module = $_.name; owner = $_.owner; backupOwner = $_.backupOwner } })
    contractRoles = [ordered]@{ provider = 'Contracts'; consumerPort = 'Application'; consumerAdapter = 'IntegrationAdapter' }
    providerContracts = $providers; adapterEdges = $expectedEdges
    sharedPrimitiveProjects = @($primitives.project | Sort-Object -Unique)
    contractDependencyPolicy = $catalog.contractDependencyPolicy; waiverPolicy = $catalog.waiverPolicy; waivers = $waivers
}
foreach ($key in $expected.Keys) {
    if ($null -eq $projection.PSObject.Properties[$key] -or -not (Same-Json $expected[$key] $projection.$key)) { Add-Finding 'projection-drift' $key 'governance-projection' }
}
if ($projection.formatVersion -eq 1 -and $projection.source -ceq $policy.catalogPath -and $projection.catalogSha256 -ceq $expected.catalogSha256) { $matched[3] = 1 }
if ($findings.Count -eq 0) { Emit 'pass' 'success' }
else { Emit 'fail' 'findings-blocking' }
