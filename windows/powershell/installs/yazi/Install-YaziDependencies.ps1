#Requires -Version 5.1
<#
    .SYNOPSIS
    Install Yazi dependencies on Windows using Scoop.

    .DESCRIPTION
    This script installs recommended dependencies for Yazi file manager including:
    - File previewers (ffmpeg, poppler, imagemagick)
    - Search tools (ripgrep, fd, fzf)
    - Utilities (7zip, jq)
    - Nerd Fonts

    .PARAMETER SkipFonts
    Skip Nerd Fonts installation.

    .PARAMETER Essential
    Install only essential dependencies (skip optional tools).

    .EXAMPLE
    .\Install-YaziDependencies.ps1
    Installs all recommended dependencies.

    .EXAMPLE
    .\Install-YaziDependencies.ps1 -SkipFonts
    Installs dependencies but skips Nerd Fonts.

    .EXAMPLE
    .\Install-YaziDependencies.ps1 -Essential
    Installs only essential dependencies.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "Skip Nerd Fonts installation.")]
    [switch]$SkipFonts,
    [Parameter(Mandatory = $false, HelpMessage = "Install only essential dependencies.")]
    [switch]$Essential
)

function Test-ScoopInstalled {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return $true
    }
    return $false
}

function Test-ScoopBucket {
    param([string]$BucketName)
    
    $buckets = scoop bucket list 2>&1 | Out-String
    return $buckets -match $BucketName
}

function Add-ScoopBucket {
    param([string]$BucketName)
    
    Write-Host "Adding Scoop bucket: $BucketName..." -ForegroundColor Cyan
    try {
        scoop bucket add $BucketName
        Write-Host "Bucket '$BucketName' added successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to add bucket '$BucketName': $($_.Exception.Message)"
    }
}

function Install-ScoopPackage {
    param(
        [string]$PackageName,
        [string]$DisplayName = $PackageName,
        [switch]$Optional
    )
    
    ## Check if already installed
    $installed = scoop list 2>&1 | Out-String
    if ($installed -match $PackageName) {
        Write-Host "  ✓ $DisplayName is already installed." -ForegroundColor Gray
        return $true
    }
    
    Write-Host "  Installing $DisplayName..." -ForegroundColor Cyan
    try {
        $output = scoop install $PackageName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ $DisplayName installed successfully." -ForegroundColor Green
            return $true
        } else {
            if ($Optional) {
                Write-Warning "  ⚠ Optional package '$DisplayName' failed to install."
            } else {
                Write-Error "  ✗ Failed to install $DisplayName"
            }
            return $false
        }
    } catch {
        if ($Optional) {
            Write-Warning "  ⚠ Optional package '$DisplayName' failed: $($_.Exception.Message)"
        } else {
            Write-Error "  ✗ Failed to install $($DisplayName): $($_.Exception.Message)"
        }
        return $false
    }
}

## Main execution
Write-Host "=== Yazi Dependencies Installation ===" -ForegroundColor Cyan
Write-Host ""

## Check Scoop
if (-not (Test-ScoopInstalled)) {
    Write-Error "Scoop is not installed. Please install Scoop first or run Install-Yazi.ps1"
    exit 1
}

## Update Scoop
Write-Host "Updating Scoop..." -ForegroundColor Cyan
scoop update | Out-Null

## Add required buckets
if (-not (Test-ScoopBucket "extras")) {
    Add-ScoopBucket "extras"
}

if (-not $SkipFonts) {
    if (-not (Test-ScoopBucket "nerd-fonts")) {
        Add-ScoopBucket "nerd-fonts"
    }
}

## Essential dependencies (required for core Yazi functionality)
Write-Host ""
Write-Host "Installing essential dependencies..." -ForegroundColor Green

$essentialPackages = @(
    @{ Name = "7zip"; Display = "7-Zip (Archive support)" }
    @{ Name = "jq"; Display = "jq (JSON processing)" }
    @{ Name = "ripgrep"; Display = "ripgrep (Fast search)" }
    @{ Name = "fd"; Display = "fd (Fast file finder)" }
    @{ Name = "fzf"; Display = "fzf (Fuzzy finder)" }
)

foreach ($pkg in $essentialPackages) {
    Install-ScoopPackage -PackageName $pkg.Name -DisplayName $pkg.Display
}

## Optional dependencies (enhance Yazi functionality)
if (-not $Essential) {
    Write-Host ""
    Write-Host "Installing optional dependencies..." -ForegroundColor Green
    
    $optionalPackages = @(
        @{ Name = "ffmpeg"; Display = "FFmpeg (Video preview)" }
        @{ Name = "poppler"; Display = "Poppler (PDF preview)" }
        @{ Name = "imagemagick"; Display = "ImageMagick (Image processing)" }
        @{ Name = "zoxide"; Display = "zoxide (Smart directory jumping)" }
    )
    
    foreach ($pkg in $optionalPackages) {
        Install-ScoopPackage -PackageName $pkg.Name -DisplayName $pkg.Display -Optional
    }
}

## Nerd Fonts
if (-not $SkipFonts) {
    Write-Host ""
    Write-Host "Installing Nerd Fonts..." -ForegroundColor Green
    Write-Host "  Note: Font installation may require administrator privileges." -ForegroundColor Yellow
    
    ## Popular Nerd Fonts choices
    $fonts = @(
        "Hack-NF",
        "Hack-NF-Mono",
        "FiraCode-NF",
        "FiraCode-NF-Mono",
        "JetBrainsMono-NF",
        "JetBrainsMono-NF-Mono"
    )
    
    foreach ($font in $fonts) {
        Install-ScoopPackage -PackageName $font -DisplayName "Nerd Font ($font)" -Optional
    }
    
    Write-Host ""
    Write-Host "  After installation, you may need to:" -ForegroundColor Yellow
    Write-Host "  1. Restart your terminal" -ForegroundColor Yellow
    Write-Host "  2. Configure your terminal to use a Nerd Font" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Dependencies Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Installed packages summary:" -ForegroundColor Cyan
scoop list

Write-Host ""
Write-Host "You can now use Yazi with enhanced functionality!" -ForegroundColor Green
Write-Host "Run 'yazi' to start." -ForegroundColor Cyan
