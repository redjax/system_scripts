#!/usr/bin/env bash
set -euo pipefail

## Default install location
INSTALL_DIR="${HOME}/.local/bin"
TMP_DIR="$(mktemp -d)"

## Cleanup temp directory on exit
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

## Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux)   OS_NAME="Linux" ;;
    Darwin)  OS_NAME="Darwin" ;;
    CYGWIN*|MINGW*|MSYS*) OS_NAME="Windows" ;;
    *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

## Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ARCH_NAME="x86_64" ;;
    i386|i686) ARCH_NAME="i386" ;;
    arm64|aarch64) ARCH_NAME="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

## Determine file extension
EXT="tar.gz"
[[ "$OS_NAME" == "Windows" ]] && EXT="zip"

## Check if scaffold is installed
if command -v scaffold &>/dev/null; then
    read -rp "scaffold is already installed. Update to the latest version? [y/N]: " yn
    case "$yn" in
        [Yy]*) echo "Updating" ;;
        *) echo "Aborting."; exit 0 ;;
    esac
fi

## Get latest release tag from GitHub API
REPO="hay-kot/scaffold"
LATEST_TAG=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')

if [[ -z "$LATEST_TAG" ]]; then
    echo "Failed to fetch latest release."
    exit 1
fi

## Construct download URL
FILENAME="scaffold_${OS_NAME}_${ARCH_NAME}.${EXT}"
URL="https://github.com/$REPO/releases/download/$LATEST_TAG/$FILENAME"

echo "Downloading $FILENAME from $URL "
curl -L -o "$TMP_DIR/$FILENAME" "$URL"

## Extract and install
echo "Extracting $FILENAME"
if [[ "$EXT" == "tar.gz" ]]; then
    tar -xzf "$TMP_DIR/$FILENAME" -C "$TMP_DIR"
elif [[ "$EXT" == "zip" ]]; then
    unzip -q "$TMP_DIR/$FILENAME" -d "$TMP_DIR"
fi

## Make executable
chmod +x "$TMP_DIR/scaffold"

## Create install dir if missing
mkdir -p "$INSTALL_DIR"

## Move binary
mv "$TMP_DIR/scaffold" "$INSTALL_DIR/"

echo "scaffold installed to $INSTALL_DIR"
echo "Make sure $INSTALL_DIR is in your PATH"
