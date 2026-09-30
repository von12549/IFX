# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: the 0.5.0-a matrix fixture
# specification; successor of candidates/ifx-rebind-116/fixture-spec-116.json (unchanged). The I1 matrix proved 153 of
# its 191 core cases from the 0.4.4 suites and 38 from the c6c4 supplemental fixtures. For 0.5.0-a:
# - the 25 changed modules are proved by their own suites (suites/<id>.cases.json) run in capture mode; the catalog
#   cases added for the matrix carry a note beginning 'A1-4 matrix' and are listed here;
# - the 12 unchanged modules keep their 0.4.4 suites and the supplemental fixtures that concern them
#   (Test-IFX050SupplementalFixtures.ps1, listed here).
# Sources are bound by their UTF-8/LF text hash (ruling R5), so a Windows and a Linux checkout agree.
[CmdletBinding()]
param(
    [string]$ContractPath = 'docs/guards/candidates/ifx-i2b-051/matrix-contract-050.json',
    [string]$OutputPath = 'docs/guards/candidates/ifx-i2b-051/fixture-spec-050.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Rel([string]$Path) { [IO.Path]::GetRelativePath($repo, $Path).Replace('\', '/') }

$sources = [ordered]@{}
$cases = [Collections.Generic.List[object]]::new()
$supplemental = Join-Path $PSScriptRoot 'Test-IFX050SupplementalFixtures.ps1'
$sources.supplemental = [ordered]@{ path = Rel $supplemental; sha256 = Get-IFX050PinSha256 $supplemental }
$supplementalCases = [ordered]@{
    'ifx-provider-cycle/M' = 'policy-local provider graph authority absent'
    'ifx-provider-cycle/Z' = 'policy-local provider graph with zero provider edges'
    'ifx-provider-cycle/V/PROVIDER-CYCLE' = 'policy-local provider graph A -> B -> C -> A'
    'ifx-package-reference/Z' = 'one out-of-scope project selects no governed ring'
    'ifx-ring-graph/Z' = 'one out-of-scope project selects no governed ring'
    'ifx-ownership-graph/Z' = 'one out-of-scope project selects no governed ring'
    'ifx-injection/Z' = 'CRM Application and Infrastructure projects with no governed dependency'
    'ifx-source-policy/Z' = 'CRM projects with no governed import, declaration, symbol or payload'
    'ifx-source-policy/V/DECLARATION-IMPLEMENTS' = 'disposable blocking mustImplement declaration and a Gateway that does not implement it'
    'ifx-source-policy/A/DECLARATION-PLACEMENT-ADVISORY' = 'a command validator placed in Domain'
    'ifx-history-integrity/M' = 'absent history target'
    'architecture-conformance/C' = 'synthetic Contracts and Application assemblies without a forbidden dependency'
    'architecture-conformance/M' = 'assembly manifest naming an absent DLL'
    'architecture-conformance/Z' = 'forbidden-dependency rule over an absent source namespace'
    'architecture-conformance/V/ARCH.TYPE_DEPENDENCY' = 'Application type exposing a forbidden Contracts type'
}
foreach ($k in $supplementalCases.Keys) { $cases.Add([ordered]@{ id = $k; source = 'supplemental'; fixture = $k; recipe = $supplementalCases[$k] }) }
foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'suites') -File -Filter '*.cases.json' | Sort-Object Name)) {
    $catalog = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -Depth 30
    $key = "suite:$($catalog.moduleId)"
    $sources[$key] = [ordered]@{ path = Rel $file.FullName; sha256 = Get-IFX050PinSha256 $file.FullName }
    foreach ($c in @($catalog.cases | Where-Object { $_.PSObject.Properties.Name -contains 'note' -and ([string]$_.note).StartsWith('A1-4 matrix', [StringComparison]::Ordinal) })) {
        $cases.Add([ordered]@{ id = "$($catalog.moduleId)/$($c.id)"; source = $key; fixture = [string]$c.id; recipe = [string]$c.note })
    }
}
$spec = [ordered]@{
    formatVersion = 1
    id = 'ifx-050a-matrix-fixtures'
    status = 'complete'
    derivedFrom = [ordered]@{ path = 'docs/guards/candidates/ifx-rebind-116/fixture-spec-116.json'; sha256 = Get-IFX050PinSha256 (Full 'docs/guards/candidates/ifx-rebind-116/fixture-spec-116.json') }
    matrixContractSha256 = Get-IFX050PinSha256 (Full $ContractPath)
    requiredCoreCases = 191
    supplementalCaseCount = $supplementalCases.Count
    suiteMatrixCaseCount = $cases.Count - $supplementalCases.Count
    sources = $sources
    cases = @($cases.ToArray())
}
Write-IFX050Json (Full $OutputPath) $spec
"fixture spec: $(Full $OutputPath) ($($cases.Count) cases, $($sources.Count) sources)"
