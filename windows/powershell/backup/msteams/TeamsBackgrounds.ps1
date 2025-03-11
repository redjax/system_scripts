Param(
    [Parameter(Mandatory = $false, HelpMessage = "The path where Teams stores backgrounds.")]
    $TeamsBackgroundsDir = (Join-Path -Path $env:LOCALAPPDATA -ChildPath "Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"),
    [Parameter(Mandatory = $false, HelpMessage = "The path where images will be backed up.")]
    $BackupDir = "backup\TeamsBackgrounds",
    [Parameter(Mandatory = $false, HelpMessage = "The path where images will be restored from.")]
    [ValidateSet("backup", "restore")]
    $Operation = $null
)

Write-Verbose "Teams backgrounds directory: $TeamsBackgroundsDir, exists: $(Test-Path -Path $TeamsBackgroundsDir)"
Write-Verbose "Teams backgrounds backup directory: $BackupDir, exists: $(Test-Path -Path $BackupDir)"

if ( -Not ( Test-Path -Path $TeamsBackgroundsDir ) ) {
    Write-Error "Could not find Teams backgrounds at path '$($TeamsBackgroundsDir)'. Teams may not be installed, or you may be using the old version of Teams."
    exit(1)
}

if ( -Not ( Test-Path $BackupDir ) ) {
    Write-Warning "Backup directory '$($BackupDir)' does not exist. Creating path."
    try {
        New-Item -Path $BackupDir -ItemType Directory -Force
        Write-Output "Created path '$($BackupDir)'."
    }
    catch {
        Write-Error "Unhandled exception creating path [$($BackupDir)]. Details: $($_.Exception.Message)"
        exit(1)
    }
}

function Get-BackgroundImages {
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "The path where Teams stores backgrounds.")]
        $ScanPath = $TeamsBackgroundsDir
    )

    $BackgroundImages = Get-ChildItem -Path $ScanPath -File -Recurse | Where-Object {
    ($_.Extension -eq ".jpg" -or $_.Extension -eq ".jpeg" -or $_.Extension -eq ".png") -and ($_.Name -notmatch "_thumb")
    }

    if ( $BackgroundImages.Count -eq 0 ) {
        Write-Error "No background images found at path '$($ScanPath)'."
        exit(1)
    }

    Write-Debug "Found [$($BackgroundImages.Count)] background image(s)."

    $BackgroundImages | ForEach-Object {
        Write-Debug "Background image: $($_.FullName)"
    }

    return $BackgroundImages
}

function Backup-Image {
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "The image to backup")]
        $ImgPath,
        [Parameter(Mandatory = $false, HelpMessage = "The directory where the image will be backed up to.")]
        $BackupLocation = $BackupDir
    )

    if ( -Not ( $ImgPath ) ) {
        Write-Error "-ImgPath cannot be blank/null."
        return
    }
    else {
        if ( -Not ( Test-Path -Path $ImgPath ) ) {
            Write-Error "Cannot find image at path '$($ImgPath)'."
            return
        }
    }

    if ( Test-Path -Path ( Join-Path -Path $BackupLocation -ChildPath $ImgPath.Name ) ) {
        Write-Warning "Image '$($_.Name)' already exists at path '$($BackupLocation)'."
        return
    }

    Write-Output "Backing up image '$($ImgPath)' to directory '$($BackupLocation)'."
    try {
        Copy-Item -Path $ImgPath -Destination $BackupLocation -Force
        Write-Output "Successfully backed up image '$($ImgPath)' to path '$($BackupLocation)'"
        return $true
    }
    catch {
        Write-Error "Unhandled exception backing up image [$($ImgPath)]. Details: $($_.Exception.Message)"
        return $false
    }
}

function Start-TeamsBackgroundsBackup {
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "The path where Teams stores backgrounds.")]
        $ScanPath = $TeamsBackgroundsDir,
        [Parameter(Mandatory = $false, HelpMessage = "The path where images will be backed up.")]
        $BackupLocation = $BackupDir
    )

    if ( -Not ( Test-Path -Path $BackupLocation ) ) {
        Write-Warning "Backup path does not exist: $BackupLocation. Creating path."
        try {
            New-Item -Path $BackupLocation -ItemType Directory -Force
        }
        catch {
            Write-Error "Unhandled exception creating path [$($BackupLocation)]. Details: $($_.Exception.Message)"
            exit(1)
        }
    }

    $BackgroundImages = Get-BackgroundImages -ScanPath $TeamsBackgroundsDir
    Write-Output "Found [$($BackgroundImages.Count)] background image(s)."

    $BackgroundImages | ForEach-Object {
        try {
            Backup-Image -ImgPath $_.FullName -BackupLocation $BackupLocation
        }
        catch {
            Write-Error "Unhandled exception backing up image [$($_.FullName)]. Details: $($_.Exception.Message)"
        }
    }
}

function Get-BackedUpImages {
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "The path where images will be backed up.")]
        $BackupLocation = $BackupDir
    )

    $BackedUpImages = Get-ChildItem -Path $BackupLocation -File -Recurse | Where-Object {
        ($_.Extension -eq ".jpg" -or $_.Extension -eq ".jpeg" -or $_.Extension -eq ".png") -and ($_.Name -notmatch "_thumb")
    }

    Write-Debug "Found [$($BackedUpImages.Count)] backed up image(s)."

    return $BackedUpImages
}

function Restore-BackgroundImg {
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "The image to restore")]
        $ImgPath,
        [Parameter(Mandatory = $false, HelpMessage = "The directory where the image will be restored to.")]
        $RestoreLocation = $TeamsBackgroundsDir
    )

    if ( -Not ( $ImgPath ) ) {
        Write-Error "-ImgPath cannot be blank/null."
    }

    if ( -Not ( Test-Path -Path ( Join-Path -Path $RestoreLocation -ChildPath $ImgPath.Name ) ) ) {

        Write-Output "Restoring image '$($_.FullName)' to path '$($TeamsBackgroundsPath)'"
        try {
            Copy-Item -Path $ImgPath -Destination $TeamsBackgroundsPath -Force
            Write-Output "Successfully restored image '$($_.Name)' to path '$($TeamsBackgroundsPath)'"

            return $true
        }
        catch {
            Write-Error "Unhandled exception restoring image [$($_.Name)]. Details: $($_.Exception.Message)"

            return $false
        }
    }
    else {
        Write-Warning "Image '$($_.Name)' already exists at path '$($TeamsBackgroundsPath)'"
        return
    }
}

function Start-RestoreTeamsBackgrounds {
    Param(
        [Parameter(Mandatory = $false, HelpMessage = "The path where Teams stores backgrounds. Images will be restored here.")]
        $TeamsBackgroundsPath = $TeamsBackgroundsDir,
        [Parameter(Mandatory = $false, HelpMessage = "The path where images are backed up.")]
        $BackupLocation = $BackupDir
    )

    if ( -Not ( Test-Path $BackupLocation ) ) {
        Write-Error "Could not find backup directory at path '$($BackupLocation)'."
        exit(1)
    }

    $BackedUpImages = Get-BackedUpImages -BackupLocation $BackupLocation
    if ( $BackedUpImages.Count -eq 0 ) {
        Write-Error "No backed up images found at path '$($BackupLocation)'."
        exit(1)
    }

    Write-Output "Restoring Teams backgrounds"

    $BackedUpImages | ForEach-Object {
        if ( -Not ( Test-Path -Path ( Join-Path -Path $TeamsBackgroundsPath -ChildPath $_.FullName ) ) ) {
            Write-Debug "Restoring image '$($_.FullName)' to path '$($TeamsBackgroundsPath)'"
            Restore-BackgroundImg -ImgPath $_.FullName -RestoreLocation $TeamsBackgroundsPath
        }
        else {
            Write-Warning "Image '$($_.FullName)' already exists at path '$($TeamsBackgroundsPath)'."
        }
    }
}

if ( -Not ($Operation -eq "backup" -or $Operation -eq "restore") ) {
    Write-Error "-Operation must be either 'backup' or 'restore'."
    exit(1)
}

switch ( $Operation ) {
    "backup" {
        Start-TeamsBackgroundsBackup
    }
    "restore" {
        Start-RestoreTeamsBackgrounds
    }
}