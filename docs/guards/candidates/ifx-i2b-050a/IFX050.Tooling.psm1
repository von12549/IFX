# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-3: shared tooling for the
# ifx_profile 0.5.0-a module successors. The change specification (change-spec.json, accepted at A1-2) is the
# single source for each module's disposition, target version and kept or dropped Profile bindings.
Set-StrictMode -Version Latest

$script:Root = $PSScriptRoot
$script:Repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$script:Base044 = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.4.4'

function Get-IFX050Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

function Write-IFX050Json([string]$Path, $Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}

function Get-IFX050Spec {
    Get-Content -LiteralPath (Join-Path $script:Root 'change-spec.json') -Raw | ConvertFrom-Json -Depth 50
}

function Get-IFX050SpecModule([string]$ModuleId) {
    $m = @((Get-IFX050Spec).modules | Where-Object { $_.id -ceq $ModuleId })
    if ($m.Count -ne 1) { throw "Module is not in the change specification: $ModuleId" }
    $m[0]
}

function Get-IFX050ModuleRoot([string]$ModuleId) { Join-Path $script:Root "modules/$ModuleId" }

function Get-IFX050SourceModuleRoot([string]$ModuleId) {
    # The 0.4.4 source of a module, as recorded by the composed installation's authority map.
    $map = Get-Content -LiteralPath (Join-Path $script:Base044 'package/profiles/catalog/ifx_profile/authority-map.json') -Raw | ConvertFrom-Json -Depth 50
    $row = @($map.modules | Where-Object { $_.id -ceq $ModuleId })
    if ($row.Count -ne 1) { throw "Module is not in the 0.4.4 authority map: $ModuleId" }
    Join-Path $script:Repo ([string]$row[0].sourcePath)
}

function Copy-IFX050Module {
    # Copies the accepted 0.4.4 module source into the 0.5.0-a tree; the copy is then edited and re-manifested.
    [CmdletBinding()] param([Parameter(Mandatory)][string]$ModuleId)
    $spec = Get-IFX050SpecModule $ModuleId
    if ($spec.disposition -contains 'unchanged') { throw "Module is unchanged in 0.5.0-a: $ModuleId" }
    $to = Get-IFX050ModuleRoot $ModuleId
    if (Test-Path -LiteralPath $to) { throw "Module successor already exists: $to" }
    $from = Get-IFX050SourceModuleRoot $ModuleId
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to))
    Copy-Item -LiteralPath $from -Destination $to -Recurse
    $to
}

function Update-IFX050ModuleManifest {
    # Sets the specified version and recomputes the adapter, dependency-lock and authority hashes of module.json.
    [CmdletBinding()] param([Parameter(Mandatory)][string]$ModuleId)
    $spec = Get-IFX050SpecModule $ModuleId
    $root = Get-IFX050ModuleRoot $ModuleId
    $packageRoot = [IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($root))
    $manifestPath = Join-Path $root 'module.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 50
    if ($manifest.id -cne $ModuleId) { throw "Manifest id mismatch: $($manifest.id)" }
    $manifest.version = [string]$spec.newVersion
    $manifest.adapter.sha256 = Get-IFX050Sha256 (Join-Path $packageRoot $manifest.adapter.path)
    $manifest.dependencyLock.sha256 = Get-IFX050Sha256 (Join-Path $packageRoot $manifest.dependencyLock.path)
    foreach ($a in $manifest.authorities) { $a.sha256 = Get-IFX050Sha256 (Join-Path $packageRoot $a.path) }
    Write-IFX050Json $manifestPath $manifest
    [ordered]@{ id = $ModuleId; version = $manifest.version; adapterSha256 = $manifest.adapter.sha256 }
}

function Get-IFX050BaseConfig([string]$ModuleId) {
    # The module's config in the composed 0.4.4 Profile.
    $profile = Get-Content -LiteralPath (Join-Path $script:Base044 'package/profiles/catalog/ifx_profile/profile.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $row = @($profile.moduleSelections | Where-Object { $_.id -ceq $ModuleId })
    if ($row.Count -ne 1) { throw "Module is not selected by the 0.4.4 Profile: $ModuleId" }
    $row[0].config
}

function New-IFX050ModuleConfig {
    # The 0.5.0-a config: the 0.4.4 config without the removed fields and authority entries, with the policy hash of
    # the successor. Kept (governance) values are carried over unchanged, so a governance file that changed since the
    # 0.4.4 Target commit is reported by the module rather than silently re-pinned.
    [CmdletBinding()] param([Parameter(Mandatory)][string]$ModuleId)
    $spec = Get-IFX050SpecModule $ModuleId
    $config = Get-IFX050BaseConfig $ModuleId
    $removeFields = @($spec.profileConfig.remove | Where-Object { $_ -notmatch '^authorityHashes\[' })
    $removeAuthorities = @($spec.profileConfig.remove | Where-Object { $_ -match '^authorityHashes\[(.+)\]$' } | ForEach-Object { ($_ -replace '^authorityHashes\[(.+)\]$', '$1') })
    foreach ($f in $removeFields) { if ($config.Contains($f)) { $config.Remove($f) } else { throw "Field to remove is absent: $ModuleId.$f" } }
    if ($config.Contains('authorityHashes')) {
        # The specification keys an authority entry by its id, or by its index when the entry has no id.
        $all = @($config.authorityHashes); $kept = [Collections.Generic.List[object]]::new()
        for ($i = 0; $i -lt $all.Count; $i++) {
            $key = if ($all[$i].Contains('id')) { [string]$all[$i].id } else { [string]$i }
            if ($removeAuthorities -notcontains $key) { $kept.Add($all[$i]) }
        }
        $config.authorityHashes = @($kept.ToArray())
    }
    $policy = Join-Path (Get-IFX050ModuleRoot $ModuleId) 'policy.json'
    if (Test-Path -LiteralPath $policy) { $config.policySha256 = Get-IFX050Sha256 $policy }
    $config
}

Export-ModuleMember -Function Get-IFX050Sha256, Write-IFX050Json, Get-IFX050Spec, Get-IFX050SpecModule, Get-IFX050ModuleRoot,
    Get-IFX050SourceModuleRoot, Copy-IFX050Module, Update-IFX050ModuleManifest, Get-IFX050BaseConfig, New-IFX050ModuleConfig
