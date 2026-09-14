$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$setup = Join-Path $package 'scripts/Invoke-V3Setup.ps1'
$docs = Join-Path $package 'scripts/Invoke-V3Docs.ps1'
$guard = Join-Path $package 'scripts/Invoke-V3.ps1'
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$trial = Join-Path $tempRoot ('v3-tools-' + [Guid]::NewGuid().ToString('N'))
$trialPrefix = $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $trial.StartsWith($trialPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe trial directory.' }
$utf8 = [Text.UTF8Encoding]::new($false)
try {
    [void] [IO.Directory]::CreateDirectory((Join-Path $trial 'src/App'))
    [IO.File]::WriteAllText((Join-Path $trial 'src/App/App.csproj'), '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup><ItemGroup><ProjectReference Include="../Core/Core.csproj" /></ItemGroup></Project>', $utf8)
    [void] [IO.Directory]::CreateDirectory((Join-Path $trial '.github/workflows'))
    [IO.File]::WriteAllText((Join-Path $trial '.github/workflows/build.yml'), 'name: build', $utf8)
    & $setup -Mode Init -TargetRoot $trial -ProfileDirectory 'guard/profile' -ProjectId sample -TargetFramework net10.0
    & $guard -Mode Validate -TargetRoot $trial -ProfileDirectory 'guard/profile' -OutputDirectory 'guard/generated'
    $profile = Join-Path $trial 'guard/profile'
    $rulePath = Join-Path $profile 'rules/ARCH.UNCONFIGURED.json'
    $rule = Get-Content -LiteralPath $rulePath -Raw | ConvertFrom-Json
    if ($rule.enforcement -ne 'advisory' -or $rule.kind -ne 'none') { throw 'Init unexpectedly promoted an unreviewed rule.' }
    $pre = & pwsh -NoProfile -File $guard -Mode Pre -TargetRoot $trial -ProfileDirectory 'guard/profile' -PlannedPaths 'src/App/App.cs' -ReportPath 'guard/pre.json' 2>&1
    if ($LASTEXITCODE -eq 0) { throw 'Unreviewed scaffold mapped a real source path.' }
    & $setup -Mode Analyze -TargetRoot $trial -OutputDirectory 'guard/analysis' -ExcludePaths 'guard/**'
    $inventoryPath = Join-Path $trial 'guard/analysis/inventory.json'
    $first = [IO.File]::ReadAllBytes($inventoryPath)
    $inventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json
    if ($inventory.projects.Count -ne 1 -or $inventory.workflows.Count -ne 1 -or $inventory.projects[0].projectReferences[0].resolvedPath -ne 'src/Core/Core.csproj') { throw 'Analyze missed repository evidence.' }
    & $setup -Mode Analyze -TargetRoot $trial -OutputDirectory 'guard/analysis' -ExcludePaths 'guard/**'
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]] $first, [byte[]] [IO.File]::ReadAllBytes($inventoryPath))) { throw 'Analyze output was not deterministic.' }
    & $docs -Mode Render -TargetRoot $trial -ProfileDirectory 'guard/profile'
    & $docs -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/profile'
    $view = Join-Path $profile 'views/rules/ARCH.UNCONFIGURED.md'
    $edited = [IO.File]::ReadAllText($view).Replace('"title": "Replace with reviewed target rules"', '"title": "Review source boundaries"')
    [IO.File]::WriteAllText($view, $edited, $utf8)
    $drift = $false
    try { & $docs -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/profile' } catch { $drift = $_.Exception.Message -match 'Markdown view drift' }
    if (-not $drift) { throw 'Check did not detect edited Markdown.' }
    & $docs -Mode Import -TargetRoot $trial -ProfileDirectory 'guard/profile'
    if ((Get-Content -LiteralPath $rulePath -Raw | ConvertFrom-Json).title -ne 'Replace with reviewed target rules') { throw 'Import preview mutated JSON.' }
    & $docs -Mode Import -TargetRoot $trial -ProfileDirectory 'guard/profile' -Apply
    & $docs -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/profile'
    if ((Get-Content -LiteralPath $rulePath -Raw | ConvertFrom-Json).title -ne 'Review source boundaries') { throw 'Import did not update JSON.' }
    [IO.File]::WriteAllText((Join-Path $profile 'views/rules/STALE.md'), 'stale', $utf8)
    $extra = $false
    try { & $docs -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/profile' } catch { $extra = $_.Exception.Message -match 'Unexpected generated views' }
    if (-not $extra) { throw 'Check did not detect an extra view.' }
    & $docs -Mode Render -TargetRoot $trial -ProfileDirectory 'guard/profile'
    & $docs -Mode Check -TargetRoot $trial -ProfileDirectory 'guard/profile'
    $edited = [IO.File]::ReadAllText($view).Replace('"title": "Review source boundaries"', '"title": "Markdown proposal"')
    [IO.File]::WriteAllText($view, $edited, $utf8)
    $source = [IO.File]::ReadAllText($rulePath).Replace('"title": "Review source boundaries"', '"title": "Independent JSON change"')
    [IO.File]::WriteAllText($rulePath, $source, $utf8)
    $conflict = $false
    try { & $docs -Mode Import -TargetRoot $trial -ProfileDirectory 'guard/profile' -Apply } catch { $conflict = $_.Exception.Message -match 'JSON changed since Markdown render' }
    if (-not $conflict) { throw 'Import did not reject a stale Markdown base hash.' }
    Write-Host 'V3 setup/docs tests passed: fail-closed Init, evidence inventory, deterministic Analyze, Render/Check, preview/import and conflict rejection.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($trial)
    if (-not $resolved.StartsWith($trialPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe trial cleanup path.' }
    if ([IO.Directory]::Exists($resolved)) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
