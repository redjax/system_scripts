#!/usr/bin/env pwsh
param(
    [switch]$Latest,
    [switch]$Local,
    [switch]$Simple
)

## URL for Go releases JSON
$goJsonUrl = "https://go.dev/dl/?mode=json"

## Fetch JSON
try {
    $releases = Invoke-RestMethod -Uri $goJsonUrl
} catch {
    Write-Error "Failed to fetch Go releases: $_"
    exit 1
}

## If --local, filter for current OS/Arch
if ($Local) {
    $os = $PSVersionTable.PSEdition -eq "Core" ? $env:OS : "windows"
    $arch = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }

    foreach ($release in $releases) {
        $release.files = $release.files | Where-Object { $_.os -eq $os -and $_.arch -eq $arch }
    }
}

## If --latest, sort descending and take first
if ($Latest) {
    $releases = $releases | Sort-Object version -Descending
    
    if ($releases.Count -gt 0) {
        $releases = $releases[0..0]
    }
}

## Print results
foreach ($release in $releases) {
    if ($Simple) {
        ## Print only version number (without "go" prefix)
        $release.version -replace "^go", ""
    } else {
        Write-Output $release.version
        foreach ($file in $release.files) {
            Write-Output ("  {0} ({1}/{2})" -f $file.filename, $file.os, $file.arch)
        }
    }
}
