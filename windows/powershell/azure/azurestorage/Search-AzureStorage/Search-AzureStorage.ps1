<#
.SYNOPSIS
    Search for files in Azure Storage. Download a 'manifest' of all blobs in a container and iterate
    over the local copy to search for a blob by name.

.DESCRIPTION
    This script uses the Azure CLI to authenticate and list blobs in an Azure Storage container.
    It then uses a local copy of the container's blob manifest to search for a blob by name.

    You must have the `az` CLI installed, and you must run `az login` and authenticate with an account
    that has permissions/access to the storage account you are querying.

.PARAMETER ResourceGroupName
    The name of the resource group that contains the storage account.

.PARAMETER StorageAccountName
    The name of the storage account.

.PARAMETER ContainerName
    The name of the container in the storage account.

.PARAMETER ManifestFilePath
    The path to the local copy of the container's blob manifest.

.PARAMETER SearchString
    The string to search for in the blob manifest.

.EXAMPLE
    .\Search-AzureStorage.ps1 -ResourceGroupName "MyResourceGroup" -StorageAccountName "MyStorageAccount" -ContainerName "MyContainer" -ManifestFilePath "blob_manifest.json" -SearchString "MyBlobName"
#>
Param(
    [switch]$Debug,
    [switch]$Cleanup,
    [string]$ResourceGroupName = $null,
    [string]$StorageAccountName = $null,
    [string]$ContainerName = $null,
    [string]$ManifestFilePath = "blob_manifest.json",
    [string]$SearchString = $null
)

If ($Debug) {
    $DebugPreference = "Continue"
} else {
    $DebugPreference = "SilentlyContinue"
}

Write-Debug "Resource Group: $ResourceGroupName"
Write-Debug "Storage Account: $StorageAccountName"
Write-Debug "Container: $ContainerName"
Write-Debug "Manifest File: $ManifestFilePath"
Write-Debug "Search String: $SearchString"

## Validate input parameters
ForEach ($Item in @($ResourceGroupName, $StorageAccountName, $ContainerName, $ManifestFilePath)) {
    If ([string]::IsNullOrWhiteSpace($Item)) {
        Write-Error "You must provide a value for ResourceGroupName, StorageAccountName, ContainerName, and ManifestFilePath."
        Exit 1
    }
}

Function Check-AzCLI {
    <#
    .SYNOPSIS
    Check if the Azure CLI (az) tool is installed.
    
    .DESCRIPTION
    Attempts to locate the `az` command, and presents user with install URL if not found.
    
    .EXAMPLE
    Check-AzCLI
    #>
    Write-Host "Checking for Azure CLI (az) installation..." -ForegroundColor Cyan
    $AzCommand = Get-Command az -ErrorAction SilentlyContinue
    If (-not $AzCommand) {
        Write-Error "Azure CLI (az) is not installed. Please install it from https://aka.ms/azure-cli."
        Exit 1
    }
    Write-Host "Azure CLI (az) is installed." -ForegroundColor Green
}

Function Authenticate-AzCLI {
    <#
    .SYNOPSIS
    Authenticates with the Azure CLI (az).

    .DESCRIPTION
    Authenticates with the Azure CLI (az) using the `az login` command.
    
    .EXAMPLE
    Authenticate-AzCLI
    #>
    Write-Host "Authenticating with Azure CLI..." -ForegroundColor Cyan
    try {
        az account show -o none
        Write-Host "Azure CLI is authenticated." -ForegroundColor Green
    } catch {
        Write-Host "No active Azure CLI session found. Logging in..." -ForegroundColor Yellow
        az login --scope https://management.core.windows.net//.default
    }
}

# Retrieve blob manifest using Azure CLI
Function Get-BlobManifest {
    <#
    .SYNOPSIS
    Retrieves a blob manifest from an Azure Storage container.
    
    .DESCRIPTION
    Retrieves a blob manifest from an Azure Storage container using the `az storage blob list` command.
    
    .PARAMETER ResourceGroupName
    The name of the resource group that contains the storage account.
    
    .PARAMETER StorageAccountName
    The name of the storage account.
    
    .PARAMETER ContainerName
    The name of the container in the storage account.
    
    .PARAMETER ManifestFilePath
    The path to the local copy of the container's blob manifest.

    .EXAMPLE
    Get-BlobManifest -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -ContainerName $ContainerName -ManifestFilePath $ManifestFilePath
    #>
    Param(
        [string]$ResourceGroupName,
        [string]$StorageAccountName,
        [string]$ContainerName,
        [string]$ManifestFilePath
    )

    Write-Host "Retrieving blobs from container '$ContainerName'..." -ForegroundColor Cyan
    try {
        # Fetch storage account key
        $StorageAccountKey = az storage account keys list `
            --resource-group $ResourceGroupName `
            --account-name $StorageAccountName `
            --query "[0].value" -o tsv

        If (-not $StorageAccountKey) {
            Write-Error "Failed to retrieve the storage account key. Ensure the account exists and you have access."
            Exit 1
        }

        # List blobs and save manifest as JSON
        $BlobList = az storage blob list `
            --account-name $StorageAccountName `
            --account-key $StorageAccountKey `
            --container-name $ContainerName `
            --output json

        If ($null -eq $BlobList -or $BlobList -eq "") {
            Write-Error "No blobs were found in the specified container."
            Exit 1
        }

        $BlobList | Out-File -FilePath $ManifestFilePath -Encoding utf8
        Write-Host "Blob manifest saved to $ManifestFilePath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to retrieve blob manifest. $($_.Exception.Message)"
        Exit 1
    }
}

Function Search-Blobs {
    <#
    .SYNOPSIS
    Searches for blobs in a local copy of a container's blob manifest.
    
    .DESCRIPTION
    Searches for blobs in a local copy of a container's blob manifest using the -like operator with wildcards.
    
    .PARAMETER ManifestFilePath
    The path to the local copy of the container's blob manifest.
    
    .PARAMETER SearchString
    The string to search for in the blob manifest.
    
    .EXAMPLE
    Search-Blobs -ManifestFilePath $ManifestFilePath -SearchString $SearchString
    #>
    Param(
        [string]$ManifestFilePath,
        [string]$SearchString
    )

    Write-Host "Searching for blobs matching '$SearchString'..." -ForegroundColor Cyan
    try {

        ## Read the JSON file and convert it to an object
        $Blobs = Get-Content -Path $ManifestFilePath | ConvertFrom-Json
        
        ## Perform the search using the -like operator with wildcards
        $MatchingBlobs = $Blobs | Where-Object { $_.name -like "*$SearchString*" }

        If ($MatchingBlobs) {
            Write-Host "`nBlobs matching search string: '$($SearchString)':" -ForegroundColor Green

            $MatchingBlobs | Select-Object @{
                Name = 'Name'; Expression = { $_.name }
            }, @{
                Name = 'Deleted'; Expression = { $_.deleted }
            }, @{
                Name = 'BlobTierChangeTime'; Expression = { $_.properties.blobTierChangeTime }
            }, @{
                Name = 'BlobTier'; Expression = { $_.properties.blobTier }
            }, @{
                Name = 'BlobType'; Expression = { $_.properties.blobType }
            }, @{
                Name = 'CreationTime'; Expression = { $_.properties.creationTime }
            }, @{
                Name = 'DeletedTime'; Expression = { $_.properties.deletedTime }
            }, @{
                Name = 'ETag'; Expression = { $_.properties.etag }
            }, @{
                Name = 'LastModified'; Expression = { $_.properties.lastModified }
            }, @{
                Name = 'LeaseDuration'; Expression = { $_.properties.leaseDuration }
            }, @{
                Name = 'LeaseState'; Expression = { $_.properties.leaseState }
            }, @{
                Name = 'LeaseStatus'; Expression = { $_.properties.leaseStatus }
            }, @{
                Name = 'RehydratedPolicy'; Expression = { $_.properties.rehydratedPolicy }
            }, @{
                Name = 'Tags'; Expression = { $_.properties.metadata }
            } | Out-String

        } else {
            Write-Host "No blobs matched the search string." -ForegroundColor Yellow
        }

    } catch {
        Write-Error "Failed to search blobs. $($_.Exception.Message)"
        Exit 1
    }
}

## Check if manifest file already exists
If ( -Not (Test-Path $ManifestFilePath ) ) {
    Write-Host "No '$ManifestFilePath' file found. Querying Azure Storage for a manifest of all blobs & files in container: $($StorageAccountName)/$($ContainerName)" -ForegroundColor Magenta
    Check-AzCLI
    Authenticate-AzCLI
    Get-BlobManifest -ResourceGroupName $ResourceGroupName -StorageAccountName $StorageAccountName -ContainerName $ContainerName -ManifestFilePath $ManifestFilePath
} else {
    Write-Host "Using existing manifest file: $ManifestFilePath" -ForegroundColor Green
}

If ($SearchString) {
    Search-Blobs -ManifestFilePath $ManifestFilePath -SearchString $SearchString
}

## Remove manifest file if -Cleanup was specified
If ( $Cleanup ) {
    Write-Host "-Cleanup detected, removing manifest file: $ManifestFilePath" -ForegroundColor Magenta
    Remove-Item -Path $ManifestFilePath
}
