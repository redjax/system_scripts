function Check-WingetInstalled {
    [CmdletBinding()]
    Param(
        $InstallIfMissing = $False
    )

    $IsAdmin = Is-Admin
    Write-Host "admin user: $($IsAdmin)"

    # Check if 'winget' is available
    $wingetInstalled = Get-Command winget -ErrorAction SilentlyContinue

    if (-not $wingetInstalled) {
        Write-Warning "Winget is not installed."

        If ( -Not $wingetInstalled ) {
            return $null
        } else {
            # Call the Install-WingetCli function to install Winget
            Install-WingetCli -Debug:$Debug
        }
    } else {
        Write-Debug "Winget is already installed."
    }
}

function Install-WingetCli {
    param (
        [switch]$Debug
    )

    if ($Debug) {
        Write-Host "Debug mode: Attempting to install Winget."
    }

    # Installation command for Winget (example for Windows 10/11)
    $wingetInstallCommand = 'winget install --id Microsoft.Powershell --source winget'

    try {
        # Execute the installation command
        Invoke-Expression $wingetInstallCommand
        Write-Host "Winget has been installed successfully."
    } catch {
        Write-Host "Failed to install Winget: $_"
    }
}
