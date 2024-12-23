#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Install Chocolatey.
.DESCRIPTION
    This script will install Chocolatey.
.PARAMETER Debug
    Enable debug mode.
.PARAMETER DryRun
    Enable dry run mode.
.EXAMPLE
    .\install-chocolatey.ps1 [-Debug] [-DryRun]
#>

Param(
    [Switch]$Debug,
    [Switch]$DryRun
)

Write-Information "Start chocolatey install script"

If ( $Debug ) {
    ## enable powershell logging
    $DebugPreference = "Continue"
}

If ( $DryRun ) {
    Write-Host "-DryRun enabled. Actions will be described, instead of taken. Messages will appear in purple where a live action would be taken." -ForegroundColor Magenta
}

If ( Get-Command choco -ErrorAction SilentlyContinue ) {
    Write-Host "Chocolatey is already installed. Exiting." -ForegroundColor Green
    exit 0
}

function Install-Chocolatey {
    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would run chocolatey install commands:`
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072`
            iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    } else {
        Write-Host "Installing chocolatey" -ForegroundColor cyan
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
}

try {
    Install-Chocolatey
    if ( -Not $DryRun ) {
        Write-Host "Chocolatey installed." -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to install chocolatey: $($_.Exception.Message)"
}