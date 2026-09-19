[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repo = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$fixtureParent = [IO.Path]::GetFullPath((Join-Path $repo 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $fixtureParent "v3-fixture-$([Guid]::NewGuid().ToString('N'))"))
$profile = Join-Path $fixture 'profile'
$runner = Join-Path $package 'scripts/Invoke-V3.ps1'
$generationRoot = [IO.Path]::GetFullPath((Join-Path $fixtureParent "v3-generation-$([Guid]::NewGuid().ToString('N'))"))
$output = Join-Path $generationRoot 'v3/gates/stage'
$newGeneratedRoot = Join-Path $output 'Sample.Guards.StageGate.Tests'
if (-not $fixture.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }

$protectionFile = Join-Path $fixtureParent "v3-protection-$([Guid]::NewGuid().ToString('N')).json"

function Assert-Run {
    param([int] $Expected, [string[]] $Arguments, [string] $Label, [string] $ExpectText)
    $result = @(& pwsh -NoProfile -File $runner -ProfileDirectory $profile -TargetRoot $fixture -GenerationRoot $generationRoot -OutputDirectory $output -LockMode Update -LockRoot (Join-Path $fixture 'locks') @Arguments 2>&1)
    if ($LASTEXITCODE -ne $Expected) { throw "$Label expected exit $Expected, got ${LASTEXITCODE}: $($result -join ' | ')" }
    if ($ExpectText -and -not (($result -join ' ') -replace '\s+', ' ').Contains($ExpectText, [StringComparison]::Ordinal)) { throw "$Label did not report '$ExpectText': $($result -join ' | ')" }
}
function Invoke-FixtureGit {
    & git -C $fixture @args
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed in the fixture." }
}

$passed = $false
try {
    [void] [IO.Directory]::CreateDirectory((Join-Path $fixture 'src/App'))
    [void] [IO.Directory]::CreateDirectory((Join-Path $fixture 'docs/plans'))
    [void] [IO.Directory]::CreateDirectory($generationRoot)
    Copy-Item -LiteralPath (Join-Path $package 'examples/minimal') -Destination $profile -Recurse
    [IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), "docs/guards/V3/generated/`nartifacts/`n")
    $projectFile = Join-Path $fixture 'src/App/App.csproj'
    $good = '<Project><ItemGroup><ProjectReference Include="../Core/Core.csproj" /></ItemGroup></Project>'
    $bad = '<Project><ItemGroup><ProjectReference Include="../Legacy/Legacy.csproj" /></ItemGroup></Project>'
    [void] [IO.Directory]::CreateDirectory((Join-Path $fixture 'src/App/Guarded/authorizations'))
    [IO.File]::WriteAllText((Join-Path $fixture 'src/App/Guarded/keep.txt'), 'protected')
    [IO.File]::WriteAllText((Join-Path $fixture 'src/App/Guarded/authorizations/sample.json'), '{}')
    [IO.File]::WriteAllText((Join-Path $fixture 'src/App/Guarded/authorizations/other.json'), '{}')
    [IO.File]::WriteAllText($projectFile, $good)
    Assert-Run 0 @('-Mode', 'Validate') 'validate synthetic profile'
    $sampleRule = Join-Path $profile 'rules/ARCH.SAMPLE.json'
    $originalRule = [IO.File]::ReadAllText($sampleRule)
    [IO.File]::WriteAllText($sampleRule, $originalRule.Replace('forbidden-project-reference', 'unsupported-detector'))
    Assert-Run 1 @('-Mode', 'Validate') 'unsupported detector fails validation'
    [IO.File]::WriteAllText($sampleRule, $originalRule)
    [IO.File]::WriteAllText((Join-Path $profile 'rules/ARCH.UNCOVERED.json'), '{"formatVersion":1,"id":"ARCH.UNCOVERED","title":"Future semantic detector","kind":"none","enforcement":"advisory","coverage":"none","authority":"Synthetic example","appliesTo":["src/App/**"]}')
    Assert-Run 0 @('-Mode', 'Validate') 'advisory uncovered rule remains explicit'
    Assert-Run 0 @('-Mode', 'Generate') 'generate .NET project'
    Assert-Run 0 @('-Mode', 'Check') 'generated project check'
    $usesProjectLayout = [IO.Directory]::Exists($newGeneratedRoot)
    $generatedRoot = if ($usesProjectLayout) { $newGeneratedRoot } else { $output }
    if ($usesProjectLayout) {
        foreach ($directory in @('Self', 'Post', 'Diff', 'GeneratedInputs')) {
            if (-not [IO.Directory]::Exists((Join-Path $generatedRoot $directory))) { throw "Generated Stage Gate directory is missing: $directory" }
        }
        $profileIdentity = Join-Path $profile 'profile.json'
        $originalIdentity = [IO.File]::ReadAllText($profileIdentity)
        [IO.File]::WriteAllText($profileIdentity, $originalIdentity.Replace('"sample"', '"sample-a"'))
        Assert-Run 0 @('-Mode', 'Generate') 'hyphenated project ID maps to a .NET identifier'
        [IO.File]::WriteAllText($profileIdentity, $originalIdentity.Replace('"sample"', '"samplea"'))
        Assert-Run 1 @('-Mode', 'Generate') 'colliding project identifier fails closed' 'Stage Gate identifier collision'
        [IO.File]::WriteAllText($profileIdentity, $originalIdentity)
    }
    $generatedProject = Join-Path $generatedRoot $(if ($usesProjectLayout) { 'Sample.Guards.StageGate.Tests.csproj' } else { 'GuardV3.Tests.csproj' })
    [IO.File]::AppendAllText($generatedProject, "`n")
    Assert-Run 1 @('-Mode', 'Check') 'generated byte drift'
    Assert-Run 0 @('-Mode', 'Generate') 'regenerate after drift'
    $projectMap = Join-Path $profile 'project-map.json'
    $originalMap = [IO.File]::ReadAllText($projectMap)
    [IO.File]::WriteAllText($projectMap, $originalMap.Replace('sample-owner', 'changed-owner'))
    Assert-Run 1 @('-Mode', 'Check') 'project map snapshot drift'
    Assert-Run 0 @('-Mode', 'Generate') 'regenerate changed map snapshot'
    [IO.File]::WriteAllText($projectMap, $originalMap)
    Assert-Run 0 @('-Mode', 'Generate') 'regenerate after map drift'
    Remove-Item -LiteralPath (Join-Path $profile 'rules/ARCH.UNCOVERED.json') -Force
    Assert-Run 1 @('-Mode', 'Check') 'removed rule leaves stale snapshot'
    Assert-Run 0 @('-Mode', 'Generate') 'regenerate removes stale rule snapshot'
    Assert-Run 0 @('-Mode', 'Test') 'allowed project reference and detector fixtures'
    $ruleData = Get-Content -LiteralPath $sampleRule -Raw | ConvertFrom-Json -AsHashtable
    $ruleData.sourcePattern = 'src/Never/**/*.csproj'
    [IO.File]::WriteAllText($sampleRule,($ruleData | ConvertTo-Json -Depth 20))
    Assert-Run 0 @('-Mode', 'Generate') 'generate unmatched-source rule'
    Assert-Run 1 @('-Mode', 'Test') 'unmatched-source rule cannot pass'
    $ruleData.sourcePattern = 'src/**/*.csproj'
    $ruleData.negativeFixture.referenceInclude = '../Core/Core.csproj'
    [IO.File]::WriteAllText($sampleRule,($ruleData | ConvertTo-Json -Depth 20))
    Assert-Run 0 @('-Mode', 'Generate') 'generate ineffective negative fixture'
    Assert-Run 1 @('-Mode', 'Test') 'ineffective negative fixture cannot pass'
    [IO.File]::WriteAllText($sampleRule, $originalRule)
    Assert-Run 0 @('-Mode', 'Generate') 'restore effective rule'
    [IO.File]::WriteAllText($projectFile, $bad)
    Assert-Run 1 @('-Mode', 'Test') 'forbidden project reference'
    [IO.File]::WriteAllText($projectFile, $good)

    Assert-Run 0 @('-Mode', 'Pre', '-PlannedPaths', 'src/App/Program.cs') 'ordinary summary Pre'
    $hook = Join-Path $package 'hooks/Invoke-PlanHook.ps1'
    $hookOutput = if ((Get-Command $hook).Parameters.ContainsKey('GenerationRoot')) {
        @(& pwsh -NoProfile -File $hook -ProfileDirectory $profile -TargetRoot $fixture -GenerationRoot $generationRoot -OutputDirectory $output -PlannedPaths 'src/App/Program.cs' 2>&1)
    }
    else {
        @(& pwsh -NoProfile -File $hook -ProfileDirectory $profile -TargetRoot $fixture -OutputDirectory 'generated/hook' -PlannedPaths 'src/App/Program.cs' 2>&1)
    }
    if ($LASTEXITCODE -ne 0) { throw "Summary hook adapter failed: $($hookOutput -join ' | ')" }
    $preReport = Get-Content -LiteralPath (Join-Path $fixture 'artifacts/guards/v3-pre.json') -Raw | ConvertFrom-Json
    if ($preReport.status -ne 'advisory' -or $preReport.mode -ne 'summary' -or 'App' -notin $preReport.areas.id -or 'ARCH.SAMPLE' -notin $preReport.ruleIds) { throw 'Summary Pre report lost impact mapping.' }
    Assert-Run 1 @('-Mode', 'Pre', '-PlannedPaths', 'src/App/App.csproj') 'risk requires formal Plan'
    $riskReport = Get-Content -LiteralPath (Join-Path $fixture 'artifacts/guards/v3-pre.json') -Raw | ConvertFrom-Json
    if ('project-files' -notin $riskReport.risks.id -or 'App' -notin $riskReport.areas.id) { throw 'Blocked Pre report lost risk or area context.' }
    Assert-Run 1 @('-Mode', 'Pre', '-PlannedPaths', 'src/Unknown/File.cs') 'unmapped path blocks Pre'

    $plan = 'docs/plans/20260914-sample.plan.json'
    $planFile = Join-Path $fixture $plan
    $planData = [ordered]@{ formatVersion = 1; id = '20260914-sample'; title = 'Sample dependency'; goal = 'Change a dependency safely'; acceptanceCriteria = @('The reference remains allowed'); plannedPaths = @('src/App/App.csproj'); areaIds = @('App'); ruleIds = @('ARCH.SAMPLE'); validationCommands = @('sample-test'); decisionPaths = @() }
    [IO.File]::WriteAllText($planFile, ($planData | ConvertTo-Json -Depth 20))
    [IO.File]::WriteAllText((Join-Path $fixture 'docs/plans/20260914-sample.md'), '# Sample dependency')
    Assert-Run 1 @('-Mode', 'Pre', '-PlanPath', $plan) 'risk without decision'
    $decision = 'docs/plans/20260914-decision.json'
    [IO.File]::WriteAllText((Join-Path $fixture $decision), '{"formatVersion":1,"id":"sample-decision","owner":"sample","summary":"Sample dependency","affectedPaths":["src/App/App.csproj"],"rationale":"Synthetic test"}')
    $planData.decisionPaths = @($decision)
    [IO.File]::WriteAllText($planFile, ($planData | ConvertTo-Json -Depth 20))
    Assert-Run 0 @('-Mode', 'Pre', '-PlanPath', $plan) 'risk with decision'
    foreach ($field in @('areaIds', 'ruleIds', 'validationCommands')) {
        $saved = $planData[$field]
        $planData[$field] = @()
        [IO.File]::WriteAllText($planFile, ($planData | ConvertTo-Json -Depth 20))
        Assert-Run 1 @('-Mode', 'Pre', '-PlanPath', $plan) "missing $field blocks Pre"
        $planData[$field] = $saved
    }
    $planData.validationCommands = @('unknown-command')
    [IO.File]::WriteAllText($planFile, ($planData | ConvertTo-Json -Depth 20))
    Assert-Run 1 @('-Mode', 'Pre', '-PlanPath', $plan) 'unknown command blocks Pre'
    $planData.validationCommands = @('sample-test')
    [IO.File]::WriteAllText((Join-Path $fixture 'docs/plans/20260914-sample.md'), ' ')
    [IO.File]::WriteAllText($planFile, ($planData | ConvertTo-Json -Depth 20))
    Assert-Run 1 @('-Mode', 'Pre', '-PlanPath', $plan) 'empty Markdown companion blocks Pre'
    [IO.File]::WriteAllText((Join-Path $fixture 'docs/plans/20260914-sample.md'), '# Sample dependency')
    [IO.File]::WriteAllText($planFile, ($planData | ConvertTo-Json -Depth 20))
    Assert-Run 0 @('-Mode', 'Pre', '-PlanPath', $plan) 'restored formal Pre'

    Push-Location $fixture
    try {
        & git init -q
        & git config user.email guard-v3@example.invalid
        & git config user.name 'Guard V3 Fixture'
        & git config core.autocrlf false
        & git add .
        & git commit -qm baseline
        if ($LASTEXITCODE -ne 0) { throw 'Fixture commit failed.' }
    }
    finally { Pop-Location }
    [IO.File]::AppendAllText($projectFile, "`n<!-- planned -->")
    Assert-Run 0 @('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD') 'planned diff'
    [IO.File]::WriteAllText((Join-Path $fixture 'src/Unplanned.cs'), 'class Unplanned {}')
    Assert-Run 1 @('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD') 'out-of-plan diff'
    [IO.File]::Delete((Join-Path $fixture 'src/Unplanned.cs'))

    # Plan 06 P3.1/P3.2: committed ranges use the verified merge base, an empty changed set fails closed, and protected
    # paths and consumable authorization records come from the Diff protection configuration.
    [IO.File]::WriteAllText($protectionFile, '{"formatVersion":1,"protectedPaths":["src/App/Guarded/"],"authorizationDirectory":"src/App/Guarded/authorizations/"}')
    $guarded = @('src/App/Guarded/keep.txt', 'src/App/Guarded/keep-renamed.txt', 'src/App/Guarded/module', 'src/App/Guarded/authorizations/sample.json', 'src/App/Guarded/authorizations/other.json')
    $planData.plannedPaths = @('src/App/App.csproj') + $guarded
    [IO.File]::WriteAllText($planFile, ($planData | ConvertTo-Json -Depth 20))
    Invoke-FixtureGit add -A
    Invoke-FixtureGit commit -qm 'planned change'
    $protected = @('-ProtectionPath', $protectionFile)
    Assert-Run 0 (@('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD~1', '-HeadRef', 'HEAD') + $protected) 'committed planned diff'
    Assert-Run 1 (@('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD', '-HeadRef', 'HEAD') + $protected) 'empty committed diff fails closed' 'Diff changed set is empty'
    [IO.File]::WriteAllText($protectionFile, '{"formatVersion":1,"protectedPaths":["../outside"]}')
    Assert-Run 1 (@('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD~1', '-HeadRef', 'HEAD') + $protected) 'invalid protection configuration fails' '/protectedPaths/0'
    [IO.File]::WriteAllText($protectionFile, '{"formatVersion":1,"protectedPaths":["src/App/Guarded/"],"authorizationDirectory":"src/App/Guarded/authorizations/"}')

    [IO.File]::Delete((Join-Path $fixture 'src/App/Guarded/keep.txt'))
    Invoke-FixtureGit commit -qam 'delete protected file'
    Assert-Run 1 (@('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD~1', '-HeadRef', 'HEAD') + $protected) 'protected deletion fails' 'Protected guard deletions: src/App/Guarded/keep.txt'
    Assert-Run 0 @('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD~1', '-HeadRef', 'HEAD') 'without protection configuration nothing is protected'
    Invoke-FixtureGit reset -q --hard HEAD~1
    Invoke-FixtureGit mv src/App/Guarded/keep.txt src/App/Guarded/keep-renamed.txt
    Invoke-FixtureGit commit -qm 'rename protected file'
    Assert-Run 1 (@('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD~1', '-HeadRef', 'HEAD') + $protected) 'protected rename fails' 'Protected guard deletions: src/App/Guarded/keep.txt'
    Invoke-FixtureGit reset -q --hard HEAD~1

    # Plan 06 §12.3: a protected path in a gitlink fails, whatever the tree entry points to.
    $gitlinkTarget = (& git -C $fixture rev-parse HEAD).Trim()
    Invoke-FixtureGit update-index --add --cacheinfo "160000,$gitlinkTarget,src/App/Guarded/module"
    Invoke-FixtureGit commit -qm 'protected gitlink'
    Assert-Run 1 (@('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD~1', '-HeadRef', 'HEAD') + $protected) 'protected gitlink fails' 'Gitlinks in protected paths: src/App/Guarded/module'
    Invoke-FixtureGit reset -q --hard HEAD~1

    # D23: only a passing protected change report bound to this base, merge base, head and configuration exempts deletions.
    $sample = 'src/App/Guarded/authorizations/sample.json'
    Invoke-FixtureGit rm -q $sample
    Invoke-FixtureGit commit -qm 'consume authorization'
    $reportFile = Join-Path $fixtureParent "v3-protected-changes-$([Guid]::NewGuid().ToString('N')).json"
    function Write-ProtectedChangeReport([string[]] $Allowed, [hashtable] $Override = @{}) {
        $baseSha = (& git -C $fixture rev-parse HEAD~1).Trim()
        $headSha = (& git -C $fixture rev-parse HEAD).Trim()
        $report = [ordered]@{
            formatVersion = 1; check = 'protected-changes'; status = 'pass'; baseSha = $baseSha; mergeBase = $baseSha; headSha = $headSha
            protectionSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($protectionFile))).ToLowerInvariant()
            planPath = $plan; revocation = $false; obligations = @(); authorizations = @(); allowedDeletions = @($Allowed); failures = @()
        }
        foreach ($key in $Override.Keys) { $report[$key] = $Override[$key] }
        [IO.File]::WriteAllText($reportFile, ($report | ConvertTo-Json -Depth 5))
    }
    $committedRange = @('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD~1', '-HeadRef', 'HEAD')
    try {
        $env:GUARD_PROTECTED_CHANGES = $reportFile
        Write-ProtectedChangeReport @($sample)
        Assert-Run 0 ($committedRange + $protected) 'deletion allowed by a bound report passes'
        Write-ProtectedChangeReport @($sample, 'src/App/Guarded/authorizations/other.json')
        Assert-Run 1 ($committedRange + $protected) 'allowed deletion that was not deleted fails' 'Allowed deletions were not deleted by this change: src/App/Guarded/authorizations/other.json'
        Write-ProtectedChangeReport @($sample) @{ headSha = (& git -C $fixture rev-parse HEAD~1).Trim() }
        Assert-Run 1 ($committedRange + $protected) 'report bound to another head fails' 'GUARD_PROTECTED_CHANGES is not bound to this Diff: headSha'
        Write-ProtectedChangeReport @($sample) @{ protectionSha256 = ('0' * 64) }
        Assert-Run 1 ($committedRange + $protected) 'report bound to another protection configuration fails' 'GUARD_PROTECTED_CHANGES is not bound to this Diff: protectionSha256'
        Write-ProtectedChangeReport @($sample) @{ status = 'fail' }
        Assert-Run 1 ($committedRange + $protected) 'failed report fails' 'GUARD_PROTECTED_CHANGES is not bound to this Diff: status'
        $env:GUARD_PROTECTED_CHANGES = $null
        Assert-Run 1 ($committedRange + $protected) 'deletion without a report fails' "Protected guard deletions: $sample"
        Invoke-FixtureGit reset -q --hard HEAD~1
        Invoke-FixtureGit rm -q $sample
        $env:GUARD_PROTECTED_CHANGES = $reportFile
        Assert-Run 1 (@('-Mode', 'Diff', '-PlanPath', $plan, '-BaseRef', 'HEAD') + $protected) 'report is not honoured for uncommitted changes' "Protected guard deletions: $sample"
    }
    finally {
        $env:GUARD_PROTECTED_CHANGES = $null
        if ([IO.File]::Exists($reportFile)) { [IO.File]::Delete($reportFile) }
    }
    $passed = $true
    Write-Host 'V3 synthetic positive/negative tests passed.'
}
finally {
    if ($passed -and [IO.Directory]::Exists($fixture)) {
        $verified = [IO.Path]::GetFullPath($fixture)
        if (-not $verified.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path.' }
        Remove-Item -LiteralPath $verified -Recurse -Force
    }
    elseif (-not $passed) { Write-Warning "Failed fixture retained at $fixture" }
    if ($passed -and [IO.Directory]::Exists($generationRoot)) {
        $verifiedGeneration = [IO.Path]::GetFullPath($generationRoot)
        if (-not $verifiedGeneration.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe generation cleanup path.' }
        Remove-Item -LiteralPath $verifiedGeneration -Recurse -Force
    }
    elseif (-not $passed -and [IO.Directory]::Exists($generationRoot)) { Write-Warning "Failed generation retained at $generationRoot" }
    if ([IO.File]::Exists($protectionFile)) { [IO.File]::Delete($protectionFile) }
}
$global:LASTEXITCODE = 0
