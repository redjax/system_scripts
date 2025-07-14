Write-Host "Downloading & executin Chezmoi install script."
try {
  iex "&{$(irm 'https://get.chezmoi.io/ps1')} -b '~/bin'"
  Write-Host "Chezmoi installed."
} catch {
  Write-Error "Error installing chezmoi. Details: $($_.Exception.Message)"
  exit(1)
}

