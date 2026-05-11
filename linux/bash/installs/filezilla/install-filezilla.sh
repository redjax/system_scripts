#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"
case "$OS" in
  Linux*) DISTRO="$(grep '^ID=' /etc/os-release 2>/dev/null || echo unknown | cut -d'=' -f2 | tr -d '\"')" ;;
  Darwin*) DISTRO="macos" ;;
  *) DISTRO="unknown" ;;
esac

install_via_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    return 1
  fi

  if ! flatpak remotes | grep -q "flathub"; then
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  sudo flatpak install -y org.filezillaproject.Filezilla
}

install_via_pkg_manager() {
  case "$DISTRO" in
    ubuntu|debian|linuxmint|pop|raspbian)
      sudo apt update
      sudo apt install -y filezilla
      ;;
    fedora|rhel|centos|almalinux|rocky)
      sudo dnf install -y filezilla
      ;;
    opensuse)
      sudo zypper install -y filezilla
      ;;
    arch)
      sudo pacman -Syu --noconfirm
      sudo pacman -S --noconfirm filezilla
      ;;
    macos)
      if command -v brew >/dev/null 2>&1; then
        brew install --cask filezilla
      else
        return 1
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

if install_via_flatpak 2>/dev/null; then
  exit 0
fi

install_via_pkg_manager
