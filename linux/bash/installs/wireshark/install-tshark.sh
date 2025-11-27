#!/usr/bin/env bash
set -euo pipefail

echo "[+] Installing tshark / Wireshark CLI..."

OS="$(uname -s)"

if [ "$OS" = "Linux" ]; then
    if command -v apt >/dev/null; then
        sudo apt update
        sudo apt install -y tshark
    elif command -v dnf >/dev/null; then
        sudo dnf install -y wireshark-cli
    elif command -v yum >/dev/null; then
        sudo yum install -y wireshark-cli
    elif command -v pacman >/dev/null; then
        sudo pacman -Sy --noconfirm wireshark-cli
    else
        echo "Unsupported Linux distribution"
        exit 1
    fi
elif [ "$OS" = "Darwin" ]; then
    if ! command -v brew >/dev/null; then
        echo "[!] Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install wireshark
else
    echo "Unsupported OS: $OS"
    exit 1
fi

echo "[✓] tshark installed successfully!"
echo "Run 'tshark -v' to verify."
