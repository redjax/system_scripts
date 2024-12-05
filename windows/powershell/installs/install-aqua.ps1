Param(
    [switch]$Debug,
    [switch]$DryRun,
    [ValidateSet("winget", "chocolatey", "scoop", $null)]
    [string]$InstallWith = $null,
    [string]$AquaRoot = "$($env:USERPROFILE)\.aqua",
    [string]$AquaProjectRoot = "$($AquaRoot)\aquaproject-aqua"
)

## Enable informational logging
# $InformationPreference = "Continue"

If ( $Debug ) {
    ## enable powershell logging
    $DebugPreference = "Continue"

    Write-Debug "Debugging enabled"
}

$BIN_PATH = "$AQUA_PROJECT_ROOT\bin"

function New-AquaPaths {
    <#
        .SYNOPSIS
        Creates directories for aqua install

        .DESCRIPTION
        Creates directories for aqua install

        .PARAMETER RootPath
        Root path for aqua install

        .PARAMETER ProjectPath    
        Project path for aqua install
    #>
    Param(
        $RootPath = $AquaRoot,
        $ProjectPath = $AquaProjectRoot
    )

    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would create aqua paths." -ForegroundColor Magenta
        return
    }

    Write-Information "Initializing aqua install paths."
    Write-Host "Creating aqua paths." -ForegroundColor cyan

    try {
        New-Item -ItemType Directory -Force -Path $RootPath | Out-Null
        Write-Debug "Created directory: $RootPath"
    } 
    catch {
        Write-Error "Unhandled exception creating path [$($RootPath)]. Details: $($_.Exception.Message)"
        return 1
    }

    # ## Define the paths to check
    # $paths = @($RootPath, $ProjectPath) # , "$ProjectPath\bin")

    # # Loop over each path and create the directory if it doesn't exist
    # ForEach ( $path in $paths ) {
    #     If ( -Not (Test-Path -Type container -Path $path) ) {
    #         Write-Host "Path '$($path)' does not exist. Creating path." -ForegroundColor Gray

    #         If ( $DryRun ) {
    #             Write-Host "[DRY RUN] Would create path: $path" -ForegroundColor Magenta
    #             continue
    #         } 

    #         try {
    #             New-Item -ItemType Directory -Force -Path $path | Out-Null
    #             Write-Debug "Created directory: $path"
    #         }
    #         catch {
    #             Write-Error "Unhandled exception creating path [$($path)]. Details: $($_.Exception.Message)"
    #         }
    #     }
    #     else {
    #         Write-Debug "Path '$($path)' already exists."
    #     }
    # }
}

function Get-PkgManager {
    Param(
        [ValidateSet("winget", "chocolatey", "scoop", $null)] 
        [string]$PreferPkgManager = $null
    )

    ## List of package manager commands to test
    $testPkgManagers = @("winget", "scoop", "choco")

    ## Initialize an empty array to hold the installed package managers
    $installedPkgManagers = @()

    ## Loop over the package manager commands and check if they are installed
    $testPkgManagers | ForEach-Object {
        if (Get-Command $_ -ErrorAction SilentlyContinue) {
            $installedPkgManagers += $_
        }
    }

    if ($installedPkgManagers.Count -eq 0) {
        Write-Warning "No package managers found. Please install at least one package manager."
        # return $null
        exit 1
    }
    elseif ($installedPkgManagers.Count -eq 1) {
        Write-Debug "Only one package manager found: $($installedPkgManagers[0]), using it."
        return $installedPkgManagers[0]
    }
    else {
        ## Check if a preferred package manager was provided
        If ( $PreferPkgManager ) {

        }
        else {
            ## Return the first available package manager
            Write-Warning "Multiple package managers found: $($installedPkgManagers -join ', '), using the first one: $($installedPkgManagers[0]). Provide a preferred package manager with -PreferPkgManager."
            return $installedPkgManagers[0]
        }
    }

    ## Check if a preferred package manager is provided
    if ($PreferPkgManager) {
        # If the preferred package manager is installed, return it
        if ( $installedPkgManagers -contains $PreferPkgManager ) {
            Write-Debug "Preferred package manager '$PreferPkgManager' is installed, using it."
            return $PreferPkgManager
        }
        else {
            Write-Warning "Preferred package manager '$PreferPkgManager' is not installed."
            return $null
        }
    }
    else {
        # If no preferred package manager is specified, return the first available one
        if ($installedPkgManagers.Count -gt 0) {
            return $installedPkgManagers[0]
        }
        else {
            Write-Warning "No package manager found."
            return $null
        }
    }
}

function Get-AquaInstalledState {
    $AquaCmdTest = Get-Command aqua -ErrorAction SilentlyContinue

    return $AquaCmdTest
}

function Install-AquaCLI {
    Param(
        [string]$PkgMgr = $null
    )

    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would install aqua with package manager: $PkgMgr." -ForegroundColor Magenta
        return
    }

    switch ($PkgMgr) {
        "winget" {
            $InstallCmd = "winget install --id=aquaproj.aqua --accept-package-agreements --accept-source-agreements"
        }
        "chocolatey" {
            Write-Warning "Installing aqua with chocolatey is not supported yet."
            exit 1
        }
        "scoop" {
            $InstallCmd = "scoop install aqua"
        }
        default {
            Write-Error "No supported package manager found. Please install at least one package manager, i.e. Scoop (https://scoop.sh)"
            exit 1
        }
    }

    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would install aqua with package manager: $PkgMgr." -ForegroundColor Magenta
        return
    }

    $installMsg = "Installing aqua with package manager: $PkgMgr"
    Write-Host $installMsg -ForegroundColor Green
    Write-Information $installMsg

    try {
        Write-Debug "Running command: $InstallCmd"
        Invoke-Expression $InstallCmd
    }
    catch {
        Write-Error "Error installing aqua. Details: $($_.Exception.Message)"
        exit 1
    }
}

function Set-AquaEnvVariables {
    Param(
        [string]$AquaRoot = $AquaRoot,
        [string]$AquaProjectRoot = "$($AquaRoot)\aquaproject-aqua",
        [string]$AquaGlobalConfig = "$($AquaRoot)\aqua.yaml",
        [bool]$EnableAquaProgressBar = $true,
        [bool]$EnableAquaDetailedOutput = $true,
        [int]$AquaMaxParallelDownloads = 5
    )

    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would set environment variables for aqua." -ForegroundColor Magenta
        Write-Debug "[DRY RUN] Would set `$AQUA_ROOT_DIR environment variable to: $AquaProjectRoot"
        Write-Debug "[DRY RUN] Would set `$AQUA_GLOBAL_CONFIG environment variable to: $AquaGlobalConfig"
        Write-Debug "[DRY RUN] Would set `$AQUA_PROGRESS_BAR environment variable to: $($EnableAquaProgressBar)"
        Write-Debug "[DRY RUN] Would set `$AQUA_GENERATE_WITH_DETAIL environment variable to: $($EnableAquaDetailedOutput)"
        Write-Debug "[DRY RUN] Would set `$AQUA_MAX_PARALLEL_DOWNLOADS environment variable to: $($AquaMaxParallelDownloads)"

        return
    }
    
    Write-Information "Setting aqua env variables"
    Write-Host "Setting environment variables for aqua." -ForegroundColor cyan

    ## Set environment variables
    try {
        [Environment]::SetEnvironmentVariable("AQUA_ROOT_DIR", $AquaRoot, "User")
        [Environment]::SetEnvironmentVariable("AQUA_GLOBAL_CONFIG", $AquaGlobalConfig, "User")
        [Environment]::SetEnvironmentVariable("AQUA_PROGRESS_BAR", $EnableAquaProgressBar, "User")
        [Environment]::SetEnvironmentVariable("AQUA_GENERATE_WITH_DETAIL", $EnableAquaDetailedOutput, "User")
        [Environment]::SetEnvironmentVariable("AQUA_MAX_PARALLEL_DOWNLOADS", $AquaMaxParallelDownloads, "User")
    }
    catch {
        Write-Error "Error setting aqua environment variables. Details: $($_.Exception.Message)"
        exit 1
    }
}

function Set-AquaBinPath {
    Param(
        [string]$AquaBinPath = "$env:USERPROFILE\.aqua\bin"  # Default Aqua bin path
    )

    If ( -Not $AquaBinPath ) {
        Write-Error "No aqua bin path provided, and could not load path from environment. Please provide -AquaBinPath parameter."
        exit 1
    }

    ## Add bin directory to PATH if not already added
    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would add aqua bin directory to PATH: $($AquaBinPath)" -ForegroundColor Magenta
        return
    }

    ## Get current user PATH environment variable
    $existingPath = [Environment]::GetEnvironmentVariable("Path", "User")

    ## Check if the bin path is already in the PATH variable
    if ($existingPath -notlike "*$AquaBinPath*") {
        ## Append the new path if not already there
        $newPath = if ($existingPath) { "$existingPath;$AquaBinPath" } else { $AquaBinPath }

        ## Set the updated PATH
        try {
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            Write-Host "Aqua bin path added to PATH: $AquaBinPath" -ForegroundColor Green
        }
        catch {
            Write-Error "Error adding aqua bin path to PATH. Details: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Host "Aqua bin path is already in the PATH." -ForegroundColor Yellow
    }
}

function Invoke-AquaInit {
    Param(
        [string]$AquaRoot = $AquaRoot,
        [string]$AquaProjectRoot = "$($AquaRoot)\aquaproject-aqua",
        [string]$AquaConfigPath = "$($AquaProjectRoot)\aqua.yaml"
    )

    If ( $DryRun ) {
        Write-Host "[DRY RUN] Would run 'aqua init' command." -ForegroundColor Magenta
        return
    }

    Write-Information "Running aqua init command"

    If ( -Not (Test-Path -Type Leaf -Path "$($AquaConfigPath)") ) {
        Write-Host "Running 'aqua init' command." -ForegroundColor Cyan
        try {
            Push-Location $AquaRoot
            & aqua init
        }
        catch {
            Write-Error "Error running 'aqua init' command. Details: $($_.Exception.Message)"
            exit 1
        }
        finally {
            Pop-Location

            Write-Host "Aqua init command complete. Run 'aqua --help' to get started. Run 'aqua root-dir' to get the path to the global aqua project." -ForegroundColor Green
        }
    } else {
        Write-Host "Aqua project already initialized. Run 'aqua --help' to get started. Run 'aqua root-dir' to get the path to the global aqua project." -ForegroundColor Green
        return 0
    }
    
}


function Start-AquaSetup {
    Param(
        [string]$AquaRoot = $AquaRoot,
        [string]$AquaProjectRoot = "$($AquaRoot)\aquaproject-aqua"
    )

    $AquaBinPath = "$($AquaProjectRoot)\bin"

    $isAquaInstalled = Get-AquaInstalledState

    ## Skip setup if aqua is already installed
    If ( $isAquaInstalled ) {
        Write-Host "Aqua is already installed. Exiting." -ForegroundColor Green
        exit 0
    }

    Write-Host "Start aqua install script" -ForegroundColor Green

    If ( $DryRun ) {
        Write-Host "-DryRun detected. No live action will be taken, but a message will tell you what would have happened." -ForegroundColor Magenta
    }

    Write-Debug "AQUA_ROOT: $AquaRoot"
    Write-Debug "AQUA_PROJECT_ROOT: $AquaProjectRoot"
    Write-Debug "AQUA_BIN_PATH: $AquaBinPath"

    $PkgMgr = Get-PkgManager -PreferPkgManager "scoop"

    ## Create directories
    try {
        New-AquaPaths -RootPath $AquaRoot -ProjectPath $AquaProjectRoot
    }
    catch {
        Write-Error "Error setting up aqua paths. Details: $($_.Exception.Message)"
        exit 1
    }

    ## Install aqua
    try {
        Install-AquaCLI -PkgMgr $PkgMgr
    }
    catch {
        Write-Error "Error installing aqua. Details: $($_.Exception.Message)"
        exit 1
    }

    ## Set environment variables.
    Set-AquaEnvVariables -AquaRoot $AquaRoot -AquaProjectRoot $AquaProjectRoot -AquaMaxParallelDownloads 10

    ## Add aqua bin path to $PATH
    Set-AquaBinPath -AquaBinPath $AquaBinPath

    ## Initialize global aqua.yaml
    Invoke-AquaInit -AquaRoot $AquaRoot -AquaProjectRoot $AquaProjectRoot

    If ( -Not $DryRun ) {
        ## Output success message
        Write-Host "Aqua install complete. Restart PowerShell to load the updated environment variables." -ForegroundColor Green
        Write-Host "    To use aqua, run 'aqua --help'." -ForegroundColor Green
        Write-Host "    To initialize a new project, run 'aqua init'." -ForegroundColor Green
        Write-Host "    Run this command from $($AquaProjectRoot) to create a 'global' configuration for your user account." -ForegroundColor Green

        exit 0
    } else {
        Write-Host "[DRY RUN] End dry run" -ForegroundColor Magenta
    }

}

## Run the script
Start-AquaSetup -AquaRoot $AquaRoot -AquaProjectRoot $AquaProjectRoot

# # Create aqua.yaml if it doesn't exist
# $aquaYamlPath = Join-Path $AQUA_ROOT "aqua.yaml"
# if (!(Test-Path $aquaYamlPath)) {
#     New-Item -ItemType File -Force -Path $aquaYamlPath | Out-Null
# }

# # Add bin directory to PATH if not already added
# $existingPath = [Environment]::GetEnvironmentVariable("Path", "User")
# if ($existingPath -notlike "*$BIN_PATH*") {
#     $newPath = "$existingPath;$BIN_PATH"
#     [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
# }

# # Output success message
# Write-Output "Setup complete. Restart PowerShell to load the updated environment variables."
