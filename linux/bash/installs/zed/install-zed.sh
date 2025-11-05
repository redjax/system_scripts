#!/usr/bin/env bash

set -uo pipefail

# Parse arguments
FORCE_FLATPAK=0
for arg in "$@"; do
  case "$arg" in
    --flatpak)
      FORCE_FLATPAK=1
      ;;
  esac
done

# Detect OS and distro
get_distro() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo $ID
  else
    uname
  fi
}

# Detect CPU platform
cpu_platform() {
  uname -m
}

# Check if flatpak is installed
is_flatpak_installed() {
  command -v flatpak >/dev/null 2>&1
}

# Install Zed using flatpak if available
install_via_flatpak() {
  echo "Installing Zed via Flatpak"
  flatpak install -y flathub dev.zed.Zed
}

# Download and install Zed manually
install_via_download() {
  local tmpdir
  tmpdir=$(mktemp -d)
  echo "Downloading Zed to temporary directory: $tmpdir"

  local arch platform_url=""
  local platform
  platform="$(cpu_platform)"
  local distro
  distro="$(get_distro)"

  case "$platform" in
    x86_64|amd64)
      arch="x86_64"
      ;;
    aarch64|arm64)
      arch="aarch64"
      ;;
    *)
      echo "Unsupported CPU platform: $platform"
      exit 1
      ;;
  esac

  if [[ "$distro" == "Darwin" ]]; then
    echo "Detected macOS - installing via official install script."
    curl -fsSL https://zed.dev/install.sh | sh
    return
  fi

  local url="https://zed.dev/api/releases/stable/latest/zed-linux-${arch}.tar.gz"

  echo "Downloading Zed tarball from $url"
  curl -fL "$url" -o "$tmpdir/zed.tar.gz"

  echo "Extracting Zed"
  mkdir -p ~/.local/zed.app/
  tar -xf "$tmpdir/zed.tar.gz" -C ~/.local/zed.app/

  echo "Creating symlink in ~/.local/bin"
  mkdir -p ~/.local/bin
  ln -sf ~/.local/zed.app/bin/zed ~/.local/bin/zed

  echo "Zed installed. You may want to add ~/.local/bin to your PATH if it's not already set."
}

create_desktop_entry() {
  local desktop_file=~/.local/share/applications/zed.desktop
  mkdir -p ~/.local/share/applications
  cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=Zed
Comment=Zed code editor
Exec=$HOME/.local/bin/zed %F
Icon=$HOME/.local/zed.app/share/icons/hicolor/256x256/apps/zed.png
Type=Application
Categories=Development;IDE;
StartupNotify=true
EOF

  echo "Created desktop entry at $desktop_file"
}

main() {
  echo "Detecting system"
  local distro
  distro=$(get_distro)
  local platform
  platform=$(cpu_platform)

  echo "Detected OS/Distro: $distro"
  echo "Detected CPU platform: $platform"

  if [[ "$FORCE_FLATPAK" -eq 1 ]]; then
    if is_flatpak_installed; then
      install_via_flatpak
    else
      echo "Error: --flatpak given but flatpak is not installed."
      exit 1
    fi
    return
  fi

  if is_flatpak_installed; then
    read -rp "Flatpak is installed. Use it to install Zed? (y/n): " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      install_via_flatpak
      return
    fi
  fi

  install_via_download

  create_desktop_entry
}

main "$@"
