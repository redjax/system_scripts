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
    [int]$OlderThanDays = $null
)

function Save-DeletedJson {
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

## Determine cutoff date
$cutoffDate = $null

if ( $OlderThanDays ) {
    $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
}
elseif ( -not [string]::IsNullOrWhiteSpace($OlderThan) ) {
    # Try to parse as yyyy-MM-dd, yyyy-MM, or yyyy
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

$DownloadsPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
Write-Host "Downloads path: $DownloadsPath" -ForegroundColor Cyan

if ( [string]::IsNullOrWhiteSpace($InputJson) -eq $false -and [string]::IsNullOrWhiteSpace($InputCsv) -eq $false ) {
    Write-Error "Only one of -InputJson or -InputCsv can be specified."
    exit 1
}
elseif ( [string]::IsNullOrWhiteSpace($InputJson) -eq $false ) {
    $DeleteObjects = @(Read-InputJson -Path $InputJson)
}
elseif ( [string]::IsNullOrWhiteSpace($InputCsv) -eq $false ) {
    $DeleteObjects = @(Read-InputCsv -Path $InputCsv)
}
else {
    $DeleteObjects = Get-ChildItem -Path $DownloadsPath | Where-Object { $_.Name -notin $ExcludeDirs }
}

if ( $cutoffDate ) {
    ## Limit files by cutoff date
    $DeleteObjects = $DeleteObjects | Where-Object { $_.LastWriteTime -lt $cutoffDate }
}

Write-Host "Found $($DeleteObjects.Count) file(s)." -ForegroundColor Cyan

if ( $DeleteObjects.Count -eq 0 ) {
    Write-Host "No files to delete." -ForegroundColor Green
    exit(0)
}

$DeleteObjects | Format-Table -Property Name, FullName, LastWriteTime, Length -AutoSize

if ( $SaveCsv -or $SaveJson ) {
    ## Generate timestamp for filename
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    if ( $SaveJson ) {
        Save-DeletedJson -DeletedObjects $DeleteObjects -timestamp $timestamp
    }

    if ( $SaveCsv ) {
        Save-DeletedCsv -DeletedObjects $DeleteObjects -timestamp $timestamp
    }
}

if ( $DryRun ) {
    $DeleteObjects | ForEach-Object {
        Write-Host "Would delete $($_.FullName)" -ForegroundColor Yellow
    }

    Write-Host "`n> Script would have deleted $($DeleteObjects.Count) file(s)/dir(s)." -ForegroundColor Yellow
}
else {
    Write-Host "Deleting $($DeleteObjects.Count) file(s)." -ForegroundColor Cyan
    $DeletedCount = 0

    $DeleteObjects | ForEach-Object {
        try {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
            Write-Host "Deleted $($_.FullName)" -ForegroundColor Green
            $DeletedCount++
        }
        catch {
            if ($_.Exception -is [System.IO.FileNotFoundException] -or
                $_.Exception -is [System.Management.Automation.ItemNotFoundException]) {
                Write-Host "File not found: $($_.FullName)" -ForegroundColor Red
            }
            elseif ($_.Exception -is [System.UnauthorizedAccessException]) {
                Write-Host "Access denied deleting $($_.FullName). Check permissions." -ForegroundColor Red
            }
            else {
                Write-Host "Error deleting $($_.FullName): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    Write-Host "Deleted $DeletedCount file(s)/dir(s)." -ForegroundColor Green
}
