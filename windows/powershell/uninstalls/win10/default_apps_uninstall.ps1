Set-ExecutionPolicy -ExecutionPolicy Bypass -Force

## Reinstall command
# Get-AppxPackage -AllUsers| Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}

# Array with packages
$DEFAULT_PKGS = @('*3dbuilder*', '*windowsalarms*', '*windowscalculator*', '*windowscommunicationsapps*', '*windowscamera*', '*officehub*', '*skypeapp*', '*getstarted*', '*zunemusic*', '*windowsmaps*', '*solitairecollection*', '*bingfinance*', '*zunevideo*', '*bingnews*', '*onenote*', '*people*', '*windowsphone*', '*photos*', '*windowsstore*', '*bingsports*', '*soundrecorder*', '*bingweather*', '*xboxapp*')

# Uninstall package
# Get-AppxPackage $PKG | Remove-AppxPackage

# Loop over package array and uninstall
Foreach ( $PKG in $DEFAULT_PKGS )
{
    Get-AppxPackage $PKG | Remove-AppxPackage
}

# Loop over package array and offer to uninstally
