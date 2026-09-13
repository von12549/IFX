[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixture = [IO.Path]::GetFullPath((Join-Path $repo "artifacts/guards/test-fixture-$([Guid]::NewGuid().ToString('N'))"))
$fixtureParent = [IO.Path]::GetFullPath((Join-Path $repo 'artifacts/guards'))
if (-not $fixture.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }

function Assert-Exit {
    param([int] $Expected, [string[]] $Arguments, [string] $Label)
    $output = @(& pwsh -NoProfile -File $Arguments[0] @($Arguments[1..($Arguments.Count - 1)]) 2>&1)
    if ($LASTEXITCODE -ne $Expected) {
        throw "$Label expected exit $Expected, got $LASTEXITCODE. Output: $($output -join ' | ')"
    }
}

function Set-JsonProperty {
    param([string] $Path, [scriptblock] $Edit)
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    & $Edit $value
    [IO.File]::WriteAllText($Path, ($value | ConvertTo-Json -Depth 100))
}

$passed = $false
try {
    [void] [IO.Directory]::CreateDirectory($fixture)
    [void] [IO.Directory]::CreateDirectory((Join-Path $fixture 'docs/guards'))
    [void] [IO.Directory]::CreateDirectory((Join-Path $fixture 'scripts'))
    [void] [IO.Directory]::CreateDirectory((Join-Path $fixture 'app/config'))
    [void] [IO.Directory]::CreateDirectory((Join-Path $fixture '.github/workflows'))
    Copy-Item -LiteralPath (Join-Path $repo 'docs/guards/contracts') -Destination (Join-Path $fixture 'docs/guards/contracts') -Recurse
    [void] [IO.Directory]::CreateDirectory((Join-Path $fixture 'scripts/guards'))
    foreach ($script in @('GuardCore.psm1', 'Invoke-CodingGuard.ps1', 'Invoke-GuardRegeneration.ps1')) {
        Copy-Item -LiteralPath (Join-Path $repo "scripts/guards/$script") -Destination (Join-Path $fixture "scripts/guards/$script")
    }
    $template = Join-Path $repo 'docs/guards/templates/new-project'
    Copy-Item -LiteralPath (Join-Path $template 'inputs') -Destination (Join-Path $fixture 'docs/guards/inputs') -Recurse
    Copy-Item -LiteralPath (Join-Path $template 'bindings') -Destination (Join-Path $fixture 'docs/guards/bindings') -Recurse
    [IO.File]::WriteAllText((Join-Path $fixture 'app/example.txt'), 'sample')
    [IO.File]::WriteAllText((Join-Path $fixture '.github/workflows/sample.yml'), 'name: sample')
    [IO.File]::WriteAllText((Join-Path $fixture '.gitignore'), "artifacts/`n")
    $regen = Join-Path $fixture 'scripts/guards/Invoke-GuardRegeneration.ps1'
    $runner = Join-Path $fixture 'scripts/guards/Invoke-CodingGuard.ps1'
    $regenArgs = @($regen, '-RepositoryRoot', $fixture, '-Profile', 'template')
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'template generate'
    $manifest = Join-Path $fixture 'docs/guards/generated/guard-manifest.json'
    $first = [IO.File]::ReadAllBytes($manifest)
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'idempotent generate'
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $first, [byte[]] [IO.File]::ReadAllBytes($manifest))) { throw 'Second generation changed the manifest.' }
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Check')) 'template check'

    $rulePath = Join-Path $fixture 'docs/guards/inputs/rules/TEMPLATE.SMOKE.json'
    $originalRule = [IO.File]::ReadAllText($rulePath)
    Set-JsonProperty $rulePath { param($r) $r.title = 'edited title' }
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'edited input drift'
    [IO.File]::WriteAllText($rulePath, $originalRule)
    Set-JsonProperty $rulePath { param($r) $r.authority.path = 'missing-authority.json' }
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'missing authority'
    [IO.File]::WriteAllText($rulePath, $originalRule)
    Set-JsonProperty $rulePath { param($r) $r.enforcement = 'blocking'; $r.coverage = 'none' }
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'blocking without coverage'
    [IO.File]::WriteAllText($rulePath, $originalRule)
    Set-JsonProperty $rulePath { param($r) $r.scopePatterns = @('../outside/**') }
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'path traversal glob'
    [IO.File]::WriteAllText($rulePath, $originalRule)
    $externalAuthority = Join-Path $fixture 'policy.json'
    [IO.File]::WriteAllText($externalAuthority, '{"rule":"sample"}')
    Set-JsonProperty $rulePath { param($r) $r.authority.path = 'policy.json' }
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'external authority binding'
    [IO.File]::AppendAllText($externalAuthority, "`n")
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'external authority hash drift'
    [IO.File]::WriteAllText($rulePath, $originalRule)
    [IO.File]::Delete($externalAuthority)
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'restore rule authority'

    $mapPath = Join-Path $fixture 'docs/guards/inputs/PROJECT_MAP.json'
    $originalMap = [IO.File]::ReadAllText($mapPath)
    Set-JsonProperty $mapPath { param($m) $m.areas[0].pathPattern = 'app/new/**' }
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'project map drift'
    [IO.File]::WriteAllText($mapPath, $originalMap)

    $techPath = Join-Path $fixture 'docs/guards/inputs/TECH_STACK.json'
    $originalTech = [IO.File]::ReadAllText($techPath)
    Set-JsonProperty $techPath { param($t) $t.commands += $t.commands[0] }
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'duplicate command ID'
    [IO.File]::WriteAllText($techPath, $originalTech)
    $bindingPath = Join-Path $fixture 'docs/guards/bindings/template.json'
    $originalBinding = [IO.File]::ReadAllText($bindingPath)
    Set-JsonProperty $bindingPath { param($b) $b.detectors = @() }
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'missing detector binding'
    [IO.File]::WriteAllText($bindingPath, $originalBinding)
    $sampleWorkflow = Join-Path $fixture '.github/workflows/sample.yml'
    [IO.File]::WriteAllText($sampleWorkflow, "name: Example`njobs:`n  template-check:`n    runs-on: ubuntu-latest`n")
    Set-JsonProperty $bindingPath { param($b) $b.detectors[0].ciWorkflow = '.github/workflows/sample.yml'; $b.detectors[0].ciJob = 'Example / template-check' }
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'bound CI job'
    [IO.File]::WriteAllText($sampleWorkflow, "name: Example`njobs:`n  other-job:`n    runs-on: ubuntu-latest`n")
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'missing bound CI job'
    [IO.File]::WriteAllText($bindingPath, $originalBinding)
    [IO.File]::WriteAllText($sampleWorkflow, 'name: sample')
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'restore CI binding fixture'

    [IO.File]::AppendAllText($manifest, "`n")
    Assert-Exit 1 ($regenArgs + @('-Mode', 'Check')) 'tampered output'
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'restore output'

    Assert-Exit 0 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Pre', '-PlannedPaths', 'app/example.txt')) 'normal Pre'
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Pre')) 'missing Pre paths'
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Pre', '-PlannedPaths', 'app/config/settings.txt')) 'risk Pre without decision'
    $decisionDirectory = Join-Path $fixture 'docs/guards/decisions'
    [void] [IO.Directory]::CreateDirectory($decisionDirectory)
    $decisionPath = Join-Path $decisionDirectory '001-config.json'
    [IO.File]::WriteAllText($decisionPath, '{"formatVersion":1,"id":"001-config","owner":"maintainers","summary":"Change sample config","affectedPaths":["app/config/**"],"plan":"Review config behavior"}')
    Assert-Exit 0 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Pre', '-PlannedPaths', 'app\config\settings.txt', '-DecisionPath', 'docs/guards/decisions/001-config.json')) 'risk Pre with decision and Windows path'
    $originalDecision = [IO.File]::ReadAllText($decisionPath)
    Set-JsonProperty $decisionPath { param($d) $d.affectedPaths = @('**') }
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Pre', '-PlannedPaths', 'app/config/settings.txt', '-DecisionPath', 'docs/guards/decisions/001-config.json')) 'overbroad decision record'
    [IO.File]::WriteAllText($decisionPath, $originalDecision)
    Assert-Exit 0 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Post', '-Scope', 'Focused')) 'focused Post'
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Post', '-Scope', 'Focused', '-SkipCommands')) 'skipped Post'
    Set-JsonProperty $techPath { param($t) $t.commands[0].executable = 'missing-guard-executable-xyz' }
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'regenerate missing executable binding'
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Post', '-Scope', 'Full')) 'missing Post dependency'
    [IO.File]::WriteAllText($techPath, $originalTech)
    Set-JsonProperty $techPath { param($t) $t.commands[0]['expectedOutput'] = 'artifacts/guards/not-produced.json' }
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'regenerate expected-output fixture'
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Post', '-Scope', 'Full')) 'empty Post evidence'
    [IO.File]::WriteAllText($techPath, $originalTech)
    Set-JsonProperty $techPath { param($t) $t.commands[0].arguments = @('-NoProfile', '-Command', 'Start-Sleep -Seconds 3') }
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'regenerate timeout fixture'
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Post', '-Scope', 'Full', '-TimeoutSeconds', '1')) 'Post timeout'
    [IO.File]::WriteAllText($techPath, $originalTech)
    Assert-Exit 0 ($regenArgs + @('-Mode', 'Generate')) 'restore valid binding'

    Push-Location $fixture
    try {
        & git init -q
        & git config user.email guard-test@example.invalid
        & git config user.name 'Guard Test'
        & git config core.autocrlf false
        & git add .
        & git commit -qm baseline
        if ($LASTEXITCODE -ne 0) { throw 'Fixture commit failed.' }
    }
    finally { Pop-Location }
    [IO.File]::AppendAllText((Join-Path $fixture 'app/example.txt'), "`nchange")
    Assert-Exit 0 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Diff')) 'ordinary Diff'
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Diff', '-DeclaredPaths', 'docs/**')) 'diff outside declared scope'
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Diff', '-BaseRef', 'missing-base-ref-xyz')) 'invalid Diff base'
    [IO.File]::WriteAllText((Join-Path $fixture 'app/config/settings.txt'), 'value')
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Diff')) 'high-risk untracked Diff without decision'
    [IO.File]::AppendAllText($decisionPath, "`n")
    Assert-Exit 0 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Diff')) 'high-risk Diff with changed decision'
    [IO.File]::Delete((Join-Path $fixture '.github/workflows/sample.yml'))
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Diff')) 'protected workflow deletion'
    [IO.File]::WriteAllText((Join-Path $fixture '.github/workflows/sample.yml'), 'name: sample')
    Push-Location $fixture
    try {
        & git add .
        & git commit -qm 'risk fixture baseline'
        if ($LASTEXITCODE -ne 0) { throw 'Risk fixture commit failed.' }
        & git mv app/config/settings.txt app/renamed.txt
        if ($LASTEXITCODE -ne 0) { throw 'Fixture rename failed.' }
    }
    finally { Pop-Location }
    Assert-Exit 1 (@($runner, '-RepositoryRoot', $fixture, '-Profile', 'template', '-Stage', 'Diff')) 'rename out of risk path without new decision'
    $passed = $true
    Write-Host 'Coding guard framework tests passed.'
}
finally {
    if ($passed -and [IO.Directory]::Exists($fixture)) {
        $verified = [IO.Path]::GetFullPath($fixture)
        if (-not $verified.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup path.' }
        Remove-Item -LiteralPath $verified -Recurse -Force
    }
    elseif (-not $passed) { Write-Warning "Failed fixture retained at $fixture" }
}
