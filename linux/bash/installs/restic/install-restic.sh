#!/bin/bash


##
# Script to detect OS and install restic accordingly.
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
            return 1 ## ensure exit code is failure
            ;;
    esac
}

function install_resticprofile_linux() {
    echo "Downloading & executing resticprofile install script."
    sudo sh -c "$(curl -fsLS https://raw.githubusercontent.com/creativeprojects/resticprofile/master/install.sh)" -- -b /usr/local/bin

    if [[ $? -ne 0 ]]; then
        echo "Failed installing resticprofile."
        return 1 ## always return a numeric code
    else
        echo "resticprofile installed successfully."
        return 0
    fi
}

function install_restic_linux() {
    ## Detect distro and install using native package managers
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION_ID=$VERSION_ID
    else
        echo "Cannot detect Linux distribution."
        return 1
    fi

    echo "Detected Linux distro: $DISTRO version $VERSION_ID"

    case $DISTRO in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y restic
            ;;
        fedora)
            sudo dnf install -y restic
            ;;
        centos|rhel)
            sudo yum install -y epel-release
            sudo yum install -y restic
            ;;
        arch|manjaro)
            sudo pacman -Sy --noconfirm restic
            ;;
        alpine)
            sudo apk add restic
            ;;
        *)
            echo "Linux distribution $DISTRO is not supported by this script."
            echo "Please install restic manually: https://restic.readthedocs.io/en/latest/020_installation.html"
            return 1 ## exit code should be consistent
            ;;
    esac
}

function install_autorestic() {
    local WGET_INSTALLED=""
    local CURL_INSTALLED=""

    if command -v wget >/dev/null 2>&1; then
        WGET_INSTALLED="true"
    fi

    if command -v curl >/dev/null 2>&1; then
        CURL_INSTALLED="true"
    fi

    if [[ "$WGET_INSTALLED" == "" ]] && [[ "$CURL_INSTALLED" == "" ]]; then
        echo "[ERROR] Missing both wget & curl. Install one or both and try again."
        return 1 ## do not use exit inside a function
    fi

    if [[ "$WGET_INSTALLED" == "true" ]]; then
        echo "Installing autorestic"
        wget -qO- https://raw.githubusercontent.com/cupcakearmy/autorestic/master/install.sh | sudo bash ## corrected raw URL syntax

        if [[ $? -ne 0 ]]; then
            echo "[ERROR] Failed to install autorestic."
            return 1 ## properly handle install failure
        fi
    elif [[ "$CURL_INSTALLED" == "true" ]]; then
        echo "Installing autorestic"
        curl -LsSf https://raw.githubusercontent.com/cupcakearmy/autorestic/master/install.sh | sudo bash ## corrected raw URL syntax

        if [[ $? -ne 0 ]]; then
            echo "[ERROR] Failed to install autorestic."
            return 1 ## properly handle install failure
        fi
    fi
}

function install_rclone_macos() {
    if command -v brew >/dev/null 2>&1; then
        echo "Installing rclone using Homebrew..."
        brew install rclone
    else
        echo "Homebrew not found. Please install Homebrew or install rclone manually: https://rclone.org/install/"
        echo ""
        return 1
    fi
}

function install_restic_macos() {
    ## Use Homebrew if available
    if command -v brew >/dev/null 2>&1; then
        echo "Installing restic using Homebrew..."
        brew install restic
    else
        echo "Homebrew not found. Please install Homebrew or install restic manually:"
        echo "https://restic.readthedocs.io/en/latest/020_installation.html"
        return 1
    fi
}

function install_resticprofile_macos() {
    ## Use Homebrew if available
    if command -v brew >/dev/null 2>&1; then
        echo "Installing resticprofile using Homebrew..."
        brew install resticprofile ## fixed: proper Homebrew package name instead of restic
    else
        echo "Homebrew not found. Please install Homebrew or install resticprofile manually:"
        echo "https://restic.readthedocs.io/en/latest/020_installation.html"
        return 1
    fi
}

function main() {
    OS=$(uname -s)

    local RESTIC_INSTALLED="false"
    local RCLONE_INSTALLED="false"
    local AUTORESTIC_INSTALLED="false"
    local RESTICPROFILE_INSTALLED="false"
    local INSTALL_RESTIC="false"
    local INSTALL_RCLONE="false"
    local INSTALL_AUTORESTIC="false"
    local INSTALL_RESTICPROFILE="false"

    ## Check restic is installed
    if command -v restic &>/dev/null; then
        echo "Restic is already installed."
        RESTIC_INSTALLED="true"
    fi

    ## Check rclone is installed
    if command -v rclone &>/dev/null; then
        echo "Rclone is already installed."
        RCLONE_INSTALLED="true"
    else
        read -rp "Do you want to install rclone as a backend for restic? [y/N]: " rclone_reply

        if [[ "$rclone_reply" =~ ^[Yy]$ ]]; then
            INSTALL_RCLONE="true"
        fi
    fi

    ## Check autorestic is installed
    if command -v autorestic &>/dev/null; then
        echo "Autorestic is already installed."
        AUTORESTIC_INSTALLED="true"
    else
        read -rp "Do you want to install autorestic? [y/N]: " reply

        if [[ "$reply" =~ ^[Yy]$ ]]; then
            INSTALL_AUTORESTIC="true"
        fi
    fi

    ## Check resticprofile is installed
    if command -v resticprofile &>/dev/null; then
        echo "Resticprofile is already installed."
        RESTICPROFILE_INSTALLED="true"
    else
        read -rp "Do you want to install resticprofile? [y/N]: " reply

        if [[ "$reply" =~ ^[Yy]$ ]]; then
            INSTALL_RESTICPROFILE="true"
        fi
    fi

    ## Detect OS
    case "$OS" in
        Linux)
            if [[ "$RESTIC_INSTALLED" == "false" ]]; then
                install_restic_linux
                if [[ $? -ne 0 ]]; then
                    echo "Failed to install restic."
                    return 1
                fi
            fi

            if [[ "$INSTALL_RCLONE" == "true" ]]; then
                if [[ "$RCLONE_INSTALLED" == "false" ]]; then
                    install_rclone_linux
                    if [[ $? -ne 0 ]]; then
                        echo "Failed to install rclone."
                        return 1
                    fi
                else
                    echo "Rclone is already installed."
                fi
            fi

            if [[ "$INSTALL_AUTORESTIC" == "true" ]]; then
                if [[ "$AUTORESTIC_INSTALLED" == "false" ]]; then
                    install_autorestic
                    if [[ $? -ne 0 ]]; then
                        echo "Failed to install autorestic."
                        return 1
                    fi
                else
                    echo "Autorestic is already installed."
                fi
            fi

            if [[ "$INSTALL_RESTICPROFILE" == "true" ]]; then
                if [[ "$RESTICPROFILE_INSTALLED" == "false" ]]; then
                    install_resticprofile_linux
                    if [[ $? -ne 0 ]]; then
                        echo "Failed to install resticprofile."
                        return 1
                    fi
                else
                    echo "Resticprofile is already installed."
                fi
            fi
            ;;
        Darwin)
            if [[ "$RESTIC_INSTALLED" == "false" ]]; then
                install_restic_macos
                if [[ $? -ne 0 ]]; then
                    echo "Failed to install restic."
                    return 1
                fi
            fi

            if [[ "$INSTALL_RCLONE" == "true" ]]; then
                if [[ "$RCLONE_INSTALLED" == "false" ]]; then
                    install_rclone_macos
                    if [[ $? -ne 0 ]]; then
                        echo "Failed to install rclone."
                        return 1
                    fi
                else
                    echo "Rclone is already installed."
                fi
            fi

            if [[ "$INSTALL_AUTORESTIC" == "true" ]]; then
                if [[ "$AUTORESTIC_INSTALLED" == "false" ]]; then
                    install_autorestic
                    if [[ $? -ne 0 ]]; then
                        echo "Failed to install autorestic."
                        return 1
                    fi
                else
                    echo "Autorestic is already installed."
                fi
            fi

            if [[ "$INSTALL_RESTICPROFILE" == "true" ]]; then
                if [[ "$RESTICPROFILE_INSTALLED" == "false" ]]; then
                    install_resticprofile_macos
                    if [[ $? -ne 0 ]]; then
                        echo "Failed to install resticprofile."
                        return 1
                    fi
                else
                    echo "Resticprofile is already installed."
                fi
            fi
            ;;
        *)
            echo "Unsupported operating system: $OS"
            return 1
            ;;
    esac

    echo "Restic installation completed."
    if [[ "$INSTALL_RCLONE" == "true" ]]; then
        echo "Rclone installation completed."
    fi

    if [[ "$INSTALL_AUTORESTIC" == "true" ]]; then
        echo "Autorestic installation completed."
    fi

    if [[ "$INSTALL_RESTICPROFILE" == "true" ]]; then
        echo "Resticprofile installation completed."
    fi
}

main
if [[ $? -ne 0 ]]; then
    echo "Installation failed."
    exit 1
fi
