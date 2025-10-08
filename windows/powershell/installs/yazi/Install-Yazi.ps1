#Requires -Version 5.1
<#
    .SYNOPSIS
    Install Yazi file manager on Windows using Scoop.

    .DESCRIPTION
    This script installs Yazi file manager using the Scoop package manager.
    It checks for Scoop availability and installs Yazi from the main bucket.

    .PARAMETER Force
    Force reinstallation of Yazi even if it's already installed.

    .PARAMETER SkipDependencies
    Skip checking and installing dependencies.

    .EXAMPLE
    .\Install-Yazi.ps1
    Installs Yazi using Scoop.

    .EXAMPLE
    .\Install-Yazi.ps1 -Force
    Forces reinstallation of Yazi.

    .EXAMPLE
    .\Install-Yazi.ps1 -SkipDependencies
    Installs Yazi without checking for dependencies.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "Force reinstallation of Yazi.")]
    [switch]$Force,
    [Parameter(Mandatory = $false, HelpMessage = "Skip dependency checks and installation.")]
    [switch]$SkipDependencies
)

function Test-ScoopInstalled {
    <#
        .SYNOPSIS
        Check if Scoop is installed.
    #>
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return $true
    }
    return $false
}

function Install-Scoop {
    <#
        .SYNOPSIS
        Install Scoop package manager.
    #>
    Write-Host "Scoop is not installed. Installing Scoop..." -ForegroundColor Cyan
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        Write-Host "Scoop installed successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to install Scoop: $($_.Exception.Message)"
        throw
    }
}

function Test-YaziInstalled {
    <#
        .SYNOPSIS
        Check if Yazi is already installed.
    #>
    if (Get-Command yazi -ErrorAction SilentlyContinue) {
        $version = & yazi --version 2>&1 | Select-Object -First 1
        Write-Host "Yazi is already installed: $version" -ForegroundColor Yellow
        return $true
    }
    return $false
}

## Main execution
Write-Host "=== Yazi Installation Script ===" -ForegroundColor Cyan
Write-Host ""

## Check if Scoop is installed
if (-not (Test-ScoopInstalled)) {
    $response = Read-Host "Scoop is required but not installed. Install Scoop now? (Y/N)"
    if ($response -match '^[Yy]') {
        Install-Scoop
    } else {
        Write-Error "Scoop is required to install Yazi. Exiting."
        exit 1
    }
}

## Update Scoop
Write-Host "Updating Scoop..." -ForegroundColor Cyan
try {
    scoop update
} catch {
    Write-Warning "Failed to update Scoop: $($_.Exception.Message)"
}

## Check if Yazi is already installed
if (Test-YaziInstalled) {
    if (-not $Force) {
        $response = Read-Host "Yazi is already installed. Reinstall? (Y/N)"
        if ($response -notmatch '^[Yy]') {
            Write-Host "Installation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host "Uninstalling existing Yazi installation..." -ForegroundColor Yellow
    try {
        scoop uninstall yazi
    } catch {
        Write-Warning "Failed to uninstall existing Yazi: $($_.Exception.Message)"
    }
}

## Install Yazi
Write-Host "Installing Yazi..." -ForegroundColor Green
try {
    scoop install yazi
    Write-Host "Yazi installed successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to install Yazi: $($_.Exception.Message)"
    exit 1
}

## Verify installation
if (Get-Command yazi -ErrorAction SilentlyContinue) {
    $version = & yazi --version 2>&1 | Select-Object -First 1
    Write-Host "Verification successful: $version" -ForegroundColor Green
} else {
    Write-Error "Yazi installation verification failed."
    exit 1
}

## Install dependencies if not skipped
if (-not $SkipDependencies) {
    Write-Host ""
    $response = Read-Host "Install recommended dependencies? (Y/N)"
    if ($response -match '^[Yy]') {
        $dependenciesScript = Join-Path $PSScriptRoot "Install-YaziDependencies.ps1"
        if (Test-Path $dependenciesScript) {
            Write-Host "Running dependencies installation script..." -ForegroundColor Cyan
            & $dependenciesScript
        } else {
            Write-Warning "Dependencies script not found at: $dependenciesScript"
            Write-Host "You can manually run Install-YaziDependencies.ps1 later."
        }
    }
}

Write-Host ""
Write-Host "=== Yazi Installation Complete ===" -ForegroundColor Green
Write-Host "Run 'yazi' to start the file manager." -ForegroundColor Cyan
