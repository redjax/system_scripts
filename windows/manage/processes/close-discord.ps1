param(
    $processName = "Discord"
)

while ( $True ) {
    try {
        $processes = Get-Process -Name $processName -ErrorAction Stop

        if ( $processes ) {
            Write-Host "[$processName] is running. Stopping process"
            try {
                $processes | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction Stop }
            }
            catch {
                Write-Host "Could not find process with ID $($_.Id). Exception details: $($_.Exception.Message)"
                Write-Host "This could mean the app is still closing, but the process ended before PowerShell could kill it."
                break
            }
        }
        else {
            Write-Host "[$processName] is not running."
            break
        }
    }
    catch {
        Write-Host "[$processName] is not running."
        break
    }

    ## Sleep for 1 second between checks
    Start-Sleep -Seconds 1
}