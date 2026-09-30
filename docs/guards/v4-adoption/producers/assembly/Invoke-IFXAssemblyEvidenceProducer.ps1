[CmdletBinding()]
param([Parameter(Mandatory)][string]$SolutionLockPath,[string]$TargetRoot,[string]$RunId=([guid]::NewGuid().ToString('N')))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($RunId -cnotmatch '^[a-f0-9]{32}$'){throw 'RunId must be lowercase 32-hex.'}
$repo=if($TargetRoot){[IO.Path]::GetFullPath($TargetRoot)}else{[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Tree-Lines([string]$Root){
    $files=@(foreach($relative in @('src','tests','tools')){Get-ChildItem -LiteralPath (Join-Path $Root $relative) -File -Recurse -Force|Where-Object{$_.Extension -in '.cs','.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]' }})
    $files+=Get-Item -LiteralPath (Join-Path $Root 'IFX.sln')
    return @($files|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})
}
function Text-Hash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
$dirty=(& git -C $repo status --porcelain --untracked-files=no -- src tests tools IFX.sln)
if($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace(($dirty -join "`n"))){throw 'Controlled Assembly run requires clean tracked source inputs.'}
$solutionFile=if([IO.Path]::IsPathFullyQualified($SolutionLockPath)){$SolutionLockPath}else{Join-Path $repo $SolutionLockPath}
if(-not [IO.File]::Exists($solutionFile)){throw 'Solution lock missing.'}
$solution=Get-Content $solutionFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100
if($solution.gate -cne 'Solution' -or $solution.result -cne 'passed' -or $solution.producer -cne 'ifx-c5b-controlled-v1'){throw 'Solution lock does not prove a controlled passing build.'}
$source=@(Tree-Lines $repo);$sourceHash=Text-Hash ($source -join "`n")
if($source.Count -ne $solution.sourceFileCount -or $sourceHash -cne $solution.sourceTreeSha256){throw 'Source changed since Solution build.'}
$solutionCompleted=if($solution.completedAt -is [DateTime]){[DateTimeOffset]$solution.completedAt}else{[DateTimeOffset]::Parse([string]$solution.completedAt,[Globalization.CultureInfo]::InvariantCulture)}
if($solutionCompleted -lt [DateTimeOffset]::UtcNow.AddHours(-24)){throw 'Solution build evidence expired.'}
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
if($LASTEXITCODE -ne 0 -or $commit -cnotmatch '^[a-f0-9]{40}$'){throw 'Target commit unavailable.'}
$relative="artifacts/guards/p10-ifx-c5c/assembly-runs/$RunId";$output=Join-Path $repo $relative
if([IO.Directory]::Exists($output)){throw 'Run directory exists.'}
$started=[DateTimeOffset]::UtcNow
& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repo 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1') -Mode Quality -QualityTarget Assembly -TargetRoot $repo -OutputDirectory $relative
if($LASTEXITCODE -ne 0){throw 'V3 Assembly Quality failed; no passing lock issued.'}
$completed=[DateTimeOffset]::UtcNow
$reportPath=Join-Path $output 'quality/assembly.json';$summaryPath=Join-Path $output 'quality/summary.json'
$report=Get-Content $reportPath -Raw|ConvertFrom-Json;$summary=Get-Content $summaryPath -Raw|ConvertFrom-Json
if($report.status -cne 'pass' -or @($report.checks).Count -ne 5 -or $summary.status -cne 'pass' -or @($summary.checks|Where-Object{$_.id -ceq 'Assembly' -and $_.status -ceq 'pass'}).Count -ne 1){throw 'Incomplete Assembly report.'}
$assemblies=@(foreach($check in $report.checks){
    $path=[string]$check.assemblyPath;$full=Join-Path $repo $path
    if($check.status -cne 'pass' -or $check.stale -ne $false -or -not [IO.File]::Exists($full) -or $path -cnotmatch '^src/Modules/(CRM|Holdings|IAM|Registry|Transaction)/IFX\.Modules\.[^/]+\.Domain/bin/Release/net8\.0/IFX\.Modules\.[^/]+\.Domain\.dll$'){throw "Invalid Domain DLL: $path"}
    [ordered]@{id=[string]$check.id;path=$path;sha256=Hash $full}
})
if((@($assemblies.id|Sort-Object)-join '|') -cne (@('IFX.Modules.CRM.Domain','IFX.Modules.Holdings.Domain','IFX.Modules.IAM.Domain','IFX.Modules.Registry.Domain','IFX.Modules.Transaction.Domain'|Sort-Object)-join '|')){throw 'Domain assembly set drift.'}
if((Text-Hash ((Tree-Lines $repo) -join "`n")) -cne $sourceHash){throw 'Source changed during Assembly run.'}
$lock=[ordered]@{formatVersion=1;gate='Assembly';producer='ifx-c5c-controlled-v1';result='passed';targetCommit=$commit;startedAt=$started.ToString('o');completedAt=$completed.ToString('o');evidencePrefix="$relative/";sourceFileCount=$source.Count;sourceTreeSha256=$sourceHash;solutionLockPath=[IO.Path]::GetRelativePath($repo,$solutionFile).Replace('\','/');solutionLockSha256=Hash $solutionFile;authorityHashes=[ordered]@{assembly=(Hash (Join-Path $repo 'docs/guards/V3_ifx/stages/post/gates/quality/Invoke-IFXAssemblyGuard.ps1'));domainPolicy=(Hash (Join-Path $repo 'docs/guards/V3_ifx/stages/post/policy/layerguard.json'))};reportSha256=Hash $reportPath;summarySha256=Hash $summaryPath;assemblies=$assemblies}
$lockPath=Join-Path $output 'evidence-lock.json'
[IO.File]::WriteAllText($lockPath,(($lock|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))
Write-Output "Assembly evidence lock: $lockPath"
Write-Output "SHA256: $(Hash $lockPath)"
