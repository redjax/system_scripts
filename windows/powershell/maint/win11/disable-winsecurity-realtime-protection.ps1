$IsAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent() `
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

If ( -Not $IsAdmin ) {
    Write-Error "Script must be run as administrator."

    Exit
}

Write-Warning "You must disable Tamper Protection in Windows Security before running this script."
Write-Warning "Ensure Tamper Protection is disabled by opening Windows Security, clicking 'Virus & Threat Protection,' then click 'Manage settings' under 'Virus & threat protection settings."
Write-Warning "Scroll down and toggle 'Tamper Protection' off."

Write-Host "Disabling Microsoft Defender Realtime Monitoring"
## Disable Realtime Protection
Invoke-Expression "PowerShell Set-MpPreference -DisableRealtimeMonitoring 1"

Write-Host "Tamper protection is enabled. You should reboot your computer now."

