function Get-InstallableApps {
    [CmdletBinding()]
    Param(
        [String]$WingetAppsListPath = $script:WingetAppListsDir
    )

    ## Get list of JSON files
    $WingetAppLists = Get-WingetAppJsonFiles -WingetAppListsPath $WingetAppsListPath

    ## Initialize array of apps found in JSON files
    $InstallableApps = @()
    
    ## Loop over each discovered JSON file
    ForEach ( $AppList in $WingetAppLists ) {
        Write-Verbose "Scanning app list: $($AppList.Name)"

        $AppObjects = Read-WingetAppFile -JsonFilePath $AppList

        ForEach ( $AppObject in $AppObjects ) {
            $InstallableApps += $AppObject
        }
    }

    Write-Debug "Found [$($InstallableApps.Count)] total app(s)"
    $InstallableApps | ForEach-Object {
        Write-Verbose "Found App: $($_.name)"
    }

    ## Remove duplicates from array of installable apps
    $UniqueInstallableApps = $InstallableApps | Sort-Object -Property id -Unique

    Write-Verbose "Number of apps after deduplicating list: $($UniqueInstallableApps.Count)"

    return $UniqueInstallableApps
}