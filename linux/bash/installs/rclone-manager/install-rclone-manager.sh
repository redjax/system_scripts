#!/usr/bin/env bash
set -o pipefail

REPO="Zarestia-Dev/rclone-manager"
FLATPAK_ID="io.github.zarestia_dev.rclone-manager"

function exists() {
  command -v "$1" >/dev/null 2>&1
}

function detect_distro() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

function install_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    return 1
  fi

  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

  if ! flatpak install -y flathub "$FLATPAK_ID"; then
    return 1
  fi

  echo "Creating rclone-manager Flatpak overrides"
  sudo flatpak override "$FLATPAK_ID" \
    --filesystem=home \
    --filesystem=xdg-documents \
    --filesystem=xdg-download \
    --filesystem=/run/media \
    --share=network

  return 0
}

function install_aur() {
  if ! exists pacman; then
    return 1
  fi

  if exists yay; then
    if yay -S --noconfirm rclone-manager; then
      return 0
    fi
  fi

  if exists paru; then
    if paru -S --noconfirm rclone-manager; then
      return 0
    fi
  fi

  return 1
}

function install_appimage() {
  local arch tmp url

  arch=$(uname -m)

  case "$arch" in
  x86_64) arch="x86_64" ;;
  aarch64 | arm64) arch="arm64" ;;
  *) return 1 ;;
  esac

  tmp=$(mktemp -d)
  cd "$tmp" || return 1

  url=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" |
    grep browser_download_url |
    grep -i appimage |
    grep -i linux |
    grep "$arch" |
    head -n 1 |
    cut -d '"' -f4)

  if [[ -z "$url" ]]; then
    return 1
  fi

  if ! curl -L "$url" -o rclone-manager.AppImage; then
    return 1
  fi

  chmod +x rclone-manager.AppImage
  sudo mv rclone-manager.AppImage /usr/local/bin/rclone-manager

  return 0
}

echo "Installing RClone Manager"
echo ""

DISTRO=$(detect_distro)
echo "Detected distribution: $DISTRO"
echo ""

if [[ "$DISTRO" == "arch" || "$DISTRO" == "manjaro" || "$DISTRO" == "endeavouros" ]]; then
  if install_aur; then exit 0; fi
  if install_flatpak; then exit 0; fi
  if install_appimage; then exit 0; fi
else
  if install_flatpak; then exit 0; fi
  if install_appimage; then exit 0; fi
fi

echo "All installation methods failed"
exit 1
