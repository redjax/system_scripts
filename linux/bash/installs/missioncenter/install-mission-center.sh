#!/usr/bin/env bash
set -uo pipefail

APP_ID="io.missioncenter.MissionCenter"
FLATHUB_REPO="https://flathub.org/repo/flathub.flatpakrepo"

## Check if flatpak is installed
if ! command -v flatpak &>/dev/null; then
    echo "Flatpak is not installed. Install it first, then add Flathub and rerun."
    echo "Ubuntu/Debian: sudo apt install flatpak"

    echo "Then: flatpak remote-add --if-not-exists flathub $FLATHUB_REPO"
    exit 1
fi

## Add Flathub repo if needed
flatpak remote-add --if-not-exists flathub "$FLATHUB_REPO"

## Check if app is already installed
if flatpak list | grep -q "$APP_ID"; then
    echo "$APP_ID is already installed. Update it? (y/N)"
    read -r -n 1 -t 10 response
    echo

    if [[ "$response" =~ ^[Yy]$ ]]; then
        flatpak update "$APP_ID" -y
    else
        echo "Skipping update."
        exit 0
    fi
else
    echo "Installing $APP_ID from Flathub"
    flatpak install flathub "$APP_ID" -y
fi

echo "Mission Center ready. Run with: flatpak run $APP_ID"
