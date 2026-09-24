[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path,
    [Parameter(Mandatory)][string]$InventoryPath,
    [string]$ContractPath = 'docs/guards/candidates/ifx-gate-coverage-c6c4/matrix-contract.json',
    [string]$FixtureSpecPath = 'docs/guards/candidates/ifx-gate-coverage-c6c4/fixture-spec.json',
    [string]$ReportPath = 'artifacts/guards/p10-ifx-c6c4/matrix-contract/summary.json',
    [string]$CaptureDirectory,
    [string[]]$AdditionalCapturePath = @(),
    [string]$DiagnosticReportPath = 'artifacts/guards/p10-ifx-c6c4/matrix-contract/reclassification.json'
)

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath($RepositoryRoot)
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Text-Hash([string]$Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant() }
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-Json([string]$Path, $Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }

$inventoryFull = Full $InventoryPath
$contractFull = Full $ContractPath
$fixtureSpecFull = Full $FixtureSpecPath
Assert ([IO.File]::Exists($inventoryFull)) 'Ordinal inventory is missing.'
Assert ([IO.File]::Exists($contractFull)) 'Matrix contract is missing.'
Assert ([IO.File]::Exists($fixtureSpecFull)) 'Supplemental fixture specification is missing.'
$inventory = Get-Content -Raw -LiteralPath $inventoryFull | ConvertFrom-Json -Depth 100
$contract = Get-Content -Raw -LiteralPath $contractFull | ConvertFrom-Json -Depth 100
$fixtureSpec = Get-Content -Raw -LiteralPath $fixtureSpecFull | ConvertFrom-Json -Depth 100
Assert ($contract.formatVersion -eq 1 -and $contract.id -ceq 'ifx-c6c4-independent-matrix-contract') 'Matrix contract identity drift.'
$inventoryProjection = [ordered]@{
    modules = @($inventory.modules | Sort-Object ordinal | ForEach-Object { [ordered]@{ ordinal=$_.ordinal; id=$_.id; stage=$_.stage; sourcePath=$_.sourcePath; adapterSha256=$_.adapterSha256 } })
    rules = @($inventory.rules | Sort-Object ordinal | ForEach-Object { [ordered]@{ ordinal=$_.ordinal; moduleOrdinal=$_.moduleOrdinal; moduleId=$_.moduleId; stage=$_.stage; ruleId=$_.ruleId; claimId=$_.claimId; severity=$_.severity; minimumMatches=$_.minimumMatches } })
}
$inventoryProjectionSha256 = Text-Hash (($inventoryProjection | ConvertTo-Json -Depth 20 -Compress).Replace("`r`n", "`n"))
Assert ($inventoryProjectionSha256 -ceq $contract.inventoryProjectionSha256) 'Matrix contract inventory projection drift.'
$blocking = @($inventory.rules | Where-Object severity -CEQ 'blocking')
$advisory = @($inventory.rules | Where-Object severity -CEQ 'advisory')
Assert (@($inventory.modules).Count -eq $contract.moduleCount -and $contract.moduleCount -eq 37) 'Module count drift.'
Assert ($blocking.Count -eq $contract.blockingRuleCount -and $contract.blockingRuleCount -eq 80) 'Blocking-rule count drift.'
Assert ($advisory.Count -eq $contract.advisoryRuleCount -and $contract.advisoryRuleCount -eq 3) 'Advisory-rule count drift.'
Assert (@($contract.modules).Count -eq 37) 'Module contract cardinality drift.'
Assert (@($contract.modules.id | Sort-Object -Unique).Count -eq 37) 'Duplicate module contract.'
$allowedZero = @('enumerated-zero', 'fixed-checklist-zero', 'integrity-zero')
foreach ($module in @($inventory.modules | Sort-Object ordinal)) {
    $entry = @($contract.modules | Where-Object id -CEQ $module.id)
    Assert ($entry.Count -eq 1) "Module contract missing: $($module.id)"
    $entry = $entry[0]
    Assert ($entry.ordinal -eq $module.ordinal) "Module ordinal drift: $($module.id)"
    Assert ($entry.zeroStrategy -cin $allowedZero) "Unknown zero strategy: $($module.id)"
    Assert (-not [string]::IsNullOrWhiteSpace([string]$entry.sourceFact)) "Source fact missing: $($module.id)"
    $adapter = Full ([string]$entry.adapterPath)
    Assert ([IO.File]::Exists($adapter)) "Adapter path missing: $($module.id)"
    Assert ((Hash $adapter) -ceq [string]$entry.adapterSha256) "Adapter hash drift: $($module.id)"
    if ($module.id -cne 'architecture-conformance') { Assert ([string]$module.adapterSha256 -ceq [string]$entry.adapterSha256) "Inventory adapter hash drift: $($module.id)" }
    if ($entry.zeroStrategy -ceq 'fixed-checklist-zero') {
        $finding = $entry.zeroFinding
        Assert ($null -ne $finding -and -not [string]::IsNullOrWhiteSpace([string]$finding.subject) -and -not [string]::IsNullOrWhiteSpace([string]$finding.evidenceKind)) "Fixed-checklist finding missing: $($module.id)"
        Assert (@($blocking | Where-Object { $_.moduleId -ceq $module.id -and $_.ruleId -ceq $finding.ruleId }).Count -eq 1) "Fixed-checklist rule is not owned: $($module.id)"
    }
    if ($entry.zeroStrategy -ceq 'integrity-zero') { Assert ($entry.zeroExitCategory -ceq 'integrity-failure') "Integrity-zero category drift: $($module.id)" }
}
Assert ($contract.defaultRuleContract.outcome -ceq 'findings-blocking' -and $contract.defaultRuleContract.allowedRuleSet -ceq 'isolated' -and $contract.defaultRuleContract.coverage -ceq 'nonzero') 'Default rule contract drift.'
$seenOverrides = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($override in @($contract.ruleOverrides)) {
    $key = "$($override.moduleId)/$($override.ruleId)"
    Assert ($seenOverrides.Add($key)) "Duplicate rule override: $key"
    $rule = @($blocking | Where-Object { $_.moduleId -ceq $override.moduleId -and $_.ruleId -ceq $override.ruleId })
    Assert ($rule.Count -eq 1) "Unknown rule override: $key"
    Assert ($override.outcome -cin @('findings-blocking', 'integrity-failure')) "Unknown rule outcome: $key"
    Assert ($override.coverage -cin @('nonzero', 'finding-proves-evaluation', 'integrity-progress')) "Unknown coverage contract: $key"
    if ($override.outcome -ceq 'findings-blocking') {
        Assert (@($override.allowedRuleIds).Count -gt 0 -and @($override.allowedRuleIds) -ccontains [string]$override.ruleId) "Rule override omits its target: $key"
        foreach ($allowed in @($override.allowedRuleIds)) { Assert (@($blocking | Where-Object { $_.moduleId -ceq $override.moduleId -and $_.ruleId -ceq $allowed }).Count -eq 1) "Cross-module or unknown coupled rule: $key -> $allowed" }
    } else {
        Assert (@($override.allowedRuleIds).Count -eq 0 -and $override.coverage -ceq 'integrity-progress') "Integrity outcome contract drift: $key"
    }
}
$expectedAdvisory = @($advisory | ForEach-Object { "$($_.moduleId)/$($_.ruleId)/$($_.claimId)" } | Sort-Object)
$actualAdvisory = @($contract.advisoryRules | ForEach-Object { "$($_.moduleId)/$($_.ruleId)/$($_.claimId)" } | Sort-Object)
Assert (($expectedAdvisory -join "`n") -ceq ($actualAdvisory -join "`n")) 'Advisory-rule contract drift.'
Assert ($fixtureSpec.formatVersion -eq 1 -and $fixtureSpec.id -ceq 'ifx-c6c4-supplemental-fixtures' -and $fixtureSpec.status -cin @('planned','partial','complete')) 'Fixture specification identity drift.'
Assert ($fixtureSpec.matrixContractSha256 -ceq (Hash $contractFull)) 'Fixture specification contract binding drift.'
Assert ($fixtureSpec.requiredCoreCasesBeforeSupplement -eq 191 -and $fixtureSpec.provenCoreCasesBeforeSupplement -eq 153 -and $fixtureSpec.residualCoreCaseCount -eq 38 -and $fixtureSpec.residualAdvisoryCount -eq 1) 'Fixture specification cardinality drift.'
Assert (@($fixtureSpec.cases).Count -eq 39 -and @($fixtureSpec.cases.id | Sort-Object -Unique).Count -eq 39) 'Fixture case cardinality or uniqueness drift.'
Assert (@($fixtureSpec.cases | Where-Object id -Match '/A/').Count -eq 1) 'Fixture advisory cardinality drift.'
Assert ($fixtureSpec.implementedCoreCaseCount -eq @($fixtureSpec.implementedCaseIds).Count -and $fixtureSpec.remainingCoreCaseCount -eq ($fixtureSpec.residualCoreCaseCount - $fixtureSpec.implementedCoreCaseCount)) 'Implemented fixture cardinality drift.'
foreach ($implemented in @($fixtureSpec.implementedCaseIds)) { Assert (@($fixtureSpec.cases | Where-Object id -CEQ $implemented).Count -eq 1 -and $implemented -cnotmatch '/A/') "Implemented fixture ID drift: $implemented" }
foreach ($suiteProperty in $fixtureSpec.sourceSuites.PSObject.Properties) {
    $source = $suiteProperty.Value
    $sourcePath = Full ([string]$source.path)
    Assert ([IO.File]::Exists($sourcePath) -and (Hash $sourcePath) -ceq [string]$source.sha256) "Fixture source-suite drift: $($suiteProperty.Name)"
}
foreach ($case in $fixtureSpec.cases) {
    Assert (-not [string]::IsNullOrWhiteSpace([string]$case.recipe)) "Fixture recipe missing: $($case.id)"
    Assert ($null -ne $fixtureSpec.sourceSuites.PSObject.Properties[[string]$case.sourceSuite]) "Fixture source suite unknown: $($case.id)"
}
$reportFull = Full $ReportPath
$report = [ordered]@{
    formatVersion = 1
    status = 'pass'
    scope = 'c6c4-matrix-contract'
    inventorySha256 = Hash $inventoryFull
    inventoryProjectionSha256 = $inventoryProjectionSha256
    contractSha256 = Hash $contractFull
    fixtureSpecSha256 = Hash $fixtureSpecFull
    moduleCount = 37
    blockingRuleCount = 80
    advisoryRuleCount = 3
    zeroStrategies = [ordered]@{
        enumerated = @($contract.modules | Where-Object zeroStrategy -CEQ 'enumerated-zero').Count
        fixedChecklist = @($contract.modules | Where-Object zeroStrategy -CEQ 'fixed-checklist-zero').Count
        integrity = @($contract.modules | Where-Object zeroStrategy -CEQ 'integrity-zero').Count
    }
    ruleOverrideCount = @($contract.ruleOverrides).Count
}
Write-Json $reportFull $report
Write-Output "IFX C6c4 matrix contract passed: $reportFull"

if (-not [string]::IsNullOrWhiteSpace($CaptureDirectory)) {
    $captureFull = Full $CaptureDirectory
    Assert ([IO.Directory]::Exists($captureFull)) 'Capture directory is missing.'
    $captures = [Collections.Generic.List[object]]::new()
    $captureFiles = [Collections.Generic.List[IO.FileInfo]]::new()
    foreach ($file in Get-ChildItem -LiteralPath $captureFull -File -Filter '*.jsonl' | Sort-Object Name) { $captureFiles.Add($file) }
    foreach ($additional in $AdditionalCapturePath) { $path = Full $additional; Assert ([IO.File]::Exists($path)) "Additional capture is missing: $additional"; $captureFiles.Add((Get-Item -LiteralPath $path)) }
    foreach ($file in $captureFiles) {
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $record = $line | ConvertFrom-Json -Depth 100
            try { $result = $record.output | ConvertFrom-Json -Depth 100 } catch { continue }
            $captures.Add([pscustomobject]@{
                moduleId = [string]$record.moduleId
                fixtureId = [IO.Path]::GetFileName([string]$record.targetRoot)
                fixtureSha256 = [string]$record.fixtureSha256
                processExit = [int]$record.exitCode
                status = [string]$result.status
                exitCategory = [string]$result.exitCategory
                findings = @($result.findings)
                coverage = @($result.coverage)
                targetInvariant = ($null -eq $record.targetBefore -or [string]$record.targetBefore -ceq [string]$record.targetAfter)
            })
        }
    }
    $cases = [Collections.Generic.List[object]]::new()
    $gaps = [Collections.Generic.List[object]]::new()
    $usedViolationFixtures = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($module in @($inventory.modules | Sort-Object ordinal)) {
        $moduleId = [string]$module.id
        $moduleContract = @($contract.modules | Where-Object id -CEQ $moduleId)[0]
        $moduleRules = @($blocking | Where-Object moduleId -CEQ $moduleId)
        $claims = @($moduleRules.claimId | Sort-Object -Unique)
        $rows = @($captures | Where-Object moduleId -CEQ $moduleId)
        $clean = @($rows | Where-Object {
            $_.processExit -eq 0 -and $_.status -ceq 'pass' -and @($_.findings).Count -eq 0 -and $_.targetInvariant -and
            @($_.coverage | Where-Object { $_.claimId -cin $claims -and $_.matched -ge $_.minimum }).Count -eq $claims.Count
        })
        if ($clean.Count) { $cases.Add([ordered]@{ id="$moduleId/C"; kind='clean'; fixtureSha256=$clean[0].fixtureSha256 }) }
        else { $gaps.Add([ordered]@{ id="$moduleId/C"; reason='No strict clean result.' }) }
        $missing = @($rows | Where-Object { $_.processExit -eq 0 -and $_.status -ceq 'error' -and $_.exitCategory -ceq 'prerequisite-missing' -and @($_.findings).Count -eq 0 -and $_.targetInvariant })
        if ($missing.Count) { $cases.Add([ordered]@{ id="$moduleId/M"; kind='missing'; fixtureSha256=$missing[0].fixtureSha256 }) }
        else { $gaps.Add([ordered]@{ id="$moduleId/M"; reason='No strict prerequisite-missing result.' }) }
        $zero = switch ([string]$moduleContract.zeroStrategy) {
            'enumerated-zero' {
                @($rows | Where-Object {
                    if ($_.processExit -ne 0 -or $_.status -cne 'fail' -or $_.exitCategory -cne 'findings-blocking' -or -not $_.targetInvariant) { return $false }
                    $zeroClaims = @($_.coverage | Where-Object { $_.claimId -cin $claims -and $_.matched -eq 0 -and $_.minimum -gt 0 } | ForEach-Object claimId | Sort-Object -Unique)
                    return (($zeroClaims -join ',') -ceq ($claims -join ','))
                })
            }
            'fixed-checklist-zero' {
                @($rows | Where-Object {
                    if ($_.fixtureId -cnotmatch 'zero' -or $_.processExit -ne 0 -or $_.status -cne 'fail' -or $_.exitCategory -cne 'findings-blocking' -or -not $_.targetInvariant) { return $false }
                    $finding = @($_.findings | Where-Object { $_.ruleId -ceq $moduleContract.zeroFinding.ruleId -and $_.subject -ceq $moduleContract.zeroFinding.subject -and $_.evidenceKind -ceq $moduleContract.zeroFinding.evidenceKind -and $_.detectorId -ceq $moduleId })
                    $covered = @($_.coverage | Where-Object { $_.claimId -cin $claims -and $_.minimum -gt 0 } | ForEach-Object claimId | Sort-Object -Unique)
                    return ($finding.Count -gt 0 -and ($covered -join ',') -ceq ($claims -join ','))
                })
            }
            'integrity-zero' {
                @($rows | Where-Object {
                    if ($_.processExit -ne 0 -or $_.status -cne 'error' -or $_.exitCategory -cne $moduleContract.zeroExitCategory -or @($_.findings).Count -ne 0 -or -not $_.targetInvariant) { return $false }
                    $zeroClaims = @($_.coverage | Where-Object { $_.claimId -cin $claims -and $_.matched -eq 0 -and $_.minimum -gt 0 } | ForEach-Object claimId | Sort-Object -Unique)
                    return (($zeroClaims -join ',') -ceq ($claims -join ','))
                })
            }
        }
        if (@($zero).Count) { $cases.Add([ordered]@{ id="$moduleId/Z"; kind='zero'; strategy=$moduleContract.zeroStrategy; fixtureSha256=@($zero)[0].fixtureSha256 }) }
        else { $gaps.Add([ordered]@{ id="$moduleId/Z"; reason="No $($moduleContract.zeroStrategy) result." }) }
        foreach ($rule in $moduleRules) {
            $override = @($contract.ruleOverrides | Where-Object { $_.moduleId -ceq $moduleId -and $_.ruleId -ceq $rule.ruleId })
            $outcome = if ($override.Count) { [string]$override[0].outcome } else { [string]$contract.defaultRuleContract.outcome }
            $coverageContract = if ($override.Count) { [string]$override[0].coverage } else { [string]$contract.defaultRuleContract.coverage }
            $allowedRules = if ($override.Count) { @($override[0].allowedRuleIds | Sort-Object -Unique) } else { @([string]$rule.ruleId) }
            $violation = if ($outcome -ceq 'integrity-failure') {
                @($rows | Where-Object { $_.processExit -eq 0 -and $_.status -ceq 'error' -and $_.exitCategory -ceq 'integrity-failure' -and @($_.findings).Count -eq 0 -and $_.targetInvariant })
            } else {
                @($rows | Where-Object {
                    if ($_.processExit -ne 0 -or $_.status -cne 'fail' -or $_.exitCategory -cne 'findings-blocking' -or -not $_.targetInvariant) { return $false }
                    $finding = @($_.findings | Where-Object { $_.ruleId -ceq $rule.ruleId -and -not [string]::IsNullOrWhiteSpace([string]$_.subject) -and -not [string]::IsNullOrWhiteSpace([string]$_.detectorId) -and -not [string]::IsNullOrWhiteSpace([string]$_.evidenceKind) })
                    $actualRules = @($_.findings | Where-Object { $_.ruleId -cin @($moduleRules.ruleId) } | ForEach-Object ruleId | Sort-Object -Unique)
                    $coverageRows = @($_.coverage | Where-Object claimId -CEQ $rule.claimId)
                    $coverageOkay = $coverageRows.Count -eq 1 -and ($coverageContract -ceq 'finding-proves-evaluation' -or $coverageRows[0].matched -gt 0)
                    return ($finding.Count -gt 0 -and ($actualRules -join ',') -ceq ($allowedRules -join ',') -and $coverageOkay)
                })
            }
            $unused = @($violation | Where-Object { -not $usedViolationFixtures.Contains([string]$_.fixtureSha256) })
            if ($unused.Count) {
                [void]$usedViolationFixtures.Add([string]$unused[0].fixtureSha256)
                $cases.Add([ordered]@{ id="$moduleId/V/$($rule.ruleId)"; kind='violation'; outcome=$outcome; coverage=$coverageContract; allowedRuleIds=$allowedRules; fixtureSha256=$unused[0].fixtureSha256 })
            } else { $gaps.Add([ordered]@{ id="$moduleId/V/$($rule.ruleId)"; reason='No independent result satisfies the rule contract.' }) }
        }
    }
    foreach ($advisoryRule in $advisory) {
        $projected = @($captures | Where-Object moduleId -CEQ $advisoryRule.moduleId | ForEach-Object { @($_.findings) } | Where-Object ruleId -CEQ $advisoryRule.ruleId)
        if (-not $projected.Count) { $gaps.Add([ordered]@{ id="$($advisoryRule.moduleId)/A/$($advisoryRule.ruleId)"; reason='Advisory companion was not projected.' }) }
    }
    $diagnostic = [ordered]@{
        formatVersion = 1
        status = if ($gaps.Count -eq 0 -and $cases.Count -eq 191) { 'pass' } else { 'blocked' }
        scope = 'c6c4-offline-reclassification'
        source = 'historical-captures-diagnostic-only'
        contractSha256 = Hash $contractFull
        captureCount = $captures.Count
        requiredCoreCases = 191
        provenCoreCases = $cases.Count
        gaps = @($gaps.ToArray())
        cases = @($cases.ToArray() | Sort-Object id)
    }
    $diagnosticFull = Full $DiagnosticReportPath
    Write-Json $diagnosticFull $diagnostic
    Write-Output "IFX C6c4 offline reclassification $($diagnostic.status): $($diagnostic.provenCoreCases)/191 rows; report: $diagnosticFull"
}
