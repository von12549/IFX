# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: the supplemental matrix fixtures
# of the modules that ifx_profile 0.5.0-a leaves unchanged, and of architecture-conformance (published 1.1.6 module).
# Derived from candidates/ifx-gate-coverage-c6c4/Test-IFXC6SupplementalFixtures.ps1 (unchanged) by keeping its
# Provider, raw-graph, Injection, Source Policy, History and Architecture fixtures literally. Its G04/G05 authority,
# locked-lineage (type, graph, assembly, frontend) fixtures are dropped: those 0.5.0-a successors are covered by their
# own suites (suites/<id>.cases.json) run in capture mode against the composed package.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackageRoot,
    [string]$RepositoryRoot = (Get-Location).Path,
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-i2b/a2-051/supplemental-runs',
    [Parameter(Mandatory)][string]$CapturePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$package = [IO.Path]::GetFullPath($PackageRoot)
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
$evidence = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { [IO.Path]::GetFullPath($EvidenceRoot) } else { [IO.Path]::GetFullPath((Join-Path $repo $EvidenceRoot)) }
$capture = if ([IO.Path]::IsPathFullyQualified($CapturePath)) { [IO.Path]::GetFullPath($CapturePath) } else { [IO.Path]::GetFullPath((Join-Path $repo $CapturePath)) }
$runRoot = Join-Path $evidence ([Guid]::NewGuid().ToString('N'))
$realPwsh = @(Get-Command pwsh -CommandType Application)[0].Source

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Text-Hash([string]$Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant() }
function Write-Utf8([string]$Path,[string]$Content) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false)) }
function Write-Json([string]$Path,$Value) { Write-Utf8 $Path ((($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n")) + "`n") }
function Fingerprint([string]$Root) {
    if (-not [IO.Directory]::Exists($Root)) { return '<absent>' }
    @((Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object { "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)" })) -join "`n"
}
$sourceCommit = (& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
Assert ($LASTEXITCODE -eq 0 -and $sourceCommit -cmatch '^[a-f0-9]{40}$') 'Supplemental source commit unavailable.'
function New-Target([string]$Name) {
    $target = Join-Path $runRoot "targets/$Name"
    [void][IO.Directory]::CreateDirectory($target)
    [void][IO.Directory]::CreateDirectory((Join-Path $target 'src'))
    [void][IO.Directory]::CreateDirectory((Join-Path $target '.git'))
    Write-Utf8 (Join-Path $target '.git/HEAD') "$sourceCommit`n"
    Write-Utf8 (Join-Path $target 'fixture.txt') "$Name`n"
    return $target
}
function Invoke-CapturedAdapter([string]$CaseId,[string]$ModuleId,[string]$AdapterPath,[string]$FixtureRoot,$Payload,[string]$InvariantRoot='') {
    $expectedAdapter = Join-Path $package "modules/$ModuleId/adapter.ps1"
    Assert ([IO.File]::Exists($expectedAdapter) -and [IO.File]::Exists($AdapterPath)) "Adapter missing: $CaseId"
    Assert ((Hash $AdapterPath) -ceq (Hash $expectedAdapter)) "Adapter bytes are not the frozen composed bytes: $CaseId"
    $target = [IO.Path]::GetFullPath([string]$Payload.targetRoot)
    $invariant = if($InvariantRoot){[IO.Path]::GetFullPath($InvariantRoot)}else{$target}
    $before = Fingerprint $invariant
    $input = ($Payload | ConvertTo-Json -Depth 100 -Compress).Replace("`r`n","`n")
    $previous = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $input
        $output = @(& $realPwsh -NoLogo -NoProfile -NonInteractive -File $AdapterPath 2>&1)
        $code = $LASTEXITCODE
    } finally { $env:V4_STAGE_INPUT_JSON = $previous }
    $after = Fingerprint $invariant
    $raw = $output -join "`n"
    Assert ($code -eq 0) "Adapter process failed: $CaseId / $raw"
    try { $result = $raw | ConvertFrom-Json -Depth 100 } catch { throw "Adapter result is not JSON: $CaseId / $raw" }
    Assert ($before -ceq $after) "TargetRoot changed: $CaseId"
    $fixtureFingerprint = Fingerprint $FixtureRoot
    $record = [ordered]@{
        moduleId = $ModuleId
        requested = $AdapterPath
        executed = $AdapterPath
        targetRoot = $target
        stage = [string]$Payload.stage
        caseId = $CaseId
        inputSha256 = Text-Hash $input
        fixtureSha256 = Text-Hash "$CaseId`n$input`n$before`n$fixtureFingerprint"
        exitCode = $code
        targetBefore = $before
        targetAfter = $after
        output = $raw
    }
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($capture))
    [IO.File]::AppendAllText($capture,(($record | ConvertTo-Json -Depth 100 -Compress)+"`n"),[Text.UTF8Encoding]::new($false))
    return $result
}
function New-Input([string]$Stage,[string]$Target,$Config,[string]$ExternalEvidence='') {
    $value = [ordered]@{
        formatVersion = 1
        stage = $Stage
        targetRoot = $Target
        packageRoot = $package
        stateRoot = Join-Path $runRoot 'state'
        evidenceRoot = if ($ExternalEvidence) { $ExternalEvidence } else { Join-Path $runRoot 'evidence' }
        projectId = 'ifx-050a-supplemental'
        relativeRoots = @('src')
        config = $Config
    }
    foreach ($path in @($value.stateRoot,$value.evidenceRoot)) { [void][IO.Directory]::CreateDirectory($path) }
    return $value
}

Assert ([IO.Directory]::Exists($package)) 'Composed PackageRoot is missing.'
Assert (-not [IO.File]::Exists($capture)) 'CapturePath must be absent.'
[void][IO.Directory]::CreateDirectory($runRoot)

# Provider Cycle uses a policy-local graph. The exact composed adapter bytes are copied beside
# disposable policy authorities so the detector can see clean, zero, missing and cyclic inputs.
$providerSource = Join-Path $package 'modules/ifx-provider-cycle'
$providerAdapterHash = Hash (Join-Path $providerSource 'adapter.ps1')
$providerPolicy = Get-Content -Raw -LiteralPath (Join-Path $providerSource 'policy.json') | ConvertFrom-Json -Depth 100
$providerClaim = 'IFX.C1.PROVIDER_CYCLE'
foreach ($definition in @(
    [ordered]@{ id='ifx-provider-cycle/M'; kind='missing'; graph=$null },
    [ordered]@{ id='ifx-provider-cycle/Z'; kind='zero'; graph=[ordered]@{} },
    [ordered]@{ id='ifx-provider-cycle/V/PROVIDER-CYCLE'; kind='violation'; graph=[ordered]@{ A=@('B'); B=@('C'); C=@('A') } }
)) {
    $caseRoot = Join-Path $runRoot ("provider/" + ($definition.id -replace '[^A-Za-z0-9._-]','_'))
    $moduleRoot = Join-Path $caseRoot 'ifx-provider-cycle'
    [void][IO.Directory]::CreateDirectory($moduleRoot)
    Copy-Item -LiteralPath (Join-Path $providerSource 'adapter.ps1') -Destination (Join-Path $moduleRoot 'adapter.ps1')
    Assert ((Hash (Join-Path $moduleRoot 'adapter.ps1')) -ceq $providerAdapterHash) "Provider adapter copy drift: $($definition.id)"
    $policyPath = Join-Path $moduleRoot 'policy.json'
    if ($definition.kind -cne 'missing') {
        $policy = $providerPolicy | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
        $policy.providerContracts = $definition.graph
        Write-Json $policyPath $policy
    }
    $policyHash = if ([IO.File]::Exists($policyPath)) { Hash $policyPath } else { '0' * 64 }
    $target = New-Target ($definition.id -replace '[^A-Za-z0-9._-]','_')
    $input = New-Input 'pre' $target ([ordered]@{ enabledClaims=@($providerClaim); policySha256=$policyHash })
    $result = Invoke-CapturedAdapter $definition.id 'ifx-provider-cycle' (Join-Path $moduleRoot 'adapter.ps1') $caseRoot $input
    if ($definition.kind -ceq 'missing') { Assert ($result.status -ceq 'error' -and $result.exitCategory -ceq 'prerequisite-missing' -and @($result.findings).Count -eq 0) 'Provider missing fixture failed.' }
    elseif ($definition.kind -ceq 'zero') { Assert ($result.status -ceq 'fail' -and $result.exitCategory -ceq 'findings-blocking' -and $result.coverage[0].matched -eq 0 -and @($result.findings | Where-Object { $_.subject -ceq 'providerContracts: zero provider edges' }).Count -eq 1) 'Provider zero fixture failed.' }
    else { Assert ($result.status -ceq 'fail' -and $result.exitCategory -ceq 'findings-blocking' -and $result.coverage[0].matched -eq 3 -and @($result.findings | Where-Object ruleId -CEQ 'PROVIDER-CYCLE').Count -gt 0) 'Provider violation fixture failed.' }
}

# Raw project-graph modules can share a syntactically valid out-of-scope project. It keeps src
# present while selecting no governed ring, so the composed adapters must emit their own zero
# findings rather than treating the prerequisite as missing.
$outsideTarget=New-Target 'raw-graph-zero'
$outsideProject=Join-Path $outsideTarget 'src/Other/Synthetic.Other/Synthetic.Other.csproj'
Write-Utf8 $outsideProject '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
foreach($definition in @(
    [ordered]@{id='ifx-package-reference/Z';module='ifx-package-reference';claims=@('IFX.C1.PACKAGE_ALLOW_RAW','IFX.C1.PACKAGE_DENY_RAW')},
    [ordered]@{id='ifx-ring-graph/Z';module='ifx-ring-graph';claims=@('IFX.C1.RING_GRAPH_RAW')},
    [ordered]@{id='ifx-ownership-graph/Z';module='ifx-ownership-graph';claims=@('IFX.C1.OWNERSHIP_GRAPH_RAW')}
)){
    $moduleRoot=Join-Path $package "modules/$($definition.module)";$adapter=Join-Path $moduleRoot 'adapter.ps1';$policyPath=Join-Path $moduleRoot 'policy.json'
    $input=New-Input 'pre' $outsideTarget ([ordered]@{enabledClaims=$definition.claims;policySha256=Hash $policyPath})
    $result=Invoke-CapturedAdapter $definition.id $definition.module $adapter $outsideTarget $input
    $claimIds=@($result.coverage|Where-Object{$_.matched-eq0-and$_.minimum-gt0}|ForEach-Object claimId|Sort-Object -Unique)
    Assert ($result.status-ceq'fail'-and$result.exitCategory-ceq'findings-blocking'-and($claimIds-join',')-ceq(@($definition.claims|Sort-Object)-join',')) "Raw graph zero fixture failed: $($definition.id)"
}

$injectionTarget=New-Target 'injection-zero'
$applicationProject=Join-Path $injectionTarget 'src/Modules/CRM/IFX.Modules.CRM.Application/IFX.Modules.CRM.Application.csproj'
$infrastructureProject=Join-Path $injectionTarget 'src/Modules/CRM/IFX.Modules.CRM.Infrastructure/IFX.Modules.CRM.Infrastructure.csproj'
Write-Utf8 $applicationProject '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
Write-Utf8 ([IO.Path]::ChangeExtension($applicationProject,'.cs')) 'namespace IFX.Modules.CRM.Application { public sealed class Marker { } }'
Write-Utf8 $infrastructureProject '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
Write-Utf8 ([IO.Path]::ChangeExtension($infrastructureProject,'.cs')) 'namespace IFX.Modules.CRM.Infrastructure { public sealed class Store { } }'
$injectionModule=Join-Path $package 'modules/ifx-injection';$injectionClaims=@('IFX.C1.FORBIDDEN_DEPENDENCY_SOURCE','IFX.C1.FORBIDDEN_DEPENDENCY_ORIGIN_SOURCE')
$injectionInput=New-Input 'pre' $injectionTarget ([ordered]@{enabledClaims=$injectionClaims;policySha256=Hash (Join-Path $injectionModule 'policy.json')})
$injectionResult=Invoke-CapturedAdapter 'ifx-injection/Z' 'ifx-injection' (Join-Path $injectionModule 'adapter.ps1') $injectionTarget $injectionInput
$injectionZeroClaims=@($injectionResult.coverage|Where-Object{$_.matched-eq0-and$_.minimum-gt0}|ForEach-Object claimId|Sort-Object -Unique)
Assert ($injectionResult.status-ceq'fail'-and$injectionResult.exitCategory-ceq'findings-blocking'-and($injectionZeroClaims-join',')-ceq(@($injectionClaims|Sort-Object)-join',')) 'Injection zero fixture failed.'

function New-SourcePolicyBase([string]$Name,[switch]$Zero) {
    $target=New-Target "source-policy-$Name"
    foreach($projectName in @('IFX.Modules.CRM.Domain','IFX.Modules.CRM.Application','IFX.Modules.CRM.Infrastructure','IFX.Modules.CRM.Contracts')){
        Write-Utf8 (Join-Path $target "src/$projectName/$projectName.csproj") '<Project Sdk="Microsoft.NET.Sdk" />'
    }
    if($Zero){
        Write-Utf8 (Join-Path $target 'src/IFX.Modules.CRM.Domain/Empty.cs') '// Intentionally contains no governed import, declaration, symbol or payload.'
        return $target
    }
    $files=[ordered]@{
        'src/IFX.Modules.CRM.Domain/IAccountRepository.cs'='namespace IFX.Modules.CRM.Domain { public interface IAccountRepository {} }'
        'src/IFX.Modules.CRM.Application/IAccountPort.cs'='using IFX.Modules.CRM.Domain; using MediatR; namespace IFX.Modules.CRM.Application.Ports { public interface IAccountPort {} }'
        'src/IFX.Modules.CRM.Infrastructure/AccountRepository.cs'='using IFX.Modules.CRM.Domain; namespace IFX.Modules.CRM.Infrastructure { public class AccountRepository : IAccountRepository {} }'
        'src/IFX.Modules.CRM.Contracts/IAccountContract.cs'='namespace IFX.Modules.CRM.Contracts { public interface IAccountContract {} }'
        'src/IFX.Modules.CRM.Contracts/AccountIntegrationEvent.cs'='namespace IFX.Modules.CRM.Contracts.Events { public record AccountIntegrationEvent(System.Guid Id); }'
    }
    foreach($entry in $files.GetEnumerator()){Write-Utf8 (Join-Path $target $entry.Key) $entry.Value}
    return $target
}

$sourceModule=Join-Path $package 'modules/ifx-source-policy'
$sourceAdapter=Join-Path $sourceModule 'adapter.ps1'
$sourcePolicyPath=Join-Path $sourceModule 'policy.json'
$sourcePolicy=Get-Content -Raw -LiteralPath $sourcePolicyPath|ConvertFrom-Json -Depth 100
$sourceClaims=@($sourcePolicy.claims)
$sourceZeroTarget=New-SourcePolicyBase 'zero' -Zero
$sourceZeroInput=New-Input 'pre' $sourceZeroTarget ([ordered]@{enabledClaims=$sourceClaims;policySha256=Hash $sourcePolicyPath})
$sourceZeroResult=Invoke-CapturedAdapter 'ifx-source-policy/Z' 'ifx-source-policy' $sourceAdapter $sourceZeroTarget $sourceZeroInput
$sourceZeroClaims=@($sourceZeroResult.coverage|Where-Object{$_.matched-eq0-and$_.minimum-gt0}|ForEach-Object claimId|Sort-Object -Unique)
Assert ($sourceZeroResult.status-ceq'fail'-and$sourceZeroResult.exitCategory-ceq'findings-blocking'-and($sourceZeroClaims-join',')-ceq(@($sourceClaims|Sort-Object)-join',')) 'Source Policy zero fixture failed.'

# The published policy currently marks its only mustImplement declaration as bends, so its
# generic blocking branch is unreachable from that authority. Keep the frozen adapter bytes and
# add a disposable blocking declaration to exercise the branch without changing the package.
$sourceBlockingRoot=Join-Path $runRoot 'source-policy/blocking-implements'
$sourceBlockingModule=Join-Path $sourceBlockingRoot 'ifx-source-policy'
[void][IO.Directory]::CreateDirectory($sourceBlockingModule)
Copy-Item -LiteralPath $sourceAdapter -Destination (Join-Path $sourceBlockingModule 'adapter.ps1')
$sourceBlockingPolicy=$sourcePolicy|ConvertTo-Json -Depth 100|ConvertFrom-Json -Depth 100
$sourceBlockingPolicy.declarations=@($sourceBlockingPolicy.declarations)+@([ordered]@{match='*Gateway';kind='class';mustLiveIn='Infrastructure';mustImplement='Application'})
$sourceBlockingPolicyPath=Join-Path $sourceBlockingModule 'policy.json'
Write-Json $sourceBlockingPolicyPath $sourceBlockingPolicy
$sourceBlockingTarget=New-SourcePolicyBase 'blocking-implements'
Write-Utf8 (Join-Path $sourceBlockingTarget 'src/IFX.Modules.CRM.Infrastructure/Integrations/BadGateway.cs') 'namespace IFX.Modules.CRM.Infrastructure.Integrations { public class BadGateway {} }'
$sourceBlockingInput=New-Input 'pre' $sourceBlockingTarget ([ordered]@{enabledClaims=$sourceClaims;policySha256=Hash $sourceBlockingPolicyPath})
$sourceBlockingResult=Invoke-CapturedAdapter 'ifx-source-policy/V/DECLARATION-IMPLEMENTS' 'ifx-source-policy' (Join-Path $sourceBlockingModule 'adapter.ps1') $sourceBlockingTarget $sourceBlockingInput
$sourceBlockingRules=@($sourceBlockingResult.findings|Where-Object severity -CEQ 'blocking'|ForEach-Object ruleId|Sort-Object -Unique)
Assert ($sourceBlockingResult.status-ceq'fail'-and$sourceBlockingResult.exitCategory-ceq'findings-blocking'-and($sourceBlockingRules-join',')-ceq'DECLARATION-IMPLEMENTS'-and@($sourceBlockingResult.coverage|Where-Object matched -lt 1).Count-eq0) 'Source Policy blocking implements fixture failed.'

$sourceAdvisoryTarget=New-SourcePolicyBase 'advisory-placement'
Write-Utf8 (Join-Path $sourceAdvisoryTarget 'src/IFX.Modules.CRM.Domain/MisplacedCommandValidator.cs') 'namespace IFX.Modules.CRM.Domain { public class MisplacedCommandValidator {} }'
$sourceAdvisoryInput=New-Input 'pre' $sourceAdvisoryTarget ([ordered]@{enabledClaims=$sourceClaims;policySha256=Hash $sourcePolicyPath})
$sourceAdvisoryResult=Invoke-CapturedAdapter 'ifx-source-policy/A/DECLARATION-PLACEMENT-ADVISORY' 'ifx-source-policy' $sourceAdapter $sourceAdvisoryTarget $sourceAdvisoryInput
$sourceAdvisoryRules=@($sourceAdvisoryResult.findings|ForEach-Object ruleId|Sort-Object -Unique)
Assert ($sourceAdvisoryResult.status-ceq'pass'-and$sourceAdvisoryResult.exitCategory-ceq'success'-and($sourceAdvisoryRules-join',')-ceq'DECLARATION-PLACEMENT-ADVISORY'-and@($sourceAdvisoryResult.coverage|Where-Object matched -lt 1).Count-eq0) 'Source Policy advisory placement fixture failed.'

$historyModule=Join-Path $package 'modules/ifx-history-integrity'
$historyFixture=Join-Path $runRoot 'history-missing-fixture';[void][IO.Directory]::CreateDirectory($historyFixture)
$historyMissingTarget=Join-Path $historyFixture 'missing-target'
$historyInput=New-Input 'post' $historyMissingTarget ([ordered]@{enabledClaims=@('IFX.C5.HISTORY_INTEGRITY');policySha256=Hash (Join-Path $historyModule 'policy.json')})
$historyInput.relativeRoots=@('mcp','docs')
$historyResult=Invoke-CapturedAdapter 'ifx-history-integrity/M' 'ifx-history-integrity' (Join-Path $historyModule 'adapter.ps1') $historyFixture $historyInput
Assert ($historyResult.status-ceq'error'-and$historyResult.exitCategory-ceq'prerequisite-missing'-and@($historyResult.findings).Count-eq0-and$historyResult.coverage[0].matched-eq0) 'History missing fixture failed.'

function New-ArchitectureFixture([string]$Name,[switch]$Violating) {
    $root=Join-Path $runRoot "architecture/$Name";$source=Join-Path $root 'source';$evidenceRoot=Join-Path $root 'evidence';$assemblies=Join-Path $evidenceRoot 'assemblies';$target=New-Target "architecture-$Name"
    foreach($path in @($source,$assemblies)){[void][IO.Directory]::CreateDirectory($path)}
    $contracts=Join-Path $source 'Contracts';$application=Join-Path $source 'Application'
    Write-Utf8 (Join-Path $contracts 'Synthetic.Contracts.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Contracts</AssemblyName><RootNamespace>Synthetic.Contracts</RootNamespace></PropertyGroup></Project>'
    Write-Utf8 (Join-Path $contracts 'Contracts.cs') 'namespace Synthetic.Contracts { public interface IPort { } } namespace Synthetic.Forbidden { public sealed class ForbiddenType { } }'
    Write-Utf8 (Join-Path $application 'Synthetic.Application.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework><AssemblyName>Synthetic.Application</AssemblyName><RootNamespace>Synthetic.Application</RootNamespace></PropertyGroup><ItemGroup><ProjectReference Include="../Contracts/Synthetic.Contracts.csproj" /></ItemGroup></Project>'
    $appSource=if($Violating){'namespace Synthetic.Application.Bad { public sealed class Port : Synthetic.Contracts.IPort { public Synthetic.Forbidden.ForbiddenType Value { get; } = new(); } }'}else{'namespace Synthetic.Application.Allowed { public sealed class Port : Synthetic.Contracts.IPort { } }'}
    Write-Utf8 (Join-Path $application 'Application.cs') $appSource
    $props=@('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false')
    $restore=@(& dotnet restore (Join-Path $application 'Synthetic.Application.csproj') --configfile (Join-Path $package 'build/NuGet.config') -nologo @props 2>&1);Assert ($LASTEXITCODE-eq0) "Architecture restore failed: $Name / $($restore-join"`n")"
    $build=@(& dotnet build (Join-Path $application 'Synthetic.Application.csproj') --no-restore -c Debug -o $assemblies -nologo @props 2>&1);Assert ($LASTEXITCODE-eq0) "Architecture build failed: $Name / $($build-join"`n")"
    $manifest=[ordered]@{formatVersion=1;assemblies=@()};foreach($assemblyName in @('Synthetic.Contracts','Synthetic.Application')){$path=Join-Path $assemblies "$assemblyName.dll";$manifest.assemblies += [ordered]@{assemblyName=$assemblyName;path="assemblies/$assemblyName.dll";sha256=Hash $path}}
    Write-Json (Join-Path $evidenceRoot 'assembly-manifest.json') $manifest
    [pscustomobject]@{Root=$root;Target=$target;Evidence=$evidenceRoot;SourceNamespace=$(if($Violating){'Synthetic.Application.Bad'}else{'Synthetic.Application.Allowed'})}
}
function Architecture-Config($Fixture,[switch]$Zero) {
    [ordered]@{
        enabledClaims=@('ARCH.TYPE_DEPENDENCY')
        assemblyManifestPath='assembly-manifest.json'
        forbiddenTypeDependencies=@([ordered]@{sourceAssembly='Synthetic.Application';sourceNamespace=$(if($Zero){'Synthetic.Application.Absent'}else{$Fixture.SourceNamespace});forbiddenAssembly='Synthetic.Contracts';forbiddenNamespace='Synthetic.Forbidden';minimumMatches=1})
        implementationLocations=@()
        assemblyPlacements=@()
    }
}
$architectureAdapter=Join-Path $package 'modules/architecture-conformance/adapter.ps1'
$architectureClean=New-ArchitectureFixture 'clean'
$architectureBad=New-ArchitectureFixture 'violating' -Violating
$cleanInput=New-Input 'post' $architectureClean.Target (Architecture-Config $architectureClean) $architectureClean.Evidence
$cleanResult=Invoke-CapturedAdapter 'architecture-conformance/C' 'architecture-conformance' $architectureAdapter $architectureClean.Root $cleanInput
Assert ($cleanResult.status-ceq'pass'-and$cleanResult.exitCategory-ceq'success'-and@($cleanResult.coverage|Where-Object{$_.claimId-ceq'ARCH.TYPE_DEPENDENCY'-and$_.matched-gt0}).Count-eq1) 'Architecture clean fixture failed.'
$zeroInput=New-Input 'post' $architectureClean.Target (Architecture-Config $architectureClean -Zero) $architectureClean.Evidence
$zeroResult=Invoke-CapturedAdapter 'architecture-conformance/Z' 'architecture-conformance' $architectureAdapter $architectureClean.Root $zeroInput
Assert ($zeroResult.status-ceq'fail'-and$zeroResult.exitCategory-ceq'findings-blocking'-and@($zeroResult.coverage|Where-Object{$_.claimId-ceq'ARCH.TYPE_DEPENDENCY'-and$_.matched-eq0}).Count-eq1) 'Architecture zero fixture failed.'
$badInput=New-Input 'post' $architectureBad.Target (Architecture-Config $architectureBad) $architectureBad.Evidence
$badResult=Invoke-CapturedAdapter 'architecture-conformance/V/ARCH.TYPE_DEPENDENCY' 'architecture-conformance' $architectureAdapter $architectureBad.Root $badInput
Assert ($badResult.status-ceq'fail'-and$badResult.exitCategory-ceq'findings-blocking'-and@($badResult.findings|Where-Object{$_.ruleId-ceq'ARCH.TYPE_DEPENDENCY'-and$_.detectorId-ceq'archunitnet'-and$_.evidenceKind-ceq'compiled-assembly'}).Count-gt0) 'Architecture violation fixture failed.'
$missingRoot=Join-Path $runRoot 'architecture/missing';$missingEvidence=Join-Path $missingRoot 'evidence';$missingTarget=New-Target 'architecture-missing';[void][IO.Directory]::CreateDirectory($missingEvidence)
Write-Json (Join-Path $missingEvidence 'assembly-manifest.json') ([ordered]@{formatVersion=1;assemblies=@([ordered]@{assemblyName='Synthetic.Contracts';path='assemblies/missing.dll';sha256='0'*64})})
$missingFixture=[pscustomobject]@{Root=$missingRoot;Target=$missingTarget;Evidence=$missingEvidence;SourceNamespace='Synthetic.Application.Allowed'}
$missingInput=New-Input 'post' $missingTarget (Architecture-Config $missingFixture) $missingEvidence
$missingResult=Invoke-CapturedAdapter 'architecture-conformance/M' 'architecture-conformance' $architectureAdapter $missingRoot $missingInput
Assert ($missingResult.status-ceq'error'-and$missingResult.exitCategory-ceq'prerequisite-missing'-and@($missingResult.findings).Count-eq0) 'Architecture missing fixture failed.'

$lines=@(Get-Content -LiteralPath $capture)
Assert ($lines.Count -eq 15) "Expected fifteen supplemental captures, found $($lines.Count)."
Write-Output "IFX 0.5.0-a supplemental fixtures passed fifteen Provider, raw-graph, Injection, Source Policy, History and Architecture cases: $capture"
