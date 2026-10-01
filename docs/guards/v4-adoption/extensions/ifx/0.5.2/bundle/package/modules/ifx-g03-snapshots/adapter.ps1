$ErrorActionPreference = 'Stop'
function Get-PinSha256([string]$Path) {
    # 0.5.0-a (R5): a governance pin is the SHA-256 of the UTF-8 text with line endings normalized to LF, so the pin
    # does not depend on the checkout; binary files are hashed by their raw bytes.
    if ([IO.Path]::GetExtension($Path).ToLowerInvariant() -in @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.dll', '.exe')) { return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
    $text = [IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text))).ToLowerInvariant()
}
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
function Is-Under([string]$Path,[string]$Root){$r=[IO.Path]::GetRelativePath($Root,$Path);$r-ne'..'-and-not[IO.Path]::IsPathRooted($r)-and-not$r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Load-WorkspaceEvidence($InputObject,[string]$TargetRoot){if(-not($InputObject.PSObject.Properties.Name-contains'workspaceEvidencePath')-or-not($InputObject.PSObject.Properties.Name-contains'workspaceEvidenceSha256')){return $null};if(-not($InputObject.PSObject.Properties.Name-contains'workspaceEvidenceTargetCommit')){Stop-Adapter 'invalid-input' 'Workspace evidence target commit is required.'};$path=[IO.Path]::GetFullPath([string]$InputObject.workspaceEvidencePath);Assert-NoLink $path 'Workspace evidence';$expected=[string]$InputObject.workspaceEvidenceSha256;$expectedCommit=[string]$InputObject.workspaceEvidenceTargetCommit;if($expected-cnotmatch'^[a-f0-9]{64}$'-or-not[IO.File]::Exists($path)-or(Is-Under $path $TargetRoot)-or(Is-Under $TargetRoot ([IO.Path]::GetDirectoryName($path)))){Stop-Adapter 'unsafe-path' 'Workspace evidence is missing, invalid, or overlaps TargetRoot.'};if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()-cne$expected){Stop-Adapter 'integrity-failure' 'Workspace evidence hash drift.'};try{$value=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -Depth 30}catch{Stop-Adapter 'integrity-failure' 'Workspace evidence is malformed.'};if($expectedCommit-cnotmatch'^[a-f0-9]{40}$'-or$value.targetCommit-cne$expectedCommit-or$value.formatVersion-ne1-or$value.scope-cne'v4-workspace-evidence-v1'-or$value.pathOrder-cne'ordinal'-or@($value.files).Count-ne$value.fileCount){Stop-Adapter 'integrity-failure' 'Workspace evidence identity drift.'};$value}
function Read-Target([string] $Relative, [string] $ExpectedHash) {
    $path = [IO.Path]::GetFullPath((Join-Path $targetRoot $Relative))
    Assert-NoLink $path
    if (-not [IO.File]::Exists($path)) { Stop-Adapter 'prerequisite-missing' "Missing G03 input: $Relative" }
    if ($ExpectedHash -and (Get-PinSha256 $path) -cne $ExpectedHash) { Stop-Adapter 'integrity-failure' "G03 governance input hash drift: $Relative" }
    try { $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 100 }
    catch { Stop-Adapter 'invalid-input' "Malformed G03 input: $Relative" }
    if ($value -isnot [pscustomobject]) { Stop-Adapter 'invalid-input' "G03 input must be an object: $Relative" }
    return $value
}
function Source-Files([string] $Root) {
    if($null-ne$script:sourceFileCache){return $script:sourceFileCache}
    if($null-ne$script:workspaceEvidence){$script:sourceFileCache=@($script:workspaceEvidence.files|Where-Object{$_.extension-in '.cs','.csproj'-and([string]$_.path).StartsWith('src/',[StringComparison]::Ordinal)}|ForEach-Object{[pscustomobject]@{path=[string]$_.path;full=[IO.Path]::GetFullPath((Join-Path $targetRoot ([string]$_.path)));text=[string]$_.text}});return $script:sourceFileCache}
    $files = [Collections.Generic.List[object]]::new()
    $pending = [Collections.Generic.Queue[string]]::new(); $pending.Enqueue($Root)
    while ($pending.Count -gt 0) {
        $current = $pending.Dequeue()
        foreach ($directoryPath in [IO.Directory]::EnumerateDirectories($current)) {
            if (([IO.File]::GetAttributes($directoryPath) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-Adapter 'unsafe-path' 'G03 source tree contains a link.' }
            if ([IO.Path]::GetFileName($directoryPath) -in @('bin','obj')) { continue }
            $pending.Enqueue($directoryPath)
        }
        foreach ($pattern in @('*.cs','*.csproj')) {
            foreach ($filePath in [IO.Directory]::EnumerateFiles($current, $pattern, [IO.SearchOption]::TopDirectoryOnly)) {
                if (([IO.File]::GetAttributes($filePath) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-Adapter 'unsafe-path' 'G03 source tree contains a link.' }
                $files.Add([ordered]@{ path = [IO.Path]::GetRelativePath($targetRoot, $filePath).Replace('\','/'); full = $filePath })
            }
        }
    }
    $script:sourceFileCache=@($files.ToArray() | Sort-Object path)
    return $script:sourceFileCache
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
                $body = if($typeFiles[0].PSObject.Properties.Name-contains'text'){$typeFiles[0].text}else{[IO.File]::ReadAllText($typeFiles[0].full)}
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
$script:workspaceEvidence=Load-WorkspaceEvidence $inputObject $targetRoot
$script:sourceFileCache=$null
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
if ((Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256) { Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.' }
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 50 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-g03-snapshots-050a' -or $policy.pinPolicy -cne 'governance-only' -or
    (@($policy.claims | ForEach-Object claimId) -join '|') -cne ($claims -join '|')) { Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.' }
# 0.5.0-a: the catalog and both snapshots are live (R1); the snapshots are regenerated and compared below.
$catalog = Read-Target $policy.catalogPath ('')
$apiSnapshot = Read-Target $policy.apiSnapshotPath ('')
$serializationSnapshot = Read-Target $policy.serializationSnapshotPath ('')
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
