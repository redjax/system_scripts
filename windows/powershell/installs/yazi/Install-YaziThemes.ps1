#Requires -Version 5.1
<#
    .SYNOPSIS
    Install Yazi themes using the ya package manager.

    .DESCRIPTION
    This script installs a curated collection of Yazi themes (both dark and light)
    using the 'ya' command-line tool. It mirrors the functionality of the Bash version
    but follows PowerShell best practices.

    .PARAMETER ThemeList
    Custom array of themes to install. If not specified, uses the default curated list.

    .PARAMETER DarkOnly
    Install only dark themes.

    .PARAMETER LightOnly
    Install only light themes.

    .EXAMPLE
    .\Install-YaziThemes.ps1
    Installs all default themes (dark and light).

    .EXAMPLE
    .\Install-YaziThemes.ps1 -DarkOnly
    Installs only dark themes.

    .EXAMPLE
    .\Install-YaziThemes.ps1 -ThemeList @("dangooddd/kanagawa", "yazi-rs/flavors:catppuccin-macchiato")
    Installs specified themes only.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "Custom list of themes to install.")]
    [string[]]$ThemeList,
    [Parameter(Mandatory = $false, HelpMessage = "Install only dark themes.")]
    [switch]$DarkOnly,
    [Parameter(Mandatory = $false, HelpMessage = "Install only light themes.")]
    [switch]$LightOnly
)

## Define default theme collections
$DarkThemes = @(
    "dangooddd/kanagawa"
    "yazi-rs/flavors:catppuccin-macchiato"
    "yazi-rs/flavors:catppuccin-frappe"
    "yazi-rs/flavors:dracula"
    "bennyyip/gruvbox-dark"
    "kmlupreti/ayu-dark"
    "gosxrgxx/flexoki-dark"
    "956MB/vscode-dark-modern"
    "956MB/vscode-dark-plus"
    "Mintass/rose-pine"
    "Mintass/rose-pine-moon"
)

$LightThemes = @(
    "yazi-rs/flavors:catppuccin-latte"
    "muratoffalex/kanagawa-lotus"
    "gosxrgxx/flexoki-light"
    "956MB/vscode-light-modern"
    "956MB/vscode-light-plus"
    "Mintass/rose-pine-dawn"
)

function Test-YaziInstalled {
    <#
        .SYNOPSIS
        Check if Yazi and ya command are available.
    #>
    $yaziExists = Get-Command yazi -ErrorAction SilentlyContinue
    $yaExists = Get-Command ya -ErrorAction SilentlyContinue
    
    if (-not $yaziExists) {
        Write-Error "Yazi is not installed. Please run Install-Yazi.ps1 first."
        return $false
    }
    
    if (-not $yaExists) {
        Write-Error "The 'ya' command is not available. Yazi may not be properly installed."
        return $false
    }
    
    return $true
}

function Install-YaziTheme {
    <#
        .SYNOPSIS
        Install a single Yazi theme.
        
        .PARAMETER ThemeName
        The theme identifier (e.g., "dangooddd/kanagawa").
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThemeName
    )
    
    Write-Host "  Installing theme: $ThemeName" -ForegroundColor Cyan
    
    try {
        $output = ya pkg add $ThemeName 2>&1 | Out-String
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Theme '$ThemeName' installed successfully." -ForegroundColor Green
            return @{ Success = $true; Theme = $ThemeName }
        } elseif ($output -match "already exists") {
            Write-Host "    ⚠ Theme '$ThemeName' is already installed, skipping." -ForegroundColor Yellow
            return @{ Success = $true; Theme = $ThemeName; Skipped = $true }
        } else {
            Write-Warning "    ✗ Failed to install theme '$ThemeName': $output"
            return @{ Success = $false; Theme = $ThemeName; Error = $output }
        }
    } catch {
        Write-Warning "    ✗ Exception installing theme '$ThemeName': $($_.Exception.Message)"
        return @{ Success = $false; Theme = $ThemeName; Error = $_.Exception.Message }
    }
}

## Main execution
Write-Host "=== Yazi Themes Installation ===" -ForegroundColor Cyan
Write-Host ""

## Verify Yazi is installed
if (-not (Test-YaziInstalled)) {
    exit 1
}

## Determine which themes to install
$themesToInstall = @()

if ($ThemeList) {
    $themesToInstall = $ThemeList
} elseif ($DarkOnly) {
    $themesToInstall = $DarkThemes
} elseif ($LightOnly) {
    $themesToInstall = $LightThemes
} else {
    $themesToInstall = $DarkThemes + $LightThemes
}

Write-Host "Installing $($themesToInstall.Count) theme(s)..." -ForegroundColor Green
Write-Host ""

## Track results
$results = @{
    Installed = @()
    Skipped = @()
    Failed = @()
}

## Install each theme
foreach ($theme in $themesToInstall) {
    $result = Install-YaziTheme -ThemeName $theme
    
    if ($result.Success) {
        if ($result.Skipped) {
            $results.Skipped += $theme
        } else {
            $results.Installed += $theme
        }
    } else {
        $results.Failed += $theme
    }
    
    Write-Host ""
}

## Summary
Write-Host "=== Installation Summary ===" -ForegroundColor Cyan
Write-Host "  Installed: $($results.Installed.Count)" -ForegroundColor Green
Write-Host "  Skipped: $($results.Skipped.Count)" -ForegroundColor Yellow
Write-Host "  Failed: $($results.Failed.Count)" -ForegroundColor Red
Write-Host ""

if ($results.Failed.Count -gt 0) {
    Write-Host "Failed themes:" -ForegroundColor Red
    foreach ($theme in $results.Failed) {
        Write-Host "  - $theme" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "Themes installation complete!" -ForegroundColor Green
Write-Host "Configure your theme in Yazi's configuration file." -ForegroundColor Cyan
