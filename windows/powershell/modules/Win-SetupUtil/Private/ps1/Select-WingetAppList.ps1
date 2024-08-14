function Select-WingetAppList {
    param(
        [string]$WingetAppListsPath = "$PSScriptRoot/../WingetAppLists"
    )

    # Get the list of .json files with full paths
    $JsonFilesFullPath = Get-WingetAppJsonFiles -Path $WingetAppListsPath

    if ($JsonFilesFullPath.Count -eq 0) {
        Write-Host 'No JSON files found in the specified directory.'
        return
    }

    # Extract only filenames for display
    $JsonFiles = $JsonFilesFullPath | ForEach-Object { [System.IO.Path]::GetFileName($_) }

    # Display the list of files with numbers
    Write-Host 'Select the JSON files by entering the corresponding numbers separated by commas (e.g., 1,3,5):'
    for ($i = 0; $i -lt $JsonFiles.Count; $i++) {
        Write-Host "$($i + 1). $($JsonFiles[$i])"
    }

    # Loop to get valid user input
    $SelectedFiles = @()
    while ($SelectedFiles.Count -eq 0) {
        # Get the user's selection
        $Selection = Read-Host 'Enter your selection'

        if (-not $Selection) {
            Write-Host 'No selection made. Please try again.'
            continue
        }

        # Convert the input into an array of selected indexes
        $SelectedIndexes = $Selection -split ',' | ForEach-Object { $_.Trim() }

        # Validate the selections
        foreach ($index in $SelectedIndexes) {
            if ($index -as [int] -and $index -gt 0 -and $index -le $JsonFiles.Count) {
                $SelectedFiles += $JsonFilesFullPath[$index - 1] # Return full file path
            }
            else {
                Write-Host "Invalid selection: $index. Please enter a number between 1 and $($JsonFiles.Count)."
                $SelectedFiles = @() # Clear selected files to re-prompt
                break
            }
        }

        if ($SelectedFiles.Count -eq 0) {
            Write-Host 'Please try again.'
        }
    }

    ForEach ( $SelectedFile in $SelectedFiles ) {
        Write-Debug "Selected file: $($SelectedFile.Name)"
    }

    return $SelectedFiles
}

