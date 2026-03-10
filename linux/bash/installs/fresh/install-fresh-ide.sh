#!/usr/bin/env bash

set -euo pipefail

## Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

function detect_linux_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

function install_fresh_brew() {
  if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew is not installed. Install it from https://brew.sh"
    exit 1
  fi

  brew tap sinelaw/fresh
  brew install fresh-editor
}

function install_fresh_arch() {
  if command -v yay &>/dev/null; then
    yay -S fresh-editor-bin
  elif command -v paru &>/dev/null; then
    paru -S fresh-editor-bin
  else
    echo "Installing fresh-editor from AUR manually"
    local tmpdir
    tmpdir="$(mktemp -d)"
    git clone https://aur.archlinux.org/fresh-editor-bin.git "$tmpdir/fresh-editor-bin"
    cd "$tmpdir/fresh-editor-bin"
    makepkg --syncdeps --install
    cd -
    rm -rf "$tmpdir"
  fi
}

function install_fresh_deb() {
  echo "Downloading latest .deb package"

  local deb_url

  deb_url="$(curl -s https://api.github.com/repos/sinelaw/fresh/releases/latest \
    | grep "browser_download_url.*_$(dpkg --print-architecture)\.deb" \
    | cut -d '"' -f 4)"

  if [ -z "$deb_url" ]; then
    echo "Error: Could not find .deb download URL for architecture $(dpkg --print-architecture)"
    exit 1
  fi

  local tmpfile
  tmpfile="$(mktemp --suffix=.deb)"

  curl -sL "$deb_url" -o "$tmpfile"
  sudo dpkg -i "$tmpfile"
  rm -f "$tmpfile"
}

function install_fresh_rpm() {
  echo "Downloading latest .rpm package"

  local rpm_url

  rpm_url="$(curl -s https://api.github.com/repos/sinelaw/fresh/releases/latest \
    | grep "browser_download_url.*\.$(uname -m)\.rpm" \
    | cut -d '"' -f 4)"

  if [ -z "$rpm_url" ]; then
    echo "Error: Could not find .rpm download URL for architecture $(uname -m)"
    exit 1
  fi

  local tmpfile
  tmpfile="$(mktemp --suffix=.rpm)"

  curl -sL "$rpm_url" -o "$tmpfile"
  sudo rpm -U "$tmpfile"
  rm -f "$tmpfile"
}

function install_fresh_gentoo() {
  echo "Installing fresh-editor from GURU overlay"
  sudo emerge --ask app-editors/fresh
}

function install_fresh_binary() {
  echo "No native package method available. Installing from pre-built binary"

  local target=""
  case "$OS" in
    Linux)
      target="${ARCH}-unknown-linux-gnu"
      ;;
    Darwin)
      target="${ARCH}-apple-darwin"
      ;;
    *)
      echo "Error: Unsupported OS '$OS' for binary install."
      exit 1
      ;;
  esac

  ## Normalize arch name (x86_64 is already correct, arm64 -> aarch64)
  target="${target/arm64/aarch64}"

  local tarball="fresh-editor-${target}.tar.xz"
  local download_url
  download_url="$(curl -s https://api.github.com/repos/sinelaw/fresh/releases/latest \
    | grep "browser_download_url.*${target}\.tar\.xz\"" \
    | cut -d '"' -f 4)"

  if [ -z "$download_url" ]; then
    echo "Error: Could not find binary release for target '$target'"
    exit 1
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  echo "Downloading $download_url "
  curl -sL "$download_url" -o "$tmpdir/$tarball"

  echo "Extracting"
  tar -xf "$tmpdir/$tarball" -C "$tmpdir"

  ## Install binary to ~/.local/bin
  mkdir -p ~/.local/bin
  local fresh_bin
  fresh_bin="$(find "$tmpdir" -name 'fresh' -type f -executable | head -n 1)"

  if [ -z "$fresh_bin" ]; then
    ## Try without executable bit (tar might not preserve it)
    fresh_bin="$(find "$tmpdir" -name 'fresh' -type f | head -n 1)"
  fi

  if [ -z "$fresh_bin" ]; then
    echo "Error: Could not find 'fresh' binary in extracted archive."
    rm -rf "$tmpdir"
    exit 1
  fi

  cp "$fresh_bin" ~/.local/bin/fresh
  chmod +x ~/.local/bin/fresh
  rm -rf "$tmpdir"

  echo "Installed fresh to ~/.local/bin/fresh"
  if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo "Warning: ~/.local/bin is not in your PATH. Add it to your shell profile."
  fi
}

echo "Installing Fresh terminal IDE"
echo "  OS: $OS ($ARCH)"

case "$OS" in
  Darwin)
    echo "  Method: Homebrew"
    install_fresh_brew
    ;;

  Linux)
    DISTRO="$(detect_linux_distro)"
    echo "  Distro: $DISTRO"

    case "$DISTRO" in
      ## Brew-based immutable distros
      bazzite|bluefin|aurora)
        echo "  Method: Homebrew"
        install_fresh_brew
        ;;

      ## Arch Linux and derivatives
      arch|endeavouros|manjaro)
        echo "  Method: AUR"
        install_fresh_arch
        ;;

      ## Debian/Ubuntu family
      debian|ubuntu|pop|linuxmint|elementary|zorin|kali)
        echo "  Method: .deb package"
        install_fresh_deb
        ;;

      ## RPM-based distros
      fedora|rhel|centos|rocky|alma|ol|opensuse*|sles)
        echo "  Method: .rpm package"
        install_fresh_rpm
        ;;

      ## Gentoo
      gentoo)
        echo "  Method: GURU overlay"
        install_fresh_gentoo
        ;;

      ## Anything else: fall back to pre-built binary
      *)
        echo "  Method: Pre-built binary (fallback)"
        install_fresh_binary
        ;;
    esac
    ;;

  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

if [[ $? -ne 0 ]]; then
  echo "Fresh installation failed."
  exit 1
fi

echo ""
echo "Fresh terminal IDE installed successfully."
