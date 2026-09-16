[CmdletBinding()]
param(
    [string] $BaselineCommit = 'd2663392db1bacd34dd866917c45b7cdf3ede7cc',
    [string] $OutputDirectory = 'docs/guards/V3_ifx/analysis/ifx/refactor-baseline',
    [string] $FrequencySince = '2026-06-01',
    [switch] $Check
)

# Plan 06 P0 baseline generator. Reads Git objects of the recovery commit only (never the working tree),
# so its output is reproducible from any checkout that contains the commit.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../..'))
$output = [IO.Path]::GetFullPath((Join-Path $root $OutputDirectory))
$utf8 = [Text.UTF8Encoding]::new($false)

function Invoke-Git {
    $result = & git -C $root @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed with exit code $LASTEXITCODE" }
    return $result
}

function Sort-Ordinal([string[]] $values) {
    $copy = [string[]]@($values)
    [Array]::Sort([Array]$copy, [Collections.IComparer][StringComparer]::Ordinal)
    return ,$copy
}

function Sort-ByOrdinal([object[]] $items, [scriptblock] $key) {
    # Culture-independent ordering so output is byte-identical on Windows and Linux.
    $array = @($items)
    $keys = [string[]]@($array | ForEach-Object { [string](& $key $_) })
    # Non-generic overload: the generic one sorts a converted copy of the items in PowerShell.
    [Array]::Sort([Array]$keys, [Array]$array, [Collections.IComparer][StringComparer]::Ordinal)
    return ,$array
}

function Write-Json([string] $name, [object] $value) {
    $text = ($value | ConvertTo-Json -Depth 30).Replace("`r`n", "`n") + "`n"
    $path = Join-Path $output $name
    if ($Check) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing baseline output: $name" }
        if ([IO.File]::ReadAllText($path, $utf8) -cne $text) { throw "Baseline output drift: $name" }
        return
    }
    [IO.File]::WriteAllText($path, $text, $utf8)
}

function Show-Blob([string] $path) {
    return ((Invoke-Git show "${BaselineCommit}:$path") -join "`n")
}

$commit = (Invoke-Git rev-parse --verify "$BaselineCommit^{commit}").Trim()
$generatedBy = 'docs/guards/V3_ifx/analysis/ifx/refactor-baseline/tools/New-RefactorBaseline.ps1'

# ---------------------------------------------------------------- scopes and tree entries
$scopes = [ordered]@{
    'V3'             = 'docs/guards/V3/'
    'V3_backup'      = 'docs/guards/V3_backup/'
    'V3_ifx'         = 'docs/guards/V3_ifx/'
    'plans'          = 'docs/guards/plans/'
    'mcp-layerguard' = 'mcp/LayerGuard/'
    'github'         = '.github/'
}

$entries = [Collections.Generic.List[object]]::new()
foreach ($scope in $scopes.Keys) {
    $prefix = $scopes[$scope]
    $raw = (Invoke-Git ls-tree -r -z --long $commit -- $prefix) -join "`n"
    foreach ($record in ($raw -split "`0")) {
        if ([string]::IsNullOrWhiteSpace($record)) { continue }
        $tab = $record.IndexOf("`t")
        $meta = $record.Substring(0, $tab).Trim() -split '\s+'
        $path = $record.Substring($tab + 1).Trim("`n")
        $entries.Add([pscustomobject]@{
            scope = $scope; path = $path; relative = $path.Substring($prefix.Length)
            mode = $meta[0]; type = $meta[1]; objectId = $meta[2]; size = [long]$meta[3]
        })
    }
}

# ---------------------------------------------------------------- CODEOWNERS (last matching rule wins)
$ownerRules = @(foreach ($line in ((Show-Blob '.github/CODEOWNERS') -split "`n")) {
    $trimmed = $line.Trim()
    if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
    $parts = $trimmed -split '\s+'
    $pattern = $parts[0]
    $regex = [Regex]::Escape($pattern.TrimStart('/')).Replace('\*', '[^/]*')
    $regex = if ($pattern.EndsWith('/')) { '^' + $regex } else { '^' + $regex + '(/|$)' }
    [pscustomobject]@{ pattern = $pattern; regex = $regex; owners = @($parts | Select-Object -Skip 1) }
})
function Get-Owner([string] $path) {
    $match = $null
    foreach ($rule in $ownerRules) { if ($path -match $rule.regex) { $match = $rule } }
    if ($null -eq $match) { return [ordered]@{ rule = $null; owners = @() } }
    return [ordered]@{ rule = $match.pattern; owners = @($match.owners) }
}

# ---------------------------------------------------------------- classification rules (first match wins)
# kind: authority | implementation | generated | activation | evidence | documentation
# stage: bootstrap | analysis | pre | post | diff | ci | shared | external
# disposition: retain | migrate | migrate-overlay | merge-into-v3 | split | untrack | replace | delete | delete-duplicate | out-of-scope
# dedupe: when true and the V3_ifx file is byte-identical to V3, disposition becomes delete-duplicate (P7.5, D1).
function New-ClassRule([string[]] $scopes, [string] $pattern, [string] $kind, [string] $stage, [string] $role, [string] $disposition, [string] $target, [string] $phase, [string[]] $decisions, [hashtable] $extra = @{}) {
    [pscustomobject]@{
        scopes = $scopes; pattern = $pattern; kind = $kind; stage = $stage; role = $role; disposition = $disposition
        target = $target; phase = $phase; decisions = $decisions
        stages = if ($extra.ContainsKey('stages')) { $extra.stages } else { @($stage) }
        lifecycle = if ($extra.ContainsKey('lifecycle')) { $extra.lifecycle } else { $null }
        dedupe = $extra.ContainsKey('dedupe') -and $extra.dedupe
        note = if ($extra.ContainsKey('note')) { $extra.note } else { $null }
    }
}
$generic = @('V3', 'V3_ifx')
$ifx = @('V3_ifx')
$rules = @(
    # ---- shared package documentation
    New-ClassRule $generic '^(README|DEPLOYMENT)\.md$' 'documentation' 'shared' 'package-guide' 'migrate-overlay' 'docs/authored/' 'P8' @('D4')
    New-ClassRule $generic '^architecture/[^/]+\.md$' 'documentation' 'shared' 'architecture-rationale' 'migrate-overlay' 'docs/authored/architecture/' 'P10' @() @{ dedupe = $true }
    New-ClassRule $generic '^rules/README\.md$' 'documentation' 'post' 'rule-authoring-guide' 'migrate-overlay' 'docs/authored/' 'P10' @()
    New-ClassRule $generic '^generated/README\.md$' 'documentation' 'shared' 'generated-output-guide' 'replace' 'docs/authored/ (generated outputs leave the package)' 'P7' @('D3')
    # ---- contracts, examples, templates
    New-ClassRule $generic '^contracts/[^/]+\.schema\.json$' 'authority' 'shared' 'schema' 'migrate' 'shared/contracts/' 'P10' @() @{ dedupe = $true }
    New-ClassRule $generic '^examples/minimal/views/' 'generated' 'bootstrap' 'example-view' 'migrate' 'examples/ (read-only generated view)' 'P8' @('D4')
    New-ClassRule $generic '^examples/' 'authority' 'bootstrap' 'example-profile' 'migrate' 'examples/' 'P10' @() @{ dedupe = $true }
    New-ClassRule $generic '^templates/dotnet/[^/]+\.in$' 'implementation' 'post' 'stage-gate-template' 'merge-into-v3' 'generators/stage-gate/ (V3)' 'P3' @('D1', 'D6', 'D15') @{ stages = @('post', 'diff'); dedupe = $true }
    New-ClassRule $generic '^templates/plan/' 'documentation' 'pre' 'plan-template' 'migrate-overlay' 'examples/plan/' 'P10' @() @{ dedupe = $true }
    New-ClassRule $ifx '^templates/ifx-layerguard/src/LayerGuard/GatePolicyBindings\.cs$' 'implementation' 'post' 'architecture-engine-ifx-binding' 'split' 'engine: V3 stages/post/gates/architecture/dotnet/; binding: V3_ifx stages/post/gates/architecture/' 'P6' @('D12') @{ note = 'Hardcodes runtime roles ifx-api, ifx-worker and ifx-all.' }
    New-ClassRule $ifx '^templates/ifx-layerguard/(LayerGuard\.slnx|src/)' 'implementation' 'post' 'architecture-engine' 'merge-into-v3' 'V3 stages/post/gates/architecture/dotnet/Guards.ArchitectureConformance/' 'P6' @('D6', 'D12')
    New-ClassRule $ifx '^templates/ifx-layerguard/tests/LayerGuard\.Tests/GatePolicyBindingTests\.cs$' 'implementation' 'post' 'architecture-engine-ifx-binding-test' 'split' 'synthetic test: V3; IFX binding test: V3_ifx stages/post/gates/architecture/' 'P6' @('D12') @{ note = 'Contains IFX project and type names.' }
    New-ClassRule $ifx '^templates/ifx-layerguard/tests/fixtures/' 'implementation' 'post' 'architecture-engine-fixture' 'merge-into-v3' 'V3 stages/post/gates/architecture/dotnet/Guards.ArchitectureConformance.Tests/fixtures/' 'P6' @('D12')
    New-ClassRule $ifx '^templates/ifx-layerguard/tests/' 'implementation' 'post' 'architecture-engine-test' 'merge-into-v3' 'V3 stages/post/gates/architecture/dotnet/Guards.ArchitectureConformance.Tests/' 'P6' @('D12')
    # ---- commands and engine scripts
    New-ClassRule $generic '^scripts/Invoke-V3\.ps1$' 'implementation' 'shared' 'public-command' 'migrate' 'commands/Invoke-V3.ps1 + engine/' 'P8' @('D1', 'D9', 'D15') @{ stages = @('pre', 'post', 'diff'); dedupe = $true }
    New-ClassRule $generic '^scripts/Invoke-V3Setup\.ps1$' 'implementation' 'bootstrap' 'public-command' 'migrate' 'commands/Invoke-V3Setup.ps1' 'P8' @('D1') @{ stages = @('bootstrap', 'analysis'); dedupe = $true }
    New-ClassRule $generic '^scripts/Invoke-V3Architecture\.ps1$' 'implementation' 'analysis' 'analysis-engine' 'migrate' 'engine/stages/analysis/ (Invoke-V3Setup Analysis)' 'P8' @('D1') @{ dedupe = $true }
    New-ClassRule $generic '^scripts/Invoke-V3Docs\.ps1$' 'implementation' 'shared' 'public-command' 'migrate' 'commands/Invoke-V3Docs.ps1 (Render/Check only)' 'P8' @('D1', 'D4') @{ dedupe = $true }
    New-ClassRule $ifx '^scripts/Invoke-IFXGuardrails\.ps1$' 'implementation' 'ci' 'public-command' 'migrate-overlay' 'commands/Invoke-IFXGuardrails.ps1 (thin wrapper)' 'P8' @('D9', 'D15') @{ stages = @('pre', 'post', 'diff', 'ci') }
    New-ClassRule $ifx '^scripts/Invoke-IFX\.ps1$' 'implementation' 'post' 'architecture-runner' 'merge-into-v3' 'engine/stages/post/ (Architecture Conformance runner)' 'P6' @('D12', 'D15')
    New-ClassRule $ifx '^scripts/Sync-IFXPolicyInputs\.ps1$' 'implementation' 'shared' 'maintenance-projection' 'migrate-overlay' 'maintenance/' 'P10' @('D13')
    New-ClassRule $generic '^hooks/[^/]+\.ps1$' 'implementation' 'pre' 'agent-hook' 'migrate' 'integrations/agents/' 'P10' @('D1') @{ dedupe = $true }
    New-ClassRule $generic '^hooks/README\.md$' 'documentation' 'pre' 'agent-hook-guide' 'migrate' 'integrations/agents/' 'P10' @() @{ dedupe = $true }
    New-ClassRule $generic '^skills/guard-bootstrap/' 'implementation' 'bootstrap' 'agent-skill' 'migrate-overlay' 'integrations/agents/' 'P10' @() @{ dedupe = $true }
    New-ClassRule $generic '^skills/guard-plan/' 'implementation' 'pre' 'agent-skill' 'migrate-overlay' 'integrations/agents/' 'P10' @() @{ dedupe = $true }
    New-ClassRule $ifx '^specialized/Invoke-IFXSpecialized\.ps1$' 'implementation' 'post' 'specialized-dispatcher' 'migrate-overlay' 'stages/post/gates/specialized/' 'P10' @('D15')
    New-ClassRule $ifx '^specialized/contracts/' 'authority' 'post' 'schema' 'migrate-overlay' 'stages/post/gates/specialized/contracts/' 'P10' @()
    New-ClassRule $ifx '^specialized/scripts/' 'implementation' 'post' 'specialized-detector' 'migrate-overlay' 'stages/post/gates/specialized/' 'P10' @('D15')
    New-ClassRule $ifx '^quality/' 'implementation' 'post' 'quality-gate' 'migrate-overlay' 'stages/post/gates/quality/' 'P10' @('D15')
    New-ClassRule $ifx '^history/Invoke-IFXHistoricalIntegrity\.ps1$' 'implementation' 'post' 'historical-integrity-gate' 'migrate-overlay' 'stages/post/gates/historical-integrity/' 'P10' @('D8', 'D15')
    New-ClassRule $ifx '^history/New-IFXHistoryManifest\.ps1$' 'implementation' 'post' 'maintenance-history-manifest' 'migrate-overlay' 'maintenance/' 'P10' @('D8')
    New-ClassRule $ifx '^history/manifest\.json$' 'authority' 'post' 'history-manifest' 'migrate-overlay' 'stages/post/gates/historical-integrity/' 'P10' @('D8')
    # ---- tests
    New-ClassRule $generic '^tests/Test-V3\.ps1$' 'implementation' 'shared' 'package-test' 'merge-into-v3' 'tests/ (V3)' 'P3' @('D1', 'D15') @{ stages = @('pre', 'post', 'diff'); dedupe = $true }
    New-ClassRule $generic '^tests/Test-V3ArchUnit\.ps1$' 'implementation' 'post' 'package-test' 'migrate' 'tests/post/' 'P10' @('D1') @{ dedupe = $true }
    New-ClassRule $generic '^tests/Test-V3Tools\.ps1$' 'implementation' 'bootstrap' 'package-test' 'migrate' 'tests/bootstrap/' 'P10' @('D1') @{ stages = @('bootstrap', 'analysis', 'shared'); dedupe = $true }
    New-ClassRule $ifx '^tests/Test-IFXTools\.ps1$' 'implementation' 'bootstrap' 'package-test' 'migrate-overlay' 'tests/ (overlay)' 'P10' @() @{ stages = @('bootstrap', 'analysis', 'shared') }
    New-ClassRule $ifx '^tests/Test-IFXPre\.ps1$' 'implementation' 'pre' 'package-test' 'migrate-overlay' 'tests/pre/' 'P10' @('D15')
    New-ClassRule $ifx '^tests/Test-IFX(AssemblyGuard|Package)\.ps1$' 'implementation' 'post' 'package-test' 'migrate-overlay' 'tests/post/' 'P10' @('D15')
    New-ClassRule $ifx '^tests/Test-IFXAuthorityProjection\.ps1$' 'implementation' 'shared' 'package-test' 'migrate-overlay' 'tests/support/ (authority projection)' 'P10' @('D13', 'D15')
    New-ClassRule $ifx '^tests/Test-IFXSpecializedContracts\.ps1$' 'implementation' 'post' 'package-test' 'migrate-overlay' 'tests/post/' 'P10' @('D15')
    New-ClassRule $ifx '^tests/Test-IFXHistoricalIntegrity\.ps1$' 'implementation' 'post' 'package-test' 'migrate-overlay' 'tests/post/' 'P10' @('D8', 'D15')
    New-ClassRule $ifx '^tests/Test-CutoverPreservation\.ps1$' 'implementation' 'ci' 'package-test' 'migrate-overlay' 'tests/ci/' 'P10' @('D15')
    # ---- IFX configuration authority
    New-ClassRule $ifx '^profiles/ifx/views/' 'generated' 'shared' 'profile-view' 'replace' 'docs/generated/ or read-only views (P8.7)' 'P8' @('D4')
    New-ClassRule $ifx '^profiles/ifx/README\.md$' 'documentation' 'shared' 'profile-guide' 'migrate-overlay' 'docs/authored/' 'P10' @()
    New-ClassRule $ifx '^profiles/ifx/profile\.json$' 'authority' 'shared' 'profile' 'migrate-overlay' 'guard-system.json / shared/' 'P10' @('D13')
    New-ClassRule $ifx '^profiles/ifx/project-map\.json$' 'authority' 'pre' 'project-map' 'migrate-overlay' 'stages/pre/' 'P10' @('D13')
    New-ClassRule $ifx '^profiles/ifx/tech-stack\.json$' 'authority' 'shared' 'toolchain' 'migrate-overlay' 'shared/toolchain.json' 'P10' @('D13')
    New-ClassRule $ifx '^profiles/ifx/rules/' 'authority' 'post' 'stage-rule' 'migrate-overlay' 'stages/post/rules/' 'P10' @('D13')
    New-ClassRule $ifx '^policy/README\.md$' 'documentation' 'post' 'policy-guide' 'migrate-overlay' 'docs/authored/' 'P10' @()
    New-ClassRule $ifx '^policy/authorities\.json$' 'authority' 'shared' 'authority-registry' 'migrate-overlay' 'shared/authorities/' 'P10' @('D13')
    New-ClassRule $ifx '^policy/baselines/' 'authority' 'post' 'architecture-baseline' 'migrate-overlay' 'stages/post/policy/baselines/' 'P10' @('D13')
    New-ClassRule $ifx '^policy/' 'authority' 'post' 'architecture-policy' 'migrate-overlay' 'stages/post/policy/' 'P10' @('D13')
    New-ClassRule $ifx '^ci/jobs\.json$' 'authority' 'ci' 'ci-job-declaration' 'replace' 'stages/ci/required-checks.json' 'P9' @('D11')
    New-ClassRule $ifx '^decisions/history/' 'authority' 'shared' 'decision' 'migrate-overlay' 'shared/decisions/' 'P10' @()
    # ---- generated copies
    New-ClassRule $ifx '^generated/stages/' 'generated' 'post' 'stage-gate-output' 'untrack' 'out-of-repository generation root (<gen>/v3-ifx/gates/stage/)' 'P7' @('D3', 'D14') @{ stages = @('post', 'diff') }
    New-ClassRule $ifx '^generated/dotnet/LayerGuard/' 'generated' 'post' 'layerguard-generated-copy' 'delete' '(removed; byte-identical to templates/ifx-layerguard)' 'P6' @('D12')
    # ---- analysis evidence (P0.2 lifecycle)
    New-ClassRule $ifx '^analysis/ifx/refactor-baseline/' 'evidence' 'analysis' 'refactor-baseline' 'migrate-overlay' 'stages/analysis/evidence/refactor-baseline/' 'P10' @('D7') @{ lifecycle = 'reviewed-input' }
    New-ClassRule $ifx '^analysis/ifx/(ARCHITECTURE|TECHNICAL)\.md$' 'evidence' 'analysis' 'reviewed-architecture-input' 'migrate-overlay' 'stages/analysis/evidence/' 'P8' @() @{ lifecycle = 'reviewed-input'; note = 'Seeded by Invoke-V3Architecture Draft, then human-reviewed; consumed by Review.' }
    New-ClassRule $ifx '^analysis/ifx/legacy-deletion-manifest\.json$' 'evidence' 'analysis' 'plan05-deletion-manifest' 'migrate-overlay' 'stages/analysis/evidence/' 'P8' @() @{ lifecycle = 'reviewed-input'; note = 'Consumed by Test-CutoverPreservation.ps1.' }
    New-ClassRule $ifx '^analysis/ifx/(cutover-baseline\.json|CUTOVER-BASELINE\.md|specialized-parity\.json)$' 'evidence' 'analysis' 'plan05-report-snapshot' 'migrate-overlay' 'stages/analysis/reports/' 'P8' @() @{ lifecycle = 'reviewed-snapshot' }
    New-ClassRule $ifx '^analysis/ifx/(inventory\.json|INVENTORY\.md|PROPOSAL\.md)$' 'evidence' 'analysis' 'analyze-output' 'replace' 'artifacts/guards/v3-ifx/analysis/' 'P8' @() @{ lifecycle = 'runtime-output'; note = 'Written by Invoke-V3Setup -Mode Analyze.' }
    New-ClassRule $ifx '^analysis/ifx/(architecture-review\.json|ARCHITECTURE-REVIEW\.md|review-profile/)' 'evidence' 'analysis' 'review-output' 'replace' 'artifacts/guards/v3-ifx/analysis/' 'P8' @() @{ lifecycle = 'runtime-output'; note = 'Written by Invoke-V3Architecture -Mode Review.' }
    # ---- plans
    New-ClassRule @('plans') '\.plan\.json$' 'authority' 'shared' 'formal-plan-sidecar' 'retain' 'docs/guards/plans/' '-' @()
    New-ClassRule @('plans') '\.md$' 'documentation' 'shared' 'plan-document' 'retain' 'docs/guards/plans/' '-' @()
    # ---- legacy MCP LayerGuard (preserved by Plan 05; outside Plan 06 migration scope)
    New-ClassRule @('mcp-layerguard') '^baselines/[^/]+\.json$' 'evidence' 'post' 'historical-layerguard-baseline' 'out-of-scope' 'mcp/LayerGuard/baselines/ (history manifest protected)' '-' @('D8')
    New-ClassRule @('mcp-layerguard') '\.md$' 'documentation' 'external' 'legacy-mcp-guide' 'out-of-scope' 'mcp/LayerGuard/' '-' @()
    New-ClassRule @('mcp-layerguard') '^(LayerGuard\.slnx|src/|tests/)' 'implementation' 'external' 'legacy-mcp-server' 'out-of-scope' 'mcp/LayerGuard/' '-' @() @{ note = 'src tree is identical to V3_ifx templates/ifx-layerguard/src; tests differ only in GatePolicyBindingTests.cs.' }
    # ---- GitHub activation
    New-ClassRule @('github') '^workflows/v3-ifx-guardrails\.yml$' 'activation' 'ci' 'workflow' 'retain' '.github/workflows/ (activated copy of V3_ifx stages/ci/workflow.template.yml)' 'P9' @('D5', 'D9', 'D11')
    New-ClassRule @('github') '^CODEOWNERS$' 'activation' 'ci' 'review-routing' 'retain' '.github/CODEOWNERS (guard managed block)' 'P9' @('D5', 'D11')
    New-ClassRule @('github') '' 'documentation' 'external' 'repository-collaboration' 'out-of-scope' '.github/' '-' @()
)

$byPath = @{}
foreach ($entry in $entries) { $byPath[$entry.path] = $entry }

$files = [Collections.Generic.List[object]]::new()
$unclassified = [Collections.Generic.List[string]]::new()
foreach ($entry in $entries) {
    $ruleScope = if ($entry.scope -eq 'V3_backup') { 'V3' } else { $entry.scope }
    $rule = $rules | Where-Object { $ruleScope -in $_.scopes -and $entry.relative -match $_.pattern } | Select-Object -First 1
    if ($null -eq $rule) { $unclassified.Add($entry.path); continue }
    $disposition = $rule.disposition; $target = $rule.target; $phase = $rule.phase; $decisions = @($rule.decisions)
    $identicalTo = $null
    if ($entry.scope -eq 'V3_backup') {
        $disposition = 'delete'; $target = '(removed; V3_backup is retired)'; $phase = 'P10.5'; $decisions = @('D2')
        $identicalTo = "docs/guards/V3/$($entry.relative)"
    } elseif ($entry.scope -eq 'V3' -and $disposition -in @('merge-into-v3', 'migrate-overlay')) {
        # V3 is the canonical package: it receives merges and keeps generic documents, so its own files migrate in place.
        $disposition = 'migrate'
    } elseif ($entry.scope -eq 'V3_ifx' -and $rule.dedupe) {
        $counterpart = "docs/guards/V3/$($entry.relative)"
        if ($byPath.ContainsKey($counterpart) -and $byPath[$counterpart].objectId -eq $entry.objectId) {
            $disposition = 'delete-duplicate'; $target = "(removed; canonical copy is $counterpart)"; $phase = 'P7.5'; $decisions = @('D1')
            $identicalTo = $counterpart
        } elseif ($disposition -eq 'migrate') {
            # Generic capability that exists only in, or diverged in, the IFX fork belongs in V3 (D1, D7).
            $disposition = 'merge-into-v3'
        }
    }
    $owner = Get-Owner $entry.path
    $files.Add([ordered]@{
        path = $entry.path; scope = $entry.scope; mode = $entry.mode; type = $entry.type; objectId = $entry.objectId; size = $entry.size
        kind = $rule.kind; stage = $rule.stage; stages = @($rule.stages); role = $rule.role
        lifecycle = $rule.lifecycle; owner = $owner.owners; ownerRule = $owner.rule
        disposition = $disposition; target = $target; phase = $phase; decisions = $decisions
        identicalTo = $identicalTo; note = $rule.note
    })
}
if ($unclassified.Count -gt 0) { throw "Unclassified baseline files: $($unclassified -join ', ')" }

function Count-By([object[]] $items, [string] $property) {
    $result = [ordered]@{}
    foreach ($key in (Sort-Ordinal @($items | ForEach-Object { [string]$_[$property] } | Select-Object -Unique))) {
        $result[$key] = @($items | Where-Object { [string]$_[$property] -eq $key }).Count
    }
    return $result
}
$fileArray = Sort-ByOrdinal @($files) { param($x) $x.path }
$scopeSummary = [ordered]@{}
foreach ($scope in $scopes.Keys) {
    $inScope = @($fileArray | Where-Object { $_.scope -eq $scope })
    $scopeSummary[$scope] = [ordered]@{
        prefix = $scopes[$scope]; files = $inScope.Count
        treeId = (Invoke-Git rev-parse "${commit}:$($scopes[$scope].TrimEnd('/'))").Trim()
        kinds = Count-By $inScope 'kind'; dispositions = Count-By $inScope 'disposition'
    }
}
Write-Json 'inventory.json' ([ordered]@{
    formatVersion = 1; baselineCommit = $commit; generatedBy = $generatedBy
    classification = [ordered]@{
        kinds = @('authority', 'implementation', 'generated', 'activation', 'evidence', 'documentation')
        stages = @('bootstrap', 'analysis', 'pre', 'post', 'diff', 'ci', 'shared', 'external')
        lifecycles = @('reviewed-input', 'reviewed-snapshot', 'runtime-output')
        unclassified = 0
    }
    scopes = $scopeSummary; files = $fileArray
})

# ---------------------------------------------------------------- duplicates
$blobGroups = @($fileArray | Where-Object { $_.type -eq 'blob' } | Group-Object { $_.objectId } | Where-Object { $_.Count -gt 1 } | ForEach-Object {
    [ordered]@{ objectId = $_.Name; paths = (Sort-Ordinal @($_.Group | ForEach-Object { $_.path })) }
})
$blobGroups = Sort-ByOrdinal $blobGroups { param($x) $x.paths[0] }
$treePairs = @(
    @('docs/guards/V3', 'docs/guards/V3_backup'),
    @('docs/guards/V3_ifx/templates/ifx-layerguard', 'docs/guards/V3_ifx/generated/dotnet/LayerGuard'),
    @('docs/guards/V3_ifx/templates/ifx-layerguard/src', 'mcp/LayerGuard/src'),
    @('docs/guards/V3_ifx/templates/ifx-layerguard/tests', 'mcp/LayerGuard/tests')
) | ForEach-Object {
    $left = (Invoke-Git rev-parse "${commit}:$($_[0])").Trim(); $right = (Invoke-Git rev-parse "${commit}:$($_[1])").Trim()
    $count = @((Invoke-Git ls-tree -r --name-only $commit -- "$($_[0])/")).Count
    $differing = if ($left -eq $right) { @() } else { Sort-Ordinal @(Invoke-Git diff --name-only $left $right) }
    [ordered]@{ left = $_[0]; right = $_[1]; leftTreeId = $left; rightTreeId = $right; identical = ($left -eq $right); leftFiles = $count; differingFiles = $differing }
}
Write-Json 'duplicates.json' ([ordered]@{
    formatVersion = 1; baselineCommit = $commit; generatedBy = $generatedBy
    treePairs = $treePairs; duplicateBlobGroups = $blobGroups.Count; duplicateBlobs = $blobGroups
})

# ---------------------------------------------------------------- V3 vs V3_ifx divergence (P0.6)
$divergenceClass = @{
    'templates/dotnet/GuardTests.cs.in' = [ordered]@{ category = 'generic-hardening+ifx-specific'; detail = 'Diff merge-base verification, protected deletion/rename detection and empty changed-set failure are generic hardening; the hardcoded IsProtectedGuardPath list is IFX-specific.'; action = 'P3.1-P3.2 merge hardening into V3 and parameterize protected paths' }
    'tests/Test-V3.ps1' = [ordered]@{ category = 'generic-hardening+ifx-specific'; detail = 'Exit-code normalization ($global:LASTEXITCODE = 0) is generic; copying docs/Directory.Packages.props and switching NuGet.Offline.Config to nuget.org NuGet.Test.Config are IFX host/environment choices.'; action = 'P3.3 decide the NuGet source and align with V3 build/NuGet.config; P5 removes the host props dependency' }
    'README.md' = [ordered]@{ category = 'ifx-specific'; detail = 'IFX package guide.'; action = 'P8 docs/authored overlay' }
    'DEPLOYMENT.md' = [ordered]@{ category = 'ifx-specific'; detail = 'IFX deployment and CI evidence.'; action = 'P8 docs/authored overlay' }
    'architecture/ARCHITECTURE.md' = [ordered]@{ category = 'ifx-specific'; detail = 'Describes the IFX fork configuration instead of Init/Analyze defaults.'; action = 'P10 docs/authored overlay' }
    'architecture/TECHNICAL.md' = [ordered]@{ category = 'ifx-specific'; detail = 'Describes checked-in IFX outputs and the Invoke-IFX LayerGuard generator.'; action = 'P10 docs/authored overlay' }
    'generated/README.md' = [ordered]@{ category = 'ifx-specific'; detail = 'Describes checked-in IFX generated projects.'; action = 'P7 replace (generated outputs leave the package)' }
    'rules/README.md' = [ordered]@{ category = 'ifx-specific'; detail = 'IFX rule authoring guide including policy/layerguard.json ownership.'; action = 'P10 docs/authored overlay' }
    'skills/guard-bootstrap/SKILL.md' = [ordered]@{ category = 'ifx-specific'; detail = 'Points at profiles/ifx and V3_ifx documents.'; action = 'P10 integrations/agents overlay' }
    'skills/guard-plan/SKILL.md' = [ordered]@{ category = 'ifx-specific'; detail = 'Points at profiles/ifx and policy/layerguard.json.'; action = 'P10 integrations/agents overlay' }
    'templates/plan/README.md' = [ordered]@{ category = 'ifx-specific'; detail = 'References IFX tech-stack command IDs.'; action = 'P10 examples/plan overlay' }
    'templates/plan/20260914-example.plan.json' = [ordered]@{ category = 'ifx-specific'; detail = 'Example sidecar uses IFX paths, areas, rules and commands instead of the minimal sample profile.'; action = 'P10 examples/plan overlay' }
}
$v3Files = @($fileArray | Where-Object { $_.scope -eq 'V3' })
$divergence = @(foreach ($file in $v3Files) {
    $relative = $file.path.Substring($scopes['V3'].Length)
    $counterpart = "docs/guards/V3_ifx/$relative"
    if (-not $byPath.ContainsKey($counterpart)) {
        [ordered]@{ path = $relative; status = 'v3-only'; v3ObjectId = $file.objectId; ifxObjectId = $null; numstat = $null; category = 'generic'; detail = 'Present only in V3.'; action = 'keep in V3' }
        continue
    }
    $other = $byPath[$counterpart]
    if ($other.objectId -eq $file.objectId) {
        [ordered]@{ path = $relative; status = 'identical'; v3ObjectId = $file.objectId; ifxObjectId = $other.objectId; numstat = $null; category = 'generic'; detail = 'Byte-identical copy.'; action = 'P7.5 delete V3_ifx copy' }
        continue
    }
    $numstat = ((Invoke-Git diff --numstat $file.objectId $other.objectId) -join '') -split '\s+'
    if (-not $divergenceClass.ContainsKey($relative)) { throw "Unclassified V3/V3_ifx divergence: $relative" }
    $class = $divergenceClass[$relative]
    [ordered]@{ path = $relative; status = 'diverged'; v3ObjectId = $file.objectId; ifxObjectId = $other.objectId; numstat = [ordered]@{ added = [int]$numstat[0]; deleted = [int]$numstat[1] }; category = $class.category; detail = $class.detail; action = $class.action }
})
$ifxOnly = @($fileArray | Where-Object { $_.scope -eq 'V3_ifx' -and -not $byPath.ContainsKey("docs/guards/V3/$($_.path.Substring($scopes['V3_ifx'].Length))") })
$ifxOnlyByDirectory = [ordered]@{}
foreach ($file in $ifxOnly) {
    $relative = $file.path.Substring($scopes['V3_ifx'].Length)
    $directory = if ($relative.Contains('/')) { ($relative -split '/')[0] + '/' } else { $relative }
    if (-not $ifxOnlyByDirectory.Contains($directory)) { $ifxOnlyByDirectory[$directory] = 0 }
    $ifxOnlyByDirectory[$directory]++
}
Write-Json 'v3-divergence.json' ([ordered]@{
    formatVersion = 1; baselineCommit = $commit; generatedBy = $generatedBy
    summary = [ordered]@{
        v3Files = $v3Files.Count
        identical = @($divergence | Where-Object { $_.status -eq 'identical' }).Count
        diverged = @($divergence | Where-Object { $_.status -eq 'diverged' }).Count
        v3Only = @($divergence | Where-Object { $_.status -eq 'v3-only' }).Count
        ifxOnly = $ifxOnly.Count
    }
    files = $divergence; ifxOnlyByTopLevel = $ifxOnlyByDirectory
})

# ---------------------------------------------------------------- call graph (P0.3)
$executables = @($fileArray | Where-Object { $_.scope -in @('V3', 'V3_ifx') -and $_.path.EndsWith('.ps1') })
$content = @{}
foreach ($executable in $executables) { $content[$executable.path] = Show-Blob $executable.path }
$dotnetProjects = @($fileArray | Where-Object { $_.scope -in @('V3', 'V3_ifx') -and $_.path -match '\.(csproj|slnx)(\.in)?$' -and $_.path -notmatch '/tests/fixtures/' })

$edges = [Collections.Generic.List[object]]::new()
foreach ($executable in $executables) {
    $tokens = [Regex]::Matches($content[$executable.path], '[A-Za-z0-9][A-Za-z0-9.-]*\.(ps1|csproj|slnx)') | ForEach-Object { $_.Value } | Select-Object -Unique
    foreach ($token in $tokens) {
        if ($token -eq [IO.Path]::GetFileName($executable.path)) { continue }
        $candidates = @($executables + $dotnetProjects | Where-Object { $_.scope -eq $executable.scope -and ([IO.Path]::GetFileName($_.path) -eq $token -or [IO.Path]::GetFileName($_.path) -eq "$token.in") })
        if ($candidates.Count -eq 0) { continue }
        if ($candidates.Count -gt 1) {
            $preferred = @($candidates | Where-Object { $_.path -notmatch '/generated/' })
            if ($preferred.Count -eq 1) { $candidates = $preferred }
        }
        foreach ($candidate in $candidates) { $edges.Add([ordered]@{ from = $executable.path; to = $candidate.path; via = $token }) }
    }
}

# CI jobs and their first executable entry
$workflowLines = (Show-Blob '.github/workflows/v3-ifx-guardrails.yml') -split "`n"
$jobs = [ordered]@{}
$currentJob = $null; $inJobs = $false
foreach ($line in $workflowLines) {
    if ($line -match '^jobs:\s*$') { $inJobs = $true; continue }
    if (-not $inJobs) { continue }
    if ($line -match '^  ([a-z0-9-]+):\s*$') { $currentJob = $Matches[1]; $jobs[$currentJob] = [ordered]@{ checkNames = @(); invocations = [Collections.Generic.List[string]]::new() }; continue }
    if ($null -eq $currentJob) { continue }
    if ($line -match '^    name:\s*(.+?)\s*$' -and $jobs[$currentJob].checkNames.Count -eq 0) { $jobs[$currentJob].checkNames = @($Matches[1]) }
    foreach ($match in [Regex]::Matches($line, '\./(docs/guards/[^\s''"]+\.ps1)')) { $jobs[$currentJob].invocations.Add($match.Groups[1].Value) }
}
$ciJobs = @(foreach ($job in $jobs.Keys) {
    $names = @($jobs[$job].checkNames)
    if ($names.Count -eq 1 -and $names[0] -match '\$\{\{\s*matrix\.os\s*\}\}') {
        $names = @('ubuntu-latest', 'windows-latest' | ForEach-Object { $jobs[$job].checkNames[0] -replace '\$\{\{\s*matrix\.os\s*\}\}', $_ })
    }
    $invocations = @($jobs[$job].invocations)
    [ordered]@{ jobId = $job; checkNames = $names; firstExecutableEntry = if ($invocations.Count -gt 0) { $invocations[0] } else { $null }; directInvocations = @($invocations | Select-Object -Unique); entrySource = 'head checkout (baseline)' }
})
$ciRoots = @($ciJobs | ForEach-Object { $_.directInvocations } | Select-Object -Unique)

$techStack = (Show-Blob 'docs/guards/V3_ifx/profiles/ifx/tech-stack.json') | ConvertFrom-Json
$commandRoots = @($techStack.commands | ForEach-Object { @($_.arguments | Where-Object { $_ -like '*.ps1' }) } | Select-Object -Unique)
$documented = [ordered]@{}
foreach ($doc in @($fileArray | Where-Object { $_.scope -in @('V3', 'V3_ifx') -and ($_.path -match '/(README|DEPLOYMENT)\.md$' -or $_.path -match '/SKILL\.md$') })) {
    $text = Show-Blob $doc.path
    foreach ($token in ([Regex]::Matches($text, '[A-Za-z0-9-]+\.ps1') | ForEach-Object { $_.Value } | Select-Object -Unique)) {
        foreach ($target in @($executables | Where-Object { $_.scope -eq $doc.scope -and [IO.Path]::GetFileName($_.path) -eq $token })) {
            if (-not $documented.Contains($target.path)) { $documented[$target.path] = [Collections.Generic.List[string]]::new() }
            $documented[$target.path].Add($doc.path)
        }
    }
}

function Get-Reachable([string[]] $starts, [string[]] $stopAt = @()) {
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $queue = [Collections.Generic.Queue[string]]::new()
    foreach ($start in $starts) { if ($seen.Add($start)) { $queue.Enqueue($start) } }
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if ($current -in $stopAt) { continue }
        foreach ($edge in @($edges | Where-Object { $_.from -eq $current })) { if ($seen.Add($edge.to)) { $queue.Enqueue($edge.to) } }
    }
    return $seen
}
$testFiles = @($executables | Where-Object { $_.role -eq 'package-test' } | ForEach-Object { $_.path })
$ciReachable = Get-Reachable $ciRoots
# Verdict chain: CI roots and their callees, without following calls made by package tests.
$verdictReachable = Get-Reachable $ciRoots $testFiles
$nodes = @(foreach ($executable in $executables) {
    $path = $executable.path
    $callers = Sort-Ordinal @($edges | Where-Object { $_.to -eq $path } | ForEach-Object { $_.from } | Select-Object -Unique)
    $audiences = [Collections.Generic.List[string]]::new()
    if ($path -in $ciRoots) { $audiences.Add('ci') }
    if ($path -in $commandRoots) { $audiences.Add('validation-command') }
    if ($documented.Contains($path)) {
        if (@($documented[$path] | Where-Object { $_ -match 'SKILL\.md$' }).Count -gt 0) { $audiences.Add('agent') }
        if (@($documented[$path] | Where-Object { $_ -notmatch 'SKILL\.md$' }).Count -gt 0) { $audiences.Add('human') }
    }
    $testCallers = @($callers | Where-Object { $_ -in $testFiles })
    $exposure = if ($audiences.Count -gt 0) { 'public' } elseif ($callers.Count -gt 0 -and $testCallers.Count -eq $callers.Count) { 'test-only' } elseif ($callers.Count -gt 0) { 'internal' } else { 'unreferenced' }
    [ordered]@{
        path = $path; scope = $executable.scope; role = $executable.role; exposure = $exposure; audiences = @($audiences)
        ciReachable = $ciReachable.Contains($path); verdictChain = $verdictReachable.Contains($path)
        calls = Sort-Ordinal @($edges | Where-Object { $_.from -eq $path } | ForEach-Object { $_.to } | Select-Object -Unique)
        calledBy = $callers; documentedIn = if ($documented.Contains($path)) { Sort-Ordinal @($documented[$path]) } else { @() }
    }
})
Write-Json 'call-graph.json' ([ordered]@{
    formatVersion = 1; baselineCommit = $commit; generatedBy = $generatedBy
    method = 'Static: script and project file names referenced in PowerShell source, resolved within the same package; CI entries parsed from the baseline workflow; audiences from tech-stack commands, README/DEPLOYMENT and SKILL documents. ciReachable follows every edge from CI entries; verdictChain stops at package tests, so it lists only executables whose behavior decides a check verdict.'
    ciJobs = $ciJobs
    summary = [ordered]@{
        executables = $nodes.Count
        public = @($nodes | Where-Object { $_.exposure -eq 'public' }).Count
        internal = @($nodes | Where-Object { $_.exposure -eq 'internal' }).Count
        testOnly = @($nodes | Where-Object { $_.exposure -eq 'test-only' }).Count
        unreferenced = @($nodes | Where-Object { $_.exposure -eq 'unreferenced' }).Count
        ciReachable = @($nodes | Where-Object { $_.ciReachable }).Count
        verdictChain = @($nodes | Where-Object { $_.verdictChain }).Count
        v3PackageCiReachable = @($nodes | Where-Object { $_.scope -eq 'V3' -and $_.ciReachable }).Count
    }
    nodes = Sort-ByOrdinal $nodes { param($x) $x.path }
    edges = Sort-ByOrdinal @($edges) { param($x) "$($x.from)|$($x.to)" }
    notCiReachable = Sort-Ordinal @($nodes | Where-Object { -not $_.ciReachable } | ForEach-Object { $_.path })
})

# ---------------------------------------------------------------- initial TCB component list (P0.3, Plan 06 §11.5)
$parityDefault = 'On the fixed corpus of existing fixtures and baseline inputs: identical command contract, fail-closed categories, summary/report schema and blocking verdict.'
$tcbComponents = @(
    [ordered]@{ id = 'tcb.entry.ifx-guardrails'; type = 'public-entry-orchestrator'; paths = @('docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1'); validationSuite = @('all 13 required checks', 'docs/guards/V3_ifx/tests/Test-IFXPackage.ps1'); parityContract = $parityDefault; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.engine.v3-runner'; type = 'engine-dispatcher'; paths = @('docs/guards/V3_ifx/scripts/Invoke-V3.ps1'); validationSuite = @('docs/guards/V3_ifx/tests/Test-V3.ps1', 'docs/guards/V3_ifx/tests/Test-IFXPre.ps1', 'v3-pre-diff', 'v3-cross-platform-*'); parityContract = $parityDefault; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.generator.stage-gate'; type = 'generator-template'; paths = @('docs/guards/V3_ifx/templates/dotnet/'); validationSuite = @('docs/guards/V3_ifx/tests/Test-V3.ps1', 'Invoke-V3.ps1 -Mode Check', 'v3-pre-diff'); parityContract = $parityDefault; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.generated.stage-gate'; type = 'generated-candidate'; paths = @('docs/guards/V3_ifx/generated/stages/'); validationSuite = @('Invoke-V3.ps1 -Mode Check'); parityContract = 'Byte-identical regeneration from tcb.generator.stage-gate and the profile.'; allowedChange = 'regenerate-only; untracked in P7 (D3)' }
    [ordered]@{ id = 'tcb.engine.architecture-runner'; type = 'engine-runner'; paths = @('docs/guards/V3_ifx/scripts/Invoke-IFX.ps1', 'docs/guards/V3_ifx/scripts/Sync-IFXPolicyInputs.ps1'); validationSuite = @('docs/guards/V3_ifx/tests/Test-IFXPackage.ps1', 'docs/guards/V3_ifx/tests/Test-IFXAuthorityProjection.ps1', 'v3-architecture'); parityContract = $parityDefault; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.engine.architecture-conformance'; type = 'dotnet-engine'; paths = @('docs/guards/V3_ifx/templates/ifx-layerguard/LayerGuard.slnx', 'docs/guards/V3_ifx/templates/ifx-layerguard/src/'); validationSuite = @('docs/guards/V3_ifx/templates/ifx-layerguard/tests/', 'Invoke-IFX.ps1 -Mode Test'); parityContract = $parityDefault; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.validation.architecture-conformance'; type = 'base-owned-tests-and-fixtures'; paths = @('docs/guards/V3_ifx/templates/ifx-layerguard/tests/'); validationSuite = @('Invoke-IFX.ps1 -Mode Test'); parityContract = 'Test and fixture set may only grow; removing or weakening an assertion is a non-equivalent change.'; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.generated.architecture-conformance'; type = 'generated-candidate'; paths = @('docs/guards/V3_ifx/generated/dotnet/LayerGuard/'); validationSuite = @('Invoke-IFX.ps1 -Mode Check'); parityContract = 'Byte-identical copy of templates/ifx-layerguard.'; allowedChange = 'delete in P6.1 (D12)' }
    [ordered]@{ id = 'tcb.engine.specialized'; type = 'engine-detectors'; paths = @('docs/guards/V3_ifx/specialized/Invoke-IFXSpecialized.ps1', 'docs/guards/V3_ifx/specialized/scripts/', 'docs/guards/V3_ifx/specialized/contracts/'); validationSuite = @('docs/guards/V3_ifx/tests/Test-IFXSpecializedContracts.ps1', 'v3-specialized-*'); parityContract = $parityDefault; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.engine.quality'; type = 'engine-gates'; paths = @('docs/guards/V3_ifx/quality/'); validationSuite = @('docs/guards/V3_ifx/tests/Test-IFXPackage.ps1', 'docs/guards/V3_ifx/tests/Test-IFXAssemblyGuard.ps1', 'v3-quality-*'); parityContract = $parityDefault; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.engine.historical-integrity'; type = 'engine-gate'; paths = @('docs/guards/V3_ifx/history/Invoke-IFXHistoricalIntegrity.ps1'); validationSuite = @('docs/guards/V3_ifx/tests/Test-IFXHistoricalIntegrity.ps1', 'v3-historical-integrity'); parityContract = $parityDefault; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.contracts'; type = 'contracts'; paths = @('docs/guards/V3_ifx/contracts/'); validationSuite = @('Invoke-IFXGuardrails.ps1 -Mode Validate', 'docs/guards/V3_ifx/tests/Test-IFXPre.ps1'); parityContract = 'Schemas may only tighten or stay equivalent for existing valid documents.'; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.validation.package-tests'; type = 'base-owned-tests'; paths = @('docs/guards/V3_ifx/tests/Test-IFXPre.ps1', 'docs/guards/V3_ifx/tests/Test-IFXAssemblyGuard.ps1', 'docs/guards/V3_ifx/tests/Test-IFXAuthorityProjection.ps1', 'docs/guards/V3_ifx/tests/Test-IFXSpecializedContracts.ps1', 'docs/guards/V3_ifx/tests/Test-IFXHistoricalIntegrity.ps1', 'docs/guards/V3_ifx/tests/Test-CutoverPreservation.ps1', 'docs/guards/V3_ifx/tests/Test-IFXPackage.ps1', 'docs/guards/V3_ifx/tests/Test-V3.ps1'); validationSuite = @('v3-architecture', 'v3-cross-platform-*'); parityContract = 'Assertions and negative controls may only grow.'; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.activation.ci'; type = 'activation-contract'; paths = @('.github/workflows/v3-ifx-guardrails.yml', '.github/CODEOWNERS', 'docs/guards/V3_ifx/ci/jobs.json'); validationSuite = @('P1.3 ruleset verifier', 'v3-pre-diff'); parityContract = '13 required check names, job DAG and trigger semantics unchanged (Plan 06 §10.3).'; allowedChange = 'change-trusted-base; workflow definition itself is outside the trust boundary (O1)' }
    [ordered]@{ id = 'tcb.build.host-inherited'; type = 'build-baseline (current, inherited)'; paths = @('Directory.Build.props', 'Directory.Packages.props', 'docs/Directory.Packages.props'); validationSuite = @('P5 locked restore and import allowlist'); parityContract = 'Security properties may not weaken; replaced by V3 build/ in P5 (D14).'; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.manifest'; type = 'trust-root (planned)'; paths = @(); plannedPaths = @('docs/guards/V3/shared/trusted-components.json'); validationSuite = @('P1.5 schema', 'P2.6-P2.7 negative controls'); parityContract = 'Self-protecting: includes itself, its schema and verifier.'; allowedChange = 'change-trusted-base' }
    [ordered]@{ id = 'tcb.build.package-local'; type = 'build-baseline (planned)'; paths = @(); plannedPaths = @('docs/guards/V3/build/'); validationSuite = @('P5.3-P5.6'); parityContract = 'Not weaker than tcb.build.host-inherited.'; allowedChange = 'change-trusted-base' }
)
$tcbAssignments = @{}
$tcbProblems = [Collections.Generic.List[string]]::new()
foreach ($component in $tcbComponents) {
    foreach ($path in $component.paths) {
        $isDirectory = $path.EndsWith('/')
        $exists = if ($isDirectory) { @($fileArray | Where-Object { $_.path.StartsWith($path) }).Count -gt 0 } else { $byPath.ContainsKey($path) -or ((& git -C $root cat-file -t "${commit}:$path" 2>$null) -eq 'blob') }
        if (-not $exists) { $tcbProblems.Add("Missing TCB path $path ($($component.id))") }
        foreach ($file in @($fileArray | Where-Object { if ($isDirectory) { $_.path.StartsWith($path) } else { $_.path -eq $path } })) {
            if ($tcbAssignments.ContainsKey($file.path)) { $tcbProblems.Add("TCB overlap on $($file.path): $($tcbAssignments[$file.path]) and $($component.id)") }
            $tcbAssignments[$file.path] = $component.id
        }
    }
}
# Every executable on a CI verdict chain must belong to a TCB component.
foreach ($node in @($nodes | Where-Object { $_.verdictChain })) {
    if (-not $tcbAssignments.ContainsKey($node.path)) { $tcbProblems.Add("Verdict-chain executable outside TCB: $($node.path)") }
}
if ($tcbProblems.Count -gt 0) { throw ($tcbProblems -join [Environment]::NewLine) }
Write-Json 'tcb.json' ([ordered]@{
    formatVersion = 1; baselineCommit = $commit; generatedBy = $generatedBy
    status = 'initial-frozen-list (P0.3); materialized as shared/trusted-components.json in P1.5'
    note = 'At the baseline every TCB component executes from the PR head checkout; trusted base execution starts in P2.'
    components = $tcbComponents
    coverage = [ordered]@{ assignedInventoryFiles = $tcbAssignments.Count; verdictChainExecutablesOutsideTcb = 0 }
})

# ---------------------------------------------------------------- policy/config change frequency (P0.9)
$categories = [ordered]@{
    'profiles/ifx/rules'          = 'docs/guards/V3_ifx/profiles/ifx/rules/'
    'profiles/ifx/project-map'    = 'docs/guards/V3_ifx/profiles/ifx/project-map.json'
    'profiles/ifx/tech-stack'     = 'docs/guards/V3_ifx/profiles/ifx/tech-stack.json'
    'profiles/ifx/profile'        = 'docs/guards/V3_ifx/profiles/ifx/profile.json'
    'policy/layerguard'           = 'docs/guards/V3_ifx/policy/layerguard.json'
    'policy/authorities'          = 'docs/guards/V3_ifx/policy/authorities.json'
    'policy/baselines'            = 'docs/guards/V3_ifx/policy/baselines/'
    'policy/g03'                  = 'docs/guards/V3_ifx/policy/g03/'
    'policy/g04/bindings'         = 'docs/guards/V3_ifx/policy/g04/bindings/'
    'policy/g04/runtime-manifest' = 'docs/guards/V3_ifx/policy/g04/runtime-manifest.json'
    'policy/g05'                  = 'docs/guards/V3_ifx/policy/g05/'
    'history/manifest'            = 'docs/guards/V3_ifx/history/manifest.json'
    'ci/jobs'                     = 'docs/guards/V3_ifx/ci/jobs.json'
    'contracts'                   = 'docs/guards/V3_ifx/contracts/'
    'specialized/contracts'       = 'docs/guards/V3_ifx/specialized/contracts/'
}
$log = (Invoke-Git log --no-merges --format='@@%H' --name-only "--since=$FrequencySince" $commit -- 'docs/guards/V3_ifx') -join "`n"
$commits = @($log -split '@@' | Where-Object { $_.Trim() } | ForEach-Object {
    $lines = @($_ -split "`n" | Where-Object { $_.Trim() })
    [pscustomobject]@{ sha = $lines[0].Trim(); files = @($lines | Select-Object -Skip 1) }
})
$frequency = @(foreach ($name in $categories.Keys) {
    $prefix = $categories[$name]
    $touching = @($commits | Where-Object { @($_.files | Where-Object { $_ -eq $prefix -or ($prefix.EndsWith('/') -and $_.StartsWith($prefix)) }).Count -gt 0 })
    $fileChanges = ($commits | ForEach-Object { @($_.files | Where-Object { $_ -eq $prefix -or ($prefix.EndsWith('/') -and $_.StartsWith($prefix)) }).Count } | Measure-Object -Sum).Sum
    [ordered]@{ category = $name; path = $prefix; commits = $touching.Count; fileChanges = [int]$fileChanges }
})
$frequency = Sort-ByOrdinal $frequency { param($x) '{0:D6}|{1:D6}|{2}' -f (999999 - $x.commits), (999999 - $x.fileChanges), $x.category }
Write-Json 'change-frequency.json' ([ordered]@{
    formatVersion = 1; baselineCommit = $commit; generatedBy = $generatedBy
    window = [ordered]@{ since = $FrequencySince; until = $commit; path = 'docs/guards/V3_ifx'; mergesExcluded = $true }
    limitation = 'Counts commits at current V3_ifx paths only; history before files moved into V3_ifx (Plan 05 cutover) is not followed.'
    categories = $frequency
    comparatorOrder = @($frequency | Where-Object { $_.commits -gt 0 } | ForEach-Object { $_.category })
})

Write-Host "Refactor baseline $(if ($Check) { 'checked' } else { 'written' }): $output ($($fileArray.Count) files, $($nodes.Count) executables, $($tcbComponents.Count) TCB components)"
