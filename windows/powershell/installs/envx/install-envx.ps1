# Requires PowerShell 5+
$Repo = "mikeleppane/envx"
$Bin = "envx"
$Temp = New-Item -ItemType Directory -Path ([System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid()) -Force
$InstallDir = "$env:ProgramFiles\envx"
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }

# Detect architecture
$Arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
$File = "$Bin-windows-$Arch.exe"

# Get the latest tag name from GitHub API
$LatestTag = (Invoke-WebRequest "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing).Content | ConvertFrom-Json | Select-Object -ExpandProperty tag_name
$DownloadUrl = "https://github.com/$Repo/releases/download/$LatestTag/$File"

Write-Host "Downloading $File version $LatestTag to temp"
Invoke-WebRequest -Uri $DownloadUrl -OutFile "$Temp\$File"

Write-Host "Installing $File to $InstallDir"
Copy-Item "$Temp\$File" "$InstallDir\$Bin.exe" -Force

# Add install dir to PATH (current user)
$CurrentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($CurrentPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$CurrentPath;$InstallDir", 'User')
    Write-Host "Added $InstallDir to PATH for current user."
}

Write-Host "$Bin installed to $InstallDir as $Bin.exe (version $LatestTag)"
Remove-Item -Path $Temp -Recurse -Force

