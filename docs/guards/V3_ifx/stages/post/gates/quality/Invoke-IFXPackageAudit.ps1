[CmdletBinding()]
param(
    [string] $RepositoryRoot,
    [string] $OutputPath = 'artifacts/guards/v3-ifx/quality/nuget-audit.json',
    [switch] $SkipRestore
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = if ($RepositoryRoot) {
    [IO.Path]::GetFullPath($RepositoryRoot)
} elseif ($env:GUARD_TARGET_ROOT) {
    [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT)
} else {
    [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../..'))
}
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputPath)) {
    [IO.Path]::GetFullPath($OutputPath)
} else {
    [IO.Path]::GetFullPath((Join-Path $root $OutputPath))
}
$outputDirectory = [IO.Path]::GetDirectoryName($resolvedOutput)
[void] [IO.Directory]::CreateDirectory($outputDirectory)

function Invoke-Checked([string] $Label, [scriptblock] $Command) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE." }
}

$projects = @(
    Push-Location $root
    try {
        git ls-files -- 'src/**/*.csproj' 'tests/**/*.csproj' 'tools/**/*.csproj'
        if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate tracked active projects.' }
    } finally {
        Pop-Location
    }
) | Sort-Object -Unique
if ($projects.Count -eq 0) { throw 'No active PackageReference projects were found.' }

if (-not $SkipRestore) {
    Invoke-Checked 'Solution restore' {
        dotnet restore (Join-Path $root 'IFX.sln') --force-evaluate -warnaserror:NU1603
    }
}

$auditWorkspace = Join-Path $outputDirectory ".nuget-audit-$([Guid]::NewGuid().ToString('N'))"
$auditWorkspace = [IO.Path]::GetFullPath($auditWorkspace)
if (-not $auditWorkspace.StartsWith($outputDirectory.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe package audit workspace.' }

try {
    Invoke-Checked 'Create package audit solution' {
        dotnet new sln --name IFX.PackageAudit --output $auditWorkspace --format sln | Out-Null
    }
    $auditSolution = Join-Path $auditWorkspace 'IFX.PackageAudit.sln'
    $projectPaths = @($projects | ForEach-Object { Join-Path $root $_ })
    Invoke-Checked 'Populate package audit solution' {
        dotnet sln $auditSolution add @projectPaths | Out-Null
    }

    $auditOutput = @(& dotnet list $auditSolution package --vulnerable --include-transitive --format json --no-restore 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Package audit failed with exit code $LASTEXITCODE.`n$($auditOutput -join [Environment]::NewLine)" }
    $audit = ($auditOutput -join [Environment]::NewLine) | ConvertFrom-Json -AsHashtable -Depth 100

    $findings = [Collections.Generic.List[object]]::new()
    function Find-Vulnerabilities([object] $Node) {
        if ($null -eq $Node -or $Node -is [string]) { return }
        if ($Node -is [Collections.IDictionary]) {
            if ($Node.Contains('vulnerabilities')) {
                foreach ($vulnerability in @($Node['vulnerabilities'])) {
                    $findings.Add([ordered]@{
                        package = if ($Node.Contains('id')) { [string]$Node['id'] } else { $null }
                        resolvedVersion = if ($Node.Contains('resolvedVersion')) { [string]$Node['resolvedVersion'] } else { $null }
                        severity = [string]$vulnerability['severity']
                        advisoryUrl = [string]$vulnerability['advisoryurl']
                    })
                }
            }
            foreach ($value in $Node.Values) { Find-Vulnerabilities $value }
            return
        }
        if ($Node -is [Collections.IEnumerable]) {
            foreach ($value in $Node) { Find-Vulnerabilities $value }
        }
    }
    Find-Vulnerabilities $audit

    $blocking = @($findings | Where-Object { $_.severity -in @('high', 'critical') })
    $report = [ordered]@{
        schemaVersion = 1
        generatedAtUtc = [DateTimeOffset]::UtcNow.ToString('O')
        status = if ($blocking.Count -eq 0) { 'pass' } else { 'fail' }
        projectCount = $projects.Count
        auditMode = 'all'
        blockingSeverities = @('high', 'critical')
        findings = @($findings)
        audit = $audit
    }
    $report | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $resolvedOutput -Encoding utf8NoBOM
    if ($blocking.Count -ne 0) { throw "NuGet audit found $($blocking.Count) high or critical advisories. Report: $resolvedOutput" }
    Write-Host "NuGet direct/transitive audit passed for $($projects.Count) projects: $resolvedOutput"
}
finally {
    if ([IO.Directory]::Exists($auditWorkspace)) {
        [IO.Directory]::Delete($auditWorkspace, $true)
    }
}

$global:LASTEXITCODE = 0
