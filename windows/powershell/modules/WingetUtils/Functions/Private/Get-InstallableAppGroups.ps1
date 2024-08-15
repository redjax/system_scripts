function Get-InstallableAppGroups {
    <# Get list of winget app JSON files, return as list of installable app groups. #>
    [CmdletBinding()]
    Param(
        [String]$WingetAppsListPath = $script:WingetAppListsDir
    )

    if ($WingetAppsListPath.Count -eq 0) {
        Write-Host 'No JSON files found in the specified directory.'
        return $null
    }

    $WingetAppGroups = $(Get-WingetAppJsonFiles -WingetAppListsPath $WingetAppsListPath) | Out-Null

    return $WingetAppGroups
}
