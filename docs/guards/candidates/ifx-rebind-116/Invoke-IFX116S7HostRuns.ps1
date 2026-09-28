# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) step S7 successor of
# docs/guards/candidates/ifx-rebind-115/Invoke-IFX115R5HostRuns.ps1 for V4 Guards 1.1.6 +
# ifx-profile-candidate 0.4.4. Derived by exact literal substitution; the accepted script stays unchanged.
# Runs direct Pre on the clean and deliberately violating Git-backed Targets through the installed,
# receipted 1.1.6 + 0.4.4 Host, cross-checks every result with the Host run and evidence queries,
# re-inventories the protected roots and writes the S7 decision. The installed Web UI record is
# deferred to the P10.GATE successor (Plan section 5).
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $EvidenceOutputRoot,
    [Parameter(Mandatory)][string] $DecisionPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Fail([string] $Message) { throw $Message }
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function TextHash([string] $Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($Text))).ToLowerInvariant() }
function Read-Json([string] $Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100 }
function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
function Get-RootInventoryDigest([string] $Root) {
    # Same ordering and line format as the preparation script's Get-RootInventory.
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | ForEach-Object {
        [ordered]@{ path = [IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'); size = [long]$_.Length; sha256 = (Hash $_.FullName) }
    })
    $lines = @($files | Sort-Object { [string]$_.path } | ForEach-Object { "$($_.path)|$($_.size)|$($_.sha256)" })
    TextHash (($lines -join "`n") + "`n")
}
function Invoke-Host([string] $Name, [string[]] $Arguments) {
    $log = Join-Path $logRoot $Name; [void][IO.Directory]::CreateDirectory($log)
    $info = [Diagnostics.ProcessStartInfo]::new('dotnet'); $info.UseShellExecute = $false; $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    [void]$info.ArgumentList.Add($hostDll); foreach ($a in $Arguments) { [void]$info.ArgumentList.Add($a) }
    $p = [Diagnostics.Process]::Start($info); $out = $p.StandardOutput.ReadToEndAsync(); $err = $p.StandardError.ReadToEndAsync(); $p.WaitForExit()
    $stdout = $out.GetAwaiter().GetResult(); $stderr = $err.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $log 'stdout.txt'), $stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $log 'stderr.txt'), $stderr, [Text.UTF8Encoding]::new($false))
    $doc = $null; $channel = $null
    foreach ($candidate in @(@('stdout', $stdout), @('stderr', $stderr))) {
        if ([string]::IsNullOrWhiteSpace($candidate[1])) { continue }
        try { $doc = $candidate[1] | ConvertFrom-Json -AsHashtable -Depth 100; $channel = $candidate[0]; break } catch {}
    }
    [ordered]@{ exitCode = $p.ExitCode; channel = $channel; result = $doc; stdoutSha256 = TextHash $stdout; stderrSha256 = TextHash $stderr }
}

$evidenceOutput = [IO.Path]::GetFullPath($EvidenceOutputRoot)
$decisionFull = [IO.Path]::GetFullPath($DecisionPath)
if ([IO.File]::Exists($decisionFull)) { Fail "Decision already exists: $decisionFull" }
$prep = Read-Json (Join-Path $evidenceOutput 'preparation-summary.json')
if ($prep.status -cne 'pass') { Fail 'S7 preparation did not pass.' }
$install = [string]$prep.roots.install; $state = [string]$prep.roots.state; $evidence = [string]$prep.roots.evidence
$clean = [string]$prep.roots.cleanTarget; $violating = [string]$prep.roots.violatingTarget
$hostDll = Join-Path $install 'host/v4-guards.dll'; $package = Join-Path $install 'package'
$logRoot = Join-Path $evidenceOutput 'host-runs'
if ([IO.Directory]::Exists($logRoot)) { Fail 'Host-run evidence already exists.' }

$profile = Read-Json (Join-Path $package 'profiles/catalog/ifx_profile/profile.json')
$profileSha = Hash (Join-Path $package 'profiles/catalog/ifx_profile/profile.json')
$version = Invoke-Host 'version' @('version')
if ($version.exitCode -ne 0 -or $version.result.version -cne '1.1.6') { Fail 'Installed Host version is not 1.1.6.' }

$cases = [ordered]@{}
foreach ($case in @(@{ id = 'clean'; root = $clean; exit = 0 }, @{ id = 'violating'; root = $violating; exit = 16 })) {
    $run = Invoke-Host "stage-$($case.id)" @('stage','run','--stage','pre','--package-root',$package,'--target-root',$case.root,'--state-root',$state,'--evidence-root',$evidence,'--profile','ifx_profile')
    if ($run.exitCode -ne $case.exit -or $null -eq $run.result) { Fail "Host $($case.id) Pre returned exit $($run.exitCode)." }
    $project = Invoke-Host "project-$($case.id)" @('query','project','--package-root',$package,'--target-root',$case.root,'--state-root',$state,'--evidence-root',$evidence)
    if ($project.exitCode -ne 0) { Fail "Project query failed: $($case.id)" }
    $projectId = [string]$project.result['project']['projectId']
    if ($projectId -cnotmatch '^[a-f0-9]{32}$' -or -not [bool]$project.result['project']['bound']) { Fail "Project ID unavailable or unbound: $($case.id)" }
    $runId = [string]$run.result.runId
    $runs = Invoke-Host "runs-$($case.id)" @('query','runs','--package-root',$package,'--state-root',$state,'--evidence-root',$evidence,'--project',$projectId)
    $ev = Invoke-Host "evidence-$($case.id)" @('query','evidence','--package-root',$package,'--state-root',$state,'--evidence-root',$evidence,'--project',$projectId,'--run',$runId)
    if ($runs.exitCode -ne 0 -or $ev.exitCode -ne 0) { Fail "Host queries failed: $($case.id)" }
    $listed = @($runs.result['runs'] | Where-Object { [string]$_['runId'] -ceq $runId })
    if ($listed.Count -ne 1) { Fail "Run is not listed exactly once by query runs: $($case.id)" }
    $r = $run.result
    $row = [ordered]@{
        targetRoot = $case.root; projectId = $projectId; runId = $runId; hostExitCode = $run.exitCode; resultChannel = $run.channel
        status = [string]$r.status; exitCategory = [string]$r.exitCategory
        moduleCount = @($r.moduleResults).Count; passedModuleCount = @($r.moduleResults | Where-Object { $_.status -ceq 'pass' }).Count
        failedModules = @($r.moduleResults | Where-Object { $_.status -cne 'pass' } | ForEach-Object { [string]$_.moduleId })
        findings = @($r.findings); coverageClaimCount = @($r.coverage).Count
        allCoverageNonVacuous = (@($r.coverage | Where-Object { [int]$_.matched -lt [int]$_.minimum -or [int]$_.matched -lt 1 }).Count -eq 0)
        profileSha256 = [string]$r.profile.sha256; packageHash = [string]$r.authorityHashes.package
        stageResultSha256 = $run.stdoutSha256
        query = [ordered]@{
            listedStatus = [string]$listed[0]['status']; listedExitCategory = [string]$listed[0]['exitCategory']
            listedFindingCount = [int]$listed[0]['findingCount']; listedCoverageCount = [int]$listed[0]['coverageCount']
            listedResultSha256 = [string]$listed[0]['resultSha256']; evidenceResultSha256 = [string]$ev.result['resultSha256']
            evidenceStageStatus = [string]$ev.result['stageResult']['status']; evidenceFindingCount = @($ev.result['stageResult']['findings']).Count
            evidenceCoverageCount = @($ev.result['stageResult']['coverage']).Count
            runsSha256 = $runs.stdoutSha256; evidenceSha256 = $ev.stdoutSha256
        }
    }
    $cases[$case.id] = $row
}

$c = $cases['clean']; $v = $cases['violating']
$expectedFinding = @($v.findings | Where-Object { $_.ruleId -ceq 'IMPORT-DIRECTION' -and $_.detectorId -ceq 'ifx-source-policy' -and $_.severity -ceq 'blocking' -and ([string]$_.subject).StartsWith('src/Modules/CRM/IFX.Modules.CRM.Domain/I1S7Fault.cs:1:') })
$checks = [ordered]@{
    cleanPass = ($c.status -ceq 'pass' -and $c.exitCategory -ceq 'success' -and $c.moduleCount -eq 10 -and $c.passedModuleCount -eq 10 -and @($c.findings).Count -eq 0)
    cleanNonVacuous = ($c.coverageClaimCount -gt 0 -and $c.allCoverageNonVacuous)
    violatingBlocks = ($v.status -ceq 'fail' -and $v.exitCategory -ceq 'findings-blocking' -and $v.moduleCount -eq 10 -and (($v.failedModules) -join '|') -ceq 'ifx-source-policy')
    deliberateFinding = ($expectedFinding.Count -eq 1 -and @($v.findings).Count -eq 1)
    violatingNonVacuous = ($v.coverageClaimCount -eq $c.coverageClaimCount -and $v.allCoverageNonVacuous)
    profileIdentity = ($c.profileSha256 -ceq $profileSha -and $v.profileSha256 -ceq $profileSha -and $profile.version -ceq '0.4.4')
    hostQueriesAgree = (@($c, $v | Where-Object {
        $_.query.listedStatus -cne $_.status -or $_.query.listedExitCategory -cne $_.exitCategory -or
        $_.query.listedFindingCount -ne @($_.findings).Count -or $_.query.listedCoverageCount -ne $_.coverageClaimCount -or
        $_.query.listedResultSha256 -cne $_.query.evidenceResultSha256 -or $_.query.evidenceStageStatus -cne $_.status -or
        $_.query.evidenceFindingCount -ne @($_.findings).Count -or $_.query.evidenceCoverageCount -ne $_.coverageClaimCount }).Count -eq 0)
}

# Protected roots and Git facts after the runs.
$pre = Read-Json (Join-Path $evidenceOutput 'pre-inventories.json')
$post = [ordered]@{
    baseInstallation = Get-RootInventoryDigest ([string]$pre.roots.baseInstallation.root)
    bundle = Get-RootInventoryDigest ([string]$pre.roots.bundle.root)
    cleanTarget = Get-RootInventoryDigest $clean
    violatingTarget = Get-RootInventoryDigest $violating
}
$preDigests = [ordered]@{}
foreach ($name in @('baseInstallation','bundle','cleanTarget','violatingTarget')) { $preDigests[$name] = [string]$pre.roots[$name].inventorySha256 }
$checks.protectedRootsUnchanged = (@($post.Keys | Where-Object { $post[$_] -cne $preDigests[$_] }).Count -eq 0)
$cleanStatus = @(& git -C $clean status --porcelain=v1 --untracked-files=all); $violatingStatus = @(& git -C $violating status --porcelain=v1 --untracked-files=all)
$checks.gitFactsUnchanged = ($cleanStatus.Count -eq 0 -and $violatingStatus.Count -eq 1 -and $violatingStatus[0] -ceq '?? src/Modules/CRM/IFX.Modules.CRM.Domain/I1S7Fault.cs' -and
    (& git -C $clean rev-parse HEAD).Trim() -ceq $prep.targetCommit -and (& git -C $violating rev-parse HEAD).Trim() -ceq $prep.targetCommit)

$status = if (@($checks.Values | Where-Object { -not $_ }).Count -eq 0) { 'pass' } else { 'fail' }
Write-Json (Join-Path $evidenceOutput 'host-verification.json') ([ordered]@{
    formatVersion = 1; status = $status; verification = 'installed-host-and-host-query-match'
    installedRuntime = [ordered]@{ installRoot = $install; packageHash = $c.packageHash; profileId = 'ifx_profile'; profileVersion = [string]$profile.version; profileSha256 = $profileSha }
    cases = $cases; checks = $checks; preInventoryDigests = $preDigests; postInventoryDigests = $post
    installedWebUi = 'deferred-to-p10-gate-successor'
})
Write-Json $decisionFull ([ordered]@{
    formatVersion = 1; status = $status
    decision = $(if ($status -ceq 'pass') { 'i1-s7-composition-accepted' } else { 'i1-s7-composition-stopped' })
    targetCommit = $prep.targetCommit
    composition = [ordered]@{ installRoot = $install; receipt = $prep.compositionReceipt; packageHash = $c.packageHash; bundleManifestSha256 = $prep.identities.bundleManifest; reviewRecordSha256 = $prep.identities.reviewRecord }
    preparationSummarySha256 = Hash (Join-Path $evidenceOutput 'preparation-summary.json')
    hostVerificationSha256 = Hash (Join-Path $evidenceOutput 'host-verification.json')
    checks = $checks
    boundary = [ordered]@{ installedWebUi = 'deferred-to-p10-gate-successor'; p10GatePassed = $false; activated = $false; cutover = $false }
})
Write-Output "I1 S7 $status`: $decisionFull"
if ($status -cne 'pass') { exit 1 }
