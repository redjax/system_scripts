#!/usr/bin/env bash

set -euo pipefail

REPO="jj-vcs/jj"
INSTALL_DIR="/usr/local/bin"

function require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command '$1' not found"
    exit 1
  }
}

require curl
require tar

## Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
Darwin)
  PLATFORM="apple-darwin"
  ;;
Linux)
  PLATFORM="unknown-linux-musl"
  ;;
*)
  echo "Unsupported OS: $OS"
  exit 1
  ;;
esac

case "$ARCH" in
x86_64 | amd64)
  ARCH="x86_64"
  ;;
arm64 | aarch64)
  ARCH="aarch64"
  ;;
*)
  echo "Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

echo "Detected platform: ${ARCH}-${PLATFORM}"

## Get latest jj tag from Github
LATEST_TAG="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" |
  grep '"tag_name":' |
  sed -E 's/.*"([^"]+)".*/\1/')"

if [[ -z "$LATEST_TAG" ]]; then
  echo "Failed to determine latest release"
  exit 1
fi

echo "Latest release: $LATEST_TAG"

FILENAME="jj-${LATEST_TAG}-${ARCH}-${PLATFORM}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${FILENAME}"

TMP_DIR="$(mktemp -d)"
ARCHIVE_PATH="${TMP_DIR}/${FILENAME}"

echo "Downloading:"
echo "  $DOWNLOAD_URL"

curl -fL "$DOWNLOAD_URL" -o "$ARCHIVE_PATH"

echo "Extracting"
tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"

JJ_BIN="$(find "$TMP_DIR" -type f -name jj | head -n 1)"

if [[ ! -f "$JJ_BIN" ]]; then
  echo "Failed to locate jj binary after extraction"
  exit 1
fi

echo "Installing to ${INSTALL_DIR}"

if [[ -w "$INSTALL_DIR" ]]; then
  install -m 755 "$JJ_BIN" "${INSTALL_DIR}/jj"
else
  sudo install -m 755 "$JJ_BIN" "${INSTALL_DIR}/jj"
fi

echo "Installed successfully!"
echo
jj --version
