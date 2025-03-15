## Remove the space between "#" and "Requires" to check that user running script is an Administrator
# Requires -RunAsAdministrator
<#
.SYNOPSIS
    Install applications using winget.
.DESCRIPTION
    This script will install applications using winget.
.PARAMETER AppList
    The name of the app list to use. Default is "all", and will translate to '.\applists\winget\all.json'.
.PARAMETER Debug
    Enable debug mode.
.PARAMETER DryRun
    Enable dry run mode.
.PARAMETER All
    Install all apps, skipping prompt.
.EXAMPLE
    .\install-winget-apps.ps1 -AppList azure [-Debug] [-DryRun] [-All]
#>

Param(
    [String]$AppList = "all",
    [String]$AppListsPath = (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath "app_lists"),
    [Switch]$Debug,
    [Switch]$DryRun,
    [Switch]$All
)

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
$JsonFilePath = "$($AppListsPath)\$($AppList).json"
$AppsList = Load-AppList -JsonFilePath $JsonFilePath

function Install-Prompt {
    <# Prompt user for Y/N response to install application. #>
    Param(
        $Application = $null
    )

    If ( -Not $Application ) {
        Write-Error "No application detected"
        exit 1
    }

    If ( $Debug ) {
        Write-Host "Prompting user for install choice." -ForegroundColor Yellow
        Write-Host "App name: $($Application.name)" -ForegroundColor Yellow
        Write-Host "App description: $($Application.description)" -ForegroundColor Yellow
        Write-Host "App ID: $($Application.winget_id)" -ForegroundColor Yellow
    }

    ## Prompt user
    $InstallChoice = Read-Host -Prompt "Do you want to install $($Application.name) with winget? (Y/N, default=N)"

    ## Check user input
    switch ( $InstallChoice.ToLower() ) {
        { @("y", "yes") -contains $_ } {
            return $true
        }
        { @("n", "no") -contains $_ } {
            return $false
        }
        { @("", " ") -contains $_ } {
            return $false
        }
        { $_ -eq $null } {
            return $false
        }
        default {
            Write-Host "Invalid input: $($_). Please enter 'Y' or 'N'."
            Install-Prompt $app
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

    If ( -not $AppsList ) {
        Write-Error "No applications were passed to Install-Apps."

        exit 1
    }

    If ( $All ) {
        ## Install all apps, skipping prompt
        Write-Host "-All flag detected. Skipping install prompt and installing all apps." -ForegroundColor Magenta

        ForEach ( $app in $AppsList ) {

            Write-Host "Installing $($app.name)" -ForegroundColor Blue

            If ( $Debug ) {
                Write-Host "App name: $($app.name)" -ForegroundColor Yellow
                Write-Host "App description: $($app.description)" -ForegroundColor Yellow
            }

            If ( $DryRun ) {
                ## Dry run, don't install app

                Write-Host "-DryRun detected. No app will be installed." -ForegroundColor Magenta
                Write-Host "App: $($app.name)" -ForegroundColor Yellow
                Write-Host "Description: $($app.description)" -ForegroundColor Yellow
                Write-Host "Installation ID: $($app.winget_id)" -ForegroundColor Yellow
                Write-Host "Install command: winget install --id=$($app.winget_id) -e" -ForegroundColor Blue
                Write-Host ""

            }
            else {
                ## Live run, install app
                try {
                    winget install --id=$($app.winget_id) -e
                }
                catch {
                    Write-Error "Error installing app $($app.name). Details: $($_.Exception.Message)"
                }
            }
        }
    }
    else {
        ## -All flag not detected, loop over apps and prompt for install
        ForEach ( $app in $AppsList ) {

            Write-Host "Installing $($app.name)" -ForegroundColor Blue
            
            $Proceed = Install-Prompt -Application $app

            If ( $Proceed ) {

                ## User answered Y/Yes
                If ( $DryRun ) {
                    ## Dry run detected, don't install any apps
                    Write-Host "-DryRun detected. No app will be installed." -ForegroundColor Magenta
                    Write-Host "App: $($app.name)" -ForegroundColor Yellow
                    Write-Host "Description: $($app.description)" -ForegroundColor Yellow
                    Write-Host "Installation ID: $($app.winget_id)" -ForegroundColor Yellow
                    Write-Host "Install command: winget install --id=$($app.id) -e" -ForegroundColor Blue
                    Write-Host ""
                }
                else {
                    ## No dry run, install application
                    Write-Host "Installing app: $($app.name)"
                    If ( $Debug ) {
                        Write-Host "App name: $($app.name)" -ForegroundColor Yellow
                        Write-Host "App description: $($app.description)" -ForegroundColor Yellow
                    }

                    try {
                        winget install --id=$($app.winget_id) -e
                    }
                    catch {
                        Write-Error "Error installing app $($app.name). Details: $($_.Exception.Message)"
                    }
                }
            }
            else {
                ## User answered "n" or "no", skip install
                Write-Host "Skipping install of $($app.name)" -ForegroundColor Yellow
                Write-Host ""
            }
        }
    }
}

Install-Apps -AppsList $AppsList
