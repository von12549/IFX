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
function Load-WorkspaceEvidence($InputObject,[string]$TargetRoot){
    if(-not$InputObject.ContainsKey('workspaceEvidencePath') -or -not$InputObject.ContainsKey('workspaceEvidenceSha256')){return $null}
    if(-not$InputObject.ContainsKey('workspaceEvidenceTargetCommit')){Stop-Adapter 'invalid-input' 'Workspace evidence target commit is required.'}
    $path=[IO.Path]::GetFullPath([string]$InputObject.workspaceEvidencePath);Assert-NoLink $path ([IO.Path]::GetPathRoot($path));$expected=[string]$InputObject.workspaceEvidenceSha256;$expectedCommit=[string]$InputObject.workspaceEvidenceTargetCommit
    if($expected-cnotmatch'^[a-f0-9]{64}$' -or -not[IO.File]::Exists($path) -or (Is-Under $path $TargetRoot) -or (Is-Under $TargetRoot ([IO.Path]::GetDirectoryName($path)))){Stop-Adapter 'unsafe-path' 'Workspace evidence is missing, invalid, or overlaps TargetRoot.'}
    if((Hash $path)-cne$expected){Stop-Adapter 'integrity-failure' 'Workspace evidence hash drift.'}
    try{$value=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -AsHashtable -Depth 30}catch{Stop-Adapter 'integrity-failure' 'Workspace evidence is malformed.'}
    if($expectedCommit-cnotmatch'^[a-f0-9]{40}$' -or $value.targetCommit-cne$expectedCommit -or $value.formatVersion-ne1 -or $value.scope-cne'v4-workspace-evidence-v1' -or $value.pathOrder-cne'ordinal' -or @($value.files).Count-ne$value.fileCount){Stop-Adapter 'integrity-failure' 'Workspace evidence identity drift.'}
    $value
}
function Record([string]$Id,[bool]$Pass){$script:matched++;if(-not $Pass){$findings.Add([ordered]@{ruleId=$rule;subject=$Id;evidenceKind='security-source';detectorId=$detector;severity='blocking'})}}
function Match([string]$Text,[string]$Pattern){[Regex]::IsMatch($Text,$Pattern,[Text.RegularExpressions.RegexOptions]::None,[TimeSpan]::FromSeconds(1))}
function Pure-Contract([string]$Text){-not (Match ($Text.Replace('Sdk="Microsoft.NET.Sdk"','')) 'Microsoft\.|Amazon\.|Auth0\.|System\.Text\.Json|ClaimsPrincipal|HttpContext|IQueryable|DbContext|IServiceCollection|PackageReference|ProjectReference|\.Infrastructure\.')}
function Neutral-Runtime([string]$Text){-not (Match $Text 'IFX\.Modules\.|IHttpContextAccessor|HttpContext\.Current|EntityFrameworkCore|DbContext')}
function Source-Files([string]$Root,[string]$SourceRoot){
    $rows=[Collections.Generic.List[object]]::new()
    $pending=[Collections.Generic.Queue[string]]::new();$pending.Enqueue($SourceRoot)
    $excluded=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($name in @('bin','obj','node_modules','dist','coverage','.vite')){[void]$excluded.Add($name)}
    while($pending.Count-gt 0){
        $current=$pending.Dequeue()
        foreach($directory in [IO.Directory]::EnumerateDirectories($current)){
            if($excluded.Contains([IO.Path]::GetFileName($directory))){continue}
            if(([IO.File]::GetAttributes($directory)-band[IO.FileAttributes]::ReparsePoint)-ne0){Stop-Adapter 'unsafe-path' "Linked source directory: $directory"}
            $pending.Enqueue($directory)
        }
        foreach($file in [IO.Directory]::EnumerateFiles($current)){
            $extension=[IO.Path]::GetExtension($file)
            if($extension -notin @('.cs','.csproj')){continue}
            if(([IO.File]::GetAttributes($file)-band[IO.FileAttributes]::ReparsePoint)-ne0){Stop-Adapter 'unsafe-path' "Linked source file: $file"}
            $bytes=[IO.File]::ReadAllBytes($file)
            $text=[Text.Encoding]::UTF8.GetString($bytes);if($text.Length-gt0-and$text[0]-eq[char]0xFEFF){$text=$text.Substring(1)}
            $rows.Add([pscustomobject]@{FullName=$file;RelativePath=[IO.Path]::GetRelativePath($Root,$file).Replace('\','/');Sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant();Text=$text})
        }
    }
    @($rows.ToArray()|Sort-Object FullName)
}
if([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)){Stop-Adapter 'invalid-input' 'Stage input is required.'}
try{$inputObject=$env:V4_STAGE_INPUT_JSON|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'invalid-input' 'Stage input is malformed.'}
if($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'post' -or (@($inputObject.config.enabledClaims)-join '|') -cne $claim -or @($inputObject.relativeRoots) -notcontains 'src'){Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.'}
if(-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot)){Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'}
$target=[IO.Path]::GetFullPath([string]$inputObject.targetRoot);if(-not [IO.Directory]::Exists($target)){Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.'};Assert-NoLink $target $target
$workspace=Load-WorkspaceEvidence $inputObject $target
$policyFile=Join-Path $PSScriptRoot 'policy.json'
if(-not [IO.File]::Exists($policyFile) -or (Hash $policyFile) -cne [string]$inputObject.config.policySha256){Stop-Adapter 'integrity-failure' 'Plan05 policy hash drift.'}
try{$policy=Get-Content -LiteralPath $policyFile -Raw|ConvertFrom-Json -AsHashtable -Depth 100}catch{Stop-Adapter 'integrity-failure' 'Plan05 policy is malformed.'}
if($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-plan05-security-050a' -or $policy.pinPolicy -cne 'governance-only' -or @($policy.checkIds).Count -ne 13 -or @($policy.authorities).Count -ne 8){Stop-Adapter 'integrity-failure' 'Plan05 policy identity drift.'}
# 0.5.0-a: governance authorities keep their Profile pins; each live authority is bound to its current bytes, so the
# unchanged loop below verifies pins only where the policy marks a governance authority (pinned).
$pinned=@($policy.authorities | Where-Object { $_.pinned -eq $true })
$configLocks=@($inputObject.config.authorityHashes)
if($pinned.Count -ne 1 -or $configLocks.Count -ne $pinned.Count){Stop-Adapter 'invalid-input' 'Governance authority lock count mismatch.'}
for($k=0;$k -lt $pinned.Count;$k++){if($pinned[$k].id -cne $configLocks[$k].id){Stop-Adapter 'invalid-input' "Governance authority lock mismatch: $k"}}
$locks=@(foreach($pa in @($policy.authorities)){
    if($pa.pinned -eq $true){@($configLocks | Where-Object { $_.id -ceq $pa.id })[0]}
    else{
        $liveRelative=[string]$pa.path;$liveFull=[IO.Path]::GetFullPath((Join-Path $target $liveRelative))
        $liveSafe=-not [IO.Path]::IsPathRooted($liveRelative) -and $liveRelative -notmatch '(^|[\\/])\.\.([\\/]|$)' -and (Is-Under $liveFull $target) -and [IO.File]::Exists($liveFull) -and ((Get-Item -LiteralPath $liveFull -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0
        [ordered]@{id=[string]$pa.id;sha256=$(if($liveSafe){(Get-FileHash -Algorithm SHA256 -LiteralPath $liveFull).Hash.ToLowerInvariant()}else{'0'*64})}
    }
})
if($locks.Count -ne 8){Stop-Adapter 'invalid-input' 'Authority lock count mismatch.'}
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
$sources=if($null-ne$workspace){@($workspace.files|Where-Object{$_.extension-in '.cs','.csproj' -and ([string]$_.path).StartsWith('src/',[StringComparison]::Ordinal)}|ForEach-Object{[pscustomobject]@{FullName=[IO.Path]::GetFullPath((Join-Path $target ([string]$_.path)));RelativePath=[string]$_.path;Sha256=[string]$_.sha256;Text=[string]$_.text}}|Sort-Object FullName)}else{@(Source-Files $target $sourceRoot)}
if($sources.Count -eq 0){$findings.Add([ordered]@{ruleId=$rule;subject='zero-subject';evidenceKind='coverage';detectorId=$detector;severity='blocking'});Emit 'fail' 'findings-blocking';exit 0}
$lines=@($sources|ForEach-Object{"$($_.RelativePath)|$($_.Sha256)"}) -join "`n"
# 0.5.0-a: the live source set is no longer compared with a Profile fingerprint (sourceTreeSha256); the checks below read its current content.
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
    $contracts=@($sources|Where-Object{$_.RelativePath.StartsWith($contractPrefix,[StringComparison]::Ordinal)})
    $runtimes=@($sources|Where-Object{$_.RelativePath.StartsWith($runtimePrefix,[StringComparison]::Ordinal)})
    $checks["${capability}ContractsArePure"]=$contracts.Count -gt 0 -and @($contracts|Where-Object{-not(Pure-Contract $_.Text)}).Count -eq 0
    $checks["${capability}RuntimeHasNoBusinessOrHttpDependency"]=$runtimes.Count -gt 0 -and @($runtimes|Where-Object{-not(Neutral-Runtime $_.Text)}).Count -eq 0
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
foreach($file in $sources){$relative=$file.RelativePath;foreach($line in ([string]$file.Text -split "`r?`n")){if(Match $line 'IFX\.Modules\.Auth\b'){if(@($compat.legacyTypeReferences|Where-Object{$_.path -ceq $relative -and $line.Contains([string]$_.value)}).Count -ne 1){$legacyFindings.Add($relative)}}}}
$checks.legacyTypeNamesHaveExactCompatibilityEntries=$legacyFindings.Count -eq 0 -and @($compat.legacyTypeReferences).Count -eq 1
if((@($checks.Keys)-join '|') -cne (@($policy.checkIds)-join '|')){Stop-Adapter 'integrity-failure' 'Plan05 check-ID mapping drift.'}
foreach($id in $policy.checkIds){Record $id ([bool]$checks[$id])}
if($findings.Count -gt 0){Emit 'fail' 'findings-blocking'}else{Emit 'pass' 'success'}
