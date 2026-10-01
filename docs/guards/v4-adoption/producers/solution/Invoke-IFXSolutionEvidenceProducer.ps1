# Relocated from docs/guards/candidates/ifx-gate-coverage-c5b/Invoke-IFXSolutionEvidenceProducer.ps1 (IFX I2-B amendment A2, rulings R6-R10). Adapted: producer ifx-v4a-solution-v1; runs producers/quality directly; explicit -TargetRoot; run directory artifacts/guards/v4a-producers/solution-runs.
[CmdletBinding()]
param([string]$TargetRoot,[string]$RunId=([guid]::NewGuid().ToString('N')))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($RunId -cnotmatch '^[a-f0-9]{32}$'){throw 'RunId must be lowercase 32-hex.'}
if(-not $TargetRoot){throw 'An explicit Target root is required: the relocated producers never derive the repository from their own location.'};$repo=[IO.Path]::GetFullPath($TargetRoot)
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Tree-Lines([string]$Root){
    $files=@(foreach($relative in @('src','tests','tools')){
        Get-ChildItem -LiteralPath (Join-Path $Root $relative) -File -Recurse -Force |
            Where-Object { $_.Extension -in '.cs','.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]' }
    })
    $files+=Get-Item -LiteralPath (Join-Path $Root 'IFX.sln')
    return @($files|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})
}
function Text-Hash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
$dirty=(& git -C $repo status --porcelain --untracked-files=no -- src tests tools IFX.sln)
if($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace(($dirty -join "`n"))){throw 'Controlled Solution run requires clean tracked source inputs.'}
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
if($LASTEXITCODE -ne 0 -or $commit -cnotmatch '^[a-f0-9]{40}$'){throw 'Target commit unavailable.'}
$relative="artifacts/guards/v4a-producers/solution-runs/$RunId"
$output=Join-Path $repo $relative
if([IO.Directory]::Exists($output)){throw 'Run directory exists.'}
$before=@(Tree-Lines $repo)
if($before.Count -lt 81){throw 'Solution source set is unexpectedly small.'}
$started=[DateTimeOffset]::UtcNow
& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot '../quality/Invoke-IFXQuality.ps1') -Target Solution -TargetRoot $repo -OutputDirectory "$relative/quality"
if($LASTEXITCODE -ne 0){throw 'Solution quality failed; no passing lock issued.'}
$completed=[DateTimeOffset]::UtcNow
$after=@(Tree-Lines $repo)
if(($before -join "`n") -cne ($after -join "`n")){throw 'Solution source changed during controlled run.'}
$quality=Join-Path $output 'quality'
$summary=Get-Content (Join-Path $quality 'summary.json') -Raw|ConvertFrom-Json
$audit=Get-Content (Join-Path $quality 'nuget-audit.json') -Raw|ConvertFrom-Json
$trx=@(Get-ChildItem -LiteralPath (Join-Path $quality 'solution-test-results') -File -Filter '*.trx')
if($summary.status -cne 'pass' -or @($summary.checks|Where-Object{$_.id -ceq 'Solution' -and $_.status -ceq 'pass'}).Count -ne 1 -or $audit.status -cne 'pass' -or $audit.projectCount -ne 81 -or @($audit.findings).Count -ne 0 -or $trx.Count -lt 1){throw 'Incomplete Solution evidence.'}
$total=0
foreach($file in $trx){
    [xml]$xml=Get-Content -LiteralPath $file.FullName -Raw
    $counters=$xml.SelectSingleNode("//*[local-name()='Counters']")
    if($null -eq $counters -or $counters.failed -ne '0' -or $counters.error -ne '0' -or [int]$counters.total -lt 1){throw "Failed or empty TRX: $($file.Name)"}
    $total+=[int]$counters.total
}
$files=@(Get-ChildItem -LiteralPath $quality -File -Recurse -Force|Where-Object{$_.Name -eq 'summary.json' -or $_.Name -eq 'nuget-audit.json' -or $_.Extension -eq '.trx'}|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($repo,$_.FullName).Replace('\','/');sha256=Hash $_.FullName}})
if($files.Count -ne $trx.Count+2){throw 'Solution evidence inventory mismatch.'}
$sources=[ordered]@{quality=(Hash (Join-Path $PSScriptRoot '../quality/Invoke-IFXQuality.ps1'));audit=(Hash (Join-Path $PSScriptRoot '../quality/Invoke-IFXPackageAudit.ps1'))}
$lock=[ordered]@{formatVersion=1;gate='Solution';producer='ifx-v4a-solution-v1';result='passed';targetCommit=$commit;startedAt=$started.ToString('o');completedAt=$completed.ToString('o');evidencePrefix="$relative/";sourceFileCount=$before.Count;sourceTreeSha256=(Text-Hash ($before -join "`n"));authorityHashes=$sources;projectCount=81;testRunCount=$trx.Count;totalTests=$total;files=$files}
$lockPath=Join-Path $output 'evidence-lock.json'
[IO.File]::WriteAllText($lockPath,(($lock|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))
Write-Output "Solution evidence lock: $lockPath"
Write-Output "SHA256: $(Hash $lockPath)"
