# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-2: the 0.5.0-a change
# specification. Derived from the composed 0.4.4 installation (Profile, module policies and manifests) and the
# pin-split rule accepted at B3 with rulings R1-R4:
# - governance pins stay;
# - live sources and live registries lose their pins;
# - the G03 projection is regenerated in the G03 core module;
# - lab and V3 couplings are embedded or removed;
# - evidence locks are bound by producer contract from EvidenceRoot.
# Changed modules move to the next minor version. The per-module checkBasis notes record the A1-2 reading of each adapter. A1-3 proves them with the benign-edit
# and rule-breaking-edit suite cases.
[CmdletBinding()]
param(
    [string]$InstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.4.4',
    [string]$OutputPath = (Join-Path $PSScriptRoot 'change-spec.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$package = Join-Path $InstallRoot 'package'
$profilePath = Join-Path $package 'profiles/catalog/ifx_profile/profile.json'
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json -Depth 100
$pre = @($profile.stageConfiguration.pre.modules); $post = @($profile.stageConfiguration.post.modules)

# Same ordered rules as candidates/ifx-i2b/Get-IFXI2BPinClassification.ps1 (record a1-design/pin-classification.json).
$rules = @(
    @{ class = 'lab-coupling'; pattern = '^docs/guards/candidates/' }
    @{ class = 'v3-coupling'; pattern = '(?i)^docs/guards/V3|^mcp/LayerGuard/|/generated/layerguard-governance-input\.json$' }
    @{ class = 'live-registry'; pattern = '^docs/architecture/review/gates/G03/(contract-event-catalog\.yaml|snapshots/)|^docs/architecture/review/policies/.*registry[^/]*\.json$' }
    @{ class = 'live-source'; pattern = '^(src|tests|deployment)(/|$)|^docker-compose[^/]*\.yml$|^IFX\.sln$|^Directory\.[^/]+$|^\.github/CODEOWNERS$' }
    @{ class = 'governance'; pattern = '^docs/architecture/review/|^\.claude/Plans/' }
)
function Classify([string]$Path) { foreach ($r in $rules) { if ($Path -cmatch $r.pattern) { return $r.class } }; throw "Unclassified path: $Path" }
# R2: the projection is regenerated and compared by ifx-g03-governance-core, so the file is checked like a live registry.
function Action([string]$Class) {
    switch ($Class) {
        'governance' { 'keep-pin' }
        'live-source' { 'drop-pin' }
        'live-registry' { 'drop-pin-reconcile' }
        'v3-coupling' { 'drop-pin-regenerated-in-g03-core' }
        'lab-coupling' { 'embed-in-module' }
    }
}

# Profile *Sha256 field -> policy property naming the bound path (the tree fields name a root).
$fieldMap = @{
    catalogSha256 = 'catalogPath'; projectionSha256 = 'projectionPath'; apiSnapshotSha256 = 'apiSnapshotPath'
    serializationSnapshotSha256 = 'serializationSnapshotPath'; zhSha256 = 'zhPath'; enSha256 = 'enPath'
    closeoutSha256 = 'closeoutPath'; g03PlanSha256 = 'g03PlanPath'; layerPlanSha256 = 'layerPlanPath'
    extractionPolicySha256 = 'policyPath'; tenantPolicySha256 = 'policyPath'; schemaSha256 = 'schemaPath'
    registrySha256 = 'registryPath'; solutionSha256 = 'solutionPath'; projectNamePolicySha256 = 'projectNamePolicyPath'
    referencePolicySha256 = 'referencePolicyPath'; fixtureTreeSha256 = 'fixtureRoot'; presentationSha256 = 'presentationRoot'
    transactionHandlersSha256 = 'transactionHandlersRoot'; diagramTreeSha256 = 'diagramRoot'; sourceTreeSha256 = 'sourceRoot'
    inventorySha256 = 'scanRoots'
}
# Where a module has no sourceRoot property, the fingerprint covers src (ifx-g05-inventory: every src/**/*.cs).
$defaultTreeRoot = @{ 'ifx-g05-inventory' = 'src' }

$producers = [ordered]@{
    'ifx-solution-evidence' = [ordered]@{ gate = 'solution'; producerId = 'ifx-c5b-controlled-v1'; script = 'docs/guards/candidates/ifx-gate-coverage-c5b/Invoke-IFXSolutionEvidenceProducer.ps1'; freshness = 'PT24H' }
    'ifx-assembly-evidence' = [ordered]@{ gate = 'assembly'; producerId = 'ifx-c5c-controlled-v1'; script = 'docs/guards/candidates/ifx-gate-coverage-c5c/Invoke-IFXAssemblyEvidenceProducer.ps1'; freshness = 'PT24H' }
    'ifx-frontend-evidence' = [ordered]@{ gate = 'frontend'; producerId = 'ifx-c5d-controlled-v1'; script = 'docs/guards/candidates/ifx-gate-coverage-c5d/Invoke-IFXFrontendEvidenceProducer.ps1'; freshness = 'PT24H' }
    'ifx-database-evidence' = [ordered]@{ gate = 'database'; producerId = 'ifx-c4b-controlled-v2'; script = 'docs/guards/candidates/ifx-gate-coverage-c4b/Invoke-IFXDatabaseEvidenceProducer.ps1'; freshness = 'PT24H' }
    'ifx-c1-type-provenance' = [ordered]@{ gate = 'type'; producerId = 'ifx-c1-r1b-controlled-v1'; script = 'docs/guards/candidates/ifx-gate-coverage-c1r1b/Invoke-IFXCompiledTypeEvidenceProducer.ps1'; freshness = 'PT1H'; staged = @('assembly-manifest.json', 'assemblies/*.dll') }
    'ifx-c1-evaluated-reference' = [ordered]@{ gate = 'graph'; producerId = 'ifx-c1-r2b-controlled-v1'; script = 'docs/guards/candidates/ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1'; freshness = 'PT1H' }
}
$hardCoded = [ordered]@{
    'ifx-c1-type-provenance' = @([ordered]@{ kind = 'v3-coupling'; detail = 'adapter reads docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json and docs/guards/V3_ifx/stages/post/policy/layerguard.json'; action = 'embed the rule and policy content in the module package; the policy pins their hashes' })
}
$checkBasis = [ordered]@{
    'ifx-g03-governance-core' = 'content: rebuilds the governance projection from the catalog and compares it with the committed projection (projection-drift); ownership routes read from CODEOWNERS'
    'ifx-g03-catalog-semantics' = 'content: catalog lifecycle, field-governance, legacy-surface and change-control rules on the catalog'
    'ifx-g03-source-reconciliation' = 'content: re-inventories contract and event sources and reconciles them with the catalog (field-source-drift)'
    'ifx-g03-snapshots' = 'content: regenerates the sync-API and serialization snapshots and compares them with the committed snapshots (snapshot-drift)'
    'ifx-g03-docs-closeout' = 'content: protocol tables in the zh/en documents must equal the catalog; readiness block recomputed from catalog and plans; messaging project existence'
    'ifx-g04-manifests' = 'content: inventory, manifest, orchestration and failure-policy predicates over deployment and runtime manifests'
    'ifx-g04-runtime' = 'content: 47 regex predicates over Program.cs, runtime, drain, health, backpressure and inbound sources'
    'ifx-g04-closeout' = 'mostly existence checks over governance evidence (pins kept); one live file'
    'ifx-plan04-extraction' = 'content: schema, gates, state machine and fixture checks over the extraction policy (governance) and fixtures (live)'
    'ifx-plan04-tenant' = 'content: tenant predicates over src and the bypass registry; negative fixtures'
    'ifx-plan04-projection' = 'content: projection registry, schema and module-edge checks over src/Modules; negative fixtures'
    'ifx-plan04-abstractions' = 'content: legacy Abstractions absence over the solution, src and tests; reads the project-name and reference policies (lab coupling, to embed)'
    'ifx-database-evidence' = 'lock consumer; the three live authorities are compared with the hashes recorded in the lock at the same commit instead of Profile pins'
    'ifx-g05-inventory' = 'content: surface counts over every src/**/*.cs; historical inventory and phase-0 documents are governance'
    'ifx-g05-protocol' = 'content: regex predicates over protocol contracts and tests; reads the G03 projection (checked by G03 core under R2)'
    'ifx-g05-execution-http' = 'content: regex predicates over execution and HTTP sources and the presentation source set'
    'ifx-g05-carriers' = 'content: regex predicates over contract and event carriers and tests'
    'ifx-g05-governance' = 'content: field-governance and observability predicates; transaction handler source set; reads the G03 projection (R2)'
    'ifx-g05-closeout' = 'mostly governance documents and diagrams (pins kept); one live test file'
    'ifx-plan05-security' = 'content: identity and authorization predicates over src; retired paths must be absent'
}

$modules = [Collections.Generic.List[object]]::new()
foreach ($selection in $profile.moduleSelections) {
    $id = $selection.id
    $stage = if ($pre -contains $id) { 'pre' } elseif ($post -contains $id) { 'post' } else { 'none' }
    $manifestPath = Join-Path $package "modules/$id/module.json"
    $version = if (Test-Path -LiteralPath $manifestPath) { (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json).version } else { $null }
    $policyPath = Join-Path $package "modules/$id/policy.json"
    $policy = if (Test-Path -LiteralPath $policyPath) { Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 100 } else { $null }
    $c = $selection.config; $names = @($c.PSObject.Properties.Name)
    $bindings = [Collections.Generic.List[object]]::new()
    if ($names -contains 'authorityHashes') {
        $i = 0
        foreach ($h in @($c.authorityHashes)) {
            $path = if ($h.PSObject.Properties.Name -contains 'path') { [string]$h.path }
                elseif ($null -ne $policy -and $policy.PSObject.Properties.Name -contains 'authorities') { [string](@($policy.authorities | Where-Object { $_.id -ceq $h.id })[0].path) }
                elseif ($null -ne $policy -and $policy.PSObject.Properties.Name -contains 'authorityPaths') { [string]@($policy.authorityPaths)[$i] }
                else { throw "Cannot resolve authority $($h.id) of $id" }
            if ([string]::IsNullOrWhiteSpace($path)) { throw "Empty authority path: $id/$($h.id)" }
            $class = Classify $path
            $bindings.Add([ordered]@{ field = "authorityHashes[$($h.PSObject.Properties.Name -contains 'id' ? $h.id : $i)]"; path = $path; class = $class; action = Action $class })
            $i++
        }
    }
    foreach ($field in @($names | Where-Object { $_ -match 'Sha256$' -and $_ -notin @('policySha256', 'evidenceLockSha256') })) {
        $property = $fieldMap[$field]
        if ($null -eq $property) { throw "Unmapped Profile field $id.$field" }
        $path = if ($null -ne $policy -and $policy.PSObject.Properties.Name -contains $property) { (@($policy.$property) | ForEach-Object { [string]$_ }) -join ', ' }
            elseif ($defaultTreeRoot.ContainsKey($id) -and $field -ceq 'sourceTreeSha256') { $defaultTreeRoot[$id] }
            else { throw "Policy property $property missing for $id.$field" }
        $classes = @($path -split ', ' | ForEach-Object { Classify $_ } | Sort-Object -Unique)
        if ($classes.Count -ne 1) { throw "Mixed classes for $id.${field}: $($classes -join ',')" }
        $class = $classes[0]
        $bindings.Add([ordered]@{ field = $field; path = $path; tree = ($property -match 'Roots?$'); class = $class; action = Action $class })
    }
    $lock = if ($producers.Contains($id)) { $producers[$id] } else { $null }
    $labReads = @(if ($null -ne $policy -and $policy.PSObject.Properties.Name -contains 'sourcePolicies' -and $id -ceq 'ifx-c1-evaluated-reference') { @($policy.sourcePolicies | ForEach-Object { [ordered]@{ kind = 'lab-coupling'; detail = "adapter reads $($_.path)"; action = 'embed the policy content in the module package; the policy pins its hash' } }) })
    $couplings = @(@($bindings | Where-Object { $_.class -in @('v3-coupling', 'lab-coupling') } | ForEach-Object { [ordered]@{ kind = $_.class; detail = "Profile field $($_.field) binds $($_.path)"; action = $_.action } }) + $labReads + @(if ($hardCoded.Contains($id)) { $hardCoded[$id] }))
    $dropped = @($bindings | Where-Object { $_.action -cne 'keep-pin' }).Count
    $disposition = @()
    if ($null -ne $lock) { $disposition += 'lock-binding' }
    if ($dropped -gt 0) { $disposition += 'pin-split' }
    if ($couplings.Count -gt 0) { $disposition += 'coupling' }
    if ($disposition.Count -eq 0) { $disposition = @('unchanged') }
    $modules.Add([ordered]@{
        id = $id; stage = $stage; version = $version
        # Changed modules move to the next minor version (0.1.x -> 0.2.0, 0.2.x -> 0.3.0).
        newVersion = $(if ($disposition -ccontains 'unchanged') { $version } else { $v = [version]$version; "$($v.Major).$($v.Minor + 1).0" })
        disposition = $disposition
        profileConfig = [ordered]@{
            remove = @(@(if ($null -ne $lock) { 'evidenceLockPath', 'evidenceLockSha256' }) + @($bindings | Where-Object { $_.action -cne 'keep-pin' } | ForEach-Object { $_.field }))
            keep = @($bindings | Where-Object { $_.action -ceq 'keep-pin' } | ForEach-Object { $_.field })
        }
        bindings = @($bindings.ToArray())
        lockBinding = $lock
        couplings = $couplings
        checkBasis = $(if ($checkBasis.Contains($id)) { $checkBasis[$id] } elseif ($stage -ceq 'pre') { 'unchanged Pre module; evaluates the current source (I2-A)' } else { $null })
    })
}
$changed = @($modules | Where-Object { $_.disposition -notcontains 'unchanged' })
$spec = [ordered]@{
    formatVersion = 1; kind = 'ifx-050a-change-spec'
    plan = '20260929-v4-ifx-i2b-ci-evidence-and-bundle'; amendment = 'A1'; step = 'A1-2'
    base = [ordered]@{ install = 'v4-guards-1.1.6-ifx-0.4.4'; profileVersion = $profile.version; profileSha256 = (Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    target = [ordered]@{ profileVersion = '0.5.1'; moduleSourceRoot = 'docs/guards/candidates/ifx-i2b-051/modules' }
    rulings = [ordered]@{ R1 = 'registries are live'; R2 = 'G03 core regenerates the projection'; R3 = 'lab tree candidates/ifx-i2b-051'; R4 = 'IFX-V4-005 fixed first under its own Plan' }
    lockLayout = [ordered]@{
        root = 'EvidenceRoot'; lock = 'locks/<gate>/evidence-lock.json'; evidence = 'locks/<gate>/<files listed in the lock>'
        staged = 'locks/type/assembly-manifest.json and locks/type/assemblies/*.dll (read by ifx-c1-type-provenance and architecture-conformance)'
        verification = @('producer id', 'producer script SHA-256 pinned in the module policy', 'targetCommit equals TargetRoot HEAD', 'freshness window unchanged', 'source-tree fingerprint', 'every listed evidence file hash', 'lineage between locks')
        failureCategories = [ordered]@{ missing = 'prerequisite-missing'; inconsistent = 'integrity-failure' }
    }
    profileChanges = [ordered]@{
        workspaceEvidenceRemoveRoots = @($profile.workspaceEvidence.relativeRoots | Where-Object { $_ -match '(?i)^docs/guards/V3' })
        otherCouplings = @('the generated producer pins and reads docs/guards/V3/.../SourceFiles.cs (lineage only; replaced in 0.5.0-b with the producers)', 'the frontend producer sets a fixed Windows PATH (replaced in 0.5.0-b)')
    }
    summary = [ordered]@{
        modules = $modules.Count; pre = $pre.Count; post = $post.Count; changed = $changed.Count
        unchanged = @($modules | Where-Object { $_.disposition -contains 'unchanged' } | ForEach-Object { $_.id })
        lockBinding = @($changed | Where-Object { $_.disposition -contains 'lock-binding' }).Count
        pinSplit = @($changed | Where-Object { $_.disposition -contains 'pin-split' }).Count
        coupling = @($changed | Where-Object { $_.disposition -contains 'coupling' }).Count
        bindingsKept = @($modules | ForEach-Object { $_.bindings } | Where-Object { $_.action -ceq 'keep-pin' }).Count
        bindingsDropped = @($modules | ForEach-Object { $_.bindings } | Where-Object { $_.action -cne 'keep-pin' }).Count
    }
    suiteRule = 'Every changed module adds: (a) a benign edit of each formerly pinned live file still passes; (b) a rule-breaking edit of a live input still blocks with the module rule; (c) an edited governance file is still integrity-failure. A check that no longer blocks under (b) depended on the hash alone and is rewritten before A1-4.'
    modules = @($modules.ToArray())
}
[IO.File]::WriteAllText($OutputPath, (($spec | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
$spec.summary | ConvertTo-Json -Compress
