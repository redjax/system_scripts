#!/bin/bash

set -e

install_wine() {
    echo "Installing Wine for $1..."
    case "$1" in
        ubuntu|debian)
            ## Enable 32-bit architecture for Wine
            sudo dpkg --add-architecture i386
            ## Download and add WineHQ key and repository
            wget -nc https://dl.winehq.org/wine-builds/winehq.key
            sudo apt-key add winehq.key
            if [ "$1" = "ubuntu" ]; then
                release="$(lsb_release -cs)"
            else
                release="$(lsb_release -cs)"
            fi
            ## Add WineHQ repo
            sudo apt-add-repository "https://dl.winehq.org/wine-builds/$1/"
            sudo apt update
            ## Install Wine Stable with recommended dependencies
            sudo apt install -y --install-recommends winehq-stable
            ;;
        fedora)
            ## Enable 32-bit architecture (Fedora does this by default in most cases)
            sudo dnf install -y wine
            ;;
        rhel|almalinux|rocky)
            ## Enable EPEL and RPM Fusion repos for Wine and Lutris dependencies
            sudo dnf install -y epel-release
            sudo dnf install -y https://download1.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm
            ## Install Wine
            sudo dnf install -y wine wine-dosdevices wine-core wine-fonts wine-uninstaller
            ;;
        opensuse*|suse*)
            sudo zypper install -y wine
            ;;
        arch)
            sudo pacman -Sy --noconfirm wine
            ;;
        *)
            echo "Unsupported distribution for Wine installation: $1"
            ;;
    esac
}

install_lutris() {
    echo "Installing Lutris for $1..."

    case "$1" in
        ubuntu)
            sudo add-apt-repository ppa:lutris-team/lutris -y
            sudo apt update
            sudo apt install -y lutris
            ;;
        debian)
            codename=$(lsb_release -cs)
            echo "deb http://download.opensuse.org/repositories/home:/strycore/Debian_${codename^}/ ./" | sudo tee /etc/apt/sources.list.d/lutris.list
            wget -q https://download.opensuse.org/repositories/home:/strycore/Debian_${codename^}/Release.key -O- | sudo apt-key add -
            sudo apt update
            sudo apt install -y lutris
            ;;
        fedora)
            sudo dnf install -y lutris
            ;;
        rhel|almalinux|rocky)
            sudo dnf install -y epel-release
            sudo dnf install -y https://download1.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm
            sudo dnf install -y lutris
            ;;
        opensuse*|suse*)
            sudo zypper ar -f https://download.opensuse.org/repositories/games:tools/openSUSE_Tumbleweed/games:tools.repo
            sudo zypper refresh
            sudo zypper install -y lutris
            ;;
        arch)
            sudo pacman -Sy --noconfirm lutris
            ;;
        *)
            echo "Unsupported distribution: $1"
            echo "Try using the Flatpak install instead:"
            echo "flatpak install flathub net.lutris.Lutris"
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

install_wine "$distro"
if [[ $? -ne 0 ]]; then
  echo "Failed installing Wine on distro: $distro"
  exit $?
fi

install_lutris "$distro"
if [[ $? -ne 0 ]]; then
  echo "Failed installing Lutris on distro: $distro"
  exit $?
fi

echo "Wine and Lutris successfully installed on $distro!"

exit 0
