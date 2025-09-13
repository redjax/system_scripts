#!/usr/bin/env bash

## Install OSV Scanner (https://github.com/google/osv-scanner)

set -e

if ! command -v curl &>/dev/null; then
  echo "[ERROR] curl is not installed."
  exit 1
fi

## Variables
REPO="google/osv-scanner"
API_URL="https://api.github.com/repos/$REPO/releases/latest"
INSTALL_DIR="/usr/local/bin"
TMP_DIR=$(mktemp -d)
BINARY_NAME="osv-scanner"
VERSION=""
DOWNLOAD_URL=""
TARGET=""

## Detect OS type
OS_TYPE="$(uname | tr '[:upper:]' '[:lower:]')"

## Detect CPU architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

## Map OS and Arch to release asset name format
if [[ "$OS_TYPE" == "darwin" ]]; then
    TARGET="${BINARY_NAME}_darwin_${ARCH}"
elif [[ "$OS_TYPE" == "linux" ]]; then
    TARGET="${BINARY_NAME}_linux_${ARCH}"
elif [[ "$OS_TYPE" == "windowsnt" ]] || [[ "$OS_TYPE" == "mingw"* ]] || [[ "$OS_TYPE" == "msys"* ]]; then
    TARGET="${BINARY_NAME}_windows_${ARCH}.exe"
else
    echo "Unsupported OS: $OS_TYPE"
    exit 1
fi

## Fetch latest release info from GitHub API
echo "Fetching latest release info for $REPO..."

release_json=$(curl -s $API_URL)
VERSION=$(echo "$release_json" | grep -Po '"tag_name": "\K.*?(?=")')

if [[ -z "$VERSION" ]]; then
    echo "Could not retrieve the latest version."
    exit 1
fi

echo "Latest version detected: $VERSION"
DOWNLOAD_URL=$(echo "$release_json" | grep -Po '"browser_download_url": "\K.*?(?=")' | grep "$TARGET")

if [[ -z "$DOWNLOAD_URL" ]]; then
    echo "Could not find a download URL for target $TARGET"
    exit 1
fi

## Download the binary
echo "Downloading $TARGET from $DOWNLOAD_URL ..."
curl -L -o "$TMP_DIR/$BINARY_NAME" "$DOWNLOAD_URL"

## Set executable permission
chmod +x "$TMP_DIR/$BINARY_NAME"

## Move to install directory
echo "Installing to $INSTALL_DIR/$BINARY_NAME ..."
sudo mv "$TMP_DIR/$BINARY_NAME" "$INSTALL_DIR/"

## Clean up
rm -rf "$TMP_DIR"

echo "Installation complete. Verify by running: $BINARY_NAME --version"

