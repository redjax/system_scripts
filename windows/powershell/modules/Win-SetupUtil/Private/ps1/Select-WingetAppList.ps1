function Select-WingetAppList {
    <# Present user with list of found JSON file(s) containing lists of apps to install with Winget. #>
    param(
        [string]$Path = "$PSScriptRoot/../WingetAppLists"
    )

    # Get the list of .json files with full paths
    $jsonFilesFullPath = Get-WingetAppJsonFiles -Path $Path

    if ($jsonFilesFullPath.Count -eq 0) {
        Write-Host 'No JSON files found in the specified directory.'
        return
    }

    # Extract only filenames for display
    $jsonFiles = $jsonFilesFullPath | ForEach-Object { [System.IO.Path]::GetFileName($_) }

    # Display the list of files with numbers
    Write-Host 'Select which Winget JSON file(s) to install from by entering the corresponding numbers separated by spaces (e.g., 1 3 5):'
    for ($i = 0; $i -lt $jsonFiles.Count; $i++) {
        Write-Host "$($i + 1). $($jsonFiles[$i])"
    }

    # Loop to get valid user input
    $selectedFiles = @()
    while ($selectedFiles.Count -eq 0) {
        # Get the user's selection
        $selection = Read-Host 'Enter your selection'

        if (-not $selection) {
            Write-Host 'No selection made. Please try again.'
            continue
        }

        # Convert the input into an array of selected indexes (space-separated)
        $selectedIndexes = $selection -split '\s+' | ForEach-Object { $_.Trim() }

        # Validate the selections
        foreach ($index in $selectedIndexes) {
            if ($index -as [int] -and $index -gt 0 -and $index -le $jsonFiles.Count) {
                $selectedFiles += $jsonFilesFullPath[$index - 1] # Return full file path
            }
            else {
                Write-Host "Invalid selection: $index. Please enter a number between 1 and $($jsonFiles.Count)."
                $selectedFiles = @() # Clear selected files to re-prompt
                break
            }
        }

        if ($selectedFiles.Count -eq 0) {
            Write-Host 'Please try again.'
        }
    }

    return $selectedFiles
}
