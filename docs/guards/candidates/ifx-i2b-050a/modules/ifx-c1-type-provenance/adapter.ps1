Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# 0.5.0-a: evidence locks are staged into EvidenceRoot by the trusted workflow
# (candidates/ifx-i2b-050a/Invoke-IFX050EvidenceProducers.ps1); the Profile names no lock. locks/staging.json maps each
# producer run prefix (artifacts/guards/.../<run>/) to its staged directory, and records the producer that ran.
function Get-IFX050StagedGate([string]$EvidenceRootValue,[string]$TargetRootValue,[string]$Gate,$Producer){
    if([string]::IsNullOrWhiteSpace($EvidenceRootValue) -or -not [IO.Path]::IsPathFullyQualified($EvidenceRootValue)){Stop-Adapter 'invalid-input' 'EvidenceRoot is required for staged evidence.'}
    $root=[IO.Path]::GetFullPath($EvidenceRootValue).TrimEnd([IO.Path]::DirectorySeparatorChar);$targetFull=[IO.Path]::GetFullPath($TargetRootValue).TrimEnd([IO.Path]::DirectorySeparatorChar)
    if(-not [IO.Directory]::Exists($root)){Stop-Adapter 'prerequisite-missing' 'EvidenceRoot is missing.'}
    $a=[IO.Path]::GetRelativePath($targetFull,$root);$b=[IO.Path]::GetRelativePath($root,$targetFull)
    if(-not($a -eq '..' -or $a.StartsWith('..'+[IO.Path]::DirectorySeparatorChar) -or [IO.Path]::IsPathRooted($a)) -or -not($b -eq '..' -or $b.StartsWith('..'+[IO.Path]::DirectorySeparatorChar) -or [IO.Path]::IsPathRooted($b))){Stop-Adapter 'unsafe-path' 'EvidenceRoot must be separate from TargetRoot.'}
    $locks=Join-Path $root 'locks';$manifest=Join-Path $locks 'staging.json'
    foreach($p in @($locks,$manifest)){if(([IO.File]::Exists($p) -or [IO.Directory]::Exists($p)) -and ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){Stop-Adapter 'unsafe-path' 'Staged evidence crosses a link.'}}
    if(-not [IO.File]::Exists($manifest)){Stop-Adapter 'prerequisite-missing' 'Staged evidence manifest is missing.'}
    try{$staging=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json -Depth 20}catch{Stop-Adapter 'integrity-failure' 'Staged evidence manifest is malformed.'}
    if($staging.formatVersion -ne 1 -or $staging.kind -cne 'ifx-050a-evidence-staging'){Stop-Adapter 'integrity-failure' 'Staged evidence manifest identity drift.'}
    $script:stagedRoots=[Collections.Generic.List[object]]::new()
    foreach($g in @($staging.gates)){
        $prefix=[string]$g.prefix;$dir=[string]$g.stagedRoot
        if($prefix -cnotmatch '^artifacts/guards/[A-Za-z0-9._/-]+/$' -or $prefix -match '(^|/)\.\.(/|$)' -or $dir -cnotmatch '^locks/[a-z]+$'){Stop-Adapter 'integrity-failure' 'Staged evidence entry is unsafe.'}
        $script:stagedRoots.Add([pscustomobject]@{gate=[string]$g.gate;prefix=$prefix;root=[IO.Path]::GetFullPath((Join-Path $root $dir))})
    }
    $own=@($staging.gates|Where-Object{[string]$_.gate -ceq $Gate})
    if($own.Count -ne 1){Stop-Adapter 'prerequisite-missing' "Staged evidence for gate $Gate is missing."}
    $o=$own[0]
    if([string]$o.producer.id -cne [string]$Producer.id -or [string]$o.producer.script -cne [string]$Producer.script -or [string]$o.producer.scriptSha256 -cne [string]$Producer.scriptSha256){Stop-Adapter 'integrity-failure' "Staged evidence was not produced by the pinned producer: $Gate"}
    if([string]$o.lockPath -cne ([string]$o.prefix+'evidence-lock.json') -or [string]$o.lockSha256 -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'integrity-failure' 'Staged lock entry is invalid.'}
    return $o
}
function Map-StagedPath([string]$Relative){
    if($null -eq $script:stagedRoots){return $null}
    foreach($s in $script:stagedRoots){if($Relative.StartsWith($s.prefix,[StringComparison]::Ordinal)){return [pscustomobject]@{root=$s.root;full=[IO.Path]::GetFullPath((Join-Path $s.root $Relative.Substring($s.prefix.Length)))}}}
    return $null
}
$script:stagedRoots=$null
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
    $base=$target;$mapped=Map-StagedPath $Relative;if($null -ne $mapped){$base=$mapped.root;$full=$mapped.full}else{$full=[IO.Path]::GetFullPath((Join-Path $target $Relative))}
    if(-not(Is-Under $full $base)){Stop-Adapter 'unsafe-path' "Escaping input: $Relative"}
    $cursor=$full
    while(Is-Under $cursor $base){
        if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){
            $item=Get-Item -LiteralPath $cursor -Force
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked input: $Relative"}
        }
        if($cursor -ceq $base){break};$cursor=[IO.Path]::GetDirectoryName($cursor)
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
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-c1-type-provenance-050a' -or $policy.lockBinding -cne 'staged-evidence' -or $policy.gate -cne 'type' -or $policy.baseVersion -cne '1.1.3' -or $policy.configuration -cne 'Release' -or $policy.targetFramework -cne 'net8.0' -or $policy.maximumAgeSeconds -ne 3600 -or @($policy.assemblies).Count -ne 4){Stop-Adapter 'integrity-failure' 'Type provenance policy shape drift.'}
$staged=Get-IFX050StagedGate ([string]$inputObject.evidenceRoot) $target 'type' $policy.producer;$lockRelative=[string]$staged.lockPath
if($lockRelative -cnotmatch '^artifacts/guards/p10-ifx-c1-r1b/type-runs/[a-f0-9]{32}/evidence-lock\.json$'){Stop-Adapter 'invalid-input' 'Uncontrolled type evidence path.'}
$lockPath=Resolve-Input $lockRelative ([string]$staged.lockSha256)
try{$lock=Get-Content $lockPath -Raw|ConvertFrom-Json -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Malformed type evidence lock.'}
$prefix=$lockRelative.Substring(0,$lockRelative.Length-'evidence-lock.json'.Length)
if($lock.formatVersion -ne 1 -or $lock.gate -cne 'C1CompiledTypeProvenance' -or $lock.producer -cne 'ifx-c1-r1b-controlled-v1' -or $lock.result -cne 'passed' -or $lock.targetCommit -cnotmatch '^[a-f0-9]{40}$' -or $lock.configuration -cne $policy.configuration -or $lock.targetFramework -cne $policy.targetFramework -or @($lock.assemblies).Count -ne 4 -or $lock.policySha256 -cne [string]$policy.producer.policySha256 -or $lock.v3TypeRuleSha256 -cne $policy.v3TypeRuleSha256 -or $lock.v3LayerPolicySha256 -cne $policy.v3LayerPolicySha256){Stop-Adapter 'integrity-failure' 'Type evidence lock shape or authority drift.'}
if($lock.targetCommit -cne $targetCommit){Stop-Adapter 'integrity-failure' 'Type lock target commit differs from TargetRoot HEAD.'}
$now=[DateTimeOffset]::UtcNow;$created=Parse-Time $lock.createdAt;$expires=Parse-Time $lock.expiresAt
if($created -gt $now.AddMinutes(5) -or $created -lt $now.AddSeconds(-[int]$policy.maximumAgeSeconds) -or $expires -le $now -or $expires -gt $created.AddSeconds([int]$policy.maximumAgeSeconds)){Stop-Adapter 'integrity-failure' 'Type evidence stale or future-dated.'}
# 0.5.0-a: the V3_ifx type rule and layer policy are packaged with the module (no V3_ifx read).
$v3Rule=Join-Path $PSScriptRoot 'embedded/type-rule.json';if(-not [IO.File]::Exists($v3Rule) -or (Hash $v3Rule) -cne [string]$policy.v3TypeRuleSha256){Stop-Adapter 'integrity-failure' 'Packaged type rule drift.'}
$v3Policy=Join-Path $PSScriptRoot 'embedded/layer-policy.json';if(-not [IO.File]::Exists($v3Policy) -or (Hash $v3Policy) -cne [string]$policy.v3LayerPolicySha256){Stop-Adapter 'integrity-failure' 'Packaged layer policy drift.'}
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
