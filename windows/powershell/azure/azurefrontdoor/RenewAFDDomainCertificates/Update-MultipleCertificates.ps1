[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to a JSON file with the domains to update.")]
    [string]$DomainsJSONPath,
    [Parameter(Mandatory = $false, HelpMessage = "Enable dry run mode, no changes will be made.")]
    [Switch]$DryRun
)

$ThisDir = $PSScriptRoot
Write-Verbose "Script path: $ThisDir"

$RotationScript = Join-Path -Path $ThisDir -ChildPath "Start-UpdateCustomDomainCertificate.ps1"
Write-Verbose "Front Door certificate rotation script path: $RotationScript"

if ( -not ( Test-Path -Path "$($RotationScript)" -PathType Leaf ) ) {
    Write-Error "Rotation script not found at path: $RotationScript"
    exit 1
} else {
    Write-Debug "Rotation script found at path: $RotationScript"
}

. $RotationScript

Write-Verbose "Domains JSON Path: $($DomainsJSONPath)"
if ( -not ( Test-Path -Path "$($DomainsJSONPath)" -PathType Leaf ) ) {
    Write-Error "Domains JSON file not found at path: $DomainsJSONPath"
    exit 1
} else {
    Write-Debug "Domains JSON file found at path: $DomainsJSONPath"
}

## Load and parse the JSON file
try {
    $resources = Get-Content -Raw -Path "$DomainsJSONPath" | ConvertFrom-Json
} catch {
    Write-Error "Failed to read or parse the JSON file at path: $DomainsJSONPath. Error: $($_.Exception.Message)"
    exit 1
}
if ( -not $resources ) {
    Write-Error "No resources found in the JSON file at path: $DomainsJSONPath."
    exit 1
} else {
    Write-Debug "Resources loaded from JSON file: $($resources | ConvertTo-Json -Depth 5)"
}

## Iterate through each resource and update the custom domain certificate
foreach ( $resource in $resources ) {
    Write-Debug "Subscription: $($resource.AzSubscription)"
    Write-Debug "Resource group: $($resource.ResourceGroup)"
    Write-Debug "Front Door name: $($resource.FrontDoorName)"
    Write-Debug "Custom domain name: $($resource.CustomDomainName)"
    Write-Debug "Certificate secret name: $($resource.CertificateName)"

    
    $cmdParams = @{
        AzSubscription = $resource.AzSubscription
        ResourceGroup = $resource.ResourceGroup
        FrontDoorName = $resource.FrontDoorName
        CustomDomainName = $resource.CustomDomainName
        CertificateName = $resource.CertificateName
    }

    if ($PSBoundParameters.ContainsKey('DryRun')) {
        $cmdParams['DryRun'] = $true
    }

    try {
        $UpdateSuccess = Update-CustomDomainCertificate @cmdParams
        Write-Debug "Update-CustomDomainCertificate returned: $UpdateSuccess"
    } catch {
        Write-Error "An error occurred while processing the resource: $($_.Exception.Message)"
        continue
    }
}
