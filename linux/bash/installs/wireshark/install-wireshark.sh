#!/usr/bin/env bash
set -euo pipefail

echo "[+] Installing Wireshark (GUI + CLI) cross-platform"

OS="$(uname -s)"

if [ "$OS" = "Linux" ]; then

    # Debian/Ubuntu
    if command -v apt >/dev/null; then
        echo "[+] Using apt (Debian/Ubuntu)"

        sudo apt update
        sudo apt install -y wireshark

        # Ensure wireshark group exists
        if ! getent group wireshark >/dev/null; then
            echo "[+] Creating wireshark group"
            sudo groupadd wireshark
        fi

        echo "[+] Adding current user to wireshark group for packet capture"
        sudo usermod -aG wireshark "$USER"

        echo "You may need to log out/in for group changes to take effect."
        echo "Optionally, run: sudo dpkg-reconfigure wireshark-common to allow non-root capture"

    # Fedora/RHEL
    elif command -v dnf >/dev/null; then
        echo "[+] Using dnf (Fedora/RHEL)"
        sudo dnf install -y wireshark-qt tshark

        if ! getent group wireshark >/dev/null; then
            echo "[+] Creating wireshark group"
            sudo groupadd wireshark
        fi

        sudo usermod -aG wireshark "$USER"
        echo "You may need to log out/in for group changes to take effect."

    # CentOS/RHEL legacy
    elif command -v yum >/dev/null; then
        echo "[+] Using yum (RHEL/CentOS)"
        sudo yum install -y wireshark-qt tshark

        if ! getent group wireshark >/dev/null; then
            echo "[+] Creating wireshark group"
            sudo groupadd wireshark
        fi

        sudo usermod -aG wireshark "$USER"
        echo "You may need to log out/in for group changes to take effect."

    # Arch/Manjaro
    elif command -v pacman >/dev/null; then
        echo "[+] Using pacman (Arch/Manjaro)"
        sudo pacman -Sy --noconfirm wireshark-qt

        if ! getent group wireshark >/dev/null; then
            echo "[+] Creating wireshark group"
            sudo groupadd wireshark
        fi

        sudo gpasswd -a "$USER" wireshark
        echo "You may need to log out/in for group changes to take effect."

    else
        echo "[-] Unsupported Linux distribution"
        exit 1
    fi

# macOS
elif [ "$OS" = "Darwin" ]; then
    if ! command -v brew >/dev/null; then
        echo "[!] Homebrew not found. Installing Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    echo "[+] Installing Wireshark via Homebrew"
    brew install --cask wireshark

    echo "[+] Wireshark installed!"

else
    echo "[-] Unsupported OS: $OS"
    exit 1
fi

echo "[✓] Wireshark installation complete!"

echo "Verify CLI: tshark -v"
echo "Verify GUI: wireshark --version"
