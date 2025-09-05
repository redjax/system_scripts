#!/bin/bash

##
# Script to detect OS and install rsync accordingly.
##

set -euo pipefail

function install_rclone_linux() {
    case $DISTRO in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y rclone
            ;;
        fedora)
            sudo dnf install -y rclone
            ;;
        centos|rhel)
            sudo yum install -y epel-release
            sudo yum install -y rclone
            ;;
        arch|manjaro)
            sudo pacman -Sy --noconfirm rclone
            ;;
        alpine)
            sudo apk add rclone
            ;;
        *)
            echo "Linux distribution $DISTRO is not supported."
            echo "Please install rclone manually: https://rclone.org/install/"
            ;;
    esac
}

function install_rclone_macos() {
    if command -v brew >/dev/null 2>&1; then
        echo "Installing rclone using Homebrew..."
        brew install rclone
    else
        echo "Homebrew not found. Please install Homebrew or install rclone manually: https://rclone.org/downloads/"
        echo ""
        return 1
    fi
}

function main() {
    OS=$(uname -s)

    if command -v rclone &>/dev/null; then
        echo "Rclone is already installed."

        return 0
    fi

    case "$OS" in
        Linux)
            
            install_rclone_linux

            if [[ $? -ne 0 ]]; then
                echo "Failed to install rclone."
                return 1
            fi
            ;;
        Darwin)
            install_rclone_macos

            if [[ $? -ne 0 ]]; then
                echo "Failed to install rclone."
                return 1
            fi
            ;;
        *)
            echo "Unsupported operating system: $OS"
            return 1
            ;;
    esac

    echo "Rclone installation completed."
}

main
if [[ $? -ne 0 ]]; then
    echo "Installation failed."
    exit 1
fi
