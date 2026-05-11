#!/usr/bin/env bash

set -euo pipefail

OS_TYPE="$(uname -s)"
ARCH="$(uname -m)"
XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-}"

echo "Detected OS: $OS_TYPE"
echo "Detected ARCH: $ARCH"
echo "XDG_SESSION_TYPE: $XDG_SESSION_TYPE"

install_espanso_mac() {
  echo "Installing Espanso on macOS"
  if command -v brew >/dev/null 2>&1; then
    echo "Using Homebrew to install"
    brew tap federico-terzi/espanso
    brew install espanso
  else
    echo "Homebrew not found. Installing manually"
    ESPANSO_URL="https://github.com/espanso/espanso/releases/latest/download/espanso-macos.zip"
    TMP_DIR=$(mktemp -d)
    curl -L "$ESPANSO_URL" -o "$TMP_DIR/espanso.zip"
    unzip "$TMP_DIR/espanso.zip" -d "$TMP_DIR"
    sudo mv "$TMP_DIR/espanso" /usr/local/bin/espanso
    chmod +x /usr/local/bin/espanso
    rm -rf "$TMP_DIR"
  fi
  echo "Registering Espanso for accessibility permissions"
  espanso register
  echo "Installation complete. Run: espanso start"
}

install_espanso_debian() {
  echo "Installing Espanso on Debian/Ubuntu based system"

  # Determine package postfix for X11 or Wayland and arch
  local arch_part=""
  case "$ARCH" in
    x86_64) arch_part="amd64" ;;
    aarch64) arch_part="arm64" ;;
    *)
      echo "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  local session_part="x11"
  if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    session_part="wayland"
  fi

  PACKAGE_NAME="espanso-debian-${session_part}-${arch_part}.deb"
  DOWNLOAD_URL="https://github.com/espanso/espanso/releases/latest/download/${PACKAGE_NAME}"

  TMP_DIR=$(mktemp -d)
  echo "Downloading $PACKAGE_NAME from $DOWNLOAD_URL"
  curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/espanso.deb"
  sudo apt install -y "$TMP_DIR/espanso.deb"
  rm -rf "$TMP_DIR"

  echo "Espanso installed. You can now register and start the service:"
  echo "  espanso service register"
  echo "  espanso start"
}

install_espanso_fedora() {
  echo "Installing Espanso on Fedora-based system using Terra RPM repo..."

  # Check for existing Terra repo files to avoid duplicates
  if ls /etc/yum.repos.d/terra*.repo >/dev/null 2>&1; then
    echo "Terra repository already configured, skipping add."
  else
    echo "Adding Terra repo and installing terra-release package..."
    sudo dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
  fi

  # Check if espanso package is installed; install if missing
  if ! rpm -q espanso-wayland &>/dev/null && ! rpm -q espanso-x11 &>/dev/null; then
    echo "Installing Espanso package..."
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
      sudo dnf install -y espanso-wayland
    else
      sudo dnf install -y espanso-x11
    fi
  else
    echo "Espanso package already installed, skipping installation."
  fi

  echo "Espanso installed. Register and start with:"
  echo "  espanso service register"
  echo "  espanso start"
}

install_espanso_appimage() {
  echo "Installing Espanso AppImage fallback"

  local arch_part=""
  case "$ARCH" in
    x86_64) arch_part="x86_64" ;;
    aarch64) arch_part="arm64" ;;
    *)
      echo "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  local session_part="x11"
  if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    session_part="wayland"
  fi

  APPIMAGE="espanso-${session_part}-${arch_part}.AppImage"
  DOWNLOAD_URL="https://github.com/espanso/espanso/releases/latest/download/$APPIMAGE"

  TMP_DIR=$(mktemp -d)
  curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/espanso.AppImage"
  chmod +x "$TMP_DIR/espanso.AppImage"
  sudo mv "$TMP_DIR/espanso.AppImage" /usr/local/bin/espanso
  rm -rf "$TMP_DIR"

  echo "Espanso AppImage installed at /usr/local/bin/espanso"

  # Create desktop entry for start menu integration
  DESKTOP_DIR="$HOME/.local/share/applications"
  mkdir -p "$DESKTOP_DIR"
  ICON_PATH="/usr/share/icons/hicolor/256x256/apps/espanso.png"

  cat > "$DESKTOP_DIR/espanso.desktop" <<EOF
[Desktop Entry]
Name=Espanso
Comment=Text expander tool
Exec=/usr/local/bin/espanso
Icon=$ICON_PATH
Terminal=false
Type=Application
Categories=Utility;
EOF

  echo "Created desktop entry at $DESKTOP_DIR/espanso.desktop"
  echo "Run 'espanso start' to begin"
}


case "$OS_TYPE" in
  Darwin)
    install_espanso_mac
    ;;
  Linux)
    if command -v apt >/dev/null 2>&1; then
      install_espanso_debian
    elif command -v dnf >/dev/null 2>&1; then
      install_espanso_fedora
    else
      install_espanso_appimage
    fi
    ;;
  *)
    echo "Unsupported OS: $OS_TYPE"
    exit 1
    ;;
esac
