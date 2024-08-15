function Show-InstallableGroups {
    [CmdletBinding()]
    Param(
        [String]$WingetAppsListPath = "$script:ModuleRoot$($script:DirectorySeparator)Data$($script:DirectorySeparator)WingetAppLists"
    )

    # $WingetAppLists = Get-WingetAppJsonFiles -WingetAppListsDir $WingetAppsListPath
    $WingetAppGroups = $(Get-InstallableAppGroups) | Out-Null

    Write-Debug "`n[ Winget: Installable app groups]`n"

    ForEach ( $AppGroup in $WingetAppGroups ) {
        Write-Host "$($AppGroup.Name)"
    }

    return $WingetAppGroups
}

