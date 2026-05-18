#!/usr/bin/env bash
set -euo pipefail

REPO="gokcehan/lf"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

## Check dependencies
for cmd in curl tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
done

if ! command -v unzip >/dev/null 2>&1; then
  HAVE_UNZIP=0
else
  HAVE_UNZIP=1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching latest release" >&2
JSON="$(curl -fsSL "$API_URL")"

## Parse latest release tag name 
TAG="$(echo "$JSON" | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')"

if [[ -z "$TAG" ]]; then
  echo "Failed to parse latest version tag" >&2
  exit 1
fi

echo "Latest version: $TAG" >&2

## Detect OS/CPU arch
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l) ARCH="arm" ;;
  i386|i686) ARCH="386" ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

case "$OS" in
  linux|darwin|freebsd|openbsd|netbsd) ;;
  *)
    echo "Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

## Build asset name
EXT="tar.gz"
ASSET="lf-${OS}-${ARCH}.${EXT}"
URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET}"

## Download archive
echo "Downloading: $ASSET" >&2
curl -fL "$URL" -o "$TMPDIR/lf.$EXT"

cd "$TMPDIR"

## Extract archive
tar -xzf "lf.$EXT"

## Find binary
BIN="$(find . -type f -name lf | head -n 1)"

if [[ -z "$BIN" ]]; then
  echo "Could not find lf binary in archive" >&2
  exit 1
fi

## Install
INSTALL_DIR="/usr/local/bin"

if [[ ! -w "$INSTALL_DIR" ]]; then
  INSTALL_DIR="$HOME/.local/bin"
  mkdir -p "$INSTALL_DIR"
fi

install -m 755 "$BIN" "$INSTALL_DIR/lf"

echo "Installed lf to $INSTALL_DIR/lf"

