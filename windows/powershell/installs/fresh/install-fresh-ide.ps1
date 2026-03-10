<#
    .SYNOPSIS
    Installs Fresh terminal IDE on Windows.

    .DESCRIPTION
    This script installs the Fresh terminal IDE on a Windows machine.
    It uses winget as the preferred method, falling back to scoop,
    then npm if winget is not available.

    .LINK
    https://github.com/sinelaw/fresh

    .EXAMPLE
    .\install-fresh-ide.ps1
#>

[CmdletBinding()]
Param()

function Install-FreshWinget {
    Write-Host "Installing Fresh via winget" -ForegroundColor Cyan
    try {
        winget install fresh-editor
    }
    catch {
        Write-Error "Failed to install Fresh via winget. Details: $($_.Exception.Message)"
        exit 1
    }
}

function Install-FreshScoop {
    Write-Host "Installing Fresh via scoop" -ForegroundColor Cyan
    try {
        scoop install fresh-editor
    }
    catch {
        Write-Error "Failed to install Fresh via scoop. Details: $($_.Exception.Message)"
        exit 1
    }
}

function Install-FreshNpm {
    Write-Host "Installing Fresh via npm" -ForegroundColor Cyan
    try {
        npm install -g fresh-editor
    }
    catch {
        Write-Error "Failed to install Fresh via npm. Details: $($_.Exception.Message)"
        exit 1
    }
}

## Main execution
Write-Host "Installing Fresh terminal IDE" -ForegroundColor Cyan

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Install-FreshWinget
}
elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "winget not found, falling back to scoop." -ForegroundColor Yellow
    Install-FreshScoop
}
elseif (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "winget and scoop not found, falling back to npm." -ForegroundColor Yellow
    Install-FreshNpm
}
else {
    Write-Error "Neither winget, scoop, nor npm were found. Install one of them and try again."
    exit 1
}

Write-Host "Fresh terminal IDE installed successfully." -ForegroundColor Green