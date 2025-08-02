#!/bin/bash

set -e

# Detect Distro via /etc/os-release
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO_ID="$ID"
else
    echo "Unsupported or unknown OS."
    exit 1
fi

function install_direnv() {
    local id="$1"
    case "$id" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y direnv
            ;;
        fedora)
            sudo dnf install -y direnv
            ;;
        rhel|rocky|almalinux)
            ## Try dnf first, fallback to yum for older releases
            if command -v dnf &>/dev/null; then
                sudo dnf install -y direnv
            else
                sudo yum install -y direnv
            fi
            ;;
        opensuse*|sles)
            sudo zypper install -y direnv
            ;;
        arch)
            sudo pacman -Sy --noconfirm direnv
            ;;
        *)
            echo "Distribution '$id' not supported by this script."
            exit 1
            ;;
    esac
}

if ! command -v direnv &>/dev/null; then
    echo "Detected distribution: $DISTRO_ID"
    install_direnv "$DISTRO_ID"

    echo "direnv installation complete."
else
    echo "direnv is already installed."
fi
