#!/bin/bash

if ! command -v curl &>/dev/null; then
  echo "curl is not installed."
  exit 1
fi

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

## Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

echo "OS: $OS"
echo "ARCH: $ARCH"

## Detect distro using /etc/os-release
DISTRO=$(detect_distro)
echo "DISTRO: $DISTRO"

## Get latest version from GitHub API
DRY_VERSION=$(curl -s https://api.github.com/repos/moncho/dry/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
## Remove leading 'v' if present (e.g., 'v${TERMSCP_VERSION}' -> '${TERMSCP_VERSION}')
DRY_VERSION="${DRY_VERSION#v}"

echo "DRY_VERSION: $DRY_VERSION"

if command -v dry &>/dev/null; then
  echo "dry is already installed."
  exit 0
fi

echo "Installing dry (Terminal UI for Docker) v${DRY_VERSION}"

## Map to Github asset names
case "$OS" in
Linux)
  case "$ARCH" in
  x86_64)
    FILE="dry-linux-amd64"
    ;;
  aarch64 | arm64)
    FILE="dry-linux-arm64"
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
    FILE="dry-darwin-amd64"
    ;;
  arm64)
    FILE="dry-darwin-arm64"
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
URL="https://github.com/moncho/dry/releases/download/v${DRY_VERSION}/$FILE"
BIN_FILE="$TMPDIR/dry"

## Download the archive to the temp directory
echo "Downloading $FILE from $URL"
curl -L -o "$BIN_FILE" "$URL"

if [ "$OS" = "Darwin" ]; then
  ## macOS: install to /usr/local/bin (may require sudo)
  install -m 755 "$BIN_FILE" /usr/local/bin/
else
  ## Linux: install to /usr/local/bin (may require sudo)
  sudo install -m 755 "$BIN_FILE" /usr/local/bin/
fi

echo "dry installed successfully!"

exit 0