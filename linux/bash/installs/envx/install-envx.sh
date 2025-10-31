#!/usr/bin/env bash
set -uo pipefail

TMP_DIR="$(mktemp -d)"
REPO="mikeleppane/envx"
BIN="envx"
INSTALL_DIR="/usr/local/bin"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Detect platform
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
x86_64) ARCH="amd64" ;;
aarch64 | arm64) ARCH="arm64" ;;
*)
  echo "Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

if [[ "$OS" == "darwin" ]]; then
  PLATFORM="macos"
elif [[ "$OS" == "linux" ]]; then
  PLATFORM="linux"
elif [[ "$OS" == "windows" ]]; then
  PLATFORM="windows"
else
  echo "Unsupported OS: $OS"
  exit 1
fi

# Get latest release tag
LATEST_TAG="$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')"

# Set correct release asset name
FILE="${BIN}-${PLATFORM}-${ARCH}"
if [[ "$PLATFORM" == "windows" ]]; then
  FILE="${FILE}.exe"
fi

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${FILE}"

echo "Downloading $DOWNLOAD_URL"
curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/$FILE"

echo "Installing to $INSTALL_DIR/$BIN"
if [[ "$PLATFORM" == "windows" ]]; then
  cp "$TMP_DIR/$FILE" "$INSTALL_DIR/${BIN}.exe"
else
  chmod +x "$TMP_DIR/$FILE"
  sudo cp "$TMP_DIR/$FILE" "$INSTALL_DIR/$BIN"
fi

echo "Installed $BIN version $LATEST_TAG to $INSTALL_DIR"
