#!/usr/bin/env bash

set -uo pipefail

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

# Download and install Zed manually for Linux/macOS
install_via_download() {
  local tmpdir=$(mktemp -d)
  echo "Downloading Zed to temporary directory: $tmpdir"

  local arch platform_url=""
  local platform="$(cpu_platform)"
  local distro="$(get_distro)"

  # Determine architecture for download
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

  # Determine the download URL - using the official Zed install.sh script for most cases
  # For macOS (Darwin), use the install script as well
  if [[ "$distro" == "Darwin" ]]; then
    echo "Detected macOS - installing via official install script."
    curl -f https://zed.dev/install.sh | sh
    return
  fi

  # For Linux, fallback to manual download for unsupported distros or architectures
  # If you want to customize the URL based on arch, adjust below
  local url="https://download.zed.dev/zed-linux-${arch}.tar.gz"

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

main() {
  echo "Detecting system"
  local distro=$(get_distro)
  local platform=$(cpu_platform)

  echo "Detected OS/Distro: $distro"
  echo "Detected CPU platform: $platform"

  if is_flatpak_installed; then
    install_via_flatpak
  else
    install_via_download
  fi
}

main
