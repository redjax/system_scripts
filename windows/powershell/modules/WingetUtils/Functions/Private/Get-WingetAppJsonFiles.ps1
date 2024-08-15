function Get-WingetAppJsonFiles {
    <#
        Loop over JSON files in the private WingetAppLists directory,
        or a directory defined with -WingetAppListsDir.

        Return list of JSON files that do not begin with "_".
    #>
    [CmdletBinding()]
    Param(
        [String]$WingetAppListsPath = $script:WingetAppListsDir
    )

    Write-Verbose "Scanning path for JSON file with winget apps to install: $($WingetAppListsPath) (exists: $(Test-Path -Path ($WingetAppListsPath)))"

    $JsonFiles = Get-ChildItem -Path $WingetAppListsPath -Filter *.json | Where-Object { $_.Name -notmatch '^_' }

    return $JsonFiles
}