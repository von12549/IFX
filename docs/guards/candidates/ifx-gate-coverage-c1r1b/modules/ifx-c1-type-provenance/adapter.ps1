Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$claim='IFX.C1.COMPILED_TYPE_PROVENANCE';$rule='C1-COMPILED-TYPE-PROVENANCE';$detector='ifx-c1-type-provenance'
$matched=0
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Text-Hash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Emit([string]$Status,[string]$Category,[string]$Message=''){
    $document=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@();coverage=@([ordered]@{claimId=$claim;matched=[int]$script:matched;minimum=7})}
    if($Message){$document.message=$Message}
    [Console]::Out.WriteLine(($document|ConvertTo-Json -Depth 30 -Compress))
}
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
function Is-Under([string]$Path,[string]$Root){
    $relative=[IO.Path]::GetRelativePath($Root,$Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)
}
function Resolve-Input([string]$Relative,[string]$Expected){
    if($Relative -cnotmatch '^[A-Za-z0-9._/-]+$' -or $Relative -match '(^|/)\.\.(/|$)' -or $Expected -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'invalid-input' 'Unsafe path or hash.'}
    $full=[IO.Path]::GetFullPath((Join-Path $target $Relative))
    if(-not(Is-Under $full $target)){Stop-Adapter 'unsafe-path' "Escaping input: $Relative"}
    $cursor=$full
    while(Is-Under $cursor $target){
        if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){
            $item=Get-Item -LiteralPath $cursor -Force
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked input: $Relative"}
        }
        if($cursor -ceq $target){break};$cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing input: $Relative"}
    if((Hash $full) -cne $Expected){Stop-Adapter 'integrity-failure' "Altered input: $Relative"}
    return $full
}
function Resolve-ExternalEvidence([string]$Relative,[string]$Expected){
    if($Relative -cnotmatch '^assemblies/[A-Za-z0-9.]+\.dll$' -and $Relative -cne 'assembly-manifest.json'){Stop-Adapter 'invalid-input' 'Unexpected external evidence path.'}
    if($Expected -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'invalid-input' 'Invalid external evidence hash.'}
    $full=[IO.Path]::GetFullPath((Join-Path $externalEvidence $Relative))
    if(-not(Is-Under $full $externalEvidence)){Stop-Adapter 'unsafe-path' 'External evidence escapes EvidenceRoot.'}
    $cursor=$full
    while(Is-Under $cursor $externalEvidence){
        if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){
            $item=Get-Item -LiteralPath $cursor -Force
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' 'External evidence crosses a link.'}
        }
        if($cursor -ceq $externalEvidence){break};$cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "External evidence missing: $Relative"}
    if((Hash $full) -cne $Expected){Stop-Adapter 'integrity-failure' "External evidence altered: $Relative"}
    return $full
}
function Parse-Time($Value){try{return [DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)}catch{Stop-Adapter 'integrity-failure' 'Invalid evidence time.'}}
function Tree-Lines([string]$Root){
    $files=@(foreach($relative in @('src','tests','tools')){
        $folder=Join-Path $Root $relative;if(-not [IO.Directory]::Exists($folder)){Stop-Adapter 'prerequisite-missing' "Missing source root: $relative"}
        Get-ChildItem -LiteralPath $folder -File -Recurse -Force|Where-Object{$_.Extension -in '.cs','.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]'}
    })
    $solution=Join-Path $Root 'IFX.sln';if(-not [IO.File]::Exists($solution)){Stop-Adapter 'prerequisite-missing' 'IFX.sln missing.'};$files+=Get-Item -LiteralPath $solution
    return @($files|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})
}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -Depth 100}catch{Stop-Adapter 'invalid-input' 'Malformed stage input.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'src'){Stop-Adapter 'invalid-input' 'Wrong stage or claim selection.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'invalid-input' 'TargetRoot must be absolute.'}
$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot missing.'}
$targetCommit=Resolve-TargetCommit $target
if(-not ($inputObject.PSObject.Properties.Name -contains 'evidenceRoot') -or -not [IO.Path]::IsPathFullyQualified([string]$inputObject.evidenceRoot)){Stop-Adapter 'invalid-input' 'External EvidenceRoot is required.'}
$externalEvidence=[IO.Path]::GetFullPath([string]$inputObject.evidenceRoot)
if(-not [IO.Directory]::Exists($externalEvidence) -or (Is-Under $externalEvidence $target) -or (Is-Under $target $externalEvidence)){Stop-Adapter 'unsafe-path' 'EvidenceRoot must be separate from TargetRoot.'}
$policyPath=Join-Path $PSScriptRoot 'policy.json'
if(-not [IO.File]::Exists($policyPath) -or (Hash $policyPath) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Type provenance policy drift.'}
try{$policy=Get-Content $policyPath -Raw|ConvertFrom-Json -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed type provenance policy.'}
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-c1-type-provenance-r1b' -or $policy.baseVersion -cne '1.1.3' -or $policy.configuration -cne 'Release' -or $policy.targetFramework -cne 'net8.0' -or $policy.maximumAgeSeconds -ne 3600 -or @($policy.assemblies).Count -ne 4){Stop-Adapter 'integrity-failure' 'Type provenance policy shape drift.'}
$lockRelative=[string]$inputObject.config.evidenceLockPath
if($lockRelative -cnotmatch '^artifacts/guards/p10-ifx-c1-r1b/type-runs/[a-f0-9]{32}/evidence-lock\.json$'){Stop-Adapter 'invalid-input' 'Uncontrolled type evidence path.'}
$lockPath=Resolve-Input $lockRelative ([string]$inputObject.config.evidenceLockSha256)
try{$lock=Get-Content $lockPath -Raw|ConvertFrom-Json -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed type evidence lock.'}
$prefix=$lockRelative.Substring(0,$lockRelative.Length-'evidence-lock.json'.Length)
if($lock.formatVersion -ne 1 -or $lock.gate -cne 'C1CompiledTypeProvenance' -or $lock.producer -cne 'ifx-c1-r1b-controlled-v1' -or $lock.result -cne 'passed' -or $lock.targetCommit -cnotmatch '^[a-f0-9]{40}$' -or $lock.configuration -cne $policy.configuration -or $lock.targetFramework -cne $policy.targetFramework -or @($lock.assemblies).Count -ne 4 -or $lock.policySha256 -cne (Hash $policyPath) -or $lock.v3TypeRuleSha256 -cne $policy.v3TypeRuleSha256 -or $lock.v3LayerPolicySha256 -cne $policy.v3LayerPolicySha256){Stop-Adapter 'integrity-failure' 'Type evidence lock shape or authority drift.'}
if($lock.targetCommit -cne $targetCommit){Stop-Adapter 'integrity-failure' 'Type lock target commit differs from TargetRoot HEAD.'}
$now=[DateTimeOffset]::UtcNow;$created=Parse-Time $lock.createdAt;$expires=Parse-Time $lock.expiresAt
if($created -gt $now.AddMinutes(5) -or $created -lt $now.AddSeconds(-[int]$policy.maximumAgeSeconds) -or $expires -le $now -or $expires -gt $created.AddSeconds([int]$policy.maximumAgeSeconds)){Stop-Adapter 'integrity-failure' 'Type evidence stale or future-dated.'}
$v3Rule=Resolve-Input 'docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json' ([string]$policy.v3TypeRuleSha256)
$v3Policy=Resolve-Input 'docs/guards/V3_ifx/stages/post/policy/layerguard.json' ([string]$policy.v3LayerPolicySha256)
$source=@(Tree-Lines $target)
if($source.Count -ne $lock.sourceFileCount -or (Text-Hash ($source -join "`n")) -cne $lock.sourceTreeSha256){Stop-Adapter 'integrity-failure' 'Source tree differs from type evidence.'}
if($lock.solutionLockPath -cnotmatch '^artifacts/guards/p10-ifx-c5b/solution-runs/[a-f0-9]{32}/evidence-lock\.json$' -or $lock.assemblyLockPath -cnotmatch '^artifacts/guards/p10-ifx-c5c/assembly-runs/[a-f0-9]{32}/evidence-lock\.json$'){Stop-Adapter 'invalid-input' 'Uncontrolled C5 lineage path.'}
$solutionPath=Resolve-Input ([string]$lock.solutionLockPath) ([string]$lock.solutionLockSha256)
$assemblyPath=Resolve-Input ([string]$lock.assemblyLockPath) ([string]$lock.assemblyLockSha256)
try{$solution=Get-Content $solutionPath -Raw|ConvertFrom-Json -Depth 100;$assembly=Get-Content $assemblyPath -Raw|ConvertFrom-Json -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed C5 lineage lock.'}
if($solution.gate -cne 'Solution' -or $solution.result -cne 'passed' -or $solution.producer -cne 'ifx-c5b-controlled-v1' -or $solution.targetCommit -cne $targetCommit -or $solution.sourceTreeSha256 -cne $lock.sourceTreeSha256 -or $solution.sourceFileCount -ne $lock.sourceFileCount -or $solution.projectCount -ne 81 -or $solution.totalTests -lt 1 -or (Parse-Time $solution.completedAt) -lt $now.AddHours(-24)){Stop-Adapter 'integrity-failure' 'C5b lineage is invalid or stale.'}
$script:matched++
if($assembly.gate -cne 'Assembly' -or $assembly.result -cne 'passed' -or $assembly.producer -cne 'ifx-c5c-controlled-v1' -or $assembly.targetCommit -cne $targetCommit -or $assembly.sourceTreeSha256 -cne $lock.sourceTreeSha256 -or $assembly.solutionLockPath -cne $lock.solutionLockPath -or $assembly.solutionLockSha256 -cne $lock.solutionLockSha256 -or (Parse-Time $assembly.completedAt) -lt $now.AddHours(-24)){Stop-Adapter 'integrity-failure' 'C5c lineage is invalid or stale.'}
$script:matched++
if($lock.manifestPath -cne ($prefix+'assembly-manifest.json')){Stop-Adapter 'integrity-failure' 'Manifest path drift.'}
$manifestPath=Resolve-Input ([string]$lock.manifestPath) ([string]$lock.manifestSha256)
$externalManifest=Resolve-ExternalEvidence 'assembly-manifest.json' ([string]$lock.manifestSha256)
try{$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed assembly manifest.'}
if($manifest.formatVersion -ne 1 -or @($manifest.assemblies).Count -ne 4){Stop-Adapter 'integrity-failure' 'Assembly manifest shape drift.'}
$script:matched++
$names=@($lock.assemblies|ForEach-Object name|Sort-Object);$expectedNames=@($policy.assemblies|ForEach-Object name|Sort-Object)
if(($names -join '|') -cne ($expectedNames -join '|')){Stop-Adapter 'integrity-failure' 'Assembly identity set drift.'}
foreach($expected in $policy.assemblies){
    $name=[string]$expected.name;$sourceRelative=[string]$expected.sourcePath
    $locked=@($lock.assemblies|Where-Object name -CEQ $name);$manifestRow=@($manifest.assemblies|Where-Object assemblyName -CEQ $name)
    if($locked.Count -ne 1 -or $manifestRow.Count -ne 1 -or $locked[0].sourcePath -cne $sourceRelative -or $locked[0].copiedPath -cne ($prefix+"assemblies/$name.dll") -or $manifestRow[0].path -cne "assemblies/$name.dll" -or $manifestRow[0].sha256 -cne $locked[0].sha256){Stop-Adapter 'integrity-failure' "Assembly manifest binding drift: $name"}
    $sourceDll=Resolve-Input $sourceRelative ([string]$locked[0].sha256)
    $copyDll=Resolve-Input ([string]$locked[0].copiedPath) ([string]$locked[0].sha256)
    $externalDll=Resolve-ExternalEvidence "assemblies/$name.dll" ([string]$locked[0].sha256)
    try{$identity=[Reflection.AssemblyName]::GetAssemblyName($copyDll).Name}catch{Stop-Adapter 'integrity-failure' "Unreadable DLL: $name"}
    if($identity -cne $name){Stop-Adapter 'integrity-failure' "DLL identity drift: $name"}
    if($name -ceq 'IFX.Modules.CRM.Domain'){
        $row=@($assembly.assemblies|Where-Object id -CEQ $name)
        if($row.Count -ne 1 -or $row[0].path -cne $sourceRelative -or $row[0].sha256 -cne $locked[0].sha256){Stop-Adapter 'integrity-failure' 'CRM Domain differs from C5c DLL.'}
    }
    $script:matched++
}
if($matched -ne 7){Stop-Adapter 'integrity-failure' 'Type provenance coverage drift.'}
Emit 'pass' 'success'
