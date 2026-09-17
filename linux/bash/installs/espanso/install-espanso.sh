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

  if command -v brew > /dev/null 2>&1; then
    echo "Using Homebrew to install"
    brew tap federico-terzi/espanso
    brew install espanso
  else
    echo "Homebrew not found. Installing manually"

    local espanso_url="https://github.com/espanso/espanso/releases/latest/download/espanso-macos.zip"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN

    echo "Downloading Espanso..."
    curl --fail --location "$espanso_url" -o "$tmp_dir/espanso.zip"

    unzip "$tmp_dir/espanso.zip" -d "$tmp_dir"

    sudo mv "$tmp_dir/espanso" /usr/local/bin/espanso
    sudo chmod +x /usr/local/bin/espanso
  fi

  echo "Registering Espanso for accessibility permissions"
  espanso register

  echo "Installation complete. Run: espanso start"
}

install_espanso_debian() {
  echo "Installing Espanso on Debian/Ubuntu based system"

  local arch_part=""
  case "$ARCH" in
    x86_64)
      arch_part="amd64"
      ;;
    aarch64)
      arch_part="arm64"
      ;;
    *)
      echo "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  local session_part="x11"
  if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    session_part="wayland"
  fi

  local package_name="espanso-debian-${session_part}-${arch_part}.deb"
  local download_url="https://github.com/espanso/espanso/releases/latest/download/${package_name}"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  echo "Downloading $package_name from $download_url"
  curl --fail --location "$download_url" -o "$tmp_dir/espanso.deb"

  sudo apt install -y "$tmp_dir/espanso.deb"

  echo "Espanso installed. You can now register and start the service:"
  echo "  espanso service register"
  echo "  espanso start"
}

install_espanso_fedora() {
  echo "Installing Espanso on Fedora-based system using Terra RPM repo..."

  ## Check for existing Terra repo files to avoid duplicates.
  if ls /etc/yum.repos.d/terra*.repo > /dev/null 2>&1; then
    echo "Terra repository already configured, skipping add."
  else
    echo "Adding Terra repo and installing terra-release package..."
    sudo dnf install \
      --nogpgcheck \
      --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
      terra-release
  fi

  ## Select the package that matches the current display server.
  local package_name="espanso-x11"

  if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    package_name="espanso-wayland"
  fi

  echo "Selected package: $package_name"

  ## Check whether the correct RPM is installed, and whether the executable
  #  that package provides actually exists.
  #
  #  This prevents a broken RPM installation from being treated as healthy
  #  if /usr/bin/espanso was manually removed or otherwise disappeared.
  if rpm -q "$package_name" > /dev/null 2>&1 && [[ -x "/usr/bin/espanso" ]]; then
    echo "$package_name is installed and /usr/bin/espanso exists."
    echo "Skipping installation."
  else
    if rpm -q "$package_name" > /dev/null 2>&1; then
      echo "$package_name is installed, but /usr/bin/espanso is missing or not executable."
      echo "Reinstalling $package_name..."
      sudo dnf reinstall -y "$package_name"
    else
      echo "$package_name is not installed."
      echo "Installing $package_name..."
      sudo dnf install -y "$package_name"
    fi
  fi

  ## Final sanity check.
  if [[ ! -x "/usr/bin/espanso" ]]; then
    echo "ERROR: Espanso installation completed but /usr/bin/espanso is missing."
    exit 1
  fi

  echo "Espanso installed successfully:"
  /usr/bin/espanso --version

  echo "Register and start with:"
  echo "  espanso service register"
  echo "  espanso start"
}

install_espanso_appimage() {
  echo "Installing Espanso AppImage fallback"

  local arch_part=""
  case "$ARCH" in
    x86_64)
      arch_part="x86_64"
      ;;
    aarch64)
      arch_part="arm64"
      ;;
    *)
      echo "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  local session_part="x11"
  if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    session_part="wayland"
  fi

  local appimage="espanso-${session_part}-${arch_part}.AppImage"
  local download_url="https://github.com/espanso/espanso/releases/latest/download/$appimage"

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  echo "Downloading $appimage from $download_url"
  curl --fail --location "$download_url" -o "$tmp_dir/espanso.AppImage"

  chmod +x "$tmp_dir/espanso.AppImage"
  sudo mv "$tmp_dir/espanso.AppImage" /usr/local/bin/espanso

  echo "Espanso installed at /usr/local/bin/espanso"

  ## Create desktop entry for start menu integration.
  local desktop_dir="$HOME/.local/share/applications"
  local icon_path="/usr/share/icons/hicolor/256x256/apps/espanso.png"

  mkdir -p "$desktop_dir"

  cat > "$desktop_dir/espanso.desktop" << EOF
[Desktop Entry]
Name=Espanso
Comment=Text expander tool
Exec=/usr/local/bin/espanso
Icon=$icon_path
Terminal=false
Type=Application
Categories=Utility;
EOF

  echo "Created desktop entry at $desktop_dir/espanso.desktop"
  echo "Run 'espanso start' to begin"
}

case "$OS_TYPE" in
  Darwin)
    install_espanso_mac
    ;;
  Linux)
    if command -v apt > /dev/null 2>&1; then
      install_espanso_debian
    elif command -v dnf > /dev/null 2>&1; then
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
