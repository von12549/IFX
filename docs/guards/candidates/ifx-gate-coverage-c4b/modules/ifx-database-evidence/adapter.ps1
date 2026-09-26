Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$claim='IFX.C4.DATABASE_EVIDENCE';$rule='DATABASE-LOCKED-EVIDENCE';$detector='ifx-database-evidence'
$findings=[Collections.Generic.List[object]]::new();$matched=0
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Hash-Text([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Hash-Normalized([string]$Path){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")))).ToLowerInvariant()}
function Is-Excluded([string]$Relative,[string[]]$Names){$segments=$Relative.Replace('\','/').Split('/');foreach($segment in $segments){if($Names -ccontains $segment){return $true}};return $false}
function Read-InventoryContract([string]$Path){$value=Get-Content $Path -Raw|ConvertFrom-Json -Depth 20;if($value.formatVersion -ne 1 -or $value.id -cne 'ifx-database-source-inventory-v2' -or (@($value.extensions)-join '|') -cne '.cs|.csproj|.json|.ps1' -or $value.pathOrder -cne 'ordinal' -or $value.contentHash -cne 'utf8-lf-sha256' -or $value.trackedAtProduction -ne $true){Stop-Adapter 'integrity-failure' 'Database source inventory contract drift.'};return $value}
function Source-Entries([string]$Root,$Contract){
    if($null-ne$script:workspaceEvidence){
        $rows=[Collections.Generic.List[object]]::new();$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach($entry in $script:workspaceEvidence.files){$relative=[string]$entry.path;$inRoot=@($Contract.roots|Where-Object{$relative-ceq$_ -or $relative.StartsWith("$_/",[StringComparison]::Ordinal)}).Count-gt0;if(-not$inRoot -or [string]$entry.extension -notin @($Contract.extensions) -or (Is-Excluded $relative @($Contract.excludedDirectoryNames))){continue};if(-not$seen.Add($relative)){Stop-Adapter 'integrity-failure' "Duplicate Database source input: $relative"};$rows.Add([ordered]@{path=$relative;sha256=[string]$entry.normalizedSha256})}
        $ordered=$rows.ToArray();[Array]::Sort($ordered,[Comparison[object]]{param($a,$b);[StringComparer]::Ordinal.Compare([string]$a.path,[string]$b.path)});return @($ordered)
    }
    $paths=[Collections.Generic.List[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);$excluded=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);foreach($name in @($Contract.excludedDirectoryNames)){[void]$excluded.Add([string]$name)}
    foreach($relativeRoot in $Contract.roots){
        $folder=[IO.Path]::GetFullPath((Join-Path $Root ([string]$relativeRoot)));if(-not[IO.Directory]::Exists($folder)){continue}
        $pending=[Collections.Generic.Queue[string]]::new();$pending.Enqueue($folder)
        while($pending.Count-gt0){
            $current=$pending.Dequeue()
            foreach($directory in [IO.Directory]::EnumerateDirectories($current)){
                if($excluded.Contains([IO.Path]::GetFileName($directory))){continue}
                if(([IO.File]::GetAttributes($directory)-band[IO.FileAttributes]::ReparsePoint)-ne0){Stop-Adapter 'unsafe-path' "Linked Database source directory: $directory"}
                $pending.Enqueue($directory)
            }
            foreach($file in [IO.Directory]::EnumerateFiles($current)){
                $relative=[IO.Path]::GetRelativePath($Root,$file).Replace('\','/');if([IO.Path]::GetExtension($file).ToLowerInvariant()-notin@($Contract.extensions)-or(Is-Excluded $relative @($Contract.excludedDirectoryNames))){continue}
                if(([IO.File]::GetAttributes($file)-band[IO.FileAttributes]::ReparsePoint)-ne0){Stop-Adapter 'unsafe-path' "Linked Database source input: $relative"}
                if(-not$seen.Add($relative)){Stop-Adapter 'integrity-failure' "Duplicate Database source input: $relative"};$paths.Add($relative)
            }
        }
    }
    $ordered=$paths.ToArray();[Array]::Sort($ordered,[StringComparer]::Ordinal);return @($ordered|ForEach-Object{[ordered]@{path=$_;sha256=Hash-Normalized (Join-Path $Root $_)}})
}
function Field($Object,[string]$Name){foreach($key in $Object.Keys){if($key.Equals($Name,[StringComparison]::OrdinalIgnoreCase)){return $Object[$key]}};return $null}
function Parse-Time($Value){if($Value -is [DateTime]){return [DateTimeOffset]$Value};return [DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)}
function Emit([string]$Status,[string]$Category,[string]$Message=''){$r=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@([ordered]@{claimId=$claim;matched=[int]$matched;minimum=1})};if($Message){$r.message=$Message};[Console]::Out.WriteLine(($r|ConvertTo-Json -Depth 50 -Compress))}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Resolve-TargetCommit([string]$Root){
    $marker=Join-Path $Root '.git';$gitDir=$null
    if([IO.Directory]::Exists($marker)){$gitDir=$marker}
    elseif([IO.File]::Exists($marker)){
        $pointer=[IO.File]::ReadAllText($marker).Trim()
        if($pointer -cnotmatch '^gitdir:\s*(.+)$'){Stop-Adapter 'integrity-failure' 'Malformed TargetRoot Git pointer.'}
        $gitDirValue=$Matches[1].Trim();$gitDir=if([IO.Path]::IsPathFullyQualified($gitDirValue)){[IO.Path]::GetFullPath($gitDirValue)}else{[IO.Path]::GetFullPath((Join-Path $Root $gitDirValue))}
    }else{Stop-Adapter 'prerequisite-missing' 'TargetRoot Git metadata missing.'}
    if(-not [IO.Directory]::Exists($gitDir)){Stop-Adapter 'prerequisite-missing' 'TargetRoot Git directory missing.'}
    $headPath=Join-Path $gitDir 'HEAD';if(-not [IO.File]::Exists($headPath)){Stop-Adapter 'prerequisite-missing' 'TargetRoot Git HEAD missing.'}
    $head=[IO.File]::ReadAllText($headPath).Trim()
    if($head -cmatch '^[a-f0-9]{40}$'){return $head}
    if($head -cnotmatch '^ref:\s*(refs/[A-Za-z0-9._/-]+)$'){Stop-Adapter 'integrity-failure' 'Malformed TargetRoot Git HEAD.'}
    $reference=$Matches[1]
    if($reference -match '(^|/)\.\.(/|$)'){Stop-Adapter 'integrity-failure' 'Unsafe TargetRoot Git reference.'}
    $roots=[Collections.Generic.List[string]]::new();$roots.Add($gitDir)
    $commonMarker=Join-Path $gitDir 'commondir'
    if([IO.File]::Exists($commonMarker)){
        $commonValue=[IO.File]::ReadAllText($commonMarker).Trim();$commonDir=if([IO.Path]::IsPathFullyQualified($commonValue)){[IO.Path]::GetFullPath($commonValue)}else{[IO.Path]::GetFullPath((Join-Path $gitDir $commonValue))}
        if([IO.Directory]::Exists($commonDir) -and -not $roots.Contains($commonDir)){$roots.Add($commonDir)}
    }
    foreach($rootPath in $roots){
        $loose=Join-Path $rootPath ($reference.Replace('/',[IO.Path]::DirectorySeparatorChar));if([IO.File]::Exists($loose)){$value=[IO.File]::ReadAllText($loose).Trim();if($value -cmatch '^[a-f0-9]{40}$'){return $value}}
        $packed=Join-Path $rootPath 'packed-refs';if([IO.File]::Exists($packed)){foreach($line in [IO.File]::ReadLines($packed)){if($line.StartsWith('#') -or $line.StartsWith('^')){continue};$parts=$line.Split(' ',[StringSplitOptions]::RemoveEmptyEntries);if($parts.Count -ge 2 -and $parts[1] -ceq $reference -and $parts[0] -cmatch '^[a-f0-9]{40}$'){return $parts[0]}}}
    }
    Stop-Adapter 'integrity-failure' 'TargetRoot Git reference cannot be resolved.'
}
function Is-Under([string]$Path,[string]$Root){$r=[IO.Path]::GetRelativePath($Root,$Path);$r -ne '..' -and -not [IO.Path]::IsPathRooted($r) -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Load-WorkspaceEvidence($InputObject,[string]$TargetRoot){if(-not$InputObject.ContainsKey('workspaceEvidencePath') -or -not$InputObject.ContainsKey('workspaceEvidenceSha256')){return $null};if(-not$InputObject.ContainsKey('workspaceEvidenceTargetCommit')){Stop-Adapter 'invalid-input' 'Workspace evidence target commit is required.'};$path=[IO.Path]::GetFullPath([string]$InputObject.workspaceEvidencePath);$expected=[string]$InputObject.workspaceEvidenceSha256;$expectedCommit=[string]$InputObject.workspaceEvidenceTargetCommit;if($expected-cnotmatch'^[a-f0-9]{64}$' -or -not[IO.File]::Exists($path) -or (Is-Under $path $TargetRoot) -or (Is-Under $TargetRoot ([IO.Path]::GetDirectoryName($path)))){Stop-Adapter 'unsafe-path' 'Workspace evidence is missing, invalid, or overlaps TargetRoot.'};if((Hash $path)-cne$expected){Stop-Adapter 'integrity-failure' 'Workspace evidence hash drift.'};try{$value=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -AsHashtable -Depth 30}catch{Stop-Adapter 'integrity-failure' 'Workspace evidence is malformed.'};if($expectedCommit-cnotmatch'^[a-f0-9]{40}$' -or $value.targetCommit-cne$expectedCommit -or $value.formatVersion-ne1 -or $value.scope-cne'ifx-workspace-evidence-v1' -or $value.pathOrder-cne'ordinal' -or @($value.files).Count-ne$value.fileCount){Stop-Adapter 'integrity-failure' 'Workspace evidence identity drift.'};$value}
function Resolve-File([string]$Relative,[string]$Expected){if([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\/])\.\.([\/]|$)' -or $Expected -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'invalid-input' 'Invalid evidence path or hash.'};$full=[IO.Path]::GetFullPath((Join-Path $target $Relative));if(-not(Is-Under $full $target)){Stop-Adapter 'unsafe-path' 'Evidence escapes TargetRoot.'};$cursor=$full;while(Is-Under $cursor $target){if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked evidence path: $Relative"}};if($cursor -ceq $target){break};$cursor=[IO.Path]::GetDirectoryName($cursor)};if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing evidence: $Relative"};if((Hash $full) -cne $Expected){Stop-Adapter 'integrity-failure' "Stale evidence: $Relative"};return $full}
function Record([string]$Id,[bool]$Pass){$script:matched++;if(-not $Pass){$findings.Add([ordered]@{ruleId=$rule;subject=$Id;evidenceKind='database-evidence';detectorId=$detector;severity='blocking'})}}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Malformed stage input.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'deployment'){Stop-Adapter 'invalid-input' 'Stage or claim selection invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'invalid-input' 'TargetRoot must be absolute.'};$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot missing.'}
$script:workspaceEvidence=Load-WorkspaceEvidence $inputObject $target
$targetCommit=Resolve-TargetCommit $target
$policyFile=Join-Path $PSScriptRoot 'policy.json';if((Hash $policyFile) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Module policy drift.'}
$inventoryContractPath=Join-Path $PSScriptRoot 'source-inventory.json';$inventoryContract=Read-InventoryContract $inventoryContractPath
try{$policy=Get-Content $policyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed module policy.'}
if($policy.id -cne 'ifx-database-evidence-c4b' -or @($policy.checkIds).Count -ne 9){Stop-Adapter 'integrity-failure' 'Module policy identity drift.'}
$authority=@{};foreach($a in $policy.authorities){$entry=@($inputObject.config.authorityHashes|Where-Object id -CEQ $a.id);if($entry.Count -ne 1){Stop-Adapter 'invalid-input' "Authority lock missing: $($a.id)"};$authority[$a.id]=Resolve-File ([string]$a.path) ([string]$entry[0].sha256)}
try{$sourceManifest=Get-Content $authority.migrationCatalog -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$release=Get-Content $authority.releaseManifest -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$safetyPolicy=Get-Content $authority.safetyPolicy -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed Database authority.'}
if($sourceManifest.formatVersion -ne 1 -or $release.formatVersion -ne 1 -or $safetyPolicy.formatVersion -ne 1 -or $release.migrationCatalogSha256 -cne (Hash $authority.migrationCatalog) -or $safetyPolicy.defaultStrategy -cne 'roll-forward' -or $safetyPolicy.automaticDownAllowed -ne $false){Stop-Adapter 'integrity-failure' 'Database authority contract failed.'}
$lockFile=Resolve-File ([string]$inputObject.config.evidenceLockPath) ([string]$inputObject.config.evidenceLockSha256)
try{$lock=Get-Content $lockFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed evidence lock.'}
if($lock.formatVersion -ne 1 -or $lock.gate -cne 'Database' -or $lock.producer -cne 'ifx-c4b-controlled-v2' -or $lock.result -cne 'passed' -or $lock.targetCommit -cnotmatch '^[a-f0-9]{40}$' -or @($lock.files).Count -lt 10 -or $lock.sourceInventoryId -cne $inventoryContract.id -or $lock.sourceInventorySha256 -cne (Hash $inventoryContractPath)){Stop-Adapter 'integrity-failure' 'Incomplete Database evidence lock.'}
if($lock.targetCommit -cne $targetCommit){Stop-Adapter 'integrity-failure' 'Database lock target commit differs from TargetRoot HEAD.'}
$sourceEntries=@(Source-Entries $target $inventoryContract);$sourceLines=@($sourceEntries|ForEach-Object{"$($_.path)|$($_.sha256)"});$lockedLines=@($lock.sourceFiles|ForEach-Object{"$($_.path)|$($_.sha256)"});if($sourceLines.Count -lt 19 -or $lock.sourceFileCount -ne $sourceLines.Count -or @($lock.sourceFiles).Count -ne $sourceLines.Count -or ($lockedLines -join "`n") -cne ($sourceLines -join "`n") -or [string]$lock.sourceTreeSha256 -cne (Hash-Text ($sourceLines -join "`n"))){Stop-Adapter 'integrity-failure' 'Database source tree changed after evidence generation.'}
try{$started=Parse-Time $lock.startedAt;$completed=Parse-Time $lock.completedAt}catch{Stop-Adapter 'integrity-failure' 'Invalid evidence time.'}
$now=[DateTimeOffset]::UtcNow;if($completed -lt $started -or $completed -gt $now.AddMinutes(5) -or $completed -lt $now.AddHours(-24)){Stop-Adapter 'integrity-failure' 'Database evidence is stale or future-dated.'}
foreach($a in $policy.authorities){if([string]$lock.authorityHashes[$a.id] -cne (Hash $authority[$a.id])){Stop-Adapter 'integrity-failure' "Evidence authority drift: $($a.id)"}}
$evidence=@{};$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach($entry in $lock.files){$path=[string]$entry.path;if(-not $seen.Add($path)){Stop-Adapter 'integrity-failure' 'Duplicate evidence lock path.'};$evidence[$path]=Resolve-File $path ([string]$entry.sha256)}
$prefix=[string]$lock.evidencePrefix;if($prefix -notmatch '^artifacts/guards/[a-zA-Z0-9/_-]+/$'){Stop-Adapter 'invalid-input' 'Evidence prefix is outside controlled artifacts.'}
$required=@('specialized/summary.json','specialized/database/verification-summary.json','specialized/database/migration-safety.json','specialized/database/G02-migration-manifest.json','specialized/database/G02-database-inventory.json','specialized/database/release/artifact-manifest.json','specialized/database/release/migration-manifest.json','specialized/database/release/release-manifest.json')
foreach($suffix in $required){if(-not $evidence.ContainsKey($prefix+$suffix)){Stop-Adapter 'prerequisite-missing' "Missing locked artifact: $suffix"}}
foreach($path in $evidence.Keys){if(-not $path.StartsWith($prefix,[StringComparison]::Ordinal)){Stop-Adapter 'unsafe-path' 'Evidence file outside locked prefix.'}}
try{$outer=Get-Content $evidence[$prefix+'specialized/summary.json'] -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$summary=Get-Content $evidence[$prefix+'specialized/database/verification-summary.json'] -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$safety=Get-Content $evidence[$prefix+'specialized/database/migration-safety.json'] -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$inventory=Get-Content $evidence[$prefix+'specialized/database/G02-database-inventory.json'] -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$generated=Get-Content $evidence[$prefix+'specialized/database/G02-migration-manifest.json'] -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$artifact=Get-Content $evidence[$prefix+'specialized/database/release/artifact-manifest.json'] -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed Database evidence artifact.'}
$moduleNames=@('Auth','CRM','Registry','Holdings','Transaction');$manifestNames=@($sourceManifest.modules|ForEach-Object moduleName);$inventoryNames=@($inventory.modules|ForEach-Object Module)
$sourcesOkay=$sourceManifest.physicalDatabase -ceq 'IFXDb' -and $generated.physicalDatabase -ceq 'IFXDb' -and (@($manifestNames|Sort-Object)-join '|') -ceq (@($moduleNames|Sort-Object)-join '|') -and (@($inventoryNames|Sort-Object)-join '|') -ceq (@($moduleNames|Sort-Object)-join '|')
foreach($module in $sourceManifest.modules){$im=@($inventory.modules|Where-Object Module -CEQ $module.moduleName);$gm=@($generated.modules|Where-Object module -CEQ $module.moduleName);if($im.Count -ne 1 -or $gm.Count -ne 1 -or @($module.migrations).Count -eq 0 -or @($module.migrations).Count -ne @($im[0].Migrations).Count -or @($module.migrations).Count -ne @($gm[0].migrations).Count){$sourcesOkay=$false;continue};foreach($m in $module.migrations){$row=@($im[0].Migrations|Where-Object MigrationId -CEQ $m.migrationId);$grow=@($gm[0].migrations|Where-Object MigrationId -CEQ $m.migrationId);if($row.Count -ne 1 -or $grow.Count -ne 1){$sourcesOkay=$false;continue};if($m.sourceSha256 -cne $row[0].SourceSha256 -or $m.sourceSha256 -cne $grow[0].SourceSha256){$sourcesOkay=$false};$sourcePath=[string]$row[0].Source;if($sourcePath -notmatch '^src/' -or $sourcePath -match '(^|/)\.\.(/|$)'){ $sourcesOkay=$false;continue };$sourceFull=[IO.Path]::GetFullPath((Join-Path $target $sourcePath));if(-not(Is-Under $sourceFull $target) -or -not [IO.File]::Exists($sourceFull) -or (Hash-Normalized $sourceFull) -cne $m.sourceSha256){$sourcesOkay=$false}}}
$sql=@($evidence.Keys|Where-Object{$_ -like ($prefix+'specialized/database/release/*.sql')});$published=@($evidence.Keys|Where-Object{$_ -like ($prefix+'specialized/database/publish/IFX.DatabaseMigrator.dll')})
$artifactScripts=@(Field $artifact 'scripts');$releaseOkay=$summary.checks.releaseArtifacts -eq $true -and $sql.Count -eq 5 -and (Field $artifact 'releaseVersion') -ceq $release.releaseVersion -and (Field $artifact 'migrationCatalogSha256') -ceq $release.migrationCatalogSha256 -and $artifactScripts.Count -eq 5
if((Hash $evidence[$prefix+'specialized/database/release/migration-manifest.json']) -cne (Hash $authority.migrationCatalog) -or (Hash $evidence[$prefix+'specialized/database/release/release-manifest.json']) -cne (Hash $authority.releaseManifest)){$releaseOkay=$false}
foreach($script in $artifactScripts){$scriptPath=$prefix+'specialized/database/release/'+[string](Field $script 'file');if(-not $evidence.ContainsKey($scriptPath)){$releaseOkay=$false;continue};if([string](Field $script 'sha256') -cne (Hash $evidence[$scriptPath])){$releaseOkay=$false}}
Record 'controlledExecutionPassed' ($outer.status -ceq 'pass' -and @($outer.checks|Where-Object{$_.id -ceq 'Database' -and $_.status -ceq 'pass'}).Count -eq 1)
Record 'evidenceFreshAndLocked' $true
Record 'migrationSafetyPassed' ($summary.result -ceq 'passed' -and $summary.checks.migrationSafety -eq $true -and $safety.result -ceq 'passed' -and $safety.automaticDownAllowed -eq $false -and @($safety.failures).Count -eq 0)
Record 'pendingModelChecksPassed' ($summary.checks.pendingModelChanges -eq $true)
Record 'releaseArtifactsComplete' $releaseOkay
Record 'migratorPublishPassed' ($summary.checks.publish -eq $true -and $published.Count -eq 1)
Record 'boundaryTestsPassed' ($summary.checks.boundaryTests -eq $true)
Record 'sqlServerMatrixPassed' ($summary.checks.sqlServerMatrix -eq $true)
Record 'migrationSourcesMatch' $sourcesOkay
if((@($policy.checkIds)-join '|') -cne (@('controlledExecutionPassed','evidenceFreshAndLocked','migrationSafetyPassed','pendingModelChecksPassed','releaseArtifactsComplete','migratorPublishPassed','boundaryTestsPassed','sqlServerMatrixPassed','migrationSourcesMatch')-join '|')){Stop-Adapter 'integrity-failure' 'Database check mapping drift.'}
if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
