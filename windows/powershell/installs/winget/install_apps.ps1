## Remove the space between "#" and "Requires" to check that user running script is an Administrator
# Requires -RunAsAdministrator

Param(
    ## Print debug messages
    [Switch]$Debug,
    ## Do not take any actions, but describe what would happen
    [Switch]$DryRun,
    ## Install all apps, skipping y/n prompts
    [Switch]$All,
    ## Append $OptionalApps list to chosen install list
    [Switch]$Optional
)

## List of objects representing apps to be installed with WinGet
$AppSupportApps = @(
    [PSCustomObject]@{
        Name = 'Visual Studio Code' ; ID = 'Microsoft.VisualStudioCode' ; Description = 'Text editor/code IDE'
    },
    [PSCustomObject]@{
        Name = 'Azure Data Studio' ; ID = 'Microsoft.AzureDataStudio' ; Description = 'Connect to data sources in Azure (databases, blob storage, etc)'
    },
    [PSCustomObject]@{
        Name = 'Microsoft SQL Server Management Studio (SSMS)' ; ID = 'Microsoft.SqlServerManagementStudio' ; Description = 'Connect to and manage Microsoft SQL Server databases'
    },
    [PSCustomObject]@{
        Name = 'VLC Media Player' ; ID = 'VideoLAN.VLC' ; Description = 'Play (almost) any type of media. Also includes tools for managing/converting media'
    },
    [PSCustomObject]@{
        Name = 'WinSCP' ; ID = 'WinSCP.WinSCP' ; Description = 'Connect to SCP/SFTP servers.'
    },
    [PSCustomObject]@{
        Name = 'Greenshot (Screenshots)' ; ID = 'Greenshot.Greenshot' ; Description = 'Free, open-source screenshot utility'
    },
    [PSCustomObject]@{
        Name = 'Peazip' ; ID = 'Giorgiotani.Peazip' ; Description = 'Free, open-source file archiving utility'
    },
    [PSCustomObject]@{
        Name = 'Postman' ; ID = 'Postman.Postman' ; Description = 'Utility for interacting with APIs'
    },
    [PSCustomObject]@{
        Name = 'Notepad++' ; ID = 'Notepad++.Notepad++' ; Description = 'Improved notepad, with persistence & code features (auto-format, syntax highlighting, line numbers, etc)'
    },
    [PSCustomObject]@{
        Name = 'Azure CLI' ; ID = 'Microsoft.AzureCLI' ; Description = 'Command line utility for interacting with Azure environment. Needed for some scripts/apps'
    },
    [PSCustomObject]@{
        Name = 'Git' ; ID = 'Git.Git' ; Description = 'Git source control. Needed to interact with Azure DevOps repositories'
    },
    [PSCustomObject]@{
        Name = 'Ente Auth' ; ID = 'ente-io.auth-desktop' ; Description = 'Cross platform, open source MFA app'
    },
    [PSCustomObject]@{
        Name = 'ShareX' ; ID = 'ShareX' ; Description = 'Screenshot utility'
    },
    [PSCustomObject]@{
        Name = 'Mozilla Firefox' ; ID = 'Mozilla.Firefox' ; Description = 'Open source browser'
    },
    [PSCustomObject]@{
        Name = 'Mozilla Thunderbird' ; ID = 'Mozilla.Thunderbird' ; Description = 'Open source email client'
    },
    [PSCustomObject]@{
        Name = 'Notepad++' ; ID = 'Notepad++.Notepad++' ; Description = 'Free, open source notepad alternative with memory'
    },
    [PSCustomObject]@{
        Name = 'VLC media player' ; ID = 'VideoLAN.VLC' ; Description = 'The best project on the Internet'
    },
    [PSCustomObject]@{
        Name = 'Neovim' ; ID = 'Neovim.Neovim' ; Description = 'A CLI text editor'
    },
    [PSCustomObject]@{
        Name = 'Microsoft VSCode' ; ID = 'Microsoft.VisualStudioCode' ; Description = "Open source, extensible text editor. Microsoft's only solid piece of software."
    },
    [PSCustomObject]@{
        Name = 'Microsoft Powershell Core' ; ID = 'Microsoft.PowerShell' ; Description = "Cross-platform, 'new' version of Powershell. Not totally backwards compatible."
    },
    [PSCustomObject]@{
        Name = 'Microsoft PowerToys' ; ID = 'Microsoft.PowerToys' ; Description = 'Tools & utilities for Windows.'
    },
    [PSCustomObject]@{
        Name = 'dBeaver' ; ID = 'dbeaver.dbeaver' ; Description = 'A useful database connection manager'
    },
    [PSCustomObject]@{
        Name = 'Obsidian.md' ; ID = 'Obsidian.Obsidian' ; Description = 'A cross-platform markdown notes app, with synch'
    },
    [PSCustomObject]@{
        Name = 'Ventoy' ; ID = 'Ventoy.Ventoy' ; Description = 'A USB live media creation tool'
    },
    [PSCustomObject]@{
        Name = 'WinSCP' ; ID = 'WinSCP.WinSCP' ; Description = 'An SCP and (S)FTP client for Windows'
    },
    [PSCustomObject]@{
        Name = 'WinDbg' ; ID = 'Microsoft.WinDbg' ; Description = 'A utility for opening Windows memory dumps'
    }

)

If ( $Optional ) {
    Write-Host 'Optional list is not yet implemented.' -ForegroundColor Yellow
}

function Install-Prompt {
    <# Prompt user for Y/N response to install application. #>
    Param(
        $Application = $null
    )

    If ( -Not $Application ) {
        Write-Error 'No application detected'
        exit 1
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

Install-Apps -AppsList $AppSupportApps