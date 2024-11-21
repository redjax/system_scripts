## Remove the space between "#" and "Requires" to check that user running script is an Administrator
# Requires -RunAsAdministrator

<#
.SYNOPSIS
Installs a list of apps using WinGet.

.DESCRIPTION
Installs a list of apps using WinGet, as defined in a JSON file.

.PARAMETER AppsJsonFile
The path to a JSON file containing the list of apps to install.

.PARAMETER Debug
Enable Debug mode.

.PARAMETER DryRun
Do not take any actions, but describe what would happen.

.PARAMETER Y
Automatically answer "yes" to install prompts.

.EXAMPLE
.\install_apps.ps1 -AppsJsonFile C:\Users\<username>\Desktop\winget-apps.json -DryRun
#>

Param(
    ## Print debug messages
    [Switch]$Debug,
    ## Do not take any actions, but describe what would happen
    [Switch]$DryRun,
    ## Automatically answer "yes" to install prompts
    [Switch]$Y,
    ## Path to a JSON file containing the list of apps to install
    [String]$AppsJsonFile = ".\applists\standard.json"
)

If ( $Debug ) {
    ## Enable debugging if -Debug passed
    $DebugPreference = "Continue"
}

if ( $DryRun ) {
    Write-Host "[DRY RUN ENABLED]`n" -ForegroundColor Magenta -NoNewline;
    Write-Host " -DryRun " -ForegroundColor Cyan -NoNewline;
    Write-Host "detected. Script will not install any apps, but will print details about the action it would take."
}

## Convert JSON file path to absolute path
$AbsolutePath = Resolve-Path -Path $AppsJsonFile
## Re-assign AppsJsonFile var
$AppsJsonFile = $AbsolutePath
Write-Debug "App JSON file path: $($AbsolutePath)"
Write-Debug "$($AbsolutePath) exists: $([System.IO.File]::Exists($AbsolutePath))"

if ( -Not ( $AppsJsonFile ) ) {
    Write-Warning "No -AppsJsonFile detected. Script will exit, run it again with the -AppsJsonFile parameter."
    exit 1
}
elseif ( -Not ( Test-Path -PathType Leaf -Path $AppsJsonFile) ) {
    Write-Warning "Could not find app JSON file at path '$($AppsJsonFile)'. Script will exit, pass a path to a valid JSON file with -AppsJsonFile."
}

function Read-AppsFromJson {
    <#
    .SYNOPSIS
    Read winget install apps list from a JSON file.
    
    .DESCRIPTION
    Read winget install apps list from a JSON file, create a PSCustomObject from it, and return it.
    
    .PARAMETER JsonFilePath
    Path to a JSON file containing the list of apps to install.
    
    .EXAMPLE
    Read-AppsFromJson -JsonFilePath "C:\Users\<username>\Desktop\winget-apps.json"
    
    .NOTES
    - Relative paths like '.\file.json' will be converted to absolute paths.
    #>
    Param(
        [String]$JsonFilePath
    )

    Write-Debug "JSON file path: $($JsonFilePath)"
    Write-Debug "$($JsonFilePath) exists: $([System.IO.File]::Exists($JsonFilePath))"

    if ( -Not $JsonFilePath ) {
        Write-Error "Load-AppsFromJson called without a path to a JSON file. Run script with -Debug to check value."
        exit 1
    }

    try {
        [PSCustomObject]$AppsJson = Get-Content -Path $JsonFilePath | ConvertFrom-Json
        Write-Host "Loaded apps from JSON file at path '$($JsonFilePath)'" -ForegroundColor Green

        return $AppsJson
    } catch {
        Write-Error "Could not load JSON file at path '$($JsonFilePath)'. Details: $($_.Exception.Message)"
        exit 1
    }
}

function Install-Prompt {
    <# Prompt user for Y/N response to install application. #>
    Param(
        [PSCustomObject]$Application = $null,
        [Switch]$SkipPrompt = $Y
    )

    If ( -Not $Application ) {
        Write-Error 'No application detected'
        exit 1
    }

    If ( $SkipPrompt ) {
        Write-Debug "-Y detected, skipping prompt."
        return $true
    }

    If ( $Debug ) {
        Write-Host 'Prompting user for install choice.' -ForegroundColor Yellow
        Write-Host "App name: $($Application.Name)" -ForegroundColor Yellow
        Write-Host "App description: $($Application.Description)" -ForegroundColor Yellow
        Write-Host "App ID: $($Application.ID)" -ForegroundColor Yellow
    }

    ## Prompt user
    $InstallChoice = Read-Host -Prompt "Do you want to install $($Application.Name)? (Y/N, default=N)"

    ## Check user input
    switch ( $InstallChoice.ToLower() ) {
        { @('y', 'yes') -contains $_ } {
            return $true
        }
        { @('n', 'no') -contains $_ } {
            return $false
        }
        { @('', ' ') -contains $_ } {
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
        Write-Error 'No applications were passed to Install-Apps.'

        exit 1
    }

    If ( $All ) {
        ## Install all apps, skipping prompt
        Write-Host '-All flag detected. Skipping install prompt and installing all apps.' -ForegroundColor Magenta

        ForEach ( $app in $AppsList ) {

            Write-Host "Installing $($app.Name)" -ForegroundColor Blue

            If ( $Debug ) {
                Write-Host "App name: $($app.Name)" -ForegroundColor Yellow
                Write-Host "App description: $($app.Description)" -ForegroundColor Yellow
            }

            If ( $DryRun ) {
                ## Dry run, don't install app

                Write-Host '-DryRun detected. No app will be installed.' -ForegroundColor Magenta
                Write-Host "App: $($app.Name)" -ForegroundColor Yellow
                Write-Host "Description: $($app.Description)" -ForegroundColor Yellow
                Write-Host "Installation ID: $($app.ID)" -ForegroundColor Yellow
                Write-Host "Install command: winget install --id=$($app.ID) -e" -ForegroundColor Blue
                Write-Host ''

            }
            else {
                ## Live run, install app
                try {
                    winget install --id=$($app.ID) -e
                }
                catch {
                    Write-Error "Error installing app $($app.Name). Details: $($_.Exception.Message)"
                }
            }
        }
    }
    else {
        ## -All flag not detected, loop over apps and prompt for install
        ForEach ( $app in $AppsList ) {

            Write-Host "Installing $($app.Name)" -ForegroundColor Blue
            
            $Proceed = Install-Prompt -Application $app

            If ( $Proceed ) {

                ## User answered Y/Yes
                If ( $DryRun ) {
                    ## Dry run detected, don't install any apps
                    Write-Host '-DryRun detected. No app will be installed.' -ForegroundColor Magenta
                    Write-Host "App: $($app.Name)" -ForegroundColor Yellow
                    Write-Host "Description: $($app.Description)" -ForegroundColor Yellow
                    Write-Host "Installation ID: $($app.ID)" -ForegroundColor Yellow
                    Write-Host "Install command: winget install --id=$($app.ID) -e" -ForegroundColor Blue
                    Write-Host ''
                }
                else {
                    ## No dry run, install application
                    Write-Host "Installing app: $($app.Name)"
                    If ( $Debug ) {
                        Write-Host "App name: $($app.Name)" -ForegroundColor Yellow
                        Write-Host "App description: $($app.Description)" -ForegroundColor Yellow
                    }

                    try {
                        winget install --id=$($app.ID) -e
                    }
                    catch {
                        Write-Error "Error installing app $($app.Name). Details: $($_.Exception.Message)"
                    }
                }
            }
            else {
                ## User answered "n" or "no", skip install
                Write-Host "Skipping install of $($app.Name)" -ForegroundColor Yellow
                Write-Host ''
            }
        }
    }
}

## Get AppsJson PSCustomObject
[PSCustomObject]$AppsJson = Read-AppsFromJson -JsonFilePath $AppsJsonFile

Install-Apps -AppsList $AppsJson
