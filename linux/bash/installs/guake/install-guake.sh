#!/usr/bin/env bash

set -e

install_guake_via_flatpak() {
  echo "Trying to install Guake via Flatpak..."
  if command -v flatpak >/dev/null 2>&1; then
    flatpak install -y flathub org.guake.Guake && echo "Guake installed with Flatpak." && exit 0
  else
    echo "Flatpak is not installed or not available."
  fi
}

install_guake_via_package_manager() {
  echo "Attempting distro-specific package manager install for Guake..."
  if [[ $EUID -ne 0 ]]; then
    SUDO='sudo'
  else
    SUDO=''
  fi

  case "$ID" in
  ubuntu | debian | raspbian)
    $SUDO apt update
    $SUDO apt install -y guake
    ;;
  fedora)
    $SUDO dnf install -y guake
    ;;
  arch | manjaro)
    $SUDO pacman -Sy --noconfirm guake
    ;;
  opensuse* | suse)
    $SUDO zypper install -y guake
    ;;
  *)
    echo "Unsupported or unknown distribution: $ID"
    echo "Please install Guake manually."
    exit 1
    ;;
  esac

  echo "Guake installed successfully via package manager."
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
  install_guake_via_flatpak
fi

install_guake_via_package_manager
