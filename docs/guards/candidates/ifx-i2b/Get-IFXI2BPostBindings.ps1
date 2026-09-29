# IFX I2-B (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step B2, finding F3: per-module hash bindings of the
# composed ifx_profile. Counts, for each Pre and Post module, the evidence lock it reads and the target-file hash
# bindings in its Profile config (authorityHashes entries and *Sha256 fields other than policySha256 and
# evidenceLockSha256), and names the whole-tree fingerprints.
[CmdletBinding()]
param(
    [string]$InstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.4.4',
    [Parameter(Mandatory)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputPath) { throw "Output already exists: $OutputPath" }
$profilePath = Join-Path $InstallRoot 'package/profiles/catalog/ifx_profile/profile.json'
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json -Depth 100
$pre = @($profile.stageConfiguration.pre.modules); $post = @($profile.stageConfiguration.post.modules)
$rows = foreach ($m in $profile.moduleSelections) {
    $c = $m.config; $names = @($c.PSObject.Properties.Name)
    $authority = if ($names -contains 'authorityHashes') { @($c.authorityHashes).Count } else { 0 }
    $fields = @($names | Where-Object { $_ -match 'Sha256$' -and $_ -notin @('policySha256', 'evidenceLockSha256') })
    [ordered]@{
        module = $m.id; stage = $(if ($pre -contains $m.id) { 'pre' } elseif ($post -contains $m.id) { 'post' } else { 'none' })
        evidenceLock = $names -contains 'evidenceLockPath'
        authorityHashes = $authority; hashFields = $fields.Count; bindings = $authority + $fields.Count
        treeFingerprints = @($fields | Where-Object { $_ -match 'Tree' })
    }
}
$postRows = @($rows | Where-Object { $_.stage -ceq 'post' })
$record = [ordered]@{
    formatVersion = 1; kind = 'ifx-i2b-b2-post-bindings'
    profile = [ordered]@{ path = 'package/profiles/catalog/ifx_profile/profile.json'; version = $profile.version; sha256 = (Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    workspaceEvidenceRoots = @($profile.workspaceEvidence.relativeRoots)
    summary = [ordered]@{
        preModules = $pre.Count; postModules = $post.Count
        postWithLock = @($postRows | Where-Object { $_.evidenceLock }).Count
        postWithBindings = @($postRows | Where-Object { $_.bindings -gt 0 }).Count
        postBindings = [int](($postRows | ForEach-Object { $_.bindings } | Measure-Object -Sum).Sum)
        postWithTreeFingerprint = @($postRows | Where-Object { @($_.treeFingerprints).Count -gt 0 }).Count
        postWithNeither = @($postRows | Where-Object { -not $_.evidenceLock -and $_.bindings -eq 0 } | ForEach-Object { $_.module })
    }
    modules = @($rows)
}
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($OutputPath)))
[IO.File]::WriteAllText($OutputPath, (($record | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
$record.summary | ConvertTo-Json -Compress
