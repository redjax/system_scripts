function Show-InstallableApps {
    [CmdletBinding()]
    Param(
        [String]$WingetAppsListPath = $script:WingetAppListsDir
    )

    $InstallableApps = Get-InstallableApps

    Write-Host "`n[ Winget: ($($InstallableApps.Count)) Installable apps ]`n"

    $InstallableApps | Format-Table -Property Name, Description, Id
}