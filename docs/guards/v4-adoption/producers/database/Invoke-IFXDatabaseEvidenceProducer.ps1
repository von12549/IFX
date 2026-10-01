# Relocated from docs/guards/candidates/ifx-gate-coverage-c4b/Invoke-IFXDatabaseEvidenceProducer.ps1 (IFX I2-B amendment A2, rulings R6-R10). Adapted: producer ifx-v4a-database-v1; runs producers/database/Invoke-IFXSpecialized.ps1 directly; source inventory contract v3 (producers/database replaces the V3_ifx specialized root); explicit -TargetRoot; run directory artifacts/guards/v4a-producers/database-runs.
[CmdletBinding()]
param(
    [string]$TargetRoot,
    [string]$RunId = ([guid]::NewGuid().ToString('N')),
    [switch]$InventoryOnly,
    [string]$InventoryReportPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($RunId -cnotmatch '^[a-f0-9]{32}$'){throw 'RunId must be a 32-character lowercase hex identifier.'}
if(-not $TargetRoot){throw 'An explicit Target root is required: the relocated producers never derive the repository from their own location.'};$repo=[IO.Path]::GetFullPath($TargetRoot)
$inventoryContractPath=Join-Path $PSScriptRoot 'source-inventory.json'
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Hash-Text([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Hash-Normalized([string]$Path){Hash-Text ([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n"))}
function Is-Excluded([string]$Relative,[string[]]$Names){$segments=$Relative.Replace('\','/').Split('/');foreach($segment in $segments){if($Names -ccontains $segment){return $true}};return $false}
function Read-InventoryContract([string]$Path){
    $value=Get-Content $Path -Raw|ConvertFrom-Json -Depth 20
    if($value.formatVersion -ne 1 -or $value.id -cne 'ifx-database-source-inventory-v3' -or (@($value.extensions)-join '|') -cne '.cs|.csproj|.json|.ps1' -or $value.pathOrder -cne 'ordinal' -or $value.contentHash -cne 'utf8-lf-sha256' -or $value.trackedAtProduction -ne $true){throw 'Database source inventory contract drift.'}
    return $value
}
function Get-SourceInventory([string]$Root,$Contract){
    $paths=[Collections.Generic.List[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($relativeRoot in $Contract.roots){
        $folder=Join-Path $Root $relativeRoot
        if(-not [IO.Directory]::Exists($folder)){continue}
        foreach($file in Get-ChildItem -LiteralPath $folder -File -Recurse -Force){
            $relative=[IO.Path]::GetRelativePath($Root,$file.FullName).Replace('\','/')
            if($file.Extension.ToLowerInvariant() -notin @($Contract.extensions) -or (Is-Excluded $relative @($Contract.excludedDirectoryNames))){continue}
            if(($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $file.LinkTarget){throw "Linked Database source input: $relative"}
            if(-not $seen.Add($relative)){throw "Duplicate Database source input: $relative"}
            $paths.Add($relative)
        }
    }
    $ordered=$paths.ToArray();[Array]::Sort($ordered,[StringComparer]::Ordinal)
    return @($ordered|ForEach-Object{[ordered]@{path=$_;sha256=Hash-Normalized (Join-Path $Root $_)}})
}
$inventoryContract=Read-InventoryContract $inventoryContractPath
$command=Join-Path $PSScriptRoot 'Invoke-IFXSpecialized.ps1'
if(-not [IO.File]::Exists($command)){throw 'Relocated Database gate missing.'}
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
if($LASTEXITCODE -ne 0 -or $commit -cnotmatch '^[a-f0-9]{40}$'){throw 'Target commit unavailable.'}
if(-not [string]::IsNullOrWhiteSpace((& git -C $repo status --porcelain --untracked-files=no -- src tests/IFX.DatabaseBoundary.Tests tools/IFX.DatabaseInventory docs/guards/v4-adoption/producers/database deployment))){throw 'Controlled Database run requires clean tracked Database inputs.'}
$sourceFiles=@(Get-SourceInventory $repo $inventoryContract)
$gitArguments=@('-C',$repo,'-c','core.quotePath=false','ls-files','--')+@($inventoryContract.roots)
$trackedRaw=@(& git @gitArguments)
if($LASTEXITCODE -ne 0){throw 'Cannot enumerate tracked Database source inputs.'}
$tracked=[Collections.Generic.List[string]]::new()
foreach($relative in $trackedRaw){
    $normalized=$relative.Replace('\','/');$extension=[IO.Path]::GetExtension($normalized).ToLowerInvariant()
    if($extension -in @($inventoryContract.extensions) -and -not(Is-Excluded $normalized @($inventoryContract.excludedDirectoryNames))){$tracked.Add($normalized)}
}
$trackedOrdered=$tracked.ToArray();[Array]::Sort($trackedOrdered,[StringComparer]::Ordinal)
$selectedPaths=@($sourceFiles|ForEach-Object path)
if(($selectedPaths -join "`n") -cne ($trackedOrdered -join "`n")){throw 'Database source inventory must equal the selected Git tracked set.'}
$sourceLines=@($sourceFiles|ForEach-Object{"$($_.path)|$($_.sha256)"})
if($sourceLines.Count -lt 19){throw 'Database source inventory is empty.'}
$sourceTreeSha256=Hash-Text ($sourceLines -join "`n")
if($InventoryOnly){
    $inventoryResult=[ordered]@{formatVersion=1;status='pass';scope='ifx-database-source-inventory-v3';targetCommit=$commit;sourceInventoryId=$inventoryContract.id;sourceInventorySha256=Hash $inventoryContractPath;sourceFileCount=$sourceLines.Count;sourceTreeSha256=$sourceTreeSha256;sourceFiles=$sourceFiles}
    $json=(($inventoryResult|ConvertTo-Json -Depth 20).Replace("`r`n","`n")+"`n")
    if($InventoryReportPath){$resolved=[IO.Path]::GetFullPath($InventoryReportPath);[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($resolved));[IO.File]::WriteAllText($resolved,$json,[Text.UTF8Encoding]::new($false));Write-Output "Database source inventory: $resolved"}else{Write-Output $json}
    return
}
$relative="artifacts/guards/v4a-producers/database-runs/$RunId"
$output=Join-Path $repo $relative
if([IO.Directory]::Exists($output)){throw 'Database evidence run directory already exists.'}
$started=[DateTimeOffset]::UtcNow
& pwsh -NoLogo -NoProfile -NonInteractive -File $command -Gate Database -TargetRoot $repo -OutputDirectory "$relative/specialized"
if($LASTEXITCODE -ne 0){throw "Controlled Database gate failed; inspect $output. No passing lock was issued."}
$completed=[DateTimeOffset]::UtcNow
$required=@('specialized/summary.json','specialized/database/verification-summary.json','specialized/database/migration-safety.json','specialized/database/G02-migration-manifest.json','specialized/database/G02-database-inventory.json','specialized/database/release/artifact-manifest.json','specialized/database/release/migration-manifest.json','specialized/database/release/release-manifest.json','specialized/database/publish/IFX.DatabaseMigrator.dll')
foreach($item in $required){if(-not [IO.File]::Exists((Join-Path $output $item))){throw "Controlled Database output missing: $item"}}
$files=@(Get-ChildItem -LiteralPath (Join-Path $output 'specialized') -File -Recurse -Force|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($repo,$_.FullName).Replace('\','/');sha256=Hash $_.FullName}})
if(@($files|Where-Object path -like '*/release/*.sql').Count -lt 5){throw 'Controlled Database run produced fewer than five SQL scripts.'}
$authorities=[ordered]@{}
foreach($entry in @(@('migrationCatalog','src/DatabaseMigrator/IFX.DatabaseMigrator/migration-manifest.json'),@('releaseManifest','deployment/release-manifest.json'),@('safetyPolicy','deployment/migration-safety-policy.json'))){$authorities[$entry[0]]=Hash (Join-Path $repo $entry[1])}
$lock=[ordered]@{formatVersion=1;gate='Database';producer='ifx-v4a-database-v1';result='passed';targetCommit=$commit;startedAt=$started.ToString('o');completedAt=$completed.ToString('o');evidencePrefix="$relative/";sourceInventoryId=$inventoryContract.id;sourceInventorySha256=Hash $inventoryContractPath;sourceFileCount=$sourceLines.Count;sourceTreeSha256=$sourceTreeSha256;sourceFiles=$sourceFiles;authorityHashes=$authorities;files=$files}
$lockPath=Join-Path $output 'evidence-lock.json'
[IO.File]::WriteAllText($lockPath,(($lock|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))
Write-Output "Database evidence lock: $lockPath"
Write-Output "SHA256: $(Hash $lockPath)"
