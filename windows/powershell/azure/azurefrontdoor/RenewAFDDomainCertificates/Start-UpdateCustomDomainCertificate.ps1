<#
    .SYNOPSIS
    This script updates the custom domain certificate for an Azure Front Door instance.

    .DESCRIPTION
    This PowerShell script is designed to update the custom domain certificate for an Azure Front Door instance. It uses the Azure CLI to perform the update, and it can operate in a dry run mode where no changes are made but the commands that would be executed are displayed.

    .PARAMETER AzSubscription
    The Azure subscription name or ID where the Front Door instance is located. This can be either the subscription name (e.g., 'connectivity') or the subscription ID (e.g., 'abc12345-6789-0123-4567-89abcdef0123').

    .PARAMETER ResourceGroup
    The name of the Azure resource group where the Front Door instance is located. This is required to identify the resource group that contains the Front Door instance.

    .PARAMETER FrontDoorName
    The name of the Azure Front Door instance for which the certificate is being rotated. This should match the name of the Front Door instance configured in Azure.

    .PARAMETER CustomDomainName
    The custom domain name for which the certificate is being rotated. This should match the domain configured in the Front Door instance. The script will format this domain name to a format accepted by the Azure CLI.

    .PARAMETER CertificateName
    The name of the certificate to rotate. This should match the name used in the Front Door configuration. The script will use this name to update the custom domain with the new certificate.

    .PARAMETER DryRun
    A switch parameter that, when specified, enables dry run mode. In this mode, the script will not make any changes but will output the commands that would be executed. This is useful for testing and verification purposes before making actual changes.

    .EXAMPLE
    Start-FrontdoorCertificatesRotation.ps1 -AzSubscription "connectivity" `
        -ResourceGroup "MyResourceGroup" `
        -FrontDoorName "MyFrontDoor" `
        -CustomDomainName "www.example.com" `
        -CertificateName "MyCertificate" `
        -DryRun
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "The Azure subscription name or ID, i.e. 'connectivity' or 'abc12345-6789-0123-4567-89abcdef0123'.")]
    [string]$AzSubscription,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure resource group name where the Front Door is located.")]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Front Door instance to rotate the certificate for.")]
    [string]$FrontDoorName,

    [Parameter(Mandatory = $false, HelpMessage = "The custom domain name for which the certificate is being rotated. This should match the domain configured in Front Door.")]
    [string]$CustomDomainName,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the certificate to rotate. This should match the name used in the Front Door configuration.")]
    [string]$CertificateName,

    [Parameter(Mandatory = $false, HelpMessage = "Do a dry run, where no actions are taken but the script will output what it would do.")]
    [switch]$DryRun
)

Write-Debug "Subscription: $AzSubscription"
Write-Debug "Resource Group: $ResourceGroup"
Write-Debug "Front Door Name: $FrontDoorName"
Write-Debug "Custom Domain Name: $CustomDomainName"
Write-Debug "Certificate Name: $CertificateName"

function Format-CustomDomainName {
    <#
        .SYNOPSIS
        Converts a custom domain name to a format accepted by the Azure CLI for Front Door.

        .DESCRIPTION
        This function takes a custom domain name and formats it by replacing dots and hyphens with dashes,
        and prepending "cd-" to the result. This is necessary because Azure CLI requires a specific format
        for custom domain names in Azure Front Door.

        .PARAMETER DomainIn
        The input domain name that needs to be formatted.
    #>
    [CmdletBinding()]
    Param(
        [string]$DomainIn
    )

    ## Convert the domain name to a format accepted by the Azure CLI
    $DomainOut = "cd-" + ($DomainIn -replace '\.', '-' -replace '\-', '-')

    $DomainOut
}

function Update-CustomDomainCertificate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "The Azure subscription name or ID, i.e. 'connectivity' or 'abc12345-6789-0123-4567-89abcdef0123'.")]
        [string]$AzSubscription,

        [Parameter(Mandatory = $false, HelpMessage = "The Azure resource group name where the Front Door is located.")]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Front Door instance to rotate the certificate for.")]
        [string]$FrontDoorName,

        [Parameter(Mandatory = $false, HelpMessage = "The custom domain name for which the certificate is being rotated. This should match the domain configured in Front Door.")]
        [string]$CustomDomainName,

        [Parameter(Mandatory = $false, HelpMessage = "The name of the certificate to rotate. This should match the name used in the Front Door configuration.")]
        [string]$CertificateName,

        [Parameter(Mandatory = $false, HelpMessage = "Do a dry run, where no actions are taken but the script will output what it would do.")]
        [switch]$DryRun
    )

    if ( $PSBoundParameters.ContainsKey('DryRun') ) {
        Write-Host "Running in dry run mode. No changes will be made." -ForegroundColor Magenta
    } else {
        Write-Host "Running in normal mode. Changes will be applied."
    }

    ## Validate input parameters
    if ( -not $AzSubscription ) {
        Write-Error "The AzSubscription parameter is required."
        return 1
    }

    if ( -not $ResourceGroup ) {
        Write-Error "The ResourceGroup parameter is required."
        return 1
    }

    if ( -not $FrontDoorName ) {
        Write-Error "The FrontDoorName parameter is required."
        return 1
    }

    if ( -not $CustomDomainName ) {
        Write-Error "The CustomDomainName parameter is required."
        return 1
    }

    if ( -not $CertificateName ) {
        Write-Error "The CertificateName parameter is required."
        return 1
    }

    ## Check if the Azure CLI is installed
    if ( -not ( Get-Command -Name "az" -ErrorAction SilentlyContinue ) ) {
        Write-Error "The az module is not installed. Please install it before continuing: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest"
        return 1
    }

    ## Set the Azure subscription context
    Write-Host "Setting Azure subscription context to '$AzSubscription'" -ForegroundColor Cyan
    az account set --subscription $AzSubscription
    if ( $LASTEXITCODE -ne 0 ) {
        Write-Error "Failed to set the Azure subscription context. Please check the subscription name or ID. You may also need to log in using 'az login'."
        return $LASTEXITCODE
    }

    ## Convert the custom domain name to a value accepted by the CLI
    Write-Host "Formatting custom domain name '$CustomDomainName' for Azure CLI" -ForegroundColor Cyan
    $CustomDomainNameEscaped = Format-CustomDomainName -DomainIn $CustomDomainName
    Write-Debug "Custom Domain Name Escaped: $CustomDomainNameEscaped"

    ## Build Azure CLI command to update the custom domain with the new certificate
    Write-Host "Building Azure CLI command to update the custom domain with the new certificate" -ForegroundColor Cyan
    $AzDomainUpdateCommand = "az afd custom-domain update --resource-group $ResourceGroup --profile-name $FrontDoorName --custom-domain-name $CustomDomainName --certificate-type CustomerCertificate --secret $CertificateName"
    Write-Debug "Azure CLI command:`n$AzDomainUpdateCommand"

    if ( $PSBoundParameters.ContainsKey('DryRun') ) {
        Write-Host "Dry run mode is enabled. The following command would be executed:" -ForegroundColor Magenta
        Write-Host $AzDomainUpdateCommand -ForegroundColor Magenta

        return 0
    }
    else {
        ## Execute the Azure CLI command to update the custom domain with the new certificate
        Write-Host "Executing Azure CLI command to update the custom domain with the new certificate..." -ForegroundColor Cyan
        try {
            Invoke-Expression $AzDomainUpdateCommand

            if ( $LASTEXITCODE -ne 0 ) {
                Write-Error "Failed to update the custom domain with the new certificate. Please check the command and try again."
                return $LASTEXITCODE
            }
            else {
                Write-Host "Custom domain updated successfully with the new certificate." -ForegroundColor Green
                return 0
            }
        } catch {
            Write-Error "An error occurred while executing the Azure CLI command: $($_.Exception.Message)"
            return 1
        }
    }

}

## Run the function if the script is called directly, i.e. ./Start-FrontdoorCertificatesRotation.ps1
# if ($PSCommandPath -eq $MyInvocation.MyCommand.Path) {
#     if ( $PSBoundParameters.ContainsKey('DryRun') ) {
#         Write-Host "Running in dry run mode. No changes will be made." -ForegroundColor Magenta
#     } else {
#         Write-Host "Running in normal mode. Changes will be applied."
#     }

#     $UpdateSuccess = Update-CustomDomainCertificate -AzSubscription $AzSubscription `
#         -ResourceGroup $ResourceGroup `
#         -FrontDoorName $FrontDoorName `
#         -CustomDomainName $CustomDomainName `
#         -CertificateName $CertificateName `
#         -DryRun:$DryRun
# }
