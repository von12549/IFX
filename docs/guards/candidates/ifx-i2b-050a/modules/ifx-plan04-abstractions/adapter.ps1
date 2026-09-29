Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
function Get-PinSha256([string]$Path){
    # 0.5.0-a (R5): a governance pin is the SHA-256 of the UTF-8 text with line endings normalized to LF; binary files by raw bytes.
    if([IO.Path]::GetExtension($Path).ToLowerInvariant() -in @('.png','.jpg','.jpeg','.gif','.ico','.pdf','.zip','.dll','.exe')){return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()}
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")))).ToLowerInvariant()
}
$claim='IFX.C4A.PLAN04_ABSTRACTIONS';$rule='PLAN04-ABSTRACTIONS';$detector='ifx-plan04-abstractions';$findings=[Collections.Generic.List[object]]::new();$matched=0
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Hash-Text([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Emit([string]$Status,[string]$Category,[string]$Message=''){$result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@([ordered]@{claimId=$claim;matched=[int]$matched;minimum=1})};if($Message){$result.message=$Message};[Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 40 -Compress))}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Is-Under([string]$Path,[string]$Root){$r=[IO.Path]::GetRelativePath($Root,$Path);$r -ne '..' -and -not [IO.Path]::IsPathRooted($r) -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Assert-NoLink([string]$Path,[string]$Root){$cursor=[IO.Path]::GetFullPath($Path);while(Is-Under $cursor $Root){if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked authority: $Path"}};if($cursor -ceq $Root){break};$parent=[IO.Path]::GetDirectoryName($cursor);if(-not $parent -or $parent -ceq $cursor){break};$cursor=$parent}}
function Resolve-Authority([string]$Relative,[string]$Expected){if([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)' -or ($Expected -and $Expected -cnotmatch '^[a-f0-9]{64}$')){Stop-Adapter 'invalid-input' 'Authority path or hash invalid.'};$full=[IO.Path]::GetFullPath((Join-Path $target $Relative));if(-not(Is-Under $full $target)){Stop-Adapter 'unsafe-path' "Authority escapes TargetRoot: $Relative"};Assert-NoLink $full $target;if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing authority: $Relative"};if($Expected -and (Get-PinSha256 $full) -cne $Expected){Stop-Adapter 'integrity-failure' "Stale governance authority: $Relative"};return $full}
function ProjectName([string]$Path){[IO.Path]::GetFileNameWithoutExtension($Path.Replace('\','/'))}
function DirectoryName([string]$Path){[IO.Path]::GetFileName($Path.Replace('\','/'))}
function Equal-Set([object[]]$Left,[object[]]$Right){(@($Left|Sort-Object)-join '|') -ceq (@($Right|Sort-Object)-join '|')}
function Record([string]$Id,[bool]$Pass){$script:matched++;if(-not $Pass){$findings.Add([ordered]@{ruleId=$rule;subject=$Id;evidenceKind='abstractions-source';detectorId=$detector;severity='blocking'})}}
$legacyPattern='^IFX\.(Modules|Platform)\..+\.Abstractions$'
function Validate-State($state){$errors=[Collections.Generic.HashSet[string]]::new();if(@($state.directories|Where-Object{(DirectoryName ([string]$_)) -match $legacyPattern}).Count -gt 0){[void]$errors.Add('legacy-abstractions-directory')};if(@($state.projects|Where-Object{(ProjectName ([string]$_)) -match $legacyPattern}).Count -gt 0){[void]$errors.Add('legacy-abstractions-project')};if(@($state.projectReferences|Where-Object{(ProjectName ([string]$_)) -match $legacyPattern}).Count -gt 0){[void]$errors.Add('legacy-abstractions-reference')};if(@($state.solutionProjects|Where-Object{(ProjectName ([string]$_)) -match $legacyPattern}).Count -gt 0){[void]$errors.Add('legacy-abstractions-solution-entry')};if(@($settings.requiredContracts|Where-Object{$_ -notin @($state.solutionProjects|ForEach-Object{ProjectName ([string]$_)})}).Count -gt 0){[void]$errors.Add('contracts-project-missing-from-solution')};if(@($state.ambiguousCompositionArtifacts).Count -gt 0){[void]$errors.Add('ambiguous-composition-abstractions-name')};if(@($state.legacyAuthorizationNamespaces).Count -gt 0){[void]$errors.Add('legacy-authorization-abstractions-namespace')};if($settings.requiredCompositionProject -notin @($state.solutionProjects|ForEach-Object{ProjectName ([string]$_)})){[void]$errors.Add('composition-project-missing-from-solution')};if($state.layerGuardEnforcesRetirement -ne $true){[void]$errors.Add('layerguard-retirement-rule-missing')};if($state.layerGuardNamingIsCurrent -ne $true){[void]$errors.Add('layerguard-composition-name-stale')};return @($errors|Sort-Object)}
function Scan-Root([string]$Root){
    $pending=[Collections.Generic.Queue[string]]::new();$pending.Enqueue($Root)
    while($pending.Count -gt 0){
        $current=$pending.Dequeue()
        foreach($directoryPath in [IO.Directory]::EnumerateDirectories($current)){
            if(([IO.File]::GetAttributes($directoryPath) -band [IO.FileAttributes]::ReparsePoint) -ne 0){Stop-Adapter 'unsafe-path' 'Abstractions source tree contains a link.'}
            if([IO.Path]::GetFileName($directoryPath) -in @('bin','obj','node_modules','dist','coverage','.vite')){continue}
            $scanDirs.Add([pscustomobject]@{FullName=$directoryPath;Name=[IO.Path]::GetFileName($directoryPath);RelativePath=[IO.Path]::GetRelativePath($target,$directoryPath).Replace('\','/')});$pending.Enqueue($directoryPath)
        }
        foreach($filePath in [IO.Directory]::EnumerateFiles($current,'*',[IO.SearchOption]::TopDirectoryOnly)){
            $extension=[IO.Path]::GetExtension($filePath);if($extension -notin @('.cs','.csproj')){continue}
            if(([IO.File]::GetAttributes($filePath) -band [IO.FileAttributes]::ReparsePoint) -ne 0){Stop-Adapter 'unsafe-path' 'Abstractions source tree contains a link.'}
            $scanFiles.Add([pscustomobject]@{FullName=$filePath;Name=[IO.Path]::GetFileName($filePath);BaseName=[IO.Path]::GetFileNameWithoutExtension($filePath);Extension=$extension;RelativePath=[IO.Path]::GetRelativePath($target,$filePath).Replace('\','/');Sha256=Hash $filePath;Text=[IO.File]::ReadAllText($filePath)})
        }
    }
}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Stage input malformed.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'src'){Stop-Adapter 'invalid-input' 'Stage or claim selection invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'};$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot);if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot missing.'};Assert-NoLink $target $target
$settingsFile=Join-Path $PSScriptRoot 'policy.json';if(-not [IO.File]::Exists($settingsFile) -or (Hash $settingsFile) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Abstractions module policy drift.'}
try{$settings=Get-Content $settingsFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Abstractions module policy malformed.'}
if($settings.formatVersion -ne 1 -or $settings.id -cne 'ifx-plan04-abstractions-050a' -or $settings.pinPolicy -cne 'governance-only' -or @($settings.checkIds).Count -ne 11 -or @($settings.requiredContracts).Count -ne 7){Stop-Adapter 'integrity-failure' 'Abstractions module identity drift.'}
$solutionFile=Resolve-Authority ([string]$settings.solutionPath) ('');$projectPolicyFile=Join-Path $PSScriptRoot ([string]$settings.embeddedProjectNamePolicy.path);$referencePolicyFile=Join-Path $PSScriptRoot ([string]$settings.embeddedReferencePolicy.path)
# 0.5.0-a: the project-name and reference policies are packaged with the module (no docs/guards/candidates read).
if(-not [IO.File]::Exists($projectPolicyFile) -or (Hash $projectPolicyFile) -cne [string]$settings.embeddedProjectNamePolicy.sha256 -or -not [IO.File]::Exists($referencePolicyFile) -or (Hash $referencePolicyFile) -cne [string]$settings.embeddedReferencePolicy.sha256){Stop-Adapter 'integrity-failure' 'Packaged V4 project or reference policy drift.'}
try{$projectPolicy=Get-Content $projectPolicyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$referencePolicy=Get-Content $referencePolicyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'V4 project or reference policy malformed.'}
$scanFiles=[Collections.Generic.List[object]]::new();$scanDirs=[Collections.Generic.List[object]]::new()
foreach($relativeRoot in $settings.scanRoots){$root=[IO.Path]::GetFullPath((Join-Path $target ([string]$relativeRoot)));if(-not(Is-Under $root $target) -or -not [IO.Directory]::Exists($root)){Stop-Adapter 'prerequisite-missing' "Scan root missing: $relativeRoot"};Assert-NoLink $root $target;Scan-Root $root}
if($scanFiles.Count -lt 20){$findings.Add([ordered]@{ruleId=$rule;subject='zero-subject';evidenceKind='coverage';detectorId=$detector;severity='blocking'});Emit 'fail' 'findings-blocking';exit 0}
$inventoryLines=@(@($scanDirs|Sort-Object FullName|ForEach-Object{"D|$($_.RelativePath)"})+@($scanFiles|Sort-Object FullName|ForEach-Object{"F|$($_.RelativePath)|$($_.Sha256)"})) -join "`n";<# 0.5.0-a: live tree; no Profile fingerprint #>
$fixtureRoot=[IO.Path]::GetFullPath((Join-Path $target ([string]$settings.fixtureRoot)));if(-not(Is-Under $fixtureRoot $target) -or -not [IO.Directory]::Exists($fixtureRoot)){Stop-Adapter 'prerequisite-missing' 'Fixture root missing.'};Assert-NoLink $fixtureRoot $target
$fixtures=@(Get-ChildItem -LiteralPath $fixtureRoot -File -Filter 'abstractions-*.json' -Force|Sort-Object Name);foreach($file in $fixtures){Assert-NoLink $file.FullName $target};$fixtureLines=@($fixtures|ForEach-Object{"$($_.Name)|$(Hash $_.FullName)"}) -join "`n";<# 0.5.0-a: live tree; no Profile fingerprint #>
$solutionText=[IO.File]::ReadAllText($solutionFile);$solutionProjects=@([Regex]::Matches($solutionText,'(?m)^Project\("[^"]+"\) = "[^"]+", "([^"]+\.csproj)"')|ForEach-Object{$_.Groups[1].Value});$projects=@($scanFiles|Where-Object Extension -eq '.csproj');$sourceFiles=@($scanFiles|Where-Object Extension -eq '.cs')
$projectRefs=[Collections.Generic.List[string]]::new();foreach($file in $projects){try{[xml]$xml=$file.Text;foreach($node in $xml.SelectNodes('//ProjectReference')){if($node.HasAttribute('Include')){$projectRefs.Add([string]$node.GetAttribute('Include'))}}}catch{Stop-Adapter 'integrity-failure' "Malformed project: $($file.FullName)"}}
$legacyDirs=@($scanDirs|Where-Object{$_.FullName -match '[\\/]src[\\/](Modules|Platform)[\\/]' -and $_.Name -match $legacyPattern}|ForEach-Object FullName)
$ambiguous=@($scanDirs|Where-Object{$_.Name -ceq 'App.Abstractions' -and $_.FullName -match '[\\/]src[\\/]BuildingBlocks[\\/]'}|ForEach-Object FullName)+@($projects|Where-Object BaseName -CEQ 'App.Abstractions'|ForEach-Object FullName)+@($projectRefs|Where-Object{(ProjectName $_) -ceq 'App.Abstractions'})+@($solutionProjects|Where-Object{(ProjectName $_) -ceq 'App.Abstractions'})
$legacyNamespaces=@($sourceFiles|Where-Object{$_.Text -match 'IFX\.BuildingBlocks\.Security\.Authorization\.Abstractions'}|ForEach-Object FullName)
$layerRetirement=(@($projectPolicy.forbiddenProjectNames) -contains '*.Abstractions' -and $projectPolicy.ruleId -ceq 'PROJECT-NAME-FORBIDDEN' -and $projectPolicy.claimId -ceq 'IFX.C1.PROJECT_NAME_FORBIDDEN')
$layerNaming=('App.Abstractions' -notin @($referencePolicy.allowedReferences.Composition) -and 'App.Abstractions' -notin @($referencePolicy.allowedReferences.RuntimeHost) -and $settings.requiredCompositionProject -in @($referencePolicy.allowedReferences.RuntimeHost))
$state=[ordered]@{directories=$legacyDirs;projects=@($projects|ForEach-Object FullName);projectReferences=@($projectRefs);solutionProjects=$solutionProjects;ambiguousCompositionArtifacts=$ambiguous;legacyAuthorizationNamespaces=$legacyNamespaces;layerGuardEnforcesRetirement=$layerRetirement;layerGuardNamingIsCurrent=$layerNaming}
$errors=@(Validate-State $state);$missingContracts=@($settings.requiredContracts|Where-Object{$_ -notin @($solutionProjects|ForEach-Object{ProjectName $_})})
$fixtureResults=[Collections.Generic.List[object]]::new();foreach($file in $fixtures){try{$fixture=[IO.File]::ReadAllText($file.FullName)|ConvertFrom-Json -AsHashtable -Depth 100;$actual=@(Validate-State $fixture);$expected=@($fixture['expectedErrors']|Sort-Object);$fixtureResults.Add([ordered]@{passed=Equal-Set $expected $actual;positive=$actual.Count -eq 0})}catch{$fixtureResults.Add([ordered]@{passed=$false;positive=$false})}}
$checks=[ordered]@{
    noLegacyAbstractionsDirectories=(@($errors|Where-Object{$_ -eq 'legacy-abstractions-directory'}).Count -eq 0)
    noLegacyAbstractionsProjects=(@($errors|Where-Object{$_ -eq 'legacy-abstractions-project'}).Count -eq 0)
    noLegacyAbstractionsReferences=(@($errors|Where-Object{$_ -eq 'legacy-abstractions-reference'}).Count -eq 0)
    noLegacyAbstractionsSolutionEntries=(@($errors|Where-Object{$_ -eq 'legacy-abstractions-solution-entry'}).Count -eq 0)
    requiredContractsAreExplicitSolutionProjects=($missingContracts.Count -eq 0)
    compositionProjectNameIsUnambiguous=(@($errors|Where-Object{$_ -eq 'ambiguous-composition-abstractions-name'}).Count -eq 0)
    authorizationNamespaceNameIsUnambiguous=(@($errors|Where-Object{$_ -eq 'legacy-authorization-abstractions-namespace'}).Count -eq 0)
    compositionProjectIsExplicitlyInSolution=(@($errors|Where-Object{$_ -eq 'composition-project-missing-from-solution'}).Count -eq 0)
    layerGuardRetirementRuleIsBound=$layerRetirement
    layerGuardCompositionNameIsCurrent=$layerNaming
    positiveAndNegativeFixturesPass=($fixtureResults.Count -eq 6 -and @($fixtureResults|Where-Object passed -ne $true).Count -eq 0 -and @($fixtureResults|Where-Object positive -eq $true).Count -eq 2)
}
if((@($checks.Keys)-join '|') -cne (@($settings.checkIds)-join '|')){Stop-Adapter 'integrity-failure' 'Abstractions check-ID mapping drift.'};foreach($id in $settings.checkIds){Record $id ([bool]$checks[$id])}
if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
