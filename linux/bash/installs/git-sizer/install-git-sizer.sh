#!/usr/bin/env bash

set -uo pipefail

REPO="github/git-sizer"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
TMP_DIR=$(mktemp -d)
INSTALL_DIR="/usr/local/bin"

# Determine OS and architecture
OS=$(uname | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
x86_64) ARCH="amd64" ;;
arm64 | aarch64) ARCH="arm64" ;;
i386 | i686) ARCH="386" ;;
*)
  echo "Unsupported architecture: $ARCH"
  exit 1
  ;;
esac

if [[ "$OS" != "linux" && "$OS" != "darwin" ]]; then
  echo "Unsupported OS: $OS"
  exit 1
fi

echo "Fetching latest release info from GitHub API"
RELEASE_JSON=$(curl -sL $API_URL)

TAG_NAME=$(echo "$RELEASE_JSON" | grep -m 1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
echo "Latest version: $TAG_NAME"

# Find asset URL matching OS and ARCH
ASSET_URL=$(echo "$RELEASE_JSON" | grep -o "https://github.com/[^ ]*\(git-sizer-${TAG_NAME#v}-$OS-$ARCH.zip\)\"" | tr -d '"')

if [[ -z "$ASSET_URL" ]]; then
  echo "Could not find matching asset for $OS-$ARCH"
  exit 1
fi

echo "Downloading $ASSET_URL"
curl -L -o "$TMP_DIR/git-sizer.zip" "$ASSET_URL"

echo "Extracting"
unzip -q "$TMP_DIR/git-sizer.zip" -d "$TMP_DIR"

echo "Installing to $INSTALL_DIR"
chmod +x "$TMP_DIR/git-sizer"
sudo mv "$TMP_DIR/git-sizer" "$INSTALL_DIR/"

echo "Cleaning up"
rm -rf "$TMP_DIR"

echo "git-sizer installed successfully."
