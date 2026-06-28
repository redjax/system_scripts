#!/usr/bin/env bash
set -euo pipefail

OS="$(uname -s)"
ARCH="$(uname -m)"
INSTALL_DIR="/usr/local/bin"
TMPDIR=$(mktemp -d)

## Determine OS/ARCH for filename
case "$OS" in
Darwin)
  if [[ "$ARCH" == "arm64" ]]; then
    FILE_OS="Darwin_arm64"
  else
    FILE_OS="Darwin_x86_64"
  fi
  ;;
Linux)
  if [[ "$ARCH" == "x86_64" ]]; then
    FILE_OS="Linux_x86_64"
  else
    FILE_OS="Linux_arm64"
  fi
  ;;
*)
  echo "Unsupported OS: $OS"
  exit 1
  ;;
esac

## Get latest release tag from GitHub
LATEST_TAG=$(curl -s https://api.github.com/repos/simulot/immich-go/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
echo "Latest release: $LATEST_TAG"

## Get download URL for our OS/ARCH
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/simulot/immich-go/releases/latest |
  grep -Po '"browser_download_url": "\K.*?(?=")' |
  grep "$FILE_OS\.tar\.gz")

echo "Downloading $DOWNLOAD_URL "
curl -L -o "$TMPDIR/immich-go.tar.gz" "$DOWNLOAD_URL"

echo "Extracting"
tar -xzf "$TMPDIR/immich-go.tar.gz" -C "$TMPDIR"

echo "Installing to $INSTALL_DIR "
sudo mv "$TMPDIR/immich-go" "$INSTALL_DIR/immich-go"
sudo chmod +x "$INSTALL_DIR/immich-go"

echo "immich-go installed successfully!"
immich-go --version

rm -rf "$TMPDIR"
