function Test-Administrator  
{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

function Disable-DefenderRealtimeMonitoring {
    Write-Host "Disabling Windows Defender Real-Time monitoring" -ForegroundColor green
    PowerShell Set-MpPreference -DisableRealtimeMonitoring 1
}

function main {
  $isAdmin = $(Test-Administrator)

  if ( -not $isAdmin ) {
    Write-Warning "This script must be run as administrator. Restart Powershell, right click the icon and choose 'Run as Administrator'."

    exit 1
  } else {
    Disable-DefenderRealtimeMonitoring
  }
}

main
