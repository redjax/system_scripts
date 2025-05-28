<#
    .SYNOPSIS
    Installs Docker Engine on Windows.

    .DESCRIPTION
    This script installs Docker Engine on a Windows machine. It downloads the latest Docker release, extracts it to a specified directory, and adds Docker to the system PATH.

    .PARAMETER DockerVersion
    The version of Docker to install. Defaults to "latest".

    .PARAMETER InstallPath
    The directory where Docker will be installed. Defaults to "C:\docker".

    .PARAMETER CPUArch
    The CPU architecture for Docker. Defaults to "x86_64".

    .PARAMETER Cleanup
    If specified, the script will remove the downloaded zip file after installation. Defaults to false.

    .PARAMETER Update
    If specified, the script will update Docker if it is already installed. Defaults to false.

    .EXAMPLE
    Install-DockerEngine -DockerVersion "20.10.7" -InstallPath "C:\docker" -CPUArch "x86_64" -Cleanup -Update

    Installs Docker version 20.10.7 to C:\docker, cleans up the downloaded zip file, and updates Docker if it is already installed.

    .EXAMPLE
    Install-DockerEngine -DockerVersion "latest" -InstallPath "C:\docker" -CPUArch "x86_64"

    Installs the latest version of Docker to C:\docker without cleaning up the downloaded zip file and without updating if Docker is already installed.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, HelpMessage = "Version of Docker to install (default: latest)")]
    [string]$DockerVersion = "latest",
    [Parameter(Mandatory = $false, HelpMessage = "Path where Docker will be installed (default: C:\docker)")]
    [string]$InstallPath = "C:\docker",
    [Parameter(Mandatory = $false, HelpMessage = "CPU architecture for Docker (default: x86_64)")]
    [string]$CPUArch = "x86_64",
    [Parameter(Mandatory = $false, HelpMessage = "Cleanup downloaded files after installation (default: false)")]
    [switch]$Cleanup,
    [Parameter(Mandatory = $false, HelpMessage = "Update Docker if already installed (default: false)")]
    [switch]$Update
)

$BaseUrl = "https://download.docker.com/win/static/stable/$($CPUArch)/"
Write-Debug "Base URL: $BaseUrl"

function Get-LatestDockerVersion {
    ## Request HTML content from the Docker download page
    Write-Debug "Requesting HTML content from $BaseUrl"
    try {
        $html = Invoke-WebRequest -Uri $BaseUrl
    }
    catch {
        Write-Error "Failed to retrieve the Docker download page. Please check your internet connection or the URL. Details: $($_.Exception.Message)"
        exit 1
    }

    Write-Debug "Retrieved HTML:`n$html"

    Write-Debug "Extracting zip filenames using regex"
    try {
        ## Match all docker-<version>.zip filenames
        $VersionMatches = [regex]::Matches($html.Content, "docker-(\d+\.\d+\.\d+)\.zip")
        
        if ($VersionMatches.Count -eq 0) {
            Write-Error "No Docker zip files found in the HTML content."
            exit 1
        }

        
        $zipFiles = $VersionMatches | ForEach-Object {
            [PSCustomObject]@{
                FileName = $_.Value
                Version  = [version]$_.Groups[1].Value
            }
        }

        $latest = $zipFiles | Sort-Object Version | Select-Object -Last 1
        return $latest.FileName

    }
    catch {
        Write-Error "Failed to extract or sort Docker zip files. Details: $($_.Exception.Message)"
        exit 1
    }

}

function Start-DockerDownload {
    Param(
        [string]$BaseUrl = $BaseUrl,
        [string]$Version = $DockerVersion
    )


    if ( -not $DockerVersion -or $DockerVersion -eq "latest") {
        try {
            $ZipRelease = Get-LatestDockerVersion
        }
        catch {
            Write-Error "Failed to extract Docker version from the HTML content. Please check the URL or your internet connection. Details: $($_.Exception.Message)"
            exit 1
        }

        ## Ensure a version was found
        if ( -Not $ZipRelease ) {
            Write-Error "No Docker zip files found in the HTML content. Please check the URL or your internet connection."
            exit 1
        }

        ## Construct the full download URL
        $DownloadUrl = $BaseUrl + $ZipRelease
        Write-Debug "Download URL: $DownloadUrl"
    }
    else {
        try {
            $ZipRelease = $DockerVersion + ".zip"
        }
        catch {
            Write-Error "Failed to construct Docker version zip file name. Please check the provided version format. Details: $($_.Exception.Message)"
            exit 1
        }

        ## Ensure a version was found
        if ( -Not $ZipRelease ) {
            Write-Error "No Docker zip files found in the HTML content. Please check the URL or your internet connection."
            exit 1
        }

        ## Construct the full download URL
        $DownloadUrl = $BaseUrl + "" + "docker-$($ZipRelease).zip"
        Write-Debug "Download URL: $DownloadUrl"
    }

    if (-not $ZipRelease) {
        Write-Error "No Docker zip files found in the HTML content. Details: $($_.Exception.Message)"
        exit 1
    }

    Write-Host "Preparing to download Docker for Windows release: $ZipRelease" -ForegroundColor Cyan

    if (-not $DownloadUrl) {
        Write-Error "Failed to construct the download URL."
        exit 1
    }

    ## Define the output file name
    $OutputFile = "docker-latest.zip"

    ## Download the file
    Write-Host "Downloading Docker from $DownloadUrl to $OutputFile" -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $OutputFile
    }
    catch {
        Write-Error "Failed to download the Docker zip file. Please check the URL or your internet connection. Details: $($_.Exception.Message)"
        exit 1
    }

    Write-Host "Downloaded latest Docker for Windows release to $OutputFile"
}


function Start-ExtractDockerZip {
    Param(
        [string]$ZipFile = "docker-latest.zip",
        [string]$DestinationPath = $InstallPath,
        [switch]$Cleanup = $false
    )

    if ( -not ( Test-Path -Path $ZipFile ) ) {
        Write-Error "The specified zip file does not exist: $ZipFile"
        exit 1
    }

    # Create a temporary extraction path
    $tempPath = Join-Path -Path $env:TEMP -ChildPath "docker-extract"
    if ( Test-Path $tempPath ) {
        Remove-Item -Recurse -Force -Path $tempPath
    }
    New-Item -ItemType Directory -Path $tempPath | Out-Null

    Write-Host "Extracting Docker zip file to temporary path: $tempPath" -ForegroundColor Cyan
    try {
        Expand-Archive -Path $ZipFile -DestinationPath $tempPath -Force
    }
    catch {
        Write-Error "Failed to extract the Docker zip file. Details: $($_.Exception.Message)"
        exit 1
    }

    ## Move contents of the inner 'docker' folder to the final destination
    $innerDockerPath = Join-Path -Path $tempPath -ChildPath "docker"
    
    if ( -not ( Test-Path $innerDockerPath ) ) {
        Write-Error "Expected 'docker' folder not found in the archive."
        exit 1
    }

    if ( -not ( Test-Path $DestinationPath ) ) {
        New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    }

    Write-Host "Moving Docker files to $DestinationPath" -ForegroundColor Cyan
    Get-ChildItem -Path $innerDockerPath -Recurse | Move-Item -Destination $DestinationPath -Force

    ## Clean up
    if ( $Cleanup ) {
        try {
            Remove-Item -Recurse -Force -Path $tempPath
        } catch {
            Write-Error "Failed to clean up temporary extraction path: $tempPath. Details: $($_.Exception.Message)"
            exit 1
        }
    } 

    Write-Host "Docker has been extracted to $DestinationPath"
}


function Add-DockerToPath {
    Param(
        [string]$DockerPath = $InstallPath
    )
    
    ## Get the current system PATH
    $ExistingPath = [Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)

    ## Check if Docker path is already in PATH
    if ( $ExistingPath -notlike "*$dockerPath*" ) {
        ## Append Docker path to system PATH
        $NewPath = "$existingPath;$dockerPath"

        try {
            [Environment]::SetEnvironmentVariable("Path", $NewPath, [System.EnvironmentVariableTarget]::Machine)
            Write-Host "Docker path added to system PATH. You may need to restart your session for changes to take effect."
        }
        catch {
            Write-Error "Failed to add Docker path to system PATH. Please check your permissions. Details: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Host "Docker path is already in the system PATH."
    }

}

## Download Docker release
try {
    Start-DockerDownload -BaseUrl $BaseUrl -Version $DockerVersion
}
catch {
    Write-Error "An error occurred while trying to download Docker: $($_.Exception.Message)"
    exit 1
}

## Check if Docker is already installed
if ( Test-Path -Path $InstallPath ) {
    if ( $Update ) {
        Write-Host "Docker is already installed at $InstallPath and will be updated." -ForegroundColor Yellow
        
        try {
            Remove-Item -Recurse -Force -Path $installPath
            Write-Host "Removed existing Docker installation at $installPath"
        }
        catch {
            Write-Error "Failed to remove existing Docker installation at $installPath. Please check your permissions or if the path is correct. Details: $($_.Exception.Message)"
            exit 1
        }

    }
    else {
        Write-Host "Docker is already installed at $InstallPath. Use -Update to reinstall." -ForegroundColor Yellow
        exit 0
    }
}

## Extract to install location
try {
    Start-ExtractDockerZip -ZipFile "docker-latest.zip" -DestinationPath $InstallPath -Cleanup:$Cleanup
}
catch {
    Write-Error "An error occurred while trying to extract Docker: $($_.Exception.Message)"
    exit 1
}

## Add Docker to system PATH
try {
    Add-DockerToPath -DockerPath $InstallPath
}
catch {
    Write-Error "An error occurred while trying to add Docker to the system PATH: $($_.Exception.Message)"
    exit 1
}

Write-Host "Docker installed. Restart your Powershell session, then run dockerd --register-service as an administrator to register the Docker service." -ForegroundColor Green

## Do cleanup
if ( $Cleanup ) {
    Write-Host "Cleaning up downloaded files..." -ForegroundColor Cyan
    try {
        Remove-Item -Path "docker-latest.zip" -Force
        Write-Host "Cleanup completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to clean up downloaded files: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Host "Cleanup skipped. The downloaded zip file remains in the current directory." -ForegroundColor Yellow
    exit 0
}
