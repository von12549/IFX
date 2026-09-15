[CmdletBinding()]
param(
    [string] $ReportPath = 'docs/architecture/review/evidence/gates/G03/G03-phase8-documentation-report.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$g03Directory = Join-Path $repositoryRoot 'docs/architecture/review/gates/G03'
$documents = @(
    Join-Path $g03Directory 'contract-event-governance.zh-CN.md'
    Join-Path $g03Directory 'contract-event-governance.en.md'
)
$expectedIdentities = @(
    'crm.account-compliance.v1'
    'registry.class-subscription-availability.v1'
    'ifx.transaction.transaction-processed.v1'
    'ifx.registry.class-status-changed.v1'
)
$expectedDiagrams = @('provider-consumer', 'lifecycle-migration', 'compatibility-decision', 'v1-v2-migration', 'change-approval')
$brokenLinks = [Collections.Generic.List[string]]::new()
$identityFailures = [Collections.Generic.List[string]]::new()

foreach ($document in $documents) {
    if (-not (Test-Path -LiteralPath $document)) { $identityFailures.Add("missing-document:$document"); continue }
    $content = Get-Content -Raw -LiteralPath $document
    foreach ($identity in $expectedIdentities) {
        if ($content -notmatch [regex]::Escape($identity)) { $identityFailures.Add("$([IO.Path]::GetFileName($document)):$identity") }
    }
    foreach ($match in [regex]::Matches($content, '!?' + '\[[^\]]*\]\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Split('#')[0]
        if ([string]::IsNullOrWhiteSpace($target) -or $target -match '^(https?://|mailto:|#)') { continue }
        $target = $target.Trim('<', '>')
        $resolved = Join-Path (Split-Path -Parent $document) $target
        if (-not (Test-Path -LiteralPath $resolved)) { $brokenLinks.Add("$([IO.Path]::GetFileName($document)):$target") }
    }
}

$diagramFailures = [Collections.Generic.List[string]]::new()
foreach ($name in $expectedDiagrams) {
    foreach ($extension in @('mmd', 'svg', 'png')) {
        $path = Join-Path $g03Directory "diagrams/$name.$extension"
        if (-not (Test-Path -LiteralPath $path)) { $diagramFailures.Add("missing:$name.$extension"); continue }
        if ((Get-Item -LiteralPath $path).Length -lt 100) { $diagramFailures.Add("empty:$name.$extension") }
        if ($extension -eq 'png') {
            $bytes = [IO.File]::ReadAllBytes($path)
            $signature = [BitConverter]::ToString($bytes[0..7])
            if ($signature -ne '89-50-4E-47-0D-0A-1A-0A') { $diagramFailures.Add("invalid-png:$name.png") }
        }
        if ($extension -eq 'svg' -and (Get-Content -Raw -LiteralPath $path) -notmatch '<svg') {
            $diagramFailures.Add("invalid-svg:$name.svg")
        }
    }
}

$checks = [ordered]@{
    bilingualDocumentsPresent = @($documents | Where-Object { Test-Path -LiteralPath $_ }).Count -eq 2
    bilingualIdentitiesMatch = $identityFailures.Count -eq 0
    localLinksResolve = $brokenLinks.Count -eq 0
    mermaidSvgPngTriplets = $diagramFailures.Count -eq 0
    responsibilityAndEvidenceSections = @($documents | Where-Object {
        $text = Get-Content -Raw -LiteralPath $_
        $text -match 'Provider Contract' -and $text -match 'Consumer Port' -and
        $text -match 'Integration Adapter' -and $text -match 'Composition' -and
        $text -match 'LayerGuard' -and $text -match 'waiver'
    }).Count -eq 2
}
$report = [ordered]@{
    formatVersion = 1
    gate = 'G03'
    phase = 8
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    checks = $checks
    counts = [ordered]@{ documents = 2; diagrams = $expectedDiagrams.Count; renderedAssets = $expectedDiagrams.Count * 2 }
    failures = [ordered]@{ identities = $identityFailures; links = $brokenLinks; diagrams = $diagramFailures }
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G03 documentation validation failed. Report: $resolvedReportPath" }
Write-Host "G03 documentation validation passed. Report: $resolvedReportPath"
