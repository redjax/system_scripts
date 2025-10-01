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
            ;;
    esac
}

function install_resticprofile_linux() {
    echo "Downloading & executing resticprofile install script."
    sudo sh -c "$(curl -fsLS https://raw.githubusercontent.com/creativeprojects/resticprofile/master/install.sh)" -- -b /usr/local/bin
    
    if [[ $? -ne 0 ]]; then
        echo "Failed installing resticprofile."
        return $?
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
            exit 1
            ;;
    esac
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
        echo "Installing restic using Homebrew..."
        brew install restic
    else
        echo "Homebrew not found. Please install Homebrew or install restic manually:"
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
    local INSTALL_RESTICPROFILE="falsse"

    if command -v restic &>/dev/null; then
        echo "Restic is already installed."
        RESTIC_INSTALLED=true
    fi

    if [[ "$RCLONE_INSTALLED" = "false" ]]; then
        if command -v rclone &>/dev/null; then
            echo "Rclone is already installed."
            RCLONE_INSTALLED=true
        else
            read -rp "Do you want to install rclone as a backend for restic? [y/N]: " rclone_reply
        
            if [[ "$rclone_reply" =~ ^[Yy]$ ]]; then
                INSTALL_RCLONE=true
            else
                INSTALL_RCLONE=false
            fi
        fi
    fi

    if [[ "$AUTORESTIC_INSTALLED" = "false" ]]; then
        if command -v autorestic &>/dev/null; then
            echo "Autorestic is already installed."
            AUTORESTIC_INSTALLED=true
        else
	    read -rp "Do you want to install autorestic? [y/N]: " reply
        
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                INSTALL_AUTORESTIC=true
            else
                INSTALL_AUTORESTIC=false
            fi
        fi
    fi

    if [[ "${RESTICPROFILE_INSTALLED}" = "false" ]]; then
        if command -v resticprofile &>/dev/null; then
	    echo "Resticprofile is already installed."
            RESTICPROFILE_INSTALLED=true
        else
	    read -rp "Do you want to install resticprofile? [y/N]: " reply

	    if [[ "$reply" =~ ^[Yy]$ ]]; then
	        INSTALL_RESTICPROFILE=true
            else
	        INSTALL_RESTICPROFILE=false
            fi
	fi
    fi

    case "$OS" in
        Linux)
            if [[ ! "$RESTIC_INSTALLED" = "true" ]]; then
                install_restic_linux

                if [[ $? -ne 0 ]]; then
                    echo "Failed to install restic."
                    return 1
                fi
            fi

            if [[ "$INSTALL_RCLONE" = "true" ]]; then
                if [[ ! "$RCLONE_INSTALLED" = "true" ]]; then
                    install_rclone_linux

                    if [[ $? -ne 0 ]]; then
                        echo "Failed to install rclone."
                        return 1
                    fi
                fi
            fi

            if [[ "$INSTALL_AUTORESTIC" = "true" ]]; then
                install_autorestic
                if [[ $? -ne 0 ]]; then
                    echo "Failed to install autorestic."
                    return 1
                fi
            fi
            

	    if [[ "$INSTALL_RESTICPROFILE" = "true" ]]; then
		install_resticprofile

		if [[ $? -ne 0 ]]; then
		    echo "Failed to install resticprofile"
		    return 1
		fi
	    fi
            ;;
        Darwin)
            if [[ ! "$RESTIC_INSTALLED" = "true" ]]; then
                install_restic_macos

                if [[ $? -ne 0 ]]; then
                    echo "Failed to install restic."
                    return 1
                fi
            fi

            if [[ "$INSTALL_RCLONE" = "true" ]]; then
                if [[ ! "$RCLONE_INSTALLED" = "true" ]]; then
                    install_rclone_macos

                    if [[ $? -ne 0 ]]; then
                        echo "Failed to install rclone."
                        return 1
                    fi
                fi
            fi

            if [[ "$INSTALL_AUTORESTIC" = "true" ]]; then
                install_autorestic
                if [[ $? -ne 0 ]]; then
                    echo "Failed to install autorestic."
                    return 1
                fi
            fi

	    if [[ "$INSTALL_RESTICPROFILE" = "true" ]]; then
		install_resticprofile_macos

		if [[ $? -ne 0 ]]; then
		    echo "Failed to install resticprofile."
		    return 1
		fi
	    fi
	    ;;
        *)
            echo "Unsupported operating system: $OS"
            return 1
            ;;
    esac

    echo "Restic installation completed."
    if [[ "$INSTALL_RCLONE" = "true" ]]; then
        echo "Rclone installation completed."
    fi

    if [[ "$INSTALL_AUTORESTIC" = "true" ]]; then
	echo "Autorestic installation completed."
    fi

    if [[ "$INSTALL_RESTICPROFILE" = "true" ]]; then
	echo "Resticprofile installation completed."
    fi
}

main
if [[ $? -ne 0 ]]; then
    echo "Installation failed."
    exit 1
fi
