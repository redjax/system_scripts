#!/usr/bin/env bash
set -Eeuo pipefail

APPIMAGE_DIR="$HOME/.local/bin"
GITHUB_REPO="keepassxreboot/keepassxc"

function log() {
  echo "[INFO] $*"
}

function error() {
  echo "[ERROR] $*" >&2
}

function install_via_package_manager() {

  if command -v apt-get >/dev/null 2>&1; then
    log "Installing via apt"
    sudo apt-get update
    sudo apt-get install -y keepassxc
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    log "Installing via dnf"
    sudo dnf install -y keepassxc
    return 0
  fi

  if command -v yum >/dev/null 2>&1; then
    log "Installing via yum"
    sudo yum install -y keepassxc
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    log "Installing via pacman"
    sudo pacman -Sy --noconfirm keepassxc
    return 0
  fi

  if command -v zypper >/dev/null 2>&1; then
    log "Installing via zypper"
    sudo zypper --non-interactive install keepassxc
    return 0
  fi

  if command -v apk >/dev/null 2>&1; then
    log "Installing via apk"
    sudo apk add keepassxc
    return 0
  fi

  return 1

}

function install_via_flatpak() {

  command -v flatpak >/dev/null 2>&1 || return 1

  log "Installing via Flatpak"

  if ! flatpak remote-list | grep -q flathub; then
    flatpak remote-add --if-not-exists \
      flathub \
      https://flathub.org/repo/flathub.flatpakrepo
  fi

  flatpak install -y flathub org.keepassxc.KeePassXC

}

function install_via_github_release() {

  log "Attempting GitHub AppImage installation"

  command -v curl >/dev/null 2>&1 || {
    error "curl is required"
    return 1
  }

  mkdir -p "$APPIMAGE_DIR"

  RELEASE_JSON=$(curl -fsSL \
    "https://api.github.com/repos/${GITHUB_REPO}/releases/latest")

  APPIMAGE_URL=$(
    echo "$RELEASE_JSON" |
    grep browser_download_url |
    grep AppImage |
    grep x86_64 |
    head -n1 |
    cut -d '"' -f4
  )

  if [[ -z "$APPIMAGE_URL" ]]; then
    error "Could not locate AppImage release"
    return 1
  fi

  DEST="$APPIMAGE_DIR/keepassxc.AppImage"

  curl -L "$APPIMAGE_URL" -o "$DEST"

  chmod +x "$DEST"

  cat > "$HOME/.local/share/applications/keepassxc.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=KeePassXC
Exec=$DEST
Icon=keepassxc
Terminal=false
Categories=Utility;Security;
EOF

  log "Installed AppImage to: $DEST"
  log "Run with: $DEST"

}

function main() {

  log "Attempting package-manager installation"

  if install_via_package_manager; then
    log "KeePassXC installed successfully."
    exit 0
  fi

  log "Package manager installation unavailable."

  if install_via_flatpak; then
    log "KeePassXC installed successfully via Flatpak."
    exit 0
  fi

  log "Flatpak unavailable."

  if install_via_github_release; then
    log "KeePassXC installed successfully via AppImage."
    exit 0
  fi

  error "All installation methods failed."
  exit 1

}

main "$@"
