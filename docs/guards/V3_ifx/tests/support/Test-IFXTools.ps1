# Stage-oriented test group: support.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not [IO.File]::Exists((Join-Path $package 'guard-system.json'))) { $package = [IO.Path]::GetFullPath((Join-Path $package '..')) }
if (-not [IO.File]::Exists((Join-Path $package 'guard-system.json'))) { throw 'Cannot resolve the IFX guard package root.' }
$root = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$v3 = Join-Path $root 'docs/guards/V3'
$profileLayout = Join-Path $package 'shared/profile-layout.json'
$profileViews = Join-Path $package 'profiles/ifx/views'
$profileAuthorityPaths = @(
    (Join-Path $package 'shared/profile.json'),
    (Join-Path $package 'stages/pre/project-map.json'),
    (Join-Path $package 'shared/toolchain.json'),
    (Join-Path $package 'stages/post/rules'),
    $profileViews
)
$artifacts = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/guards'))
$inventoryRoot = [IO.Path]::GetFullPath((Join-Path $artifacts "v3-ifx-tools-$([Guid]::NewGuid().ToString('N'))"))
if (-not $inventoryRoot.StartsWith($artifacts.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe IFX tools fixture path.' }
$inventoryPath = Join-Path $inventoryRoot 'inventory.json'
$usesCommandLayout = [IO.File]::Exists((Join-Path $v3 'commands/Invoke-V3.ps1')) -and [IO.File]::Exists((Join-Path $package 'commands/Invoke-IFXGuardrails.ps1'))
$entryDirectory = if ($usesCommandLayout) { 'commands' } else { 'scripts' }
$evidenceRoot = if ($usesCommandLayout) { Join-Path $package 'stages/analysis/evidence' } else { $inventoryRoot }
$architecturePath = Join-Path $evidenceRoot 'ARCHITECTURE.md'
$technicalPath = Join-Path $evidenceRoot 'TECHNICAL.md'
$v3Runner = Join-Path $v3 "$entryDirectory/Invoke-V3.ps1"
$v3Docs = Join-Path $v3 "$entryDirectory/Invoke-V3Docs.ps1"
$v3Setup = Join-Path $v3 "$entryDirectory/Invoke-V3Setup.ps1"
$policyCandidates = @('policy/layerguard.json', 'stages/post/policy/layerguard.json' | ForEach-Object { Join-Path $package $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
if ($policyCandidates.Count -ne 1) { throw "Exactly one complete legacy or stage-owned policy layout must exist; found $($policyCandidates.Count)." }
$policyPath = $policyCandidates[0]
$policyBefore = [IO.File]::ReadAllBytes($policyPath)
try {
    [void][IO.Directory]::CreateDirectory($inventoryRoot)
    if (-not $usesCommandLayout) {
        [IO.File]::WriteAllBytes($architecturePath, [IO.File]::ReadAllBytes((Join-Path $package 'analysis/ifx/ARCHITECTURE.md')))
        [IO.File]::WriteAllBytes($technicalPath, [IO.File]::ReadAllBytes((Join-Path $package 'analysis/ifx/TECHNICAL.md')))
    }
    $profileBefore = @($profileAuthorityPaths | ForEach-Object { Get-ChildItem -LiteralPath $_ -File -Recurse } | Sort-Object FullName -Unique | ForEach-Object { "$([IO.Path]::GetRelativePath($root, $_.FullName)):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
    & $v3Runner -Mode Validate -TargetRoot $root -ProfileLayoutPath $profileLayout
    & $v3Docs -Mode Check -TargetRoot $root -ProfileLayoutPath $profileLayout -PackageDirectory $package
    if ($usesCommandLayout) {
        $commandsPath = Join-Path $package 'shared/commands.json'
        $commandsBefore = [IO.File]::ReadAllBytes($commandsPath)
        try {
            [IO.File]::WriteAllText($commandsPath, [IO.File]::ReadAllText($commandsPath).Replace('formal Plan (Pre/Diff)', 'reviewed formal Plan (Pre/Diff)'), [Text.UTF8Encoding]::new($false))
            $docsDrift = @(& pwsh -NoProfile -File $v3Docs -Mode Check -TargetRoot $root -ProfileLayoutPath $profileLayout -PackageDirectory $package 2>&1)
            if ($LASTEXITCODE -eq 0 -or ($docsDrift -join ' | ') -notmatch 'Generated Markdown drift') { throw 'Docs Check accepted an authority change without regeneration.' }
        }
        finally { [IO.File]::WriteAllBytes($commandsPath, $commandsBefore) }
        $maintenancePackage = Join-Path $inventoryRoot 'maintenance-fixture/docs/guards/V3_ifx'
        $maintenanceDirectory = Join-Path $maintenancePackage 'maintenance'
        $maintenanceEvidence = Join-Path $maintenancePackage 'stages/analysis/evidence'
        $maintenanceSource = Join-Path $inventoryRoot 'maintenance-fixture/reviewed'
        [void][IO.Directory]::CreateDirectory($maintenanceDirectory)
        [void][IO.Directory]::CreateDirectory($maintenanceEvidence)
        [void][IO.Directory]::CreateDirectory($maintenanceSource)
        $maintenanceCommand = Join-Path $maintenanceDirectory 'Update-IFXAnalysisEvidence.ps1'
        Copy-Item -LiteralPath (Join-Path $package 'maintenance/Update-IFXAnalysisEvidence.ps1') -Destination $maintenanceCommand
        $maintenanceTarget = Join-Path $maintenanceEvidence 'ARCHITECTURE.md'
        $maintenanceCandidate = Join-Path $maintenanceSource 'ARCHITECTURE.md'
        [IO.File]::WriteAllText($maintenanceTarget, "accepted`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($maintenanceCandidate, "reviewed`n", [Text.UTF8Encoding]::new($false))
        & $maintenanceCommand -Mode Preview -TargetRoot (Join-Path $inventoryRoot 'maintenance-fixture') -SourceDirectory $maintenanceSource -Names 'ARCHITECTURE.md'
        if ([IO.File]::ReadAllText($maintenanceTarget) -ne "accepted`n") { throw 'Analysis evidence Preview modified long-lived evidence.' }
        $applyRejected = $false
        try { & $maintenanceCommand -Mode Apply -TargetRoot (Join-Path $inventoryRoot 'maintenance-fixture') -SourceDirectory $maintenanceSource -Names 'ARCHITECTURE.md' } catch { $applyRejected = $_.Exception.Message -match 'AcceptAnalysisEvidence' }
        if (-not $applyRejected) { throw 'Analysis evidence Apply succeeded without explicit acceptance.' }
        & $maintenanceCommand -Mode Apply -TargetRoot (Join-Path $inventoryRoot 'maintenance-fixture') -SourceDirectory $maintenanceSource -Names 'ARCHITECTURE.md' -AcceptAnalysisEvidence
        if ([IO.File]::ReadAllText($maintenanceTarget) -ne "reviewed`n") { throw 'Accepted analysis evidence was not applied.' }
    }
    $architectureBefore = [IO.File]::ReadAllBytes($architecturePath)
    $technicalBefore = [IO.File]::ReadAllBytes($technicalPath)
    if ($usesCommandLayout) { & $v3Setup -Mode Analyze -TargetRoot $root -OutputDirectory $inventoryRoot -EvidenceDirectory $evidenceRoot -ProfileLayoutPath $profileLayout -ExcludePaths 'docs/guards/**' -PackageId v3-ifx }
    else { & $v3Setup -Mode Analyze -TargetRoot $root -OutputDirectory $inventoryRoot -ProfileLayoutPath $profileLayout -ExcludePaths 'docs/guards/**' }
    if (-not [IO.File]::Exists($inventoryPath)) { throw 'IFX inventory was not generated.' }
    $first = [IO.File]::ReadAllBytes($inventoryPath)
    if ($usesCommandLayout) { & $v3Setup -Mode Analyze -TargetRoot $root -OutputDirectory $inventoryRoot -EvidenceDirectory $evidenceRoot -ProfileLayoutPath $profileLayout -ExcludePaths 'docs/guards/**' -PackageId v3-ifx }
    else { & $v3Setup -Mode Analyze -TargetRoot $root -OutputDirectory $inventoryRoot -ProfileLayoutPath $profileLayout -ExcludePaths 'docs/guards/**' }
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $first, [byte[]] [IO.File]::ReadAllBytes($inventoryPath))) { throw 'IFX analysis is not reproducible across consecutive runs.' }
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $architectureBefore, [byte[]] [IO.File]::ReadAllBytes($architecturePath)) -or
        -not [Linq.Enumerable]::SequenceEqual([byte[]] $technicalBefore, [byte[]] [IO.File]::ReadAllBytes($technicalPath))) { throw 'Analyze overwrote editable IFX architecture drafts.' }
    if ($usesCommandLayout) { & (Join-Path $v3 'scripts/Invoke-V3Architecture.ps1') -Mode Review -TargetRoot $root -AnalysisDirectory $inventoryRoot -EvidenceDirectory $evidenceRoot -ProfileLayoutPath $profileLayout }
    else { & (Join-Path $v3 'scripts/Invoke-V3Architecture.ps1') -Mode Review -TargetRoot $root -AnalysisDirectory $inventoryRoot -ProfileLayoutPath $profileLayout }
$review = Get-Content -LiteralPath (Join-Path $inventoryRoot 'architecture-review.json') -Raw | ConvertFrom-Json
if ($review.projectId -ne 'ifx' -or $review.documentReviewed -or $review.profileDifferences.Count -ne 0 -or -not $review.hasBlockingDetector -or $review.observedForbiddenReferences.Count -ne 0) { throw 'IFX architecture review does not match current evidence/profile.' }
$profileAfter = @($profileAuthorityPaths | ForEach-Object { Get-ChildItem -LiteralPath $_ -File -Recurse } | Sort-Object FullName -Unique | ForEach-Object { "$([IO.Path]::GetRelativePath($root, $_.FullName)):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)" })
if (@(Compare-Object $profileBefore $profileAfter).Count -ne 0) { throw 'Architecture review modified the current IFX profile.' }
if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $policyBefore, [byte[]] [IO.File]::ReadAllBytes($policyPath))) { throw 'Analyze modified independent LayerGuard policy.' }
$inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
if (@($inventory.projects | Where-Object { $_.role -eq 'source' }).Count -lt 40) { throw 'IFX source project inventory is incomplete.' }
if (@($inventory.projects | Where-Object { $_.path -eq 'mcp/LayerGuard/src/LayerGuard/LayerGuard.csproj' }).Count -ne 1) { throw 'Existing LayerGuard project was not inventoried.' }
if (@($inventory.workflows | Where-Object { $_.path -eq '.github/workflows/v3-ifx-guardrails.yml' }).Count -ne 1) { throw 'V3 IFX CI workflow was not inventoried.' }
if (@($inventory.workflows | Where-Object { $_.path -match '(coding-guardrails|contract-event-governance|database-migrations|g04-deployment-runtime|g05-context-boundary|layerguard|plan04-governance)\.yml$' }).Count -ne 0) { throw 'Retired guard workflow remains in the inventory.' }
if ('src/Modules/CRM' -notin @($inventory.areaCandidates)) { throw 'IFX module candidate was not detected.' }
$coverage = [IO.File]::ReadAllText((Join-Path $profileViews 'COVERAGE.md'))
if ($coverage -notmatch '\[L2\.2\].*blocking' -or $coverage -notmatch '\[L2\.3\].*advisory') { throw 'IFX stage coverage view misstates enforcement.' }
    Write-Host "IFX V3 tools passed: $($inventory.projects.Count) projects, $($inventory.workflows.Count) workflows, reproducible analysis, preserved architecture drafts, zero profile drift, unchanged LayerGuard policy and checked Markdown views$(if ($usesCommandLayout) { ', explicit evidence acceptance' } else { '' })."
}
finally {
    if ([IO.Directory]::Exists($inventoryRoot)) { [IO.Directory]::Delete($inventoryRoot, $true) }
}
