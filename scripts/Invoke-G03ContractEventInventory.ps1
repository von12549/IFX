[CmdletBinding()]
param(
    [string] $ReportPath = "docs/architecture/review/evidence/gates/G03/G03-contract-event-inventory.json",
    [string] $BaselineCommit = "b9f1c19"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) {
    $ReportPath
} else {
    Join-Path $repositoryRoot $ReportPath
}

function Get-RelativePath([string] $Path) {
    [System.IO.Path]::GetRelativePath($repositoryRoot, $Path).Replace('\', '/')
}

function Get-LineNumber([string] $Content, [int] $Index) {
    if ($Index -le 0) { return 1 }
    return ([regex]::Matches($Content.Substring(0, $Index), "`n").Count + 1)
}

function Get-SourceSites([string] $Symbol, [string] $DeclarationPath) {
    $sites = @()
    foreach ($source in $allSourceFiles) {
        $relative = Get-RelativePath $source.FullName
        if ($relative -eq $DeclarationPath) { continue }
        $content = Get-Content -Raw -LiteralPath $source.FullName
        foreach ($match in [regex]::Matches($content, "\b$([regex]::Escape($Symbol))\b")) {
            $lineStart = $content.LastIndexOf("`n", [Math]::Max(0, $match.Index - 1)) + 1
            $lineEnd = $content.IndexOf("`n", $match.Index)
            if ($lineEnd -lt 0) { $lineEnd = $content.Length }
            $line = $content.Substring($lineStart, $lineEnd - $lineStart).Trim()
            $kind = if ($line -match '(PublishAsync|eventBuffer\.Add|eventSource\.Add)') {
                'producer'
            } elseif ($content -match "IIntegrationEventHandler\s*<\s*$([regex]::Escape($Symbol))\s*>" -or
                      $content -match 'IInboundIntegrationEventHandler') {
                'handler'
            } elseif ($line -match '^using\s') {
                'import'
            } else {
                'reference'
            }
            $sites += [ordered]@{
                file = $relative
                line = Get-LineNumber $content $match.Index
                kind = $kind
                evidence = $line
            }
        }
    }
    @($sites | Sort-Object file, line, kind -Unique)
}

$allSourceFiles = @(Get-ChildItem (Join-Path $repositoryRoot 'src') -Recurse -File -Filter '*.cs' |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
    Sort-Object FullName)

$catalogForProjects = Get-Content -Raw (Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') | ConvertFrom-Json -Depth 100
$registeredProjects = @($catalogForProjects.protocols.source.project)
$contractProjects = @(Get-ChildItem (Join-Path $repositoryRoot 'src') -Recurse -File -Filter '*.csproj' |
    Where-Object { ($_.FullName -match '[\\/]Modules[\\/]' -and ($_.BaseName -like '*.Abstractions' -or $_.BaseName -like '*.Contracts')) -or $_.BaseName -in $registeredProjects } |
    Sort-Object FullName)

$projects = @()
$surfaces = @()
foreach ($projectFile in $contractProjects) {
    [xml] $projectXml = Get-Content -Raw -LiteralPath $projectFile.FullName
    $projectName = $projectFile.BaseName
    $module = ($projectName -split '\.')[2]
    $projectDirectory = Split-Path -Parent $projectFile.FullName
    $references = @($projectXml.Project.ItemGroup.ProjectReference.Include | Where-Object { $_ } |
        ForEach-Object { [System.IO.Path]::GetFullPath((Join-Path $projectDirectory $_)) } |
        ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) } |
        Sort-Object -Unique)
    $packages = @($projectXml.Project.ItemGroup.PackageReference.Include | Where-Object { $_ } | Sort-Object -Unique)
    $projects += [ordered]@{
        name = $projectName
        module = $module
        path = Get-RelativePath $projectFile.FullName
        projectReferences = $references
        packageReferences = $packages
    }

    $sourceFiles = @(Get-ChildItem $projectDirectory -Recurse -File -Filter '*.cs' |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } |
        Sort-Object FullName)
    foreach ($sourceFile in $sourceFiles) {
        $content = Get-Content -Raw -LiteralPath $sourceFile.FullName
        $namespace = [regex]::Match($content, '(?m)^namespace\s+([^;]+);').Groups[1].Value
        $declaration = [regex]::Match($content, '(?m)^public\s+(?:(?:abstract|sealed|partial|readonly)\s+)*(interface|record(?:\s+(?:class|struct))?|class|enum)\s+([A-Za-z0-9_]+)')
        if (-not $declaration.Success) { continue }
        $kind = $declaration.Groups[1].Value
        $name = $declaration.Groups[2].Value
        $surfaceKind = if ($content -match ':\s*(?:IntegrationEvent|IIntegrationEventV1)\b') {
            'integration-event'
        } elseif ($kind -eq 'interface') {
            'reader'
        } elseif ($sourceFile.DirectoryName -like '*DTOs*') {
            'dto'
        } else {
            'public-type'
        }
        $methods = @()
        if ($kind -eq 'interface') {
            foreach ($methodMatch in [regex]::Matches($content, '(?m)^\s*(Task<[^;]+?\([^;]+?\);)\s*$')) {
                $signature = ($methodMatch.Groups[1].Value -replace '\s+', ' ').Trim()
                $methodName = [regex]::Match($signature, '([A-Za-z0-9_]+)Async\s*\(').Groups[1].Value + 'Async'
                $methods += [ordered]@{
                    name = $methodName
                    signature = $signature
                    callSites = Get-SourceSites $methodName (Get-RelativePath $sourceFile.FullName)
                }
            }
        }
        $surfaces += [ordered]@{
            project = $projectName
            module = $module
            namespace = $namespace
            name = $name
            kind = $surfaceKind
            declaration = [ordered]@{
                file = Get-RelativePath $sourceFile.FullName
                line = Get-LineNumber $content $declaration.Index
            }
            baseType = if ($content -match ':\s*IIntegrationEventV1\b') { 'IIntegrationEventV1' } elseif ($content -match ':\s*IntegrationEvent\b') { 'IntegrationEvent' } else { $null }
            methods = $methods
            sourceSites = Get-SourceSites $name (Get-RelativePath $sourceFile.FullName)
        }
    }
}

$messagingProjectPath = Join-Path $repositoryRoot 'src/Platform/Messaging/IFX.Platform.Messaging.Contracts/IFX.Platform.Messaging.Contracts.csproj'
[xml] $messagingProject = Get-Content -Raw -LiteralPath $messagingProjectPath
$messagingTypes = @(Get-ChildItem (Split-Path -Parent $messagingProjectPath) -Recurse -File -Filter '*.cs' |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } | Sort-Object FullName | ForEach-Object {
    $content = Get-Content -Raw -LiteralPath $_.FullName
    $declaration = [regex]::Match($content, '(?m)^public\s+(?:(?:abstract|sealed|partial|readonly)\s+)*(interface|record(?:\s+(?:class|struct))?|class)\s+([A-Za-z0-9_]+)')
    if ($declaration.Success) {
        [ordered]@{
            name = $declaration.Groups[2].Value
            kind = $declaration.Groups[1].Value
            file = Get-RelativePath $_.FullName
            packageReferences = @($messagingProject.Project.ItemGroup.PackageReference.Include | Where-Object { $_ } | Sort-Object -Unique)
        }
    }
})

$allProjects = @(Get-ChildItem (Join-Path $repositoryRoot 'src') -Recurse -File -Filter '*.csproj' | Sort-Object FullName)
$projectEdges = @()
foreach ($projectFile in $allProjects) {
    [xml] $xml = Get-Content -Raw -LiteralPath $projectFile.FullName
    foreach ($reference in @($xml.Project.ItemGroup.ProjectReference.Include | Where-Object { $_ })) {
        $target = [System.IO.Path]::GetFileNameWithoutExtension($reference)
        if ($target -like '*.Abstractions' -or $target -like '*.Contracts' -or
            $projectFile.BaseName -like '*.Abstractions' -or $projectFile.BaseName -like '*.Contracts') {
            $projectEdges += [ordered]@{ from = $projectFile.BaseName; to = $target }
        }
    }
}

$commitSha = (git -C $repositoryRoot rev-parse $BaselineCommit).Trim()
$commitTime = (git -C $repositoryRoot show -s --format=%cI $commitSha).Trim()
$governance = [ordered]@{
    codeowners = Test-Path (Join-Path $repositoryRoot '.github/CODEOWNERS')
    apiDiff = @(Get-ChildItem $repositoryRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|.git)[\\/]' -and $_.Name -match '(PublicApi|ApiCompat)' }).Count -gt 0
    serializationSnapshots = @(Get-ChildItem $repositoryRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|.git)[\\/]' -and $_.Name -match '(golden|snapshot)' }).Count -gt 0
    contractCatalog = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/contract-event-catalog.yaml')
    ciWorkflow = Test-Path (Join-Path $repositoryRoot '.github/workflows')
    externalConsumerEvidencePolicy = 'A consumer outside this repository is recognized only with system identity, accountable owner/contact, supported version, connection evidence, and last-confirmed date.'
}

$report = [ordered]@{
    formatVersion = 1
    gate = 'G03'
    phase = 0
    source = [ordered]@{
        commitSha = $commitSha
        capturedAtUtc = $commitTime
        repositoryScope = @('src/**/*.csproj', 'src/**/*.cs')
        exclusions = @('**/bin/**', '**/obj/**')
        generator = 'scripts/Invoke-G03ContractEventInventory.ps1'
    }
    counts = [ordered]@{
        abstractionProjects = @($projects | Where-Object name -like '*.Abstractions').Count
        contractProjects = @($projects | Where-Object name -like '*.Contracts').Count
        readers = @($surfaces | Where-Object kind -eq 'reader').Count
        readerMethods = @($surfaces.methods | Where-Object { $null -ne $_ }).Count
        dtos = @($surfaces | Where-Object kind -eq 'dto').Count
        integrationEvents = @($surfaces | Where-Object kind -eq 'integration-event').Count
        messagingAbstractionTypes = $messagingTypes.Count
        abstractionProjectEdges = $projectEdges.Count
    }
    abstractionProjects = @($projects | Where-Object name -like '*.Abstractions')
    contractProjects = @($projects | Where-Object name -like '*.Contracts')
    publicSurface = @($surfaces | Sort-Object module, kind, name)
    messagingAbstractions = $messagingTypes
    projectEdges = @($projectEdges | Sort-Object from, to)
    governanceCapabilities = $governance
}

$reportDirectory = Split-Path -Parent $resolvedReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
Write-Host "G03 contract/event inventory written: $resolvedReportPath"
