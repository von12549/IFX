[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ArchivePath,
    [Parameter(Mandatory)][string] $ReceiptPath,
    [Parameter(Mandatory)][string] $InstallRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$source = Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1i/Test-PublishedV4Base.ps1'
$body = [IO.File]::ReadAllText($source)
$changes = [ordered]@{
    '$receipt.files.Count -eq 136' = @('$receipt.files.Count -eq 137', 1)
    '$zipFiles.Count -eq 136' = @('$zipFiles.Count -eq 137', 1)
    '@($manifest.files).Count -eq 135' = @('@($manifest.files).Count -eq 136', 1)
    '12270a26f923a86f49be4ee0d003f5493b2562891fd1484a4fac079f02b73c95' = @('28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e', 1)
    '5bc176f61508fd01ddceb2d4e33ee34136493a35' = @('90aa87b5c5a8e866db3384564518377d50fe997c', 1)
    '922196c12917436b087c9c09361ca3669103992694eb5aa0ca8f2873ecc11a8d' = @('9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494', 1)
    'c052354ff6c068d740c7b7d8893da9eefbfee929bd0e396e4458741218d4a153' = @('b90d17b051b4c8fc5e2783c58cd7d98b29f7a0058e6bf7f1f6d54a5fc091d7eb', 1)
    '1.1.2' = @('1.1.3', 9)
}
foreach ($old in $changes.Keys) {
    $expected = [int]$changes[$old][1]
    $actual = [regex]::Matches($body, [regex]::Escape($old)).Count
    if ($actual -ne $expected) { throw "Historical base checker drift: $old count $actual, expected $expected." }
    $body = $body.Replace($old, [string]$changes[$old][0])
}
$work = Join-Path ([IO.Path]::GetTempPath()) ('ifx-v4-113-base-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
try {
    $adapted = Join-Path $work 'Test-PublishedV4Base113.adapted.ps1'
    $sidecar = Join-Path $work 'v4-guards-1.1.3.zip.sha256'
    [IO.File]::WriteAllText($adapted, $body, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($sidecar, '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e  v4-guards-1.1.3.zip', [Text.UTF8Encoding]::new($false))
    & pwsh -NoLogo -NoProfile -NonInteractive -File $adapted -ArchivePath $ArchivePath -ReceiptPath $ReceiptPath -InstallRoot $InstallRoot -SidecarPath $sidecar
    if ($LASTEXITCODE -ne 0) { throw "1.1.3 base check exited $LASTEXITCODE." }
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force
}
