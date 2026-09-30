# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-8b: case-level parity of the
# 0.5.0 C6c independent matrix against the accepted 0.4.4 matrix (I1). Both matrices come from the same matrix
# contract, so every case ID, kind, rule, claim set and expected outcome must be equal and every actual outcome
# (process exit, status, exit category) must be equal. What may differ is the first finding a case reports
# (subject, evidence kind), because the 0.5.0 suites use new fixtures; each such difference is listed with the
# module's change-spec disposition. It also compares the P10.2 replay matrix with the accepted 0.4.4 replay.
[CmdletBinding()]
param(
    [string]$PredecessorCaseManifestPath = 'artifacts/guards/p10-ifx-116/c6c-full/windows/case-manifest.json',
    [string]$PredecessorCaseManifestSha256 = '5a941375c7803b2031fb967f4ed5bebfa754e3419c8887f36c54d27f4b2af65f',
    [string]$CaseManifestPath = 'artifacts/guards/p10-ifx-i2b/a2-051/c6c-full/windows/case-manifest.json',
    [Parameter(Mandatory)][string]$CaseManifestSha256,
    [string]$PredecessorParityMatrixPath = 'artifacts/guards/p10-ifx-116/p10-2-parity-044/parity-matrix.json',
    [string]$PredecessorParityMatrixSha256 = '1d61650695185ed8ad69b3c013f241a63190d0ca5999e0205c7262676bf4ac7c',
    [string]$ParityMatrixPath = 'artifacts/guards/p10-ifx-i2b/a2-051/p10-2-parity-050/parity-matrix.json',
    [string]$ChangeSpecPath = (Join-Path $PSScriptRoot 'change-spec.json'),
    [Parameter(Mandatory)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Read-Pinned([string]$Path, [string]$Sha256, [string]$Label) { $f = Full $Path; if ((Get-IFX050Sha256 $f) -cne $Sha256) { throw "$Label identity mismatch: $f" }; Get-Content -LiteralPath $f -Raw | ConvertFrom-Json -AsHashtable -Depth 100 }
function Canon($Value) { $Value | ConvertTo-Json -Depth 50 -Compress }
$output = Full $OutputPath; if ([IO.File]::Exists($output)) { throw "Output already exists: $output" }

# 1. The 191-case independent matrix.
$old = @{}; foreach ($c in @((Read-Pinned $PredecessorCaseManifestPath $PredecessorCaseManifestSha256 '0.4.4 case manifest').cases)) { $old[[string]$c.id] = $c }
$new = @{}; foreach ($c in @((Read-Pinned $CaseManifestPath $CaseManifestSha256 '0.5.0 case manifest').cases)) { $new[[string]$c.id] = $c }
$spec = Get-Content -LiteralPath (Full $ChangeSpecPath) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$disposition = @{}; foreach ($m in @($spec.modules)) { $disposition[[string]$m.id] = @($m.disposition) }
$gaps = [Collections.Generic.List[object]]::new(); $subjectChanges = [Collections.Generic.List[object]]::new()
foreach ($id in @($old.Keys | Where-Object { -not $new.ContainsKey($_) })) { $gaps.Add([ordered]@{ id = $id; category = 'case-missing-in-050' }) }
foreach ($id in @($new.Keys | Where-Object { -not $old.ContainsKey($_) })) { $gaps.Add([ordered]@{ id = $id; category = 'case-added-in-050' }) }
foreach ($id in @($old.Keys | Where-Object { $new.ContainsKey($_) } | Sort-Object)) {
    $o = $old[$id]; $n = $new[$id]
    foreach ($field in @('kind', 'moduleId', 'ruleId', 'claimIds', 'expected', 'status')) { if ((Canon $o[$field]) -cne (Canon $n[$field])) { $gaps.Add([ordered]@{ id = $id; category = "contract-$field-differs"; old = $o[$field]; new = $n[$field] }) } }
    foreach ($field in @('processExit', 'status', 'exitCategory')) { if ((Canon $o.actual[$field]) -cne (Canon $n.actual[$field])) { $gaps.Add([ordered]@{ id = $id; category = "outcome-$field-differs"; old = $o.actual[$field]; new = $n.actual[$field] }) } }
    $os = [ordered]@{ subject = $o.actual['subject']; detectorId = $o.actual['detectorId']; evidenceKind = $o.actual['evidenceKind'] }
    $ns = [ordered]@{ subject = $n.actual['subject']; detectorId = $n.actual['detectorId']; evidenceKind = $n.actual['evidenceKind'] }
    if ((Canon $os) -cne (Canon $ns)) {
        $d = @($disposition[[string]$n.moduleId])
        $subjectChanges.Add([ordered]@{ id = $id; moduleId = [string]$n.moduleId; disposition = $d; old = $os; new = $ns
            reason = $(if ($d -contains 'unchanged') { 'unchanged module; the supplemental fixture of the 0.5.0 matrix differs from the c6c4 fixture' } else { 'changed module; the 0.5.0 successor suite fixture reports a different first finding for the same rule' }) })
        if ($os.detectorId -cne $ns.detectorId) { $gaps.Add([ordered]@{ id = $id; category = 'detector-differs'; old = $os.detectorId; new = $ns.detectorId }) }
    }
}

# 2. The 52-case P10.2 replay (ten unchanged Pre modules): every row must equal the accepted 0.4.4 row.
$oldMatrix = Read-Pinned $PredecessorParityMatrixPath $PredecessorParityMatrixSha256 '0.4.4 P10.2 matrix'
$newMatrixFile = Full $ParityMatrixPath; $newMatrix = Get-Content -LiteralPath $newMatrixFile -Raw | ConvertFrom-Json -AsHashtable -Depth 100
# Semantic projection as in the I1 comparison: run metadata (paths, timestamps, process and input hashes) excluded.
function Semantic($Row) {
    $current = $Row.v4.currentResult
    [ordered]@{ id = $Row.id; kind = $Row.kind; moduleId = $Row.moduleId; claimIds = @($Row.claimIds); expectedRule = $Row.expectedRule; ownedRules = @($Row.ownedRules); ownedV3Rules = @($Row.ownedV3Rules)
        comparison = $Row.comparison; explanation = $Row.explanation
        v4 = [ordered]@{ status = $current.status; exitCategory = $current.exitCategory; findings = @($current.findings); coverage = @($current.coverage) }
        v3 = [ordered]@{ rules = @($Row.v3.rules); violationCount = $Row.v3.violationCount } }
}
$rowKey = 'cases'
$oldRows = @{}; foreach ($r in @($oldMatrix.cases)) { $oldRows[[string]$r.id] = $r }
$rowDiffs = [Collections.Generic.List[object]]::new()
foreach ($r in @($newMatrix.cases)) {
    $id = [string]$r.id; if (-not $oldRows.ContainsKey($id)) { $rowDiffs.Add([ordered]@{ id = $id; category = 'row-added' }); continue }
    $a = Semantic $oldRows[$id]; $b = Semantic $r
    if ((Canon $a) -cne (Canon $b)) { $rowDiffs.Add([ordered]@{ id = $id; category = 'semantic-row-differs'; old = $a; new = $b }) }
}
if (@($newMatrix.cases).Count -ne @($oldMatrix.cases).Count) { $rowDiffs.Add([ordered]@{ id = '*'; category = 'row-count-differs' }) }
$strengtheningsEqual = (Canon @($oldMatrix.strengthenings)) -ceq (Canon @($newMatrix.strengthenings))
$p102Equal = ($rowDiffs.Count -eq 0 -and [int]$newMatrix.gapCount -eq 0 -and $strengtheningsEqual)

$status = if ($gaps.Count -eq 0 -and $p102Equal) { 'pass' } else { 'fail' }
Write-IFX050Json $output ([ordered]@{ formatVersion = 1; status = $status; step = 'A1-8b'; scope = 'ifx-050a-parity-against-044'
    independentMatrix = [ordered]@{ predecessor = [ordered]@{ path = $PredecessorCaseManifestPath; sha256 = $PredecessorCaseManifestSha256 }; current = [ordered]@{ path = $CaseManifestPath; sha256 = $CaseManifestSha256 }
        caseCount = $new.Count; outcomeGaps = @($gaps); firstFindingChanges = @($subjectChanges)
        rule = 'case IDs, kinds, rules, claims, expected and actual outcomes equal; only the first finding subject or evidence kind may differ, and each difference is listed' }
    p10_2Replay = [ordered]@{ predecessor = [ordered]@{ path = $PredecessorParityMatrixPath; sha256 = $PredecessorParityMatrixSha256 }; current = [ordered]@{ path = $ParityMatrixPath; sha256 = (Get-IFX050Sha256 $newMatrixFile) }
        rowsKey = $rowKey; caseCount = @($newMatrix.cases).Count; gapCount = [int]$newMatrix.gapCount; strengtheningCount = [int]$newMatrix.strengtheningCount; strengtheningsIdentical = $strengtheningsEqual; semanticRowDifferences = @($rowDiffs); equalToPredecessor = $p102Equal } })
Write-Output "A1-8b parity against 0.4.4 $status`: gaps=$($gaps.Count), first-finding changes=$($subjectChanges.Count), P10.2 row differences=$($rowDiffs.Count)"
if ($status -cne 'pass') { exit 1 }
