#Requires -Version 5.1
<#
    .SYNOPSIS
    Copy Yazi configuration files to the user's Yazi config directory.

    .DESCRIPTION
    This script copies Yazi configuration toml files from the local configs
    directory to $env:APPDATA\yazi\config. It creates the config directory
    if it doesn't exist and optionally backs up existing configurations.

    .PARAMETER Backup
    Create a backup of existing configuration files before copying.

    .PARAMETER Force
    Overwrite existing configuration files without prompting.

    .PARAMETER ConfigFiles
    Specify which config files to copy. If not specified, all toml files are copied.

    .EXAMPLE
    .\Copy-YaziConfigs.ps1
    Copies all Yazi config toml files to the config directory.

    .EXAMPLE
    .\Copy-YaziConfigs.ps1 -Backup
    Backs up existing configs before copying new ones.

    .EXAMPLE
    .\Copy-YaziConfigs.ps1 -Force
    Overwrites existing configs without prompting.

    .EXAMPLE
    .\Copy-YaziConfigs.ps1 -ConfigFiles "yazi.toml", "keymap.toml"
    Copies only the specified config files.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "Create backup of existing configuration files.")]
    [switch]$Backup,
    
    [Parameter(Mandatory = $false, HelpMessage = "Overwrite existing files without prompting.")]
    [switch]$Force,
    
    [Parameter(Mandatory = $false, HelpMessage = "Specify which config files to copy.")]
    [string[]]$ConfigFiles
)

function Test-YaziInstalled {
    <#
        .SYNOPSIS
        Check if Yazi is installed.
    #>
    if (Get-Command yazi -ErrorAction SilentlyContinue) {
        return $true
    }
    return $false
}

function Backup-ConfigFile {
    <#
        .SYNOPSIS
        Backup a configuration file.
    #>
    Param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$FilePath.$timestamp.bak"
        Copy-Item -Path $FilePath -Destination $backupPath -Force
        Write-Warning "  Backed up to: $backupPath"
        return $true
    }
    return $false
}

Write-Host "`n=== Yazi Configuration Copy Script ===" -ForegroundColor Cyan

## Check if Yazi is installed
if (-not (Test-YaziInstalled)) {
    Write-Warning "Yazi does not appear to be installed."
    Write-Host "You can still copy configuration files, but Yazi won't be able to use them until installed."

    $continue = Read-Host "`nDo you want to continue? (Y/N)"

    if ($continue -ne "Y" -and $continue -ne "y") {
        Write-Host "Operation cancelled."
        exit 0
    }
}

## Get the script directory and configs source path
$configsSourceDir = Join-Path $PSScriptRoot "configs"

## Verify configs source directory exists
if (-not (Test-Path $configsSourceDir)) {
    Write-Error "Source configs directory not found: $configsSourceDir"
    exit 1
}

## Define destination directory
$yaziConfigDir = Join-Path $env:APPDATA "yazi\config"

## Create destination directory if it doesn't exist
if (-not (Test-Path $yaziConfigDir)) {
    Write-Host "`nCreating Yazi config directory: $yaziConfigDir" -ForegroundColor Green
    New-Item -Path $yaziConfigDir -ItemType Directory -Force | Out-Null
} else {
    Write-Host "`nYazi config directory exists: $yaziConfigDir" -ForegroundColor Green
}

# Get all toml files from source directory
$allTomlFiles = Get-ChildItem -Path $configsSourceDir -Filter "*.toml" | Select-Object -ExpandProperty Name

if ($allTomlFiles.Count -eq 0) {
    Write-Error "No toml files found in: $configsSourceDir"
    exit 1
}

## Determine which files to copy
if ($ConfigFiles) {
    $filesToCopy = $ConfigFiles

    ## Validate that specified files exist
    foreach ($file in $filesToCopy) {
        $sourcePath = Join-Path $configsSourceDir $file

        if (-not (Test-Path $sourcePath)) {
            Write-Warning "File not found: $file"
            $filesToCopy = $filesToCopy | Where-Object { $_ -ne $file }
        }
    }

} else {
    $filesToCopy = $allTomlFiles
}

if ($filesToCopy.Count -eq 0) {
    Write-Error "No valid files to copy."
    exit 1
}

## Display files to be copied
Write-Host "`nFiles to copy:" -ForegroundColor Cyan
foreach ($file in $filesToCopy) {
    Write-Host "  - $file"
}

## Copy files
Write-Host "`nCopying configuration files" -ForegroundColor Cyan
$copiedCount = 0
$skippedCount = 0

foreach ($file in $filesToCopy) {
    $sourcePath = Join-Path $configsSourceDir $file
    $destPath = Join-Path $yaziConfigDir $file
    
    ## Check if destination file exists
    if (Test-Path $destPath) {
        if ($Backup) {
            Write-Warning "Backing up existing: $file"
            Backup-ConfigFile -FilePath $destPath
        }
        
        if (-not $Force) {
            $overwrite = Read-Host "`n$file already exists. Overwrite? (Y/N)"
            if ($overwrite -ne "Y" -and $overwrite -ne "y") {
                Write-Host "  Skipped: $file" -ForegroundColor Yellow
                $skippedCount++
                continue
            }
        }
    }
    
    try {
        Copy-Item -Path $sourcePath -Destination $destPath -Force
        Write-Host "  Copied: $file" -ForegroundColor Green
        $copiedCount++
    } catch {
        Write-Error "Failed to copy ${file}: $_"
    }
}

Write-Host "`n=== Copy Summary ===" -ForegroundColor Cyan
Write-Host "Files copied: $copiedCount" -ForegroundColor Green
if ($skippedCount -gt 0) {
    Write-Host "Files skipped: $skippedCount" -ForegroundColor Yellow
}
Write-Host "Destination: $yaziConfigDir"

Write-Host "`nYazi configuration files copied successfully" -ForegroundColor Green
