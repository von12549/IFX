[CmdletBinding()]
param(
    [string] $OutputPath = 'docs/architecture/review/evidence/plan04/module-boundary-inventory.json',
    [string] $GraphPath = 'docs/architecture/review/evidence/plan04/module-boundary-dependency-graph.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}

function Sha256([string] $path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant()
}

function ModuleId([string] $name) {
    if ([string]::IsNullOrWhiteSpace($name)) { return $null }
    $registered = @($g03.modules | Where-Object { $_.name -eq $name -or $_.id -eq $name })
    if ($registered.Count -eq 1) { return $registered[0].id }
    return $name.ToLowerInvariant()
}

$baseline = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/plan04/phase0-baseline-inputs.json') | ConvertFrom-Json -Depth 100
$g02 = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/gates/G02/G02-database-inventory.json') | ConvertFrom-Json -Depth 100
$g03 = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') | ConvertFrom-Json -Depth 100
$g04 = Get-Content -Raw -LiteralPath (Repo 'deployment/g04/module-manifest.json') | ConvertFrom-Json -Depth 100
$dependencyGraphPath = 'docs/architecture/review/evidence/plan05/current-dependency-graph.json'
$b4 = Get-Content -Raw -LiteralPath (Repo $dependencyGraphPath) | ConvertFrom-Json -Depth 100

$businessModuleIds = @('auth', 'crm', 'registry', 'transaction', 'holdings')
$moduleNames = @{
    auth = 'IAM'
    crm = 'CRM'
    registry = 'Registry'
    transaction = 'Transaction'
    holdings = 'Holdings'
}

$protocolEdges = @()
foreach ($protocol in @($g03.protocols | Sort-Object identity)) {
    foreach ($consumerId in @($protocol.consumers | Sort-Object)) {
        $consumer = @($g03.consumers | Where-Object id -eq $consumerId)
        if ($consumer.Count -ne 1) {
            throw "Protocol '$($protocol.identity)' has an unknown or ambiguous consumer '$consumerId'."
        }
        $protocolEdges += [ordered]@{
            identity = $protocol.identity
            kind = $protocol.kind
            lifecycle = $protocol.lifecycle
            provider = $protocol.provider
            consumer = $consumer[0].module
            consumerId = $consumerId
            sourceProject = $protocol.source.project
            executionScope = $protocol.executionScope
        }
    }
}

$projectEdges = @()
foreach ($edge in @($b4.projectEdges | Sort-Object from, to)) {
    $fromModule = ModuleId $edge.fromModule
    $toModule = ModuleId $edge.toModule
    $classification = 'outside-or-platform'
    $protocolIdentity = $null
    if ($fromModule -in $businessModuleIds -and $toModule -in $businessModuleIds) {
        if ($fromModule -eq $toModule) {
            $classification = 'same-module-layer'
        }
        else {
            $matches = @($protocolEdges | Where-Object {
                $_.consumer -eq $fromModule -and $_.provider -eq $toModule -and $_.sourceProject -eq $edge.to
            })
            if ($matches.Count -eq 1) {
                $classification = 'registered-cross-module-protocol'
                $protocolIdentity = $matches[0].identity
            }
            elseif ($matches.Count -gt 1) {
                $classification = 'ambiguous-cross-module-protocol'
            }
            else {
                $classification = 'unregistered-cross-module-edge'
            }
        }
    }
    elseif ($fromModule -in $businessModuleIds -and $edge.to -like 'IFX.Platform.*') {
        $classification = 'module-to-platform'
    }
    elseif ($edge.fromRole -in @('RuntimeHost', 'Composition')) {
        $classification = 'host-composition'
    }

    $projectEdges += [ordered]@{
        from = $edge.from
        fromRole = $edge.fromRole
        fromModule = $fromModule
        to = $edge.to
        toRole = $edge.toRole
        toModule = $toModule
        uses = $edge.uses
        classification = $classification
        protocolIdentity = $protocolIdentity
    }
}

$namespaceEdges = @()
foreach ($edge in @($b4.namespaceEdges | Sort-Object from, to)) {
    $fromModule = ModuleId $edge.fromModule
    $toModule = ModuleId $edge.toModule
    $classification = if ($fromModule -in $businessModuleIds -and $toModule -in $businessModuleIds -and $fromModule -ne $toModule) {
        'cross-module'
    } elseif ($fromModule -in $businessModuleIds -and $toModule -eq $fromModule) {
        'same-module-layer'
    } elseif ($fromModule -in $businessModuleIds -and $edge.to -like 'IFX.Platform.*') {
        'module-to-platform'
    } else {
        'outside-or-platform'
    }
    $namespaceEdges += [ordered]@{
        from = $edge.from
        fromRole = $edge.fromRole
        fromModule = $fromModule
        to = $edge.to
        toRole = $edge.toRole
        toModule = $toModule
        uses = $edge.uses
        classification = $classification
    }
}

$historyLines = @(& git -C $repositoryRoot log $baseline.baselineCommit -n 200 --format='@@%H' --name-only)
if ($LASTEXITCODE -ne 0) { throw 'Unable to read the frozen Git history for change-coupling metrics.' }
$moduleCommitCounts = @{}
$pairCounts = @{}
$currentModules = New-Object System.Collections.Generic.HashSet[string]
function Commit-HistoryGroup {
    if ($currentModules.Count -eq 0) { return }
    $names = @($currentModules | Sort-Object)
    foreach ($name in $names) {
        if (-not $moduleCommitCounts.ContainsKey($name)) { $moduleCommitCounts[$name] = 0 }
        $moduleCommitCounts[$name]++
    }
    for ($i = 0; $i -lt $names.Count; $i++) {
        for ($j = $i + 1; $j -lt $names.Count; $j++) {
            $pair = "$($names[$i])|$($names[$j])"
            if (-not $pairCounts.ContainsKey($pair)) { $pairCounts[$pair] = 0 }
            $pairCounts[$pair]++
        }
    }
    $currentModules.Clear()
}
foreach ($line in $historyLines) {
    if ($line -like '@@*') {
        Commit-HistoryGroup
        continue
    }
    if ($line -match '^src/Modules/([^/\\]+)/') {
        $candidate = $matches[1].ToLowerInvariant()
        if ($candidate -in $businessModuleIds) { [void]$currentModules.Add($candidate) }
    }
}
Commit-HistoryGroup

$coChangePairs = @($pairCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $parts = $_.Name.Split('|')
    [ordered]@{ left = $parts[0]; right = $parts[1]; commits = $_.Value }
})

$modules = @()
foreach ($moduleId in $businessModuleIds) {
    $catalogModule = @($g03.modules | Where-Object id -eq $moduleId)
    $runtimeModule = @($g04.modules | Where-Object moduleId -eq $moduleId)
    $databaseModule = @($g02.modules | Where-Object { ([string]$_.Module).ToLowerInvariant() -eq $moduleId })
    if ($catalogModule.Count -ne 1 -or $runtimeModule.Count -ne 1 -or $databaseModule.Count -ne 1) {
        throw "Module '$moduleId' is not uniquely represented in G02, G03 and G04."
    }

    $moduleName = $moduleNames[$moduleId]
    $projects = @(Get-ChildItem -LiteralPath (Repo "src/Modules/$moduleName") -Recurse -File -Filter '*.csproj' |
        ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) } | Sort-Object)
    $tests = @(Get-ChildItem -LiteralPath (Repo 'tests') -Directory | Where-Object {
        $_.Name -like "IFX.Modules.$moduleName*Tests"
    } | Select-Object -ExpandProperty Name | Sort-Object)
    $physicalInbound = @($projectEdges | Where-Object { $_.toModule -eq $moduleId -and $_.fromModule -in $businessModuleIds -and $_.fromModule -ne $moduleId })
    $physicalOutbound = @($projectEdges | Where-Object { $_.fromModule -eq $moduleId -and $_.toModule -in $businessModuleIds -and $_.toModule -ne $moduleId })
    $logicalInbound = @($protocolEdges | Where-Object consumer -eq $moduleId)
    $logicalOutbound = @($protocolEdges | Where-Object provider -eq $moduleId)

    $modules += [ordered]@{
        id = $moduleId
        name = $catalogModule[0].name
        owner = $catalogModule[0].owner
        backupOwner = $catalogModule[0].backupOwner
        capabilities = @($catalogModule[0].capabilities)
        dataFacts = @($catalogModule[0].dataFacts)
        schema = $runtimeModule[0].schema
        dbContext = $databaseModule[0].DbContext
        releaseVersion = $runtimeModule[0].version
        endpointGroups = @($runtimeModule[0].endpointGroups)
        runtimeCapabilities = @($runtimeModule[0].runtimeCapabilities)
        configuration = @($runtimeModule[0].configuration)
        projects = $projects
        tests = $tests
        metrics = [ordered]@{
            projectCount = $projects.Count
            independentTestProjectCount = $tests.Count
            physicalFanInModules = @($physicalInbound.fromModule | Sort-Object -Unique).Count
            physicalFanOutModules = @($physicalOutbound.toModule | Sort-Object -Unique).Count
            physicalCrossModuleEdgeCount = $physicalInbound.Count + $physicalOutbound.Count
            synchronousProvided = @($logicalOutbound | Where-Object kind -eq 'sync').Count
            synchronousConsumed = @($logicalInbound | Where-Object kind -eq 'sync').Count
            eventsProvided = @($logicalOutbound | Where-Object kind -eq 'event').Count
            eventsConsumed = @($logicalInbound | Where-Object kind -eq 'event').Count
            commitsInHistoryWindow = if ($moduleCommitCounts.ContainsKey($moduleId)) { $moduleCommitCounts[$moduleId] } else { 0 }
        }
        assessmentSignals = [ordered]@{
            dataOwnershipRecorded = @($catalogModule[0].dataFacts).Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($runtimeModule[0].schema)
            independentTestsPresent = $tests.Count -gt 0
            releaseIndependent = $false
        }
    }
}

$crossSchemaFindings = @($g02.staticScan.CrossSchemaFindings)
$unregisteredEdges = @($projectEdges | Where-Object classification -in @('unregistered-cross-module-edge','ambiguous-cross-module-protocol'))
$knownBusinessNames = @($businessModuleIds | ForEach-Object { $moduleNames[$_] })
$sourceModuleDirectories = @(Get-ChildItem -LiteralPath (Repo 'src/Modules') -Directory | Where-Object {
    @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' }).Count -gt 0
} | Select-Object -ExpandProperty Name | Sort-Object)
$unknownSourceModules = @($sourceModuleDirectories | Where-Object { $_ -notin $knownBusinessNames })

$inventory = [ordered]@{
    formatVersion = 1
    plan = '04-module-boundary-evolution'
    slice = 'P04-S1'
    asOf = $baseline.capturedAt
    historyBaselineCommit = $baseline.baselineCommit
    inputs = [ordered]@{
        g02DatabaseInventorySha256 = Sha256 'docs/architecture/review/evidence/gates/G02/G02-database-inventory.json'
        g03CatalogSha256 = Sha256 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
        g04ModuleManifestSha256 = Sha256 'deployment/g04/module-manifest.json'
        b4DependencyGraphSha256 = Sha256 $dependencyGraphPath
    }
    modules = $modules
    protocolEdges = $protocolEdges
    projectEdges = $projectEdges
    namespaceEdges = $namespaceEdges
    changeCoupling = [ordered]@{
        window = 'last 200 commits reachable from historyBaselineCommit'
        moduleCommitCounts = @($businessModuleIds | ForEach-Object {
            [ordered]@{ module = $_; commits = if ($moduleCommitCounts.ContainsKey($_)) { $moduleCommitCounts[$_] } else { 0 } }
        })
        pairs = $coChangePairs
    }
    runtimeAndDataCoupling = [ordered]@{
        businessReleaseBoundary = 'single-required-five-module-release'
        physicalDatabase = $g02.physicalDatabase
        schemaOwnership = 'module-owned'
        crossSchemaAccess = if ($crossSchemaFindings.Count -eq 0) { 'none-detected' } else { 'detected' }
        runtimeRoles = @('api','worker','all')
        independentModuleRelease = 'not-supported'
    }
    sharedPrimitives = @($g03.sharedPrimitives | Sort-Object id | ForEach-Object {
        [ordered]@{ id = $_.id; project = $_.project; owner = $_.owner; consumers = @($_.consumers) }
    })
    failClosedFindings = [ordered]@{
        unknownSourceModules = $unknownSourceModules
        unregisteredCrossModuleProjectEdges = $unregisteredEdges
        crossSchemaDataAccess = $crossSchemaFindings
    }
}

$resolvedOutput = Repo $OutputPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutput) | Out-Null
$inventory | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8NoBOM
$graph = [ordered]@{
    formatVersion = 1
    plan = '04-module-boundary-evolution'
    slice = 'P04-S1'
    authority = [ordered]@{
        protocolGraph = 'G03'
        projectAndNamespaceGraph = 'LayerGuard-Plan05 (B4 rules retained)'
        dataOwnership = 'G02'
        releaseBoundary = 'G04'
    }
    nodes = @($modules | ForEach-Object {
        [ordered]@{
            id = $_.id
            owner = $_.owner
            schema = $_.schema
            releaseVersion = $_.releaseVersion
            capabilities = @($_.capabilities)
            dataFacts = @($_.dataFacts)
        }
    })
    protocolEdges = $protocolEdges
    physicalCrossModuleEdges = @($projectEdges | Where-Object {
        $_.fromModule -in $businessModuleIds -and $_.toModule -in $businessModuleIds -and $_.fromModule -ne $_.toModule
    })
    moduleMetrics = @($modules | ForEach-Object { [ordered]@{ module = $_.id; metrics = $_.metrics } })
    failClosedFindings = $inventory.failClosedFindings
}
$resolvedGraph = Repo $GraphPath
$graph | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolvedGraph -Encoding utf8NoBOM
Write-Host "Plan 04 module-boundary inventory generated: $resolvedOutput"
