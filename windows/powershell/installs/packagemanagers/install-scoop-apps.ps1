# Requires -RunAsAdministrator
<#
.SYNOPSIS
    Install applications using Scoop.
.DESCRIPTION
    This script will install applications using Scoop.
.PARAMETER AppList
    The name of the app list to use. Default is "all", and will translate to '.\applists\scoop\all.json'.
.PARAMETER Debug
    Enable debug mode.
.PARAMETER DryRun
    Enable dry run mode.
.PARAMETER All
    Install all apps, skipping prompt.
.EXAMPLE
    .\install-scoop-apps.ps1 -AppList azure [-Debug] [-DryRun] [-All]
#>

Param(
    [String]$AppList = "all",
    [Switch]$Debug,
    [Switch]$DryRun,
    [Switch]$All
)

## Check that Scoop is installed
if (-not (Get-Command "scoop" -ErrorAction SilentlyContinue)) {
    Write-Error "Scoop is not installed. Please install Scoop first."
    exit 1
}

## Function to load apps list from JSON file
function Load-AppList {
    Param(
        [string]$JsonFilePath
    )

    if (-not (Test-Path -Path $JsonFilePath)) {
        Write-Error "JSON file '$JsonFilePath' not found."
        exit 1
    }

    try {
        $jsonContent = Get-Content -Path $JsonFilePath -Raw | ConvertFrom-Json
        return $jsonContent
    } catch {
        Write-Error "Failed to parse JSON file '$JsonFilePath'. Details: $($_.Exception.Message)"
        exit 1
    }
}

## Load the apps list from JSON file
$JsonFilePath = "./applists/scoop/$($AppList).json"
$AppSupportApps = Load-AppList -JsonFilePath $JsonFilePath

function Install-Prompt {
    <# Prompt user for Y/N response to install application. #>
    Param(
        $Application = $null
    )

    If (-Not $Application) {
        Write-Error "No application detected"
        exit 1
    }

    If ($Debug) {
        Write-Host "Prompting user for install choice." -ForegroundColor Yellow
        Write-Host "App name: $($Application.name)" -ForegroundColor Yellow
        Write-Host "App description: $($Application.description)" -ForegroundColor Yellow
        Write-Host "App ID: $($Application.id)" -ForegroundColor Yellow
    }

    ## Prompt user
    $InstallChoice = Read-Host -Prompt "Do you want to install $($Application.name) with Scoop? (Y/N, default=N)"

    ## Check user input
    switch ($InstallChoice.ToLower()) {
        { @("y", "yes") -contains $_ } {
            return $true
        }
        { @("n", "no", "", " ") -contains $_ } {
            return $false
        }
        default {
            Write-Host "Invalid input: $($_). Please enter 'Y' or 'N'."
            Install-Prompt $Application
        }
    }
}

function Install-Apps {
    <# Main installation loop.
       If -All switch was not detected, loop over each app and prompt user to install.
       If -All switch was detected, loop over each app, skipping user prompt and installing directly.
       If -DryRun was detected, app install command will be printed but not executed.
    #>
    Param(
        $AppsList = $null
    )

    If (-not $AppsList) {
        Write-Error "No applications were passed to Install-Apps."
        exit 1
    }

    If ($All) {
        ## Install all apps, skipping prompt
        Write-Host "-All flag detected. Skipping install prompt and installing all apps." -ForegroundColor Magenta

        ForEach ($app in $AppsList) {
            Write-Host "Installing $($app.name)" -ForegroundColor Blue

            If ($Debug) {
                Write-Host "App name: $($app.name)" -ForegroundColor Yellow
                Write-Host "App description: $($app.description)" -ForegroundColor Yellow
            }

            If ($DryRun) {
                Write-Host "-DryRun detected. No app will be installed." -ForegroundColor Magenta
                Write-Host "Install command: scoop install $($app.id)" -ForegroundColor Blue
            } else {
                try {
                    scoop install $app.id
                } catch {
                    Write-Error "Error installing app $($app.name). Details: $($_.Exception.Message)"
                }
            }
        }
    } else {
        ForEach ($app in $AppsList) {
            $Proceed = Install-Prompt -Application $app

            If ($Proceed) {
                If ($DryRun) {
                    Write-Host "-DryRun detected. No app will be installed." -ForegroundColor Magenta
                    Write-Host "Install command: scoop install $($app.id)" -ForegroundColor Blue
                } else {
                    try {
                        scoop install $app.id
                    } catch {
                        Write-Error "Error installing app $($app.name). Details: $($_.Exception.Message)"
                    }
                }
            } else {
                Write-Host "Skipping install of $($app.name)" -ForegroundColor Yellow
            }
        }
    }
}

Install-Apps -AppsList $AppSupportApps
