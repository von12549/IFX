# Relocated from docs/guards/candidates/ifx-gate-coverage-c5c/Invoke-IFXAssemblyEvidenceProducer.ps1 (IFX I2-B amendment A2, rulings R6-R10). Adapted: producer ifx-v4a-assembly-v1 (accepts ifx-v4a-solution-v1 locks); runs producers/quality directly; explicit -TargetRoot; run directory artifacts/guards/v4a-producers/assembly-runs.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SolutionLockPath,[string]$TargetRoot,[string]$RunId=([guid]::NewGuid().ToString('N')))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($RunId -cnotmatch '^[a-f0-9]{32}$'){throw 'RunId must be lowercase 32-hex.'}
if(-not $TargetRoot){throw 'An explicit Target root is required: the relocated producers never derive the repository from their own location.'};$repo=[IO.Path]::GetFullPath($TargetRoot)
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
if($solution.gate -cne 'Solution' -or $solution.result -cne 'passed' -or $solution.producer -cne 'ifx-v4a-solution-v1'){throw 'Solution lock does not prove a controlled passing build.'}
$source=@(Tree-Lines $repo);$sourceHash=Text-Hash ($source -join "`n")
if($source.Count -ne $solution.sourceFileCount -or $sourceHash -cne $solution.sourceTreeSha256){throw 'Source changed since Solution build.'}
$solutionCompleted=if($solution.completedAt -is [DateTime]){[DateTimeOffset]$solution.completedAt}else{[DateTimeOffset]::Parse([string]$solution.completedAt,[Globalization.CultureInfo]::InvariantCulture)}
if($solutionCompleted -lt [DateTimeOffset]::UtcNow.AddHours(-24)){throw 'Solution build evidence expired.'}
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
if($LASTEXITCODE -ne 0 -or $commit -cnotmatch '^[a-f0-9]{40}$'){throw 'Target commit unavailable.'}
$relative="artifacts/guards/v4a-producers/assembly-runs/$RunId";$output=Join-Path $repo $relative
if([IO.Directory]::Exists($output)){throw 'Run directory exists.'}
$started=[DateTimeOffset]::UtcNow
& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot '../quality/Invoke-IFXQuality.ps1') -Target Assembly -TargetRoot $repo -OutputDirectory "$relative/quality"
if($LASTEXITCODE -ne 0){throw 'Assembly quality failed; no passing lock issued.'}
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
$lock=[ordered]@{formatVersion=1;gate='Assembly';producer='ifx-v4a-assembly-v1';result='passed';targetCommit=$commit;startedAt=$started.ToString('o');completedAt=$completed.ToString('o');evidencePrefix="$relative/";sourceFileCount=$source.Count;sourceTreeSha256=$sourceHash;solutionLockPath=[IO.Path]::GetRelativePath($repo,$solutionFile).Replace('\','/');solutionLockSha256=Hash $solutionFile;authorityHashes=[ordered]@{assembly=(Hash (Join-Path $PSScriptRoot '../quality/Invoke-IFXAssemblyGuard.ps1'));domainPolicy=(Hash (Join-Path $PSScriptRoot '../policy/layerguard.json'))};reportSha256=Hash $reportPath;summarySha256=Hash $summaryPath;assemblies=$assemblies}
$lockPath=Join-Path $output 'evidence-lock.json'
[IO.File]::WriteAllText($lockPath,(($lock|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))
Write-Output "Assembly evidence lock: $lockPath"
Write-Output "SHA256: $(Hash $lockPath)"
