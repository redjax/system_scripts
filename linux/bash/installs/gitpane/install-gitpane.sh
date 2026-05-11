#!/usr/bin/env bash
set -euo pipefail

REPO="affromero/gitpane"
INSTALL_DIR="${HOME}/.local/bin"

function require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

require curl
require tar
require uname

## Detect architecture
ARCH="$(uname -m)"

case "$ARCH" in
x86_64)
  ARCH="x86_64"
  ;;
aarch64 | arm64)
  ARCH="aarch64"
  ;;
*)
  echo "Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

## Detect libc (glibc vs musl)
if ldd --version 2>&1 | grep -qi musl; then
  LIBC="musl"
else
  LIBC="gnu"
fi

TARGET="${ARCH}-unknown-linux-${LIBC}"

echo "Detected target: $TARGET"

## Fetch releases and get newest tag
RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases")"

TAG="$(printf '%s\n' "$RELEASE_JSON" |
  grep '"tag_name":' |
  head -n1 |
  sed -E 's/.*"([^"]+)".*/\1/')"

if [[ -z "$TAG" ]]; then
  echo "Failed to determine latest release tag"
  exit 1
fi

echo "Latest release tag: $TAG"

ASSET="gitpane-${TARGET}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"

echo "Downloading: $DOWNLOAD_URL"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fL "$DOWNLOAD_URL" -o "$TMP_DIR/gitpane.tar.gz"

tar -xzf "$TMP_DIR/gitpane.tar.gz" -C "$TMP_DIR"

BIN_PATH="$(find "$TMP_DIR" -type f -name gitpane | head -n1)"

if [[ -z "$BIN_PATH" ]]; then
  echo "gitpane binary not found in archive"
  exit 1
fi

chmod +x "$BIN_PATH"

mkdir -p "$INSTALL_DIR"

cp "$BIN_PATH" "$INSTALL_DIR/gitpane"

echo
echo "Installed gitpane to:"
echo "  $INSTALL_DIR/gitpane"

# Ensure ~/.local/bin is on PATH
case ":$PATH:" in
*":$INSTALL_DIR:"*)
  ;;
*)
  echo
  echo "WARNING: $INSTALL_DIR is not in your PATH."
  echo
  echo "Add this to your shell config:"
  echo
  echo 'export PATH="$HOME/.local/bin:$PATH"'
  ;;
esac

