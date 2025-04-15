<#
    .SYNOPSIS
    Cleanup the Downloads folder.

    .DESCRIPTION
    Cleanup the Downloads folder, optionally ignoring certain directories.

    Run the script with -DryRun and -SaveJson or -SaveCsv to generate a list of files to delete.
    You can modify this file, leaving only the files you want to delete and feeding it back to script
    with either -InputJson or -InputCsv.

    .PARAMETER ExcludeDirs
    Directories to exclude from search.

    .PARAMETER DryRun
    Enable dry run mode.

    .PARAMETER SaveCsv
    Save results to CSV.

    .PARAMETER SaveJson
    Save results to JSON.

    .PARAMETER InputJson
    Input JSON file with objects to delete. Can be generated with -DryRun -SaveJson.

    .PARAMETER InputCsv
    Input CSV file with objects to delete. Can be generated with -DryRun -SaveCsv.

    .PARAMETER OlderThan
    Delete only files older than this date (yyyy, yyyy-MM, or yyyy-MM-dd).

    .PARAMETER OlderThanDays
    Delete only files older than this many days.

    .PARAMETER Filetypes
    Filetypes to include in search. Wildcards are supported. This acts as a filter,
    if there are any -Filetypes specified, only files with matching filetypes will
    be deleted.

    .EXAMPLE
    .\cleanup_downloads.ps1 -DryRun

    .EXAMPLE
    .\cleanup_downloads.ps1 -DryRun -SaveJson

    .EXAMPLE
    .\cleanup_downloads.ps1 -InputJson [[PATH TO SAVED JSON]]
#>
Param(
    [Parameter(Mandatory = $false, HelpMessage = "Directories to exclude from search")]
    [string[]]$ExcludeDirs = @("_keep"),
    [Parameter(Mandatory = $false, HelpMessage = "Enable dry run mode")]
    [switch]$DryRun,
    [Parameter(Mandatory = $false, HelpMessage = "Save results to CSV")]
    [switch]$SaveCsv,
    [Parameter(Mandatory = $false, HelpMessage = "Save results to JSON")]
    [switch]$SaveJson,
    [Parameter(Mandatory = $false, HelpMessage = "Input JSON file with objects to delete. Can be generated with -DryRun -SaveJson")]
    [string]$InputJson = $null,
    [Parameter(Mandatory = $false, HelpMessage = "Input CSV file with objects to delete. Can be generated with -DryRun -SaveCsv")]
    [string]$InputCsv = $null,
    [Parameter(Mandatory = $false, HelpMessage = "Delete only files older than this date (yyyy, yyyy-MM, or yyyy-MM-dd)")]
    [string]$OlderThan = $null,
    [Parameter(Mandatory = $false, HelpMessage = "Delete only files older than this many days")]
    [int]$OlderThanDays = $null,
    [Parameter(Mandatory = $false, HelpMessage = "Delete only files matching filetype extension(s)")]
    [string[]]$Filetypes = @()
)

function Save-DeletedJson {
    <#
        .SYNOPSIS
        Save a list of files to JSON

        .PARAMETER DeletedObjects
        List of files to save

        .PARAMETER timestamp
        Timestamp
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$DeletedObjects,
        [Parameter(Mandatory = $true)]
        $timestamp
    )
    Write-Host "Saving $($DeletedObjects.Count) file(s) to JSON." -ForegroundColor Magenta
    $jsonPath = "$($timestamp)_deleted_files.json"
    try {
        $DeletedObjects | ConvertTo-Json -Depth 3 | Set-Content -Path $jsonPath
        Write-Host "Saved JSON: $jsonPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Error saving JSON: $($_.Exception.Message)"
    }
}

function Save-DeletedCsv {
    <#
        .SYNOPSIS
        Save a list of files to CSV

        .PARAMETER DeletedObjects
        List of files to save

        .PARAMETER timestamp
        Timestamp
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$DeletedObjects,
        [Parameter(Mandatory = $true)]
        $timestamp
    )
    Write-Host "Saving $($DeletedObjects.Count) file(s) to CSV." -ForegroundColor Magenta
    $csvPath = "$($timestamp)_deleted_files.csv"
    try {
        $DeletedObjects | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "Saved CSV: $csvPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Error saving CSV: $($_.Exception.Message)"
    }
}

function Read-InputJson {
    <#
        .SYNOPSIS
        Read a JSON file

        .PARAMETER Path
        Path to JSON file
    #>
    Param(
        [Parameter(Mandatory = $true, HelpMessage = "Path to JSON file")]
        [string]$Path
    )

    Write-Host "Reading JSON file: $Path"

    try {
        return Get-Content -Path $Path | ConvertFrom-Json
    }
    catch {
        Write-Error "Error loading JSON: $($_.Exception.Message)"
    }
}

function Read-InputCsv {
    <#
        .SYNOPSIS
        Read a CSV file

        .PARAMETER Path
        Path to CSV file
    #>
    Param(
        [Parameter(Mandatory = $true, HelpMessage = "Path to CSV file")]
        [string]$Path
    )

    Write-Host "Reading CSV file: $Path" -ForegroundColor Cyan

    try {
        return Import-Csv -Path $Path
    }
    catch {
        Write-Error "Error loading CSV: $($_.Exception.Message)"
    }
}

function Get-FilteredDeleteObjects {
    <#
        .SYNOPSIS
        Filter an existing list of objects to delete by filetype

        .PARAMETER DeleteObjects
        List of files to filter

        .PARAMETER Filetypes
        List of filetypes to filter
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$DeleteObjects,
        [Parameter(Mandatory = $true)]
        [string[]]$Filetypes
    )

    Write-Host "Filtering: $($Filetypes)" -ForegroundColor Cyan

    ## Normalize filetypes to include leading dot (e.g., "exe" becomes ".exe")
    $normalizedFiletypes = $Filetypes | ForEach-Object {
        if ($_ -notmatch '^\.') { ".$_" } else { $_ }
    }

    ## Create an array to hold filtered file objects
    $filteredObjects = @()

    ## Loop through each file and check if it matches the file types
    foreach ($obj in $DeleteObjects) {
        ## Check if the item is a directory
        $isDirectory = $obj.PSIsContainer

        ## Only perform extension filtering on files
        if (-not $isDirectory) {
            ## Extract file extension
            $extension = $obj.Extension

            ## If it matches one of the extensions, add it
            if ($normalizedFiletypes -contains $extension) {
                $filteredObjects += $obj
            }
        }
    }

    return $filteredObjects
}

## Determine cutoff date
$cutoffDate = $null

if ( $OlderThanDays ) {
    ## If an 'older than days' value was specified, calculate the cutoff date
    $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
}
elseif ( -not [string]::IsNullOrWhiteSpace($OlderThan) ) {
    ## Try to parse as yyyy-MM-dd, yyyy-MM, or yyyy
    if ( $OlderThan -match '^\d{4}-\d{2}-\d{2}$' ) {
        $cutoffDate = [datetime]::ParseExact($OlderThan, 'yyyy-MM-dd', $null)
    }
    elseif ( $OlderThan -match '^\d{4}-\d{2}$' ) {
        $cutoffDate = [datetime]::ParseExact($OlderThan, 'yyyy-MM', $null)
    }
    elseif ( $OlderThan -match '^\d{4}$' ) {
        $cutoffDate = [datetime]::ParseExact($OlderThan, 'yyyy', $null)
    }
    else {
        Write-Error "Invalid date format for -OlderThan. Use yyyy, yyyy-MM, or yyyy-MM-dd."
        exit 1
    }
}

## Get path to user's Downloads directory
$DownloadsPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
Write-Host "Downloads path: $DownloadsPath" -ForegroundColor Cyan

## Parse -InputJson / -InputCsv
if ( [string]::IsNullOrWhiteSpace($InputJson) -eq $false -and [string]::IsNullOrWhiteSpace($InputCsv) -eq $false ) {
    Write-Error "Only one of -InputJson or -InputCsv can be specified."
    exit 1
}
elseif ( [string]::IsNullOrWhiteSpace($InputJson) -eq $false ) {
    # Convert the JSON objects to FileInfo objects
    $jsonObjects = @(Read-InputJson -Path $InputJson)
    $DeleteObjects = foreach ($jsonObj in $jsonObjects) {
        try {
            # Use FullName to convert to FileInfo object
            [System.IO.FileInfo]$fileInfo = $jsonObj.FullName
            $fileInfo
        } catch {
            Write-Error "Could not convert object to FileInfo: $($jsonObj.FullName)"
            continue  # Skip to the next object
        }
    }
}
elseif ( [string]::IsNullOrWhiteSpace($InputCsv) -eq $false ) {
    $csvObjects = @(Read-InputCsv -Path $InputCsv)
    # Convert CSV objects to FileInfo objects, assuming CSV has a FullName column
    $DeleteObjects = foreach ($csvObj in $csvObjects) {
        try {
            # Convert to FileInfo object
            [System.IO.FileInfo]$fileInfo = $csvObj.FullName
            $fileInfo
        } catch {
            Write-Error "Could not convert object to FileInfo: $($csvObj.FullName)"
            continue  # Skip to the next object
        }
    }
}
else {
    $DeleteObjects = Get-ChildItem -Path $DownloadsPath | Where-Object { $_.Name -notin $ExcludeDirs }
}

## Limit files by cutoff date
if ( $cutoffDate ) {
    $DeleteObjects = $DeleteObjects | Where-Object { $_.LastWriteTime -lt $cutoffDate }
}

## Filetype filtering
if ($Filetypes.Count -gt 0) {
    Write-Host "Filtering by filetypes: $Filetypes" -ForegroundColor Cyan
    try {
        $DeleteObjects = Get-FilteredDeleteObjects -DeleteObjects $DeleteObjects -Filetypes $Filetypes
    } catch {
        Write-Error "Error filtering objects to delete by filetypes. Details: $($_.Exception.Message)"
    }
}

Write-Host "Found $($DeleteObjects.Count) file(s)." -ForegroundColor Cyan

## Ensure there is at least 1 object to delete
if ( $DeleteObjects.Count -eq 0 ) {
    Write-Host "No files to delete." -ForegroundColor Green
    exit(0)
}

## Print table of objects to delete
$DeleteObjects | Format-Table -Property Name, FullName, LastWriteTime, Length -AutoSize

if ( $SaveCsv -or $SaveJson ) {
    ## Generate timestamp for filename
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    if ( $SaveJson ) {
        ## Save files to be deleted to JSON
        Save-DeletedJson -DeletedObjects $DeleteObjects -timestamp $timestamp
    }

    if ( $SaveCsv ) {
        ## Save files to be deleted to CSV
        Save-DeletedCsv -DeletedObjects $DeleteObjects -timestamp $timestamp
    }
}

if ( $DryRun ) {
    ## Print list of objects that would be deleted
    $DeleteObjects | ForEach-Object {
        Write-Host "Would delete $($_.FullName)" -ForegroundColor Yellow
    }

    Write-Host "`n> Script would have deleted $($DeleteObjects.Count) file(s)/dir(s)." -ForegroundColor Yellow
}
else {
    Write-Host "Deleting $($DeleteObjects.Count) file(s)." -ForegroundColor Cyan
    
    ## Initialize count of deleted objects
    $DeletedCount = 0

    ## Live operation, delete selected files
    $DeleteObjects | ForEach-Object {
        try {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
            Write-Host "Deleted $($_.FullName)" -ForegroundColor Green

            ## Increment deleted count on successful deletion
            $DeletedCount++
        }
        catch {
            if ($_.Exception -is [System.IO.FileNotFoundException] -or
                $_.Exception -is [System.Management.Automation.ItemNotFoundException]) {
                    ## File not found
                Write-Host "File not found: $($_.FullName)" -ForegroundColor Red
            }
            elseif ($_.Exception -is [System.UnauthorizedAccessException]) {
                ## Permission error
                Write-Host "Access denied deleting $($_.FullName). Check permissions." -ForegroundColor Red
            }
            else {
                ## Unhandled error
                Write-Host "Error deleting $($_.FullName): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    Write-Host "Deleted $DeletedCount file(s)/dir(s)." -ForegroundColor Green
}
