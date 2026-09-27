[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $InputPath,
    [Parameter(Mandatory)] [string] $OutputPath,
    [int] $ExpectedCaseCount = 52
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    $json = (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n")
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}

$inputFull = [IO.Path]::GetFullPath($InputPath)
$outputFull = [IO.Path]::GetFullPath($OutputPath)
if (-not [IO.File]::Exists($inputFull)) { throw "Engine result input is missing: $inputFull" }
if ([IO.File]::Exists($outputFull)) { throw "Comparison output must be absent: $outputFull" }

$inputDocument = Get-Content -LiteralPath $inputFull -Raw | ConvertFrom-Json -AsHashtable -Depth 100
if ([int]$inputDocument.formatVersion -ne 1 -or @($inputDocument.cases).Count -ne $ExpectedCaseCount) {
    throw "Engine result input is not the expected $ExpectedCaseCount-case contract."
}

$matrix = [Collections.Generic.List[object]]::new()
$gaps = [Collections.Generic.List[object]]::new()
$strengthenings = [Collections.Generic.List[object]]::new()
foreach ($case in @($inputDocument.cases | Sort-Object { [string]$_.id })) {
    $comparison = 'equivalent'
    $explanation = 'equivalent'
    $v4 = $case.v4.currentResult
    $v3 = $case.v3.result
    $v3Rules = @($case.v3.rules)
    $ownedRules = @($case.ownedRules)
    $ownedV3Rules = @($v3Rules | Where-Object { $_ -in $ownedRules })

    if ($null -eq $v4 -or [int]$case.v4.process.exitCode -ne 0) {
        $comparison = 'gap'; $explanation = 'v4-engine-or-result-failure'
    } else {
        switch ([string]$case.kind) {
            'clean' {
                if ([string]$v4.status -cne 'pass' -or [string]$v4.exitCategory -cne 'success' -or @($v4.findings).Count -ne 0) {
                    $comparison = 'gap'; $explanation = 'v4-clean-row-did-not-pass'
                } elseif ($ownedV3Rules.Count -gt 0) {
                    $comparison = 'gap'; $explanation = 'v4-missed-module-owned-v3-clean-row-finding'
                } elseif ($v3Rules.Count -gt 0) {
                    $explanation = 'equivalent-for-module; unrelated-v3-findings-visible'
                } elseif ($null -eq $v3) {
                    $explanation = 'equivalent-for-module; v3-not-applicable-to-provider-local-clean-row'
                }
            }
            'missing' {
                if ([string]$v4.status -cne 'error' -or [string]$v4.exitCategory -cne 'prerequisite-missing') {
                    $comparison = 'gap'; $explanation = 'v4-missing-input-accepted-or-category-difference'
                } elseif ([int]$case.v3.process.exitCode -eq 0) {
                    $comparison = 'strengthening'; $explanation = 'v4-fail-closed-missing-input-strengthening-over-v3'
                } else { $explanation = 'both-fail-closed-on-missing-input' }
            }
            'zero' {
                $zeroClaims = @($v4.coverage | Where-Object { [int]$_.matched -eq 0 -and [int]$_.minimum -gt 0 })
                if ([string]$v4.status -ceq 'pass' -or [string]$v4.exitCategory -cne 'findings-blocking' -or $zeroClaims.Count -eq 0) {
                    $comparison = 'gap'; $explanation = 'v4-zero-match-success-or-non-vacuity-loss'
                } elseif ([int]$case.v3.process.exitCode -eq 0) {
                    $comparison = 'strengthening'; $explanation = 'v4-explicit-non-vacuity-strengthening-over-v3'
                } else { $explanation = 'both-fail-closed-on-zero-or-invalid-input' }
            }
            'violation' {
                $rule = [string]$case.expectedRule
                $matching = @($v4.findings | Where-Object {
                    [string]$_.ruleId -ceq $rule -and [string]$_.severity -ceq 'blocking' -and
                    [string]$_.detectorId -ceq [string]$case.moduleId -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.subject) -and
                    -not [string]::IsNullOrWhiteSpace([string]$_.evidenceKind)
                })
                if ([string]$v4.status -cne 'fail' -or [string]$v4.exitCategory -cne 'findings-blocking' -or $matching.Count -eq 0) {
                    $comparison = 'gap'; $explanation = 'v4-missing-expected-blocking-rule-or-finding-semantics'
                } elseif (@($v3Rules | Where-Object { $_ -ceq $rule }).Count -eq 0) {
                    $comparison = 'strengthening'; $explanation = 'v4-blocking-rule-coverage-strengthening-over-v3'
                }
            }
            default { $comparison = 'gap'; $explanation = 'unknown-case-kind' }
        }
    }

    $entry = [ordered]@{
        id = [string]$case.id
        kind = [string]$case.kind
        moduleId = [string]$case.moduleId
        claimIds = @($case.claimIds)
        expectedRule = $case.expectedRule
        v4 = $case.v4
        v3 = $case.v3
        ownedRules = $ownedRules
        ownedV3Rules = $ownedV3Rules
        comparison = $comparison
        explanation = $explanation
    }
    $matrix.Add($entry)
    if ($comparison -ceq 'gap') {
        $gaps.Add([ordered]@{id=[string]$case.id;category='parity-gap';detail=$explanation;v3Rules=$v3Rules;v4Rule=$case.expectedRule})
    } elseif ($comparison -ceq 'strengthening') {
        $strengthenings.Add([ordered]@{id=[string]$case.id;category='v4-fail-closed-strengthening';detail=$explanation;v3Rules=$v3Rules;v4Rule=$case.expectedRule})
    }
}

$status = if ($gaps.Count -eq 0) { 'pass' } else { 'fail' }
Write-Json $outputFull ([ordered]@{
    formatVersion = 1
    status = $status
    caseCount = $matrix.Count
    gapCount = $gaps.Count
    strengtheningCount = $strengthenings.Count
    cases = @($matrix.ToArray())
    gaps = @($gaps.ToArray())
    strengthenings = @($strengthenings.ToArray())
})

Write-Output "P10.2 independent comparison ${status}: cases=$($matrix.Count); gaps=$($gaps.Count); strengthenings=$($strengthenings.Count)"
if ($status -cne 'pass') { exit 1 }
