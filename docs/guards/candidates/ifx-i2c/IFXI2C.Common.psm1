# IFX I2-C (Plan 20261001-v4-ifx-i2c-main-promotion): shared helpers for the local steps C1-C4.
Set-StrictMode -Version Latest

$script:Repository = 'von12549/IFX'
$script:RulesetId = 23459908
$script:RequiredContexts = @(
    'v3-pre-diff', 'v3-architecture', 'v3-quality-solution', 'v3-quality-assembly', 'v3-quality-frontend',
    'v3-specialized-g03', 'v3-specialized-g04', 'v3-specialized-g05', 'v3-specialized-plan04',
    'v3-specialized-database', 'v3-historical-integrity', 'v3-cross-platform-ubuntu-latest',
    'v3-cross-platform-windows-latest')

function Get-IFXI2CRepositoryName { $script:Repository }
function Get-IFXI2CRulesetId { $script:RulesetId }
function Get-IFXI2CRequiredContexts { $script:RequiredContexts }

function Assert-IFXI2C([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }

function Invoke-IFXI2CGit {
    param([string] $Root, [string[]] $Arguments, [switch] $AllowFailure)
    $output = @(& git -C $Root -c core.longpaths=true @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) { throw "git $($Arguments -join ' ') failed: $($output -join ' | ')" }
    return , $output
}

# GET-only GitHub API read. The method is fixed; nothing else is accepted.
function Invoke-IFXI2CGitHubGet([string] $Endpoint) {
    $text = (& gh api --method GET $Endpoint 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "gh api GET $Endpoint failed: $text" }
    return $text
}

function ConvertTo-IFXI2CCanonicalJson($Value) {
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [System.Collections.IDictionary]) {
        $parts = foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)) {
            (ConvertTo-Json -Compress -InputObject $key) + ':' + (ConvertTo-IFXI2CCanonicalJson $Value[$key])
        }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [string]) { return ConvertTo-Json -Compress -InputObject $Value }
    if ($Value -is [System.Collections.IEnumerable]) {
        return '[' + (@($Value | ForEach-Object { ConvertTo-IFXI2CCanonicalJson $_ }) -join ',') + ']'
    }
    return ConvertTo-Json -Compress -InputObject $Value
}

function Get-IFXI2CStringSha256([string] $Text) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    return ([Security.Cryptography.SHA256]::HashData($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Get-IFXI2CFileSha256([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

# The ruleset without volatile response fields, canonicalized, so that C1 and C10 compare the configuration only.
function Get-IFXI2CRulesetIdentity {
    $raw = Invoke-IFXI2CGitHubGet "repos/$script:Repository/rulesets/$script:RulesetId"
    $ruleset = $raw | ConvertFrom-Json -AsHashtable -Depth 100
    $config = [ordered]@{}
    foreach ($key in 'id', 'name', 'target', 'source_type', 'source', 'enforcement', 'conditions', 'rules', 'bypass_actors') { $config[$key] = $ruleset[$key] }
    $canonical = ConvertTo-IFXI2CCanonicalJson $config
    return [ordered]@{ configuration = $config; canonicalSha256 = Get-IFXI2CStringSha256 $canonical; updatedAt = $ruleset['updated_at'] }
}

function Write-IFXI2CJson([string] $Path, $Value) {
    $directory = Split-Path -Parent $Path
    if (-not [IO.Directory]::Exists($directory)) { [void][IO.Directory]::CreateDirectory($directory) }
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
}

Export-ModuleMember -Function *
