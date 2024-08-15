function Get-WingetInstalledState {
    [CmdletBinding()]

    $IsAdmin = Is-Admin
    Write-Debug "Elevated shell: $($IsAdmin)"

    # Check if 'winget' is available
    $wingetInstalled = Get-Command winget -ErrorAction SilentlyContinue

    if ( -not $wingetInstalled ) {
        return $false
    }
    else {
        return $true
    }
}

function Install-WingetCli {
    [CmdletBinding()]

    ## Check if winget is installed
    $WingetIsInstalled = Get-WingetInstalledState

    If ( -Not $WingetIsInstalled ) {
        Write-Host 'Winget is not installed, attempting to install.'

        # Installation command for Winget (example for Windows 10/11)
        $wingetInstallCommand = 'winget install --id Microsoft.Powershell --source winget'

        try {
            # Execute the installation command
            Invoke-Expression $wingetInstallCommand
            Write-Host 'Winget has been installed successfully.'
        }
        catch {
            Write-Host "Failed to install Winget: $_"
        }
    }
    else {
        Write-Debug 'Winget is already installed.'
        return $null
    }

    
}
