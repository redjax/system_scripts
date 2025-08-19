<#
    .SYNOPSIS
    Backup Visual Studio Code settings, keybinds, & extensions for all profiles.

    .DESCRIPTION
    This script backs up Visual Studio Code user settings, keybinds, and installed extensions for all profiles 
    to a specified directory. Each profile's backups are stored in separate subdirectories named after the profile.
    The script backs up both the default profile and any named profiles found in the profiles directory.

    .PARAMETER BackupDir
    The directory where the backup files will be stored. Defaults to `$env:USERPROFILE\VSCodeBackup`.
    Each profile will have its own subdirectory within this path.

    .PARAMETER Retain
    The number of backup files to retain for each file type in each profile. Defaults to 3. 
    Older backups will be deleted if this number is exceeded.

    .PARAMETER Trim
    If specified, the script will delete older backups beyond the retention limit for each profile.

    .EXAMPLE
    PS> .\backup_vscode.ps1 -BackupDir "C:\Backups\VSCode"
    This command will back up VS Code settings, keybinds, and extensions for all profiles to the specified directory.

    .EXAMPLE
    PS> .\backup_vscode.ps1 -Trim -Retain 5
    This command will back up all profiles and keep only the 5 most recent backups of each type for each profile.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "Directory to store VS Code backups.")]
    [string]$BackupDir = "$env:USERPROFILE\VSCodeBackup",
    [Parameter(Mandatory = $false, HelpMessage = "Number of backup files to retain.")]
    [ValidateRange(1, 100)]
    [int]$Retain = 3,
    [Parameter(Mandatory = $false, HelpMessage = "Trim older backups beyond the retention limit.")]
    [switch]$Trim
)

function Get-Timestamp {
    <#
        .SYNOPSIS
        Return a formatted timestamp.
    #>
    [CmdletBinding()]
    Param(
        [string]$Fmt = "yyyyMMdd_HHmmss"
    )
    return Get-Date -Format $Fmt
}

function Start-BackupsCleanup {
    <#
        .SYNOPSIS
        Clean up old VS Code backup files.

        .PARAMETER Dir
        The directory where the backups are stored. Defaults to `$BackupDir`.

        .PARAMETER RetainCount
        The number of backup files to retain. Defaults to 3.

        .EXAMPLE
        PS> Start-BackupsCleanup -Dir "C:\Backups\VSCode"
        This command will remove older backup files beyond the specified retention count.
    #>
    [CmdletBinding()]
    Param(
        [string]$Dir,
        [int]$RetainCount = 3
    )

    Write-Host "Cleaning up old VS Code backups in directory: $Dir" -ForegroundColor Cyan

    ## Check if there are profile subdirectories
    $ProfileDirs = Get-ChildItem -Path $Dir -Directory -ErrorAction SilentlyContinue
    
    if ($ProfileDirs) {
        ## Clean up each profile directory
        foreach ($ProfileDir in $ProfileDirs) {
            Write-Host "Cleaning up profile directory: $($ProfileDir.Name)" -ForegroundColor Yellow
            Start-BackupsCleanupForProfile -Dir $ProfileDir.FullName -RetainCount $RetainCount
        }
    } else {
        ## Clean up the main directory (legacy support)
        Start-BackupsCleanupForProfile -Dir $Dir -RetainCount $RetainCount
    }
}

function Start-BackupsCleanupForProfile {
    <#
        .SYNOPSIS
        Clean up old VS Code backup files for a specific profile directory.

        .PARAMETER Dir
        The directory where the backups are stored.

        .PARAMETER RetainCount
        The number of backup files to retain.
    #>
    [CmdletBinding()]
    Param(
        [string]$Dir,
        [int]$RetainCount = 3
    )

    $types = @{
        "settings"  = "*_settings.json"
        "keybinds"  = "*_keybinds.json"
        "extensions"= "*_extensions.txt"
    }

    ForEach ( $type in $types.Keys ) {
        $pattern = $types[$type]
        Write-Debug "Processing pattern: $pattern for type: $type in directory: $Dir"

        ## List files in path matching pattern
        $files = Get-ChildItem -Path $Dir -Filter $pattern -ErrorAction SilentlyContinue | Sort-Object Name -Descending
        
        if ($files -and $files.Count -gt $RetainCount) {
            $toDelete = $files | Select-Object -Skip $RetainCount

            ForEach ( $file in $toDelete ) {
                try {
                    Write-Host "Trimming $type backup: Removing $($file.FullName)" -ForegroundColor Yellow
                    Remove-Item $file.FullName -Force
                } catch {
                    Write-Warning "Failed to remove $($file.FullName): $($_.Exception.Message)"
                }
            }
        }
    }
}

function Start-VSCodeExtensionsBackup {
    <#
        .SYNOPSIS
        Backup VS Code extensions to a JSON file.

        .PARAMETER OutputDir
        The directory where the extensions list will be saved. Defaults to `$BackupDir`.

        .PARAMETER ProfileName
        The name of the VS Code profile for which to backup extensions.
    #>
    [CmdletBinding()]
    Param(
        [string]$OutputDir = $BackupDir,
        [string]$ProfileName = "default"
    )
    
    $timestamp = Get-Timestamp
    $ExtensionsFile = "$OutputDir\$($timestamp)_extensions.txt"

    Write-Host "Backing up VS Code extensions for profile '$ProfileName' to path: $ExtensionsFile" -ForegroundColor Cyan
    try {
        if ($ProfileName -eq "default") {
            code --list-extensions | Out-File -FilePath $ExtensionsFile -Encoding utf8
        } else {
            code --list-extensions --profile $ProfileName | Out-File -FilePath $ExtensionsFile -Encoding utf8
        }
    } catch {
        Write-Error "Failed backing up VS Code extensions for profile '$ProfileName'. Details: $($_.Exception.Message)"
        throw
    }
}

function Start-VSCodeSettingsBackup {
    <#
        .SYNOPSIS
        Backup VS Code user settings.

        .PARAMETER SettingsSource
        The path to the VS Code user settings file.

        .PARAMETER OutputDir
        The directory where the settings backup will be saved.

        .PARAMETER ProfileName
        The name of the VS Code profile for which to backup settings.
    #>
    [CmdletBinding()]
    Param(
        [string]$SettingsSource,
        [string]$OutputDir = $BackupDir,
        [string]$ProfileName = "default"
    )

    if ( -not ( $SettingsSource ) ) {
        throw "Could not find VS Code settings at path '$SettingsSource'"
    }
    
    $timestamp = Get-Timestamp
    $SettingsDest = "$OutputDir\$($timestamp)_settings.json"

    if ( -not ( Test-Path -Path $SettingsSource -ErrorAction SilentlyContinue ) ) {
        Write-Warning "Could not find VS Code user settings at path '$SettingsSource' for profile '$ProfileName'"
        return
    }

    $OutPath = ( Split-Path -Path $SettingsDest -Parent )
    if ( -not ( Test-Path -Path $OutPath -ErrorAction SilentlyContinue ) ) {
        Write-Warning "Output path '$OutPath' does not exist. Creating..."
        try {
            New-Item -ItemType Directory -Path $OutPath -Force
        } catch {
            Write-Error "Failed creating directory '$OutPath'. Details: $($_.Exception.Message)"
            throw
        }
    }

    Write-Host "Backing up VS Code user settings for profile '$ProfileName' to path '$SettingsDest'" -ForegroundColor Cyan
    try {
        Copy-Item $SettingsSource -Destination $SettingsDest -ErrorAction SilentlyContinue
    } catch {
        Write-Error "Failed to backup VS Code user settings for profile '$ProfileName'. Details: $($_.Exception.Message)"
        throw
    }
}

function Start-VSCodeKeybindsBackup {
    <#
        .SYNOPSIS
        Backup VS Code keybinds.

        .PARAMETER KeybindsSource
        The path to the VS Code keybinds file.

        .PARAMETER OutputDir
        The directory where the keybinds backup will be saved.

        .PARAMETER ProfileName
        The name of the VS Code profile for which to backup keybinds.
    #>
    [CmdletBinding()]
    Param(
        [string]$KeybindsSource,
        [string]$OutputDir = $BackupDir,
        [string]$ProfileName = "default"
    )

    if ( -not ( $KeybindsSource ) ) {
        throw "Could not find VS Code keybinds at path '$KeybindsSource'"
    }
    
    $timestamp = Get-Timestamp
    $KeybindsDest = "$OutputDir\$($timestamp)_keybinds.json"

    if ( -not ( Test-Path -Path $KeybindsSource -ErrorAction SilentlyContinue ) ) {
        Write-Warning "Could not find VS Code keybinds at path '$KeybindsSource' for profile '$ProfileName'"
        return
    }

    $OutPath = ( Split-Path -Path $KeybindsDest -Parent )
    if ( -not ( Test-Path -Path $OutPath -ErrorAction SilentlyContinue ) ) {
        Write-Warning "Output path '$OutPath' does not exist. Creating..."
        try {
            New-Item -ItemType Directory -Path $OutPath -Force
        } catch {
            Write-Error "Failed creating directory '$OutPath'. Details: $($_.Exception.Message)"
            throw
        }
    }

    Write-Host "Backing up VS Code keybinds for profile '$ProfileName' to path '$KeybindsDest'" -ForegroundColor Cyan
    try {
        Copy-Item $KeybindsSource -Destination $KeybindsDest -ErrorAction SilentlyContinue
    } catch {
        Write-Error "Failed to backup VS Code keybinds for profile '$ProfileName'. Details: $($_.Exception.Message)"
        throw
    }
}

function Start-VSCodeProfileBackup {
    <#
        .SYNOPSIS
        Backup all components (settings, keybinds, extensions) for a specific VS Code profile.

        .PARAMETER ProfileName
        The name of the VS Code profile to backup.

        .PARAMETER ProfilePath
        The file system path to the profile directory.

        .PARAMETER OutputDir
        The directory where the profile backup will be saved.
    #>
    [CmdletBinding()]
    Param(
        [string]$ProfileName,
        [string]$ProfilePath,
        [string]$OutputDir
    )

    Write-Host "Backing up VS Code profile: $ProfileName" -ForegroundColor Green

    ## Create profile-specific backup directory
    $ProfileBackupDir = Join-Path $OutputDir $ProfileName
    if ( -not ( Test-Path -Path $ProfileBackupDir -ErrorAction SilentlyContinue ) ) {
        try {
            New-Item -ItemType Directory -Path $ProfileBackupDir -Force | Out-Null
        } catch {
            Write-Error "Failed creating profile backup directory '$ProfileBackupDir'. Details: $($_.Exception.Message)"
            return
        }
    }

    ## Backup extensions for this profile
    try {
        Start-VSCodeExtensionsBackup -OutputDir $ProfileBackupDir -ProfileName $ProfileName
    } catch {
        Write-Error "Failed backing up VS Code extensions for profile '$ProfileName': $($_.Exception.Message)"
    }

    ## Backup settings for this profile
    $SettingsFile = Join-Path $ProfilePath "settings.json"
    if (Test-Path $SettingsFile) {
        try {
            Start-VSCodeSettingsBackup -SettingsSource $SettingsFile -OutputDir $ProfileBackupDir -ProfileName $ProfileName
        } catch {
            Write-Error "Failed backing up VS Code settings for profile '$ProfileName': $($_.Exception.Message)"
        }
    }

    ## Backup keybinds for this profile
    $KeybindsFile = Join-Path $ProfilePath "keybindings.json"
    if (Test-Path $KeybindsFile) {
        try {
            Start-VSCodeKeybindsBackup -KeybindsSource $KeybindsFile -OutputDir $ProfileBackupDir -ProfileName $ProfileName
        } catch {
            Write-Error "Failed backing up VS Code keybinds for profile '$ProfileName': $($_.Exception.Message)"
        }
    }
}

## Test if VS Code is installed
if ( -not ( Get-Command -Name code -ErrorAction SilentlyContinue ) ) {
    Write-Error "VS Code is not installed."
    exit(1)
}

## Test $BackupDir is not empty
if ( -not ( $BackupDir ) ) {
    Write-Error "Missing a -BackupDir path"
    exit(1)
}

## Ensure $BackupDir exists
if ( -not ( Test-Path $BackupDir ) ) {
    Write-Warning "Backup path '$BackupDir' does not exist. Creating..."
    try {
        New-Item -ItemType Directory -Path $BackupDir -Force
    } catch {
        Write-Error "Failed creating backup directory '$BackupDir'. Details: $($_.Exception.Message)"
        throw
    }
}

## Backup default profile first (User folder)
Write-Host "Backing up default VS Code profile..." -ForegroundColor Cyan
$DefaultUserPath = "$env:APPDATA\Code\User"
if (Test-Path $DefaultUserPath) {
    Start-VSCodeProfileBackup -ProfileName "default" -ProfilePath $DefaultUserPath -OutputDir $BackupDir
} else {
    Write-Warning "Default VS Code user directory not found at: $DefaultUserPath"
}

## Backup all named profiles
$ProfilesRoot = "$env:APPDATA\Code\User\profiles"
if (Test-Path $ProfilesRoot) {
    Write-Host "Found VS Code profiles directory. Backing up all profiles..." -ForegroundColor Cyan
    $ProfileDirs = Get-ChildItem -Path $ProfilesRoot -Directory -ErrorAction SilentlyContinue
    
    if ($ProfileDirs) {
        foreach ($ProfileDir in $ProfileDirs) {
            $ProfileName = $ProfileDir.Name
            Write-Host "Processing profile: $ProfileName" -ForegroundColor Yellow
            Start-VSCodeProfileBackup -ProfileName $ProfileName -ProfilePath $ProfileDir.FullName -OutputDir $BackupDir
        }
    } else {
        Write-Host "No named profiles found in profiles directory." -ForegroundColor Yellow
    }
} else {
    Write-Host "No VS Code profiles directory found. Only backing up default profile." -ForegroundColor Yellow
}

## Trim backups if requested
if ( $Trim ) {
    Start-BackupsCleanup -Dir $BackupDir -RetainCount $Retain
}
