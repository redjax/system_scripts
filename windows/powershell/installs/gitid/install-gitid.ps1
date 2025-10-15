# Detect CPU architecture (x64 or arm64)
$archRaw = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLower()

if ($archRaw -notin @('x64', 'arm64')) {
    Write-Error "Unsupported architecture: $archRaw"
    exit 1
}

# Map .NET architecture to release asset naming scheme
switch ($archRaw) {
    "x64" { $archStr = "amd64" }
    "arm64" { $archStr = "arm64" }
    default {
        Write-Error "Unsupported architecture mapping: $archRaw"
        exit 1
    }
}

$repo = "nathabonfim59/gitid"
$apiUrl = "https://api.github.com/repos/$repo/releases/latest"

# Create temp directory for download/extraction
$tmpDir = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath()) -Name ("gitid_install_" + [guid]::NewGuid().ToString()) -Force

try {
    Write-Host "Fetching latest release info from GitHub"
    $release = Invoke-RestMethod -Uri $apiUrl

    # Pick first asset matching windows and architecture
    $asset = $release.assets | Where-Object { 
        $_.name -match "windows" -and $_.name -match $archStr 
    } | Select-Object -First 1

    if (-not $asset) {
        Write-Error "No suitable release asset found for Windows and architecture '$archStr'."
        exit 1
    }

    $assetUrl = $asset.browser_download_url
    $fileName = Join-Path $tmpDir $asset.name

    Write-Host "Downloading $($asset.name)"
    Invoke-WebRequest -Uri $assetUrl -OutFile $fileName

    # Define and create install directory
    $installDir = Join-Path $env:LOCALAPPDATA "Programs\gitid"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    Write-Host "Extracting downloaded archive"
    if ($fileName -like "*.zip") {
        Expand-Archive -Path $fileName -DestinationPath $tmpDir -Force
    } elseif ($fileName -like "*.tar.gz") {
        tar -xzf $fileName -C $tmpDir
    } else {
        # If single executable, just copy it
        Copy-Item -Path $fileName -Destination (Join-Path $installDir "gitid.exe") -Force
        Write-Host "Installed gitid to $installDir\gitid.exe"
    }

    # Permanently add installDir to User PATH if missing
    $currentUserPath = [Environment]::GetEnvironmentVariable('Path', 'User') -or ''
    $paths = $currentUserPath -split ';' | ForEach-Object { $_.TrimEnd('\') }

    if (-not ($paths -contains $installDir)) {
        $newUserPath = if ([string]::IsNullOrWhiteSpace($currentUserPath)) {
            $installDir
        } else {
            "$currentUserPath;$installDir"
        }

        [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
        Write-Host "Added $installDir to the user PATH environment variable."
        Write-Host "You must restart your terminal or log off and log back in to apply the PATH change."
    } else {
        Write-Host "$installDir is already in the user PATH environment variable."
    }
} finally {
    # Clean up temp files
    Remove-Item -Path $tmpDir -Recurse -Force
}


