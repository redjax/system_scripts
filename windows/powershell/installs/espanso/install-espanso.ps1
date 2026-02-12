## Install with scoop if scoop is installed
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "Scoop found, installing Espanso via Scoop..."
    scoop bucket add main
    scoop install main/espanso
## Install with winget
} else {
    Write-Host "Scoop not found, falling back to Winget..."
    winget install --id=Espanso.Espanso -e
}
