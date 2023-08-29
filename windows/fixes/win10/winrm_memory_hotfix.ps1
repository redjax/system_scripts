[String] $url = "https://raw.githubusercontent.com/jborean93/ansible-windows/master/scripts/Install-WMF3Hotfix.ps1"
[String] $file = "$env:temp\Install-WMF3Hotfix.ps1"

try {
    (New-Object -TypeName System.Net.WebClient).DownloadFile($url, $file) 
}
catch { 
    Write-Error "Error downloading file from URL: [{$url}] to File: [{$file}]"
    Write-Error "Exception details: $($exc.Message)"

    # if ( Test-Path -Path $file -PathType -Leaf ) {
    #     Remove-Item -Path $file -Force
    # }

    exit 1
}

powershell.exe -ExecutionPolicy ByPass -File $file -Verbose
