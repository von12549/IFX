# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-3: the suite for one ifx_profile
# 0.5.0-a module successor. The Target is a clean clone of IFX; each case applies its edits, runs the adapter with the
# same stage input the Host builds, checks that the adapter left the Target unchanged, and restores the clone.
#
# Cases (A1-2 suite rule):
# - clean: the unedited clone passes with coverage, twice with identical results;
# - benign-*: a harmless edit of each file whose pin 0.5.0-a drops still passes;
# - governance-*: an edit of each file whose pin 0.5.0-a keeps is still integrity-failure;
# - the module's rule-breaking edits (suites/<id>.cases.json, taken from the 0.4.4 suite) still block.
# A synthetic single-module bundle is then composed on the published 1.1.6 base, and the installed Host runs Post on
# the clean clone. A lock consumer gets a fresh EvidenceRoot per case, staged from the recorded producer runs, and the
# generated lock cases (missing, forged, tampered, other commit, expired).
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ModuleId,
    [Parameter(Mandatory)][string]$CloneRoot,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$ExpectedArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$ExpectedPackageHash = 'a09469f77956190fbffa827ff5b7da2a63b615d66bf47a86ad0d17c7207bc825',
    [switch]$SkipHost,
    # Lock consumers: the record of the producer runs on CloneRoot (Invoke-IFX050EvidenceProducers.ps1 -Phase Produce).
    [string]$ProductionRecord
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { Get-IFX050Sha256 $Path }
function Invoke-CloneGit([string[]]$Arguments) { $o = @(& git -C $clone @Arguments 2>&1); if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($o -join '; ')" }; $o }

$spec = Get-IFX050SpecModule $ModuleId
Assert ($spec.disposition -notcontains 'unchanged') "Module is unchanged in 0.5.0-a: $ModuleId"
$packageRoot = $PSScriptRoot
$moduleRoot = Get-IFX050ModuleRoot $ModuleId
$manifestPath = Join-Path $moduleRoot 'module.json'
$adapterPath = Join-Path $moduleRoot 'adapter.ps1'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 50
$basePackage = Join-Path $BaseInstallRoot 'package'

# 1. Module identity against the published 1.1.6 contracts and the change specification.
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $basePackage 'core/contracts/module.schema.json') -ErrorAction Stop) 'Module schema failed.'
Assert ($manifest.id -ceq $ModuleId -and $manifest.version -ceq [string]$spec.newVersion) "Module identity or version drift: $($manifest.version)"
Assert ((Hash $adapterPath) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $packageRoot $manifest.dependencyLock.path)) -ceq $manifest.dependencyLock.sha256) 'Adapter or dependency-lock hash drift.'
foreach ($a in $manifest.authorities) { Assert ((Hash (Join-Path $packageRoot $a.path)) -ceq $a.sha256) "Module authority drift: $($a.id)" }

# 2. The Target clone.
$clone = [IO.Path]::GetFullPath($CloneRoot)
Assert ([IO.Directory]::Exists((Join-Path $clone '.git'))) "CloneRoot is not a Git clone: $clone"
$head = ([string]@(Invoke-CloneGit @('rev-parse', 'HEAD'))[0]).Trim()
Assert (@(Invoke-CloneGit @('status', '--porcelain', '--untracked-files=all')).Count -eq 0) 'CloneRoot must be clean.'
$config = New-IFX050ModuleConfig $ModuleId -TargetRoot $clone
Assert (Test-Json -Json ($config | ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'
$profile044 = Get-Content -LiteralPath 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.4.4/package/profiles/catalog/ifx_profile/profile.json' -Raw | ConvertFrom-Json -Depth 100
$relativeRoots = @($profile044.projectIdentity.relativeRoots)
$evidence = [IO.Path]::GetFullPath($EvidenceRoot)
$runRoot = Join-Path $evidence ("$ModuleId-" + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)

$lockGate = if ($spec.disposition -contains 'lock-binding') { [string]$spec.lockBinding.gate } else { $null }
if ($lockGate) { Assert ($ProductionRecord -and (Test-Path -LiteralPath $ProductionRecord)) 'A lock consumer needs -ProductionRecord.' }
$script:caseEvidence = $null
function Stage-Evidence([string]$Dir) {
    $o = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Invoke-IFX050EvidenceProducers.ps1') -Phase Stage -TargetRoot $clone -RunRecordPath $ProductionRecord -EvidenceRoot $Dir 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Staging failed: $($o -join '; ')"
}
function Update-Staging([string]$Dir, [scriptblock]$Change) {
    $p = Join-Path $Dir 'locks/staging.json'; $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -AsHashtable -Depth 30
    & $Change $j
    Write-IFX050Json $p $j
}
function Invoke-Adapter {
    $state = Join-Path $runRoot 'state'; $ev = if ($script:caseEvidence) { $script:caseEvidence } else { Join-Path $runRoot 'evidence' }
    [void][IO.Directory]::CreateDirectory($state); [void][IO.Directory]::CreateDirectory($ev)
    $env:V4_STAGE_INPUT_JSON = [ordered]@{ formatVersion = 1; stage = 'post'; targetRoot = $clone; packageRoot = $packageRoot; stateRoot = $state; evidenceRoot = $ev
        projectId = 'ifx'; runId = [guid]::NewGuid().ToString('N'); relativeRoots = $relativeRoots; config = $config } | ConvertTo-Json -Depth 60 -Compress
    $before = @(Invoke-CloneGit @('status', '--porcelain', '--untracked-files=all')) -join "`n"
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapterPath 2>&1)
    $exit = $LASTEXITCODE
    Remove-Item Env:V4_STAGE_INPUT_JSON
    Assert ($exit -eq 0) "Adapter process failed ($exit): $($output -join "`n")"
    Assert ((@(Invoke-CloneGit @('status', '--porcelain', '--untracked-files=all')) -join "`n") -ceq $before) 'The adapter changed the Target.'
    $result = ($output -join "`n") | ConvertFrom-Json -Depth 100
    Assert (Test-Json -Json ($result | ConvertTo-Json -Depth 60 -Compress) -SchemaFile (Join-Path $moduleRoot 'result.schema.json') -ErrorAction Stop) 'Result schema failed.'
    $result
}
function Restore-Clone {
    Remove-Junctions
    [void](Invoke-CloneGit @('checkout', '--quiet', '--', '.'))
    [void](Invoke-CloneGit @('clean', '-fdq'))
    Assert (@(Invoke-CloneGit @('status', '--porcelain', '--untracked-files=all')).Count -eq 0) 'CloneRoot could not be restored.'
}
function Select-TreeFile([string]$Roots) {
    # The first file (ordinal) under the first root, preferring the file types the modules read.
    foreach ($r in ($Roots -split ', ')) {
        $full = Join-Path $clone $r
        if ([IO.File]::Exists($full)) { return $r }
        if (-not [IO.Directory]::Exists($full)) { continue }
        $files = [Collections.Generic.List[string]]::new()
        foreach ($f in (Get-ChildItem -LiteralPath $full -File -Recurse -Force | Where-Object { $_.Extension -in @('.cs', '.json', '.md', '.yaml', '.yml', '.csproj', '.mmd', '.svg') -and $_.FullName -notmatch '[\\/](bin|obj|node_modules)[\\/]' })) {
            $files.Add([IO.Path]::GetRelativePath($clone, $f.FullName).Replace('\', '/'))
        }
        $files.Sort([StringComparer]::Ordinal)
        if ($files.Count -gt 0) { return $files[0] }
    }
    throw "No file under $Roots"
}
function Add-HarmlessText([string]$Relative) {
    # Content-neutral for every reader: a comment or a trailing newline, by file type.
    $full = Join-Path $clone $Relative
    $suffix = switch -regex ($Relative) {
        '\.(cs|ts|tsx|js)$' { "`n// ifx-050a harmless edit`n" }
        '\.(md|csproj|props|targets|xml)$' { "`n<!-- ifx-050a harmless edit -->`n" }
        # YAML files here may hold JSON (the G03 catalog is read as JSON), so they only gain a trailing newline.
        '(CODEOWNERS|\.sln)$' { "`n# ifx-050a harmless edit`n" }
        default { "`n" }
    }
    [IO.File]::AppendAllText($full, $suffix)
}
function Add-Waiver($Catalog, [string] $Category, [string] $Expires) {
    # Transcribed from the 0.4.4 G03 governance-core suite (used by jsonObject edits).
    $Catalog.waivers = @([pscustomobject]@{
        id = 'W-TEST'; owner = 'xiaolong-feng'; reason = 'test'; risk = 'test'; createdAt = '2026-09-01'
        expiresAt = $Expires; removalCondition = 'remove'; linkedPlanItem = 'test'; category = $Category
    })
}
$script:junctions = [Collections.Generic.List[string]]::new()
function Remove-Junctions {
    # A junction is removed as a link only (non-recursive), never through its target.
    foreach ($j in $script:junctions) { if ([IO.Directory]::Exists($j)) { [IO.Directory]::Delete($j, $false) } }
    $script:junctions.Clear()
}
function Apply-Edit($Edit) {
    if ($Edit.PSObject.Properties.Name -contains 'staging') {
        # Changes locks/staging.json ($j) of the case's staged EvidenceRoot.
        Update-Staging $script:caseEvidence ([scriptblock]::Create([string]$Edit.staging))
        return
    }
    if ($Edit.PSObject.Properties.Name -contains 'staged') {
        # Edits a staged evidence file; reseal records the new lock hash in staging.json, so deeper checks decide.
        $full = Join-Path $script:caseEvidence ([string]$Edit.staged)
        if ($Edit.PSObject.Properties.Name -contains 'remove' -and $Edit.remove) { Assert ([IO.File]::Exists($full)) "Staged subject absent: $($Edit.staged)"; [IO.File]::Delete($full) }
        elseif ($Edit.PSObject.Properties.Name -contains 'append') { [IO.File]::AppendAllText($full, [string]$Edit.append) }
        elseif ($Edit.PSObject.Properties.Name -contains 'json') { $j = Get-Content -LiteralPath $full -Raw | ConvertFrom-Json -AsHashtable -Depth 100; & ([scriptblock]::Create([string]$Edit.json)); Write-IFX050Json $full $j }
        else { throw "Unknown staged edit: $($Edit.staged)" }
        if ($Edit.PSObject.Properties.Name -contains 'reseal' -and $Edit.reseal) {
            $gateName = ([string]$Edit.staged).Split('/')[1]; $sha = Hash $full
            Update-Staging $script:caseEvidence { param($j) foreach ($g in $j.gates) { if ($g.gate -ceq $gateName) { $g.lockSha256 = $sha } } }.GetNewClosure()
        }
        return
    }
    if ($Edit.PSObject.Properties.Name -contains 'jsonObject') {
        # A 0.4.4 suite mutation over the parsed document ($source), written back as that suite wrote it.
        $full = Join-Path $clone ([string]$Edit.path)
        $source = Get-Content -LiteralPath $full -Raw | ConvertFrom-Json -Depth 100
        & ([scriptblock]::Create([string]$Edit.jsonObject))
        [IO.File]::WriteAllText($full, (($source | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
        return
    }
    if ($Edit.PSObject.Properties.Name -contains 'mkdir' -and $Edit.mkdir) {
        [void][IO.Directory]::CreateDirectory((Join-Path $clone ([string]$Edit.path)))
        return
    }
    if ($Edit.PSObject.Properties.Name -contains 'removeDir' -and $Edit.removeDir) {
        $full = [IO.Path]::GetFullPath((Join-Path $clone ([string]$Edit.path)))
        Assert ($full.StartsWith($clone + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and [IO.Directory]::Exists($full)) "removeDir subject invalid: $($Edit.path)"
        Remove-Item -LiteralPath $full -Recurse -Force
        return
    }
    if ($Edit.PSObject.Properties.Name -contains 'junction' -and $Edit.junction) {
        # Replaces a directory with a junction to a copy of it under the run root (the linked-path control).
        $full = [IO.Path]::GetFullPath((Join-Path $clone ([string]$Edit.path)))
        $copy = Join-Path $runRoot ('junction-target-' + [guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $full -Destination $copy -Recurse
        Remove-Item -LiteralPath $full -Recurse -Force
        [void](New-Item -ItemType Junction -Path $full -Target $copy)
        $script:junctions.Add($full)
        return
    }
    if ($Edit.PSObject.Properties.Name -contains 'root') {
        # A multi-file edit: every file under root matching filter (and pathMatch) that contains find.
        $hits = 0
        $except = @(if ($Edit.PSObject.Properties.Name -contains 'except') { @($Edit.except) })
        foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $clone ([string]$Edit.root)) -Recurse -File -Filter ([string]$Edit.filter) | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' -and (-not ($Edit.PSObject.Properties.Name -contains 'pathMatch') -or $_.FullName -match [string]$Edit.pathMatch) -and $except -notcontains [IO.Path]::GetRelativePath($clone, $_.FullName).Replace('\', '/') })) {
            if ($Edit.PSObject.Properties.Name -contains 'remove' -and $Edit.remove) { Remove-Item -LiteralPath $f.FullName; $hits++; continue }
            $body = [IO.File]::ReadAllText($f.FullName)
            if ($body.Contains([string]$Edit.find)) { [IO.File]::WriteAllText($f.FullName, $body.Replace([string]$Edit.find, [string]$Edit.replace), [Text.UTF8Encoding]::new($false)); $hits++ }
        }
        Assert ($hits -gt 0) "Multi-file edit matched nothing under $($Edit.root)"
        return
    }
    $full = Join-Path $clone ([string]$Edit.path)
    if ($Edit.PSObject.Properties.Name -contains 'remove' -and $Edit.remove) { Assert ([IO.File]::Exists($full)) "Edit subject absent: $($Edit.path)"; Remove-Item -LiteralPath $full; return }
    if ($Edit.PSObject.Properties.Name -contains 'write') { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full)); [IO.File]::WriteAllText($full, [string]$Edit.write, [Text.UTF8Encoding]::new($false)); return }
    if ($Edit.PSObject.Properties.Name -contains 'append') { [IO.File]::AppendAllText($full, [string]$Edit.append); return }
    if ($Edit.PSObject.Properties.Name -contains 'json') {
        # A structured JSON edit transcribed from the 0.4.4 suite: the expression changes $j, which is written back.
        $j = Get-Content -LiteralPath $full -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        & ([scriptblock]::Create([string]$Edit.json))
        Write-IFX050Json $full $j
        return
    }
    $body = [IO.File]::ReadAllText($full)
    Assert ($body.Contains([string]$Edit.find)) "Edit subject absent in $($Edit.path): $($Edit.find)"
    [IO.File]::WriteAllText($full, $body.Replace([string]$Edit.find, [string]$Edit.replace), [Text.UTF8Encoding]::new($false))
}

# 3. Cases.
$cases = [Collections.Generic.List[object]]::new()
$cases.Add([pscustomobject]@{ id = 'clean'; kind = 'clean'; edits = @(); status = 'pass'; category = 'success' })
$catalogPath = Join-Path $PSScriptRoot "suites/$ModuleId.cases.json"
Assert (Test-Path -LiteralPath $catalogPath) "Rule-breaking case catalog missing: suites/$ModuleId.cases.json"
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -Depth 30
# A live file that another live file binds by content (for example a release manifest naming its hash) cannot change
# alone: the catalog states the expected outcome of the lone edit and gives the consistent edit as a rule case.
$overrides = @{}
if ($catalog.PSObject.Properties.Name -contains 'benignExpectations') { foreach ($o in $catalog.benignExpectations) { $overrides[[string]$o.path] = $o } }
$n = 0
foreach ($b in @($spec.bindings | Where-Object { $_.action -cne 'keep-pin' })) {
    $n++; $file = Select-TreeFile ([string]$b.path)
    $o = if ($overrides.ContainsKey($file)) { $overrides[$file] } else { $null }
    $cases.Add([pscustomobject]@{ id = "benign-$n"; kind = 'benign'; binding = $b.field; edits = @([pscustomobject]@{ path = $file; harmless = $true })
        status = $(if ($o) { $o.status } else { 'pass' }); category = $(if ($o) { $o.category } else { 'success' }); rule = $(if ($o -and $o.PSObject.Properties.Name -contains 'rule') { $o.rule } else { $null }) })
}
$n = 0
foreach ($b in @($spec.bindings | Where-Object { $_.action -ceq 'keep-pin' })) {
    $n++; $file = Select-TreeFile ([string]$b.path)
    $cases.Add([pscustomobject]@{ id = "governance-$n"; kind = 'governance'; binding = $b.field; edits = @([pscustomobject]@{ path = $file; harmless = $true }); status = 'error'; category = 'integrity-failure' })
}
Assert ($catalog.formatVersion -eq 1 -and $catalog.moduleId -ceq $ModuleId -and @($catalog.cases).Count -ge 1) 'Case catalog identity drift.'
foreach ($c in $catalog.cases) { $cases.Add([pscustomobject]@{ id = $c.id; kind = 'rule'; edits = @($c.edits); status = $c.status; category = $c.category; rule = $(if ($c.PSObject.Properties.Name -contains 'rule') { $c.rule } else { $null }); repin = ($c.PSObject.Properties.Name -contains 'repin' -and $c.repin); configSet = $(if ($c.PSObject.Properties.Name -contains 'configSet') { [string]$c.configSet } else { $null }); code = $(if ($c.PSObject.Properties.Name -contains 'code') { [string]$c.code } else { $null }) }) }
if ($lockGate) {
    # Generated lock cases: every lock consumer rejects missing, forged, tampered, foreign-commit and expired evidence.
    $lock = "locks/$lockGate/evidence-lock.json"
    $evidenceFile = @{ solution = 'quality/summary.json'; assembly = 'quality/assembly.json'; frontend = 'quality/summary.json'; database = 'specialized/summary.json'; type = 'assembly-manifest.json' }
    $expire = if ($lockGate -in @('type', 'graph')) { '$j.createdAt=[DateTimeOffset]::UtcNow.AddHours(-2).ToString(''o'');$j.expiresAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString(''o'')' } else { '$j.startedAt=[DateTimeOffset]::UtcNow.AddHours(-26).ToString(''o'');$j.completedAt=[DateTimeOffset]::UtcNow.AddHours(-25).ToString(''o'')' }
    $generated = @(
        ,@('lock-missing-staging', @([pscustomobject]@{ staged = 'locks/staging.json'; remove = $true }), 'error', 'prerequisite-missing')
        ,@('lock-missing', @([pscustomobject]@{ staged = $lock; remove = $true }), 'error', 'prerequisite-missing')
        ,@('lock-forged-producer', @([pscustomobject]@{ staging = "foreach(`$x in `$j.gates){if(`$x.gate -ceq '$lockGate'){`$x.producer.scriptSha256='0'*64}}" }), 'error', 'integrity-failure')
        ,@('lock-tampered', @([pscustomobject]@{ staged = $lock; append = ' ' }), 'error', 'integrity-failure')
        ,@('lock-other-commit', @([pscustomobject]@{ staged = $lock; json = '$j.targetCommit=''0''*40'; reseal = $true }), 'error', 'integrity-failure')
        ,@('lock-expired', @([pscustomobject]@{ staged = $lock; json = $expire; reseal = $true }), 'error', 'integrity-failure')
    )
    if ($evidenceFile.ContainsKey($lockGate)) { $generated += ,@('lock-tampered-evidence', @([pscustomobject]@{ staged = "locks/$lockGate/$($evidenceFile[$lockGate])"; append = ' ' }), 'error', 'integrity-failure') }
    foreach ($g in $generated) { $cases.Add([pscustomobject]@{ id = $g[0]; kind = 'lock'; edits = @($g[1]); status = $g[2]; category = $g[3] }) }
}
$policyForRepin = Get-Content -LiteralPath (Join-Path $moduleRoot 'policy.json') -Raw | ConvertFrom-Json -Depth 100
function Get-RepinnedConfig($Case) {
    # A governance change is delivered with a new bundle: the kept Profile binding of each edited governance file is
    # recomputed from the change specification (authority entries and named fields), so the module's content checks
    # decide the outcome. Edits of live files in the same case need no repin; at least one edit must hit a kept pin.
    $copy = $config | ConvertTo-Json -Depth 60 | ConvertFrom-Json -AsHashtable -Depth 60
    $hits = 0
    foreach ($e in @($Case.edits | Where-Object { $_.PSObject.Properties.Name -contains 'path' })) {
        $full = Join-Path $clone ([string]$e.path)
        $value = if ([IO.File]::Exists($full)) { Get-IFX050PinSha256 $full } else { '0' * 64 }
        foreach ($b in @($spec.bindings | Where-Object { $_.action -ceq 'keep-pin' -and $_.path -ceq [string]$e.path })) {
            if ($b.field -match '^authorityHashes\[(.+)\]$') {
                $key = $Matches[1]
                $all = @($copy.authorityHashes)
                for ($i = 0; $i -lt $all.Count; $i++) {
                    if (($all[$i].Contains('id') -and [string]$all[$i].id -ceq $key) -or (-not $all[$i].Contains('id') -and [string]$i -ceq $key)) { $all[$i].sha256 = $value; $hits++ }
                }
            } elseif ($copy.Contains([string]$b.field)) { $copy[[string]$b.field] = $value; $hits++ }
        }
    }
    Assert ($hits -gt 0) "repin: no edited file is a kept governance binding ($($Case.id))"
    $copy
}

$results = [Collections.Generic.List[object]]::new()
try {
    foreach ($case in $cases) {
        if ($lockGate) { $script:caseEvidence = Join-Path $runRoot "evidence-$($case.id)"; Stage-Evidence $script:caseEvidence }
        foreach ($e in $case.edits) { if ($e.PSObject.Properties.Name -contains 'harmless') { Add-HarmlessText ([string]$e.path) } else { Apply-Edit $e } }
        $savedConfig = $config
        if ($case.PSObject.Properties.Name -contains 'repin' -and $case.repin) { $config = Get-RepinnedConfig $case }
        if ($case.PSObject.Properties.Name -contains 'configSet' -and $case.configSet) {
            # A governance tree update delivered with a new bundle: the expression recomputes a kept Profile field ($c).
            $c = $config | ConvertTo-Json -Depth 60 | ConvertFrom-Json -AsHashtable -Depth 60
            & ([scriptblock]::Create([string]$case.configSet))
            $config = $c
        }
        try { $result = Invoke-Adapter } finally { $config = $savedConfig }
        $ok = $result.status -ceq $case.status -and $result.exitCategory -ceq $case.category
        if ($ok -and $case.kind -ceq 'rule' -and $case.PSObject.Properties.Name -contains 'code' -and $case.code) { $ok = @($result.findings | Where-Object { [string]$_.subject -ceq [string]$case.code -or ([string]$_.subject).StartsWith([string]$case.code + ':', [StringComparison]::Ordinal) }).Count -ge 1 }
        if ($ok -and $case.kind -in @('rule', 'benign') -and $null -ne $case.rule) { $ok = @($result.findings | Where-Object { $_.ruleId -ceq $case.rule }).Count -ge 1 }
        if ($ok -and $case.status -ceq 'pass') { $ok = @($result.coverage | Where-Object { $_.matched -lt $_.minimum }).Count -eq 0 }
        if ($ok -and $case.kind -ceq 'clean') { $again = Invoke-Adapter; $ok = ($again | ConvertTo-Json -Depth 60 -Compress) -ceq ($result | ConvertTo-Json -Depth 60 -Compress) }
        $results.Add([ordered]@{ id = $case.id; kind = $case.kind; binding = $(if ($case.PSObject.Properties.Name -contains 'binding') { $case.binding } else { $null })
            edited = @($case.edits | ForEach-Object { $n = $_.PSObject.Properties.Name; if ($n -contains 'path') { $_.path } elseif ($n -contains 'root') { "$($_.root)/**/$($_.filter)" } elseif ($n -contains 'staged') { "EvidenceRoot/$($_.staged)" } else { 'EvidenceRoot/locks/staging.json' } }); expected = "$($case.status)/$($case.category)"; actual = "$($result.status)/$($result.exitCategory)"
            findings = @($result.findings | ForEach-Object { "$($_.ruleId):$($_.subject)" } | Select-Object -First 5)
            message = $(if ($result.PSObject.Properties.Name -contains 'message') { $result.message } else { $null }); pass = $ok })
        Restore-Clone
    }
} finally { Restore-Clone }

# 4. Synthetic composition on the published 1.1.6 base and installed-Host Post on the clean clone.
$hostRecord = $null
if (-not $SkipHost) {
    Assert ((Hash $BaseArchivePath) -ceq $ExpectedArchiveSha256) '1.1.6 archive drift.'
    $baseCheck = & pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage | ConvertFrom-Json -Depth 50
    Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq $ExpectedPackageHash) '1.1.6 Package check failed.'
    $bundleRoot = Join-Path $runRoot 'bundle'; $bundlePackage = Join-Path $bundleRoot 'package'
    $bundleModule = Join-Path $bundlePackage "modules/$ModuleId"; [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bundleModule))
    Copy-Item -LiteralPath $moduleRoot -Destination $bundleModule -Recurse
    $rulePlan = Get-Content -LiteralPath (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 30
    $profileId = 'ifx_050a_fixture'; $profilePath = Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
    Write-IFX050Json $profilePath ([ordered]@{
        formatVersion = 1; id = $profileId; version = '0.1.0'; projectIdentity = [ordered]@{ id = 'ifx-050a-fixture'; relativeRoots = $relativeRoots }
        moduleSelections = @([ordered]@{ id = $ModuleId; versionRange = '>=0.1.0 <1.0.0'; config = $config })
        stageConfiguration = [ordered]@{ bootstrap = [ordered]@{ enabled = $false; modules = @() }; analysis = [ordered]@{ enabled = $false; modules = @() }; pre = [ordered]@{ enabled = $false; modules = @() }; post = [ordered]@{ enabled = $true; modules = @($ModuleId) } }
        rules = @($rulePlan.rules | ForEach-Object { $_.ruleId } | Sort-Object -Unique); baselineRefs = @()
    })
    $files = @(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse | Sort-Object FullName | ForEach-Object { [ordered]@{ path = [IO.Path]::GetRelativePath($bundlePackage, $_.FullName).Replace('\', '/'); sha256 = Hash $_.FullName; size = $_.Length } })
    $cap = $manifest.capabilities
    $ceiling = [ordered]@{ readRoots = @($cap.readRoots); writeRoots = @($cap.writeRoots); processes = @($cap.processes); network = $false; maxTimeoutSeconds = [int]$cap.timeoutSeconds }
    $bundleManifest = Join-Path $bundleRoot 'bundle-manifest.json'
    Write-IFX050Json $bundleManifest ([ordered]@{ formatVersion = 1; id = 'ifx-050a-synthetic-extension'; version = '0.1.0'; compatibleApi = '1.x'; baseVersion = '1.1.6'
        profiles = @([ordered]@{ id = $profileId; version = '0.1.0'; path = "profiles/catalog/$profileId/profile.json"; sha256 = Hash $profilePath })
        modules = @([ordered]@{ id = $ModuleId; version = $manifest.version; manifestPath = "modules/$ModuleId/module.json"; manifestSha256 = Hash (Join-Path $bundleModule 'module.json'); allowedCapabilities = $ceiling }); files = $files })
    $review = Join-Path $runRoot 'synthetic-review.json'
    Write-IFX050Json $review ([ordered]@{ formatVersion = 1; id = '20260929-ifx-050a-synthetic-fixture'; scope = 'synthetic-test-only'; decision = 'accepted'
        acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-050a-synthetic-fixture'; candidateHostVerdictAllowed = $false }
        bundleManifestSha256 = Hash $bundleManifest; baseArchiveSha256 = Hash $BaseArchivePath; moduleCeilings = @([ordered]@{ moduleId = $ModuleId; allowedCapabilities = $ceiling }) })
    $composed = Join-Path $runRoot 'composed'; $receipt = Join-Path $runRoot 'composition.receipt.json'
    $cState = Join-Path $runRoot 'compose-state'; $cEvidence = Join-Path $runRoot 'compose-evidence'; [void][IO.Directory]::CreateDirectory($cState); [void][IO.Directory]::CreateDirectory($cEvidence)
    $out = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $bundleRoot -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $clone -StateRoot $cState -EvidenceRoot $cEvidence -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Composition failed: $($out -join "`n")"
    $hState = Join-Path $runRoot 'host-state'; $hEvidence = Join-Path $runRoot 'host-evidence'; [void][IO.Directory]::CreateDirectory($hState); [void][IO.Directory]::CreateDirectory($hEvidence)
    if ($lockGate) { Stage-Evidence $hEvidence }
    $hOut = @(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $clone --state-root $hState --evidence-root $hEvidence --profile $profileId 2>&1)
    $hResult = ($hOut -join "`n") | ConvertFrom-Json -Depth 100
    Assert (@(Invoke-CloneGit @('status', '--porcelain', '--untracked-files=all')).Count -eq 0) 'Host Post changed the Target.'
    $hostRecord = [ordered]@{ status = $hResult.status; exitCategory = $hResult.exitCategory; coverage = @($hResult.coverage); receiptSha256 = Hash $receipt }
    $results.Add([ordered]@{ id = 'host-post-clean'; kind = 'host'; expected = 'pass/success'; actual = "$($hResult.status)/$($hResult.exitCategory)"; pass = ($hResult.status -ceq 'pass' -and $hResult.exitCategory -ceq 'success') })
}

$failed = @($results | Where-Object { -not $_.pass })
$summary = [ordered]@{
    formatVersion = 1; kind = 'ifx-050a-module-suite'; status = $(if ($failed.Count -eq 0) { 'pass' } else { 'fail' })
    moduleId = $ModuleId; version = $manifest.version; adapterSha256 = $manifest.adapter.sha256; policySha256 = $config.policySha256
    targetCommit = $head; baseVersion = '1.1.6'; caseCatalogSha256 = Hash $catalogPath
    counts = [ordered]@{ total = $results.Count; clean = @($results | Where-Object kind -eq 'clean').Count; benign = @($results | Where-Object kind -eq 'benign').Count
        governance = @($results | Where-Object kind -eq 'governance').Count; rule = @($results | Where-Object kind -eq 'rule').Count; failed = $failed.Count }
    host = $hostRecord; cases = @($results.ToArray())
}
Write-IFX050Json (Join-Path $runRoot 'summary.json') $summary
"$ModuleId $($manifest.version): $($summary.status) ($($results.Count) cases, $($failed.Count) failed) -> $runRoot"
$failed | ForEach-Object { "FAIL $($_.id) [$($_.kind)] expected $($_.expected) actual $($_.actual) $(if ($_.Contains('message')) { $_.message })" }
if ($failed.Count -gt 0) { exit 1 }
