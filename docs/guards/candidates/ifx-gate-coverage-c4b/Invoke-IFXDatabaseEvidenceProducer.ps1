[CmdletBinding()]
param(
    [string]$TargetRoot,
    [string]$RunId = ([guid]::NewGuid().ToString('N'))
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($RunId -cnotmatch '^[a-f0-9]{32}$'){throw 'RunId must be a 32-character lowercase hex identifier.'}
$repo=if($TargetRoot){[IO.Path]::GetFullPath($TargetRoot)}else{[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))}
$command=Join-Path $repo 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1'
if(-not [IO.File]::Exists($command)){throw 'V3 Database gate command missing.'}
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
if($LASTEXITCODE -ne 0 -or $commit -cnotmatch '^[a-f0-9]{40}$'){throw 'Target commit unavailable.'}
if(-not [string]::IsNullOrWhiteSpace((& git -C $repo status --porcelain --untracked-files=no -- src tests/IFX.DatabaseBoundary.Tests tools/IFX.DatabaseInventory docs/guards/V3_ifx/stages/post/gates/specialized deployment))){throw 'Controlled Database run requires clean tracked Database inputs.'}
$relative="artifacts/guards/p10-ifx-c4b/database-runs/$RunId"
$output=Join-Path $repo $relative
if([IO.Directory]::Exists($output)){throw 'Database evidence run directory already exists.'}
$started=[DateTimeOffset]::UtcNow
& pwsh -NoLogo -NoProfile -NonInteractive -File $command -Mode Specialized -SpecializedGate Database -TargetRoot $repo -OutputDirectory $relative
if($LASTEXITCODE -ne 0){throw "Controlled V3 Database gate failed; inspect $output. No passing lock was issued."}
$completed=[DateTimeOffset]::UtcNow
$db=Join-Path $output 'specialized/database'
$required=@('specialized/summary.json','specialized/database/verification-summary.json','specialized/database/migration-safety.json','specialized/database/G02-migration-manifest.json','specialized/database/G02-database-inventory.json','specialized/database/release/artifact-manifest.json','specialized/database/release/migration-manifest.json','specialized/database/release/release-manifest.json','specialized/database/publish/IFX.DatabaseMigrator.dll')
foreach($item in $required){if(-not [IO.File]::Exists((Join-Path $output $item))){throw "Controlled Database output missing: $item"}}
$files=@(Get-ChildItem -LiteralPath (Join-Path $output 'specialized') -File -Recurse -Force|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($repo,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}})
if(@($files|Where-Object path -like '*/release/*.sql').Count -lt 5){throw 'Controlled Database run produced fewer than five SQL scripts.'}
$sourceFiles=@(foreach($relativeRoot in @('src','tests/IFX.DatabaseBoundary.Tests','tools/IFX.DatabaseInventory','docs/guards/V3_ifx/stages/post/gates/specialized')){Get-ChildItem -LiteralPath (Join-Path $repo $relativeRoot) -File -Recurse -Force|Where-Object{$_.Extension -in '.cs','.csproj','.json','.ps1' -and $_.FullName -notmatch '[\\/](bin|obj)[\\/]' }})
$sourceLines=@($sourceFiles|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($repo,$_.FullName).Replace('\','/'))|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())"})
if($sourceLines.Count -lt 19){throw 'Database source inventory is empty.'}
$sourceTreeSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($sourceLines -join "`n")))).ToLowerInvariant()
$authorities=[ordered]@{}
foreach($entry in @(@('migrationCatalog','src/DatabaseMigrator/IFX.DatabaseMigrator/migration-manifest.json'),@('releaseManifest','deployment/release-manifest.json'),@('safetyPolicy','deployment/migration-safety-policy.json'))){$authorities[$entry[0]]=(Get-FileHash -LiteralPath (Join-Path $repo $entry[1]) -Algorithm SHA256).Hash.ToLowerInvariant()}
$lock=[ordered]@{formatVersion=1;gate='Database';producer='ifx-c4b-controlled-v1';result='passed';targetCommit=$commit;startedAt=$started.ToString('o');completedAt=$completed.ToString('o');evidencePrefix="$relative/";sourceFileCount=$sourceLines.Count;sourceTreeSha256=$sourceTreeSha256;authorityHashes=$authorities;files=$files}
$lockPath=Join-Path $output 'evidence-lock.json'
[IO.File]::WriteAllText($lockPath,(($lock|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))
Write-Output "Database evidence lock: $lockPath"
Write-Output "SHA256: $((Get-FileHash -LiteralPath $lockPath -Algorithm SHA256).Hash.ToLowerInvariant())"
