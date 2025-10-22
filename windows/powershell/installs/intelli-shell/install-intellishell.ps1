Write-Host "Installing intelli-shell"

try {
  irm https://raw.githubusercontent.com/lasantosr/intelli-shell/main/install.ps1 | iex

  Write-Host "Intelli-shell installed. Press CTRL+Space to use it." -ForegroundColor Green
} catch {
  Write-Error "Failed to download & install intelli-shell: $($_.Exception.Message)"
}

