#!/usr/bin/env bash
set -e
OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

# Map architecture names for OpenTofu releases
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  i386|i686) ARCH="386" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Map OS for OpenTofu releases
case "$OS" in
  linux) OS="linux" ;;
  darwin) OS="darwin" ;;
  windows|mingw*) OS="windows" ;;
  *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

# Set version or fetch latest dynamically (hardcoded here for example)
VERSION="1.10.6"

ASSET_NAME="tofu_${VERSION}_${OS}_${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/opentofu/opentofu/releases/download/v${VERSION}/${ASSET_NAME}"

echo "Detected OS: $OS"
echo "Detected ARCH: $ARCH"
echo "Downloading OpenTofu release: $ASSET_NAME"
echo "From URL: $DOWNLOAD_URL"

TMP_DIR=$(mktemp -d)
cd $TMP_DIR

curl -L -o $ASSET_NAME $DOWNLOAD_URL
tar -xzf $ASSET_NAME

# Binary is named "tofu"
sudo mv tofu /usr/local/bin/opentofu
sudo chmod +x /usr/local/bin/opentofu

echo "OpenTofu installed successfully to /usr/local/bin/opentofu"
rm -rf $TMP_DIR
