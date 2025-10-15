# Detect CPU architecture (x64 or arm64)
$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLower()

if ($arch -notin @('x64', 'arm64')) {
    Write-Error "Unsupported architecture: $arch"
    exit 1
}

# Map architecture to common release asset string format used in gitid releases
switch ($arch) {
    "x64" { $archStr = "amd64" }
    "arm64" { $archStr = "arm64" }
    default {
        Write-Error "Unsupported architecture mapping: $arch"
        exit 1
    }
}

$repo = "nathabonfim59/gitid"
$apiUrl = "https://api.github.com/repos/$repo/releases/latest"

# Create a temporary directory for download and extraction
$tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath()) -Name ("gitid_install_" + [guid]::NewGuid().ToString()) -Force

try {
    Write-Host "Fetching latest release info from GitHub..."
    $release = Invoke-RestMethod -Uri $apiUrl

    # Find the first asset matching "windows" and the architecture string
    $asset = $release.assets | Where-Object {
        $_.name -match "windows" -and $_.name -match $archStr
    } | Select-Object -First 1

    if (-not $asset) {
        Write-Error "No suitable release asset found for Windows and architecture '$archStr'"
        exit 1
    }

    $assetUrl = $asset.browser_download_url
    $fileName = Join-Path $tmpDir $asset.name

    Write-Host "Downloading $($asset.name) ..."
    Invoke-WebRequest -Uri $assetUrl -OutFile $fileName

    # Define install directory ("%LOCALAPPDATA%\Programs\gitid\bin")
    $installDir = Join-Path $env:LOCALAPPDATA "Programs\gitid\bin"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    Write-Host "Extracting downloaded archive..."
    if ($fileName -like "*.zip") {
        Expand-Archive -Path $fileName -DestinationPath $tmpDir -Force
    } elseif ($fileName -like "*.tar.gz") {
        # Requires tar available (Windows 10+)
        tar -xzf $fileName -C $tmpDir
    } else {
        # If it's a single executable, copy directly
        Copy-Item $fileName -Destination (Join-Path $installDir "gitid.exe") -Force
        Write-Host "Installed gitid to $installDir\gitid.exe"
        exit 0
    }

    # Locate the extracted gitid.exe
    $exePath = Get-ChildItem -Path $tmpDir -Recurse -Filter "gitid.exe" | Select-Object -First 1

    if (-not $exePath) {
        Write-Error "gitid.exe not found after extraction"
        exit 1
    }

    # Move gitid.exe to install directory
    Move-Item -Path $exePath.FullName -Destination (Join-Path $installDir "gitid.exe") -Force
    Write-Host "gitid installed to $installDir\gitid.exe"

    # Update User PATH environment variable if needed
    $currentUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $paths = $currentUserPath -split ';'
    if ($paths -notcontains $installDir) {
        $newUserPath = if ([string]::IsNullOrEmpty($currentUserPath)) {
            $installDir
        } else {
            "$currentUserPath;$installDir"
        }
        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        Write-Host "Added $installDir to User PATH environment variable."
        Write-Host "Restart your terminal or log off/on for changes to take effect."
    } else {
        Write-Host "$installDir is already in the User PATH."
    }
} finally {
    # Clean up temporary directory
    Remove-Item -Path $tmpDir -Recurse -Force
}


