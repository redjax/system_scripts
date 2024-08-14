<#
    Loop over the WingetAppLists JSON files and show them to the user. Skip any files beginning with '_'.
#>
function Get-WingetAppJsonFiles {
    Param(
        [String]$WingetAppsListsDir = "$PSScriptRoot/../WingetAppLists"
    )

    $JsonFiles = Get-ChildItem -Path $WingetAppsListsDir -Filter *.json | Where-Object { $_.Name -notmatch '^_' }

    return $JsonFiles
}