#!/usr/bin/env bash
set -uo pipefail

TMP_DIR="$(mktemp -d)"
REPO="tokuhirom/dcv"
BIN="dcv"
INSTALL_DIR="/usr/local/bin"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# OS/platform detection
OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Normalize architecture for DCV releases
case "$ARCH" in
x86_64) ARCH="amd64" ;;
aarch64 | arm64) ARCH="arm64" ;;
armv7l) ARCH="armv7" ;;
*)
  echo "Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

if [[ "$OS" == "darwin" ]]; then
  PLATFORM="darwin"
elif [[ "$OS" == "linux" ]]; then
  PLATFORM="linux"
elif [[ "$OS" == "msys" || "$OS" == "mingw"* || "$OS" == "cygwin"* || "$OS" == "windowsnt" ]]; then
  PLATFORM="windows"
else
  echo "Unsupported OS: $OS"
  exit 1
fi

# Get latest release tag from GitHub
LATEST_TAG="$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"

# Set correct asset name
if [[ "$PLATFORM" == "windows" ]]; then
  FILE="${BIN}_${PLATFORM}_amd64.tar.gz"
else
  FILE="${BIN}_${PLATFORM}_${ARCH}.tar.gz"
fi

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${FILE}"

echo "Downloading $DOWNLOAD_URL"
curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/$FILE"

echo "Extracting"
tar -xzf "$TMP_DIR/$FILE" -C "$TMP_DIR"

echo "Installing $BIN"
chmod +x "$TMP_DIR/$BIN"
sudo mv "$TMP_DIR/$BIN" "$INSTALL_DIR/$BIN"

echo "$BIN installed to $INSTALL_DIR/$BIN (version $LATEST_TAG)"
