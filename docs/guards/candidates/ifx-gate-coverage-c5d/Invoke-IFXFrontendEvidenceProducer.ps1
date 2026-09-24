[CmdletBinding()]
param([string]$TargetRoot,[string]$RunId=([guid]::NewGuid().ToString('N')))
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($RunId -cnotmatch '^[a-f0-9]{32}$'){throw 'RunId must be lowercase 32-hex.'}
$repo=if($TargetRoot){[IO.Path]::GetFullPath($TargetRoot)}else{[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Text-Hash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Source-Lines([string]$Root){
    $folder=Join-Path $Root 'src/Frontend/IFX.FrontEnd'
    if(-not [IO.Directory]::Exists($folder)){return @()}
    $files=@(Get-ChildItem -LiteralPath $folder -File -Recurse -Force|Where-Object{$_.Extension -in '.ts','.tsx','.js','.json','.html','.css','.svg','.mjs','.cjs' -and $_.FullName -notmatch '[\\/](node_modules|dist|coverage|\.vite)[\\/]' })
    return @($files|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})
}
$dirty=(& git -C $repo status --porcelain --untracked-files=no -- src/Frontend/IFX.FrontEnd)
if($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrWhiteSpace(($dirty -join "`n"))){throw 'Controlled Frontend run requires clean tracked source inputs.'}
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant();if($LASTEXITCODE -ne 0 -or $commit -cnotmatch '^[a-f0-9]{40}$'){throw 'Target commit unavailable.'}
$source=@(Source-Lines $repo);if($source.Count -lt 20){throw 'Frontend source set unexpectedly small.'}
$sourceHash=Text-Hash ($source -join "`n")
$relative="artifacts/guards/p10-ifx-c5d/frontend-runs/$RunId";$output=Join-Path $repo $relative
if([IO.Directory]::Exists($output)){throw 'Run directory exists.'};[void][IO.Directory]::CreateDirectory($output)
$logPath=Join-Path $output 'frontend-run.log'
$previousPath=[Environment]::GetEnvironmentVariable('PATH','Process');$previousCi=[Environment]::GetEnvironmentVariable('CI','Process');$previousNoColor=[Environment]::GetEnvironmentVariable('NO_COLOR','Process')
try{
    $env:PATH='C:\Program Files\PowerShell\7;C:\Program Files\nodejs;C:\WINDOWS\system32;C:\WINDOWS;C:\Program Files\Git\cmd'
    $env:CI='true';$env:NO_COLOR='1'
    $nodeVersion=(& node --version).Trim();$npmVersion=(& npm --version).Trim()
    $started=[DateTimeOffset]::UtcNow
    $lines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repo 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1') -Mode Quality -QualityTarget Frontend -TargetRoot $repo -OutputDirectory $relative 2>&1)
    $gateExit=$LASTEXITCODE;$completed=[DateTimeOffset]::UtcNow
    [IO.File]::WriteAllLines($logPath,@($lines|ForEach-Object{$_.ToString()}),[Text.UTF8Encoding]::new($false))
}finally{
    [Environment]::SetEnvironmentVariable('PATH',$previousPath,'Process')
    [Environment]::SetEnvironmentVariable('CI',$previousCi,'Process')
    [Environment]::SetEnvironmentVariable('NO_COLOR',$previousNoColor,'Process')
}
if($gateExit -ne 0){throw "V3 Frontend Quality failed; no passing lock issued. Log: $logPath"}
$after=@(Source-Lines $repo);if(($after -join "`n") -cne ($source -join "`n")){throw 'Frontend source changed during controlled run.'}
$quality=Join-Path $output 'quality';$summaryPath=Join-Path $quality 'summary.json';$prodPath=Join-Path $quality 'npm-audit-production.json';$fullPath=Join-Path $quality 'npm-audit.json'
$summary=Get-Content $summaryPath -Raw|ConvertFrom-Json;$prod=Get-Content $prodPath -Raw|ConvertFrom-Json;$full=Get-Content $fullPath -Raw|ConvertFrom-Json
if($summary.status -cne 'pass' -or @($summary.checks|Where-Object{$_.id -ceq 'Frontend' -and $_.status -ceq 'pass'}).Count -ne 1 -or $prod.metadata.vulnerabilities.high -ne 0 -or $prod.metadata.vulnerabilities.critical -ne 0 -or $full.metadata.vulnerabilities.high -ne 0 -or $full.metadata.vulnerabilities.critical -ne 0){throw 'Frontend quality or audit failed.'}
$log=[IO.File]::ReadAllText($logPath);$testMatch=[regex]::Match($log,'(?m)\bTests\s+(\d+)\s+passed\b');$fileMatch=[regex]::Match($log,'(?m)\bTest Files\s+(\d+)\s+passed\b')
if(-not $testMatch.Success -or -not $fileMatch.Success -or [int]$testMatch.Groups[1].Value -lt 1 -or [int]$fileMatch.Groups[1].Value -lt 1 -or $log -notmatch 'found 0 vulnerabilities' -or $log -notmatch 'built in'){throw 'Non-vacuous Frontend test/build output missing.'}
$lock=[ordered]@{formatVersion=1;gate='Frontend';producer='ifx-c5d-controlled-v1';result='passed';targetCommit=$commit;startedAt=$started.ToString('o');completedAt=$completed.ToString('o');evidencePrefix="$relative/";sourceFileCount=$source.Count;sourceTreeSha256=$sourceHash;nodeVersion=$nodeVersion;npmVersion=$npmVersion;testFileCount=[int]$fileMatch.Groups[1].Value;testCount=[int]$testMatch.Groups[1].Value;authorityHashes=[ordered]@{quality=(Hash (Join-Path $repo 'docs/guards/V3_ifx/stages/post/gates/quality/Invoke-IFXQuality.ps1'));packageJson=(Hash (Join-Path $repo 'src/Frontend/IFX.FrontEnd/package.json'));packageLock=(Hash (Join-Path $repo 'src/Frontend/IFX.FrontEnd/package-lock.json'))};files=@([ordered]@{path="$relative/quality/summary.json";sha256=Hash $summaryPath},[ordered]@{path="$relative/quality/npm-audit-production.json";sha256=Hash $prodPath},[ordered]@{path="$relative/quality/npm-audit.json";sha256=Hash $fullPath},[ordered]@{path="$relative/frontend-run.log";sha256=Hash $logPath})}
$lockPath=Join-Path $output 'evidence-lock.json';[IO.File]::WriteAllText($lockPath,(($lock|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))
Write-Output "Frontend evidence lock: $lockPath"
Write-Output "SHA256: $(Hash $lockPath)"
