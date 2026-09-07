[CmdletBinding()]
param(
    [string] $CatalogPath = 'docs/architecture/review/gates/G03/contract-event-catalog.yaml',
    [string] $ReportPath,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedCatalogPath = if ([IO.Path]::IsPathRooted($CatalogPath)) { $CatalogPath } else { Join-Path $repositoryRoot $CatalogPath }

function Test-Catalog($catalog) {
    $errors = [Collections.Generic.List[object]]::new()
    function Add-Error([string] $Code, [string] $Path, [string] $Message) {
        $errors.Add([ordered]@{ code = $Code; path = $Path; message = $Message })
    }
    function Test-Unique($items, [string] $property, [string] $path) {
        foreach ($duplicate in @($items | Group-Object -Property $property | Where-Object Count -gt 1)) {
            Add-Error 'duplicate-id' $path "Duplicate $property '$($duplicate.Name)'."
        }
    }

    if ($catalog.formatVersion -ne 1) { Add-Error 'format-version' 'formatVersion' 'Only formatVersion 1 is supported.' }
    if ($catalog.mode -notin @('baseline', 'strict')) { Add-Error 'mode' 'mode' 'Mode must be baseline or strict.' }
    foreach ($name in @('owners', 'modules', 'consumers', 'protocols', 'publicSurface', 'sharedPrimitives', 'waivers', 'changeRecords')) {
        if ($null -eq $catalog.$name) { Add-Error 'required-node' $name "Required node '$name' is missing." }
    }
    Test-Unique @($catalog.owners) 'id' 'owners'
    Test-Unique @($catalog.modules) 'id' 'modules'
    Test-Unique @($catalog.consumers) 'id' 'consumers'
    Test-Unique @($catalog.protocols) 'identity' 'protocols'
    $ownerIds = @($catalog.owners.id)
    $moduleIds = @($catalog.modules.id)
    $consumerIds = @($catalog.consumers.id)
    foreach ($owner in @($catalog.owners)) {
        if ([string]::IsNullOrWhiteSpace($owner.name) -or [string]::IsNullOrWhiteSpace($owner.contact) -or [string]::IsNullOrWhiteSpace($owner.repositoryEvidence)) {
            Add-Error 'owner-incomplete' "owners.$($owner.id)" 'Owner name, contact, and repositoryEvidence are required.'
        }
    }
    foreach ($module in @($catalog.modules)) {
        if ($module.owner -notin $ownerIds) { Add-Error 'owner-reference' "modules.$($module.id).owner" "Unknown owner '$($module.owner)'." }
        if (@($module.capabilities).Count -eq 0 -or @($module.dataFacts).Count -eq 0) { Add-Error 'module-ownership' "modules.$($module.id)" 'Capabilities and dataFacts are required.' }
    }
    foreach ($consumer in @($catalog.consumers)) {
        if ($consumer.owner -notin $ownerIds) { Add-Error 'owner-reference' "consumers.$($consumer.id).owner" "Unknown owner '$($consumer.owner)'." }
        if ($consumer.kind -notin @('internal-module', 'external-service', 'external-client')) { Add-Error 'consumer-kind' "consumers.$($consumer.id).kind" 'Invalid consumer kind.' }
        if ($consumer.kind -eq 'internal-module' -and $consumer.module -notin $moduleIds) { Add-Error 'module-reference' "consumers.$($consumer.id).module" "Unknown module '$($consumer.module)'." }
        if ([string]::IsNullOrWhiteSpace($consumer.evidence) -or [string]::IsNullOrWhiteSpace($consumer.lastConfirmedAt)) { Add-Error 'consumer-evidence' "consumers.$($consumer.id)" 'Evidence and lastConfirmedAt are required.' }
    }
    foreach ($protocol in @($catalog.protocols)) {
        $path = "protocols.$($protocol.identity)"
        if ($protocol.identity -notmatch '^[a-z][a-z0-9.-]+\.v[1-9][0-9]*$') { Add-Error 'identity-format' "$path.identity" 'Identity must be lowercase, globally stable, and end in .vN.' }
        if ($protocol.provider -notin $moduleIds) { Add-Error 'module-reference' "$path.provider" "Unknown provider '$($protocol.provider)'." }
        if ($protocol.owner -notin $ownerIds) { Add-Error 'owner-reference' "$path.owner" "Unknown owner '$($protocol.owner)'." }
        if ($protocol.lifecycle -notin @('Proposed', 'Active', 'Deprecated', 'Retired')) { Add-Error 'lifecycle' "$path.lifecycle" 'Invalid protocol lifecycle.' }
        if (@($protocol.consumers).Count -eq 0) { Add-Error 'missing-consumer' "$path.consumers" 'A Proposed or Active protocol requires a real consumer.' }
        foreach ($consumerId in @($protocol.consumers)) {
            if ($consumerId -notin $consumerIds) { Add-Error 'consumer-reference' "$path.consumers" "Unknown consumer '$consumerId'." }
        }
        foreach ($required in @('businessUse', 'executionScope', 'authorization', 'freshness')) {
            if ([string]::IsNullOrWhiteSpace($protocol.$required)) { Add-Error 'protocol-metadata' "$path.$required" "$required is required." }
        }
        if (@($protocol.failureSemantics).Count -eq 0 -or @($protocol.tests).Count -eq 0) { Add-Error 'protocol-evidence' $path 'Failure semantics and test locations are required.' }
        foreach ($field in @($protocol.fields)) {
            $fieldPath = "$path.fields.$($field.name)"
            if ($field.classification -notin @('C0', 'C1', 'C2', 'C3', 'C4')) { Add-Error 'field-classification' $fieldPath 'Field classification must be C0-C4.' }
            if ($field.classification -eq 'C4') { Add-Error 'secret-forbidden' $fieldPath 'C4 is never allowed in a public Contract/Event.' }
            foreach ($required in @('purpose', 'retention', 'logPolicy')) {
                if ([string]::IsNullOrWhiteSpace($field.$required)) { Add-Error 'field-metadata' "$fieldPath.$required" "$required is required." }
            }
        }
    }
    return @($errors)
}

$catalogText = Get-Content -Raw -LiteralPath $resolvedCatalogPath
try { $catalog = $catalogText | ConvertFrom-Json -Depth 100 } catch { throw "Catalog must be JSON-compatible YAML: $($_.Exception.Message)" }
$errors = @(Test-Catalog $catalog)

$selfTestResults = @()
if ($SelfTest) {
    $cases = @(
        @{ name = 'duplicate identity'; mutate = { param($x) $x.protocols += $x.protocols[0] }; expected = 'duplicate-id' },
        @{ name = 'missing owner'; mutate = { param($x) $x.protocols[0].owner = 'unknown-owner' }; expected = 'owner-reference' },
        @{ name = 'missing consumer'; mutate = { param($x) $x.protocols[0].consumers = @() }; expected = 'missing-consumer' },
        @{ name = 'broken reference'; mutate = { param($x) $x.protocols[0].provider = 'unknown-module' }; expected = 'module-reference' },
        @{ name = 'C4 exposure'; mutate = { param($x) $x.protocols[0].fields[0].classification = 'C4' }; expected = 'secret-forbidden' }
    )
    foreach ($case in $cases) {
        $copy = ($catalogText | ConvertFrom-Json -Depth 100)
        & $case.mutate $copy
        $caseErrors = @(Test-Catalog $copy)
        $passed = $case.expected -in @($caseErrors.code)
        $selfTestResults += [ordered]@{ name = $case.name; expected = $case.expected; passed = $passed }
        if (-not $passed) { $errors += [ordered]@{ code = 'self-test'; path = $case.name; message = "Expected $($case.expected)." } }
    }
}

$graphEdges = @($catalog.protocols | ForEach-Object {
    $protocol = $_
    foreach ($consumerId in @($protocol.consumers)) {
        $consumer = $catalog.consumers | Where-Object id -eq $consumerId | Select-Object -First 1
        [ordered]@{ identity = $protocol.identity; kind = $protocol.kind; provider = $protocol.provider; consumer = $consumer.module; consumerId = $consumerId }
    }
} | Sort-Object provider, consumer, kind, identity)

function Find-Cycles($edges) {
    $reach = @{}
    foreach ($edge in $edges) { $reach["$($edge.provider)|$($edge.consumer)"] = $true }
    $changed = $true
    while ($changed) {
        $changed = $false
        $pairs = @($reach.Keys)
        foreach ($left in $pairs) {
            $leftParts = $left.Split('|')
            foreach ($right in $pairs) {
                $rightParts = $right.Split('|')
                if ($leftParts[1] -eq $rightParts[0]) {
                    $key = "$($leftParts[0])|$($rightParts[1])"
                    if (-not $reach.ContainsKey($key)) { $reach[$key] = $true; $changed = $true }
                }
            }
        }
    }
    @($reach.Keys | Where-Object { $parts = $_.Split('|'); $parts[0] -eq $parts[1] } | Sort-Object)
}

$syncCycles = @(Find-Cycles @($graphEdges | Where-Object kind -eq 'sync'))
$mixedCycles = @(Find-Cycles $graphEdges)
if ($syncCycles.Count -gt 0) { $errors += [ordered]@{ code = 'sync-cycle'; path = 'protocols'; message = "Synchronous dependency cycle: $($syncCycles -join ', ')." } }
if ($mixedCycles.Count -gt 0) { $errors += [ordered]@{ code = 'mixed-cycle'; path = 'protocols'; message = "Mixed dependency cycle requires explicit reviewed workflow: $($mixedCycles -join ', ')." } }

$report = [ordered]@{
    formatVersion = 1
    gate = 'G03'
    result = if ($errors.Count -eq 0) { 'passed' } else { 'failed' }
    mode = $catalog.mode
    counts = [ordered]@{ owners = @($catalog.owners).Count; modules = @($catalog.modules).Count; consumers = @($catalog.consumers).Count; protocols = @($catalog.protocols).Count; graphEdges = $graphEdges.Count; syncCycles = $syncCycles.Count; mixedCycles = $mixedCycles.Count; errors = $errors.Count }
    checks = [ordered]@{ schema = $errors.Count -eq 0; uniqueIdentity = 'duplicate-id' -notin @($errors.code); referenceIntegrity = @('owner-reference', 'module-reference', 'consumer-reference') | Where-Object { $_ -in @($errors.code) } | Measure-Object | Select-Object -ExpandProperty Count | ForEach-Object { $_ -eq 0 }; fieldClassification = @('field-classification', 'secret-forbidden', 'field-metadata') | Where-Object { $_ -in @($errors.code) } | Measure-Object | Select-Object -ExpandProperty Count | ForEach-Object { $_ -eq 0 }; dependencyCycles = $syncCycles.Count -eq 0 -and $mixedCycles.Count -eq 0; selfTests = (-not $SelfTest) -or @($selfTestResults | Where-Object passed -eq $false).Count -eq 0 }
    graph = $graphEdges
    selfTests = $selfTestResults
    errors = $errors
}

if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    $resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
    $report | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
}
if ($report.result -ne 'passed') {
    $report | ConvertTo-Json -Depth 20 | Write-Error
    exit 1
}
Write-Host "G03 catalog validation passed: $resolvedCatalogPath"
