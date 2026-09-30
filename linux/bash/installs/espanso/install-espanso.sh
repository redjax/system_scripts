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

    trap 'rm -rf "$tmp_dir"' EXIT

    echo "Downloading Espanso"
    curl --fail --location "$espanso_url" -o "$tmp_dir/espanso.zip"

    unzip "$tmp_dir/espanso.zip" -d "$tmp_dir"

    sudo mv "$tmp_dir/espanso" /usr/local/bin/espanso
    sudo chmod +x /usr/local/bin/espanso

    trap - EXIT
    rm -rf "$tmp_dir"
  fi

  echo "Registering Espanso for accessibility permissions"
  espanso register

  echo "Espanso installed: $(command -v espanso)"
  espanso --version

  echo "Run:"
  echo "  espanso service start"
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

  trap 'rm -rf "$tmp_dir"' EXIT

  echo "Downloading $package_name"
  curl --fail --location "$download_url" -o "$tmp_dir/espanso.deb"

  sudo apt install -y "$tmp_dir/espanso.deb"

  trap - EXIT
  rm -rf "$tmp_dir"

  echo "Espanso installed: $(command -v espanso)"
  espanso --version

  echo "Run:"
  echo "  espanso service register"
  echo "  espanso service start"
}


install_espanso_fedora() {
  echo "Installing Espanso on Fedora-based system using Terra RPM repo"

  ## Configure Terra if it isn't already configured.
  if compgen -G "/etc/yum.repos.d/terra*.repo" > /dev/null; then
    echo "Terra repository already configured."
  else
    echo "Adding Terra repository"
    sudo dnf install \
      --nogpgcheck \
      --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
      terra-release
  fi

  ## Select the package matching the current display server.
  local package_name="espanso-x11"

  if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    package_name="espanso-wayland"
  fi

  echo "Using package: $package_name"

  ## Install/update the package.
  sudo dnf install -y "$package_name"

  ## Make sure the package actually owns the executable we expect.
  if ! rpm -q "$package_name" > /dev/null 2>&1; then
    echo "ERROR: $package_name is not installed."
    exit 1
  fi

  if [[ ! -x "/usr/bin/espanso" ]]; then
    echo "ERROR: $package_name is installed but /usr/bin/espanso is missing."
    exit 1
  fi

  ## Make sure the shell isn't resolving Espanso to some stale/manual copy.
  local espanso_path
  espanso_path="$(command -v espanso || true)"

  if [[ "$espanso_path" != "/usr/bin/espanso" ]]; then
    echo "WARNING: shell resolves espanso to:"
    echo "  ${espanso_path:-<not found>}"
    echo
    echo "Expected:"
    echo "  /usr/bin/espanso"
    echo
    echo "Check your PATH or shell aliases."
  fi

  echo
  echo "Espanso installed:"
  echo "  Package:  $(rpm -q "$package_name")"
  echo "  Binary:   /usr/bin/espanso"

  local binary_version
  binary_version="$(/usr/bin/espanso --version 2>/dev/null || true)"

  if [[ -n "$binary_version" ]]; then
    echo "  Version:  $binary_version"
  else
    echo "  Version:  unable to determine"
  fi

  echo
  echo "Run:"
  echo "  espanso service register"
  echo "  espanso service start"
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

  trap 'rm -rf "$tmp_dir"' EXIT

  echo "Downloading $appimage"
  curl --fail --location "$download_url" -o "$tmp_dir/espanso.AppImage"

  chmod +x "$tmp_dir/espanso.AppImage"
  sudo mv "$tmp_dir/espanso.AppImage" /usr/local/bin/espanso

  trap - EXIT
  rm -rf "$tmp_dir"

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

  echo "Espanso installed: $(command -v espanso)"
  espanso --version

  echo "Run:"
  echo "  espanso service register"
  echo "  espanso service start"
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
