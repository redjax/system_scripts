#Requires -RunAsAdministrator
Param(
    [switch]$Debug,
    [switch]$DryRun
)

$ChocolateyDir = $env:ChocolateyInstall

If ( $Debug ) {
    ## enable powershell logging
    $DebugPreference = "Continue"
}

If ( $DryRun ) {
    Write-Host "-DryRun enabled. Actions will be described, instead of taken. Messages will appear in purple where a live action would be taken." -ForegroundColor Magenta
}

If ( -Not (Get-Command choco) ) {
    Write-Host "Chocolatey is not installed. Exiting." -ForegroundColor Green
    exit 0
}

Write-Information "Begin chocolatey uninstall"
Write-Host "Uninstalling chocolatey" -ForegroundColor cyan

$WarningMessage = "
This script removes the chocolatey directory ($($ChocolateyDir)) and chocolatey environment variables, but does not do a 'full uninstall.'
    Chocolatey has a script that will do this, but it is not recommended as it is very desctructive:
    https://docs.chocolatey.org/en-us/choco/uninstallation/#script
"
Write-Warning $WarningMessage 


function Remove-ChocoDir {
    If ( Test-Path $ChocolateyDir) {
        Write-Information "Chocolatey directory found: $($ChocolateyDir)"

        If ( $DryRun ) {
            Write-Host "[DRY RUN] Would remove path: $($ChocolateyDir)" -ForegroundColor Magenta
            return
        }
        else {
            Write-Host "Removing chocolatey directory: $($ChocolateyDir)" -ForegroundColor cyan

            try {
                Remove-Item $ChocolateyDir -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Error "Failed to remove chocolatey directory: $($_.Exception.Message)"
            }
        }
    }
}

function Remove-ChocoEnvVars {
    Param(
        [array]$ChocoEnvVars = @("ChocolateyInstall", "ChocolateyToolsLocation", "ChocolateyLastPathUpdate")
    )

    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would remove environment variables: $($ChocoEnvVars)" -ForegroundColor Magenta
        return
    }

    Write-Host "Removing environment variables: $($ChocoEnvVars)" -ForegroundColor cyan
    ForEach ( $EnvVar in $ChocoEnvVars ) {
        Write-Debug "Remove environment variable: $($EnvVar)"
        try {
            [Environment]::SetEnvironmentVariable("$($EnvVar)", $null, "User")
        } catch {
            Write-Error "Failed to remove environment variable: $($_.Exception.Message)"
        }
    }
}

try {
    Remove-ChocoDir
    Remove-ChocoEnvVars

    Write-Host "Chocolatey uninstall complete." -ForegroundColor Green

} catch {
    Write-Error "Failed to remove chocolatey directory: $($_.Exception.Message)"
}

Write-Information "End chocolatey uninstall"
