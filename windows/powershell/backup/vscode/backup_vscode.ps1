<#
    .SYNOPSIS
    Backup Visual Studio Code settings, keybinds, & extensions.

    .DESCRIPTION
    This script backs up Visual Studio Code user settings, keybinds, and installed extensions to a specified directory.

    .PARAMETER BackupDir
    The directory where the backup files will be stored. Defaults to `$env:USERPROFILE\VSCodeBackup`.

    .EXAMPLE
    PS> .\backup_vscode.ps1 -BackupDir "C:\Backups\VSCode"
    This command will back up VS Code settings, keybinds, and extensions to the specified directory.
#>
[CmdletBinding()]
Param(
    [string]$BackupDir = "$env:USERPROFILE\VSCodeBackup"
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

function Start-VSCodeExtensionsBackup {
    <#
        .SYNOPSIS
        Backup VS Code extensions to a JSON file.

        .PARAMETER OutputDir
        The directory where the extensions list will be saved. Defaults to `$BackupDir`.
    #>
    [CmdletBinding()]
    Param(
        [string]$OutputDir = $BackupDir
    )
    
    $timestamp = Get-Timestamp
    $ExtensionsFile = "$OutputDir\$($timestamp)_extensions.txt"

    Write-Host "Backing up VS Code extensions to path: $ExtensionsFile"
    try {
        code --list-extensions | Out-File -FilePath $ExtensionsFile -Encoding utf8
    } catch {
        Write-Error "Failed backing up VS Code extensions. Details: $($_.Exception.Message)"
        throw
    }
}

function Start-VSCodeSettingsBackup {
    <#
        .SYNOPSIS
        Backup VS Code user settings.

        .PARAMETER SettingsSource
        The path to the VS Code user settings file. Defaults to `$env:APPDATA\Code\User\settings.json`.
    #>
    [CmdletBinding()]
    Param(
        [string]$SettingsSource = "$env:APPDATA\Code\User\settings.json"
    )

    if ( -not ( $SettingsSource ) ) {
        throw "Could not find VS Code settings at path '$SettingsSource'"
    }
    
    $timestamp = Get-Timestamp
    $SettingsDest = "$BackupDir\$($timestamp)_settings.json"

    if ( -not ( Test-Path -Path $SettingsSource -ErrorAction SilentlyContinue ) ) {
        throw "Could not find VS Code user settings at path '$SettingsSource'"
    }

    $OutPath = ( Split-Path -Path $SettingsDest -Parent )
    if ( -not ( Test-Path -Path $OutPath -ErrorAction SilentlyContinue ) ) {
        Write-Warning "Output path '$OutPath' does not exist. Creating..."
        try {
            New-Item -ItemType Directory -Path $OutPath
        } catch {
            Write-Error "Failed creating directory '$OutPath'. Details: $($_.Exception.Message)"
            throw
        }
    }

    Write-Host "Backing up VS Code user settings to path '$SettingsDest'"
    try {
        Copy-Item $SettingsSource -Destination $SettingsDest -ErrorAction SilentlyContinue
    } catch {
        Write-Error "Failed to backup VS Code user settings. Details: $($_.Exception.Message)"
        throw
    }
}

function Start-VSCodeKeybindsBackup {
    <#
        .SYNOPSIS
        Backup VS Code keybinds.

        .PARAMETER KeybindsSource
        The path to the VS Code keybinds file. Defaults to `$env:APPDATA\Code\User\keybindings.json`.
    #>
    [CmdletBinding()]
    Param(
        [string]$KeybindsSource = "$env:APPDATA\Code\User\keybindings.json"
    )

    if ( -not ( $KeybindsSource ) ) {
        throw "Could not find VS Code keybinds at path '$KeybindsSource'"
    }
    
    $timestamp = Get-Timestamp
    $KeybindsDest = "$BackupDir\$($timestamp)_keybinds.json"

    if ( -not ( Test-Path -Path $KeybindsSource -ErrorAction SilentlyContinue ) ) {
        throw "Could not find VS Code keybinds at path '$KeybindsSource'"
    }

    $OutPath = ( Split-Path -Path $KeybindsDest -Parent )
    if ( -not ( Test-Path -Path $OutPath -ErrorAction SilentlyContinue ) ) {
        Write-Warning "Output path '$OutPath' does not exist. Creating..."
        try {
            New-Item -ItemType Directory -Path $OutPath
        } catch {
            Write-Error "Failed creating directory '$OutPath'. Details: $($_.Exception.Message)"
            throw
        }
    }

    Write-Host "Backing up VS Code keybinds to path '$KeybindsDest'"
    try {
        Copy-Item $KeybindsSource -Destination $KeybindsDest -ErrorAction SilentlyContinue
    } catch {
        Write-Error "Failed to backup VS Code keybinds. Details: $($_.Exception.Message)"
        throw
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
        New-Item -ItemType Directory -Path $BackupDir
    } catch {
        Write-Error "Failed creating backup directory '$BackupDir'. Details: $($_.Exception.Message)"
        throw
    }
}

## Backup extensions
try {
    Start-VSCodeExtensionsBackup -OutputDir $BackupDir
} catch {
    Write-Error "Failed backing up VS Code extensions: $($_.Exception.Message)"
}

## Backup settings.json
try {
    Start-VSCodeSettingsBackup
} catch {
    Write-Error "Failed backing up VS Code user settings: $($_.Exception.Message)"
}

## Backup keybindings.json
try {
    Start-VSCodeKeybindsBackup
} catch {
    Write-Error "Failed backing up VS Code keybinds: $($_.Exception.Message)"
}
