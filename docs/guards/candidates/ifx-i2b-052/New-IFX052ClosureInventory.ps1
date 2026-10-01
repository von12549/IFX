# IFX I2-B amendment A3 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A3-1: the closure inventory of bundle
# 0.5.1 and its specimen (finding F-C1 of I2-C). It collects every docs/guards path that runs on a main that admits only
# docs/guards/v4-adoption:
#  - the specimen's paths (trusted-base checkouts and environment values);
#  - the string constants of the staging script, of every producer it runs and of every script in the producer package
#    (PowerShell AST string constants, so comments do not count; simple variables holding a docs/guards path are expanded;
#    Join-Path $PSScriptRoot literals resolve against the script's directory);
#  - the graph producer policy's sourcePolicies, which the producer checks in the Target;
#  - the bundle's runtime JSON values (producer scripts, the staging script, workspaceEvidence roots).
# Each path is classified v4-adoption, relocate (an origin listed in closure-spec.json, by file or containing directory)
# or unlisted. The inventory passes when nothing is unlisted; the post-relocation view maps every relocate path to its
# destination and must lie entirely under the allowed root. It also records the identity of every relocate and extract
# origin. -Check re-derives the inventory and compares it with the committed one.
[CmdletBinding()]
param(
    [string]$SpecPath = (Join-Path $PSScriptRoot 'closure-spec.json'),
    [string]$OutPath = (Join-Path $PSScriptRoot 'closure-inventory.json'),
    [switch]$Check
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Rel([string]$Path) { [IO.Path]::GetRelativePath($repo, $Path).Replace('\', '/') }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function TextHash([string]$Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant() }
function LfHash([string]$Path) { TextHash ([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")) }
function Write-Json([string]$Path, $Value) { [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }

$spec = Get-Content -LiteralPath $SpecPath -Raw | ConvertFrom-Json -Depth 20
$allowed = [string]$spec.allowedRoot
$moves = @(@($spec.relocate) + @($spec.extract))
$productRoots = @($spec.productSourceRoots)
$guardsPattern = [regex]'(?i)^docs/guards/'

function Get-Class([string]$Path) {
    $p = $Path.Replace('\', '/').TrimEnd('/')
    if (-not $guardsPattern.IsMatch($p)) {
        if ($p.StartsWith('artifacts/', [StringComparison]::Ordinal)) { return 'output' }
        if (@($productRoots | Where-Object { $p -ceq $_ -or $p.StartsWith("$_/", [StringComparison]::Ordinal) }).Count) { return 'product-source' }
        return 'other-target'
    }
    if ($p -ceq $allowed -or $p.StartsWith("$allowed/", [StringComparison]::Ordinal)) { return 'v4-adoption' }
    if (@($moves | Where-Object { [string]$_.origin -ceq $p -or ([string]$_.origin).StartsWith("$p/", [StringComparison]::Ordinal) }).Count) { return 'relocate' }
    return 'unlisted'
}
function Get-Destination([string]$Path) {
    $hit = @($moves | Where-Object { [string]$_.origin -ceq $Path })
    if ($hit.Count) { return [string]$hit[0].destination }
    # A directory that contains origins maps to the common destination directory of those origins.
    $dirs = @($moves | Where-Object { ([string]$_.origin).StartsWith("$Path/", [StringComparison]::Ordinal) } | ForEach-Object { ([string]$_.destination).Substring(0, ([string]$_.destination).LastIndexOf('/')) } | Sort-Object -Unique)
    if ($dirs.Count -eq 1) { return $dirs[0] }
    return $null
}

# String constants of a script, with simple docs/guards variables expanded.
function Get-ScriptReferences([string]$Path) {
    $tokens = $null; $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count) { throw "Parse error in $(Rel $Path)" }
    $vars = @{}
    foreach ($a in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] }, $true)) {
        if ($a.Left -is [Management.Automation.Language.VariableExpressionAst] -and $a.Right -is [Management.Automation.Language.CommandExpressionAst] -and $a.Right.Expression -is [Management.Automation.Language.StringConstantExpressionAst]) {
            $value = $a.Right.Expression.Value
            if ($guardsPattern.IsMatch($value)) { $vars[$a.Left.VariablePath.UserPath] = $value }
        }
    }
    $dir = [IO.Path]::GetDirectoryName($Path)
    $refs = [Collections.Generic.List[object]]::new()
    foreach ($n in $ast.FindAll({ param($x) $x -is [Management.Automation.Language.StringConstantExpressionAst] -or $x -is [Management.Automation.Language.ExpandableStringExpressionAst] }, $true)) {
        if ($n.Parent -is [Management.Automation.Language.ExpandableStringExpressionAst]) { continue }
        # A prefix variable's own value is not a read; its expansions are recorded where they are used.
        if ($n.Parent -is [Management.Automation.Language.CommandExpressionAst] -and $n.Parent.Parent -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Parent.Parent.Left -is [Management.Automation.Language.VariableExpressionAst] -and $vars.ContainsKey($n.Parent.Parent.Left.VariablePath.UserPath)) { continue }
        $text = if ($n -is [Management.Automation.Language.ExpandableStringExpressionAst]) {
            $t = $n.Value; foreach ($k in $vars.Keys) { $t = $t.Replace("`$$k/", "$($vars[$k])/").Replace("`$($k)/", "$($vars[$k])/") }; $t
        } else { $n.Value }
        $parent = $n.Parent
        $base = $null
        if ($parent -is [Management.Automation.Language.CommandAst] -and $parent.GetCommandName() -ceq 'Join-Path') {
            $elements = @($parent.CommandElements)
            $index = [Array]::IndexOf($elements, $n)
            if ($index -ge 2 -and $elements[$index - 1] -is [Management.Automation.Language.VariableExpressionAst]) { $base = $elements[$index - 1].VariablePath.UserPath }
        }
        if ($base -ceq 'PSScriptRoot') {
            $resolved = Rel ([IO.Path]::GetFullPath((Join-Path $dir $text)))
            $refs.Add([ordered]@{ literal = $text; base = 'PSScriptRoot'; path = $resolved; class = (Get-Class $resolved) })
        } elseif ($guardsPattern.IsMatch($text)) {
            $refs.Add([ordered]@{ literal = $text; base = $(if ($base) { $base } else { 'literal' }); path = $text; class = (Get-Class $text) })
        }
    }
    # one row per distinct (base, path)
    $seen = @{}; @($refs | Where-Object { $k = "$($_.base)|$($_.path)"; if ($seen.ContainsKey($k)) { $false } else { $seen[$k] = $true; $true } })
}

$head = (& git -C $repo rev-parse HEAD).Trim()
$roots = [ordered]@{}
$unlisted = [Collections.Generic.List[object]]::new()
function Add-Root([string]$Name, [string]$Kind, [object[]]$References) {
    foreach ($r in $References) { if ($r.class -ceq 'unlisted') { $unlisted.Add([ordered]@{ root = $Name; path = $r.path; literal = $r.literal }) } }
    $roots[$Name] = [ordered]@{ kind = $Kind; references = @($References) }
}

# 1. specimen
$specimenPath = Join-Path $repo $spec.roots.specimen
$specimenRefs = @([regex]::Matches([IO.File]::ReadAllText($specimenPath), '(?i)docs/guards/[A-Za-z0-9_./-]*[A-Za-z0-9_]') | ForEach-Object { $_.Value } | Sort-Object -Unique | ForEach-Object { [ordered]@{ literal = $_; base = 'trusted-base'; path = $_; class = (Get-Class $_) } })
Add-Root $spec.roots.specimen 'specimen' $specimenRefs

# 2. staging script, the producers it runs and every script in the producer package
$staging = Join-Path $repo $spec.roots.stagingScript
$stagingRefs = @(Get-ScriptReferences $staging)
Add-Root $spec.roots.stagingScript 'staging' $stagingRefs
$scripts = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
foreach ($r in $stagingRefs) { if ($r.path -like '*.ps1') { [void]$scripts.Add($r.path) } }
foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $repo $spec.roots.producerPackage) -Recurse -File -Filter '*.ps1')) { [void]$scripts.Add((Rel $f.FullName)) }
foreach ($s in $scripts) {
    $full = Join-Path $repo $s
    if (-not [IO.File]::Exists($full)) { $unlisted.Add([ordered]@{ root = $spec.roots.stagingScript; path = $s; literal = 'missing script' }); continue }
    Add-Root $s 'producer-script' @(Get-ScriptReferences $full)
}

# 3. the graph producer policy's sourcePolicies (checked in the Target by path and hash)
foreach ($m in @($spec.relocate | Where-Object kind -CEQ 'lab-policy')) {
    $policy = Get-Content -LiteralPath (Join-Path $repo $m.origin) -Raw | ConvertFrom-Json -Depth 20
    Add-Root $m.origin 'producer-policy' @(@($policy.sourcePolicies) | ForEach-Object { [ordered]@{ literal = $_.path; base = 'target'; path = [string]$_.path; class = (Get-Class ([string]$_.path)); sha256 = [string]$_.sha256 } })
}

# 4. bundle runtime JSON values
$bundle = Join-Path $repo $spec.roots.bundlePackage
$runtimeKeys = @($spec.runtimeJsonKeys)
function Get-JsonRuntime($Node, [string]$Key, [string]$Pointer, [Collections.Generic.List[object]]$Out) {
    if ($Node -is [Collections.IDictionary]) { foreach ($k in $Node.Keys) { Get-JsonRuntime $Node[$k] ([string]$k) "$Pointer/$k" $Out } }
    elseif ($Node -is [Collections.IList] -and $Node -isnot [string]) { for ($i = 0; $i -lt $Node.Count; $i++) { Get-JsonRuntime $Node[$i] $Key "$Pointer/$i" $Out } }
    elseif ($Node -is [string] -and $guardsPattern.IsMatch($Node) -and $Key -cin $runtimeKeys) { $Out.Add([ordered]@{ literal = $Node; base = $Pointer; path = $Node; class = (Get-Class $Node) }) }
}
$bundleRefs = [Collections.Generic.List[object]]::new()
foreach ($f in @(Get-ChildItem -LiteralPath $bundle -Recurse -File -Filter '*.json' | Sort-Object FullName)) {
    $refsHere = [Collections.Generic.List[object]]::new()
    Get-JsonRuntime (Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 100) '' '' $refsHere
    foreach ($r in $refsHere) { $r.base = "$([IO.Path]::GetRelativePath($bundle, $f.FullName).Replace('\', '/'))#$($r.base)"; $bundleRefs.Add($r) }
}
Add-Root 'bundle 0.5.1' 'bundle-runtime' @($bundleRefs)

# post-relocation view
$post = [Collections.Generic.List[object]]::new()
foreach ($name in $roots.Keys) {
    foreach ($r in @($roots[$name].references)) {
        if ($r.class -ceq 'relocate') {
            $d = Get-Destination $r.path
            $post.Add([ordered]@{ root = $name; from = $r.path; to = $d; underAllowedRoot = ($null -ne $d -and ($d -ceq $allowed -or $d.StartsWith("$allowed/", [StringComparison]::Ordinal))) })
        }
    }
}
$origins = foreach ($m in $moves) {
    $p = Join-Path $repo $m.origin
    if (-not [IO.File]::Exists($p)) { throw "Origin is missing: $($m.origin)" }
    $blob = (& git -C $repo rev-parse "HEAD:$($m.origin)" 2>$null); if ($LASTEXITCODE -ne 0) { throw "Origin is not tracked at HEAD: $($m.origin)" }
    $row = [ordered]@{ origin = $m.origin; destination = $m.destination; kind = $m.kind; sha256 = Hash $p; lfSha256 = LfHash $p; gitBlob = $blob.Trim(); lines = @([IO.File]::ReadAllLines($p)).Count; usedBy = @(@($post | Where-Object { $_.from -ceq $m.origin -or ([string]$m.origin).StartsWith("$($_.from)/", [StringComparison]::Ordinal) } | ForEach-Object root) | Sort-Object -Unique) }
    if ($m.kind -ceq 'lab-aggregate') {
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$errors)
        $branch = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.IfStatementAst] -and $n.Clauses[0].Item1.Extent.Text -ceq "`$Mode -ceq 'Aggregate'" }, $true))
        if ($branch.Count -ne 1) { throw 'The Aggregate branch is not unique.' }
        $row.branch = [ordered]@{ startLine = $branch[0].Extent.StartLineNumber; endLine = $branch[0].Extent.EndLineNumber; sha256 = TextHash $branch[0].Extent.Text.ReplaceLineEndings("`n") }
    }
    $row
}
$postFailures = @($post | Where-Object { -not $_.underAllowedRoot })
$inventory = [ordered]@{
    formatVersion = 1; kind = 'ifx-052-closure-inventory'; specSha256 = LfHash $SpecPath; allowedRoot = $allowed
    origins = @($origins)
    roots = $roots
    counts = [ordered]@{
        roots = $roots.Count
        references = (@($roots.Values | ForEach-Object { @($_.references).Count }) | Measure-Object -Sum).Sum
        relocate = $post.Count
        unlisted = $unlisted.Count
    }
    postRelocation = @($post)
    unlistedReads = @($unlisted)
    status = $(if ($unlisted.Count -eq 0 -and $postFailures.Count -eq 0) { 'pass' } else { 'fail' })
}
if ($Check) {
    $committed = Get-Content -LiteralPath $OutPath -Raw | ConvertFrom-Json -Depth 30 | ConvertTo-Json -Depth 30 -Compress
    $derived = $inventory | ConvertTo-Json -Depth 30 | ConvertFrom-Json -Depth 30 | ConvertTo-Json -Depth 30 -Compress
    if ($committed -cne $derived) { throw 'Committed closure inventory differs from the re-derived inventory.' }
    Write-Output "Closure inventory re-derived: equal ($($inventory.counts.references) references, status $($inventory.status))"
} else {
    Write-Json $OutPath $inventory
    Write-Output "Closure inventory: $($inventory.counts.roots) roots, $($inventory.counts.references) references, $($post.Count) to relocate, unlisted $($unlisted.Count), status $($inventory.status)"
}
if ($inventory.status -cne 'pass') { $unlisted | ForEach-Object { Write-Warning "unlisted: $($_.root) -> $($_.path) ($($_.literal))" }; $postFailures | ForEach-Object { Write-Warning "post: $($_.from) -> $($_.to)" }; exit 1 }
