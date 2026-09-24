[CmdletBinding()]
param(
    [string]$TargetRoot,
    [string]$SolutionLockPath='artifacts/guards/p10-ifx-c5b/solution-runs/7e653152cd764804bf3e2b989fd97276/evidence-lock.json',
    [string]$AssemblyLockPath='artifacts/guards/p10-ifx-c5c/assembly-runs/6a9cf7146fd44434bd476ba1b16b8631/evidence-lock.json',
    [string]$RunId=([guid]::NewGuid().ToString('N'))
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Text-Hash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Write-Json([string]$Path,$Value){[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Parse-Time($Value){[DateTimeOffset]::Parse([string]$Value,[Globalization.CultureInfo]::InvariantCulture)}
function Tree-Lines([string]$Root){
    $files=@(foreach($relative in @('src','tests','tools')){
        $folder=Join-Path $Root $relative;Assert ([IO.Directory]::Exists($folder)) "Missing source root: $relative"
        Get-ChildItem -LiteralPath $folder -File -Recurse -Force|Where-Object{$_.Extension -in '.cs','.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]'}
    })
    $solution=Join-Path $Root 'IFX.sln';Assert ([IO.File]::Exists($solution)) 'Missing IFX.sln.';$files+=Get-Item -LiteralPath $solution
    return @($files|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})
}
Assert ($RunId -cmatch '^[a-f0-9]{32}$') 'RunId must be lowercase 32-hex.'
$repo=if($TargetRoot){[IO.Path]::GetFullPath($TargetRoot)}else{[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))}
$dirty=@(& git -C $repo status --porcelain --untracked-files=no -- src tests tools IFX.sln)
Assert ($LASTEXITCODE -eq 0 -and -not $dirty) 'Controlled type evidence requires clean tracked source inputs.'
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant();Assert ($LASTEXITCODE -eq 0 -and $commit -cmatch '^[a-f0-9]{40}$') 'Target commit unavailable.'
function Lock-Path([string]$Relative,[string]$Prefix){
    Assert ($Relative -cmatch $Prefix) "Uncontrolled lock path: $Relative"
    $full=[IO.Path]::GetFullPath((Join-Path $repo $Relative))
    Assert ([IO.File]::Exists($full)) "Missing lock: $Relative"
    return $full
}
$solutionFull=Lock-Path $SolutionLockPath '^artifacts/guards/p10-ifx-c5b/solution-runs/[a-f0-9]{32}/evidence-lock\.json$'
$assemblyFull=Lock-Path $AssemblyLockPath '^artifacts/guards/p10-ifx-c5c/assembly-runs/[a-f0-9]{32}/evidence-lock\.json$'
$solution=Get-Content $solutionFull -Raw|ConvertFrom-Json -Depth 50
$assembly=Get-Content $assemblyFull -Raw|ConvertFrom-Json -Depth 50
$now=[DateTimeOffset]::UtcNow
Assert ($solution.gate -ceq 'Solution' -and $solution.result -ceq 'passed' -and $solution.producer -ceq 'ifx-c5b-controlled-v1' -and $solution.projectCount -eq 81 -and $solution.totalTests -gt 0) 'Solution lock is incomplete.'
Assert ($assembly.gate -ceq 'Assembly' -and $assembly.result -ceq 'passed' -and $assembly.producer -ceq 'ifx-c5c-controlled-v1' -and @($assembly.assemblies).Count -eq 5) 'Assembly lock is incomplete.'
Assert ((Parse-Time $solution.completedAt) -le $now -and (Parse-Time $solution.completedAt) -ge $now.AddHours(-24) -and (Parse-Time $assembly.completedAt) -le $now -and (Parse-Time $assembly.completedAt) -ge $now.AddHours(-24)) 'C5 evidence is stale or future-dated.'
Assert ($assembly.solutionLockPath -ceq $SolutionLockPath -and $assembly.solutionLockSha256 -ceq (Hash $solutionFull) -and $assembly.sourceTreeSha256 -ceq $solution.sourceTreeSha256 -and $assembly.sourceFileCount -eq $solution.sourceFileCount) 'C5 Solution/Assembly lineage mismatch.'
$source=@(Tree-Lines $repo);$sourceHash=Text-Hash ($source -join "`n")
Assert ($source.Count -eq $solution.sourceFileCount -and $sourceHash -ceq $solution.sourceTreeSha256) 'Current source tree differs from C5 build.'
$module=Join-Path $PSScriptRoot 'modules/ifx-c1-type-provenance'
$policyFile=Join-Path $module 'policy.json';$policy=Get-Content $policyFile -Raw|ConvertFrom-Json -Depth 50
$v3Rule=Join-Path $repo 'docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json'
$v3Policy=Join-Path $repo 'docs/guards/V3_ifx/stages/post/policy/layerguard.json'
Assert ((Hash $v3Rule) -ceq $policy.v3TypeRuleSha256 -and (Hash $v3Policy) -ceq $policy.v3LayerPolicySha256) 'C1 authority drift.'
Assert ($policy.configuration -ceq 'Release' -and $policy.targetFramework -ceq 'net8.0' -and @($policy.assemblies).Count -eq 4) 'Type policy shape drift.'
$prefix="artifacts/guards/p10-ifx-c1-r1b/type-runs/$RunId/"
$output=Join-Path $repo $prefix;Assert (-not [IO.Directory]::Exists($output)) 'Run directory already exists.'
$copies=Join-Path $output 'assemblies';[void][IO.Directory]::CreateDirectory($copies)
$manifest=[ordered]@{formatVersion=1;assemblies=@()}
$lockedAssemblies=[Collections.Generic.List[object]]::new()
foreach($entry in $policy.assemblies){
    $name=[string]$entry.name;$relative=[string]$entry.sourcePath
    Assert ($relative -cmatch '^src/.+/bin/Release/net8\.0/[A-Za-z0-9.]+\.dll$' -and -not $relative.Contains('..')) "Unsafe assembly source: $relative"
    $sourceDll=Join-Path $repo $relative;Assert ([IO.File]::Exists($sourceDll)) "Missing assembly: $relative"
    $sha=Hash $sourceDll
    if($name -ceq 'IFX.Modules.CRM.Domain'){
        $row=@($assembly.assemblies|Where-Object id -CEQ $name)
        Assert ($row.Count -eq 1 -and $row[0].path -ceq $relative -and $row[0].sha256 -ceq $sha) 'CRM Domain DLL differs from C5c.'
    }
    $destination=Join-Path $copies "$name.dll";Copy-Item -LiteralPath $sourceDll -Destination $destination
    Assert ((Hash $destination) -ceq $sha) "Copied DLL changed: $name"
    $manifest.assemblies+=([ordered]@{assemblyName=$name;path="assemblies/$name.dll";sha256=$sha})
    $lockedAssemblies.Add([ordered]@{name=$name;sourcePath=$relative;copiedPath="$prefix"+"assemblies/$name.dll";sha256=$sha})
}
$manifestPath=Join-Path $output 'assembly-manifest.json';Write-Json $manifestPath $manifest
$lock=[ordered]@{formatVersion=1;gate='C1CompiledTypeProvenance';producer='ifx-c1-r1b-controlled-v1';result='passed';targetCommit=$commit;createdAt=$now.ToString('o');expiresAt=$now.AddSeconds([int]$policy.maximumAgeSeconds).ToString('o');configuration=$policy.configuration;targetFramework=$policy.targetFramework;sourceFileCount=$source.Count;sourceTreeSha256=$sourceHash;solutionLockPath=$SolutionLockPath;solutionLockSha256=Hash $solutionFull;assemblyLockPath=$AssemblyLockPath;assemblyLockSha256=Hash $assemblyFull;policySha256=Hash $policyFile;v3TypeRuleSha256=Hash $v3Rule;v3LayerPolicySha256=Hash $v3Policy;manifestPath="$prefix"+'assembly-manifest.json';manifestSha256=Hash $manifestPath;assemblies=@($lockedAssemblies.ToArray())}
$lockPath=Join-Path $output 'evidence-lock.json';Write-Json $lockPath $lock
Write-Output "Compiled type evidence lock: $lockPath"
Write-Output "SHA256: $(Hash $lockPath)"
