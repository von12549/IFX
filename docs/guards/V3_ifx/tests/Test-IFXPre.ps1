[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixtureParent = [IO.Path]::GetFullPath((Join-Path $repo 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $fixtureParent "v3-ifx-pre-$([Guid]::NewGuid().ToString('N'))"))
$runner = Join-Path $repo 'docs/guards/V3/scripts/Invoke-V3.ps1'
$profile = Join-Path $package 'profiles/ifx'
$reportRelative = [IO.Path]::GetRelativePath($repo, (Join-Path $fixture 'report.json')).Replace('\', '/')
$planRelative = [IO.Path]::GetRelativePath($repo, (Join-Path $fixture '20260914-ifx-pre.plan.json')).Replace('\', '/')
$planFile = Join-Path $fixture '20260914-ifx-pre.plan.json'
$decisionRelative = [IO.Path]::GetRelativePath($repo, (Join-Path $fixture 'decision.json')).Replace('\', '/')
$riskyPath = 'src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj'

function Assert-Pre {
    param([int] $Expected, [string[]] $Arguments, [string] $Label)
    $output = @(& pwsh -NoProfile -File $runner -Mode Pre -ProfileDirectory $profile -TargetRoot $repo -ReportPath $reportRelative @Arguments 2>&1)
    if ($LASTEXITCODE -ne $Expected) { throw "$Label expected exit $Expected, got ${LASTEXITCODE}: $($output -join ' | ')" }
    $result = Get-Content -LiteralPath (Join-Path $fixture 'report.json') -Raw | ConvertFrom-Json
    if ($Expected -eq 0 -and $result.status -ne 'advisory') { throw "$Label did not produce an advisory result." }
    if ($Expected -ne 0 -and $result.status -ne 'blocked') { throw "$Label did not produce a blocked result." }
    return $result
}

if (-not $fixture.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe IFX Pre fixture path.' }
try {
    [void] [IO.Directory]::CreateDirectory($fixture)
    $summary = Assert-Pre 0 @('-PlannedPaths', 'src/Modules/CRM/IFX.Modules.CRM.Domain/Sample.cs') 'ordinary CRM summary'
    if ('CRM' -notin $summary.areas.id -or 'L2.2' -notin $summary.ruleIds -or 'ARCH.BINARY.DOMAIN.CONTRACTS' -notin $summary.ruleIds -or 'L2.9' -notin $summary.ruleIds -or 'crm-tests' -notin $summary.validationCommands -or $summary.inputSha256.Length -ne 64) { throw 'IFX summary lost area, rule, command or input hash.' }
    $iamRisk = Assert-Pre 1 @('-PlannedPaths', 'src/Modules/IAM/IFX.Modules.IAM.Domain/Sample.cs') 'IAM risk needs formal Plan'
    if ('identity-security' -notin $iamRisk.risks.id -or 'IAM' -notin $iamRisk.areas.id) { throw 'Blocked IFX summary lost risk context.' }
    [void] (Assert-Pre 1 @('-PlannedPaths', 'unknown/Unmapped.cs') 'unmapped path fails closed')
    [void] (Assert-Pre 1 @('-PlannedPaths', 'src/Modules/NewModule/Domain/New.cs') 'unregistered module fails closed')
    $plan = [ordered]@{
        formatVersion = 1; id = '20260914-ifx-pre'; title = 'IFX dependency change'
        goal = 'Maintain the CRM Domain boundary'; acceptanceCriteria = @('The Domain project remains compliant')
        plannedPaths = @($riskyPath); areaIds = @('CRM'); ruleIds = @('L1.2', 'L2.2', 'L2.9', 'ARCH.BINARY.DOMAIN.CONTRACTS')
        validationCommands = @('ifx-layerguard', 'crm-tests'); decisionPaths = @()
    }
    [IO.File]::WriteAllText($planFile, ($plan | ConvertTo-Json -Depth 20))
    [IO.File]::WriteAllText((Join-Path $fixture '20260914-ifx-pre.md'), '# IFX dependency change')
    $missingDecision = Assert-Pre 1 @('-PlanPath', $planRelative) 'project change needs decision'
    if ('dotnet-dependency' -notin $missingDecision.risks.id -or 'CRM' -notin $missingDecision.areas.id) { throw 'Blocked IFX formal Plan lost risk context.' }
    [IO.File]::WriteAllText((Join-Path $fixture 'decision.json'), ('{"formatVersion":1,"id":"ifx-test-decision","owner":"xiaolong-feng","summary":"CRM dependency review","affectedPaths":["' + $riskyPath + '"],"rationale":"Test fixture"}'))
    $plan.decisionPaths = @($decisionRelative)
    [IO.File]::WriteAllText($planFile, ($plan | ConvertTo-Json -Depth 20))
    $formal = Assert-Pre 0 @('-PlanPath', $planRelative) 'complete formal Plan'
    if ($formal.mode -ne 'formal' -or $formal.planId -ne $plan.id -or 'dotnet-dependency' -notin $formal.risks.id) { throw 'IFX formal result lost Plan or risk mapping.' }
    foreach ($field in @('areaIds', 'ruleIds', 'validationCommands')) {
        $saved = $plan[$field]
        $plan[$field] = @()
        [IO.File]::WriteAllText($planFile, ($plan | ConvertTo-Json -Depth 20))
        [void] (Assert-Pre 1 @('-PlanPath', $planRelative) "omitted $field fails closed")
        $plan[$field] = $saved
    }
    Write-Host 'IFX Pre positive and negative tests passed.'
}
finally {
    if ([IO.Directory]::Exists($fixture)) {
        $resolved = [IO.Path]::GetFullPath($fixture)
        if (-not $resolved.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe IFX Pre fixture cleanup path.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
$global:LASTEXITCODE = 0
