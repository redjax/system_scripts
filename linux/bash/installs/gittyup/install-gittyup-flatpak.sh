#!/bin/bash

set -e

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

if ! command -v flatpak &>/dev/null; then
  echo "Flatpak not found. Please install Flatpak first."
  exit 1
fi

## Get latest release version from GitHub API (strip leading 'v')
VERSION=$(curl -s https://api.github.com/repos/Murmele/Gittyup/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
VERSION="${VERSION#v}"

if [[ -z "$VERSION" ]]; then
  echo "[ERROR] Could not fetch latest version."
  exit 1
fi

GITHUB_FLATPAK_URL="https://github.com/Murmele/Gittyup/releases/download/gittyup_v${VERSION}/Gittyup-gittyup_v${VERSION}.flatpak"
FLATPAK_APP_ID="com.github.Murmele.Gittyup"

echo "Latest Gittyup version detected: $VERSION"
echo "Choose an option:"
echo "1) Download the Flatpak release from GitHub and install it"
echo "2) Install Gittyup via Flatpak from Flathub"
read -rp "Enter 1 or 2: " CHOICE

if [[ "$CHOICE" == "1" ]]; then
  echo "Downloading Gittyup Flatpak release from GitHub..."
  curl -LO "$GITHUB_FLATPAK_URL"
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to download Gittyup Flatpak release"
    exit 1
  fi

  FILE_NAME="Gittyup-gittyup_v${VERSION}.flatpak"
  echo "Download complete: $FILE_NAME"

  echo "Installing downloaded Flatpak package..."
  flatpak install --user --noninteractive "$FILE_NAME"
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to install the Flatpak package."
    exit 1
  fi

  echo "Installation from downloaded Flatpak complete."

elif [[ "$CHOICE" == "2" ]]; then
  echo "Installing Gittyup via Flatpak from Flathub..."

  ## Add Flathub repo if missing
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to add Flathub repo."
    exit 1
  fi

  flatpak install -y flathub "$FLATPAK_APP_ID"
  if [[ $? -ne 0 ]]; then
    echo "[ERROR] Failed to install Gittyup from Flathub."
    exit 1
  fi

  echo "Gittyup installed via Flatpak from Flathub."

else
  echo "Invalid choice."
  exit 1
fi
