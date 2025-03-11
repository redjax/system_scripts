Param(
    [Parameter(Mandatory = $false, HelpMessage = "The path where Teams stores backgrounds.")]
    $TeamsBackgroundsDir = (Join-Path -Path $env:LOCALAPPDATA -ChildPath "Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"),
    [Parameter(Mandatory = $false, HelpMessage = "The path where images will be backed up.")]
    $BackupDir = "backup\TeamsBackgrounds"
)

if ( -Not ( Test-Path $TeamsBackgroundsDir ) ) {
    Write-Error "Could not find Teams backgrounds at path '$($TeamsBackgroundsDir)'. Teams may not be installed, or you may be using the old version of Teams."
    exit(1)
}

if ( -Not ( Test-Path $BackupDir ) ) {
    Write-Error "Could not find backup directory at path '$($BackupDir)'."
    exit(1)
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

Start-RestoreTeamsBackgrounds -TeamsBackgroundsPath $TeamsBackgroundsDir -BackupLocation $BackupDir
