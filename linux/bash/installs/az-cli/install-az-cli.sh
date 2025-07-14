#!/bin/bash

set -e

install_azure_cli() {
    echo "Installing Azure CLI for $1..."

    case "$1" in
        debian|ubuntu)
            curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
            ;;
        fedora)
            sudo dnf install -y azure-cli
            ;;
        rhel|almalinux|rocky)
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

            sudo dnf install -y https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
            sudo dnf install -y azure-cli
            ;;
        opensuse*)
            sudo zypper install -y azure-cli
            ;;
        arch)
            sudo pacman -Sy --noconfirm azure-cli
            ;;
        *)
            echo "Unsupported distribution: $1"
            exit 1
            ;;
    esac
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

distro=$(detect_distro)
install_azure_cli "$distro"
if [[ $? -ne 0 ]]; then
  echo "Failed installing the Azure CLI on distro: $distro"
  exit $?
else
  echo "Installed the Azure CLI"
  exit 0
fi

