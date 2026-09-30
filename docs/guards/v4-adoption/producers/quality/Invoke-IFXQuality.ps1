[CmdletBinding()]
param(
    [ValidateSet('Solution','Assembly','Frontend','All')][string] $Target = 'All',
    [ValidateSet('Debug','Release')][string] $Configuration = 'Release',
    [string] $OutputDirectory = 'artifacts/guards/v3-ifx/quality',
    [string] $TargetRoot
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } elseif ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../..')) }
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $repositoryRoot $OutputDirectory }
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null
$selected = if ($Target -eq 'All') { @('Solution','Assembly','Frontend') } else { @($Target) }
$results = @()

function Invoke-Checked([string] $label, [scriptblock] $command) {
    & $command
    if ($LASTEXITCODE -ne 0) { throw "$label failed with exit code $LASTEXITCODE." }
}

function Invoke-NpmAudit([string] $label, [string[]] $auditArguments, [string] $reportPath) {
    & npm audit @auditArguments | Set-Content -LiteralPath $reportPath -Encoding utf8NoBOM
    if ($LASTEXITCODE -ne 0) { throw "$label failed with exit code $LASTEXITCODE. Report: $reportPath" }
}

foreach ($targetId in $selected) {
    try {
        switch ($targetId) {
            'Solution' {
                $solution = Join-Path $repositoryRoot 'IFX.sln'
                Invoke-Checked 'Solution restore' { dotnet restore $solution --force-evaluate -warnaserror:NU1603 }
                & (Join-Path $PSScriptRoot 'Invoke-IFXPackageAudit.ps1') -RepositoryRoot $repositoryRoot -OutputPath (Join-Path $resolvedOutput 'nuget-audit.json') -SkipRestore
                Invoke-Checked 'Solution build' { dotnet build $solution --configuration $Configuration --no-restore }
                $trxRoot = Join-Path $resolvedOutput 'solution-test-results'
                New-Item -ItemType Directory -Force -Path $trxRoot | Out-Null
                Invoke-Checked 'Solution tests' { dotnet test $solution --configuration $Configuration --no-build --no-restore --results-directory $trxRoot --logger 'trx;LogFilePrefix=solution' }
            }
            'Assembly' {
                & (Join-Path $PSScriptRoot 'Invoke-IFXAssemblyGuard.ps1') -RepositoryRoot $repositoryRoot -Configuration $Configuration -ReportPath (Join-Path $resolvedOutput 'assembly.json')
            }
            'Frontend' {
                $previousNpmCache = [Environment]::GetEnvironmentVariable('NPM_CONFIG_CACHE', 'Process')
                $env:NPM_CONFIG_CACHE = Join-Path $resolvedOutput 'npm-cache'
                Push-Location (Join-Path $repositoryRoot 'src/Frontend/IFX.FrontEnd')
                try {
                    Invoke-Checked 'Frontend npm ci' { npm ci }
                    Invoke-NpmAudit 'Frontend production dependency audit' @('--omit=dev', '--json', '--audit-level=high') (Join-Path $resolvedOutput 'npm-audit-production.json')
                    Invoke-NpmAudit 'Frontend full dependency audit' @('--json', '--audit-level=high') (Join-Path $resolvedOutput 'npm-audit.json')
                    Invoke-Checked 'Frontend lint' { npm run lint -- --max-warnings=0 }
                    Invoke-Checked 'Frontend tests' { npm run test:run }
                    Invoke-Checked 'Frontend build' { npm run build }
                } finally {
                    Pop-Location
                    [Environment]::SetEnvironmentVariable('NPM_CONFIG_CACHE', $previousNpmCache, 'Process')
                }
            }
        }
        $results += [ordered]@{ id = $targetId; status = 'pass' }
    } catch {
        $results += [ordered]@{ id = $targetId; status = 'fail'; message = $_.Exception.Message }
    }
}

$summary = [ordered]@{ schemaVersion = 1; mode = 'quality'; status = if (@($results | Where-Object status -eq 'fail').Count -eq 0) { 'pass' } else { 'fail' }; checks = $results }
$summaryPath = Join-Path $resolvedOutput 'summary.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
if ($summary.status -ne 'pass') { throw "IFX quality checks failed: $summaryPath" }
Write-Host "IFX quality checks passed: $summaryPath"
