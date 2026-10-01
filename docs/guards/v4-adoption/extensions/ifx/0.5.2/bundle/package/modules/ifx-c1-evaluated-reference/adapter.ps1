Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# 0.5.2: evidence locks are staged into EvidenceRoot by the trusted workflow
# (docs/guards/v4-adoption/ci/Invoke-IFXEvidenceProducers.ps1); the Profile names no lock. locks/staging.json maps each
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
$claim='IFX.C1.EVALUATED_REFERENCE_GRAPH';$detector='ifx-c1-evaluated-reference';$matched=0
$findings=[Collections.Generic.List[object]]::new()
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Emit([string]$Status,[string]$Category,[string]$Message=''){
    $result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@([ordered]@{claimId=$claim;matched=[int]$script:matched;minimum=1})}
    if($Message){$result.message=$Message};[Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 50 -Compress))
}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Under([string]$Path,[string]$Root){$r=[IO.Path]::GetRelativePath($Root,$Path);$r -ne '..' -and -not [IO.Path]::IsPathRooted($r) -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Resolve-Input([string]$Relative,[string]$Expected){
    if($Relative -cnotmatch '^[A-Za-z0-9._/-]+$' -or $Relative -match '(^|/)\.\.(/|$)' -or $Expected -cnotmatch '^[a-f0-9]{64}$'){Stop-Adapter 'invalid-input' 'Unsafe path or hash.'}
    $base=$target;$mapped=Map-StagedPath $Relative;if($null -ne $mapped){$base=$mapped.root;$full=$mapped.full}else{$full=[IO.Path]::GetFullPath((Join-Path $target $Relative))}
    if(-not(Under $full $base)){Stop-Adapter 'unsafe-path' "Escaping path: $Relative"}
    $cursor=$full
    while(Under $cursor $base){
        if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){
            $item=Get-Item -LiteralPath $cursor -Force
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked path: $Relative"}
        }
        if($cursor -ceq $base){break};$cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing input: $Relative"}
    if((Hash $full) -cne $Expected){Stop-Adapter 'integrity-failure' "Altered input: $Relative"}
    return $full
}
function Matches([string]$Name,[string]$Pattern){[Management.Automation.WildcardPattern]::new($Pattern,[Management.Automation.WildcardOptions]::IgnoreCase).IsMatch($Name)}
function Ring([string]$Name){
    $hits=@(foreach($entry in $referencePolicy.rings.PSObject.Properties){if(@($entry.Value|Where-Object{Matches $Name ([string]$_)}).Count -gt 0){$entry.Name}})
    if($hits.Count -gt 1){Stop-Adapter 'integrity-failure' "Overlapping rings: $Name"}
    if($hits.Count -eq 0){return 'Outside'};return $hits[0]
}
function Module([string]$Path,[string]$Name,[string]$Role){
    foreach($pattern in $ownershipPolicy.ownership.modulePatterns){
        $expression='^'+[Regex]::Escape([string]$pattern).Replace('\{module}','(?<module>[^.]+)').Replace('\*','.*')+'$'
        $hit=[Regex]::Match($Name,$expression,[Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if($hit.Success){return $hit.Groups['module'].Value}
    }
    if($Role -in @('RuntimeHost','Test')){return $null}
    return [IO.Path]::GetFileName([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($Path)))
}
function Finding([string]$Rule,[string]$Subject){$findings.Add([ordered]@{ruleId=$Rule;subject=$Subject;evidenceKind='project-reference-evaluated';detectorId=$detector;severity='blocking'})}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -Depth 100}catch{Stop-Adapter 'invalid-input' 'Malformed stage input.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'src'){Stop-Adapter 'invalid-input' 'Wrong stage or claim.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'invalid-input' 'Absolute TargetRoot required.'}
$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot missing.'}
$policyPath=Join-Path $PSScriptRoot 'policy.json'
if(-not [IO.File]::Exists($policyPath) -or (Hash $policyPath) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Module policy drift.'}
try{$policy=Get-Content $policyPath -Raw|ConvertFrom-Json -Depth 50}catch{Stop-Adapter 'integrity-failure' 'Malformed module policy.'}
if($policy.id -cne 'ifx-c1-evaluated-reference-050a' -or $policy.lockBinding -cne 'staged-evidence' -or $policy.gate -cne 'graph' -or $policy.baseVersion -cne '1.1.3' -or $policy.sdk -cne '10.0.303' -or $policy.configuration -cne 'Release' -or $policy.targetFramework -cne 'net8.0' -or $policy.projectCount -ne 58 -or $policy.maximumAgeSeconds -ne 3600 -or @($policy.sourcePolicies).Count -ne 2){Stop-Adapter 'integrity-failure' 'Module policy shape drift.'}
$references=@()
foreach($row in $policy.sourcePolicies){$source=Join-Path $PSScriptRoot ([string]$row.embedded);if(-not [IO.File]::Exists($source) -or (Hash $source) -cne [string]$row.sha256){Stop-Adapter 'integrity-failure' "Packaged C1 source policy drift: $($row.path)"};$references+=Get-Content $source -Raw|ConvertFrom-Json -Depth 100}
$referencePolicy=$references[0];$ownershipPolicy=$references[1]
if($referencePolicy.id -cne 'ifx-reference-cycle-c1n' -or $ownershipPolicy.id -cne 'ifx-ownership-graph-c1e'){Stop-Adapter 'integrity-failure' 'C1 source policy identity drift.'}
$staged=Get-IFX050StagedGate ([string]$inputObject.evidenceRoot) $target 'graph' $policy.producer;$lockRelative=[string]$staged.lockPath
if($lockRelative -cnotmatch '^artifacts/guards/v4a-producers/graph-runs/[a-f0-9]{32}/evidence-lock\.json$'){Stop-Adapter 'invalid-input' 'Uncontrolled lock path.'}
$lockPath=Resolve-Input $lockRelative ([string]$staged.lockSha256)
try{$lock=Get-Content $lockPath -Raw|ConvertFrom-Json -Depth 100 -DateKind String}catch{Stop-Adapter 'integrity-failure' 'Malformed graph lock.'}
if($lock.formatVersion -ne 1 -or $lock.gate -cne 'C1EvaluatedReferenceGraph' -or $lock.producer -cne 'ifx-v4a-graph-v1' -or $lock.result -cne 'passed' -or $lock.sdk -cne $policy.sdk -or $lock.configuration -cne $policy.configuration -or $lock.targetFramework -cne $policy.targetFramework -or $lock.policySha256 -cne [string]$policy.producer.policySha256 -or @($lock.projects).Count -ne 58 -or @($lock.projectStates).Count -ne 58 -or @($lock.edges).Count -lt 1 -or $lock.evaluatedReferenceCount -ne @($lock.edges).Count -or $lock.rawReferenceCount -lt 1 -or $lock.rawEvaluatedDelta -ne ($lock.evaluatedReferenceCount-$lock.rawReferenceCount) -or (@($lock.arguments)-join '|') -cne '-getProperty:TargetFramework,DisableTransitiveProjectReferences|-getItem:ProjectReference|-p:Configuration=Release|-nologo'){Stop-Adapter 'integrity-failure' 'Graph lock shape or authority drift.'}
try{$created=[DateTimeOffset]::Parse([string]$lock.createdAt);$expires=[DateTimeOffset]::Parse([string]$lock.expiresAt)}catch{Stop-Adapter 'integrity-failure' 'Invalid graph lock time.'}
$now=[DateTimeOffset]::UtcNow
if($created -gt $now.AddMinutes(5) -or $created -lt $now.AddSeconds(-[int]$policy.maximumAgeSeconds) -or $expires -le $now -or $expires -gt $created.AddSeconds([int]$policy.maximumAgeSeconds)){Stop-Adapter 'integrity-failure' 'Graph lock stale or future-dated.'}
$commit=(& git -C $target rev-parse HEAD).Trim().ToLowerInvariant()
if($LASTEXITCODE -ne 0 -or $commit -cne $lock.targetCommit){Stop-Adapter 'integrity-failure' 'Target commit drift.'}
$actualProjects=@(Get-ChildItem -LiteralPath (Join-Path $target 'src') -Recurse -File -Filter '*.csproj'|Where-Object{$_.FullName -notmatch '[\\/](bin|obj)[\\/]'}|ForEach-Object{[IO.Path]::GetRelativePath($target,$_.FullName).Replace('\','/')}|Sort-Object)
if(($actualProjects -join '|') -cne (@($lock.projects)-join '|')){Stop-Adapter 'integrity-failure' 'Evaluated project set drift.'}
$actualInputs=@(Get-ChildItem -LiteralPath (Join-Path $target 'src') -Recurse -File|Where-Object{$_.Extension -in '.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj)[\\/]'}|ForEach-Object{[IO.Path]::GetRelativePath($target,$_.FullName).Replace('\','/')}|Sort-Object)
$actualInputs=@($actualInputs)+@('Directory.Build.props','Directory.Packages.props')|Sort-Object
if(($actualInputs -join '|') -cne (@($lock.inputs|ForEach-Object path)-join '|')){Stop-Adapter 'integrity-failure' 'Evaluation input set drift.'}
foreach($row in $lock.inputs){[void](Resolve-Input ([string]$row.path) ([string]$row.sha256))}
$node=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($path in $lock.projects){
    $name=[IO.Path]::GetFileNameWithoutExtension([string]$path);$role=Ring $name
    $states=@($lock.projectStates|Where-Object project -CEQ ([string]$path))
    if($states.Count -ne 1 -or $states[0].disableTransitive -isnot [bool]){Stop-Adapter 'integrity-failure' 'Project evaluation state drift.'}
    $node.Add([string]$path,[pscustomobject]@{path=[string]$path;name=$name;ring=$role;module=(Module ([string]$path) $name $role);disabled=[bool]$states[0].disableTransitive})
}
$adjacency=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($path in $lock.projects){$adjacency.Add([string]$path,[Collections.Generic.List[object]]::new())}
foreach($edge in $lock.edges){
    $from=[string]$edge.from;$to=[string]$edge.to;$definer=[string]$edge.definer
    if(-not $node.ContainsKey($from) -or -not $node.ContainsKey($to) -or $actualInputs -cnotcontains $definer -or $edge.stopsFlow -isnot [bool]){Stop-Adapter 'integrity-failure' 'Graph edge leaves locked project or import set.'}
    $adjacency[$from].Add($edge)
    $left=$node[$from];$right=$node[$to];if($left.ring -ceq 'Outside'){continue}
    $script:matched++
    $directions=@($referencePolicy.allowedDependencies.PSObject.Properties[$left.ring].Value)
    $directionOkay=$right.ring -ceq 'Outside' -or $right.ring -ceq $left.ring -or $directions -contains $right.ring
    $shared=$left.ring -notin @('Domain','Outside') -and @($referencePolicy.sharedPrimitiveProjects) -inotcontains $left.name -and @($referencePolicy.sharedPrimitiveProjects) -icontains $right.name
    if(-not $directionOkay -and -not $shared){Finding 'C1-EVALUATED-RING-REFERENCE' "$from -> $to [direction]";continue}
    $allowed=@($referencePolicy.allowedReferences.PSObject.Properties[$left.ring].Value)
    if(-not $shared -and @($allowed|Where-Object{Matches $right.name ([string]$_)}).Count -eq 0){Finding 'C1-EVALUATED-RING-REFERENCE' "$from -> $to [allow-list]"}
    if($right.ring -ceq 'Outside' -or $shared){continue}
    $constraints=@($ownershipPolicy.referenceScopes|Where-Object{$_.from -ieq $left.ring -and $_.to -ieq $right.ring})
    if($constraints.Count -eq 0){continue}
    $relation=if($null -ne $left.module -and [StringComparer]::OrdinalIgnoreCase.Equals([string]$left.module,[string]$right.module)){'own'}else{'foreign'}
    if(@($constraints|Where-Object{$_.ownership -ceq 'any' -or $_.ownership -ceq $relation}).Count -eq 0){Finding 'C1-EVALUATED-OWNERSHIP' "$from -> $to [$relation]"}
}
foreach($rootPath in $lock.projects){
    $root=$node[[string]$rootPath]
    if($root.ring -ceq 'Outside' -or $root.disabled){continue}
    $reached=[Collections.Generic.Dictionary[string,int]]::new([StringComparer]::OrdinalIgnoreCase)
    $frontier=[Collections.Generic.Queue[object]]::new()
    foreach($edge in $adjacency[[string]$rootPath]){
        if(-not $reached.ContainsKey([string]$edge.to)){$reached.Add([string]$edge.to,1);$frontier.Enqueue([pscustomobject]@{path=[string]$edge.to;depth=1})}
    }
    while($frontier.Count -gt 0){
        $current=$frontier.Dequeue();$currentNode=$node[[string]$current.path]
        if(@($ownershipPolicy.transitiveBoundaryRoles) -contains $currentNode.ring){continue}
        foreach($edge in $adjacency[[string]$current.path]){
            if($edge.stopsFlow -or $reached.ContainsKey([string]$edge.to) -or [StringComparer]::OrdinalIgnoreCase.Equals([string]$edge.to,[string]$rootPath)){continue}
            $depth=[int]$current.depth+1;$reached.Add([string]$edge.to,$depth);$frontier.Enqueue([pscustomobject]@{path=[string]$edge.to;depth=$depth})
        }
    }
    foreach($targetPath in $reached.Keys){
        if($reached[$targetPath] -lt 2){continue}
        $right=$node[$targetPath]
        if($right.ring -ceq 'Outside'){continue}
        $directions=@($ownershipPolicy.allowedDependencies.PSObject.Properties[$root.ring].Value)
        if($right.ring -cne $root.ring -and $directions -notcontains $right.ring){continue}
        $shared=$root.ring -notin @('Domain','Outside') -and @($ownershipPolicy.sharedPrimitiveProjects) -inotcontains $root.name -and @($ownershipPolicy.sharedPrimitiveProjects) -icontains $right.name
        if($shared){continue}
        $constraints=@($ownershipPolicy.referenceScopes|Where-Object{$_.from -ieq $root.ring -and $_.to -ieq $right.ring})
        if($constraints.Count -eq 0){continue}
        $relation=if($null -ne $root.module -and [StringComparer]::OrdinalIgnoreCase.Equals([string]$root.module,[string]$right.module)){'own'}else{'foreign'}
        if(@($constraints|Where-Object{$_.ownership -ceq 'any' -or $_.ownership -ceq $relation}).Count -eq 0){Finding 'C1-EVALUATED-OWNERSHIP' "$rootPath -> $targetPath [transitive $relation]"}
    }
}
if($matched -lt 1){Stop-Adapter 'integrity-failure' 'Zero in-scope evaluated edges.'}
Emit $(if($findings.Count -eq 0){'pass'}else{'fail'}) $(if($findings.Count -eq 0){'success'}else{'findings-blocking'})
