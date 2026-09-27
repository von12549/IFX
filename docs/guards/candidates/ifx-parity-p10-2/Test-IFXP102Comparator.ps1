[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function V4([string] $Status,[string] $Category,$Findings=@(),$Coverage=@()) {
    [ordered]@{process=[ordered]@{exitCode=0};currentResult=[ordered]@{status=$Status;exitCategory=$Category;findings=@($Findings);coverage=@($Coverage)}}
}
function V3([int] $Exit,[string[]] $Rules) {
    [ordered]@{process=[ordered]@{exitCode=$Exit};result=[ordered]@{verdict=$(if($Exit-eq0){'baseline-clean'}else{'new-violations'});violations=@($Rules|ForEach-Object{[ordered]@{rule=$_}})};rules=@($Rules);violationCount=$Rules.Count}
}
function Case([string] $Id,[string] $Kind,[string] $ExpectedRule,[string[]] $OwnedRules,$V4,$V3) {
    [ordered]@{id=$Id;kind=$Kind;moduleId='module-a';claimIds=@('CLAIM-A');expectedRule=$(if($ExpectedRule){$ExpectedRule}else{$null});ownedRules=$OwnedRules;v4=$V4;v3=$V3}
}

$root = Join-Path ([IO.Path]::GetTempPath()) ('ifx-p10-2-comparator-' + [Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($root)
try {
    $blocking = [ordered]@{ruleId='RULE-A';subject='subject';evidenceKind='source';detectorId='module-a';severity='blocking'}
    $zero = [ordered]@{claimId='CLAIM-A';matched=0;minimum=1}
    $cases = @(
        (Case 'clean-unrelated' 'clean' '' @('RULE-A') (V4 'pass' 'success') (V3 1 @('RULE-X'))),
        (Case 'missing-strengthening' 'missing' '' @('RULE-A') (V4 'error' 'prerequisite-missing') (V3 0 @())),
        (Case 'zero-strengthening' 'zero' '' @('RULE-A') (V4 'fail' 'findings-blocking' @($blocking) @($zero)) (V3 0 @())),
        (Case 'violation-strengthening' 'violation' 'RULE-A' @('RULE-A') (V4 'fail' 'findings-blocking' @($blocking)) (V3 0 @())),
        (Case 'violation-equivalent' 'violation' 'RULE-A' @('RULE-A') (V4 'fail' 'findings-blocking' @($blocking)) (V3 1 @('RULE-A'))),
        (Case 'violation-weakening' 'violation' 'RULE-A' @('RULE-A') (V4 'pass' 'success') (V3 1 @('RULE-A')))
    )
    $input = Join-Path $root 'input.json'; $output = Join-Path $root 'output.json'
    [IO.File]::WriteAllText($input,(([ordered]@{formatVersion=1;cases=$cases}|ConvertTo-Json -Depth 100)+"`n"),[Text.UTF8Encoding]::new($false))
    $comparer = Join-Path $PSScriptRoot 'Compare-IFXP102Parity.ps1'
    $text = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $comparer -InputPath $input -OutputPath $output -ExpectedCaseCount 6 2>&1)
    $code = $LASTEXITCODE
    Assert ($code -eq 1 -and [IO.File]::Exists($output)) "Comparator did not fail closed on the weakening fixture: $($text -join "`n")"
    $result = Get-Content -LiteralPath $output -Raw | ConvertFrom-Json -Depth 100
    Assert ($result.caseCount -eq 6 -and $result.gapCount -eq 1 -and $result.strengtheningCount -eq 3) 'Comparator counts differ from the self-test contract.'
    Assert ($result.gaps[0].id -ceq 'violation-weakening') 'Comparator did not isolate the real weakening.'
    Assert (@($result.cases | Where-Object { $_.id -ceq 'clean-unrelated' -and $_.comparison -ceq 'equivalent' }).Count -eq 1) 'Unrelated V3 clean-row findings were not scoped out.'
    Assert (@($result.strengthenings | Where-Object id -CEQ 'missing-strengthening').Count -eq 1) 'Missing-input strengthening was not preserved.'
    Write-Output 'P10.2 independent comparator self-test passed: equivalence, three visible strengthenings and one isolated weakening.'
}
finally {
    if ([IO.Directory]::Exists($root)) { Remove-Item -LiteralPath $root -Recurse -Force }
}
