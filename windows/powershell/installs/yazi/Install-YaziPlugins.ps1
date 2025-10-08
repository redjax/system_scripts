#Requires -Version 5.1
<#
    .SYNOPSIS
    Install Yazi plugins using the ya package manager.

    .DESCRIPTION
    This script installs a curated collection of useful Yazi plugins
    using the 'ya' command-line tool. It mirrors the functionality of the Bash version
    but follows PowerShell best practices.

    .PARAMETER PluginList
    Custom array of plugins to install. If not specified, uses the default curated list.

    .EXAMPLE
    .\Install-YaziPlugins.ps1
    Installs all default plugins.

    .EXAMPLE
    .\Install-YaziPlugins.ps1 -PluginList @("yazi-rs/plugins:smart-enter", "yazi-rs/plugins:smart-paste")
    Installs specified plugins only.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "Custom list of plugins to install.")]
    [string[]]$PluginList
)

## Define default plugin collection
$DefaultPlugins = @(
    "yazi-rs/plugins:smart-enter"   # Open files/dirs with Enter
    "yazi-rs/plugins:smart-paste"   # Paste file into hovered dir
    "yazi-rs/plugins:mount"         # Mount/eject paths
    "yazi-rs/plugins:vcs-files"     # Show git changes
    "yazi-rs/plugins:smart-filter"  # Smart filter
    "yazi-rs/plugins:chmod"         # Chmod permissions
    "yazi-rs/plugins:mime-ext"      # Faster MIME types (uses file extensions)
    "yazi-rs/plugins:diff"          # Diff files
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

function Install-YaziPlugin {
    <#
        .SYNOPSIS
        Install a single Yazi plugin.
        
        .PARAMETER PluginName
        The plugin identifier (e.g., "yazi-rs/plugins:smart-enter").
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PluginName
    )
    
    Write-Host "  Installing plugin: $PluginName" -ForegroundColor Cyan
    
    try {
        $output = ya pkg add $PluginName 2>&1 | Out-String
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Plugin '$PluginName' installed successfully." -ForegroundColor Green
            return @{ Success = $true; Plugin = $PluginName }
        } elseif ($output -match "already exists") {
            Write-Host "    ⚠ Plugin '$PluginName' is already installed, skipping." -ForegroundColor Yellow
            return @{ Success = $true; Plugin = $PluginName; Skipped = $true }
        } else {
            Write-Warning "    ✗ Failed to install plugin '$PluginName': $output"
            return @{ Success = $false; Plugin = $PluginName; Error = $output }
        }
    } catch {
        Write-Warning "    ✗ Exception installing plugin '$PluginName': $($_.Exception.Message)"
        return @{ Success = $false; Plugin = $PluginName; Error = $_.Exception.Message }
    }
}

## Main execution
Write-Host "=== Yazi Plugins Installation ===" -ForegroundColor Cyan
Write-Host ""

## Verify Yazi is installed
if (-not (Test-YaziInstalled)) {
    exit 1
}

## Determine which plugins to install
$pluginsToInstall = if ($PluginList) { $PluginList } else { $DefaultPlugins }

Write-Host "Installing $($pluginsToInstall.Count) plugin(s)..." -ForegroundColor Green
Write-Host ""

## Track results
$results = @{
    Installed = @()
    Skipped = @()
    Failed = @()
}

## Install each plugin
foreach ($plugin in $pluginsToInstall) {
    $result = Install-YaziPlugin -PluginName $plugin
    
    if ($result.Success) {
        if ($result.Skipped) {
            $results.Skipped += $plugin
        } else {
            $results.Installed += $plugin
        }
    } else {
        $results.Failed += $plugin
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
    Write-Host "Failed plugins:" -ForegroundColor Red
    foreach ($plugin in $results.Failed) {
        Write-Host "  - $plugin" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "Plugins installation complete!" -ForegroundColor Green
Write-Host "Plugins are now available in Yazi." -ForegroundColor Cyan
Write-Host ""
Write-Host "Plugin descriptions:" -ForegroundColor Yellow
Write-Host "  • smart-enter   - Open files/dirs with Enter key" -ForegroundColor Gray
Write-Host "  • smart-paste   - Paste files into hovered directory" -ForegroundColor Gray
Write-Host "  • mount         - Mount/eject drives and paths" -ForegroundColor Gray
Write-Host "  • vcs-files     - Show git status for files" -ForegroundColor Gray
Write-Host "  • smart-filter  - Enhanced filtering capabilities" -ForegroundColor Gray
Write-Host "  • chmod         - Change file permissions" -ForegroundColor Gray
Write-Host "  • mime-ext      - Faster MIME type detection" -ForegroundColor Gray
Write-Host "  • diff          - Compare files" -ForegroundColor Gray
