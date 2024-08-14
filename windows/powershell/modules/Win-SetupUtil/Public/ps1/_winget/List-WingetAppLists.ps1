function List-WingetAppLists {
    [CmdletBinding()]
    Param(
        [String]$WingetAppsListPath = "$PSScriptRoot/../Private/WingetAppLists"
    )

    $WingetAppLists = Get-WingetAppJsonFiles -Path $WingetAppsListPath

    Write-Debug "Winget app lists:`n"

    ForEach ( $AppList in $WingetAppLists ) {
        Write-Debug "$($AppList.Name)"
    }

    return $WingetAppLists
}
