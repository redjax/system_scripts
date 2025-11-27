#!/usr/bin/env bash
set -euo pipefail

echo "[+] Installing nethogs"

OS="$(uname -s)"
if [ "$OS" = "Darwin" ]; then
    echo "[-] nethogs is NOT available on macOS."
    exit 1
fi

if command -v apt >/dev/null; then
    sudo apt update && sudo apt install -y nethogs
elif command -v dnf >/dev/null; then
    sudo dnf install -y nethogs
elif command -v yum >/dev/null; then
    sudo yum install -y epel-release && sudo yum install -y nethogs
elif command -v pacman >/dev/null; then
    sudo pacman -Sy --noconfirm nethogs
else
    echo "Unsupported Linux distribution."
    exit 1
fi

echo "[✓] nethogs installed!"
echo "Run:   sudo nethogs"
