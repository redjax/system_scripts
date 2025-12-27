$repo = "github/git-sizer"
$apiUrl = "https://api.github.com/repos/$repo/releases/latest"
$tmpDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
New-Item -Path $tmpDir -ItemType Directory | Out-Null

if ([Environment]::Is64BitOperatingSystem) {
    $arch = "amd64"
} else {
    $arch = "386"
}

Write-Host "Fetching latest release info from GitHub API"
$releaseJson = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing

$tagName = $releaseJson.tag_name
Write-Host "Latest version: $tagName"

# Find the asset matching windows and arch
$asset = $releaseJson.assets | Where-Object { $_.name -like "git-sizer-$($tagName.TrimStart('v'))-windows-$arch.zip" }

if (-not $asset) {
    Write-Error "Cannot find matching asset for windows-$arch"
    exit 1
}

$assetUrl = $asset.browser_download_url
$outputPath = Join-Path $tmpDir "git-sizer.zip"

Write-Host "Downloading $($asset.name)"
Invoke-WebRequest -Uri $assetUrl -OutFile $outputPath

Write-Host "Extracting"
Expand-Archive -Path $outputPath -DestinationPath $tmpDir

$installPath = Join-Path $env:USERPROFILE "bin"

if (-not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath | Out-Null
}

Move-Item -Path (Join-Path $tmpDir "git-sizer.exe") -Destination $installPath -Force

Write-Host "Cleaning up"
Remove-Item -Recurse -Force $tmpDir

Write-Host "git-sizer $tagName installed successfully."
Write-Host "Please add $installPath to your PATH environment variable if it is not already included."

