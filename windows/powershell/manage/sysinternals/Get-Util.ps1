param(
    [Switch]$Debug,
    [String]$URI = "https://live.sysinternals.com",
    [String]$OutputPath = "C:\sysinternals",
    [String]$Filter = $Null
)

$sysToolsPage = Invoke-WebRequest -Uri $URI

# Set-Location -Path $OutputPath

$sysTools = $sysToolsPage.Links.innerHTML | Where-Object -FilterScript { $_ -like "*.exe" -or $_ -like "*.chm" }

ForEach ( $tool in $sysTools ) {

    $downloadpath = "$($OutputPath)\$($tool)"

    If ( $Filter ) {

        If ( $tool -eq $Filter ) {

            If ( $Debug ) {
                Write-Host "Filter match: [tool:$($tool)] [filter:$($Filter)]" -ForegroundColor Blue
            }
            
            If ( -Not ( Test-Path $downloadpath ) ) {
                Write-Host "Downloading tool: $($tool) to $downloadpath" -ForegroundColor Green

                If ( $Debug ) {
                    Write-Host "URL: $($URI)/$($tool)" -ForegroundColor Blue
                }

                Invoke-WebRequest -Uri "$URI/$tool" -OutFile $downloadpath
            }
            else {
                Write-Host "Tool $($tool) already exists at $($downloadpath)" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "Downloading tool: $($tool)"
        Invoke-WebRequest -Uri "$URI/$tool" -OutFile $downloadpath
    }
}