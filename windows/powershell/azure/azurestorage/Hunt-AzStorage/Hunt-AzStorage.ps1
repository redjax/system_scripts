<#
    .SYNOPSIS
    Retrieve empty files and BLOBs from Azure Storage.

    .DESCRIPTION
    Connects to an Azure Storage account and scans for empty files/BLOBs, and large files/BLOBs.

    .PARAMETER ConfigPath
    The path to a JSON configuration file for the script.

    .PARAMETER SizeThreshold
    The size (in bytes) threshold for large files/BLOBs. Default is 104857600 (100MB).
    The equation for converting size in bytes to size in MB is: $Bytes * 1024 * 1024.
    1MB = 1048576, 10MB = 10485760, 100MB = 104857600

    .EXAMPLE
    .\Hunt-AzStorage.ps1 -ConfigPath path/to/params.json
#>

Param(
    [Parameter(Mandatory = $false, HelpMessage = "Enter a path to a configuration JSON file for the script")]
    [string]$ConfigPath = "./params.json",
    [Parameter(Mandatory = $false, HelpMessage = "Enter a size threshold (i.e. 100MB) for large files/BLOBs")]
    [int64]$SizeThreshold = 104857600
)

$DefaultConfig = [PSCustomObject]@{
    storage_account   = "default-storage-account"
    storage_key       = "default-storage-key"
    subscription_id   = "default-subscription-id"
    resource_group    = "default-resource-group"
    tenant_id         = "default-tenant-id"
    blob_container    = "default-blob-container"
    file_share        = "default-file-share"
    connection_string = $null
}

function Convert-BytesToHumanReadable {
    param (
        [int64]$Bytes
    )

    if ($Bytes -lt 1KB) {
        return "$Bytes Bytes"
    }
    elseif ($Bytes -lt 1MB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }
    elseif ($Bytes -lt 1GB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }
    else {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }
}

function Get-StorageConfig {
    <#
        .SYNOPSIS
        Read script configuration from a JSON config file.
    #>
    param (
        [string]$ConfigPath
    )

    if ( -Not $ConfigPath ) {
        Write-Error "Missing path to a configuration file to load."
        return $null
    }

    if ( -Not ( Test-Path $ConfigPath ) ) {
        Write-Warning "Config file not found at path: $ConfigPath. Creating default configuration and exiting early."
        
        try {
            ## Convert $DefaultConfig to JSON and write to $ConfigPath
            $DefaultConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $ConfigPath

            Write-Host "Default configuration saved to '$($ConfigPath)'. Please modify this file before re-running this script." -ForegroundColor Green
            exit 0
        }
        catch {
            Write-Error "Error saving default configuration. Details: $($_.Exception.Message)"
            return $null
        }
    }

    try {
        return Get-Content -Path $ConfigPath | ConvertFrom-Json
    }
    catch {
        Write-Error "Error reading config file. Details: $($_.Exception.Message)"
        return $null
    }
}

function Get-AzStorageContext {
    <#
        .SYNOPSIS
        Get Azure Storage context object.
    #>
    param (
        [string]$StorageAccount,
        [string]$StorageKey
    )

    try {
        return New-AzStorageContext -StorageAccountName $StorageAccount -StorageAccountKey $StorageKey
    }
    catch {
        Write-Error "Error getting Azure storage context object. Details: $($_.Exception.Message)"
        return $null

    }
}

function Get-EmptyBlobs {
    <#
        .SYNOPSIS
        Retrieve empty BLOBs from a container.
    #>
    param (
        [object]$Context,
        [string]$ContainerName
    )

    try {
        $blobs = Get-AzStorageBlob -Context $Context -Container $ContainerName

        return $blobs | Where-Object { $_.Length -eq 0 }
    }
    catch {
        Write-Error "Error scanning for empty BLOBs. Details: $($_.Exception.Message)"
        return $null
    }
    
}

function Get-LargeBlobs {
    <#
        .SYNOPSIS
        Retrieve large BLOBs from a container.
    #>
    param (
        [object]$Context,
        [string]$ContainerName,
        [int64]$SizeThreshold = 104857600
    )

    try {
        $blobs = Get-AzStorageBlob -Context $Context -Container $ContainerName
        return $blobs | Where-Object { $_.Length -gt $SizeThreshold }
    }
    catch {
        Write-Error "Error scanning for large BLOBs. Details: $($_.Exception.Message)"
        return $null
    }
}

function Get-EmptyFiles {
    <#
        .SYNOPSIS
        Retrieve empty files from a share.
    #>
    param (
        [object]$Context,
        [string]$ShareName
    )

    try {
        $files = Get-AzStorageFile -Context $Context -ShareName $ShareName -Path "/"
        return $files | Where-Object { $_.Length -eq 0 }
    }
    catch {
        Write-Error "Error scanning for empty files in Azure File Storage. Details: $($_.Exception.Message)"
        return $null
    }
}

function Get-LargeFiles {
    <#
        .SYNOPSIS
        Retrieve large files from a share.
    #>
    param (
        [object]$Context,
        [string]$ShareName,
        [int64]$SizeThreshold = 104857600
    )

    try {
        $files = Get-AzStorageFile -Context $Context -ShareName $ShareName -Path "/"
        return $files | Where-Object { $_.Length -gt $SizeThreshold }
    }
    catch {
        Write-Error "Error scanning for large files in Azure File Storage. Details: $($_.Exception.Message)"
        return $null
    }
}

## Main execution

try {
    $config = Get-StorageConfig -ConfigPath $ConfigPath
}
catch {
    Write-Error "Error loading configuration from params file: $($ConfigPath). Details: $($_.Exception.Message)"
    exit 1
}

if ( $config ) {
    Write-Host "Scanning Azure Storage account for 0kb or large file(s)/BLOB(s)`n" -ForegroundColor Blue

    try {
        $context = Get-AzStorageContext -StorageAccount $config.storage_account -StorageKey $config.storage_key
    }
    catch {
        Write-Error "Error getting Azure context object. Details: $($_.Exception.Message)"
        exit 1
    }

    if ( $context ) {
        
        ## Get 0kb BLOBs
        Write-Host "Scanning for empty BLOBs" -ForegroundColor Cyan
        try {
            $emptyBlobs = Get-EmptyBlobs -Context $context -ContainerName $config.blob_container
        }
        catch {
            Write-Error "Error searching Azure Storage for empty BLOBs. Details: $($_.Exception.Message)"
            $emptyBlobs = @()
        }

        ## Get large BLOBs
        Write-Host "Scanning for large BLOBs" -ForegroundColor Cyan
        try {
            $largeBlobs = Get-LargeBlobs -Context $context -ContainerName $config.blob_container -SizeThreshold $SizeThreshold
        }
        catch {
            Write-Error "Error searching Azure Storage for large BLOBs. Details: $($_.Exception.Message)"
            $largeBlobs = @()
        }

        ## Get 0kb files
        Write-Host "Scanning for empty files" -ForegroundColor Cyan
        try {
            $emptyFiles = Get-EmptyFiles -Context $context -ShareName $config.file_share
        }
        catch {
            Write-Error "Error searching Azure File Storage for empty files. Details: $($_.Exception.Message)"
            $emptyFiles = @()
        }

        ## Get large files
        Write-Host "Scanning for large files" -ForegroundColor Cyan
        try {
            $largeFiles = Get-LargeFiles -Context $context -ShareName $config.file_share -SizeThreshold $SizeThreshold
        }
        catch {
            Write-Error "Error searching Azure File Storage for large files. Details: $($_.Exception.Message)"
            $largeFiles = @()
        }

        Write-Host "`n[SCAN RESULTS]`n" -ForegroundColor Blue

        if ( $emptyBlobs ) {
            Write-Host "[$($emptyBlobs.Count)] Empty Blobs:" -ForegroundColor Magenta
            $emptyBlobs | ForEach-Object { Write-Host "Blob: $($_.Name) | Size: $(Convert-BytesToHumanReadable -Bytes $($_.Length))" -ForegroundColor Yellow }
        }
        else {
            Write-Host "No 0kb BLOB files found" -ForegroundColor Green
        }

        if ( $largeBlobs ) {
            Write-Host "[$($largeBlobs.Count)] Large Blobs:" -ForegroundColor Magenta
            $largeBlobs | ForEach-Object { Write-Host "Blob: $($_.Name) | Size: $(Convert-BytesToHumanReadable -Bytes $($_.Length))" -ForegroundColor Yellow }
        }
        else {
            Write-Host "No large BLOB files found" -ForegroundColor Green
        }

        if ( $emptyFiles ) {
            Write-Host "[$($emptyFiles.Count)] Empty Files:" -ForegroundColor Magenta
            $emptyFiles | ForEach-Object { Write-Host "File: $($_.Name) | Size: $(Convert-BytesToHumanReadable -Bytes $($_.Length))" -ForegroundColor Yellow }
        }
        else {
            Write-Host "No 0kb files found in Azure File Storage" -ForegroundColor Green
        }

        if ( $largeFiles ) {
            Write-Host "[$($largeFiles.Count)] Large Files:" -ForegroundColor Magenta
            $largeFiles | ForEach-Object { Write-Host "File: $($_.Name) | Size: $(Convert-BytesToHumanReadable -Bytes $($_.Length))" -ForegroundColor Yellow }
        }
        else {
            Write-Host "No large files found in Azure File Storage" -ForegroundColor Green
        }
    }
}
else {
    Write-Error "Config object was empty. Ensure you have a valid config file at path: $ConfigPath"
    exit 1
}
