#!/bin/bash

set -euo pipefail

if command -v nordvpn >/dev/null 2>&1; then
    echo "NordVPN is already installed."
    exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "curl is not installed."
    exit 1
fi

echo "Installing NordVPN (CLI)"
sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)

echo "Creating group 'nordvpn' & adding user $USER"
sudo groupadd nordvpn
sudo usermod -aG nordvpn $USER
newgrp nordvpn

exit 0
