function Start-AppInstaller {
    [CmdletBinding()]
    Param()

    Write-Host 'Install type:'
    Write-Host '1. Individual apps'
    Write-Host '2. App Groups'

    # Get user input
    $selection = Read-Host 'Please select an option (1 or 2)'

    If ( $selection -eq 1 ) {
        $InstallableApps = Get-InstallableApps
        $InstallApps = Select-WingetAppsFromList -AppObjects $InstallableApps
    }
    ElseIf ( $selection -eq 2 ) {
        $InstallAppGroups = Select-WingetAppList
        $AppsFromGroups = @()

        ForEach ( $AppGroup in $InstallAppGroups ) {
            Write-Debug "Adding app group $($AppGroup)"
            $DiscoveredApps = Read-WingetAppFile -JsonFile $AppGroup
            Write-Debug "Discovered [$($DiscoveredApps.Count)] app(s) in group"

            ForEach ( $DiscoveredApp in $DiscoveredApps ) {
                $AppsFromGroups += $DiscoveredApp
            }
        }

        $InstallApps = $AppsFromGroups | Select-Object -Property Id -Unique

    }
    else {
        Write-Error "Invalid option: $($selection). Must be 1 or 2."
    }

    Write-Host "Installing [$($InstallApps.Count)] app(s)"

    $InstallSuccesses = @()
    $InstallFailures = @()

    ForEach ( $App in $InstallApps ) {
        Write-Debug "Installing app: $($App.name) (id: $($App.id))"
        try {
            Install-WingetApp -AppObject $App
            $InstallSuccesses += $App
        }
        catch {
            Write-Error "Unhandled exception installing app '$($App.name)'. Details: $($_.Exception.Message)"
            $InstallFailures += $App
        }
    }

    If ( $InstallFailures.Count -gt 0 ) {
        Write-Warning "Failed to install [$($InstallFailures.Count)] app(s)"

        Write-Debug 'Failed to install apps:'
        ForEach ( $FailedApp in $InstallFailures ) {
            Write-Debug "(fail) $($FailedApp.name) (id: $($FailedApp.id))"
        }
    }
}