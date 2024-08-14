function Install-WingetAppsFromList {
    $AppLists = Select-WingetAppList

    If ( $AppLists ) {
        Write-Host 'Installing apps from the following lists:'

        $AppLists | ForEach-Object { Write-Host $_ }
    }
}