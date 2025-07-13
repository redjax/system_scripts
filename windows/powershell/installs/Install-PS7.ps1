function Test-PwshInstalled {
    <# Check if Powershell 7 is already installed, print version if so. #>
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue

    if ($pwsh) {
        $version = & pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
        Write-Host "PowerShell 7 is already installed" -ForegroundColor Green -NoNewline; Write-Host " (version $version)." -ForegroundColor Blue

        return $true
    }

    return $false
}

function Test-WingetAvailable {
    <# Check if winget is installed. #>
    $winget = Get-Command winget -ErrorAction SilentlyContinue

    return [bool]$winget
}

function Install-PwshWithWinget {
    <# Install PowerShell 7 using winget. #>
    Write-Host "Installing PowerShell 7 using winget..." -ForegroundColor Cyan

    try {
        winget install --id Microsoft.PowerShell --source winget --accept-source-agreements --accept-package-agreements -e
    } catch {
        Write-Error "Error installing PowerShell 7 with winget. Details: $($_.Exception.Message)"
        return $LASTEXITCODE
    }
}

function Install-PwshWithMSI {
    <# Install PowerShell 7 using MSI. #>
    Write-Host "Downloading latest PowerShell 7 MSI installer..." -ForegroundColor Cyan

    ## Get latest stable release info from GitHub API
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
    } catch {
        Write-Error "Failed to get latest release info from GitHub API. Details: $($_.Exception.Message)"
        return $LASTEXITCODE
    }

    $asset = $release.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1
    if (-not $asset) {
        Write-Error "Could not find MSI asset in latest GitHub release."
        return
    }
    
    $msiUrl = $asset.browser_download_url
    $msiPath = "$env:TEMP\$($asset.name)"
    
    try {
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath
    } catch {
        Write-Error "Failed to download PowerShell 7 MSI installer. Details: $($_.Exception.Message)"
        return $LASTEXITCODE
    }

    Write-Host "Installing PowerShell 7 from MSI..." -ForegroundColor Cyan
    
    try {
        Start-Process "msiexec.exe" -ArgumentList "/i `"$msiPath`" /qn ADD_PATH=1 ENABLE_PSREMOTING=1" -Wait
    } catch {
        Write-Error "Failed to install PowerShell 7 from MSI. Details: $($_.Exception.Message)"
        return $LASTEXITCODE
    }

    Write-Host "Installation complete. You may need to restart your shell to use 'pwsh'." -ForegroundColor Green
}

if ( Test-PwshInstalled ) {
    exit 0
}

if ( Test-WingetAvailable ) {
    Install-PwshWithWinget
} else {
    Install-PwshWithMSI
}
