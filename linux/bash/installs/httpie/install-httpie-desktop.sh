#!/bin/bash

set -e

## Add Flathub repo if missing
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
if [[ $? -ne 0 ]]; then
echo "[ERROR] Failed to add Flathub repo."
exit 1
fi

if ! command -v flatpak &>/dev/null; then
  echo "Flatpak not found. Please install Flatpak first."
  exit 1
fi

## Add Flathub repo if missing
# Add Flathub repo if missing
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to add Flathub repo."
  exit 1
fi

FLATPAK_APP_ID="io.httpie.Httpie"

flatpak install -y flathub "$FLATPAK_APP_ID"
if [[ $? -ne 0 ]]; then
  echo "[ERROR] Failed to install HTTPie from Flathub."
  exit 1
fi

echo "Installed HTTPie desktop flatpak"
exit 0
