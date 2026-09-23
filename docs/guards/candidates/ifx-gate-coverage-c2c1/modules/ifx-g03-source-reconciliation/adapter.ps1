$ErrorActionPreference = 'Stop'
$detector = 'ifx-g03-source-reconciliation'
$claims = @('IFX.C2.G03_SOURCE_INVENTORY','IFX.C2.G03_SOURCE_RECONCILIATION','IFX.C2.G03_FIELD_SOURCE')
$rules = @{ inventory = 'G03-SOURCE-INVENTORY'; reconcile = 'G03-SOURCE-RECONCILIATION'; field = 'G03-FIELD-SOURCE' }
$kinds = @{ inventory = 'source-inventory'; reconcile = 'source-catalog'; field = 'field-source' }
$matched = @(0,0,0)
$findings = [Collections.Generic.List[object]]::new()
function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $coverage = for ($i = 0; $i -lt $claims.Count; $i++) { [ordered]@{ claimId = $claims[$i]; matched = $matched[$i]; minimum = 1 } }
    $result = [ordered]@{ formatVersion = 1; status = $Status; exitCategory = $Category; findings = @($findings.ToArray()); coverage = @($coverage) }
    if ($Message) { $result.message = $Message }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string] $Category, [string] $Message) { Emit 'error' $Category $Message; exit 0 }
function Add-Finding([string] $Group, [string] $Code, [string] $Path, [string] $Kind = '') {
    if (-not $Kind) { $Kind = $kinds[$Group] }
    $findings.Add([ordered]@{ ruleId = $rules[$Group]; subject = "${Code}:${Path}"; evidenceKind = $Kind; detectorId = $detector; severity = 'blocking' })
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current -and ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current))) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Stop-Adapter 'unsafe-path' 'Source input crosses a link.' }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Relative([string] $Path) { [IO.Path]::GetRelativePath($targetRoot, $Path).Replace('\','/') }
function Source-Files([string] $Directory) {
    $result = [Collections.Generic.List[object]]::new()
    $pending = [Collections.Generic.Stack[string]]::new(); $pending.Push($Directory)
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $current -Force | Sort-Object FullName)) {
            if ($item.PSIsContainer -and $item.Name -in @('bin','obj')) { continue }
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Stop-Adapter 'unsafe-path' 'Source tree contains a link.' }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
            elseif ($item.Extension -in @('.cs','.csproj')) { $result.Add([ordered]@{ path = Relative $item.FullName; full = $item.FullName; text = [IO.File]::ReadAllText($item.FullName) }) }
        }
    }
    return @($result.ToArray() | Sort-Object path)
}
function Build-Snapshot {
    $files = @(Source-Files $sourceRoot)
    $source = @($files | Where-Object { $_.path.EndsWith('.cs', [StringComparison]::OrdinalIgnoreCase) })
    $projects = @($files | Where-Object { $_.path.EndsWith('.csproj', [StringComparison]::OrdinalIgnoreCase) })
    $registered = @($catalog.protocols | ForEach-Object { $_.source.project } | Sort-Object -Unique)
    $selected = @($projects | Where-Object {
        $name = [IO.Path]::GetFileNameWithoutExtension($_.path)
        ($_.path -match '^src/Modules/' -and ($name -like '*.Abstractions' -or $name -like '*.Contracts')) -or $name -in $registered
    })
    $surfaces = [Collections.Generic.List[object]]::new()
    foreach ($project in $selected) {
        $name = [IO.Path]::GetFileNameWithoutExtension($project.path)
        $directory = [IO.Path]::GetDirectoryName($project.path).Replace('\','/') + '/'
        foreach ($file in @($source | Where-Object { $_.path.StartsWith($directory, [StringComparison]::OrdinalIgnoreCase) })) {
            $declaration = [regex]::Match($file.text, '(?m)^public\s+(?:(?:abstract|sealed|partial|readonly)\s+)*(interface|record(?:\s+(?:class|struct))?|class|enum)\s+([A-Za-z0-9_]+)')
            if (-not $declaration.Success) { continue }
            $type = $declaration.Groups[2].Value; $declarationKind = $declaration.Groups[1].Value
            $kind = if ($file.text -match ':\s*(?:IntegrationEvent|IIntegrationEventV1)\b') { 'integration-event' }
                elseif ($declarationKind -eq 'interface') { 'reader' }
                elseif ($file.path -match '/DTOs/') { 'dto' }
                else { 'public-type' }
            $methods = [Collections.Generic.List[object]]::new()
            if ($declarationKind -eq 'interface') {
                foreach ($match in [regex]::Matches($file.text, '(?m)^\s*(Task<[^;]+?\([^;]+?\);)\s*$')) {
                    $signature = ($match.Groups[1].Value -replace '\s+', ' ').Trim()
                    $methodName = [regex]::Match($signature, '([A-Za-z0-9_]+)Async\s*\(').Groups[1].Value + 'Async'
                    $methods.Add([ordered]@{ name = $methodName; signature = $signature })
                }
            }
            $surfaces.Add([ordered]@{ project = $name; name = $type; kind = $kind; file = $file.path; methods = @($methods.ToArray()) })
        }
    }
    $messagingDir = 'src/Platform/Messaging/IFX.Platform.Messaging.Contracts/'
    $messaging = @($source | Where-Object { $_.path.StartsWith($messagingDir, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object {
        $declaration = [regex]::Match($_.text, '(?m)^public\s+(?:(?:abstract|sealed|partial|readonly)\s+)*(interface|record(?:\s+(?:class|struct))?|class)\s+([A-Za-z0-9_]+)')
        if ($declaration.Success) { [ordered]@{ name = $declaration.Groups[2].Value; file = $_.path } }
    })
    $surfaces = @($surfaces.ToArray() | Sort-Object project, kind, name, file)
    $counts = [ordered]@{
        abstractionProjects = @($selected | Where-Object { [IO.Path]::GetFileNameWithoutExtension($_.path) -like '*.Abstractions' }).Count
        contractProjects = @($selected | Where-Object { [IO.Path]::GetFileNameWithoutExtension($_.path) -like '*.Contracts' }).Count
        readers = @($surfaces | Where-Object kind -eq 'reader').Count
        readerMethods = @($surfaces | ForEach-Object { @($_.methods).Count } | Measure-Object -Sum).Sum
        dtos = @($surfaces | Where-Object kind -eq 'dto').Count
        integrationEvents = @($surfaces | Where-Object kind -eq 'integration-event').Count
        messagingAbstractionTypes = $messaging.Count
    }
    return [pscustomobject]@{ files = $files; source = $source; surfaces = $surfaces; messaging = $messaging; counts = $counts }
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.' }
try { $inputObject = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or
    (@($inputObject.config.enabledClaims) -join '|') -cne ($claims -join '|') -or
    @($inputObject.relativeRoots) -notcontains 'src') { Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.' }
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
$targetRoot = [IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Directory]::Exists($targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
if ((Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256) { Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.' }
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g03-source-reconciliation-c2c1' -or
    (@($policy.claims | ForEach-Object claimId) -join '|') -cne ($claims -join '|') -or
    $policy.catalogPath -cne 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') { Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.' }
$catalogPath = [IO.Path]::GetFullPath((Join-Path $targetRoot $policy.catalogPath))
Assert-NoLink $catalogPath
if (-not [IO.File]::Exists($catalogPath)) { Stop-Adapter 'prerequisite-missing' 'G03 catalog is missing.' }
if ((Get-FileHash -LiteralPath $catalogPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.catalogSha256) { Stop-Adapter 'integrity-failure' 'G03 catalog hash drift.' }
try { $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -Depth 100 }
catch { Stop-Adapter 'invalid-input' 'G03 catalog is malformed.' }
if ($catalog -isnot [pscustomobject]) { Stop-Adapter 'invalid-input' 'G03 catalog must be an object.' }
$sourceRoot = Join-Path $targetRoot 'src'
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot
try { $first = Build-Snapshot; $second = Build-Snapshot }
catch { Stop-Adapter 'invalid-input' "Source inventory failed: $($_.Exception.Message)" }
$comparableFirst = [ordered]@{ counts = $first.counts; surfaces = $first.surfaces; messaging = $first.messaging }
$comparableSecond = [ordered]@{ counts = $second.counts; surfaces = $second.surfaces; messaging = $second.messaging }
if (($comparableFirst | ConvertTo-Json -Depth 50 -Compress) -cne ($comparableSecond | ConvertTo-Json -Depth 50 -Compress)) { Add-Finding inventory 'nondeterministic-inventory' 'src' }
if ($second.source.Count -eq 0 -or @($second.files | Where-Object { $_.path.EndsWith('.csproj') }).Count -eq 0) { Add-Finding inventory 'zero-source' 'src' 'coverage' }
else { $matched[0] = 1 }
foreach ($key in @('abstractionProjects','readers','readerMethods','dtos','integrationEvents','messagingAbstractionTypes')) {
    if ($second.counts[$key] -ne $policy.expectedPhase9.$key) { Add-Finding inventory 'exact-count' "$key=$($second.counts[$key])" }
}
if (@($second.surfaces | Where-Object { $_.file -match '(^|/)(bin|obj)/' }).Count -gt 0) { Add-Finding inventory 'generated-contamination' 'src' }
$sourceKeys = [Collections.Generic.List[string]]::new()
foreach ($surface in @($second.surfaces | Where-Object project -like '*.Abstractions')) {
    $sourceKeys.Add("$($surface.project)|$($surface.name)|")
    foreach ($method in @($surface.methods)) { $sourceKeys.Add("$($surface.project)|$($surface.name)|$($method.name)") }
}
$catalogKeys = @($catalog.publicSurface | Where-Object lifecycle -eq 'LegacyPendingMigration' | ForEach-Object { "$($_.project)|$($_.type)|$($_.member)" })
if ($catalogKeys.Count -ne $policy.expectedPhase9.pendingLegacySurface) { Add-Finding reconcile 'pending-legacy-count' "publicSurface=$($catalogKeys.Count)" }
foreach ($key in @($sourceKeys.ToArray() | Where-Object { $_ -notin $catalogKeys } | Sort-Object -Unique)) { Add-Finding reconcile 'unregistered-source' $key }
foreach ($key in @($catalogKeys | Where-Object { $_ -notin $sourceKeys } | Sort-Object -Unique)) { Add-Finding reconcile 'missing-source' $key }
if ($second.surfaces.Count -gt 0 -and @($catalog.protocols).Count -gt 0) { $matched[1] = 1 }
else { Add-Finding reconcile 'zero-reconciliation-subject' 'protocols/source' 'coverage' }
$moduleMap = @{}; foreach ($module in @($catalog.modules)) { $moduleMap[[string]$module.id] = $module }
$consumerMap = @{}; foreach ($consumer in @($catalog.consumers)) { $consumerMap[[string]$consumer.id] = $consumer }
foreach ($protocol in @($catalog.protocols | Where-Object { $null -ne $_ })) {
    $path = "protocols.$($protocol.identity)"
    $surface = $second.surfaces | Where-Object { $_.project -eq $protocol.source.project -and $_.name -eq $protocol.source.type } | Select-Object -First 1
    if ($null -eq $surface) { Add-Finding reconcile 'protocol-source-missing' $path; continue }
    if ($protocol.source.member -and $protocol.source.member -notin @($surface.methods | ForEach-Object name)) { Add-Finding reconcile 'protocol-member-missing' $path }
    if ($protocol.kind -eq 'event') {
        $symbol = [regex]::Escape([string]$protocol.source.type)
        $handler = @($second.source | Where-Object { $_.path -ne $surface.file -and $_.text -match "\b$symbol\b" -and
            ($_.text -match "IIntegrationEventHandler\s*<\s*$symbol\s*>" -or $_.text -match 'IInboundIntegrationEventHandler') })
        if ($handler.Count -eq 0) { Add-Finding reconcile 'protocol-consumer-missing' $path }
    } else {
        $adapterStem = ([string]$protocol.source.type -replace '^I','' -replace 'Contract$','')
        foreach ($consumerId in @($protocol.consumers)) {
            $consumer = $consumerMap[[string]$consumerId]
            $module = $moduleMap[[string]$consumer.module]
            $prefix = "src/Modules/$($module.name)/"
            $consumerFiles = @($second.source | Where-Object { $_.path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
            $direct = @($consumerFiles | Where-Object { $_.text.Contains([string]$protocol.source.type, [StringComparison]::Ordinal) }).Count -gt 0
            $adapter = @($consumerFiles | Where-Object { [IO.Path]::GetFileNameWithoutExtension($_.path) -like "$adapterStem*Adapter" -and $_.text -match '\bClient\b' }).Count -gt 0
            if (-not ($direct -or $adapter)) { Add-Finding reconcile 'protocol-consumer-missing' "$path.$consumerId" }
        }
    }
}
$legacyFields = @($catalog.fieldSurfaces | Where-Object kind -in @('legacy-dto','legacy-event'))
if ($legacyFields.Count -eq 0) { Add-Finding field 'zero-field-inventory' 'fieldSurfaces' 'coverage' }
else { $matched[2] = 1 }
foreach ($surface in $legacyFields) {
    $catalogSurface = $catalog.publicSurface | Where-Object id -eq $surface.id | Select-Object -First 1
    if ($catalogSurface.lifecycle -eq 'Retired') { continue }
    $sourceFile = $second.source | Where-Object { [IO.Path]::GetFileName($_.path) -ceq "$($surface.source).cs" -and $_.path -match '^src/Modules/.+\.Abstractions/(DTOs|Events)/' } | Select-Object -First 1
    if ($null -eq $sourceFile) { Add-Finding field 'field-source-missing' "fieldSurfaces.$($surface.id)"; continue }
    $pattern = "public\s+record\s+$([regex]::Escape([string]$surface.source))\s*\((?<parameters>.*?)\)\s*(?::|;)"
    $declaration = [regex]::Match($sourceFile.text, $pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
    $parameters = if ($declaration.Success) { ($declaration.Groups['parameters'].Value -replace '//[^\r\n]*','') -split ',' } else { @() }
    $sourceFields = @($parameters | ForEach-Object { if ($_ -match '([A-Za-z_][A-Za-z0-9_]*)\s*$') { $Matches[1] } } | Sort-Object)
    $inventoryFields = @($surface.fields | ForEach-Object name | Sort-Object)
    if (($sourceFields -join ',') -cne ($inventoryFields -join ',')) { Add-Finding field 'field-source-drift' "fieldSurfaces.$($surface.id)" }
}
if ($findings.Count -eq 0) { Emit 'pass' 'success' }
else { Emit 'fail' 'findings-blocking' }
