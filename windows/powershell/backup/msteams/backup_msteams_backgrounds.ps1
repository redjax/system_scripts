Param(
    [Parameter(Mandatory = $false, HelpMessage = "The path where Teams stores backgrounds.")]
    $TeamsBackgroundsDir = (Join-Path -Path $env:LOCALAPPDATA -ChildPath "Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"),
    [Parameter(Mandatory = $false, HelpMessage = "The path where images will be backed up.")]
    $BackupDir = "backup\TeamsBackgrounds"
)

Write-Verbose "Teams backgrounds directory: $TeamsBackgroundsDir, exists: $(Test-Path -Path $TeamsBackgroundsDir)"

if ( -Not ( Test-Path -Path $TeamsBackgroundsDir ) ) {
    Write-Error "Could not find Teams backgrounds at path '$($TeamsBackgroundsDir)'. Teams may not be installed, or you may be using the old version of Teams."
    exit(1)
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

Start-TeamsBackgroundsBackup -ScanPath $TeamsBackgroundsDir -BackupLocation $BackupDir
