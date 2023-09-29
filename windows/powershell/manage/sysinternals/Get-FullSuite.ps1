param(
    [Switch]$Debug,
    [String]$OutputPath = "tmp"
)

Function Get-Sysinternals {
    [CmdletBinding()]
    param ()
    [string] $temp = "$env:HOMEDRIVE\$OutputPath"
    [string] $url = 'http://download.sysinternals.com/files/SysinternalsSuite.zip'
    [string] $downloadpath = "$temp\SysinternalsSuite.zip"
    [string] $destination = "$env:HOMEDRIVE\SYSINTERNALS\"
    
    if (!(Test-Path -Path $temp)) {
        New-Item -Path $env:HOMEDRIVE\temp -ItemType Directory -Verbose | Out-Null
    }
    else {
        Write-Host "$($temp) already exists" -ForegroundColor Green
    }

    If ( Test-Path $downloadpath ) {
        Write-Host "$($downloadpath) exists. Exiting." -ForegroundColor Green

        exit 1
    }
  
    Write-Host "Downloading SysinternalsSuite.zip" -ForegroundColor Yellow
  
  (New-Object System.Net.WebClient).DownloadFile($url, $downloadpath)
    
    Write-Verbose -Message "Downloading SysinternalsSuite.zip to $temp"
  
    $file = Get-Item -Path "$env:HOMEDRIVE\temp\SysinternalsSuite.zip"
    Unblock-File -Path $file -Verbose

    if (!(Test-Path -Path $destination)) {
        New-Item -ItemType Directory -Force -Path "$destination" -Verbose | Out-Null
    }
    Expand-Archive -Path $file -DestinationPath $destination -Force
  
    # Set-Location -Path $destination
}

Get-Sysinternals
