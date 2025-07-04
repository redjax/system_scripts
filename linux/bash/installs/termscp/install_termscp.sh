#!/usr/bin/env bash

set -e

if command -v termscp &>/dev/null; then
  echo "termscp is already installed. Upgrade by running termscp --upgrade"
  exit 0
fi

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

## Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

## Get latest version from GitHub API
TERMSCP_VERSION=$(curl -s https://api.github.com/repos/veeso/termscp/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
## Remove leading 'v' if present (e.g., 'v${TERMSCP_VERSION}' -> '${TERMSCP_VERSION}')
TERMSCP_VERSION="${TERMSCP_VERSION#v}"

echo "Installing termscp v${TERMSCP_VERSION}"

## Map to GitHub asset names
case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64)
        FILE="termscp-v${TERMSCP_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
        ;;
      aarch64|arm64)
        FILE="termscp-v${TERMSCP_VERSION}-aarch64-unknown-linux-gnu.tar.gz"
        ;;
      *)
        echo "Unsupported Linux architecture: $ARCH"
        exit 1
        ;;
    esac
    ;;
  Darwin)
    case "$ARCH" in
      x86_64)
        FILE="termscp-v${TERMSCP_VERSION}-x86_64-apple-darwin.tar.gz"
        ;;
      arm64)
        FILE="termscp-v${TERMSCP_VERSION}-arm64-apple-darwin.tar.gz"
        ;;
      *)
        echo "Unsupported macOS architecture: $ARCH"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

## Create a temporary directory
TMPDIR=$(mktemp -d)

## Download the release
URL="https://github.com/veeso/termscp/releases/download/v${TERMSCP_VERSION}/$FILE"
ARCHIVE="$TMPDIR/termscp.tar.gz"

## Download the archive to the temp directory
echo "Downloading $FILE from $URL"
curl -L -o "$ARCHIVE" "$URL"

## Extract the archive into the temp directory
tar -xzf "$ARCHIVE" -C "$TMPDIR"

if [ "$OS" = "Darwin" ]; then
  ## macOS: install to /usr/local/bin (may require sudo)
  install -m 755 "$TMPDIR/termscp" /usr/local/bin/
else
  ## Linux: install to /usr/local/bin (may require sudo)
  sudo install -m 755 "$TMPDIR/termscp" /usr/local/bin/
fi

echo "termscp installed successfully!"
