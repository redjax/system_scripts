#!/usr/bin/env bash
set -euo pipefail

if ! command -v ya >/dev/null 2>&1; then
  echo "ERROR: 'ya' is not installed."
  exit 1
fi

PACKAGES=(
  ## Flavors (themes)
  dangooddd/kanagawa
  muratoffalex/kanagawa-lotus

  ## Plugins
  yazi-rs/plugins:smart-enter
  yazi-rs/plugins:smart-paste
  yazi-rs/plugins:mount
  yazi-rs/plugins:vcs-files
  yazi-rs/plugins:smart-filter
  yazi-rs/plugins:chmod
  yazi-rs/plugins:mime-ext
  yazi-rs/plugins:diff
)

echo "Installing Yazi packages"

for package in "${PACKAGES[@]}"; do
  echo "  -> $package"
  ya pkg add "$package" || true
done

echo
echo "Yazi packages installed."
