#!/usr/bin/env bash
set -euo pipefail

for cmd in git cmake; do
  if ! command -v "$cmd" >&/dev/null; then
    echo "[ERROR] $cmd is not installed" >&2
    exit 1
  fi
done

FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  -f | --force)
    FORCE=1
    shift
    ;;
  *)
    echo "Unknown option: $1"
    exit 1
    ;;
  esac
done

echo "Detecting Linux distribution"

if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
else
  echo "[ERROR] Cannot detect distribution (missing /etc/os-release)" >&2
  exit 1
fi

echo "Detected: $DISTRO"

function detect_pkg_manager() {
  if command -v apt >/dev/null; then
    PKG_MANAGER="apt"
  elif command -v dnf >/dev/null; then
    PKG_MANAGER="dnf"
  elif command -v pacman >/dev/null; then
    PKG_MANAGER="pacman"
  elif command -v zypper >/dev/null; then
    PKG_MANAGER="zypper"
  elif command -v apk >/dev/null; then
    PKG_MANAGER="apk"
  else
    PKG_MANAGER="unknown"
  fi

  echo "Using package manager: $PKG_MANAGER"
}

function install_build_deps() {
  case "$PKG_MANAGER" in
  apt)
    sudo apt update
    sudo apt install -y git cmake ninja-build pkg-config libgtk-4-dev
    ;;
  dnf)
    sudo dnf install -y git cmake ninja-build gtk4-devel
    ;;
  pacman)
    sudo pacman -Sy --noconfirm git cmake ninja base-devel
    ;;
  zypper)
    sudo zypper install -y git cmake ninja gtk4-devel
    ;;
  apk)
    sudo apk add git cmake ninja build-base gtk4-dev
    ;;
  *)
    echo "Unsupported package manager. Please install dependencies manually." >&2
    exit 1
    ;;
  esac
}

function build_from_source() {
  echo "Building Ghostty from source"

  detect_pkg_manager
  install_build_deps

  TMP_DIR=$(mktemp -d)
  echo "Using temp dir: $TMP_DIR"

  cleanup() {
    echo "Cleaning up"
    rm -rf "$TMP_DIR"
  }
  trap cleanup EXIT

  git clone https://github.com/ghostty-org/ghostty.git "$TMP_DIR/ghostty"
  cd "$TMP_DIR/ghostty"

  cmake -B build
  cmake --build build
  sudo cmake --install build
}

function install_ghostty_debian() {
  echo "Installing Ghostty on Debian/Ubuntu"
  sudo apt update

  if apt-cache search ghostty | grep -q ghostty; then
    sudo apt install -y ghostty
  else
    echo "Ghostty not found in apt repos."
    build_from_source
  fi
}

function install_ghostty_fedora() {
  echo "Installing Ghostty on Fedora/RHEL"
  sudo dnf install -y ghostty || {
    echo "Ghostty not in repos."
    build_from_source
  }
}

function install_ghostty_arch() {
  echo "Installing Ghostty on Arch Linux"
  sudo pacman -Sy --noconfirm ghostty || {
    echo "Installing from AUR"
    if ! command -v yay >/dev/null; then
      sudo pacman -S --needed --noconfirm base-devel git
      TMP_DIR=$(mktemp -d)
      git clone https://aur.archlinux.org/yay.git "$TMP_DIR/yay"
      cd "$TMP_DIR/yay"
      makepkg -si --noconfirm
    fi
    yay -S --noconfirm ghostty
  }
}

function install_ghostty_alpine() {
  echo "Installing Ghostty on Alpine"
  sudo apk add ghostty || {
    echo "Ghostty not available."
    build_from_source
  }
}

function install_ghostty_opensuse() {
  echo "Installing Ghostty on openSUSE"
  sudo zypper install -y ghostty || {
    echo "Ghostty not available."
    build_from_source
  }
}

function install_ghostty_themes() {
  echo "Installing Ghostty themes (iTerm2 Color Schemes)..."

  THEME_DIR="$HOME/.config/ghostty/themes"
  mkdir -p "$THEME_DIR"

  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' RETURN

  git clone --depth 1 \
    https://github.com/mbadolato/iTerm2-Color-Schemes.git \
    "$TMP_DIR/schemes"

  if [ ! -d "$TMP_DIR/schemes/ghostty" ]; then
    echo "[ERROR] Ghostty theme export folder not found in repository."
    exit 1
  fi

  cp -f "$TMP_DIR/schemes/ghostty/"* "$THEME_DIR/"

  echo "Themes installed to: $THEME_DIR"
}

function prompt_install_themes() {
  if [ "$FORCE" -eq 1 ]; then
    install_ghostty_themes
    return
  fi

  echo
  read -rp "Install Ghostty themes (iTerm2 color schemes)? [Y/n] " choice

  case "$choice" in
  n | N)
    echo "Skipping theme installation."
    ;;
  *)
    install_ghostty_themes
    ;;
  esac
}

case "$DISTRO" in
ubuntu | debian)
  install_ghostty_debian
  ;;
fedora | rhel | centos | rocky)
  install_ghostty_fedora
  ;;
arch)
  install_ghostty_arch
  ;;
alpine)
  install_ghostty_alpine
  ;;
opensuse* | suse)
  install_ghostty_opensuse
  ;;
*)
  echo "Unknown or unsupported distro: $DISTRO"
  build_from_source
  ;;
esac

if [[ "$FORCE" == 0 ]]; then
  install_ghostty_themes
else
  prompt_install_themes
fi

echo "Done."

