Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-IFXC6CertificationPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][bool]$WindowsPassed,
        [Parameter(Mandatory)][bool]$ControlsPassed,
        [Parameter(Mandatory)][bool]$LinuxPassed,
        [Parameter(Mandatory)][ValidateSet('equal','different','not-evaluated')][string]$SemanticProjection
    )

    $productReasons = [Collections.Generic.List[string]]::new()
    if (-not $WindowsPassed) { $productReasons.Add('windows-full-failed') }
    if (-not $ControlsPassed) { $productReasons.Add('certification-controls-failed') }
    $productStatus = if ($productReasons.Count -eq 0) { 'pass' } else { 'fail' }

    $portabilityReasons = [Collections.Generic.List[string]]::new()
    if (-not $LinuxPassed) { $portabilityReasons.Add('linux-complete-failed') }
    if ($SemanticProjection -cne 'equal') { $portabilityReasons.Add("semantic-projection-$SemanticProjection") }
    $portabilityStatus = if ($portabilityReasons.Count -eq 0) { 'pass' } else { 'advisory-fail' }

    [ordered]@{
        productCertification = [ordered]@{
            targetProduct = 'IFX'
            deploymentPlatform = 'windows-server'
            status = $productStatus
            blockingRequirements = @('windows-full','certification-controls')
            reasonCodes = @($productReasons.ToArray())
        }
        portabilityAssessment = [ordered]@{
            platform = 'linux-x64'
            blocking = $false
            status = $portabilityStatus
            semanticProjection = $SemanticProjection
            reasonCodes = @($portabilityReasons.ToArray())
        }
        v4PackageReleaseCertification = 'not-adjudicated'
    }
}

Export-ModuleMember -Function Resolve-IFXC6CertificationPolicy
