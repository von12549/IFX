Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$rule='PLAN05-SECURITY-BOUNDARY';$claim='IFX.C4.PLAN05_SECURITY';$detector='ifx-plan05-security'
$findings=[Collections.Generic.List[object]]::new();$matched=0
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Hash-Text([string]$Value){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Value))).ToLowerInvariant()}
function Emit([string]$Status,[string]$Category,[string]$Message=''){
    $result=[ordered]@{formatVersion=1;status=$Status;exitCategory=$Category;findings=@($findings.ToArray());coverage=@([ordered]@{claimId=$claim;matched=[int]$matched;minimum=1})}
    if($Message){$result.message=$Message};[Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 30 -Compress))
}
function Stop-Adapter([string]$Category,[string]$Message){Emit 'error' $Category $Message;exit 0}
function Is-Under([string]$Path,[string]$Root){$relative=[IO.Path]::GetRelativePath($Root,$Path);$relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)",[StringComparison]::Ordinal)}
function Assert-NoLink([string]$Path,[string]$Root){
    $cursor=[IO.Path]::GetFullPath($Path)
    while(Is-Under $cursor $Root){
        if([IO.File]::Exists($cursor) -or [IO.Directory]::Exists($cursor)){$item=Get-Item -LiteralPath $cursor -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget){Stop-Adapter 'unsafe-path' "Linked authority: $Path"}}
        if($cursor -ceq $Root){break};$parent=[IO.Path]::GetDirectoryName($cursor);if(-not $parent -or $parent -ceq $cursor){break};$cursor=$parent
    }
}
function Record([string]$Id,[bool]$Pass){$script:matched++;if(-not $Pass){$findings.Add([ordered]@{ruleId=$rule;subject=$Id;evidenceKind='security-source';detectorId=$detector;severity='blocking'})}}
function Match([string]$Text,[string]$Pattern){[Regex]::IsMatch($Text,$Pattern,[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1))}
function Pure-Contract([string]$Text){-not (Match ($Text.Replace('Sdk="Microsoft.NET.Sdk"','')) 'Microsoft\.|Amazon\.|Auth0\.|System\.Text\.Json|ClaimsPrincipal|HttpContext|IQueryable|DbContext|IServiceCollection|PackageReference|ProjectReference|\.Infrastructure\.')}
function Neutral-Runtime([string]$Text){-not (Match $Text 'IFX\.Modules\.|IHttpContextAccessor|HttpContext\.Current|EntityFrameworkCore|DbContext')}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input is required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Stage input is malformed.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'src'){Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'}
$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot);if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.'};Assert-NoLink $target $target
$policyFile=Join-Path $PSScriptRoot 'policy.json'
if(-not [IO.File]::Exists($policyFile) -or (Hash $policyFile) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Plan05 policy hash drift.'}
try{$policy=Get-Content -LiteralPath $policyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Plan05 policy is malformed.'}
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-plan05-security-c4s' -or @($policy.checkIds).Count -ne 13 -or @($policy.authorities).Count -ne 8){Stop-Adapter 'integrity-failure' 'Plan05 policy identity drift.'}
$locks=@($inputObject.config.authorityHashes);if($locks.Count -ne 8){Stop-Adapter 'invalid-input' 'Authority lock count drift.'}
$texts=@{}
for($i=0;$i -lt 8;$i++){
    $authority=$policy.authorities[$i];$lock=$locks[$i];$relative=[string]$authority.path
    if($authority.id -cne $lock.id -or [string]$lock.sha256 -cnotmatch '^[a-f0-9]{64}$' -or [IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)'){Stop-Adapter 'invalid-input' "Authority lock mismatch: $i"}
    $full=[IO.Path]::GetFullPath((Join-Path $target $relative));if(-not(Is-Under $full $target)){Stop-Adapter 'unsafe-path' "Authority escapes TargetRoot: $relative"};Assert-NoLink $full $target
    if(-not [IO.File]::Exists($full)){Stop-Adapter 'prerequisite-missing' "Missing authority: $relative"}
    if((Hash $full) -cne [string]$lock.sha256){Stop-Adapter 'integrity-failure' "Stale authority: $relative"}
    $texts[[string]$authority.id]=[IO.File]::ReadAllText($full)
}
$sourceRoot=[IO.Path]::GetFullPath((Join-Path $target ([string]$policy.sourceRoot)))
if(-not(Is-Under $sourceRoot $target) -or -not [IO.Directory]::Exists($sourceRoot)){Stop-Adapter 'prerequisite-missing' 'Source root is missing.'};Assert-NoLink $sourceRoot $target
$sources=@(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse -Force|Where-Object{$_.Extension -in '.cs','.csproj' -and $_.FullName -notmatch '[\\/](bin|obj)[\\/]'}|Sort-Object FullName)
if($sources.Count -eq 0){$findings.Add([ordered]@{ruleId=$rule;subject='zero-subject';evidenceKind='coverage';detectorId=$detector;severity='blocking'});Emit 'fail' 'findings-blocking';exit 0}
foreach($source in $sources){Assert-NoLink $source.FullName $target}
$lines=@($sources|ForEach-Object{"$([IO.Path]::GetRelativePath($target,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"
if((Hash-Text $lines) -cne [string]$inputObject.config.sourceTreeSha256){Stop-Adapter 'integrity-failure' 'Source tree lock drift.'}
$selfTests=@(
    @{kind='contract';source='public record Request(string Id);';expected=$true},@{kind='contract';source='public record Request(Microsoft.AspNetCore.Http.HttpContext Context);';expected=$false},
    @{kind='contract';source='using Amazon.CognitoIdentityProvider;';expected=$false},@{kind='contract';source='using IFX.Platform.Authorization.Infrastructure.Opa;';expected=$false},
    @{kind='contract';source='public record Policy(System.Text.Json.JsonElement Value);';expected=$false},@{kind='contract';source='<PackageReference Include="SomeSdk" />';expected=$false},
    @{kind='runtime';source='using IFX.Platform.Authorization.Contracts.V1;';expected=$true},@{kind='runtime';source='using IFX.Modules.IAM.Infrastructure.Persistence;';expected=$false},
    @{kind='runtime';source='public class Runtime(IHttpContextAccessor context);';expected=$false},@{kind='runtime';source='public class Runtime(DbContext db);';expected=$false}
)
$selfOk=@($selfTests|Where-Object{$actual=$(if($_.kind -eq 'contract'){Pure-Contract $_.source}else{Neutral-Runtime $_.source});$actual -ne $_.expected}).Count -eq 0
$checks=[ordered]@{positiveAndNegativeDetectors=$selfOk}
foreach($capability in @('Authentication','Authorization')){
    $contractPrefix="src/Platform/$capability/IFX.Platform.$capability.Contracts/";$runtimePrefix="src/Platform/$capability/IFX.Platform.$capability.Runtime/"
    $contracts=@($sources|Where-Object{[IO.Path]::GetRelativePath($target,$_.FullName).Replace('\','/').StartsWith($contractPrefix,[StringComparison]::Ordinal)})
    $runtimes=@($sources|Where-Object{[IO.Path]::GetRelativePath($target,$_.FullName).Replace('\','/').StartsWith($runtimePrefix,[StringComparison]::Ordinal)})
    $checks["${capability}ContractsArePure"]=$contracts.Count -gt 0 -and @($contracts|Where-Object{-not(Pure-Contract ([IO.File]::ReadAllText($_.FullName)))}).Count -eq 0
    $checks["${capability}RuntimeHasNoBusinessOrHttpDependency"]=$runtimes.Count -gt 0 -and @($runtimes|Where-Object{-not(Neutral-Runtime ([IO.File]::ReadAllText($_.FullName)))}).Count -eq 0
}
$registration=$texts.identityRegistration;$facts=$texts.verifiedFacts;$actor=$texts.httpIdentity;$permission=$texts.permission;$resource=$texts.resourceAdapter;$program=$texts.program;$handler=$texts.handler
$checks.verifiedIdentityIsTheProductionSource=(Match $registration 'AddScoped<IExecutionIdentityFacts>.*GetRequiredService<VerifiedIdentityFacts>') -and -not(Match $registration 'AddScoped<IExecutionIdentityFacts>.*GetRequiredService<HttpIdentityFacts>')
$checks.membershipFactsAreCurrentAndTenantBound=(Match $facts 'IsAuthenticated.*Refresh\(') -and (Match $facts 'AsNoTracking\(') -and (Match $facts 't.Id == tenantId && t.IsActive') -and (Match $facts 'r.TenantId == tenant') -and -not(Match $facts 'IMemoryCache|IDistributedCache|FindAll\(')
$checks.workerActorRequiresTrustedUserIdentity=(Match $actor 'ContextProvenance.Trusted') -and (Match $actor 'ActorKind.User') -and (Match $actor 'Guid.TryParse')
$checks.internalAuthorizationRequiresExplicitContext=(Match $permission '_execution.HasCurrent') -and (Match $permission 'ActorKind.User') -and (Match $permission '_currentUser.TenantId == _execution.Current.TenantId') -and (Match $resource 'contextValidator.Validate') -and (Match $resource 'ContractTenantValidation.MatchWhenTenantScoped') -and (Match $resource 'contract_context_invalid')
$checks.httpUsesIamDecision=(Match $handler 'IPermissionChecker') -and (Match $handler 'HasPermissionAsync') -and -not(Match $handler 'HasClaim|GlobalRoles')
$checks.hostUsesIamComposition=(Match $program 'AddIamModule') -and -not(Match $program 'AddOpaClient|AddAuthModule|IFX.Modules.IAM.(Application|Infrastructure|Presentation)')
$retiredPresent=@($policy.retiredPaths|Where-Object{[IO.File]::Exists((Join-Path $target $_))})
$checks.retiredTransitionTypesAreAbsent=$retiredPresent.Count -eq 0
try{$compat=$texts.compatibility|ConvertFrom-Json -AsHashtable -Depth 30}catch{Stop-Adapter 'integrity-failure' 'Compatibility registry malformed.'}
$legacyFindings=[Collections.Generic.List[string]]::new()
foreach($file in $sources){$relative=[IO.Path]::GetRelativePath($target,$file.FullName).Replace('\','/');foreach($line in [IO.File]::ReadAllLines($file.FullName)){if(Match $line 'IFX\.Modules\.Auth\b'){if(@($compat.legacyTypeReferences|Where-Object{$_.path -ceq $relative -and $line.Contains([string]$_.value)}).Count -ne 1){$legacyFindings.Add($relative)}}}}
$checks.legacyTypeNamesHaveExactCompatibilityEntries=$legacyFindings.Count -eq 0 -and @($compat.legacyTypeReferences).Count -eq 1
if((@($checks.Keys)-join '|') -cne (@($policy.checkIds)-join '|')){Stop-Adapter 'integrity-failure' 'Plan05 check-ID mapping drift.'}
foreach($id in $policy.checkIds){Record $id ([bool]$checks[$id])}
if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
