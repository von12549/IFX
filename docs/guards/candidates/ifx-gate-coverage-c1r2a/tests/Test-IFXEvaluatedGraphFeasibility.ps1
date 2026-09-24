[CmdletBinding()]
param([string]$EvidenceRoot='artifacts/guards/p10-ifx-c1-r2a/test-runs')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-Text([string]$Path,[string]$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,$Value,[Text.UTF8Encoding]::new($false))}
function Write-Json([string]$Path,$Value){Write-Text $Path (($Value|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n")}
function Under([string]$Path,[string]$Root){$relative=[IO.Path]::GetRelativePath($Root,$Path);return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Evaluate([string]$Project,[string]$Configuration='Release'){
    $lines=@(& dotnet msbuild $Project -getProperty:TargetFramework -getItem:ProjectReference "-p:Configuration=$Configuration" -nologo 2>&1)
    Assert ($LASTEXITCODE -eq 0) "MSBuild evaluation failed: $Project / $Configuration / $($lines -join "`n")"
    $raw=$lines -join "`n"
    try{$document=$raw|ConvertFrom-Json -Depth 40}catch{throw "MSBuild evaluation was not JSON: $Project / $raw"}
    Assert ($document.Properties.TargetFramework -ceq 'net8.0') "Wrong evaluated TFM: $Project"
    return [ordered]@{project=$Project;configuration=$Configuration;references=@($document.Items.ProjectReference|Where-Object{$_})}
}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$projects=@(Get-ChildItem -LiteralPath (Join-Path $repo 'src') -Recurse -File -Filter '*.csproj'|Where-Object{$_.FullName -notmatch '[\\/](bin|obj)[\\/]'}|Sort-Object FullName)
Assert ($projects.Count -eq 58) 'Current src project count drift.'
$sdk=(& dotnet --version).Trim();Assert ($LASTEXITCODE -eq 0 -and $sdk -ceq '10.0.303') 'SDK version drift.'
$evaluated=0;$raw=0;$definers=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach($project in $projects){
    [xml]$xml=Get-Content $project.FullName -Raw
    $raw+=$xml.SelectNodes('//*[local-name()="ProjectReference"]').Count
    $result=Evaluate $project.FullName
    foreach($edge in $result.references){
        $evaluated++
        $to=[IO.Path]::GetFullPath([string]$edge.FullPath)
        $from=[IO.Path]::GetFullPath([string]$edge.DefiningProjectFullPath)
        Assert ((Under $to $repo) -and (Under $from $repo) -and [IO.File]::Exists($to) -and [IO.File]::Exists($from)) "Unresolved or escaping evaluated edge: $($project.FullName) -> $to from $from"
        [void]$definers.Add([IO.Path]::GetRelativePath($repo,$from).Replace('\','/'))
    }
}
Assert ($raw -eq 155 -and $evaluated -eq 155 -and $definers.Count -eq 48) "Current raw/evaluated graph drift: raw=$raw evaluated=$evaluated definers=$($definers.Count)"
$id=[guid]::NewGuid().ToString('N')
$fixture=Join-Path ([IO.Path]::GetTempPath()) "ifx-c1-r2a-$id";[void][IO.Directory]::CreateDirectory($fixture)
$a=Join-Path $fixture 'A/A.csproj';$b=Join-Path $fixture 'B/B.csproj'
Write-Text $b '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>'
$baseA='<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>'
Write-Text $a $baseA
Assert ((Evaluate $a).references.Count -eq 0) 'Synthetic raw baseline was not empty.'
$props=Join-Path $fixture 'Directory.Build.props'
Write-Text $props '<Project><ItemGroup Condition="''$(MSBuildProjectName)'' == ''A''"><ProjectReference Include="../B/B.csproj" /></ItemGroup></Project>'
[xml]$rawA=Get-Content $a -Raw
Assert ($rawA.SelectNodes('//*[local-name()="ProjectReference"]').Count -eq 0) 'Directory.Build fixture leaked into raw XML.'
$propsResult=Evaluate $a
Assert ($propsResult.references.Count -eq 1 -and (Get-Item $propsResult.references[0].FullPath).FullName -ceq (Get-Item $b).FullName -and (Get-Item $propsResult.references[0].DefiningProjectFullPath).FullName -ceq (Get-Item $props).FullName) 'Directory.Build.props injection was not evaluated.'
Write-Text $props '<Project />'
$import=Join-Path $fixture 'shared/Extra.targets'
Write-Text $import '<Project><ItemGroup><ProjectReference Include="../B/B.csproj" /></ItemGroup></Project>'
Write-Text $a '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><Import Project="../shared/Extra.targets" /></Project>'
$importResult=Evaluate $a
Assert ($importResult.references.Count -eq 1 -and (Get-Item $importResult.references[0].DefiningProjectFullPath).FullName -ceq (Get-Item $import).FullName) 'Explicit Import injection was not evaluated.'
Write-Text $a '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><ItemGroup Condition="''$(Configuration)'' == ''Release''"><ProjectReference Include="../B/B.csproj" /></ItemGroup></Project>'
$release=Evaluate $a 'Release';$debug=Evaluate $a 'Debug'
Assert ($release.references.Count -eq 1 -and $debug.references.Count -eq 0) 'Configuration condition did not change evaluated graph.'
Write-Text $a '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup><Import Project="../shared/Missing.targets" /></Project>'
$missing=@(& dotnet msbuild $a -getItem:ProjectReference -p:Configuration=Release -nologo 2>&1)
Assert ($LASTEXITCODE -ne 0) 'Missing import did not stop evaluation.'
Assert (-not (Test-Path -LiteralPath (Join-Path $fixture 'A/obj')) -and -not (Test-Path -LiteralPath (Join-Path $fixture 'A/bin'))) 'Evaluation unexpectedly invoked build targets.'
$evidence=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot}
$out=Join-Path $evidence $id
Write-Json (Join-Path $out 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='r2a-feasibility-only';sdk=$sdk;projectCount=$projects.Count;rawReferenceCount=$raw;evaluatedReferenceCount=$evaluated;definingProjectCount=$definers.Count;cases=@([ordered]@{id='directory-build-props';status='evaluated-only-edge'},[ordered]@{id='explicit-import';status='evaluated-only-edge'},[ordered]@{id='configuration-condition';status='release-only-edge'},[ordered]@{id='missing-import';status='evaluation-failed'});notes=@('No locked evaluated graph','No V4 policy verifier','No build targets executed')})
Write-Output "IFX C1 R2a evaluated-graph feasibility passed: $out"
