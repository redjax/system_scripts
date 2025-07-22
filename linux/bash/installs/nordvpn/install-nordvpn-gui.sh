#!/bin/bash

set -euo pipefail

if command -v nordvpn >/dev/null 2>&1; then
    echo "NordVPN is already installed."
    exit 0
fi

if ! command -v wget >/dev/null 2>&1; then
    echo "wget is not installed."
    exit 1
fi

echo "Installing NordVPN (GUI)"
sh <(wget -qO - https://downloads.nordcdn.com/apps/linux/install.sh) -p nordvpn-gui

echo "Creating group 'nordvpn' & adding user $USER"
sudo groupadd nordvpn
sudo usermod -aG nordvpn $USER
newgrp nordvpn

exit 0
