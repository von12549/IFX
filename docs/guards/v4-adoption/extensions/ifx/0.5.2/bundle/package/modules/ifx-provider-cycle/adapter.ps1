Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$claimId = 'IFX.C1.PROVIDER_CYCLE'
$ruleId = 'PROVIDER-CYCLE'
$detectorId = 'ifx-provider-cycle'
$matched = 0
$findings = [Collections.Generic.List[object]]::new()

function Write-Result([string] $Status, [string] $Category, [string] $Message = '') {
    $result = [ordered]@{
        formatVersion = 1
        status = $Status
        exitCategory = $Category
        findings = @($findings.ToArray())
        coverage = @([ordered]@{ claimId = $claimId; matched = $matched; minimum = 1 })
    }
    if ($Message) { $result.message = $Message }
    $result | ConvertTo-Json -Depth 20 -Compress
}

function Stop-Adapter([string] $Category, [string] $Message) {
    Write-Result 'error' $Category $Message
    exit 0
}

function Visit-Node([string] $Node) {
    if ($active.Contains($Node)) {
        $start = -1
        for ($index = 0; $index -lt $path.Count; $index++) {
            if ([StringComparer]::OrdinalIgnoreCase.Equals($path[$index], $Node)) { $start = $index; break }
        }
        if ($start -lt 0) { Stop-Adapter 'integrity-failure' 'Cycle path is inconsistent.' }
        $cycle = @($path.GetRange($start, $path.Count - $start).ToArray()) + @($Node)
        $sorted = [string[]]@($cycle)
        [Array]::Sort($sorted, [StringComparer]::OrdinalIgnoreCase)
        $key = $sorted -join '|'
        if ($emitted.Add($key)) { $cycles.Add($cycle) }
        return
    }
    [void]$active.Add($Node)
    $path.Add($Node)
    if ($graph.ContainsKey($Node)) {
        foreach ($target in $graph[$Node]) { Visit-Node $target }
    }
    $path.RemoveAt($path.Count - 1)
    [void]$active.Remove($Node)
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) {
    Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.'
}
try { $payload = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($payload.formatVersion -ne 1 -or $payload.stage -cne 'pre' -or
    @($payload.config.enabledClaims).Count -ne 1 -or
    $payload.config.enabledClaims[0] -cne $claimId) {
    Stop-Adapter 'invalid-input' 'Stage or enabled claim is invalid.'
}

$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'prerequisite-missing' 'Candidate policy is missing.' }
$policyHash = (Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($policyHash -cne [string]$payload.config.policySha256) {
    Stop-Adapter 'integrity-failure' 'Candidate policy hash differs from Profile configuration.'
}
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Candidate policy is not valid JSON.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-provider-cycle-c1f' -or
    $policy.claimId -cne $claimId -or $policy.minimumProviderEdges -ne 1 -or
    $policy.sourcePolicy.path -cne 'docs/guards/V3_ifx/stages/post/policy/layerguard.json' -or
    $policy.sourceG03.path -cne 'docs/guards/V3_ifx/stages/post/policy/g03/governance.json' -or
    $policy.sourceRule.path -cne 'docs/guards/V3_ifx/stages/post/rules/L2.4.json') {
    Stop-Adapter 'integrity-failure' 'Candidate policy identity or authority paths are invalid.'
}
if ($null -eq $policy.providerContracts -or $policy.providerContracts -isnot [pscustomobject]) {
    Stop-Adapter 'invalid-input' 'Provider graph is missing or malformed.'
}
$graph = [Collections.Generic.Dictionary[string,string[]]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($entry in $policy.providerContracts.PSObject.Properties) {
    $consumer = [string]$entry.Name
    if ([string]::IsNullOrWhiteSpace($consumer) -or $entry.Value -isnot [array]) {
        Stop-Adapter 'invalid-input' 'Provider graph contains an invalid consumer or provider list.'
    }
    $providers = [Collections.Generic.List[string]]::new()
    foreach ($provider in $entry.Value) {
        if ($provider -isnot [string] -or [string]::IsNullOrWhiteSpace($provider)) {
            Stop-Adapter 'invalid-input' 'Provider graph contains an invalid provider.'
        }
        $providers.Add([string]$provider)
        $matched++
    }
    if ($graph.ContainsKey($consumer)) { Stop-Adapter 'invalid-input' 'Provider graph contains duplicate consumers.' }
    $graph.Add($consumer, $providers.ToArray())
}
if ($matched -eq 0) {
    $findings.Add([ordered]@{
        ruleId = $ruleId
        subject = 'providerContracts: zero provider edges'
        evidenceKind = 'coverage'
        detectorId = $detectorId
        severity = 'blocking'
    })
}

$cycles = [Collections.Generic.List[object]]::new()
$emitted = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$starts = [string[]]@($graph.Keys)
[Array]::Sort($starts, [StringComparer]::OrdinalIgnoreCase)
foreach ($start in $starts) {
    $path = [Collections.Generic.List[string]]::new()
    $active = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    Visit-Node $start
}
foreach ($cycle in $cycles) {
    $findings.Add([ordered]@{
        ruleId = $ruleId
        subject = $cycle -join ' -> '
        evidenceKind = 'policy-graph'
        detectorId = $detectorId
        severity = 'blocking'
    })
}
$sortedFindings = $findings.ToArray()
[Array]::Sort($sortedFindings, [Comparison[object]]{
    param($left, $right)
    [StringComparer]::Ordinal.Compare([string]$left['subject'], [string]$right['subject'])
})
$findings.Clear()
foreach ($finding in $sortedFindings) { $findings.Add($finding) }
Write-Result $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' }) `
    $(if ($findings.Count -eq 0) { 'success' } else { 'findings-blocking' })
