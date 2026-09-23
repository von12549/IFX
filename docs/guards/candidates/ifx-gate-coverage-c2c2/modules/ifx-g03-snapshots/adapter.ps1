$ErrorActionPreference = 'Stop'
$detector = 'ifx-g03-snapshots'
$claims = @('IFX.C2.G03_SYNC_API_SNAPSHOT','IFX.C2.G03_SERIALIZATION_SNAPSHOT')
$rules = @('G03-SYNC-API-SNAPSHOT','G03-SERIALIZATION-SNAPSHOT')
$matched = @(0,0)
$findings = [Collections.Generic.List[object]]::new()
function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $coverage = for ($i = 0; $i -lt 2; $i++) { [ordered]@{ claimId = $claims[$i]; matched = $matched[$i]; minimum = 1 } }
    $result = [ordered]@{ formatVersion = 1; status = $Status; exitCategory = $Category; findings = @($findings.ToArray()); coverage = @($coverage) }
    if ($Message) { $result.message = $Message }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 100 -Compress))
}
function Stop-Adapter([string] $Category, [string] $Message) { Emit 'error' $Category $Message; exit 0 }
function Finding([int] $Index, [string] $Code, [string] $Subject) {
    $kind = if ($Index -eq 0) { 'sync-api-snapshot' } else { 'serialization-snapshot' }
    $findings.Add([ordered]@{ ruleId = $rules[$Index]; subject = "${Code}:${Subject}"; evidenceKind = $kind; detectorId = $detector; severity = 'blocking' })
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current -and ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current))) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Stop-Adapter 'unsafe-path' 'G03 input crosses a link.' }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Read-Target([string] $Relative, [string] $ExpectedHash) {
    $path = [IO.Path]::GetFullPath((Join-Path $targetRoot $Relative))
    Assert-NoLink $path
    if (-not [IO.File]::Exists($path)) { Stop-Adapter 'prerequisite-missing' "Missing G03 input: $Relative" }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $ExpectedHash) { Stop-Adapter 'integrity-failure' "G03 input hash drift: $Relative" }
    try { $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 100 }
    catch { Stop-Adapter 'invalid-input' "Malformed G03 input: $Relative" }
    if ($value -isnot [pscustomobject]) { Stop-Adapter 'invalid-input' "G03 input must be an object: $Relative" }
    return $value
}
function Source-Files([string] $Root) {
    $files = [Collections.Generic.List[object]]::new()
    $pending = [Collections.Generic.Stack[string]]::new(); $pending.Push($Root)
    while ($pending.Count -gt 0) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force | Sort-Object FullName)) {
            if ($item.PSIsContainer -and $item.Name -in @('bin','obj')) { continue }
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Stop-Adapter 'unsafe-path' 'G03 source tree contains a link.' }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
            elseif ($item.Extension -in @('.cs','.csproj')) {
                $files.Add([ordered]@{ path = [IO.Path]::GetRelativePath($targetRoot, $item.FullName).Replace('\','/'); full = $item.FullName })
            }
        }
    }
    return @($files.ToArray() | Sort-Object path)
}
function Projection {
    $protocols = @($catalog.protocols)
    $sync = @($protocols | Where-Object kind -eq 'sync' | Sort-Object identity)
    if ($protocols.Count -eq 0 -or $sync.Count -eq 0) {
        Finding 0 'zero-subject' 'catalog'; Finding 1 'zero-subject' 'catalog'
        return $null
    }
    $files = @(Source-Files $sourceRoot)
    $projects = @($files | Where-Object { $_.path.EndsWith('.csproj', [StringComparison]::OrdinalIgnoreCase) })
    $source = @($files | Where-Object { $_.path.EndsWith('.cs', [StringComparison]::OrdinalIgnoreCase) })
    if ($source.Count -eq 0) { Finding 0 'zero-source' 'src' }
    $apiRows = [Collections.Generic.List[object]]::new()
    foreach ($protocol in $sync) {
        $project = @($projects | Where-Object { [IO.Path]::GetFileNameWithoutExtension($_.path) -ceq $protocol.source.project })
        $signature = $null
        if ($project.Count -eq 1) {
            $directory = [IO.Path]::GetDirectoryName($project[0].path).Replace('\','/') + '/'
            $typeFiles = @($source | Where-Object { $_.path.StartsWith($directory, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileNameWithoutExtension($_.path) -ceq $protocol.source.type })
            if ($typeFiles.Count -eq 1) {
                $body = [IO.File]::ReadAllText($typeFiles[0].full)
                if ($body -match "(?m)^public\s+interface\s+$([regex]::Escape([string]$protocol.source.type))\b") {
                    $methods = @([regex]::Matches($body, '(?m)^\s*(Task<[^;]+?\([^;]+?\);)\s*$') | ForEach-Object {
                        $value = ($_.Groups[1].Value -replace '\s+', ' ').Trim()
                        if ($value -match "\b$([regex]::Escape([string]$protocol.source.member))\s*\(") { $value }
                    })
                    if ($methods.Count -eq 1) { $signature = $methods[0] }
                }
            }
        }
        if (-not $signature) { Finding 0 'source-signature-missing' ([string]$protocol.identity) }
        $apiRows.Add([ordered]@{
            identity = $protocol.identity; version = $protocol.version; lifecycle = $protocol.lifecycle
            sourceSignature = $signature; targetNamespace = "$($protocol.source.project).V$($protocol.version)"
            fields = @($protocol.fields | Select-Object name, required, classification)
        })
    }
    $api = [ordered]@{ formatVersion = 1; status = 'authoritative-current'; protocols = @($apiRows.ToArray()) }
    $schemaRows = @($protocols | Sort-Object identity | ForEach-Object {
        [ordered]@{
            identity = $_.identity; version = $_.version; kind = $_.kind; lifecycle = $_.lifecycle
            fields = @($_.fields | Select-Object name, required, classification)
            compatibility = if ($_.kind -eq 'event') { 'immutable envelope plus provider-owned payload' } else { 'capability request/response' }
        }
    })
    $serialization = [ordered]@{ formatVersion = 1; status = 'authoritative-current'; unknownFields = 'ignored-by-consumers'; propertyNaming = 'camelCase'; schemas = $schemaRows }
    return [pscustomobject]@{ api = $api; serialization = $serialization }
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.' }
try { $inputObject = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'invalid-input' 'Stage input is malformed.' }
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or
    (@($inputObject.config.enabledClaims) -join '|') -cne ($claims -join '|') -or
    @($inputObject.relativeRoots) -notcontains 'src' -or @($inputObject.relativeRoots) -notcontains 'docs') { Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.' }
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.' }
$targetRoot = [IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Directory]::Exists($targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
if ((Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256) { Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.' }
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g03-snapshots-c2c2' -or
    (@($policy.claims | ForEach-Object claimId) -join '|') -cne ($claims -join '|')) { Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.' }
$catalog = Read-Target $policy.catalogPath ([string]$inputObject.config.catalogSha256)
$apiSnapshot = Read-Target $policy.apiSnapshotPath ([string]$inputObject.config.apiSnapshotSha256)
$serializationSnapshot = Read-Target $policy.serializationSnapshotPath ([string]$inputObject.config.serializationSnapshotSha256)
$sourceRoot = Join-Path $targetRoot 'src'
Assert-NoLink $sourceRoot
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
$first = Projection
if ($null -eq $first) { Emit 'fail' 'findings-blocking'; exit 0 }
$second = Projection
if (($first.api | ConvertTo-Json -Depth 100 -Compress) -cne ($second.api | ConvertTo-Json -Depth 100 -Compress) -or
    ($first.serialization | ConvertTo-Json -Depth 100 -Compress) -cne ($second.serialization | ConvertTo-Json -Depth 100 -Compress)) {
    Finding 0 'nondeterministic-projection' 'sync-api'; Finding 1 'nondeterministic-projection' 'serialization'
}
if (($first.api | ConvertTo-Json -Depth 100 -Compress) -cne ($apiSnapshot | ConvertTo-Json -Depth 100 -Compress)) { Finding 0 'snapshot-drift' 'sync-api' }
if (($first.serialization | ConvertTo-Json -Depth 100 -Compress) -cne ($serializationSnapshot | ConvertTo-Json -Depth 100 -Compress)) { Finding 1 'snapshot-drift' 'serialization' }
if ($findings.Count -eq 0) { $matched[0] = @($first.api.protocols).Count; $matched[1] = @($first.serialization.schemas).Count }
Emit $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' }) $(if ($findings.Count -eq 0) { 'success' } else { 'findings-blocking' })
