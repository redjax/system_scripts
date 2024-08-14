function Get-WingetAppJsonFiles {
    <#
        Loop over JSON files in the private WingetAppLists directory,
        or a directory defined with -WingetAppListsDir.

        Return list of JSON files that do not begin with "_".
    #>
    Param(
        [String]$WingetAppListsDir = "$PSScriptRoot/../WingetAppLists"
    )

    $JsonFiles = Get-ChildItem -Path $WingetAppListsDir -Filter *.json | Where-Object { $_.Name -notmatch '^_' }

    return $JsonFiles
}