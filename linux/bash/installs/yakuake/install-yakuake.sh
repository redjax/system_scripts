#!/usr/bin/env bash

set -e

install_yakuake_via_flatpak() {
  echo "Trying to install Yakuake via Flatpak..."
  if command -v flatpak >/dev/null 2>&1; then
    flatpak install -y flathub org.kde.yakuake && echo "Yakuake installed with Flatpak." && exit 0
  else
    echo "Flatpak is not installed or not available."
  fi
}

install_yakuake_via_package_manager() {
  echo "Attempting distro-specific package manager install for Yakuake..."
  if [[ $EUID -ne 0 ]]; then
    SUDO='sudo'
  else
    SUDO=''
  fi

  case "$ID" in
  ubuntu | debian | raspbian)
    $SUDO apt update
    $SUDO apt install -y yakuake
    ;;
  fedora)
    $SUDO dnf install -y yakuake
    ;;
  arch | manjaro)
    $SUDO pacman -Sy --noconfirm yakuake
    ;;
  opensuse* | suse)
    $SUDO zypper install -y yakuake
    ;;
  *)
    echo "Unsupported or unknown distribution: $ID"
    echo "Please install Yakuake manually."
    exit 1
    ;;
  esac

  echo "Yakuake installed successfully via package manager."
}

# Detect distro ID from /etc/os-release
if [[ -f /etc/os-release ]]; then
  source /etc/os-release
else
  echo "/etc/os-release not found. Cannot detect distribution."
  exit 1
fi

# Try Flatpak install first if flatpak exists
if command -v flatpak >/dev/null 2>&1; then
  install_yakuake_via_flatpak
fi

# Otherwise fallback to package manager install
install_yakuake_via_package_manager
