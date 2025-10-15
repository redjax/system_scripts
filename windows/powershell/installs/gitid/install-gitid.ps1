# Detect CPU architecture (x64 or arm64)
$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLower()

if ($arch -notin @('x64', 'arm64')) {
    Write-Error "Unsupported architecture: $arch"
    exit 1
}

# Map architecture to common release asset string format
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

# Temporary directory for download and extraction
$tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath()) -Name ("gitid_install_" + [guid]::NewGuid().ToString()) -Force

try {
    Write-Host "Fetching latest release info..."
    $release = Invoke-RestMethod -Uri $apiUrl

    # Find matching asset for Windows + arch
    $asset = $release.assets | Where-Object {
        $_.name -match "windows" -and $_.name -match $archStr
    } | Select-Object -First 1

    if (-not $asset) {
        Write-Error "No suitable release asset found for Windows and architecture $archStr"
        exit 1
    }

    $assetUrl = $asset.browser_download_url
    $fileName = Join-Path $tmpDir $asset.name

    Write-Host "Downloading $($asset.name) ..."
    Invoke-WebRequest -Uri $assetUrl -OutFile $fileName

    # Prepare install directory
    $installDir = Join-Path $env:LOCALAPPDATA "Programs\gitid"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    # Extract depending on file extension
    Write-Host "Extracting..."
    if ($fileName -like "*.zip") {
        Expand-Archive -Path $fileName -DestinationPath $tmpDir -Force
    } elseif ($fileName -like "*.tar.gz") {
        # Requires tar on system (Windows 10+)
        tar -xzf $fileName -C $tmpDir
    } else {
        # Assume it's executable binary directly
        Copy-Item $fileName -Destination $installDir\gitid.exe -Force
        Write-Host "Installed gitid to $installDir\gitid.exe"
        exit 0
    }

    # Find extracted gitid.exe
    $exePath = Get-ChildItem -Path $tmpDir -Recurse -Filter "gitid.exe" | Select-Object -First 1

    if (-not $exePath) {
        Write-Error "gitid.exe not found after extraction"
        exit 1
    }

    # Move executable to install directory
    Move-Item -Path $exePath.FullName -Destination (Join-Path $installDir "gitid.exe") -Force

    Write-Host "gitid installed to $installDir\gitid.exe"
    Write-Host "Make sure to add '$installDir' to your PATH environment variable if not already present, so you can run 'gitid' from any command line."
} finally {
    # Cleanup temp directory
    Remove-Item -Path $tmpDir -Recurse -Force
}

