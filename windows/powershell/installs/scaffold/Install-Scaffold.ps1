<#
.SYNOPSIS
Installs or updates hay-kot/scaffold from GitHub releases. https://github.com/hay-kot/scaffold
#>

param (
    [string]$InstallDir = "$HOME\bin"
)

## Ensure the install directory exists
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

## Detect OS
switch ($PSVersionTable.OS) {
    { $_ -match "Windows" } { $OSName = "Windows"; $Ext = "zip"; break }
    { $_ -match "Darwin" }  { $OSName = "Darwin"; $Ext = "tar.gz"; break }
    default                  { $OSName = "Linux"; $Ext = "tar.gz" }
}

## Detect architecture
$Arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
    "X64"   { "x86_64" }
    "X86"   { "i386" }
    "Arm64" { "arm64" }
    default { throw "Unsupported architecture: $_" }
}

## Check if scaffold is already installed
$scaffoldPath = Get-Command scaffold -ErrorAction SilentlyContinue | Select-Object -First 1
if ($scaffoldPath) {
    $answer = Read-Host "scaffold is already installed at $($scaffoldPath.Path). Update to latest version? [y/N]"

    if ($answer -notmatch "^[Yy]") {
        Write-Host "Aborting."
        exit 0
    }

    Write-Host "Updating scaffold"
}

## Get latest release tag from GitHub API
$Repo = "hay-kot/scaffold"
$Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing
$LatestTag = $Release.tag_name

if (-not $LatestTag) {
    Write-Error "Failed to fetch latest release."
    exit 1
}

## Construct download URL
$FileName = "scaffold_${OSName}_${Arch}.${Ext}"
$Url = "https://github.com/$Repo/releases/download/$LatestTag/$FileName"

## Download to temp directory
$TmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.IO.Path]::GetRandomFileName())
$DownloadPath = Join-Path $TmpDir $FileName

Write-Host "Downloading $FileName from $Url "
Invoke-WebRequest -Uri $Url -OutFile $DownloadPath

## Extract and install
if ($Ext -eq "tar.gz") {
    ## Requires tar available (Linux/macOS or Windows 10+ with tar)
    tar -xzf $DownloadPath -C $TmpDir
} elseif ($Ext -eq "zip") {
    Expand-Archive -Path $DownloadPath -DestinationPath $TmpDir
} else {
    throw "Unsupported archive format: $Ext"
}

## Move binary to install directory
$BinaryPath = Join-Path $TmpDir "scaffold"
if ($OSName -eq "Windows") { $BinaryPath += ".exe" }

Move-Item -Path $BinaryPath -Destination $InstallDir -Force
Write-Host "scaffold installed to $InstallDir"

## Suggest updating PATH if needed
if (-not ($Env:PATH -split ";" | Where-Object { $_ -eq $InstallDir })) {
    Write-Host "Consider adding $InstallDir to your PATH."
}