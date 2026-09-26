[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'IFX.C6.CertificationPolicy.psm1') -Force

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }

$cases = @(
    [ordered]@{name='all-pass';windows=$true;controls=$true;linux=$true;semantic='equal';product='pass';portability='pass'},
    [ordered]@{name='linux-process-failure';windows=$true;controls=$true;linux=$false;semantic='not-evaluated';product='pass';portability='advisory-fail'},
    [ordered]@{name='linux-report-failure';windows=$true;controls=$true;linux=$false;semantic='not-evaluated';product='pass';portability='advisory-fail'},
    [ordered]@{name='semantic-mismatch';windows=$true;controls=$true;linux=$true;semantic='different';product='pass';portability='advisory-fail'},
    [ordered]@{name='windows-failure';windows=$false;controls=$true;linux=$true;semantic='equal';product='fail';portability='pass'},
    [ordered]@{name='control-failure';windows=$true;controls=$false;linux=$true;semantic='equal';product='fail';portability='pass'}
)

foreach ($case in $cases) {
    $result = Resolve-IFXC6CertificationPolicy -WindowsPassed $case.windows -ControlsPassed $case.controls -LinuxPassed $case.linux -SemanticProjection $case.semantic
    Assert ($result.productCertification.status -ceq $case.product) "$($case.name): product result drift."
    Assert ($result.portabilityAssessment.status -ceq $case.portability) "$($case.name): portability result drift."
    Assert ($result.productCertification.deploymentPlatform -ceq 'windows-server') "$($case.name): deployment platform drift."
    Assert (-not $result.portabilityAssessment.blocking) "$($case.name): Linux portability became blocking."
    Assert ($result.v4PackageReleaseCertification -ceq 'not-adjudicated') "$($case.name): IFX run claimed V4 package release certification."
}

Write-Output "IFX C6 certification policy tests passed: $($cases.Count) cases."
