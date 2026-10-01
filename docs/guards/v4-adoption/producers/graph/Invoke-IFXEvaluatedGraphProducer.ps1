# Relocated from docs/guards/candidates/ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1 (IFX I2-B amendment A3, rulings R12-R13). Adapted: producer ifx-v4a-graph-v1; reads policy.json next to itself, whose sourcePolicies name the relocated copies in policies/; explicit -TargetRoot; run directory artifacts/guards/v4a-producers/graph-runs.
[CmdletBinding()]
param([string]$TargetRoot,[string]$RunId=([guid]::NewGuid().ToString('N')))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Ok,[string]$Why){if(-not $Ok){throw $Why}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function TextHash([string]$Value){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))).ToLowerInvariant()}
function Under([string]$Path,[string]$Root){$r=[IO.Path]::GetRelativePath($Root,$Path);$r -ne '..' -and -not [IO.Path]::IsPathRooted($r) -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function NoLink([string]$Path){
    $cursor=[IO.Path]::GetFullPath($Path)
    while($cursor){
        if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){
            $item=Get-Item -LiteralPath $cursor -Force
            Assert ((($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) -and $null -eq $item.LinkTarget) "Linked input: $Path"
        }
        $next=[IO.Path]::GetDirectoryName($cursor);if(-not $next -or $next -ceq $cursor){break};$cursor=$next
    }
}
function Rel([string]$Path){[IO.Path]::GetRelativePath($repo,$Path).Replace('\','/')}
function Checked([string]$Path){
    $full=[IO.Path]::GetFullPath($Path)
    Assert (Under $full $repo) "Input escapes TargetRoot: $Path"
    Assert ([IO.File]::Exists($full)) "Missing input: $Path"
    NoLink $full
    return $full
}
Assert ($RunId -cmatch '^[a-f0-9]{32}$') 'RunId must be lowercase 32-hex.'
if(-not $TargetRoot){throw 'An explicit Target root is required: the relocated producers never derive the repository from their own location.'};$repo=[IO.Path]::GetFullPath($TargetRoot)
Assert ([IO.Directory]::Exists((Join-Path $repo 'src'))) 'TargetRoot/src missing.'
$sdk=(& dotnet --version).Trim();Assert ($LASTEXITCODE -eq 0 -and $sdk -ceq '10.0.303') 'Pinned SDK drift.'
foreach($name in @('MSBuildSDKsPath','MSBuildExtensionsPath','MSBuildProjectExtensionsPath','CustomAfterMicrosoftCommonTargets','CustomBeforeMicrosoftCommonTargets')){
    Assert (-not [Environment]::GetEnvironmentVariable($name)) "Uncontrolled MSBuild environment override: $name"
}
$dirty=@(& git -C $repo status --porcelain --untracked-files=all -- src IFX.sln Directory.Build.props Directory.Packages.props)
Assert ($LASTEXITCODE -eq 0 -and -not $dirty) 'Controlled evaluation requires clean tracked source inputs.'
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant();Assert ($LASTEXITCODE -eq 0 -and $commit -cmatch '^[a-f0-9]{40}$') 'Target commit unavailable.'
$projects=@(Get-ChildItem -LiteralPath (Join-Path $repo 'src') -Recurse -File -Filter '*.csproj'|Where-Object{$_.FullName -notmatch '[\\/](bin|obj)[\\/]'}|Sort-Object FullName)
Assert ($projects.Count -eq 58) "Current src project-set drift: $($projects.Count)"
$allFiles=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $repo 'src') -Recurse -File|Where-Object{$_.Extension -in '.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj)[\\/]'})){
    $full=Checked $file.FullName;$allFiles.Add((Rel $full),(Hash $full))
}
foreach($name in @('Directory.Build.props','Directory.Packages.props')){
    $full=Checked (Join-Path $repo $name);$allFiles.Add((Rel $full),(Hash $full))
}
$edges=[Collections.Generic.List[object]]::new();$states=[Collections.Generic.List[object]]::new();$rawCount=0
foreach($path in $allFiles.Keys){
    $full=Checked (Join-Path $repo $path)
    $text=[IO.File]::ReadAllText($full)
    Assert ($text -notmatch '\$\(\[' -and $text -notmatch '<\s*(UsingTask|Exec)\b') "Unsupported evaluation construct: $(Rel $full)"
    $settings=[Xml.XmlReaderSettings]::new();$settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit;$settings.XmlResolver=$null
    $reader=[Xml.XmlReader]::Create($full,$settings)
    try{$xml=[xml]::new();$xml.Load($reader)}finally{$reader.Dispose()}
    foreach($import in @($xml.SelectNodes("//*[local-name()='Import']"))){
        $literal=[string]$import.GetAttribute('Project')
        Assert ($literal -and $literal -notmatch '[\$\*\?]' -and -not [IO.Path]::IsPathRooted($literal)) "Dynamic or rooted import: $(Rel $full)"
        $importFull=Checked (Join-Path ([IO.Path]::GetDirectoryName($full)) $literal.Replace('\','/'))
        Assert ($allFiles.ContainsKey((Rel $importFull))) "Import is outside approved input set: $(Rel $importFull)"
    }
}
foreach($project in $projects){
    $full=Checked $project.FullName
    [xml]$xml=[IO.File]::ReadAllText($full)
    $rawCount+=$xml.SelectNodes("//*[local-name()='ProjectReference']").Count
    $lines=@(& dotnet msbuild $full -getProperty:TargetFramework,DisableTransitiveProjectReferences -getItem:ProjectReference -p:Configuration=Release -nologo 2>&1)
    Assert ($LASTEXITCODE -eq 0) "MSBuild evaluation failed: $(Rel $full): $($lines -join ' ')"
    try{$result=($lines -join "`n")|ConvertFrom-Json -Depth 50}catch{throw "MSBuild output is not JSON: $(Rel $full)"}
    Assert ($result.Properties.TargetFramework -ceq 'net8.0') "Evaluated TFM drift: $(Rel $full)"
    $states.Add([ordered]@{project=(Rel $full);disableTransitive=([string]$result.Properties.DisableTransitiveProjectReferences -ieq 'true')})
    foreach($item in @($result.Items.ProjectReference|Where-Object{$_})){
        $to=Checked ([string]$item.FullPath);$definer=Checked ([string]$item.DefiningProjectFullPath)
        Assert ([IO.Path]::GetExtension($to) -ieq '.csproj' -and $allFiles.ContainsKey((Rel $definer))) "Unapproved evaluated reference definer: $(Rel $definer)"
        Assert (@($projects|Where-Object FullName -EQ $to).Count -eq 1) "Evaluated reference leaves src project set: $(Rel $to)"
        $privateAssets=if($item.PSObject.Properties.Name -contains 'PrivateAssets'){[string]$item.PrivateAssets}else{''}
        $stops=@($privateAssets -split '[;,]'|ForEach-Object Trim|Where-Object{$_ -ieq 'all' -or $_ -ieq 'compile'}).Count -gt 0
        $edges.Add([ordered]@{from=(Rel $full);to=(Rel $to);definer=(Rel $definer);stopsFlow=[bool]$stops})
    }
}
Assert ($edges.Count -gt 0 -and $rawCount -gt 0) 'Zero reference subjects.'
$policyPath=Join-Path $PSScriptRoot 'policy.json';$policy=Get-Content $policyPath -Raw|ConvertFrom-Json
foreach($source in @($policy.sourcePolicies)){
    Assert ((Hash (Checked (Join-Path $repo $source.path))) -ceq $source.sha256) "C1 policy source drift: $($source.path)"
}
$now=[DateTimeOffset]::UtcNow
$prefix="artifacts/guards/v4a-producers/graph-runs/$RunId/"
$out=Join-Path $repo $prefix;Assert (-not [IO.Directory]::Exists($out)) 'Run already exists.'
[void][IO.Directory]::CreateDirectory($out)
$inputRows=@($allFiles.Keys|Sort-Object|ForEach-Object{[ordered]@{path=$_;sha256=$allFiles[$_]}})
$projectPaths=@($projects|ForEach-Object{Rel $_.FullName}|Sort-Object)
$lock=[ordered]@{formatVersion=1;gate='C1EvaluatedReferenceGraph';producer='ifx-v4a-graph-v1';result='passed';targetCommit=$commit;createdAt=$now.ToString('o');expiresAt=$now.AddHours(1).ToString('o');sdk=$sdk;configuration='Release';targetFramework='net8.0';arguments=@('-getProperty:TargetFramework,DisableTransitiveProjectReferences','-getItem:ProjectReference','-p:Configuration=Release','-nologo');policySha256=Hash $policyPath;projects=$projectPaths;projectStates=@($states.ToArray()|Sort-Object project);inputs=$inputRows;rawReferenceCount=$rawCount;edges=@($edges.ToArray()|Sort-Object from,to,definer);evaluatedReferenceCount=$edges.Count;rawEvaluatedDelta=($edges.Count-$rawCount)}
$lockPath=Join-Path $out 'evidence-lock.json'
[IO.File]::WriteAllText($lockPath,(($lock|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))
Write-Output "Evaluated graph evidence lock: $lockPath"
Write-Output "SHA256: $(Hash $lockPath)"
