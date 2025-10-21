#!/bin/bash

## Check for Remote Desktop Manager
if command -v remotedesktopmanager >/dev/null 2>&1 || command -v remote-desktop-manager >/dev/null 2>&1; then
    echo "Devolutions Remote Desktop Manager is already installed."
    exit 0
fi

if ! command -v curl &>/dev/null; then
    echo "curl is not installed."
    exit 1
fi

## Detect Distribution and Package Manager
source /etc/os-release
DISTRO=$ID

## Debian/Ubuntu
if command -v apt >/dev/null; then
    echo "Detected apt-based system ($DISTRO)."
    curl -1sLf 'https://dl.cloudsmith.io/public/devolutions/rdm/setup.deb.sh' | sudo -E bash
    
    sudo apt-get update -y
    sudo apt-get install remotedesktopmanager -y
## Fedora/RHEL/CentOS/SUSE
elif command -v dnf >/dev/null; then
    echo "Detected dnf-based system ($DISTRO)."

    if [ -f /etc/yum.repos.d/devolutions-rdm.repo ]; then
        sudo rm /etc/yum.repos.d/devolutions-rdm.repo
    fi
    curl -1sLf 'https://dl.cloudsmith.io/public/devolutions/rdm/setup.rpm.sh' | sudo -E bash

    sudo dnf update -y
    sudo dnf install RemoteDesktopManager -y
## Legacy RedHat/CentOS
elif command -v yum >/dev/null; then
    echo "Detected yum-based system ($DISTRO)."

    if [ -f /etc/yum.repos.d/devolutions-rdm.repo ]; then
        sudo rm /etc/yum.repos.d/devolutions-rdm.repo
    fi
    curl -1sLf 'https://dl.cloudsmith.io/public/devolutions/rdm/setup.rpm.sh' | sudo -E bash

    sudo yum install RemoteDesktopManager -y
## Arch/Manjaro (using yay for AUR)
elif command -v pacman >/dev/null; then
    echo "Detected pacman-based system ($DISTRO)."
    if ! command -v yay >/dev/null; then
        sudo pacman -Sy yay
    fi

    yay -Sy remote-desktop-manager
else
    echo "Unsupported or unknown distribution: $DISTRO"
    exit 1
fi
