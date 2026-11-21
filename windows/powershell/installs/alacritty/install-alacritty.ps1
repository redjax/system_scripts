## Install Alacritty from the latest stable GitHub release.
#  https://github.com/alacritty/alacritty/releases

$ErrorActionPreference = "Stop"

$Repository = "alacritty/alacritty"
$ApiUrl = "https://api.github.com/repos/$Repository/releases/latest"

Write-Host "Checking latest Alacritty release"

$Release = Invoke-RestMethod -Uri $ApiUrl -Headers @{
    "Accept" = "application/vnd.github+json"
}

$Installer = $Release.assets |
Where-Object { $_.name -match "installer\.msi$" } |
Select-Object -First 1

if (-not $Installer) {
    throw "No Windows MSI installer found in release $($Release.tag_name)"
}

Write-Host "Installing Alacritty $($Release.tag_name)"

$TempFile = Join-Path $env:TEMP $Installer.name

try {
    Invoke-WebRequest -Uri $Installer.browser_download_url `
        -OutFile $TempFile

    $Process = Start-Process msiexec.exe `
        -ArgumentList @("/i", "`"$TempFile`"", "/passive", "/norestart") `
        -Wait `
        -PassThru

    if ($Process.ExitCode -notin @(0, 3010)) {
        throw "MSI installation failed with exit code $($Process.ExitCode)"
    }

    Write-Host "Alacritty installation completed."
    if ($Process.ExitCode -eq 3010) {
        Write-Host "A restart is required to complete installation."
    }
}
finally {
    Remove-Item $TempFile -Force -ErrorAction SilentlyContinue
}
