param(
    [string]$ReportPath = ""
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $repositoryRoot "src/Modules"
$sourceRoot = Join-Path $repositoryRoot "src"

function Get-SourceText([System.IO.FileInfo]$file) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    return [regex]::Replace($text, '(?m)^\s*//.*$', '')
}

function New-Check([string]$name, [bool]$passed, [object]$actual, [string]$expectation) {
    return [ordered]@{
        name = $name
        passed = $passed
        actual = $actual
        expectation = $expectation
    }
}

$commandFiles = @(Get-ChildItem $moduleRoot -Recurse -Filter "*Command.cs" |
    Where-Object { $_.FullName -match '\.Application\\' })
$handlerFiles = @(Get-ChildItem $moduleRoot -Recurse -Filter "*CommandHandler.cs" |
    Where-Object { $_.FullName -match '\.Application\\' })
$applicationFiles = @(Get-ChildItem $moduleRoot -Recurse -Filter "*.cs" |
    Where-Object { $_.FullName -match '\.Application\\' })
$sourceFiles = @(Get-ChildItem $sourceRoot -Recurse -Filter "*.cs")

$commandsWithoutMarker = @($commandFiles | Where-Object {
    (Get-SourceText $_) -notmatch 'ICommand\s*<'
} | ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName) })

$handlerViolations = [ordered]@{
    saveChanges = @()
    catchAll = @()
    directPublish = @()
    nestedSend = @()
    rawSql = @()
}

foreach ($file in $handlerFiles) {
    $text = Get-SourceText $file
    $path = [IO.Path]::GetRelativePath($repositoryRoot, $file.FullName)
    if ($text -match 'SaveChangesAsync\s*\(') { $handlerViolations.saveChanges += $path }
    if ($text -match 'catch\s*\(\s*Exception(?:\s+\w+)?\s*\)') { $handlerViolations.catchAll += $path }
    if ($text -match '\.PublishAsync\s*\(') { $handlerViolations.directPublish += $path }
    if ($text -match '\.Send\s*\(') { $handlerViolations.nestedSend += $path }
    if ($text -match '(ExecuteSql|FromSql|SqlQuery)(Raw|Interpolated)?\s*\(') { $handlerViolations.rawSql += $path }
}

$moduleBehaviorFiles = @(Get-ChildItem $moduleRoot -Recurse -Filter "*Behavior.cs" |
    Where-Object { $_.FullName -match '\.Application\\Behaviors\\' } |
    ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName) })

$loggingRegistrations = 0
$validationRegistrations = 0
$transactionRegistrations = 0
$transactionScopeUses = @()
foreach ($file in $sourceFiles) {
    $text = Get-SourceText $file
    $loggingRegistrations += ([regex]::Matches($text, 'typeof\(LoggingBehavior<,>\)')).Count
    $validationRegistrations += ([regex]::Matches($text, 'typeof\(ValidationBehavior<,>\)')).Count
    $transactionRegistrations += ([regex]::Matches($text, 'typeof\(TransactionBehavior<,>\)')).Count
    if ($text -match '\bTransactionScope\b') {
        $transactionScopeUses += [IO.Path]::GetRelativePath($repositoryRoot, $file.FullName)
    }
}

$unitOfWorkTransactionProtocol = @($applicationFiles | Where-Object {
    $_.Name -eq 'IUnitOfWork.cs' -and (Get-SourceText $_) -match '\b(Begin|Commit|Rollback)(Transaction)?Async\s*\('
} | ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName) })

$contractProtocolLeaks = @(Get-ChildItem $moduleRoot -Recurse -Filter "*.cs" | Where-Object {
    $_.FullName -match '\.(Abstractions|Contracts)\\' -and
    (Get-SourceText $_) -match '\b(IOperationResult|ITransactionExecutor|ITransactionParticipant|ICommand\s*<)'
} | ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName) })

$checks = @(
    New-Check "all commands use explicit ICommand marker" ($commandFiles.Count -eq 89 -and $commandsWithoutMarker.Count -eq 0) `
        ([ordered]@{ commandCount = $commandFiles.Count; missingMarker = $commandsWithoutMarker }) `
        "89 commands and zero missing markers"
    New-Check "command handlers do not own final persistence" ($handlerViolations.saveChanges.Count -eq 0) $handlerViolations.saveChanges "zero active SaveChangesAsync calls"
    New-Check "command handlers do not catch all exceptions" ($handlerViolations.catchAll.Count -eq 0) $handlerViolations.catchAll "zero catch (Exception) blocks"
    New-Check "command handlers do not publish transport events" ($handlerViolations.directPublish.Count -eq 0) $handlerViolations.directPublish "zero PublishAsync calls"
    New-Check "command handlers do not nest commands" ($handlerViolations.nestedSend.Count -eq 0) $handlerViolations.nestedSend "zero MediatR Send calls"
    New-Check "command handlers do not execute raw SQL" ($handlerViolations.rawSql.Count -eq 0) $handlerViolations.rawSql "zero raw SQL calls"
    New-Check "module-local shared behaviors are removed" ($moduleBehaviorFiles.Count -eq 0) $moduleBehaviorFiles "zero module Application Behavior files"
    New-Check "shared pipeline registrations are unique" `
        ($loggingRegistrations -eq 1 -and $validationRegistrations -eq 1 -and $transactionRegistrations -eq 1) `
        ([ordered]@{ logging = $loggingRegistrations; validation = $validationRegistrations; transaction = $transactionRegistrations }) `
        "one registration for each shared behavior"
    New-Check "ambient distributed transactions are forbidden" ($transactionScopeUses.Count -eq 0) $transactionScopeUses "zero TransactionScope uses"
    New-Check "UnitOfWork ports do not expose transaction control" ($unitOfWorkTransactionProtocol.Count -eq 0) $unitOfWorkTransactionProtocol "zero Begin/Commit/Rollback methods"
    New-Check "transaction protocol does not leak into external contracts" ($contractProtocolLeaks.Count -eq 0) $contractProtocolLeaks "zero Abstractions/Contracts references"
)

$report = [ordered]@{
    gate = "G01"
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    passed = @($checks | Where-Object { -not $_.passed }).Count -eq 0
    inventory = [ordered]@{
        commands = $commandFiles.Count
        commandHandlers = $handlerFiles.Count
        handlerViolations = $handlerViolations
    }
    checks = $checks
}

$json = $report | ConvertTo-Json -Depth 8
if ($ReportPath) {
    $resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) {
        $ReportPath
    } else {
        Join-Path $repositoryRoot $ReportPath
    }
    $reportDirectory = Split-Path -Parent $resolvedReportPath
    [IO.Directory]::CreateDirectory($reportDirectory) | Out-Null
    [IO.File]::WriteAllText($resolvedReportPath, $json + [Environment]::NewLine)
}

Write-Output $json
if (-not $report.passed) {
    exit 1
}
