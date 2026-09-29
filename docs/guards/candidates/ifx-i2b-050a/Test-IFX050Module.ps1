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
# the clean clone.
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
    [switch]$SkipHost
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
$config = New-IFX050ModuleConfig $ModuleId
Assert (Test-Json -Json ($config | ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'

# 2. The Target clone.
$clone = [IO.Path]::GetFullPath($CloneRoot)
Assert ([IO.Directory]::Exists((Join-Path $clone '.git'))) "CloneRoot is not a Git clone: $clone"
$head = ([string]@(Invoke-CloneGit @('rev-parse', 'HEAD'))[0]).Trim()
Assert (@(Invoke-CloneGit @('status', '--porcelain', '--untracked-files=all')).Count -eq 0) 'CloneRoot must be clean.'
$profile044 = Get-Content -LiteralPath 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.4.4/package/profiles/catalog/ifx_profile/profile.json' -Raw | ConvertFrom-Json -Depth 100
$relativeRoots = @($profile044.projectIdentity.relativeRoots)
$evidence = [IO.Path]::GetFullPath($EvidenceRoot)
$runRoot = Join-Path $evidence ("$ModuleId-" + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)

function Invoke-Adapter {
    $state = Join-Path $runRoot 'state'; $ev = Join-Path $runRoot 'evidence'
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
function Apply-Edit($Edit) {
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
        status = $(if ($o) { $o.status } else { 'pass' }); category = $(if ($o) { $o.category } else { 'success' }); rule = $(if ($o) { $o.rule } else { $null }) })
}
$n = 0
foreach ($b in @($spec.bindings | Where-Object { $_.action -ceq 'keep-pin' })) {
    $n++; $file = Select-TreeFile ([string]$b.path)
    $cases.Add([pscustomobject]@{ id = "governance-$n"; kind = 'governance'; binding = $b.field; edits = @([pscustomobject]@{ path = $file; harmless = $true }); status = 'error'; category = 'integrity-failure' })
}
Assert ($catalog.formatVersion -eq 1 -and $catalog.moduleId -ceq $ModuleId -and @($catalog.cases).Count -ge 1) 'Case catalog identity drift.'
foreach ($c in $catalog.cases) { $cases.Add([pscustomobject]@{ id = $c.id; kind = 'rule'; edits = @($c.edits); status = $c.status; category = $c.category; rule = $(if ($c.PSObject.Properties.Name -contains 'rule') { $c.rule } else { $null }); repin = ($c.PSObject.Properties.Name -contains 'repin' -and $c.repin); configSet = $(if ($c.PSObject.Properties.Name -contains 'configSet') { [string]$c.configSet } else { $null }) }) }
$policyForRepin = Get-Content -LiteralPath (Join-Path $moduleRoot 'policy.json') -Raw | ConvertFrom-Json -Depth 100
function Get-RepinnedConfig($Case) {
    # A governance change is delivered with a new bundle: the kept Profile hash of each edited governance authority is
    # recomputed, so the module's content checks (not the pin) decide the outcome.
    # Edits of live files in the same case need no repin; at least one edited file must be a kept authority.
    $copy = $config | ConvertTo-Json -Depth 60 | ConvertFrom-Json -AsHashtable -Depth 60
    $hits = 0
    foreach ($e in @($Case.edits | Where-Object { $_.PSObject.Properties.Name -contains 'path' })) {
        $full = Join-Path $clone ([string]$e.path)
        if ($copy.Contains('authorityHashes') -and $policyForRepin.PSObject.Properties.Name -contains 'authorities') {
            foreach ($a in @($policyForRepin.authorities | Where-Object { $_.path -ceq [string]$e.path })) {
                foreach ($lock in @($copy.authorityHashes | Where-Object { $_.Contains('id') -and $_.id -ceq [string]$a.id })) { $lock.sha256 = $(if ([IO.File]::Exists($full)) { Hash $full } else { '0' * 64 }); $hits++ }
            }
        }
    }
    Assert ($hits -gt 0) "repin: no edited file is a kept governance authority ($($Case.id))"
    $copy
}

$results = [Collections.Generic.List[object]]::new()
try {
    foreach ($case in $cases) {
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
        if ($ok -and $case.kind -in @('rule', 'benign') -and $null -ne $case.rule) { $ok = @($result.findings | Where-Object { $_.ruleId -ceq $case.rule }).Count -ge 1 }
        if ($ok -and $case.status -ceq 'pass') { $ok = @($result.coverage | Where-Object { $_.matched -lt $_.minimum }).Count -eq 0 }
        if ($ok -and $case.kind -ceq 'clean') { $again = Invoke-Adapter; $ok = ($again | ConvertTo-Json -Depth 60 -Compress) -ceq ($result | ConvertTo-Json -Depth 60 -Compress) }
        $results.Add([ordered]@{ id = $case.id; kind = $case.kind; binding = $(if ($case.PSObject.Properties.Name -contains 'binding') { $case.binding } else { $null })
            edited = @($case.edits | ForEach-Object { if ($_.PSObject.Properties.Name -contains 'path') { $_.path } else { "$($_.root)/**/$($_.filter)" } }); expected = "$($case.status)/$($case.category)"; actual = "$($result.status)/$($result.exitCategory)"
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
