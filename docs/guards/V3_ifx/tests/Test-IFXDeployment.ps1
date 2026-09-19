$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$artifacts = [IO.Path]::GetFullPath((Join-Path $repository 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $artifacts "v3-deployment-$([Guid]::NewGuid().ToString('N'))"))
if (-not $fixture.StartsWith($artifacts + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
$command = Join-Path $repository 'docs/guards/V3/commands/Invoke-V3Deployment.ps1'
$utf8 = [Text.UTF8Encoding]::new($false)

function Write-Fixture([string] $relative, [string] $content) {
    $path = Join-Path $fixture $relative
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path, $content.Replace("`r`n", "`n"), $utf8)
}
function Invoke-Mode([string] $label, [string] $mode, [int] $expected, [string[]] $extra = @(), [string] $expectText) {
    $arguments = @('-NoProfile', '-File', $command, '-Mode', $mode, '-ActivationPath', 'config/activation.json', '-TargetRoot', $fixture) + $extra
    $output = @(& pwsh @arguments 2>&1) -join ' | '
    if ($LASTEXITCODE -ne $expected) { throw "$label expected exit $expected, got ${LASTEXITCODE}: $output" }
    if ($expectText -and $output -notmatch [Regex]::Escape($expectText)) { throw "$label expected '$expectText': $output" }
}

try {
    [void][IO.Directory]::CreateDirectory($fixture)
    [void][IO.Directory]::CreateDirectory((Join-Path $fixture 'config'))
    Copy-Item -LiteralPath (Join-Path $repository 'docs/guards/V3_ifx/contracts/activation.schema.json') -Destination (Join-Path $fixture 'config/activation.schema.json')
    Write-Fixture 'config/workflow.template.yml' "name: Fixture`n# runtime @@RUNTIME@@`njobs:`n  verify:`n    name: fixture-check`n"
    Write-Fixture 'config/variables.json' "{`n  `"RUNTIME`": `"pwsh`"`n}`n"
    Write-Fixture 'config/variables.schema.json' '{ "type": "object", "additionalProperties": false, "required": ["RUNTIME"], "properties": { "RUNTIME": { "const": "pwsh" } } }'
    Write-Fixture 'config/codeowners.template' "/guard/ @owner`n"
    Write-Fixture 'commands/Validator.ps1' @'
[CmdletBinding()]
param([string] $TargetRoot, [string] $WorkflowPath, [string] $RequiredChecksPath)
if (-not (Test-Path -LiteralPath (Join-Path $TargetRoot $WorkflowPath))) { throw 'candidate missing' }
if (-not (Test-Path -LiteralPath (Join-Path $TargetRoot $RequiredChecksPath))) { throw 'declaration missing' }
'fixture validator passed'
'@
    Write-Fixture 'config/required-checks.json' "{}`n"
    Write-Fixture 'config/commands.json' @'
{
  "formatVersion": 1,
  "commands": [
    { "id": "fixture-validator", "kind": "public", "entryPoint": "commands/Validator.ps1" }
  ]
}
'@
    Write-Fixture 'config/activation.json' @'
{
  "formatVersion": 1,
  "schema": "config/activation.schema.json",
  "packageId": "fixture",
  "commandsManifest": "config/commands.json",
  "artifacts": [
    {
      "id": "workflow",
      "kind": "full-file",
      "template": "config/workflow.template.yml",
      "variables": "config/variables.json",
      "variablesSchema": "config/variables.schema.json",
      "candidate": "artifacts/generated/fixture/workflow.yml",
      "target": ".github/workflows/guard.yml"
    },
    {
      "id": "owners",
      "kind": "managed-block",
      "template": "config/codeowners.template",
      "candidate": "artifacts/generated/fixture/CODEOWNERS.guard",
      "target": ".github/CODEOWNERS",
      "marker": "fixture"
    }
  ],
  "validators": [
    {
      "id": "fixture",
      "commandId": "fixture-validator",
      "arguments": ["-WorkflowPath", "artifacts/generated/fixture/workflow.yml", "-RequiredChecksPath", "config/required-checks.json"]
    }
  ]
}
'@
    Write-Fixture '.github/workflows/guard.yml' "name: Fixture`n# runtime pwsh`njobs:`n  verify:`n    name: fixture-check`n"
    Write-Fixture '.github/CODEOWNERS' "# user-owned`n/guard/ @owner`n"

    Invoke-Mode 'generate succeeds' Generate 0 -expectText 'Generated 2'
    Invoke-Mode 'check succeeds through public validator' Check 0 -expectText 'Checked 2'
    Invoke-Mode 'legacy preview succeeds with explained differences' Preview 0 -expectText 'LEGACY-EQUIVALENT workflow'
    Invoke-Mode 'install requires acceptance' Install 1 -expectText 'Install requires -AcceptDeployment'
    Invoke-Mode 'explicit install succeeds' Install 0 @('-AcceptDeployment') -expectText 'Install passed'
    Invoke-Mode 'installed files verify' Verify 0 -expectText 'Verify passed'

    $workflowTarget = Get-Content -LiteralPath (Join-Path $fixture '.github/workflows/guard.yml') -Raw
    if ($workflowTarget -notmatch '^# Generated from: config/workflow\.template\.yml\n# Source-SHA256: [a-f0-9]{64}\n') { throw 'Installed workflow lacks source provenance.' }
    $ownersTarget = Get-Content -LiteralPath (Join-Path $fixture '.github/CODEOWNERS') -Raw
    if ($ownersTarget -notmatch '# BEGIN V3 MANAGED: fixture' -or $ownersTarget -notmatch '# user-owned') { throw 'Managed block install did not preserve unmanaged CODEOWNERS content.' }

    Write-Fixture 'config/workflow.template.yml' "name: Changed`n# runtime @@RUNTIME@@`n"
    Invoke-Mode 'candidate drift fails check' Check 1 -expectText 'Generated candidate drift'
    Invoke-Mode 'regenerate after authority change succeeds' Generate 0
    Invoke-Mode 'activated drift fails verify' Verify 1 -expectText 'DRIFT workflow'
    Write-Fixture 'config/workflow.template.yml' "name: Fixture`n@@MISSING@@`n"
    Invoke-Mode 'unbound stable variable fails closed' Generate 1 -expectText 'Unbound template variables'
    Write-Fixture 'config/workflow.template.yml' "name: Fixture`n# runtime @@RUNTIME@@`n"
    Write-Fixture 'config/variables.json' "{`n  `"RUNTIME`": `"bash`"`n}`n"
    Invoke-Mode 'variables schema violation fails closed' Generate 1 -expectText 'JSON is not valid with the schema'
    Write-Fixture 'config/variables.json' "{`n  `"RUNTIME`": `"pwsh`"`n}`n"

    $commandsPath = Join-Path $fixture 'config/commands.json'
    $commands = Get-Content -LiteralPath $commandsPath -Raw | ConvertFrom-Json
    $commands.commands[0].kind = 'internal'
    [IO.File]::WriteAllText($commandsPath, ($commands | ConvertTo-Json -Depth 10), $utf8)
    Write-Fixture 'config/workflow.template.yml' "name: Fixture`n# runtime @@RUNTIME@@`njobs:`n  verify:`n    name: fixture-check`n"
    Invoke-Mode 'regenerate before command classification negative' Generate 0
    Invoke-Mode 'internal validator is rejected' Check 1 -expectText 'may call only a public command'

    Write-Host 'V3 deployment lifecycle tests passed.'
} finally {
    if ([IO.Directory]::Exists($fixture)) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
