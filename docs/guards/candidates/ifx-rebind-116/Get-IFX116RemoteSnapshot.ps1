# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) step S9: GET-only snapshot of
# the live IFX rollback anchors and the standalone Guard release consumed by the successor specimen.
# Only GitHub GET requests are issued; nothing remote is changed.
[CmdletBinding()]
param([Parameter(Mandatory)][string] $OutputPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Get-Api([string] $Path) {
    $text = & gh api -X GET $Path
    if ($LASTEXITCODE -ne 0) { throw "GET failed: $Path" }
    $text | ConvertFrom-Json -Depth 100
}
$out = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $out) { throw "Snapshot already exists: $out" }

$ifx = Get-Api 'repos/von12549/IFX'
$default = Get-Api "repos/von12549/IFX/branches/$($ifx.default_branch)"
$dev = Get-Api 'repos/von12549/IFX/branches/codex%2Fv4-development-base'
$workflow = Get-Api "repos/von12549/IFX/contents/.github/workflows/v3-ifx-guardrails.yml?ref=$($dev.commit.sha)"
$ruleset = Get-Api 'repos/von12549/IFX/rulesets/23459908'
$checks = @($ruleset.rules | Where-Object type -ceq 'required_status_checks')
if ($checks.Count -ne 1) { throw 'IFX ruleset has no single required_status_checks rule.' }
$tagRef = Get-Api 'repos/von12549/Guard/git/ref/tags/v4-guards-v1.1.6'
$tagObject = Get-Api "repos/von12549/Guard/git/tags/$($tagRef.object.sha)"
$release = Get-Api 'repos/von12549/Guard/releases/tags/v4-guards-v1.1.6'

$snapshot = [ordered]@{
    formatVersion = 1; capturedAt = [DateTimeOffset]::UtcNow.ToString('o'); status = 'pass'; mode = 'github-get-only'
    repository = 'von12549/IFX'
    defaultBranch = [ordered]@{ name = $ifx.default_branch; commit = $default.commit.sha }
    developmentBranch = [ordered]@{ name = 'codex/v4-development-base'; remoteCommit = $dev.commit.sha; v3WorkflowPath = '.github/workflows/v3-ifx-guardrails.yml'; v3WorkflowBlob = $workflow.sha }
    ruleset = [ordered]@{
        id = $ruleset.id; name = $ruleset.name; enforcement = $ruleset.enforcement
        strict = [bool]$checks[0].parameters.strict_required_status_checks_policy
        includes = @($ruleset.conditions.ref_name.include)
        requiredContexts = @($checks[0].parameters.required_status_checks | ForEach-Object context)
    }
    guardRelease = [ordered]@{
        repository = 'von12549/Guard'; tag = $release.tag_name; tagObject = $tagRef.object.sha; commit = $tagObject.object.sha
        immutable = [bool]$release.immutable; url = $release.html_url
        assets = @($release.assets | ForEach-Object { [ordered]@{ name = $_.name; size = $_.size; digest = $_.digest; url = $_.browser_download_url } })
    }
    classification = [ordered]@{ remoteMutationPerformed = $false }
}
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($out))
[IO.File]::WriteAllText($out, (($snapshot | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output "GET-only snapshot written: $out"
