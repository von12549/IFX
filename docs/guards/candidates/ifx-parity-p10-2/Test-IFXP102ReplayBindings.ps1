[CmdletBinding()]
param(
    [string] $InstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4-ifx-0.4.2-c6e-r1',
    [string] $WindowsEvidenceRoot = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-114/c6c-recovery-042-full/windows',
    [string] $RuntimeRoot = 'D:/IFX-Root/guard-runtime/evidence/p10-2-r2-repair-042',
    [string] $OutputPath = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-114/p10-2-r2-repair-042/replay-bindings.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Sha([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Text-Sha([string] $Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($Text))).ToLowerInvariant() }
function Fingerprint([string] $Root) {
    @((Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Sha $_.FullName)"
    })) -join "`n"
}
function Write-Json([string] $Path,$Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))
}

$install = [IO.Path]::GetFullPath($InstallRoot)
$windows = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($WindowsEvidenceRoot))
$runtime = [IO.Path]::GetFullPath($RuntimeRoot)
$output = [IO.Path]::GetFullPath($OutputPath)
if (-not [IO.Directory]::Exists($install) -or -not [IO.Directory]::Exists($windows)) { throw 'Frozen installation or C6c Windows evidence is missing.' }
if ([IO.Directory]::Exists($runtime) -or [IO.File]::Exists($output) -or [IO.Directory]::Exists([IO.Path]::GetDirectoryName($output))) { throw 'R2 repair evidence paths must be absent.' }
[void][IO.Directory]::CreateDirectory($runtime)

$profilePath = Join-Path $install 'package/profiles/catalog/ifx_profile/profile.json'
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -LiteralPath (Join-Path $windows 'case-manifest.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$records = @(Get-Content -LiteralPath (Join-Path $windows 'captures/c6c4.jsonl') | ForEach-Object { $_ | ConvertFrom-Json -AsHashtable -Depth 100 })
$ids = @('ifx-provider-cycle/M','ifx-provider-cycle/Z','ifx-provider-cycle/V/PROVIDER-CYCLE','ifx-source-policy/V/DECLARATION-IMPLEMENTS')
$results = [Collections.Generic.List[object]]::new()

foreach ($id in $ids) {
    $case = @($manifest.cases | Where-Object { [string]$_.id -ceq $id })
    if ($case.Count -ne 1) { throw "Certified case missing: $id" }
    $capture = @($records | Where-Object { [string]$_.moduleId -ceq [string]$case[0].moduleId -and [string]$_.fixtureSha256 -ceq [string]$case[0].fixtureSha256 })
    if ($capture.Count -ne 1) { throw "Certified capture missing or ambiguous: $id" }
    $capture = $capture[0]
    $adapter = [IO.Path]::GetFullPath([string]$capture.executed)
    $installedAdapter = Join-Path $install "package/modules/$($case[0].moduleId)/adapter.ps1"
    if (-not [IO.File]::Exists($adapter) -or -not $adapter.StartsWith($windows+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Sha $adapter) -cne (Sha $installedAdapter)) { throw "Provider adapter binding failed: $id" }
    $providerRoot = [IO.Path]::GetDirectoryName($adapter)
    $providerBefore = Fingerprint $providerRoot
    $target = [IO.Path]::GetFullPath([string]$capture.targetRoot)
    $targetBefore = Fingerprint $target
    if ($targetBefore -cne [string]$capture.targetAfter) { throw "Target fingerprint drift: $id" }
    $selection = @($profile.moduleSelections | Where-Object { [string]$_.id -ceq [string]$case[0].moduleId })
    if ($selection.Count -ne 1) { throw "Profile selection drift: $id" }
    $config = $selection[0].config | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
    $policyPath = Join-Path $providerRoot 'policy.json'
    $config.policySha256 = if ([IO.File]::Exists($policyPath)) { Sha $policyPath } else { '0' * 64 }
    $safe = $id -replace '[^A-Za-z0-9._-]','_'
    $payload = [ordered]@{formatVersion=1;stage='pre';targetRoot=$target;packageRoot=Join-Path $install 'package';stateRoot=Join-Path $runtime "$safe/state";evidenceRoot=Join-Path $runtime "$safe/evidence";projectId='ifx-c6c4-supplemental';relativeRoots=@('src');config=$config}
    $payloadJson = $payload | ConvertTo-Json -Depth 100 -Compress
    $previous = $env:V4_STAGE_INPUT_JSON
    try {
        $env:V4_STAGE_INPUT_JSON = $payloadJson
        $text = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1)
        $code = $LASTEXITCODE
    } finally { $env:V4_STAGE_INPUT_JSON = $previous }
    if ($code -ne 0) { throw "Replay adapter process failed: $id / $($text -join "`n")" }
    $current = ($text -join "`n") | ConvertFrom-Json -AsHashtable -Depth 100
    $certified = ([string]$capture.output) | ConvertFrom-Json -AsHashtable -Depth 100
    $currentSemantic = [ordered]@{status=$current.status;exitCategory=$current.exitCategory;findings=@($current.findings);coverage=@($current.coverage)} | ConvertTo-Json -Depth 100 -Compress
    $certifiedSemantic = [ordered]@{status=$certified.status;exitCategory=$certified.exitCategory;findings=@($certified.findings);coverage=@($certified.coverage)} | ConvertTo-Json -Depth 100 -Compress
    $providerAfter = Fingerprint $providerRoot; $targetAfter = Fingerprint $target
    if ($currentSemantic -cne $certifiedSemantic -or $providerAfter -cne $providerBefore -or $targetAfter -cne $targetBefore) { throw "Replay semantic or invariant mismatch: $id" }
    $results.Add([ordered]@{id=$id;moduleId=[string]$case[0].moduleId;adapterSha256=Sha $adapter;providerFingerprintSha256=Text-Sha $providerBefore;targetFingerprintSha256=Text-Sha $targetBefore;inputSha256=Text-Sha $payloadJson;status=[string]$current.status;exitCategory=[string]$current.exitCategory;semanticSha256=Text-Sha $currentSemantic})
}

Write-Json $output ([ordered]@{formatVersion=1;status='pass';caseCount=$results.Count;cases=@($results.ToArray());installProfileSha256=Sha $profilePath;boundary=[ordered]@{frozenInputsChanged=$false;p10_3Started=$false}})
Write-Output "P10.2 replay-binding test passed: $($results.Count) certified supplemental cases."
