function Install-WingetApps {
    <# Present user with list of apps installable via Winget, loaded from JSON files. #>
    [CmdletBinding()]
    Param()

    # Set the debug preference globally
    # Set-DebugPreference

    Write-Debug "START install Winget apps"

    # Get JSON files from the Private/WingetAppLists directory
    $jsonFilesPath = Get-WingetAppJsonFiles -Path "$PSScriptRoot/Private/WingetAppLists"

    if (-Not $jsonFilesPath) {
        Write-Warning 'No .json files found in the specified directory.'
        exit 1
    }

    # Allow user to select JSON files
    $selectedJsonFiles = Select-WingetAppList -Path "$PSScriptRoot/Private/WingetAppLists"

    if (-Not $selectedJsonFiles) {
        Write-Warning 'No JSON files selected.'
        exit 1
    }

    $allSelectedApps = @()

    foreach ($jsonFile in $selectedJsonFiles) {
        # Read apps from the JSON file
        $appObjects = Read-WingetAppFile -JsonFilePath $jsonFile -Debug:$Debug

        if (-not $appObjects) {
            Write-Host "No apps found in: $jsonFile"
            continue
        }

        # Present the apps to the user for selection
        $selectedApps = Select-WingetAppsFromList -AppObjects $appObjects -Debug:$Debug

        # Add selected apps to the total list
        $allSelectedApps += $selectedApps
    }

    # Remove duplicates from the selected apps
    $uniqueSelectedApps = $allSelectedApps | Select-Object -Unique

    # Check if the user wants to install all apps
    if ($uniqueSelectedApps.Count -eq 0) {
        Write-Host 'No apps were selected for installation.'
        return
    }

    Write-Host 'You have selected the following apps for installation:'
    $uniqueSelectedApps | ForEach-Object { Write-Host $_.Name }

    # Here you can implement the installation logic for the selected apps
    # return $uniqueSelectedApps

    $InstalledApps = @()

    ForEach ( $App in $uniqueSelectedApps ) {
        try {
            Install-WingetApp -AppObject $App

            $InstalledApps += $App
        } catch {
            Write-Error "Error installing app '$($App.Name)'. Details: $($_.Exception.Message)"
        }
    }
}