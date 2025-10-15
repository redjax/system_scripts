#!/bin/bash

set -e

# Detect OS
OS=$(uname -s)
case "$OS" in
  Linux*)   OS=linux ;;
  Darwin*)  OS=macos ;;
  *)        echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

# Detect CPU Architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64) ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac

REPO="nathabonfim59/gitid"
API_URL="https://api.github.com/repos/$REPO/releases/latest"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching latest release info..."
# Get list of asset download URLs with their names from GitHub API output,
# then filter those matching OS and ARCH
ASSET_URL=$(curl -s "$API_URL" | \
  grep '"browser_download_url":' | \
  sed -E 's/.*"browser_download_url": "(.*)".*/\1/' | \
  grep -i "$OS" | grep -i "$ARCH" | head -n 1)

if [ -z "$ASSET_URL" ]; then
  echo "No suitable release asset found for OS=$OS and ARCH=$ARCH" >&2
  exit 1
fi

echo "Downloading $ASSET_URL ..."
cd "$TMPDIR"
curl -L -o asset "$ASSET_URL"

echo "Extracting binary..."
if [[ "$ASSET_URL" =~ \.tar\.gz$ ]]; then
  tar -xzf asset
elif [[ "$ASSET_URL" =~ \.zip$ ]]; then
  unzip -q asset
else
  echo "Unknown archive format, assuming binary..."
  mv asset gitid
  chmod +x gitid
fi

# Find gitid binary
if [ ! -x ./gitid ]; then
  FOUND_BINARY=$(find . -type f -name gitid -perm -u=x | head -n 1)
  if [ -z "$FOUND_BINARY" ]; then
    echo "gitid binary not found after extraction" >&2
    exit 1
  else
    mv "$FOUND_BINARY" ./gitid
  fi
fi

chmod +x ./gitid

# Choose install dir
BINDIR="/usr/local/bin"
if [ ! -w "$BINDIR" ]; then
  BINDIR="$HOME/.local/bin"
  mkdir -p "$BINDIR"
  echo "Using local bin directory: $BINDIR"
fi

echo "Installing gitid binary to $BINDIR"
mv ./gitid "$BINDIR/gitid"

echo "Installation complete. You can now run 'gitid'."

