#!/bin/bash
set -e

get_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        unameOut="$(uname -s)"
        echo "$unameOut"
    fi
}

install_flatpak_dbeaver() {
    echo "Installing DBeaver via Flatpak..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub io.dbeaver.DBeaverCommunity
    echo "DBeaver installed via Flatpak."
}

install_dbeaver_deb() {
    echo "Installing DBeaver via .deb package..."
    tmpdeb=$(mktemp --suffix=.deb)
    wget -q -O "$tmpdeb" https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb
    sudo dpkg -i "$tmpdeb"
    rm -f "$tmpdeb"
    echo "DBeaver installed."
}

install_dbeaver_rpm() {
    echo "Installing DBeaver via .rpm package..."
    tmprpm=$(mktemp --suffix=.rpm)
    wget -q -O "$tmprpm" https://dbeaver.io/files/dbeaver-ce-latest-stable.x86_64.rpm
    sudo rpm -Uvh "$tmprpm"
    rm -f "$tmprpm"
    echo "DBeaver installed."
}

main() {
    if command -v flatpak >/dev/null 2>&1; then
        install_flatpak_dbeaver
        exit 0
    fi

    DISTRO=$(get_distro)
    case "$DISTRO" in
        debian|ubuntu|linuxmint)
            install_dbeaver_deb
            ;;
        fedora|rhel|centos|opensuse*|suse)
            install_dbeaver_rpm
            ;;
        *)
            echo "Unsupported Linux distribution: $DISTRO"
            exit 1
            ;;
    esac
}

main

