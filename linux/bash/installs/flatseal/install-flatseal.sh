#!/usr/bin/env bash

set -uo pipefail

if ! command -v flatpak &>/dev/null; then
  echo "[ERROR] Flatpak is not installed."
  exit 1
fi

if ! flatpak remotes | grep -q flathub; then
  echo "Adding Flathub repository"
  flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

echo "Installing Flatseal"
flatpak install -y flathub com.github.tchx84.Flatseal
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to install flatseal"

  exit $?
else
  echo "Flatseal installed"

  exit 0
fi
