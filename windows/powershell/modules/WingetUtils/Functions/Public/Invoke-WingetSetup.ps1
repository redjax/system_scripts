function Invoke-WingetSetup {
    [CmdletBinding()]
    Param()

    $WingetIsInstalled = Get-WingetInstalledState

    If ( -Not $WingetIsInstalled ) {
        Write-Host 'Winget is not installed, installing now'
        Install-WingetCli
    }
    else {
        Write-Host 'Winget is already installed. Use Get-Module WingetSetup to see available commands.'
    }
}