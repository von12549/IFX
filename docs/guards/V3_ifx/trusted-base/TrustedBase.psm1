Set-StrictMode -Version Latest

# Shared helpers for Plan 06 P2 trusted base guard execution: Git object plumbing, path containment,
# canonical JSON, D18 pointer roles and isolated child processes. Nothing here reads the target
# repository except through explicit parameters.

$script:GuardEnvironmentVariables = @('GUARD_TARGET_ROOT', 'GUARD_PLAN_PATH', 'GUARD_BASE_REF', 'GUARD_HEAD_REF', 'GUARD_GENERATED_ROOT', 'GUARD_GENERATION_ROOT', 'GUARD_BUILD_ROOT', 'GUARD_CONSUMED_AUTHORIZATIONS', 'GUARD_PROTECTED_CHANGES', 'GUARD_PROTECTION_PATH', 'LAYERGUARD_FIXTURES_ROOT', 'LAYERGUARD_PACKAGE_ROOT')

# Files outside docs/guards/ that the manifest checker validates as trusted components or compatibility entries.
$script:PackageRepositoryFiles = @('.github/workflows/v3-ifx-guardrails.yml', '.github/CODEOWNERS', 'Directory.Build.props', 'Directory.Packages.props', 'docs/Directory.Packages.props')
$script:PackageDirectories = @('docs/guards/V3', 'docs/guards/V3_ifx')
$script:AuthorizationDirectory = 'docs/guards/V3_ifx/stages/diff/authorizations/'

function Get-GuardFullPath([string] $Path) { return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) }

function Test-GuardPathWithin {
    param([string] $Path, [string] $Root)
    $full = Get-GuardFullPath $Path
    $rootFull = Get-GuardFullPath $Root
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    return $full.Equals($rootFull, $comparison) -or $full.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, $comparison)
}

function Invoke-GuardGit {
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][string[]] $Arguments, [switch] $AllowFailure)
    $output = @(& git -C $Repository @Arguments 2>$null)
    $exit = $LASTEXITCODE
    if ($exit -ne 0 -and -not $AllowFailure) { throw "git $($Arguments -join ' ') failed in ${Repository} (exit $exit)." }
    return $output
}

function Resolve-GuardCommit {
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][string] $Revision)
    $resolved = @(Invoke-GuardGit $Repository @('rev-parse', '--verify', '--quiet', "$Revision^{commit}") -AllowFailure)
    if ($LASTEXITCODE -ne 0 -or $resolved.Count -ne 1 -or $resolved[0] -notmatch '^[0-9a-f]{40}$') { throw "Revision does not resolve to a commit: $Revision" }
    return $resolved[0]
}

function Invoke-GuardGitNul {
    param([string] $Repository, [string[]] $Arguments)
    $info = [Diagnostics.ProcessStartInfo]::new('git')
    foreach ($argument in @('-C', $Repository) + $Arguments) { $info.ArgumentList.Add($argument) }
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($info)
    $memory = [IO.MemoryStream]::new()
    $process.StandardOutput.BaseStream.CopyTo($memory)
    $errorText = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "git $($Arguments -join ' ') failed: $errorText" }
    $text = [Text.UTF8Encoding]::new($false).GetString($memory.ToArray())
    return @($text.Split([char]0) | Where-Object { $_ -ne '' })
}

function Get-GuardChangedEntries {
    # Plan 06 §12.3: NUL-separated raw diff between verified commits, without rename detection.
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][string] $Base, [Parameter(Mandatory)][string] $Head)
    $tokens = @(Invoke-GuardGitNul $Repository @('diff', '--raw', '-z', '--no-renames', '--no-abbrev', $Base, $Head))
    $entries = [Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $tokens.Count; $i += 2) {
        $meta = $tokens[$i].TrimStart(':').Split(' ')
        if ($meta.Count -lt 5 -or ($i + 1) -ge $tokens.Count) { throw "Unexpected raw diff record: $($tokens[$i])" }
        $path = $tokens[$i + 1]
        $entries.Add([pscustomobject]@{
            Path = $path
            Status = $meta[4]
            Base = if ($meta[0] -eq '000000') { $null } else { New-GuardTuple $meta[0] $meta[2] }
            Head = if ($meta[1] -eq '000000') { $null } else { New-GuardTuple $meta[1] $meta[3] }
        })
    }
    return $entries.ToArray()
}

function New-GuardTuple([string] $Mode, [string] $ObjectId) {
    $type = switch ($Mode) { '040000' { 'tree' } '160000' { 'commit' } default { 'blob' } }
    return [ordered]@{ mode = $Mode; type = $type; objectId = $ObjectId }
}

function Test-GuardTupleEqual([object] $Left, [object] $Right) {
    if ($null -eq $Left -or $null -eq $Right) { return ($null -eq $Left) -and ($null -eq $Right) }
    return $Left.mode -eq $Right.mode -and $Left.type -eq $Right.type -and $Left.objectId -eq $Right.objectId
}

function Get-GuardBlobBytes {
    param([string] $Repository, [string] $Commit, [string] $Path)
    $exists = @(Invoke-GuardGit $Repository @('cat-file', '-e', "${Commit}:$Path") -AllowFailure)
    if ($LASTEXITCODE -ne 0) { return $null }
    $info = [Diagnostics.ProcessStartInfo]::new('git')
    foreach ($argument in @('-C', $Repository, 'cat-file', 'blob', "${Commit}:$Path")) { $info.ArgumentList.Add($argument) }
    $info.RedirectStandardOutput = $true
    $info.UseShellExecute = $false
    $process = [Diagnostics.Process]::Start($info)
    $memory = [IO.MemoryStream]::new()
    $process.StandardOutput.BaseStream.CopyTo($memory)
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "Cannot read ${Commit}:$Path" }
    return , $memory.ToArray()
}

function Get-GuardBlobText {
    param([string] $Repository, [string] $Commit, [string] $Path)
    $bytes = Get-GuardBlobBytes $Repository $Commit $Path
    if ($null -eq $bytes) { return $null }
    return [Text.UTF8Encoding]::new($false).GetString($bytes)
}

function Get-GuardSha256([byte[]] $Bytes) {
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function Get-GuardPackageRepositoryFiles {
    # Tracked files a package copy needs: both guard packages plus the files the manifest checker validates.
    param([Parameter(Mandatory)][string] $Repository)
    $files = @(Invoke-GuardGitNul $Repository (@('ls-files', '-z', '--') + $script:PackageDirectories + $script:PackageRepositoryFiles))
    return @($files | Where-Object { $_ -notmatch '(^|/)(bin|obj)/' -and -not $_.StartsWith('docs/guards/V3_ifx/analysis/ifx/refactor-baseline/ci-evidence/') })
}

function Copy-GuardFiles {
    param([string] $SourceRoot, [string] $DestinationRoot, [string[]] $RelativePaths)
    foreach ($relative in $RelativePaths) {
        $source = Join-Path $SourceRoot $relative
        if (-not [IO.File]::Exists($source)) { continue }
        $destination = Join-Path $DestinationRoot $relative
        if (-not (Test-GuardPathWithin $destination $DestinationRoot)) { throw "Unsafe copy destination: $relative" }
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::Copy($source, $destination, $true)
    }
}

function Get-GuardFileHashes {
    param([string] $Root, [string[]] $RelativePaths)
    $hashes = @{}
    foreach ($relative in $RelativePaths) {
        $path = Join-Path $Root $relative
        if ([IO.File]::Exists($path)) { $hashes[$relative] = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($path))) }
    }
    return $hashes
}

function Invoke-GuardIsolatedPwsh {
    # Runs a script in a separate pwsh process without guard environment variables inherited from the caller.
    param([Parameter(Mandatory)][string] $Script, [string[]] $Arguments = @(), [string] $WorkingDirectory, [hashtable] $Environment = @{})
    $info = [Diagnostics.ProcessStartInfo]::new('pwsh')
    foreach ($argument in @('-NoProfile', '-NonInteractive', '-File', $Script) + $Arguments) { $info.ArgumentList.Add($argument) }
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.RedirectStandardInput = $true
    $info.UseShellExecute = $false
    if ($WorkingDirectory) { $info.WorkingDirectory = $WorkingDirectory }
    foreach ($name in $script:GuardEnvironmentVariables) { [void]$info.Environment.Remove($name) }
    foreach ($name in $Environment.Keys) { $info.Environment[$name] = [string]$Environment[$name] }
    $process = [Diagnostics.Process]::Start($info)
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = ($stdout.Result + $stderr.Result) }
}

function ConvertTo-GuardCanonicalJson {
    # Ordinal key order, no insignificant whitespace; used for equality of JSON values.
    param([AllowNull()][object] $Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [Collections.IDictionary]) {
        $keys = [string[]]@($Value.Keys)
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        return '{' + (($keys | ForEach-Object { (ConvertTo-Json -InputObject $_ -Compress) + ':' + (ConvertTo-GuardCanonicalJson $Value[$_]) }) -join ',') + '}'
    }
    if ($Value -is [Collections.IList] -and $Value -isnot [string]) {
        return '[' + ((@($Value) | ForEach-Object { ConvertTo-GuardCanonicalJson $_ }) -join ',') + ']'
    }
    return ConvertTo-Json -InputObject $Value -Compress
}

function ConvertFrom-GuardJsonText([string] $Text) {
    return , (ConvertFrom-Json -InputObject $Text -AsHashtable -Depth 200 -NoEnumerate)
}

function Split-GuardPointer([string] $Pointer) {
    # The leading comma keeps a one-segment pointer from being unrolled into a plain string.
    if ([string]::IsNullOrEmpty($Pointer)) { return , [string[]]@() }
    return , [string[]]@($Pointer.Split('/') | Select-Object -Skip 1 | ForEach-Object { $_.Replace('~1', '/').Replace('~0', '~') })
}

function Test-GuardTemplatePrefix {
    # True when the template's segments match the first segments of a concrete path ('*' matches any segment).
    param([string[]] $Template, [string[]] $Segments)
    if ($Template.Count -gt $Segments.Count) { return $false }
    for ($i = 0; $i -lt $Template.Count; $i++) {
        if ($Template[$i] -ne '*' -and $Template[$i] -cne $Segments[$i]) { return $false }
    }
    return $true
}

function Get-GuardTcbComponentFor {
    # Longest-match lookup of an active trusted component path (files match exactly, directories by prefix).
    param([object] $Manifest, [string] $Path)
    if ($null -eq $Manifest) { return $null }
    $best = $null
    $bestLength = -1
    foreach ($component in @($Manifest.components)) {
        if ($component.status -ne 'active') { continue }
        foreach ($componentPath in @($component.paths)) {
            $match = $Path -ceq $componentPath -or ($componentPath.EndsWith('/') -and $Path.StartsWith($componentPath, [StringComparison]::Ordinal))
            if ($match -and $componentPath.Length -gt $bestLength) { $best = $component; $bestLength = $componentPath.Length }
        }
    }
    return $best
}

function Get-GuardTcbChanges {
    # Plan 06 §11.5: map the verified changed set onto trusted components. Paths the base manifest does not cover but the
    # head manifest registers count as changes of that head component; authorization records are handled by the protocol.
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][string] $Base, [Parameter(Mandatory)][string] $Head, [Parameter(Mandatory)][object] $BaseManifest, [object] $HeadManifest)
    $changes = [Collections.Generic.List[object]]::new()
    $authorizations = [Collections.Generic.List[object]]::new()
    $gitlinks = [Collections.Generic.List[string]]::new()
    foreach ($entry in @(Get-GuardChangedEntries $Repository $Base $Head)) {
        $isGitlink = ($null -ne $entry.Base -and $entry.Base.mode -eq '160000') -or ($null -ne $entry.Head -and $entry.Head.mode -eq '160000')
        if ($entry.Path.StartsWith($script:AuthorizationDirectory, [StringComparison]::Ordinal)) {
            if ($isGitlink) { $gitlinks.Add($entry.Path) } else { $authorizations.Add($entry) }
            continue
        }
        $component = Get-GuardTcbComponentFor $BaseManifest $entry.Path
        $source = 'base-manifest'
        if ($null -eq $component) { $component = Get-GuardTcbComponentFor $HeadManifest $entry.Path; $source = 'head-manifest' }
        if ($isGitlink -and ($null -ne $component -or $entry.Path.StartsWith('docs/guards/', [StringComparison]::Ordinal))) { $gitlinks.Add($entry.Path); continue }
        if ($null -eq $component) { continue }
        $changes.Add([pscustomobject]@{ Path = $entry.Path; Component = $component.id; Source = $source; Base = $entry.Base; Head = $entry.Head })
    }
    return [pscustomobject]@{
        Changes = $changes.ToArray()
        Components = [string[]]@($changes | ForEach-Object { $_.Component } | Sort-Object -Unique -CaseSensitive)
        Authorizations = $authorizations.ToArray()
        Gitlinks = $gitlinks.ToArray()
    }
}

function Get-GuardHeadExecutableReferences {
    # Executable entry points the head commit would activate: commands.json entry points and workflow script steps.
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][string] $Head)
    $references = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    $commands = Get-GuardBlobText $Repository $Head 'docs/guards/V3_ifx/shared/commands.json'
    if ($null -ne $commands) {
        # Maintenance commands never run on a verdict chain; the manifest checker applies the same rule.
        foreach ($command in @((ConvertFrom-Json $commands -AsHashtable -Depth 50).commands)) {
            if ($command.kind -ne 'maintenance' -and @($command.stages | Where-Object { $_ -in @('post', 'diff', 'ci') }).Count -gt 0) { [void]$references.Add([string]$command.entryPoint) }
        }
    }
    $workflow = Get-GuardBlobText $Repository $Head '.github/workflows/v3-ifx-guardrails.yml'
    if ($null -ne $workflow) { foreach ($match in [Regex]::Matches($workflow, '(?:\./|\$env:GUARD_BASE/)(docs/guards/[^\s''"]+\.psm?1)')) { [void]$references.Add($match.Groups[1].Value) } }
    return [string[]]@($references)
}

function Get-GuardTcbValidationSuite {
    # Base owns the suite of an existing component; only a component introduced by the head manifest brings its own.
    param([object] $BaseManifest, [object] $HeadManifest, [string[]] $Components)
    $suite = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    foreach ($id in $Components) {
        $component = @(@($BaseManifest.components | Where-Object { $_.id -eq $id }) + @(if ($null -ne $HeadManifest) { $HeadManifest.components | Where-Object { $_.id -eq $id } })) | Select-Object -First 1
        foreach ($item in @($component.validationSuite)) { [void]$suite.Add($item) }
    }
    return [string[]]@($suite)
}

function Read-GuardJsonBlob {
    param([string] $Repository, [string] $Commit, [string] $Path)
    $text = Get-GuardBlobText $Repository $Commit $Path
    if ($null -eq $text) { return $null }
    return , (ConvertFrom-Json $text -AsHashtable -Depth 100)
}

function Test-GuardJsonSchema {
    # Test-Json reports an unreadable schema as an error but can still return True, so every error counts as invalid.
    param([Parameter(Mandatory)][string] $Schema, [string] $Path, [string] $Json)
    try {
        $valid = if ($PSBoundParameters.ContainsKey('Json')) { Test-Json -Json $Json -SchemaFile $Schema -ErrorAction Stop } else { Test-Json -Path $Path -SchemaFile $Schema -ErrorAction Stop }
        return [bool]$valid
    }
    catch { return $false }
}

function Get-GuardTreeEntry {
    # Plan 06 §12.3: the tree entry tuple of one repository path at a commit (null when absent), read from the parent tree
    # so that the name comparison is ordinal on every platform.
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][string] $Commit, [Parameter(Mandatory)][string] $Path)
    $slash = $Path.LastIndexOf('/')
    $arguments = @('ls-tree', '-z', '--full-tree', $Commit)
    if ($slash -ge 0) { $arguments += @('--', $Path.Substring(0, $slash + 1)) }
    foreach ($line in @(Invoke-GuardGitNul $Repository $arguments)) {
        $tab = $line.IndexOf("`t")
        $meta = $line.Substring(0, $tab).Split(' ')
        if ($line.Substring($tab + 1) -ceq $Path) { return New-GuardTuple $meta[0] $meta[2] }
    }
    return $null
}

function Read-GuardProtection {
    # The Diff protection configuration of a package (Plan 06 P3.2), validated, with the SHA-256 of its exact bytes.
    param([Parameter(Mandatory)][string] $PackageRoot)
    $path = Join-Path $PackageRoot 'stages/diff/protection.json'
    if (-not [IO.File]::Exists($path)) { throw "Diff protection configuration is missing: $path" }
    if (-not (Test-GuardJsonSchema -Schema (Join-Path $PackageRoot 'contracts/protection.schema.json') -Path $path)) { throw "Diff protection configuration does not match its schema: $path" }
    $bytes = [IO.File]::ReadAllBytes($path)
    $document = ConvertFrom-Json ([Text.UTF8Encoding]::new($false).GetString($bytes)) -AsHashtable -Depth 20
    return [pscustomobject]@{
        Paths = [string[]]@($document.protectedPaths)
        AuthorizationDirectory = if ($document.ContainsKey('authorizationDirectory')) { [string]$document.authorizationDirectory } else { $null }
        Sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    }
}

function Test-GuardProtectedPath {
    # Same matching as the generated Diff test: entries ending in '/' protect a prefix, others one path; case is ignored.
    param([Parameter(Mandatory)][object] $Protection, [Parameter(Mandatory)][string] $Path)
    foreach ($entry in $Protection.Paths) {
        if ($entry.EndsWith('/')) { if ($Path.StartsWith($entry, [StringComparison]::OrdinalIgnoreCase)) { return $true } }
        elseif ($Path.Equals($entry, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Test-GuardTrustedBaseRecord {
    # Plan 06 §12.3 change-trusted-base checks of one base record against the verified trusted component changes. The caller
    # has already matched the component set; returns the failures.
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][string] $Head, [Parameter(Mandatory)][object] $Record, [Parameter(Mandatory)][object] $Tcb, [Parameter(Mandatory)][object] $BaseManifest, [object] $HeadManifest)
    $failures = [Collections.Generic.List[string]]::new()
    $actualPaths = [string[]]@($Tcb.Changes | ForEach-Object { $_.Path } | Sort-Object -Unique -CaseSensitive)
    $authorizedPaths = [string[]]@($Record.changedPaths | Sort-Object -Unique -CaseSensitive)
    if (($actualPaths -join "`n") -cne ($authorizedPaths -join "`n")) { $failures.Add("Changed trusted paths differ from the authorization. Actual: $($actualPaths -join ', '); authorized: $($authorizedPaths -join ', ')") }
    foreach ($change in $Tcb.Changes) {
        $entry = @($Record.entries | Where-Object { $_.path -ceq $change.Path })
        if ($entry.Count -ne 1) { $failures.Add("Authorization has no single entry for $($change.Path)"); continue }
        if ($entry[0].component -cne $change.Component) { $failures.Add("Authorization assigns $($change.Path) to $($entry[0].component), not $($change.Component)") }
        if (-not (Test-GuardTupleEqual $entry[0].base $change.Base)) { $failures.Add("Base tuple of $($change.Path) differs from the authorization.") }
        if (-not (Test-GuardTupleEqual $entry[0].head $change.Head)) { $failures.Add("Head tuple of $($change.Path) differs from the authorization.") }
    }
    $suite = Get-GuardTcbValidationSuite $BaseManifest $HeadManifest $Tcb.Components
    [string[]] $authorizedSuite = @($Record.validationSuite | Sort-Object -Unique -CaseSensitive)
    if ((@($suite | Sort-Object -Unique -CaseSensitive) -join "`n") -cne ($authorizedSuite -join "`n")) { $failures.Add("Authorization validationSuite differs from the base component suites: $(@($suite) -join ', ')") }
    foreach ($failure in (Test-GuardAuthorizationReferences $Repository $Head $Record)) { $failures.Add($failure) }
    return [string[]]@($failures)
}

function Read-GuardPolicyRegistry {
    # Plan 06 §12.4 policy and configuration registry of a package (D24), validated, with the SHA-256 of its exact bytes.
    param([Parameter(Mandatory)][string] $PackageRoot)
    $path = Join-Path $PackageRoot 'shared/policy-config.json'
    if (-not [IO.File]::Exists($path)) { throw "Policy and configuration registry is missing: $path" }
    if (-not (Test-GuardJsonSchema -Schema (Join-Path $PackageRoot 'contracts/policy-config.schema.json') -Path $path)) { throw "Policy and configuration registry does not match its schema: $path" }
    $bytes = [IO.File]::ReadAllBytes($path)
    $document = ConvertFrom-Json ([Text.UTF8Encoding]::new($false).GetString($bytes)) -AsHashtable -Depth 50
    $document['sha256'] = Get-GuardSha256 $bytes
    return $document
}

function Get-GuardPolicyEntry {
    # The registered entry of a repository path: exact paths first, then *.json files directly in a registered directory.
    param([Parameter(Mandatory)][object] $Registry, [Parameter(Mandatory)][string] $Path)
    foreach ($entry in @($Registry.entries)) { if ($entry.ContainsKey('paths') -and @($entry.paths) -ccontains $Path) { return $entry } }
    foreach ($entry in @($Registry.entries)) {
        if (-not $entry.ContainsKey('directory')) { continue }
        $directory = [string]$entry.directory
        if ($Path.StartsWith($directory, [StringComparison]::Ordinal) -and $Path.IndexOf('/', $directory.Length) -lt 0 -and $Path.EndsWith('.json', [StringComparison]::Ordinal)) { return $entry }
    }
    return $null
}

function Test-GuardPolicyScope {
    # True for a JSON path inside a registry root and outside its excluded protocol directories.
    param([Parameter(Mandatory)][object] $Registry, [Parameter(Mandatory)][string] $Path)
    if (-not $Path.EndsWith('.json', [StringComparison]::Ordinal)) { return $false }
    foreach ($excluded in @($Registry.excluded)) { if ($Path.StartsWith([string]$excluded, [StringComparison]::Ordinal)) { return $false } }
    foreach ($root in @($Registry.roots)) { if ($Path.StartsWith([string]$root, [StringComparison]::Ordinal)) { return $true } }
    return $false
}

function Get-GuardProjectionTargets {
    # Derived projections are exactly the targets that the base authority registry declares (D24).
    param([Parameter(Mandatory)][object] $Authorities, [string] $PackagePath = 'docs/guards/V3_ifx')
    $targets = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($projection in @(@($Authorities.projections) + @($Authorities.g04Bindings))) { [void]$targets.Add("$PackagePath/$($projection.target)") }
    return , $targets
}

function Add-GuardJsonDifferences {
    # Leaf JSON Pointers where two parsed documents differ; key order and whitespace never count (Plan 06 §12.4).
    param([AllowNull()][object] $Base, [AllowNull()][object] $Head, [string] $Pointer, [Collections.Generic.List[string]] $Differences)
    if ((ConvertTo-GuardCanonicalJson $Base) -ceq (ConvertTo-GuardCanonicalJson $Head)) { return }
    if ($Base -is [Collections.IDictionary] -and $Head -is [Collections.IDictionary]) {
        $keys = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
        foreach ($key in @($Base.Keys) + @($Head.Keys)) { [void]$keys.Add([string]$key) }
        foreach ($key in $keys) {
            $child = "$Pointer/" + $key.Replace('~', '~0').Replace('/', '~1')
            if (-not $Base.Contains($key) -or -not $Head.Contains($key)) { $Differences.Add($child); continue }
            Add-GuardJsonDifferences $Base[$key] $Head[$key] $child $Differences
        }
        return
    }
    $baseList = $Base -is [Collections.IList] -and $Base -isnot [string]
    $headList = $Head -is [Collections.IList] -and $Head -isnot [string]
    if ($baseList -and $headList) {
        $count = [Math]::Max($Base.Count, $Head.Count)
        for ($i = 0; $i -lt $count; $i++) {
            if ($i -ge $Base.Count -or $i -ge $Head.Count) { $Differences.Add("$Pointer/$i"); continue }
            Add-GuardJsonDifferences $Base[$i] $Head[$i] "$Pointer/$i" $Differences
        }
        return
    }
    $Differences.Add($Pointer)
}

function Get-GuardPolicyChanges {
    # Semantic changes of registered policy and configuration files between two commits (D24). JSON is compared after
    # parsing, normalized text after line-ending normalization; an added, removed or unparsable file changes at the root
    # pointer. Unregistered JSON files that head adds or changes inside the registry roots, and unregistered .gitattributes
    # files, are reported separately. Derived projection targets are never policy changes themselves.
    param([Parameter(Mandatory)][string] $Repository, [Parameter(Mandatory)][string] $Base, [Parameter(Mandatory)][string] $Head, [Parameter(Mandatory)][object] $Registry, [Parameter(Mandatory)][Collections.Generic.HashSet[string]] $ProjectionTargets, [object[]] $Entries)
    $changes = [Collections.Generic.List[object]]::new()
    $unregistered = [Collections.Generic.List[string]]::new()
    $utf8 = [Text.UTF8Encoding]::new($false)
    foreach ($entry in @($Entries)) {
        $path = [string]$entry.Path
        if (($null -ne $entry.Base -and $entry.Base.type -ne 'blob') -or ($null -ne $entry.Head -and $entry.Head.type -ne 'blob')) { continue }
        $policy = Get-GuardPolicyEntry $Registry $path
        if ($null -eq $policy) {
            $leaf = $path.Substring($path.LastIndexOf('/') + 1)
            if ($null -ne $entry.Head -and ($leaf -ceq '.gitattributes' -or ((Test-GuardPolicyScope $Registry $path) -and -not $ProjectionTargets.Contains($path)))) { $unregistered.Add($path) }
            continue
        }
        $baseBytes = if ($null -ne $entry.Base) { Get-GuardBlobBytes $Repository $Base $path } else { $null }
        $headBytes = if ($null -ne $entry.Head) { Get-GuardBlobBytes $Repository $Head $path } else { $null }
        $pointers = [Collections.Generic.List[string]]::new()
        if ($null -eq $baseBytes -or $null -eq $headBytes) { $pointers.Add('') }
        else {
            $baseText = $utf8.GetString($baseBytes).Replace("`r`n", "`n")
            $headText = $utf8.GetString($headBytes).Replace("`r`n", "`n")
            if ($policy.format -eq 'normalized-text') { if ($baseText -cne $headText) { $pointers.Add('') } }
            else {
                try { Add-GuardJsonDifferences (ConvertFrom-GuardJsonText $baseText) (ConvertFrom-GuardJsonText $headText) '' $pointers }
                catch { $pointers.Clear(); $pointers.Add('') }
            }
        }
        if ($pointers.Count -eq 0) { continue }
        $changes.Add([pscustomobject]@{
            Path = $path
            Entry = $policy
            Schema = if ($policy.ContainsKey('schema')) { [string]$policy.schema } else { [string]$policy.format }
            Base = $entry.Base
            Head = $entry.Head
            BaseSha256 = if ($null -ne $baseBytes) { Get-GuardSha256 $baseBytes } else { $null }
            HeadSha256 = if ($null -ne $headBytes) { Get-GuardSha256 $headBytes } else { $null }
            Pointers = [string[]]@($pointers | Sort-Object -Unique -CaseSensitive)
        })
    }
    return [pscustomobject]@{ Changes = $changes.ToArray(); Unregistered = $unregistered.ToArray() }
}

function Add-GuardSchemaFieldPointers {
    # JSON Pointers of every property definition in a schema document; each needs a monotonicity declaration (D13, D24).
    param([AllowNull()][object] $Node, [string] $Pointer, [Collections.Generic.List[string]] $Pointers)
    if ($Node -is [Collections.IDictionary]) {
        foreach ($key in @($Node.Keys)) {
            $child = "$Pointer/" + ([string]$key).Replace('~', '~0').Replace('/', '~1')
            if ([string]$key -ceq 'properties' -and $Node[$key] -is [Collections.IDictionary]) {
                foreach ($name in @($Node[$key].Keys)) {
                    $property = "$child/" + ([string]$name).Replace('~', '~0').Replace('/', '~1')
                    $Pointers.Add($property)
                    Add-GuardSchemaFieldPointers $Node[$key][$name] $property $Pointers
                }
            }
            else { Add-GuardSchemaFieldPointers $Node[$key] $child $Pointers }
        }
    }
    elseif ($Node -is [Collections.IList] -and $Node -isnot [string]) {
        for ($i = 0; $i -lt $Node.Count; $i++) { Add-GuardSchemaFieldPointers $Node[$i] "$Pointer/$i" $Pointers }
    }
}

function Test-GuardMonotonicityDeclarations {
    # Every property definition of every schema a registry entry names is declared exactly once; returns the failures.
    param([Parameter(Mandatory)][object] $Registry, [Parameter(Mandatory)][scriptblock] $ReadSchemaText)
    $failures = [Collections.Generic.List[string]]::new()
    $schemas = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in @($Registry.entries)) { if ($entry.ContainsKey('schema')) { [void]$schemas.Add([string]$entry.schema) } }
    foreach ($schema in $schemas) {
        $declarations = @(@($Registry.monotonicity) | Where-Object { $_.schema -ceq $schema })
        if ($declarations.Count -ne 1) { $failures.Add("Schema $schema needs exactly one monotonicity declaration block."); continue }
        $text = & $ReadSchemaText $schema
        if ($null -eq $text) { $failures.Add("Registered schema is missing: $schema"); continue }
        $pointers = [Collections.Generic.List[string]]::new()
        Add-GuardSchemaFieldPointers (ConvertFrom-GuardJsonText $text) '' $pointers
        $actual = [Collections.Generic.SortedSet[string]]::new([string[]]@($pointers), [StringComparer]::Ordinal)
        $declared = [Collections.Generic.SortedSet[string]]::new([string[]]@(@($declarations[0].fields) | ForEach-Object { [string]$_.pointer }), [StringComparer]::Ordinal)
        foreach ($pointer in $actual) { if (-not $declared.Contains($pointer)) { $failures.Add("Schema field without a monotonicity declaration: $schema#$pointer") } }
        foreach ($pointer in $declared) { if (-not $actual.Contains($pointer)) { $failures.Add("Monotonicity declaration for a missing schema field: $schema#$pointer") } }
    }
    foreach ($block in @($Registry.monotonicity)) { if (-not $schemas.Contains([string]$block.schema)) { $failures.Add("Monotonicity declarations for an unregistered schema: $($block.schema)") } }
    return [string[]]@($failures)
}

function Test-GuardAuthorizationReferences {
    param([string] $Repository, [string] $Head, [object] $Record)
    $failures = [Collections.Generic.List[string]]::new()
    foreach ($path in @($Record.planPath) + @($Record.decisionPaths)) {
        [void](Invoke-GuardGit $Repository @('cat-file', '-e', "${Head}:$path") -AllowFailure)
        if ($LASTEXITCODE -ne 0) { $failures.Add("Authorization reference is missing in head: $path") }
    }
    return [string[]]@($failures)
}

Export-ModuleMember -Function * -Variable PackageRepositoryFiles, PackageDirectories, AuthorizationDirectory, GuardEnvironmentVariables
