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

    ## Extract all href links ending in .zip
    Write-Debug "Extracting zip links from the HTML content"
    try {
        $ZipLinks = ($html.Links | Where-Object { $_.href -match "\\.zip$" }).href
    }
    catch {
        Write-Error "Failed to extract zip links from the HTML content. Details: $($_.Exception.Message)"
        exit 1
    }

    ## Sort and get the latest version (assuming the list is sorted by version/date)
    Write-Debug "Determining the latest Docker zip file"
    try {
        $LatestZip = $ZipLinks | Sort-Object | Select-Object -Last 1
    }
    catch {
        Write-Error "Failed to determine the latest Docker zip file. Details: $($_.Exception.Message)"
        exit 1
    }

    Write-Debug "Latest Docker zip file: $LatestZip"

    $LatestZip
}

function Start-DockerDownload {
    Param(
        [string]$BaseUrl = $BaseUrl,
        [string]$Version = $DockerVersion
    )


    if ( -not $DockerVersion -or $DockerVersion -eq "latest") {
        $ZipRelease = Get-LatestDockerVersion
        ## Construct the full download URL
        $DownloadUrl = $BaseUrl + $ZipRelease
        Write-Debug "Download URL: $DownloadUrl"
    }
    else {
        $ZipRelease = $DockerVersion + ".zip"
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
        [string]$DestinationPath = $InstallPath
    )

    if ( -not ( Test-Path -Path $ZipFile ) ) {
        Write-Error "The specified zip file does not exist: $ZipFile"
        exit 1
    }

    Write-Host "Extracting Docker zip file to $DestinationPath" -ForegroundColor Cyan

    try {
        Expand-Archive -Path $ZipFile -DestinationPath $DestinationPath -Force
    }
    catch {
        Write-Error "Failed to extract the Docker zip file. Please check the zip file and destination path. Details: $($_.Exception.Message)"
        exit 1
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
        } catch {
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
    Start-ExtractDockerZip -ZipFile "docker-latest.zip" -DestinationPath $InstallPath
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
}
