[CmdletBinding()]
param([string] $EvidenceRoot = 'artifacts/guards/p10-ifx-c1c2-113/revalidation')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$out = if ([IO.Path]::IsPathFullyQualified($EvidenceRoot)) { [IO.Path]::GetFullPath($EvidenceRoot) } else { [IO.Path]::GetFullPath((Join-Path $repo $EvidenceRoot)) }
$archive = Join-Path $repo 'artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip'
$receipt = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json'
$install = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3'
$baseHelper = Join-Path $PSScriptRoot 'Test-PublishedV4Base113.ps1'
$run = Join-Path $out ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($run)
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Text([string] $Path, [string] $Value) {
    [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($Path)))
    [IO.File]::WriteAllText($Path, $Value, [Text.UTF8Encoding]::new($false))
}
function Replace-Exact([string] $Body, [string] $Old, [string] $New, [int] $Count) {
    $actual = [regex]::Matches($Body, [regex]::Escape($Old)).Count
    if ($actual -ne $Count) { throw "Source adaptation drift: '$Old' occurs $actual times, expected $Count." }
    return $Body.Replace($Old, $New)
}
function Inventory([string] $Root) {
    return (@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/'))|$(Hash $_.FullName)"
    }) -join "`n")
}

$baseOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $baseHelper -ArchivePath $archive -ReceiptPath $receipt -InstallRoot $install 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Published 1.1.3 base check failed: $($baseOutput -join "`n")" }
$base = [string]$baseOutput[-1] | ConvertFrom-Json
if ($base.status -cne 'pass' -or $base.version -cne '1.1.3' -or $base.verifiedFiles -ne 137) { throw 'Published 1.1.3 base check returned unexpected identity.' }
$rootBefore = Inventory $install
Write-Text (Join-Path $run 'base.json') (($base | ConvertTo-Json -Depth 20) + "`n")

$shadow = Join-Path $run 'c2e-shadow'
[void][IO.Directory]::CreateDirectory((Join-Path $shadow 'fixtures'))
$c2e = Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c2e'
Copy-Item -LiteralPath (Join-Path $c2e 'profile.json') -Destination (Join-Path $shadow 'profile.json')
Copy-Item -LiteralPath (Join-Path $c2e 'fixtures/cases.json') -Destination (Join-Path $shadow 'fixtures/cases.json')
$lock = Get-Content -LiteralPath (Join-Path $c2e 'authority-lock.json') -Raw | ConvertFrom-Json -Depth 100
if ($lock.publishedBaseVersion -cne '1.1.2' -or $lock.publishedPackageSha256 -cne '922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d' -or
    (Hash (Join-Path $shadow 'profile.json')) -cne $lock.profileSha256) { throw 'Historical C2e authority lock or Profile drift.' }
$lock.publishedBaseVersion = '1.1.3'
$lock.publishedPackageSha256 = [string]$base.packageHash
$lock.profilePath = [IO.Path]::GetRelativePath($repo, (Join-Path $shadow 'profile.json')).Replace('\','/')
Write-Text (Join-Path $shadow 'authority-lock.json') (($lock | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n")

$suites = @(
    @('c1b','Test-IFXDomainReference.ps1',2), @('c1c','Test-IFXPackageReference.ps1',2),
    @('c1d','Test-IFXRingGraph.ps1',2), @('c1e','Test-IFXOwnershipGraph.ps1',2),
    @('c1f','Test-IFXProviderCycle.ps1',2), @('c1g','Test-IFXEmbeddedAdapter.ps1',2),
    @('c1h','Test-IFXSourcePolicy.ps1',2), @('c1j','Test-IFXProjectName.ps1',1),
    @('c1k','Test-IFXProviderReference.ps1',1), @('c1n','Test-IFXReferenceCycle.ps1',1),
    @('c1o','Test-IFXInjection.ps1',1), @('c2b1','Test-IFXG03GovernanceCore.ps1',1),
    @('c2b2','Test-IFXG03CatalogSemantics.ps1',1), @('c2c1','Test-IFXG03SourceReconciliation.ps1',1),
    @('c2c2','Test-IFXG03Snapshots.ps1',1), @('c2d','Test-IFXG03DocsCloseout.ps1',1),
    @('c2e','Test-IFXG03Combined.ps1',6)
)
$results = [Collections.Generic.List[object]]::new()
foreach ($suite in $suites) {
    $id = [string]$suite[0]
    $sourceDirectory = Join-Path $repo "docs/guards/candidates/ifx-gate-coverage-$id"
    $source = Join-Path $sourceDirectory "tests/$($suite[1])"
    $body = [IO.File]::ReadAllText($source)
    $body = Replace-Exact $body '1.1.2' '1.1.3' ([int]$suite[2])
    $rootText = if ($id -ceq 'c2e') { $shadow.Replace('\','/') } else { $sourceDirectory.Replace('\','/') }
    $body = Replace-Exact $body '$candidateRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ''..''))' ("`$candidateRoot = '" + $rootText + "'") 1
    if ($id -ceq 'c2e') {
        $body = Replace-Exact $body '$repoRoot = [IO.Path]::GetFullPath((Join-Path $candidateRoot ''../../../..''))' ("`$repoRoot = '" + $repo.Replace('\','/') + "'") 1
    }
    $helperOld = 'docs/guards/candidates/ifx-gate-coverage-c1i/Test-PublishedV4Base.ps1'
    $helperCount = if ($id -in @('c1b','c1c','c1d','c1e','c1f','c1g','c1h')) { 0 } else { 1 }
    $body = Replace-Exact $body $helperOld 'docs/guards/candidates/ifx-gate-coverage-revalidation-113/Test-PublishedV4Base113.ps1' $helperCount
    $oldArchive = '12270a26f923a86f49be4ee0d003f5493b2562891fd1484a4fac079f02b73c95'
    $oldPackage = '922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d'
    $constantCount = if ($helperCount -eq 0) { 1 } else { 0 }
    $body = Replace-Exact $body $oldArchive '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e' $constantCount
    $body = Replace-Exact $body $oldPackage '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494' $constantCount
    if ($body.Contains('1.1.2') -or $body.Contains($oldArchive) -or $body.Contains($oldPackage) -or $body.Contains($helperOld)) { throw "Historical base identity remains in adapted $id script." }
    $adapted = Join-Path $run "scripts/$id.ps1"
    Write-Text $adapted $body
    $log = Join-Path $run "logs/$id.log"
    [void][IO.Directory]::CreateDirectory(([IO.Path]::GetDirectoryName($log)))
    Write-Output "Running $id on published 1.1.3..."
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapted -EvidenceRoot (Join-Path $run "suites/$id") -BaseInstallRoot $install -BaseReceiptPath $receipt -BaseArchivePath $archive 2>&1)
    $exitCode = $LASTEXITCODE
    Write-Text $log (($output | Out-String) + "`n")
    $results.Add([ordered]@{ id=$id; status=$(if($exitCode -eq 0){'pass'}else{'fail'}); exitCode=$exitCode; sourcePath=[IO.Path]::GetRelativePath($repo,$source).Replace('\','/'); sourceSha256=Hash $source; adaptedSha256=Hash $adapted; logPath=[IO.Path]::GetRelativePath($repo,$log).Replace('\','/') })
    Write-Output "$id exit $exitCode"
}
$applicability = Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1m/tests/Test-IFXApplicability.ps1'
$appLog = Join-Path $run 'logs/c1m.log'
$appOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $applicability -RepositoryRoot $repo 2>&1)
$appExit = $LASTEXITCODE
Write-Text $appLog (($appOutput | Out-String) + "`n")
$results.Add([ordered]@{ id='c1m'; status=$(if($appExit -eq 0){'pass'}else{'fail'}); exitCode=$appExit; sourcePath=[IO.Path]::GetRelativePath($repo,$applicability).Replace('\','/'); sourceSha256=Hash $applicability; logPath=[IO.Path]::GetRelativePath($repo,$appLog).Replace('\','/') })
$rootAfter = Inventory $install
$immutable = $rootBefore -ceq $rootAfter
$summary = [ordered]@{ status=$(if(@($results | Where-Object status -ne 'pass').Count -eq 0 -and $immutable){'pass'}else{'fail'}); base=$base; installedRootImmutable=$immutable; c2eProfileSha256=Hash (Join-Path $shadow 'profile.json'); c2eLockSha256=Hash (Join-Path $shadow 'authority-lock.json'); suites=@($results) }
Write-Text (Join-Path $run 'summary.json') (($summary | ConvertTo-Json -Depth 50).Replace("`r`n", "`n") + "`n")
Write-Output "Revalidation summary: $(Join-Path $run 'summary.json')"
if ($summary.status -cne 'pass') { exit 1 }
