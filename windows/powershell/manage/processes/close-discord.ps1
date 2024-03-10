param(
    [String]$ProcessName = "Discord",
    [Switch]$Debug
)

function Remove-Process {
    param(
        [String]$Process = $ProcessName
    )

    while ( $True ) {
        try {
            If ( $Debug ) {
                Write-Host "Getting process: $($ProcessName)" -ForegroundColor Cyan
            }

            $processes = Get-Process -Name $ProcessName -ErrorAction Stop

            if ( $processes ) {
                Write-Host "[$ProcessName] is running. Stopping process" -ForegroundColor Yellow
                try {
                    Write-Host "Attempting to kill [$($ProcessName)]" -ForegroundColor Yellow
                    $processes | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction Stop }
                }
                catch {
                    [String]$isClosingString = "This could mean the app is still closing, but the process ended before PowerShell could kill it."
                    Write-Host "Could not find process with ID $($_.Id). Exception details: $($_.Exception.Message). Note: $isClosingString" -ForegroundColor Red
                    break
                }
            }
            else {
                Write-Host "[$ProcessName] is not running." -ForegroundColor Gray
                break
            }
        }
        catch {
            Write-Host "[$ProcessName] is not running." -ForegroundColor Gray
            break
        }

        ## Sleep for 1 second between checks
        Start-Sleep -Seconds 1
    }
}



If ( $null -eq $ProcessName ) {
    Write-Error "-ProcessName cannot be null."
    exit 1
}
else {
    Remove-Process

    Write-Host "Killed [$($ProcessName)]" -ForegroundColor Green

    exit 0
}

## Abnormal exit
exit 2
