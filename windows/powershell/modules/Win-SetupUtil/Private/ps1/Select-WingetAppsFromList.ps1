function Select-WingetAppsFromList {
    <# Present multi-select list of apps that can be installed with Winget. #>
    param (
        [array]$AppObjects
    )
    

    # Display the list of apps to the user
    Write-Host "Select the apps to install by entering the corresponding numbers separated by spaces (or 'a' to install all):"
    
    for ($i = 0; $i -lt $AppObjects.Count; $i++) {
        Write-Host "$($i + 1). $($AppObjects[$i].Name) | $($AppObjects[$i].Description)"
    }

    # Loop to get valid user input
    $selectedApps = @()
    while ($selectedApps.Count -eq 0) {
        # Get the user's selection
        $selection = Read-Host 'Enter your selection'

        if (-not $selection) {
            Write-Host 'No selection made. Please try again.'
            continue
        }

        # Handle 'a' or 'all' to select all apps
        if ($selection -eq 'a' -or $selection -eq 'all') {
            return $AppObjects # Return all apps
        }

        # Convert the input into an array of selected indexes (space-separated)
        $selectedIndexes = $selection -split '\s+' | ForEach-Object { $_.Trim() }

        # Validate the selections
        foreach ($index in $selectedIndexes) {
            if ($index -as [int] -and $index -gt 0 -and $index -le $AppObjects.Count) {
                $selectedApps += $AppObjects[$index - 1] # Return the app object
            }
            else {
                Write-Host "Invalid selection: $index. Please enter a valid number or 'a' for all."
                $selectedApps = @() # Clear selected apps to re-prompt
                break
            }
        }

        if ($selectedApps.Count -eq 0) {
            Write-Host 'Please try again.'
        }
    }

    return $selectedApps
}
