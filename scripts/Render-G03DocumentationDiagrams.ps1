[CmdletBinding()]
param(
    [string] $MermaidCliVersion = '11.17.0'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$diagramDirectory = Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/diagrams'
$sources = Get-ChildItem -LiteralPath $diagramDirectory -Filter '*.mmd' | Sort-Object Name
if ($sources.Count -ne 5) { throw "Expected exactly five G03 Mermaid sources; found $($sources.Count)." }

foreach ($source in $sources) {
    foreach ($extension in @('svg', 'png')) {
        $output = [IO.Path]::ChangeExtension($source.FullName, $extension)
        & npx --yes "@mermaid-js/mermaid-cli@$MermaidCliVersion" -i $source.FullName -o $output -b white
        if ($LASTEXITCODE -ne 0) { throw "Mermaid rendering failed for $($source.Name) -> $extension." }
    }
}

Write-Host "Rendered $($sources.Count) G03 diagrams to SVG and PNG with Mermaid CLI $MermaidCliVersion."

