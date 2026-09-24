[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackageRoot,
    [string]$RepositoryRoot = (Get-Location).Path,
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-c6c4/supplemental-runs',
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
function New-Target([string]$Name) {
    $target = Join-Path $runRoot "targets/$Name"
    [void][IO.Directory]::CreateDirectory($target)
    [void][IO.Directory]::CreateDirectory((Join-Path $target 'src'))
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
        projectId = 'ifx-c6c4-supplemental'
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

function New-AuthorityTarget([string]$Name,[string]$ModuleId) {
    $module=Join-Path $package "modules/$ModuleId"
    $policyPath=Join-Path $module 'policy.json'
    $policy=Get-Content -Raw -LiteralPath $policyPath|ConvertFrom-Json -Depth 100
    $target=New-Target $Name
    foreach($authority in @($policy.authorities)){
        $source=Join-Path $repo ([string]$authority.path)
        Assert ([IO.File]::Exists($source)) "Repository authority missing: $ModuleId/$($authority.id)"
        $destination=Join-Path $target ([string]$authority.path)
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::WriteAllBytes($destination,[IO.File]::ReadAllBytes($source))
    }
    [pscustomobject]@{Module=$module;PolicyPath=$policyPath;Policy=$policy;Target=$target}
}
function Authority-Hashes($Fixture){
    @($Fixture.Policy.authorities|ForEach-Object{[ordered]@{id=$_.id;sha256=Hash (Join-Path $Fixture.Target $_.path)}})
}

$g04Evidence=New-AuthorityTarget 'g04-evidence-violation' 'ifx-g04-closeout'
$g04Phase8=@($g04Evidence.Policy.authorities|Where-Object id -CEQ 'phase8')[0]
Write-Utf8 (Join-Path $g04Evidence.Target $g04Phase8.path) ''
$g04Config=[ordered]@{enabledClaims=@('IFX.C3.G04_EVIDENCE','IFX.C3.G04_DOCUMENTATION','IFX.C3.G04_CLOSEOUT','IFX.C3.G04_INBOUND_CLOSEOUT');policySha256=Hash $g04Evidence.PolicyPath;authorityHashes=Authority-Hashes $g04Evidence}
$g04Input=New-Input 'post' $g04Evidence.Target $g04Config;$g04Input.relativeRoots=@('docs','deployment')
$g04Result=Invoke-CapturedAdapter 'ifx-g04-closeout/V/G04-EVIDENCE' 'ifx-g04-closeout' (Join-Path $g04Evidence.Module 'adapter.ps1') $g04Evidence.Target $g04Input
$g04Rules=@($g04Result.findings|ForEach-Object ruleId|Sort-Object -Unique)
Assert ($g04Result.status-ceq'fail'-and$g04Result.exitCategory-ceq'findings-blocking'-and($g04Rules-join',')-ceq'G04-EVIDENCE'-and@($g04Result.coverage|Where-Object{$_.claimId-ceq'IFX.C3.G04_EVIDENCE'-and$_.matched-gt0}).Count-eq1) 'G04 evidence violation fixture failed.'

$g05Protocol=New-AuthorityTarget 'g05-protocol-evidence-violation' 'ifx-g05-protocol'
$g05Phase1=@($g05Protocol.Policy.authorities|Where-Object id -CEQ 'phase1Evidence')[0]
Write-Utf8 (Join-Path $g05Protocol.Target $g05Phase1.path) ''
$g05ProtocolConfig=[ordered]@{enabledClaims=@('IFX.C4.G05_PROTOCOL_DEPENDENCIES','IFX.C4.G05_PROTOCOL_SHAPES','IFX.C4.G05_PROTOCOL_EVIDENCE');policySha256=Hash $g05Protocol.PolicyPath;authorityHashes=Authority-Hashes $g05Protocol}
$g05ProtocolInput=New-Input 'post' $g05Protocol.Target $g05ProtocolConfig;$g05ProtocolInput.relativeRoots=@('src','docs','tests','deployment')
$g05ProtocolResult=Invoke-CapturedAdapter 'ifx-g05-protocol/V/G05-PROTOCOL-EVIDENCE' 'ifx-g05-protocol' (Join-Path $g05Protocol.Module 'adapter.ps1') $g05Protocol.Target $g05ProtocolInput
$g05ProtocolRules=@($g05ProtocolResult.findings|ForEach-Object ruleId|Sort-Object -Unique)
Assert ($g05ProtocolResult.status-ceq'fail'-and$g05ProtocolResult.exitCategory-ceq'findings-blocking'-and($g05ProtocolRules-join',')-ceq'G05-PROTOCOL-EVIDENCE'-and@($g05ProtocolResult.coverage|Where-Object{$_.claimId-ceq'IFX.C4.G05_PROTOCOL_EVIDENCE'-and$_.matched-gt0}).Count-eq1) 'G05 protocol evidence violation fixture failed.'

$g05Governance=New-AuthorityTarget 'g05-governance-zero' 'ifx-g05-governance'
$handlerRoot=Join-Path $repo ([string]$g05Governance.Policy.transactionHandlersRoot)
foreach($file in Get-ChildItem -LiteralPath $handlerRoot -File -Filter '*Handler.cs' -Recurse|Sort-Object FullName){
    $destination=Join-Path $g05Governance.Target ([IO.Path]::GetRelativePath($repo,$file.FullName));[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination));[IO.File]::WriteAllBytes($destination,[IO.File]::ReadAllBytes($file.FullName))
}
$catalogAuthority=@($g05Governance.Policy.authorities|Where-Object id -CEQ 'catalog')[0]
$catalogPath=Join-Path $g05Governance.Target $catalogAuthority.path
$catalog=Get-Content -Raw -LiteralPath $catalogPath|ConvertFrom-Json -AsHashtable -Depth 100;$catalog.fieldSurfaces=@();Write-Json $catalogPath $catalog
$handlerLines=@(Get-ChildItem -LiteralPath (Join-Path $g05Governance.Target $g05Governance.Policy.transactionHandlersRoot) -File -Filter '*Handler.cs' -Recurse|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($g05Governance.Target,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})-join"`n"
$g05GovernanceConfig=[ordered]@{enabledClaims=@('IFX.C4.G05_FIELD_GOVERNANCE','IFX.C4.G05_OBSERVABILITY');policySha256=Hash $g05Governance.PolicyPath;authorityHashes=Authority-Hashes $g05Governance;transactionHandlersSha256=Text-Hash $handlerLines}
$g05GovernanceInput=New-Input 'post' $g05Governance.Target $g05GovernanceConfig;$g05GovernanceInput.relativeRoots=@('src','docs','tests')
$g05GovernanceResult=Invoke-CapturedAdapter 'ifx-g05-governance/Z' 'ifx-g05-governance' (Join-Path $g05Governance.Module 'adapter.ps1') $g05Governance.Target $g05GovernanceInput
Assert ($g05GovernanceResult.status-ceq'fail'-and$g05GovernanceResult.exitCategory-ceq'findings-blocking'-and@($g05GovernanceResult.findings|Where-Object{$_.ruleId-ceq'G05-FIELD-GOVERNANCE'-and$_.subject-ceq'allTargetLegacyAndEnvelopeFieldsAreClassified'}).Count-eq1) 'G05 governance zero fixture failed.'

$g05Closeout=New-AuthorityTarget 'g05-closeout-handoff-zero' 'ifx-g05-closeout'
$diagramRoot=Join-Path $repo ([string]$g05Closeout.Policy.diagramRoot);$targetDiagramRoot=Join-Path $g05Closeout.Target ([string]$g05Closeout.Policy.diagramRoot);[void][IO.Directory]::CreateDirectory($targetDiagramRoot)
foreach($file in Get-ChildItem -LiteralPath $diagramRoot -File){[IO.File]::WriteAllBytes((Join-Path $targetDiagramRoot $file.Name),[IO.File]::ReadAllBytes($file.FullName))}
$handoff=@($g05Closeout.Policy.authorities|Where-Object id -CEQ 'handoff01')[0];Write-Utf8 (Join-Path $g05Closeout.Target $handoff.path) ''
$diagramLines=@(Get-ChildItem -LiteralPath $targetDiagramRoot -File -Force|Where-Object Extension -in '.mmd','.svg','.png'|Sort-Object Name|ForEach-Object{"$($_.Name)|$(Hash $_.FullName)"})-join"`n"
$g05CloseoutConfig=[ordered]@{enabledClaims=@('IFX.C4.G05_REPLAY','IFX.C4.G05_DOCUMENTATION','IFX.C4.G05_HANDOFF');policySha256=Hash $g05Closeout.PolicyPath;authorityHashes=Authority-Hashes $g05Closeout;diagramTreeSha256=Text-Hash $diagramLines}
$g05CloseoutInput=New-Input 'post' $g05Closeout.Target $g05CloseoutConfig;$g05CloseoutInput.relativeRoots=@('docs','tests')
$g05CloseoutResult=Invoke-CapturedAdapter 'ifx-g05-closeout/V/G05-HANDOFF' 'ifx-g05-closeout' (Join-Path $g05Closeout.Module 'adapter.ps1') $g05Closeout.Target $g05CloseoutInput
$g05CloseoutRules=@($g05CloseoutResult.findings|ForEach-Object ruleId|Sort-Object -Unique)
Assert ($g05CloseoutResult.status-ceq'fail'-and$g05CloseoutResult.exitCategory-ceq'findings-blocking'-and($g05CloseoutRules-join',')-ceq'G05-HANDOFF'-and@($g05CloseoutResult.findings|Where-Object subject -CEQ 'fourOwnershipPreservingHandoffsExist').Count-eq1) 'G05 closeout handoff fixture failed.'

# The final profile binds all C5/C1 evidence locks. Copy those immutable runs into one isolated
# target, refresh only their temporal/run-path fields, and let the frozen adapters revalidate the
# full source, file-hash and lineage chain.
$lineagePath=Join-Path $package 'profiles/catalog/ifx_profile/evidence-lineage.json'
Assert ([IO.File]::Exists($lineagePath)) 'Final profile evidence lineage is missing.'
$lineage=Get-Content -Raw -LiteralPath $lineagePath|ConvertFrom-Json -Depth 100
function Lineage-Path([string]$Id){
    $row=@($lineage.locks|Where-Object id -CEQ $Id);Assert ($row.Count-eq1) "Lineage lock missing: $Id"
    $path=Join-Path $repo ([string]$row[0].path);Assert ([IO.File]::Exists($path)) "Lineage file missing: $Id"
    [string]$row[0].path
}
function Copy-TargetFile([string]$Source,[string]$Relative){
    $destination=Join-Path $lineageTarget $Relative;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination));[IO.File]::WriteAllBytes($destination,[IO.File]::ReadAllBytes($Source))
}
function Copy-LineageRun([string]$SourceLockRelative,[string]$DestinationLockRelative){
    $sourceDirectory=[IO.Path]::GetDirectoryName((Join-Path $repo $SourceLockRelative));$destinationDirectory=[IO.Path]::GetDirectoryName((Join-Path $lineageTarget $DestinationLockRelative))
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destinationDirectory));Copy-Item -LiteralPath $sourceDirectory -Destination $destinationDirectory -Recurse
}
function Rebase-LockFiles($Lock,[string]$OldPrefix,[string]$NewPrefix){
    foreach($entry in @($Lock.files)){if(([string]$entry.path).StartsWith($OldPrefix,[StringComparison]::Ordinal)){$entry.path=$NewPrefix+([string]$entry.path).Substring($OldPrefix.Length)}}
}

$lineageTarget=New-Target 'lineage-evidence'
foreach($relativeRoot in @('src','tests','tools')){
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $repo $relativeRoot) -File -Recurse -Force|Where-Object{$_.Extension -in '.cs','.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]'}|Sort-Object FullName){Copy-TargetFile $file.FullName ([IO.Path]::GetRelativePath($repo,$file.FullName))}
}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $repo 'src/Frontend/IFX.FrontEnd') -File -Recurse -Force|Where-Object{$_.Extension -in '.ts','.tsx','.js','.json','.html','.css','.svg','.mjs','.cjs' -and $_.FullName -notmatch '[\\/](node_modules|dist|coverage|\.vite)[\\/]'}|Sort-Object FullName){Copy-TargetFile $file.FullName ([IO.Path]::GetRelativePath($repo,$file.FullName))}
foreach($relative in @('IFX.sln','Directory.Build.props','Directory.Packages.props','docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json','docs/guards/V3_ifx/stages/post/policy/layerguard.json','docs/guards/candidates/ifx-gate-coverage-c1n/modules/ifx-reference-cycle/policy.json','docs/guards/candidates/ifx-gate-coverage-c1e/modules/ifx-ownership-graph/policy.json')){Copy-TargetFile (Join-Path $repo $relative) $relative}

$seedSolutionRelative=Lineage-Path 'solution';$seedAssemblyRelative=Lineage-Path 'assembly';$seedFrontendRelative=Lineage-Path 'frontend';$seedTypeRelative=Lineage-Path 'type';$seedGraphRelative=Lineage-Path 'graph'
$seedAssembly=Get-Content -Raw -LiteralPath (Join-Path $repo $seedAssemblyRelative)|ConvertFrom-Json -Depth 100
$seedType=Get-Content -Raw -LiteralPath (Join-Path $repo $seedTypeRelative)|ConvertFrom-Json -Depth 100
foreach($relative in @($seedAssembly.assemblies.path)+@($seedType.assemblies.sourcePath)|Sort-Object -Unique){Copy-TargetFile (Join-Path $repo $relative) $relative}
$now=[DateTimeOffset]::UtcNow

$solutionId=[Guid]::NewGuid().ToString('N');$solutionRelative="artifacts/guards/p10-ifx-c5b/solution-runs/$solutionId/evidence-lock.json";Copy-LineageRun $seedSolutionRelative $solutionRelative
$solutionLock=Get-Content -Raw -LiteralPath (Join-Path $lineageTarget $solutionRelative)|ConvertFrom-Json -Depth 100;$oldSolutionPrefix=[string]$solutionLock.evidencePrefix;$solutionPrefix="artifacts/guards/p10-ifx-c5b/solution-runs/$solutionId/";$solutionLock.evidencePrefix=$solutionPrefix;Rebase-LockFiles $solutionLock $oldSolutionPrefix $solutionPrefix;$solutionLock.startedAt=$now.AddMinutes(-10).ToString('o');$solutionLock.completedAt=$now.AddMinutes(-9).ToString('o');Write-Json (Join-Path $lineageTarget $solutionRelative) $solutionLock

$assemblyId=[Guid]::NewGuid().ToString('N');$assemblyRelative="artifacts/guards/p10-ifx-c5c/assembly-runs/$assemblyId/evidence-lock.json";Copy-LineageRun $seedAssemblyRelative $assemblyRelative
$assemblyLock=Get-Content -Raw -LiteralPath (Join-Path $lineageTarget $assemblyRelative)|ConvertFrom-Json -Depth 100;$oldAssemblyPrefix=[string]$assemblyLock.evidencePrefix;$assemblyPrefix="artifacts/guards/p10-ifx-c5c/assembly-runs/$assemblyId/";$assemblyLock.evidencePrefix=$assemblyPrefix;$assemblyLock.solutionLockPath=$solutionRelative;$assemblyLock.solutionLockSha256=Hash (Join-Path $lineageTarget $solutionRelative);$assemblyLock.startedAt=$now.AddMinutes(-8).ToString('o');$assemblyLock.completedAt=$now.AddMinutes(-7).ToString('o');Write-Json (Join-Path $lineageTarget $assemblyRelative) $assemblyLock

$typeId=[Guid]::NewGuid().ToString('N');$typeRelative="artifacts/guards/p10-ifx-c1-r1b/type-runs/$typeId/evidence-lock.json";Copy-LineageRun $seedTypeRelative $typeRelative
$typeLock=Get-Content -Raw -LiteralPath (Join-Path $lineageTarget $typeRelative)|ConvertFrom-Json -Depth 100;$oldTypePrefix=([string]$typeLock.manifestPath).Substring(0,([string]$typeLock.manifestPath).Length-'assembly-manifest.json'.Length);$typePrefix="artifacts/guards/p10-ifx-c1-r1b/type-runs/$typeId/";$typeLock.createdAt=$now.AddMinutes(-5).ToString('o');$typeLock.expiresAt=$now.AddMinutes(55).ToString('o');$typeLock.solutionLockPath=$solutionRelative;$typeLock.solutionLockSha256=Hash (Join-Path $lineageTarget $solutionRelative);$typeLock.assemblyLockPath=$assemblyRelative;$typeLock.assemblyLockSha256=Hash (Join-Path $lineageTarget $assemblyRelative);$typeLock.manifestPath=$typePrefix+'assembly-manifest.json';foreach($row in @($typeLock.assemblies)){$row.copiedPath=$typePrefix+([string]$row.copiedPath).Substring($oldTypePrefix.Length)};Write-Json (Join-Path $lineageTarget $typeRelative) $typeLock
$typeExternal=Join-Path $runRoot 'lineage-type-external';[void][IO.Directory]::CreateDirectory($typeExternal);Copy-Item -LiteralPath (Join-Path $lineageTarget $typePrefix 'assembly-manifest.json') -Destination (Join-Path $typeExternal 'assembly-manifest.json');Copy-Item -LiteralPath (Join-Path $lineageTarget $typePrefix 'assemblies') -Destination (Join-Path $typeExternal 'assemblies') -Recurse
$typeModule=Join-Path $package 'modules/ifx-c1-type-provenance';$typeConfig=[ordered]@{enabledClaims=@('IFX.C1.COMPILED_TYPE_PROVENANCE');policySha256=Hash (Join-Path $typeModule 'policy.json');evidenceLockPath=$typeRelative;evidenceLockSha256=Hash (Join-Path $lineageTarget $typeRelative)}
$typeInput=New-Input 'post' $lineageTarget $typeConfig $typeExternal;$typeResult=Invoke-CapturedAdapter 'ifx-c1-type-provenance/C' 'ifx-c1-type-provenance' (Join-Path $typeModule 'adapter.ps1') $lineageTarget $typeInput
Assert ($typeResult.status-ceq'pass'-and$typeResult.exitCategory-ceq'success'-and$typeResult.coverage[0].matched-eq7-and@($typeResult.findings).Count-eq0) 'Type provenance clean fixture failed.'
$typeMissingConfig=$typeConfig|ConvertTo-Json -Depth 20|ConvertFrom-Json -AsHashtable -Depth 20;$typeMissingConfig.evidenceLockPath='artifacts/guards/p10-ifx-c1-r1b/type-runs/'+('0'*32)+'/evidence-lock.json';$typeMissingInput=New-Input 'post' $lineageTarget $typeMissingConfig $typeExternal
$typeMissing=Invoke-CapturedAdapter 'ifx-c1-type-provenance/M' 'ifx-c1-type-provenance' (Join-Path $typeModule 'adapter.ps1') $lineageTarget $typeMissingInput
Assert ($typeMissing.status-ceq'error'-and$typeMissing.exitCategory-ceq'prerequisite-missing'-and@($typeMissing.findings).Count-eq0) 'Type provenance missing fixture failed.'
$typeIntegrityConfig=$typeConfig|ConvertTo-Json -Depth 20|ConvertFrom-Json -AsHashtable -Depth 20;$typeIntegrityConfig.evidenceLockSha256='0'*64;$typeIntegrityInput=New-Input 'post' $lineageTarget $typeIntegrityConfig $typeExternal
$typeIntegrity=Invoke-CapturedAdapter 'ifx-c1-type-provenance/Z' 'ifx-c1-type-provenance' (Join-Path $typeModule 'adapter.ps1') $lineageTarget $typeIntegrityInput
Assert ($typeIntegrity.status-ceq'error'-and$typeIntegrity.exitCategory-ceq'integrity-failure'-and$typeIntegrity.coverage[0].matched-eq0-and@($typeIntegrity.findings).Count-eq0) 'Type provenance integrity-zero fixture failed.'

$graphId=[Guid]::NewGuid().ToString('N');$graphRelative="artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/$graphId/evidence-lock.json";$graphSourceDirectory=[IO.Path]::GetDirectoryName((Join-Path $repo $seedGraphRelative));$graphDirectory=[IO.Path]::GetDirectoryName((Join-Path $repo $graphRelative));Copy-Item -LiteralPath $graphSourceDirectory -Destination $graphDirectory -Recurse
$graphLock=Get-Content -Raw -LiteralPath (Join-Path $repo $graphRelative)|ConvertFrom-Json -Depth 100;$graphLock.targetCommit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant();Assert ($LASTEXITCODE-eq0-and$graphLock.targetCommit-cmatch'^[a-f0-9]{40}$') 'Graph target commit unavailable.';$graphLock.createdAt=$now.AddMinutes(-5).ToString('o');$graphLock.expiresAt=$now.AddMinutes(55).ToString('o');Write-Json (Join-Path $repo $graphRelative) $graphLock
$graphModule=Join-Path $package 'modules/ifx-c1-evaluated-reference';$graphConfig=[ordered]@{enabledClaims=@('IFX.C1.EVALUATED_REFERENCE_GRAPH');policySha256=Hash (Join-Path $graphModule 'policy.json');evidenceLockPath=$graphRelative;evidenceLockSha256=Hash (Join-Path $repo $graphRelative)}
$graphInvariant=Join-Path $repo ([IO.Path]::GetDirectoryName($graphRelative));$graphInput=New-Input 'post' $repo $graphConfig;$graphResult=Invoke-CapturedAdapter 'ifx-c1-evaluated-reference/C' 'ifx-c1-evaluated-reference' (Join-Path $graphModule 'adapter.ps1') $graphInvariant $graphInput $graphInvariant
Assert ($graphResult.status-ceq'pass'-and$graphResult.exitCategory-ceq'success'-and$graphResult.coverage[0].matched-gt0-and@($graphResult.findings).Count-eq0) 'Evaluated reference clean fixture failed.'

$assemblyZeroId=[Guid]::NewGuid().ToString('N');$assemblyZeroRelative="artifacts/guards/p10-ifx-c5c/assembly-runs/$assemblyZeroId/evidence-lock.json";$assemblyCleanDirectory=[IO.Path]::GetDirectoryName((Join-Path $lineageTarget $assemblyRelative));$assemblyZeroDirectory=[IO.Path]::GetDirectoryName((Join-Path $lineageTarget $assemblyZeroRelative));Copy-Item -LiteralPath $assemblyCleanDirectory -Destination $assemblyZeroDirectory -Recurse
$assemblyZero=Get-Content -Raw -LiteralPath (Join-Path $lineageTarget $assemblyZeroRelative)|ConvertFrom-Json -Depth 100;$assemblyZeroPrefix="artifacts/guards/p10-ifx-c5c/assembly-runs/$assemblyZeroId/";$assemblyZero.evidencePrefix=$assemblyZeroPrefix;$assemblyReportPath=Join-Path $lineageTarget $assemblyZeroPrefix 'quality/assembly.json';$assemblyReport=Get-Content -Raw -LiteralPath $assemblyReportPath|ConvertFrom-Json -AsHashtable -Depth 100;$assemblyReport.status='fail';Write-Json $assemblyReportPath $assemblyReport;$assemblyZero.reportSha256=Hash $assemblyReportPath;Write-Json (Join-Path $lineageTarget $assemblyZeroRelative) $assemblyZero
$assemblyModule=Join-Path $package 'modules/ifx-assembly-evidence';$assemblyConfig=[ordered]@{enabledClaims=@('IFX.C5.ASSEMBLY_QUALITY');policySha256=Hash (Join-Path $assemblyModule 'policy.json');evidenceLockPath=$assemblyZeroRelative;evidenceLockSha256=Hash (Join-Path $lineageTarget $assemblyZeroRelative)}
$assemblyInput=New-Input 'post' $lineageTarget $assemblyConfig;$assemblyInput.relativeRoots=@('src','tests','tools','artifacts');$assemblyResult=Invoke-CapturedAdapter 'ifx-assembly-evidence/Z' 'ifx-assembly-evidence' (Join-Path $assemblyModule 'adapter.ps1') $lineageTarget $assemblyInput
Assert ($assemblyResult.status-ceq'fail'-and$assemblyResult.exitCategory-ceq'findings-blocking'-and@($assemblyResult.findings|Where-Object{$_.subject-ceq'controlledAssemblyReport'-and$_.evidenceKind-ceq'assembly-report'}).Count-eq1) 'Assembly checklist zero fixture failed.'

$frontendId=[Guid]::NewGuid().ToString('N');$frontendRelative="artifacts/guards/p10-ifx-c5d/frontend-runs/$frontendId/evidence-lock.json";Copy-LineageRun $seedFrontendRelative $frontendRelative
$frontendLock=Get-Content -Raw -LiteralPath (Join-Path $lineageTarget $frontendRelative)|ConvertFrom-Json -Depth 100;$oldFrontendPrefix=[string]$frontendLock.evidencePrefix;$frontendPrefix="artifacts/guards/p10-ifx-c5d/frontend-runs/$frontendId/";$frontendLock.evidencePrefix=$frontendPrefix;Rebase-LockFiles $frontendLock $oldFrontendPrefix $frontendPrefix;$frontendLock.startedAt=$now.AddMinutes(-5).ToString('o');$frontendLock.completedAt=$now.AddMinutes(-4).ToString('o');$frontendLog=Join-Path $lineageTarget $frontendPrefix 'frontend-run.log';$frontendText=[IO.File]::ReadAllText($frontendLog).Replace('built in','compiled after');Write-Utf8 $frontendLog $frontendText;@($frontendLock.files|Where-Object path -CEQ ($frontendPrefix+'frontend-run.log'))[0].sha256=Hash $frontendLog;Write-Json (Join-Path $lineageTarget $frontendRelative) $frontendLock
$frontendModule=Join-Path $package 'modules/ifx-frontend-evidence';$frontendConfig=[ordered]@{enabledClaims=@('IFX.C5.FRONTEND_QUALITY');policySha256=Hash (Join-Path $frontendModule 'policy.json');evidenceLockPath=$frontendRelative;evidenceLockSha256=Hash (Join-Path $lineageTarget $frontendRelative)}
$frontendInput=New-Input 'post' $lineageTarget $frontendConfig;$frontendInput.relativeRoots=@('src','artifacts');$frontendResult=Invoke-CapturedAdapter 'ifx-frontend-evidence/Z' 'ifx-frontend-evidence' (Join-Path $frontendModule 'adapter.ps1') $lineageTarget $frontendInput
Assert ($frontendResult.status-ceq'fail'-and$frontendResult.exitCategory-ceq'findings-blocking'-and@($frontendResult.findings|Where-Object{$_.subject-ceq'nonVacuousTestsAndBuild'-and$_.evidenceKind-ceq'frontend-run-log'}).Count-eq1) 'Frontend checklist zero fixture failed.'

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
Assert ($lines.Count -eq 25) "Expected twenty-five supplemental captures, found $($lines.Count)."
Write-Output "IFX C6c4 supplemental fixtures passed twenty-five Provider, raw-graph, Injection, Source Policy, History, G04/G05, locked-lineage and Architecture cases: $capture"
