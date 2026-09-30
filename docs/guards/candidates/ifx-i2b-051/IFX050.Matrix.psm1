# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: the independent-matrix
# classification, transcribed from candidates/ifx-rebind-116/Test-IFX116IndependentMatrix.ps1 (unchanged). For each
# module it proves a clean (C), a prerequisite-missing (M) and a zero-subject (Z) result, and for each blocking rule a
# violation (V) from a fixture not used by another rule; it also requires each advisory rule to be projected.
Set-StrictMode -Version Latest

function Get-IFX050Prop($Object, [string]$Name) {
    if ($null -eq $Object) { return }
    if ($Object -is [System.Collections.IDictionary]) { if ($Object.Contains($Name)) { return $Object[$Name] }; return }
    $p = $Object.PSObject.Properties[$Name]; if ($null -eq $p) { return }; $p.Value
}

function Read-IFX050Captures([string[]]$Files) {
    $captures = [Collections.Generic.List[object]]::new()
    foreach ($file in $Files) {
        foreach ($line in Get-Content -LiteralPath $file) {
            if (-not $line.Trim()) { continue }
            $record = $line | ConvertFrom-Json -Depth 100
            try { $result = $record.output | ConvertFrom-Json -Depth 100 } catch { continue }
            $captures.Add([ordered]@{ moduleId = [string]$record.moduleId; fixtureId = [IO.Path]::GetFileName([string]$record.targetRoot); fixtureSha256 = [string]$record.fixtureSha256; inputSha256 = [string]$record.inputSha256
                processExit = [int]$record.exitCode; status = [string](Get-IFX050Prop $result 'status'); exitCategory = [string](Get-IFX050Prop $result 'exitCategory')
                findings = @(Get-IFX050Prop $result 'findings'); coverage = @(Get-IFX050Prop $result 'coverage')
                targetInvariant = ($null -eq $record.targetBefore -or [string]$record.targetBefore -ceq [string]$record.targetAfter) })
        }
    }
    , $captures.ToArray()
}

function Get-IFX050MatrixCases {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Inventory, [Parameter(Mandatory)]$Contract, [Parameter(Mandatory)][object[]]$Captures, [string[]]$Modules)
    $blockingAll = @($Inventory.rules | Where-Object severity -CEQ 'blocking'); $advisory = @($Inventory.rules | Where-Object severity -CEQ 'advisory')
    $gaps = [Collections.Generic.List[object]]::new(); $matrix = [Collections.Generic.List[object]]::new(); $used = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($module in $Inventory.modules) {
        $id = [string]$module.id; if ($Modules -and $Modules -cnotcontains $id) { continue }
        $blockingRules = @($blockingAll | Where-Object moduleId -CEQ $id); $ownedClaims = @($blockingRules.claimId | Sort-Object -Unique)
        $rows = @($Captures | Where-Object { $_.moduleId -ceq $id }); $mc = @($Contract.modules | Where-Object id -CEQ $id)[0]
        $clean = @($rows | Where-Object { $_.processExit -eq 0 -and $_.status -ceq 'pass' -and @($_.findings).Count -eq 0 -and @($_.coverage | Where-Object { $_.claimId -in $ownedClaims -and $_.matched -ge $_.minimum }).Count -eq $ownedClaims.Count -and $_.targetInvariant })
        if ($clean.Count -eq 0) { $gaps.Add([ordered]@{ id = "$id/C"; reason = 'No clean result with non-vacuous coverage for every owned blocking claim.' }) } else { $r = $clean[0]; $matrix.Add([ordered]@{ id = "$id/C"; kind = 'clean'; moduleId = $id; ruleId = $null; claimIds = $ownedClaims; fixtureId = $r.fixtureId; fixtureSha256 = $r.fixtureSha256; expected = [ordered]@{ processExit = 0; status = 'pass'; exitCategory = 'success' }; actual = [ordered]@{ processExit = $r.processExit; status = $r.status; exitCategory = $r.exitCategory }; status = 'pass' }) }
        $missing = @($rows | Where-Object { $_.processExit -eq 0 -and $_.status -ceq 'error' -and $_.exitCategory -ceq 'prerequisite-missing' -and @($_.findings).Count -eq 0 -and $_.targetInvariant })
        if ($missing.Count -eq 0) { $gaps.Add([ordered]@{ id = "$id/M"; reason = 'No prerequisite-missing result with zero findings.' }) } else { $r = $missing[0]; $matrix.Add([ordered]@{ id = "$id/M"; kind = 'missing'; moduleId = $id; ruleId = $null; claimIds = $ownedClaims; fixtureId = $r.fixtureId; fixtureSha256 = $r.fixtureSha256; expected = [ordered]@{ processExit = 0; status = 'error'; exitCategory = 'prerequisite-missing' }; actual = [ordered]@{ processExit = $r.processExit; status = $r.status; exitCategory = $r.exitCategory }; status = 'pass' }) }
        $zero = switch ([string]$mc.zeroStrategy) {
            'enumerated-zero' { @($rows | Where-Object { $r = $_; if ($r.processExit -ne 0 -or $r.status -cne 'fail' -or $r.exitCategory -cne 'findings-blocking' -or -not $r.targetInvariant) { return $false }; $z = @($r.coverage | Where-Object { $_.claimId -in $ownedClaims -and $_.matched -eq 0 -and $_.minimum -gt 0 } | ForEach-Object claimId | Sort-Object -Unique); return (($z -join ',') -ceq ($ownedClaims -join ',')) }) }
            'fixed-checklist-zero' { @($rows | Where-Object { $r = $_; if ($r.processExit -ne 0 -or $r.status -cne 'fail' -or $r.exitCategory -cne 'findings-blocking' -or -not $r.targetInvariant) { return $false }; $f = @($r.findings | Where-Object { $_.ruleId -ceq $mc.zeroFinding.ruleId -and $_.subject -ceq $mc.zeroFinding.subject -and $_.evidenceKind -ceq $mc.zeroFinding.evidenceKind -and $_.detectorId -ceq $id }); $c = @($r.coverage | Where-Object { $_.claimId -in $ownedClaims -and $_.minimum -gt 0 } | ForEach-Object claimId | Sort-Object -Unique); return ($f.Count -gt 0 -and ($c -join ',') -ceq ($ownedClaims -join ',')) }) }
            'integrity-zero' { @($rows | Where-Object { $r = $_; if ($r.processExit -ne 0 -or $r.status -cne 'error' -or $r.exitCategory -cne $mc.zeroExitCategory -or @($r.findings).Count -ne 0 -or -not $r.targetInvariant) { return $false }; $z = @($r.coverage | Where-Object { $_.claimId -in $ownedClaims -and $_.matched -eq 0 -and $_.minimum -gt 0 } | ForEach-Object claimId | Sort-Object -Unique); return (($z -join ',') -ceq ($ownedClaims -join ',')) }) }
            default { throw "Unknown zero strategy: $id/$($mc.zeroStrategy)" }
        }
        $zero = @($zero)
        if ($zero.Count -eq 0) { $gaps.Add([ordered]@{ id = "$id/Z"; reason = "No $($mc.zeroStrategy) result covering every owned blocking claim." }) } else { $r = $zero[0]; $matrix.Add([ordered]@{ id = "$id/Z"; kind = 'zero'; strategy = $mc.zeroStrategy; moduleId = $id; ruleId = $null; claimIds = $ownedClaims; fixtureId = $r.fixtureId; fixtureSha256 = $r.fixtureSha256; expected = [ordered]@{ processExit = 0; status = $(if ($mc.zeroStrategy -ceq 'integrity-zero') { 'error' } else { 'fail' }); exitCategory = $(if ($mc.zeroStrategy -ceq 'integrity-zero') { 'integrity-failure' } else { 'findings-blocking' }) }; actual = [ordered]@{ processExit = $r.processExit; status = $r.status; exitCategory = $r.exitCategory }; status = 'pass' }) }
        foreach ($rule in $blockingRules) {
            $o = @($Contract.ruleOverrides | Where-Object { $_.moduleId -ceq $id -and $_.ruleId -ceq $rule.ruleId })
            $outcome = if ($o.Count) { [string]$o[0].outcome } else { [string]$Contract.defaultRuleContract.outcome }
            $coverageContract = if ($o.Count) { [string]$o[0].coverage } else { [string]$Contract.defaultRuleContract.coverage }
            $allowed = if ($o.Count) { @($o[0].allowedRuleIds | Sort-Object -Unique) } else { @([string]$rule.ruleId) }
            if ($outcome -ceq 'integrity-failure') { $v = @($rows | Where-Object { $_.processExit -eq 0 -and $_.status -ceq 'error' -and $_.exitCategory -ceq 'integrity-failure' -and @($_.findings).Count -eq 0 -and $_.targetInvariant }) }
            else { $v = @($rows | Where-Object { $r = $_; if ($r.processExit -ne 0 -or $r.status -cne 'fail' -or $r.exitCategory -cne 'findings-blocking' -or -not $r.targetInvariant) { return $false }; $ids = @($r.findings | Where-Object { $_.ruleId -in @($blockingRules.ruleId) } | ForEach-Object ruleId | Sort-Object -Unique); $f = @($r.findings | Where-Object ruleId -CEQ $rule.ruleId); $cov = @($r.coverage | Where-Object claimId -CEQ $rule.claimId); $covOk = $cov.Count -eq 1 -and ($coverageContract -ceq 'finding-proves-evaluation' -or $cov[0].matched -gt 0); return (($ids -join ',') -ceq ($allowed -join ',') -and $f.Count -gt 0 -and @($f | Where-Object { [string]$_.subject -and [string]$_.detectorId -and [string]$_.evidenceKind }).Count -eq $f.Count -and $covOk) }) }
            $v = @($v | Where-Object { -not $used.Contains([string]$_.fixtureSha256) })
            if ($v.Count -eq 0) { $gaps.Add([ordered]@{ id = "$id/V/$($rule.ruleId)"; reason = "No independent result satisfies outcome $outcome, coverage $coverageContract and the allowed rule set $($allowed -join ',')." }) }
            else { $r = $v[0]; [void]$used.Add([string]$r.fixtureSha256); $f = @($r.findings | Where-Object ruleId -CEQ $rule.ruleId); $matrix.Add([ordered]@{ id = "$id/V/$($rule.ruleId)"; kind = 'violation'; outcome = $outcome; coverageContract = $coverageContract; allowedRuleIds = $allowed; moduleId = $id; ruleId = $rule.ruleId; claimIds = @($rule.claimId); fixtureId = $r.fixtureId; fixtureSha256 = $r.fixtureSha256; expected = [ordered]@{ processExit = 0; status = $(if ($outcome -ceq 'integrity-failure') { 'error' } else { 'fail' }); exitCategory = $outcome }; actual = [ordered]@{ processExit = $r.processExit; status = $r.status; exitCategory = $r.exitCategory; subject = $(if ($f.Count) { $f[0].subject } else { $null }); detectorId = $(if ($f.Count) { $f[0].detectorId } else { $null }); evidenceKind = $(if ($f.Count) { $f[0].evidenceKind } else { $null }) }; status = 'pass' }) }
        }
    }
    foreach ($rule in $advisory) {
        if ($Modules -and $Modules -cnotcontains [string]$rule.moduleId) { continue }
        $rows = @($Captures | Where-Object { $_.moduleId -ceq $rule.moduleId }); if (@($rows | ForEach-Object { @($_.findings) } | Where-Object ruleId -CEQ $rule.ruleId).Count -eq 0) { $gaps.Add([ordered]@{ id = "$($rule.moduleId)/A/$($rule.ruleId)"; reason = 'Advisory companion was not projected.' }) }
    }
    [ordered]@{ cases = @($matrix.ToArray() | Sort-Object { $_.id }); gaps = @($gaps.ToArray()) }
}

Export-ModuleMember -Function Get-IFX050Prop, Read-IFX050Captures, Get-IFX050MatrixCases
